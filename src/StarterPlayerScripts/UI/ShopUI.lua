--!strict
--[[
	ShopUI.lua — магазин (п.14 ТЗ).

	Принцип монетизации из ТЗ:
	  * монетизируется статус и удобство, а НЕ доступ к основному контенту;
	  * никаких попапов при входе — открывается только по иконке в топбаре;
	  * никаких таймеров давления.

	UI построен кодом, обновляется при изменении профиля (DataClient).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)
local GamePasses = require(Shared.Config.GamePasses)
local DeveloperProducts = require(Shared.Config.DeveloperProducts)

local UIInstances = require(script.Parent.UIInstances)
local DataClient = require(script.Parent.Parent.Data.DataClient)

local ShopUI = {}

local gui: ScreenGui? = nil
local contentBody: Frame? = nil
local isOpen = false

local rebuildQueued = false

local function priceText(def: any): string
	if def.RobuxPrice then
		return ("%d R$"):format(def.RobuxPrice)
	end
	return "R$"
end

local function entryFrame(parent: Instance, height: number?): Frame
	return UIInstances.create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, height or 92),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		UIInstances.corner(),
		UIInstances.padding(12),
	}) :: Frame
end

local function buildGamePassRow(parent: Instance, pass: any)
	local row = entryFrame(parent)

	UIInstances.create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -140, 0, 22),
		BackgroundTransparency = 1,
		Text = pass.DisplayName,
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Subtitle,
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local description = UIInstances.create("TextLabel", {
		Name = "Description",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, -140, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = pass.Description,
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.Sizes.Small,
		Font = Theme.Fonts.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = row,
	})
	description.LayoutOrder = 2

	local owned = DataClient.OwnsPass(pass.Key)
	local button = UIInstances.makeButton(row, {
		Text = if owned then "Куплено" else ("Купить %s"):format(priceText(pass)),
		Size = UDim2.fromOffset(120, 36),
		Accent = not owned,
	})
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)

	if not owned then
		button.Activated:Connect(function()
			Remotes.FireServer(Remotes.Names.RequestPurchase, { Kind = "GamePass", Key = pass.Key })
		end)
	end

	return row
end

local function buildProductRow(parent: Instance, product: any)
	local row = entryFrame(parent)

	UIInstances.create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -140, 0, 22),
		BackgroundTransparency = 1,
		Text = product.DisplayName,
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Subtitle,
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	UIInstances.create("TextLabel", {
		Name = "Description",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, -140, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = product.Description,
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.Sizes.Small,
		Font = Theme.Fonts.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = row,
	})

	local button = UIInstances.makeButton(row, {
		Text = priceText(product),
		Size = UDim2.fromOffset(120, 36),
		Accent = true,
	})
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)

	button.Activated:Connect(function()
		Remotes.FireServer(Remotes.Names.RequestPurchase, { Kind = "Product", Key = product.Key })
	end)

	return row
end

function ShopUI.Rebuild()
	if not isOpen then
		return
	end
	if rebuildQueued then
		return
	end
	rebuildQueued = true

	task.defer(function()
		rebuildQueued = false
		if not isOpen or not contentBody then
			return
		end

		for _, child in ipairs((contentBody :: Frame):GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local C = Theme.Colors
		local list = contentBody :: Frame

		UIInstances.create("TextLabel", {
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = "Пропуски",
			TextColor3 = C.Text,
			TextSize = Theme.Sizes.Subtitle,
			Font = Theme.Fonts.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = list,
		})

		for _, pass in ipairs(GamePasses.List()) do
			local row = buildGamePassRow(list, pass)
			row.LayoutOrder = 10
		end

		UIInstances.create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = "Удобство и фильтры",
			TextColor3 = C.Text,
			TextSize = Theme.Sizes.Subtitle,
			Font = Theme.Fonts.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 100,
			Parent = list,
		})

		for _, product in ipairs(DeveloperProducts.List()) do
			local row = buildProductRow(list, product)
			row.LayoutOrder = 110
		end
	end)
end

function ShopUI.Open()
	if isOpen then
		return
	end
	isOpen = true

	if not gui then
		gui = UIInstances.getScreenGui("SPB_Shop", 40)

		local _panel: Frame
		local body: Frame
		local closeButton: TextButton
		_panel, body, closeButton = UIInstances.makePanel(gui, {
			Title = "Магазин",
			Size = UDim2.fromOffset(560, 520),
		})

		contentBody = UIInstances.create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromOffset(0, 0),
			Parent = body,
		}, {
			UIInstances.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),
		}) :: Frame

		closeButton.Activated:Connect(function()
			ShopUI.Close()
		end)
	end

	ShopUI.Rebuild()
	local panelGui = gui :: ScreenGui
	panelGui.Enabled = true
end

function ShopUI.Close()
	if not isOpen then
		return
	end
	isOpen = false
	if gui then
		gui.Enabled = false
	end
end

function ShopUI.Toggle()
	if isOpen then
		ShopUI.Close()
	else
		ShopUI.Open()
	end
end

function ShopUI.Start()
	Remotes.OnClientEvent(Remotes.Names.PurchaseFinished, function(payload: any)
		if type(payload) ~= "table" or not payload.Success then
			return
		end
		ShopUI.Rebuild()
	end)

	DataClient.ProfileChanged:Connect(function()
		ShopUI.Rebuild()
	end)
end

return ShopUI
