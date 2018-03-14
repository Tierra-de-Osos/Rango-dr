#include <amxmodx>

#define PLUGIN			"Advanced Vault System"
#define VERSION			"1.5"
#define AUTHOR			"Destro"

/*
 Comentar para remover las funciones que no uses.
(Tienes que modificar el .inc para que quede igual)
*/
#define COMPILE_FIND
#define COMPILE_SORT
#define COMPILE_SIMPLE


#define _valid_vault(%1,%2) if(!valid_vault(%1, %2)) return 0;


const MAX_VAULT			= 10
#if defined COMPILE_SORT
const MAX_SORT			= 10
const MAX_SORT_FIELDS		= 5
#endif
#if defined COMPILE_FIND
const MAX_FIND_FIELDS		= 5
#endif
const MAX_DATALEN		= 1024
const MAX_FIELD_VALUE_LEN	= 256
const MAX_FIELD_NAME_LEN	= 16
const MAX_KEY_NAME_LEN		= 64
const MAX_VAULT_NAME_LEN	= 32
const MAX_INTEGER_LEN		= 12

new const __autoincrement[]	= "__autoincrement"
new const __fields[]		= "__fields"
new const _temp_vault[]		= "_temp_file.dat"

enum {
	STATUS_NONE=0,
	STATUS_OPENING,
	STATUS_READY
}

enum {
	DATATYPE_INT=0,
	DATATYPE_STRING,
	DATATYPE_ARRAY
}

#if defined COMPILE_SORT
enum {
	ORDER_DESC=0,
	ORDER_ASC
}
#endif

enum {
	SIZE_DATA=0,
	SIZE_INDEX,
	SIZE_SIMPLEDATA,
}

enum (<<= 1) {
	CLEAR_ALL=1,
	CLEAR_DATA,
	CLEAR_INDEX,
	#if defined COMPILE_SIMPLE
	CLEAR_SIMPLEDATA,
	#endif
}

#if defined COMPILE_FIND
enum (<<= 1) {
	FINDFLAGS_EQUAL=1,
	FINDFLAGS_CONTAIN,
	FINDFLAGS_CASE_SENSITIVE,
	FINDFLAGS_LESS,
	FINDFLAGS_GREATER,
	FINDFLAGS_NOT,
	FINDFLAGS_AND,
	FINDFLAGS_OR
}
#endif

enum _:_VAULT_FIELDS
{
	Array:_F_NAME=0,
	Array:_F_INDEX,
	Array:_F_TYPE,
	Array:_F_VALUE,
	Array:_F_LENGTH,
	Array:_F_UPDATE
}
new Array:g_vault_fields[MAX_VAULT][_VAULT_FIELDS]
new Trie:g_vault_index[MAX_VAULT]

#if defined COMPILE_SORT
enum _:_SORT_DATA
{
	SORT_FILEDIR[96],
	SORT_REFRESH_TIME,
	SORT_LAST_REFRESH,
	SORT_ORDER,
	SORT_MAXLIMIT,
	SORT_NUMRESULT,
	SORT_FIELDS[MAX_SORT_FIELDS],
	SORT_FIELD_COUNT
}
new g_vault_sort[MAX_VAULT][MAX_SORT][_SORT_DATA]
new Array:sort_index, Array:sort_values, sort_order, sort_fiels
#endif

#if defined COMPILE_FIND
enum _:_FIND_DATA
{
	FIND_FOPEN,
	FIND_FIELDSCOUNT,
	FIND_FLAGS[MAX_FIND_FIELDS],
	FIND_FIELD[MAX_FIND_FIELDS],
	FIND_DATATYPE[MAX_FIND_FIELDS],
	FIND_DATA[MAX_FIND_FIELDS],
}
new g_vault_find[MAX_VAULT][_FIND_DATA]
#endif

enum _:_VAULT_INFO
{
	VAULT_NAME[MAX_VAULT_NAME_LEN],
	VAULT_DIR_FIELD[96],
	VAULT_DIR_DATA[96],
	VAULT_DIR_INDEX[96],
	#if defined COMPILE_SIMPLE
	VAULT_DIR_DATA2[96],
	#endif
	VAULT_AUTO_INCREMENT,
	VAULT_FIELD_INCREMENT,
	VAULT_FIELD_COUNT,
	VAULT_CACHE_INDEX,
	#if defined COMPILE_SORT
	VAULT_SORT_COUNT,
	#endif
	VAULT_STATUS
}
new g_vault_info[MAX_VAULT][_VAULT_INFO]

new g_vault_count
#if defined COMPILE_SORT
new g_fwAutoUpdate
#endif
new g_fwClosing, g_fwInit, g_fwDummyResult

new amxx_datadir[64]

public plugin_precache()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	get_localinfo("amxx_datadir", amxx_datadir, charsmax(amxx_datadir))
	
	register_cvar("adv_vault", PLUGIN, FCVAR_SERVER|FCVAR_SPONLY)
	set_cvar_string("adv_vault", PLUGIN)
	
	#if defined COMPILE_SORT
	g_fwAutoUpdate = CreateMultiForward("fw_adv_vault_sort_update", ET_IGNORE, FP_CELL, FP_CELL)
	#endif
	g_fwClosing = CreateMultiForward("fw_adv_vault_closed", ET_IGNORE, FP_CELL)
	g_fwInit = CreateMultiForward("fw_adv_vault_init", ET_IGNORE, FP_CELL, FP_STRING)
}

public plugin_natives()
{
	register_native("adv_vault_is_open", "native_vault_is_open", 1)
	
	register_native("adv_vault_open", "native_vault_open", 1)
	register_native("adv_vault_closed", "native_vault_closed", 1)
	register_native("adv_vault_init", "native_vault_init", 1)
	register_native("adv_vault_clear", "native_vault_clear", 1)
	register_native("adv_vault_size", "native_vault_size", 1)
	
	register_native("adv_vault_register_field", "native_vault_register_field", 1)

	register_native("adv_vault_get_keyindex", "native_vault_get_keyindex", 1)
	register_native("adv_vault_get_keyname", "native_vault_get_keyname", 0)
	register_native("adv_vault_get_prepare", "native_vault_get_prepare", 1)
	register_native("adv_vault_get_field", "native_vault_get_field", 0)
	
	register_native("adv_vault_set_start", "native_vault_set_start", 1)
	register_native("adv_vault_set_field", "native_vault_set_field", 0)
	register_native("adv_vault_set_end", "native_vault_set_end", 1)
	
	register_native("adv_vault_removekey", "native_vault_removekey", 1)

	#if defined COMPILE_FIND
	register_native("adv_vault_find_start", "native_vault_find_start", 0)
	register_native("adv_vault_find_next", "native_vault_find_next", 1)
	register_native("adv_vault_find_closed", "native_vault_find_closed", 1)
	#endif
	
	#if defined COMPILE_SORT
	register_native("adv_vault_sort_create", "native_vault_sort_create", 0)
	register_native("adv_vault_sort_update", "native_vault_sort_update", 1)
	register_native("adv_vault_sort_destroy", "native_vault_sort_destroy", 1)
	register_native("adv_vault_sort_key", "native_vault_sort_key", 1)
	register_native("adv_vault_sort_position", "native_vault_sort_position", 1)
	register_native("adv_vault_sort_numresult", "native_vault_sort_numresult", 1)
	#endif
	
	#if defined COMPILE_SIMPLE
	register_native("adv_vault_simple_set", "native_vault_simple_set", 0)
	register_native("adv_vault_simple_get", "native_vault_simple_get", 1)
	register_native("adv_vault_simple_removekey", "native_vault_simple_removekey", 1)
	#endif
}

