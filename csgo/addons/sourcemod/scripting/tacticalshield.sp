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
#include <tacticalshield>

#undef REQUIRE_PLUGIN
#include <camerasanddrones>

#pragma newdecls required;

#include "tacticalshield/init.sp"
#include "tacticalshield/natives.sp"
#include "tacticalshield/shieldmanager.sp"

/*  New in this version
*
*	Added shield health
*	Added sounds
*	Improved various hint text
*	Added deploy cooldown
*	Can keep shield between rounds
*	Shield stays in the back of the player when he is not using it
*	Can drop/pickup shields
*	Added/changed natives
*/

#define VERSION "1.1.0"
#define PLUGIN_NAME "Tactical Shield"
#define AUTHOR "Keplyx"

#define customModelsFile "/custom_models.txt"

char customModelsPath[256];

bool lateload;
bool camerasAndDrones;
int playerShieldOverride[MAXPLAYERS + 1];
float buyTime;
bool canBuy[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = AUTHOR,
	description = "CSGO plugin adding a tactical shield to the game.",
	version = VERSION,
	url = "https://keplyx.github.io/TacticalShield/index.html"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	lateload = late;
	RegisterNatives();
	RegPluginLibrary("tacticalshield");
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	AddCommandListener(Command_Drop, "drop"); 
	
	CreateConVars(VERSION);
	InitVars(false);
	RegisterCommands();
	ReadCustomModelsFile();
	
	for(int i = 1; i <= MAXPLAYERS; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
			OnClientPostAdminCheck(i);
		stateTimers[i] = INVALID_HANDLE;
		deployTimers[i] = INVALID_HANDLE;
	}
	
	if (lateload)
		ServerCommand("mp_restartgame 1");
}

public void OnAllPluginsLoaded()
{
	camerasAndDrones = LibraryExists("cameras-and-drones");
}
 
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "cameras-and-drones"))
	{
		camerasAndDrones = false;
	}
}
 
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "cameras-and-drones"))
	{
		camerasAndDrones = true;
	}
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
		
	PrecacheSound(getShieldSound, true);
	PrecacheSound(toggleShieldSound, true);
	PrecacheSound(destroyShieldSound, true);
	PrecacheSound(changeStateShieldSound, true);
	PrecacheSound(cantBuyShieldSound, true);
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
	DeleteShield(client_index, false);
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
	isShieldHidden[client_index] = false;
	shieldState[client_index] = SHIELD_BACK;
	canChangeState[client_index] = true;
	canDeployShield[client_index] = true;
	playerShieldOverride[client_index] = 0;
	canBuy[client_index] = true;
	ResetPlayerTimers(client_index);
}

/**
* Initialize variables to default values.
*/
public void InitVars(bool isNewRound)
{
	useCustomModel = cvar_usecustom_model.BoolValue;
	shieldCooldown = cvar_cooldown.FloatValue;
	shieldHealth = cvar_shield_health.FloatValue;
	cvar_custom_model_path.GetString(customModelsPath, sizeof(customModelsPath));
	SetBuyTime();
	for (int i = 0; i < sizeof(hasShield); i++)
	{
		if (isNewRound && cvar_keep_between_rounds.BoolValue)
		{
			if (!hasShield[i])
			{
				shields[i] = -1;
				playerShieldOverride[i] = 0;
			}
		}
		else
		{
			hasShield[i] = false;
			shields[i] = -1;
			playerShieldOverride[i] = 0;
		}
		shieldState[i] = SHIELD_BACK;
		isShieldHidden[i] = false;
		canChangeState[i] = true;
		canDeployShield[i] = true;
		canBuy[i] = true;
		ResetPlayerTimers(i);
	}
	droppedShields = new ArrayList();
}

public void SetBuyState(int client_index, bool state)
{
	if (IsValidClient(client_index))
		canBuy[client_index] = state;
	else
	{
		for (int i = 0; i < sizeof(canBuy); i++)
		{
			canBuy[i] = state;
		}
	}
}

