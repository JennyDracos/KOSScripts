parameter destination is "KH Highport".

//parameter InitialVelocity is 62.
copypath("0:/libmath.ks","1:/").
copypath("0:/libdeltav.ks","1:/").
copypath("0:/liborbit.ks","1:/").
copypath("0:/liborbit_interplanetary.ks","1:/").
copypath("0:/lamintercept.ks","1:/").
run once lamintercept.

//parameter PitchoverAngle is 86.
local launchLatitude is round(ship:latitude, 1).
local launchMass is round(ship:mass, 1).
local targetAltitude is round(vessel(destination):altitude/1000) * 1000.
local resethillclimber is false.

function shipDeltaV {
	// dv = ve ln (wet mass / dry mass)
	// dv = isp * g0 * ln (wet mass / dry mass).
	// assumes lox.
	local wetmass is ship:mass.
	local liquidfuel is 0.
	local oxidizer is 0.
	for res in ship:resources {
		if res:name = "liquidfuel" { set liquidfuel to res:amount. }
		if res:name = "oxidizer" { set oxidizer to res:amount. }
	}
	local fuelBurned is min(liquidfuel / 9, oxidizer / 11) * 20 * 0.005.
	local drymass is wetmass - fuelBurned.
	local isp is 0.
	for engine in ship:parts { if engine:typename = "engine" { set isp to engine:visp. } }
	return isp * 9.80665 * ln(wetmass / drymass).
}

local initialdv is shipDeltaV().

if archive:exists("stellar.json") {
	set launchParameterSet to readjson("0:/stellar.json").
} else {
	set launchParameterSet to Lexicon().
}

if not (launchParameterSet:haskey(ship:body:name)) {
	launchParameterSet:add(ship:body:name, Lexicon()).
	set launchParameterSet[ship:body:name]["thrust"] to 100.
}

if not (launchParameterSet[ship:body:name]:hasKey(launchLatitude)) {
	launchParameterSet[ship:body:name]:add(launchLatitude, Lexicon()).
}

if not (launchParameterSet[ship:body:name][launchLatitude]:haskey(launchMass)) {
	launchParameterSet[ship:body:name][launchLatitude]:add(launchMass, Lexicon()).
}

if not (launchParameterSet[ship:body:name][launchLatitude][launchMass]:hasKey(targetAltitude)) {
	//launchParameterSet[ship:body:name][launchLatitude][launchMass]:add(targetAltitude, List(80, 87, 361, 0, 0, 0)).
	launchParameterSet[ship:body:name][launchLatitude][launchMass]:add(targetAltitude, Lexicon(
		"longOffset", 361,
		"simplex", List(V(0, 0, 0),V(0, 60, 70),V(0, 70, 80), V(0, 80, 60))
	)).
	// Launch parameter set consists of: magic number, pitchover angle, interceptLongitudeOffset.
}

local launchParameterList is launchParameterSet[ship:body:name][launchLatitude][launchMass][targetAltitude].
local initialVelocity is 0.
local pitchoverAngle is 0.
local interceptLongOffset is 0.

local testing is "".
local complete is false.
local simulate is true.  

local testVertex is V(0,0,0).