public plugin_end()
{
	for(new vault; vault < MAX_VAULT; vault++)
		vault_closed(vault)
}

public native_vault_is_open(const vaultname[])
{
	param_convert(1)
	
	for(new vault; vault < MAX_VAULT; vault++)
	{
		if(g_vault_info[vault][VAULT_STATUS] == STATUS_NONE)
			continue
		
		if(equal(vaultname, g_vault_info[vault][VAULT_NAME]))
			return vault+1
	}
	
	return 0
}

public native_vault_open(const vaultname[], cache_index)
{
	if(g_vault_count == MAX_VAULT)
	{
		log_error(AMX_ERR_NATIVE, "ERROR MAX_VAULT %d", MAX_VAULT)
		return 0
	}
	
	new vault
	while(g_vault_info[vault][VAULT_STATUS] != STATUS_NONE) vault++
	
	param_convert(1)
	
	if(!valid_filename(vaultname, g_vault_info[vault][VAULT_NAME], 31))
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid VaultName")
		return 0
	}
	
	new dir[96]
	formatex(dir, 95, "%s/adv_vault/", amxx_datadir)
	if(!dir_exists(dir)) mkdir(dir)
	
	formatex(dir, 95, "%s/adv_vault/%s", amxx_datadir, g_vault_info[vault][VAULT_NAME])
	if(!dir_exists(dir)) mkdir(dir)
	
	formatex(g_vault_info[vault][VAULT_DIR_DATA], 95, "%s/data.dat", dir)
	check_file(g_vault_info[vault][VAULT_DIR_DATA])
	
	#if defined COMPILE_SIMPLE
	formatex(g_vault_info[vault][VAULT_DIR_DATA2], 95, "%s/simple.dat", dir)
	check_file(g_vault_info[vault][VAULT_DIR_DATA2])
	#endif
	
	formatex(g_vault_info[vault][VAULT_DIR_INDEX], 95, "%s/index.dat", dir)
	check_file(g_vault_info[vault][VAULT_DIR_INDEX])
	
	formatex(g_vault_info[vault][VAULT_DIR_FIELD], 95, "%s/fields.dat", dir)
	check_file(g_vault_info[vault][VAULT_DIR_FIELD])
	
	g_vault_info[vault][VAULT_CACHE_INDEX] = cache_index
	g_vault_info[vault][VAULT_STATUS] = STATUS_OPENING
	g_vault_info[vault][VAULT_AUTO_INCREMENT] = 1
	g_vault_info[vault][VAULT_FIELD_INCREMENT] = 1
	g_vault_info[vault][VAULT_FIELD_COUNT] = 0
	
	#if defined COMPILE_SORT
	g_vault_info[vault][VAULT_SORT_COUNT] = 0
	#endif
	
	new str_number[MAX_INTEGER_LEN]
	if(vault_simple_get(g_vault_info[vault][VAULT_DIR_FIELD], __autoincrement, str_number, charsmax(str_number)))
		g_vault_info[vault][VAULT_AUTO_INCREMENT] = str_to_num(str_number)
		
	if(vault_simple_get(g_vault_info[vault][VAULT_DIR_FIELD], __fields, str_number, charsmax(str_number)))
		g_vault_info[vault][VAULT_FIELD_INCREMENT] = str_to_num(str_number)
	
	if(cache_index) vault_loadindex(vault)

	g_vault_fields[vault][_F_NAME] = ArrayCreate(MAX_FIELD_NAME_LEN, 1)
	g_vault_fields[vault][_F_INDEX] = ArrayCreate(1, 1)
	g_vault_fields[vault][_F_TYPE] = ArrayCreate(1, 1)
	g_vault_fields[vault][_F_VALUE] = ArrayCreate(1, 1)
	g_vault_fields[vault][_F_LENGTH] = ArrayCreate(1, 1)
	g_vault_fields[vault][_F_UPDATE] = ArrayCreate(1, 1)
	
	g_vault_count++
	
	return vault+1
}

public native_vault_closed(vault)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	vault_closed(vault)

	return 1
}

public native_vault_init(vault)
{
	vault -= 1
	_valid_vault(vault, STATUS_OPENING)
	
	ExecuteForward(g_fwInit, g_fwDummyResult, vault+1, g_vault_info[vault][VAULT_NAME])
	
	g_vault_info[vault][VAULT_STATUS] = STATUS_READY
	
	new field[MAX_FIELD_NAME_LEN], str_index[MAX_INTEGER_LEN]
	
	for(new i; i < g_vault_info[vault][VAULT_FIELD_COUNT]; i++)
	{
		ArrayGetString(g_vault_fields[vault][_F_NAME], i, field, charsmax(field))
		
		if(vault_simple_get(g_vault_info[vault][VAULT_DIR_FIELD], field, str_index, charsmax(str_index)))
		{
			ArraySetCell(g_vault_fields[vault][_F_INDEX], i, str_to_num(str_index))
		}
		else {
			ArraySetCell(g_vault_fields[vault][_F_INDEX], i, g_vault_info[vault][VAULT_FIELD_INCREMENT])
			vault_simple_set(g_vault_info[vault][VAULT_DIR_FIELD], field, "%d", g_vault_info[vault][VAULT_FIELD_INCREMENT])
			g_vault_info[vault][VAULT_FIELD_INCREMENT]++
		}
	}
	
	vault_simple_set(g_vault_info[vault][VAULT_DIR_FIELD], __fields, "%d", g_vault_info[vault][VAULT_FIELD_INCREMENT])
	
	return 1
}

public native_vault_clear(vault, flags)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	if(flags&CLEAR_ALL || flags&CLEAR_DATA)
	{
		clear_file(g_vault_info[vault][VAULT_DIR_DATA])
	}
	
	if(flags&CLEAR_ALL || flags&CLEAR_INDEX)
	{
		clear_file(g_vault_info[vault][VAULT_DIR_INDEX])
		
		if(g_vault_info[vault][VAULT_CACHE_INDEX])
			TrieDestroy(g_vault_index[vault])
	}
	
	#if defined COMPILE_SIMPLE
	if(flags&CLEAR_ALL || flags&CLEAR_SIMPLEDATA)
	{
		clear_file(g_vault_info[vault][VAULT_DIR_DATA2])
	}
	#endif
	
	return 1
}

