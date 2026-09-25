--!strict
--[[
	Landmarks.lua — единый справочник контента карты.

	Здесь объявляются:
	  * достопримечательности (используются зонами, инфо-табличками,
	    фото-точками, коллекциями и быстрым перемещением);
	  * зоны карты (имена папок в Workspace/Map/Zones) и их эмбиент;
	  * точки спавна;
	  * тексты инфо-табличек (базовый текст + расширенный для Game Pass «Гид»);
	  * настройки профиля, доступные игроку.

	ВАЖНО: этот модуль — «источник правды» для сервера и клиента.
	Добавили новую достопримечательность — добавили запись сюда,
	остальной код подхватит её автоматически.
]]

export type Priority = "critical" | "important" | "nice"

export type Landmark = {
	Id: string,
	DisplayName: string,
	ZoneId: string,
	Priority: Priority,
	Summary: string,
	Details: { string },
	ImageAsset: string,
	HasInterior: boolean,
	PhotoSpot: boolean,
	FastTravel: boolean,
	HeightStuds: number?,
}

export type Zone = {
	Id: string,
	DisplayName: string,
	LandmarkId: string?,
	Ambient: {
		SoundId: string,
		Volume: number,
		DisplayName: string,
	},
}

export type SpawnDef = {
	Id: string,
	DisplayName: string,
	LandmarkId: string,
	Folder: string,
}

export type InfoBoard = {
	Id: string,
	Title: string,
	Summary: string,
	Details: { string },
	ImageAsset: string,
}

local PLACEHOLDER_IMAGE = "rbxassetid://0"
local PLACEHOLDER_SOUND = "rbxassetid://0"

--[[ Иконки/картинки в ImageLabel и звуки в Sound требуют реальных asset id.
	Замените 0 на id загруженных в опыт ассетов (собственных или из Creator Store). ]]

local Landmarks: { [string]: Landmark } = {}

Landmarks.Dvortsovaya = {
	Id = "Dvortsovaya",
	DisplayName = "Дворцовая площадь",
	ZoneId = "Dvortsovaya",
	Priority = "critical",
	HasInterior = false,
	PhotoSpot = true,
	FastTravel = true,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Главная площадь города, 1750-е — 1840-е. Ансамбль сложился вокруг Зимнего дворца: полукружие Главного штаба, арка с колесницей Славы и Александровская колонна в центре.",
	Details = {
		"Площадь окончательно оформилась к 1840-м: здание Главного штаба построено Карлом Росси в 1819–1829 годах.",
		"Арка Главного штаба увенчана колесницей Славы работы скульпторов Пименова и Демут-Малиновского.",
		"Площадь неоднократно становилась местом исторических событий и до сих пор используется для городских праздников.",
	},
}

Landmarks.Hermitage = {
	Id = "Hermitage",
	DisplayName = "Зимний дворец (Эрмитаж)",
	ZoneId = "Dvortsovaya",
	Priority = "critical",
	HasInterior = true,
	PhotoSpot = true,
	FastTravel = true,
	HeightStuds = 30,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Барочный дворец 1754–1762 годов, проект Бартоломео Растрелли. Около 1084 залов и помещений, парадная лестница и анфилады — сердце будущего музея.",
	Details = {
		"Четвёртый по счёту Зимний дворец построен для Елизаветы Петровны, достроен уже при Екатерине II.",
		"Парадная (Иорданская) лестница — один из самых узнаваемых интерьеров дворца.",
		"Малахитовый зал получил название по отделке из уральского малахита; его площадь около 550 м².",
		"В 1764 году Екатерина II положила начало коллекции Эрмитажа, купив 225 картин в Берлине.",
	},
}

Landmarks.AlexandrovskayaColumn = {
	Id = "AlexandrovskayaColumn",
	DisplayName = "Александровская колонна",
	ZoneId = "Dvortsovaya",
	Priority = "critical",
	HasInterior = false,
	PhotoSpot = true,
	FastTravel = false,
	HeightStuds = 47,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Гранитный монолит высотой около 47,5 метров, установлен в 1834 году по проекту Огюста Монферрана в честь победы над Наполеоном.",
	Details = {
		"Вес колонны — около 600 тонн; она стоит без креплений, только под собственным весом.",
		"Ствол — цельный гранитный монолит, доставленный из карельских каменоломен по воде.",
		"Венчает колонну фигура ангела с крестом работы скульптора Бориса Орловского.",
	},
}

