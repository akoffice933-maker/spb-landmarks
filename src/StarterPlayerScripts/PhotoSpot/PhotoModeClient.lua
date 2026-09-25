--!strict
--[[
	PhotoModeClient.lua — клиентская часть Photo Spot (п.5.3 ТЗ).

	Поток (см. PhotoSpotService.lua на сервере):
	  1. Сервер проверил, что игрок в зоне, и прислал PhotoSessionStart
	     (название точки, стиль рамки — обычная или VIP);
	  2. Скрываем весь ScreenGui игрока;
	  3. Показываем рамку и (если куплены) фильтры;
	  4. Даём несколько секунд на системный скриншот;
	  5. По нажатию «Готово» (или Esc) возвращаем UI и шлём PhotoCaptured —
	     сервер пишет VisitedLandmarks + PhotoCount.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)
local DeveloperProducts = require(Shared.Config.DeveloperProducts)

local UIInstances = require(script.Parent.Parent.UI.UIInstances)
local DataClient = require(script.Parent.Parent.Data.DataClient)
local UISoundClient = require(script.Parent.Parent.Audio.UISoundClient)

local player = Players.LocalPlayer

local CAPTURE_SECONDS = 3

local PhotoModeClient = {}

local gui: ScreenGui? = nil
local frameOverlay: Frame? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local hiddenGuis: { ScreenGui } = {}

local inSession = false
local currentLandmarkId: string? = nil

local function setHudVisible(visible: boolean)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	if not visible then
		hiddenGuis = {}
		for _, child in ipairs(playerGui:GetChildren()) do
			-- Чистый кадр: прячем всё, кроме самого фоторежима
			if child:IsA("ScreenGui") and child.Enabled and child.Name ~= "SPB_PhotoSpot" then
				table.insert(hiddenGuis, child)
				child.Enabled = false
			end
		end
	else
		for _, child in ipairs(hiddenGuis) do
			if child.Parent then
				child.Enabled = true
			end
		end
		hiddenGuis = {}
	end
end

local function ensureColorCorrection(): ColorCorrectionEffect
	if colorCorrection then
		return colorCorrection
	end
	local created = Instance.new("ColorCorrectionEffect")
	created.Name = "SPB_PhotoFilter"
	created.Parent = Lighting
	colorCorrection = created
	return created
end

local function resetFilter()
	local effect = ensureColorCorrection()
	effect.Saturation = 0
	effect.Contrast = 0
	effect.Brightness = 0
	effect.TintColor = Color3.new(1, 1, 1)
end

local function applyFilter(filterId: string)
	local filter = DeveloperProducts.GetFilter(filterId)
	if not filter then
		return
	end
	local effect = ensureColorCorrection()
	effect.Saturation = filter.Saturation
	effect.Contrast = filter.Contrast
	effect.Brightness = filter.Brightness
	effect.TintColor = filter.TintColor
end

local function endSession(notifyServer: boolean)
	if not inSession then
		return
	end
	inSession = false

	local landmarkId = currentLandmarkId
	currentLandmarkId = nil

	if gui then
		gui.Enabled = false
	end

	setHudVisible(true)
	resetFilter()

	if notifyServer and landmarkId then
		Remotes.FireServer(Remotes.Names.PhotoCaptured, landmarkId)
	end
end

local function buildFrame(frameStyle: any)
	if not gui then
		return
	end

	if frameOverlay then
		frameOverlay:Destroy()
	end

	frameOverlay = UIInstances.create("Frame", {
		Name = "PhotoFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UIInstances.create("UIStroke", {
			Color = frameStyle.Color,
			Transparency = frameStyle.Transparency,
			Thickness = frameStyle.Thickness,
		}),
	}) :: any
end

local function startCountdown(seconds: number, countdownLabel: TextLabel)
	local remaining = seconds
	while remaining >= 0 and inSession do
		if countdownLabel then
			countdownLabel.Text = ("Кадр через %ds"):format(remaining)
		end
		task.wait(1)
		remaining -= 1
	end

	if inSession then
		endSession(true)
	end
end

