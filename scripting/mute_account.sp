/**
 * Sourcemod 1.7 Plugin Template
 */
#pragma semicolon 1
#include <sourcemod>

#include <regex>
#include <basecomm>

#pragma newdecls required

#define PLUGIN_VERSION "0.0.3"
public Plugin myinfo = {
	name = "Mute Player By Account",
	author = "nosoop",
	description = "Allows players to be muted by their Steam account ID.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-MuteAccount"
}

Database g_Database;

DBStatement g_AddMuteQuery;

bool g_bClientMuted[MAXPLAYERS + 1];

public void OnPluginStart() {
	char error[256];
	
	g_Database = SQL_Connect("muted_accounts", true, error, sizeof(error));
	
	if (!g_Database) {
		SetFailState("Could not connect to muted_accounts database: %s", error);
	}
	
	g_AddMuteQuery = SQL_PrepareQuery(g_Database,
			"INSERT INTO mutelist (account, end_time, reason, admin_account) VALUES (?, ?, ?, ?);",
			error, sizeof(error));
	
	if (!g_AddMuteQuery) {
		SetFailState("Could not create prepared statement g_AddMuteQuery: %s", error);
	}
	
	RegAdminCmd("sm_muteid", AdminCmd_MuteID, ADMFLAG_ROOT);
}

public void OnPluginEnd() {
	delete g_AddMuteQuery;
}

public void OnClientConnected(int client) {
	g_bClientMuted[client] = false;
}

public void OnClientAuthorized(int client) {
	int account = GetSteamAccountID(client);
	
	// note: unsafe on and after 19 January 2038
	char query[1024];
	Format(query, sizeof(query),
			"SELECT account FROM mutelist WHERE account = %d AND end_time > %d OR end_time = 0",
			account, GetTime());
	
	g_Database.Query(OnQueriedClientMute, query, GetClientUserId(client));
}

public void OnQueriedClientMute(Database database, DBResultSet results, const char[] error,
		int userid) {
	int client = GetClientOfUserId(userid);
	
	if (client && results && results.RowCount > 0) {
		g_bClientMuted[client] = true;
		
		if (IsClientInGame(client)) {
			OnClientPutInServer(client);
		}
	}
}

public void OnClientPutInServer(int client) {
	if (g_bClientMuted[client]) {
		BaseComm_SetClientMute(client, true);
		LogAction(0, client, "Muted \"%L\" for an unfinished mute punishment.", client);
	}
}

public Action AdminCmd_MuteID(int client, int argc) {
	if (argc < 2) {
		char command[64];
		GetCmdArg(0, command, sizeof(command));
		ReplyToCommand(client, "Usage: %s <time> <steamid> [reason]", command);
		return Plugin_Handled;
	}
	
	// implemented from basebans.sp
	char time[50], authid[50], arg_string[256];
	
	GetCmdArgString(arg_string, sizeof(arg_string));
	
	int len, total_len;
	
	/* get time */
	if ((len = BreakString(arg_string, time, sizeof(time))) == -1) {
		char command[64];
		GetCmdArg(0, command, sizeof(command));
		ReplyToCommand(client, "Usage: %s <time> <steamid> [reason]", command);
		return Plugin_Handled;
	}
	total_len += len;
	
	if ((len = BreakString(arg_string[total_len], authid, sizeof(authid))) != -1) {
		total_len += len;
	} else {
		total_len = 0;
		arg_string[0] = '\0';
	}
	
	int account;
	if (!strncmp(authid, "STEAM_", 6) && authid[7] == ':') {
		account = GetAccountIDFromAuthID(authid, AuthId_Steam2);
	} else if (!strncmp(authid, "[U:", 3)) {
		account = GetAccountIDFromAuthID(authid, AuthId_Steam3);
	}
	
	if (account) {
		int nMinutes = StringToInt(time);
		MuteByAccountID(account, nMinutes, arg_string[total_len], client);
		
		LogAction(client, -1, "\"%L\" added mute (minutes \"%d\") (id \"%s\") (reason \"%s\")",
				client, nMinutes, authid, arg_string[total_len]);
	}
	return Plugin_Handled;
}

void MuteByAccountID(int account, int nMinutes, const char[] reason = "no reason specified",
		int source = 0) {
	if (account) {
		int endTime = nMinutes? (GetTime() + (nMinutes * 60)) : 0;
		int sourceAccount = source? GetSteamAccountID(source) : 0;
		
		g_AddMuteQuery.BindInt(0, account);
		g_AddMuteQuery.BindInt(1, endTime);
		g_AddMuteQuery.BindString(2, reason, false);
		
		g_AddMuteQuery.BindInt(3, sourceAccount);
		
		SQL_Execute(g_AddMuteQuery);
	}
}


stock int GetAccountIDFromAuthID(const char[] auth, AuthIdType authid) {
	static Regex s_Steam2Format, s_Steam3Format;
	
	if (!s_Steam2Format) {
		s_Steam2Format = new Regex("STEAM_\\d:\\d:\\d+");
		s_Steam3Format = new Regex("\\[U:\\d:\\d+\\]");
	}
	
	switch (authid) {
		case AuthId_Steam3: {
			if (!s_Steam3Format.Match(auth)) {
				ThrowError("Input string %s is not a SteamID3-formatted string.", auth);
			}
			int account;
			StringToIntEx(auth[FindCharInString(auth, ':', true) + 1], account);
			return account;
		}
		case AuthId_Steam2: {
			if (!s_Steam2Format.Match(auth)) {
				ThrowError("Input string %s is not a SteamID2-formatted string.", auth);
			}
			
			int y;
			StringToIntEx(auth[FindCharInString(auth, ':', false) + 1], y);
			
			int z = StringToInt(auth[FindCharInString(auth, ':', true) + 1]);
			
			return (2 * z) + y;
		}
	}
	return 0;
}