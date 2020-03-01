#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <shavit>
#include <multicolors>

float g_fChallenge_RequestTime[MAXPLAYERS + 1];
bool g_bChallenge_Abort[MAXPLAYERS + 1];
bool g_bChallenge[MAXPLAYERS + 1];
bool g_bChallenge_Request[MAXPLAYERS + 1];
int g_CountdownTime[MAXPLAYERS + 1];
char g_szChallenge_OpponentID[MAXPLAYERS + 1][32];
char g_szSteamID[MAXPLAYERS + 1][32];
bool gB_Late = false;

public Plugin myinfo = 
{
	name = "Shavit Challenge",
	author = "Evan",
	description = "Challenge plugin",
	version = "0.3"
}

public void OnPluginStart()
{
	LoadTranslations("shavit-challenge.phrases");

	RegConsoleCmd("sm_challenge", Client_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_race", Client_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_accept", Client_Accept, "[Challenge] allows you to accept a challenge request");
	RegConsoleCmd("sm_surrender", Client_Surrender, "[Challenge] surrender your current challenge");
	RegConsoleCmd("sm_abort", Client_Abort, "[Challenge] abort your current challenge");
	
	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;

	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	GetClientAuthId(client, AuthId_Steam2, g_szSteamID[client], MAX_NAME_LENGTH, true);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			g_bChallenge[i] = false;
			g_bChallenge_Request[i] = false;	
		}
	}
}

public Action Client_Challenge(int client, int args)
{
	if (!g_bChallenge[client] && !g_bChallenge_Request[client])
	{
		if (IsPlayerAlive(client))
		{
			CreateTimer(20.0, Timer_Request, GetClientUserId(client));
			char szPlayerName[MAX_NAME_LENGTH];
			Menu menu2 = CreateMenu(ChallengeMenuHandler);
			SetMenuTitle(menu2, "Challenge: Select your Opponent");
			int playerCount = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && IsPlayerAlive(i) && i != client && !IsFakeClient(i))
				{
					GetClientName(i, szPlayerName, MAX_NAME_LENGTH);
					AddMenuItem(menu2, szPlayerName, szPlayerName);
					playerCount++;
				}
			}
			if (playerCount > 0)
			{
				SetMenuOptionFlags(menu2, MENUFLAG_BUTTON_EXIT);
				DisplayMenu(menu2, client, MENU_TIME_FOREVER);
			}
			else
			{
				CPrintToChat(client, "%t", "ChallengeFailed4");
			}
		}
		
		else
		{
			CPrintToChat(client, "%t", "ChallengeFailed2");
		}
	}
	
	return Plugin_Handled;
}

