// Copy pilot.ks and lib_pid.ks to local.
copypath("0:/pilot.ks","1:/").
copypath("0:/lib_ui.ks","1:/").
copypath("0:/lib_pid.ks","1:/").
copypath("0:/aeroland.ks","1:/").
copypath("0:/node.ks","1:/").
copypath("0:/circ.ks","1:/").
copypath("0:/node_apo.ks","1:/").
copypath("0:/warp.ks","1:/").

switch to 1.

sas off.

core:part:controlfrom.

if hasnode = false {

	if ship:orbit:eccentricity > 0.001 {
		run node_apo(ship:periapsis).
		run node.
	}


	// Ensure fuel cells are running and close cargo bays.
	for module in ship:modulesnamed("ModuleResourceConvertor") {
		for event in module:allevents {
			if event:contains("Start Fuel Cell") { module:doevent(event). }
		}
	}
	for cargoBay in ship:modulesnamed("ModuleCargoBay") {
		if cargoBay:part:getmodule("ModuleAnimateGeneric"):hasevent("Close") {
			cargoBay:part:getmodule("ModuleAnimateGeneric"):doevent("Close").
		}
	}

	// Make a new maneuver node.
	set mynode to node( time:seconds + 60, 0, 0, 0).
	add mynode.

	// Apply retrograde thrust until the maneuver node is at [global] feet.
	set targetAltitude to 21000.
		until mynode:orbit:periapsis < targetAltitude {
		set mynode:prograde to mynode:prograde - 1.
	}

	// Set the maneuver node to thirty seconds in the future, then move it until the ship is falling right on KSC.
	lock steering to prograde.

	set targetLongitude to -74.
	set hitLongitude to -72.

	wait until vdot(ship:facing:vector, ship:prograde:vector) > 0.9999.

	if addons:tr:available {
		wait until addons:tr:hasimpact. 
		lock hitLongitude to addons:tr:impactpos:lng.
	} else { print "Trajectories is not available.". }

	until (hitLongitude > targetLongitude) and (hitLongitude < targetLongitude + 5) {
		set mynode:eta to mynode:eta + 1.
	}
	
	set mynode:eta to mynode:eta - 5.
	until (hitLongitude > targetLongitude) {
		set mynode:eta to mynode:eta + 0.1.
	}

}

// Run the node.
run node.

// Lock to prograde.  Maximum warp.
lock steering to prograde.
set kuniverse:timewarp:warp to 4.

// Toggle mode on all engines.
wait until ship:altitude < 50000.
for modeswitch in ship:modulesnamed("MultiModeEngine") {
	if modeswitch:getfield("mode") = "closedcycle" {
		modeswitch:doevent("toggle mode").
	}
}

// Any time the nose cone reaches critical temperature, flare the ship for five seconds.
// KOS currently has no core temp monitoring, so gonna have to trigger off the user pressing Abort.
if ship:partsnamed("rocketnosecone"):length > 0 {
	when ship:partsnamed("rocketnosecone")[0]:getmodule("parttemperaturestate"):getfield(
		ship:partsnamed("rocketnosecone")[0]:getmodule("parttemperaturestate"):allfieldnames
		[1]) > 2300 then {

		set flareEndTime to time:seconds + 5.
		lock steering to ship:prograde * R(-90,0,0).

		when (time:seconds > flareEndTime) then { lock steering to prograde. }
		return true.
	}
}
// Fix for Claymores.
else {
	when ship:partsnamed("adapter?")[0]:getmodule("parttemperaturestate"):getfield(
		ship:partsnamed("adapter?")[0]:getmodule("parttemperaturestate"):allfieldnames[1]) >
		1900 then {

		set flareEndTime to time:seconds + 5.
		lock steering to ship:prograde * R(-90,0,0).

		when (time:seconds > flareEndTime) then { lock steering to prograde. }
		return true.
	}
}

// When below 20,000 feet, pop a u-ie.
wait until ship:altitude < 20000.
lock steering to heading(270,0).


// When below 5,000 feet, run pilot.
wait until ship:altitude < 7000.
unlock steering.
set looseThrottle to time:seconds + 5.
wait until time:seconds > looseThrottle.
run pilot.

