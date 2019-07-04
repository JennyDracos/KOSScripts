copypath("0:/boot/stellar.ks","1:/boot/stellar.ks").
//copypath("0:/lib_ui.ks","1:/lib_ui.ks").

compile "0:/libmath.ks" to "1:/libmath.ksm".
compile "0:/liborbit.ks" to "1:/liborbit.ksm".
compile "0:/liborbit_interplanetary.ks" to "1:/liborbit_interplanetary".

copypath("0:/lib/comms.ks","1:/lib/comms.ks").
copypath("0:/libsimplex.ks","1:/libsimplex.ks").
copypath("0:/lib/node.ks","1:/lib/node.ks").
copypath("0:/lib/dock.ks","1:/lib/dock.ks").
copypath("0:/lib/ui.ks","1:/lib/ui.ks").

runoncepath("1:/lib/comms").
runoncepath("1:/libsimplex").
runoncepath("1:/lib/node").
runoncepath("1:/lib/dock").
runoncepath("1:/liborbit_interplanetary").

copypath("0:/launch_stellar.ks","1:/launch_stellar.ks").
// copypath("0:/launch_stellar_test.ks","1:/").

set core:bootfilename to "/boot/stellar.ks".

wait 0.

// if ship:status = "prelaunch" { run launch_stellar_test. }

wait until ship:unpacked.

global data is 0.
local stellarData is readjson("0:/stellar.json").
local simulate is false.
local launchLatitude is 0.
local launchMass is 0.
local targetAltitude is 0.

local hlFrom is highlight(ship:rootpart, green).
set hlFrom:enabled to false.
local hlTo is highlight(ship:rootpart, red).
set hlTo:enabled to false.

on abort {
	runpath("0:/boot/stellar.ks").
}

if core:volume:exists("data.json") {
	set data to readjson("1:/data.json").
} else {
	set data to Lexicon().
}



if not data:haskey("mode") { set data["mode"] to "Landed". }
if not data:haskey("mother") { set data["mother"] to "KH Highport". }
if not data:haskey("mission") { set data["mission"] to "". }
if not data:haskey("cargo") { set data["cargo"] to "Experiment Module". }
if not data:haskey("flip") { set data["flip"] to 20. }
if not data:haskey("lat") { set data["lat"] to 0. }
if not data:haskey("lon") { set data["lon"] to 0. }

writejson(data, "1:/data.json").

lock mother to vessel(data["mother"]).
lock mission to data["mission"].
lock cargo to data["cargo"].
lock mode to data["mode"].

local nose is ship:partstagged("nose")[0].

global TRAddon is Addons:TR.

lock landingPos to LatLng(data["lat"],data["lon"]).
local rcsLoop is false.

clearscreen.

until not hasnode {
	remove nextnode.
		wait 0.
}

function FindLowestPart {
	local lowestpart is ship:rootpart.
		local vh to vdot(lowestpart:position, ship:facing:vector).
		for p in ship:parts {
			local tmp is vdot(p:position, ship:facing:vector).
				if tmp < vh {
					set lowestpart to p.
						set vh to tmp.
				}
		}
	return lowestpart.
}

