local d_concat = table.concat
local d_random = math.random
local d_char = string.char

_G.render.Capture = Detour.attach(render.Capture, function(hk, captureData)
	Log( LOGGER.WARN, "Someone attempted to screengrab with render.Capture" )
	if not captureData then return end

	local rnd = d_random(255)
	local buf = {}
	for i = 1, 500 do
		-- 500 * 5
		buf[i] = d_concat({ d_char( rnd * 0.25, rnd, rnd * 0.75, rnd * 0.5, rnd * 0.33 ) })
	end
	return d_concat(buf)
end)