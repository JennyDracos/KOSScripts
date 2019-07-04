copypath("0:/boot/stellar.ks","1:/boot/stellar.ks").
copypath("0:/lib_ui.ks","1:/lib_ui.ks").
copypath("0:/node_inc_tgt.ks","1:/").

compile "0:/libmath.ks" to "1:/libmath.ksm".
copypath("0:/liborbit.ks","1:/liborbit.ks").
copypath("0:/liborbit_interplanetary.ks","1:/liborbit_interplanetary.ks").
copypath("0:/lamintercept.ks","1:/").

copypath("0:/lib/comms.ks","1:/lib/comms.ks").
copypath("0:/libsimplex.ks","1:/libsimplex.ks").
copypath("0:/lib/node.ks","1:/lib/node.ks").
copypath("0:/lib/dock.ks","1:/lib/dock.ks").

runoncepath("1:/lib/comms").
runoncepath("1:/libsimplex").
runoncepath("1:/lib/node").
runoncepath("1:/lib/dock").

runoncepath("1:/liborbit_interplanetary.ks").

copypath("0:/launch_stellar.ks","1:/launch_stellar.ks").
// copypath("0:/launch_stellar_test.ks","1:/").

set core:bootfilename to "/boot/stellar.ks".

wait 0.

// if ship:status = "prelaunch" { run launch_stellar_test. }

wait until ship:unpacked.

global data is 0.

if core:volume:exists("data.json") {
	set data to readjson("1:/data.json").
} else {
	set data to Lexicon().
}

if not data:haskey("mode") { set data["mode"] to "landed". }
if not data:haskey("mother") { set data["mother"] to "KH Highport". }
if not data:haskey("mission") { set data["mission"] to "". }
if not data:haskey("cargo") { set data["cargo"] to "Experiment Module". }
if not data:haskey("flip") { set data["flip"] to 20. }
if not data:haskey("lat") { set data["lat"] to 0. }
if not data:haskey("lon") { set data["lon"] to 0. }

writejson(data, "1:/data.json").

set mode to "startup".
lock mother to data["mother"].
lock mission to data["mission"].
lock cargo to data["cargo"].

global TRAddon is Addons:TR.

local landingPos is LatLng(data["lat"],data["lon"]).
local rcsLoop is false.

clearscreen.

until not hasnode {
	remove nextnode.
	wait 0.
}

