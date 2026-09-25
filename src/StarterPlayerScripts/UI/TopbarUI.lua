--!strict
--[[
	TopbarUI.lua — иконки в верхней панели через TopbarPlus (п.17.3 ТЗ).

	Правило ТЗ (п.14.3): никаких попапов монетизации — магазин открывается
	только по иконке в топбаре. Здесь же коллекция, настройки и помощь.

	Ассеты-иконки ниже — заглушки (стандартный набор Lucide). Замените их
	на собственные, когда будет готов графический материал.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TopbarPlus = require(ReplicatedStorage.Packages.TopbarPlus)

local ShopUI = require(script.Parent.ShopUI)
local CollectionUI = require(script.Parent.CollectionUI)
local SettingsUI = require(script.Parent.SettingsUI)
local OnboardingUI = require(script.Parent.OnboardingUI)

local ICONS = {
	Shop = "rbxassetid://10709791437",
	Collection = "rbxassetid://1070976152",
	Settings = "rbxassetid://10709750322",
	Help = "rbxassetid://10723346233",
}

local TopbarUI = {}

local icons: { [string]: any } = {}

--[[ Синхронизация иконка <-> панель. Флаг нужен от рекурсии:
	закрытие панели дергает icon:deselect(), который снова вёл бы в ui.Close(). ]]
local function bindPanelIcon(key: string, order: number, image: string, label: string, ui: any)
	local icon = TopbarPlus.new()
	icon:setImage(image)
	icon:setLabel(label)
	icon:setOrder(order)
	icons[key] = icon

	local syncing = false

	local function openPanel()
		if syncing then
			return
		end
		syncing = true
		ui.Open()
		syncing = false
	end

	local function closePanel()
		if syncing then
			return
		end
		syncing = true
		ui.Close()
		icon:deselect()
		syncing = false
	end

	icon.selected:Connect(openPanel)
	icon.deselected:Connect(closePanel)

	local originalClose = ui.Close
	ui.Close = function(...)
		if syncing then
			return
		end
		syncing = true
		originalClose(...)
		icon:deselect()
		syncing = false
	end
end

local function bindActionIcon(key: string, order: number, image: string, label: string, onActivated: () -> ())
	local icon = TopbarPlus.new()
	icon:setImage(image)
	icon:setLabel(label)
	icon:setOrder(order)
	icons[key] = icon

	icon.selected:Connect(function()
		onActivated()
		-- «Кнопка», а не «панель»: сразу снимаем выделение
		task.defer(function()
			icon:deselect()
		end)
	end)
end

function TopbarUI.Start()
	bindPanelIcon("Shop", 10, ICONS.Shop, "Магазин", ShopUI)
	bindPanelIcon("Collection", 11, ICONS.Collection, "Коллекция", CollectionUI)
	bindPanelIcon("Settings", 12, ICONS.Settings, "Настройки", SettingsUI)

	bindActionIcon("Help", 13, ICONS.Help, "Помощь", function()
		OnboardingUI.Show()
	end)
end

function TopbarUI.GetIcon(key: string)
	return icons[key]
end

return TopbarUI
