#if defined _shavitchallenge_included_
#endinput
#endif
#define _shavitchallenge_included_

/* Natives */

/**
 * Checks client's freeze status
 *
 * @param client    Client's id
 * @return          True / False
 */
native bool Challenge_IsClientFrozen(int client);

public SharedPlugin:__pl_shavitchallenge =
{
    name = "shavit-challenge",
    file = "shavit-challenge.smx",
    #if defined REQUIRE_PLUGIN
    required = 1,
    #else
    required = 0,
    #endif
};

public void __pl_shavitchallenge_SetNTVOptional()
{
	MarkNativeAsOptional("Challenge_IsClientFrozen");
}