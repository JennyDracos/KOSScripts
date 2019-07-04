parameter destination is "KH Highport".

//parameter InitialVelocity is 62.
copypath("0:/libmath.ks","1:/").
copypath("0:/libdeltav.ks","1:/").
copypath("0:/exenode.ks","1:/").
copypath("0:/liborbit.ks","1:/").
copypath("0:/liborbit_interplanetary.ks","1:/").
run once liborbit_interplanetary.

//parameter PitchoverAngle is 86.
local launchLatitude is round(ship:latitude, 1).
local launchMass is round(ship:mass, 1).
local targetAltitude is round(vessel(destination):altitude/100) * 100.
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
	return isp * constant:g * ln(wetmass / drymass).
}

local initialdv is shipDeltaV().

if archive:exists("stellar.json") {
	set launchParameterSet to readjson("0:/stellar.json").
} else {
	set launchParameterSet to Lexicon().
}

if not (launchParameterSet:haskey(ship:body:name)) {
	launchParameterSet:add(ship:body:name, Lexicon()).
}

local simulation is false.
if not (launchParameterSet[ship:body:name]:hasKey(launchLatitude)) {
	launchParameterSet[ship:body:name]:add(launchLatitude, Lexicon()).
}

if not (launchParameterSet[ship:body:name][launchLatitude]:haskey(launchMass)) {
	launchParameterSet[ship:body:name][launchLatitude]:add(launchMass, Lexicon()).
}

if not (launchParameterSet[ship:body:name][launchLatitude][launchMass]:hasKey(targetAltitude)) {
	launchParameterSet[ship:body:name][launchLatitude][launchMass]:add(targetAltitude, List(20, 45, 0, 0, 0, 0)).
	// Launch parameter set consists of: magic number, pitchover angle, interceptLongitudeOffset.
	set resethillclimber to true.
	set simulation to true.
}

lock launchParameterList to launchParameterSet[ship:body:name][launchLatitude][launchMass][targetAltitude].
local initialVelocity is launchParameterList[0].
local pitchoverAngle is launchParameterList[1].
local interceptLongOffset is launchParameterList[2].

lock complete to launchParameterList[3].

