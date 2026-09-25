--!strict
--[[
	BootstrapProject.server.lua — генератор блокаута карты (этап 1–2 ТЗ).

	Назначение: собрать РАБОЧИЙ каркас проекта до прихода художников:
	  * Workspace/Map/Zones — большие прозрачные части-границы зон (ZonePlus);
	  * Workspace/Buildings — примитивные силуэты главных зданий;
	  * Workspace/Spawns, FastTravel, PhotoSpots, InfoBoards;
	  * фонари (тег Lamp), подсветка зданий (тег BuildingLight), скамейки (тег Seat).

	Все объекты — временные. Когда появится настоящая модель карты, этот
	скрипт отключается (BOOTSTRAP_ENABLED = false) или удаляется.
]]

local CollectionService = game:GetService("CollectionService")

-- Включить бутстрап. В проде/при наличии настоящей карты выключите.
local BOOTSTRAP_ENABLED = true
local BOOTSTRAP_FOLDER_NAME = "SPB_Bootstrap"

if not BOOTSTRAP_ENABLED then
	return
end

-- Не пересоздаём карту при повторном запуске в той же Studio-сессии
if workspace:FindFirstChild(BOOTSTRAP_FOLDER_NAME) then
	return
end

local marker = Instance.new("Folder")
marker.Name = BOOTSTRAP_FOLDER_NAME
marker.Parent = workspace

--=== Помощники ===================================================================

type PartProps = {
	Name: string?,
	Size: Vector3,
	Position: Vector3,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Anchored: boolean?,
	Parent: Instance?,
	Shape: Enum.PartType?,
}

local function makePart(props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(150, 150, 150)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.CanCollide = props.CanCollide ~= false
	part.Anchored = if props.Anchored == nil then true else props.Anchored
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = props.Parent or marker
	return part
end

local function folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or marker
	return f
end

local function fullBounds(size: Vector3, center: Vector3, name: string, parent: Instance): Part
	local part = makePart({
		Name = name,
		Size = size,
		Position = center + Vector3.new(0, size.Y / 2, 0),
		Color = Color3.fromRGB(255, 220, 120),
		Material = Enum.Material.ForceField,
		Transparency = 0.85,
		CanCollide = false,
		Parent = parent,
	})
	part.CastShadow = false
	return part
end

--=== Корневая структура Workspace (п.6 ТЗ) =======================================

-- Workspace/Map/Zones, Buildings, Props, Water; Spawns; PhotoSpots; InfoBoards; FastTravel
local mapFolder = workspace:FindFirstChild("Map") or folder("Map", workspace)
local zonesFolder = mapFolder:FindFirstChild("Zones") or folder("Zones", mapFolder)
local buildingsFolder = mapFolder:FindFirstChild("Buildings") or folder("Buildings", mapFolder)
local propsFolder = mapFolder:FindFirstChild("Props") or folder("Props", mapFolder)
local waterFolder = mapFolder:FindFirstChild("Water") or folder("Water", mapFolder)

local spawnsFolder = workspace:FindFirstChild("Spawns") or folder("Spawns", workspace)
local photoSpotsFolder = workspace:FindFirstChild("PhotoSpots") or folder("PhotoSpots", workspace)
local infoBoardsFolder = workspace:FindFirstChild("InfoBoards") or folder("InfoBoards", workspace)
local fastTravelFolder = workspace:FindFirstChild("FastTravel") or folder("FastTravel", workspace)

--=== Зоны (п.2, п.6) =============================================================
-- Центры/размеры — приближение схемы ТЗ п.2.1 к плоской сетке.

local ZONE_LAYOUT = {
	Dvortsovaya = {
		Center = Vector3.new(0, 0, 0),
		Size = Vector3.new(300, 60, 300),
		Color = Color3.fromRGB(240, 220, 140),
	},
	Nevsky = {
		Center = Vector3.new(430, 0, 10),
		Size = Vector3.new(560, 50, 120),
		Color = Color3.fromRGB(255, 180, 120),
	},
	Isaakievskaya = {
		Center = Vector3.new(-160, 0, 240),
		Size = Vector3.new(220, 60, 220),
		Color = Color3.fromRGB(160, 220, 255),
	},
	SpasNaKrovi = {
		Center = Vector3.new(760, 0, 60),
		Size = Vector3.new(220, 60, 220),
		Color = Color3.fromRGB(255, 150, 150),
	},
	Petropavlovka = {
		Center = Vector3.new(-160, 0, -620),
		Size = Vector3.new(320, 60, 280),
		Color = Color3.fromRGB(190, 190, 255),
	},
	Naberezhnaya = {
		Center = Vector3.new(0, 0, -250),
		Size = Vector3.new(700, 40, 140),
		Color = Color3.fromRGB(120, 200, 255),
	},
	MednyyVsadnik = {
		Center = Vector3.new(-220, 0, -120),
		Size = Vector3.new(160, 40, 160),
		Color = Color3.fromRGB(220, 200, 255),
	},
}

for zoneId, layout in pairs(ZONE_LAYOUT) do
	local holder = zonesFolder:FindFirstChild(zoneId) or folder(zoneId, zonesFolder)
	if #holder:GetChildren() == 0 then
		local part = fullBounds(layout.Size, layout.Center, zoneId .. "_Volume", holder)
		if part.Color ~= layout.Color then
			part.Color = layout.Color
		end
	end
end

--=== Земля и вода ================================================================

if not workspace:FindFirstChild("SPB_Ground") then
	local ground = makePart({
		Name = "SPB_Ground",
		Size = Vector3.new(2000, 4, 1800),
		Position = Vector3.new(100, -2, -200),
		Color = Color3.fromRGB(90, 95, 100),
		Material = Enum.Material.Basalt,
		Parent = marker,
	})
	ground.Locked = true
end

if #waterFolder:GetChildren() == 0 then
	local water = makePart({
		Name = "Neva",
		Size = Vector3.new(1400, 2, 220),
		Position = Vector3.new(100, -1, -470),
		Color = Color3.fromRGB(40, 80, 120),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
		Parent = waterFolder,
	})
	water.Locked = true
end

--=== Здания (силуэты, этап 2) ====================================================
-- Примитивные «макеты» под полигоны заменятся. Сейчас — узнаваемые силуэты
-- и подходящая подсветка (не более 1–2 источников на здание, п.4.4).

local function addBuildingLight(part: BasePart, face: Enum.NormalId, range: number)
	if part:FindFirstChildWhichIsA("Light") then
		return
	end
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Range = range
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 230, 170)
	light.Enabled = false
	light.Parent = part
	CollectionService:AddTag(part, "BuildingLight")
