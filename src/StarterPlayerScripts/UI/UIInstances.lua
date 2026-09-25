--!strict
--[[
	UIInstances.lua — общие помощники для построения UI кодом.

	UI проекта не хранится в .ui-файлах/плагинах: всё описано здесь, чтобы
	код проходил ревью в Git и форматировался StyLua (п.17.1 ТЗ).

	Состав:
	  * create(className, props, children) — компактное создание инстансов;
	  * getScreenGui(name) — ScreenGui с настройками проекта + UIScale;
	  * Notify({ Text, Kind }) — тосты;
	  * тёмная панель с заголовком и кнопкой закрытия.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)

-- Звуки тостов (success/error). Ленивый require: UIInstances — низкоуровневый
-- модуль и не должен зависеть от аудио при загрузке (п.12 ТЗ).
local UISoundClient: any = nil
local function uiSound(): any
	if UISoundClient == nil then
		local audioFolder = script.Parent.Parent:FindFirstChild("Audio")
		local module = audioFolder and audioFolder:FindFirstChild("UISoundClient")
		if module then
			UISoundClient = require(module)
		else
			UISoundClient = false
		end
	end
	return if UISoundClient == false then nil else UISoundClient
end

local player = Players.LocalPlayer

local UIInstances = {}

local MOBILE_MIN_DIMENSION = 700

function UIInstances.create(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local instance = Instance.new(className)

	if props then
		for property, value in pairs(props) do
			if property ~= "Parent" then
				instance[property] = value
			end
		end
	end

	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end

	if props and props.Parent then
		instance.Parent = props.Parent
	end

	return instance
end

function UIInstances.corner(radius: UDim?): UICorner
	return UIInstances.create("UICorner", { CornerRadius = radius or Theme.Corner }) :: any
end

function UIInstances.stroke(color: Color3?, transparency: number?, thickness: number?): UIStroke
	return UIInstances.create("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Transparency = transparency or 0.6,
		Thickness = thickness or 1,
	}) :: any
end

function UIInstances.padding(all: number?): UIPadding
	local pixels = UDim.new(0, all or Theme.Padding)
	return UIInstances.create("UIPadding", {
		PaddingTop = pixels,
		PaddingBottom = pixels,
		PaddingLeft = pixels,
		PaddingRight = pixels,
	}) :: any
end

--[[ ScreenGui проекта: не сбрасывается при респавне, масштабируется под
	мобильные устройства (п.16 ТЗ) через UIScale. ]]
function UIInstances.getScreenGui(name: string, displayOrder: number?): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local gui = UIInstances.create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = displayOrder or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}) :: ScreenGui

	local scale = Instance.new("UIScale")
	scale.Parent = gui

	local function updateScale()
		local viewport = gui.AbsoluteSize
		local minDimension = math.min(viewport.X, viewport.Y)
		if minDimension <= MOBILE_MIN_DIMENSION then
			local factor = math.clamp(minDimension / MOBILE_MIN_DIMENSION, 0.75, 1)
			scale.Scale = factor
		else
			scale.Scale = 1
		end
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
	task.defer(updateScale)

	return gui
end

--=== Тосты ======================================================================

local toastGui: ScreenGui? = nil
local toastContainer: Frame? = nil

local function ensureToastHolder()
	if toastGui and toastContainer then
		return
	end

	toastGui = UIInstances.getScreenGui("SPB_Notifications", 60)

	toastContainer = UIInstances.create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(340, 400),
		BackgroundTransparency = 1,
		Parent = toastGui,
	}, {
		UIInstances.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
		}),
	}) :: Frame
end

local TOAST_COLORS = {
	success = Theme.Colors.Success,
	info = Theme.Colors.Accent,
	warning = Theme.Colors.Gold,
	error = Theme.Colors.Danger,
}

