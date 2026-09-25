--!strict
--[[
	CollectionUI.lua — «коллекция» посещённых мест (фундамент v1.1).

	Показывает сетку достопримечательностей: сколько открыто, сколько снимков
	сделано (PhotoCount). Данные берутся из DataClient (снимок профиля).
	Открывается иконкой в топбаре (см. TopbarUI).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Landmarks = require(Shared.Config.Landmarks)

local UIInstances = require(script.Parent.UIInstances)
local DataClient = require(script.Parent.Parent.Data.DataClient)

local CollectionUI = {}

local gui: ScreenGui? = nil
local body: Frame? = nil
local statsLabel: TextLabel? = nil
local isOpen = false

local function buildTile(landmark: any, visited: boolean): Frame
	local C = Theme.Colors

	local tile = UIInstances.create("Frame", {
		Size = UDim2.fromOffset(168, 150),
		BackgroundColor3 = if visited then C.Surface else C.Background,
		BackgroundTransparency = if visited then 0 else 0.35,
		BorderSizePixel = 0,
	}, {
		UIInstances.corner(),
		UIInstances.stroke(if visited then C.Gold else C.Stroke, if visited then 0.25 else 0.7),
		UIInstances.padding(8),
	}) :: Frame

	local image = UIInstances.create("ImageLabel", {
		Name = "Image",
		Size = UDim2.new(1, 0, 0, 78),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = C.SurfaceAlt,
		Image = landmark.ImageAsset,
		ScaleType = Enum.ScaleType.Crop,
	}, {
		UIInstances.corner(),
	}) :: ImageLabel
	image.Parent = tile

	if not visited then
		UIInstances.create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "?",
			TextColor3 = C.TextDim,
			TextSize = 34,
			Font = Theme.Fonts.Title,
			Parent = image,
		})
	end

	UIInstances.create("TextLabel", {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = landmark.DisplayName,
		TextColor3 = if visited then C.Text else C.TextDim,
		TextSize = Theme.Sizes.Small,
		Font = Theme.Fonts.Button,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = tile,
	})

	UIInstances.create("TextLabel", {
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = if visited then "✓ посещено" else "не открыто",
		TextColor3 = if visited then C.Success else C.TextDim,
		TextSize = 12,
		Font = Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tile,
	})

	if landmark.PhotoSpot then
		local badge = UIInstances.create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 6),
			Size = UDim2.fromOffset(26, 16),
			BackgroundColor3 = C.Accent,
			Text = "📷",
			TextSize = 10,
			Font = Theme.Fonts.Button,
			Parent = tile,
		}, {
			UIInstances.corner(UDim.new(0, 5)),
		})
		badge.TextColor3 = C.Background
	end

	return tile
end

function CollectionUI.Refresh()
	if not isOpen or not body then
		return
	end

	local container = body :: Frame
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local profile = DataClient.GetProfile()
	local visitedCount = 0
	local list = Landmarks.List()

	for _, landmark in ipairs(list) do
		local visited = DataClient.HasVisited(landmark.Id)
		if visited then
			visitedCount += 1
		end
		buildTile(landmark, visited).Parent = container
	end

	if statsLabel then
		local photos = profile and profile.PhotoCount or 0
		statsLabel.Text = ("Открыто мест: %d/%d · Фото: %d"):format(visitedCount, #list, photos)
	end
end

function CollectionUI.Open()
	if isOpen then
		CollectionUI.Refresh()
		return
	end
	isOpen = true

	if not gui then
		gui = UIInstances.getScreenGui("SPB_Collection", 41)

		local _panel: Frame
		local panelBody: Frame
		local closeButton: TextButton
		_panel, panelBody, closeButton = UIInstances.makePanel(gui, {
			Title = "Коллекция мест",
			Size = UDim2.fromOffset(600, 440),
		})

		statsLabel = UIInstances.create("TextLabel", {
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Theme.Colors.TextDim,
			TextSize = Theme.Sizes.Small,
			Font = Theme.Fonts.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = panelBody,
		}) :: any

		body = UIInstances.create("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 1, -26),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromOffset(0, 0),
			Parent = panelBody,
		}, {
			UIInstances.create("UIGridLayout", {
				CellSize = UDim2.fromOffset(172, 152),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}) :: Frame

		closeButton.Activated:Connect(function()
			CollectionUI.Close()
		end)
	end

	gui.Enabled = true
	CollectionUI.Refresh()
end

function CollectionUI.Close()
	isOpen = false
	if gui then
		gui.Enabled = false
	end
end

function CollectionUI.Toggle()
	if isOpen then
		CollectionUI.Close()
	else
		CollectionUI.Open()
	end
end

function CollectionUI.Start()
	DataClient.ProfileChanged:Connect(function()
		CollectionUI.Refresh()
	end)
end

return CollectionUI
