--!strict
--[[
	LightingPresets.lua — пресеты освещения для LightingController (п.12.2 ТЗ).

	Четыре режима: day / sunset / whiteNights / night.
	Каждый пресет описывает свойства Lighting, Atmosphere, ColorCorrection и Bloom;
	переключение происходит плавно (TweenService), поэтому значения можно
	смело подстраивать «на глаз» в Studio.
]]

local Color3_new = Color3.fromRGB

export type Preset = {
	Id: string,
	DisplayName: string,
	ClockTime: number,
	TransitionSeconds: number,
	Lighting: { [string]: any },
	Atmosphere: { [string]: any },
	ColorCorrection: { [string]: any },
	Bloom: { [string]: any },
}

local LightingPresets = {}

--[[ Глобальные настройки цикла (п.4.1 ТЗ) ]]
LightingPresets.Config = {
	-- Полный цикл ClockTime (0 -> 24) в реальных минутах
	CycleLengthMinutes = 25,
	-- Стартовое время сервера
	StartClockTime = 10,
	-- Фонари включаются при ClockTime >= 19 или <= 6 (п.4.2)
	LampOnFrom = 19,
	LampOnTo = 6,
	-- Интервал трансляции состояния клиентам (сек)
	StateBroadcastInterval = 1,
	-- Сколько режимов «сам» выбирает контроллер по времени суток,
	-- если игрок не задал режим вручную (Game Pass «Хронос»)
	AutoMode = true,
}

local Modes: { [string]: Preset } = {
	day = {
		Id = "day",
		DisplayName = "День",
		ClockTime = 12,
		TransitionSeconds = 3,
		Lighting = {
			ClockTime = 12,
			Brightness = 2,
			Ambient = Color3_new(128, 128, 128),
			OutdoorAmbient = Color3_new(128, 128, 128),
			ColorShift_Top = Color3_new(0, 0, 0),
			ColorShift_Bottom = Color3_new(0, 0, 0),
			FogStart = 400,
			FogEnd = 3000,
			FogColor = Color3_new(202, 214, 226),
			ExposureCompensation = 0,
			ShadowSoftness = 0.4,
			GlobalShadows = true,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.25,
			Glare = 0.25,
			Haze = 1.5,
			Color = Color3_new(255, 255, 255),
			Decay = Color3_new(128, 128, 128),
		},
		ColorCorrection = {
			Saturation = 0.05,
			Contrast = 0.05,
			Brightness = 0,
			TintColor = Color3_new(255, 255, 255),
		},
		Bloom = {
			Intensity = 0.4,
			Size = 24,
			Threshold = 0.85,
		},
	},

	sunset = {
		Id = "sunset",
		DisplayName = "Закат",
		ClockTime = 18.5,
		TransitionSeconds = 5,
		Lighting = {
			ClockTime = 18.5,
			Brightness = 2.4,
			Ambient = Color3_new(150, 120, 110),
			OutdoorAmbient = Color3_new(180, 140, 120),
			ColorShift_Top = Color3_new(0, 0, 0),
			ColorShift_Bottom = Color3_new(0, 0, 0),
			FogStart = 200,
			FogEnd = 2500,
			FogColor = Color3_new(250, 190, 140),
			ExposureCompensation = -0.1,
			ShadowSoftness = 0.6,
			GlobalShadows = true,
		},
		Atmosphere = {
			Density = 0.35,
			Offset = 0.3,
			Glare = 0.5,
			Haze = 2.2,
			Color = Color3_new(255, 220, 190),
			Decay = Color3_new(200, 150, 130),
		},
		ColorCorrection = {
			Saturation = 0.1,
			Contrast = 0.1,
			Brightness = 0,
			TintColor = Color3_new(255, 240, 230),
		},
		Bloom = {
			Intensity = 0.8,
			Size = 32,
			Threshold = 0.8,
		},
	},

	whiteNights = {
		Id = "whiteNights",
		DisplayName = "Белые ночи",
		ClockTime = 0,
		TransitionSeconds = 8,
		Lighting = {
			ClockTime = 0,
			Brightness = 2.2,
			Ambient = Color3_new(140, 150, 170),
			OutdoorAmbient = Color3_new(120, 135, 170),
			ColorShift_Top = Color3_new(0, 0, 0),
			ColorShift_Bottom = Color3_new(0, 0, 0),
			FogStart = 150,
			FogEnd = 2200,
			FogColor = Color3_new(150, 165, 190),
			ExposureCompensation = 0.05,
			ShadowSoftness = 0.8,
			GlobalShadows = true,
		},
		Atmosphere = {
			Density = 0.45,
			Offset = 0.35,
			Glare = 0.2,
			Haze = 3,
			Color = Color3_new(170, 185, 210),
			Decay = Color3_new(120, 140, 180),
		},
		ColorCorrection = {
			Saturation = -0.05,
			Contrast = 0,
			Brightness = 0.02,
			TintColor = Color3_new(225, 235, 255),
		},
		Bloom = {
			Intensity = 0.5,
			Size = 28,
			Threshold = 0.85,
		},
	},

	night = {
		Id = "night",
		DisplayName = "Ночь",
		ClockTime = 23,
		TransitionSeconds = 5,
		Lighting = {
			ClockTime = 23,
			Brightness = 1.4,
			Ambient = Color3_new(60, 65, 85),
			OutdoorAmbient = Color3_new(35, 40, 60),
			ColorShift_Top = Color3_new(0, 0, 0),
			ColorShift_Bottom = Color3_new(0, 0, 0),
			FogStart = 60,
			FogEnd = 1500,
			FogColor = Color3_new(20, 25, 40),
			ExposureCompensation = 0.1,
			ShadowSoftness = 0.5,
			GlobalShadows = true,
		},
		Atmosphere = {
			Density = 0.5,
			Offset = 0.2,
			Glare = 0.1,
			Haze = 1,
			Color = Color3_new(30, 40, 60),
			Decay = Color3_new(60, 70, 100),
		},
		ColorCorrection = {
			Saturation = 0.05,
			Contrast = 0.1,
			Brightness = 0,
			TintColor = Color3_new(210, 220, 255),
		},
		Bloom = {
			Intensity = 0.9,
			Size = 30,
			Threshold = 0.7,
		},
	},
}

LightingPresets.Modes = Modes

LightingPresets.ModeOrder = { "day", "sunset", "whiteNights", "night" }

--[[ Автоматический выбор режима по времени суток (если не задан вручную). ]]
LightingPresets.AutoSchedule = {
	{ From = 6.5, To = 17, Mode = "day" },
	{ From = 17, To = 20.5, Mode = "sunset" },
	{ From = 20.5, To = 23.5, Mode = "night" },
	{ From = 23.5, To = 3, Mode = "whiteNights" }, -- «белые ночи» ночью: светло
	{ From = 3, To = 6.5, Mode = "night" },
}

function LightingPresets.Get(modeId: string): Preset?
	return Modes[modeId]
end

function LightingPresets.IsMode(modeId: any): boolean
	return type(modeId) == "string" and Modes[modeId] ~= nil
end

-- Режим, который соответствует текущему ClockTime (для автоматического цикла)
function LightingPresets.ModeForClockTime(clockTime: number): string
	for _, entry in ipairs(LightingPresets.AutoSchedule) do
		if clockTime >= entry.From and clockTime < entry.To then
			return entry.Mode
		end
	end
	return "night"
end

return LightingPresets