public native_vault_size(vault, type)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	new linedata[3], size, file
	
	if(type == SIZE_DATA) file = fopen(g_vault_info[vault][VAULT_DIR_DATA], "rt")
	else if(type == SIZE_INDEX) file = fopen(g_vault_info[vault][VAULT_DIR_INDEX], "rt")
	#if defined COMPILE_SIMPLE
	else file = fopen(g_vault_info[vault][VAULT_DIR_DATA2], "rt")
	#else
	else return 0
	#endif

	while(!feof(file))
	{
		fgets(file, linedata, 2)
		if(linedata[0] != '^5') continue
		
		size++
	}
	fclose(file)
	
	return size
}

public native_vault_register_field(vault, const fieldname[], type, length)
{
	vault -= 1
	_valid_vault(vault, STATUS_OPENING)
	
	param_convert(2)
	
	if(g_vault_info[vault][VAULT_FIELD_COUNT])
	{
		new field[MAX_FIELD_NAME_LEN]
		for(new i; i < g_vault_info[vault][VAULT_FIELD_COUNT]; i++)
		{
			ArrayGetString(g_vault_fields[vault][_F_NAME], i, field, charsmax(field))
			
			if(equal(field, fieldname)) return i+1
		}
	}

	ArrayPushString(g_vault_fields[vault][_F_NAME], fieldname)
	ArrayPushCell(g_vault_fields[vault][_F_INDEX], 0)
	ArrayPushCell(g_vault_fields[vault][_F_TYPE], type)
	ArrayPushCell(g_vault_fields[vault][_F_LENGTH], length)
	
	if(type == DATATYPE_INT)
		ArrayPushCell(g_vault_fields[vault][_F_VALUE], 0)
	else
	{
		new Array:arrayvalue = ArrayCreate(length, 1)
		
		if(type == DATATYPE_STRING)
			ArrayPushString(arrayvalue, "")
		else if(type == DATATYPE_ARRAY)
			ArrayPushArray(arrayvalue, {0})
		ArrayPushCell(g_vault_fields[vault][_F_VALUE], _:arrayvalue)
	}
	
	ArrayPushCell(g_vault_fields[vault][_F_UPDATE], 0)

	return ++g_vault_info[vault][VAULT_FIELD_COUNT]
}

public native_vault_get_keyindex(vault, const keyname[])
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	param_convert(2)
	
	return vault_getindex(vault, keyname)
}

public native_vault_get_keyname(iPlugin, iParams) // (vault, keyindex, output[], len)
{
	new vault = get_param(1)-1
	_valid_vault(vault, STATUS_READY)
	
	new keyname[MAX_KEY_NAME_LEN], result
	result = vault_get_keyname(vault, get_param(2), keyname, charsmax(keyname))
	
	set_string(3, keyname, get_param(4))
	
	return result
}

public native_vault_get_prepare(vault, keyindex, const keyname[])
{	
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	param_convert(3)
	
	new fix_keyname[64]
	copy(fix_keyname, 63, keyname)
	
	if(fix_keyname[0]) keyindex = vault_getindex(vault, fix_keyname)
	
	if(!keyindex)
	{
		return 0
	}
	
	static vaultdata[MAX_DATALEN]
	
	if(!vault_get_dataindex(vault, keyindex, vaultdata, charsmax(vaultdata)))
	{
		return 0
	}
	
	parse_fields(vault, vaultdata, false)

	return 1
}

public native_vault_get_field(iPlugin, iParams) // (vault, field, output[], len)
{
	new vault = get_param(1)-1
	_valid_vault(vault, STATUS_READY)
	
	new field = get_param(2)-1
	if(!(0 <= field < g_vault_info[vault][VAULT_FIELD_COUNT]))
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid Field %d", field+1)
		return 0
	}

	new type = ArrayGetCell(g_vault_fields[vault][_F_TYPE], field)
		
	if(type == DATATYPE_INT)
		return ArrayGetCell(g_vault_fields[vault][_F_VALUE], field)
	
	new Array:arrayvalue = Array:ArrayGetCell(g_vault_fields[vault][_F_VALUE], field)
	
	new temp[MAX_FIELD_VALUE_LEN]
	
	if(type == DATATYPE_STRING)
	{
		ArrayGetString(arrayvalue, 0, temp, charsmax(temp))
		set_string(3, temp, get_param(4))
	}
	else if(type == DATATYPE_ARRAY)
	{
		ArrayGetArray(arrayvalue, 0, temp)
		set_array(3, temp, get_param(4))
	}

	return 1
}

public native_vault_set_start(vault)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	for(new field;  field < g_vault_info[vault][VAULT_FIELD_COUNT]; field++)
	{
		ArraySetCell(g_vault_fields[vault][_F_UPDATE], field, 0)
	}
	
	return 1
}

public native_vault_set_field(iPlugin, iParams)
{
	new vault = get_param(1)-1
	_valid_vault(vault, STATUS_READY)
	
	new field = get_param(2)-1
	if(!(0 <= field <  g_vault_info[vault][VAULT_FIELD_COUNT]))
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid Field %d", field+1)
		return 0
	}

	ArraySetCell(g_vault_fields[vault][_F_UPDATE], field, 1)
	
	new type = ArrayGetCell(g_vault_fields[vault][_F_TYPE], field)
		
	if(type == DATATYPE_INT)
	{
		ArraySetCell(g_vault_fields[vault][_F_VALUE], field, get_param_byref(3))
		return 1
	}
	
	new temp[MAX_FIELD_VALUE_LEN]
	new Array:arrayvalue = Array:ArrayGetCell(g_vault_fields[vault][_F_VALUE], field)
	
	if(type == DATATYPE_STRING)
	{
		vdformat(temp, charsmax(temp), 3, 4)
		ArraySetString(arrayvalue, 0, temp)
	}
	else if(type == DATATYPE_ARRAY)
	{
		get_array(3, temp, charsmax(temp))
		ArraySetArray(arrayvalue, 0, temp)
	}

	return 1
}

public native_vault_set_end(vault, keyindex, const keyname[])
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	param_convert(3)
	
	new fix_keyname[64]
	copy(fix_keyname, 63, keyname)
	
	if(fix_keyname[0])
	{
		keyindex = vault_getindex(vault, fix_keyname)
		if(!keyindex)
		{
			keyindex = g_vault_info[vault][VAULT_AUTO_INCREMENT]++
			vault_simple_set(g_vault_info[vault][VAULT_DIR_FIELD], __autoincrement, "%d", g_vault_info[vault][VAULT_AUTO_INCREMENT])
			
			if(g_vault_info[vault][VAULT_CACHE_INDEX])
				TrieSetCell(g_vault_index[vault], fix_keyname, keyindex)
			
			vault_simple_set(g_vault_info[vault][VAULT_DIR_INDEX], fix_keyname, "%d", keyindex)
		}
	}
	else if(!keyindex)
	{
		keyindex = g_vault_info[vault][VAULT_AUTO_INCREMENT]++
		vault_simple_set(g_vault_info[vault][VAULT_DIR_FIELD], __autoincrement, "%d", g_vault_info[vault][VAULT_AUTO_INCREMENT])
	}
	
	vault_set_dataindex(vault, keyindex, false)
	
	return keyindex
}