on mode {
	print "Switching mode to " + mode.
	
	if mode = "deorbit" {
		local dualBurn is PatternSearch(
			List(1000),
			{
				parameter tuple.

				
				// preLan is longitude of ascending node for orbit over destination.
				// this is 90 degrees before longitude of landing site when lat > 0, 270 for lat < 0.
				local preLan is data["lon"] - 90.
				if data["lat"] < 0 { set preLan to preLan - 180. }

				// Problem is this needs to be compensated because LAN is based on solar prime vector.
				set preLan to preLan + ship:body:rotationAngle.

				// Also needs to be compensated for flight time.
				local apoHeight is ship:apoapsis + ship:body:radius.
				local periHeight is tuple[1] + ship:body:radius.
				local sma is (apoHeight + periHeight) / 2.
				local descentFlightTime is pi * sqrt(radiusSum * radiusSum * radiusSum / ship:body:mu).
				local deltaAngle is descentFlightTime / ship:body:rotationperiod * 360.

				set preLan to preLan + deltaAngle.

				local inclinationBurn is getChangeIncNode(data["lat"], preLan).

				set apsisTime to time:seconds + inclinationBurn:eta + descentFlightTime.

				local deorbitBurn is getApsisNodeAt(tuple[1], apsisTime). 
				wait 0.
				if deorbitBurn:orbit:periapsis < 500 {
					print "Need more height!".
					return 1e6 + (500 - deorbitBurn:orbit:periapsis).
				} else if TRAddon:hasImpact {
					print "Splat!".
					return 1e7 + (500 - deorbitBurn:orbit:periapsis).
				}
				local finalPeriapsis is deorbitBurn:orbit:periapsis.
				remove deorbitBurn.
				remove inclinationBurn.
				return finalPeriapsis.
			},
			100,
			0.1
		).
		
		
		// Drop periapsis to minimum.
		// Brake.

		local lan is data["lon"].
		if data["lat"] < 0 {
			
		}
	
		local singleBurn is SimplexSolver(
			List(time:seconds + 120, 0, -100, -100),
			{
				parameter tuple.

				local nd is node(tuple[1], tuple[2], tuple[3], tuple[4]).
				if nd:eta < data["flip"] + ManeuverTime(nd:deltav:mag) {
					print "Too soon!".
					return 1e10 - nd:eta.
				}

				
			},
			List(ship:orbit:period, 100, 200, 200),
			0.01
		).
		local flightParams is SimplexSolver(
			List(time:seconds + 120, 1200),
			{
				parameter tuple.

				if tuple[1] < time:seconds + data["flip"] { 
					print "Too soon".
					return 1e10. 
				}

				if hasnode { remove nextnode. }

				// r0 is position at departure.
				local pos0 is positionat(ship, tuple[1]).
				// r1 is geopos of landing, compensated for rotation during flight.
				local phi is (tuple[1] + tuple[2]) / ship:body:rotationperiod * 360.
				local geopos is ship:body:geopositionlatlng(data["lat"], data["lon"] + phi).
				local pos1 is geopos:altitudeposition(3000 + geopos:terrainheight).
				local posB is ship:body:position.

				local r0 is pos0 - posB.
				local r1 is pos1 - posB.

				if r0:mag < geoPos:terrainheight {
					print "WHAT THE HECK".
					print 1/0.
				}

				local dta is vang(r0, r1).
				if (vdot(vcrs(r0, r1), v(0,1,0)) > 0) set dta to clamp360(-dta).
				print tuple.
				local solution is LambertSolver(r0:mag, r1:mag, 0, dta, tuple[2], ship:body:mu).

				local f is solution[5].
				local g is solution[6].
				local gprime is solution[7].
				local vburn is (r1 - f * r0) * (1 / g).
				local v0 is velocityat(ship, tuple[1]):orbit.
				local dv is (vburn - v0):mag.
				local nd is getNodeDV(v0, vburn - v0, r0, tuple[1]).
				add nd.
				
				// Lambert solver for burn.

				// dV is difference between vBurn and v0.
				// fV is velocityat(ship, tuple[1] + tuple[2].
				local fv is velocityat(ship, tuple[1] + tuple[2]):surface:mag.

				if nd:orbit:periapsis < 500 {
					print "Still too low".
					return 1e8 - nd:orbit:periapsis.
				}

				wait 0.

				if TRAddon:hasImpact {
					local error is 1e5 + abs(TRAddon:ImpactPos:Lng - data["Lon"]).
					print error.
					return error.
				} else {
					local error is sqrt(dv * dv + fv * fv).
					print error.
					return error.
				}
			},
			100,
			0.02
		).


		if hasnode { remove nextnode. }
		// Add initial burn.

		// r0 is position at departure.
		local pos0 is positionat(ship, flightParams[1]).
		// r1 is geopos of landing, compensated for rotation during flight.
		local phi is (flightParams[1] + flightParams[2]) / ship:body:rotationperiod * 360.
		local geopos is ship:body:geopositionlatlng(data["lat"], data["lon"] + phi).
		local pos1 is geopos:altitudeposition(3000 + geopos:terrainheight).
		local posB is ship:body:position.

		local r0 is pos0 - posB.
		local r1 is pos1 - posB.

		local dta is vang(r0, r1).
		if (vdot(vcrs(r0, r1), v(0,1,0)) > 0) set dta to clamp360(-dta).
		local solution is LambertSolver(r0:mag, r1:mag, 0, dta, flightParams[2], ship:body:mu).

		local f is solution[5].
		local g is solution[6].
		local gprime is solution[7].
		local vburn is (r1 - f * r0) * (1 / g).
		local v0 is velocityat(ship, flightParams[1]):orbit.
		local dv is (vburn - v0):mag.
		local nd is getNodeDV(v0, vburn - v0, r0, flightParams[1]).
		add nd.
	
		local brake is node(flightParams[1] + flightParams[2], 0, 0, 
		  -velocityAt(ship, flightParams[1] + flightParams[2]):orbit:mag).

		add brake.
	
		local retroNode is node(time:seconds + 120, 0, 0, 0).
		add retroNode.

		local nodeParams is PatternSearch(
			List(time:seconds + 120, -ship:velocity:orbit:mag, 0, 0, 120),
			{
				parameter tuple.

				set retroNode:eta to tuple[1] - time:seconds.
				set retroNode:prograde to tuple[2].
				set retroNode:normal to tuple[3].
				set retroNode:radialout to tuple[4].

				if retroNode:eta < data["flip"] + ManeuverTime(retroNode:deltaV:mag) {
					print "too soon!".
					return 1e19.
				}

				wait 0.	
				if TRAddon:HasImpact {
					print "too low!".
					return 1e6 * abs(retroNode:orbit:periapsis).
				}

				wait 0.

				local deorbitNode is node(
					tuple[1] + tuple[4], velocityat(ship, tuple[1]+tuple[4]):surface:mag, 0, 0).

				if TRAddon:HasImpact {
					local latErr is TRAddon:ImpactPos:Lat - data["lat"].
					local lonErr is TRAddon:ImpactPos:Lng - data["lon"].

					local dVErrOne is retroNode:deltaV:mag.
					local dvErrTwo is deorbitNode:deltaV:mag.

					local error is sqrt(latErr * latErr + lonErr * lonErr + dVErrOne * dVErrOne + dvErrTwo * dvErrTwo).
					print error.
					return error.
				} else {
					local periError is retroNode:orbit:periapsis.
					local deltaVErr is retroNode:deltaV:mag.

					local error is sqrt(periError * periError + deltaVErr * deltaVErr) * 1000.
					print "too high: " + error.
					return error.
				}
			},
			100
		).

		set retroNode:eta to nodeParams[1] - time:seconds.
		set retroNode:prograde to nodeParams[2].
		set retroNode:normal to nodeParams[3].
		set retroNode:radialout to nodeParams[4].
	} else if mode = "Brake" {

		if hasnode { remove nextnode. }

		local burnTime is PatternSearch(
			List(time:seconds + eta:periapsis),
			{
				parameter tuple.

				local brakeNode is node(tuple[1], 0, 0,
				  -(velocityat(ship, tuple[1]):orbit:mag)).

				add brakeNode.

				wait 0.
				if TRAddon:hasImpact {
					local error is abs(TRAddon:ImpactPos:Lng - data["lon"]).

					remove nextNode.

					print error.
					return error.
				} else {
					print "Fail.".
					
					remove nextNode.

					return 1e10.
				}
			},
			100
		)[1].

		local brakeNode is node(burnTime, 0, 0, -(velocityAt(ship, burnTime):orbit:mag)).
		add brakeNode.

		wait 0.

	} else if mode = "Recover" {
		set cargoport to ship:partstagged("cargo fore")[0].
		cargoport:controlfrom.

		set speedcap to 0.1.
		
		set targetdock to "".
		for port in vessel(mission):dockingports {
			if port:nodetype = cargoport:nodetype {
				set targetdock to port.
			}
		}

		highlight(cargoport,green).
		highlight(targetdock,red).

		set startPos to { return cargoport:nodeposition. }.

		set pathQueue to List(
			List(V( 30, 30,0.3), 1.0, 1.0, XYZOffset@),
			List(V( 30,  0,0.3), 1.0, 1.0, XYZOffset@),
			List(V( 30,-10,0.3), 0.5, 0.5, XYZOffset@),
			List(V(  0,-10,0.3), 0.2, 0.5, XYZOffset@),
			List(V(  0, -5,0.3), 0.2, 0.1, XYZOffset@),
			List(V(  0, -3,0.3), 0.2, 0.1, XYZOffset@),
			List(V(  0, -2,0.3), 0.2, 0.1, XYZOffset@),
			List(V(  0, -1,0.3), 0.2, 0.1, XYZOffset@),
			List(V(  0,  0,0.3), 0.2, 0.1, XYZOffset@),
			List(V(  0,  0,  0), 0.1, 0.1, XYZOffset@)
		).

		set zeroVelocity to { return vessel(mission):velocity:orbit. }.
		set endPosition to { return targetdock:nodeposition. }.
		set alignment to { return targetdock:portfacing. }.
		set targetfacing to { return lookdirup(-(targetdock:facing:vector), targetdock:facing:upvector). }.
	
		set rcsloop to true.
		set terminate to { return true. }.
		dockInit().

		when targetdock:state:startswith("Acquire") then {
			print "Acquiring target!".
			bays off.
			set rcsloop to false.
			set data["mission"] to "".
			when targetdock:state:startswith("Docked") then {
				print "Docked!".
				set data["mode"] to "deorbit".
			}
		}
	
	}
	writejson(data, "1:/data.json").

	return true.
} lock mode to data["mode"].

