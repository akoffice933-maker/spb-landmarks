--!strict
--[[
	ProfileTemplate.lua — схема профиля игрока (п.5.2 ТЗ).

	Все поля v1.1+ / v2.0 зарезервированы заранее, чтобы при росте функционала
	не пришлось делать breaking-миграции: ProfileStore:Reconcile() аккуратно
	дописывает отсутствующие ключи уже существующим игрокам.

	Housing = nil записано для наглядности: в Lua это то же самое, что отсутствие
	ключа, но ключ-documented для v2.0 (аренда/покупка жилья).
]]

local ProfileTemplate = {
	-- === v1.0: активно используется ===
	VisitedLandmarks = {}, -- { "Hermitage", "Isaakiy", ... } — основа коллекций v1.1
	PhotoCount = 0,
	OwnedPasses = {}, -- кэш владения Game Pass, обновляется при входе игрока
	UnlockedFilters = {}, -- id купленных фото-фильтров
	ShadowCaptures = 0, -- квест «Охотник за тенями»: сколько Теней схвачено камерой
	Settings = {
		MusicVolume = 0.7,
		AmbientVolume = 1,
		UIVolume = 0.8,
		EraEffectsOn = false,
		WardrobeOutfit = "None",
		OnboardingCompleted = false,
	},

	-- === Техническое поле (добавлено в v1.0) ===
	-- Идемпотентность ProcessReceipt (п.7.4 ТЗ): Roblox может доставить
	-- один и тот же receipt повторно, в том числе на другой сервер.
	PurchaseLog = {}, -- { { Id = "receiptId", Time = 1700000000, ProductId = 0 }, ... }

	-- === Зарезервировано под v1.1+ / v2.0, в v1.0 не используется ===
	Money = 0,
	Inventory = {},
	Housing = nil,
}

return ProfileTemplate
