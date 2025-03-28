local d_isstring = isstring
local d_sub = string.sub

--- The detour library makes a new closure for detours anyway, so there's no issue with sharing functions.
local function Checksum(hk, str)
	if not d_isstring(str) then
		return hk(str)
	end

	if #str > 1e8 then
		str = d_sub(str, 1, 1e8)
		return
	end

	return hk(str)
end

_G.util.MD5 = Detour.attach(util.MD5, Checksum)
_G.util.SHA1 = Detour.attach(util.SHA1, Checksum)
_G.util.SHA256 = Detour.attach(util.SHA256, Checksum)
