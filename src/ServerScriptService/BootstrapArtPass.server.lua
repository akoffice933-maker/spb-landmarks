--!strict
--[[
	BootstrapArtPass.server.lua — «арт-пасс»: детализация карты-примитивов (этап художника).

	Поверх силуэтов BootstrapProject дорисовывает узнаваемость СПб до прихода
	настоящей модели:
	  * Эрмитаж — колоннада, балюстрада, оконные ряды, аттиковые вазы;
	  * Исаакий — 4 малых купола, колоннадное кольцо барабана, парадные ступени;
	  * Спас на Крови — до пяти глав, канал Грибоедова + мостик к двери;
	  * Главный штаб — боковые крылья и золотая квадрига на арке;
	  * Петропавловка — бастионы по углам, восточные ворота, пляж;
	  * Дворцовый мост через Неву, гранитный парапет и спуски к воде на набережной;
	  * Невский — проезжая часть и тротуары; деревья-примитивы в скверах.

	Ограничения ТЗ: НОЛЬ новых источников света (бюджет п.4.4 целиком у базы).
	Идемпотентность: каждый блок проверяет свой «якорный» пар-т. Самостоятельно
	отключается (ART_PASS_ENABLED = false) и не ломается без базы (bootstrap).
]]

local ART_PASS_ENABLED = true
if not ART_PASS_ENABLED then
	return
end

--=== Помощники (локальные копии bootstrap-утилит) =================================

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
	part.Parent = props.Parent
	return part
end

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local mapFolder = workspace:FindFirstChild("Map") or folder("Map", workspace)
local buildingsFolder = mapFolder:FindFirstChild("Buildings") or folder("Buildings", mapFolder)
local propsFolder = mapFolder:FindFirstChild("Props") or folder("Props", mapFolder)
local waterFolder = mapFolder:FindFirstChild("Water") or folder("Water", mapFolder)

-- Базовая модель может ещё не существовать (другой скрипт только включается).
local function getBuilding(name: string): Model?
	local found = buildingsFolder:WaitForChild(name, 15)
	if found and found:IsA("Model") then
		return found
	end
	warn(
		("[ArtPass] база «%s» не найдена — арт-пасс для неё пропущен"):format(
			name
		)
	)
	return nil
end

local GOLD = Color3.fromRGB(212, 175, 105)
local WHITE = Color3.fromRGB(235, 230, 215)
local DARK = Color3.fromRGB(70, 74, 78)
local GRANITE = Color3.fromRGB(150, 152, 155)

--=== Эрмитаж: колоннада, балюстрада, окна, аттик ==================================

do
	local model = getBuilding("Building_Hermitage")
	if model and not model:FindFirstChild("Hermitage_Colonnade_01") then
		-- Колоннада коринфского ордера вдоль главного фасада (z = -15 -> снаружи)
		for i = 0, 11 do
			local col = makePart({
				Name = ("Hermitage_Colonnade_%02d"):format(i + 1),
				Size = Vector3.new(2.6, 20, 2.6),
				Position = Vector3.new(-99 + i * 18, 10, -12),
				Color = WHITE,
				Material = Enum.Material.Marble,
				Shape = Enum.PartType.Cylinder,
				Parent = model,
			})
			col.Orientation = Vector3.new(0, 0, 90)
		end

		-- Балюстрада на карнизе главного фасада
		makePart({
			Name = "Hermitage_Balustrade",
			Size = Vector3.new(222, 1.4, 2),
			Position = Vector3.new(0, 26.5, -14),
			Color = WHITE,
			Material = Enum.Material.Marble,
			Parent = model,
		})

		-- Оконные ряды (тёмные вставки впереди фасада на z=-14.2)
		for _, y in { 8, 22 } do
			makePart({
				Name = ("Hermitage_Windows_%d"):format(y),
				Size = Vector3.new(216, 3, 0.4),
				Position = Vector3.new(0, y, -14.2),
				Color = DARK,
				Material = Enum.Material.Glass,
				CanCollide = false,
				Parent = model,
			})
		end

		-- Аттик: ряд ваз на крыше
		for i = 0, 6 do
			makePart({
				Name = ("Hermitage_Attic_%d"):format(i),
				Size = Vector3.new(3, 3.6, 3),
				Position = Vector3.new(-90 + i * 30, 38, -60),
				Color = GOLD,
				Material = Enum.Material.Marble,
				Shape = Enum.PartType.Ball,
				Parent = model,
			})
		end
	end