function tupleToDeorbit {
	parameter tuple.

	// preLan is longitude of ascending node for orbit over destination.
	// this is 90 degrees before longitude of landing site when lat < 0, 270 for lat > 0.
	local newInc is abs(data["lat"]).
	local preLan is data["lon"] - 90.
	if data["lat"] < 0 { set preLan to preLan - 180. }

	// Problem is this needs to be compensated because LAN is based on solar prime vector.
	set preLan to preLan + ship:body:rotationAngle.

	// Also needs to be compensated for flight time.
	local apoHeight is ship:apoapsis + ship:body:radius.
	local periHeight is tuple[1] + ship:body:radius.
	local sma is (apoHeight + periHeight) / 2.
	local descentFlightTime is pi * sqrt(sma * sma * sma / ship:body:mu).
	local deltaAngle is descentFlightTime / ship:body:rotationperiod * 360.

	set preLan to preLan + deltaAngle.

	local ta_an to clamp360(preLan - ship:obt:argumentofperiapsis - ship:obt:lan).
	if data["lat"] > 0 {
		set ta_an to clamp360(ta_an - 180).
		set newInc to -1 * newInc.
		print "switching to DN".
	}
	local ut_an to time:seconds + getEtaTrueAnomOrbitable(ta_an, ship).

	local startV is velocityAt(ship, ut_an):orbit.
	local incDV is (2 * startV * sin(newInc / 2)):mag.
	if newInc < 0 { set incDV to -incDV. }
	local r1 is positionAt(ship, ut_an).

	//	local inclinationBurn is getNodeDV(startV, incDV, r1, ut_an).
	local inclinationBurn is node(ut_an, 0, incDV * cos(newInc), incDV * sin(-newInc)).
	add inclinationBurn.

	set apsisTime to time:seconds + inclinationBurn:eta + 0.25 * 
		inclinationBurn:orbit:period.
	local deorbitBurn is getApsisNodeAt(tuple[1], apsisTime). 
	return List(inclinationBurn, deorbitBurn).
}.

function tupleToIntercept {
	parameter tuple.
	
	local boost is GetLambertInterceptNode(ship, mother, tuple[1], tuple[2], V(-100,0,0)).

	local match is (VelocityAt(ship, tuple[0] + tuple[1]):orbit - VelocityAt(mother, tuple[0] + tuple[1]):orbit):mag.

	local cost is boost:deltaV:mag * boost:deltaV:mag + match * match.

	remove boost.

	return cost.
}

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

