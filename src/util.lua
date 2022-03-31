local d_pairs = pairs
local d_stringsub = string.sub
local d_setmetatable = setmetatable
local d_stringmatch = string.match
local d_rawequal = rawequal
local d_rawget = rawget
local d_rawset = rawset
local d_istable = istable

--- Creates a lookup table from an array table
---@param t table
---@return table
local function ToLUT(t)
	local lut = {}
	for i, v in d_pairs(t) do
		lut[v] = true
	end
	return lut
end

--- Returns a LUT from a plugin setting by splitting by whitespace and inverting the table
---@param setting string
---@return table
local function LUTSetting(setting)
	return ToLUT(Autorun.Plugin.Settings[setting])
end

---@param setting string
---@return table
local function ArraySetting(setting)
	return Autorun.Plugin.Settings[setting]
end

--- Limits a string to dedicated length, or cuts off with ...
---@param str string
---@param len integer
local function limitString(str, len)
	if #str > (len - 3) then
		return d_stringsub(str, 1, len) .. "..."
	else
		return str
	end
end

---@param mdl string
local function isMaliciousModel(mdl)
	-- https://github.com/Facepunch/garrysmod-issues/issues/4449
	return d_stringmatch(mdl, "%.([^.]+)$") == "bsp"
end

--- Returns the true size of a table, including the size of tables inside of that table.
--- Should be safe from infinite recursion.
---@param t table
---@param done table|nil
---@return number table_size
local function trueTableSize(t, done)
	local sz = 0
	sz = sz + #t
	done = done or { t }
	for k, v in d_pairs(t) do
		if not done[v] then
			done[v] = true
			done[k] = true
			if d_istable(k) then sz = sz + trueTableSize(k, done) end
			if d_istable(v) then sz = sz + trueTableSize(v, done) end
			done[v] = nil
			done[k] = nil
		end
	end
	return sz
end

--- Returns a locked version of table t.
---@param t table
---@return table locked_version
local function getLocked(t)
	return d_setmetatable({}, {
		__index = t,
		__newindex = function(_, k, v)
			-- Do not allow overwriting, which could cause crashes.
			if d_rawequal( d_rawget(t, k), nil ) then
				d_rawset(t, k, v)
			end
		end
	})
end

return {
	ToLUT = ToLUT,
	LUTSetting = LUTSetting,
	ArraySetting = ArraySetting,

	limitString = limitString,
	isMaliciousModel = isMaliciousModel,
	getLocked = getLocked,
	trueTableSize = trueTableSize
}