--!strict
--[[
	InfoBoardUI.lua — читалка инфо-табличек (п.5.1, п.16).

	Сервер шлёт событие ShowInfoBoard с уже собранным текстом; с пассом
	«Гид-исследователь» в payload есть расширенные факты.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)

local UIInstances = require(script.Parent.UIInstances)
local ShopUI = require(script.Parent.ShopUI)

local InfoBoardUI = {}

local gui: ScreenGui? = nil
local _panel: Frame? = nil
local titleLabel: TextLabel? = nil
local summaryLabel: TextLabel? = nil
local detailsHolder: Frame? = nil
local teaserLabel: TextLabel? = nil
local guideButton: TextButton? = nil
local imageLabel: ImageLabel? = nil

local function createText(
	parent: Instance,
	text: string,
	size: number,
	color: Color3,
	font: Enum.Font,
	order: number
): TextLabel
	return UIInstances.create("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		Text = text,
		TextColor3 = color,
		TextSize = math.max(size, Theme.Sizes.MinMobileText),
		Font = font,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = parent,
	}) :: any
end

local function show(payload: any)
	if not gui then
		gui = UIInstances.getScreenGui("SPB_Info", 42)

		local body: Frame
		local closeButton: TextButton
		_panel, body, closeButton = UIInstances.makePanel(gui, {
			Title = "",
			Size = UDim2.fromOffset(460, 360),
		})

		closeButton.Activated:Connect(function()
			gui.Enabled = false
		end)

		titleLabel = UIInstances.create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Theme.Colors.Text,
			TextSize = Theme.Sizes.Title,
			Font = Theme.Fonts.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		}) :: any

		imageLabel = UIInstances.create("ImageLabel", {
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.fromOffset(120, 70),
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			ScaleType = Enum.ScaleType.Crop,
			Parent = body,
		}, { UIInstances.corner() }) :: any

		summaryLabel = UIInstances.create("TextLabel", {
			Position = UDim2.fromOffset(132, 30),
			Size = UDim2.new(1, -132, 0, 70),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Theme.Colors.TextDim,
			TextSize = Theme.Sizes.Body,
			Font = Theme.Fonts.Body,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = body,
		}) :: any

		detailsHolder = UIInstances.create("Frame", {
			Position = UDim2.fromOffset(0, 112),
			Size = UDim2.new(1, 0, 1, -112),
			BackgroundTransparency = 1,
			Parent = body,
		}, {
			UIInstances.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		}) :: any

		teaserLabel = createText(detailsHolder, "", Theme.Sizes.Small, Theme.Colors.Gold, Theme.Fonts.Body, 1000)

		guideButton = UIInstances.makeButton(detailsHolder, {
			Text = "Открыть «Гид-исследователь»",
			Size = UDim2.fromOffset(220, 32),
			Accent = false,
		})
		guideButton.LayoutOrder = 1001
		guideButton.Activated:Connect(function()
			ShopUI.Open()
		end)
	end

	local holder = detailsHolder :: Frame
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("TextLabel") and child.Name:match("^Fact") then
			child:Destroy()
		end
	end

	local t = titleLabel :: TextLabel
	t.Text = payload.Title or ""

	local s = summaryLabel :: TextLabel
	s.Text = payload.Summary or ""

	local img = imageLabel :: ImageLabel
	img.Image = payload.ImageAsset or ""
	img.ImageTransparency = if payload.ImageAsset
			and payload.ImageAsset ~= ""
			and payload.ImageAsset ~= "rbxassetid://0"
		then 0
		else 1
	img.BackgroundTransparency = if img.ImageTransparency == 1 then 0.2 else 0

	local index = 0
	for _, fact in ipairs(payload.Details or {}) do
		index += 1
		local label = createText(holder, "• " .. fact, Theme.Sizes.Body, Theme.Colors.Text, Theme.Fonts.Body, index)
		label.Name = ("Fact%d"):format(index)
	end

	local teaser = teaserLabel :: TextLabel
	teaser.Text = payload.ExtendedTeaser or ""
	teaser.Visible = payload.ExtendedTeaser ~= nil

	if guideButton then
		guideButton.Visible = payload.ExtendedTeaser ~= nil and payload.ExtendedTeaser ~= ""
	end

	gui.Enabled = true
end

function InfoBoardUI.Start()
	Remotes.OnClientEvent(Remotes.Names.ShowInfoBoard, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		show(payload)
	end)
end

return InfoBoardUI
