--[[
   ______            _____
  / ____/___  ____  / __(_)___ ______
 / /   / __ \/ __ \/ /_/ / __ `/ ___/
/ /___/ /_/ / / / / __/ / /_/ (__  )
\____/\____/_/ /_/_/ /_/\__, /____/
					   /____/
]]

-- Files to hide in file reading and writing. If a path contains any of these keywords, it will be blocked. Uses string.find
local BlockedPaths = {
	"sf_filedata",
	"e2files",
	"starfall",
	"expression2"
}

-- Commands to not let execute in RunConsoleCommand.
-- Ply:ConCommand will also use these.
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

local d_gsub = string.gsub

--- Doesn't account for \0 but we shouldn't use that in URLs anyway.
local function patternSafe(s)
	return d_gsub(s, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
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

-- 8/19/2020
-- 7/7/2021

local ProtectedMetatables = {
	[_G] = "_G",
	[debug.getregistry()] = "_R"
}

-- Globals
local d_format = string.format
local d_stringfind = string.find
local d_stringmatch = string.match
local d_print = print
local d_getinfo = debug.getinfo
local d_unpack = _G.unpack
local d_date = os.date
local d_traceback = debug.traceback
local d_rawset = rawset
local d_jitattach = _G.jit.attach

local d_setmetatable = debug.setmetatable
local d_getmetatable = debug.getmetatable

local REGISTRY = debug.getregistry()

local COLOR = {}
COLOR.__index = COLOR

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

local function log(urgency, ...)
	if urgency == LOGGER.EVIL then
		alert(...)
	end
	-- Atrocious debug.getinfo spam
	sautorun.log( d_format("[%s] -> ", urgency) .. d_format(...) .. " -> " .. ( getLocation(6) or getLocation(5) or getLocation(4) or getLocation(3) or getLocation(2) ) )
end

local function isMaliciousModel(mdl)
	-- https://github.com/Facepunch/garrysmod-issues/issues/4449
	if d_stringmatch(mdl, ".*%.(.*)") == "bsp" then return true end
	return false
end

local function isWhitelistedURL(url)
	if not isstring(url) then return false end

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
-- Should be safe from infinite recursion.
local function trueTableSize(t, done)
	local sz = 0
	sz = sz + #t
	done = done or { t }
	for k, v in pairs(t) do
		if not done[v] then
			done[v] = true
			if istable(k) then sz = sz + trueTableSize(k, done) end
			if istable(v) then sz = sz + trueTableSize(v, done) end
			done[v] = nil
		end
	end
	return sz
end

--- Cheap check if two tables equal in their values
local function isTableMostlyCopied(t, t2)
	if not istable(t) or not istable(t2) then return false end
	if d_getmetatable(t) ~= d_getmetatable(t2) then return false end

	for k, v in pairs(t) do
		if t2[k] ~= v then return false end
	end
	return true
end

--- Returns a locked version of table t.
local function getLocked(t)
	return setmetatable({}, {
		__index = t,
		__newindex = function(_, k, v)
			-- Do not allow overwriting, which could cause crashes.
			if rawget(t, k) == nil then
				rawset(t, k, v)
			end
		end
	})
end

local LOCKED_REGISTRY = getLocked(REGISTRY)
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
--@param function Target function to hook
--@param function Hook to return
--@return function New hooked function that was given
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
--@param function Hooked
--@return function Original function, to overwrite with.
--@return bool True if successful.
function detours.detach( hooked )
	local ret = detours.list[hooked]
	detours.list[hooked] = nil
	return ret or hooked, ret and true or false
end

--- Returns the unhooked function if val is hooked.
-- Else returns ``val``
-- @param function val Function to check. Can actually be any type though.
-- @return function Return function/val
-- @return boolean Was the value hooked?
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
setmetatable(begunMeshes, {
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
	for _, blacklisted in ipairs(BlacklistedConCommands) do
		if d_stringfind(command, blacklisted) then
			return log( LOGGER.WARN, "Found blacklisted cmd ['%s'] being executed with RunConsoleCommand", command )
		end
	end
	log(LOGGER.INFO, "RunConsoleCommand(%s)", command)
	return __undetoured(command, ...)
end)

-- Behaves exactly like table.insert
local function pureLuaInsert(tab, key, val)
	if not istable(tab) then return end

	if val~=nil then
		if not isnumber(key) then return end
		for k = #tab, key, -1 do
			tab[k+1] = tab[k]
		end
		rawset(tab, key, val)
		return key
	elseif key ~= nil then
		local ind = #tab+1
		rawset(tab, ind, key)
		return ind
	end
end

-- This doesn't call the __newindex metamethod, so we need to patrol this func as well.
_G.table.insert = detours.attach(table.insert, function(myTable, key, value)
	if myTable and istable(myTable) then
		if #myTable > 100000 then log(LOGGER.WARN, "Table") return end
		if trueTableSize(myTable) > 100000 then return log(LOGGER.WARN, "trueTableSize in table.insert was too large!") end
		if istable(value) and isTableMostlyCopied(myTable, value) then return log(LOGGER.WARN, "Copied table found in table.insert, lag/crash attempt?") end
	end
	if value~=nil and isnumber(key) and key > 2^31-1 then return log(LOGGER.WARN, "table.insert with massive key!") end
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
	if type(value) == "CSoundPatch" then return false, "CSoundPatch" end
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

	return __undetoured( format, unpack(T) )
end)


_G.print = detours.attach(print, function(...)
	local t = {...}
	for k, arg in pairs(t) do
		t[k] = detours.shadow(arg) -- Won't log detouring
	end
	return __undetoured( unpack(t) )
end)

local JitCallbacks = {}

_G.jit.attach = detours.attach(jit.attach, function(callback,event)
	-- Attaches jit to a function so they can get constants and protos from it. We will give it the original function :)
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

local fakeMetatables = setmetatable({}, {
	__mode = "k"
})

_G.setmetatable = detours.attach(setmetatable, function(object, metatable)
	local meta = fakeMetatables[object] or {}
	if meta.__metatable ~= nil then
		return error("cannot change a protected metatable")
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

_G.debug.getupvalue = detours.attach(debug.getupvalue, function(func,index)
	return __undetoured( detours.shadow(func), index )
end)

_G.render.Capture = detours.attach(render.Capture, function(captureData)
	log( LOGGER.WARN, "Someone attempted to screengrab with render.Capture" )
	if not captureData then return end
	-- return "nice screengrab bro"
	return math.random(-1e5, 1e5)
end)

_G.file.Delete = detours.attach(file.Delete, function(name)
	if not name then return end
	log( LOGGER.WARN, "Someone attempted to delete file ["..name.."]" )
end)

local CamStack = {}

local function pushCam()
	return function(...)
		CamStack[#CamStack+1] = true
		__undetoured(...)
	end
end

local function popCam()
	return function()
		if #CamStack == 0 then
			-- https://github.com/Facepunch/garrysmod-issues/issues/1091
			-- Solution also from StarfallEx
			return log(LOGGER.WARN, "Attempted to pop cam without a valid context")
		end
		CamStack[#CamStack] = nil
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
local function fileMethod(ret)
	return function()
		log(LOGGER.WARN, "Someone tried to read/write to a locked file!")
		return ret
	end
end

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

_G.string.rep = detours.attach(string.rep, function(str,reps,separator)
	-- Max string.rep length is 1,000,000
	local sep = separator or ""
	local retlength = #str*reps + #sep*reps
	if retlength > 1000000 then log(LOGGER.EVIL, "Someone tried to string.rep with a fucking massive return string!") return end
	return __undetoured(str,reps,sep)
end)

_G.ClientsideModel = detours.attach(ClientsideModel, function(model,rendergroup)
	if not isstring(model) then return end
	if isMaliciousModel(model) then log(LOGGER.EVIL, "Someone tried to create a ClientsideModel with a .bsp model!") return end
	return __undetoured(model,rendergroup)
end)

_G.ClientsideScene = detours.attach(ClientsideScene, function(model,targetEnt)
	if not isstring(model) then return end
	if isMaliciousModel(model) then log(LOGGER.EVIL, "Someone tried to create a ClientsideScene with a .bsp model!") return end
	return __undetoured(model,targetEnt)
end)

_G.ClientsideRagdoll = detours.attach(ClientsideRagdoll, function(model,rendergroup)
	if not isstring(model) then return end
	if isMaliciousModel(model) then log(LOGGER.EVIL, "Someone tried to create a ClientsideRagdoll with a .bsp model!") return end
	return __undetoured(model,rendergroup)
end)

_G.ents.CreateClientProp = detours.attach(ents.CreateClientProp, function(model)
	if not isstring(model) then model = "models/error.mdl" end
	if isMaliciousModel(model) then log(LOGGER.EVIL, "Someone tried to create a malicious clientsideprop with a .bsp model!") return end
	return __undetoured(model)
end)

-- Todo: Stuff with these
_G.CompileString = detours.attach(CompileString, function(code,identifier,handleError)
	return __undetoured(code,identifier,handleError)
end)

_G.RunString = detours.attach(RunString, function(code,identifier,handleError)
	return __undetoured(code,identifier,handleError)
end)

_G.RunStringEx = detours.attach(RunStringEx, function(code,identifier,handleError)
	return __undetoured(code,identifier,handleError)
end)

_G.game.MountGMA = detours.attach(game.MountGMA, function(path)
	log( LOGGER.INFO, "Mounting GMA: '%s'", path )
	return __undetoured(path)
end)

_G.game.CleanUpMap = detours.attach(game.CleanUpMap, function(dontSendToClients, extraFilters)
	local len = #extraFilters
	d_rawset(extraFilters, len+1, "env_fire")
	d_rawset(extraFilters, len+2, "entityflame")
	d_rawset(extraFilters, len+3, "_firesmoke")

	__undetoured(dontSendToClients or false, extraFilters)
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

	__undetoured(name,helpText,flags)
end)

_G.os.date = detours.attach(os.date, function(format, time)
	-- https://github.com/thegrb93/StarfallEx/blob/423e75182d3590bb1560677d54724c134625b549/lua/starfall/libs_sh/builtins.lua#L348
	if format ~= nil then
		for v in string.gmatch(format, "%%(.?)") do
			if not string.match(v, "[%%aAbBcCdDSHeUmMjIpwxXzZyY]") then
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

_G.HTTP = detours.attach(HTTP, function(params)
	if not params then return end -- todo: investigate if this should error instead
	if not isWhitelistedURL(params.url) then
		return log(LOGGER.INFO, "Blocked HTTP Request to %s", params.url)
	end
	return __undetoured(params)
end)

-- Registry detours
REGISTRY.Player.ConCommand = detours.attach(REGISTRY.Player.ConCommand, function(ply, command)
	if not ply or not isstring(command) then return end

	log( LOGGER.INFO, "%s:ConCommand(%s)", ply, command )

	local args = {}
	for arg in string.gmatch(command, "[^%s]+") do
		args[#args+1] = arg
	end

	return _G.RunConsoleCommand( unpack(args) )
end)

REGISTRY.Entity.SetModel = detours.attach(REGISTRY.Entity.SetModel, function(self, model)
	if isMaliciousModel(model) then
		return log(LOGGER.EVIL, "Entity:SetModel(%s) blocked!", model) -- Crash
	end
	__undetoured(self, model)
end)

REGISTRY.Entity.DrawModel = detours.attach(REGISTRY.Entity.DrawModel, function(self, flags)
	if self == game.GetWorld() then
		return log(LOGGER.EVIL, "Entity:DrawModel() called with worldspawn") -- Crash
	end
	__undetoured(self, flags)
end)