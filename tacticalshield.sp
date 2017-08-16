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

#define customModelsPath "gamedata/tacticalshield/custom_models.txt"

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
	ReadCustomModelsFile();
	
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
	PrecacheModel(defaultShieldModel, true);
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
	useCustomModel = cvar_usecustom_model.BoolValue;
	shieldCooldown = cvar_cooldown.FloatValue;
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

public Action ReloadModelsList(int client_index, int args)
{
	ReadCustomModelsFile();
	return Plugin_Handled;
}

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
	if (!IsHoldingPistol(client_index))
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>You must hold your pistol to use the shield</font>");
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
	
	
	if (IsHoldingShield(client_index))
	{
		if (buttons & IN_USE)
			ToggleShieldState(client_index);
		
		if (!isShieldFull[client_index])
		{
			// Limit speed when using shield (faster when not fully using it)
			float runSpeed = cvar_speed.FloatValue + 100;
			if (runSpeed > 250.0)
				runSpeed = 250.0;
			
			LimitSpeed(client_index, runSpeed);
			
			float fUnlockTime = GetGameTime() + 0.5;
			SetEntPropFloat(client_index, Prop_Send, "m_flNextAttack", fUnlockTime);
		}
		else
		{
			float walkSpeed = cvar_speed.FloatValue;
			if (buttons & IN_SPEED)
				walkSpeed /= 2.0;
			if (buttons & IN_DUCK)
				walkSpeed /= 4.0;
			// Limit speed when using shield
			LimitSpeed(client_index, walkSpeed);
		}
	}
	return Plugin_Changed;
}

public void LimitSpeed(int client_index, float maxSpeed)
{
	float vel[3];
	GetEntPropVector(client_index, Prop_Data, "m_vecVelocity", vel);
	float velNorm = SquareRoot(vel[0]*vel[0] + vel[1]*vel[1]); // We do not limit falling speed
	if (velNorm <= maxSpeed)
		return;
	
	vel[0] /= velNorm;
	vel[0] *= maxSpeed;
	vel[1] /= velNorm;
	vel[1] *= maxSpeed;
	TeleportEntity(client_index, NULL_VECTOR, NULL_VECTOR, vel);
}

/************************************************************************************************************
 *											TESTS
 ************************************************************************************************************/

public bool IsHoldingShield(int client_index)
{
	return shields[client_index] > 0;
}

public bool IsHoldingPistol(int client_index)
{
	char weaponName[64], pistolName[64];
	int pistol = GetPlayerWeaponSlot(client_index, CS_SLOT_SECONDARY);
	GetClientWeapon(client_index, weaponName, sizeof(weaponName));
	GetEdictClassname(pistol, pistolName, sizeof(pistolName));
	return StrEqual(pistolName, weaponName, false);
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}


public void OnCvarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	if (convar == cvar_usecustom_model)
		useCustomModel = convar.BoolValue;
	else if (convar == cvar_cooldown)
		shieldCooldown = convar.FloatValue;
}


/************************************************************************************************************
 *											CUSTOM MODEL
 ************************************************************************************************************/

public void ReadCustomModelsFile()
{
	char path[PLATFORM_MAX_PATH], line[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "%s", customModelsPath);
	File file = OpenFile(path, "r");
	while (file.ReadLine(line, sizeof(line)))
	{
		if (StrContains(line, "//", false) == 0)
			continue;
		
		if (StrContains(line, "model=", false) == 0)
			ReadModel(line)
		else if (StrContains(line, "pos{", false) == 0)
			SetCustomTransform(file, true, true);
		else if (StrContains(line, "rot{", false) == 0)
			SetCustomTransform(file, false, true);
		else if (StrContains(line, "movedpos{", false) == 0)
			SetCustomTransform(file, true, false);
		else if (StrContains(line, "movedrot{", false) == 0)
			SetCustomTransform(file, false, false);
		if (file.EndOfFile())
			break;
	}
	CloseHandle(file);
}

public void ReadModel(char line[PLATFORM_MAX_PATH])
{
	ReplaceString(line, sizeof(line), "model=", "", false);
	ReplaceString(line, sizeof(line), "\n", "", false);
	if (TryPrecacheCamModel(line))
		Format(customShieldModel, sizeof(customShieldModel), "%s", line);
	else
		customShieldModel = "";
}

public void SetCustomTransform(File file, bool isPos, bool isFull)
{
	char line[512];
	while (file.ReadLine(line, sizeof(line)))
	{
		int i = 0;
		if (StrContains(line, "x=", false) == 0)
			ReplaceString(line, sizeof(line), "x=", "", false);
		else if (StrContains(line, "y=", false) == 0)
		{
			ReplaceString(line, sizeof(line), "y=", "", false);
			i = 1;
		}
		else if (StrContains(line, "z=", false) == 0)
		{
			ReplaceString(line, sizeof(line), "z=", "", false);
			i = 2;
		}
		else if (StrContains(line, "}", false) == 0)
			return;
		ReplaceString(line, sizeof(line), "\n", "", false);
		
		if (isFull)
		{
			if (isPos)
				customPos[i] = StringToFloat(line);
			else
				customRot[i] = StringToFloat(line);
		}
		else
		{
			if (isPos)
				customMovedPos[i] = StringToFloat(line);
			else
				customMovedRot[i] = StringToFloat(line);
		}
	}
}


public bool TryPrecacheCamModel(char[] model)
{
	int result = PrecacheModel(model);
	if (result < 1)
	{
		PrintToServer("Error precaching custom model '%s'. Falling back to default", model);
		return false;
	}
	PrintToServer("Successfully precached custom model '%s'", model);
	return true;
}