public native_vault_removekey(vault, keyindex, const keyname[])
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	param_convert(3)
	
	new fix_keyname[64]
	copy(fix_keyname, 63, keyname)
	
	if(fix_keyname[0])
	{
		keyindex = vault_getindex(vault, fix_keyname)

		if(g_vault_info[vault][VAULT_CACHE_INDEX])
			TrieDeleteKey(g_vault_index[vault], fix_keyname)
			
		vault_simple_removekey(g_vault_info[vault][VAULT_DIR_INDEX], fix_keyname)
	}

	if(!keyindex) return 0
	
	vault_set_dataindex(vault, keyindex, true)

	return 1
}

#if defined COMPILE_FIND
public native_vault_find_start(iPlugin, iParams) // (vault, any:.. (field, value, flags))
{
	new any_params = iParams-1
	
	if(any_params % 3)
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid number of parameters")
		return 0
	}
	
	any_params /= 3
	
	if(any_params > MAX_FIND_FIELDS)
	{
		log_error(AMX_ERR_NATIVE, "ERROR Max find fields: %d", MAX_FIND_FIELDS)
		return 0
	}
	
	new vault = get_param(1)-1
	_valid_vault(vault, STATUS_READY)
	
	if(g_vault_find[vault][FIND_FOPEN])
	{
		log_error(AMX_ERR_NATIVE, "ERROR Another search in progress")
		return 0
	}
	
	new temp[MAX_FIELD_VALUE_LEN], param = 1
	
	for(new fields; fields < any_params; fields++)
	{
		g_vault_find[vault][FIND_FIELD][fields] = get_param_byref(++param)-1
		if(!(0 <= g_vault_find[vault][FIND_FIELD][fields] <  g_vault_info[vault][VAULT_FIELD_COUNT]))
		{
			log_error(AMX_ERR_NATIVE, "ERROR Invalid Field %d", g_vault_find[vault][FIND_FIELD][fields]+1)
			return 0
		}

		g_vault_find[vault][FIND_DATATYPE][fields] = ArrayGetCell(g_vault_fields[vault][_F_TYPE], g_vault_find[vault][FIND_FIELD][fields])
		if(g_vault_find[vault][FIND_DATATYPE][fields] == DATATYPE_ARRAY)
		{
			log_error(AMX_ERR_NATIVE, "ERROR Invalid field data type (only allowed DATATYPE_INT and DATATYPE_STRING)")
			return 0
		}
		
		if(g_vault_find[vault][FIND_DATATYPE][fields] == DATATYPE_INT)
			g_vault_find[vault][FIND_DATA][fields] = get_param_byref(++param)
		else {
			get_string(++param, temp, charsmax(temp))
			
			g_vault_find[vault][FIND_DATA][fields] = _:ArrayCreate(ArrayGetCell(g_vault_fields[vault][_F_LENGTH], g_vault_find[vault][FIND_FIELD][fields]), 1)
			
			ArrayPushString(Array:g_vault_find[vault][FIND_DATA][fields], temp)
		}
		
		g_vault_find[vault][FIND_FLAGS][fields] = get_param_byref(++param)
	}

	g_vault_find[vault][FIND_FOPEN] = fopen(g_vault_info[vault][VAULT_DIR_DATA], "rt")
	if(!g_vault_find[vault][FIND_FOPEN]) g_vault_find[vault][FIND_FOPEN] = -1
	
	g_vault_find[vault][FIND_FIELDSCOUNT] = any_params
	
	return 1
}

public native_vault_find_next(vault)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	if(!g_vault_find[vault][FIND_FOPEN])
	{
		log_error(AMX_ERR_NATIVE, "ERROR There is no search in progress")
		return 0
	}
	
	if(g_vault_find[vault][FIND_FOPEN] == -1) return 0
	
	static linedata[MAX_DATALEN], keyindex, values[2][MAX_FIELD_VALUE_LEN], field, found, flags, result

	while(!feof(g_vault_find[vault][FIND_FOPEN]))
	{
		fgets(g_vault_find[vault][FIND_FOPEN], linedata, charsmax(linedata))
		
		if(linedata[0] != '^5') continue

		keyindex = parse_linedata(linedata, 0, linedata, charsmax(linedata))
		if(!keyindex) continue
			
		parse_fields(vault, linedata, false)
		
		found = true

		for(field=0; field < g_vault_find[vault][FIND_FIELDSCOUNT]; field++)
		{
			flags = g_vault_find[vault][FIND_FLAGS][field]
			
			if(g_vault_find[vault][FIND_DATATYPE][field] == DATATYPE_INT)
			{
				values[0][0] = ArrayGetCell(g_vault_fields[vault][_F_VALUE], g_vault_find[vault][FIND_FIELD][field])
				
				if(((flags&FINDFLAGS_EQUAL && flags&FINDFLAGS_NOT) && g_vault_find[vault][FIND_DATA][field] != values[0][0])
				|| ((flags&FINDFLAGS_EQUAL && !(flags&FINDFLAGS_NOT)) && g_vault_find[vault][FIND_DATA][field] == values[0][0])
				|| (flags&FINDFLAGS_LESS && g_vault_find[vault][FIND_DATA][field] > values[0][0])
				|| (flags&FINDFLAGS_GREATER && g_vault_find[vault][FIND_DATA][field] > values[0][0]))
				{
					if(field && g_vault_find[vault][FIND_FLAGS][field-1]&FINDFLAGS_OR) found=true
					continue
				}

				if(field && !(g_vault_find[vault][FIND_FLAGS][field-1]&FINDFLAGS_OR)) found=false
				else if(!field) found=false
			}
			else {
				ArrayGetString(Array:ArrayGetCell(g_vault_fields[vault][_F_VALUE], g_vault_find[vault][FIND_FIELD][field]), 0, values[0], charsmax(values[]))
				ArrayGetString(Array:g_vault_find[vault][FIND_DATA][field], 0, values[1], charsmax(values[]))
				
				if(flags&FINDFLAGS_CONTAIN)
				{
					if(flags&FINDFLAGS_CASE_SENSITIVE)
						result = (containi(values[0], values[1]) != -1)
					else result = (contain(values[0], values[1]) != -1)
				}
				else
				{
					if(flags&FINDFLAGS_CASE_SENSITIVE)
						result = equali(values[0], values[1])
					else result = equal(values[0], values[1])
				}
				
				if((flags&FINDFLAGS_NOT && !result) || result)
				{
					if(field && g_vault_find[vault][FIND_FLAGS][field-1]&FINDFLAGS_OR) found=true
					continue
				}

				if(field && !(g_vault_find[vault][FIND_FLAGS][field-1]&FINDFLAGS_OR)) found=false
				else if(!field) found=false
			}
		}
		
		if(found) return keyindex
	}

	return 0
}

