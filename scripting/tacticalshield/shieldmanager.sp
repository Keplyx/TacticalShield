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
		DispatchSpawn(shield);
		ActivateEntity(shield);
		
		SetEntityMoveType(shield, MOVETYPE_NONE)
		SetVariantString("!activator"); AcceptEntityInput(shield, "SetParent", client_index, shield, 0);
		SetShieldPos(client_index, true);
		isShieldFull[client_index] = true;
		canChangeState[client_index] = true;
		
		SDKHook(client_index, SDKHook_OnTakeDamage, Hook_TakeDamageShield);
		SDKHook(client_index, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
	}
}

public void DeleteShield(int client_index)
{
	SDKUnhook(client_index, SDKHook_OnTakeDamage, Hook_TakeDamageShield);
	SDKUnhook(client_index, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
	if (IsValidEdict(shields[client_index]))
	{
		RemoveEdict(shields[client_index]);
	}
	shields[client_index] = -1;
}

public void ToggleShieldState(int client_index)
{
	if (canChangeState[client_index])
	{
		SetShieldPos(client_index, !isShieldFull[client_index]);
		isShieldFull[client_index] = !isShieldFull[client_index];
		canChangeState[client_index] = false;
		int ref = EntIndexToEntRef(client_index);
		CreateTimer(shieldCooldown, Timer_ShieldCooldown, ref);
	}
}

public void SetShieldPos(int client_index, bool isFull)
{
	float pos[3], rot[3];
	for (int i = 0; i < 3; i++)
	{
		if (!isFull)
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

public void Hook_WeaponSwitch(int client_index, int weapon_index)
{
	DeleteShield(client_index);
}

public Action Timer_ShieldCooldown(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	canChangeState[client_index] = true;
}

public Action Hook_TakeDamageShield(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker < 1 || attacker > MAXPLAYERS)
		return Plugin_Continue;
	float attackerPos[3];
	GetClientEyePosition(attacker, attackerPos);
	
	Handle trace = TR_TraceRayFilterEx(attackerPos, damagePosition, MASK_SHOT, RayType_EndPoint, TraceFilterShield, shields[victim]);
	if(trace != INVALID_HANDLE && TR_DidHit(trace))
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public bool TraceFilterShield(int entity_index, int mask, any data)
{
	return entity_index == data;
} 