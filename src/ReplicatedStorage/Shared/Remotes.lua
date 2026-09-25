--!strict
--[[
	Remotes.lua — единая точка доступа к RemoteEvent / RemoteFunction.

	Зачем: не разбрасывать Instance.new("RemoteEvent") по коду и не ловить
	гонки «клиент требует remote раньше, чем сервер его создал».

	Поведение:
	  * на сервере — объекты создаются лениво при первом обращении;
	  * на клиенте — объекты дожидаются появления (WaitForChild с таймаутом).

	Использование:
		local Remotes = require(path.to.Remotes)
		Remotes.Event(Remotes.Names.ProfileUpdated).OnClientEvent:Connect(onUpdate)
		Remotes.FireServer(Remotes.Names.PhotoCaptured, landmarkId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 30

local Remotes = {}

-- Все имена remote-объектов объявляются здесь: один реестр на весь проект.
Remotes.Names = {
	-- Сервер -> клиент
	ProfileUpdated = "ProfileUpdated",
	ZoneChanged = "ZoneChanged",
	Notify = "Notify",
	PhotoSpotHint = "PhotoSpotHint",
	PhotoSessionStart = "PhotoSessionStart",
	ShowInfoBoard = "ShowInfoBoard",
	TeleportFade = "TeleportFade",
	ShowSpawnChoice = "ShowSpawnChoice",
	FastTravelReady = "FastTravelReady",
	LightingState = "LightingState",
	PurchaseFinished = "PurchaseFinished",

	-- Клиент -> сервер
	PhotoCaptured = "PhotoCaptured",
	RequestPurchase = "RequestPurchase",
	SelectSpawn = "SelectSpawn",
	RequestFastTravel = "RequestFastTravel",
	UpdateSettings = "UpdateSettings",
	RequestLightingMode = "RequestLightingMode",
	RequestLightingTime = "RequestLightingTime",
	OnboardingCompleted = "OnboardingCompleted",
	RequestWardrobe = "RequestWardrobe",
	RequestPose = "RequestPose",

	-- RemoteFunction (клиент запрашивает, сервер отвечает)
	GetInfoBoard = "GetInfoBoard",
}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing :: Folder
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT) :: Folder
end

local cache: { [string]: Instance } = {}

local function get(name: string, className: string): Instance
	local cached = cache[name]
	if cached and cached.Parent == folder then
		return cached
	end

	local instance = folder:FindFirstChild(name)
	if not instance then
		if RunService:IsServer() then
			instance = Instance.new(className)
			instance.Name = name
			instance.Parent = folder
		else
			instance = folder:WaitForChild(name, WAIT_TIMEOUT)
		end
	end

	cache[name] = instance
	return instance
end

function Remotes.Event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: any
end

function Remotes.Function(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: any
end

function Remotes.FireClient(name: string, player: Player, ...: any)
	Remotes.Event(name):FireClient(player, ...)
end

function Remotes.FireAllClients(name: string, ...: any)
	Remotes.Event(name):FireAllClients(...)
end

function Remotes.FireServer(name: string, ...: any)
	Remotes.Event(name):FireServer(...)
end

function Remotes.InvokeServer(name: string, ...: any): ...any
	return Remotes.Function(name):InvokeServer(...)
end

function Remotes.OnServerEvent(name: string, handler: (Player, ...any) -> ())
	return Remotes.Event(name).OnServerEvent:Connect(handler)
end

function Remotes.OnClientEvent(name: string, handler: (...any) -> ())
	return Remotes.Event(name).OnClientEvent:Connect(handler)
end

function Remotes.OnServerInvoke(name: string, handler: (Player, ...any) -> ...any)
	Remotes.Function(name).OnServerInvoke = handler
end

return Remotes