Landmarks.Nevsky = {
	Id = "Nevsky",
	DisplayName = "Невский проспект",
	ZoneId = "Nevsky",
	Priority = "critical",
	HasInterior = false,
	PhotoSpot = true,
	FastTravel = true,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Главная улица города длиной около 4,5 км. Витрины, фонари, скамейки и плотная застройка XVIII–XX веков.",
	Details = {
		"Проспект проложен в 1710-х годах как дорога от Адмиралтейства к Александро-Невской лавре.",
		"Историческая застройка сформировалась в основном в конце XVIII — начале XX века.",
		"Здесь находится одна из первых в городе систем уличного освещения.",
	},
}

Landmarks.Kazansky = {
	Id = "Kazansky",
	DisplayName = "Казанский собор",
	ZoneId = "Nevsky",
	Priority = "critical",
	HasInterior = false,
	PhotoSpot = true,
	FastTravel = true,
	HeightStuds = 70,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Собор 1801–1811 годов, архитектор Андрей Воронихин. Узнаваемая полуциркульная колоннада из 96 колонн, выходящая прямо на Невский проспект.",
	Details = {
		"Собор построен для хранения чтимой иконы Казанской Божией Матери.",
		"Колоннада из 96 коринфских колонн — отсылка к собору Святого Петра в Риме.",
		"В 1813 году здесь был похоронен фельдмаршал Михаил Кутузов.",
	},
}

Landmarks.SpasNaKrovi = {
	Id = "SpasNaKrovi",
	DisplayName = "Спас на Крови",
	ZoneId = "SpasNaKrovi",
	Priority = "critical",
	HasInterior = true,
	PhotoSpot = true,
	FastTravel = true,
	HeightStuds = 81,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Храм Воскресения Христова, 1883–1907 годы. Построен на месте покушения на императора Александра II 1 марта 1881 года. Самый узнаваемый силуэт города.",
	Details = {
		"Архитекторы — Альфред Парланд и архимандрит Игнатий (Малышев).",
		"Площадь мозаик внутри — более 7000 м², одна из крупнейших коллекций мозаики в Европе.",
		"Девять глав с луковичными куполами создают тот самый «сказочный» силуэт.",
		"Храм стоит на набережной канала Грибоедова, на месте, где был смертельно ранен император.",
	},
}

Landmarks.Isaakiy = {
	Id = "Isaakiy",
	DisplayName = "Исаакиевский собор",
	ZoneId = "Isaakievskaya",
	Priority = "critical",
	HasInterior = true,
	PhotoSpot = true,
	FastTravel = true,
	HeightStuds = 101,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Крупнейший православный храм города: строили 40 лет, с 1818 по 1858 год. Проект Огюста Монферрана. Высота вместе с крестом — около 101,5 метра.",
	Details = {
		"Четвёртый храм, возведённый на этом месте, и первый, построенный на надёжном свайном основании.",
		"Золочение купола в XIX веке выполнялось огневым способом — это стоило жизни многим мастеров.",
		"Смотровая площадка на колоннаде находится на высоте около 43 метров.",
		"Фасады облицованы серым мрамором, портики — 48 монолитных гранитных колонн.",
	},
}

Landmarks.MednyyVsadnik = {
	Id = "MednyyVsadnik",
	DisplayName = "Медный всадник",
	ZoneId = "MednyyVsadnik",
	Priority = "important",
	HasInterior = false,
	PhotoSpot = true,
	FastTravel = true,
	HeightStuds = 11,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Памятник Петру I работы Этьена Мориса Фальконе, открыт в 1782 году. Постамент — гранитный монолит «Гром-камень».",
	Details = {
		"Надпись на постаменте: «Петру первому Екатерина вторая».",
		"«Гром-камень» весил более 1500 тонн — его везли из Лахты несколько месяцев.",
		"Голова памятника лепилась Мари-Анн Колло, ученицей Фальконе.",
	},
}

Landmarks.Petropavlovka = {
	Id = "Petropavlovka",
	DisplayName = "Петропавловская крепость",
	ZoneId = "Petropavlovka",
	Priority = "important",
	HasInterior = false,
	PhotoSpot = true,
	FastTravel = true,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Заложена 16 (27) мая 1703 года — с неё начался город. Стены, бастионы, собор и знаменитый пляж у стен крепости.",
	Details = {
		"Крепость задумывалась как защита от шведов в устье Невы, но ни разу не участвовала в бою.",
		"С Нарышкина бастиона ежедневно в полдень производится традиционный пушечный выстрел.",
		"Пляж у стен крепости — неожиданно популярное место отдыха горожан.",
	},
}

