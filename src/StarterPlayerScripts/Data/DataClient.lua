--!strict
--[[
	DataClient.lua — клиентский кэш профиля.

	Сервер присылает снимок профиля (ProfileUpdated) после загрузки и после
	каждого значимого изменения. UI подписывается на ProfileChanged и
	перерисовывается без лишних запросов.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local DataClient = {}

export type ProfileSnapshot = {
	VisitedLandmarks: { string },
	PhotoCount: number,
	OwnedPasses: { [string]: boolean },
	UnlockedFilters: { string },
	Settings: { [string]: any },
}

DataClient.ProfileChanged = Signal.new()

local profile: ProfileSnapshot? = nil
local receivedAtLeastOnce = false

function DataClient.GetProfile(): ProfileSnapshot?
	return profile
end

function DataClient.WaitForProfile(timeout: number?): ProfileSnapshot?
	local waited = 0
	local limit = timeout or 30
	while not profile and waited < limit do
		task.wait(0.1)
		waited += 0.1
	end
	return profile
end

function DataClient.IsReady(): boolean
	return receivedAtLeastOnce
end

function DataClient.GetSetting(key: string, fallback: any): any
	if not profile or type(profile.Settings) ~= "table" then
		return fallback
	end
	local value = profile.Settings[key]
	if value == nil then
		return fallback
	end
	return value
end

function DataClient.OwnsPass(passKey: string): boolean
	if not profile or type(profile.OwnedPasses) ~= "table" then
		return false
	end
	return profile.OwnedPasses[passKey] == true
end

function DataClient.HasVisited(landmarkId: string): boolean
	if not profile then
		return false
	end
	for _, id in ipairs(profile.VisitedLandmarks or {}) do
		if id == landmarkId then
			return true
		end
	end
	return false
end

function DataClient.HasFilter(filterId: string): boolean
	if not profile then
		return false
	end
	for _, id in ipairs(profile.UnlockedFilters or {}) do
		if id == filterId then
			return true
		end
	end
	return false
end

function DataClient.Start()
	Remotes.OnClientEvent(Remotes.Names.ProfileUpdated, function(snapshot: ProfileSnapshot)
		profile = snapshot
		receivedAtLeastOnce = true
		DataClient.ProfileChanged:Fire(snapshot)
	end)
end

return DataClient
