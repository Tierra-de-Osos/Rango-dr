#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <cstrike>
#include <adv_vault>

#define PLUGIN "New Plug-In"
#define VERSION "1.0"
#define AUTHOR "author"

#define HUD_ID (taskid - TASK_HUD)

new g_rangos[33]
new g_frags[33]
new g_vault
new g_cuenta[33][32]
new Hud
enum _:inf_rgn
{
	rgn_name[33],
	rgn_frags,
	rgn_model[100]
}

new const Rangos[][inf_rgn] =
{
	{ "Novato", 	1},
	{ "Bueno", 	5},
	{ "Semi Pro", 	10},
	{ "Pro", 	20}
}

new const g_szmodels_rangos[][] =
{
	//Novato	Bueno		Semi Pro	Pro
	"zp_nemesis", "zp_survivor", "zp_wesker", "zp_sniper"
}

enum 
{
	C_RANGO,
	C_FRAGS,
	C_MAX
}
new g_campos[C_MAX]

enum (+= 100)
{
	TASK_HUD = 2000,
	TASK_SHOWHUD = 2000
}
const PEV_SPEC_TARGET = pev_iuser2

public plugin_precache( )
{
	new i, playermodel[100]
	formatex(playermodel, sizeof playermodel - 1, "models/player/%s/%s.mdl", g_szmodels_rangos[i], g_szmodels_rangos[i])
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	RegisterHam( Ham_Killed, "player", "Ham_PlayerKilled", 1 )
	RegisterHam( Ham_Spawn, "player", "Ham_SpawnPost", .Post = true )
	Hud = CreateHudSyncObj()
	g_vault = adv_vault_open("Rangos", false),
	g_campos[C_RANGO] = adv_vault_register_field(g_vault, "RANGO"),
	g_campos[C_FRAGS] = adv_vault_register_field(g_vault, "FRAGS"),
	adv_vault_init(g_vault)
}

public client_putinserver(id)
{
	set_task(1.0, "ShowHud", id+TASK_SHOWHUD, _, _, "b");
	get_user_name(id, g_cuenta[id], 31)
	Cargar(id)
}

public client_disconnect(id)
{
	remove_task(id+TASK_SHOWHUD)
	Guardar(id)
}

public Ham_PlayerKilled(victim, attacker)
{
	if (victim == attacker)
	return;
	
	g_frags[attacker]++
	check_rango(attacker)
}

public check_rango(id)
{
	if (g_frags[id] >= Rangos[g_rangos[id] + 1][rgn_frags] && g_rangos[id] < 9)
	{ 
		g_rangos[id]++
		cs_set_user_model(id, g_szmodels_rangos[g_rangos[id]])
	}
	return PLUGIN_HANDLED
}

public ShowHud(taskid) 
{
	static id 
	id = HUD_ID     
	static hud[256], len
    
	if (!is_user_alive(id))
	{
		id = pev(id, PEV_SPEC_TARGET)

		if (!is_user_alive(id)) return;
	}
	new CurrentTime[9]
	get_time("%H:%M:%S",CurrentTime,8)
	if (id != HUD_ID)
	{
		len = 0
		len += formatex(hud[len], charsmax(hud) - len, "Nombre : %s^nRango : %s^nFrags %d | %d^nHora : %s", g_cuenta[id], Rangos[g_rangos[id]][rgn_name], g_frags[id], Rangos[g_rangos[id]+1][rgn_frags], CurrentTime) 
		set_hudmessage(random_num(0, 255), random_num(0, 255), random_num(0, 255), 0.00, 0.00, 1, 0.9)       
		ShowSyncHudMsg(HUD_ID, Hud, hud)
	}
	else
	{
		set_hudmessage(random_num(0, 255), random_num(0, 255), random_num(0, 255), 0.00, 0.00, 1, 0.9) 
		ShowSyncHudMsg(HUD_ID, Hud, "Rango : %s^nFrags %d | %d^nHora : %s", Rangos[g_rangos[id]][rgn_name], g_frags[id], Rangos[g_rangos[id]+1][rgn_frags], CurrentTime) 
	}
}

public Ham_SpawnPost(id)
{
	if(is_user_alive(id))
	{
		cs_set_user_model(id, g_szmodels_rangos[g_rangos[id]])
	}
}
    	
public Cargar(id) 
{
	if(!adv_vault_get_prepare(g_vault, _, g_cuenta[id])) return;
	g_rangos[id] = adv_vault_get_field(g_vault, g_campos[C_RANGO]);
	g_frags[id] = adv_vault_get_field(g_vault, g_campos[C_FRAGS]);
}

public Guardar(id) 
{
	if(!is_user_connected(id)) return;
	adv_vault_set_start(g_vault);
	adv_vault_set_field(g_vault, g_campos[C_RANGO], g_rangos[id]);
	adv_vault_set_field(g_vault, g_campos[C_FRAGS], g_frags[id]);
	adv_vault_set_end(g_vault, 0, g_cuenta[id])
}