public native_vault_find_closed(vault)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	if(!g_vault_find[vault][FIND_FOPEN])
	{
		log_error(AMX_ERR_NATIVE, "ERROR There is no search in progress")
		return 0
	}
	
	fclose(g_vault_find[vault][FIND_FOPEN])
	g_vault_find[vault][FIND_FOPEN] = 0
	
	for(new field; field < g_vault_find[vault][FIND_FIELDSCOUNT]; field++)
	{
		if(g_vault_find[vault][FIND_DATATYPE][field] != DATATYPE_INT)
			ArrayDestroy(Array:g_vault_find[vault][FIND_DATA][field])
	}
	
	return 1
}
#endif

#if defined COMPILE_SORT
public native_vault_sort_create(iPlugin, iParams) // (vault, order, refresh, maxlimit, fields:..)
{
	if(iParams < 5)
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid number of parameters")
		return 0
	}
	
	new vault = get_param(1)-1
	_valid_vault(vault, STATUS_READY)
	
	if(g_vault_info[vault][VAULT_SORT_COUNT] == MAX_SORT)
	{
		log_error(AMX_ERR_NATIVE, "ERROR MAX_SORT %d", MAX_SORT)
		return 0
	}
	
	new fields = iParams-4
	if(fields > MAX_SORT_FIELDS)
	{
		log_error(AMX_ERR_NATIVE, "ERROR MAX_SORT_FIELDS %d", MAX_SORT_FIELDS)
		return 0
	}
	
	new sort
	while(g_vault_sort[vault][sort][SORT_LAST_REFRESH]) sort++
	
	new field
	for(new i; i < fields; i++)
	{
		field = get_param_byref(i+5)-1
		
		if(!(0 <= field <  g_vault_info[vault][VAULT_FIELD_COUNT]))
		{
			log_error(AMX_ERR_NATIVE, "ERROR Invalid Field %d", field+1)
			return 0
		}
	
		if(ArrayGetCell(g_vault_fields[vault][_F_TYPE], field) != DATATYPE_INT)
		{
			log_error(AMX_ERR_NATIVE, "ERROR Invalid field data type (only allowed DATATYPE_INT)")
			return 0
		}

		g_vault_sort[vault][sort][SORT_FIELDS][i] = field
	}
	
	g_vault_info[vault][VAULT_SORT_COUNT]++
	g_vault_sort[vault][sort][SORT_ORDER] = get_param(2)
	g_vault_sort[vault][sort][SORT_REFRESH_TIME] = get_param(3)
	g_vault_sort[vault][sort][SORT_MAXLIMIT] = get_param(4)
	g_vault_sort[vault][sort][SORT_FIELD_COUNT] = fields
	
	formatex(g_vault_sort[vault][sort][SORT_FILEDIR], 95, "%s/adv_vault/%s/sort_%d.dat", amxx_datadir, g_vault_info[vault][VAULT_NAME], sort)
	
	vault_sorting(vault, sort)
	
	return sort+1
}

public native_vault_sort_update(vault, sort)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	sort -= 1
	if(!(0 <= sort < MAX_SORT) || !g_vault_sort[vault][sort][SORT_LAST_REFRESH])
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid SortIndex: %d", sort+1)
		return 0
	}
	
	return vault_sorting(vault, sort)
}

public native_vault_sort_destroy(vault, sort)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	sort -= 1
	if(!(0 <= sort < MAX_SORT) || !g_vault_sort[vault][sort][SORT_LAST_REFRESH])
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid SortIndex: %d", sort+1)
		return 0
	}
	
	g_vault_sort[vault][sort][SORT_LAST_REFRESH] = 0
	g_vault_info[vault][VAULT_SORT_COUNT]--
	delete_file(g_vault_sort[vault][sort][SORT_FILEDIR])
	
	return 1
}


public native_vault_sort_key(vault, sort, keyindex, const keyname[])
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	sort -= 1
	if(!(0 <= sort < MAX_SORT) || !g_vault_sort[vault][sort][SORT_LAST_REFRESH])
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid SortIndex: %d", sort+1)
		return 0
	}
	
	vault_sort_checktime(vault, sort)
	
	param_convert(4)
	new fix_keyname[64]
	copy(fix_keyname, 63, keyname)
	
	if(fix_keyname[0]) keyindex = vault_getindex(vault, fix_keyname)
	
	if(!keyindex) return 0
	
	num_to_str(keyindex, fix_keyname, 63)
	
	return vault_simple_get(g_vault_sort[vault][sort][SORT_FILEDIR], fix_keyname, fix_keyname, 2)
}

public native_vault_sort_position(vault, sort, position)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	sort -= 1
	if(!(0 <= sort < MAX_SORT) || !g_vault_sort[vault][sort][SORT_LAST_REFRESH])
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid SortIndex: %d", sort+1)
		return 0
	}
	
	vault_sort_checktime(vault, sort)
	
	if(!(0 < position <= g_vault_sort[vault][sort][SORT_NUMRESULT]))
		return 0
	
	new str_keyindex[MAX_INTEGER_LEN]
	vault_simple_get(g_vault_sort[vault][sort][SORT_FILEDIR], "", str_keyindex, charsmax(str_keyindex), position)
	
	return str_to_num(str_keyindex)
}

public native_vault_sort_numresult(vault, sort)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	sort -= 1
	if(!(0 <= sort < MAX_SORT) || !g_vault_sort[vault][sort][SORT_LAST_REFRESH])
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid SortIndex: %d", sort+1)
		return 0
	}
	
	vault_sort_checktime(vault, sort)
	
	return g_vault_sort[vault][sort][SORT_NUMRESULT]
}
#endif

#if defined COMPILE_SIMPLE
public native_vault_simple_get(vault, const key[], output[], len)
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	param_convert(3)
	
	return vault_simple_get(g_vault_info[vault][VAULT_DIR_DATA2], key, output, len)
}

public native_vault_simple_set(iPlugin, iParams) // (vault, const key[], const data[], any:...)
{
	new vault = get_param(1)-1
	_valid_vault(vault, STATUS_READY)
	
	new key[MAX_KEY_NAME_LEN], data[MAX_DATALEN]
	
	get_string(2, key, charsmax(key))
	vdformat(data, charsmax(data), 3, 4)
	
	vault_simple_set(g_vault_info[vault][VAULT_DIR_DATA2], key, data)

	return 1
}

public native_vault_simple_removekey(vault, const key[])
{
	vault -= 1
	_valid_vault(vault, STATUS_READY)
	
	param_convert(2)
	vault_simple_removekey(g_vault_info[vault][VAULT_DIR_DATA2], key)

	return 1
}
#endif

