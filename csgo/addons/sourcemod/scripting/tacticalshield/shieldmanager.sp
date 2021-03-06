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
ArrayList droppedShields;
int shieldState[MAXPLAYERS + 1];

bool hasShield[MAXPLAYERS + 1];
bool isShieldHidden[MAXPLAYERS + 1];
bool canChangeState[MAXPLAYERS + 1];
bool canDeployShield[MAXPLAYERS + 1];

Handle stateTimers[MAXPLAYERS + 1];
Handle deployTimers[MAXPLAYERS + 1];

bool useCustomModel = false;

float defaultFullPos[3] = {20.0, 0.0, -70.0};
float defaultFullRot[3] = {0.0, 0.0, 0.0};
float defaultHalfPos[3] = {0.0, 15.0, -70.0};
float defaultHalfRot[3] = {0.0, 80.0, 0.0};
float defaultBackPos[3] = {-25.0, 0.0, -70.0};
float defaultBackRot[3] = {0.0, 0.0, 0.0};

float customFullPos[3];
float customFullRot[3];
float customHalfPos[3];
float customHalfRot[3];
float customBackPos[3];
float customBackRot[3];

float shieldCooldown = 0.5;

float damageTakenByShield[MAXPLAYERS + 1];
float shieldHealth;

enum (+=1)
{
	SHIELD_BACK = 0,
	SHIELD_HALF,
	SHIELD_FULL
}