function UIInstances.Notify(payload: { Text: string, Kind: string? })
	ensureToastHolder()
	local container = toastContainer :: Frame

	local accent = TOAST_COLORS[payload.Kind or "info"] or Theme.Colors.Accent

	-- П.12 ТЗ: звук только у важных тостов (успех/ошибка), info/warning — тихие.
	local toastSound = if payload.Kind == "success" then "Success" elseif payload.Kind == "error" then "Error" else nil
	if toastSound then
		local sound = uiSound()
		if sound then
			sound.Play(toastSound)
		end
	end

	local toast = UIInstances.create("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Colors.Surface,
		BackgroundTransparency = 0.05,
		LayoutOrder = os.clock() * 1000,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		UIInstances.corner(),
		UIInstances.stroke(),
		UIInstances.create("Frame", {
			Name = "Accent",
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		}, { UIInstances.corner(UDim.new(0, 3)) }),
		UIInstances.create("TextLabel", {
			Name = "Text",
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -22, 1, 0),
			BackgroundTransparency = 1,
			Text = payload.Text,
			TextColor3 = Theme.Colors.Text,
			TextSize = Theme.Sizes.Body,
			Font = Theme.Fonts.Body,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
	toast.Parent = container

	toast.Position = UDim2.fromOffset(40, 0)
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, 0),
	}):Play()

	task.delay(4, function()
		if not toast.Parent then
			return
		end
		local tween = TweenService:Create(toast, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(40, 0),
		})
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

--=== Базовая панель с заголовком и закрытием ======================================

--[[ Возвращает (frame, body) — body это область под заголовком, куда
	кладётся содержимое. Заголовок и кнопка закрытия уже настроены. ]]
function UIInstances.makePanel(
	parent: Instance,
	props: { Title: string, Size: UDim2, Name: string? }
): (Frame, Frame, TextButton)
	local C = Theme.Colors

	local frame = UIInstances.create("Frame", {
		Name = props.Name or "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
		BackgroundColor3 = C.Background,
		BackgroundTransparency = Theme.Colors.BackgroundTransparency,
		Parent = parent,
	}, {
		UIInstances.corner(UDim.new(0, 16)),
		UIInstances.stroke(),
	}) :: Frame

	local _header = UIInstances.create("TextLabel", {
		Name = "Header",
		Size = UDim2.new(1, -64, 0, 48),
		Position = UDim2.fromOffset(20, 0),
		BackgroundTransparency = 1,
		Text = props.Title,
		TextColor3 = C.Text,
		TextSize = Theme.Sizes.Title,
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local _divider = UIInstances.create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, -40, 0, 1),
		Position = UDim2.fromOffset(20, 48),
		BackgroundColor3 = C.Stroke,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Parent = frame,
	})

	local closeButton = UIInstances.create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = C.SurfaceAlt,
		Text = "✕",
		TextColor3 = C.TextDim,
		TextSize = 16,
		Font = Theme.Fonts.Button,
		Parent = frame,
	}, {
		UIInstances.corner(UDim.new(1, 0)),
	}) :: TextButton

	local body = UIInstances.create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 1, -72),
		BackgroundTransparency = 1,
		Parent = frame,
	}) :: Frame

	return frame, body, closeButton
end

-- Стандартная кнопка действия (например, "Купить")
function UIInstances.makeButton(parent: Instance, props: { Text: string, Size: UDim2?, Accent: boolean? }): TextButton
	local C = Theme.Colors
	local button = UIInstances.create("TextButton", {
		Size = props.Size or UDim2.fromOffset(120, 36),
		BackgroundColor3 = if props.Accent then C.Accent else C.SurfaceAlt,
		Text = props.Text,
		TextColor3 = if props.Accent then C.Background else C.Text,
		TextSize = Theme.Sizes.Body,
		Font = Theme.Fonts.Button,
		Parent = parent,
	}, {
		UIInstances.corner(),
	}) :: TextButton

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = if props.Accent
			then C.Accent:Lerp(Color3.new(1, 1, 1), 0.15)
			else C.SurfaceAlt:Lerp(Color3.new(1, 1, 1), 0.1)
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = if props.Accent then C.Accent else C.SurfaceAlt
	end)

	return button
end

return UIInstances
