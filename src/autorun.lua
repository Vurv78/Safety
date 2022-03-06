--[[
	Configs
]]

--- Creates a lookup table from an array table
---@param t table
---@return table
local function ToLUT(t)
	local lut = {}
	for i, v in pairs(t) do
		lut[v] = true
	end
	return lut
end

--- Returns a LUT from a plugin setting by splitting by whitespace and inverting the table
---@param setting string
---@return table
local function LUTSetting(setting)
	return ToLUT(Autorun.Plugin.Settings[setting])
end

---@param setting string
---@return table
local function ArraySetting(setting)
	return Autorun.Plugin.Settings[setting]
end

-- Bad Net Messages to use with net.Start, prevent them from executing. Checks equality
local BlockedNetMessages = LUTSetting("BlockedNetMessages")
local BlockedConcommands = LUTSetting("BlockedConcommands")
local BlockedPaths = LUTSetting("BlockedPaths")
local WhitelistedIPs = LUTSetting("WhitelistedIPs")

---@class FilePermission
local FilePermission = {
	readonly = 0,
	readwrite = 2, -- Also includes append.
	writeonly = 3,
	hidden = 4
}

--[[
	Folder structured as:
	FilePerms = {
		["GAME"] = {
			["e2files/*.txt"] = FilePermission.readonly
		}
	}

	Except keys are changed to be lua patterns by replacing * with [^/]+
]]
local FilePerms = Autorun.Plugin.Settings.FilePerms

do
	local out = {}
	for k, v in pairs(FilePerms) do
		local scope, rest = string.match(k, "^(%w+)|(.+)$")
		scope = scope or "DATA"
		rest = rest or k

		rest = string.gsub(rest, "%*", "[^/\\]+")

		out[scope] = out[scope] or {}
		out[scope][rest] =  FilePermission[v] or FilePermission.readonly
	end

	FilePerms = out
end

--[[
	Detours
]]

local d_stringgsub = string.gsub

