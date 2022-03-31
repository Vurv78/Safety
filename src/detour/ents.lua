local require = Autorun.require
local Util = require("util")

local d_isstring = isstring

_G.ents.CreateClientProp = Detour.attach(ents.CreateClientProp, function(hk, model)
	if not d_isstring(model) then model = "models/error.mdl" end

	if Util.isMaliciousModel(model) then
		return Log(LOGGER.WARN, "Someone tried to create a malicious ClientProp with a .bsp model!")
	end

	return hk(model)
end)