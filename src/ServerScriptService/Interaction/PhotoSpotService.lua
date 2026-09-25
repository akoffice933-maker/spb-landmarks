--!strict
--[[
	PhotoSpotService.lua — Photo Spots (п.5.3 ТЗ).

	Решение v1.0: мы НЕ делаем кастомный захват кадра (дорого и ломается на
	мобильных), а подготавливаем сцену под системный скриншот игрока:
		1. Игрок входит в зону (ZonePlus) или жмёт ProximityPrompt;
		2. Сервер валидирует, что игрок действительно рядом с точкой;
		3. Клиент скрывает весь UI, показывает рамку (обычную или VIP);
		4. Игрок делает скриншот средствами устройства;
		5. Клиент сообщает о «снимке» — сервер пишет в VisitedLandmarks и PhotoCount.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Landmarks = require(Shared.Config.Landmarks)
local Theme = require(Shared.Config.Theme)
local Validate = require(Shared.Util.Validate)

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local ZoneService = require(script.Parent.Parent.Zones.ZoneService)
local MonetizationController = require(script.Parent.Parent.Monetization.MonetizationController)

local MAX_INTERACTION_DISTANCE = 30
local CAPTURE_COOLDOWN = 3

local PhotoSpotService = {}

local spotsById: { [string]: Instance } = {}
local lastCaptureAt: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.FireClient(Remotes.Names.Notify, player, { Text = text, Kind = kind or "info" })
end

local function getRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

local function isPlayerNearSpot(player: Player, landmarkId: string): boolean
	local spot = spotsById[landmarkId]
	if not spot then
		return false
	end

	local root = getRootPart(player)
	if not root then
		return false
	end

	local spotPosition = if spot:IsA("Model") then spot:GetPivot().Position else (spot :: BasePart).Position
	return (root.Position - spotPosition).Magnitude <= MAX_INTERACTION_DISTANCE
end

local function getFrameStyle(player: Player)
	if MonetizationController.HasFeature(player, "VipPhotoFrame") then
		return Theme.PhotoFrames.VipPhotographer
	end
	return Theme.PhotoFrames.Default
end

local function startSession(player: Player, landmarkId: string)
	if not Landmarks.Get(landmarkId) then
		return
	end
	if not isPlayerNearSpot(player, landmarkId) then
		return
	end

	Remotes.FireClient(Remotes.Names.PhotoSessionStart, player, {
		LandmarkId = landmarkId,
		DisplayName = Landmarks.GetDisplayName(landmarkId),
		Frame = getFrameStyle(player),
	})
end

--=== Настройка объектов на карте ================================================

local function ensurePrompt(spot: Instance, landmarkId: string): ProximityPrompt
	local existing = spot:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existing then
		existing:SetAttribute("Managed", true)
		return existing
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PhotoPrompt"
	prompt.ActionText = "Сделать фото"
	prompt.ObjectText = Landmarks.GetDisplayName(landmarkId)
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = spot
	return prompt
end

local function setupSpots()
	local photoSpots = workspace:FindFirstChild("PhotoSpots")
	if not photoSpots then
		warn("[PhotoSpotService] Workspace/PhotoSpots не найдена")
		return
	end

	for _, spot in ipairs(photoSpots:GetChildren()) do
		local landmarkId = spot:GetAttribute("LandmarkId")
		if type(landmarkId) ~= "string" or not Landmarks.Get(landmarkId) then
			warn(("[PhotoSpotService] %s: некорректный атрибут LandmarkId"):format(spot.Name))
			continue
		end

		spotsById[landmarkId] = spot

		local prompt = ensurePrompt(spot, landmarkId)
		prompt.Triggered:Connect(function(player: Player)
			startSession(player, landmarkId)
		end)
	end
end

--=== Обработка «снимка» от клиента ==============================================

local function onPhotoCaptured(player: Player, landmarkId: any)
	if not Validate.LandmarkId(landmarkId) then
		warn(("[PhotoSpotService] Некорректный LandmarkId от %s"):format(player.Name))
		return
	end

	local id = landmarkId :: string

	if not ZoneService.IsPlayerInPhotoSpot(player, id) and not isPlayerNearSpot(player, id) then
		warn(
			("[PhotoSpotService] %s попытался отметить фото вне зоны %s"):format(
				player.Name,
				id
			)
		)
		return
	end

	local now = os.clock()
	if (lastCaptureAt[player] or 0) + CAPTURE_COOLDOWN > now then
		return
	end
	lastCaptureAt[player] = now

	PlayerDataService.MarkVisited(player, id)
	PlayerDataService.IncrementPhotoCount(player, 1)

	notify(player, ("Снимок сохранён: %s"):format(Landmarks.GetDisplayName(id)), "success")
end

function PhotoSpotService.Start()
	setupSpots()

	ZoneService.PhotoSpotEntered:Connect(function(player: Player, landmarkId: string)
		Remotes.FireClient(Remotes.Names.PhotoSpotHint, player, {
			Visible = true,
			LandmarkId = landmarkId,
			Text = "Нажмите E, чтобы подготовить кадр",
		})
	end)

	ZoneService.PhotoSpotExited:Connect(function(player: Player)
		Remotes.FireClient(Remotes.Names.PhotoSpotHint, player, { Visible = false })
	end)

	Remotes.OnServerEvent(Remotes.Names.PhotoCaptured, onPhotoCaptured)

	Players.PlayerRemoving:Connect(function(player)
		lastCaptureAt[player] = nil
	end)
end

return PhotoSpotService
