--!strict
--[[
	SettingsUI.lua — настройки звука (п.5.2): громкость музыки и эмбиента.

	Ползунки рисуются кодом; значения кладутся в SettingsClient, который
	отправляет их на сервер с дебаунсом.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Landmarks = require(Shared.Config.Landmarks)

local UIInstances = require(script.Parent.UIInstances)
local DataClient = require(script.Parent.Parent.Data.DataClient)
local SettingsClient = require(script.Parent.SettingsClient)

local SettingsUI = {}

local gui: ScreenGui? = nil
local isOpen = false
local sliders: { [string]: { Track: Frame, Fill: Frame, Label: TextLabel } } = {}

local function percentText(value: number): string
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

local function buildSlider(parent: Instance, key: string, order: number)
	local def = Landmarks.SETTINGS[key]
	if not def then
		return
	end

	local holder = UIInstances.create("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})

	UIInstances.create("TextLabel", {
		Size = UDim2.new(0.7, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = def.DisplayName,
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Body,
		Font = Theme.Fonts.Button,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local valueLabel = UIInstances.create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.Sizes.Small,
		Font = Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = holder,
	}) :: any

	local track = UIInstances.create("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Theme.Colors.SurfaceAlt,
		Active = true,
		Parent = holder,
	}, { UIInstances.corner(UDim.new(1, 0)) }) :: any

	local fill = UIInstances.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.Accent,
		Parent = track,
	}, { UIInstances.corner(UDim.new(1, 0)) }) :: any

	local state = {
		Track = track,
		Fill = fill,
		Label = valueLabel,
	}
	sliders[key] = state

	local dragging = false

	local function apply(position: Vector3)
		local relativeX = position.X - track.AbsolutePosition.X
		local percent = math.clamp(relativeX / track.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.fromScale(percent, 1)
		valueLabel.Text = percentText(percent)
		SettingsClient.Set(key, percent)
	end

	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			apply(input.Position)
		end
	end)

	track.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
			SettingsClient.FlushNow()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		apply(input.Position)
	end)
end

local function refresh()
	for key, state in pairs(sliders) do
		local value = DataClient.GetSetting(key, 0.5)
		if type(value) == "number" then
			state.Fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
			state.Label.Text = percentText(math.clamp(value, 0, 1))
		end
	end
end

function SettingsUI.Open()
	if isOpen then
		return
	end
	isOpen = true

	if not gui then
		gui = UIInstances.getScreenGui("SPB_Settings", 43)

		local _panel: Frame
		local body: Frame
		local closeButton: TextButton
		_panel, body, closeButton = UIInstances.makePanel(gui, {
			Title = "Настройки",
			Size = UDim2.fromOffset(360, 220),
		})

		UIInstances.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			Parent = body,
		})

		buildSlider(body, "MusicVolume", 1)
		buildSlider(body, "AmbientVolume", 2)

		closeButton.Activated:Connect(function()
			SettingsUI.Close()
		end)
	end

	refresh()(gui :: ScreenGui).Enabled = true
end

function SettingsUI.Close()
	isOpen = false
	if gui then
		gui.Enabled = false
	end
	SettingsClient.FlushNow()
end

function SettingsUI.Toggle()
	if isOpen then
		SettingsUI.Close()
	else
		SettingsUI.Open()
	end
end

function SettingsUI.Start()
	DataClient.ProfileChanged:Connect(function()
		if isOpen then
			refresh()
		end
	end)
end

return SettingsUI
