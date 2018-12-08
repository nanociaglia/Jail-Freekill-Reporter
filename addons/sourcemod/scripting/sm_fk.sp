#pragma semicolon 1
 
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <colors>
 
#pragma newdecls required
 
#define SOUND_START_INDEX 0
#define MAX_FILE_LEN 80
#define MSG "\x01[\x04FK-Report\x01] \x10%t"
#define PLUGIN_VERSION "6.0"
 
char g_sSoundFile[10][MAX_FILE_LEN];
bool g_bUsedCmd[MAXPLAYERS + 1];
bool g_bIsClientKiller[MAXPLAYERS + 1];
bool g_bDieByCT[MAXPLAYERS + 1];
int g_iKillerId[MAXPLAYERS + 1];
int g_iDeathTime[MAXPLAYERS + 1];
ConVar g_cvarSoundFKReport;
ConVar g_cvarPluginEnabled;
ConVar g_cvarCommandForAdm;
ConVar g_cvarPublicMessage;
ConVar g_cvarMaxUses;
ConVar g_cvarReportTime;

int g_iMaxUses[MAXPLAYERS+1];

EngineVersion g_Game;

public Plugin myinfo =
{
	name		= "Freekill Reporter",
	description	= "Report a freekiller.",
	author		= "Nano",
	version		= PLUGIN_VERSION,
	url			= "http://steamcommunity.com/id/marianzet1"
}
 
void PrecacheSounds() 
{
	g_cvarSoundFKReport.GetString(g_sSoundFile[SOUND_START_INDEX], PLATFORM_MAX_PATH);
 
	for (int i = 0; i < sizeof(g_sSoundFile); i++) 
	{
		if (strlen(g_sSoundFile[i]) > 0) 
		{
			char soundAbsolutePath[PLATFORM_MAX_PATH];
			Format(soundAbsolutePath, PLATFORM_MAX_PATH, "sound/%s", g_sSoundFile[i]);
 
			if (FileExists(soundAbsolutePath, true)) 
			{
				Format(g_sSoundFile[i], PLATFORM_MAX_PATH, "*%s", g_sSoundFile[i]);
				AddToStringTable(FindStringTable("soundprecache"), g_sSoundFile[i]);
				AddFileToDownloadsTable(soundAbsolutePath);
			}
			else 
			{
				LogError("%s Sound file (%s) not found", g_sSoundFile[i]);
			}
		}
	}
}
 
public void OnClientConnected(int client) 
{
	g_iMaxUses[client] = 0;
}

public void OnClientDisconnect(int client) 
{
	g_iMaxUses[client] = 0;
} 
 
public void OnPluginStart() 
{
	LoadTranslations("fkreport.phrases");
 
	g_Game = GetEngineVersion();
	if (g_Game != Engine_CSGO && g_Game != Engine_CSS) 
	{
		SetFailState("This plugin is only for CSGO/CSS.");
	}

	RegConsoleCmd("sm_fk", Command_reportfk, "Report a freekill.");
	RegConsoleCmd("sm_freekill", Command_reportfk, "Report a freekill.");
 
	HookEvent("player_death", player_death);
	HookEvent("round_start", round_start);
 
	CreateConVar("sm_fk_version", PLUGIN_VERSION, "Freekill Reporter Version");
 
	g_cvarCommandForAdm = CreateConVar("sm_fk_adminonly", "0", "Only allow admins to use this command? (need ADMFLAG_GENERIC or override sm_fk_admin to use this command) 1: Enable, 0: Disable");
	
	g_cvarPublicMessage = CreateConVar("sm_fk_private", "0", "Display message/report only to admins? (only admins with ADMFLAG_SLAY or override sm_fk_adminmessage will see the reports) 1: Enable, 0: Disable (messages/report will be public)");  
	
	g_cvarSoundFKReport = CreateConVar("sm_fk_sound", "nano/beep2.mp3", "Play a sound when a Terrorist type the command");
	
	g_cvarPluginEnabled = CreateConVar("sm_fk_enable", "1", "1 - Enable the plugin | 0 - Disable the plugin");
	
	g_cvarMaxUses = CreateConVar("sm_fk_limit", "1", "Set here how many times a player can use the command in one round (Default 1)");
	
	g_cvarReportTime = CreateConVar("sm_fk_report_time", "10", "The player can use the command after -X- (10 default) seconds of his death.");
	
	AutoExecConfig(true, "sm_fk_cvars");
}
 
public void OnMapStart() 
{
	AddFileToDownloadsTable("sound/nano/beep2.mp3");
	PrecacheSounds();
}
 
public Action Command_reportfk(int client, int args) 
{
	if (!g_cvarPluginEnabled.BoolValue) 
	{
		PrintToChat(client, MSG, "Disabled" );        
		return Plugin_Handled;
	}
	int maxTime = g_cvarMaxUses.IntValue;
	
	if(g_iMaxUses[client] >= maxTime) 
	{
		PrintToChat(client, MSG, "Max Time", maxTime);
		return Plugin_Continue;
	}   
	if (IsPlayerAlive(client)) 
	{
		PrintToChat(client, MSG, "Dead");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == CS_TEAM_CT) 
	{
		PrintToChat(client, MSG, "Terrorist");
		return Plugin_Handled;
	}
	if (g_cvarCommandForAdm.BoolValue && !CheckCommandAccess(client, "sm_fk_admin", ADMFLAG_GENERIC)) 
	{
		PrintToChat(client, MSG, "Admin Only");
		return Plugin_Handled;
	}
	if ((g_iDeathTime[client] + g_cvarReportTime.IntValue) <= GetTime()) 
	{
		PrintToChat(client, MSG, "Time Expired", g_cvarReportTime.IntValue);
		return Plugin_Continue;
	}	
	if (g_bDieByCT[client]) 
	{
		char nameClient[32];
		GetClientName(client, nameClient, sizeof(nameClient));

		PrintToChat(client, MSG, "Successful");

		char killerName[MAX_NAME_LENGTH];
		GetClientName(g_iKillerId[client], killerName, sizeof(killerName));

		for (int i = 1; i <= MaxClients; i++) 
		{
			if (!IsValidClient(i) || (g_cvarPublicMessage.BoolValue && !CheckCommandAccess(i, "sm_fk_adminmessage", ADMFLAG_SLAY))) 
			{
				continue;
			}
			PrintCenterText(i, "%t", "Report Two", client, killerName);
			CPrintToChat(i, MSG, "Reported", nameClient, killerName);
			EmitSoundToClient(i, g_sSoundFile[SOUND_START_INDEX], _, SNDCHAN_STATIC, _, _, 0.2);
		}
		g_bUsedCmd[client] = true;     
	}
	else 
	{
		PrintToChat(client, MSG, "Killed CT");
	}
	
	g_iMaxUses[client]++;
	return Plugin_Handled;
}
 
public Action player_death(Event event, char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
 
	if (client == attacker) 
	{
		g_bIsClientKiller[client] = true;
	}
 
	if (1 <= attacker <= MaxClients && GetClientTeam(client) == CS_TEAM_T && GetClientTeam(attacker) == CS_TEAM_CT) 
	{
		g_bDieByCT[client] = true;
		g_iDeathTime[client] = GetTime();
	}
 
	g_iKillerId[client] = attacker;
}
public Action round_start(Event event, char[] name, bool dontBroadcast) 
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		g_bUsedCmd[i] = false;
		g_bDieByCT[i] = false;
		g_iMaxUses[i] = 0;
	}
}
 
bool IsValidClient(int client) 
{
	return (0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}