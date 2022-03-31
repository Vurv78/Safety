local require = Autorun.require
local Util = require("util")

local d_istable = istable
local d_isnumber = isnumber

-- This doesn't call the __newindex metamethod, so we need to patrol this func as well.
_G.table.insert = Detour.attach(table.insert, function(hk, tbl, position, value)
	local key
	if d_istable(tbl) and position ~= nil then
		if value ~= nil then
			if d_isnumber(position) then
				key = position
			else
				-- Error
				return hk(tbl, position, value)
			end
		else
			-- Push value to top of table
			key = #tbl + 1
			value = position
		end

		if key > 2 ^ 31 - 1 then
			-- Key is too large, this would crash you. Just return the key to act as if it really did get pushed.
			Log(LOGGER.WARN, "table.insert with massive key!")
			return key
		elseif Util.trueTableSize(tbl) > 200000 then
			Log(LOGGER.DEBUG, "table.insert with massive table!")
			rawset(tbl, key, {})
			return key
		end
	else
		-- Error
		return hk(tbl, position, value)
	end

	return hk(tbl, key, value)
end)