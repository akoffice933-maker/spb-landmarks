--!strict
--[[
	VipBadgeService.lua — значок над головой владельцев «VIP-фотографа» (п.14.1 ТЗ).

	Владение пассом читается ИЗ ПРОФИЛЯ через MonetizationController.HasFeature
	(не через MarketplaceService напрямую — кэш уже есть, лишних сетевых
	запросов нет). BillboardGui живёт на Head и пересоздаётся на респауне;
	при покупке пасса в рантайме значок появляется без перезахода
	(событие DataChanged("OwnedPasses") из PlayerDataService).
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = ServerScriptService:WaitForChild("Data")
local Monetization = ServerScriptService:WaitForChild("Monetization")

local PlayerDataService = require(Data.PlayerDataService)
local MonetizationController = require(Monetization.MonetizationController)

local BADGE_NAME = "SPB_VipBadge"
local FEATURE = "VipPhotoFrame"

local VipBadgeService = {}

local function ensureBadge(head: BasePart)
	local existing = head:FindFirstChild(BADGE_NAME)
	if existing and existing:IsA("BillboardGui") then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = BADGE_NAME
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "★ VIP-фотограф"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 210, 80)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = Color3.fromRGB(60, 40, 5)
	stroke.Thickness = 1.4
	stroke.Parent = label

	gui.Parent = head
end

local function refreshCharacter(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local show = MonetizationController.HasFeature(player, FEATURE)
	local badge = head:FindFirstChild(BADGE_NAME)
	if show then
		ensureBadge(head :: BasePart)
	elseif badge then
		badge:Destroy()
	end
end

function VipBadgeService.Start()
	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Head может появиться не мгновенно (нестандартные риги).
			task.defer(function()
				character:WaitForChild("Head", 15)
				if player.Character == character then
					refreshCharacter(player)
				end
			end)
		end)
		if player.Character then
			refreshCharacter(player)
		end
	end

	Players.PlayerAdded:Connect(bind)
	for _, existing in Players:GetPlayers() do
		bind(existing)
	end

	-- Покупка пасса в середине сессии: PlayerDataService стреляет событием.
	PlayerDataService.DataChanged:Connect(function(player: Player, key: string)
		if key == "OwnedPasses" then
			refreshCharacter(player)
		end
	end)
end

return VipBadgeService
