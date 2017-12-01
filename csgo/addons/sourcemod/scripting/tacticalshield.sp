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
	
	for(int i = 1; i <= MAXPLAYERS; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
			OnClientPostAdminCheck(i);
	}

	if (lateload)
		ServerCommand("mp_restartgame 1");
}

/**
* Precache models when the map starts to prevent crashes.
*/
public void OnMapStart()
{
	ReadCustomModelsFile();
	PrecacheModel(defaultShieldModel, true);
	if (!StrEqual(customShieldModel, "", false))
		PrecacheModel(customShieldModel, true);
}

/**
* Display a welcome message when the user gets in the server.
*/
public void OnClientPostAdminCheck(int client_index)
{
	int ref = EntIndexToEntRef(client_index);
	CreateTimer(3.0, Timer_WelcomeMessage, ref);
	SDKHook(client_index, SDKHook_OnTakeDamage, Hook_TakeDamagePlayer);
}

/**
* Reset everything related to the disconnected player.
*/
public void OnClientDisconnect(int client_index)
{
	DeleteShield(client_index);
	ResetPlayerVars(client_index);
	SDKUnhook(client_index, SDKHook_OnTakeDamage, Hook_TakeDamagePlayer);
}

/**
* Reset variables related to the given player player.
*
* @param client_index        Index of the client.
*/
public void ResetPlayerVars(int client_index)
{
	hasShield[client_index] = false;
	isShieldFull[client_index] = true;
	canChangeState[client_index] = true;
}

/**
* Initialize variables to default values.
*/
public void InitVars()
{
	useCustomModel = cvar_usecustom_model.BoolValue;
	shieldCooldown = cvar_cooldown.FloatValue;
	for (int i = 0; i < sizeof(hasShield); i++)
	{
		hasShield[i] = false;
		isShieldFull[i] = true;
		canChangeState[i] = true;
		shields[i] = -1;
	}
}

/************************************************************************************************************
 *											EVENTS
 ************************************************************************************************************/

 /**
 * Initialize variables when round starts.
 */
public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	InitVars();
}

/**
* Reset everything related to the dying player.
*/
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	DeleteShield(victim);
	ResetPlayerVars(victim);
}

/************************************************************************************************************
 *											COMMANDS
 ************************************************************************************************************/

 /**
 * Reload custom models file.
 */
public Action ReloadModelsList(int client_index, int args)
{
	ReadCustomModelsFile();
	return Plugin_Handled;
}

/**
* Show plugin help in the console and in chat.
*/
public Action ShowHelp(int client_index, int args)
{
	PrintToConsole(client_index, "|-------------------------------------------------------|");
	PrintToConsole(client_index, "|------------- TACTICAL SHIELD HELP --------------------|");
	PrintToConsole(client_index, "|---- CONSOLE ----|-- IN CHAT --|-- DESCRIPTION --------|");
	PrintToConsole(client_index, "|ts_buy           |             |Buy shield             |");
	PrintToConsole(client_index, "|-----------------|-------------|-----------------------|");
	PrintToConsole(client_index, "|ts_toggle        |             |Toggle the shield      |");
	PrintToConsole(client_index, "|-----------------|-------------|-----------------------|");
	PrintToConsole(client_index, "|ts_help          |!ts_help     |Display this help      |");
	PrintToConsole(client_index, "|-----------------|-------------|-----------------------|");
	PrintToConsole(client_index, "|-----------        ADMIN ONLY       -------------------|");
	PrintToConsole(client_index, "|-----------------|-------------|-----------------------|");
	PrintToConsole(client_index, "|cd_reloadmodels  |             |Reload custom models   |");
	PrintToConsole(client_index, "|-------------------------------------------------------|");
	PrintToConsole(client_index, "");
	PrintToConsole(client_index, "Press +use when holding the shield to switch between 'full' mode and 'half' mode");
	PrintToConsole(client_index, "Shield is automatically removed when switching weapons");
	PrintToConsole(client_index, "");
	PrintToConsole(client_index, "For a better experience, you should bind ts_buy and ts_toggle to a key:");
	PrintToConsole(client_index, "bind 'KEY' 'COMMAND' | This will bind 'COMMAND to 'KEY'");
	PrintToConsole(client_index, "EXAMPLE:");
	PrintToConsole(client_index, "bind \"z\" \"ts_buy\" | This will bind the buy command to the <Z> key");
	PrintToConsole(client_index, "bind \"x\" \"ts_toggle\" | This will bind the toggle command to the <X> key");

	CPrintToChat(client_index, "{green}----- TACTICAL SHIELD HELP -----");
	CPrintToChat(client_index, "{lime}>>> START");
	CPrintToChat(client_index, "This plugin is used with the console:");
	CPrintToChat(client_index, "To enable the console, do the following:");
	CPrintToChat(client_index, "{yellow}Options -> Game Option -> Enable Developper Console");
	CPrintToChat(client_index, "To set the toggle key, do the following:");
	CPrintToChat(client_index, "{yellow}Options -> Keyboard/Mouse -> Toggle Console");
	CPrintToChat(client_index, "{lime}Open the console for more information");
	CPrintToChat(client_index, "{green}----- ---------- ---------- -----");
	return Plugin_Handled;
}

