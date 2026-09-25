--!strict
--[[
	Theme.lua — общая палитра и размеры UI.

	Цвета подобраны под «северную» карту: холодный графит, белые ночи,
	золото куполов. Всё UI строится кодом (см. StarterPlayerScripts/UI),
	поэтому шрифты/размеры тоже живут здесь.
]]

local Theme = {
	Colors = {
		Background = Color3.fromRGB(18, 22, 30),
		BackgroundTransparency = 0.12,
		Surface = Color3.fromRGB(28, 34, 45),
		SurfaceAlt = Color3.fromRGB(38, 46, 60),
		Stroke = Color3.fromRGB(120, 140, 170),
		Text = Color3.fromRGB(238, 242, 250),
		TextDim = Color3.fromRGB(165, 178, 198),
		Accent = Color3.fromRGB(120, 180, 255),
		Gold = Color3.fromRGB(226, 187, 106),
		Success = Color3.fromRGB(112, 200, 140),
		Danger = Color3.fromRGB(224, 96, 96),
		Shadow = Color3.fromRGB(0, 0, 0),
	},

	Fonts = {
		Title = Enum.Font.GothamBold,
		Body = Enum.Font.Gotham,
		Button = Enum.Font.GothamMedium,
	},

	Sizes = {
		Title = 24,
		Subtitle = 18,
		Body = 16,
		Small = 14,
		Button = 18,
		-- Минимальный размер текста для мобильных (п.16 ТЗ)
		MinMobileText = 14,
	},

	Corner = UDim.new(0, 12),
	Padding = 12,

	-- Фреймы Photo Spot (п.5.3)
	PhotoFrames = {
		Default = {
			Color = Color3.fromRGB(238, 242, 250),
			Transparency = 0.15,
			Thickness = 6,
			Label = "",
		},
		VipPhotographer = {
			Color = Color3.fromRGB(226, 187, 106),
			Transparency = 0,
			Thickness = 10,
			Label = "VIP",
		},
	},
}

return Theme
