--!strict
--[[
	AvatarPresets.lua — гардероб и позы для фото (v2.0).

	Гардероб v2.0: набор пресетов через HumanoidDescription. По умолчанию
	в пресетах только тона кожи/костюма (без ассетов: внешних ID нет,
	нельзя нарваться на отсутствующий каталог). Чтобы добавить настоящую
	одежду/аксессуары — впиши свои AssetId в Hat/ShirtAssetId и т.п.

	Позы v2.0: сервер корректирует C0 моторов R15 (без анимационных ассетов).
	Углы подобраны под стандартный R15-риг; если в Studio поза «смотрит
	не туда» — подстрой Amplitudes в Offsets и проверь ещё раз.

	Бюджет света (п.4.4) здесь не затрагивается вообще.
]]

export type OutfitPreset = {
	Id: string,
	Name: string,
	Desc: string,
	RequiresFeature: string?,
	-- Квестовая авторизация (v2.3): требуется прогресс в профиле, едваучитываемый
	RequiresQuest: { Kind: string, Count: number }?,
	Head: Color3,
	Torso: Color3,
	LeftArm: Color3,
	RightArm: Color3,
	LeftLeg: Color3,
	RightLeg: Color3,
	-- Плейсхолдеры на будущее (оставь nil/пусто — не применяется)
	HatAssetIds: { number }?,
	ShirtAssetId: number?,
	PantsAssetId: number?,
}

export type PosePreset = {
	Id: string,
	Name: string,
	-- Имя мотора R15 -> поворотная мульти-позиция к базовому C0
	Offsets: { [string]: CFrame },
}

local AvatarPresets = {}

AvatarPresets.Outfits = {
	{
		Id = "Tourist",
		Name = "Турист",
		Desc = "Лёгкий дневной гардероб Невского",
		RequiresFeature = nil,
		Head = Color3.fromRGB(226, 198, 166),
		Torso = Color3.fromRGB(214, 120, 96),
		LeftArm = Color3.fromRGB(226, 198, 166),
		RightArm = Color3.fromRGB(226, 198, 166),
		LeftLeg = Color3.fromRGB(56, 70, 92),
		RightLeg = Color3.fromRGB(56, 70, 92),
	},
	{
		Id = "WhiteNight",
		Name = "Белая ночь",
		Desc = "Прохладные светлые тона июня",
		RequiresFeature = nil,
		Head = Color3.fromRGB(232, 214, 192),
		Torso = Color3.fromRGB(214, 222, 232),
		LeftArm = Color3.fromRGB(214, 222, 232),
		RightArm = Color3.fromRGB(214, 222, 232),
		LeftLeg = Color3.fromRGB(138, 150, 170),
		RightLeg = Color3.fromRGB(138, 150, 170),
	},
	{
		Id = "Granite",
		Name = "Гранит",
		Desc = "Дождевая набежный палитра",
		RequiresFeature = nil,
		Head = Color3.fromRGB(190, 168, 140),
		Torso = Color3.fromRGB(96, 98, 104),
		LeftArm = Color3.fromRGB(96, 98, 104),
		RightArm = Color3.fromRGB(96, 98, 104),
		LeftLeg = Color3.fromRGB(52, 54, 60),
		RightLeg = Color3.fromRGB(52, 54, 60),
	},
	{
		Id = "GoldGala",
		Name = "Золотой гала",
		Desc = "Вечерний парад (пасс «Фото в золоте»)",
		RequiresFeature = "VipPhotoFrame",
		Head = Color3.fromRGB(228, 202, 172),
		Torso = Color3.fromRGB(214, 178, 84),
		LeftArm = Color3.fromRGB(214, 178, 84),
		RightArm = Color3.fromRGB(214, 178, 84),
		LeftLeg = Color3.fromRGB(34, 34, 40),
		RightLeg = Color3.fromRGB(34, 34, 40),
	},
	{
		Id = "Nocturne",
		Name = "Ноктюрн",
		Desc = "Награда квеста «Охотник за тенями» (3 ночных снимка)",
		RequiresFeature = nil,
		RequiresQuest = { Kind = "ShadowCaptures", Count = 3 },
		Head = Color3.fromRGB(196, 188, 210),
		Torso = Color3.fromRGB(46, 50, 88),
		LeftArm = Color3.fromRGB(46, 50, 88),
		RightArm = Color3.fromRGB(46, 50, 88),
		LeftLeg = Color3.fromRGB(24, 26, 44),
		RightLeg = Color3.fromRGB(24, 26, 44),
	},
}

AvatarPresets.Poses = {
	{
		Id = "Salute",
		Name = "Отдать честь",
		Offsets = {
			RightShoulder = CFrame.Angles(0, 0, math.rad(-150)),
			Neck = CFrame.Angles(math.rad(-12), 0, 0),
		},
	},
	{
		Id = "Heart",
		Name = "Сердце",
		Offsets = {
			RightShoulder = CFrame.Angles(0, 0, math.rad(-120)),
			LeftShoulder = CFrame.Angles(0, 0, math.rad(120)),
		},
	},
	{
		Id = "Lean",
		Name = "Поза у парапета",
		Offsets = {
			Root = CFrame.Angles(math.rad(-8), 0, 0),
			Neck = CFrame.Angles(math.rad(-18), 0, 0),
			LeftShoulder = CFrame.Angles(0, 0, math.rad(30)),
		},
	},
	{
		Id = "Wave",
		Name = "Привет",
		Offsets = {
			RightShoulder = CFrame.Angles(0, 0, math.rad(-80)),
			RightElbow = CFrame.Angles(0, 0, math.rad(-40)),
		},
	},
}

-- Индексы для быстрой валидации
local outfitsById: { [string]: OutfitPreset } = {}
for _, preset in AvatarPresets.Outfits do
	outfitsById[preset.Id] = preset
end
AvatarPresets.GetOutfitById = function(id: string): OutfitPreset?
	return outfitsById[id]
end

local posesById: { [string]: PosePreset } = {}
for _, pose in AvatarPresets.Poses do
	posesById[pose.Id] = pose
end
AvatarPresets.GetPoseById = function(id: string): PosePreset?
	return posesById[id]
end

return AvatarPresets
