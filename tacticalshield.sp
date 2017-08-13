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
#include "tacticalshield/shieldmanager.sp"

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
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	
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

public void OnMapStart()
{
	PrecacheModel(shieldModel, true);
}

public void OnClientPostAdminCheck(int client_index)
{
	int ref = EntIndexToEntRef(client_index);
	CreateTimer(3.0, Timer_WelcomeMessage, ref);
}

public void OnClientDisconnect(int client_index)
{
	DeleteShield(client_index);
	ResetPlayerVars(client_index);
}

public void ResetPlayerVars(int client_index)
{
	hasShield[client_index] = false;
}

public void InitVars()
{
	for (int i = 0; i < sizeof(hasShield); i++)
	{
		hasShield[i] = false;
		shields[i] = -1;
	}
}

/************************************************************************************************************
 *											EVENTS
 ************************************************************************************************************/

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	InitVars();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	DeleteShield(victim);
	ResetPlayerVars(victim);
}

/************************************************************************************************************
 *											COMMANDS
 ************************************************************************************************************/

public Action BuyShield(int client_index, int args)
{
	if (hasShield[client_index])
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>You already have a shield</font>");
		return Plugin_Handled;
	}
	int money = GetEntProp(client_index, Prop_Send, "m_iAccount");
	if (cvar_price.IntValue > money)
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>Not enough money</font>");
		return Plugin_Handled;
	}
	SetEntProp(client_index, Prop_Send, "m_iAccount", money - cvar_price.IntValue);
	PrintHintText(client_index, "Use ts_deploy command to use your shield");
	hasShield[client_index] = true;
	return Plugin_Handled;
}

public Action DeployShield(int client_index, int args)
{
	if (!hasShield[client_index])
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>You don't have a shield</font>");
		return Plugin_Handled;
	}
	if (IsHoldingShield(client_index))
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>Shield already deployed</font>");
		return Plugin_Handled;
	}
	PrintHintText(client_index, "Use ts_remove command to remove your shield");
	CreateShield(client_index);
	return Plugin_Handled;
}

public Action RemoveShield(int client_index, int args)
{
	DeleteShield(client_index);
	return Plugin_Handled;
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
 *											INPUT
 ************************************************************************************************************/
 

public Action OnPlayerRunCmd(int client_index, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayerAlive(client_index))
		return Plugin_Continue;
	
	
	// Limit speed when using shield
	if (IsHoldingShield(client_index))
	{
		if (vel[0] > cvar_speed.FloatValue)
			vel[0] = cvar_speed.FloatValue;
		if (vel[1] > cvar_speed.FloatValue)
			vel[1] = cvar_speed.FloatValue;
	}
	return Plugin_Changed;
}

/************************************************************************************************************
 *											TESTS
 ************************************************************************************************************/

public bool IsHoldingShield(int client_index)
{
	return shields[client_index] > 0;
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}