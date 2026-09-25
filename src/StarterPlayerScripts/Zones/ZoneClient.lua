--!strict
--[[
	ZoneClient.lua — клиентская реакция на смену зоны (п.12.3 ТЗ):
	  * показывает название зоны и эмбиент в HUD;
	  * переключает эмбиент-звук с плавным кроссфейдом;
	  * громкость эмбиента — из настроек профиля (AmbientVolume).

	Все звуки — через SoundGroups: создаём свою группу "Ambient", чтобы
	громкость управлялась централизовано и не смешивалась с музыкой/эффектами.
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Landmarks = require(Shared.Config.Landmarks)

local HUDUI = require(script.Parent.Parent.UI.HUDUI)
local DataClient = require(script.Parent.Parent.Data.DataClient)

local player = Players.LocalPlayer

local FADE_IN = 2.5
local FADE_OUT = 1.5

local ZoneClient = {}

local soundGroup: SoundGroup? = nil
local currentSound: Sound? = nil
local currentAmbientVolume = 1

local function ensureSoundGroup(): SoundGroup
	if soundGroup then
		return soundGroup
	end

	local existing = SoundService:FindFirstChild("Ambient")
	if existing and existing:IsA("SoundGroup") then
		soundGroup = existing
		return existing
	end

	local created = Instance.new("SoundGroup")
	created.Name = "Ambient"
	created.Volume = 1
	created.Parent = SoundService

	soundGroup = created
	return created
end

local function stopCurrentSound()
	if not currentSound then
		return
	end

	local old = currentSound
	currentSound = nil

	local fadeOut = TweenService:Create(old, TweenInfo.new(FADE_OUT), { Volume = 0 })
	fadeOut:Play()
	fadeOut.Completed:Once(function()
		old:Destroy()
	end)
end

local function playAmbient(ambient: any)
	if not ambient or ambient.SoundId == "rbxassetid://0" or ambient.SoundId == "" then
		stopCurrentSound()
		return
	end

	-- Тот же трек уже играет — ничего не перезапускаем
	if currentSound and currentSound.SoundId == ambient.SoundId then
		return
	end

	stopCurrentSound()

	local group = ensureSoundGroup()
	local sound = Instance.new("Sound")
	sound.Name = ("Ambient_%s"):format(ambient.SoundId:gsub("%D", ""):sub(-6))
	sound.SoundId = ambient.SoundId
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = player:WaitForChild("PlayerGui")
	sound:Play()

	currentSound = sound

	local targetVolume = (ambient.Volume or 0.3) * currentAmbientVolume
	TweenService:Create(sound, TweenInfo.new(FADE_IN), { Volume = targetVolume }):Play()
end

local function onZoneChanged(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local zones: { string } = if type(payload.Zones) == "table" then payload.Zones else {}
	local zoneDef = nil
	for _, zoneId in ipairs(zones) do
		zoneDef = Landmarks.GetZone(zoneId)
		if zoneDef then
			break
		end
	end

	HUDUI.SetZone(if zoneDef then zoneDef.DisplayName else "", payload.Ambient or (zoneDef and zoneDef.Ambient))
	playAmbient(payload.Ambient or (zoneDef and zoneDef.Ambient))
end

local function applyVolumeSetting()
	currentAmbientVolume = DataClient.GetSetting("AmbientVolume", 1)

	local group = ensureSoundGroup()
	group.Volume = currentAmbientVolume
end

function ZoneClient.Start()
	Remotes.OnClientEvent(Remotes.Names.ZoneChanged, onZoneChanged)

	DataClient.ProfileChanged:Connect(applyVolumeSetting)
	DataClient.ProfileChanged:Once(function()
		applyVolumeSetting()
	end)

	applyVolumeSetting()
end

return ZoneClient
