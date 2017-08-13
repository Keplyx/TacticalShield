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

ConVar cvar_welcome_message = null;

ConVar cvar_price = null;

public void CreateConVars(char[] version)
{
	CreateConVar("tacticalshield_version", version, "Tactical Shield", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvar_welcome_message = CreateConVar("ts_welcomemessage", "1", "Displays a welcome message to new players. 0 = no message, 1 = display message", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_price = CreateConVar("ts_price", "100", "Shield price.", FCVAR_NOTIFY, true, 0.0, true, 50000.0);
	AutoExecConfig(true, "tacticalshield");
}

public void IntiCvars()
{
	
}



public void RegisterCommands()
{
	RegConsoleCmd("ts_buy", BuyShield, "Buy the tactical shield");
	RegConsoleCmd("ts_deploy", DeployShield, "Deploy the tactical shield");
	RegConsoleCmd("ts_remove", RemoveShield, "Remove the tactical shield");
}