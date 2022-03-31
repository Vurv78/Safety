local d_isfunction = isfunction

-- local JitCallbacks = {}

_G.jit.attach = Detour.attach(jit.attach, function(hk, callback, event)
	-- Attaches jit to a function so they can get constants and protos from it. We will give it the original function.
	if not d_isfunction(callback) then
		-- Error
		return hk(callback)
	end

	-- JitCallbacks[callback] = event
	return hk( function(a, b, c, d, e, f)
		Detour.shadow(callback)( Detour.shadow(a), Detour.shadow(b), Detour.shadow(c), Detour.shadow(d), Detour.shadow(e), Detour.shadow(f) )
	end, event )
end)

-- Make lua language server happy..
_G.jit.util = _G.jit.util or {}

_G.jit.util.ircalladdr = Detour.attach(jit.util.ircalladdr, function(hk, index)
	return hk(index)
end)

_G.jit.util.funcinfo = Detour.attach(jit.util.funcinfo, function(hk, func, pos) -- Function that is basically Debug.getinfo
	return hk( Detour.shadow(func), pos )
end)

_G.jit.util.funcbc = Detour.attach(jit.util.funcbc, function(hk, func, pos)
	return hk( Detour.shadow(func), pos )
end)

_G.jit.util.funck = Detour.attach(jit.util.funck, function(hk, func, index)
	-- Function that returns a constant from a lua function, throws an error in native c++ functions which we want here.
	return hk( Detour.shadow(func), index )
end)

_G.jit.util.funcuvname = Detour.attach(jit.util.funcuvname, function(hk, func, index)
	return hk( Detour.shadow(func), index )
end)