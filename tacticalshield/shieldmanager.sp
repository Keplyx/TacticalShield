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


char shieldModel[] = "models/props/de_inferno/hr_i/ground_stone/ground_stone.mdl";

int shields[MAXPLAYERS + 1];

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
		pos[2] += 50.0;
		TeleportEntity(shield, pos, rot, NULL_VECTOR);
		
		SDKHook(shield, SDKHook_OnTakeDamage, Hook_TakeDamageShield);
	}
}

public void DeleteShield(int client_index)
{
	if (IsValidEdict(shields[client_index]))
	{
		RemoveEdict(shields[client_index]);
	}
}


public Action Hook_TakeDamageShield(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	PrintToChatAll("TOUCHED");
	damage = 0.0;
	return Plugin_Changed;
}
