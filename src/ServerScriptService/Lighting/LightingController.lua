--!strict
--[[
	LightingController.lua — система дня/ночи и уличного освещения (п.4, п.12.2 ТЗ).

	Готовых качественных библиотек под день/ночь почти нет (п.17.5), поэтому
	контроллер свой. Он отвечает за:
	  * плавный цикл ClockTime (полный цикл ~25 реальных минут);
	  * пресеты освещения (day / sunset / whiteNights / night) с твинами;
	  * автоматическое включение фонарей и подсветки зданий;
	  * ручное управление временем — только для владельцев Game Pass «Хронос».

	Публичное API:
		LightingController.Start()
		LightingController.SetTime(hour)
		LightingController.SetMode("day" | "sunset" | "whiteNights" | "night")
		LightingController.UpdateLamps(force?)
		LightingController.GetState() -> { Mode, ClockTime, IsNight, Manual }
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local LightingPresets = require(Shared.Config.LightingPresets)
local Validate = require(Shared.Util.Validate)

local MonetizationController = require(script.Parent.Parent.Monetization.MonetizationController)

local LAMP_TAG = "Lamp"
local BUILDING_LIGHT_TAG = "BuildingLight"

local MODE_REQUEST_COOLDOWN = 3

local LightingController = {}

local Config = LightingPresets.Config

local state = {
	Mode = "day",
	ClockTime = Config.StartClockTime,
	Manual = false,
	IsNight = false,
}

local atmosphere: Atmosphere? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil

local lastModeRequest: { [Player]: number } = {}
local broadcastAccumulator = 0
local started = false

--=== Постобработка ==============================================================

local function ensureEffects()
	if not atmosphere then
		atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if not atmosphere then
			local created = Instance.new("Atmosphere")
			created.Name = "CityAtmosphere"
			created.Parent = Lighting
			atmosphere = created
		end
	end

	if not colorCorrection then
		colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if not colorCorrection then
			local created = Instance.new("ColorCorrectionEffect")
			created.Name = "CityColorCorrection"
			created.Parent = Lighting
			colorCorrection = created
		end
	end

	if not bloom then
		bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		if not bloom then
			local created = Instance.new("BloomEffect")
			created.Name = "CityBloom"
			created.Parent = Lighting
			bloom = created
		end
	end
end

local function tweenProperties(
	instance: Instance,
	properties: { [string]: any },
	duration: number,
	skipClockTime: boolean
)
	for property, value in pairs(properties) do
		if skipClockTime and property == "ClockTime" then
			continue
		end

		-- Динамическое обращение к свойству: оборачиваем в pcall, чтобы
		-- опечатка в пресете не уронила весь контроллер
		local ok = pcall(function()
			local current = (instance :: any)[property]
			if current == nil then
				return
			end
			TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Sine), { [property] = value }):Play()
		end)

		if not ok then
			warn(
				("[LightingController] Свойство %s.%s недоступно"):format(
					instance.ClassName,
					property
				)
			)
		end
	end
end

local function applyPreset(modeId: string, includeClockTime: boolean)
	local preset = LightingPresets.Get(modeId)
	if not preset then
		return
	end

	ensureEffects()

	state.Mode = modeId

	tweenProperties(Lighting, preset.Lighting, preset.TransitionSeconds, not includeClockTime)
	if atmosphere then
		tweenProperties(atmosphere, preset.Atmosphere, preset.TransitionSeconds, false)
	end
	if colorCorrection then
		tweenProperties(colorCorrection, preset.ColorCorrection, preset.TransitionSeconds, false)
	end
	if bloom then
		tweenProperties(bloom, preset.Bloom, preset.TransitionSeconds, false)
	end

	if includeClockTime then
		state.ClockTime = preset.ClockTime
		TweenService:Create(
			Lighting,
			TweenInfo.new(preset.TransitionSeconds, Enum.EasingStyle.Sine),
			{ ClockTime = preset.ClockTime }
		):Play()
	end

	LightingController.UpdateLamps(true)
end

--=== Фонари и подсветка =========================================================

local function isNightTime(clockTime: number): boolean
	return clockTime >= Config.LampOnFrom or clockTime <= Config.LampOnTo
end

local function forEachLight(instance: Instance, callback: (light: Light) -> ())
	if instance:IsA("Light") then
		callback(instance :: Light)
		return
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Light") then
			callback(descendant :: Light)
		end
	end
end

local function setGlow(instance: Instance, enabled: boolean)
	-- Светящаяся часть фонаря: ищем прямого ребёнка с именем Glow
	local glow = instance:FindFirstChild("Glow")
	if not glow or not glow:IsA("BasePart") then
		return
	end

	if glow:GetAttribute("DayMaterial") == nil then
		glow:SetAttribute("DayMaterial", glow.Material.Name)
	end

	if enabled then
		glow.Material = Enum.Material.Neon
	else
		local dayMaterial = glow:GetAttribute("DayMaterial")
		local ok = pcall(function()
			glow.Material = (Enum.Material :: any)[dayMaterial]
		end)
		if not ok then
			glow.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function toggleTagged(tag: string, enabled: boolean)
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		forEachLight(instance, function(light)
			light.Enabled = enabled
		end)
		if tag == LAMP_TAG then
			setGlow(instance, enabled)
		end
	end
