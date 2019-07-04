@lazyglobal off.

copypath("0:/boot/crane.ks","1:/boot/crane.ks").

compile "0:/libmath.ks" to "1:/libmath.ksm".
compile "0:/liborbit.ks" to "1:/liborbit.ksm".
compile "0:/liborbit_interplanetary.ks" to "1:/liborbit_interplanetary.ksm".

copypath("0:/lib/comms.ks","1:/lib/comms.ks").
copypath("0:/libsimplex.ks","1:/libsimplex.ks").
copypath("0:/lib/node.ks","1:/lib/node.ks").
copypath("0:/lib/dock.ks","1:/lib/dock.ks").
copypath("0:/lib/ui.ks","1:/lib/ui.ks").

runoncepath("1:/lib/comms").
runoncepath("1:/libsimplex").
runoncepath("1:/lib/node").
runoncepath("1:/lib/dock").
runoncepath("1:/lib/ui.ks").

runoncepath("1:/liborbit_interplanetary").

// copypath("0:/launch_stellar_test.ks","1:/").

set core:bootfilename to "/boot/crane.ks".

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
	copypath("0:/boot/crane.ks","1:/boot/crane.ks").
	reboot.
}

local vesselList is List().
function FindUID {
	parameter UID.

	list targets in vesselList.
	for vess in vesselList {
		if vess:loaded and vess:unpacked {
			for part in vess:parts {
				if part:UID = UID { return List(part, vess). }
			}
		}
	}
	return List().
}

global data is Lexicon().
if core:volume:exists("data.json") {
	set data to readjson("1:/data.json").
}

if not data:haskey("mode") { set data["mode"] to "Landed". }
if not data:haskey("mother") { set data["mother"] to "Munport". }
if not data:haskey("base") { set data["base"] to "Munbase". }
if not data:haskey("mission") { set data["mission"] to "". }
if not data:haskey("MissionPortUID") { set data["MissionPortUID"] to "". }
if not data:haskey("cargo") { set data["cargo"] to "Experiment Module". }
if not data:haskey("flip") { set data["flip"] to 20. }
if not data:haskey("lat") { set data["lat"] to vessel(data["base"]):geoposition:lat. }
if not data:haskey("lon") { set data["lon"] to vessel(data["base"]):geoposition:lng. }
if not data:haskey("site") { set data["site"] to "". }
if not data:haskey("pad") { set data["pad"] to "". }
local pad is "".
if not data:haskey("slot") { set data["slot"] to "". }
local slot is "".
if not data:haskey("field") { set data["field"] to "". }
local field is "".
if not data:haskey("CommandQ") { set data["CommandQ"] to Queue(). }

print data.

writejson(data, "1:/data.json").
lock mode to data["mode"].

if mode = "Recover" and FindUID(data["MissionPortUID"])[1] = ship {
	set data["mode"] to "PlaneChange".
	set data["cargo"] to data["mission"].
	set data["mission"] to "".
}

local cap is ship:partstagged(core:tag + " Cap")[0].
local base is ship:partstagged(core:tag + " Base")[0].

global TRAddon is Addons:TR.

lock landingGeo to LatLng(data["lat"],data["lon"]).
lock landingPos to landingGeo:position.

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

	local apsisTime is time:seconds + inclinationBurn:eta + 0.25 * 
		inclinationBurn:orbit:period.
	local deorbitBurn is getApsisNodeAt(tuple[1], apsisTime). 
	return List(inclinationBurn, deorbitBurn).
}.