Landmarks.PetropavlovskySobor = {
	Id = "PetropavlovskySobor",
	DisplayName = "Петропавловский собор",
	ZoneId = "Petropavlovka",
	Priority = "important",
	HasInterior = false,
	PhotoSpot = true,
	FastTravel = false,
	HeightStuds = 122,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Петропавловский собор 1712–1733 годов, архитектор Доменико Трезини. Шпиль высотой 122,5 метра — самая высокая доминанта исторического центра.",
	Details = {
		"Собор — усыпальница российских императоров от Петра I до Николая II.",
		"Шпиль венчает фигура летящего ангела с крестом.",
		"Колокольня с золочёным шпилем задаёт вертикаль всему центру города.",
	},
}

Landmarks.Naberezhnaya = {
	Id = "Naberezhnaya",
	DisplayName = "Набережные Невы",
	ZoneId = "Naberezhnaya",
	Priority = "critical",
	HasInterior = false,
	PhotoSpot = true,
	FastTravel = true,
	ImageAsset = PLACEHOLDER_IMAGE,
	Summary = "Гранитные парапеты, спуски к воде, мосты и открытый вид на Неву. Летом сюда приходят ради закатов и разводки мостов.",
	Details = {
		"Гранитная облицовка набережных появилась в основном в 1760–1780-х годах.",
		"Дворцовый мост соединяет центр с Васильевским островом; в навигацию его разводят ночью.",
		"Спуски к воде традиционно оформлялись пристанями со сфинксами и львами.",
	},
}

-- Порядок обхода для интерфейсов (коллекция, быстрые перемещения, подсказки)
local ORDER: { string } = {
	"Dvortsovaya",
	"Hermitage",
	"AlexandrovskayaColumn",
	"Nevsky",
	"Kazansky",
	"SpasNaKrovi",
	"Isaakiy",
	"MednyyVsadnik",
	"Petropavlovka",
	"PetropavlovskySobor",
	"Naberezhnaya",
}

--[[ Зоны карты. Id == имя папки в Workspace/Map/Zones (см. п.6 ТЗ).
	Ambient — эмбиент-звук, который включается при входе игрока в зону (п.12.3). ]]
local Zones: { [string]: Zone } = {
	Dvortsovaya = {
		Id = "Dvortsovaya",
		DisplayName = "Дворцовая площадь",
		LandmarkId = "Dvortsovaya",
		Ambient = { SoundId = PLACEHOLDER_SOUND, Volume = 0.35, DisplayName = "Город и голуби" },
	},
	Nevsky = {
		Id = "Nevsky",
		DisplayName = "Невский проспект",
		LandmarkId = "Nevsky",
		Ambient = { SoundId = PLACEHOLDER_SOUND, Volume = 0.4, DisplayName = "Город и толпа" },
	},
	Isaakievskaya = {
		Id = "Isaakievskaya",
		DisplayName = "Исаакиевская площадь",
		LandmarkId = "Isaakiy",
		Ambient = { SoundId = PLACEHOLDER_SOUND, Volume = 0.3, DisplayName = "Колокола" },
	},
	SpasNaKrovi = {
		Id = "SpasNaKrovi",
		DisplayName = "Спас на Крови",
		LandmarkId = "SpasNaKrovi",
		Ambient = { SoundId = PLACEHOLDER_SOUND, Volume = 0.3, DisplayName = "Канал и колокола" },
	},
	Petropavlovka = {
		Id = "Petropavlovka",
		DisplayName = "Петропавловская крепость",
		LandmarkId = "Petropavlovka",
		Ambient = { SoundId = PLACEHOLDER_SOUND, Volume = 0.4, DisplayName = "Чайки и вода" },
	},
	Naberezhnaya = {
		Id = "Naberezhnaya",
		DisplayName = "Набережные Невы",
		LandmarkId = "Naberezhnaya",
		Ambient = { SoundId = PLACEHOLDER_SOUND, Volume = 0.4, DisplayName = "Вода и ветер" },
	},
	MednyyVsadnik = {
		Id = "MednyyVsadnik",
		DisplayName = "Сенатская площадь",
		LandmarkId = "MednyyVsadnik",
		Ambient = { SoundId = PLACEHOLDER_SOUND, Volume = 0.3, DisplayName = "Ветер и вода" },
	},
}

--[[ Точки спавна (п.5.1): игрок выбирает одну из трёх при входе.
	Позиции задаются в Workspace/Spawns — здесь только метаданные. ]]
local Spawns: { [string]: SpawnDef } = {
	Dvortsovaya = {
		Id = "Dvortsovaya",
		DisplayName = "Дворцовая площадь",
		LandmarkId = "Dvortsovaya",
		Folder = "Spawns",
	},
	Nevsky = {
		Id = "Nevsky",
		DisplayName = "Невский проспект",
		LandmarkId = "Nevsky",
		Folder = "Spawns",
	},
	Petropavlovka = {
		Id = "Petropavlovka",
		DisplayName = "Петропавловская крепость",
		LandmarkId = "Petropavlovka",
		Folder = "Spawns",
	},
}

