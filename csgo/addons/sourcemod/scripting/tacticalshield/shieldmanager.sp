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

#include <sdktools>
#include <sdkhooks>


char defaultShieldModel[] = "models/props/de_overpass/overpass_metal_door02.mdl";
char customShieldModel[PLATFORM_MAX_PATH];

char getShieldSound[] = "items/itempickup.wav";
char toggleShieldSound[] = "weapons/movement3.wav";
char changeStateShieldSound[] = "weapons/movement1.wav";
char destroyShieldSound[] = "physics/metal/metal_box_break1.wav";
char cantBuyShieldSound[] = "ui/weapon_cant_buy.wav";


int shields[MAXPLAYERS + 1];
bool hasShield[MAXPLAYERS + 1];
bool isShieldFull[MAXPLAYERS + 1];
bool canChangeState[MAXPLAYERS + 1];
bool canDeployShield[MAXPLAYERS + 1];

Handle stateTimers[MAXPLAYERS + 1];
Handle deployTimers[MAXPLAYERS + 1];

bool useCustomModel = false;

float defaultPos[3] = {20.0, 0.0, -70.0};
float defaultRot[3] = {0.0, 0.0, 0.0};
float defaultMovedPos[3] = {0.0, 15.0, -70.0};
float defaultMovedRot[3] = {0.0, 80.0, 0.0};
float customPos[3];
float customRot[3];
float customMovedPos[3];
float customMovedRot[3];
float shieldCooldown = 0.5;

float damageTakenByShield[MAXPLAYERS + 1];
float shieldHealth;

