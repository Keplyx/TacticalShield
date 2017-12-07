/*
*   This file is part of Tactical Shield.
*   Copyright (C) 2017  Keplyx
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

ConVar cvar_welcome_message = null;

ConVar cvar_price = null;
ConVar cvar_speed = null;
ConVar cvar_shield_team = null;

ConVar cvar_usecustom_model = null;

ConVar cvar_cooldown = null;

ConVar cvar_buytime = null;
ConVar cvar_buytime_start = null;

ConVar cvar_custom_model_path = null;

/**
* Creates plugin convars
*
* @param version        version name
*/
public void CreateConVars(char[] version)
{
	CreateConVar("tacticalshield_version", version, "Tactical Shield", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvar_welcome_message = CreateConVar("ts_welcomemessage", "1", "Displays a welcome message to new players. 0 = no message, 1 = display message", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_price = CreateConVar("ts_price", "800", "Shield price.", FCVAR_NOTIFY, true, 0.0, true, 50000.0);
	cvar_speed = CreateConVar("ts_speed", "100", "Player speed when using shield. 130 = walk with knife, 250 = run with knife", FCVAR_NOTIFY, true, 0.0, true, 250.0);
	cvar_shield_team = CreateConVar("ts_shield_team", "0", "Set which team can use shields. This can be overridden per players with the command 'ts_override'. 0 = Everyone, 1 = Nobody, 2 = T only, 3 = CT only", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_usecustom_model = CreateConVar("ts_custom_model", "0", "Set whether to use a model specified in sourcemod/gamedata/tacticalshield/custom_models.txt.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	cvar_usecustom_model.AddChangeHook(OnCvarChange);
	
	cvar_cooldown = CreateConVar("ts_cooldown", "1", "Set the time after which player can change the shield state (full/half).", FCVAR_NOTIFY, true, 0.0, true, 1000.0);
	cvar_cooldown.AddChangeHook(OnCvarChange);
	
	cvar_buytime = CreateConVar("ts_buytime", "-2", "Set how much time (in seconds) players have to buy a shield. -2 to use 'mp_buytime' value, -1 = forever", FCVAR_NOTIFY, true, -2.0, true, 1000.0);
	cvar_buytime_start = CreateConVar("ts_buytime_start", "0", "Set when to start buy time counter. 0 = on round start, 1 = on spawn", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_buytime.AddChangeHook(OnCvarChange);
	
	cvar_custom_model_path = CreateConVar("ts_custom_model_path", "gamedata/tacticalshield", "Set the path to the custom models file, relative to addons/sourcemod", FCVAR_NOTIFY);
	cvar_custom_model_path.AddChangeHook(OnCvarChange);
	AutoExecConfig(true, "tacticalshield");
}

/**
* Creates plugin commands
*/
public void RegisterCommands()
{
	RegAdminCmd("ts_override", OverrideShieldCommand, ADMFLAG_GENERIC, "Override shield for a player");
	RegAdminCmd("ts_reloadmodels", ReloadModelsList, ADMFLAG_GENERIC, "Reload custom model file");
	RegConsoleCmd("ts_buy", BuyShieldCommand, "Buy the tactical shield");
	RegConsoleCmd("ts_toggle", ToggleShield, "Toggle the tactical shield");
	RegConsoleCmd("ts_help", ShowHelp, "Show plugin help");
	RegConsoleCmd("say !ts_help", ShowHelp, "Show plugin help");
	RegConsoleCmd("say_team !ts_help", ShowHelp, "Show plugin help");
}
