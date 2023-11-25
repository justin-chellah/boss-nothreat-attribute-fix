#include <sourcemod>

#define REQUIRE_EXTENSIONS
#include <dhooks>

#define GAMEDATA_FILE	"boss_nothreat_attribute_fix"

// This is global since we have to patch it only once UpdateVersusBossSpawning is called
DynamicDetour g_hDDetour_TerrorNavArea_IsValidForWanderingPopulation = null;
int TerrorNavArea_m_spawnAttributeFlags = -1;

// https://developer.valvesoftware.com/wiki/Navigation_Meshes_(L4D)
enum TerrorNavSpawnAttributeType
{
    // L4D/2
    SPAWN_INVALID               = 0,
    SPAWN_EMPTY                 = 0x0000002,
    SPAWN_STOP_SCAN             = 0x0000004,
    SPAWN_BATTLESTATION         = 0x0000020,
    SPAWN_FINALE                = 0x0000040,
    SPAWN_PLAYER_START          = 0x0000080,
    SPAWN_BATTLEFIELD           = 0x0000100,
    SPAWN_IGNORE_VISIBILITY     = 0x0000200,
    SPAWN_NOT_CLEARABLE         = 0x0000400,
    SPAWN_CHECKPOINT            = 0x0000800,
    SPAWN_OBSCURED              = 0x0001000,
    SPAWN_NO_MOBS               = 0x0002000,
    SPAWN_THREAT                = 0x0004000,
    SPAWN_RESCUE_VEHICLE        = 0x0008000,
    SPAWN_RESCUE_CLOSET         = 0x0010000,
    SPAWN_ESCAPE_ROUTE          = 0x0020000,
    SPAWN_DOOR                  = 0x0040000,

    // L4D2
    SPAWN_NOTHREAT              = 0x0080000,
    SPAWN_LYINGDOWN             = 0x0100000,
};

public MRESReturn DHook_TerrorNavArea_IsValidForWanderingPopulation_Pre( Address addrThis, DHookReturn hReturn )
{
    TerrorNavSpawnAttributeType attr = view_as< TerrorNavSpawnAttributeType >( 
        LoadFromAddress( addrThis + view_as< Address >( TerrorNavArea_m_spawnAttributeFlags ), 
        NumberType_Int32 ) 
        );

    if ( attr & SPAWN_NOTHREAT )
    {
        hReturn.Value = false;
        return MRES_Supercede;
    }

    return MRES_Ignored;
}

public MRESReturn DHook_UpdateVersusBossSpawning_Pre( Address addrThis, DHookReturn hReturn )
{
    g_hDDetour_TerrorNavArea_IsValidForWanderingPopulation.Enable( Hook_Pre, DHook_TerrorNavArea_IsValidForWanderingPopulation_Pre );
    return MRES_Ignored;
}

public MRESReturn DHook_UpdateVersusBossSpawning_Post( Address addrThis, DHookReturn hReturn )
{
    // We're done here and we don't want to interfere with the rest of the game logic
    g_hDDetour_TerrorNavArea_IsValidForWanderingPopulation.Disable( Hook_Pre, DHook_TerrorNavArea_IsValidForWanderingPopulation_Pre );
    return MRES_Ignored;
}

public void OnPluginStart()
{
    GameData hGameData = new GameData( GAMEDATA_FILE );
    if ( hGameData == null )
    {
        SetFailState( "Unable to load gamedata file \"" ... GAMEDATA_FILE ... "\"" );
    }

    TerrorNavArea_m_spawnAttributeFlags = hGameData.GetOffset( "TerrorNavArea::m_spawnAttributeFlags" );
    if ( TerrorNavArea_m_spawnAttributeFlags == -1 )
    {
        delete hGameData;

        SetFailState( "Unable to find gamedata offset entry for \"TerrorNavArea::m_spawnAttributeFlags\"" );
    }

    // This is our entry point. It's called only once and it is one of the conditions that needs to pass the test before the Director can spawn a tank
    g_hDDetour_TerrorNavArea_IsValidForWanderingPopulation = new DynamicDetour( Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address );
    if ( !g_hDDetour_TerrorNavArea_IsValidForWanderingPopulation.SetFromConf( hGameData, SDKConf_Signature, "TerrorNavArea::IsValidForWanderingPopulation" ) )
    {
        delete hGameData;

        SetFailState( "Unable to setup dynamic detour for \"TerrorNavArea::IsValidForWanderingPopulation\"" );
    }

    DynamicDetour hDDetour_UpdateVersusBossSpawning = new DynamicDetour( Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_Address );
    if ( !hDDetour_UpdateVersusBossSpawning.SetFromConf( hGameData, SDKConf_Signature, "UpdateVersusBossSpawning" ) )
    {
        delete hGameData;

        SetFailState( "Unable to setup dynamic detour for \"UpdateVersusBossSpawning\"" );
    }

    delete hGameData;

    hDDetour_UpdateVersusBossSpawning.Enable( Hook_Pre, DHook_UpdateVersusBossSpawning_Pre );
    hDDetour_UpdateVersusBossSpawning.Enable( Hook_Post, DHook_UpdateVersusBossSpawning_Post );
}

public Plugin myinfo =
{
    name = "[L4D/2] Boss \"NOTHREAT\" Attribute Fix",
    author = "Justin \"Sir Jay\" Chellah",
    description = "Fixes an issue where the Director would spawn boss infected in areas that have the NOTHREAT attribute, in versus mode",
    version = "1.0.0",
    url = "https://www.justin-chellah.com/"
};