end

-- Эрмитаж (Зимний дворец)
if not buildingsFolder:FindFirstChild("Building_Hermitage") then
	local model = Instance.new("Model")
	model.Name = "Building_Hermitage"
	model.Parent = buildingsFolder

	local base = makePart({
		Name = "Hermitage_Facade",
		Size = Vector3.new(220, 30, 90),
		Position = Vector3.new(0, 15, -60),
		Color = Color3.fromRGB(150, 170, 155),
		Material = Enum.Material.Pebble,
		Parent = model,
	})
	addBuildingLight(base, Enum.NormalId.Front, 70)

	local _roof = makePart({
		Name = "Hermitage_Roof",
		Size = Vector3.new(222, 6, 92),
		Position = Vector3.new(0, 33, -60),
		Color = Color3.fromRGB(190, 190, 190),
		Parent = model,
	})
	model.PrimaryPart = base
end

-- Александровская колонна (цилиндр-аппроксимация)
if not buildingsFolder:FindFirstChild("Building_Alexandrovskaya") then
	local model = Instance.new("Model")
	model.Name = "Building_Alexandrovskaya"
	model.Parent = buildingsFolder

	makePart({
		Name = "Column_Pedestal",
		Size = Vector3.new(6, 4, 6),
		Position = Vector3.new(0, 2, 0),
		Color = Color3.fromRGB(140, 140, 140),
		Parent = model,
	})
	local column = makePart({
		Name = "Column_Shaft",
		Size = Vector3.new(4, 46, 4),
		Position = Vector3.new(0, 25, 0),
		Color = Color3.fromRGB(120, 60, 60),
		Material = Enum.Material.Marble,
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})
	column.Orientation = Vector3.new(0, 0, 90)
	makePart({
		Name = "Column_Angel",
		Size = Vector3.new(4, 6, 4),
		Position = Vector3.new(0, 51, 0),
		Color = Color3.fromRGB(200, 180, 120),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		Parent = model,
	})
	addBuildingLight(column, Enum.NormalId.Front, 40)
end