if not complete {

	if resethillclimber or not (launchParameterSet:haskey("HillClimberList")) {
		set hillClimberList to list().
		hillClimberList:add(List(85, 81, 0)).
		hillClimberList:add(List(86, 81, 0)).
		hillClimberList:add(List(87, 81, 0)).
	
		hillClimberList:add(List(85, 81.5, 0)).
		hillClimberList:add(List(86, 81.5, 0)).
		hillClimberList:add(List(87, 81.5, 0)).
		
		hillClimberList:add(List(85, 82, 0)).
		hillClimberList:add(List(86, 82, 0)).
		hillClimberList:add(List(87, 82, 0)).
	
		if launchParameterSet:haskey("HillClimberList") {
			set launchParameterSet["HillClimberList"] to hillClimberList.
		} else { launchParameterSet:Add("HillClimberList", hillClimberList). }
	
		writejson(launchParameterSet, "0:/stellar.json").
	}
	lock hillClimberList to launchParameterSet["HillClimberList"].
	
	set hillClimberIteration to 9.
	
	for n in range(0,9) {
		if hillClimberList[n][2] = 0 { set hillClimberIteration to n. }
	}
	
	local complete is false.
	
	if hillClimberIteration = 9 {
		set highestPercent to 0.
		set highestIteration to -1.
		for n in range(0,9) {
			if hillClimberList[n][2] > highestPercent {
				set highestPercent to hillClimberList[n][2].
				set highestIteration to n.
			}
		}

		set newList to List(0,0,0,0,0,0,0,0,0).
	
	
		if highestIteration = 0 {
			set newList[0] to List(hillClimberList[0][0]-1, hillClimberList[0][1]-0.5, 0).
			set newList[1] to List(hillClimberList[0][0],   hillClimberList[0][1]-0.5, 0).
			set newList[2] to List(hillClimberList[0][0]+1, hillClimberList[0][1]-0.5, 0).
			set newList[3] to List(hillClimberList[0][0]-1, hillClimberList[0][1],     0).
			set newList[4] to hillClimberList[0].
			set newList[5] to hillClimberList[1].
			set newList[6] to List(hillClimberList[0][0]-1, hillClimberList[0][1]+0.5, 0).
			set newList[7] to hillClimberList[3].
			set newList[8] to hillClimberList[4].
		} else if highestIteration = 1 {
			set newList[0] to List(hillClimberList[1][0]-1, hillClimberList[1][1]-0.5, 0).
			set newList[1] to List(hillClimberList[1][0],   hillClimberList[1][1]-0.5, 0).
			set newList[2] to List(hillClimberList[1][0]+1, hillClimberList[1][1]-0.5, 0).
			set newList[3] to hillClimberList[0].
			set newList[4] to hillClimberList[1].
			set newList[5] to hillClimberList[2].
			set newList[6] to hillClimberList[3].
			set newList[7] to hillClimberList[4].
			set newList[8] to hillClimberList[5].
		} else if highestIteration = 2 {
			set newList[0] to List(hillClimberList[2][0]-1, hillClimberList[2][1]-0.5, 0).
			set newList[1] to List(hillClimberList[2][0],   hillClimberList[2][1]-0.5, 0).
			set newList[2] to List(hillClimberList[2][0]+1, hillClimberList[2][1]-0.5, 0).
			set newList[3] to hillClimberList[1].
			set newList[4] to hillClimberList[2].
			set newList[5] to List(hillClimberList[2][0]+1, hillClimberList[2][1],     0).
			set newList[6] to hillClimberList[4].
			set newList[7] to hillClimberList[7].
			set newList[8] to List(hillClimberList[2][0]+1, hillClimberList[2][1]+0.5, 0).
		} else if highestIteration = 3 {
			set newList[0] to List(hillClimberList[3][0]-1, hillClimberList[3][1]-0.5, 0).
			set newList[1] to hillClimberList[0].
			set newList[2] to hillClimberList[1].
			set newList[3] to List(hillClimberList[3][0]-1, hillClimberList[3][1],     0).
			set newList[4] to hillClimberList[3].
			set newList[5] to hillClimberList[4].
			set newList[6] to List(hillClimberList[3][0]-1, hillClimberList[3][1]+0.5, 0).
			set newList[7] to hillClimberList[6].
			set newList[8] to hillClimberList[7].
		} else if highestIteration = 5 {
			set newList[0] to hillClimberList[1].
			set newList[1] to hillClimberList[2].
			set newList[2] to List(hillClimberList[5][0]+1, hillClimberList[5][1]-0.5, 0).
			set newList[3] to hillClimberList[4].
			set newList[4] to hillClimberList[5].
			set newList[5] to List(hillClimberList[5][0]+1, hillClimberList[5][1],     0).
			set newList[6] to hillClimberList[7].
			set newList[7] to hillClimberList[8].
			set newList[8] to List(hillClimberList[5][0]+1, hillClimberList[5][1]+0.5, 0).
		} else if highestIteration = 6 {
			set newList[0] to List(hillClimberList[6][0]-1, hillClimberList[6][1]-0.5, 0).
			set newList[1] to hillClimberList[3].
			set newList[2] to hillClimberList[4].
			set newList[3] to List(hillClimberList[6][0]-1, hillClimberList[6][1],     0).
			set newList[4] to hillClimberList[6].
			set newList[5] to hillClimberList[7].
			set newList[6] to List(hillClimberList[6][0]-1, hillClimberList[6][1]+0.5, 0).
			set newList[7] to List(hillClimberList[6][0],   hillClimberList[6][1]+0.5, 0).
			set newList[8] to List(hillClimberList[6][0]+1, hillClimberList[6][1]+0.5, 0).
		} else if highestIteration = 7 {
			set newList[0] to hillClimberList[3].
			set newList[1] to hillClimberList[4].
			set newList[2] to hillClimberList[5].
			set newList[3] to hillClimberList[6].
			set newList[4] to hillClimberList[7].
			set newList[5] to hillClimberList[8].
			set newList[6] to List(hillClimberList[7][0]-1, hillClimberList[7][1]+0.5, 0).
			set newList[7] to List(hillClimberList[7][0],   hillClimberList[7][1]+0.5, 0).
			set newList[8] to List(hillClimberList[7][0]+1, hillClimberList[7][1]+0.5, 0).
		} else if highestIteration = 8 {
			set newList[0] to hillClimberList[4].
			set newList[1] to hillClimberList[5].
			set newList[2] to List(hillClimberList[8][0]+1, hillClimberList[8][1]-0.5, 0).
			set newList[3] to hillClimberList[7].
			set newList[4] to hillClimberList[8].
			set newList[5] to List(hillClimberList[8][0]+1, hillClimberList[8][1],     0).
			set newList[6] to List(hillClimberList[8][0]-1, hillClimberList[8][1]+0.5, 0).
			set newList[7] to List(hillClimberList[8][0],   hillClimberList[8][1]+0.5, 0).
			set newList[8] to List(hillClimberList[8][0]+1, hillClimberList[8][1]+0.5, 0).
		} 
	
	
		if highestIteration = 4 {
			// We can't improve except by changing resolution.
			// And I don't wanna.
			set launchParameterList[3] to true.
			// print "Optimal results with this climber.".
			// print 1/0.
		} else {
		// 0 1 2
		// 3 4 5
		// 6 7 8
			set launchParameterSet["HillClimberList"] to newList.
			writejson(launchParameterSet, "0:/stellar.json").
	
			reboot.
		}
	}

	set initialVelocity to hillClimberList[hillClimberIteration][0].
	set pitchoverAngle to hillClimberList[hillClimberIteration][1].
}	


