--!strict
--[[
	DeveloperProducts.lua — реестр расходуемых товаров (п.14.2 ТЗ).

	ID = 0 — заглушка: замените на реальные id после создания Developer Products.
	Обработка покупок — ServerScriptService/Monetization/ProductHandler.lua
	(идемпотентность обязательна: Roblox может доставить receipt повторно).
]]

export type ProductDef = {
	Key: string,
	Id: number,
	DisplayName: string,
	Description: string,
	RobuxPrice: number?,
	Grant: string, -- тип выдачи: "FastTravel" | "Filter" | "FilterPack"
	Payload: any?,
}

-- Фильтры фото-режима (разблокируются в PlayerData.UnlockedFilters)
local FILTERS = {
	Mono = {
		Id = "Mono",
		DisplayName = "Ч/Б",
		Saturation = -1,
		Contrast = 0.15,
		Brightness = 0,
		TintColor = Color3.fromRGB(255, 255, 255),
	},
	Sepia = {
		Id = "Sepia",
		DisplayName = "Сепия",
		Saturation = -0.4,
		Contrast = 0.05,
		Brightness = 0.02,
		TintColor = Color3.fromRGB(255, 230, 190),
	},
	BelayaNoch = {
		Id = "BelayaNoch",
		DisplayName = "Белая ночь",
		Saturation = -0.15,
		Contrast = 0.05,
		Brightness = 0.03,
		TintColor = Color3.fromRGB(210, 225, 255),
	},
	Neva = {
		Id = "Neva",
		DisplayName = "Нева",
		Saturation = 0.05,
		Contrast = 0.1,
		Brightness = 0,
		TintColor = Color3.fromRGB(215, 235, 245),
	},
}

local Products: { [string]: ProductDef } = {
	FastTravel = {
		Key = "FastTravel",
		Id = 0,
		DisplayName = "Быстрое перемещение",
		Description = "Мгновенный телепорт к выбранной достопримечательности.",
		RobuxPrice = 15,
		Grant = "FastTravel",
	},

	PhotoFilterPack = {
		Key = "PhotoFilterPack",
		Id = 0,
		DisplayName = "Набор фильтров",
		Description = "Все фильтры фото-режима сразу, дешевле, чем по одному.",
		RobuxPrice = 60,
		Grant = "FilterPack",
	},

	FilterMono = {
		Key = "FilterMono",
		Id = 0,
		DisplayName = "Фильтр «Ч/Б»",
		Description = "Чёрно-белый фильтр для Photo Spot.",
		RobuxPrice = 20,
		Grant = "Filter",
		Payload = "Mono",
	},

	FilterSepia = {
		Key = "FilterSepia",
		Id = 0,
		DisplayName = "Фильтр «Сепия»",
		Description = "Тёплый ретро-фильтр для Photo Spot.",
		RobuxPrice = 20,
		Grant = "Filter",
		Payload = "Sepia",
	},

	FilterBelayaNoch = {
		Key = "FilterBelayaNoch",
		Id = 0,
		DisplayName = "Фильтр «Белая ночь»",
		Description = "Холодный ночной фильтр для Photo Spot.",
		RobuxPrice = 25,
		Grant = "Filter",
		Payload = "BelayaNoch",
	},
}

local DeveloperProducts = {
	Products = Products,
	Filters = FILTERS,
	Order = { "FastTravel", "FilterMono", "FilterSepia", "FilterBelayaNoch", "PhotoFilterPack" },
}

function DeveloperProducts.Get(key: string): ProductDef?
	return Products[key]
end

function DeveloperProducts.GetFilter(id: string)
	return FILTERS[id]
end

function DeveloperProducts.FindByProductId(productId: number): ProductDef?
	for _, product in pairs(Products) do
		if product.Id == productId and product.Id ~= 0 then
			return product
		end
	end
	return nil
end

-- Список фильтров, которые разблокирует «набор фильтров»
function DeveloperProducts.PackFilters(): { string }
	return { "Mono", "Sepia", "BelayaNoch", "Neva" }
end

function DeveloperProducts.List(): { ProductDef }
	local list: { ProductDef } = {}
	for _, key in ipairs(DeveloperProducts.Order) do
		local product = Products[key]
		if product then
			table.insert(list, product)
		end
	end
	return list
end

return DeveloperProducts