local SPAWN_ORDER: { string } = { "Dvortsovaya", "Nevsky", "Petropavlovka" }

--[[ Отдельные тексты инфо-табличек (кроме тех, что совпадают с достопримечательностями).
	InfoId на табличке (атрибут) -> сначала ищется здесь, потом в Landmarks. ]]
local InfoBoards: { [string]: InfoBoard } = {
	Nevsky_01 = {
		Id = "Nevsky_01",
		Title = "Невский проспект",
		Summary = "Главная улица города: около 4,5 км от Адмиралтейства до Александро-Невской лавры. Здесь сосредоточены магазины, кофейни и почти все архитектурные стили двух веков.",
		Details = {
			"Современная длина проспекта — около 4,5 километров.",
			"Застройка складывалась с 1710-х годов и до начала XX века.",
			"На проспекте более 50 зданий признаны памятниками архитектуры.",
		},
		ImageAsset = PLACEHOLDER_IMAGE,
	},
	Naberezhnaya_01 = {
		Id = "Naberezhnaya_01",
		Title = "Разводка мостов",
		Summary = "В период навигации мосты через Неву разводят ночью, чтобы пропустить суда. Расписание зависит от сезона и освещения.",
		Details = {
			"Навигация обычно длится с конца апреля по ноябрь.",
			"Разводка начинается после захода солнца и занимает около получаса.",
			"Дворцовый мост разводится одним из последних и считается самой зрелищной разводкой.",
		},
		ImageAsset = PLACEHOLDER_IMAGE,
	},
	Petropavlovka_01 = {
		Id = "Petropavlovka_01",
		Title = "Полуденный выстрел",
		Summary = "Традиция ежедневного пушечного выстрела в 12:00 с Нарышкина бастиона Петропавловской крепости.",
		Details = {
			"Традиция восходит к XIX веку, когда выстрел служил сигналом точного времени.",
			"Выстрел возобновлён в 1957 году и с тех пор производится ежедневно.",
		},
		ImageAsset = PLACEHOLDER_IMAGE,
	},
}

--[[ Настройки профиля, которыми игрок управляет из UI.
	Схема совпадает с PlayerData.Settings (п.5.2 ТЗ). ]]
type SettingDef = {
	Type: "number" | "boolean" | "string",
	Default: any,
	Min: number?,
	Max: number?,
	MaxLength: number?,
	DisplayName: string,
}

local SETTINGS: { [string]: SettingDef } = {
	MusicVolume = { Type = "number", Default = 0.7, Min = 0, Max = 1, DisplayName = "Громкость музыки" },
	AmbientVolume = {
		Type = "number",
		Default = 1,
		Min = 0,
		Max = 1,
		DisplayName = "Громкость эмбиента",
	},
	OnboardingCompleted = { Type = "boolean", Default = false, DisplayName = "Онбординг пройден" },
}

local LandmarksModule = {
	Landmarks = Landmarks,
	Zones = Zones,
	Spawns = Spawns,
	SpawnOrder = SPAWN_ORDER,
	InfoBoards = InfoBoards,
	Order = ORDER,
	SETTINGS = SETTINGS,
}

function LandmarksModule.Get(id: string): Landmark?
	return Landmarks[id]
end

function LandmarksModule.GetZone(id: string): Zone?
	return Zones[id]
end

function LandmarksModule.GetSpawn(id: string): SpawnDef?
	return Spawns[id]
end

function LandmarksModule.GetDisplayName(id: string): string
	local landmark = Landmarks[id]
	return if landmark then landmark.DisplayName else id
end

-- Текст инфо-таблички: сначала собственные тексты, затем тексты достопримечательностей.
function LandmarksModule.GetInfoBoard(id: string): InfoBoard?
	local board = InfoBoards[id]
	if board then
		return board
	end

	local landmark = Landmarks[id]
	if not landmark then
		return nil
	end

	return {
		Id = landmark.Id,
		Title = landmark.DisplayName,
		Summary = landmark.Summary,
		Details = landmark.Details,
		ImageAsset = landmark.ImageAsset,
	}
end

function LandmarksModule.List(): { Landmark }
	local result: { Landmark } = {}
	for _, id in ipairs(ORDER) do
		local landmark = Landmarks[id]
		if landmark then
			table.insert(result, landmark)
		end
	end
	return result
end

-- Список локаций с быстрым перемещением (для платного телепорта, п.14.2)
function LandmarksModule.FastTravelList(): { Landmark }
	local result: { Landmark } = {}
	for _, landmark in ipairs(LandmarksModule.List()) do
		if landmark.FastTravel then
			table.insert(result, landmark)
		end
	end
	return result
end

return LandmarksModule