end

--=== Исаакий: малые купола, кольцо барабана, парадные ступени ======================

do
	local model = getBuilding("Building_Isaakiy")
	if model and not model:FindFirstChild("Isaakiy_Dome_NW") then
		local offsets = {
			{ "NW", -35, -35 },
			{ "NE", 35, -35 },
			{ "SW", -35, 35 },
			{ "SE", 35, 35 },
		}
		for _, o in offsets do
			makePart({
				Name = ("Isaakiy_Dome_%s"):format(o[1]),
				Size = Vector3.new(12, 12, 12),
				Position = Vector3.new(-160 + o[2], 38, 240 + o[3]),
				Color = Color3.fromRGB(200, 160, 70),
				Material = Enum.Material.Metal,
				Shape = Enum.PartType.Ball,
				Parent = model,
			})
		end

		-- Колоннадное кольцо барабана: 8 свободных колонн вокруг драма
		for i = 0, 7 do
			local angle = (i / 8) * math.pi * 2
			local col = makePart({
				Name = ("Isaakiy_DrumCol_%d"):format(i),
				Size = Vector3.new(2.4, 16, 2.4),
				Position = Vector3.new(-160 + math.cos(angle) * 26, 45, 240 + math.sin(angle) * 26),
				Color = WHITE,
				Material = Enum.Material.Marble,
				Shape = Enum.PartType.Cylinder,
				Parent = model,
			})
			col.Orientation = Vector3.new(0, 0, 90)
		end

		-- Парадные гранитные ступени к главной двери (на запад, z ≈ 176–186)
		for i, spec in
			{
				{ 30, 1.6, 6, 176 },
				{ 26, 1.1, 5, 180.5 },
				{ 22, 0.6, 5, 185 },
			}
		do
			makePart({
				Name = ("Isaakiy_Steps_%d"):format(i),
				Size = Vector3.new(spec[1], spec[2], spec[3]),
				Position = Vector3.new(-160, spec[2] / 2, spec[4]),
				Color = GRANITE,
				Material = Enum.Material.Pebble,
				Parent = model,
			})
		end
	end
end

--=== Спас на Крови: до полных пяти глав + канал Грибоедова с мостиком ==============

do
	local model = getBuilding("Building_Spas")
	if model and not model:FindFirstChild("Spas_Dome_4") then
		makePart({
			Name = "Spas_Dome_4",
			Size = Vector3.new(14, 14, 14),
			Position = Vector3.new(738, 48, 80),
			Color = Color3.fromRGB(180, 60, 55),
			Shape = Enum.PartType.Ball,
			Parent = model,
		})
		makePart({
			Name = "Spas_Dome_5",
			Size = Vector3.new(14, 14, 14),
			Position = Vector3.new(782, 48, 40),
			Color = Color3.fromRGB(70, 140, 90),
			Shape = Enum.PartType.Ball,
			Parent = model,
		})

		-- Канал Грибоедова к западу от здания (x = 706..718, z = -60..180)
		if not waterFolder:FindFirstChild("Griboedov") then
			local canal = makePart({
				Name = "Griboedov",
				Size = Vector3.new(12, 2, 240),
				Position = Vector3.new(712, -1, 60),
				Color = Color3.fromRGB(40, 80, 120),
				Material = Enum.Material.Glass,
				Transparency = 0.25,
				CanCollide = false,
				Parent = waterFolder,
			})
			canal.CastShadow = false

			-- Парапеты канала
			for _, x in { 705.5, 718.5 } do
				makePart({
					Name = ("Griboedov_Parapet_%d"):format(x),
					Size = Vector3.new(1, 1.6, 240),
					Position = Vector3.new(x, 0.8, 60),
					Color = GRANITE,
					Material = Enum.Material.Pebble,
					Parent = propsFolder,
				})
			end

			-- Мостик к входной двери (z = 24.5 — ось двери)
			makePart({
				Name = "Griboedov_Bridge",
				Size = Vector3.new(26, 1.6, 14),
				Position = Vector3.new(712, 1.2, 24.5),
				Color = Color3.fromRGB(190, 180, 160),
				Material = Enum.Material.Pebble,
				Parent = propsFolder,
			})
		end
	end