/**
* Creates a shield for the given player, in his back, ready for deployment.
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
		PrintToServer("custom model : %s", customShieldModel);
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
		canChangeState[client_index] = true;
		damageTakenByShield[client_index] = 0.0;
		shieldState[client_index] = SHIELD_BACK;
		hasShield[client_index] = true;
		SetShieldPos(client_index);
		
		SDKHook(client_index, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
		SDKHook(shield, SDKHook_OnTakeDamage, Hook_TakeDamageShield);
		SDKHook(shield, SDKHook_SetTransmit, Hook_SetTransmitShield);
	}
}

/**
* Deletes the shield for the given player.
*
* @param client_index		Index of the client.
* @param isHiding			Whether is keeping the shield in the inventory or not.
*/
public void DeleteShield(int client_index, bool isHiding)
{
	SDKUnhook(client_index, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
	SDKUnhook(shields[client_index], SDKHook_OnTakeDamage, Hook_TakeDamageShield);
	SDKUnhook(shields[client_index], SDKHook_SetTransmit, Hook_SetTransmitShield);
	if (IsValidEdict(shields[client_index]) && !isShieldHidden[client_index])
	{
		RemoveEdict(shields[client_index]);
	}
	shields[client_index] = -1;
	hasShield[client_index] = isHiding;
	isShieldHidden[client_index] = isHiding;
}

/**
* Hide/unhide the shield for the given player, stopping him to use it while hidden.
*
* @param client_index			Index of the client.
* @param hide					true to hide the shield, false otherwise.
*/
public void SetHideShield(int client_index, bool hide)
{
	if (!hasShield[client_index])
		return;
	if (hide)
		DeleteShield(client_index, true);
	else
		CreateShield(client_index);
	isShieldHidden[client_index] = hide;
}

/**
* Equip/Unequip the shield for the given player, playing the sound.
*
* @param client_index		Index of the client.
* @param equip				true to equip, false otherwise.
*/
public void SetEquipShield(int client_index, bool equip)
{
	if (equip)
		EquipShield(client_index);
	else
		UnequipShield(client_index);
}

/**
* Equip the shield for the given player, playing the sound.
*
* @param client_index        Index of the client.
*/
public void EquipShield(int client_index)
{
	if (IsHoldingShield(client_index))
		return;
	EmitSoundToClient(client_index, toggleShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
	shieldState[client_index] = SHIELD_FULL;
	SetShieldPos(client_index);
}

/**
* Unequip the shield for the given player, playing the sound.
*
* @param client_index        Index of the client.
*/
public void UnequipShield(int client_index)
{
	if (!IsHoldingShield(client_index))
		return;
	EmitSoundToClient(client_index, toggleShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
	shieldState[client_index] = SHIELD_BACK;
	SetShieldPos(client_index);
	canDeployShield[client_index] = false;
	int ref = EntIndexToEntRef(client_index);
	deployTimers[client_index] = CreateTimer(shieldCooldown, Timer_ShieldDeployCooldown, ref);
}

/**
* Destroys the shield for the given player, playing the destroy sound forcing him to buy an other one.
*
* @param client_index        Index of the client.
*/
public void DestroyShield(int client_index)
{
	if (!hasShield[client_index])
		return;
	EmitSoundToAll(destroyShieldSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
	PrintHintText(client_index, "<font color='#FF000'>Your shield got destroyed!</font>");
	DeleteShield(client_index, false);
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
		if (shieldState[client_index] == SHIELD_FULL)
			shieldState[client_index] = SHIELD_HALF;
		else if (shieldState[client_index] == SHIELD_HALF)
			shieldState[client_index] = SHIELD_FULL;
		
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
		switch(shieldState[client_index])
		{
			case SHIELD_FULL:
			{
				if (useCustomModel)
				{
					pos[i] = customFullPos[i];
					rot[i] = customFullRot[i];
				}
				else
				{
					pos[i] = defaultFullPos[i];
					rot[i] = defaultFullRot[i];
				}
			}
			case SHIELD_HALF:
			{
				if (useCustomModel)
				{
					pos[i] = customHalfPos[i];
					rot[i] = customHalfRot[i];
				}
				else
				{
					pos[i] = defaultHalfPos[i];
					rot[i] = defaultHalfRot[i];
				}
			}
			case SHIELD_BACK:
			{
				if (useCustomModel)
				{
					pos[i] = customBackPos[i];
					rot[i] = customBackRot[i];
				}
				else
				{
					pos[i] = defaultBackPos[i];
					rot[i] = defaultBackRot[i];
				}
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
	if (IsHoldingShield(client_index))
		SetEquipShield(client_index, false);
}

/**
* Timer to prevent players from changing shield state too quickly.
*/
public Action Timer_ShieldStateCooldown(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (client_index > 0 && client_index <= MAXPLAYERS)
		canChangeState[client_index] = true;
	stateTimers[client_index] = INVALID_HANDLE;
	return Plugin_Handled;
}

/**
* Timer to prevent players from deploying/removing shield too quickly.
*/
public Action Timer_ShieldDeployCooldown(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (client_index > 0 && client_index <= MAXPLAYERS)
		canDeployShield[client_index] = true;
	deployTimers[client_index] = INVALID_HANDLE;
	return Plugin_Handled;
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

/**
* Reset timers related to the player.
*
* @param client_index        Index of the client.
*/
public void ResetPlayerTimers(int client_index)
{
	if (deployTimers[client_index] != INVALID_HANDLE)
		CloseHandle(deployTimers[client_index]);
	if (stateTimers[client_index] != INVALID_HANDLE)
		CloseHandle(stateTimers[client_index]);
	
	deployTimers[client_index] = INVALID_HANDLE;
	stateTimers[client_index] = INVALID_HANDLE
}

/**
* Create a prop_physics at the position of the shield, and deletes the shield.
*
* @param client_index        Index of the client.
*/
public void DropShield(int client_index, bool isThrowing)
{
	float pos[3], rot[3], vel[3];
	AcceptEntityInput(shields[client_index], "SetParent");
	GetEntPropVector(shields[client_index], Prop_Send, "m_vecOrigin", pos);
	GetEntPropVector(shields[client_index], Prop_Send, "m_angRotation", rot);
	DeleteShield(client_index, false);
	int shield = CreateEntityByName("prop_physics_override");
	if (IsValidEntity(shield)) {
		if (useCustomModel && !StrEqual(customShieldModel, "", false))
			SetEntityModel(shield, customShieldModel);
		else
			SetEntityModel(shield, defaultShieldModel);
		DispatchKeyValue(shield, "solid", "6");
		SetEntProp(shield, Prop_Data, "m_CollisionGroup", 1);
		DispatchSpawn(shield);
		ActivateEntity(shield);
		
		if (isThrowing)
		{
			float ang[3];
			GetClientEyeAngles(client_index, ang);
			GetAngleVectors(ang, vel, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(vel, 200.0);
			vel[2] += 200;
		}
		
		TeleportEntity(shield, pos, rot, vel);
		droppedShields.Push(shield);
	}
}

/**
* Try to pick up a shield from the ground if the player doesn't have any.
*
* @param client_index        Index of the client.
*/
public void TryPickupShield(int client_index)
{
	int target = GetClientAimTarget(client_index, false);
	if (droppedShields == INVALID_HANDLE || droppedShields.Length == 0)
		return;
	int shieldIndex = droppedShields.FindValue(target);
	
	if (shieldIndex != -1)
	{
		int shield = droppedShields.Get(shieldIndex);
		float shieldPos[3], playerPos[3];
		GetEntPropVector(shield, Prop_Send, "m_vecOrigin", shieldPos);
		GetClientEyePosition(client_index, playerPos);
		if (GetVectorDistance(shieldPos, playerPos) > 150.0)
			return;
		
		if (hasShield[client_index])
		{
			PrintHintText(client_index, "You already have a shield");
			return;
		}
		PickupShield(client_index, shieldIndex);
	}
}

/**
* Create a shield for the specified player, removing the shield on the ground.
*
* @param client_index		Index of the client.
* @param state				Index of the shield in the shields list.
*/
public void PickupShield(int client_index, int shieldIndex)
{
	PrintHintText(client_index, "You picked up a shield");
	int shield = droppedShields.Get(shieldIndex);
	RemoveEdict(shield);
	droppedShields.Erase(shieldIndex);
	CreateShield(client_index);
}

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
		return shields[client_index] > 0 && shieldState[client_index] != SHIELD_BACK;
}

/**
* Hide shield only from player holding it.
*
* @param			Index of the hooked entity.
* @param			Index of the client seeing the entity.
*/
public Action Hook_SetTransmitShield(int entity_index, int client_index)
{
	if (client_index >0 && client_index <= MAXPLAYERS && shields[client_index] == entity_index && shieldState[client_index] == SHIELD_BACK)
		return Plugin_Handled;
	
	return Plugin_Continue;
}