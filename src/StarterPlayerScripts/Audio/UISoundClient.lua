--!strict
--[[
	UISoundClient.lua — звуки интерфейса (п.12 ТЗ: тихие, ненавязчивые UI-звуки).

	Единый SoundGroup "SPB_UI" в SoundService; громкость = настройка UIVolume
	(профиль, п.5.2). SettingsUI пишет значение на сервер, снапшот профиля
	приходит обратно, DataClient.ProfileChanged применяет громкость на лету —
	рестарт клиента не нужен.

	Звуки — встроенные в движок (rbxasset://sounds/*), чтобы этап не зависел
	от загрузки внешних ассетов. Когда появятся собственные sfx, замените id
	в таблице SOUNDS — остальной код не трогайте.

	Автоподключение: любой GuiButton, появившийся в PlayerGui, получает звук
	Click на Activated. Проводки в каждом UI-файле не требуется. Особые
	события (затвор фото, тосты-ошибки) — через UISoundClient.Play(name).
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local DataClient = require(script.Parent.Parent.Data.DataClient)

type SoundDef = { Id: string, Volume: number, PlaybackSpeed: number? }

local UISoundClient = {}

-- Имя -> встроенный звук движка. Volumes — относительные (внутри канала).
local SOUNDS: { [string]: SoundDef } = {
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.6 },
	Open = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.5 },
	Close = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.5 },
	Shutter = { Id = "rbxasset://sounds/flashbulb.wav", Volume = 0.8 },
	Success = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5 },
	Error = { Id = "rbxasset://sounds/alert.mp3", Volume = 0.5 },
}

local FALLBACK_VOLUME = 0.8
local HOOK_ATTRIBUTE = "SPB_SoundHooked"

local group: SoundGroup? = nil
local instances: { [string]: Sound } = {}

local function ensureGroup(): SoundGroup
	if group and group.Parent then
		return group :: SoundGroup
	end

	local existing = SoundService:FindFirstChild("SPB_UI")
	if existing and existing:IsA("SoundGroup") then
		group = existing
		return existing
	end

	local created = Instance.new("SoundGroup")
	created.Name = "SPB_UI"
	created.Volume = DataClient.GetSetting("UIVolume", FALLBACK_VOLUME)
	created.Parent = SoundService
	group = created
	return created
end

local function ensureSoundInstance(name: string): Sound?
	local existing = instances[name]
	if existing then
		return existing
	end

	local def = SOUNDS[name]
	if not def then
		warn(("[UISoundClient] неизвестный звук: %s"):format(name))
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = ("UISound_%s"):format(name)
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.PlaybackSpeed or 1
	sound.Looped = false
	sound.SoundGroup = ensureGroup()
	-- SoundGroup живёт внутри SoundService, поэтому потомки воспроизводятся.
	sound.Parent = sound.SoundGroup
	instances[name] = sound
	return sound
end

local function applyVolume()
	local grp = ensureGroup()
	grp.Volume = math.clamp(DataClient.GetSetting("UIVolume", FALLBACK_VOLUME), 0, 1)
end

function UISoundClient.Play(name: string)
	local sound = ensureSoundInstance(name)
	if sound then
		-- Play() у Sound перезапускает воспроизведение — для быстрых кликов это
		-- нормально (каждый клик слышен даже при спаме).
		sound:Play()
	end
end

local function hookButton(button: GuiButton)
	if button:GetAttribute(HOOK_ATTRIBUTE) then
		return
	end
	button:SetAttribute(HOOK_ATTRIBUTE, true)
	button.Activated:Connect(function()
		UISoundClient.Play("Click")
	end)
end

local function hookExisting(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") then
			hookButton(descendant)
		end
	end
end

function UISoundClient.Start()
	ensureGroup()
	-- Пресоздаём клик, чтобы первый клик не ждал инстанцирования.
	ensureSoundInstance("Click")
	applyVolume()
	DataClient.ProfileChanged:Connect(applyVolume)

	local playerGui = player:WaitForChild("PlayerGui")
	hookExisting(playerGui)
	playerGui.DescendantAdded:Connect(function(instance)
		if instance:IsA("GuiButton") then
			hookButton(instance)
		end
	end)
end

return UISoundClient
