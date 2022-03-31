local require = Autorun.require
local Util = require("util")

-- Bad Net Messages to use with net.Start, prevent them from executing. Checks equality
local BlockedNetMessages = Util.LUTSetting("BlockedNetMessages")
local BlockedConcommands = Util.LUTSetting("BlockedConcommands")
local BlockedPaths = Util.LUTSetting("BlockedPaths")
local WhitelistedIPs = Util.LUTSetting("WhitelistedIPs")

return {
	BlockedNetMessages = BlockedNetMessages,
	BlockedConcommands = BlockedConcommands,
	BlockedPaths = BlockedPaths,
	WhitelistedIPs = WhitelistedIPs
}