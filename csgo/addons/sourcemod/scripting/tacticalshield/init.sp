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

ConVar cvar_usecustom_model = null;

ConVar cvar_cooldown = null;


/**
* Creates plugin convars
*
* @param version        version name
*/
public void CreateConVars(char[] version)
{
	CreateConVar("tacticalshield_version", version, "Tactical Shield", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvar_welcome_message = CreateConVar("ts_welcomemessage", "1", "Displays a welcome message to new players. 0 = no message, 1 = display message", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_price = CreateConVar("ts_price", "100", "Shield price.", FCVAR_NOTIFY, true, 0.0, true, 50000.0);
	cvar_speed = CreateConVar("ts_speed", "100", "Player speed when using shield. 130 = walk with knife, 250 = run with knife", FCVAR_NOTIFY, true, 0.0, true, 250.0);

	cvar_usecustom_model = CreateConVar("ts_custommodel", "0", "Set whether to use a model specified in sourcemod/gamedata/tacticalshield/custom_models.txt.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_usecustom_model.AddChangeHook(OnCvarChange);
	cvar_cooldown = CreateConVar("ts_cooldown", "1", "Set the time after which player can change the shield state (full/half).", FCVAR_NOTIFY, true, 0.0, true, 1000.0);
	cvar_cooldown.AddChangeHook(OnCvarChange);

	AutoExecConfig(true, "tacticalshield");
}

/**
* Creates plugin commands
*/
public void RegisterCommands()
{
	RegAdminCmd("ts_reloadmodels", ReloadModelsList, ADMFLAG_GENERIC, "Reload custom models file");
	RegConsoleCmd("ts_buy", BuyShield, "Buy the tactical shield");
	RegConsoleCmd("ts_toggle", ToggleShield, "Toggle the tactical shield");
	RegConsoleCmd("ts_help", ShowHelp, "Show plugin help");
	RegConsoleCmd("say !ts_help", ShowHelp, "Show plugin help");
	RegConsoleCmd("say_team !ts_help", ShowHelp, "Show plugin help");
}
