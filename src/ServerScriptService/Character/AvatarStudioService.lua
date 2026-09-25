--!strict
--[[
	AvatarStudioService.lua — гардероб и позы (v2.0).

	Правила:
	  * RequestWardrobe/RequestPose валидируются на сервере (см. п.10 ТЗ):
	    тип строки, существование пресета, владение пассом для RequiresFeature.
	  * Пресет применяется через HumanoidDescription — без ассетов тона
	    меняются мгновенно и ничего не стоит; ассеты включаются в конфиге.
	  * Поза: кэшируем базовые C0 для каждого мотора R15, применяем
	    Offsets = база * поворот. Остановка проигрываемых анимаций — иначе
	    контроллер анимаций перезапишет C0 на следующем кадре.
	  * Кулдаун на заявки — защита от спама ApplyDescriptionAsync.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Validate = require(Shared.Util.Validate)
local AvatarPresets = require(Shared.Config.AvatarPresets)

local MonetizationController = require(script.Parent.Parent.Monetization.MonetizationController)

local REQUEST_COOLDOWN = 1.0

local AvatarStudioService = {}

local lastRequestAt: { [Player]: number } = {}
-- Базовые C0 и имя активной позы по персонажу
local baseC0ByCharacter: { [Model]: { [string]: CFrame } } = {}
local activePoseByPlayer: { [Player]: string? } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.FireClient(Remotes.Names.Notify, player, { Text = text, Kind = kind or "info" })
end

local function getHumanoid(character: Model?): Humanoid?
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

-- Запоминает базовые C0 всех моторов персонажа (лениво, один раз на спаун)
local function ensureBaseC0(character: Model): { [string]: CFrame }
	local cached = baseC0ByCharacter[character]
	if cached then
		return cached
	end
	local base: { [string]: CFrame } = {}
	for _, inst in character:GetDescendants() do
		if inst:IsA("Motor6D") then
			base[inst.Name] = inst.C0
		end
	end
	baseC0ByCharacter[character] = base
	return base
end

local function resetPose(character: Model)
	local base = ensureBaseC0(character)
	for _, inst in character:GetDescendants() do
		if inst:IsA("Motor6D") and base[inst.Name] then
			inst.C0 = base[inst.Name]
		end
	end
end

local function stopHumanoidAnimations(humanoid: Humanoid?)
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.15)
		end
	end
end

function AvatarStudioService.ApplyOutfit(player: Player, outfit: AvatarPresets.OutfitPreset)
	local character = player.Character
	local humanoid = getHumanoid(character)
	if not character or not humanoid then
		return
	end

	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = outfit.Head
	desc.TorsoColor = outfit.Torso
	desc.LeftArmColor = outfit.LeftArm
	desc.RightArmColor = outfit.RightArm
	desc.LeftLegColor = outfit.LeftLeg
	desc.RightLegColor = outfit.RightLeg

	if outfit.ShirtAssetId then
		desc.Shirt = outfit.ShirtAssetId
	end
	if outfit.PantsAssetId then
		desc.Pants = outfit.PantsAssetId
	end
	if outfit.HatAssetIds then
		local ids = {}
		for _, id in outfit.HatAssetIds do
			table.insert(ids, tostring(id))
		end
		desc.HatAccessory = table.concat(ids, ",")
	end

	-- ApplyDescriptionAsync понадобится, когда появятся реальные ассеты;
	-- без них достаточно мгновенного ApplyDescription.
	local ok = pcall(function()
		if outfit.ShirtAssetId or outfit.PantsAssetId or outfit.HatAssetIds then
			humanoid:ApplyDescriptionAsync(desc, Enum.AssetTypeVerification.Always)
		else
			humanoid:ApplyDescription(desc, Enum.AssetTypeVerification.Always)
		end
	end)
	if not ok then
		warn(("[AvatarStudio] ApplyDescription упал для %s"):format(player.Name))
	end

	-- Смена одежды пересоздаёт риг: сбрасываем кэш баз C0 и активную позу
	if character then
		baseC0ByCharacter[character] = nil
		activePoseByPlayer[player] = nil
	end
end

function AvatarStudioService.ApplyPose(player: Player, pose: AvatarPresets.PosePreset?)
	local character = player.Character
	local humanoid = getHumanoid(character)
	if not character or not humanoid then
		return false
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		notify(player, "Позы работают на риге R15", "warn")
		return false
	end

	stopHumanoidAnimations(humanoid)

	local base = ensureBaseC0(character)
	-- Отката прежней позы не требуется: базовое состояние восстановили раньше
	resetPose(character)

	if pose then
		for motorName, rotation in pose.Offsets do
			for _, inst in character:GetDescendants() do
				if inst:IsA("Motor6D") and inst.Name == motorName and base[inst.Name] then
					inst.C0 = base[inst.Name] * rotation
					break
				end
			end
		end
		activePoseByPlayer[player] = pose.Id
	else
		activePoseByPlayer[player] = nil
	end
	return true
end

local function onRequestWardrobe(player: Player, payload: any)
	if type(payload) ~= "string" or not Validate.String(payload, 40) then
		return
	end
	local now = os.clock()
	if lastRequestAt[player] and now - lastRequestAt[player] < REQUEST_COOLDOWN then
		return
	end
	lastRequestAt[player] = now

	local outfit = AvatarPresets.GetOutfitById(payload)
	if not outfit then
		return
	end
	if outfit.RequiresFeature and not MonetizationController.HasFeature(player, outfit.RequiresFeature) then
		notify(player, ("Этот наряд — за пасс «%s»"):format(outfit.RequiresFeature), "warn")
		return
	end

	AvatarStudioService.ApplyOutfit(player, outfit)
	notify(player, ("Гардероб: %s — %s"):format(outfit.Name, outfit.Desc), "success")
end

local function onRequestPose(player: Player, payload: any)
	if type(payload) ~= "string" or not Validate.String(payload, 40) then
		return
	end
	local now = os.clock()
	if lastRequestAt[player] and now - lastRequestAt[player] < REQUEST_COOLDOWN then
		return
	end
	lastRequestAt[player] = now

	if payload == "Reset" then
		if AvatarStudioService.ApplyPose(player, nil) then
			notify(player, "Поза сброшена", "info")
		end
		return
	end

	local pose = AvatarPresets.GetPoseById(payload)
	if not pose then
		return
	end
	if AvatarStudioService.ApplyPose(player, pose) then
		notify(player, ("Поза: %s"):format(pose.Name), "success")
	end
end

local function onPlayerRemoving(player: Player)
	lastRequestAt[player] = nil
	activePoseByPlayer[player] = nil
end

local function onCharacterAdded(player: Player, character: Model)
	-- Новый спаун: кэш/поза недействительны, персонаж отребликается
	baseC0ByCharacter[character] = nil
	activePoseByPlayer[player] = nil
end

function AvatarStudioService.Start()
	Remotes.OnServerEvent(Remotes.Names.RequestWardrobe, onRequestWardrobe)
	Remotes.OnServerEvent(Remotes.Names.RequestPose, onRequestPose)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
end

return AvatarStudioService
