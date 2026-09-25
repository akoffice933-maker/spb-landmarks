--!strict
--[[
	InfoService.lua — инфо-таблички (п.5.1 ТЗ).

	Таблички на карте помечаются CollectionService-тегом "InfoBoard" и
	атрибутом InfoId ("Nevsky", "Hermitage" или собственный id из
	Landmarks.InfoBoards — Nevsky_01 и т.п.).

	Поток:
	  * ProximityPrompt -> сервер собирает текст (базовый всем, расширенный
	    с пассом «Гид-исследователь», п.14.1) и отправляет клиенту;
	  * клиент показывает читаемый GUI (минимальный кегль соблюдён в UI-коде,
	    п.16).

	`GetInfoBoard` также доступен как RemoteFunction — клиент может заранее
	подтянуть текст (например, для предпросмотра в коллекции).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Landmarks = require(Shared.Config.Landmarks)

local MonetizationController = require(script.Parent.Parent.Monetization.MonetizationController)

local INFOBOARD_TAG = "InfoBoard"

local InfoService = {}

local boardsById: { [string]: { Instance } } = {}

local function buildPayload(player: Player, infoId: string): any?
	local board = Landmarks.GetInfoBoard(infoId)
	if not board then
		return nil
	end

	local hasExtended = MonetizationController.HasFeature(player, "ExtendedInfo")

	return {
		Id = board.Id,
		Title = board.Title,
		Summary = board.Summary,
		Details = if hasExtended then board.Details else {},
		ExtendedUnlocked = hasExtended,
		ExtendedTeaser = if not hasExtended and #board.Details > 0
			then ("Ещё %d факт(а) — с пропуском «Гид-исследователь»"):format(
				#board.Details
			)
			else nil,
		ImageAsset = board.ImageAsset,
	}
end

local function openBoard(player: Player, infoId: string)
	local payload = buildPayload(player, infoId)
	if not payload then
		return
	end
	Remotes.FireClient(Remotes.Names.ShowInfoBoard, player, payload)
end

local function ensurePrompt(instance: Instance)
	local existing = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existing then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "InfoPrompt"
	prompt.ActionText = "Прочитать"
	prompt.ObjectText = "Информация"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 10
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = instance
end

local function registerBoard(instance: Instance)
	local infoId = instance:GetAttribute("InfoId")
	if type(infoId) ~= "string" or not Landmarks.GetInfoBoard(infoId) then
		warn(
			("[InfoService] %s: некорректный атрибут InfoId (`%s`)"):format(
				instance:GetFullName(),
				tostring(instance:GetAttribute("InfoId"))
			)
		)
		return
	end

	boardsById[infoId] = boardsById[infoId] or {}
	table.insert(boardsById[infoId], instance)

	ensurePrompt(instance)
	local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			openBoard(player, infoId)
		end)
	end
end

function InfoService.Start()
	for _, instance in ipairs(CollectionService:GetTagged(INFOBOARD_TAG)) do
		task.spawn(registerBoard, instance)
	end

	CollectionService:GetInstanceAddedSignal(INFOBOARD_TAG):Connect(registerBoard)

	Remotes.OnServerInvoke(Remotes.Names.GetInfoBoard, function(player: Player, infoId: any)
		if type(infoId) ~= "string" or #infoId > 64 then
			return nil
		end
		return buildPayload(player, infoId)
	end)
end

return InfoService
