--[[
	Configs
]]

local require = Autorun.require

local Settings = require("settings")
local Palette = require("palette.lua")
local Util = require("util")

-- Note the lack of _G. This is to only be used in autorun files
Detour = require("detour")

local d_format = string.format
local d_getinfo = debug.getinfo
local d_traceback = debug.traceback
local d_collectgarbage = collectgarbage

local function getLocation(n)
	local data = d_getinfo(n, "S")
	return data and (data.source .. ":" .. n)
end

local function alert(...)
	MsgC (
		Palette.BLACK, "[", Palette.LOGO, "Safety", Palette.BLACK, "]: ",
		Palette.WHITE, d_format(...), "\n",
		Palette.YELLOW, Util.limitString(d_traceback(), 400), "\n"
	)
end

LOGGER = {
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	DEBUG = 4,
	TRACE = 5
}

local alert_level = LOGGER[Autorun.Plugin.Settings.AlertLevel] or LOGGER.WARN

---@param urgency string
---@param fmt string
function Log(urgency, fmt, ...)
	if urgency <= alert_level then
		Autorun.print( Palette.WHITE, "[", Palette.LOGO, "Safety", Palette.WHITE, "]:", d_format(fmt, ...) )
	end

	-- Atrocious debug.getinfo spam
	Autorun.log(
		d_format(fmt, ...) .. " -> " .. ( getLocation(6) or getLocation(5) or getLocation(4) or getLocation(3) or getLocation(2) ),
		urgency
	)
end

--- Startup
local Str = [[
=====================================================================

    ad88888ba                  ad88
    d8"     "8b                d8"                 ,d
    Y8,                        88                  88
    `Y8aaaaa,    ,adPPYYba,  MM88MMM  ,adPPYba,  MM88MMM  8b       d8
      `"""""8b,  ""     `Y8    88    a8P_____88    88     `8b     d8'
            `8b  ,adPPPPP88    88    8PP"""""""    88      `8b   d8'
    Y8a     a8P  88,    ,88    88    "8b,   ,aa    88,      `8b,d8'
     "Y88888P"   `"8bbdP"Y8    88     `"Ybbd8"'    "Y888      Y88'
                                                              d8'
                                                             d8'
                    Version %s
                    by %s
]]

local disabled = Settings.WhitelistedIPs[Autorun.IP]
MsgC (
	d_format(Str, Autorun.Plugin.VERSION, Autorun.Plugin.AUTHOR),
	"\n\tStatus: ", disabled and { r = 255, g = 0, b = 0 } or { r = 0, g = 255, b = 0 }, disabled and "DISABLED" or "ENABLED",
	{ r = 255, g = 255, b = 255 },
	"\n=====================================================================\n"
)

if disabled then
	Log(LOGGER.INFO, "IP is whitelisted: " .. Autorun.IP)
	return
end

--[[
	Run detours
]]

LOCKED_REGISTRY = Util.getLocked( debug.getregistry() )

local SAFETY_MEMUSED
function MemCounter()
	local out = d_collectgarbage("count")
	if SAFETY_MEMUSED then
		return out - SAFETY_MEMUSED
	end
	return out
end

for _, v in pairs {"builtins", "cam", "debug", "ents", "file", "game", "gui", "http", "jit", "mesh", "mtable", "net", "os", "registry", "render", "sound", "string", "table", "util"} do
	require( "detour/" .. v )
end

SAFETY_MEMUSED = d_collectgarbage("count")
