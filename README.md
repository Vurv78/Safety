# ``Safety`` [![License](https://img.shields.io/github/license/Vurv78/Safety?color=red)](https://opensource.org/licenses/MIT)

This is a repo that contains files to be used with [Autorun-rs](https://github.com/Vurv78/Autorun-rs).

Take back control from the shitty security hellhole that Gmod is.  
These scripts attempt to make your game more safe by preventing crashes and disallowing anything malicious like deleting all of your files or spamming you with massive evil files.  

## Features
* Blacklisting Net Messages
* Changing File Read/Write Permissions
* Blacklisting ConCommands (``+voicerecord``, etc)
* Patches >15 easy ways to crash your game
* Being mostly undetectable (Unless a dev is moderately smart and looks at the code in this repo, which I'd doubt from most anti-cheat creators. You can always make this 100% by modifying the source. Anything that's open source will always have holes in it.)
* HTTP Whitelist to avoid leaking your IP and downloading evil content thanks to terribly made addons (PAC, Streamcore)

## Usage
As noted in the ``Autorun`` repo, drag both ``autorun.lua`` and ``hook.lua`` into your ``C:\Users\<User>\sautorun-rs`` folder.  
Boot up gmod with Autorun-rs injected, and that's it.
