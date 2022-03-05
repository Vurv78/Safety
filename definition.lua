-- Emmylua Autorun definition.
-- Feel free to use in your own plugins.

---@class Autorun
---@field log fun(message: string, severity: integer)
---@field require fun(name: string): any
---@field Plugin Plugin
---@field NAME string # Name of script running
---@field STARTUP boolean # True if script is running on autorun.lua
---@field CODE string # Source code of script
---@field CODE_LEN integer # Length of source code
---@field IP string # IP Address of server
Autorun = {}

---@class Plugin
---@field Settings table # Key value pairs settings retrieved from plugin.toml
---@field VERSION string # Version of the plugin
---@field AUTHOR string
---@field NAME string # Display name of the plugin

---@type Autorun
_G.sautorun = {}