if launchParameterList:istype("List") {
	set initialVelocity to launchParameterList[0].
	set pitchoverAngle to launchParameterList[1].
	set interceptLongOffset to launchParameterList[2].

	if launchParameterList[3] = 0 {
		set testing to "base".
	} else if launchParameterList[4] = 0 {
		set initialVelocity to initialVelocity + 0.1.
		set testing to "magic number".
	} else if launchParameterList[5] = 0 {
		set pitchoverAngle to pitchoverAngle + 0.1.
		set testing to "pitchover angle".
	} else if abs(launchParameterList[4]) < 0.05 and abs(launchParameterList[5]) < 0.05 {
		set complete to true.
		set simulate to launchParameterList[2] > 360.	
	} else {
		set launchParameterList[0] to initialVelocity - launchParameterList[4].
		set launchParameterList[1] to pitchoverAngle - launchParameterList[5].
		set launchParameterList[3] to 0.
		set launchParameterList[4] to 0.
		set launchParameterList[5] to 0.
		set initialVelocity to launchParameterList[0].
		set pitchoverAngle to launchParameterList[1].
		set testing to "base".
		writejson(launchParameterSet, "0:/stellar.json").
	}
} else if launchParameterList["longOffset"] <= 360 {
	set complete to true.
	set simulate to false.
	local vertexOne is launchParameterList["simplex"][1].
	global maxThrottle is launchParameterSet[ship:body:name]["thrust"] / 100.
	set initialVelocity to vertexOne:y.
	set pitchoverAngle to vertexOne:z.
	set interceptLongOffset to launchParameterList["longOffset"].
} else {
	global simplex is launchParameterList["simplex"].
	global maxThrottle is launchParameterSet[ship:body:name]["thrust"] / 100.
	set testVertex to 0.
	// Order
	if simplex[1]:x = 0 { 
		set testVertex to simplex[1]. 
		set testing to "vertex one".
	} else if simplex[2]:x = 0 { 
		set testVertex to simplex[2]. 
		set testing to "vertex two".
	} else if simplex[3]:x = 0 { 
		set testVertex to simplex[3]. 
		set testing to "vertex three".
	} else {
		print "All simplex vertices computed.  Ordering.".
		function swapVertices {
			parameter first, second.
			local temp is simplex[first].
			set simplex[first] to simplex[second].
			set simplex[second] to temp.
		}
		if simplex[2]:x < simplex[1]:x { swapVertices(1,2). }
		if simplex[3]:x < simplex[1]:x { swapVertices(1,3). }
		if simplex[3]:x < simplex[2]:x { swapVertices(2,3). }
		print "All vertices ordered.".

		set simplex[0] to (simplex[1] + simplex[2])/2.
//		for n in range(1,4) { set simplex[0] to simplex[0] + simplex[n] / 3. }
	
		print "Centroid computed.".

		if simplex[3]:x - simplex[1]:x < 1 or 
			(abs(simplex[3]:y - simplex[1]:y) < 0.1 and
			 abs(simplex[3]:z - simplex[1]:z) < 0.1) { // Terminate
			set testVertex to simplex[1].
			set complete to true.
			set testing to "longitude offset".
		} else if launchParameterList:haskey("contraction") { 
			set testVertex to launchParameterList["contraction"]. 
			set testing to "contraction".
		} else if launchParameterList:haskey("expansion") { 
			set testVertex to launchParameterList["expansion"]. 
			set testing to "expansion".
		} else { 
			set newVertex to simplex[0] + (simplex[0] - simplex[3]).
			set newVertex:x to 0.
			launchParameterList:add("reflection", newVertex).
			set testVertex to launchParameterList["reflection"]. 
			set testing to "reflection".
		}

		writejson(launchParameterSet, "0:/stellar.json").
	}

	set initialVelocity to testVertex:y.
	set pitchoverAngle to testVertex:z.
}

wait until KUniverse:canquicksave().
KUniverse:quicksaveto("prelaunch").

function failureState {
	writejson(launchParameterSet,"0:/stellar.json").
	if KUniverse:canreverttolaunch() { KUniverse:reverttolaunch(). }
	KUniverse:quickloadfrom("prelaunch").
}

for res in ship:resources {
	if res:name = "Oxidizer" { lock oxidizer to res. }
}

on abort { EndState(0). }

function LongToDegrees  {
	Parameter lng.
	return mod(lng+360, 360).
}
function TimeToLong {
	Parameter lng.
	Parameter sh is ship.
	
	local sday is ship:body:rotationperiod.
	local kang is 360/sday.
	local p is sh:orbit:period.
	local sangs is (360/p) - kang.
	local tgtlong is LongToDegrees(lng).
	local shipLong is LongToDegrees(sh:longitude).
	local dLong is tgtLong-shipLong.
	if dlong < 0 {
		return (dlong + 360) / sangs.
	}
	else {
		return dlong / sangs.
	}
}


