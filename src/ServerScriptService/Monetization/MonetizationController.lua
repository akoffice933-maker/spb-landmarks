--!strict
--[[
	MonetizationController.lua — проверка владения Game Pass и инициирование покупок.

	Принцип из п.14 ТЗ: монетизируется статус и удобство, а не доступ к контенту.
	Никаких попапов при входе — игрок сам открывает магазин в топбаре (TopbarPlus).

	Публичное API:
		MonetizationController.Start()
		MonetizationController.RefreshOwnedPasses(player)
		MonetizationController.OwnsPass(player, passKey) -> boolean
		MonetizationController.HasFeature(player, "ManualLighting" | "ExtendedInfo" | ...) -> boolean
		(строки-фичи заданы в GamePasses.lua: VipPhotoFrame, ExtendedInfo,
		InteriorAccess, ManualLighting, EraSkins)
		MonetizationController.PromptGamePass(player, passKey)
		MonetizationController.PromptProduct(player, productKey)
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local GamePasses = require(Shared.Config.GamePasses)
local DeveloperProducts = require(Shared.Config.DeveloperProducts)
local Validate = require(Shared.Util.Validate)

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

local PROMPT_COOLDOWN = 2 -- защита от спама нажатиями

local MonetizationController = {}

local lastPromptAt: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.FireClient(Remotes.Names.Notify, player, {
		Text = text,
		Kind = kind or "info",
	})
end

function MonetizationController.RefreshOwnedPasses(player: Player)
	local owned: { [string]: boolean } = {}

	for key, pass in pairs(GamePasses.Passes) do
		if pass.Id ~= 0 then
			local success, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)

			if success then
				owned[key] = result == true
			else
				-- Ошибка запроса: НЕ записываем false, чтобы не «отобрать» пасс
				-- из-за временного сбоя. Кэш обновится при следующем входе.
				warn(("[Monetization] UserOwnsGamePassAsync не удался (%s): %s"):format(key, tostring(result)))
			end
		else
			owned[key] = false
		end
	end

	PlayerDataService.CacheOwnedPasses(player, owned)
	return owned
end

function MonetizationController.OwnsPass(player: Player, passKey: string): boolean
	local pass = GamePasses.Get(passKey)
	if not pass then
		return false
	end

	local data = PlayerDataService.GetData(player)
	if not data or type(data.OwnedPasses) ~= "table" then
		return false
	end

	return data.OwnedPasses[passKey] == true
end

function MonetizationController.HasFeature(player: Player, feature: string): boolean
	for _, key in ipairs(GamePasses.KeysForFeature(feature)) do
		if MonetizationController.OwnsPass(player, key) then
			return true
		end
	end
	return false
end

local function canPrompt(player: Player): boolean
	local now = os.clock()
	if (lastPromptAt[player] or 0) + PROMPT_COOLDOWN > now then
		return false
	end
	lastPromptAt[player] = now
	return true
end

function MonetizationController.PromptGamePass(player: Player, passKey: string): boolean
	local pass = GamePasses.Get(passKey)
	if not pass or pass.Id == 0 then
		return false
	end
	if not canPrompt(player) then
		return false
	end

	-- Уже куплен — не показываем окно повторной покупки
	if MonetizationController.OwnsPass(player, passKey) then
		notify(player, "Этот пропуск уже есть в вашей коллекции", "info")
		return false
	end

	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	return true
end

function MonetizationController.PromptProduct(player: Player, productKey: string): boolean
	local product = DeveloperProducts.Get(productKey)
	if not product or product.Id == 0 then
		return false
	end
	if not canPrompt(player) then
		return false
	end

	MarketplaceService:PromptProductPurchase(player, product.Id)
	return true
end

--=== Обработка запросов от клиента ===============================================

local function onRequestPurchase(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end

	local kind = payload.Kind
	local key = payload.Key

	if not Validate.PurchaseKind(kind) or not Validate.String(key, 64) then
		warn(("[Monetization] Некорректный запрос покупки от %s"):format(player.Name))
		return
	end

	if kind == "GamePass" then
		MonetizationController.PromptGamePass(player, key :: string)
	else
		MonetizationController.PromptProduct(player, key :: string)
	end
end

function MonetizationController.Start()
	-- Кэш владения формируется один раз за сессию (п.5.2 ТЗ)
	local function onProfileReady(player: Player)
		task.spawn(function()
			MonetizationController.RefreshOwnedPasses(player)
		end)
	end

	PlayerDataService.ProfileReady:Connect(onProfileReady)

	-- На случай, если профиль уже загружен к моменту старта контроллера
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerDataService.GetData(player) then
			onProfileReady(player)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, gamePassId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end

			MonetizationController.RefreshOwnedPasses(player)

			for key, pass in pairs(GamePasses.Passes) do
				if pass.Id == gamePassId then
					notify(player, ("Покупка выполнена: %s"):format(pass.DisplayName), "success")
					Remotes.FireClient(Remotes.Names.PurchaseFinished, player, {
						Kind = "GamePass",
						Key = key,
						Success = true,
					})
					break
				end
			end
		end
	)

	Players.PlayerRemoving:Connect(function(player)
		lastPromptAt[player] = nil
	end)
end

Remotes.OnServerEvent(Remotes.Names.RequestPurchase, onRequestPurchase)

-- Настройки уровня Game Pass (п.14.1): значение пишется через общий
-- UpdateSettings, но включать может только владелец пасса (п.16).
PlayerDataService.RegisterSettingValidator("EraEffectsOn", function(player: Player, value: any): boolean
	if value == true then
		return MonetizationController.HasFeature(player, "EraSkins")
	end
	return true
end)

return MonetizationController
