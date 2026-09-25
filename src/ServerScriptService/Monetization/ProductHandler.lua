--!strict
--[[
	ProductHandler.lua — ProcessReceipt для Developer Products (п.7.4, п.14.2 ТЗ).

	Два обязательных требования:
	  1) ИДЕМПОТЕНТНОСТЬ. Roblox может доставить один и тот же receipt несколько раз
	     и на разные серверы. Проверяем PurchaseLog в профиле (ProfileStore) +
	    立刻 сохраняем профиль после выдачи.
	  2) Никаких блокировок основного потока: обработка внутри ProcessReceipt
	     не должна yield'ить дольше необходимого (п.8 ТЗ).

	Поддерживаемые выдачи (DeveloperProducts.Grant):
	  * "FastTravel"  — открывает окно быстрого перемещения на 2 минуты;
	  * "Filter"      — разблокирует один фильтр (Payload);
	  * "FilterPack"  — разблокирует набор фильтров.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local DeveloperProducts = require(Shared.Config.DeveloperProducts)
local Landmarks = require(Shared.Config.Landmarks)

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

local FAST_TRAVEL_WINDOW_SECONDS = 120

local ProductHandler = {}

-- В очереди «ожидает выбора точки»: ключ — игрок, значение — время истечения
local pendingFastTravel: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.FireClient(Remotes.Names.Notify, player, { Text = text, Kind = kind or "info" })
end

function ProductHandler.HasPendingFastTravel(player: Player): boolean
	local expiresAt = pendingFastTravel[player]
	if not expiresAt then
		return false
	end
	if os.time() > expiresAt then
		pendingFastTravel[player] = nil
		return false
	end
	return true
end

-- Вызывается SpawnService, когда игрок выбрал точку назначения
function ProductHandler.ConsumeFastTravel(player: Player): boolean
	if not ProductHandler.HasPendingFastTravel(player) then
		return false
	end
	pendingFastTravel[player] = nil
	return true
end

local function grantFastTravel(player: Player)
	pendingFastTravel[player] = os.time() + FAST_TRAVEL_WINDOW_SECONDS

	local destinations = {}
	for _, landmark in ipairs(Landmarks.FastTravelList()) do
		table.insert(destinations, { Id = landmark.Id, DisplayName = landmark.DisplayName })
	end

	Remotes.FireClient(Remotes.Names.FastTravelReady, player, { Destinations = destinations })
	notify(player, "Быстрое перемещение доступно: выберите точку", "success")
end

local function grantFilter(player: Player, filterId: string)
	if PlayerDataService.UnlockFilter(player, filterId) then
		local filter = DeveloperProducts.GetFilter(filterId)
		notify(
			player,
			("Фильтр «%s» разблокирован"):format(if filter then filter.DisplayName else filterId),
			"success"
		)
	end
end

local function grantFilterPack(player: Player)
	for _, filterId in ipairs(DeveloperProducts.PackFilters()) do
		PlayerDataService.UnlockFilter(player, filterId)
	end
	notify(player, "Набор фильтров разблокирован", "success")
end

local function grant(player: Player, product: any, receiptInfo: any)
	if product.Grant == "FastTravel" then
		grantFastTravel(player)
	elseif product.Grant == "Filter" then
		grantFilter(player, product.Payload)
	elseif product.Grant == "FilterPack" then
		grantFilterPack(player)
	else
		warn(("[ProductHandler] Неизвестный тип выдачи: %s"):format(tostring(product.Grant)))
	end

	PlayerDataService.LogReceipt(player, receiptInfo.PurchaseId, receiptInfo.ProductId)
	-- Немедленное сохранение: покупка не должна потеряться при краше сервера
	PlayerDataService.SaveNow(player)

	Remotes.FireClient(Remotes.Names.PurchaseFinished, player, {
		Kind = "Product",
		Key = product.Key,
		Success = true,
	})
end

function ProductHandler.Start()
	-- В Roblox может быть только один обработчик ProcessReceipt на опыт.
	MarketplaceService.ProcessReceipt = function(receiptInfo: any)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local data = PlayerDataService.WaitForData(player, 10)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Уже выдавали по этому чеку (повторная доставка Roblox)
		if PlayerDataService.HasProcessedReceipt(player, receiptInfo.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local product = DeveloperProducts.FindByProductId(receiptInfo.ProductId)
		if not product then
			warn(("[ProductHandler] Неизвестный ProductId: %s"):format(tostring(receiptInfo.ProductId)))
			-- Возвращаем PurchaseGranted, чтобы Roblox не зациклил повторную доставку
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local ok, err = pcall(grant, player, product, receiptInfo)
		if not ok then
			warn(("[ProductHandler] Ошибка выдачи (%s): %s"):format(product.Key, tostring(err)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

Players.PlayerRemoving:Connect(function(player)
	pendingFastTravel[player] = nil
end)

return ProductHandler