end

function LightingController.UpdateLamps(force: boolean?)
	local isNight = isNightTime(Lighting.ClockTime)

	if not force and isNight == state.IsNight then
		return
	end

	state.IsNight = isNight
	toggleTagged(LAMP_TAG, isNight)
	toggleTagged(BUILDING_LIGHT_TAG, isNight)
end

--=== Цикл времени ===============================================================

local function advanceClock(deltaTime: number)
	if state.Manual then
		return
	end

	local hoursPerSecond = 24 / (Config.CycleLengthMinutes * 60)
	state.ClockTime = (state.ClockTime + deltaTime * hoursPerSecond) % 24
	Lighting.ClockTime = state.ClockTime

	if Config.AutoMode then
		local autoMode = LightingPresets.ModeForClockTime(state.ClockTime)
		if autoMode ~= state.Mode then
			-- Пресет применяется без перемотки ClockTime, чтобы цикл шёл плавно
			applyPreset(autoMode, false)
		end
	end
end

local function broadcast(deltaTime: number)
	broadcastAccumulator += deltaTime
	if broadcastAccumulator < Config.StateBroadcastInterval then
		return
	end
	broadcastAccumulator = 0

	Remotes.FireAllClients(Remotes.Names.LightingState, LightingController.GetState())
end

--=== Публичное API ==============================================================

function LightingController.GetState()
	return {
		Mode = state.Mode,
		ClockTime = state.ClockTime,
		IsNight = state.IsNight,
		Manual = state.Manual,
		LampsOn = state.IsNight,
	}
end

function LightingController.SetTime(hour: number)
	if not Validate.Hour(hour) then
		return
	end

	state.ClockTime = hour % 24
	Lighting.ClockTime = state.ClockTime
	LightingController.UpdateLamps()
end

function LightingController.SetMode(modeId: string, manual: boolean?)
	if not LightingPresets.IsMode(modeId) then
		return
	end

	state.Manual = manual == true
	applyPreset(modeId, true)
end

--=== Ручное управление (Game Pass «Хронос») =====================================

local function canRequest(player: Player): boolean
	if not MonetizationController.HasFeature(player, "ManualLighting") then
		Remotes.FireClient(Remotes.Names.Notify, player, {
			Text = "Управление временем суток доступно с пропуском «Хронос»",
			Kind = "info",
		})
		return false
	end

	local now = os.clock()
	if (lastModeRequest[player] or 0) + MODE_REQUEST_COOLDOWN > now then
		return false
	end
	lastModeRequest[player] = now
	return true
end

local function onRequestMode(player: Player, payload: any)
	if type(payload) ~= "table" or not LightingPresets.IsMode(payload.Mode) then
		warn(("[LightingController] Некорректный режим от %s"):format(player.Name))
		return
	end
	if not canRequest(player) then
		return
	end

	LightingController.SetMode(payload.Mode, true)
end

local function onRequestTime(player: Player, payload: any)
	if type(payload) ~= "table" or not Validate.Hour(payload.Hour) then
		warn(("[LightingController] Некорректное время от %s"):format(player.Name))
		return
	end
	if not canRequest(player) then
		return
	end

	state.Manual = true
	LightingController.SetTime(payload.Hour)

	-- Подтягиваем соответствующий пресет (без перемотки времени)
	local autoMode = LightingPresets.ModeForClockTime(state.ClockTime)
	if autoMode ~= state.Mode then
		applyPreset(autoMode, false)
	end
end

function LightingController.Start()
	if started then
		return
	end
	started = true

	ensureEffects()
	Lighting.ClockTime = state.ClockTime

	-- Стартовый пресет по времени суток
	local startMode = LightingPresets.ModeForClockTime(state.ClockTime)
	applyPreset(startMode, false)
	LightingController.UpdateLamps(true)

	-- Новые фонари могут появиться в Studio в любой момент — подхватываем
	for _, tag in ipairs({ LAMP_TAG, BUILDING_LIGHT_TAG }) do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
			local enabled = isNightTime(Lighting.ClockTime)
			forEachLight(instance, function(light)
				light.Enabled = enabled
			end)
			if tag == LAMP_TAG then
				setGlow(instance, enabled)
			end
		end)
	end

	Remotes.OnServerEvent(Remotes.Names.RequestLightingMode, onRequestMode)
	Remotes.OnServerEvent(Remotes.Names.RequestLightingTime, onRequestTime)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		advanceClock(deltaTime)
		LightingController.UpdateLamps()
		broadcast(deltaTime)
	end)
end

return LightingController
