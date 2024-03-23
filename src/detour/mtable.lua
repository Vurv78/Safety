local d_istable = istable
local d_error = error

-- May need to be globalized to contain locked registry again.
local ProtectedMetatables = {
	[_G] = "_G"
}

local fakeMetatables = setmetatable({}, {
	__mode = "k"
})

_G.setmetatable = Detour.attach(setmetatable, function(hk, tab, metatable)
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
			Log(LOGGER.WARN, "Denied [set] access to protected metatable %q", ProtectedMetatables[tab])
			return tab
		end
		hk( Detour.shadow(tab), metatable )
		return tab
	end
end)

_G.debug.setmetatable = Detour.attach(debug.setmetatable, function(hk, object, metatable)
	if not d_istable(metatable) then
		-- Error
		return hk(object, metatable)
	end

	if ProtectedMetatables[object] then
		fakeMetatables[object] = metatable -- To pretend it actually got set.
		Log(LOGGER.WARN, "Denied [set, debug] access to protected metatable %q", ProtectedMetatables[object])
		return true
	end
	return hk( Detour.shadow(object), metatable )
end)

_G.getmetatable = Detour.attach(getmetatable, function(hk, object)
	if ProtectedMetatables[object] then
		Log( LOGGER.WARN, "Denied [get] access to protected metatable %q", ProtectedMetatables[object] )
		return fakeMetatables[object]
	end
	return hk( Detour.shadow(object) )
end)

_G.debug.getmetatable = Detour.attach(debug.getmetatable, function(hk, object)
	if ProtectedMetatables[object] then
		Log( LOGGER.WARN, "Denied [get, debug] access to protected metatable %q", ProtectedMetatables[object] )
		return fakeMetatables[object]
	end
	return hk( Detour.shadow(object) )
end)