end

--=== Главный штаб: крылья и квадрига ===========================================

do
	local model = getBuilding("Building_GeneralStaff")
	if model and not model:FindFirstChild("Staff_Wing_W") then
		for _, side in { { "W", -100 }, { "E", 100 } } do
			makePart({
				Name = ("Staff_Wing_%s"):format(side[1]),
				Size = Vector3.new(90, 18, 16),
				Position = Vector3.new(side[2], 9, 120),
				Color = Color3.fromRGB(205, 200, 190),
				Parent = model,
			})
		end

		-- Квадрига Славы: пьедестал + три золотые фигуры
		makePart({
			Name = "Staff_Chariot_Base",
			Size = Vector3.new(12, 2.5, 8),
			Position = Vector3.new(0, 37.5, 120),
			Color = Color3.fromRGB(180, 175, 165),
			Parent = model,
		})
		for i = 0, 2 do
			makePart({
				Name = ("Staff_Chariot_%d"):format(i),
				Size = Vector3.new(3.4, 3.4, 3.4),
				Position = Vector3.new(-3.5 + i * 3.5, 41, 120),
				Color = GOLD,
				Material = Enum.Material.Metal,
				Shape = Enum.PartType.Ball,
				Parent = model,
			})
		end
	end
end

--=== Петропавловка: бастионы, восточные ворота, пляж =============================

do
	if not buildingsFolder:FindFirstChild("Bastion_NW") then
		for _, spec in
			{
				{ "NW", -300, -480 },
				{ "NE", -20, -480 },
				{ "SW", -300, -760 },
				{ "SE", -20, -760 },
			}
		do
			makePart({
				Name = ("Bastion_%s"):format(spec[1]),
				Size = Vector3.new(26, 12, 26),
				Position = Vector3.new(spec[2], 6, spec[3]),
				Color = Color3.fromRGB(160, 155, 145),
				Material = Enum.Material.Pebble,
				Shape = Enum.PartType.Cylinder,
				Parent = buildingsFolder,
			})
		end

		-- Восточные ворота (декоративная арка у восточной стены)
		makePart({
			Name = "Petropavlovka_Gate_Top",
			Size = Vector3.new(4, 3, 40),
			Position = Vector3.new(-16, 10, -620),
			Color = Color3.fromRGB(180, 175, 165),
			Parent = buildingsFolder,
		})
		for _, z in { -602, -638 } do
			makePart({
				Name = ("Petropavlovka_Gate_Pylon_%d"):format(z),
				Size = Vector3.new(4, 13, 8),
				Position = Vector3.new(-16, 6.5, z),
				Color = Color3.fromRGB(180, 175, 165),
				Parent = buildingsFolder,
			})
		end

		-- Северные ворота (декоративные пилоны по краям проёма в стене x=-130)
		for _, x in { -141, -119 } do
			makePart({
				Name = ("Petropavlovka_NorthGate_Pylon_%d"):format(x),
				Size = Vector3.new(6, 14, 6),
				Position = Vector3.new(x, 7, -480),
				Color = Color3.fromRGB(180, 175, 165),
				Shape = Enum.PartType.Cylinder,
				Parent = buildingsFolder,
			})
		end
		makePart({
			Name = "Petropavlovka_NorthGate_Top",
			Size = Vector3.new(30, 3, 5),
			Position = Vector3.new(-130, 12.5, -480),
			Color = Color3.fromRGB(180, 175, 165),
			Parent = buildingsFolder,
		})

		-- Пляж южного берега крепости (песок над водой у стены z=-760)
		makePart({
			Name = "Petropavlovka_Beach",
			Size = Vector3.new(280, 1.2, 14),
			Position = Vector3.new(-160, -0.4, -768),
			Color = Color3.fromRGB(214, 196, 158),
			Material = Enum.Material.Sand,
			CanCollide = false,
			Parent = propsFolder,
		})
	end
