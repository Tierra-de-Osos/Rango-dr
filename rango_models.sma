// PARA HACER COMENTARIOS LO HACERN ASI

// COMNETARIO

/*
   COMENTARIO
   COMENTARIO
   VARIAS LINEAS
*/


/*
LOS INCLUDES son archivos .inc que se encuentra
cstrike\addons\amxmodx\scripting\include
sirve para compilar nada mas no hace falta subirlo al servidor archivo .inc
*/

#include <amxmodx>      // lo trae por defaul amx
#include <hamsandwich>  // lo trae por defaul amx
#include <fakemeta>     // lo trae por defaul amx
#include <cstrike>      // lo trae por defaul amx
#include <adv_vault>    // este lo descargan de aca https://amxmodx-es.com/Thread-API-Advanced-Vault-System-1-5-12-06-2015

#define PLUGIN "Rango+Models" // nombre del plugins en este caso va a ser Rango+Models
#define VERSION "1.0" // Esto se modifica si haces alguna mejora del plugins le das una vercion mejorada EJEMPLO #define VERSION "1.1"
#define AUTHOR "Tierra de Osos" // Nombre del autor usamos para la comunidad Tierra de Osos

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

// NOMBRE DE RANGO Y FRAG NESESARIO PARA SUBIR DE RANGO

new const Rangos[][inf_rgn] =
{
	{ "Rancio", 	1},
	{ "John Wayne", 	1},
	{ "Clint Eastwood", 	1},
	{ "Michael Myers", 	1},
	{ "Nairobi", 	1},
	{ "Berlin", 	1},
	{ "Scarface", 	1},
	{ "Charles Manson", 	1}
}

// Nombre del los Models que te da cuando subis de Rango

new const g_szmodels_rangos[][] =
{
					
	"zp_nemesis",	// Rancio
	"zp_survivor",  // Bueno
	"zp_wesker",    // Semi Pro
	"zp_sniper"     // Pro
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

/*
 plugin_precache Esto hace que se descargen los models

 linia 81 "models/player/%s/%s.mdl" donde colocamos los model lo podemos cambiar la carpeta
 "models/Tierra_de_Osos/%s/%s.mdl" dentro de la carpeta tierra de osos, ponemos los models
*/

public plugin_precache( )
{
	new i, playermodel[100]
	formatex(playermodel, sizeof playermodel - 1, "models/player/%s/%s.mdl", g_szmodels_rangos[i], g_szmodels_rangos[i])
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR) // llama a la funcin linia 24 25 26
	RegisterHam( Ham_Killed, "player", "Ham_PlayerKilled", 1 )
	RegisterHam( Ham_Spawn, "player", "Ham_SpawnPost", .Post = true ) // lamamos a la funcion linia 167
	Hud = CreateHudSyncObj() // para que se muestre mensaje hud mas grande que el default
	g_vault = adv_vault_open("Rangos", false),
	g_campos[C_RANGO] = adv_vault_register_field(g_vault, "RANGO"), // guardar rango
	g_campos[C_FRAGS] = adv_vault_register_field(g_vault, "FRAGS"), // guardar frag
	adv_vault_init(g_vault)
}

public client_putinserver(id) // se lo voy a enseñar cuando ya esten mas orientado a la ora de programar
{
	set_task(1.0, "ShowHud", id+TASK_SHOWHUD, _, _, "b");
	get_user_name(id, g_cuenta[id], 31)
	Cargar(id)
}

public client_disconnect(id) 
{
	remove_task(id+TASK_SHOWHUD) // destruimos el guardado ¿porque destruir? porque si se desconecta el player no tire error 
	Guardar(id)
}

public Ham_PlayerKilled(victim, attacker) // cuando se conecta player vemos los rango linia 129
{
	if (victim == attacker)
	return;
	
	g_frags[attacker]++
	check_rango(attacker)
}

public check_rango(id) // vemos que rango tiene para despues setiar models
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

public Ham_SpawnPost(id) // aca creo que setiamos el model al player "se lo damos"
{
	if(is_user_alive(id))
	{
		cs_set_user_model(id, g_szmodels_rangos[g_rangos[id]])
	}
}
    	
public Cargar(id) // cargan los frag y rango #include <adv_vault> 
{
	if(!adv_vault_get_prepare(g_vault, _, g_cuenta[id])) return;
	g_rangos[id] = adv_vault_get_field(g_vault, g_campos[C_RANGO]);
	g_frags[id] = adv_vault_get_field(g_vault, g_campos[C_FRAGS]);
}

public Guardar(id)  // Guardan los frag y rango con #include <adv_vault> 
{
	if(!is_user_connected(id)) return;
	adv_vault_set_start(g_vault);
	adv_vault_set_field(g_vault, g_campos[C_RANGO], g_rangos[id]);
	adv_vault_set_field(g_vault, g_campos[C_FRAGS], g_frags[id]);
	adv_vault_set_end(g_vault, 0, g_cuenta[id])
}