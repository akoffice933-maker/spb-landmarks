--!strict
--[[
	PlayerDataService.lua — работа с профилем игрока через ProfileStore.

	Почему ProfileStore, а не «сырой» DataStoreService (п.17.2 ТЗ):
	  * session-locking из коробки (защита от дюпа при быстром переходе между серверами);
	  * автосохранение + Reconcile() для безопасного расширения схемы;
	  * в Studio переключаемся на PlayerStore.Mock, чтобы не затирать живые ключи.

	Публичное API:
		PlayerDataService.Start()
		PlayerDataService.WaitForData(player, timeout) -> table?
		PlayerDataService.GetData(player) -> table?
		PlayerDataService.GetProfile(player) -> Profile?
		PlayerDataService.MarkVisited(player, landmarkId)
		PlayerDataService.IncrementPhotoCount(player)
		PlayerDataService.UnlockFilter(player, filterId)
		PlayerDataService.SetSetting(player, key, value)
		PlayerDataService.HasProcessedReceipt(player, receiptId) -> boolean
		PlayerDataService.LogReceipt(player, receiptId, productId)
		PlayerDataService.CacheOwnedPasses(player, owned: { [string]: boolean })
		PlayerDataService.GetSnapshot(player) -> table
		PlayerDataService.ProfileReady / PlayerDataService.DataChanged (Signal)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local Validate = require(Shared.Util.Validate)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local STORE_NAME = "SPB_PlayerData_v1"
local STUDIO_USES_MOCK_STORE = true
local SNAPSHOT_PUSH_DELAY = 0.4

local PlayerDataService = {}

local store = ProfileStore.New(STORE_NAME, ProfileTemplate)
if STUDIO_USES_MOCK_STORE and RunService:IsStudio() then
	store = store.Mock
end

local profiles: { [Player]: any } = {}
local troves: { [Player]: any } = {}
local pushPending: { [Player]: boolean } = {}

-- Пер-полевые валидаторы настроек (бизнес-правила сверх схемы, п.16).
-- Регистрируются из доменных сервисов (см. MonetizationController), чтобы
-- сам модуль данных не тянул зависимость на монетизацию (защита от циклов).
local settingValidators: { [string]: (player: Player, value: any) -> boolean } = {}

function PlayerDataService.RegisterSettingValidator(key: string, validator: (player: Player, value: any) -> boolean)
	settingValidators[key] = validator
end

PlayerDataService.ProfileReady = Signal.new() -- (player, data)
PlayerDataService.DataChanged = Signal.new() -- (player, key)

local function deepCopy(value: any, seen: { [any]: any }?): any
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local copy = {}
	seen[value] = copy
	for key, item in pairs(value) do
		copy[deepCopy(key, seen)] = deepCopy(item, seen)
	end
	return copy
end

local function getSnapshotFromData(data: any)
	return {
		VisitedLandmarks = deepCopy(data.VisitedLandmarks or {}),
		PhotoCount = data.PhotoCount or 0,
		OwnedPasses = deepCopy(data.OwnedPasses or {}),
		UnlockedFilters = deepCopy(data.UnlockedFilters or {}),
		Settings = deepCopy(data.Settings or {}),
	}
end

function PlayerDataService.GetSnapshot(player: Player)
	local data = profiles[player] and profiles[player].Data
	if not data then
		return nil
	end
	return getSnapshotFromData(data)
end

--[[ Отправка快照 клиенту с троттлингом: за одну секунду игрок может отметить
	несколько локаций, а сеть нагружать незачем. ]]
local function pushSnapshot(player: Player)
	if pushPending[player] then
		return
	end
	pushPending[player] = true

	task.delay(SNAPSHOT_PUSH_DELAY, function()
		pushPending[player] = nil
		if not player:IsDescendantOf(Players) then
			return
		end
		local snapshot = PlayerDataService.GetSnapshot(player)
		if snapshot then
			Remotes.FireClient(Remotes.Names.ProfileUpdated, player, snapshot)
		end
	end)
end

local function ensureList(data: any, key: string)
	if type(data[key]) ~= "table" then
		data[key] = {}
	end
	return data[key]
end

function PlayerDataService.GetProfile(player: Player)
	return profiles[player]
end

function PlayerDataService.GetData(player: Player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return profile.Data
end

function PlayerDataService.WaitForData(player: Player, timeout: number?)
	local profile = profiles[player]
	if profile then
		return profile.Data
	end

	local waited = 0
	local limit = timeout or 30
	while waited < limit do
		task.wait(0.1)
		waited += 0.1
		local found = profiles[player]
		if found then
			return found.Data
		end
		if not player:IsDescendantOf(Players) then
			return nil
		end
	end
	return nil
end

--=== Изменения данных ============================================================

function PlayerDataService.MarkVisited(player: Player, landmarkId: string): boolean
	if not Validate.LandmarkId(landmarkId) then
		return false
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local visited = ensureList(data, "VisitedLandmarks")
	for _, id in ipairs(visited) do
		if id == landmarkId then
			return false -- уже отмечено
		end
	end

	table.insert(visited, landmarkId)
	pushSnapshot(player)
	PlayerDataService.DataChanged:Fire(player, "VisitedLandmarks")
	return true
end

function PlayerDataService.IncrementPhotoCount(player: Player, amount: number?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	data.PhotoCount = (data.PhotoCount or 0) + (amount or 1)
	pushSnapshot(player)
	PlayerDataService.DataChanged:Fire(player, "PhotoCount")
	return true
end

function PlayerDataService.UnlockFilter(player: Player, filterId: string): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local unlocked = ensureList(data, "UnlockedFilters")
	for _, id in ipairs(unlocked) do
		if id == filterId then
			return false
		end
	end

	table.insert(unlocked, filterId)
	pushSnapshot(player)
	PlayerDataService.DataChanged:Fire(player, "UnlockedFilters")
	return true
end

function PlayerDataService.SetSetting(player: Player, key: string, value: any): boolean
	if not Validate.SettingKey(key) or not Validate.SettingValue(key, value) then
		return false
	end

	-- Бизнес-правила (например, настройку уровня пасса схема не проверит):
	local validator = settingValidators[key]
	if validator and not validator(player, value) then
		Remotes.FireClient(Remotes.Names.Notify, player, {
			Text = "Этот параметр доступен владельцам соответствующего Game Pass.",
			Kind = "warning",
		})
		return false
	end

	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	if type(data.Settings) ~= "table" then
		data.Settings = deepCopy(ProfileTemplate.Settings)
	end

	data.Settings[key] = value
	pushSnapshot(player)
	PlayerDataService.DataChanged:Fire(player, "Settings")
	return true
end

function PlayerDataService.CacheOwnedPasses(player: Player, owned: { [string]: boolean })
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	if type(data.OwnedPasses) ~= "table" then
		data.OwnedPasses = {}
	end

	for key, value in pairs(owned) do
		data.OwnedPasses[key] = value
	end

	pushSnapshot(player)
end

--=== Работа с чеками (идемпотентность ProcessReceipt, п.7.4) =====================

local PURCHASE_LOG_LIMIT = 100

function PlayerDataService.HasProcessedReceipt(player: Player, receiptId: string): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local log = ensureList(data, "PurchaseLog")
	for _, entry in ipairs(log) do
		if entry.Id == receiptId then
			return true
		end
	end
	return false
end

function PlayerDataService.LogReceipt(player: Player, receiptId: string, productId: number)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	local log = ensureList(data, "PurchaseLog")
	table.insert(log, { Id = receiptId, ProductId = productId, Time = os.time() })

	while #log > PURCHASE_LOG_LIMIT do
		table.remove(log, 1)
	end
end

function PlayerDataService.SaveNow(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

--=== Загрузка / выгрузка =========================================================

local function loadProfile(player: Player): any
	return store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player:IsDescendantOf(Players) == false
		end,
	})
end

function PlayerDataService.LoadProfileAsync(player: Player)
	return Promise.new(function(resolve, reject)
		local ok, profile = pcall(loadProfile, player)
		if not ok then
			reject(profile)
			return
		end
		if profile == nil then
			reject("Профиль занят другим сервером")
			return
		end
		resolve(profile)
	end)
end

local function onPlayerAdded(player: Player)
	local trove = Trove.new()
	troves[player] = trove

	PlayerDataService.LoadProfileAsync(player)
		:andThen(function(profile: any)
			if not player:IsDescendantOf(Players) then
				profile:EndSession()
				return
			end

			profile:Reconcile()
			profile:AddUserId(player.UserId)

			profiles[player] = profile

			trove:Connect(profile.OnSessionEnd, function()
				profiles[player] = nil
				if player:IsDescendantOf(Players) then
					player:Kick(
						"Ваши данные были загружены на другом сервере. Зайдите снова."
					)
				end
			end)

			PlayerDataService.ProfileReady:Fire(player, profile.Data)
			pushSnapshot(player)
		end)
		:catch(function(err)
			warn(
				("[PlayerDataService] Не удалось загрузить профиль %s: %s"):format(
					player.Name,
					tostring(err)
				)
			)
			if player:IsDescendantOf(Players) then
				player:Kick(
					"Не удалось загрузить данные профиля. Попробуйте зайти позже."
				)
			end
		end)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
		profiles[player] = nil
	end

	local trove = troves[player]
	if trove then
		trove:Destroy()
		troves[player] = nil
	end

	pushPending[player] = nil
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- На случай перезапуска сервера в Studio (скрипт инициализируется позже игрока)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		for _, profile in pairs(profiles) do
			profile:EndSession()
		end
		table.clear(profiles)
	end)

	store.OnError:Connect(function(message: string, storeName: string, key: string)
		warn(("[PlayerDataService] DataStore error (store: %s; key: %s): %s"):format(storeName, key, message))
	end)

	store.OnCriticalToggle:Connect(function(isCritical: boolean)
		if isCritical then
			warn(
				"[PlayerDataService] DataStore в критическом состоянии — сохранения могут задерживаться"
			)
		end
	end)

	-- Настройки игрока (MusicVolume / AmbientVolume / ...), валидация в SetSetting
	Remotes.OnServerEvent(Remotes.Names.UpdateSettings, function(player: Player, payload: any)
		if type(payload) ~= "table" then
			return
		end
		PlayerDataService.SetSetting(player, payload.Key, payload.Value)
	end)
end

return PlayerDataService