end

--=== Дворцовый мост через Неву =====================================================

do
	if not propsFolder:FindFirstChild("DvortsovyBridge") then
		-- Пролёт от площади (z=-150) до крепости (z=-600), мимо Медного всадника
		makePart({
			Name = "DvortsovyBridge",
			Size = Vector3.new(18, 2, 450),
			Position = Vector3.new(-130, 1.5, -375),
			Color = Color3.fromRGB(185, 178, 165),
			Material = Enum.Material.Concrete,
			Parent = propsFolder,
		})
		for _, x in { -139.5, -120.5 } do
			makePart({
				Name = ("DvortsovyBridge_Rail_%d"):format(x),
				Size = Vector3.new(1.5, 2.4, 450),
				Position = Vector3.new(x, 3.4, -375),
				Color = Color3.fromRGB(120, 125, 130),
				Material = Enum.Material.Metal,
				Parent = propsFolder,
			})
		end
		-- Пилоны на опорах (без света — бюджет п.4.4)
		for _, z in { -250, -350, -450, -550 } do
			for _, x in { -137, -123 } do
				makePart({
					Name = ("DvortsovyBridge_Pylon_%d_%d"):format(z, x),
					Size = Vector3.new(2, 7, 2),
					Position = Vector3.new(x, 4.8, z),
					Color = DARK,
					Material = Enum.Material.Metal,
					Parent = propsFolder,
				})
			end
		end
	end
end

--=== Набережная: гранитный парапет и спуски к воде =================================

do
	if not propsFolder:FindFirstChild("Naberezhnaya_Parapet") then
		makePart({
			Name = "Naberezhnaya_Parapet",
			Size = Vector3.new(700, 1.6, 1),
			Position = Vector3.new(0, 1, -360),
			Color = GRANITE,
			Material = Enum.Material.Pebble,
			Parent = propsFolder,
		})

		-- Спуски к воде у Дворцового моста и напротив Дворцовой
		for _, spec in { { 0 }, { -260 } } do
			local x = spec[1]
			for i = 0, 2 do
				makePart({
					Name = ("Naberezhnaya_Stairs_%d_%d"):format(x, i),
					Size = Vector3.new(16, 0.5, 4),
					Position = Vector3.new(x, 0.4 - i * 0.4, -362 - i * 4),
					Color = GRANITE,
					Material = Enum.Material.Pebble,
					Parent = propsFolder,
				})
			end
		end
	end
end

--=== Невский: проезжая часть и тротуары ===========================================

do
	if not propsFolder:FindFirstChild("Nevsky_Road") then
		makePart({
			Name = "Nevsky_Road",
			Size = Vector3.new(560, 0.2, 40),
			Position = Vector3.new(430, 0.15, 10),
			Color = Color3.fromRGB(65, 68, 72),
			Material = Enum.Material.Asphalt,
			CanCollide = false,
			Parent = propsFolder,
		})
		for _, spec in { { -46 }, { 66 } } do
			makePart({
				Name = ("Nevsky_Sidewalk_%d"):format(spec[1]),
				Size = Vector3.new(560, 0.3, 12),
				Position = Vector3.new(430, 0.3, spec[1]),
				Color = Color3.fromRGB(165, 160, 150),
				Material = Enum.Material.Pebble,
				CanCollide = false,
				Parent = propsFolder,
			})
		end
	end
end

--=== Деревья-примитивы =============================================================

