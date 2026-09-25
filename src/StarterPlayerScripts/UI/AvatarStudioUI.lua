--!strict
--[[
	AvatarStudioUI.lua — панель «Стиль» (v2.0): гардероб + позы для фото.

	Иконка в TopbarPlus — person-standing (lucide: accessibility).
	Две секции в одном окне; запросы летят через
	RequestWardrobe / RequestPose (клиент -> сервер, валидация на сервере).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local AvatarPresets = require(Shared.Config.AvatarPresets)

local UIInstances = require(script.Parent.UIInstances)
local DataClient = require(script.Parent.Parent.Data.DataClient)

local AvatarStudioUI = {}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local isOpen = false

-- Владение пассом — для тегов «VIP» на нарядах
local function ownsFeature(feature: string): boolean
	for _, key in require(Shared.Config.GamePasses).KeysForFeature(feature) do
		if DataClient.OwnsPass(key) then
			return true
		end
	end
	return false
end

-- Текущий сохранённый наряд (v2.1 живёт в профиле)
local function currentOutfitId(): string
	return DataClient.GetSetting("WardrobeOutfit", "None")
end

local function outfitRow(outfit: AvatarPresets.OutfitPreset, order: number): Frame
	local row = UIInstances.create("Frame", {
		Name = ("Outfit_%s"):format(outfit.Id),
		Size = UDim2.new(1, -8, 0, 76),
		BackgroundTransparency = 0.6,
		BackgroundColor3 = Color3.fromRGB(24, 28, 36),
		LayoutOrder = order,
	}, { UIInstances.corner(), UIInstances.stroke() }) :: Frame

	-- Чипы цветов гардероб
	for index, color in { outfit.Torso, outfit.LeftLeg, outfit.Head } do
		UIInstances.create("Frame", {
			Name = ("Chip_%d"):format(index),
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset(16 + (index - 1) * 32, 22),
			BackgroundColor3 = color,
			Parent = row,
		}, { UIInstances.corner(UDim.new(0, 6)), UIInstances.stroke(Color3.fromRGB(40, 45, 55), 1) })
	end

	UIInstances.create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -140, 0, 22),
		Position = UDim2.fromOffset(130, 12),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(235, 238, 245),
		Text = if outfit.RequiresFeature and not ownsFeature(outfit.RequiresFeature)
			then ("%s 🔒"):format(outfit.Name)
			elseif currentOutfitId() == outfit.Id then ("%s ✓ надето"):format(outfit.Name)
			else outfit.Name,
		Parent = row,
	})

	UIInstances.create("TextLabel", {
		Name = "Desc",
		Size = UDim2.new(1, -140, 0, 34),
		Position = UDim2.fromOffset(130, 34),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(160, 168, 185),
		Text = outfit.Desc,
		Parent = row,
	})

	local button = UIInstances.create("TextButton", {
		Name = "Apply",
		Size = UDim2.fromOffset(92, 30),
		Position = UDim2.new(1, -108, 0.5, -15),
		BackgroundColor3 = Color3.fromRGB(58, 110, 165),
		Text = "Надеть",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Parent = row,
	}, { UIInstances.corner() }) :: TextButton

	button.MouseButton1Click:Connect(function()
		Remotes.FireServer(Remotes.Names.RequestWardrobe, outfit.Id)
	end)

	return row
end

local function poseRow(pose: AvatarPresets.PosePreset, order: number): TextButton
	local button = UIInstances.create("TextButton", {
		Name = ("Pose_%s"):format(pose.Id),
		Size = UDim2.new(0.5, -10, 0, 40),
		BackgroundColor3 = Color3.fromRGB(36, 42, 52),
		Text = pose.Name,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(225, 228, 235),
		LayoutOrder = order,
	}, { UIInstances.corner(), UIInstances.stroke() }) :: TextButton

	button.MouseButton1Click:Connect(function()
		Remotes.FireServer(Remotes.Names.RequestPose, pose.Id)
	end)

	return button
end