local function showSession(payload: any)
	if inSession then
		return
	end

	local landmarkId = payload.LandmarkId
	currentLandmarkId = landmarkId

	setHudVisible(false)

	if not gui then
		gui = UIInstances.getScreenGui("SPB_PhotoSpot", 80)
	end

	-- Текст точки и «закрыть»
	local panel = UIInstances.create("Frame", {
		Name = "PhotoUI",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	UIInstances.create("TextLabel", {
		Name = "LandmarkName",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.6, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = payload.DisplayName or "",
		TextColor3 = Theme.Colors.Text,
		TextSize = Theme.Sizes.Title,
		Font = Theme.Fonts.Title,
		Parent = panel,
	})

	-- Бейдж «VIP» для владельцев пасса
	local frameStyle = payload.Frame or Theme.PhotoFrames.Default
	if frameStyle.Label and frameStyle.Label ~= "" then
		local badge = UIInstances.create("TextLabel", {
			Name = "VipBadge",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(70, 26),
			BackgroundColor3 = Theme.Colors.Gold,
			Text = "VIP",
			TextColor3 = Color3.new(0, 0, 0),
			TextSize = 14,
			Font = Theme.Fonts.Title,
			Parent = panel,
		}, {
			UIInstances.corner(UDim.new(0, 6)),
		})
		badge.BackgroundTransparency = 0.1
	end

	-- Блок фильтров (если разблокированы хоть какие-то)
	local filtersRow = UIInstances.create("Frame", {
		Name = "Filters",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(170, 0),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		UIInstances.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	local anyFilter = false
	for index, filterId in ipairs(DeveloperProducts.PackFilters()) do
		if not DataClient.HasFilter(filterId) then
			continue
		end
		anyFilter = true

		local filterDef = DeveloperProducts.GetFilter(filterId)
		local filterButton = UIInstances.makeButton(filtersRow, {
			Text = filterDef.DisplayName,
			Size = UDim2.new(1, 0, 0, 32),
			Accent = false,
		})
		filterButton.LayoutOrder = index
		filterButton.Activated:Connect(function()
			applyFilter(filterId)
		end)
	end

	if anyFilter then
		local resetButton = UIInstances.makeButton(filtersRow, {
			Text = "Без фильтра",
			Size = UDim2.new(1, 0, 0, 32),
			Accent = false,
		})
		resetButton.LayoutOrder = 100
		resetButton.Activated:Connect(resetFilter)
	end

	-- Подсказка и затворах
	UIInstances.create("TextLabel", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -80),
		Size = UDim2.new(0.7, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Интерфейс скрыт — сделайте скриншот средствами устройства",
		TextColor3 = Theme.Colors.TextDim,
		TextSize = Theme.Sizes.Small,
		Font = Theme.Fonts.Body,
		Parent = panel,
	})

	local countdownLabel = UIInstances.create("TextLabel", {
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -46),
		Size = UDim2.new(0.5, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Colors.Gold,
		TextSize = Theme.Sizes.Title,
		Font = Theme.Fonts.Title,
		Parent = panel,
	}) :: any

	-- Кнопка «Готово»
	local doneButton = UIInstances.makeButton(panel, {
		Text = "Снимок готов",
		Size = UDim2.fromOffset(160, 38),
		Accent = true,
	})
	doneButton.AnchorPoint = Vector2.new(0.5, 1)
	doneButton.Position = UDim2.new(0.5, 0, 1, -8)
	doneButton.Activated:Connect(function()
		-- Звук затвора — единственный «громкий» UI-звук по ТЗ (фото = ключевая механика).
		UISoundClient.Play("Shutter")
		endSession(true)
	end)

	-- Кнопка отмены
	local cancelButton = UIInstances.makeButton(panel, {
		Text = "Отмена",
		Size = UDim2.fromOffset(110, 34),
		Accent = false,
	})
	cancelButton.AnchorPoint = Vector2.new(0, 1)
	cancelButton.Position = UDim2.new(0.5, -170, 1, -8)
	cancelButton.Activated:Connect(function()
		endSession(false)
	end)

	-- Рамка поверх всего экрана
	buildFrame(frameStyle)

	-- Esc закрывает без сохранения
	local exitConnection
	exitConnection = UserInputService.InputBegan:Connect(function(input)
		if not inSession then
			exitConnection:Disconnect()
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			endSession(false)
			exitConnection:Disconnect()
		end
	end)

	inSession = true
	gui.Enabled = true

	-- Запуск обратного отсчёта: несколько секунд на кадр
	task.spawn(function()
		startCountdown(CAPTURE_SECONDS, countdownLabel)
	end)
end

function PhotoModeClient.Start()
	Remotes.OnClientEvent(Remotes.Names.PhotoSessionStart, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		showSession(payload)
	end)

	-- Если игрок вышел с сервера — отпускаем сессию
	player.AncestorRemoved:Connect(function()
		endSession(false)
	end)
end

--[[ Для квеста «Охотник за тенями»: серверу нужно знать, в фото-режиме ли
	игрок. Отдаём только флаг — внутреннюю логику сессии не трогаем. ]]
function PhotoModeClient.IsInSession(): boolean
	return inSession
end

return PhotoModeClient
