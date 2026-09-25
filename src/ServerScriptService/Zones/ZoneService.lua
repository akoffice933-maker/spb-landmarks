--!strict
--[[
	ZoneService.lua — обвязка над ZonePlus (п.17.3 ТЗ).

	Зоны берутся из Workspace/Map/Zones (по папке на зону, Id == имя папки)
	и из Workspace/PhotoSpots (по объекту на фото-точку, атрибут LandmarkId).

	Что даёт зона:
	  * отметка «посещено» в профиле (VisitedLandmarks);
	  * включение эмбиента на клиенте (п.12.3);
	  * валидация действий игрока (например, Photo Spot — п.5.3);
	  * подсказки онбординга (п.5.5).

	Сервис деградирует аккуратно: если карта ещё не построена (этап 0–1
	разработки), он просто предупредит в консоль и продолжит работу.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zone = require(ReplicatedStorage.Packages.Zone)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local Landmarks = require(Shared.Config.Landmarks)

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

local ZoneService = {}

local CHILD_TIMEOUT = 10

ZoneService.PlayerEnteredZone = Signal.new() -- (player, zoneId)
ZoneService.PlayerExitedZone = Signal.new() -- (player, zoneId)
ZoneService.PhotoSpotEntered = Signal.new() -- (player, landmarkId)
ZoneService.PhotoSpotExited = Signal.new() -- (player, landmarkId)

type ZoneEntry = {
	Id: string,
	Zone: any,
	LandmarkId: string?,
}

local zoneEntries: { [string]: ZoneEntry } = {}
local photoSpotZones: { [string]: any } = {}
local playerZones: { [Player]: { [string]: boolean } } = {}
local playerTroves: { [Player]: any } = {}
local mainTrove = Trove.new()

local function waitForChild(parent: Instance, name: string, timeout: number): Instance?
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end
	return parent:WaitForChild(name, timeout)
end

local function getZoneId(instance: Instance, fallback: string): string
	local attribute = instance:GetAttribute("ZoneId")
	if type(attribute) == "string" and attribute ~= "" then
		return attribute
	end
	return instance.Name ~= "" and instance.Name or fallback
end

local function trackPlayerZone(player: Player, zoneId: string)
	local zones = playerZones[player]
	if not zones then
		zones = {}
		playerZones[player] = zones
	end
	zones[zoneId] = true
end

local function untrackPlayerZone(player: Player, zoneId: string)
	local zones = playerZones[player]
	if not zones then
		return
	end
	zones[zoneId] = nil
end

--[[ Приоритетная зона игрока: если он стоит на стыке зон (например, Невский и
	Дворцовая), эмбиент и подсказки берутся по первой зоне из реестра. ]]
local function getPrimaryZoneId(zones: { [string]: boolean }): string
	for id in pairs(Landmarks.Zones) do
		if zones[id] then
			return id
		end
	end
	for id in pairs(zones) do
		return id
	end
	return ""
end

local function pushZoneState(player: Player)
	local zones = playerZones[player] or {}
	local list: { string } = {}
	for zoneId in pairs(zones) do
		table.insert(list, zoneId)
	end

	local zoneDef = Landmarks.GetZone(getPrimaryZoneId(zones))
	Remotes.FireClient(Remotes.Names.ZoneChanged, player, {
		Zones = list,
		Ambient = if zoneDef then zoneDef.Ambient else nil,
	})
end

local function onZoneEntered(entry: ZoneEntry, player: Player)
	trackPlayerZone(player, entry.Id)

	if entry.LandmarkId then
		PlayerDataService.MarkVisited(player, entry.LandmarkId)
	end

	pushZoneState(player)
	ZoneService.PlayerEnteredZone:Fire(player, entry.Id)
end

local function onZoneExited(entry: ZoneEntry, player: Player)
	untrackPlayerZone(player, entry.Id)
	pushZoneState(player)
	ZoneService.PlayerExitedZone:Fire(player, entry.Id)
end

local function createZone(container: Instance, accuracy: string, landmarkId: string?): ZoneEntry?
	local ok, zone = pcall(function()
		return Zone.new(container)
	end)

	if not ok or not zone then
		warn(
			("[ZoneService] Не удалось создать зону для %s: %s"):format(
				container:GetFullName(),
				tostring(zone)
			)
		)
		return nil
	end

	zone:setAccuracy(accuracy)

	local entry: ZoneEntry = {
		Id = getZoneId(container, "Unknown"),
		Zone = zone,
		LandmarkId = landmarkId,
	}

	mainTrove:Add(zone)
	mainTrove:Connect(zone.playerEntered, function(player: Player)
		onZoneEntered(entry, player)
	end)
	mainTrove:Connect(zone.playerExited, function(player: Player)
		onZoneExited(entry, player)
	end)

	return entry
end

--=== Публичное API ==============================================================

function ZoneService.GetZone(zoneId: string): any
	local entry = zoneEntries[zoneId]
	return entry and entry.Zone or nil
end

function ZoneService.IsPlayerInZone(player: Player, zoneId: string): boolean
	local zone = ZoneService.GetZone(zoneId)
	if not zone then
		return false
	end
	return zone:findPlayer(player) == true
end

function ZoneService.IsPlayerInPhotoSpot(player: Player, landmarkId: string): boolean
	local zone = photoSpotZones[landmarkId]
	if not zone then
		return false
	end
	return zone:findPlayer(player) == true
end

function ZoneService.GetPhotoSpotZone(landmarkId: string): any
	return photoSpotZones[landmarkId]
end

function ZoneService.GetPlayerZones(player: Player): { string }
	local result: { string } = {}
	for zoneId in pairs(playerZones[player] or {}) do
		table.insert(result, zoneId)
	end
	return result
end

function ZoneService.Start()
	local map = waitForChild(workspace, "Map", CHILD_TIMEOUT)
	if not map then
		warn(
			"[ZoneService] Workspace/Map не найден — зоны будут созданы после появления папки Map"
		)
		return
	end

	local zonesFolder = waitForChild(map, "Zones", CHILD_TIMEOUT)
	if zonesFolder then
		for _, child in ipairs(zonesFolder:GetChildren()) do
			local zoneId = getZoneId(child, "")
			local zoneDef = Landmarks.GetZone(zoneId)
			if not zoneDef then
				warn(
					("[ZoneService] Зона %s отсутствует в Landmarks.lua — добавьте запись"):format(
						zoneId
					)
				)
			end

			local entry = createZone(child, "Medium", zoneDef and zoneDef.LandmarkId or nil)
			if entry then
				zoneEntries[entry.Id] = entry
			end
		end
	else
		warn("[ZoneService] Workspace/Map/Zones не найдена")
	end

	local photoSpots = waitForChild(workspace, "PhotoSpots", CHILD_TIMEOUT)
	if photoSpots then
		for _, child in ipairs(photoSpots:GetChildren()) do
			local landmarkId = child:GetAttribute("LandmarkId")
			if type(landmarkId) ~= "string" or not Landmarks.Get(landmarkId) then
				warn(
					("[ZoneService] PhotoSpot %s: некорректный атрибут LandmarkId"):format(
						child.Name
					)
				)
				continue
			end

			local entry = createZone(child, "High", landmarkId)
			if entry then
				photoSpotZones[landmarkId] = entry.Zone
				mainTrove:Connect(entry.Zone.playerEntered, function(player: Player)
					ZoneService.PhotoSpotEntered:Fire(player, landmarkId)
				end)
				mainTrove:Connect(entry.Zone.playerExited, function(player: Player)
					ZoneService.PhotoSpotExited:Fire(player, landmarkId)
				end)
			end
		end
	else
		warn("[ZoneService] Workspace/PhotoSpots не найдена")
	end

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		local trove = playerTroves[player]
		if trove then
			trove:Destroy()
			playerTroves[player] = nil
		end
	end)
end

--[[ Ближайшая непосещённая достопримечательность — для индикатора направления
	в онбординге (п.5.5). nil, если игрок обошёл всё. ]]
function ZoneService.GetNextUnvisitedLandmark(player: Player): string?
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end

	local visited = {}
	for _, id in ipairs(data.VisitedLandmarks or {}) do
		visited[id] = true
	end

	for _, landmark in ipairs(Landmarks.List()) do
		if not visited[landmark.Id] then
			return landmark.Id
		end
	end

	return nil
end

return ZoneService
