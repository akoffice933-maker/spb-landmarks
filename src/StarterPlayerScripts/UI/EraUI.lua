--!strict
--[[
	EraUI.lua — панель пасса «Костюмы эпохи» (Feature = "EraSkins", п.14.1 ТЗ).

	Состав фичи:
	  * «Эффекты белых ночей» — клиентский визуальный слой поверх серверного
	    освещения: свой ColorCorrection и SunRays (эффекты одного класса
	    роблокса суммируются, серверный пресет не портим) + блёстки на Неве.
	    НОЛЬ новых источников света — бюджет п.4.4 не затронут.
	  * «Гардероб» — костюмы эпохи уйдут в v2.0 с ролеплеем; в v1.0 слоты
	    показываются как «скоро», чтобы покупатель видел дорожную карту.

	Состояние — настройка профиля EraEffectsOn. Клиент шлёт UpdateSettings;
	сервер валидирует тип значения И владение пассом (п.16, см.
	MonetizationController -> RegisterSettingValidator).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)
local GamePasses = require(Shared.Config.GamePasses)

local UIInstances = require(script.Parent.UIInstances)
local SettingsClient = require(script.Parent.SettingsClient)
local DataClient = require(script.Parent.Parent.Data.DataClient)

local PASS_KEY = "EraSkins"
local SETTING_KEY = "EraEffectsOn"
local WHITE_NIGHTS_MODE = "whiteNights"

local EraUI = {}

local gui: ScreenGui? = nil
local toggleButton: TextButton? = nil
local isOpen = false

-- Клиентский слой эффектов (создаются лениво, один раз)
local eraColorCorrection: ColorCorrectionEffect? = nil
local eraSunRays: SunRaysEffect? = nil
local eraSparkles: ParticleEmitter? = nil

local currentMode: string? = nil

local function owned(): boolean
	return DataClient.OwnsPass(PASS_KEY)
end

local function effectsEnabledInProfile(): boolean
	return DataClient.GetSetting(SETTING_KEY, false) == true
end

local function ensureColorCorrection(): ColorCorrectionEffect
	if eraColorCorrection and eraColorCorrection.Parent == Lighting then
		return eraColorCorrection
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "SPB_EraCC"
	-- Priority выше серверного: слои суммируются, не конфликтуют.
	effect.Priority = 2
	effect.Brightness = 0.02
	effect.Contrast = 0.04
	effect.Saturation = 0.06
	effect.TintColor = Color3.fromRGB(255, 231, 204) -- тёплый налёт белой ночи
	effect.Enabled = false
	effect.Parent = Lighting
	eraColorCorrection = effect
	return effect
end

local function ensureSunRays(): SunRaysEffect
	if eraSunRays and eraSunRays.Parent == Lighting then
		return eraSunRays
	end
	local effect = Instance.new("SunRaysEffect")
	effect.Name = "SPB_EraSunRays"
	effect.Priority = 2
	effect.Intensity = 0.045
	effect.Spread = 0.75
	effect.Enabled = false
	effect.Parent = Lighting
	eraSunRays = effect
	return effect
end

local function ensureSparkles(): ParticleEmitter?
	if eraSparkles and eraSparkles.Parent then
		return eraSparkles
	end

	local neva: BasePart? = nil
	for _, descendant in workspace:GetDescendants() do
		if descendant.Name == "Neva" and descendant:IsA("BasePart") then
			neva = descendant
			break
		end
	end
	if not neva then
		return nil
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SPB_EraSparkles"
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.Lifetime = NumberRange.new(2.5, 4.5)
	emitter.SpreadAngle = Vector2.new(180, 15)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.85
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 214)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 228, 255)),
	})
	emitter.Enabled = false
	emitter.Parent = neva
	eraSparkles = emitter
	return emitter
end

local function setEffectsActive(active: boolean)
	ensureColorCorrection().Enabled = active
	ensureSunRays().Enabled = active
	if active then
		local emitter = ensureSparkles()
		if emitter then
			emitter.Enabled = true
		end
	elseif eraSparkles then
		eraSparkles.Enabled = false
	end