public int ChallengeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		char szPlayerName[MAX_NAME_LENGTH];
		char szTargetName[MAX_NAME_LENGTH];
		GetClientName(param1, szPlayerName, MAX_NAME_LENGTH);
		GetMenuItem(menu, param2, info, sizeof(info));
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && i != param1)
			{
				GetClientName(i, szTargetName, MAX_NAME_LENGTH);

				if (StrEqual(info, szTargetName))
				{
					if (!g_bChallenge[i])
					{
						char szSteamId[32];
						GetClientAuthId(i, AuthId_Steam2, szSteamId, MAX_NAME_LENGTH, true);
						Format(g_szChallenge_OpponentID[param1], 32, szSteamId);
						CPrintToChat(param1, "%t", "Challenge1", szTargetName);
						CPrintToChat(i, "%t", "Challenge2", szPlayerName);
						g_fChallenge_RequestTime[param1] = GetGameTime();
						g_bChallenge_Request[param1] = true;
					}
					
					else
					{
						CPrintToChat(param1, "%t", "ChallengeFailed6", szTargetName);
					}
				}
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action Client_Abort(int client, int args)
{
	if (g_bChallenge[client])
	{
		if (g_bChallenge_Abort[client])
		{
			g_bChallenge_Abort[client] = false;
			CPrintToChat(client, "[{green}Challenge{default}] You have disagreed to abort the challenge.");
		}
		else
		{
			g_bChallenge_Abort[client] = true;
			CPrintToChat(client, "[{green}Challenge{default}] You have agreed to abort the challenge. Waiting for your opponent..");
		}
	}
	
	return Plugin_Handled;
}

public Action Client_Accept(int client, int args)
{
	char szSteamId[32];
	GetClientAuthId(client, AuthId_Steam2, szSteamId, MAX_NAME_LENGTH, true);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && i != client && g_bChallenge_Request[i])
		{
			if (StrEqual(szSteamId, g_szChallenge_OpponentID[i]))
			{
				GetClientAuthId(i, AuthId_Steam2, g_szChallenge_OpponentID[client], MAX_NAME_LENGTH, true);
				g_bChallenge_Request[i] = false;
				
				g_bChallenge[i] = true;
				g_bChallenge[client] = true;
				
				g_bChallenge_Abort[client] = false;
				g_bChallenge_Abort[i] = false;

				Shavit_ChangeClientStyle(client, 0);
				Shavit_ChangeClientStyle(i, 0);
				
				Shavit_RestartTimer(client, Track_Main);
				Shavit_RestartTimer(i, Track_Main);
				
				SetEntityMoveType(client, MOVETYPE_NONE);
				SetEntityMoveType(i, MOVETYPE_NONE);
				
				Shavit_StopTimer(client);
				Shavit_StopTimer(i);
				
				g_CountdownTime[i] = 10;
				g_CountdownTime[client] = 10;
				
				CreateTimer(1.0, Timer_Countdown, i, TIMER_REPEAT);
				CreateTimer(1.0, Timer_Countdown, client, TIMER_REPEAT);
				
				CPrintToChat(client, "%t", "Challenge3");
				CPrintToChat(i, "%t", "Challenge3");
				
				char szPlayer1[MAX_NAME_LENGTH];
				char szPlayer2[MAX_NAME_LENGTH];
				
				GetClientName(i, szPlayer1, MAX_NAME_LENGTH);
				GetClientName(client, szPlayer2, MAX_NAME_LENGTH);

				CPrintToChatAll("[{green}Challenge{default}] Challenge: %s vs. %s", szPlayer1, szPlayer2);
				
				CreateTimer(1.0, CheckChallenge, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				CreateTimer(1.0, CheckChallenge, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	return Plugin_Handled;
}

public Action Client_Surrender(int client, int args)
{
	char szSteamIdOpponent[32];
	char szNameOpponent[MAX_NAME_LENGTH];
	char szName[MAX_NAME_LENGTH];
	if (g_bChallenge[client])
	{
		GetClientName(client, szName, MAX_NAME_LENGTH);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				GetClientAuthId(i, AuthId_Steam2, szSteamIdOpponent, MAX_NAME_LENGTH, true);
				if (StrEqual(szSteamIdOpponent, g_szChallenge_OpponentID[client]))
				{
					GetClientName(i, szNameOpponent, MAX_NAME_LENGTH);
					g_bChallenge[i] = false;
					g_bChallenge[client] = false;

					for (int j = 1; j <= MaxClients; j++)
					{
						if (IsValidClient(j) && IsValidEntity(j))
						{
							CPrintToChat(j, "%t", "Challenge4", szNameOpponent, szName);
						}
					}

					SetEntityMoveType(client, MOVETYPE_WALK);
					SetEntityMoveType(i, MOVETYPE_WALK);
					
					i = MaxClients + 1;
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action Timer_Countdown(Handle timer, any client)
{		
	if (IsValidClient(client) && g_bChallenge[client] && !IsFakeClient(client))
	{
		CPrintToChat(client, "[{green}Countdown{default}] %i", g_CountdownTime[client]);
		g_CountdownTime[client]--;
		
		if (g_CountdownTime[client] < 1)
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
			CPrintToChat(client, "%t", "ChallengeStarted1");
			CPrintToChat(client, "%t", "ChallengeStarted2");
			CPrintToChat(client, "%t", "ChallengeStarted3");
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_Request(Handle timer, any data)
{	
	int client = GetClientOfUserId(data);
	
	if(!g_bChallenge[client])
	{
		CPrintToChat(client, "%t", "ChallengeExpire");
		g_bChallenge_Request[client] = false;
	}
}

public Action CheckChallenge(Handle timer, any client)
{
	bool oppenent = false;
	char szName[32];
	char szNameTarget[32];
	if (g_bChallenge[client] && IsValidClient(client) && !IsFakeClient(client))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				if (StrEqual(g_szSteamID[i], g_szChallenge_OpponentID[client]))
				{
					oppenent = true;
					if (g_bChallenge_Abort[i] && g_bChallenge_Abort[client])
					{
						GetClientName(i, szNameTarget, 32);
						GetClientName(client, szName, 32);
						
						g_bChallenge[client] = false;
						g_bChallenge[i] = false;
						
						CPrintToChat(client, "%t", "ChallengeAborted", szNameTarget);
						CPrintToChat(i, "%t", "ChallengeAborted", szName);
						
						SetEntityMoveType(client, MOVETYPE_WALK);
						SetEntityMoveType(i, MOVETYPE_WALK);
					}
				}
			}
		}
		if (!oppenent)
		{
			g_bChallenge[client] = false;

			if (IsValidClient(client))
			{
				CPrintToChat(client, "%t", "ChallengeWon", client);
			}
			
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public void Shavit_OnFinish(int client)
{
	if(g_bChallenge[client])
	{
		char szNameOpponent[MAX_NAME_LENGTH];
		char szName[MAX_NAME_LENGTH];
		GetClientName(client, szName, MAX_NAME_LENGTH);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				if (StrEqual(g_szSteamID[i], g_szChallenge_OpponentID[client]))
				{
					g_bChallenge[client] = false;
					g_bChallenge[i] = false;
					GetClientName(i, szNameOpponent, MAX_NAME_LENGTH);
					for (int k = 1; k <= MaxClients; k++)
					{
						if (IsValidClient(k))
						{
							CPrintToChat(k, "%t", "ChallengeW", szName, szNameOpponent);
						}
					}
					
					break;
				}
			}
		}
	}
}