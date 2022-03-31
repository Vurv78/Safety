-- Ayu Mirage Theme

---@class Color
---@field r number
---@field g number
---@field b number

---@param r number
---@param g number
---@param b number
---@return Color
local function rgb( r, g, b)
	return {r, g, b}
end

local Palette = {
	BLACK = rgb(25, 30, 42),
	RED = rgb(237, 130, 116),
	GREEN = rgb(166, 204, 112),
	YELLOW = rgb(250, 208, 123),
	BLUE = rgb(109, 203, 250),
	PURPLE = rgb(207, 186, 250),
	CYAN = rgb(144, 225, 198),
	WHITE = rgb(199, 199, 199),
	BRIGHT_BLACK = rgb(104, 104, 104),
	BRIGHT_RED = rgb(242, 135, 121),
	BRIGHT_GREEN = rgb(186, 230, 126),
	BRIGHT_YELLOW = rgb(255, 213, 130),
	BRIGHT_BLUE = rgb(115, 208, 255),
	BRIGHT_PURPLE = rgb(212, 191, 255),
	BRIGHT_CYAN = rgb(149, 229, 194),
	BRIGHT_WHITE = rgb(255, 255, 255),
	BACKGROUND = rgb(31, 36, 48),
	FOREGROUND = rgb(203, 204, 198),
	SELECTION_BACKGROUND = rgb(51, 65, 94),
	CURSOR_COLOR = rgb(255, 204, 102)
}

Palette.LOGO = Palette.BRIGHT_GREEN

return Palette