local TREE_SPOTS = {
	-- Углы Дворцовой площади (у самой кромки, не пересекая крылья штаба)
	Vector3.new(-130, 0, -130),
	Vector3.new(130, 0, -130),
	Vector3.new(-135, 0, 135),
	Vector3.new(135, 0, 135),
	-- Аллея внутри Петропавловской крепости
	Vector3.new(-220, 0, -560),
	Vector3.new(-100, 0, -560),
	Vector3.new(-220, 0, -680),
	Vector3.new(-100, 0, -680),
	-- Сквер у Исаакия
	Vector3.new(-215, 0, 330),
	Vector3.new(-105, 0, 330),
}

for index, position in TREE_SPOTS do
	local name = ("Tree_%02d"):format(index)
	if propsFolder:FindFirstChild(name) then
		continue
	end
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = propsFolder

	makePart({
		Name = "Trunk",
		Size = Vector3.new(2, 8, 2),
		Position = position + Vector3.new(0, 4, 0),
		Color = Color3.fromRGB(95, 65, 45),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	makePart({
		Name = "Crown",
		Size = Vector3.new(11, 11, 11),
		Position = position + Vector3.new(0, 12.5, 0),
		Color = Color3.fromRGB(80, 130, 85),
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Ball,
		Parent = model,
	})
end

--================================================================================
-- АРТ-ПРОХОД 2 (v3): архитектурные доминанты — художник здесь агент, а не человек.
-- Ступенчатые фронтоны (сборные прямоугольники вместо сложных призм), луковки,
-- жилые корпуса, Адмиралтейство со шпилем. Всё так же: ноль источников света.
--================================================================================

local BRICK = Color3.fromRGB(160, 90, 70)

-- Ступенчатый фронтон: 3 убывающих яруса — читается как античный треугольник.
local function steppedPediment(
	parent: Instance,
	name: string,
	center: Vector3,
	width: number,
	baseY: number,
	depth: number
)
	local tiers = {
		{ width, 2.6 },
		{ width * 0.62, 2.0 },
		{ width * 0.34, 1.6 },
	}
	local y = baseY
	for index, tier in tiers do
		makePart({
			Name = ("%s_T%d"):format(name, index),
			Size = Vector3.new(tier[1], tier[2], depth),
			Position = Vector3.new(center.X, y + tier[2] / 2, center.Z),
			Color = WHITE,
			Material = Enum.Material.Marble,
			Parent = parent,
		})
		y += tier[2]
	end
end

-- Адмиралтейство: главный корпус + знаменитый золотой шпиль с «корабликом»
do
	if not buildingsFolder:FindFirstChild("Building_Admiralteistvo") then
		local model = Instance.new("Model")
		model.Name = "Building_Admiralteistvo"
		model.Parent = buildingsFolder

		makePart({
			Name = "Admiralty_Block",
			Size = Vector3.new(70, 16, 40),
			Position = Vector3.new(-250, 8, 60),
			Color = Color3.fromRGB(215, 195, 130),
			Material = Enum.Material.Pebble,
			Parent = model,
		})
		makePart({
			Name = "Admiralty_Tower",
			Size = Vector3.new(18, 10, 18),
			Position = Vector3.new(-250, 21, 60),
			Color = Color3.fromRGB(215, 195, 130),
			Parent = model,
		})
		-- Ярусы шпиля: драма → башенка → игла → кораблик
		local drum = makePart({
			Name = "Admiralty_Drum",
			Size = Vector3.new(10, 8, 10),
			Position = Vector3.new(-250, 30, 60),
			Color = WHITE,
			Shape = Enum.PartType.Cylinder,
			Parent = model,
		})
		drum.Orientation = Vector3.new(0, 0, 90)
		makePart({
			Name = "Admiralty_SpireBase",
			Size = Vector3.new(6, 12, 6),
			Position = Vector3.new(-250, 40, 60),
			Color = GOLD,
			Material = Enum.Material.Metal,
			Parent = model,
		})
		makePart({
			Name = "Admiralty_Spire",
			Size = Vector3.new(2, 24, 2),
			Position = Vector3.new(-250, 58, 60),
			Color = GOLD,
			Material = Enum.Material.Metal,
			Parent = model,
		})
		makePart({
			Name = "Admiralty_Ship",
			Size = Vector3.new(1.6, 1.6, 1.6),
			Position = Vector3.new(-250, 71.5, 60),
			Color = Color3.fromRGB(255, 225, 130),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
			Parent = model,
		})
		model.PrimaryPart = model:FindFirstChild("Admiralty_Block") :: BasePart
	end
end

-- Эрмитаж: боковые крылья к площади + парадный портал у двери интерьера
do
	local model = getBuilding("Building_Hermitage")
	if model and not model:FindFirstChild("Hermitage_Wing_W") then
		for _, side in { { "W", -113 }, { "E", 113 } } do
			makePart({
				Name = ("Hermitage_Wing_%s"):format(side[1]),
				Size = Vector3.new(40, 30, 30),
				Position = Vector3.new(side[2], 15, -10),
				Color = Color3.fromRGB(150, 170, 155),
				Material = Enum.Material.Pebble,
				Parent = model,
			})
		end

		-- Портал: два пилона и ступенчатый фронтон над входом в интерьер
		for _, x in { -5.5, 5.5 } do
			local pil = makePart({
				Name = ("Hermitage_PortalPil_%d"):format(x),
				Size = Vector3.new(2, 10.5, 2),
				Position = Vector3.new(x, 5.25, -13.8),
				Color = WHITE,
				Material = Enum.Material.Marble,
				Shape = Enum.PartType.Cylinder,
				Parent = model,
			})
			pil.Orientation = Vector3.new(0, 0, 90)
		end
		steppedPediment(model, "Hermitage_Portal", Vector3.new(0, 0, -13.6), 17, 11, 3)
	end
end

-- Главный штаб: ступенчатый фронтон + оконный ряд
do
	local model = getBuilding("Building_GeneralStaff")
	if model and not model:FindFirstChild("Staff_Pediment_T1") then
		steppedPediment(model, "Staff_Pediment", Vector3.new(0, 0, 120), 60, 36, 18)
		makePart({
			Name = "Staff_Windows",
			Size = Vector3.new(200, 3, 0.4),
			Position = Vector3.new(0, 12, 111.8),
			Color = DARK,
			Material = Enum.Material.Glass,
			CanCollide = false,
			Parent = model,
		})
	end
end

-- Казанский собор: полукруглая колоннада к Невскому + купол и фронтон
do
	local model = getBuilding("Building_Kazansky")
	if model and not model:FindFirstChild("Kazansky_ArcCol_00") then
		for t = 0, 10 do
			local angle = math.rad(180 + t * 18)
			local col = makePart({
				Name = ("Kazansky_ArcCol_%02d"):format(t),
				Size = Vector3.new(4.5, 18, 4.5),
				Position = Vector3.new(430 + math.cos(angle) * 55, 9, 66 + math.sin(angle) * 55),
				Color = Color3.fromRGB(190, 185, 170),
				Material = Enum.Material.Marble,
				Shape = Enum.PartType.Cylinder,
				Parent = model,
			})
			col.Orientation = Vector3.new(0, 0, 90)
			-- Капитель
			makePart({
				Name = ("Kazansky_ArcCap_%02d"):format(t),
				Size = Vector3.new(6.5, 2, 6.5),
				Position = Vector3.new(430 + math.cos(angle) * 55, 19, 66 + math.sin(angle) * 55),
				Color = WHITE,
				Parent = model,
			})
		end
		-- Купол на барабане над фасадом
		local drum = makePart({
			Name = "Kazansky_Drum",
			Size = Vector3.new(20, 10, 20),
			Position = Vector3.new(430, 31, 66),
			Color = Color3.fromRGB(170, 165, 155),
			Shape = Enum.PartType.Cylinder,
			Parent = model,
		})
		drum.Orientation = Vector3.new(0, 0, 90)
		makePart({
			Name = "Kazansky_Dome",
			Size = Vector3.new(18, 18, 18),
			Position = Vector3.new(430, 42, 66),
			Color = Color3.fromRGB(90, 120, 150),
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Ball,
			Parent = model,
		})
		steppedPediment(model, "Kazansky_Pediment", Vector3.new(430, 0, 55), 60, 26, 6)
	end
end

-- Исаакий: ступенчатый фронтон + балюстрада барабана
do
	local model = getBuilding("Building_Isaakiy")
	if model and not model:FindFirstChild("Isaakiy_Pediment_T1") then
		steppedPediment(model, "Isaakiy_Pediment", Vector3.new(-160, 0, 184.6), 66, 31, 5)
		makePart({
			Name = "Isaakiy_DrumBalustrade",
			Size = Vector3.new(46, 1.2, 46),
			Position = Vector3.new(-160, 60.6, 240),
			Color = WHITE,
			Material = Enum.Material.Marble,
			Parent = model,
		})
	end
end

-- Спас на Крови: лантерны над всеми пятью главами + два шатра по углам
do
	local model = getBuilding("Building_Spas")
	if model and not model:FindFirstChild("Spas_Lantern_1") then
		local domes = {
			{ 1, Vector3.new(760, 82, 60) },
			{ 2, Vector3.new(738, 57, 40) },
			{ 3, Vector3.new(782, 57, 80) },
			{ 4, Vector3.new(738, 57, 80) },
			{ 5, Vector3.new(782, 57, 40) },
		}
		for _, d in domes do
			local i, top = d[1], d[2]
			local lan = makePart({
				Name = ("Spas_Lantern_%d"):format(i),
				Size = Vector3.new(2.4, 3.4, 2.4),
				Position = top,
				Color = GOLD,
				Material = Enum.Material.Metal,
				Shape = Enum.PartType.Cylinder,
				Parent = model,
			})
			lan.Orientation = Vector3.new(0, 0, 90)
			makePart({
				Name = ("Spas_LanternTip_%d"):format(i),
				Size = Vector3.new(1.2, 1.6, 1.2),
				Position = top + Vector3.new(0, 2.4, 0),
				Color = Color3.fromRGB(255, 235, 140),
				Shape = Enum.PartType.Ball,
				Parent = model,
			})
		end

		-- Кирпичные угловые шатры с белым поясом
		for _, spec in { { "SW", 725, 25 }, { "NE", 795, 95 } } do
			local tag, x, z = spec[1], spec[2], spec[3]
			local tent = makePart({
				Name = ("Spas_Tent_%s"):format(tag),
				Size = Vector3.new(10, 30, 10),
				Position = Vector3.new(x, 15, z),
				Color = BRICK,
				Shape = Enum.PartType.Cylinder,
				Parent = model,
			})
			tent.Orientation = Vector3.new(0, 0, 90)
			local band = makePart({
				Name = ("Spas_TentBand_%s"):format(tag),
				Size = Vector3.new(10.4, 2, 10.4),
				Position = Vector3.new(x, 26, z),
				Color = WHITE,
				Shape = Enum.PartType.Cylinder,
				Parent = model,
			})
			band.Orientation = Vector3.new(0, 0, 90)
			makePart({
				Name = ("Spas_TentTop_%s"):format(tag),
				Size = Vector3.new(9, 9, 9),
				Position = Vector3.new(x, 32.5, z),
				Color = Color3.fromRGB(70, 140, 90),
				Shape = Enum.PartType.Ball,
				Parent = model,
			})
		end
	end
end

-- Жилые корпуса вдоль Невского (северная и южная стороны)
do
	if not buildingsFolder:FindFirstChild("Nevsky_House_N1") then
		local houses = {
			-- Северная сторона (z = -62, глубина 20)
			{ "N1", 180, -62, 22 },
			{ "N2", 255, -62, 26 },
			{ "N3", 330, -62, 18 },
			{ "N4", 505, -62, 22 },
			{ "N5", 580, -62, 26 },
			{ "N6", 655, -62, 18 },
			-- Южная сторона (z = 82, глубина 20)
			{ "S1", 220, 82, 20 },
			{ "S2", 320, 82, 24 },
			{ "S3", 545, 82, 20 },
			{ "S4", 610, 82, 24 },
			{ "S5", 675, 82, 20 },
		}
		local palettes = {
			Color3.fromRGB(195, 170, 130),
			Color3.fromRGB(170, 150, 175),
			Color3.fromRGB(150, 165, 185),
		}
		for index, h in houses do
			local model = Instance.new("Model")
			model.Name = ("Nevsky_House_%s"):format(h[1])
			model.Parent = buildingsFolder

			local body = makePart({
				Name = "Body",
				Size = Vector3.new(60, h[4], 20),
				Position = Vector3.new(h[2], h[4] / 2, h[3]),
				Color = palettes[(index % #palettes) + 1],
				Material = Enum.Material.Pebble,
				Parent = model,
			})
			-- Карниз + оконный ряд со стороны улицы
			makePart({
				Name = "Cornice",
				Size = Vector3.new(60.5, 1.2, 20.5),
				Position = Vector3.new(h[2], h[4] - 1, h[3]),
				Color = WHITE,
				Parent = model,
			})
			makePart({
				Name = "Windows",
				Size = Vector3.new(56, 2.4, 0.4),
				Position = Vector3.new(h[2], h[4] * 0.55, h[3] + (if h[3] < 0 then -10.2 else 10.2)),
				Color = DARK,
				Material = Enum.Material.Glass,
				CanCollide = false,
				Parent = model,
			})
			model.PrimaryPart = body
		end
	end
end

-- Дворцовая: мощёные кольца вокруг Александровской колонны
do
	if not propsFolder:FindFirstChild("Dvortsovaya_Disc_1") then
		for i, spec in
			{
				{ 160, 0.25, Color3.fromRGB(150, 148, 140) },
				{ 105, 0.3, Color3.fromRGB(170, 163, 148) },
				{ 60, 0.35, Color3.fromRGB(140, 140, 135) },
			}
		do
			local disc = makePart({
				Name = ("Dvortsovaya_Disc_%d"):format(i),
				Size = Vector3.new(spec[1], spec[2], spec[1]),
				Position = Vector3.new(0, spec[2] / 2, 0),
				Color = spec[3],
				Material = Enum.Material.Pebble,
				Shape = Enum.PartType.Cylinder,
				Parent = propsFolder,
			})
			disc.Orientation = Vector3.new(0, 0, 90)
		end
	end
end

-- Мост: опоры в воде + золочёные пьедесталы-фонари (без света — п.4.4)
do
	if not propsFolder:FindFirstChild("DvortsovyBridge_Pier_1") then
		for i, z in { -430, -520 } do
			local pier = makePart({
				Name = ("DvortsovyBridge_Pier_%d"):format(i),
				Size = Vector3.new(14, 6, 14),
				Position = Vector3.new(-130, -3, z),
				Color = GRANITE,
				Shape = Enum.PartType.Cylinder,
				Parent = propsFolder,
			})
			pier.Orientation = Vector3.new(0, 0, 90)
		end
		for _, spec in { { -137, -180 }, { -123, -180 }, { -137, -565 }, { -123, -565 } } do
			makePart({
				Name = ("DvortsovyBridge_LampBase_%d_%d"):format(spec[1], spec[2]),
				Size = Vector3.new(2, 5, 2),
				Position = Vector3.new(spec[1], 5, spec[2]),
				Color = DARK,
				Material = Enum.Material.Metal,
				Parent = propsFolder,
			})
			makePart({
				Name = ("DvortsovyBridge_LampCap_%d_%d"):format(spec[1], spec[2]),
				Size = Vector3.new(1.4, 1.4, 1.4),
				Position = Vector3.new(spec[1], 8.2, spec[2]),
				Color = Color3.fromRGB(255, 240, 170),
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Ball,
				Parent = propsFolder,
			})
		end
	end
end

print(
	"[SPB Landmarks] Арт-проход v3: Адмиралтейство, крылья дворца, арка Казанского, дома Невского, луковки, фронтоны."
)
