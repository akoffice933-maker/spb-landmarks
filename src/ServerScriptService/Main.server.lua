--!strict
--[[
	Main.server.lua — точка входа сервера.

	Порядок запуска важен:
	  1. PlayerDataService — ProfileStore сессии стартуют первыми.
	  2. Monetization — кэш пассов подписывается на ProfileReady.
	  3. ProductHandler — регистрирует ProcessReceipt (единственный на опыт).
	  4. Зоны / взаимодействие / спавны / онбординг.
	  5. LightingController — в самом конце, чтобы фонари уже отреагировали.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Data = ServerScriptService:WaitForChild("Data")
local Monetization = ServerScriptService:WaitForChild("Monetization")
local Zones = ServerScriptService:WaitForChild("Zones")
local Lighting = ServerScriptService:WaitForChild("Lighting")
local Interaction = ServerScriptService:WaitForChild("Interaction")
local Spawn = ServerScriptService:WaitForChild("Spawn")
local Character = ServerScriptService:WaitForChild("Character")

local PlayerDataService = require(Data.PlayerDataService)
local MonetizationController = require(Monetization.MonetizationController)
local ProductHandler = require(Monetization.ProductHandler)
local VipBadgeService = require(Monetization.VipBadgeService)
local ZoneService = require(Zones.ZoneService)
local LightingController = require(Lighting.LightingController)
local InfoService = require(Interaction.InfoService)
local PhotoSpotService = require(Interaction.PhotoSpotService)
local InteriorService = require(Interaction.InteriorService)
local OnboardingService = require(Interaction.OnboardingService)
local SpawnService = require(Spawn.SpawnService)
local AvatarStudioService = require(Character.AvatarStudioService)

PlayerDataService.Start()
MonetizationController.Start()
ProductHandler.Start()
VipBadgeService.Start()

-- ProcessReceipt должен быть назначен как можно раньше
task.spawn(ZoneService.Start)
PhotoSpotService.Start()
InfoService.Start()
InteriorService.Start()
OnboardingService.Start()
SpawnService.Start()
AvatarStudioService.Start()
LightingController.Start()

print("[SPB Landmarks] Сервер запущен")