function EndState {
	parameter value is testVertex:x.

	set testVertex:x to value.

	if launchParameterList:haskey("contraction") {
		if testVertex:x < simplex[3]:x {
			set simplex[3] to testVertex.
		} else {
			set simplex[2] to simplex[1] + 0.5 * (simplex[2] - simplex[1]).
			set simplex[2]:x to 0.
			set simplex[3] to simplex[1] + 0.5 * (simplex[3] - simplex[3]).
			set simplex[3]:x to 0.
		}
		launchParameterList:remove("reflection").
		launchParameterList:remove("contraction").
	} else if launchParameterList:haskey("expansion") {
		if testVertex:x < launchParameterList["reflection"]:x {
			set simplex[3] to testVertex.
		} else { set simplex[3] to launchParameterList["reflection"]. }
		launchParameterList:remove("reflection").
		launchParameterList:remove("expansion").
	} else if launchParameterList:haskey("reflection") {
		if testVertex:x < simplex[1]:x {
			set newVertex to simplex[0] + 2.0 * (testVertex - simplex[0]).
			set newVertex:x to 0.
			launchParameterList:add("expansion", newVertex).
		} else if testVertex:x < simplex[2]:x {
			set simplex[3] to testVertex.
			launchParameterList:remove("reflection").
		} else {
			set newVertex to simplex[0] + 0.5 * (simplex[3] - simplex[0]).
			set newVertex:x to 0.
			launchParameterList:add("contraction", newVertex).
		}
	} // Else we are backfilling the simplex.

	writejson(launchParameterSet, "0:/stellar.json").
	wait 2.
	if KUniverse:CanRevert() { KUniverse:RevertToLaunch(). }
	else KUniverse:QuickLoadFrom("prelaunch").

}

bays off.

if complete {
	if simulate { set interceptLongOffset to 0. }
	set launchtime to time:seconds + TimeToLong(interceptLongOffset, Vessel(destination)) - 05.
}
else set launchtime to time:seconds + 10.

set ship:control:pilotmainthrottle to 0.

addalarm("Maneuver",launchtime,ship:name + " Launch","").

if simulate {
	set kuniverse:timewarp:mode to "RAILS".
	kuniverse:timewarp:warpto(launchtime).
}

set mode to "prelaunch".

when time:seconds > launchtime + 05 then {
	set mode to "launch".
}

core:part:controlfrom.

// close cargo bays.
bays off.

set ship:control:pilotmainthrottle to 0.
lock steering to heading(90,90).

when mode = "launch" then {

	// max throttle.
	lock throttle to maxThrottle.

	// stage.
	stage.
	gear off.

	rcs on.
	set mode to "ascent".

	// once velocity hits magic number, pitchover.
	when ship:velocity:surface:mag > InitialVelocity then {
		lock steering to heading(90,pitchoverAngle).
		set mode to "pitchover".
		
		// wait for pitch to over.
		when 90 - vang(ship:up:forevector, ship:srfprograde:forevector) <= pitchoverAngle  then {

			unlock steering.
			set mode to "gravity turn".

			rcs on.

			// Keep above horizon.
			when ship:altitude < ship:body:atm:height and vdot(ship:facing:vector, ship:up:vector) < 0 then {
				set mode to "horizontal burn".
				lock steering to heading(90,0).
			}

			// kill throttle when reach orbit.
		}
	}
}

if ship:partsnamedpattern("launchClamp.*"):length > 0 {
	when mode = "pitchover" then {
		on ship:parts:length { EndState(1e10). }
	}
} else { 
	on ship:parts:length { EndState(1e10). }
}

when ship:obt:apoapsis > targetAltitude then {
	lock throttle to 0.
	lock steering to ship:prograde.
	rcs on.
	set mode to "coast".
}

