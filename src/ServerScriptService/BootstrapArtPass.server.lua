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

print(
	"[SPB Landmarks] Арт-пасс применён: колоннады, купола, мосты, парапеты, канал, деревья."
)
