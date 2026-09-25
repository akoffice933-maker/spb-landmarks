--!strict
--[[
	ShadowHunterService.lua — квест «Охотник за тенями» (ночной стелс-фото).

	Логика круга:
	  1. Раз в SPAWN_PERIOD секунд у случайной фото-точки на SPAWN_WINDOW
	     секунд встаёт «Тень» (процедурная фигура, света 0 — бюджет п.4.4).
	  2. Тень медленно осматривается. Если игрок ближе ALERT_DISTANCE
	     находится в её секторе взгляда И НЕ в фото-режиме — накапливается
	     внимание; ALERT_SECONDS секунд задержки → Тень ускользает.
	  3. Фото-режим = маскировка: в нём можно смотреть сколько угодно.
	     Захват = серверная валидация RequestShadowCapture (расстояние,
	     кулдаун, наличие Тени) → +1 к ShadowCaptures в профиле.
	  4. Три захвата открывают наряд «Ноктюрн» (см. AvatarPresets).

	Профиль: ShadowCaptures добавлен в ProfileTemplate; клиентский каунтер
	летит в ShadowQuestState (снимок профиля отдельной схемой — не трогаем).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Landmarks = require(Shared.Config.Landmarks)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

-- Мастер-выключатель квеста (календарный ивент: false = событие не идёт)
local SHADOW_QUEST_ENABLED = true

local FIRST_SPAWN_DELAY = 45 -- первое окно быстро, чтобы проверить в Studio
local SPAWN_PERIOD = 210 -- пауза между окнами появления Тени, сек
local SPAWN_WINDOW = 120 -- сколько Тень простоит, сек
local ALERT_DISTANCE = 32 -- радиус восприятия, стадов
local ALERT_SECONDS = 3 -- сколько можно смотреть на Тень без камеры
local ALERT_CONE_DOT = 0.34 -- косинус ~70° — сектор "перед глазами"
local CAPTURE_DISTANCE = 48 -- дальность запечатления
local CAPTURE_COOLDOWN = 2
local QUEST_TARGET = 3 -- снимков до награды

local ShadowHunterService = {}

local activeShadow: Model? = nil
local activeLandmarkId: string? = nil
local facingAngle = 0
local windowActiveUntil = 0
local nextSpawnAt = 0
local exposure: { [Player]: number } = {}
local photoMode: { [Player]: boolean } = {}
local lastCaptureAt: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.FireClient(Remotes.Names.Notify, player, { Text = text, Kind = kind or "info" })
end

local function getCaptureCount(player: Player): number
	local data = PlayerDataService.GetData(player)
	local count = if data then (data :: any).ShadowCaptures else nil
	return if type(count) == "number" then count else 0
end

local function broadcastState()
	for _, player in Players:GetPlayers() do
		Remotes.FireClient(Remotes.Names.ShadowQuestState, player, {
			Active = activeShadow ~= nil,
			LandmarkId = activeLandmarkId,
			DisplayName = if activeLandmarkId then Landmarks.GetDisplayName(activeLandmarkId) else nil,
			Captures = getCaptureCount(player),
			Required = QUEST_TARGET,
		})
	end
end

local function getRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

--=== Тень как объект ============================================================

local function buildShadow(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "ShadowHunter_Shadow"

	local cloak = Instance.new("Part")
	cloak.Name = "Cloak"
	cloak.Size = Vector3.new(2.6, 5.2, 1.7)
	cloak.CFrame = CFrame.new(position + Vector3.new(0, 2.6, 0))
	cloak.Transparency = 0.35
	cloak.Color = Color3.fromRGB(22, 24, 34)
	cloak.Material = Enum.Material.SmoothPlastic
	cloak.CanCollide = false
	cloak.CanQuery = false
	cloak.Anchored = true
	cloak.Parent = model

	local hood = Instance.new("Part")
	hood.Name = "Hood"
	hood.Size = Vector3.new(2.1, 2.1, 2.1)
	hood.Transparency = 0.3
	hood.Shape = Enum.PartType.Ball
	hood.Color = Color3.fromRGB(26, 28, 38)
	hood.CanCollide = false
	hood.CanQuery = false
	hood.Anchored = true
	-- Капюшон чуть сверху плаща
	hood.CFrame = CFrame.new(position + Vector3.new(0, 5.3, 0))
	hood.Parent = model

	-- Глаза: яркий материал, НЕ источники света (п.4.4 соблюдён)
	for _, offset in { Vector3.new(-0.3, 5.45, 0.72), Vector3.new(0.3, 5.45, 0.72) } do
		local eye = Instance.new("Part")
		eye.Name = if offset.X < 0 then "EyeL" else "EyeR"
		eye.Size = Vector3.new(0.24, 0.24, 0.24)
		eye.Shape = Enum.PartType.Ball
		eye.Transparency = 0.15
		eye.Color = Color3.fromRGB(150, 170, 255)
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
		eye.CanQuery = false
		eye.Anchored = true
		eye.CFrame = CFrame.new(position + offset)
		eye.Parent = model
	end

	model.PrimaryPart = cloak
	model.Parent = workspace
	return model
end

local function despawnShadow(reason: string)
	if not activeShadow then
		return
	end
	local model = activeShadow
	activeShadow = nil
	activeLandmarkId = nil
	broadcastState()

	-- Плавное растворение перед разрушением
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.7), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.8, function()
		model:Destroy()
	end)
	if reason == "spotted" then
		for _, player in Players:GetPlayers() do
			notify(
				player,
				"👁 Тень заметила взгляд и растаяла в набережной дымке.",
				"info"
			)
		end
	end
end

local function spawnShadow()
	local photoSpots = workspace:FindFirstChild("PhotoSpots")
	if not photoSpots then
		return
	end
	local spots: { Instance } = {}
	for _, child in photoSpots:GetChildren() do
		if child.Name:find("^PhotoSpot_") then
			table.insert(spots, child)
		end
	end
	if #spots == 0 then
		return
	end

	local spot = spots[math.random(#spots)]
	local position = if spot:IsA("Model") then (spot :: Model):GetPivot().Position else (spot :: BasePart).Position
	-- Ставим рядом с фото-точкой, не прямо на ней
	local shadowPos = position + Vector3.new(7, 0.5, 7)
	activeShadow = buildShadow(shadowPos)
	activeLandmarkId = spot.Name:gsub("^PhotoSpot_", "")
	facingAngle = math.rad(math.random(0, 360))
	windowActiveUntil = os.clock() + SPAWN_WINDOW
	exposure = {}

	for _, player in Players:GetPlayers() do
		notify(
			player,
			("🌘 Ночь теней: силуэт замечен у «%s». Фото-режим — твоя маскировка."):format(
				Landmarks.GetDisplayName(activeLandmarkId :: string)
			),
			"info"
		)
	end
	broadcastState()
end

--=== Сердцебиение квеста ========================================================

local function heartbeat(dt: number)
	local now = os.clock()
	if activeShadow and activeShadow.PrimaryPart then
		local cloak = activeShadow.PrimaryPart
		facingAngle += dt * 0.55 -- медленный обзор на месте
		activeShadow:PivotTo(CFrame.new(cloak.Position) * CFrame.Angles(0, facingAngle, 0))

		if now >= windowActiveUntil then
			despawnShadow("timeout")
			return
		end

		local facing = CFrame.Angles(0, facingAngle, 0).LookVector
		for _, player in Players:GetPlayers() do
			local root = getRootPart(player)
			if root then
				local toPlayer = root.Position - cloak.Position
				local distance = toPlayer.Magnitude
				if distance <= ALERT_DISTANCE then
					if facing:Dot(toPlayer.Unit) > ALERT_CONE_DOT and not photoMode[player] then
						exposure[player] = (exposure[player] or 0) + dt
						if exposure[player] >= ALERT_SECONDS then
							notify(
								player,
								"👁 Тень встретилась с тобой взглядом...",
								"warn"
							)
							despawnShadow("spotted")
							return
						end
					else
						exposure[player] = math.max(0, (exposure[player] or 0) - dt * 2)
					end
				else
					exposure[player] = math.max(0, (exposure[player] or 0) - dt)
				end
			end
		end
	else
		if now >= nextSpawnAt then
			spawnShadow()
			nextSpawnAt = os.clock() + SPAWN_PERIOD
		end
	end
end

--=== Запросы клиента ============================================================

local function onCaptureRequest(player: Player)
	if not activeShadow or not activeShadow.PrimaryPart then
		return
	end
	local now = os.clock()
	if lastCaptureAt[player] and now - lastCaptureAt[player] < CAPTURE_COOLDOWN then
		return
	end
	lastCaptureAt[player] = now

	if not photoMode[player] then
		notify(
			player,
			"Тень ловится только из фото-режима — встань у фото-точки и открой камеру.",
			"warn"
		)
		return
	end

	local root = getRootPart(player)
	if not root then
		return
	end
	if (root.Position - activeShadow.PrimaryPart.Position).Magnitude > CAPTURE_DISTANCE then
		return
	end

	-- Засчитываем снимок
	despawnShadow("captured")
	local data = PlayerDataService.GetData(player)
	if data then
		(data :: any).ShadowCaptures = getCaptureCount(player) + 1
		PlayerDataService.DataChanged:Fire(player, "ShadowCaptures")
	end
	PlayerDataService.IncrementPhotoCount(player, 1)

	local captures = getCaptureCount(player)
	if captures >= QUEST_TARGET then
		notify(
			player,
			("📸 Тень запечатлена! Открыта награда: наряд «Ноктюрн» (вкладка «Стиль»)."):format(),
			"success"
		)
	else
		notify(player, ("📸 Тень запечатлена! Прогресс %d/3."):format(captures), "success")
	end
	broadcastState()
end

local function onHunterState(player: Player, payload: any)
	-- Клиент честно сообщает, в фото-режиме ли он; при обмане раунд просто
	-- станет легче — чит не даёт внеплановой награды (расстояние проверяется).
	if type(payload) == "boolean" then
		photoMode[player] = payload
	end
end

local function onPlayerRemoving(player: Player)
	exposure[player] = nil
	photoMode[player] = nil
	lastCaptureAt[player] = nil
end

function ShadowHunterService.Start()
	if not SHADOW_QUEST_ENABLED then
		return
	end
	Remotes.OnServerEvent(Remotes.Names.RequestShadowCapture, onCaptureRequest)
	Remotes.OnServerEvent(Remotes.Names.ShadowHunterState, onHunterState)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	PlayerDataService.ProfileReady:Connect(function()
		broadcastState()
	end)
	nextSpawnAt = os.clock() + FIRST_SPAWN_DELAY
	RunService.Heartbeat:Connect(heartbeat)
end

return ShadowHunterService
