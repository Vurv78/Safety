local d_isstring = isstring
local d_stringmatch = string.match
local d_stringgmatch = string.gmatch

_G.os.date = Detour.attach(os.date, function(hk, format, time)
	-- Patches #329 https://github.com/Facepunch/garrysmod-issues/issues/329
	if d_isstring(format) then
		for v in d_stringgmatch(format, "%%(.?)") do
			if not d_stringmatch(v, "[%%aAbBcCdDSHeUmMjIpwxXzZyY]") then
				return Log(LOGGER.WARN, "Blocked evil os.date format!")
			end
		end
	end
	return hk(format, time)
end)