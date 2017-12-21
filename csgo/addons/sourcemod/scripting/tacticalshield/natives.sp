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

public void RegisterNatives()
{
	CreateNative("GivePlayerShield", Native_GivePlayerShield);
	CreateNative("OverridePlayerShield", Native_OverridePlayerShield);
	CreateNative("RemovePlayerShield", Native_RemovePlayerShield);
	CreateNative("DestroyPlayerShield", Native_DestroyPlayerShield);
	CreateNative("EquipPlayerShield", Native_EquipPlayerShield);
	CreateNative("UnequipPlayerShield", Native_UnequipPlayerShield);
	CreateNative("HidePlayerShield", Native_HidePlayerShield);
	CreateNative("UnhidePlayerShield", Native_UnhidePlayerShield);
}

/************************************************************************************************************
 *											NATIVES
 ************************************************************************************************************/

public int Native_GivePlayerShield(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	GetShield(client_index, true);
}

public int Native_OverridePlayerShield(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	int status = GetNativeCell(2);
	OverrideShield(client_index, status);
}

public int Native_RemovePlayerShield(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	DeleteShield(client_index, false);
}

public int Native_DestroyPlayerShield(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	DestroyShield(client_index);
}

public int Native_EquipPlayerShield(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	EquipShield(client_index);
}

public int Native_UnequipPlayerShield(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	UnequipShield(client_index);
}

public int Native_HidePlayerShield(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	HideShield(client_index);
}

public int Native_UnhidePlayerShield(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	UnhideShield(client_index);
}