#if defined COMPILE_SORT
vault_sorting(vault, sort)
{
	new i, keyindex, values[MAX_SORT_FIELDS]
	
	sort_index = ArrayCreate(1, 1)
	sort_values = ArrayCreate(MAX_SORT_FIELDS, 1)
	
	new file = fopen(g_vault_info[vault][VAULT_DIR_DATA], "rt")
	new _linedata[MAX_DATALEN]
	
	while(!feof(file))
	{
		fgets(file, _linedata, charsmax(_linedata))
		
		if(_linedata[0] != '^5') continue

		keyindex = parse_linedata(_linedata, 0, _linedata, charsmax(_linedata))
		if(!keyindex) continue
		
		parse_fields(vault, _linedata, false)
		
		for(i=0; i < g_vault_sort[vault][sort][SORT_FIELD_COUNT]; i++)
			values[i] = ArrayGetCell(g_vault_fields[vault][_F_VALUE], g_vault_sort[vault][sort][SORT_FIELDS][i])

		ArrayPushArray(sort_values, values)
		ArrayPushCell(sort_index, keyindex)
	}
	
	fclose(file)

	new arraysize = ArraySize(sort_index)
	
	if(arraysize)
	{
		sort_fiels = g_vault_sort[vault][sort][SORT_FIELD_COUNT]
		sort_order = g_vault_sort[vault][sort][SORT_ORDER]
		
		_qs(0, arraysize-1)
	
		if(g_vault_sort[vault][sort][SORT_MAXLIMIT] && g_vault_sort[vault][sort][SORT_MAXLIMIT] < arraysize)
			arraysize = g_vault_sort[vault][sort][SORT_MAXLIMIT]

		file = fopen(g_vault_sort[vault][sort][SORT_FILEDIR], "w")
		for(i=0; i < arraysize; i++)
		{
			fprintf(file, "^5^3%d^4^3%d^4^n", ArrayGetCell(sort_index, i), i+1)
		}

		fclose(file)
	}

	ArrayDestroy(sort_index)
	ArrayDestroy(sort_values)	
		
	g_vault_sort[vault][sort][SORT_LAST_REFRESH] = get_systime()
	g_vault_sort[vault][sort][SORT_NUMRESULT] = arraysize

	return arraysize
}

_qs(limite_izq, limite_der)
{
	static der, pivote, values[MAX_SORT_FIELDS]
	new izq // fix recursive

	izq =limite_izq
	der = limite_der
	pivote = (izq+der)/2

	ArrayGetArray(sort_values, pivote, values)
				
	while(izq <= der)
	{
		while(_qs_compare(values, izq) < 0) izq++
		while(_qs_compare(values, der) > 0) der--
		
		if(izq <=der)
		{
			_qs_swap(izq, der)
			izq++
			der--
		}

	}

	if(limite_izq < der) _qs(limite_izq, der)
	if(limite_der > izq) _qs(izq, limite_der)
}

_qs_compare(valuesA[], item)
{
	static i, valuesB[MAX_SORT_FIELDS]
	ArrayGetArray(sort_values, item, valuesB)
	
	for(i=0; i < sort_fiels; i++)
	{
		if(sort_order == ORDER_DESC)
		{
			if(valuesB[i] < valuesA[i]) return 1
			if(valuesB[i] > valuesA[i]) return -1
		}
		
		if(sort_order == ORDER_ASC)
		{
			if(valuesB[i] > valuesA[i]) return 1
			if(valuesB[i] < valuesA[i]) return -1
		}
	}

	return 0
}

_qs_swap(item1, item2)
{
	ArraySwap(sort_index, item1, item2)
	ArraySwap(sort_values, item1, item2)
}

vault_sort_checktime(vault, sort)
{
	if(!g_vault_sort[vault][sort][SORT_REFRESH_TIME]) return
	
	if((get_systime() - g_vault_sort[vault][sort][SORT_LAST_REFRESH]) < g_vault_sort[vault][sort][SORT_REFRESH_TIME]) return
	
	vault_sorting(vault, sort)
	
	ExecuteForward(g_fwAutoUpdate, g_fwDummyResult, vault, sort)
}
#endif

vault_closed(vault)
{
	if(g_vault_info[vault][VAULT_STATUS] == STATUS_NONE)
		return
	
	ExecuteForward(g_fwClosing, g_fwDummyResult, vault)
	
	vault_simple_set(g_vault_info[vault][VAULT_DIR_FIELD], __autoincrement, "%d", g_vault_info[vault][VAULT_AUTO_INCREMENT])
	
	if(g_vault_info[vault][VAULT_CACHE_INDEX])
		TrieDestroy(g_vault_index[vault])
	
	ArrayDestroy(g_vault_fields[vault][_F_NAME])
	ArrayDestroy(g_vault_fields[vault][_F_INDEX])
	
	new Array:arrayvalue
	for(new field; field < g_vault_info[vault][VAULT_FIELD_COUNT]; field++)
	{
		if(ArrayGetCell(g_vault_fields[vault][_F_TYPE], field) != DATATYPE_INT)
		{
			arrayvalue = Array:ArrayGetCell(g_vault_fields[vault][_F_VALUE], field)
			ArrayDestroy(arrayvalue)
		}
	}
	
	ArrayDestroy(g_vault_fields[vault][_F_LENGTH])
	ArrayDestroy(g_vault_fields[vault][_F_TYPE])
	
	#if defined COMPILE_SORT
	for(new sort; sort < MAX_SORT; sort++)
	{
		if(g_vault_sort[vault][sort][SORT_LAST_REFRESH])
		{
			delete_file(g_vault_sort[vault][sort][SORT_FILEDIR])
			g_vault_sort[vault][sort][SORT_LAST_REFRESH] = 0
		}
	}
	#endif

	g_vault_info[vault][VAULT_STATUS] = STATUS_NONE
	g_vault_count--
}

vault_getindex(vault, const keyname[])
{
	if(g_vault_info[vault][VAULT_CACHE_INDEX])
	{
		new index
		if(!TrieGetCell(g_vault_index[vault], keyname, index)) return 0

		return index
	}
	
	new str_index[MAX_INTEGER_LEN]
	if(vault_simple_get(g_vault_info[vault][VAULT_DIR_INDEX], keyname, str_index, 11))
		return str_to_num(str_index)
		
	return 0
}

vault_get_dataindex(vault, keyindex, data[], len)
{
	new file = fopen(g_vault_info[vault][VAULT_DIR_DATA], "rt")
	if(!file)
	{
		copy(data, len, "")
		return 0
	}
	
	new _linedata[MAX_DATALEN], _keyindex
	
	while(!feof(file))
	{
		fgets(file, _linedata, charsmax(_linedata))
		
		if(_linedata[0] != '^5') continue

		_keyindex = parse_linedata(_linedata, keyindex, data, len)
		
		if(_keyindex == 0) continue
		if(_keyindex == -1) break
			
		if(_keyindex == keyindex)
		{
			fclose(file)
			return 1
		}
	}
	
	fclose(file)
	copy(data, len, "")
	return 0
}