set commsHandler to {
	parameter content.

	if mode = "Sleep" {
		if content:istype:string and content = core:tag + " WAKE" {
			set data["mode"] to "Wake".
		}
	} else if content:istype("Lexicon") {
		if not content:haskey("type") {
			print "Malformed message.".
		} else if content["type"] <> "Stellar" {
			print "Misdirected message.".
		} else {
			print "No handler for complex messages.".
		}
	} else if content:startswith("RECOVER ") {
		set data["mission"] to content:replace("RECOVER ","").
		set data["mode"] to "Recover".
	} else if content:startswith("LAND ") {
		set contentParts to content:split(" ").
		set data["lat"] to contentParts[1]:tonumber(0).
		set data["lon"] to contentParts[2]:tonumber(0).
		set data["mode"] to "Deorbit".
	} else {
		print "No handler for " + content.
	}

	writejson(data, "1:/data.json").
}.


until false {

	if mode = "Sleep" {
		wait 1.
	} else if hasNode {
		core:part:controlFrom.
		rcs on.
		RunNode(nextNode).


		if mode = "deorbit" {
			set data["mode"] to "brake".
		} else if mode = "brake" {
			set data["mode"] to "finalDescent".
		}

		writejson(data, "1:/data.json").
		wait 0.
	} else if rcsLoop {
		set rcsLoop to dockUpdate().

		wait 0.1.
	} else if mode = "Landed" and bays = false {
		set data["mode"] to "Boost".
		wait 0.
	} else if mode = "Boost" {
		runpath("1:/launch_stellar",mother).
	} else if mode = "FinalDescent" {
		lock steering to retrograde.

		local finalDescent is landingPos:AltitudePosition(landingPos:terrainheight + 500).

		local touchdownSpeed is 2.

		// PID Throttle
		local throttlePID is PIDLoop(0.04, 0.001, 0.01).
		set throttlePID:MaxOutput to 1.
		set throttlePID:MinOutput to 0.
		set throttlePID:Setpoint to 0.

		SAS off.
		RCS on.
		LIGHTS on.
		LEGS on.

		local tVal is 0.
		lock throttle to tVal.
		local sDir is ship:up.
		lock steering to sDir.

		clearscreen.

		function landRadarAltimeter {
			return ship:altitude - ship:geoposition:terrainheight.
		}

		until ship:status = "landed" or ship:status = "splashed" {
			clearvecdraws().

			local shipVelocity is ship:velocity:surface.
			local shipHVelocity is vxcl(ship:up:vector, shipVelocity).
			local dFactor is 0.01.
			local targetVector is vxcl(ship:up:vector, landingPos:position * dFactor).
			local steerVector is -shipVelocity - shipHVelocity + targetVector.

			local drawsv is vecdraw(v(0,0,0), SteerVector, red, "Steering", 1, true, 1).
			local drawv is vecdraw(v(0,0,0), ShipVelocity, green, "Velocity", 1, true, 1).
			local drawhv is vecdraw(v(0,0,0), ShipHVelocity, yellow, "Horizontal Velocity", 1, true, 1).
			local drawtv is vecdraw(v(0,0,0), targetVector, magenta, "Target", 1, true, 1).

			set sDir to steerVector:direction.
			set targetVSpeed to Max(TouchdownSpeed, sqrt(landRadarAltimeter())). // Need that function!

			if abs(ship:verticalspeed) > targetVSpeed {
				set tval to throttlePID:Update(time:seconds, (ship:verticalspeed + targetVSpeed)).
			} else {
				set tval to 0.
			}

			print ("Vertical Speed " + abs(Ship:Verticalspeed)):padright(40) at (0,0).
			print ("Target VSpeed  " + TargetVSpeed):padright(40) at (0,1).
			print ("Throttle       " + tVal):padright(40) at (0,2).
			print ("Ship Velocity  " + ShipVelocity:mag):padright(40) at (0,3).
			print ("Ship Height    " + landRadarAltimeter()):padright(40) at (0,4).

			wait 0.
		}

		unlock throttle.
		unlock steering.
		set ship:control:pilotMainThrottle to 0.
		clearvecdraws().
		LADDERS on.
		SAS on.
		BAYS on.

		set mode to "Landed".
		wait 0.
	}
}