--- Doesn't account for \0 but we shouldn't use that in URLs anyway.
---@param s string
---@return string pattern_safe
local function patternSafe(s)
	return d_stringgsub(s, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

local URLWhitelist = {}

do
	local simple_urls = ArraySetting("SimpleURLWhitelist")
	for k, url in ipairs(simple_urls) do
		URLWhitelist[k] = { patternSafe(url), false }
	end

	local pattern_urls = ArraySetting("PatternURLWhitelist")
	local len = #URLWhitelist
	for k, url in ipairs(pattern_urls) do
		URLWhitelist[k + len] = { url, true }
	end
end

local ProtectedMetatables = {
	[_G] = "_G",
	[debug.getregistry()] = "_R"
}

-- Globals
local d_format = string.format
local d_stringfind = string.find
local d_stringmatch = string.match
local d_stringgmatch = string.gmatch
local d_sub = string.sub

local d_random = math.random

local d_getinfo = debug.getinfo
local d_traceback = debug.traceback

local d_rawget = rawget
local d_rawset = rawset
local d_rawequal = rawequal

local d_setmetatable = setmetatable
local d_objsetmetatable = debug.setmetatable

local d_pairs = pairs
local d_ipairs = ipairs
local d_unpack = unpack

local d_type = type
local d_istable = istable
local d_isstring = isstring
local d_isnumber = isnumber
local d_isfunction = isfunction

local d_collectgarbage = collectgarbage
local d_error = error
local d_concat = table.concat

local d_char = string.char
local d_tostring = tostring

local WORLDSPAWN = game.GetWorld()
local _R = debug.getregistry()

---@class Color
---@field r number
---@field g number
---@field b number
---@field a number|nil

---@param r number
---@param g number
---@param b number
---@param a number|nil
---@return Color
local function RGB( r, g, b, a ) -- Mini color function
	return {r = r, g = g, b = b, a = a or 255}
end

local function getLocation(n)
	local data = d_getinfo(n, "S")
	return data and (data.source .. ":" .. n)
end

--- Todo make this palette not shit
local WHITE = RGB(255, 255, 255)
local BLACK = RGB(0, 0, 0)
local YELLOW = RGB(255, 255, 100)
local ALERT_COLOR = RGB(255, 0, 0)

--- Limits a string to dedicated length, or cuts off with ...
---@param str string
---@param len integer
local function limitString(str, len)
	if #str > (len - 3) then
		return str:sub(1, len) .. "..."
	else
		return str
	end
end

local function alert(...)
	MsgC( BLACK, "[", ALERT_COLOR, "Safety", BLACK, "]: ", WHITE, d_format(...), "\n", YELLOW, limitString(d_traceback(), 400), "\n" )
end

local LOGGER = {
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	DEBUG = 4,
	TRACE = 5
}

---@param urgency string
---@param fmt string
local function log(urgency, fmt, ...)
	if urgency <= LOGGER.WARN then
		alert(fmt, ...)
	end

	-- Atrocious debug.getinfo spam
	Autorun.log(
		d_format(fmt, ...) .. " -> " .. ( getLocation(6) or getLocation(5) or getLocation(4) or getLocation(3) or getLocation(2) ),
		urgency
	)
end

---@param mdl string
local function isMaliciousModel(mdl)
	-- https://github.com/Facepunch/garrysmod-issues/issues/4449
	return d_stringmatch(mdl, "%.([^.]+)$") == "bsp"
end

---@param url string
local function isWhitelistedURL(url)
	if not d_isstring(url) then return false end

	local relative = d_stringmatch(url, "^https?://(.*)")
	if not relative then return false end

	for _, data in d_ipairs(URLWhitelist) do
		local match, is_pattern = data[1], data[2]

		local haystack = is_pattern and relative or (d_stringmatch(relative, "(.-)/.*") or relative)
		if d_stringfind(haystack, "^" .. match .. (is_pattern and "" or "$") ) then
			return true
		end
	end

	return false
end

--- Returns the true size of a table, including the size of tables inside of that table.
--- Should be safe from infinite recursion.
---@param t table
---@param done table|nil
---@return number table_size
local function trueTableSize(t, done)
	local sz = 0
	sz = sz + #t
	done = done or { t }
	for k, v in d_pairs(t) do
		if not done[v] then
			done[v] = true
			done[k] = true
			if d_istable(k) then sz = sz + trueTableSize(k, done) end
			if d_istable(v) then sz = sz + trueTableSize(v, done) end
			done[v] = nil
			done[k] = nil
		end
	end
	return sz
end

--- Returns a locked version of table t.
---@param t table
---@return table locked_version
local function getLocked(t)
	return d_setmetatable({}, {
		__index = t,
		__newindex = function(_, k, v)
			-- Do not allow overwriting, which could cause crashes.
			if d_rawequal( d_rawget(t, k), nil ) then
				d_rawset(t, k, v)
			end
		end
	})
end

local LOCKED_REGISTRY = getLocked(_R)
ProtectedMetatables[LOCKED_REGISTRY] = "Locked _R"

local TYPE_NUMBER = "number"
local TYPE_STRING = "string"

--- Startup

jit.off()
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

local disabled = WhitelistedIPs[Autorun.IP]
MsgC (
	WHITE,
	string.format(Str, Autorun.Plugin.VERSION, Autorun.Plugin.AUTHOR),
	"\n\tStatus: ", disabled and RGB(255, 0, 0) or RGB(0, 255, 0), disabled and "DISABLED" or "ENABLED",
	WHITE,
	"\n=====================================================================\n"
)

if disabled then
	log(LOGGER.INFO, "IP is whitelisted: " .. Autorun.IP)
	return
end

--[[
	Detour Library
]]

local detours = { list = {}, hide = {} }

--- Returns the given hook to replace a function with.
---@param target function Func to hook
---@param replace_with fun(hook: function, args: ...) Func to return
---@return function hooked Hooked function that was given in ``replace_with``
function detours.attach( target, replace_with )
	local fn = function(...)
		return replace_with(target, ...)
	end
	detours.list[fn] = target
	return fn
end

--- Returns the original function that the function given hooked.
---@param hooked function Hooked function
---@return function original Original function to overwrite with.
---@return boolean @True if the hook was detached
function detours.detach( hooked )
	local ret = detours.list[hooked]
	detours.list[hooked] = nil
	return ret or hooked, ret and true or false
end

--- Returns the unhooked function if val is hooked.
-- Else returns ``val``
---@param val function Function to check. Can actually be any type though.
---@return function original Unhooked value or function.
---@return boolean Was the value hooked?
function detours.shadow( val )
	local v = detours.list[val]
	if v then
		return v, true
	end
	return val, false
end

--[[
	Detours
]]

local begunMeshes = {}
d_setmetatable(begunMeshes, {
	__mode = "k"
})

_G.mesh.Begin = detours.attach(mesh.Begin, function(hk, i_mesh, primitiveType, primiteCount)
	if i_mesh then
		if begunMeshes[i_mesh] then
			return log( LOGGER.WARN, "mesh.Begin called with a mesh that has already been started.")
		end
		begunMeshes[i_mesh] = true
	end
	hk(i_mesh, primitiveType, primiteCount)
end)

_G.RunConsoleCommand = detours.attach(RunConsoleCommand, function(hk, command, ...)
	local command_ty = d_type(command)
	if command_ty ~= TYPE_NUMBER and command_ty ~= TYPE_STRING then
		return hk(command, ...)
	end

	-- In case it's a number
	command = d_tostring(command)

	if BlockedConcommands[command] then
		return log( LOGGER.WARN, "Found blacklisted cmd [%q] being executed with RunConsoleCommand", command )
	end

	log(LOGGER.TRACE, "RunConsoleCommand(%s)", command)
	return hk(command, ...)
end)

-- This doesn't call the __newindex metamethod, so we need to patrol this func as well.
_G.table.insert = detours.attach(table.insert, function(hk, tbl, position, value)
	local key
	if d_istable(tbl) and position ~= nil then
		if value ~= nil then
			if d_isnumber(position) then
				key = position
			else
				-- Error
				return hk(tbl, position, value)
			end
		else
			-- Push value to top of table
			key = #tbl + 1
			value = position
		end

		if key > 2 ^ 31 - 1 then
			-- Key is too large, this would crash you. Just return the key to act as if it really did get pushed.
			log(LOGGER.WARN, "table.insert with massive key!")
			return key
		elseif trueTableSize(tbl) > 200000 then
			log(LOGGER.WARN, "table.insert with massive table!")
			return key
		end
	else
		-- Error
		return hk(tbl, position, value)
	end

	return hk(tbl, key, value)
end)

_G.debug.getinfo = detours.attach(debug.getinfo, function(hk, funcOrStackLevel, fields)
	return hk( detours.shadow(funcOrStackLevel), fields)
end)

_G.string.dump = detours.attach(string.dump, function(hk, func, stripDebugInfo)
	if not d_isfunction(func) then
		-- Error
		return hk(func)
	end
	return hk( detours.shadow(func), stripDebugInfo)
end)

_G.debug.getlocal = detours.attach(debug.getlocal, function(hk, thread, level, index)
	return hk( detours.shadow(thread), (level or 0) + 1, index) -- Same as debug.getinfo
end)

-- Prevent tostring crash with tostring(CreateSound(LocalPlayer(),''))
function _R.CSoundPatch.__tostring()
	return "CSoundPatch"
end

_G.tostring = detours.attach(tostring, function(hk, value)
	-- Could be used as an alternate form to string.format("%p", fn)
	return hk( detours.shadow(value) )
end)

--- Detour checking if the pointer is the same.
_G.string.format = detours.attach(string.format, function(hk, format, ...)
	local _t = d_type(format)
	if _t ~= "string" and _t ~= "number" then
		-- Should error
		return hk(format)
	end

	if not d_stringfind(format, "%%[ps]") then
		-- It's not going to try and get a ptr or tostring a function
		return hk(format, ...)
	end

	local T = {...}
	local did_shadow = false
	for k, arg in d_pairs(T) do
		local new, shadowed = detours.shadow(arg)
		if shadowed then
			did_shadow = true
		end
		T[k] = new
	end
	if did_shadow then
		log( LOGGER.INFO, "Detoured string.format(%q, ...)", format )
	end

	return hk( format, d_unpack(T) )
end)


_G.print = detours.attach(print, function(hk, ...)
	local t = {...}
	for k, arg in d_pairs(t) do
		t[k] = detours.shadow(arg)
	end
	return hk( d_unpack(t) )
end)

local JitCallbacks = {}

_G.jit.attach = detours.attach(jit.attach, function(hk, callback, event)
	-- Attaches jit to a function so they can get constants and protos from it. We will give it the original function.
	if not d_isfunction(callback) then
		-- Error
		return hk(callback)
	end

	JitCallbacks[callback] = event
	return hk( function(a)
		detours.shadow(callback)( detours.shadow(a) )
	end, event )
end)

-- Make lua language server happy..
_G.jit.util = _G.jit.util or {}

_G.jit.util.ircalladdr = detours.attach(jit.util.ircalladdr, function(hk, index)
	return hk(index)
end)

_G.jit.util.funcinfo = detours.attach(jit.util.funcinfo, function(hk, func, pos) -- Function that is basically Debug.getinfo
	return hk( detours.shadow(func), pos )
end)

_G.jit.util.funcbc = detours.attach(jit.util.funcbc, function(hk, func, pos)
	return hk( detours.shadow(func), pos )
end)

_G.jit.util.funck = detours.attach(jit.util.funck, function(hk, func, index)
	-- Function that returns a constant from a lua function, throws an error in native c++ functions which we want here.
	return hk( detours.shadow(func), index )
end)

_G.jit.util.funcuvname = detours.attach(jit.util.funcuvname, function(hk, func, index)
	return hk( detours.shadow(func), index )
end)

local SAFETY_MEMUSED
local function memcounter()
	local out = d_collectgarbage("count")
	if SAFETY_MEMUSED then
		return out - SAFETY_MEMUSED
	end
	return out
end

-- Using string indexing so gluafixer doesn't cry about gcinfo
_G["gcinfo"] = detours.attach(_G["gcinfo"], function()
	-- Incase in another function to avoid equality with collectgarbage
	return memcounter()
end)

_G.collectgarbage = detours.attach(collectgarbage, function(hk, action, arg)
	if d_rawequal(action, "count") then
		return memcounter()
	end
	return hk( action, arg )
end)

--[[
	Lua Hooks
]]

-- Function, mask, count
local _HookList = {
	current = {}
}

_G.debug.sethook = detours.attach(debug.sethook, function(hk, thread, hook, mask, count)
	return hk(thread, hook, mask, count)
	--[[
	if thread and count then
		-- Thread isn't omitted
		HookList["current"] = {hook, mask, count}
	else
		-- If thread is omitted
		HookList["current"] = {thread, hook, mask}
	end]]
end)

_G.debug.gethook = detours.attach(debug.gethook, function(hk, thread)
	-- return d_unpack(HookList["current"])
	return hk(thread)
end)

local fakeMetatables = d_setmetatable({}, {
	__mode = "k"
})

_G.setmetatable = detours.attach(setmetatable, function(hk, tab, metatable)
	if not d_istable(tab) or not d_istable(metatable) then
		-- Error
		return hk(tab, metatable)
	end

	local meta = fakeMetatables[tab] or {}
	if meta.__metatable ~= nil then
		return d_error("cannot change a protected metatable")
	else
		if ProtectedMetatables[tab] then
			fakeMetatables[tab] = metatable
			log(LOGGER.WARN, "Denied [set] access to protected metatable %q", ProtectedMetatables[tab])
			return tab
		end
		hk( detours.shadow(tab), metatable )
		return tab
	end
end)

_G.debug.setmetatable = detours.attach(debug.setmetatable, function(hk, object, metatable)
	if not d_istable(metatable) then
		-- Error
		return hk(object, metatable)
	end

	if ProtectedMetatables[object] then
		fakeMetatables[object] = metatable -- To pretend it actually got set.
		log(LOGGER.WARN, "Denied [set, debug] access to protected metatable %q", ProtectedMetatables[object])
		return true
	end
	return hk( detours.shadow(object), metatable )
end)

_G.getmetatable = detours.attach(getmetatable, function(hk, object)
	if ProtectedMetatables[object] then
		log( LOGGER.WARN, "Denied [get] access to protected metatable %q", ProtectedMetatables[object] )
		return fakeMetatables[object]
	end
	return hk( detours.shadow(object) )
end)

_G.debug.getmetatable = detours.attach(debug.getmetatable, function(hk, object)
	if ProtectedMetatables[object] then
		log( LOGGER.WARN, "Denied [get, debug] access to protected metatable %q", ProtectedMetatables[object] )
		return fakeMetatables[object]
	end
	return hk( detours.shadow(object) )
end)

_G.setfenv = detours.attach(setfenv, function(hk, location, enviroment)
	if d_rawequal(location, 0) then
		log(LOGGER.WARN, "Someone tried to setfenv(0, x)!") return
	end
	return hk( detours.shadow(location), enviroment)
end)

_G.debug.setfenv = detours.attach(debug.setfenv, function(hk, object, env)
	return hk(object, env)
end)


_G.debug.getfenv = detours.attach(debug.getfenv, function(hk, object)
	return hk( detours.shadow(object) )
end)

_G.FindMetaTable = detours.attach(FindMetaTable, function(hk, name)
	return LOCKED_REGISTRY[name]
end)

_G.debug.getregistry = detours.attach(debug.getregistry, function()
	return LOCKED_REGISTRY
end)

_G.debug.getupvalue = detours.attach(debug.getupvalue, function(hk, func, index)
	if not d_isnumber(index) or not d_isfunction(func) then
		-- Error
		return hk( func, index )
	end

	return hk( detours.shadow(func), index )
end)

_G.render.Capture = detours.attach(render.Capture, function(hk, captureData)
	log( LOGGER.WARN, "Someone attempted to screengrab with render.Capture" )
	if not captureData then return end

	local rnd = d_random(255)
	local buf = {}
	for i = 1, 500 do
		-- 500 * 5
		buf[i] = d_concat({ d_char( rnd * 0.25, rnd, rnd * 0.75, rnd * 0.5, rnd * 0.33 ) })
	end
	return d_concat(buf)
end)

_G.file.Delete = detours.attach(file.Delete, function(hk, name)
	local name_ty = d_type(name)
	if name_ty ~= TYPE_NUMBER and name_ty ~= TYPE_STRING then
		-- Error
		return hk(name)
	end

	log( LOGGER.WARN, "Someone attempted to delete file [%s]", name )
end)

-- Patches #1091 https://github.com/Facepunch/garrysmod-issues/issues/1091
local CamStack = 0

local function pushCam(hk, ...)
	CamStack = CamStack + 1
	hk(...)
end

local function popCam(hk)
	if CamStack == 0 then
		return log(LOGGER.WARN, "Attempted to pop cam without a valid context")
	end
	CamStack = CamStack - 1
	hk()
end

_G.cam.Start = detours.attach( cam.Start, pushCam )
_G.cam.Start3D2D = detours.attach( cam.Start3D2D, pushCam )
_G.cam.StartOrthoView = detours.attach( cam.StartOrthoView, pushCam )

_G.cam.End2D = detours.attach( cam.End2D, popCam )
_G.cam.End3D = detours.attach( cam.End3D, popCam )
_G.cam.End3D2D = detours.attach( cam.End3D2D, popCam )
_G.cam.End = detours.attach( cam.End, popCam )
_G.cam.EndOrthoView = detours.attach( cam.EndOrthoView, popCam )

local FILE_META = debug.getregistry().File

local function DO_NOTHING() end
local function RETURN(val) return function() return val end end

---@class ReadOnlyFile
local ReadOnlyFile = {
	Read = FILE_META.Read,
	ReadBool = FILE_META.ReadBool,
	ReadByte = FILE_META.ReadByte,
	ReadDouble = FILE_META.ReadDouble,
	ReadFloat = FILE_META.ReadFloat,
	ReadLong = FILE_META.ReadLong,
	ReadShort = FILE_META.ReadShort,
	ReadULong = FILE_META.ReadULong,
	ReadUShort = FILE_META.ReadUShort,
	ReadLine = FILE_META.ReadLine,

	Write = detours.attach( FILE_META.Write, DO_NOTHING ),
	WriteBool = detours.attach( FILE_META.WriteBool, DO_NOTHING ),
	WriteByte = detours.attach( FILE_META.WriteByte, DO_NOTHING ),
	WriteDouble = detours.attach( FILE_META.WriteDouble, DO_NOTHING ),
	WriteFloat = detours.attach( FILE_META.WriteFloat, DO_NOTHING ),
	WriteLong = detours.attach( FILE_META.WriteLong, DO_NOTHING ),
	WriteShort = detours.attach( FILE_META.WriteShort, DO_NOTHING ),
	WriteULong = detours.attach( FILE_META.WriteULong, DO_NOTHING ),
	WriteUShort = detours.attach( FILE_META.WriteUShort, DO_NOTHING ),

	__tostring = FILE_META.__tostring,
	Size = FILE_META.Size,
	Close = FILE_META.Close,
	Flush = FILE_META.Flush,
	EndOfFile = FILE_META.EndOfFile,
	Tell = FILE_META.Tell,
	Seek = FILE_META.Seek,
	Skip = FILE_META.Skip
}

---@class WriteOnlyFile
local WriteOnlyFile = {
	Write = FILE_META.Write,
	WriteBool = FILE_META.WriteBool,
	WriteByte = FILE_META.WriteByte,
	WriteDouble = FILE_META.WriteDouble,
	WriteFloat = FILE_META.WriteFloat,
	WriteLong = FILE_META.WriteLong,
	WriteShort = FILE_META.WriteShort,
	WriteULong = FILE_META.WriteULong,
	WriteUShort = FILE_META.WriteUShort,

	Read = detours.attach( FILE_META.Read, RETURN("") ),
	ReadBool = detours.attach( FILE_META.ReadBool, RETURN(false) ),
	ReadByte = detours.attach( FILE_META.ReadByte, RETURN(0) ),
	ReadDouble = detours.attach( FILE_META.ReadDouble, RETURN(0) ),
	ReadFloat = detours.attach( FILE_META.ReadFloat, RETURN(0) ),
	ReadLong = detours.attach( FILE_META.ReadLong, RETURN(0) ),
	ReadShort = detours.attach( FILE_META.ReadShort, RETURN(0) ),
	ReadULong = detours.attach( FILE_META.ReadULong, RETURN(0) ),
	ReadUShort = detours.attach( FILE_META.ReadUShort, RETURN(0) ),
	ReadLine = detours.attach( FILE_META.ReadLine, RETURN("") ),

	__tostring = FILE_META.__tostring,
	Size = FILE_META.Size,
	Close = FILE_META.Close,
	Flush = FILE_META.Flush,
	EndOfFile = FILE_META.EndOfFile,
	Tell = FILE_META.Tell,
	Seek = FILE_META.Seek,
	Skip = FILE_META.Skip
}

ReadOnlyFile.__index = ReadOnlyFile
WriteOnlyFile.__index = WriteOnlyFile


local ValidModes = ToLUT( { "rb", "r", "w", "wb", "a", "ab" } )
local ModePerms = {
	["r"] = {
		[FilePermission.readonly] = true,
		[FilePermission.readwrite] = true
	},
	["rb"] = {
		[FilePermission.readonly] = true,
		[FilePermission.readwrite] = true
	},
	["w"] = {
		[FilePermission.writeonly] = true,
		[FilePermission.readwrite] = true
	},
	["wb"] = {
		[FilePermission.writeonly] = true,
		[FilePermission.readwrite] = true
	},
	["a"] = {
		[FilePermission.readwrite] = true,
		[FilePermission.writeonly] = true
	},
	["ab"] = {
		[FilePermission.readwrite] = true,
		[FilePermission.writeonly] = true
	}
}

local HandleMetas = {
	["rb"] = ReadOnlyFile,
	["r"] = ReadOnlyFile,
	["wb"] = WriteOnlyFile,
	["w"] = WriteOnlyFile,
	["ab"] = WriteOnlyFile,
	["a"] = WriteOnlyFile
}

---@param path string
---@param scope string?
---@return FilePermission?
local function permFromPath(path, scope)
	if scope then
		if not FilePerms[scope] then
			return
		end
		for pattern, perm in pairs(FilePerms[scope]) do
			local match = d_stringfind(path, pattern)
			if match then
				return perm
			end
		end
	else
		for scope2, v in pairs(FilePerms) do
			for pattern, perm in pairs(FilePerms[scope2]) do
				local match = d_stringfind(path, pattern)
				if match then
					return perm
				end
			end
		end
	end
end

_G.file.Open = detours.attach(file.Open, function(hk, path, mode, scope)
	if not scope or not d_isstring(mode) then
		-- Error
		return hk(path, mode, scope)
	end

	if not ValidModes[mode] then
		-- Error
		return hk(path, mode, scope)
	end

	if FilePerms[scope] then
		local mode_required_perms = ModePerms[mode]

		path = d_tostring(path)
		for pattern, perm in pairs(FilePerms[scope]) do
			local match = d_stringfind(path, pattern)
			if match then
				if perm == FilePermission.hidden then
					return nil
				elseif mode_required_perms[perm] then
					local handle = hk(path, mode, scope)
					d_setmetatable(handle, HandleMetas[mode])
				else
					log(LOGGER.WARN, "Access denied to file %q for scope %q. Need permission %s", path, scope, perm)
				end
			end
		end
	end
end)

_G.file.Rename = detours.attach(file.Rename, function(hk, path, to)
	local perm = permFromPath(path, "DATA")
	local perm2 = permFromPath(to, "DATA")
	if perm == FilePermission.hidden or FilePermission.readonly then
		log(LOGGER.WARN, "Someone tried to rename file [%s] with filename %s", path, to)
		return false
	elseif perm2 == FilePermission.hidden or perm2 == FilePermission.readonly then
		-- Trying to move a file into a restricted directory
		log(LOGGER.WARN, "Someone tried to rename file [%s] with filename %s", path, to)
		return false
	end

	return hk(path, to)
end)

_G.file.Time = detours.attach(file.Time, function(hk, path, scope)
	local perm = permFromPath(path, scope)
	if perm == FilePermission.hidden or perm == FilePermission.writeonly then
		log(LOGGER.WARN, "Someone tried to get the time of file [%s]", path)
		return 0
	end
	return hk(path, scope)
end)

_G.file.IsDir = detours.attach(file.IsDir, function(hk, path, scope)
	local perm = permFromPath(path, scope)
	if perm == FilePermission.hidden then
		log(LOGGER.WARN, "Someone tried to check if file [%s] is a directory", path)
		return false
	end
	return hk(path, scope)
end)

_G.file.Exists = detours.attach(file.Exists, function(hk, path, scope)
	local perm = permFromPath(path, scope)
	if perm == FilePermission.hidden then
		log(LOGGER.WARN, "Someone tried to check if file [%s] exists", path)
		return false
	end
	return hk(path, scope)
end)

_G.file.Size = detours.attach(file.Size, function(hk, path, scope)
	local perm = permFromPath(path, scope)
	if perm == FilePermission.hidden then
		log(LOGGER.WARN, "Someone tried to get the size of file [%s]", path)
		return 0
	end
	return hk(path, scope)
end)

_G.file.Find = detours.attach(file.Find, function(hk, path, scope, sorting)
	local perm = permFromPath(path, scope)

	if perm == FilePermission.hidden then
		log(LOGGER.WARN, "Someone tried to find files in directory [%s]", path)
		return {}, {}
	end

	return hk(path, scope, sorting)
end)

_G.file.AsyncRead = detours.attach(file.AsyncRead, function(hk, path, scope, callback, sync)
	local perm = permFromPath(path, scope or "DATA")
	if perm == FilePermission.hidden or perm == FilePermission.writeonly then
		log(LOGGER.WARN, "Someone tried to async read file [%s]", path)

		callback(path, scope, -1)
		return 0
	end
	return hk(path, scope, callback, sync)
end)

_G.net.Start = detours.attach(net.Start, function(hk, str, unreliable)
	if BlockedNetMessages[str] then
		return log(LOGGER.INFO, "Blocked net.Start(%q, %s)!", str, unreliable)
	end
	log( LOGGER.TRACE, "net.Start(%s, %s)", str, unreliable )

	return hk(str,unreliable)
end)

local MAX_REP = 1000000
_G.string.rep = detours.attach(string.rep, function(hk, str, reps, sep)
	-- Max string.rep length is 1,000,000
	if #str * reps + ( d_isstring(sep) and #sep or 0 ) * reps > MAX_REP then
		return log(LOGGER.EVIL, "Someone tried to string.rep with a fucking massive return string!")
	end
	return hk(str, reps, sep)
end)

_G.ClientsideModel = detours.attach(ClientsideModel, function(hk, model, rendergroup)
	if not d_isstring(model) then return end
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Someone tried to create a ClientsideModel with a .bsp model!")
	end
	return hk(model, rendergroup)
end)

_G.ClientsideScene = detours.attach(ClientsideScene, function(hk, model, targetEnt)
	if not d_isstring(model) then return end
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Someone tried to create a ClientsideScene with a .bsp model!")
	end
	return hk(model, targetEnt)
end)

_G.ClientsideRagdoll = detours.attach(ClientsideRagdoll, function(hk, model, rendergroup)
	if not d_isstring(model) then return end
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Someone tried to create a ClientsideRagdoll with a .bsp model!")
	end
	return hk(model, rendergroup)
end)

_G.ents.CreateClientProp = detours.attach(ents.CreateClientProp, function(hk, model)
	if not d_isstring(model) then model = "models/error.mdl" end
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Someone tried to create a malicious ClientProp with a .bsp model!")
	end
	return hk(model)
end)

-- Todo: Stuff with these
_G.CompileString = detours.attach(CompileString, function(hk, code, identifier, handleError)
	return hk(code, identifier, handleError)
end)

_G.RunString = detours.attach(RunString, function(hk, code, identifier, handleError)
	return hk(code, identifier, handleError)
end)

_G.RunStringEx = detours.attach(RunStringEx, function(hk, code, identifier, handleError)
	return hk(code, identifier, handleError)
end)

_G.game.MountGMA = detours.attach(game.MountGMA, function(hk, path)
	log( LOGGER.INFO, "Mounting GMA: %q", path )
	return hk(path)
end)


--- https://github.com/Facepunch/garrysmod-issues/issues/3637
local ISSUE_3637 = {"env_fire", "entityflame", "_firesmoke"}

_G.game.CleanUpMap = detours.attach(game.CleanUpMap, function(hk, dontSendToClients, extraFilters)
	if d_istable(extraFilters) then
		local len = #extraFilters
		d_rawset(extraFilters, len + 1, "env_fire")
		d_rawset(extraFilters, len + 2, "entityflame")
		d_rawset(extraFilters, len + 3, "_firesmoke")
	else
		return hk(dontSendToClients, ISSUE_3637)
	end

	hk(dontSendToClients, extraFilters)
end)

_G.gui.OpenURL = detours.attach(gui.OpenURL, function(hk, url)
	if not isWhitelistedURL(url) then
		return log( LOGGER.INFO, "Blocked unwhitelisted gui.OpenURL(%q)", url )
	end
	log( LOGGER.INFO, "gui.OpenURL(%q)", url )
	return hk(url)
end)

_G.gui.HideGameUI = detours.attach(gui.HideGameUI, function(hk)
	log( LOGGER.INFO, "Blocked gui.HideGameUI" )
end)

_G.AddConsoleCommand = detours.attach(AddConsoleCommand, function(hk, name, helpText, flags)
	-- Garry used to have it so that adding a console command named 'sendrcon' would crash your game.
	-- Malicious anticheats and others would abuse this. I'm not sure if adding sendrcon even still crashes you.
	-- https://github.com/CookieMaster/GMD/blob/11eae396d7448df325601d748ee09293ba0dd5c3/Addons/ULX%20Addons/custom-ulx-commands-and-utilities-23-1153/CustomCommands/lua/ulx/modules/sh/cc_util(2).lua

	if d_isstring(name) and d_stringfind(name, "sendrcon") then
		return log( LOGGER.EVIL, "Someone tried to crash by adding 'sendrcon' as a concmd" )
	end

	hk(name, helpText, flags)
end)

_G.os.date = detours.attach(os.date, function(hk, format, time)
	-- Patches #329 https://github.com/Facepunch/garrysmod-issues/issues/329
	if d_isstring(format) then
		for v in d_stringgmatch(format, "%%(.?)") do
			if not d_stringmatch(v, "[%%aAbBcCdDSHeUmMjIpwxXzZyY]") then
				return log(LOGGER.EVIL, "Blocked evil os.date format!")
			end
		end
	end
	return hk(format, time)
end)

_G.sound.PlayURL = detours.attach(sound.PlayURL, function(hk, url, flags, callback)
	if not isWhitelistedURL(url) then
		return log( LOGGER.WARN, "Blocked sound.PlayURL(%q, %q, %p)", url, flags, callback )
	end

	log( LOGGER.INFO, "sound.PlayURL(%q, %q, %p)", url, flags, callback )
	return hk(url, flags, callback)
end)

_G.HTTP = detours.attach(HTTP, function(hk, parameters)
	if not d_istable(parameters) then
		return hk(parameters)
	end

	local url = d_rawget(parameters, "url")
	if url and not isWhitelistedURL(url) then
		log( LOGGER.WARN, "Blocked HTTP(%q)", url)

		local onfailure = d_rawget(parameters, "onfailure")
		if d_isfunction(onfailure) then
			onfailure("unsuccessful")
		end
		return
	end

	return hk(parameters)
end)

-- Registry detours
_R.Player.ConCommand = detours.attach(_R.Player.ConCommand, function(hk, ply, cmd_str)
	if not ply or not d_isstring(cmd_str) then
		return hk(ply, cmd_str)
	end

	local command = d_stringmatch(cmd_str, "^(%S+)")
	if BlockedConcommands[command] then
		return log( LOGGER.WARN, "Found blacklisted cmd [%q] being executed with Self:ConCommand(%q)", command, cmd_str)
	end

	return hk(ply, cmd_str)
end)

_R.Entity.SetModel = detours.attach(_R.Entity.SetModel, function(hk, ent, modelName)
	if not d_isstring(modelName) then return end
	if isMaliciousModel(modelName) then
		return log(LOGGER.EVIL, "Entity:SetModel(%s) blocked!", modelName) -- Crash
	end
	hk(ent, modelName)
end)

local ISSUE_4116
ISSUE_4116 = detours.attach(_R.Entity.DrawModel, function(hk, ent, flags)
	-- Patches #2688 https://github.com/Facepunch/garrysmod-issues/issues/2688
	if ent == WORLDSPAWN then
		return log(LOGGER.EVIL, "Entity.DrawModel called with worldspawn")
	end

	-- Fixes #4116 https://github.com/Facepunch/garrysmod-issues/issues/4116
	_R.Entity.DrawModel = function() end -- disable function
	local ok, err = pcall(hk, ent, flags)
	_R.Entity.DrawModel = ISSUE_4116

	if not ok then
		log(LOGGER.INFO, "Entity.DrawModel failed: %s", err)
		error(err, 2)
	end
end)

_R.Entity.DrawModel = ISSUE_4116


--- The detour library makes a new closure for detours anyway, so there's no issue with sharing functions.
local function Checksum(hk, str)
	if not d_isstring(str) then
		return hk(str)
	end

	if #str > 1e7 then
		str = d_sub(str, 1, 1e7)
		return
	end

	return hk(str)
end

_G.util.MD5 = detours.attach(util.MD5, Checksum)
_G.util.SHA1 = detours.attach(util.SHA1, Checksum)
_G.util.SHA256 = detours.attach(util.SHA256, Checksum)

SAFETY_MEMUSED = d_collectgarbage("count")