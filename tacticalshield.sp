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


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <csgocolors>

#pragma newdecls required;

#include "tacticalshield/init.sp"

/*  New in this version
*
*	Not released yet...
*
*/

#define VERSION "0.0.1"
#define PLUGIN_NAME "Tactical Shield"
#define AUTHOR "Keplyx"

bool lateload;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = AUTHOR,
	description = "Tactical shield to protect yourself.",
	version = VERSION,
	url = "https://github.com/Keplyx/TacticalShield"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	lateload = late;
	return APLRes_Success;
}

public void OnPluginStart()
{

	CreateConVars(VERSION);
	RegisterCommands();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
			OnClientPostAdminCheck(i);
	}
	
	if (lateload)
		ServerCommand("mp_restartgame 1");
}

public void OnClientPostAdminCheck(int client_index)
{
	int ref = EntIndexToEntRef(client_index);
	CreateTimer(3.0, Timer_WelcomeMessage, ref);
}

/************************************************************************************************************
 *											TIMERS
 ************************************************************************************************************/
 
public Action Timer_WelcomeMessage(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (cvar_welcome_message.BoolValue && IsValidClient(client_index))
	{
		//Welcome message (white text in red box)
		CPrintToChat(client_index, "{darkred}********************************");
		CPrintToChat(client_index, "{darkred}* {default}This server uses {lime}%s", PLUGIN_NAME);
		CPrintToChat(client_index, "{darkred}*            {default}Made by {lime}%s", AUTHOR);
		CPrintToChat(client_index, "{darkred}* {default}Use {lime}!ts_help{default} in chat to learn");
		CPrintToChat(client_index, "{darkred}*                  {default}how to play");
		CPrintToChat(client_index, "{darkred}********************************");
	}
}

/************************************************************************************************************
 *											TESTS
 ************************************************************************************************************/

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}