local function buildPanel()
	-- Перестраиваем на каждом открытии: подсветка «✓ надето» актуальна.
	if panel then
		panel:Destroy()
		panel = nil
	end
	gui = UIInstances.getScreenGui("SPB_AvatarStudio", 40)
	gui.Enabled = false

	local frame = UIInstances.create("Frame", {
		Name = "AvatarStudioPanel",
		Size = UDim2.fromOffset(440, 560),
		Position = UDim2.new(0.5, -220, 0.5, -280),
		BackgroundColor3 = Color3.fromRGB(16, 20, 27),
		Parent = gui,
	}, { UIInstances.corner(UDim.new(0, 14)), UIInstances.stroke(Color3.fromRGB(70, 85, 110), 2) }) :: Frame

	UIInstances.create("TextLabel", {
		Name = "Header",
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(240, 243, 250),
		Text = "🎭 Гардероб и позы",
		Parent = frame,
	})

	UIInstances.create("TextLabel", {
		Name = "Sub",
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 52),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(140, 148, 166),
		Text = "Наряды — на цвет силуэта · позы — для фото остановок",
		Parent = frame,
	})

	-- Гардероб
	local wardrobeScroll = UIInstances.create("ScrollingFrame", {
		Name = "Outfits",
		Size = UDim2.new(1, -24, 0, 320),
		Position = UDim2.fromOffset(12, 90),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 382),
		Parent = frame,
	}, {
		UIInstances.create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: ScrollingFrame

	-- Кнопка «назад к стандартному Roblox-виду» — сброс сохранённого наряда
	local backToDefault = UIInstances.create("TextButton", {
		Name = "Outfit_None",
		Size = UDim2.new(1, -8, 0, 40),
		BackgroundTransparency = 0.5,
		BackgroundColor3 = if currentOutfitId() == "None"
			then Color3.fromRGB(58, 88, 68)
			else Color3.fromRGB(52, 58, 70),
		Text = if currentOutfitId() == "None"
			then "Стандартный (Roblox) ✓ активен"
			else "Стандартный (Roblox) — вернуть",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(225, 230, 240),
		LayoutOrder = 0,
	}, { UIInstances.corner(), UIInstances.stroke() }) :: TextButton
	backToDefault.Parent = wardrobeScroll
	backToDefault.MouseButton1Click:Connect(function()
		Remotes.FireServer(Remotes.Names.RequestWardrobe, "None")
		AvatarStudioUI.Close()
	end)

	for index, outfit in AvatarPresets.Outfits do
		outfitRow(outfit, index).Parent = wardrobeScroll
	end

	-- Позы
	UIInstances.create("TextLabel", {
		Name = "PoseHeader",
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 420),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 205, 216),
		Text = "📸 Позы для фото",
		Parent = frame,
	})

	local poseGrid = UIInstances.create("Frame", {
		Name = "Poses",
		Size = UDim2.new(1, -24, 0, 96),
		Position = UDim2.fromOffset(12, 446),
		BackgroundTransparency = 1,
		Parent = frame,
	}, {
		UIInstances.create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 40),
			CellPadding = UDim2.fromOffset(12, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
	}) :: Frame

	for index, pose in AvatarPresets.Poses do
		poseRow(pose, index).Parent = poseGrid
	end
	-- Кнопка сброса рядом с позами
	local reset = poseRow({ Id = "Reset", Name = "Сброс позы", Offsets = {} }, #AvatarPresets.Poses + 1)
	reset.BackgroundColor3 = Color3.fromRGB(120, 52, 52)
	reset.Parent = poseGrid

	UIInstances.create("TextButton", {
		Name = "Close",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -44, 0, 8),
		BackgroundTransparency = 0.4,
		BackgroundColor3 = Color3.fromRGB(40, 45, 56),
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(220, 224, 232),
		Parent = frame,
	}, { UIInstances.corner() })

	local closeBtn = frame:FindFirstChild("Close") :: TextButton
	closeBtn.MouseButton1Click:Connect(function()
		AvatarStudioUI.Close()
	end)

	panel = frame
end

function AvatarStudioUI.Open()
	buildPanel()
	if gui then
		gui.Enabled = true
	end
	isOpen = true
end

function AvatarStudioUI.Close()
	if gui then
		gui.Enabled = false
	end
	isOpen = false
end

function AvatarStudioUI.Toggle()
	if isOpen then
		AvatarStudioUI.Close()
	else
		AvatarStudioUI.Open()
	end
end

function AvatarStudioUI.Start()
	-- Ленивое строительство: панель соберётся при первом открытии.
	-- Клики кнопок озвучивает общий авто-хук UISoundClient.
end

return AvatarStudioUI
