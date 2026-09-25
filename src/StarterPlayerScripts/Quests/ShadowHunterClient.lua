--!strict
--[[
	ShadowHunterClient.lua — клиент «Охотника за тенями».

	  * Слушает ShadowQuestState и рисует чип «🌘 Тень у …» (статус видна
	    всегда, без дополнитной нагрузки на HUD).
	  * Честно передаёт серверу флаг «я в фото-режиме» (PhotoModeClient).
	  * Кнопка «Сфотографировать Тень» появляется только когда логично:
	    Тень активна, камера открыта, дистанция ≤ 55 стадов.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UIInstances = require(script.Parent.Parent.UI.UIInstances)
local PhotoModeClient = require(script.Parent.Parent.PhotoSpot.PhotoModeClient)

local CAPTURE_DISTANCE_CLIENT = 55 -- отображение кнопки (сервер проверит 48)
local POLL_INTERVAL = 0.5

local ShadowHunterClient = {}

local gui: ScreenGui? = nil
local chip: TextLabel? = nil
local captureButton: TextButton? = nil

local questActive = false
local questLandmark = "…"
local questCaptures = 0
local questRequired = 3
local lastKnownPhotoMode = false
local pollAccum = 0

local function buildGui()
	gui = UIInstances.getScreenGui("SPB_ShadowHunter", 42)

	local label = UIInstances.create("TextLabel", {
		Name = "Chip",
		Size = UDim2.fromOffset(300, 30),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Color3.fromRGB(18, 20, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(190, 200, 235),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Visible = false,
		Parent = gui,
	}, { UIInstances.corner(), UIInstances.stroke(), UIInstances.padding(10) }) :: TextLabel
	chip = label

	local button = UIInstances.create("TextButton", {
		Name = "Capture",
		Size = UDim2.fromOffset(220, 40),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		BackgroundColor3 = Color3.fromRGB(58, 70, 110),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(235, 240, 255),
		Text = "📸 Сфотографировать Тень",
		Visible = false,
		Parent = gui,
	}, { UIInstances.corner(), UIInstances.stroke() }) :: TextButton
	button.MouseButton1Click:Connect(function()
		Remotes.FireServer(Remotes.Names.RequestShadowCapture)
	end)
	captureButton = button
end

local function refreshChip()
	if not chip then
		return
	end
	if not questActive then
		chip.Visible = false
		chip.Text = ""
		return
	end
	chip.Visible = true
	chip.Text = (" 🌘 Тень у «%s»  ·  снимков %d/%d"):format(
		questLandmark,
		questCaptures,
		questRequired
	)
end

local function refreshCaptureButton(player: Player)
	if not captureButton then
		return
	end
	if not questActive or not PhotoModeClient.IsInSession() then
		captureButton.Visible = false
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local shadow = workspace:FindFirstChild("ShadowHunter_Shadow")
	local cloak = if shadow and shadow:IsA("Model") then shadow.PrimaryPart else nil
	if not root or not cloak then
		captureButton.Visible = false
		return
	end
	captureButton.Visible = (root.Position - cloak.Position).Magnitude <= CAPTURE_DISTANCE_CLIENT
end

function ShadowHunterClient.Start()
	local player = Players.LocalPlayer
	buildGui()

	Remotes.OnClientEvent(Remotes.Names.ShadowQuestState, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		questActive = payload.Active == true
		if type(payload.DisplayName) == "string" then
			questLandmark = payload.DisplayName
		end
		if type(payload.Captures) == "number" then
			questCaptures = payload.Captures
		end
		if type(payload.Required) == "number" then
			questRequired = payload.Required
		end
		refreshChip()
	end)

	-- Передача флага фото-режима (только при смене) + кнопка захвата
	RunService.Heartbeat:Connect(function(dt)
		pollAccum += dt
		if pollAccum < POLL_INTERVAL then
			return
		end
		pollAccum = 0

		local inSession = PhotoModeClient.IsInSession()
		if inSession ~= lastKnownPhotoMode then
			lastKnownPhotoMode = inSession
			Remotes.FireServer(Remotes.Names.ShadowHunterState, inSession)
		end
		refreshCaptureButton(player)
	end)
end

-- Текущее число захваченных Теней (нужно панели «Стиль» для тега 🌑)
function ShadowHunterClient.GetCaptures(): number
	return questCaptures
end

function ShadowHunterClient.GetRequired(): number
	return questRequired
end

return ShadowHunterClient
