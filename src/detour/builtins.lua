local require = Autorun.require
local Settings = require("settings")
local Util = require("util")

local d_isstring = isstring
local d_pairs = pairs
local d_unpack = unpack
local d_type = type
local d_tostring = tostring
local d_rawequal = rawequal
local d_stringfind = string.find

_G.tostring = Detour.attach(tostring, function(hk, value)
	-- Could be used as an alternate form to string.format("%p", fn)
	return hk( Detour.shadow(value) )
end)

_G.RunConsoleCommand = Detour.attach(RunConsoleCommand, function(hk, command, ...)
	local command_ty = d_type(command)
	if command_ty ~= TYPE_NUMBER and command_ty ~= TYPE_STRING then
		return hk(command, ...)
	end

	-- In case it's a number
	command = d_tostring(command)

	if Settings.BlockedConcommands[command] then
		return Log( LOGGER.DEBUG, "Found blacklisted cmd [%q] being executed with RunConsoleCommand", command )
	end

	Log(LOGGER.TRACE, "RunConsoleCommand(%s)", command)
	return hk(command, ...)
end)


_G.print = Detour.attach(print, function(hk, ...)
	local t = {...}
	for k, arg in d_pairs(t) do
		t[k] = Detour.shadow(arg)
	end
	return hk( d_unpack(t) )
end)

-- Using string indexing so gluafixer doesn't cry about gcinfo
_G["gcinfo"] = Detour.attach(_G["gcinfo"], function()
	-- Incase in another function to avoid equality with collectgarbage
	return MemCounter()
end)

_G.collectgarbage = Detour.attach(collectgarbage, function(hk, action, arg)
	if d_rawequal(action, "count") then
		return MemCounter()
	end
	return hk( action, arg )
end)

_G.setfenv = Detour.attach(setfenv, function(hk, location, enviroment)
	if d_rawequal(location, 0) then
		Log(LOGGER.WARN, "Someone tried to setfenv(0, x)!") return
	end
	return hk( Detour.shadow(location), enviroment)
end)

_G.FindMetaTable = Detour.attach(FindMetaTable, function(hk, name)
	return LOCKED_REGISTRY[name]
end)

_G.ClientsideModel = Detour.attach(ClientsideModel, function(hk, model, rendergroup)
	if not d_isstring(model) then return end
	if Util.isMaliciousModel(model) then
		return Log(LOGGER.WARN, "Someone tried to create a ClientsideModel with a .bsp model!")
	end
	return hk(model, rendergroup)
end)

_G.ClientsideScene = Detour.attach(ClientsideScene, function(hk, model, targetEnt)
	if not d_isstring(model) then return end
	if Util.isMaliciousModel(model) then
		return Log(LOGGER.WARN, "Someone tried to create a ClientsideScene with a .bsp model!")
	end
	return hk(model, targetEnt)
end)

_G.ClientsideRagdoll = Detour.attach(ClientsideRagdoll, function(hk, model, rendergroup)
	if not d_isstring(model) then return end
	if Util.isMaliciousModel(model) then
		return Log(LOGGER.WARN, "Someone tried to create a ClientsideRagdoll with a .bsp model!")
	end
	return hk(model, rendergroup)
end)

-- Todo: Stuff with these
_G.CompileString = Detour.attach(CompileString, function(hk, code, identifier, handleError)
	return hk(code, identifier, handleError)
end)

_G.RunString = Detour.attach(RunString, function(hk, code, identifier, handleError)
	return hk(code, identifier, handleError)
end)

_G.RunStringEx = Detour.attach(RunStringEx, function(hk, code, identifier, handleError)
	return hk(code, identifier, handleError)
end)

_G.AddConsoleCommand = Detour.attach(AddConsoleCommand, function(hk, name, helpText, flags)
	-- Garry used to have it so that adding a console command named 'sendrcon' would crash your game.
	-- Malicious anticheats and others would abuse this. I'm not sure if adding sendrcon even still crashes you.
	-- https://github.com/CookieMaster/GMD/blob/11eae396d7448df325601d748ee09293ba0dd5c3/Addons/ULX%20Addons/custom-ulx-commands-and-utilities-23-1153/CustomCommands/lua/ulx/modules/sh/cc_util(2).lua

	if d_isstring(name) and d_stringfind(name, "sendrcon") then
		return Log( LOGGER.WARN, "Someone tried to crash by adding 'sendrcon' as a concmd" )
	end

	hk(name, helpText, flags)
end)