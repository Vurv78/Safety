local require = Autorun.require
local Util = require("util")

local d_stringgsub = string.gsub
local d_isstring = isstring
local d_stringmatch = string.match
local d_ipairs = ipairs
local d_stringfind = string.find

--- Doesn't account for \0 but we shouldn't use that in URLs anyway.
---@param s string
---@return string pattern_safe
local function patternSafe(s)
	return d_stringgsub(s, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

local URLWhitelist = {}

do
	local simple_urls = Util.ArraySetting("SimpleURLWhitelist")
	for k, url in ipairs(simple_urls) do
		URLWhitelist[k] = { patternSafe(url), false }
	end

	local pattern_urls = Util.ArraySetting("PatternURLWhitelist")
	local len = #URLWhitelist
	for k, url in ipairs(pattern_urls) do
		URLWhitelist[k + len] = { url, true }
	end
end

---@param url string
local function isWhitelisted(url)
	if not d_isstring(url) then return false end

	local relative = d_stringmatch(url, "^https?://(.*)")
	if not relative then return false end

	for _, data in d_ipairs(URLWhitelist) do
		local match, is_pattern = data[1], data[2]

		local haystack = is_pattern and relative or (d_stringmatch(relative, "(.-)/.*") or relative)
		if d_stringfind(haystack, "^" .. match .. (is_pattern and "" or "$") ) then
			return true
		end
	end

	return false
end

return {
	isWhitelisted = isWhitelisted
}