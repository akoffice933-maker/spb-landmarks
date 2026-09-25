--!strict
--[[
	TeleportFade.lua — плавное затемнение при телепортации (п.8.1: обязательный
	"LoadingScreen" при перемещении между спавнами; здесь — лёгкая версия).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UIInstances = require(script.Parent.UIInstances)

local TeleportFade = {}

local gui: ScreenGui? = nil
local overlay: Frame? = nil

local function ensure()
	if gui then
		return
	end
	gui = UIInstances.getScreenGui("SPB_Fade", 90)
	overlay = UIInstances.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: any
end

function TeleportFade.Flash(duration: number)
	ensure()
	local frame = overlay :: Frame

	frame.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(frame, TweenInfo.new(duration * 0.45), { BackgroundTransparency = 0 })
	local fadeOut = TweenService:Create(frame, TweenInfo.new(duration * 0.55), { BackgroundTransparency = 1 })

	fadeIn:Play()
	fadeIn.Completed:Once(function()
		fadeOut:Play()
	end)
end

function TeleportFade.Start()
	Remotes.OnClientEvent(Remotes.Names.TeleportFade, function(payload: any)
		local duration = type(payload) == "table" and tonumber(payload.Duration) or 0.7
		TeleportFade.Flash(duration)
	end)
end

return TeleportFade
