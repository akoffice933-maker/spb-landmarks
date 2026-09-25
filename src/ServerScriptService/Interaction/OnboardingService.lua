--!strict
--[[
	OnboardingService.lua — серверная часть онбординга (п.5.5).

	Клиент сам решает, показывать ли туториал (по Settings.OnboardingCompleted),
	поэтому на сервере нужна только валидация события завершения и запись флага.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

local OnboardingService = {}

function OnboardingService.Start()
	Remotes.OnServerEvent(Remotes.Names.OnboardingCompleted, function(player: Player)
		PlayerDataService.SetSetting(player, "OnboardingCompleted", true)
	end)
end

return OnboardingService
