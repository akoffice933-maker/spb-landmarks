--!strict
--[[
	GamePasses.lua — реестр Game Pass (п.14.1 ТЗ).

	ID = 0 — заглушка. После публикации пассов в опыте замените их на реальные
	числовые идентификаторы (Create -> Monetization -> Game Passes -> Copy ID).

	Поле Feature описывает, ЧТО именно даёт пасс в коде; проверки проходят
	через MonetizationController:HasFeature(player, "Chronos") и т.д.
]]

export type GamePassDef = {
	Key: string,
	Id: number,
	DisplayName: string,
	Description: string,
	Feature: string,
	EnabledAtRelease: boolean,
}

local GamePasses: { [string]: GamePassDef } = {
	VIPPhotographer = {
		Key = "VIPPhotographer",
		Id = 0,
		DisplayName = "VIP-фотограф",
		Description = "Золотая рамка в Photo Spot и значок над головой в городе.",
		Feature = "VipPhotoFrame",
		EnabledAtRelease = true,
	},

	GuideExplorer = {
		Key = "GuideExplorer",
		Id = 0,
		DisplayName = "Гид-исследователь",
		Description = "Расширенные тексты инфо-табличек: дополнительные факты и история локаций.",
		Feature = "ExtendedInfo",
		EnabledAtRelease = true,
	},

	InteriorPass = {
		Key = "InteriorPass",
		Id = 0,
		DisplayName = "Интерьерный пропуск",
		Description = "Доступ в закрытые помещения сверх бесплатного интерьера (п.14.1).",
		Feature = "InteriorAccess",
		EnabledAtRelease = false,
	},

	Chronos = {
		Key = "Chronos",
		Id = 0,
		DisplayName = "Хронос",
		Description = "Ручное переключение день / закат / белые ночи / ночь.",
		Feature = "ManualLighting",
		EnabledAtRelease = false,
	},

	EraSkins = {
		Key = "EraSkins",
		Id = 0,
		DisplayName = "Костюмы эпохи",
		Description = "Костюмы эпохи Петра I и эффекты «белых ночей».",
		Feature = "EraSkins",
		EnabledAtRelease = false,
	},
}

local GamePassesModule = {
	Passes = GamePasses,
	-- Порядок показа в магазине
	Order = { "VIPPhotographer", "GuideExplorer", "InteriorPass", "Chronos", "EraSkins" },
}

function GamePassesModule.Get(key: string): GamePassDef?
	return GamePasses[key]
end

-- Обратное сопоставление Feature -> список ключей пассов
function GamePassesModule.KeysForFeature(feature: string): { string }
	local keys: { string } = {}
	for key, pass in pairs(GamePasses) do
		if pass.Feature == feature then
			table.insert(keys, key)
		end
	end
	return keys
end

function GamePassesModule.List(): { GamePassDef }
	local list: { GamePassDef } = {}
	for _, key in ipairs(GamePassesModule.Order) do
		local pass = GamePasses[key]
		if pass and pass.EnabledAtRelease then
			table.insert(list, pass)
		end
	end
	return list
end

return GamePassesModule