/**
* Buy a new shield for the player using this command.
* A player can buy a shield if he has enough money and does not already have one.
*/
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
	PrintHintText(client_index, "Use <font color='#00ff00'>ts_toggle</font> command to use your shield");
	hasShield[client_index] = true;
	return Plugin_Handled;
}

/**
* Toggle the shield for the player using te command.
*/
public Action ToggleShield(int client_index, int args)
{
	if (!IsHoldingShield(client_index))
		TryDeployShield(client_index);
	else
		DeleteShield(client_index);
	return Plugin_Handled;
}

/**
* Delete the shield for the player using the command.
*/
public Action RemoveShield(int client_index, int args)
{
	DeleteShield(client_index);
	return Plugin_Handled;
}

/**
* Deploy the shield for the specified player if he is holding a pistol.
*
* @param client_index			Index of the client.
*/
public void TryDeployShield(int client_index)
{
	if (!hasShield[client_index])
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>You don't have a shield</font>");
		return;
	}
	if (!IsHoldingPistol(client_index))
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>You must hold your pistol to use the shield</font>");
		return;
	}
	PrintHintText(client_index, "Use <font color='#00ff00'>ts_toggle</font> command to remove your shield");
	CreateShield(client_index);
}

/************************************************************************************************************
 *											TIMERS
 ************************************************************************************************************/

 /**
 * Display a message to the player showing the plugin name and author.
 * Can be disabled by cvar.
 */
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

 /**
 * Manage player input.
 */
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
		}
		else
		{
			float fUnlockTime = GetGameTime() + 0.5;
			SetEntPropFloat(client_index, Prop_Send, "m_flNextAttack", fUnlockTime);

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

/**
* Limit the player speed to the ine specified.
* It does not limit falling or jumping speed
*
* @param client_index           Index of the client.
* @param maxSpeed               Speed limit.
*/
public void LimitSpeed(int client_index, float maxSpeed)
{
	float vel[3];
	GetEntPropVector(client_index, Prop_Data, "m_vecVelocity", vel);
	float velNorm = SquareRoot(vel[0]*vel[0] + vel[1]*vel[1]);
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

 /**
 * Test if the given player is holding a shield.
 *
 * @param client_index           Index of the client.
 * @return  true if the player is holding a shield, false otherwise.
 */
public bool IsHoldingShield(int client_index)
{
	if (!IsValidClient(client_index))
		return false
	else
		return shields[client_index] > 0;
}

/**
* Test if the given player is holding a pistol.
*
* @param client_index           Index of the client.
* @return   true if the player is holding a pistol, false otherwise.
*/
public bool IsHoldingPistol(int client_index)
{
	char weaponName[64], pistolName[64];
	int pistol = GetPlayerWeaponSlot(client_index, CS_SLOT_SECONDARY);
	GetClientWeapon(client_index, weaponName, sizeof(weaponName));
	GetEdictClassname(pistol, pistolName, sizeof(pistolName));
	return StrEqual(pistolName, weaponName, false);
}

/**
* Test if the given player is valid.
* The player must be connected and in game to be valid.
*
* @param client_index           Index of the client.
* @return true if the player is valid, false otherwise.
*/
stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}

/**
* Changes the variables associated to the cvars when changed.
*/
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

 /**
 * Read the custom models file to extract model names and custom rotations.
 * Those models and rotations are used if the corresponding cvar is set.
 */
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

/**
* Read the model on the given line and extracts the value to the associated variable.
*/
public void ReadModel(char line[PLATFORM_MAX_PATH])
{
	ReplaceString(line, sizeof(line), "model=", "", false);
	ReplaceString(line, sizeof(line), "\n", "", false);
	if (TryPrecacheModel(line))
		Format(customShieldModel, sizeof(customShieldModel), "%s", line);
	else
		customShieldModel = "";
}

/**
* Read the custom rotations and extracts their values to the corresponding variables.
*/
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

/**
* Try to precache the given model.
* If a model cannot be precached, it means it is not valid.
*/
public bool TryPrecacheModel(char[] model)
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




/**
* When the a player is taking damage and someone is holding a shield, trace a ray between the damage position and the damage origin.
* If the ray hits the shield, negate the damage.
*/
public Action Hook_TakeDamagePlayer(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker < 1 || attacker > MAXPLAYERS)
		return Plugin_Continue;
	bool isHoldingShield = false;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (IsHoldingShield(i))
		{
			isHoldingShield = true;
			break;
		}
	}
	if (!isHoldingShield)
		return Plugin_Continue;
	float attackerPos[3];
	GetClientEyePosition(attacker, attackerPos);

	Handle trace = TR_TraceRayFilterEx(attackerPos, damagePosition, MASK_SHOT, RayType_EndPoint, TraceFilterShield, 0);
	if(trace != INVALID_HANDLE && TR_DidHit(trace))
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

/**
* Filter for trace rays returning true only if the entity is a shield.
*/
public bool TraceFilterShield(int entity_index, int mask, any data)
{
	bool hit = false
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (IsHoldingShield(i) && entity_index == shields[i])
		{
			hit = true;
			break;
		}
	}
	return hit;
}