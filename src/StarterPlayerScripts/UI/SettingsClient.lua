--!strict
--[[
	SettingsClient.lua — отправка настроек на сервер с дебаунсом.

	Сервер валидирует каждое изменение (п.16 ТЗ), значения кладутся в
	PlayerData.Settings (MusicVolume / AmbientVolume / OnboardingCompleted).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DEBOUNCE_SECONDS = 0.6

local SettingsClient = {}

local pending: { [string]: any } = {}
local scheduled = false

local function flush()
	if not next(pending) then
		return
	end

	local payload = pending
	pending = {}

	for key, value in pairs(payload) do
		if type(value) == "boolean" then
			Remotes.FireServer(Remotes.Names.UpdateSettings, { Key = key, Value = value })
		elseif type(value) == "number" then
			Remotes.FireServer(Remotes.Names.UpdateSettings, { Key = key, Value = math.clamp(value, 0, 1) })
		end
	end
end

local function scheduleFlush()
	if scheduled then
		return
	end
	scheduled = true

	task.delay(DEBOUNCE_SECONDS, function()
		scheduled = false
		flush()
	end)
end

function SettingsClient.Set(key: string, value: any)
	pending[key] = value
	scheduleFlush()
end

function SettingsClient.FlushNow()
	flush()
end

return SettingsClient
