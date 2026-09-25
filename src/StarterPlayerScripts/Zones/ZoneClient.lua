--!strict
--[[
	ZoneClient.lua — клиентская реакция на смену зоны (п.12.3 ТЗ):
	  * показывает название зоны и звуковой контекст в HUD;
	  * эмбиент по зоне (город/вода/чайки) — SoundGroup "Ambient";
	  * МУЗЫКА В ИНТЕРЬЕРАХ — SoundGroup "Music" (п.12.3), кроссфейдом,
	    с приоритетом над эмбиентом;
	  * громкость каждой группы — отдельно, из настроек профиля
	    (AmbientVolume / MusicVolume, п.5.2).
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

type Channel = {
	Group: SoundGroup?,
	Sound: Sound?,
	Multiplier: number,
	FadeIn: number,
	FadeOut: number,
}

local channels: { [string]: Channel } = {
	Ambient = { Group = nil, Sound = nil, Multiplier = 1, FadeIn = FADE_IN, FadeOut = FADE_OUT },
	Music = { Group = nil, Sound = nil, Multiplier = 0.7, FadeIn = 3.5, FadeOut = 2 },
}

--=== SoundGroups ================================================================

local function ensureGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end

	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Volume = 1
	created.Parent = SoundService
	return created
end

local function channelGroup(channelName: string): SoundGroup
	local channel = channels[channelName]
	if not channel.Group then
		local group = ensureGroup(channelName)
		group.Volume = channel.Multiplier
		channel.Group = group
	end
	return channel.Group :: SoundGroup
end

--=== Управление треками =========================================================

local function stopChannel(channelName: string)
	local channel = channels[channelName]
	if not channel.Sound then
		return
	end

	local old = channel.Sound
	channel.Sound = nil

	local fade = TweenService:Create(old, TweenInfo.new(channel.FadeOut), { Volume = 0 })
	fade:Play()
	fade.Completed:Once(function()
		old:Destroy()
	end)
end

local function playOnChannel(channelName: string, def: any)
	local channel = channels[channelName]

	-- Тот же трек уже играет
	if channel.Sound and channel.Sound.SoundId == def.SoundId then
		return
	end

	stopChannel(channelName)

	if not def or def.SoundId == "" or def.SoundId == "rbxassetid://0" then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = ("%s_%s"):format(channelName, def.SoundId:gsub("%D", ""):sub(-6))
	sound.SoundId = def.SoundId
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = channelGroup(channelName)
	sound.Parent = player:WaitForChild("PlayerGui")
	sound:Play()

	channel.Sound = sound

	local targetVolume = def.Volume or 0.3
	TweenService:Create(sound, TweenInfo.new(channel.FadeIn), { Volume = targetVolume }):Play()
end

--=== Применение настроек ========================================================

local function applyVolumeSettings()
	for _, entry in ipairs({
		{ Name = "Ambient", Key = "AmbientVolume", Fallback = 1 },
		{ Name = "Music", Key = "MusicVolume", Fallback = 0.7 },
	}) do
		local channel = channels[entry.Name]
		channel.Multiplier = DataClient.GetSetting(entry.Key, entry.Fallback)
		local group = channelGroup(entry.Name)
		group.Volume = channel.Multiplier
	end
end

--=== Логика выбора звука ========================================================

--[[ Берём первую зону с музыкой (интерьер); если её нет — первую с эмбиентом.
	Музыка приоритетнее эмбиента (п.12.3: в интерьере музыка, на улице звуки). ]]
local function pickSoundContext(zones: { string }): (any?, any?)
	local musicDef = nil
	local ambientDef = nil

	for _, zoneId in ipairs(zones) do
		local zoneDef = Landmarks.GetZone(zoneId)
		if zoneDef then
			if not musicDef and zoneDef.Music then
				musicDef = zoneDef.Music
			end
			if not ambientDef and zoneDef.Ambient then
				ambientDef = zoneDef.Ambient
			end
		end
	end

	return musicDef, ambientDef
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

	local musicDef, ambientDef = pickSoundContext(zones)

	if musicDef then
		playOnChannel("Music", musicDef)
		stopChannel("Ambient")
	else
		stopChannel("Music")
		playOnChannel("Ambient", ambientDef)
	end

	-- HUD показывает активный контекст (музыка важнее)
	local shownDef = musicDef or ambientDef
	HUDUI.SetZone(if zoneDef then zoneDef.DisplayName else "", shownDef)
end

function ZoneClient.Start()
	Remotes.OnClientEvent(Remotes.Names.ZoneChanged, onZoneChanged)

	DataClient.ProfileChanged:Connect(applyVolumeSettings)
	DataClient.ProfileChanged:Once(applyVolumeSettings)

	applyVolumeSettings()
end

return ZoneClient
