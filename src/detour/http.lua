local require = Autorun.require
local Util = require("util")

local d_istable = istable
local d_isfunction = isfunction
local d_rawget = rawget

_G.HTTP = Detour.attach(HTTP, function(hk, parameters)
	if not d_istable(parameters) then
		return hk(parameters)
	end

	local url = d_rawget(parameters, "url")
	if url and not Util.isWhitelistedURL(url) then
		Log( LOGGER.TRACE, "Blocked HTTP(%q)", url)

		local onfailure = d_rawget(parameters, "onfailure")
		if d_isfunction(onfailure) then
			onfailure("unsuccessful")
		end
		return
	end

	return hk(parameters)
end)