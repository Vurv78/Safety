local d_type = type
local d_isfunction = isfunction
local d_stringfind = string.find
local d_pairs = pairs
local d_unpack = unpack
local d_isstring = isstring

_G.string.dump = Detour.attach(string.dump, function(hk, func, stripDebugInfo)
	if not d_isfunction(func) then
		-- Error
		return hk(func)
	end
	return hk( Detour.shadow(func), stripDebugInfo)
end)

--- Detour checking if the pointer is the same.
_G.string.format = Detour.attach(string.format, function(hk, format, ...)
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
		local new, shadowed = Detour.shadow(arg)
		if shadowed then
			did_shadow = true
		end
		T[k] = new
	end
	if did_shadow then
		Log( LOGGER.INFO, "Detoured string.format(%q, ...)", format )
	end

	return hk( format, d_unpack(T) )
end)

local MAX_REP = 1000000
_G.string.rep = Detour.attach(string.rep, function(hk, str, reps, sep)
	-- Max string.rep length is 1,000,000
	if #str * reps + ( d_isstring(sep) and #sep or 0 ) * reps > MAX_REP then
		return Log(LOGGER.WARN, "Someone tried to string.rep with a fucking massive return string!")
	end
	return hk(str, reps, sep)
end)