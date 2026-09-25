--!strict
--[[
	ClientMain.client.lua — точка входа клиента.

	Порядок:
	  1. DataClient — начинает слушать ProfileUpdated раньше всех.
	  2. UI-модули — строят интерфейс лениво (при первом открытии).
	  3. TopbarUI — иконки в панели (TopbarPlus).
	  4. Контроллеры зон / фото / затемнений.
	  5. Онбординг — авто-показ для новичков (п.5.5).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local StarterPlayerScripts = Players.LocalPlayer.PlayerScripts

-- №1 — данные (кэш профиля)
local DataClient = require(StarterPlayerScripts:WaitForChild("Data").DataClient)
-- UI-модули
local UIInstances = require(StarterPlayerScripts:WaitForChild("UI").UIInstances)
local HUDUI = require(StarterPlayerScripts:WaitForChild("UI").HUDUI)
local ShopUI = require(StarterPlayerScripts:WaitForChild("UI").ShopUI)
local CollectionUI = require(StarterPlayerScripts:WaitForChild("UI").CollectionUI)
local InfoBoardUI = require(StarterPlayerScripts:WaitForChild("UI").InfoBoardUI)
local SettingsUI = require(StarterPlayerScripts:WaitForChild("UI").SettingsUI)
local SpawnChoiceUI = require(StarterPlayerScripts:WaitForChild("UI").SpawnChoiceUI)
local TeleportFade = require(StarterPlayerScripts:WaitForChild("UI").TeleportFade)
local OnboardingUI = require(StarterPlayerScripts:WaitForChild("UI").OnboardingUI)
local TopbarUI = require(StarterPlayerScripts:WaitForChild("UI").TopbarUI)

-- Контроллеры
local ZoneClient = require(StarterPlayerScripts:WaitForChild("Zones").ZoneClient)
local PhotoModeClient = require(StarterPlayerScripts:WaitForChild("PhotoSpot").PhotoModeClient)

DataClient.Start()

-- Тосты: приходят с сервера по всему проекту
Remotes.OnClientEvent(Remotes.Names.Notify, function(payload: any)
	if type(payload) ~= "table" or type(payload.Text) ~= "string" then
		return
	end
	UIInstances.Notify({ Text = payload.Text, Kind = payload.Kind })
end)

SettingsUI.Start()
ShopUI.Start()
CollectionUI.Start()
InfoBoardUI.Start()
SpawnChoiceUI.Start()
TeleportFade.Start()
OnboardingUI.Start()
HUDUI.Start()
TopbarUI.Start()

ZoneClient.Start()
PhotoModeClient.Start()