function setMode {
	parameter newMode.

	print "Switching mode to " + mode.
	set data["mode"] to newMode.
	writejson(data, "1:/data.json").

	if rcsLoop {
		set rcsLoop to false.
		DockFinal().
	}

	if mode = "Intercept" {
		if hasnode { remove nextnode. }
		local flightParams is PatternSearch(
			List(time:seconds + 30, eta:apoapsis),
			tupleToIntercept@,
			10,
			0.1
		).
		GetLambertInterceptNode(ship, mother, flightParams[1], flightParams[2], V(-100,0,0)). 
	} else if mode = "Finetune" {
		set target to mother.
		if hasnode { remove nextnode. }
		set target to mother.
		local flightParams is PatternSearch(
			List(time:seconds + 30, eta:apoapsis),
			{
				parameter tuple.

				if tuple[1] < time:seconds + data["flip"] { return 1e10. }
				local nd is GetLambertInterceptNode(ship, mother, 
					tuple[1], tuple[2], V(-100, 0, 0)).
				local err is nd:deltaV:mag.
				remove nd.

				print err.

				return err.
			},
			200,
			0.1
		).
		local tune is GetLambertInterceptNode(ship, mother, 
			flightParams[1], flightParams[2], V(-100, 0, 0)).
		if tune:deltaV:mag < 0.1 { setMode("Match"). }
	} else if mode = "Match" {
		if hasnode { remove nextnode. }
		local closestApproachUT is getClosestApproach(ship, mother)[0].
		set node to getNode(velocityAt(ship, closestApproachUT):orbit, 
									   velocityAt(mother, closestApproachUT):orbit,
		positionAt(ship, closestApproachUT)- ship:body:position, closestApproachUT).
		add node.
	} else if mode = "planeChange" {
		local dualBurn is PatternSearch(
			List(5000),
			{
				parameter tuple.

				local nodes is tupleToDeorbit(tuple).
				local deorbitBurn is nodes[1].

				wait 0.1.
				local peri is nodes[1]:orbit:periapsis + landingPos:terrainHeight.
				remove nodes[1].
				remove nodes[0].
				if peri < 500 {
					local err is 1e6 + (500 - peri).
					print "Need more height! " + err.
					return err.
				} else if TRAddon:hasImpact {
					local err is 1e7 + (500 - peri).
					print "Splat! " + err.
					return err.
				}
				return peri.
			},
			100,
			1
		).

		local nodes is tupleToDeorbit(dualBurn).
		set data["finalAlt"] to dualBurn[0].

	} else if mode = "Deorbit" {
		until not hasnode {
			remove nextnode.
				wait 0.
		}
		// ta_apo is 90 degrees after LAN for lat < 0, 90 degrees before LAN for lat > 0.
		// ta_lan is 360 - aop.
		local ta_lan is 360 - ship:orbit:argumentofperiapsis.
		local ta_apo is ta_lan + 90.
		if data["lat"] > 0 { set ta_apo to ta_apo - 180. }
		set ta_apo to clamp360(ta_apo).

		local apotime is time:seconds + getETATrueAnom(ta_apo).

		local apo is (positionat(ship, apoTime) - ship:body:position):mag.
		local peri is data["finalAlt"] + ship:body:radius.
		local sma is (apo + peri) / 2.
			
		local descentFlightTime is pi * sqrt(sma * sma * sma / ship:body:mu).

		local deorbitBurn is getApsisNodeAt(data["finalAlt"], apoTime).

		local brakeTime is apoTime + descentFlightTime.
		local brakeBurn is node(brakeTime, 0, 0, -velocityAt(ship, brakeTime):orbit:mag).
		add brakeBurn.

	} else if false and mode = "Brake" {

		TRAddon:settarget(landingPos).

		if hasnode { remove nextnode. }

		local burnTime is PatternSearch(
			List(time:seconds + eta:periapsis),
			{
			parameter tuple.

			local brakeNode is node(tuple[1], 0, 0,
					-(velocityat(ship, tuple[1]):orbit:mag)).

			add brakeNode.

			wait 0.1.
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

		set hlFrom to highlight(cargoport,green).
		set hlTo to highlight(targetdock,red).

		set startPos to { return cargoport:nodeposition. }.
		set zeroVelocity to { return vessel(mission):velocity:orbit. }.
		set endPosition to { return targetdock:nodeposition. }.
		set alignment to { return targetdock:portfacing. }.
		set targetfacing to { return lookdirup(-(targetdock:facing:vector), 
												targetdock:facing:upvector). }.

		set pathQueue to List(
			List(V(  0,-10,0.5), 0.2, 0.5, XYZOffset@),
			List(V(  0, -5,0.5), 0.2, 0.1, XYZOffset@),
			List(V(  0, -3,0.5), 0.2, 0.1, XYZOffset@),
			List(V(  0, -2,0.5), 0.2, 0.1, XYZOffset@),
			List(V(  0, -1,0.5), 0.2, 0.1, XYZOffset@),
			List(V(  0,  0,0.5), 0.2, 0.1, XYZOffset@),
			List(V(  0,  0,  0), 0.1, 0.1, XYZOffset@)
		).

		set traversal to Traverse(vessel(mission), XYZOffset(V(0,-10,0.3))).
		if traversal:length > 0 { for node in traversal {
			pathQueue:insert(0, node).
		}}

		set rcsloop to true.
		set terminate to {
			if targetDock:state:startswith("Acquire") {
				set hlFrom:enabled to false.
				set hlTo:enabled to false.
				bays off.
				set data["cargo"] to data["mission"].
				set data["mission"] to "".
				when targetDock:state:startsWith("Docked") then {
					print "Docked!".
					setMode("PlaneChange").
				}
				return false.
			} else { return true. }
		}.
		dockInit().
	} else if mode = "Park" {
		set cargoport to ship:partstagged("cargo fore")[0].
		cargoport:controlfrom.

		set speedcap to 0.1.

		set targetdock to "".
		for port in vessel(mission):dockingports {
			if port:nodetype = cargoport:nodetype {
				set targetdock to port.
			}
		}

		set startPos to { return cargoport:nodeposition. }.
		set zeroVelocity to { return vessel(mission):velocity:orbit. }.
		set endPosition to { return targetdock:nodeposition. }.
		set alignment to { return targetdock:portfacing. }.
		set targetfacing to { return lookdirup(-(targetdock:facing:vector), targetdock:facing:upvector). }.

		set pathQueue to List(
			List(V(  0,-10,0.3), 0.2, 0.5, XYZOffset@)
		).

		set traversal to Traverse(vessel(mission), XYZOffset(V(0,-10,0.3))).
		if traversal:length > 0 { for node in traversal {
			pathQueue:insert(0, node).
		}}

		set rcsloop to true.
		set terminate to { return true. }.
		dockInit().

	} else if mode = "Dock" {
		nose:controlFrom.
		if nose:getmodule("moduleanimategeneric"):hasEvent("Open Shield") {
			nose:getmodule("moduleanimategeneric"):doEvent("Open Shield").
		 }

		set targetDock to "".
		for dock in mother:partstaggedpattern("Small Dock") {
			if dock:state = "Ready" { set targetDock to dock. }
		}
		if targetDock = "" { 
			for dock in mother:partstaggedpattern("Bow") {
				if dock:state = "Ready" and dock:nodetype = nose:nodetype {
					set targetDock to dock.
				}
			}
		}
		if targetDock = "" { 
			for dock in mother:dockingports {
				if port:nodetype = nose:nodetype {
					set targetdock to port.
				}
			}
		}

		local hlSelf is highlight(nose, green).
		local hlDock is highlight(targetdock, red).

		set startPos to { return nose:nodeposition. }.
		set zeroVelocity to { return mother:velocity:orbit. }.
		set endPosition to { return targetDock:nodePosition. }.
		set alignment to { return targetDock:portFacing. }.
		set targetFacing to { return lookdirup(-(targetdock:facing:vector), 
							  targetDock:facing:upVector). }.

		set transform to XYZOffset@.
		
		set pathQueue to List(
			List(V(  0,  0, 10), 1.0, 0.5, transform),
			List(V(  0,  0,  5), 1.0, 0.5, transform),
			List(V(  0,  0,  1), 0.5, 0.2, transform),
			List(V(  0,  0,0.5), 0.2, 0.2, transform),
			List(V(  0,  0,0.1), 0.2, 0.1, transform),
			List(V(  0,  0,0.0), 0.1, 0.1, transform)
		).

		local traversal is Traverse(mother, endPosition()).
		for node in traversal { pathQueue:insert(0, node). }

		set terminate to {
			return true.
		}.

		set rcsloop to true.

		dockInit().

	} else if mode = "LANDED" {
		lock steering to up.
	} else if mode = "Boost" {
		rcs on.
		lock throttle to stellarData[ship:body:name]["thrust"] / 100.
		lock steering to heading(90, 0).

		when ship:apoapsis > mother:altitude then {
			lock throttle to 0.
			unlock steering.

			if simulate { setMode("Coast"). }
			else { setMode("Intercept"). }
		}
	} else if mode = "Coast" {
		getApsisNodeAt(ship:apoapsis, time:seconds + eta:apoapsis).
	} else if mode = "InclinationBurn" {
		getMatchIncNode(mother).
	}
}

set commsHandler to {
	parameter content.

		if mode = "Sleep" {
			if content:istype("string") and content = core:tag + " WAKE" {
				setMode("Wake").
			}
		} else if content:istype("Lexicon") {
			if not content:haskey("type") {
				print "Malformed message.".
			} else if content["type"] <> "Stellar" {
				print "Misdirected message.".
			} else if content["task"] = "Recover" {
				set data["mission"] to content["mission"].
				setMode("Recover").
			} else {
				print "No handler for complex messages.".
			}
		} else if content:startswith("SETN ") {
			local contentParts to content:split(" ").
			set data[contentParts[1]] to contentParts[2]:tonumber(0).
		} else if content:startswith("SET ") {
			local contentParts to content:split(" ").
			local header is "SET " + contentParts[1] + " ".
			set data[contentParts[1]] to content:replace(header, "").
		} else if content:startswith("RECOVER ") {
			set data["mission"] to content:replace("RECOVER ","").
			setMode("Recover").
		} else if content:startswith("PARK ") {
			set data["mission"] to content:replace("PARK ","").
			setMode("Park").
		} else if content:startswith("LAND ") {
			set contentParts to content:split(" ").
			if contentParts[1] = "At" {
				local landAt is vessel(contentParts[2]).
				set data["lat"] to landAt:geoposition:lat.
				set data["lon"] to landAt:geoposition:lng.
			} else if contentParts[1] = "Here" {
				set data["lat"] to ship:geoposition:lat.
				set data["lon"] to ship:geoposition:lng.
			} else {
				set data["lat"] to contentParts[1]:tonumber(0).
				set data["lon"] to contentParts[2]:tonumber(0).
			}
			setMode("PlaneChange").
		} else {
			print "No handler for " + content.
		}

	writejson(data, "1:/data.json").
}.

setMode(mode).

until false {

	if mode = "Sleep" {
		wait 1.
	} else if mode = "Brake" {
		Match({ return landingPos:altitudePosition(ship:altitude). },
			  { return landingPos:altitudeVelocity(ship:altitude):orbit. }
		).
		setMode("Descent").
	} else if hasNode {
		core:part:controlFrom.
		rcs on.
		if mode = "Brake" {
			AlignForBurn(nextNode).
			MainBurn(nextNode, false).
			remove nextnode.
		} else {
			RunNode(nextNode).
		}

		if mode = "Intercept" {
			setMode("Finetune").
		} else if mode = "Finetune" {
			setMode("Finetune").
		} else if mode = "Match" {
			setMode("Dock").
		} else if mode = "PlaneChange" {
			setMode("Deorbit").
		} else if mode = "Deorbit" {
			setMode("Brake").
		} else if mode = "Brake" {
			setMode("Descent").
		} else if mode = "Coast" {
			setMode("InclinationBurn").
		} else if mode = "InclinationBurn" {
			set stellarData[ship:body:name][launchLatitude][launchMass][targetAltitude] to 
			  clamp360(ship:longitude - mother:longitude).
			writejson(stellarData, "0:/stellar.json").
			wait 1.
			KUniverse:QuickloadFrom("Prelaunch").
		}

		writejson(data, "1:/data.json").
		wait 0.
	} else if (mode = "dock" and nose:state:startswith("Docked")) {
		// You deed it!
		BAYS on.
		setMode("Sleep").
		unlock steering.
		set ship:control:neutralize to true.
		rcs off.
		set rcsloop to false.
		wait 0.
	} else if rcsLoop {
		set rcsLoop to dockUpdate().
		wait 0.1.
	} else if mode = "Landed" and bays = false {
		setMode("Prelaunch").
		wait 0.
	} else if mode = "Prelaunch" and ship:body:atm:exists {
		runpath("1:/launch_stellar",data["mother"]).
		setMode("Intercept").
		writejson(data, "1:/data.json").
	} else if mode = "Prelaunch" {
		if not stellarData:haskey(ship:body:name) { set stellarData[ship:body:name] to Lexicon("thrust",100). }
		set launchLatitude to round(ship:geoposition:lat, 1).
		if not stellarData[ship:body:name]:haskey(launchLatitude) {
			set stellarData[ship:body:name][launchLatitude] to Lexicon(). }
		set launchMass to round(ship:mass, 1).
		if not stellarData[ship:body:name][launchLatitude]:haskey(launchMass) {
			set stellarData[ship:body:name][launchLatitude][launchMass] to Lexicon(). }
		set targetAltitude to round(mother:altitude / 1000, 0) * 1000.
		if not stellarData[ship:body:name][launchLatitude][launchMass]:haskey(targetAltitude) {
			set stellarData[ship:body:name][launchLatitude][launchMass][targetAltitude] to 361. }

		writejson(stellarData, "0:/stellar.json").
	
		local longitudeOffset is stellarData[ship:body:name][launchLatitude][launchMass][targetAltitude].
		if longitudeOffset > 360 {
			wait 0.
			set simulate to true.
			set longitudeOffset to 0.
			KUniverse:QuicksaveTo("Prelaunch").
			print "Simulating Launch".
		}

		local launchTime is time:seconds + TimeToLong(longitudeOffset, mother).
		if simulate { KUniverse:Timewarp:Warpto(launchTime). }

		addAlarm("Maneuver",launchTime,ship:name + " Liftoff","").

		until time:seconds > launchTime {
			print ("Launch in: " + (launchTime - time:seconds)):padright(30) at (0,1).
			wait 0.
		}

		setMode("Boost").
		
	} else if mode = "Descent" { // Starts when brake complete. Ends 150m above target.
		local finalDescent is landingPos:AltitudePosition(landingPos:terrainheight + 150).

		local throttlePID is PIDLoop(0.04, 0.001, 0.01).
		set throttlePID:MaxOutput to 1.
		set throttlePID:MinOutput to 0.
		set throttlePid:Setpoint to 0.

		local slopePID is PIDLoop(0.04, 0.04, 0.03).
		set slopePID:MaxOutput to 0.5.
		set slopePID:MinOutput to -0.5.
		set slopePID:Setpoint to 0.

		local tVal is 0.
		lock throttle to tVal.

		local sDir is ship:up.
		lock steering to sDir.

		SAS off.
		RCS on.

		local touchdownSpeed is 0.2.


		clearscreen.

		function landRadarAltimeter {
			return ship:altitude - ship:geoposition:terrainheight.
		}

		local complete is false.
		until complete {
			clearvecdraws().

			local speedLimit is max(50, sqrt(abs(landRadarAltimeter() - 50))).

			local shipVelocity is ship:velocity:surface.
			local shipHVelocity is vxcl(ship:up:vector, shipVelocity).
			local targetVector is vxcl(ship:up:vector, landingPos:position).

			local hSpeedLimit is min(10, 0.5 * sqrt(targetVector:mag)).

			local slopeError is -slopePID:Update(time:seconds, targetVector:mag).
			local wantHVelocity is vxcl(ship:up:vector, landingPos:position) * slopeError.
			if wantHVelocity:mag > hSpeedLimit {
				 set wantHVelocity:mag to hSpeedLimit. 
			}

			local hVelocityCorrection is wantHVelocity - shipHVelocity.
			if hVelocityCorrection:mag > 4 {
				set hVelocityCorrection:mag to 4.
			}
			local steerVector is 10 * ship:up:vector + hVelocityCorrection.

			local drawlp is vecdraw(landingPos:position, finalDescent, 
									green, "Landing Position", 1, true, 0.2).
			local drawsv is vecdraw(v(0,0,0), SteerVector, 
									red, "Steering", 1, true, 0.2).
			local drawv is vecdraw(v(0,0,0), ShipVelocity, 
									green, "Velocity", 1, true, 0.2).
			local drawhv is vecdraw(v(0,0,0), ShipHVelocity, 
									yellow, "Horizontal Velocity", 1, true, 0.2).
			local drawhsv is vecdraw(ShipHVelocity, hVelocityCorrection, 
									red, "Desired Change", 1, true, 0.2).
			local drawtv is vecdraw(v(0,0,0), targetVector, 
									magenta, "Target", 1, true, 0.2).

			set sDir to steerVector:direction.
			set targetVSpeed to sqrt(abs(landRadarAltimeter() - 50)).
			if landRadarAltimeter() < 50 { set targetVSpeed to -targetVSpeed. }

			if targetVSpeed < 0 or abs(ship:verticalspeed) > targetVSpeed {
				set tval to throttlePID:Update(time:seconds, (ship:verticalspeed + targetVSpeed)).
			} else {
				set tval to 0.
			}

			print ("Vertical Speed " + abs(Ship:Verticalspeed)):padright(40) at (0,0).
			print ("Target VSpeed  " + TargetVSpeed):padright(40) at (0,1).
			print ("Throttle       " + tVal):padright(40) at (0,2).
			print ("Ship Velocity  " + ShipVelocity:mag):padright(40) at (0,3).
			print ("Ship Height    " + landRadarAltimeter()):padright(40) at (0,4).

			print ("Target Dist    " + targetVector:mag    ):padright(40) at (0,6).
			print ("Want H Vel     " + wantHVelocity:mag   ):padright(40) at (0,7).
			print ("Act H Velocity " + shipHVelocity:mag   ):padright(40) at (0,8).
		
			print ("Height Error   " + abs(landRadarAltimeter() - 50)):padright(40) at (0,10).
			
			set complete to 
			  shipHVelocity:mag < 1.0 and
			  targetVector:mag < 1.0 and
			  abs(landRadarAltimeter() - 50) < 1.0.

			wait 0.
		}

		clearvecdraws().
		unlock throttle.
		unlock steering.
		set ship:control:pilotMainThrottle to 0.
		clearvecdraws().

		setMode("Terminal").
		writejson(data, "1:/data.json").
		wait 0.
	} else if mode = "Terminal" {
		local finalDescent is landingPos:AltitudePosition(landingPos:terrainheight + 150).

		local throttlePID is PIDLoop(0.04, 0.001, 0.01).
		set throttlePID:MaxOutput to 1.
		set throttlePID:MinOutput to 0.
		set throttlePid:Setpoint to 0.

		local tVal is 0.
		lock throttle to tVal.

		local sDir is ship:up.
		lock steering to sDir.

		SAS off.
		RCS on.

		GEAR on.
		LIGHTS on.

		local touchdownSpeed is 0.


		clearscreen.

		local heightOffset is -vdot(findLowestPart():position, ship:facing:vector).

		function landRadarAltimeter {
			return max(0, ship:altitude - ship:geoposition:terrainheight - 2 * heightOffset).
		}

		until ship:status = "LANDED" {
			clearvecdraws().

			local speedLimit is max(0.2, 0.5 * sqrt(abs(landRadarAltimeter()))).

			local shipVelocity is ship:velocity:surface.
			local shipHVelocity is vxcl(ship:up:vector, shipVelocity).
			local wantHVelocity is vxcl(ship:up:vector, landingPos:position) * 0.5.
			if wantHVelocity:mag > speedLimit { set wantHVelocity:mag to speedLimit. }
			local targetVector is vxcl(ship:up:vector, landingPos:position).

			local hVelocityCorrection is wantHVelocity - shipHVelocity.
			local steerVector is 10 * ship:up:vector + hVelocityCorrection.

			local drawsv is vecdraw(v(0,0,0), SteerVector, red, "Steering", 1, true, 0.2).
			local drawv is vecdraw(v(0,0,0), ShipVelocity, green, "Velocity", 1, true, 0.2).
			local drawhv is vecdraw(v(0,0,0), ShipHVelocity, yellow, "Horizontal Velocity", 1, true, 0.2).
			local drawhsv is vecdraw(ShipHVelocity, hVelocityCorrection, red, "Desired Change", 1, true, 0.2).
			local drawtv is vecdraw(v(0,0,0), targetVector, magenta, "Target", 1, true, 0.2).

			set sDir to steerVector:direction.
			set targetVSpeed to max(touchdownSpeed, sqrt(landRadarAltimeter())).

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

		clearvecdraws().
		unlock throttle.
		unlock steering.
		set ship:control:pilotMainThrottle to 0.

		LADDERS on.
		BAYS on.

		setMode("Landed").
		writejson(data, "1:/data.json").
		wait 0.
	} else if status = "Landed" and ship:velocity:surface:mag > 0.1 {
		set ship:control:translation to -ship:velocity:surface * ship:facing:inverse.
		rcs on.
	} else {
		wait 1.
	}
}