-- Исаакиевский собор
if not buildingsFolder:FindFirstChild("Building_Isaakiy") then
	local model = Instance.new("Model")
	model.Name = "Building_Isaakiy"
	model.Parent = buildingsFolder

	local base = makePart({
		Name = "Isaakiy_Base",
		Size = Vector3.new(110, 30, 110),
		Position = Vector3.new(-160, 15, 240),
		Color = Color3.fromRGB(180, 170, 150),
		Parent = model,
	})
	local _drum = makePart({
		Name = "Isaakiy_Drum",
		Size = Vector3.new(40, 30, 40),
		Position = Vector3.new(-160, 45, 240),
		Color = Color3.fromRGB(170, 160, 140),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local dome = makePart({
		Name = "Isaakiy_Dome",
		Size = Vector3.new(44, 44, 44),
		Position = Vector3.new(-160, 70, 240),
		Color = Color3.fromRGB(190, 150, 60),
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Ball,
		Parent = model,
	})
	makePart({
		Name = "Isaakiy_Spire",
		Size = Vector3.new(3, 50, 3),
		Position = Vector3.new(-160, 95, 240),
		Color = Color3.fromRGB(210, 180, 80),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	addBuildingLight(base, Enum.NormalId.Front, 60)
	addBuildingLight(dome, Enum.NormalId.Front, 50)
	model.PrimaryPart = base
end

-- Спас на Крови
if not buildingsFolder:FindFirstChild("Building_Spas") then
	local model = Instance.new("Model")
	model.Name = "Building_Spas"
	model.Parent = buildingsFolder

	local base = makePart({
		Name = "Spas_Base",
		Size = Vector3.new(70, 40, 70),
		Position = Vector3.new(760, 20, 60),
		Color = Color3.fromRGB(160, 120, 100),
		Parent = model,
	})
	makePart({
		Name = "Spas_Drum",
		Size = Vector3.new(28, 26, 28),
		Position = Vector3.new(760, 53, 60),
		Color = Color3.fromRGB(170, 100, 80),
		Parent = model,
	})
	makePart({
		Name = "Spas_Dome_1",
		Size = Vector3.new(26, 26, 26),
		Position = Vector3.new(760, 66, 60),
		Color = Color3.fromRGB(220, 190, 90),
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Ball,
		Parent = model,
	})
	makePart({
		Name = "Spas_Dome_2",
		Size = Vector3.new(14, 14, 14),
		Position = Vector3.new(738, 48, 40),
		Color = Color3.fromRGB(90, 130, 200),
		Shape = Enum.PartType.Ball,
		Parent = model,
	})
	makePart({
		Name = "Spas_Dome_3",
		Size = Vector3.new(14, 14, 14),
		Position = Vector3.new(782, 48, 80),
		Color = Color3.fromRGB(200, 120, 60),
		Shape = Enum.PartType.Ball,
		Parent = model,
	})
	addBuildingLight(base, Enum.NormalId.Front, 55)
	model.PrimaryPart = base
end

-- Казанский собор (фасад + колоннада)
if not buildingsFolder:FindFirstChild("Building_Kazansky") then
	local model = Instance.new("Model")
	model.Name = "Building_Kazansky"
	model.Parent = buildingsFolder

	local facade = makePart({
		Name = "Kazansky_Facade",
		Size = Vector3.new(90, 26, 24),
		Position = Vector3.new(430, 13, 66),
		Color = Color3.fromRGB(170, 165, 155),
		Parent = model,
	})
	for i = -3, 3 do
		local col = makePart({
			Name = ("Kazansky_Column_%d"):format(i + 4),
			Size = Vector3.new(4, 20, 4),
			Position = Vector3.new(430 + i * 9, 10, 52),
			Color = Color3.fromRGB(190, 185, 170),
			Material = Enum.Material.Marble,
			Shape = Enum.PartType.Cylinder,
			Parent = model,
		})
		col.Orientation = Vector3.new(0, 0, 90)
	end
	addBuildingLight(facade, Enum.NormalId.Front, 50)
	model.PrimaryPart = facade
end

-- Петропавловский собор (шпиль — доминанта карты, п.12.1)
if not buildingsFolder:FindFirstChild("Building_Petropavlovsky") then
	local model = Instance.new("Model")
	model.Name = "Building_Petropavlovsky"
	model.Parent = buildingsFolder

	local base = makePart({
		Name = "Petr_Cathedral_Base",
		Size = Vector3.new(50, 26, 50),
		Position = Vector3.new(-160, 13, -620),
		Color = Color3.fromRGB(200, 190, 170),
		Parent = model,
	})
	makePart({
		Name = "Petr_Cathedral_Spire",
		Size = Vector3.new(8, 100, 8),
		Position = Vector3.new(-160, 76, -620),
		Color = Color3.fromRGB(215, 185, 90),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	makePart({
		Name = "Petr_Cathedral_Tip",
		Size = Vector3.new(2, 14, 2),
		Position = Vector3.new(-160, 133, -620),
		Color = Color3.fromRGB(240, 220, 120),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	addBuildingLight(base, Enum.NormalId.Front, 70)
	model.PrimaryPart = base

	-- Стены крепости (квадрат)
	local wallColor = Color3.fromRGB(150, 145, 135)
	-- Северная стена разбита на два пролёта: в центре (x=-130) широкий проём
	-- под Северные ворота / Дворцовый мост (см. BootstrapArtPass).
	makePart({
		Name = "Fortress_Wall_NW",
		Size = Vector3.new(158, 10, 6),
		Position = Vector3.new(-221, 5, -480),
		Color = wallColor,
		Parent = buildingsFolder,
	})
	makePart({
		Name = "Fortress_Wall_NE",
		Size = Vector3.new(98, 10, 6),
		Position = Vector3.new(-69, 5, -480),
		Color = wallColor,
		Parent = buildingsFolder,
	})
	makePart({
		Name = "Fortress_Wall_S",
		Size = Vector3.new(280, 10, 6),
		Position = Vector3.new(-160, 5, -760),
		Color = wallColor,
		Parent = buildingsFolder,
	})
	makePart({
		Name = "Fortress_Wall_W",
		Size = Vector3.new(6, 10, 280),
		Position = Vector3.new(-300, 5, -620),
		Color = wallColor,
		Parent = buildingsFolder,
	})
	makePart({
		Name = "Fortress_Wall_E",
		Size = Vector3.new(6, 10, 280),
		Position = Vector3.new(-20, 5, -620),
		Color = wallColor,
		Parent = buildingsFolder,
	})
end

-- Медный всадник (памятник + постамент) — малый, но знаковый (п.12.1)
if not buildingsFolder:FindFirstChild("Building_MednyyVsadnik") then
	local model = Instance.new("Model")
	model.Name = "Building_MednyyVsadnik"
	model.Parent = buildingsFolder

	local pedestal = makePart({
		Name = "Vsadnik_Pedestal",
		Size = Vector3.new(14, 8, 20),
		Position = Vector3.new(-220, 4, -120),
		Color = Color3.fromRGB(130, 110, 90),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local _horse = makePart({
		Name = "Vsadnik_Horse",
		Size = Vector3.new(6, 12, 14),
		Position = Vector3.new(-220, 14, -120),
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	addBuildingLight(pedestal, Enum.NormalId.Front, 22)
	model.PrimaryPart = pedestal
end

-- Арка Главного штаба
if not buildingsFolder:FindFirstChild("Building_GeneralStaff") then
	local model = Instance.new("Model")
	model.Name = "Building_GeneralStaff"
	model.Parent = buildingsFolder

	local archLeft = makePart({
		Name = "Staff_Arch_L",
		Size = Vector3.new(30, 26, 16),
		Position = Vector3.new(-50, 13, 120),
		Color = Color3.fromRGB(200, 195, 185),
		Parent = model,
	})
	local archRight = makePart({
		Name = "Staff_Arch_R",
		Size = Vector3.new(30, 26, 16),
		Position = Vector3.new(50, 13, 120),
		Color = Color3.fromRGB(200, 195, 185),
		Parent = model,
	})
	makePart({
		Name = "Staff_Arch_Top",
		Size = Vector3.new(110, 10, 16),
		Position = Vector3.new(0, 31, 120),
		Color = Color3.fromRGB(200, 195, 185),
		Parent = model,
	})
	addBuildingLight(archLeft, Enum.NormalId.Front, 40)
	addBuildingLight(archRight, Enum.NormalId.Front, 40)
	model.PrimaryPart = archLeft
end

--=== Скамейки (Seat) =============================================================

local BENCH_POSITIONS = {
	Dvortsovaya = { Vector3.new(20, 0, 60), Vector3.new(-40, 0, 80) },
	Nevsky = {
		Vector3.new(200, 0, 30),
		Vector3.new(300, 0, -20),
		Vector3.new(400, 0, 40),
		Vector3.new(500, 0, -15),
		Vector3.new(620, 0, 10),
	},
	Isaakievskaya = { Vector3.new(-140, 0, 200), Vector3.new(-180, 0, 280) },
	SpasNaKrovi = { Vector3.new(730, 0, 40), Vector3.new(790, 0, 80) },
	Petropavlovka = { Vector3.new(-140, 0, -600), Vector3.new(-180, 0, -640) },
	Naberezhnaya = { Vector3.new(-100, 0, -200), Vector3.new(0, 0, -220), Vector3.new(100, 0, -240) },
	MednyyVsadnik = { Vector3.new(-200, 0, -100), Vector3.new(-240, 0, -140) },
}

for zoneId, positions in pairs(BENCH_POSITIONS) do
	for index, position in ipairs(positions) do
		local name = ("Bench_%s_%02d"):format(zoneId, index)
		if propsFolder:FindFirstChild(name) then
			continue
		end

		local model = Instance.new("Model")
		model.Name = name
		model.Parent = propsFolder

		local seatInstance = Instance.new("Seat")
		seatInstance.Name = "Seat"
		seatInstance.Size = Vector3.new(6, 2, 2)
		seatInstance.Position = position + Vector3.new(0, 1.8, 0)
		seatInstance.Color = Color3.fromRGB(110, 75, 55)
		seatInstance.Material = Enum.Material.Fabric
		seatInstance.Anchored = true
		seatInstance.Parent = model
		CollectionService:AddTag(seatInstance, "Seat")

		makePart({
			Name = "Back",
			Size = Vector3.new(6, 2, 0.5),
			Position = position + Vector3.new(0, 3.2, -0.9),
			Color = Color3.fromRGB(70, 45, 35),
			Parent = model,
		})
		makePart({
			Name = "Leg_L",
			Size = Vector3.new(0.4, 1.8, 0.4),
			Position = position + Vector3.new(-2.5, 0.9, 0),
			Color = Color3.fromRGB(30, 30, 30),
			Parent = model,
		})
		makePart({
			Name = "Leg_R",
			Size = Vector3.new(0.4, 1.8, 0.4),
			Position = position + Vector3.new(2.5, 0.9, 0),
			Color = Color3.fromRGB(30, 30, 30),
			Parent = model,
		})

		model.PrimaryPart = seatInstance
	end
end

--=== Фонари (Lamp) ===============================================================
-- Схема по п.4.2: свет включается по ClockTime (19.0–6.0). Источник один на
-- фонарь (PointLight внутри прожектора), свечение — через дочерний Neon-шар
-- с именем Glow (управляется LightingController).

local LAMP_POSITIONS = {
	Dvortsovaya = { Vector3.new(-60, 0, -20), Vector3.new(60, 0, 20) },
	Nevsky = {
		Vector3.new(150, 0, 0),
		Vector3.new(250, 0, 20),
		Vector3.new(350, 0, -10),
		Vector3.new(450, 0, 30),
		Vector3.new(550, 0, 0),
		Vector3.new(650, 0, 20),
		Vector3.new(750, 0, -20),
	},
	Isaakievskaya = { Vector3.new(-140, 0, 220), Vector3.new(-180, 0, 260) },
	SpasNaKrovi = { Vector3.new(720, 0, 30), Vector3.new(800, 0, 90) },
	Petropavlovka = { Vector3.new(-130, 0, -580), Vector3.new(-190, 0, -660) },
	Naberezhnaya = {
		Vector3.new(-150, 0, -180),
		Vector3.new(-50, 0, -210),
		Vector3.new(50, 0, -230),
		Vector3.new(150, 0, -250),
	},
	MednyyVsadnik = { Vector3.new(-200, 0, -90), Vector3.new(-240, 0, -150) },
}

for zoneId, positions in pairs(LAMP_POSITIONS) do
	for index, position in ipairs(positions) do
		local name = ("Lamp_%s_%02d"):format(zoneId, index)
		if propsFolder:FindFirstChild(name) then
			continue
		end

		local model = Instance.new("Model")
		model.Name = name
		model.Parent = propsFolder

		local pole = makePart({
			Name = "Lamp_Pole",
			Size = Vector3.new(0.6, 9, 0.6),
			Position = position + Vector3.new(0, 4.5, 0),
			Color = Color3.fromRGB(40, 40, 45),
			Material = Enum.Material.Metal,
			Parent = model,
		})
		local head = makePart({
			Name = "Lamp_Head",
			Size = Vector3.new(2.4, 1.6, 2.4),
			Position = position + Vector3.new(0, 9.8, 0),
			Color = Color3.fromRGB(30, 30, 35),
			Material = Enum.Material.Metal,
			Parent = model,
		})

		local glow = makePart({
			Name = "Glow",
			Size = Vector3.new(1.2, 1.2, 1.2),
			Position = position + Vector3.new(0, 9.6, 0),
			Color = Color3.fromRGB(255, 230, 160),
			Material = Enum.Material.Glass,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = model,
		})
		glow.CastShadow = false

		local pointLight = Instance.new("PointLight")
		pointLight.Name = "Light"
		pointLight.Range = 26
		pointLight.Brightness = 1.4
		pointLight.Color = Color3.fromRGB(255, 225, 160)
		pointLight.Enabled = false
		pointLight.Parent = head

		CollectionService:AddTag(model, "Lamp")
		model.PrimaryPart = pole
	end
end

--=== Photo Spots ================================================================

local PHOTO_SPOTS = {
	Hermitage = Vector3.new(0, 0, 40),
	AlexandrovskayaColumn = Vector3.new(20, 0, 10),
	Dvortsovaya = Vector3.new(0, 0, 80),
	Nevsky = Vector3.new(300, 0, 20),
	Kazansky = Vector3.new(430, 0, 40),
	SpasNaKrovi = Vector3.new(700, 0, 40),
	Isaakiy = Vector3.new(-140, 0, 180),
	MednyyVsadnik = Vector3.new(-190, 0, -100),
	Petropavlovka = Vector3.new(-120, 0, -560),
	PetropavlovskySobor = Vector3.new(-150, 0, -580),
	Naberezhnaya = Vector3.new(0, 0, -200),
}

for landmarkId, position in pairs(PHOTO_SPOTS) do
	local name = ("PhotoSpot_%s"):format(landmarkId)
	if photoSpotsFolder:FindFirstChild(name) then
		continue
	end

	local spot = makePart({
		Name = name,
		Size = Vector3.new(16, 1, 16),
		Position = position,
		Color = Color3.fromRGB(255, 220, 120),
		Material = Enum.Material.ForceField,
		Transparency = 0.5,
		CanCollide = false,
		Parent = photoSpotsFolder,
	})
	spot:SetAttribute("LandmarkId", landmarkId)
	spot.CastShadow = false
end

--=== Info Boards (InfoBoard) ======================================================

-- Тексты подтянуты из Shared/Config/Landmarks.lua; здесь только места на карте.
local INFO_BOARDS = {
	Hermitage = { Position = Vector3.new(60, 0, -30), InfoId = "Hermitage" },
	Dvortsovaya = { Position = Vector3.new(-40, 0, 20), InfoId = "Dvortsovaya" },
	AlexandrovskayaColumn = { Position = Vector3.new(20, 0, 20), InfoId = "AlexandrovskayaColumn" },
	Nevsky_01 = { Position = Vector3.new(280, 0, 15), InfoId = "Nevsky_01" },
	Nevsky = { Position = Vector3.new(350, 0, -5), InfoId = "Nevsky" },
	Kazansky = { Position = Vector3.new(430, 0, 45), InfoId = "Kazansky" },
	SpasNaKrovi = { Position = Vector3.new(740, 0, 45), InfoId = "SpasNaKrovi" },
	Isaakiy = { Position = Vector3.new(-160, 0, 200), InfoId = "Isaakiy" },
	MednyyVsadnik = { Position = Vector3.new(-205, 0, -110), InfoId = "MednyyVsadnik" },
	Petropavlovka_01 = { Position = Vector3.new(-135, 0, -585), InfoId = "Petropavlovka_01" },
	Petropavlovka = { Position = Vector3.new(-150, 0, -600), InfoId = "Petropavlovka" },
	Naberezhnaya_01 = { Position = Vector3.new(20, 0, -205), InfoId = "Naberezhnaya_01" },
	Naberezhnaya = { Position = Vector3.new(-50, 0, -220), InfoId = "Naberezhnaya" },
}

for name, layout in pairs(INFO_BOARDS) do
	local fullName = ("InfoBoard_%s"):format(name)
	if infoBoardsFolder:FindFirstChild(fullName) then
		continue
	end

	local board = makePart({
		Name = fullName,
		Size = Vector3.new(6, 8, 1),
		Position = layout.Position + Vector3.new(0, 4, 0),
		Color = Color3.fromRGB(30, 40, 50),
		Material = Enum.Material.DiamondPlate,
		Parent = infoBoardsFolder,
	})
	board:SetAttribute("InfoId", layout.InfoId)
	CollectionService:AddTag(board, "InfoBoard")
end

--=== Spawns =======================================================================

local SPAWN_POSITIONS = {
	Dvortsovaya = Vector3.new(0, 0, 100),
	Nevsky = Vector3.new(250, 0, 10),
	Petropavlovka = Vector3.new(-160, 0, -500),
}

for spawnId, position in pairs(SPAWN_POSITIONS) do
	local name = ("Spawn_%s"):format(spawnId)
	if spawnsFolder:FindFirstChild(name) then
		continue
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn:SetAttribute("SpawnId", spawnId)
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = true
	spawn.Size = Vector3.new(14, 2, 14)
	spawn.Position = position
	spawn.Material = Enum.Material.Cobblestone
	spawn.Color = Color3.fromRGB(120, 130, 140)
	spawn.Anchored = true
	spawn.Parent = spawnsFolder
end

--=== FastTravel (точки для платного перемещения, п.14.2) =========================
-- Координаты — рядом с соответствующими зонами. Точка = позиция, куда телепортируем.

local FAST_TRAVEL_POSITIONS = {
	Hermitage = Vector3.new(0, 0, 20),
	AlexandrovskayaColumn = Vector3.new(25, 0, 15),
	Dvortsovaya = Vector3.new(0, 0, 70),
	Nevsky = Vector3.new(350, 0, 15),
	Kazansky = Vector3.new(430, 0, 42),
	SpasNaKrovi = Vector3.new(705, 0, 45),
	Isaakiy = Vector3.new(-155, 0, 185),
	MednyyVsadnik = Vector3.new(-195, 0, -105),
	Petropavlovka = Vector3.new(-145, 0, -590),
	PetropavlovskySobor = Vector3.new(-158, 0, -590),
	Naberezhnaya = Vector3.new(-10, 0, -205),
}

for landmarkId, position in pairs(FAST_TRAVEL_POSITIONS) do
	if fastTravelFolder:FindFirstChild(landmarkId) then
		continue
	end

	local point = makePart({
		Name = landmarkId,
		Size = Vector3.new(8, 1, 8),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		Anchored = true,
		Parent = fastTravelFolder,
	})
	point.CastShadow = false
end

print(
	"[SPB Landmarks] Блокаут карты сгенерирован: зоны, силуэты, фонари, скамейки, таблички."
)
--================================================================================
-- ИНТЕРЬЕРЫ (п.3.1 ТЗ) — обязательный блок v1.0: входы/выходы/закрытые зоны.
--================================================================================

local interiorsFolder = workspace:FindFirstChild("Interiors") or folder("Interiors", workspace)

-- Прямоугольная комната с полом и стенами без потолка — оптимистичная заглушка.
local function room(parent: Instance, name: string, size: Vector3, center: Vector3, color: Color3): Model
	local holder = Instance.new("Model")
	holder.Name = name
	holder.Parent = parent

	makePart({
		Name = "Floor",
		Size = Vector3.new(size.X, 2, size.Z),
		Position = center + Vector3.new(0, 1, 0),
		Color = color,
		Material = Enum.Material.Marble,
		Parent = holder,
	})

	local wallH = size.Y
	local t = 2
	local wallColor = color:Lerp(Color3.new(1, 1, 1), 0.08)

	makePart({
		Name = "Wall_N",
		Size = Vector3.new(size.X, wallH, t),
		Position = center + Vector3.new(0, wallH / 2, -size.Z / 2 - t / 2),
		Color = wallColor,
		Parent = holder,
	})
	makePart({
		Name = "Wall_S",
		Size = Vector3.new(size.X, wallH, t),
		Position = center + Vector3.new(0, wallH / 2, size.Z / 2 + t / 2),
		Color = wallColor,
		Parent = holder,
	})
	makePart({
		Name = "Wall_W",
		Size = Vector3.new(t, wallH, size.Z),
		Position = center + Vector3.new(-size.X / 2 - t / 2, wallH / 2, 0),
		Color = wallColor,
		Parent = holder,
	})
	makePart({
		Name = "Wall_E",
		Size = Vector3.new(t, wallH, size.Z),
		Position = center + Vector3.new(size.X / 2 + t / 2, wallH / 2, 0),
		Color = wallColor,
		Parent = holder,
	})

	return holder
end

-- Дверь-промпт на улице: оранжево-коричневая, с тегом InteriorDoor (будет Prompt).
local function facadeDoor(position: Vector3, interiorId: string, interiorZone: string, color: Color3?): Part
	local door = makePart({
		Name = "Door",
		Size = Vector3.new(7, 10, 1),
		Position = position,
		Color = color or Color3.fromRGB(95, 65, 40),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
		CanCollide = false,
		Parent = propsFolder,
	})
	door:SetAttribute("InteriorId", interiorId)
	door:SetAttribute("InteriorZone", interiorZone)
	CollectionService:AddTag(door, "InteriorDoor")
	return door
end

local function interiorExit(position: Vector3, interiorZone: string): Part
	local door = makePart({
		Name = ("Exit_%s"):format(interiorZone),
		Size = Vector3.new(7, 10, 1),
		Position = position,
		Color = Color3.fromRGB(120, 80, 40),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
		CanCollide = false,
		Parent = propsFolder,
	})
	door:SetAttribute("InteriorExit", true)
	door:SetAttribute("InteriorZone", interiorZone)
	CollectionService:AddTag(door, "InteriorDoor")
	return door
end

-- Дверь в интерьере (MoveTo/RequiresInteriorPass/exit): создаёт часть и помечает тегом.
local function interiorDoor(position: Vector3, color: Color3): Part
	local door = makePart({
		Name = "Door",
		Size = Vector3.new(7, 10, 1),
		Position = position,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
		CanCollide = false,
		Parent = propsFolder,
	})
	CollectionService:AddTag(door, "InteriorDoor")
	return door
end

local function interiorLight(parent: Instance, position: Vector3, range: number)
	local holder = makePart({
		Name = "LightHolder",
		Size = Vector3.new(1, 1, 1),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Name = "InteriorLight"
	light.Range = range
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 235, 190)
	light.Enabled = true
	light.Parent = holder
end

-- Эрмитаж (Зимний дворец) — самый большой интерфейсный интерьер
do
	if not interiorsFolder:FindFirstChild("Interior_Hermitage") then
		local model = Instance.new("Model")
		model.Name = "Interior_Hermitage"
		model.Parent = interiorsFolder

		local base = Vector3.new(0, 2000, 5000)
		local floorColor = Color3.fromRGB(220, 210, 195)

		room(model, "Hall", Vector3.new(90, 26, 90), base + Vector3.new(0, 8, 0), floorColor)
		room(model, "Throne", Vector3.new(70, 24, 90), base + Vector3.new(0, 26, 96), Color3.fromRGB(225, 215, 190))
		room(model, "Malachite", Vector3.new(46, 20, 90), base + Vector3.new(68, 26, 96), Color3.fromRGB(120, 200, 160))
		room(
			model,
			"SecretHall",
			Vector3.new(40, 18, 60),
			base + Vector3.new(0, 26, -76),
			Color3.fromRGB(230, 225, 215)
		)

		-- Лестница из фойе в Тронный зал
		for i = 0, 6 do
			local step = makePart({
				Name = ("Step_%d"):format(i),
				Size = Vector3.new(4, 1 + i * 2, 10),
				Position = base + Vector3.new(-14 + i * 4, 0.5 + i * 2, -28 + i * 12),
				Color = Color3.fromRGB(200, 195, 190),
				Material = Enum.Material.Marble,
				Parent = model,
			})
			step.CastShadow = true
		end

		-- Колонны тронного зала
		for i = -3, 3 do
			local col = makePart({
				Name = ("Throne_Column_%d"):format(i + 4),
				Size = Vector3.new(3, 22, 3),
				Position = base + Vector3.new(0, 26 + 11, 96 + i * 11),
				Color = Color3.fromRGB(245, 240, 225),
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Marble,
				Parent = model,
			})
			col.Orientation = Vector3.new(0, 0, 90)
		end

		-- Малахитовый зал: колонны справа
		for i = -2, 2 do
			local col = makePart({
				Name = ("Malachite_Column_%d"):format(i + 3),
				Size = Vector3.new(4, 18, 4),
				Position = base + Vector3.new(68 + i * 6, 26 + 9 + 5, 96 + i * 12),
				Color = Color3.fromRGB(60, 170, 120),
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Marble,
				Parent = model,
			})
			col.Orientation = Vector3.new(0, 0, 90)
		end

		-- Трон
		makePart({
			Name = "Throne_Platform",
			Size = Vector3.new(12, 2, 8),
			Position = base + Vector3.new(0, 27, 134),
			Color = Color3.fromRGB(200, 165, 80),
			Material = Enum.Material.Marble,
			Parent = model,
		})
		makePart({
			Name = "Throne_Back",
			Size = Vector3.new(6, 12, 2),
			Position = base + Vector3.new(0, 33, 137.5),
			Color = Color3.fromRGB(170, 50, 50),
			Material = Enum.Material.Fabric,
			Parent = model,
		})

		-- Свет (не более 3 на интерьер, из лимита 15–20 на всю зону)
		interiorLight(model, base + Vector3.new(0, 14, 0), 70)
		interiorLight(model, base + Vector3.new(0, 32, 96), 60)
		interiorLight(model, base + Vector3.new(68, 32, 96), 40)

		-- Спавн в фойе
		local spawn = makePart({
			Name = "InteriorSpawn",
			Size = Vector3.new(8, 1, 8),
			Position = base + Vector3.new(0, 1.5, -28),
			Transparency = 1,
			CanCollide = false,
			Anchored = true,
			Parent = model,
		})
		model.PrimaryPart = spawn

		-- Выход из фойе
		local exit = interiorExit(base + Vector3.new(0, 6, -41.05), "Interior_Hermitage")
		exit.Parent = model

		-- Дверь в закрытый зал (латная дверь) с планом пропуска наверху
		local secretDoor = interiorDoor(base + Vector3.new(10, 35, -58), Color3.fromRGB(180, 60, 60))
		secretDoor.Name = "HermitageSecretDoor"
		secretDoor:SetAttribute("MoveTo", "HermitageSecretHallSpawn")
		secretDoor:SetAttribute("RequiresInteriorPass", true)
		secretDoor:SetAttribute("InteriorZone", "Interior_Hermitage")
		secretDoor.Parent = model

		local secretSpawn = makePart({
			Name = "HermitageSecretHallSpawn",
			Size = Vector3.new(6, 1, 6),
			Position = base + Vector3.new(0, 27, -28),
			Transparency = 1,
			CanCollide = false,
			Anchored = true,
			Parent = model,
		})

		local backDoor = interiorDoor(base + Vector3.new(-14, 35, -58), Color3.fromRGB(180, 60, 60))
		backDoor.Name = "HermitageBackDoor"
		backDoor:SetAttribute("MoveTo", "InteriorSpawn")
		backDoor:SetAttribute("InteriorZone", "Interior_Hermitage")
		backDoor.Parent = model
		_ = secretSpawn
	end
end

-- Исаакиевский собор — неф, купол, смотровая площадка на колоннаде
do
	if not interiorsFolder:FindFirstChild("Interior_Isaakiy") then
		local model = Instance.new("Model")
		model.Name = "Interior_Isaakiy"
		model.Parent = interiorsFolder

		local base = Vector3.new(500, 2000, 5000)
		local naveColor = Color3.fromRGB(215, 210, 195)

		room(model, "Nave", Vector3.new(100, 46, 100), base + Vector3.new(0, 22, 0), naveColor)

		-- Купол над нефом
		makePart({
			Name = "Dome_Base",
			Size = Vector3.new(64, 10, 64),
			Position = base + Vector3.new(0, 46, 0),
			Color = Color3.fromRGB(190, 170, 120),
			Material = Enum.Material.Marble,
			Shape = Enum.PartType.Cylinder,
			Parent = model,
		})
		makePart({
			Name = "Dome_Sphere",
			Size = Vector3.new(58, 58, 58),
			Position = base + Vector3.new(0, 58, 0),
			Color = Color3.fromRGB(210, 170, 70),
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Ball,
			Parent = model,
		})

		-- Колоннада: 6 колонн по периметру
		for i = 1, 6 do
			local col = makePart({
				Name = ("Nave_Column_%d"):format(i),
				Size = Vector3.new(4, 40, 4),
				Position = base + Vector3.new(-40 + (i - 1) * 16, 20, 0),
				Color = Color3.fromRGB(230, 225, 210),
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Marble,
				Parent = model,
			})
			col.Orientation = Vector3.new(0, 0, 90)
		end

		-- Смотровая площадка (ярус над колоннадой) и railing
		makePart({
			Name = "Colonnade_Platform",
			Size = Vector3.new(70, 2, 20),
			Position = base + Vector3.new(0, 44, -52),
			Color = Color3.fromRGB(210, 205, 190),
			Material = Enum.Material.Marble,
			Parent = model,
		})
		makePart({
			Name = "Colonnade_Railing",
			Size = Vector3.new(70, 3, 1),
			Position = base + Vector3.new(0, 45, -61.5),
			Color = Color3.fromRGB(120, 20, 20),
			Material = Enum.Material.Metal,
			Parent = model,
		})

		-- Свет (два как максимум на здание, п.4.4)
		interiorLight(model, base + Vector3.new(0, 26, 0), 80)
		interiorLight(model, base + Vector3.new(0, 48, -50), 40)

		-- Спавн у входа
		local spawn = makePart({
			Name = "InteriorSpawn",
			Size = Vector3.new(8, 1, 8),
			Position = base + Vector3.new(0, 1.5, -30),
			Transparency = 1,
			CanCollide = false,
			Anchored = true,
			Parent = model,
		})
		model.PrimaryPart = spawn

		-- Выход в неф
		local exit = interiorExit(base + Vector3.new(0, 6, -49.05), "Interior_Isaakiy")
		exit.Parent = model

		-- Проход на колоннаду (MoveTo)
		local navDoor = interiorDoor(base + Vector3.new(0, 45, -38), Color3.fromRGB(120, 80, 40))
		navDoor.Name = "IsaakiyNaveDoor"
		navDoor:SetAttribute("MoveTo", "IsaakiyColonnadeStand")
		navDoor:SetAttribute("InteriorZone", "Interior_Isaakiy")
		navDoor.Parent = model

		local colonnadeStand = makePart({
			Name = "IsaakiyColonnadeStand",
			Size = Vector3.new(6, 0.5, 6),
			Position = base + Vector3.new(0, 45.5, -52),
			Transparency = 1,
			CanCollide = false,
			Anchored = true,
			Parent = model,
		})

		local backDoor = interiorDoor(colonnadeStand.Position + Vector3.new(0, 1, -6), Color3.fromRGB(120, 80, 40))
		backDoor.Name = "IsaakiyColonnadeDoor"
		backDoor:SetAttribute("MoveTo", "IsaakiyNaveStand")
		backDoor:SetAttribute("InteriorZone", "Interior_Isaakiy")
		backDoor.Parent = model

		local naveStand = makePart({
			Name = "IsaakiyNaveStand",
			Size = Vector3.new(6, 0.5, 6),
			Position = base + Vector3.new(0, 46, -42),
			Transparency = 1,
			CanCollide = false,
			Anchored = true,
			Parent = model,
		})
		_ = naveStand
	end
end

-- Спас на Крови — зал со стилизованными мозаиками и апсой
do
	if not interiorsFolder:FindFirstChild("Interior_SpasNaKrovi") then
		local model = Instance.new("Model")
		model.Name = "Interior_SpasNaKrovi"
		model.Parent = interiorsFolder

		local base = Vector3.new(1000, 2000, 5000)
		local floorColor = Color3.fromRGB(210, 200, 180)

		local hall = room(model, "Hall", Vector3.new(70, 22, 90), base + Vector3.new(0, 11, 0), floorColor)

		-- Мозаики: разноцветные панели вдоль боковых стен
		local mosaicColors = {
			Color3.fromRGB(180, 40, 40),
			Color3.fromRGB(40, 100, 180),
			Color3.fromRGB(60, 140, 90),
			Color3.fromRGB(200, 165, 60),
			Color3.fromRGB(120, 60, 160),
		}
		for i, color in ipairs(mosaicColors) do
			makePart({
				Name = ("Mosaic_%d"):format(i),
				Size = Vector3.new(12, 14, 1),
				Position = base + Vector3.new(-28 + (i - 1) * 14, 8, -43.5),
				Color = color,
				Material = Enum.Material.Neon,
				Parent = hall,
			})
			makePart({
				Name = ("MosaicR_%d"):format(i),
				Size = Vector3.new(12, 14, 1),
				Position = base + Vector3.new(-28 + (i - 1) * 14, 8, 43.5),
				Color = color,
				Material = Enum.Material.Neon,
				Parent = hall,
			})
		end

		-- Колонны по центру
		for i = -1, 1 do
			local col = makePart({
				Name = ("Spas_Column_%d"):format(i + 2),
				Size = Vector3.new(5, 20, 5),
				Position = base + Vector3.new(i * 16, 10, 20),
				Color = Color3.fromRGB(200, 190, 160),
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Marble,
				Parent = hall,
			})
			col.Orientation = Vector3.new(0, 0, 90)
		end

		-- Апсида (округлое завершение зала)
		makePart({
			Name = "Apse",
			Size = Vector3.new(26, 20, 16),
			Position = base + Vector3.new(0, 10, 48),
			Color = Color3.fromRGB(230, 215, 170),
			Material = Enum.Material.Marble,
			Shape = Enum.PartType.Cylinder,
			Parent = hall,
		})

		-- Свет
		interiorLight(model, base + Vector3.new(0, 14, 0), 70)
		interiorLight(model, base + Vector3.new(0, 14, 40), 40)

		-- Спавн
		local spawn = makePart({
			Name = "InteriorSpawn",
			Size = Vector3.new(8, 1, 8),
			Position = base + Vector3.new(0, 1.5, -30),
			Transparency = 1,
			CanCollide = false,
			Anchored = true,
			Parent = model,
		})
		model.PrimaryPart = spawn

		local exit = interiorExit(base + Vector3.new(0, 6, -44.05), "Interior_SpasNaKrovi")
		exit.Parent = model
	end
end

--=== Фасадные двери (входы из улицы в интерьеры) ================================
facadeDoor(Vector3.new(0, 5, -14.5), "Hermitage", "Interior_Hermitage")
facadeDoor(Vector3.new(-160, 5, 184.5), "Isaakiy", "Interior_Isaakiy")
facadeDoor(Vector3.new(760, 5, 24.5), "SpasNaKrovi", "Interior_SpasNaKrovi")
--================================================================================
-- Указатели улиц (п.5.1 ТЗ — физические таблички) и плейсхолдеры v2.0 (п.5.4 ТЗ).
--================================================================================

local function modelPrimaryPart(holder: Model, part: BasePart)
	holder.PrimaryPart = part
end

local function streetSign(position: Vector3, text: string, rotationY: number?)
	local holder = Instance.new("Model")
	holder.Name = ("StreetSign_%s"):format(text:gsub("%s+", "_"):sub(1, 24))
	holder.Parent = propsFolder

	makePart({
		Name = "Pole",
		Size = Vector3.new(0.4, 8.4, 0.4),
		Position = position + Vector3.new(0, 4.2, 0),
		Color = Color3.fromRGB(40, 50, 60),
		Material = Enum.Material.Metal,
		Parent = holder,
	})

	local plate = makePart({
		Name = "Plate",
		Size = Vector3.new(6, 1.6, 0.2),
		Position = position + Vector3.new(0, 6.8, 0),
		Color = Color3.fromRGB(20, 30, 45),
		Material = Enum.Material.SmoothPlastic,
		Parent = holder,
	})
	if rotationY then
		plate.Orientation = Vector3.new(0, rotationY, 0)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "StreetSignGui"
	gui.CanvasSize = Vector2.new(240, 64)
	for i = 1, 2 do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		if i == 1 then
			label.Face = Enum.NormalId.Front
		else
			label.Face = Enum.NormalId.Back
			label.Rotation = 180
		end
		label.Parent = gui
	end
	gui.Parent = plate
	modelPrimaryPart(holder, plate)
end

streetSign(Vector3.new(55, 0, 2), "Невский проспект / Nevsky Prospect", 0)
streetSign(Vector3.new(245, 0, 2), "Невский проспект / Nevsky Prospect", 0)
streetSign(Vector3.new(430, 0, 28), "Казанская / Kazansky pereulok", 0)
streetSign(Vector3.new(0, 0, -28), "Дворцовая площадь / Palace Sq.", 0)
streetSign(Vector3.new(700, 0, 28), "Канал Грибоедова / Griboedov Canal", -20)
streetSign(Vector3.new(0, 0, -80), "Набережная Невы / Neva Embankment", 0)
streetSign(Vector3.new(-160, 0, -450), "Заячий остров / Hare Is.", 0)

-- Плейсхолдеры v2.0: «квартирный квартал» и «магазин» над Невским, tagged House/Shop (п.5.4)

local function placeholderBuilding(name: string, tag: string, position: Vector3, size: Vector3, color: Color3)
	if buildingsFolder:FindFirstChild(name) then
		return
	end
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = buildingsFolder
	local body = makePart({
		Name = "Body",
		Size = size,
		Position = position + Vector3.new(0, size.Y / 2, 0),
		Color = color,
		Material = Enum.Material.Pebble,
		Parent = model,
	})
	CollectionService:AddTag(model, tag)
	model.PrimaryPart = body
end

placeholderBuilding(
	"Building_Nevsky_House_Flat",
	"House",
	Vector3.new(260, 0, -45),
	Vector3.new(46, 32, 24),
	Color3.fromRGB(210, 185, 160)
)
placeholderBuilding(
	"Shop_Nevsky_Cafe",
	"Shop",
	Vector3.new(340, 0, -40),
	Vector3.new(26, 14, 16),
	Color3.fromRGB(170, 140, 200)
)
placeholderBuilding(
	"Job_Permit_Office",
	"Job",
	Vector3.new(180, 0, 40),
	Vector3.new(30, 24, 18),
	Color3.fromRGB(150, 170, 140)
)

--=== Streaming (п.8.1) ============================================================
-- Из скриптов включить StreamingEnabled НЕЛЬЗЯ (read-only). Установите вручную в Studio:
-- Workspace.StreamingEnabled=true; MinRadius=128; TargetRadius=900.

print(
	"[SPB Landmarks] Готово: интерьеры, фасадные двери, указатели улиц, плейсхолдеры v2.0."
)