public void SetBuyTime()
{
	if (cvar_buytime.IntValue == -1)
		buyTime = -1.0;
	else if (cvar_buytime.IntValue == -2)
		buyTime = FindConVar("mp_buytime").FloatValue;
	else
		buyTime = cvar_buytime.FloatValue;
}

/************************************************************************************************************
 *											EVENTS
 ************************************************************************************************************/

 /**
 * Initialize variables when round starts.
 */
public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	InitVars(true);
	if (cvar_buytime_start.IntValue == 0)
	{
		SetBuyState(0, true);
		if (buyTime >= 0)
			CreateTimer(buyTime, Timer_BuyTime, 0);
	}
}

/**
* Reset everything related to the dying player and drop his shield.
*/
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client_index = GetClientOfUserId(GetEventInt(event, "userid"));
	if (hasShield[client_index])
		DropShield(client_index, false);
	ResetPlayerVars(client_index);
}

/**
* Starts buy timer on spawn if enabled.
*/
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client_index = GetClientOfUserId(GetEventInt(event, "userid"));
	int ref = EntIndexToEntRef(client_index);
	if (cvar_buytime_start.IntValue == 1)
	{
		SetBuyState(client_index, true);
		if (buyTime >= 0)
			CreateTimer(buyTime, Timer_BuyTime, ref);
	}
	if (hasShield[client_index])
		CreateShield(client_index);
}

/************************************************************************************************************
 *											COMMANDS
 ************************************************************************************************************/