end

local function refreshEffects()
	local active = owned() and effectsEnabledInProfile() and currentMode == WHITE_NIGHTS_MODE
	setEffectsActive(active)
end

local function requestPurchase()
	Remotes.FireServer(Remotes.Names.RequestPurchase, { Kind = "GamePass", Key = PASS_KEY })
end

local function refreshToggle()
	local button = toggleButton
	if not button then
		return
	end
	-- Цвет кнопки не трогаем: makeButton перезаписывает его на hover.
	if not owned() then
		local def = GamePasses.Get(PASS_KEY)
		button.Text = ("Купить «%s»"):format(if def then def.DisplayName else PASS_KEY)
	elseif effectsEnabledInProfile() then
		button.Text = "Эффекты: ВКЛ"
	else
		button.Text = "Эффекты: ВЫКЛ"
	end
end

local function buildUI()
	gui = UIInstances.getScreenGui("SPB_Era", 44)

	local _panel: Frame
	local body: Frame
	local closeButton: TextButton
	_panel, body, closeButton = UIInstances.makePanel(gui, {
		Title = "Костюмы эпохи",
		Size = UDim2.fromOffset(380, 300),
	})

	UIInstances.create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		Parent = body,
	})

	-- Описание пасса
	UIInstances.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = "Тёплый розово-золотой свет и блёстки воды во время пресета «Белые ночи». Индивидуальный слой — не влияет на других игроков.",
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.Sizes.Small,
		Font = Theme.Fonts.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = body,
	})

	-- Переключатель / покупка
	local button = UIInstances.makeButton(body, {
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
		Accent = false,
	})
	button.LayoutOrder = 2
	toggleButton = button

	button.Activated:Connect(function()
		if not owned() then
			requestPurchase()
			UIInstances.Notify({
				Text = "Открываю покупку пасса «Костюмы эпохи»…",
				Kind = "info",
			})
			return
		end
		local newValue = not effectsEnabledInProfile()
		SettingsClient.Set(SETTING_KEY, newValue)
		-- Отзывчивость: применяем сразу локально, снапшот подтвердит позже.
		setEffectsActive(newValue and currentMode == WHITE_NIGHTS_MODE)
		refreshToggle()
	end)

	-- Гардероб v2.0: честный слот-заглушка
	UIInstances.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Гардероб",
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Body,
		Font = Theme.Fonts.Button,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
		Parent = body,
	})

	local wardrobeRow = UIInstances.create("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Colors.Surface,
		LayoutOrder = 4,
		Parent = body,
	}, {
		UIInstances.corner(),
		UIInstances.stroke(),
	})

	UIInstances.create("TextLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 20),
		BackgroundTransparency = 1,
		Text = "Костюм эпохи Петра I",
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Body,
		Font = Theme.Fonts.Button,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wardrobeRow,
	})

	UIInstances.create("TextLabel", {
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -28, 0, 18),
		BackgroundTransparency = 1,
		Text = "скоро — с ролеплеем v2.0",
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.Sizes.Small,
		Font = Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wardrobeRow,
	})

	closeButton.Activated:Connect(function()
		EraUI.Close()
	end)
end

function EraUI.Open()
	if isOpen then
		return
	end
	isOpen = true

	if not gui then
		buildUI()
	end

	refreshToggle()
	refreshEffects()(gui :: ScreenGui).Enabled = true
end

function EraUI.Close()
	isOpen = false
	if gui then
		gui.Enabled = false
	end
end

function EraUI.Start()
	-- Реакция на смену пресета освещения (день/закат/белые ночи/ночь):
	Remotes.OnClientEvent(Remotes.Names.LightingState, function(state: any)
		if type(state) == "table" and type(state.Mode) == "string" then
			currentMode = state.Mode
			refreshEffects()
		end
	end)

	-- Реакция на покупку пасса / приход настроек с сервера:
	DataClient.ProfileChanged:Connect(function()
		refreshEffects()
		if isOpen then
			refreshToggle()
		end
	end)

	refreshEffects()
end

return EraUI
