--!strict
--[[
	verify_place.luau — «холодная» проверка собранного места без Studio.

	Запуск:  lune run tools/verify_place.luau [путь/к/SPB-Landmarks.rbxl]
	Выход:   0 = все проверки зелёные; 1 = есть ошибки.

	Проверки:
	  1. .rbxl читается корректно roblox-API lune (не битый xml/binary).
	  2. Все ключевые сервисы/скрипты на местах (Main, Bootstrap, Quests,
	     Avatar, Photo, UI, TopbarPlus-пакеты и т.д.).
	  3. Каждый скрипт модуль/глобал/клиент успешно СКОМПИЛИРОВАН luau
	     (синтаксис не сломан где-то посреди — страховка над integrity).
	  4. Инвентарные счётчики: сколько скриптов, серверных директорий — чтобы
	     отказы от регистрации каталога не прошли незаметно.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")

local path = process.args[1] or "SPB-Landmarks.rbxl"

local errors: { string } = {}
local warnings: { string } = {}

local function err(msg: string)
	table.insert(errors, msg)
end
local function warnx(msg: string)
	table.insert(warnings, msg)
end

--=== 1. Чтение места ============================================================

if not fs.isFile(path) then
	err(("Файл места не найден: %s"):format(path))
	print(table.concat(errors, "\n"))
	process.exit(1)
end

local ok, game = pcall(function()
	return roblox.deserializePlace(fs.readFile(path))
end)
if not ok then
	err((".rbxl не прочитался roblox.readPlaceFile: %s"):format(tostring(game)))
	print(table.concat(errors, "\n"))
	process.exit(1)
end

--=== 2. Требуемые скрипты/каталоги ==============================================

local REQUIRED_GLOBAL_SCRIPTS = {
	"BootstrapProject",
	"BootstrapArtPass",
	"Main",
}

local REQUIRED_SERVER_MODULES = {
	"Data/PlayerDataService",
	"Data/ProfileTemplate",
	"Zones/ZoneService",
	"Lighting/LightingController",
	"Monetization/MonetizationController",
	"Monetization/ProductHandler",
	"Monetization/VipBadgeService",
	"Interaction/InfoService",
	"Interaction/InteriorService",
	"Interaction/OnboardingService",
	"Interaction/PhotoSpotService",
	"Spawn/SpawnService",
	"Character/AvatarStudioService",
	"Quests/ShadowHunterService",
}

local REQUIRED_SHARED = {
	"Shared/Remotes",
	"Shared/Config/GamePasses",
	"Shared/Config/DeveloperProducts",
	"Shared/Config/Landmarks",
	"Shared/Config/LightingPresets",
	"Shared/Config/AvatarPresets",
	"Shared/Util/Signal",
	"Shared/Util/Validate",
}

local REQUIRED_CLIENT = {
	"ClientMain",
	"Data/DataClient",
	"UI/UIInstances",
	"UI/HUDUI",
	"UI/ShopUI",
	"UI/CollectionUI",
	"UI/InfoBoardUI",
	"UI/SettingsUI",
	"UI/SettingsClient",
	"UI/SpawnChoiceUI",
	"UI/TeleportFade",
	"UI/OnboardingUI",
	"UI/EraUI",
	"UI/AvatarStudioUI",
	"UI/TopbarUI",
	"Zones/ZoneClient",
	"PhotoSpot/PhotoModeClient",
	"Quests/ShadowHunterClient",
	"Audio/UISoundClient",
}

local function findByPath(root: Instance, dotted: string): Instance?
	local current: Instance? = root
	for part in string.gmatch(dotted, "[^/]+") do
		if not current then
			return nil
		end
		current = (current :: Instance):FindFirstChild(part)
	end
	return current
end

local sss = (game :: Instance):GetService("ServerScriptService") :: Instance
for _, name in REQUIRED_GLOBAL_SCRIPTS do
	if not sss:FindFirstChild(name) then
		err(("ServerScriptService/%s не найден"):format(name))
	end
end
for _, pathIn in REQUIRED_SERVER_MODULES do
	if not findByPath(sss, pathIn) then
		err(("ServerScriptService/%s не найден"):format(pathIn))
	end
end

local rs = (game :: Instance):GetService("ReplicatedStorage") :: Instance
for _, pathIn in REQUIRED_SHARED do
	if not findByPath(rs, pathIn) then
		err(("ReplicatedStorage/%s не найден"):format(pathIn))
	end
end

local starterPlayer = (game :: Instance):FindFirstChild("StarterPlayer") :: Instance
if not starterPlayer then
	err("StarterPlayer не найден в месте")
	starterPlayer = game :: any
end
local sps = (starterPlayer :: Instance):FindFirstChild("StarterPlayerScripts") :: Instance
if not sps then
	err("StarterPlayer/StarterPlayerScripts не найден")
	sps = starterPlayer
end
for _, pathIn in REQUIRED_CLIENT do
	if not findByPath(sps, pathIn) then
		err(("StarterPlayerScripts/%s не найден"):format(pathIn))
	end
end

-- Packages: wally/вендорные зависимости по факту проекта
local rsPackages = rs:FindFirstChild("Packages")
if not rsPackages then
	err("ReplicatedStorage/Packages не найден (зависимости не установлены)")
else
	for _, pkg in { "TopbarPlus", "Zone", "Trove", "Promise" } do
		if not (rsPackages :: Instance):FindFirstChild(pkg) then
			err(("ReplicatedStorage.Packages/%s не найден"):format(pkg))
		end
	end
end
local sssPackages = (sss :: Instance):FindFirstChild("Packages")
if not sssPackages or not (sssPackages :: Instance):FindFirstChild("ProfileStore") then
	err("ServerScriptService.Packages/ProfileStore не найден")
end

--=== 3. Компиляция всех скриптов места ==========================================

local scriptCount = 0
local folderCount = 0
local failedCompile: { string } = {}

local function walk(inst: Instance)
	if inst:IsA("LuaSourceContainer") then
		scriptCount += 1
		local source = (inst :: any).Source
		if type(source) == "string" and #source > 0 then
			local codeOk, bytecode = pcall(function()
				return luau.compile(source)
			end)
			if not (codeOk and type(bytecode) == "string" and #bytecode > 0) then
				local fullName = (inst :: Instance):GetFullName()
				table.insert(failedCompile, fullName)
			end
		end
	elseif inst:IsA("Folder") or inst:IsA("Model") then
		folderCount += 1
	end
	for _, child in inst:GetChildren() do
		walk(child)
	end
end

walk(game)

if #failedCompile > 0 then
	for _, name in failedCompile do
		err(("Скрипт не компилируется: %s"):format(name))
	end
end

print(("Скриптов собрано: %d; каталогов: %d"):format(scriptCount, folderCount))
print(("Компиляций с ошибкой: %d"):format(#failedCompile))

--=== 4. Итог ====================================================================

if #warnings > 0 then
	print("ПРЕДУПРЕЖДЕНИЯ:")
	for _, msg in warnings do
		print("  - " .. msg)
	end
end
if #errors > 0 then
	print("ОШИБКИ:")
	for _, msg in errors do
		print("  - " .. msg)
	end
	print("ИТОГ: есть ошибки ✗")
	process.exit(1)
else
	print("ИТОГ: место готово к публикации ✓")
	process.exit(0)
end
