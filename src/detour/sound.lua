local require = Autorun.require
local Util = require("util")

_G.sound.PlayURL = Detour.attach(sound.PlayURL, function(hk, url, flags, callback)
	if not Util.isWhitelistedURL(url) then
		return Log( LOGGER.WARN, "Blocked sound.PlayURL(%q, %q, %p)", url, flags, callback )
	end

	Log( LOGGER.INFO, "sound.PlayURL(%q, %q, %p)", url, flags, callback )
	return hk(url, flags, callback)
end)