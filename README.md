# ``Safety`` [![License](https://img.shields.io/github/license/Vurv78/Safety?color=red)](https://opensource.org/licenses/MIT) [![github/Vurv78](https://img.shields.io/discord/824727565948157963?label=Discord&logo=discord&logoColor=ffffff&labelColor=7289DA&color=2c2f33)](https://discord.gg/yXKMt2XUXm)

This is a plugin for [Autorun-rs](https://github.com/Vurv78/Autorun-rs) to make your experience safer by preventing crashes and disallowing common malicious behaviors like file spam and deletion.

## ☑️ Features
* ⚙️ Easy to configure (See plugin.toml)
* 📈 Blacklisting net messages, concommands
  * ``+voicerecord``, etc
* 📁 Restricting access to filesystem
* 💣 Patches >15 easy ways to crash your game
  * Issues pulled straight from the [garrysmod-issues](https://github.com/Facepunch/garrysmod-issues) facepunch won't fix.
* 🔍 Being mostly undetectable
  * Haven't tested against specific anticheats (Make an issue!).
* 📋 HTTP Whitelist
  * Avoid leaking your IP thanks to shitty addons like PAC and Streamcore.

## 🤔 Usage
This is meant to be used with Autorun's plugin system.  
__Drag this repo (as a folder) into your ``C:/Users/<NAME>/autorun/plugins`` folder!__