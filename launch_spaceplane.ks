parameter rdvTarget is "KH Highport".

local rdv is rdvTarget <> "Direct".
if rdv { set rdvTarget to vessel(rdvTarget). }

local launchdata is 0.

declare function EngineMode {
	parameter engine.

	return engine:getmodule("multimodeengine"):getfield("mode").
}
declare function EngineStateToggle {
	parameter engine.

	engine:getmodule("multimodeengine"):doevent("toggle mode").
}

if archive:exists("spaceplane.json") {
	set launchdata to readjson("0:/spaceplane.json").
} else {
	set launchdata to Lexicon().
	launchdata:add("kindjal", "1").
	launchdata:add("claymore", "1").
}

local launchmass is round(ship:mass).
local launchalt is 80000. if rdv set launchalt to round(rdvTarget:altitude/1000)*1000.
local simulation is rdv.
local interceptLongOffset is 0.

if launchdata:haskey(launchmass) {
	if launchdata[launchmass]:haskey(launchalt) {
		set simulation to false.
		set interceptLongOffset to launchdata[launchmass][launchalt].
	}
}
else {
	launchdata:add(launchmass, Lexicon()).
	writejson(launchdata, "0:/spaceplane.json").
}

if simulation {
	until KUniverse:CanQuicksave { wait 0. }
	KUniverse:quicksaveto("Pre-simulation").
	Hudtext("Simulation", 60000, 2, 20, red, true).
}

function LongToDegrees {
	PARAMETER lng.
	return mod(lng + 360, 360).
}
function timeToLong {
	Parameter lng.
	Parameter sh is ship.

	local sday is body("kerbin"):rotationperiod.
	local kang is 360/sday.
	local p is sh:orbit:period.
	local sangs is (360/p) - kang.
	local tgtlong is LongToDegrees(lng).
	local ShipLong is LongToDegrees(sh:longitude).
	local dlong is tgtlong-shiplong.
	if dlong < 0 {
		return (dlong + 360) / sangs.
	}
	else {
		return dlong / sangs.
	}
}

if rdv { set launchtime to time:seconds + timeToLong(interceptLongOffset, rdvTarget) - 05. }
else { set launchtime to time:seconds + 60. }
set launchalarm to addalarm("Maneuver", launchtime, ship:name + " Launch","").

brakes on.

set kuniverse:timewarp:mode to "RAILS".
kuniverse:timewarp:warpto(launchtime).

wait until time:seconds > launchtime.

stage.



core:part:controlfrom.
set sasmode to "stabilityassist".
sas on.

set q to queue().

set cargo to ship:partstagged("CargoFore").
if cargo:length > 0 { 
	set cargo to cargo[0]:children. 
	for part in cargo { q:push(part). }
}

set cargo to ship:partstagged("CargoAft").
if cargo:length > 0 {
	set cargo to cargo[0]:children.
	for part in cargo { q:push(part). }
}


until q:length = 0 {
	set child to q:pop().
	for subChild in child:children { q:push(subChild). }
	for moduleName in child:allmodules {
		if moduleName = "ModuleReactionWheel" {
			child:getModule("ModuleReactionWheel"):doaction("Deactivate Wheel", true).
		}
	}
}

for fuelCell in ship:modulesnamed("ModuleResourceConverter") {
	for event in fuelCell:alleventnames {
		if event:contains("Start Fuel Cell") { fuelCell:DoEvent(event). }
	}
}

list engines in engineList.

set watchEngine to engineList[0].
for engine in engineList {
	if engine:name = "RAPIER" { set watchEngine to engine. }
}

lock throttle to 0.
set mypitch to 1.
bays off.

set pitchtime to time:seconds.
set mode to "prelaunch".

when time:seconds > launchtime + 05 then {

	for engine in engineList {
		if engine:name = "RAPIER" {
			if EngineMode(engine) = "ClosedCycle" { EngineStateToggle(engine). }
			engine:activate.
		}
	}

	brakes off.

	set mysteer to heading(90, 0).

	lock steering to mysteer.
	lock throttle to 1.0.

	set mode to "launch".

	when ship:status = "FLYING" then {
		set mode to "pitch up".
	}
}

local holding is 0.
		
until ship:altitude > 070000 {
	clearscreen.

	print "Running Launch Kindjal v0.2.0".
	print "Takeoff:  ".
	print "mode:     ".
	print "          ".
	print "apoapsis: ".
	print " in:      ".
	print "periapsis:".
	print " in:      ".
	print "          ".
	print "pitch:    ".
	print "thrust:   ".

	if launchtime > time {
		print (launchtime - time):clock at (12,1).
	} else {
		print "-"+(time - launchtime):clock at (12,1).
	}
	print mode at(12,2).
	print round(ship:apoapsis) at(12,4).
	print round(eta:apoapsis) at(12,5).
	print round(ship:periapsis) at (12,6).
	print round(eta:periapsis) at (12,7).
	print mypitch at (12,9).
	print watchEngine:thrust at(12,10).
	
	if mode = "pitch up"
	{
		if eta:periapsis < eta:apoapsis {
			set mypitch to mypitch + 1.0.
			set mysteer to heading(90,mypitch).
			lock steering to mysteer.
		} else {
			set mode to "pitch down".
			gear off.
		} 
	} else if mode = "pitch down" {
		if mypitch <= 1 {
			unlock steering.
			set mode to "airbreathing burn".


			when watchEngine:thrust < 50 then {
				for engine in engineList {
					if engine:name = "RAPIER" { EngineStateToggle(engine). }
				}
				set mode to "oxidizer burn".

				sas off.
				lock steering to heading(90,5).
		
				when ship:apoapsis > launchalt then {
					lock throttle to 0.
					set mode to "coast".

				}
			}
		} else if time:seconds > holding and 
			eta:apoapsis < eta:periapsis and
			ship:altitude > 200
		{
			set mypitch to max(mypitch - 1.0, 0).
			set mysteer to heading(90,mypitch).
			lock steering to mysteer.
			set holding to time:seconds + 05.
		}
	} else if mode = "coast" {
		if ship:apoapsis < (launchalt - 1000) { lock throttle to 0.1. }
		else { lock throttle to 0. }
	}
	wait 1.
}

bays on.

unlock throttle.
unlock steering.

set ship:control:pilotmainthrottle to 0.0.

if simulation {
	getApsisNodeAt(ship:orbit:apoapsis, time:seconds + eta:apoapsis).
	wait 0.
	RunNode(nextNode).

	launchdata[launchmass]:add(launchalt, ship:longitude - rdvTarget:longitude).

	writejson(launchdata, "0:/spaceplane.json").

	KUniverse:Quickloadfrom("Pre-Simulation").
}

//set mysteer to ship:prograde.

//lock steering to mysteer.
//print "Circularizing.".


//until ship:periapsis > 75000 {
//	set mysteer to ship:prograde.
//	lock throttle to 1.0.
//}

//print "Orbit complete.".

// set throttle to 0.
