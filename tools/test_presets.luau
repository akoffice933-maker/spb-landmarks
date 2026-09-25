-- Логический тест математики гардероба/квест-наград (модули чистые).
-- Lune require запрещает "../" — грузим исходник через luau.load.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local source = fs.readFile("src/ReplicatedStorage/Shared/Config/AvatarPresets.lua")
-- В lune глобальных Roblox-типов нет: накрываем CFrame/Color3/Vector3
-- локальным шимом перед текстом модуля (в самой игре они реальные).
local shim = [[
local __rbx = require("@lune/roblox")
local Color3 = __rbx.Color3
local CFrame = __rbx.CFrame
local Vector3 = __rbx.Vector3
]]
local chunk = luau.load(shim .. source, { debugName = "AvatarPresets" })
local AvatarPresets = chunk()

local failed = 0
local function check(cond: boolean, msg: string)
	if cond then
		print("  ✓ " .. msg)
	else
		print("  ✗ " .. msg)
		failed += 1
	end
end

print("AvatarPresets — инварианты гардероба")
check(#AvatarPresets.Outfits >= 5, ("нарядов >= 5 (факт: %d)"):format(#AvatarPresets.Outfits))

for _, o in AvatarPresets.Outfits do
	check(o.Head ~= nil and o.Torso ~= nil, ("«%s»: цвета заданы"):format(o.Id))
	check(AvatarPresets.GetOutfitById(o.Id) == o, ("«%s»: GetOutfitById стабилен"):format(o.Id))
end

local nocturne = AvatarPresets.GetOutfitById("Nocturne")
check(nocturne ~= nil, "«Ноктюрн» есть")
check(nocturne ~= nil and nocturne.RequiresQuest ~= nil, "«Ноктюрн» имеет RequiresQuest")
if nocturne and nocturne.RequiresQuest then
	check(nocturne.RequiresQuest.Kind == "ShadowCaptures", "  kind = ShadowCaptures")
	check(nocturne.RequiresQuest.Count == 3, "  порог = 3 снимка")
end

local named = {}
for _, p in AvatarPresets.Poses do
	named[p.Id] = true
	check(type(p.Offsets) == "table" and next(p.Offsets) ~= nil, ("поза «%s»: Offsets не пусты"):format(p.Id))
end
check(named.Salute and named.Heart and named.Lean and named.Wave, "четыре позы полной орбиты")

-- Порог авторизации
local function authorized(count: number): boolean
	return count >= (nocturne :: any).RequiresQuest.Count
end
check(not authorized(2) and authorized(3) and authorized(5), "порог 2→3 проходит верно")

if failed > 0 then
	print(("✗ провалено %d проверок"):format(failed))
	process.exit(1)
else
	print("✓ логика гардероба/наград вся зелёная")
end