/**
* Allow players to drop their shield.
*/
public Action Command_Drop(int client_index, char[] command, int args)
{
	if (IsHoldingShield(client_index))
	{
		PrintHintText(client_index, "Your dropped your shield");
		DropShield(client_index, true);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}  

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
	PrintToConsole(client_index, "|ts_reloadmodel   |             |Reload custom model    |");
	PrintToConsole(client_index, "|-----------------|-------------|-----------------------|");
	PrintToConsole(client_index, "|ts_override      |             |Override shield status |");
	PrintToConsole(client_index, "|-------------------------------------------------------|");
	PrintToConsole(client_index, "");
	PrintToConsole(client_index, "Press +use when holding the shield to switch between 'full' mode and 'half' mode");
	PrintToConsole(client_index, "Shield is automatically removed when switching weapons");
	PrintToConsole(client_index, "Use +drop while holding the shield to drop it");
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
public Action BuyShieldCommand(int client_index, int args)
{
	GetShield(client_index, false);
	return Plugin_Handled;
}

public void GetShield(int client_index, bool isFree)
{
	if (hasShield[client_index])
	{
		PrintHintText(client_index, "<font color='#ff0000'>You already have a shield</font>");
		EmitSoundToClient(client_index, cantBuyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
		return;
	}
	if (!CanUseShield(client_index))
	{
		PrintHintText(client_index, "<font color='#ff0000'>You cannot get shields</font>");
		EmitSoundToClient(client_index, cantBuyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
		return;
	}
	if (!canBuy[client_index])
	{
		PrintHintText(client_index, "<font color='#ff0000'>Buy time expired</font>");
		EmitSoundToClient(client_index, cantBuyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
		return;
	}
	if (!isFree)
	{
		int money = GetEntProp(client_index, Prop_Send, "m_iAccount");
		if (cvar_price.IntValue > money)
		{
			PrintHintText(client_index, "<font color='#ff0000'>Not enough money</font>");
			EmitSoundToClient(client_index, cantBuyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
			return;
		}
		SetEntProp(client_index, Prop_Send, "m_iAccount", money - cvar_price.IntValue);
	}
	
	EmitSoundToClient(client_index, getShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
	PrintHintText(client_index, "Use <font color='#00ff00'>ts_toggle</font> command to use your shield");
	CreateShield(client_index);
}

/**
* Toggle the shield for the player using te command.
*/
public Action ToggleShield(int client_index, int args)
{
	if (!IsHoldingShield(client_index))
		TryDeployShield(client_index);
	else
		UnequipShield(client_index);
	return Plugin_Handled;
}

/**
* Delete the shield for the player using the command.
*/
public Action RemoveShield(int client_index, int args)
{
	UnequipShield(client_index);
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
		PrintHintText(client_index, "<font color='#ff0000'>You don't have a shield</font>");
		EmitSoundToClient(client_index, cantBuyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
		return;
	}
	if (!IsHoldingPistol(client_index))
	{
		PrintHintText(client_index, "<font color='#ff0000'>You must hold your pistol to use the shield</font>");
		EmitSoundToClient(client_index, cantBuyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
		return;
	}
	if (!CanUseShield(client_index) || (camerasAndDrones && IsPlayerInGear(client_index)))
	{
		PrintHintText(client_index, "<font color='#ff0000'>You cannot use shields</font>");
		EmitSoundToClient(client_index, cantBuyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
		return;
	}
	if (!canDeployShield[client_index])
	{
		PrintHintText(client_index, "<font color='#ff0000'>You need to wait before redeploying your shield</font>");
		EmitSoundToClient(client_index, cantBuyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
		return;
	}
	
	PrintHintText(client_index, "<font color='#dd3f18'>Commands:</font><br><font color='#00ff00'>ts_toggle</font>: remove your shield<br><font color='#00ff00'>+use</font>: toggle full/half shield mode");
	EquipShield(client_index);
}


/**
 * Overrides the given player's shield status.
 * This way you can have only one player using shields, or specific players not being able to use them.
 */
public Action OverrideShieldCommand(int client_index, int args)
{
	if (args == 0)
	{
		PrintToConsole(client_index, "Usage: ts_override <player> <status>");
		PrintToConsole(client_index, "<status> = 0 | team chosen");
		PrintToConsole(client_index, "<status> = 1 | cannot use shields");
		PrintToConsole(client_index, "<status> = 2 | can use shields");
		return Plugin_Handled;
	}

	char name[32];
	int target = -1;
	GetCmdArg(1, name, sizeof(name));
	target = FindPlayerOfName(name);
	if (target == -1)
	{
		PrintToConsole(client_index, "Could not find any player with the name: \"%s\"", name);
		PrintToConsole(client_index, "Available players:");
		ShowPlayerList(client_index);
		return Plugin_Handled;
	}

	char arg[32];
	GetCmdArg(2, arg, sizeof(arg));
	int status = StringToInt(arg);
	OverrideShield(target, status);
	return Plugin_Handled;
}

/**
* Show a list of connected clients to the specified player.
*
* @param client_index			Index of the client.
*/
public void ShowPlayerList(int client_index)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))
		{
			continue;
		}
		char player[32];
		GetClientName(i, player, sizeof(player));
		PrintToConsole(client_index, "\"%s\"", player);
	}
}

/**
* Find a client by his name.
*
* @param name			Name of the client.
* @return 				Client index.
*/
public int FindPlayerOfName(char name[32])
{
	int target = -1;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))
		{
			continue;
		}
		char other[32];
		GetClientName(i, other, sizeof(other));
		if (StrEqual(name, other))
		{
			target = i;
		}
	}
	return target;
}

/**
* Override shield status for the specified player.
*
* @param client_index			Index of the client.
* @param status					override status. 0= no override, 1= force no shields, 2= force shields.
*/
public void OverrideShield(int client_index, int status)
{
	if (status > 2 || status < 0)
		status = 0;
	playerShieldOverride[client_index] = status;
	switch (status)
	{
		case 0: PrintToConsole(client_index, "You now use shields like your teammates!");
		case 1: PrintToConsole(client_index, "You can't use shields anymore!");
		case 2: PrintToConsole(client_index, "You can now use shields!");
	}
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

 /**
 * Stops players from buying after a time limit.
 * This limit can be set by cvar.
 */
public Action Timer_BuyTime(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (IsValidClient(client_index))
		SetBuyState(client_index, false);
	else
		SetBuyState(0, false);
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
	
	if (buttons & IN_USE)
		TryPickupShield(client_index);
	
	if (IsHoldingShield(client_index))
	{
		if (buttons & IN_USE)
			ToggleShieldState(client_index);
		
		if (shieldState[client_index] == SHIELD_HALF)
		{
			// Limit speed when using shield (faster when not fully using it)
			float runSpeed = cvar_speed.FloatValue + 100;
			if (runSpeed > 250.0)
				runSpeed = 250.0;

			LimitSpeed(client_index, runSpeed);
		}
		else if (shieldState[client_index] == SHIELD_FULL)
		{
			float fUnlockTime = GetGameTime() + 0.1;
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
	if (!IsValidEdict(pistol))
		return false;
	GetEdictClassname(pistol, pistolName, sizeof(pistolName));
	
	// pistolName: 'weapon_hkp2000' | weaponName: 'weapon_usp_silencer' USP you bitch
	return StrEqual(pistolName, weaponName, false) || StrEqual(pistolName, "weapon_hkp2000", false);
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
 * Checks if the given player's team can use shields.
 * Also checks if the player's shield status has been overriden.
 *
 * @param client_index		index of the client.
 * @return					true if the player can use shields, false otherwise.
 */
public bool CanUseShield(int client_index)
{
	if (!IsValidClient(client_index))
		return false
	else
		return playerShieldOverride[client_index] != 1 && GetClientTeam(client_index) > 1 && ((GetClientTeam(client_index) == cvar_shield_team.IntValue || cvar_shield_team.IntValue == 0) || playerShieldOverride[client_index] == 2);
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
	else if (convar == cvar_buytime)
		SetBuyTime();
	else if (convar == cvar_custom_model_path)
		convar.GetString(customModelsPath, sizeof(customModelsPath));
	else if (convar == cvar_shield_health)
		shieldHealth = convar.FloatValue;
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
	BuildPath(Path_SM, path, sizeof(path), "%s%s", customModelsPath, customModelsFile);
	File file = OpenFile(path, "r");
	if (!FileExists(path))
	{
		customShieldModel = "";
		for (int i = 0; i < sizeof(customFullPos); i++)
		{
			customFullPos[i] = defaultFullPos[i];
			customFullRot[i] = defaultFullRot[i];
			customHalfPos[i] = defaultHalfPos[i];
			customHalfRot[i] = defaultHalfRot[i];
			customBackPos[i] = defaultBackPos[i];
			customBackRot[i] = defaultBackRot[i];
		}
		PrintToServer("Could not find custom models file. Falling back to default");
		return;
	}
	while (file.ReadLine(line, sizeof(line)))
	{
		if (StrContains(line, "//", false) == 0)
			continue;

		if (StrContains(line, "model=", false) == 0)
			ReadModel(line)
		else if (StrContains(line, "fullPos{", false) == 0)
			SetCustomTransform(file, true, SHIELD_FULL);
		else if (StrContains(line, "fullRot{", false) == 0)
			SetCustomTransform(file, false, SHIELD_FULL);
		else if (StrContains(line, "halfPos{", false) == 0)
			SetCustomTransform(file, true, SHIELD_HALF);
		else if (StrContains(line, "halfRot{", false) == 0)
			SetCustomTransform(file, false, SHIELD_HALF);
		else if (StrContains(line, "backPos{", false) == 0)
			SetCustomTransform(file, true, SHIELD_BACK);
		else if (StrContains(line, "backRot{", false) == 0)
			SetCustomTransform(file, false, SHIELD_BACK);
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
public void SetCustomTransform(File file, bool isPos, int state)
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

		switch(state)
		{
			case SHIELD_FULL:
			{
				if (isPos)
					customFullPos[i] = StringToFloat(line);
				else
					customFullRot[i] = StringToFloat(line);
			}
			case SHIELD_HALF:
			{
				if (isPos)
					customHalfPos[i] = StringToFloat(line);
				else
					customHalfRot[i] = StringToFloat(line);
			}
			case SHIELD_BACK:
			{
				if (isPos)
					customBackPos[i] = StringToFloat(line);
				else
					customBackRot[i] = StringToFloat(line);
			}
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