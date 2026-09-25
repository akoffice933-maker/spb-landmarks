--!strict
--[[
	SpawnService.lua — точки спавна (п.5.1) и быстрое перемещение (п.14.2).

	Точки спавна: Workspace/Spawns/<SpawnLocation или BasePart> с атрибутом
	SpawnId ("Dvortsovaya" | "Nevsky" | "Petropavlovka"). При старте игроку
	прилитает выбор точки (ShowSpawnChoice), выбранная точка становится
	RespawnLocation на сессию.

	Быстрое перемещение: покупается как Developer Product (выдача окна в
	ProductHandler), цели — Workspace/FastTravel/<LandmarkId>. Точки подбирают
	стальных, у кого Landmarks.FastTravel == true.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Landmarks = require(Shared.Config.Landmarks)
local Validate = require(Shared.Util.Validate)

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local ProductHandler = require(script.Parent.Parent.Monetization.ProductHandler)

local TELEPORT_OFFSET_Y = 4
local SHOW_SPAWN_CHOICE_DELAY = 1.2

local SpawnService = {}

local spawnPoints: { [string]: BasePart } = {}
local travelPoints: { [string]: BasePart } = {}
local playerSpawnSelection: { [Player]: string? } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.FireClient(Remotes.Names.Notify, player, { Text = text, Kind = kind or "info" })
end

local function collectPoints()
	local spawnsFolder = workspace:FindFirstChild("Spawns")
	if spawnsFolder then
		for _, child in ipairs(spawnsFolder:GetChildren()) do
			local spawnId = child:GetAttribute("SpawnId")
			if type(spawnId) == "string" and Landmarks.GetSpawn(spawnId) and child:IsA("BasePart") then
				spawnPoints[spawnId] = child
			else
				-- Поддержка именованных частей вида Spawn_Dvortsovaya (без атрибута)
				local name = child.Name:match("^Spawn_(.+)$")
				if name and Landmarks.GetSpawn(name) and child:IsA("BasePart") then
					spawnPoints[name] = child
				end
			end
		end
	else
		warn("[SpawnService] Workspace/Spawns не найдена")
	end

	local travelFolder = workspace:FindFirstChild("FastTravel")
	if travelFolder then
		for _, child in ipairs(travelFolder:GetChildren()) do
			if child:IsA("BasePart") and Landmarks.Get(child.Name) then
				travelPoints[child.Name] = child
			end
		end
	end
end

local function getPartPosition(part: BasePart): Vector3
	return part.Position + Vector3.new(0, part.Size.Y / 2 + TELEPORT_OFFSET_Y, 0)
end

local function teleportPlayer(player: Player, target: BasePart, faceForward: boolean?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end

	local position = getPartPosition(target)
	root.CFrame = CFrame.new(position, position + target.CFrame.LookVector * (faceForward == false and 0 or 4))
	return true
end

function SpawnService.GetSpawnChoices(): { any }
	local choices: { any } = {}
	for _, spawnId in ipairs(Landmarks.SpawnOrder) do
		local spawn = Landmarks.GetSpawn(spawnId)
		if spawn then
			table.insert(choices, {
				Id = spawn.Id,
				DisplayName = spawn.DisplayName,
				Available = spawnPoints[spawn.Id] ~= nil,
			})
		end
	end
	return choices
end

local function sendSpawnChoice(player: Player)
	Remotes.FireClient(Remotes.Names.ShowSpawnChoice, player, {
		Choices = SpawnService.GetSpawnChoices(),
	})
end

function SpawnService.TeleportToLandmark(player: Player, landmarkId: string): boolean
	local target = travelPoints[landmarkId]
	if not target then
		return false
	end

	local ok = teleportPlayer(player, target)
	if ok then
		PlayerDataService.MarkVisited(player, landmarkId)
		Remotes.FireClient(Remotes.Names.TeleportFade, player, { Duration = 0.7 })
	end
	return ok
end

--=== Выбор точки спавна =========================================================

local function onSelectSpawn(player: Player, payload: any)
	if type(payload) ~= "table" or not Validate.SpawnId(payload.SpawnId) then
		warn(("[SpawnService] Некорректный SpawnId от %s"):format(player.Name))
		return
	end

	local spawnId = payload.SpawnId :: string
	local part = spawnPoints[spawnId]
	if not part then
		notify(player, "Эта точка временно недоступна", "info")
		return
	end

	playerSpawnSelection[player] = spawnId

	local spawnDef = Landmarks.GetSpawn(spawnId)
	if spawnDef then
		PlayerDataService.MarkVisited(player, spawnDef.LandmarkId)
	end

	if part:IsA("SpawnLocation") then
		player.RespawnLocation = part
	end

	if teleportPlayer(player, part) then
		Remotes.FireClient(Remotes.Names.TeleportFade, player, { Duration = 0.9 })
	end
end

--=== Быстрое перемещение (платное) ==============================================

local function onRequestFastTravel(player: Player, payload: any)
	if type(payload) ~= "table" or not Validate.LandmarkId(payload.LandmarkId) then
		warn(("[SpawnService] Некорректный LandmarkId от %s"):format(player.Name))
		return
	end

	local landmarkId = payload.LandmarkId :: string
	local landmark = Landmarks.Get(landmarkId)
	if not landmark or not landmark.FastTravel then
		return
	end

	-- Перемещение доступно только с купленным «билетом» (Developer Product)
	if not ProductHandler.ConsumeFastTravel(player) then
		notify(
			player,
			"Чтобы переместиться, купите «Быстрое перемещение» в магазине",
			"info"
		)
		return
	end

	if not SpawnService.TeleportToLandmark(player, landmarkId) then
		-- Точка ещё не построена на карте (этап 1–2) — билет не списываем назад,
		-- но и не врём игроку
		notify(
			player,
			"Точка перемещения пока строится. Билет не потрачен.",
			"info"
		)
		return
	end
end

function SpawnService.Start()
	collectPoints()

	PlayerDataService.ProfileReady:Connect(function(player: Player)
		task.delay(SHOW_SPAWN_CHOICE_DELAY, function()
			if player:IsDescendantOf(Players) then
				sendSpawnChoice(player)
			end
		end)
	end)

	Remotes.OnServerEvent(Remotes.Names.SelectSpawn, onSelectSpawn)
	Remotes.OnServerEvent(Remotes.Names.RequestFastTravel, onRequestFastTravel)

	Players.PlayerRemoving:Connect(function(player)
		playerSpawnSelection[player] = nil
	end)
end

return SpawnService
