local require = Autorun.require
local Util = require("util")
local Settings = require("settings")

local d_isstring = isstring
local d_stringgmatch = string.gmatch
local d_stringmatch = string.match
local d_pcall = pcall

local WORLDSPAWN = game.GetWorld()
local _R = debug.getregistry()

-- Registry detours
_R.Player.ConCommand = Detour.attach(_R.Player.ConCommand, function(hk, ply, cmd_str)
	if not ply or not d_isstring(cmd_str) then
		return hk(ply, cmd_str)
	end

	local command = d_stringmatch(cmd_str, "^(%S+)")
	if Settings.BlockedConcommands[command] then
		return Log( LOGGER.WARN, "Found blacklisted cmd [%q] being executed with Self:ConCommand(%q)", command, cmd_str)
	end

	return hk(ply, cmd_str)
end)

_R.Entity.SetModel = Detour.attach(_R.Entity.SetModel, function(hk, ent, modelName)
	if not d_isstring(modelName) then return end
	if Util.isMaliciousModel(modelName) then
		return Log(LOGGER.WARN, "Entity:SetModel(%s) blocked!", modelName) -- Crash
	end
	hk(ent, modelName)
end)

local ISSUE_4116
ISSUE_4116 = Detour.attach(_R.Entity.DrawModel, function(hk, ent, flags)
	-- Patches #2688 https://github.com/Facepunch/garrysmod-issues/issues/2688
	if ent == WORLDSPAWN then
		return Log(LOGGER.WARN, "Entity.DrawModel called with worldspawn")
	end

	-- Fixes #4116 https://github.com/Facepunch/garrysmod-issues/issues/4116
	_R.Entity.DrawModel = function() end -- disable function
	local ok, err = d_pcall(hk, ent, flags)
	_R.Entity.DrawModel = ISSUE_4116

	if not ok then
		Log(LOGGER.INFO, "Entity.DrawModel failed: %s", err)
		error(err, 2)
	end
end)

_R.Entity.DrawModel = ISSUE_4116