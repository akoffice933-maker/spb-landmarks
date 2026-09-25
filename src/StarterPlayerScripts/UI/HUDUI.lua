--!strict
--[[
	HUDUI.lua — постоянный HUD: текущая зона, время суток (ClockTime),
	подсказкафото-зоны и мини-панель управления временем (Game Pass «Хронос»).

	Слушает события:
	  * ZoneChanged   (п.12.3 — эмбиент по зонам);
	  * LightingState (п.4.1 — день/закат/белые ночи/ночь);
	  * PhotoSpotHint (п.5.3).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)
local LightingPresets = require(Shared.Config.LightingPresets)

local UIInstances = require(script.Parent.UIInstances)
local DataClient = require(script.Parent.Parent.Data.DataClient)

local HUDUI = {}

local gui: ScreenGui? = nil
local zoneLabel: TextLabel? = nil
local ambientLabel: TextLabel? = nil
local clockLabel: TextLabel? = nil
local hintBackground: TextLabel? = nil
local chronoButton: TextButton? = nil
local timePanel: Frame? = nil
local timePanelOpen = false

--=== Собственно HUD =============================================================

local function ensureGui()
	if gui then
		return
	end

	gui = UIInstances.getScreenGui("SPB_HUD")

	-- Подсказка фото-зоны, верхняя часть экрана
	hintBackground = UIInstances.create("TextLabel", {
		Name = "PhotoHint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(320, 40),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.25,
		Visible = false,
		Text = "",
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Body,
		Font = Theme.Fonts.Body,
		Parent = gui,
	}, {
		UIInstances.corner(),
		UIInstances.stroke(Theme.Colors.Gold, 0.4, 2),
	}) :: any

	-- Метка текущей зоны (левый верхний угол, под иконками TopbarPlus)
	zoneLabel = UIInstances.create("TextLabel", {
		Name = "ZoneLabel",
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.fromOffset(260, 36),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.45,
		Text = "",
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Subtitle,
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = gui,
	}, {
		UIInstances.corner(),
		UIInstances.padding(8),
	}) :: any

	ambientLabel = UIInstances.create("TextLabel", {
		Name = "AmbientLabel",
		Position = UDim2.fromOffset(12, 94),
		Size = UDim2.fromOffset(220, 22),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.Sizes.Small,
		Font = Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = gui,
	}) :: any

	-- Часы суток (правый верхний угол)
	clockLabel = UIInstances.create("TextLabel", {
		Name = "ClockLabel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 56),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.45,
		Text = "--:--",
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Subtitle,
		Font = Theme.Fonts.Title,
		Parent = gui,
	}, {
		UIInstances.corner(),
	}) :: any

	-- Мини-панель управления временем (только для владельцев «Хроноса»)
	timePanel = UIInstances.create("Frame", {
		Name = "TimePanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 100),
		Size = UDim2.fromOffset(220, 190),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		UIInstances.corner(),
		UIInstances.stroke(),
		UIInstances.padding(10),
	}) :: any

	UIInstances.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Режим освещения",
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Subtitle,
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = timePanel,
	})

	local buttonHolder = UIInstances.create("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		BackgroundTransparency = 1,
		Parent = timePanel,
	}, {
		UIInstances.create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 32),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for order, modeId in ipairs(LightingPresets.ModeOrder) do
		local preset = LightingPresets.Get(modeId)
		if preset then
			local button = UIInstances.makeButton(buttonHolder, {
				Text = preset.DisplayName,
				Size = UDim2.new(0.5, -4, 0, 32),
				Accent = false,
			})
			button.LayoutOrder = order
			button.Activated:Connect(function()
				Remotes.FireServer(Remotes.Names.RequestLightingMode, { Mode = modeId })
			end)
		end
	end
end

local function formatClockTime(clockTime: number): string
	local hours = math.floor(clockTime) % 24
	local minutes = math.floor((clockTime % 1) * 60)
	return ("%02d:%02d"):format(hours, minutes)
end

function HUDUI.UpdateTimeState(state: any)
	if not gui then
		return
	end

	if type(state) ~= "table" then
		return
	end

	if clockLabel then
		clockLabel.Text = formatClockTime(state.ClockTime or 0)
	end

	-- Кнопка управления временем только для владельцев пасса
	if chronoButton then
		chronoButton.Visible = DataClient.OwnsPass("Chronos")
	end
end

function HUDUI.SetZone(zoneName: string, ambient: any)
	ensureGui()

	if not zoneLabel then
		return
	end

	local label = zoneLabel :: TextLabel
	if zoneName == "" then
		label.Visible = false
	else
		label.Text = zoneName
		label.Visible = true
	end

	if ambientLabel then
		if ambient and ambient.DisplayName then
			ambientLabel.Text = ("♫ " .. ambient.DisplayName)
			ambientLabel.Visible = true
		else
			ambientLabel.Visible = false
		end
	end
end

function HUDUI.SetPhotoHint(text: string?)
	ensureGui()
	if not hintBackground then
		return
	end

	local hint = hintBackground :: TextLabel
	if text then
		hint.Text = text
		hint.Visible = true
		TweenService:Create(hint, TweenInfo.new(0.3), { BackgroundTransparency = 0.25, TextTransparency = 0 }):Play()
	else
		hint.Visible = false
	end
end

function HUDUI.ToggleTimePanel()
	ensureGui()

	if not timePanel then
		return
	end

	timePanelOpen = not timePanelOpen
	timePanel.Visible = timePanelOpen
end

function HUDUI.Start()
	ensureGui()

	-- Кнопка «время» на часах: доступна для владельцев пасса
	chronoButton = UIInstances.makeButton(clockLabel :: Instance, {
		Text = "⏱",
		Size = UDim2.fromOffset(28, 28),
		Accent = false,
	})
	chronoButton.AnchorPoint = Vector2.new(1, 0.5)
	chronoButton.Position = UDim2.new(1, -4, 0.5, 0)
	chronoButton.Visible = false
	chronoButton.Activated:Connect(function()
		HUDUI.ToggleTimePanel()
	end)

	Remotes.OnClientEvent(Remotes.Names.LightingState, function(state: any)
		HUDUI.UpdateTimeState(state)
	end)

	Remotes.OnClientEvent(Remotes.Names.PhotoSpotHint, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if payload.Visible then
			HUDUI.SetPhotoHint(payload.Text or "Место для фото")
		else
			HUDUI.SetPhotoHint(nil)
		end
	end)

	DataClient.ProfileChanged:Connect(function()
		if chronoButton then
			chronoButton.Visible = DataClient.OwnsPass("Chronos")
		end
	end)
end

return HUDUI