/**
* Creates a shield for the given player.
* This shield is a prop prop_dynamic_override with the custom shield model
* (default if none was specified in the custom models file)
* It does not collide with players and world.
*
* @param client_index        Index of the client.
*/
public void CreateShield(int client_index)
{
	int shield = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(shield)) {
		shields[client_index] = shield;
		if (useCustomModel && !StrEqual(customShieldModel, "", false))
			SetEntityModel(shield, customShieldModel);
		else
			SetEntityModel(shield, defaultShieldModel);
		DispatchKeyValue(shield, "solid", "6");
		SetEntProp(shield, Prop_Data, "m_CollisionGroup", 1); // Stop collisions with players / world
		SetEntPropEnt(shield, Prop_Send, "m_hOwnerEntity", client_index);
		DispatchSpawn(shield);
		ActivateEntity(shield);

		SetEntityMoveType(shield, MOVETYPE_NONE);
		SetVariantString("!activator"); AcceptEntityInput(shield, "SetParent", client_index, shield, 0);
		SetVariantString("facemask"); AcceptEntityInput(shield, "SetParentAttachmentMaintainOffset");
		isShieldFull[client_index] = true;
		canChangeState[client_index] = true;
		damageTakenByShield[client_index] = 0.0;
		SetShieldPos(client_index);
		
		EmitSoundToClient(client_index, toggleShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
		SDKHook(client_index, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
		SDKHook(shield, SDKHook_OnTakeDamage, Hook_TakeDamageShield);
	}
}

/**
* Unequips the shield for the given player, playing the sound.
*
* @param client_index        Index of the client.
*/
public void UnEquipShield(int client_index)
{
	EmitSoundToClient(client_index, toggleShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
	DeleteShield(client_index);
}

/**
* Destroys the shield for the given player, playing the destroy sound forcing him to buy an other one.
*
* @param client_index        Index of the client.
*/
public void DestroyShield(int client_index)
{
	EmitSoundToAll(destroyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
	PrintHintText(client_index, "<font color='#FF000'>Your shield got destroyed!</font>");
	hasShield[client_index] = false;
	DeleteShield(client_index);
}

/**
* Deletes the shield for the given player.
*
* @param client_index        Index of the client.
*/
public void DeleteShield(int client_index)
{
	SDKUnhook(client_index, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
	SDKUnhook(shields[client_index], SDKHook_OnTakeDamage, Hook_TakeDamageShield);
	if (IsValidEdict(shields[client_index]))
	{
		RemoveEdict(shields[client_index]);
	}
	shields[client_index] = -1;
	canDeployShield[client_index] = false;
	int ref = EntIndexToEntRef(client_index);
	deployTimers[client_index] = CreateTimer(shieldCooldown, Timer_ShieldDeployCooldown, ref);
}

/**
* Toggles the shield between full and half position for the given player.
*
* @param client_index        Index of the client.
*/
public void ToggleShieldState(int client_index)
{
	if (canChangeState[client_index])
	{
		isShieldFull[client_index] = !isShieldFull[client_index];
		canChangeState[client_index] = false;
		int ref = EntIndexToEntRef(client_index);
		stateTimers[client_index] = CreateTimer(shieldCooldown, Timer_ShieldStateCooldown, ref);
		SetShieldPos(client_index);
		EmitSoundToClient(client_index, changeStateShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
	}
}

/**
* Sets the shield position for the given player.
* Uses the custom rotation if specified in the custom models file, default otherwise.
*
* @param client_index        Index of the client.
* @param isFull              Shield position.
*/
public void SetShieldPos(int client_index)
{
	float clientPos[3], clientAngles[3];
	GetClientAbsOrigin(client_index, clientPos);
	GetClientEyeAngles(client_index, clientAngles);
	float pos[3], rot[3];
	
	for (int i = 0; i < 3; i++)
	{
		if (!isShieldFull[client_index])
		{
			if (useCustomModel)
			{
				pos[i] = customMovedPos[i];
				rot[i] = customMovedRot[i];
			}
			else
			{
				pos[i] = defaultMovedPos[i];
				rot[i] = defaultMovedRot[i];
			}
		}
		else
		{
			if (useCustomModel)
			{
				pos[i] = customPos[i];
				rot[i] = customRot[i];
			}
			else
			{
				pos[i] = defaultPos[i];
				rot[i] = defaultRot[i];
			}
		}
	}
	TeleportEntity(shields[client_index], pos, rot, NULL_VECTOR);
}

/**
* Deletes the shield if the player switches to an other weapon.
*
* @param client_index        Index of the client.
* @param weapon_index        Index of the weapon.
*/
public void Hook_WeaponSwitch(int client_index, int weapon_index)
{
	UnEquipShield(client_index);
}

/**
* Timer to prevent players from changing shield state too quickly.
*/
public Action Timer_ShieldStateCooldown(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (client_index > 0 && client_index <= MAXPLAYERS)
		canChangeState[client_index] = true;
}

/**
* Timer to prevent players from deploying/removing shield too quickly.
*/
public Action Timer_ShieldDeployCooldown(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (client_index > 0 && client_index <= MAXPLAYERS)
		canDeployShield[client_index] = true;
}

/**
* Get damage taken by shield to destroy it.
*/
public Action Hook_TakeDamageShield(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker < 1 || attacker > MAXPLAYERS)
		return Plugin_Continue;
	int client_index = -1;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (shields[i] == victim)
		{
			client_index = i;
			break;
		}
	}
	if (client_index == -1)
		return Plugin_Continue;
	
	if (shieldHealth > 0.0)
	{
		if (damageTakenByShield[client_index]/shieldHealth < 0.8 && (damageTakenByShield[client_index] + damage)/shieldHealth > 0.8)
			PrintHintText(client_index, "<font color='#FF0000'>Your shield is about to break!<br>Take cover!</font>");
		else if (damageTakenByShield[client_index]/shieldHealth < 0.5 && (damageTakenByShield[client_index] + damage)/shieldHealth > 0.5)
			PrintHintText(client_index, "<font color='#FF0000'>Your shield is at half health!</font>");
		
		damageTakenByShield[client_index] += damage;
		
		if (damageTakenByShield[client_index] > shieldHealth)
			DestroyShield(client_index);
	}
	return Plugin_Continue;
}

public void ResetPlayerTimers(int client_index)
{
	if (deployTimers[client_index] != INVALID_HANDLE)
		CloseHandle(deployTimers[client_index]);
	if (stateTimers[client_index] != INVALID_HANDLE)
		CloseHandle(stateTimers[client_index]);
	
	deployTimers[client_index] = INVALID_HANDLE;
	stateTimers[client_index] = INVALID_HANDLE
}