clearscreen.

print "Running Launch Stellar v0.1.0".
print " - Ssto Transports Expected to Land Like A Rocket".
print "              ".
print "Mission Time: ".
print "Stage:        ".
print "              ".
print "Velocity:     ".
print "Magic Number: ".
print "              ".
print "Pitch:        ".
print "Pitchover:    ".
print "              ".
print "Apoapsis:     ".
print "Periapsis:    ".
print "              ".
print "Current test: ".

until mode = "coast" and ship:altitude > ship:body:atm:height {

	print (launchtime - time):seconds at (20,3).
	print mode:padright(20) at (20,4).

	print round(ship:velocity:surface:mag, 2):tostring:padright(20) at(20,6).
	print round(InitialVelocity,2):tostring:padright(20) at(20,7).

	print round(90- vang(ship:up:forevector, ship:srfprograde:forevector), 2):tostring:padright(20) at(20,9).
	print round(PitchoverAngle, 2):tostring:padright(20)  at(20,10).

	print round(ship:orbit:apoapsis, 2):tostring:padright(20) at(20,12).
	print round(ship:orbit:periapsis, 2):tostring:padright(20) at(20,13).

	print testing:padright(20) at (20,15).

	wait 0.

	if ship:altitude < ship:body:atm:height and
		  eta:apoapsis > eta:periapsis and 
		  (mode = "gravity turn" or mode = "horizonal burn")
	{
		EndState(1e10 - ship:periapsis).
	}
	if mode = "coast" {
		if ship:apoapsis < ship:body:atm:height {
			EndState(1e10).
		} else if ship:apoapsis < targetAltitude {
			lock throttle to 0.1.
		} else if ship:apoapsis > targetAltitude {
			lock throttle to 0.
		}
	}
}

print "Leaving atmosphere.".
until not hasnode {
	remove nextnode.
	wait 0.
}

if complete and simulate { // Hill climber is done, but need longitude difference.

	getCircNodeAt(time:seconds + eta:apoapsis).	
	RunNode(nextNode).

	rcs on.
	set target to vessel(destination).
	run node_inc_tgt.
	if hasnode { RunNode(nextNode). }

	if launchParameterList:istype("List") {
		set launchParameterList[2] to ship:longitude - target:longitude.
	} else {
		set launchParameterList["longOffset"] to ship:longitude - target:longitude.
	}
	writejson(launchParameterSet, "0:/stellar.json").
	
	wait 1.
	if KUniverse:canreverttolaunch() { KUniverse:reverttolaunch(). }
	KUniverse:quickloadfrom("prelaunch").
}
if simulate { // Still running the hill climber.

	getApsisNodeAt(ship:apoapsis, eta:apoapsis).
	set target to vessel(destination).
	run node_inc_tgt.
	
	local finalDV is shipDeltaV().
	for node in allnodes { set finalDV to finalDV - node:deltav:mag. }

	if launchParameterList:istype("List") {
		if (testing = "base") {
			set launchParameterList[3] to initialDV - finalDV.
		} else if (testing = "magic number") {
			set launchParameterList[4] to 
				(initialDV - finalDV - launchParameterList[3]) / abs(launchParameterList[3]) * 10.
		} else if (testing = "pitchover angle") {
			set launchParameterList[5] to 
				(initialDV - finalDV - launchParameterList[3]) / abs(launchParameterList[3]) * 10.
		}
	} else {

		EndState(initialDV - finalDV).

	}

	writejson(launchParameterSet, "0:/stellar.json").
	wait 1.
	if KUniverse:canreverttolaunch() { KUniverse:reverttolaunch(). }
	KUniverse:quickloadfrom("prelaunch").

}

unlock throttle.
unlock steering.

set ship:control:pilotmainthrottle to 0.

set target to vessel(destination).

set data["mode"] to "intercept".
writejson(data, "1:/data.json").
reboot.

