--!strict
--[[
	OnboardingUI.lua — короткий урок из 4 экранов (п.5.5 ТЗ).

	Показывается новому игроку один раз (флаг Settings.OnboardingCompleted),
	можно открыть повторно через иконку помощи в топбаре. Внизу окна —
	подсказка про ближайшую непосещённую достопримечательность.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(Shared.Config.Theme)
local Landmarks = require(Shared.Config.Landmarks)

local UIInstances = require(script.Parent.UIInstances)
local DataClient = require(script.Parent.Parent.Data.DataClient)

local SLIDES: { { Title: string, Body: string } } = {
	{
		Title = "Добро пожаловать в Петербург",
		Body = "Это прогулочная карта: гуляйте, заглядывайте внутрь зданий, изучайте таблички. Никакой цели «выжить» — только город вокруг вас.",
	},
	{
		Title = "Фото-места",
		Body = "Золотые зоны — лучшие точки для снимков. Встаньте на место, нажмите E: интерфейс скроется, а рамка поможет сделать чистый скриншот.",
	},
	{
		Title = "Таблички и история",
		Body = "У каждой достопримечательности есть табличка: короткий текст — бесплатно, расширенные факты — с пропуском «Гид-исследователь».",
	},
	{
		Title = "День и ночь",
		Body = "В городе идёт время: день сменяется закатом, а летом — белыми ночами. Фонари и подсветка включаются автоматически с наступлением темноты.",
	},
}

local OnboardingUI = {}

local gui: ScreenGui? = nil
local slideIndex = 1
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local nextLabel: TextLabel? = nil
local nextButton: TextButton? = nil
local skipButton: TextButton? = nil
local pagesLabel: TextLabel? = nil

local function nextUnvisitedText(): string
	local profile = DataClient.GetProfile()
	local visited = {}
	for _, id in ipairs((profile and profile.VisitedLandmarks) or {}) do
		visited[id] = true
	end
	for _, landmark in ipairs(Landmarks.List()) do
		if not visited[landmark.Id] then
			return ("Первый пункт прогулки: %s"):format(landmark.DisplayName)
		end
	end
	return "Вы обошли все главные места — впечатляет!"
end

local function renderSlide()
	if not gui then
		return
	end
	local slide = SLIDES[slideIndex]

	if titleLabel then
		titleLabel.Text = slide.Title
	end
	if bodyLabel then
		bodyLabel.Text = slide.Body
	end
	if pagesLabel then
		pagesLabel.Text = ("%d / %d"):format(slideIndex, #SLIDES)
	end
	if nextLabel then
		nextLabel.Text = nextUnvisitedText()
	end
	if nextButton then
		nextButton.Text = if slideIndex == #SLIDES then "Начать прогулку" else "Дальше"
	end
end

local function finish()
	if gui then
		gui.Enabled = false
	end
	Remotes.FireServer(Remotes.Names.OnboardingCompleted, {})
end

function OnboardingUI.Show()
	if not gui then
		gui = UIInstances.getScreenGui("SPB_Onboarding", 70)

		local dim = UIInstances.create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.Shadow,
			BackgroundTransparency = 0.4,
			Parent = gui,
		})

		local body: Frame
		local panel: Frame
		panel, body = UIInstances.makePanel(dim :: any, {
			Title = "Короткий инструктаж",
			Size = UDim2.fromOffset(460, 280),
		})

		local closeButton = panel:FindFirstChild("Close")
		if closeButton and closeButton:IsA("TextButton") then
			closeButton.Activated:Connect(finish)
		end

		titleLabel = UIInstances.create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Theme.Colors.Text,
			TextSize = Theme.Sizes.Title,
			Font = Theme.Fonts.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		}) :: any

		bodyLabel = UIInstances.create("TextLabel", {
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 84),
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

		nextLabel = UIInstances.create("TextLabel", {
			Position = UDim2.fromOffset(0, 128),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Gold,
			Text = "",
			TextSize = Theme.Sizes.Small,
			Font = Theme.Fonts.Button,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		}) :: any

		pagesLabel = UIInstances.create("TextLabel", {
			Position = UDim2.new(0, 0, 1, -36),
			Size = UDim2.fromOffset(70, 30),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.TextDim,
			Text = "",
			TextSize = Theme.Sizes.Small,
			Font = Theme.Fonts.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = body,
		}) :: any

		skipButton = UIInstances.makeButton(body, {
			Text = "Пропустить",
			Size = UDim2.fromOffset(130, 34),
			Accent = false,
		})
		skipButton.Position = UDim2.new(0, 76, 1, -38)
		skipButton.Activated:Connect(finish)

		nextButton = UIInstances.makeButton(body, {
			Text = "Дальше",
			Size = UDim2.fromOffset(160, 34),
			Accent = true,
		})
		nextButton.AnchorPoint = Vector2.new(1, 0)
		nextButton.Position = UDim2.new(1, 0, 1, -38)
		nextButton.Activated:Connect(function()
			if slideIndex < #SLIDES then
				slideIndex += 1
				renderSlide()
			else
				finish()
			end
		end)
	end

	slideIndex = 1
	renderSlide()(gui :: ScreenGui).Enabled = true
end

function OnboardingUI.Start()
	-- Авто-показ только новичку: ждём снимок профиля и проверяем флаг
	task.spawn(function()
		local profile = DataClient.WaitForProfile(60)
		if not profile then
			return
		end

		local completed = DataClient.GetSetting("OnboardingCompleted", false)
		if completed == true then
			return
		end

		task.delay(2.5, function()
			OnboardingUI.Show()
		end)
	end)
end

return OnboardingUI