vault_set_dataindex(vault, keyindex, deletekey=false)
{
	new filevault = fopen(g_vault_info[vault][VAULT_DIR_DATA], "rt")
	if(!filevault) return
	
	new file = fopen(_temp_vault, "wt")
	
	static _linedata[MAX_DATALEN], _vaultdata[MAX_DATALEN]
	new _keyindex, bool:replaced
	
	while(!feof(filevault))
	{
		fgets(filevault, _linedata, charsmax(_linedata))
		
		if(_linedata[0] != '^5') continue
		
		if(!replaced)
		{
			_keyindex = parse_linedata(_linedata, keyindex, _vaultdata, charsmax(_vaultdata))
		
			if(!deletekey && _keyindex == -1)
			{
				build_fields(vault, _vaultdata, charsmax(_vaultdata))
					
				fprintf(file, "^5^3%d^4^3%s^4^n", keyindex, _vaultdata)
				fputs(file, _linedata)
				
				replaced = true
			}
			else if(_keyindex == keyindex) 
			{
				if(!deletekey)
				{
					parse_fields(vault, _vaultdata, true)
					build_fields(vault, _vaultdata, charsmax(_vaultdata))
					
					fprintf(file, "^5^3%d^4^3%s^4^n", keyindex, _vaultdata)
				}
				replaced = true
			}
			else fputs(file, _linedata)
		}
		else fputs(file, _linedata)
	}
	
	fclose(file)
	fclose(filevault)
	
	if(!replaced && !deletekey)
	{
		build_fields(vault, _vaultdata, charsmax(_vaultdata))
		
		file = fopen(g_vault_info[vault][VAULT_DIR_DATA], "a+")
		fprintf(file, "^5^3%d^4^3%s^4^n", keyindex, _vaultdata)
		fclose(file)

		delete_file(_temp_vault)
		return
	}

	delete_file(g_vault_info[vault][VAULT_DIR_DATA])
	while(!rename_file(_temp_vault, g_vault_info[vault][VAULT_DIR_DATA], 1)) { }
}

parse_linedata(const linedata[], keyindex, vaultdata[], len)
{
	new i, _start, _len, _status, _index, str_number[MAX_INTEGER_LEN]
	while(linedata[i])
	{
		if(_status == 0 && linedata[i] == '^3')
		{
			_status++
			_start = i+1
		}
		else if(_status == 1 && linedata[i] == '^4')
		{
			_status++
			
			_len = i-_start
			
			copy(str_number, _len, linedata[_start])
			
			_index = str_to_num(str_number)
			
			if(keyindex)
			{
				if(_index > keyindex) return -1
				if(_index != keyindex) return 0
			}
		}
		else if(_status == 2 && linedata[i] == '^3')
		{
			_status++
			_start = i+1
		}
		else if(_status == 3 && linedata[i] == '^4')
		{
			_len = i-_start
			if(len < _len)
			{
				log_error(AMX_ERR_GENERAL, "ERROR parse_linedata(...) big data")
				return 0
				
			}
			
			copy(vaultdata, _len, linedata[_start])
			return _index
		}
		i++
	}
	
	return 0
}

parse_fields(vault, const vaultdata[], skip_in_update=false)
{
	static str_fieldindex[MAX_INTEGER_LEN], tempdata[MAX_FIELD_VALUE_LEN], temparray[MAX_FIELD_VALUE_LEN]
	new i, start, len, isdata, fieldindex, field
	
	while(vaultdata[i])
	{
		if(vaultdata[i] == '^6')
		{
			if(isdata)
			{
				field = find_field_arrayslot(vault, fieldindex)
				
				if(field != -1 && (!skip_in_update || (skip_in_update && !ArrayGetCell(g_vault_fields[vault][_F_UPDATE], field))))
				{
					len = i-start
					copy(tempdata, len, vaultdata[start])

					new type = ArrayGetCell(g_vault_fields[vault][_F_TYPE], field)
		
					if(type == DATATYPE_INT)
					{
						ArraySetCell(g_vault_fields[vault][_F_VALUE], field, str_to_num(tempdata))
					}
					else {
						new Array:arrayvalue = Array:ArrayGetCell(g_vault_fields[vault][_F_VALUE], field)
	
						if(type == DATATYPE_STRING)
							ArraySetString(arrayvalue, 0, tempdata)
						else if(type == DATATYPE_ARRAY)
						{
							str_to_arraynum(tempdata, temparray, ArrayGetCell(g_vault_fields[vault][_F_LENGTH], field))
							ArraySetArray(arrayvalue, 0, temparray)
						}
					}
				}
			}
			else {
				len = i-start
				copy(str_fieldindex, len, vaultdata[start])
				fieldindex = str_to_num(str_fieldindex)
			}
			
			isdata = !isdata
			start = i+1
		}
		i++
	}
}

build_fields(vault, data[], maxlen)
{
	static tempdata[MAX_FIELD_VALUE_LEN], temparray[MAX_FIELD_VALUE_LEN]
	new fieldindex, len, type, Array:arrayvalue
	
	for(new field; field < g_vault_info[vault][VAULT_FIELD_COUNT]; field++)
	{
		fieldindex = ArrayGetCell(g_vault_fields[vault][_F_INDEX], field)
		
		type = ArrayGetCell(g_vault_fields[vault][_F_TYPE], field)
		
		if(type == DATATYPE_INT)
		{
			len += formatex(data[len], maxlen-len, "%d^6%d^6", fieldindex,
			ArrayGetCell(g_vault_fields[vault][_F_VALUE], field))
			continue
		}

		arrayvalue = Array:ArrayGetCell(g_vault_fields[vault][_F_VALUE], field)
	
		if(type == DATATYPE_STRING)
			ArrayGetString(arrayvalue, 0, tempdata, charsmax(tempdata))
		else if(type == DATATYPE_ARRAY)
		{
			ArrayGetArray(arrayvalue, 0, temparray)
			arraynum_to_str(temparray, ArrayGetCell(g_vault_fields[vault][_F_LENGTH], field), tempdata, charsmax(tempdata), true)
		}
				
		len += formatex(data[len], maxlen-len, "%d^6%s^6", fieldindex, tempdata)
	}
}

find_field_arrayslot(vault, fieldindex)
{
	for(new field; field < g_vault_info[vault][VAULT_FIELD_COUNT]; field++)
	{
		if(ArrayGetCell(g_vault_fields[vault][_F_INDEX], field) == fieldindex)
			return field
	}
	return -1
}

vault_loadindex(vault)
{
	g_vault_index[vault] = TrieCreate()
		
	new file = fopen(g_vault_info[vault][VAULT_DIR_INDEX], "rt")
	if(!file) return
	
	new linedata[MAX_KEY_NAME_LEN+MAX_INTEGER_LEN+6]
	new keyname[MAX_KEY_NAME_LEN], str_keyindex[MAX_INTEGER_LEN]
	while(!feof(file))
	{
		fgets(file, linedata, charsmax(linedata))
		
		if(!parse_two(linedata, keyname, charsmax(keyname), str_keyindex, charsmax(str_keyindex)))
			continue
		
		TrieSetCell(g_vault_index[vault], keyname, str_to_num(str_keyindex))
	}
	
	fclose(file)
}

