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


int shields[MAXPLAYERS + 1];
bool hasShield[MAXPLAYERS + 1];
bool isShieldFull[MAXPLAYERS + 1];
bool canChangeState[MAXPLAYERS + 1];

bool useCustomModel = false;

float defaultPos[3] = {20.0, 0.0, 0.0};
float defaultRot[3] = {0.0, 0.0, 0.0};
float defaultMovedPos[3] = {0.0, 30.0, 0.0};
float defaultMovedRot[3] = {0.0, 45.0, 0.0};
float customPos[3];
float customRot[3];
float customMovedPos[3];
float customMovedRot[3];
float shieldCooldown = 1.0;


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
		SetShieldPos(client_index);
		isShieldFull[client_index] = true;
		canChangeState[client_index] = true;
		
		SDKHook(client_index, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
	}
}

/**
* Deletes the shield for the given player.
*
* @param client_index        Index of the client.
*/
public void DeleteShield(int client_index)
{
	SDKUnhook(client_index, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
	if (IsValidEdict(shields[client_index]))
	{
		RemoveEdict(shields[client_index]);
	}
	shields[client_index] = -1;
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
		CreateTimer(shieldCooldown, Timer_ShieldCooldown, ref);
		SetShieldPos(client_index);
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
	DeleteShield(client_index);
}

/**
* Timer to prevent players from changing shield state too quickly.
*/
public Action Timer_ShieldCooldown(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	canChangeState[client_index] = true;
}


