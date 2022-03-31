--[[
	Detour Library
]]

local detours = { list = {}, hide = {} }

--- Returns the given hook to replace a function with.
---@param target function Func to hook
---@param replace_with fun(hook: function, args: ...) Func to return
---@return function hooked Hooked function that was given in ``replace_with``
local function attach( target, replace_with )
	local fn = function(...)
		return replace_with(target, ...)
	end
	detours.list[fn] = target
	return fn
end

--- Returns the original function that the function given hooked.
---@param hooked function Hooked function
---@return function original Original function to overwrite with.
---@return boolean @True if the hook was detached
local function detach( hooked )
	local ret = detours.list[hooked]
	detours.list[hooked] = nil
	return ret or hooked, ret and true or false
end

--- Returns the unhooked function if val is hooked.
-- Else returns ``val``
---@param val function Function to check. Can actually be any type though.
---@return function original Unhooked value or function.
---@return boolean Was the value hooked?
local function shadow( val )
	local v = detours.list[val]
	if v then
		return v, true
	end
	return val, false
end

return {
	attach = attach,
	detach = detach,
	shadow = shadow
}