vault_get_keyname(vault, keyindex, output[], len)
{
	new file = fopen(g_vault_info[vault][VAULT_DIR_INDEX], "rt")
	if(!file) return 0
	
	new linedata[MAX_KEY_NAME_LEN+MAX_INTEGER_LEN+6]
	new keyname[MAX_KEY_NAME_LEN], str_keyindex[MAX_INTEGER_LEN]
	while(!feof(file))
	{
		fgets(file, linedata, charsmax(linedata))
		
		if(!parse_two(linedata, keyname, charsmax(keyname), str_keyindex, charsmax(str_keyindex)))
			continue
		
		if(str_to_num(str_keyindex) == keyindex)
		{
			copy(output, len, keyname)
			fclose(file)
			return 1
		}
	}
	
	copy(output, len, "")
	fclose(file)
	return 0
}

valid_filename(const filename[], output[], len)
{
	static const invalid_chars[][] = { "/", "\", "*", ":", "?", "^"", "<", ">", "|" }
	
	new temp[32]
	copy(temp, charsmax(temp), filename)
	
	for(new i = 0; i < sizeof invalid_chars; i++)
	{
		replace_all(temp, charsmax(temp), invalid_chars[i], "")
	}
	
	copy(output, len, temp)
	
	return temp[0]
}

vault_simple_get(const filename[], const key[], data[], len, line=0)
{
	new vault = fopen(filename, "rt")
	if(!vault)
	{
		copy(data, len, "")
		return 0
	}
	
	new linedata[MAX_DATALEN], _key[MAX_KEY_NAME_LEN], _line
	
	while(!feof(vault))
	{
		fgets(vault, linedata, charsmax(linedata))
		
		if(linedata[0] != '^5') continue
		
		parse_two(linedata, _key, charsmax(_key), linedata, charsmax(linedata))
		_line++
		
		if((!line && equal(_key, key)) || (line && line == _line))
		{
			if(line) copy(data, len, _key)
			else copy(data, len, linedata)
			
			fclose(vault)
			return _line
		}
	}
	fclose(vault)
	copy(data, len, "")
	return 0
}

vault_simple_set(const filename[], const key[], const data[], any:...)
{
	new vault = fopen(filename, "rt")
	
	if(!vault) return
	
	static _data[MAX_DATALEN]
	
	if(numargs() == 3)
		copy(_data, charsmax(_data), data)
	else vformat(_data, charsmax(_data), data, 4)
		
	new file = fopen(_temp_vault, "wt")
	new linedata[MAX_DATALEN], _key[MAX_KEY_NAME_LEN], _other[3]
	
	new bool:replaced = false
	
	while(!feof(vault))
	{
		fgets(vault, linedata, charsmax(linedata))
		
		if(linedata[0] != '^5') continue

		if(!parse_two(linedata, _key, charsmax(_key), _other, charsmax(_other)))
			continue
		
		if(!replaced && equal(_key, key))
		{
			fprintf(file, "^5^3%s^4^3%s^4^n", key, _data)
			replaced = true
		}
		else fputs(file, linedata)
	}
	fclose(file)
	fclose(vault)
	
	if(!replaced)
	{
		file = fopen(filename, "a+")
		fprintf(file, "^5^3%s^4^3%s^4^n", key, _data)
		fclose(file)
		delete_file(_temp_vault)
	}
	else
	{
		delete_file(filename)
		while(!rename_file(_temp_vault, filename, 1)) { }
	}
}

vault_simple_removekey(const filename[], const key[])
{
	new file = fopen(_temp_vault, "wt")
	new vault = fopen(filename, "rt")
	
	new linedata[MAX_DATALEN], _key[MAX_KEY_NAME_LEN], _other[3]
	
	new bool:replaced = false
	
	while(!feof(vault))
	{
		fgets(vault, linedata, charsmax(linedata))
		
		if(linedata[0] != '^5') continue

		if(!parse_two(linedata, _key, charsmax(_key), _other, charsmax(_other)))
			continue
		
		if(!replaced && equal(_key, key))
		{
			replaced = true
			continue
		}
		else fputs(file, linedata)
	}
	fclose(file)
	fclose(vault)
	
	if(!replaced)
	{
		delete_file(_temp_vault)
		return
	}
	
	delete_file(filename)
	while(!rename_file(_temp_vault, filename, 1)) { }
}

parse_two(const linedata[], key[], maxlen, data[], maxlen2)
{
	new i, _start, _len, _status
	while(linedata[i])
	{
		if(_status == 0 && linedata[i] == '^3')
		{
			_status++
			_start = i+1
		}
		else if(_status == 1 && linedata[i] == '^4')
		{
			_status++
			_len = i-_start
			if(_len > maxlen) _len = maxlen
			
			copy(key, _len, linedata[_start])
		}
		else if(_status == 2 && linedata[i] == '^3')
		{
			_status++
			_start = i+1
		}
		else if(_status == 3 && linedata[i] == '^4')
		{
			_len = i-_start
			if(_len > maxlen2) _len = maxlen2
			
			copy(data, _len, linedata[_start])
			return 1
		}
		i++
	}
	
	return 0
}

arraynum_to_str(array[], arraysize, output[], len, trim_end)
{
	new i, _len

	do {
		_len += formatex(output[_len], len-_len, "%d ", array[i])
	} while(++i < arraysize && _len < len)
	
	if(i < arraysize) log_error(AMX_ERR_GENERAL, "ERROR arraynum_to_str(...) big data")
	
	if(trim_end) output[_len-1] = '^0'
	
	return _len
}

str_to_arraynum(strnum[], array_out[], array_size)
{
	new len, j, k, c, temp[MAX_INTEGER_LEN]
	
	while(strnum[len])
	{
		if(strnum[len] == ' ')
		{
			array_out[j++] = str_to_num(temp)

			for(c = 0; c < k; c++) temp[c] = 0
			k = 0
		}
		if(j >= array_size) return len

		temp[k++] = strnum[len++]
	}

	array_out[j++] = str_to_num(temp)
	while(j < array_size) array_out[j++] = 0
	
	return len
}


valid_vault(vault, status)
{
	if(!(0 <= vault < MAX_VAULT) || g_vault_info[vault][VAULT_STATUS] != status)
	{
		log_error(AMX_ERR_NATIVE, "ERROR Invalid VaultIndex: %d", vault+1)
		return 0
	}
	return 1
}

clear_file(file[])
{
	new f = fopen(file, "w")
	if(!f) return 0
	fclose(f)
	return 1
}

check_file(file[])
{
	if(!file_exists(file))
	{
		clear_file(file)
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ froman\\ fcharset0 Times New Roman;}}\n{\\ colortbl ;\\ red0\\ green0\\ blue0;}\n\\ viewkind4\\ uc1\\ pard\\ cf1\\ lang11274\\ f0\\ fs24 \n\\ par }
*/
