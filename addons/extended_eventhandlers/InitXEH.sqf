#include "script_component.hpp"
diag_log [diag_ticktime, time, "XEH: PreInit Started"];

// Start one vehicle crew initialisation thread and one respawn monitor
SLX_XEH_objects = [];
SLX_XEH_init = compile preProcessFileLineNumbers "extended_eventhandlers\Init.sqf";
SLX_XEH_initPost = compile preProcessFileLineNumbers "extended_eventhandlers\InitPost.sqf";
SLX_XEH_initOthers = compile preProcessFileLineNumbers "extended_eventhandlers\InitOthers.sqf";
SLX_XEH_MACHINE =
[
	!isDedicated, // 0 - isClient (and thus has player)
	false, // 1 - isJip
	!isServer, // 2 - isDedicatedClient (and thus not a Client-Server)
	isServer, // 3 - isServer
	isDedicated, // 4 - isDedicatedServer (and thus not a Client-Server)
	false, // 5 - Player Check Finished
	!isMultiplayer, // 6 - SP?
	false // 7 - StartInit Passed
];
SLX_XEH_F_INIT = {
	private [
		"_i", "_c", "_entry", "_entryServer", "_entryClient", "_Inits"
	];
	_Inits = [];
	#ifdef DEBUG_MODE_FULL
	diag_log text format["(%1) XEH BEG: Init %2", time, _this];
	#endif

	if (isClass _this) then
	{
		_i = 0;
		_c = count _this;
		while { _i<_c } do
		{
			_entry = _this select _i;
			if (isClass _entry) then
			{
				_entryServer = (_entry/"serverInit");
				_entryClient = (_entry/"clientInit");
				_entry = (_entry/"init");

				if (isText _entry) then
				{
					_Inits set [count _Inits, compile(getText _entry)];
				};
				if (isServer) then
				{
					if (isText _entryServer) then
					{
						_Inits set [count _Inits, compile(getText _entryServer)];
					};				
				};
				if (!isDedicated) then
				{
					if (isText _entryClient) then
					{
						_Inits set [count _Inits, compile(getText _entryClient)];
					};
				};
			} else {
				if (isText _entry) then
				{
					_Inits set [count _Inits, compile(getText _entry)];
				};
			};
			_i = _i+1;
		};
		{ call _x } forEach _Inits;	   
	};
	#ifdef DEBUG_MODE_FULL
	diag_log text format["(%1) XEH END: Init %2", time, _this];
	#endif
};

// Load and call any "pre-init", run-once event handlers
call compile preprocessFileLineNumbers "extended_eventhandlers\PreInit.sqf";
diag_log [diag_ticktime, time, "XEH: PreInit Finished"];

/*
* Process the crews of vehicles. This "thread" will run just
* before the mission init.sqf is processed. The order of execution is
*
*  1) all config.cpp init EHs (including all Extended_Init_Eventhandlers)
*  2) all the init lines in the mission.sqm
*  3) spawn:ed "threads" are started
*  4) the mission's init.sqf/sqs is run
*/
_cinit = [] spawn
{
	{
		_sim = getText(configFile/"CfgVehicles"/(typeOf _x)/"simulation");
		_crew = crew _x;
		/*
		* If it's a vehicle then start event handlers for the crew.
		* (Vehicles have crew and are neither humanoids nor game logics)
		*/
		if ((count _crew>0)&&{ _sim == _x }count["soldier", "invisible"] == 0) then
		{
			{ [_x, "Extended_Init_Eventhandlers"] call SLX_XEH_init } forEach _crew;
		};
	} forEach vehicles;
	diag_log [diag_ticktime, time, "XEH: PostInit Started"];
	call compile preProcessFileLineNumbers "extended_eventhandlers\PostInit.sqf";
	diag_log [diag_ticktime, time, "XEH: PostInit Finished"];
};
