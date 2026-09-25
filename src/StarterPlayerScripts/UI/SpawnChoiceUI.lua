--!strict
--[[
	SpawnChoiceUI.lua — выбор точки спавна при входе (п.5.1).

	Сервер присылает ShowSpawnChoice после загрузки профиля: игрок выбирает
	одну из трёх стартовых точек (Дворцовая / Невский / Петропавловка),
	сервер валидирует выбор и телепортирует персонажа.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)

local UIInstances = require(script.Parent.UIInstances)

local SpawnChoiceUI = {}

local gui: ScreenGui? = nil

local function showSpawnChoices(choices: { any })
	if gui then
		gui:Destroy()
		gui = nil
	end

	gui = UIInstances.getScreenGui("SPB_SpawnChoice", 50)
	local instance = gui :: ScreenGui

	local dim = UIInstances.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Shadow,
		BackgroundTransparency = 0.35,
		Parent = instance,
	})

	local body: Frame
	local _panel: Frame
	_panel, body = UIInstances.makePanel(dim :: any, {
		Title = "Где начать прогулку?",
		Size = UDim2.fromOffset(520, 210),
	})

	UIInstances.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "Выберите отправную точку — перемещаться можно пешком.",
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.Sizes.Body,
		Font = Theme.Fonts.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = body,
	})

	local holder = UIInstances.create("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		UIInstances.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame

	for order, choice in ipairs(choices) do
		local button = UIInstances.makeButton(holder, {
			Text = choice.DisplayName,
			Size = UDim2.fromOffset(150, 64),
			Accent = order == 1,
		})
		button.LayoutOrder = order
		button.TextWrapped = true
		button.Visible = choice.Available ~= false

		button.Activated:Connect(function()
			Remotes.FireServer(Remotes.Names.SelectSpawn, { SpawnId = choice.Id })
			instance.Enabled = false
		end)
	end
end

--=== Быстрое перемещение (Developer Product, п.14.2) ============================

local function showTravelChoices(destinations: { any })
	if gui then
		gui:Destroy()
		gui = nil
	end

	gui = UIInstances.getScreenGui("SPB_FastTravel", 51)
	local instance = gui :: ScreenGui

	local dim = UIInstances.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Shadow,
		BackgroundTransparency = 0.35,
		Parent = instance,
	})

	local _panel: Frame
	local body: Frame
	local closeButton: TextButton
	_panel, body, closeButton = UIInstances.makePanel(dim, {
		Title = "Куда отправимся?",
		Size = UDim2.fromOffset(520, 320),
	})

	closeButton.Activated:Connect(function()
		instance.Enabled = false
	end)

	local holder = UIInstances.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 6,
		Parent = body,
	}, {
		UIInstances.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	for order, destination in ipairs(destinations) do
		local button = UIInstances.makeButton(holder, {
			Text = destination.DisplayName,
			Size = UDim2.new(1, 0, 0, 40),
			Accent = false,
		})
		button.LayoutOrder = order

		button.Activated:Connect(function()
			Remotes.FireServer(Remotes.Names.RequestFastTravel, { LandmarkId = destination.Id })
			instance.Enabled = false
		end)
	end
end

function SpawnChoiceUI.Start()
	Remotes.OnClientEvent(Remotes.Names.ShowSpawnChoice, function(payload: any)
		if type(payload) ~= "table" or type(payload.Choices) ~= "table" then
			return
		end
		-- Не показываем повторный выбор, если игрок уже делал выбор в этой сессии
		if gui and gui.Enabled == false then
			return
		end
		showSpawnChoices(payload.Choices)
	end)

	-- Платное быстрое перемещение: сервер прислал список точек после покупки
	Remotes.OnClientEvent(Remotes.Names.FastTravelReady, function(payload: any)
		if type(payload) ~= "table" or type(payload.Destinations) ~= "table" then
			return
		end
		showTravelChoices(payload.Destinations)
	end)

	-- Телепорт-затемнение: оно же «снимает» экран выбора спавна
	Remotes.OnClientEvent(Remotes.Names.TeleportFade, function(_payload: any)
		if not gui then
			return
		end
		gui.Enabled = false
	end)
end

return SpawnChoiceUI