// lock initialVelocityQueue to launchParameterSet["initialVelocityQueue"].
// lock pitchoverAngleQueue to launchParameterSet["pitchoverAngleQueue"].
// lock results to launchParameterSet["Results"].

// if initialVelocityQueue:Length = 0 {
//	set launchParameterSet["initialVelocityQueue"] to Queue().
//	for n in range(40,100) { initialVelocityQueue:push(n). }
//	pitchoverAngleQueue:pop.
// }
// if pitchoverAngleQueue:Length = 0 {
// 	print "Data complete!  Find my minimum!".
// 	print 1/0.
// }

// writejson(launchParameterSet, "0:/stellar.json").

function failureState {
	set hillClimberList[hillClimberIteration][2] to -1e50.
	writejson(launchParameterSet,"0:/stellar.json").
	KUniverse:quickload().
}

for res in ship:resources {
	if res:name = "Oxidizer" { lock oxidizer to res. }
}

on abort { FailureState. }

on ship:parts:length { FailureState. }

// set initialVelocity to initialVelocityQueue:pop().
// set pitchoverAngle to pitchoverAngleQueue:peek().

function LongToDegrees  {
	Parameter lng.
	return mod(lng+360, 360).
}
function TimeToLong {
	Parameter lng.
	Parameter sh is ship.
	
	local sday is body("kerbin"):rotationperiod.
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

bays off.

set launchtime to time:seconds + TimeToLong(interceptLongOffset, Vessel(destination)) - 05.

set ship:control:pilotmainthrottle to 0.

addalarm("Maneuver",launchtime,ship:name + " Launch","").
//set kuniverse:timewarp:mode to "RAILS".
//kuniverse:timewarp:warpto(launchtime).

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
	lock throttle to 1.

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
			// when ship:facing:pitch < 0 then {
			//	lock steering to heading(90,0).
			// }

			// kill throttle when reach orbit.
		}
	}
}

when ship:obt:apoapsis > targetAltitude then {
	lock throttle to 0.
	lock steering to ship:prograde.
	rcs on.
	set mode to "coast".
}

until mode = "coast" and ship:apoapsis > ship:body:atm:height {

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

	print (launchtime - time):seconds at (20,3).
	print mode:padright(20) at (20,4).

	print round(ship:velocity:surface:mag, 2):tostring:padright(20) at(20,6).
	print round(InitialVelocity,2):tostring:padright(20) at(20,7).

	print round(90- vang(ship:up:forevector, ship:srfprograde:forevector), 2):tostring:padright(20) at(20,8).
	print round(PitchoverAngle, 2):tostring:padright(20)  at(20,9).

	print round(ship:orbit:apoapsis, 2):tostring:padright(20) at(20,12).
	print round(ship:orbit:periapsis, 2):tostring:padright(20) at(20,13).

	print hillClimberIteration:tostring:padright(20) at (20,15).

	wait 1.

	if mode = "gravity turn" and eta:apoapsis > eta:periapsis {
		FailureState.
	}
	if mode = "coast" {
		if ship:apoapsis < ship:body:atm:height {
			FailureState.
		} else if ship:apoapsis < targetAltitude {
			lock throttle to 0.1.
		}
	}
}



if complete and simulation { // Hill climber is done, but need longitude difference.

	run circ.

	rcs on.
	set target to vessel(destination).
	run node_inc_tgt.
	run node.

	set launchParameterList[2] to ship:longitude - target:longitude.
	writejson(launchParameterSet, "0:/stellar.json").
	
	wait 1.
	KUniverse:quickload().
}
else if complete { // Whoa, we're done!

	set target to vessel(destination).
	add LeastDVGivenIntercept(getClosestApproach()[0]).

	run node.

	matchVelocityAtClosestApproach().
	rcs on.
	run node.


} else { // Still running the hill climber.

	run circ.
	rcs on.

	set target to vessel(destination).
	run node_inc_tgt.
	run node.
	
	local finalDeltaV is shipDeltaV().

	set hillClimberList[hillClimberIteration][2] to initialDV - finalDeltaV.
	writejson(launchParameterSet, "0:/stellar.json").
	wait 1.
	KUniverse:quickload().

}

unlock throttle.
unlock steering.

set ship:control:pilotmainthrottle to 0.

set target to vessel(destination).
