local require = Autorun.require
local Util = require("util")

local d_isnumber = isnumber
local d_isfunction = isfunction

_G.debug.getinfo = Detour.attach(debug.getinfo, function(hk, funcOrStackLevel, fields)
	return hk( Detour.shadow(funcOrStackLevel), fields)
end)

_G.debug.getlocal = Detour.attach(debug.getlocal, function(hk, thread, level, index)
	return hk( Detour.shadow(thread), (level or 0) + 1, index) -- Same as debug.getinfo
end)

--[[
	Lua Hooks
]]

-- Function, mask, count
local _HookList = {
	current = {}
}

_G.debug.sethook = Detour.attach(debug.sethook, function(hk, thread, hook, mask, count)
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

_G.debug.gethook = Detour.attach(debug.gethook, function(hk, thread)
	-- return d_unpack(HookList["current"])
	return hk(thread)
end)

_G.debug.setfenv = Detour.attach(debug.setfenv, function(hk, object, env)
	return hk(object, env)
end)

_G.debug.getfenv = Detour.attach(debug.getfenv, function(hk, object)
	return hk( Detour.shadow(object) )
end)

_G.debug.getregistry = Detour.attach(debug.getregistry, function()
	return LOCKED_REGISTRY
end)

_G.debug.getupvalue = Detour.attach(debug.getupvalue, function(hk, func, index)
	if not d_isnumber(index) or not d_isfunction(func) then
		-- Error
		return hk( func, index )
	end

	return hk( Detour.shadow(func), index )
end)