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


char shieldModel[] = "models/props/de_overpass/overpass_metal_door03.mdl";

int shields[MAXPLAYERS + 1];
bool hasShield[MAXPLAYERS + 1];


public void CreateShield(int client_index)
{
	int shield = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(shield)) {
		shields[client_index] = shield;
		SetEntityModel(shield, shieldModel);
		DispatchKeyValue(shield, "solid", "6");
		SetEntProp(shield, Prop_Data, "m_CollisionGroup", 1); // Stop collisions with players / world
		DispatchSpawn(shield);
		ActivateEntity(shield);
		
		SetEntityMoveType(shield, MOVETYPE_NONE)
		SetVariantString("!activator"); AcceptEntityInput(shield, "SetParent", client_index, shield, 0);
		float pos[3], rot[3];
		pos[0] += 20.0;
		TeleportEntity(shield, pos, rot, NULL_VECTOR);
		
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

public void SetShieldPos(int client_index, bool isShooting)
{
	float rot[3];
	if (isShooting)
		rot[2] = 90.0;
	TeleportEntity(shields[client_index], NULL_VECTOR, rot, NULL_VECTOR);
}

public void Hook_WeaponSwitch(int client_index, int weapon_index)
{
	DeleteShield(client_index);
}

public Action Hook_TakeDamageShield(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
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