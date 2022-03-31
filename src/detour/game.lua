local d_istable = istable
local d_rawset = rawset

_G.game.MountGMA = Detour.attach(game.MountGMA, function(hk, path)
	Log( LOGGER.INFO, "Mounting GMA: %q", path )
	return hk(path)
end)


--- https://github.com/Facepunch/garrysmod-issues/issues/3637
local ISSUE_3637 = {"env_fire", "entityflame", "_firesmoke"}

_G.game.CleanUpMap = Detour.attach(game.CleanUpMap, function(hk, dontSendToClients, extraFilters)
	if d_istable(extraFilters) then
		local len = #extraFilters
		d_rawset(extraFilters, len + 1, "env_fire")
		d_rawset(extraFilters, len + 2, "entityflame")
		d_rawset(extraFilters, len + 3, "_firesmoke")
	else
		return hk(dontSendToClients, ISSUE_3637)
	end

	hk(dontSendToClients, extraFilters)
end)