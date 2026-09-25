--!strict
--[[
	InteriorService.lua — входы/выходы в интерьеры (п.3.1, п.14.1).

	Модель мира:
	  * Интерьер — отдельная модель в Workspace/Interiors/<ZoneId>, построенная
	    вдалеке от открытой карты (так проще держать и освещение, и полигоны);
	  * У здания стоит ДВЕРЬ — BasePart с атрибутом InteriorId (например,
	    "Hermitage") и ProximityPrompt "Войти";
	  * Внутри — зеркальная дверь с атрибутом InteriorExit = true;
	  * Внутренние переходы (подъём на колоннаду, закрытый зал) — части
	    с атрибутом MoveTo = <имя части-точки внутри интерьера>.

	Правило п.14 ТЗ: базовый интерьер БЕСПЛАТЕН. На пропуск «Интерьерный
	пропуск» заводятся только закрытые зоны (атрибут RequiresInteriorPass).
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Landmarks = require(Shared.Config.Landmarks)

local MonetizationController = require(script.Parent.Parent.Monetization.MonetizationController)
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

local INTERIOR_DOOR_TAG = "InteriorDoor"
local TELEPORT_OFFSET_Y = 3.5

local InteriorService = {}

-- Запоминаем, откуда игрок вошёл (чтобы выйти туда же), только в сессии
local returnPositions: { [Player]: { [string]: CFrame } } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.FireClient(Remotes.Names.Notify, player, { Text = text, Kind = kind or "info" })
end

local function getRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart
end

local function teleportTo(player: Player, cframe: CFrame, fadeDuration: number)
	local root = getRootPart(player)
	if not root then
		return false
	end
	root.CFrame = cframe + Vector3.new(0, TELEPORT_OFFSET_Y, 0)
	Remotes.FireClient(Remotes.Names.TeleportFade, player, { Duration = fadeDuration })
	return true
end

--=== Поиск частей интерьера =====================================================

local interiorsFolder: Instance? = nil

local function getInteriorsFolder(): Instance?
	if interiorsFolder then
		return interiorsFolder
	end
	interiorsFolder = workspace:FindFirstChild("Interiors")
	return interiorsFolder
end

local function findInteriorModel(zoneId: string): Instance?
	local folderRoot = getInteriorsFolder()
	if not folderRoot then
		return nil
	end
	return folderRoot:FindFirstChild(zoneId)
end

local function findNamedPart(zoneId: string, partName: string): BasePart?
	local model = findInteriorModel(zoneId)
	if not model then
		return nil
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == partName then
			return descendant
		end
	end
	return nil
end

-- Точка появления игрока в интерьере: часть InteriorSpawn в модели зоны
local function getInteriorSpawn(zoneId: string): BasePart?
	return findNamedPart(zoneId, "InteriorSpawn")
end

--=== Вход / выход / внутренний переход ==========================================

local function enterInterior(player: Player, interiorId: string, requiresPass: boolean)
	local interior = Landmarks.GetInterior(interiorId)
	if not interior then
		return
	end

	if requiresPass and not MonetizationController.HasFeature(player, "InteriorAccess") then
		notify(
			player,
			"Этот зал закрыт — нужен «Интерьерный пропуск»",
			"warning"
		)
		return
	end

	local spawn = getInteriorSpawn(interior.ZoneId)
	if not spawn then
		notify(player, "Зал пока строится — пойдёмте на улицу", "info")
		return
	end

	local root = getRootPart(player)
	if root then
		returnPositions[player] = returnPositions[player] or {}
		returnPositions[player][interiorId] = root.CFrame
	end

	local cframe = CFrame.new(spawn.Position + Vector3.new(0, spawn.Size.Y / 2 + 0.5, 0))
	if teleportTo(player, cframe, 0.7) then
		PlayerDataService.MarkVisited(player, interior.EntryLandmarkId)
	end
end

local function exitInterior(player: Player, zoneId: string)
	local interior: any = nil
	for _, entry in pairs(Landmarks.Interiors) do
		if entry.ZoneId == zoneId then
			interior = entry
			break
		end
	end
	if not interior then
		return
	end

	local capturedReturn = (returnPositions[player] or {})[interior.Id]
	if capturedReturn then
		teleportTo(player, capturedReturn, 0.7)
	else
		-- Мы не помним, откуда вошли (перезаход): выводим к зданию на улицу
		local landmark = Landmarks.Get(interior.EntryLandmarkId)
		if landmark then
			local travelTarget = workspace:FindFirstChild("FastTravel")
				and workspace.FastTravel:FindFirstChild(interior.EntryLandmarkId)
			if travelTarget and travelTarget:IsA("BasePart") then
				teleportTo(player, CFrame.new(travelTarget.Position + Vector3.new(0, 4, 0)), 0.7)
			end
		end
	end
end

local function moveInside(player: Player, zoneId: string, partName: string, requiresPass: boolean)
	if requiresPass and not MonetizationController.HasFeature(player, "InteriorAccess") then
		notify(player, "Зал закрыт — нужен «Интерьерный пропуск»", "warning")
		return
	end

	-- MoveTo ищет часть сначала в указанной зоне интерьера, потом по всем интерьерам
	local target = if zoneId ~= "" then findNamedPart(zoneId, partName) else nil
	if not target then
		local root = getInteriorsFolder()
		if root then
			for _, model in ipairs(root:GetChildren()) do
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant.Name == partName then
						target = descendant
						break
					end
				end
				if target then
					break
				end
			end
		end
	end

	if not target then
		notify(player, "Проход пока недоступен", "info")
		return
	end

	teleportTo(player, CFrame.new(target.Position + Vector3.new(0, target.Size.Y / 2 + 0.5, 0)), 0.5)
end

--=== Двери ======================================================================

local function buildPrompt(part: BasePart, actionText: string, objectText: string): ProximityPrompt
	local existing = part:FindFirstChildWhichIsA("ProximityPrompt")
	if existing then
		return existing
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "InteriorPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part
	return prompt
end

local function setupDoor(part: BasePart)
	local interiorId = part:GetAttribute("InteriorId")
	local isExit = part:GetAttribute("InteriorExit") == true
	local moveTo = part:GetAttribute("MoveTo")
	local requiresPass = part:GetAttribute("RequiresInteriorPass") == true
	local zoneId = part:GetAttribute("InteriorZone") or ""

	if isExit then
		local exitZoneId = zoneId
		if exitZoneId == "" then
			-- попробуем определить по имени части: InteriorExit_Hermitage
			exitZoneId = part.Name:match("^InteriorExit_(.+)$") or ""
		end

		local prompt = buildPrompt(part, "Выйти на улицу", "Выход")
		prompt.Triggered:Connect(function(player: Player)
			exitInterior(player, exitZoneId)
		end)
		return
	end

	if type(moveTo) == "string" and moveTo ~= "" then
		local prompt = buildPrompt(part, "Пройти", "Проход")
		if requiresPass then
			prompt.ObjectText = "Закрытый зал"
		end
		prompt.Triggered:Connect(function(player: Player)
			moveInside(player, zoneId, moveTo, requiresPass)
		end)
		return
	end

	if type(interiorId) == "string" and interiorId ~= "" then
		local interior = Landmarks.GetInterior(interiorId)
		if not interior then
			warn(
				("[InteriorService] Неизвестный InteriorId `%s` на %s"):format(
					interiorId,
					part:GetFullName()
				)
			)
			return
		end

		local prompt = buildPrompt(part, "Войти внутрь", interior.DisplayName)
		if requiresPass then
			prompt.ObjectText = interior.DisplayName .. " (закрыто)"
		end
		prompt.Triggered:Connect(function(player: Player)
			enterInterior(player, interiorId, requiresPass)
		end)
	end
end

function InteriorService.Start()
	-- Двери помечены тегом InteriorDoor (ставится в Bootstrap или вручную)
	for _, part in ipairs(CollectionService:GetTagged(INTERIOR_DOOR_TAG)) do
		if part:IsA("BasePart") then
			setupDoor(part)
		end
	end

	CollectionService:GetInstanceAddedSignal(INTERIOR_DOOR_TAG):Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			setupDoor(instance)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		returnPositions[player] = nil
	end)
end

return InteriorService
