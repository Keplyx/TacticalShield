---
layout : default
title : Installation
topbar_link : true
---

# Installation


 * ### Plugin Installation
Simply download **[tacticalshield.smx](https://github.com/Keplyx/tacticalshield/raw/master/csgo/addons/sourcemod/plugins/tacticalshield.smx)** and place it in your server inside "csgo/addons/sourcemod/plugins/".
A map is currently being made to work along with this plugin. [Get it here!](http://steamcommunity.com/sharedfiles/filedetails/?id=1102250426)

 * ### Custom Models Installation
If you want to use custom models for your shield, download the [custom_models.txt](https://github.com/Keplyx/tacticalshield/blob/master/csgo/addons/sourcemod/gamedata/tacticalshield/custom_models.txt) file and place it in your server inside "csgo/addons/sourcemod/gamedata/tacticalshield/".
If players do not see the model, make sure they have downloaded it.
To force players to download models, use the plugin [SM File/Folder Downloader and Precacher](https://forums.alliedmods.net/showthread.php?p=602270)

# Compatibility
 * ### TTT
This plugin is compatible with [Trouble in Terrorist Town](https://github.com/Bara/TroubleinTerroristTown) for csgo by [Bara](https://github.com/Bara).
Just install TTT and Tactical Shield normally for it to work.
You will want to set the cvars *ts_price "30000"* to prevent players from buying shields outside of the traitor/detective menu, and *ts_buytime "-1"* to allow player to buy one at anytime during the game. Also set *ts_keep_between_rounds "0"* to prevent players from keeping the shield between rounds.

 * ### MyJailShop
This plugin is compatible with [MyJailShop](https://github.com/shanapu/MyJailShop) for csgo by [shanapu](https://github.com/shanapu).
Just install MyJailShop and Tactical Shield normally for it to work.
You will want to set the cvars *ts_price "30000"* to prevent players from buying shields outside of the shop, and *ts_buytime "-1"* to allow player to buy one at anytime during the game. Also set *ts_keep_between_rounds "0"* to prevent players from keeping the shield between rounds. It is recommended to set *ts_shield_team "1"*, even though "0 should work as well.

 * ### Cameras and Drones
Compatible with [Cameras And Drones](https://keplyx.github.io/cameras-and-drones/).
You can use both plugins without any problem! (be sure to have the latest versions).
If you find a bug, please post an issue on github.
