--[[
   ______            _____
  / ____/___  ____  / __(_)___ ______
 / /   / __ \/ __ \/ /_/ / __ `/ ___/
/ /___/ /_/ / / / / __/ / /_/ (__  )
\____/\____/_/ /_/_/ /_/\__, /____/
					   /____/
]]

---@diagnostic disable:undefined-global
---@diagnostic disable:undefined-field

-- Files to hide in file reading and writing / lock.
-- If a path contains any of these keywords, it will be blocked. Uses string.find
local BlockedPaths = {
	"sf_filedata",
	"e2files",
	"starfall",
	"expression2"
}

-- Commands to not let execute in RunConsoleCommand.
-- Ply:ConCommand will also use these. (These are lua patterns)
local BlacklistedConCommands = {
	"voicerecord",
	"retry",
	"startmovie",
	"endmovie",
	"^playdemo$",
	"^play$",
	"bind",
	"unbindall",
	"exit",
	"fov",
	"sendrcon",
	"cl_timeout",
	"screenshot requested",
	"screenshot"
}

-- Bad Net Messages to use with net.Start, prevent them from executing. Checks equality
local BlacklistedNetMessages = {
	["ash_ban"] = true,
	["pac_to_contraption"] = true,
	["pac_modify_movement"] = true,
	["pac_projectile"] = true,
	["pac.AllowPlayerButtons"] = true,
	["pac_request_precache"] = true,
	["pac_setmodel"] = true,
	["pac_update_playerfilter"] = true,
	["pac_in_editor"] = true,
	["pac_footstep"] = true
}

local d_stringgsub = string.gsub

--- Doesn't account for \0 but we shouldn't use that in URLs anyway.
---@param s string
---@return string pattern_safe
local function patternSafe(s)
	return d_stringgsub(s, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

local function pattern(str) return { str, true } end
local function simple(str) return { patternSafe(str), false } end

--- URL Whitelist. sound.PlayURL and HTTP/Whatever will be forced to use this.
local URLWhitelist = {
	-- Soundcloud
	pattern [[%w+%.sndcdn%.com/.+]],

	-- Google Translate Api, Needs an api key.
	simple [[translate.google.com]],

	-- Discord
	pattern [[cdn[%w-_]*%.discordapp%.com/.+]],

	-- Reddit
	simple [[i.redditmedia.com]],
	simple [[i.redd.it]],
	simple [[preview.redd.it]],

	-- Shoutcast
	simple [[yp.shoutcast.com]],

	-- Dropbox
	simple [[dl.dropboxusercontent.com]],
	pattern [[%w+%.dl%.dropboxusercontent%.com/(.+)]],
	simple [[www.dropbox.com]],
	simple [[dl.dropbox.com]],

	-- Github
	simple [[raw.githubusercontent.com]],
	simple [[gist.githubusercontent.com]],
	simple [[raw.github.com]],
	simple [[cloud.githubusercontent.com]],

	-- Steam
	simple [[steamuserimages-a.akamaihd.net]],
	simple [[steamcdn-a.akamaihd.net]],

	-- Gitlab
	simple [[gitlab.com]],

	-- Onedrive
	simple [[onedrive.live.com/redir]],

	simple [[youtubedl.mattjeanes.com]],

	simple [[google.com]],
}

--[[
	Make sure debug.getinfo(1).name and .namewhat don't appear

	jit.util.traceir
	jit.util.tracek
	jit.util.tracemc
	jit.util.tracesnap
	collectgarbage
	gcinfo

	Detour vgui functions
]]

local ProtectedMetatables = {
	[_G] = "_G",
	[debug.getregistry()] = "_R"
}

-- Globals
local d_format = string.format
local d_stringfind = string.find
local d_stringmatch = string.match
local d_stringgmatch = string.gmatch

local d_date = os.date
local d_random = math.random

local d_getinfo = debug.getinfo
local d_traceback = debug.traceback

local d_rawget = rawget
local d_rawset = rawset
local d_setmetatable = debug.setmetatable
local d_getmetatable = debug.getmetatable
local d_pairs = pairs
local d_ipairs = ipairs
local d_unpack = unpack

local d_type = type
local d_istable = istable
local d_isstring = isstring
local d_isnumber = isnumber

local d_error = error

local WORLDSPAWN = game.GetWorld()
local _R = debug.getregistry()

local COLOR = {}
COLOR.__index = COLOR

---@class Color
---@field r number
---@field g number
---@field b number
---@field a number?

---@param r number
---@param g number
---@param b number
---@param a number?
---@return Color
local function Color( r, g, b, a ) -- Mini color function
	return setmetatable( {r = r, g = g, b = b, a = a or 255}, COLOR )
end

local function getLocation(n)
	local data = d_getinfo(n, "S")
	return data and (data.source .. ":" .. n)
end

--- Todo make this palette not shit
local WHITE = Color(255, 255, 255)
local PRIMARY_COLOR = Color(117, 133, 143)
local SECONDARY_COLOR = Color(130, 224, 171)
local TERTIARY_COLOR = Color(3, 161, 252)
local ALERT_COLOR = Color(255, 0, 0)

local printColor = chat.AddText

local function alert(...)
	printColor( PRIMARY_COLOR, "Safety" , WHITE, ": ", ALERT_COLOR, d_format(...) )
	printColor( PRIMARY_COLOR, "Time: ", TERTIARY_COLOR, d_date() )
	printColor( SECONDARY_COLOR, d_traceback() )
end

local LOGGER = {
	WARN = "WARN",
	INFO = "INFO",
	EVIL = "EVIL"
}

---@param urgency string
local function log(urgency, ...)
	if urgency == LOGGER.EVIL then
		alert(...)
	end
	-- Atrocious debug.getinfo spam
	sautorun.log( d_format("[%s] -> ", urgency) .. d_format(...) .. " -> " .. ( getLocation(6) or getLocation(5) or getLocation(4) or getLocation(3) or getLocation(2) ) )
end

---@param mdl string
local function isMaliciousModel(mdl)
	-- https://github.com/Facepunch/garrysmod-issues/issues/4449
	if d_stringmatch(mdl, ".*%.(.*)") == "bsp" then return true end
	return false
end

---@param url string
local function isWhitelistedURL(url)
	if not d_isstring(url) then return false end

	local relative = d_stringmatch(url, "^https?://(.*)")
	if not relative then return false end

	for _, data in ipairs(URLWhitelist) do
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
---@param done table?
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

--- Cheap check if two tables equal in their values
---@param t table
---@param t2 table
---@return boolean mostly_copied
local function isTableMostlyCopied(t, t2)
	if not d_istable(t) or not d_istable(t2) then return false end
	if d_getmetatable(t) ~= d_getmetatable(t2) then return false end

	for k, v in d_pairs(t) do
		if t2[k] ~= v then return false end
	end
	return true
end

--- Returns a locked version of table t.
---@param t table
---@return table locked_version
local function getLocked(t)
	return d_setmetatable({}, {
		__index = t,
		__newindex = function(_, k, v)
			-- Do not allow overwriting, which could cause crashes.
			if d_rawget(t, k) == nil then
				d_rawset(t, k, v)
			end
		end
	})
end

local LOCKED_REGISTRY = getLocked(_R)
ProtectedMetatables[LOCKED_REGISTRY] = "Locked _R"

--- Startup

jit.off()
sautorun.log( "Safety <--" )

--- Detour Library
-- https://github.com/Vurv78/lua/blob/master/LuaJIT/Libraries/skid_detours.lua

-- Skid Detour library based off of msdetours.

local detours = { list = {}, hide = {} }
local d_setfenv = _G.setfenv

--- Returns the given hook to replace a function with.
---@param target function Func to hook
---@param replace_with function Func to return
---@return function hooked Hooked function that was given in ``replace_with``
function detours.attach( target, replace_with )
	local env = setmetatable({ __undetoured = target },{
		__index = _G,
		__newindex = _G
	})
	d_setfenv(replace_with, env)
	detours.list[replace_with] = target
	return replace_with
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
---@return boolean #Was the value hooked?
function detours.shadow( val )
	local v = detours.list[val]
	if v then
		return v, true
	end
	return val, false
end

--[[
	____       __
   / __ \___  / /_____  __  ____________
  / / / / _ \/ __/ __ \/ / / / ___/ ___/
 / /_/ /  __/ /_/ /_/ / /_/ / /  (__  )
/_____/\___/\__/\____/\__,_/_/  /____/

]]

local begunMeshes = {}
d_setmetatable(begunMeshes, {
	__mode = "k"
})

_G.mesh.Begin = detours.attach(mesh.Begin, function(mesh, primitiveType, primiteCount)
	if mesh then
		if begunMeshes[mesh] then return log( LOGGER.WARN, "mesh.Begin called with a mesh that has already been started.") end
		begunMeshes[mesh] = true
	end
	__undetoured(mesh, primitiveType, primiteCount)
end)

_G.RunConsoleCommand = detours.attach(RunConsoleCommand, function(command, ...)
	for _, blacklisted in d_ipairs(BlacklistedConCommands) do
		if d_stringfind(command, blacklisted) then
			return log( LOGGER.WARN, "Found blacklisted cmd ['%s'] being executed with RunConsoleCommand", command )
		end
	end
	log(LOGGER.INFO, "RunConsoleCommand(%s)", command)
	return __undetoured(command, ...)
end)

-- Behaves exactly like table.insert
local function pureLuaInsert(tab, key, val)
	if not d_istable(tab) then return end

	if val~=nil then
		if not d_isnumber(key) then return end
		for k = #tab, key, -1 do
			tab[k+1] = tab[k]
		end
		d_rawset(tab, key, val)
		return key
	elseif key ~= nil then
		local ind = #tab+1
		d_rawset(tab, ind, key)
		return ind
	end
end

-- This doesn't call the __newindex metamethod, so we need to patrol this func as well.
_G.table.insert = detours.attach(table.insert, function(myTable, key, value)
	if myTable and d_istable(myTable) then
		if #myTable > 100000 then log(LOGGER.WARN, "Table") return end
		if trueTableSize(myTable) > 100000 then return log(LOGGER.WARN, "trueTableSize in table.insert was too large!") end
		if d_istable(value) and isTableMostlyCopied(myTable, value) then return log(LOGGER.WARN, "Copied table found in table.insert, lag/crash attempt?") end
	end
	if value~=nil and d_isnumber(key) and key > 2^31-1 then return log(LOGGER.WARN, "table.insert with massive key!") end
	return pureLuaInsert(myTable, key, value)
end)

_G.debug.getinfo = detours.attach(debug.getinfo, function(funcOrStackLevel, fields)
	return __undetoured( detours.shadow(funcOrStackLevel), fields)
end)

_G.string.dump = detours.attach(string.dump, function(func, stripDebugInfo)
	return __undetoured( detours.shadow(func), stripDebugInfo)
end)

_G.debug.getlocal = detours.attach(debug.getlocal, function(thread, level, index)
	return __undetoured( detours.shadow(thread), (level or 0) + 1, index) -- Same as debug.getinfo
end)

_G.tostring = detours.attach(tostring, function(value)
	if d_type(value) == "CSoundPatch" then return "CSoundPatch" end
	-- Prevent tostring crash with tostring(CreateSound(LocalPlayer(),''))
	return __undetoured( detours.shadow(value) )
end)

--- Detour checking if the pointer is the same.
_G.string.format = detours.attach(string.format, function(format, ...)
	if format and d_stringfind(format, "%%p") then
		-- Whether its gonna try and find a pointer or not.
		return __undetoured(format, ...)
	end

	local T = {...}
	local did_shadow = false
	for k, arg in pairs(T) do
		local new, shadowed = detours.shadow(arg)
		if shadowed then
			did_shadow = true
		end
		T[k] = new
	end
	if did_shadow then
		log( LOGGER.INFO, "Detoured string.format('%s', ...)", format )
	end

	return __undetoured( format, d_unpack(T) )
end)


_G.print = detours.attach(print, function(...)
	local t = {...}
	for k, arg in d_pairs(t) do
		t[k] = detours.shadow(arg) -- Won't log detouring
	end
	return __undetoured( d_unpack(t) )
end)

local JitCallbacks = {}

_G.jit.attach = detours.attach(jit.attach, function(callback, event)
	-- Attaches jit to a function so they can get constants and protos from it. We will give it the original function.
	JitCallbacks[callback] = event
	return __undetoured( detours.shadow(callback), event )
end)

-- cool
--[[_G.jit.deattach = function()
	for Callback,Event in pairs(JitCallbacks) do
		d_jitattach(Callback)
		JitCallbacks[Callback] = nil
		printf("Unhooked jit.attach %s",Event)
	end
end]]

_G.jit.util.ircalladdr = detours.attach(jit.util.ircalladdr, function(index)
	return __undetoured(index)
end)

_G.jit.util.funcinfo = detours.attach(jit.util.funcinfo, function(func, pos) -- Function that is basically Debug.getinfo
	return __undetoured( detours.shadow(func), pos )
end)

_G.jit.util.funcbc = detours.attach(jit.util.funcbc, function(func, pos)
	return __undetoured( detours.shadow(func), pos )
end)

_G.jit.util.funck = detours.attach(jit.util.funck, function(func, index)
	-- Function that returns a constant from a lua function, throws an error in native c++ functions which we want here.
	return __undetoured( detours.shadow(func), index )
end)

_G.jit.util.funcuvname = detours.attach(jit.util.funcuvname, function(func, index)
	return __undetoured( detours.shadow(func), index )
end)

--[[
	Lua Hooks
]]

-- Function, mask, count
local HookList = {
	current = {}
}

_G.debug.sethook = detours.attach(debug.sethook, function(thread, hook, mask, count)
	return __undetoured(thread, hook, mask, count)
	--[[
	if thread and count then
		-- Thread isn't omitted
		HookList["current"] = {hook, mask, count}
	else
		-- If thread is omitted
		HookList["current"] = {thread, hook, mask}
	end]]
end)

_G.debug.gethook = detours.attach(debug.gethook, function(thread)
	--return d_unpack(HookList["current"])
	return __undetoured(thread)
end)

local fakeMetatables = d_setmetatable({}, {
	__mode = "k"
})

_G.setmetatable = detours.attach(setmetatable, function(object, metatable)
	local meta = fakeMetatables[object] or {}
	if meta.__metatable ~= nil then
		return d_error("cannot change a protected metatable")
	else
		if ProtectedMetatables[object] then
			fakeMetatables[object] = metatable
			return log(LOGGER.WARN, "Denied [set] access to protected metatable '%s'", ProtectedMetatables[object])
		end
		return __undetoured( detours.shadow(object), metatable )
	end
end)

_G.debug.setmetatable = detours.attach(debug.setmetatable, function(object, metatable)
	if ProtectedMetatables[object] then
		fakeMetatables[object] = metatable -- To pretend it actually got set.
		return log(LOGGER.WARN, "Denied [set, debug] access to protected metatable '%s'", ProtectedMetatables[object])
	end
	return __undetoured( detours.shadow(object), metatable )
end)

_G.getmetatable = detours.attach(getmetatable, function(object)
	if ProtectedMetatables[object] then
		log( LOGGER.WARN, "Denied [get] access to protected metatable '%s'", ProtectedMetatables[object] )
		return fakeMetatables[object]
	end
	return __undetoured( detours.shadow(object) )
end)

_G.debug.getmetatable = detours.attach(debug.getmetatable, function(object)
	if ProtectedMetatables[object] then
		log( LOGGER.WARN, "Denied [get, debug] access to protected metatable '%s'", ProtectedMetatables[object] )
		return fakeMetatables[object]
	end
	return __undetoured( detours.shadow(object) )
end)

_G.setfenv = detours.attach(setfenv, function(location, enviroment)
	if location == 0 then
		log(LOGGER.WARN, "Someone tried to setfenv(0, x)!") return
	end
	return __undetoured( detours.shadow(location), enviroment)
end)

_G.debug.setfenv = detours.attach(debug.setfenv, function(object,env)
	return __undetoured(object,env)
end)


_G.debug.getfenv = detours.attach(debug.getfenv, function(object)
	return __undetoured( detours.shadow(object) )
end)

_G.FindMetaTable = detours.attach(FindMetaTable, function(name)
	return __undetoured(name)
end)

_G.debug.getregistry = detours.attach(debug.getregistry, function()
	return LOCKED_REGISTRY
end)

_G.debug.getupvalue = detours.attach(debug.getupvalue, function(func, index)
	return __undetoured( detours.shadow(func), index )
end)

_G.render.Capture = detours.attach(render.Capture, function(captureData)
	log( LOGGER.WARN, "Someone attempted to screengrab with render.Capture" )
	if not captureData then return end
	-- return "nice screengrab bro"
	return d_random(-1e5, 1e5)
end)

_G.file.Delete = detours.attach(file.Delete, function(name)
	if not name then return end
	log( LOGGER.WARN, "Someone attempted to delete file ["..name.."]" )
end)

-- Patches #1091 https://github.com/Facepunch/garrysmod-issues/issues/1091
local CamStack = 0

local function pushCam()
	return function(...)
		CamStack = CamStack + 1
		__undetoured(...)
	end
end

local function popCam()
	return function()
		if CamStack == 0 then
			return log(LOGGER.WARN, "Attempted to pop cam without a valid context")
		end
		CamStack = CamStack - 1
		__undetoured()
	end
end

_G.cam.Start = detours.attach( cam.Start, pushCam() )
_G.cam.Start3D2D = detours.attach( cam.Start3D2D, pushCam() )
_G.cam.StartOrthoView = detours.attach( cam.StartOrthoView, pushCam() )

_G.cam.End2D = detours.attach( cam.End2D, popCam() )
_G.cam.End3D = detours.attach( cam.End3D, popCam() )
_G.cam.End3D2D = detours.attach( cam.End3D2D, popCam() )
_G.cam.End = detours.attach( cam.End, popCam() )
_G.cam.EndOrthoView = detours.attach( cam.EndOrthoView, popCam() )

-- File Metatable, but you can't write with it.
---@param ret any Value to return inside of function ``f``
---@return function f File method function that will just log and return the value passed.
local function fileMethod(ret)
	return function()
		log(LOGGER.WARN, "Someone tried to read/write to a locked file!")
		return ret
	end
end

---@param path string Path to check
---@return boolean #If the file at the path is not allowed to be accessed.
local function isLockedPath(path)
	for _, blocked_path in ipairs(BlockedPaths) do
		if d_stringfind(path, blocked_path) then
			return true
		end
	end
	return false
end

local FILE_META = debug.getregistry().File
local LockedFileMeta = {
	-- These just return default values but may do other stuff later.

	Write = detours.attach( FILE_META.Write, fileMethod() ),
	WriteBool = detours.attach( FILE_META.WriteBool, fileMethod() ),
	WriteByte = detours.attach( FILE_META.WriteByte, fileMethod() ),
	WriteDouble = detours.attach( FILE_META.WriteDouble, fileMethod() ),
	WriteFloat = detours.attach( FILE_META.WriteFloat, fileMethod() ),
	WriteLong = detours.attach( FILE_META.WriteLong, fileMethod() ),
	WriteShort = detours.attach( FILE_META.WriteShort, fileMethod() ),
	WriteULong = detours.attach( FILE_META.WriteULong, fileMethod() ),
	WriteUShort = detours.attach( FILE_META.WriteUShort, fileMethod() ),

	Read = detours.attach( FILE_META.Read, fileMethod("") ),
	ReadBool = detours.attach( FILE_META.ReadBool, fileMethod(true) ),
	ReadByte = detours.attach( FILE_META.ReadByte, fileMethod(0) ),
	ReadDouble = detours.attach( FILE_META.ReadDouble, fileMethod(0) ),
	ReadFloat = detours.attach( FILE_META.ReadFloat, fileMethod(0) ),
	ReadLong = detours.attach( FILE_META.ReadLong, fileMethod(0) ),
	ReadShort = detours.attach( FILE_META.ReadShort, fileMethod(0) ),
	ReadULong = detours.attach( FILE_META.ReadULong, fileMethod(0) ),
	ReadUShort = detours.attach( FILE_META.ReadUShort, fileMethod(0) ),
	ReadLine = detours.attach( FILE_META.ReadLine, fileMethod("") ),

	Size = detours.attach( FILE_META.Size, fileMethod(0) ),

	EndOfFile = detours.attach( FILE_META.EndOfFile, fileMethod(true) ),
	Close = FILE_META.Close,
	Flush = detours.attach( FILE_META.Flush, fileMethod() ),
	Seek = FILE_META.Seek,
	Tell = FILE_META.Tell,

	__tostring = FILE_META.__tostring
}

LockedFileMeta.__index = LockedFileMeta

_G.file.Open = detours.attach(file.Open, function(fileName, fileMode, path)
	local fileobj = __undetoured(fileName, fileMode, path)
	if not fileobj then return end
	if isLockedPath(fileName) then
		log( LOGGER.INFO, "Locked file created! %s", fileName )
		d_setmetatable(fileobj, LockedFileMeta)
	end
	return fileobj
end)

_G.file.Rename = detours.attach(file.Rename, function(orignalFileName, targetFileName)
	if isLockedPath(orignalFileName) then
		return log(LOGGER.WARN, "Someone tried to rename file [%s] with filename %s", orignalFileName, targetFileName)
	end
	return __undetoured(true, orignalFileName, targetFileName)
end)

_G.net.Start = detours.attach(net.Start, function(str, unreliable)
	if BlacklistedNetMessages[str] then
		return log(LOGGER.WARN, "Blocked net.Start('%s', %s)!", str, unreliable)
	end
	log( LOGGER.INFO, "net.Start(%s, %s)", str, unreliable )

	return __undetoured(str,unreliable)
end)

local MAX_REP = 1000000
_G.string.rep = detours.attach(string.rep, function(str, reps, separator)
	-- Max string.rep length is 1,000,000
	if #str*reps + ( d_isstring(sep) and #sep or 0 )*reps > MAX_REP then
		return log(LOGGER.EVIL, "Someone tried to string.rep with a fucking massive return string!")
	end
	return __undetoured(str, reps, sep)
end)

_G.ClientsideModel = detours.attach(ClientsideModel, function(model, rendergroup)
	if not d_isstring(model) then return end
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Someone tried to create a ClientsideModel with a .bsp model!")
	end
	return __undetoured(model, rendergroup)
end)

_G.ClientsideScene = detours.attach(ClientsideScene, function(model, targetEnt)
	if not d_isstring(model) then return end
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Someone tried to create a ClientsideScene with a .bsp model!")
	end
	return __undetoured(model, targetEnt)
end)

_G.ClientsideRagdoll = detours.attach(ClientsideRagdoll, function(model, rendergroup)
	if not d_isstring(model) then return end
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Someone tried to create a ClientsideRagdoll with a .bsp model!")
	end
	return __undetoured(model, rendergroup)
end)

_G.ents.CreateClientProp = detours.attach(ents.CreateClientProp, function(model)
	if not d_isstring(model) then model = "models/error.mdl" end
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Someone tried to create a malicious ClientProp with a .bsp model!")
	end
	return __undetoured(model)
end)

-- Todo: Stuff with these
_G.CompileString = detours.attach(CompileString, function(code, identifier, handleError)
	return __undetoured(code, identifier, handleError)
end)

_G.RunString = detours.attach(RunString, function(code, identifier, handleError)
	return __undetoured(code, identifier, handleError)
end)

_G.RunStringEx = detours.attach(RunStringEx, function(code, identifier, handleError)
	return __undetoured(code, identifier, handleError)
end)

_G.game.MountGMA = detours.attach(game.MountGMA, function(path)
	log( LOGGER.INFO, "Mounting GMA: '%s'", path )
	return __undetoured(path)
end)


--- https://github.com/Facepunch/garrysmod-issues/issues/3637
local ISSUE_3637 = {"env_fire", "entityflame", "_firesmoke"}

_G.game.CleanUpMap = detours.attach(game.CleanUpMap, function(dontSendToClients, extraFilters)
	if d_istable(extraFilters) then
		local len = #extraFilters
		d_rawset(extraFilters, len+1, "env_fire")
		d_rawset(extraFilters, len+2, "entityflame")
		d_rawset(extraFilters, len+3, "_firesmoke")
	else
		return __undetoured(dontSendToClients, ISSUE_3637)
	end

	__undetoured(dontSendToClients, extraFilters)
end)

_G.gui.OpenURL = detours.attach(gui.OpenURL, function(url)
	if not isWhitelistedURL(url) then
		return log( LOGGER.INFO, "Blocked unwhitelisted gui.OpenURL('%s')", url )
	end
	log( LOGGER.INFO, "gui.OpenURL('%s')", url )
	return __undetoured(url)
end)

_G.gui.HideGameUI = detours.attach(gui.HideGameUI, function()
	log( LOGGER.INFO, "Blocked gui.HideGameUI" )
end)

_G.AddConsoleCommand = detours.attach(AddConsoleCommand, function(name, helpText, flags)
	-- Garry used to have it so that adding a console command named 'sendrcon' would crash your game.
	-- Malicious anticheats and others would abuse this. I'm not sure if adding sendrcon even still crashes you.
	-- https://github.com/CookieMaster/GMD/blob/11eae396d7448df325601d748ee09293ba0dd5c3/Addons/ULX%20Addons/custom-ulx-commands-and-utilities-23-1153/CustomCommands/lua/ulx/modules/sh/cc_util(2).lua

	if d_stringfind(name, "sendrcon") then
		return log( LOGGER.EVIL, "Someone tried to crash by adding 'sendrcon' as a concmd" )
	end

	__undetoured(name, helpText, flags)
end)

_G.os.date = detours.attach(os.date, function(format, time)
	-- Patches #329 https://github.com/Facepunch/garrysmod-issues/issues/329
	if format ~= nil then
		for v in d_stringgmatch(format, "%%(.?)") do
			if not d_stringmatch(v, "[%%aAbBcCdDSHeUmMjIpwxXzZyY]") then
				return log(LOGGER.EVIL, "Blocked evil os.date format!")
			end
		end
	end
	return d_date(format, time)
end)

_G.sound.PlayURL = detours.attach(sound.PlayURL, function(url, flags, callback)
	if not isWhitelistedURL(url) then
		return log( LOGGER.WARN, "Blocked sound.PlayURL('%s', '%s', %p)", url, flags, callback )
	end

	log( LOGGER.INFO, "sound.PlayURL('%s', '%s', %p)", url, flags, callback )
	return __undetoured(url, flags, callback)
end)

_G.HTTP = detours.attach(HTTP, function(parameters)
	if not parameters then return end -- todo: investigate if this should error instead
	if not isWhitelistedURL(parameters.url) then
		return log(LOGGER.INFO, "Blocked HTTP Request to %s", parameters.url)
	end
	return __undetoured(parameters)
end)

-- Registry detours
_R.Player.ConCommand = detours.attach(_R.Player.ConCommand, function(ply, command)
	if not ply or not d_isstring(command) then return end

	log( LOGGER.INFO, "%s:ConCommand(%s)", ply, command )

	local args = {}
	for arg in d_stringgmatch(command, "[^%s]+") do
		args[#args+1] = arg
	end

	return _G.RunConsoleCommand( unpack(args) )
end)

_R.Entity.SetModel = detours.attach(_R.Entity.SetModel, function(self, modelName)
	if not d_isstring(modelName) then return end
	if isMaliciousModel(modelName) then
		return log(LOGGER.EVIL, "Entity:SetModel(%s) blocked!", modelName) -- Crash
	end
	__undetoured(self, modelName)
end)

local ISSUE_4116 = detours.attach(_R.Entity.SetModel, function(self, flags)
	-- Patches #2688 https://github.com/Facepunch/garrysmod-issues/issues/2688
	if self == WORLDSPAWN then
		return log(LOGGER.EVIL, "Entity.DrawModel called with worldspawn")
	end

	-- Fixes #4116 https://github.com/Facepunch/garrysmod-issues/issues/4116
	_R.Entity.DrawModel = function() end -- disable function
	__undetoured(self, flags)
	_R.Entity.DrawModel = ISSUE_4116
end)

_R.Entity.DrawModel = ISSUE_4116