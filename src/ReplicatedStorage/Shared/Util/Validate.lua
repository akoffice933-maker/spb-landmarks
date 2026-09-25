--!strict
--[[
	Валидация входных данных.

	Правило проекта (п.10 ТЗ): ЛЮБОЙ RemoteEvent/RemoteFunction валидируется
	на сервере. Клиент может прислать что угодно, поэтому все проверки живут
	в общем модуле и вызываются и на клиенте (для быстрого UX), и на сервере
	(по-настоящему).
]]

local Landmarks = require(script.Parent.Parent.Config.Landmarks)
local LightingPresets = require(script.Parent.Parent.Config.LightingPresets)

local Validate = {}

local MAX_STRING_LENGTH = 200

function Validate.String(value: any, maxLength: number?): boolean
	if type(value) ~= "string" then
		return false
	end
	if #value == 0 or #value > (maxLength or MAX_STRING_LENGTH) then
		return false
	end
	return true
end

function Validate.Number(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.NumberInRange(value: any, min: number, max: number): boolean
	return Validate.Number(value) and (value :: number) >= min and (value :: number) <= max
end

function Validate.IntegerInRange(value: any, min: number, max: number): boolean
	return Validate.NumberInRange(value, min, max) and (value :: number) % 1 == 0
end

function Validate.LandmarkId(value: any): boolean
	return Validate.String(value, 64) and Landmarks.Get(value :: string) ~= nil
end

function Validate.ZoneId(value: any): boolean
	return Validate.String(value, 64) and Landmarks.GetZone(value :: string) ~= nil
end

function Validate.SpawnId(value: any): boolean
	return Validate.String(value, 64) and Landmarks.GetSpawn(value :: string) ~= nil
end

function Validate.LightingMode(value: any): boolean
	return Validate.String(value, 32) and LightingPresets.Modes[value :: string] ~= nil
end

function Validate.Hour(value: any): boolean
	return Validate.NumberInRange(value, 0, 24)
end

function Validate.Volume(value: any): boolean
	return Validate.NumberInRange(value, 0, 1)
end

function Validate.SettingKey(value: any): boolean
	return Validate.String(value, 64) and Landmarks.SETTINGS[value :: string] ~= nil
end

function Validate.SettingValue(key: string, value: any): boolean
	local setting = Landmarks.SETTINGS[key]
	if not setting then
		return false
	end
	if setting.Type == "number" then
		return Validate.NumberInRange(value, setting.Min, setting.Max)
	elseif setting.Type == "boolean" then
		return type(value) == "boolean"
	elseif setting.Type == "string" then
		return Validate.String(value, setting.MaxLength or MAX_STRING_LENGTH)
	end
	return false
end

function Validate.PurchaseKind(value: any): boolean
	return value == "GamePass" or value == "Product"
end

return Validate