function tupleToIntercept {
	parameter tuple.
	local mother is vessel(data["mother"]).	
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

	print "Switching mode to " + newMode.
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
		local mother is vessel(data["mother"]).
		GetLambertInterceptNode(ship, mother, flightParams[1], flightParams[2], V(-100,0,0)). 
	} else if mode = "Finetune" {
		local mother is vessel(data["mother"]).
		if hasnode { remove nextnode. }
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
		local mother is vessel(data["mother"]).
		if hasnode { remove nextnode. }
		local closestApproachUT is getClosestApproach(ship, mother)[0].
		local node is getNode(velocityAt(ship, closestApproachUT):orbit, 
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
				local peri is nodes[1]:orbit:periapsis + landingGeo:terrainHeight.
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

		TRAddon:settarget(landingGeo).

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
		local cargoport is ship:partstagged(core:tag + " base")[0].
		cargoport:controlfrom.
		local mission is vessel(data["mission"]).
		local targetdock is mission:partstaggedpattern("bow")[0].
		set data["MissionPortUID"] to targetDock:UID.

		set hlFrom to highlight(cargoport,green).
		set hlTo to highlight(targetdock,red).

		set startPos to { return cargoport:nodeposition. }.
		set zeroVelocity to { return mission:velocity:orbit. }.
		set endPos to { return targetdock:nodeposition. }.
		set alignment to { return targetdock:portfacing. }.
		set targetfacing to { return lookdirup(-(targetdock:facing:vector), 
												targetdock:facing:upvector). }.

		set pathQueue to List(
			List(V(  0,  0,  1), 0.5, 0.2, XYZOffset@),
			List(V(  0,  0,  0), 0.2, 0.1, XYZOffset@)
		).

		local traversal is Traverse(mission, EndPos()).
		if traversal:length > 0 { for node in traversal {
			pathQueue:insert(0, node).
		}}

		on targetDock:state {
			print targetDock:state.
			return not targetDock:state:startswith("Docked").
		}

		set terminate to {
			parameter distance.
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
		local mother is vessel(data["mother"]).
		cap:controlFrom.

		local targetDock is "".
		for dock in mother:partstaggedpattern("Small Dock") {
			if dock:state = "Ready" { set targetDock to dock. }
		}
		if targetDock = "" { 
			for dock in mother:partstaggedpattern("Bow") {
				if dock:state = "Ready" and dock:nodetype = cap:nodetype {
					set targetDock to dock.
				}
			}
		}
		if targetDock = "" { 
			for dock in mother:dockingports {
				if port:nodetype = cap:nodetype {
					set targetdock to port.
				}
			}
		}

//		if base:state:startswith("Docked") {
//			local cargoDock is base:children[0].
//			if not cargoDock:istype("DockingPort") {
//				if base = ship:rootpart { set cargoDock to base:children[1]. }
//				else { set cargoDock to base:parent. }
//			}
//			local cargoDockUID is cargoDock:UID.
//			base:undock.
//			wait 0.

//			local cargoShip is FindUID(cargoDockUID)[1].
//			vessel(data["mother"]):connection:sendmessage(Lexicon("type", "klaw",
//				"mission", cargoShip:name,
//				"station", data["mother"],
//				"missionport", "Stern",
//				"stationport", "Module Dock"
//			)).
//		} 

		local hlSelf is highlight(cap, green).
		local hlDock is highlight(targetdock, red).

		set startPos to { return cap:nodeposition. }.

		set pathQueue to List(
			List(V(  0,  0, 10), 1.0, 0.5, XYZOffset@),
			List(V(  0,  0,  5), 1.0, 0.5, XYZOffset@),
			List(V(  0,  0,  1), 0.5, 0.2, XYZOffset@),
			List(V(  0,  0,0.5), 0.2, 0.2, XYZOffset@),
			List(V(  0,  0,0.1), 0.2, 0.1, XYZOffset@),
			List(V(  0,  0,0.0), 0.1, 0.1, XYZOffset@)
		).

		local traversal is Traverse(mother, endPos()).
		for node in traversal { pathQueue:insert(0, node). }

		set zeroVelocity to { return mother:velocity:orbit. }.
		set endPos to { return targetDock:nodePosition. }.
		set alignment to { return targetDock:portFacing. }.
		set targetFacing to { return lookdirup(-(targetdock:facing:vector), 
							  targetDock:facing:upVector). }.

		set terminate to {
			parameter distance.
			return ship <> vessel(data["mother"]).
		}.

		set rcsloop to true.

		dockInit().

	} else if mode = "LANDED" {
		//lock steering to up.
	} else if mode = "Boost" {
		core:part:controlfrom.
		if not (kuniverse:activevessel = ship) {
			set kuniverse:activevessel to ship.
			wait until kuniverse:activevessel = ship.
		}
		rcs on.
		lock throttle to stellarData[ship:body:name]["thrust"] / 100.
		print "Locking throttle".
		if ship:apoapsis < 6000 {
			lock steering to heading(90, 90).
			when ship:apoapsis > 6000 then {
				lock steering to heading(90, 0).
			}
		} else {
			lock steering to heading(90, 0).
		}

		when ship:apoapsis > vessel(data["mother"]):altitude then {
			lock throttle to 0.
			unlock steering.
			wait 0.
			if simulate { setMode("Coast"). }
			else { setMode("Intercept"). }
		}
	} else if mode = "Coast" {
		getApsisNodeAt(ship:apoapsis, time:seconds + eta:apoapsis).
	} else if mode = "InclinationBurn" {
		getMatchIncNode(vessel(data["mother"])).
	} else if mode = "Sleep" {
		core:part:getmodule("ModuleRCSFx"):setfield("RCS", false).
		if core:part:getmodule("ModuleReactionWheel"):hasAction("Deactivate Wheel") {
			core:part:getmodule("ModuleReactionWheel"):doAction("Deactivate Wheel",true).
		}
	}
}

set commsHandler to {
	parameter content.

	if mode = "Sleep" {
		if content:istype("string") and content = core:tag + " WAKE" {
			setMode("AWACT").
			core:part:getmodule("ModuleRCSFx"):setfield("RCS", true).
			if core:part:getModule("ModuleReactionWheel"):hasAction("Activate Wheel") {
				core:part:getmodule("ModuleReactionWheel"):doAction("Activate Wheel", true).
			}
			cap:undock.
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
		local contentParts to content:split(" ").
		if contentParts[1] = "At" {
			local landAt is vessel(contentParts[2]).
			set data["Base"] to contentParts[2].
			local site is "FIELD".
			for port in ship:dockingports {
				if port:state = "Ready" and 
					vdot(port:facing:vector, base:facing:vector) > 0.7
				{
					set site to "PAD".
				}
			}
			if site = "FIELD" and ship:partsnamed("MKS.FlexOTube"):length > 0 {
				set site to "SLOT".
			}
			set data["SITE"] to site.
			landAt:connection:sendmessage("REQUEST LANDING "+site+" "+core:tag).
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

local inputTime is 0.
until false {
			 //123456789012345
	printdata("Mode:"			, 02, mode).
	printData("Mother:"			, 03, data["mother"]).
	printData("Base:"			, 04, data["base"]).
	printData(" Pad:"			, 05, data["pad"]).

	printData("Lat:"			, 07, data["lat"]).
	printData("Long:"			, 08, data["lon"]).

	if mode:contains("Descent") {
		if ship:control:pilotyaw < -0.5 {
			if inputTime < time:seconds { set data["lon"] to lon - 0.001. }
			if inputTime = 0 { set inputTime to time:seconds + 1. }
		} else if ship:control:pilotyaw > 0.5 {
			if inputTime < time:seconds { set data["lon"] to lon + 0.001. }
			if inputTime = 0 { set inputTime to time:seconds + 1. }
		} else if ship:control:pilotpitch < -0.5 {
			if inputTime < time:seconds { set data["lat"] to lat - 0.001. }
			if inputTime = 0 { set inputTime to time:seconds + 1. }
		} else if ship:control:pilotpitch > 0.5 {
			if inputTime < time:seconds { set data["lat"] to lat + 0.001. }
			if inputTime = 0 { set inputTime to time:seconds + 1. }
		} else {
			set inputTime to 0.
		}
	}

	if mode = "Sleep" {
		wait 1.
	} else if mode = "Brake" {
		Match({ return landingGeo:altitudePosition(ship:altitude). },
			  { return landingGeo:altitudeVelocity(ship:altitude):orbit. }
		).
		setMode("Descent").
	} else if mode = "Based" {
		local deploy is true.
		for proc in ship:modulesnamed("kOSProcessor") {
			if proc:part:tag = data["base"] { set deploy to false. }
		}
		if deploy { 
			set data["mode"] to "Prelaunch".
			writejson(data, "1:/data.json").
			reboot.
		}
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
			local mother is vessel(data["mother"]).
			set stellarData[ship:body:name][launchLatitude][launchMass][targetAltitude] to 
			  clamp360(ship:longitude - mother:longitude).
			writejson(stellarData, "0:/stellar.json").
			wait 1.
			KUniverse:QuickloadFrom("Prelaunch").
		}

		writejson(data, "1:/data.json").
		wait 0.
	} else if (mode = "dock" and cap:state:startswith("Docked")) {
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
	} else if mode = "Prelaunch" {
		local mother is vessel(data["mother"]).
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
		// if simulate { KUniverse:Timewarp:Warpto(launchTime). }

		addAlarm("Maneuver",launchTime,ship:name + " Liftoff","").

		until time:seconds > launchTime {
			print ("Launch in: " + (launchTime - time:seconds)):padright(30) at (0,1).
			wait 0.
		}
		setMode("Boost").
		
	} else if mode = "Descent" { // Starts when brake complete. Ends 50m above target.
		local finalDescent is landingGeo:AltitudePosition(landingGeo:terrainheight + 50).
		if (data["Site"] = "Pad" and data["Pad"] = "") {
			local vessBase is vessel(data["Base"]).
			when vessBase:unpacked then {
				local padList is vessBase:partstaggedpattern("PAD").
				local tpad is "".
				for pad in padList { if pad:state = "Ready" { 
					set tpad to pad.
				} }
				if tpad = "" { set data["Site"] to "". }
				else {
					set data["pad"] to tpad:tag.
					lock landingPos to tpad:nodeposition.
					lock steering to lookdirup(sdir, tpad:facing:upvector).
				}
			}
		} else if (data["Site"] = "Slot" and data["Slot"] = "") {
			local vessBase is vessel(data["Base"]).
			when vessBase:unpacked then {
				local slotList is vessBase:partsNamed("MKS.FlexOTube").
				local slot is "".
				for tube in slotList {
					if tube:parent = "" or tube:children:empty {
						set slot to tube.
					}
				}
				if slot = "" { set data["slot"] to "". }
				else {
					local d is 5.
					set data["slot"] to slot:uid.
					lock landingPos to slot:position + slot:facing:vector * d.
					lock steering to lookdirup(sdir, slot:facing:vector).
				}
			}
		} else if (data["Site"] = "Field" and data["Field"] = "") {
			local vessBase is vessel(data["Base"]).
			when vessBase:unpacked then {
				local slotList is vessBase:partsNamed("MKS.FlexOTube").
				local slot is "".
				for tube in slotList {
					print tube.
					if tube:parent = "" or tube:children:empty {
						set slot to tube.
					}
				}
				if slot = "" { set data["slot"] to "". }
				else {
					local d is 5.
					set data["field"] to slot:uid.
					lock landingPos to slot:position + slot:facing:vector * d.
					lock steering to lookdirup(sdir, slot:facing:vector).
				}
			}
		}

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

		local sDir is ship:up:vector.
		lock steering to lookdirup(sDir, ship:facing:upvector).

		if data["pad"] = "slot" {
			local vessBase is vessel(data["Base"]).
			when vessBase:unpacked then {
				local slotList is vessBase:partsNamed("MKS.FlexOTube").
				local slot is "".
				for tube in slotList {
					if tube:parent = "" or tube:children:empty {
						set slot to tube.
					}
				}
				if slot = "" { set data["slot"] to "". }
				else {
					local d is 3.
					lock landingPos to slot:position + slot:facing:vector * d.
					lock steering to lookdirup(sdir, slot:facing:vector).
				}
			}
		}

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
			local targetVector is vxcl(ship:up:vector, landingPos).

			local hSpeedLimit is min(10, 0.5 * sqrt(targetVector:mag)).

			local slopeError is -slopePID:Update(time:seconds, targetVector:mag).
			local wantHVelocity is vxcl(ship:up:vector, landingPos) * slopeError.
			if wantHVelocity:mag > hSpeedLimit {
				 set wantHVelocity:mag to hSpeedLimit. 
			}

			local hVelocityCorrection is wantHVelocity - shipHVelocity.
			if hVelocityCorrection:mag > 4 {
				set hVelocityCorrection:mag to 4.
			}
			local steerVector is 10 * ship:up:vector + hVelocityCorrection.

			local drawlp is vecdraw(landingPos, ship:up:vector * 50, 
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

			set sDir to steerVector.
			local targetVSpeed to sqrt(abs(landRadarAltimeter() - 50)).
			if landRadarAltimeter() < 50 { set targetVSpeed to -targetVSpeed. }

			if targetVSpeed < 0 or abs(ship:verticalspeed) > targetVSpeed {
				set tval to throttlePID:Update(time:seconds, (ship:verticalspeed + targetVSpeed)).
			} else {
				set tval to 0.
			}
			//      123456789012345
			printData("Vertical Speed ", 30, abs(ship:verticalspeed)).
			printData("Target VSpeed: ", 31, targetVSpeed).
			printData("Throttle:",       32, tVal).
			printData("Ship Velocity:",  33, shipVelocity:mag).
			printData("Ship Height:",    34, landRadarAltimeter()).

			printData("Target Dist:",    36, targetVector:mag).
			printData("Want HVelocity:", 37, wantHVelocity:mag).
			printData("Act H Velocity:", 38, shipHVelocity:mag).

			printData("Height Error:",   40, abs(landRadarAltimeter() - 50)).
			
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
		local throttlePID is PIDLoop(0.30, 0.001, 0.01).
		set throttlePID:MaxOutput to 1.
		set throttlePID:MinOutput to 0.
		set throttlePid:Setpoint to 0.

		local tVal is 0.
		lock throttle to tVal.

		local sDir is ship:up:vector.
		lock steering to lookdirup(sDir, ship:facing:upvector).
		
		if data["Site"] = "Pad" and data["Pad"] <> "" {
			local pad is vessel(data["base"]):partsTagged(data["Pad"])[0].
			lock steering to lookdirup(sDir, pad:portfacing:upvector).
		} else if data["Site"] = "Slot" and data["Slot"] <> "" {
			local slot is findUID(data["Slot"])[0].
			lock steering to lookdirup(sdir, -slot:facing:vector).
		} else if data["Site"] = "Field" and data["Field"] <> "" {
			local field is findUID(data["Field"])[0].
			lock steering to lookdirup(sdir, field:position).
		} else if data["Site"] <> "" {
			set data["mode"] to "Descent". writejson(data, "1:/data.json"). reboot.
		}

		SAS off.
		RCS on.

		GEAR on.
		LIGHTS on.

		local touchdownSpeed is 0.


		clearscreen.

		local heightOffset is -vdot(findLowestPart():position, ship:facing:vector).

		local landRadarAltimeter  is {
			return max(0, ship:altitude - ship:geoposition:terrainheight - 2 * heightOffset).
		}.
		if data["Site"] = "Pad" {
			lock landingPos to vessel(data["base"]):partstagged(data["Pad"])[0]:nodeposition.
			local ownDock is "".
			for dock in ship:dockingports {
				if dock:istype("DockingPort") and
				   (not dock:state:startswith("Docked")) and 
				   vang(dock:portfacing:vector, ship:facing:vector) > 150
				{
					set ownDock to dock.
				}
			}
			set landRadarAltimeter to {
				return max(0.1, 0.2 + vdot(ownDock:nodePosition - landingPos, up:vector)).
			}.
		}


		until ship:status = "LANDED" {
			clearvecdraws().

			local speedLimit is max(0.5, 0.5 * sqrt(abs(landRadarAltimeter()))).

			local shipVelocity is ship:velocity:surface.
			local shipHVelocity is vxcl(ship:up:vector, shipVelocity).
			local wantHVelocity is vxcl(ship:up:vector, landingPos) * 0.5.
			if wantHVelocity:mag > speedLimit { set wantHVelocity:mag to speedLimit. }
			local targetVector is vxcl(ship:up:vector, landingPos).

			local hVelocityCorrection is wantHVelocity - shipHVelocity.
			local steerVector is 10 * ship:up:vector + hVelocityCorrection.

			local drawsv is vecdraw(v(0,0,0), SteerVector, red, "Steering", 1, true, 0.2).
			local drawv is vecdraw(v(0,0,0), ShipVelocity, green, "Velocity", 1, true, 0.2).
			local drawhv is vecdraw(v(0,0,0), ShipHVelocity, yellow, "Horizontal Velocity", 1, true, 0.2).
			local drawhsv is vecdraw(ShipHVelocity, hVelocityCorrection, red, "Desired Change", 1, true, 0.2).
			local drawtv is vecdraw(v(0,0,0), targetVector, magenta, "Target", 1, true, 0.2).

			set sDir to steerVector.
			local targetVSpeed is max(touchdownSpeed, 0.1 * sqrt(landRadarAltimeter())).

			if abs(ship:verticalspeed) > targetVSpeed {
				set tval to throttlePID:Update(time:seconds, 
											   (ship:verticalspeed + targetVSpeed)).
			} else {
				set tval to 0.
			}
			
			printData("Vertical Speed ", 30, abs(ship:verticalspeed)).
			printData("Target VSpeed: ", 31, targetVSpeed).
			printData("Throttle:",       32, tVal).
			printData("Ship Velocity:",  33, shipVelocity:mag).
			printData("Ship Height:",    34, landRadarAltimeter()).

			printData("Target Dist:",    36, targetVector:mag).
			printData("Want HVelocity:", 37, wantHVelocity:mag).
			printData("Act H Velocity:", 38, shipHVelocity:mag).

			printData("Height Error:",   40, abs(landRadarAltimeter() - 50)).
			wait 0.
		}

		clearvecdraws().
		unlock throttle.
		unlock steering.
		set ship:control:pilotMainThrottle to 0.

		LADDERS on.
		BAYS on.

		if data["Pad"] <> "" { 
			when ship:partstagged(data["base"]):length > 0 then { setMode("Based"). }
		}
		else { setMode("Landed"). }
		writejson(data, "1:/data.json").
		wait 0.
	} else if status = "Landed" and ship:velocity:surface:mag > 0.1 {
		set ship:control:translation to -ship:velocity:surface * ship:facing:inverse.
		rcs on.
	} else if status = "Landed" and (not data["base"] = "") and
		ship:partstagged(data["base"]):length > 0 {
		setMode("Based").
	} else if status = "Landed" {
		rcs off.
	} else {
		wait 1.
	}
}
