 
copypath("0:/boot/kind.ks","1:/boot/").
copypath("0:/launch_kindj.ks","1:/").
copypath("0:/lib_ui.ks","1:/").
copypath("0:/warp","1:/").
copypath("0:/aeroland.ks","1:/").
copypath("0:/pilot.ks","1:/").
copypath("0:/lib_pid.ks","1:/").

copypath("0:/lamintercept.ks","1:/").
copypath("0:/libmath.ks","1:/").
copypath("0:/libdeltav.ks","1:/").
copypath("0:/liblanding.ks","1:/").
copypath("0:/liborbit.ks","1:/").
copypath("0:/liborbit_interplanetary.ks","1:/").
copypath("0:/libsimplex.ks","1:/").

copypath("0:/lib/node.ks", "1:/lib/node.ks").
copypath("0:/lib/ui.ks", "1:/lib/ui.ks").

copypath("0:/libdock.ks", "1:/").

copypath("0:/boot/kindtemp.ks","1:/boot/").

runoncepath("1:/lib/ui").
runoncepath("1:/lib/node.ks").
runoncepath("1:/lamintercept.ks").
runoncepath("1:/libsimplex.ks").
runoncepath("1:/libdock.ks").

set core:bootfilename to "/boot/kindtemp.ks".

on abort {
	copypath("0:/boot/kind.ks","1:/").
	writejson(data, "1:/data.json").
	reboot.
}

global data is 0.
if core:volume:exists("data.json") {
	set data to readjson("1:/data.json").
	set data["rcsloop"] to false.
} else {

	set data to Lexicon(
		"mission",	"Cargo",
		"station",	"KH Highport",
		"missionport",	"",
		"stationport",	"DockingPortLarge",
		"phase",	"Prelaunch",
		"rcsloop",  false,
		"klaws",	true).
}

lock mission to data["mission"].
lock station to vessel(data["station"]).
lock klaws to data["klaws"].
lock phase to data["phase"].
local speedcap is 1.0.
lock rcsloop to data["rcsloop"].

print "Standing up with data: "+data.

if not data:haskey("class") {
	local database is readjson("0:/spaceplane.json").
	if ship:name:startswith("Kindjal") {
		data:add("count", database["kindjal"]).
		set database["kindjal"] to database["kindjal"] + 1.
		data:add("class", "KJ").
		data:add("burnup", 2200).
		set ship:name to ship:name:replace("Kindjal ", "").
	} else if ship:name:startswith("Claymore") {

		data:add("count", database["claymore"]).
		set database["claymore"] to database["claymore"] + 1.
		data:add("class", "CL").
		data:add("burnup", 1800).
		set ship:name to ship:name:replace("Claymore ", "").
	} else if ship:name:startswith("Scimitar") {
		data:add("count", database["scimitar"]).
		set database["scimitar"] to database["scimitar"] + 1.
		data:add("class", "SC").
		data:add("burnup", 2600).
		set ship:name to ship:name:replace("Scimitar ", "").
	} else {
		print "Unrecognized class.  Expect crash.".
	}
	local tags is ship:name:split("-").
	if tags[0]:startswith("Direct") {
		set data["station"] to "KH Highport".
		set tags[0] to tags[0]:replace("Direct ", "").
	}
	set data["mission"] to tags[0].
	if tags:length = 2 { set data["stationport"] to tags[1]. }
	else if tags:length = 3 {
		set data["missionport"] to tags[1].
		set data["stationport"] to tags[2].
	}
	set ship:name to data["class"]+"-"+data["count"]+" "+data["mission"].
	set core:part:tag to "KJ-"+data["count"]+" Core".
	writejson(database, "0:/spaceplane.json").
} else {
	if ship:name:startswith("Kindjal") or ship:name:startswith("Claymore") {
		if data["mission"] = "" {
			set ship:name to data["class"] + "-" + data["count"].
		} else {
			set ship:name to data["class"] + "-" + data["count"] + " " + data["mission"].
		}
	}
}

if ship:status = "prelaunch" { 
	setPhase("Prelaunch").
	writejson(data, "1:/data.json").
	run launch_kindj(data["station"]).
	setPhase("Intercept").
	writejson(data, "1:/data.json").
	reboot.
} else {
	runpath("1:/liblanding.ks").
}


if data["phase"] = "Land" {
	local enginelist is list().
	list engines in enginelist.
	for engine in enginelist {
		if not engine:multimode { engine:shutdown. }
		else { set engine:primarymode to true. }
	}
	unlock throttle.
	unlock steering.
	set ship:control:neutralize to true.
	if ship:longitude > -74 { 
		runpath("1:/pilot.ks","KSCReverse",45,120).
	} else {
		runpath("1:/pilot.ks","KSC",45,120).
	}
} else if ship:status = "flying" and ship:altitude < 10000 { 
	setPhase("land").	
}

local cargofore is "".
local cargoaft is "".

local dock is 0.

wait until ship:loaded() and ship:unpacked().

// Iterate through all parts on the ship.
set planeParts to list().
// Updated part recognition.  Start by gathering all elements in the ship.
set element to queue().
set iterator to core:part.
until (iterator:hasparent = false) or (iterator:istype("dockingport")) or (iterator:name = "grapplingdevice") {
	set iterator to iterator:parent.
}
if iterator:hasparent { for child in iterator:children { element:push(child). } }
element:push(iterator).
until element:empty {
	set iterator to element:pop.
	if iterator:name = "dockingport1" { set dock to iterator. }
	else if iterator:name = "dockingportLarge" and vang(iterator:facing:vector, core:part:facing:vector) < 0.1 { 
		if iterator:children:length > 0 { 
			if iterator:children[0]:resources:length > 0 {
				set cargoaft to "fuel".
			} else { set cargoaft to "cargo". }
		}
	} else if iterator:name = "dockingportLarge" or iterator:name = "dockingport2" {
		if iterator:children:length > 0 {
			if iterator:children[0]:resources:length > 0 {
				set cargofore to "fuel".
			} else { set cargofore to "cargo". }
		}
	} else if iterator:name = "rocketnosecone" {
		set nosetempstate to iterator:getmodule("parttemperaturestate").
		lock nosetemp to nosetempstate:getfield(nosetempstate:allfieldnames[1]):split("/")[0]:tonumber().
	}
 	else { for child in iterator:children { element:push(child). } }
}

local tank is ship:partsdubbed("Refuel").

local targetdock is "".


local dockpath is List().
local targetoffset is 0.
local tolerance is 1.

on ship:name {
	if ship:name:startswith("Claymore") 
		or ship:name:startswith("Kindjal") 
		or ship:name:startswith("Scimitar")
		or ship:name:startswith("[Claymore]")
		or ship:name:startswith("[Kindjal]") {
		
		set ship:name to data["class"]+"-"+data["count"].
		if data["mission"] <> "" { set ship:name to ship:name+" "+data["mission"]. }
	}

	return true.
}

when not ship:messages:empty then {
	set message to ship:messages:pop.
	for processor in ship:modulesnamed("kosprocessor") {
		processor:connection:sendmessage(message:content).
	}
	return true.
}

when not core:messages:empty then {
	set message to core:messages:pop():content.

	print "Recieved message " + message.

	if message:istype("Lexicon") {
		if message:haskey("type") and message["type"] = "Kind" {

			set data["mission"] to message["mission"].
			
			if message:haskey("missionport") {
				set data["missionport"] to message["missionport"]. }
			
			setPhase("Recover").

		}

	} else if message = "KLAW DOCKED" {
		if cargoaft = "cargo" {
			station:connection:sendmessage("KIND AWAITING KLAW").
			setPhase("parking").
		} else {
			station:connection:sendmessage("KIND ON APPROACH").
			setPhase("Dock").
		}
	} else if message = "STAND BY FOR CARGO" {
		set data["retrieve"] to true.
		set data["klaws"] to false.
		if data["mission"] = "Refueler" { setPhase("Dock"). }
		else { setPhase("release"). }
	} else if message = "BYE" {
		if data["phase"] = "Release" { setPhase("PreRTB"). } 
	}

	writejson(data, "1:/data.json").

	return true.
}

function setPhase {
	parameter newPhase.

	print "Updating phase to " + newPhase.
	set data["phase"] to newPhase.

	until hasNode = false {
		print "Clearing node.".
		remove nextnode.
		wait 0.
	}

	if phase = "Land" {
		writejson(data, "1:/data.json").
		reboot.
	}

	if phase = "Intercept" {
		RecalcEngines().
		set target to vessel(data["station"]).
		if hasnode { remove nextnode. }
		local flightParams is PatternSearch(
			List(time:seconds + 30, eta:apoapsis),
			{
				parameter tuple.
				local nd is GetLambertInterceptNode(
							ship, 
							target, 
							tuple[1], 
							tuple[2], 
							V(-100,0,0)).
				if tuple[1] < time:seconds + 30 + ManeuverTime(nd:deltav:mag) { 
					remove nd.
					return 1e10. 
				}
				local error is nd:deltaV:mag.
				remove nd.
				return error.
			},
			10,
			0.1
		).
		GetLambertInterceptNode(ship, target, flightParams[1], flightParams[2], V(-100,0,0)). 
	}

	if phase = "Finetune" {
		set target to vessel(data["station"]).
		if hasnode { remove nextnode. }
		local flightParams is PatternSearch(
			List(time:seconds + 30, eta:apoapsis),
			{
				parameter tuple.

				if tuple[1] < time:seconds + 20 { return 1e10. }
				local nd is GetLambertInterceptNode(ship, target, tuple[1], tuple[2], V(-100, 0, 0)).
				local err is nd:deltaV:mag.
				remove nd.
				wait 0.
				return err.
			},
			10,
			0.1
		).
		local tune is GetLambertInterceptNode(ship, target, flightParams[1], flightParams[2], V(-100, 0, 0)).
		print "Node deltaV: " + tune:deltaV:mag.
		if tune:deltaV:mag <= 0.19 { setPhase("Match"). }
	} 

	if phase = "Match" {
		if hasnode { remove nextnode. }
		set target to vessel(data["station"]).
		local closestApproachUT is getClosestApproach(ship, target)[0].
		set node to getNode(velocityAt(ship, closestApproachUT):orbit, 
							velocityAt(target, closestApproachUT):orbit,
							positionAt(ship, closestApproachUT)- ship:body:position, 
							closestApproachUT).
		add node.

	}

	if phase = "Parking" {
		lock shipposition to ship:position.
		lock targetpoint to station:position + -55 * station:facing:upvector.
		lock targetfacing to station:facing.
		lock guide to station.
		set data["rcsloop"] to true.

		rcs on.
	}

	if phase = "Dock" {
		dock:controlfrom.
		highlight(dock, green).
		if targetdock = "" {
			if station:partstagged("Bow Dock")[0]:state = "Ready" {
				set targetdock to station:partstagged("Bow Dock")[0].
			} else if station:partstagged("Small Dock A")[0]:state = "Ready" {
				set targetdock to station:partstagged("Small Dock A")[0].
			} else if station:partstagged("Small Dock C")[0]:state = "Ready" {
				set targetdock to station:partstagged("Small Dock C")[0].
			} else if station:partstagged("Small Dock B")[0]:state = "Ready" {
				set targetdock to station:partstagged("Small Dock B")[0].
			}
		}

		if dock:getmodule("moduleanimategeneric"):hasevent("open shield") {
			dock:getmodule("moduleanimategeneric"):doevent("open shield").			
		}

		highlight(targetdock, red).
		lock shipposition to dock:nodeposition.

		set dockpath to List(
			List(V(0, 0, 1), 0.5, 0.2, XYZOffset@),
			List(V(0, 0, 0), 0.1, 0.1, XYZOffset@)
		).

		local traversal is Traverse(station, targetdock:nodeposition).
		for node in traversal { dockpath:insert(0, node). }

		lock guide to station.
		lock endPosition to targetdock:nodeposition.
		lock alignment to targetdock:portfacing.
		lock targetfacing to lookdirup(-targetdock:portfacing:vector, station:facing:vector).

		set targetoffset to dockpath[0][0].
		set speedcap to dockpath[0][1].
		set tolerance to dockpath[0][2].
		set deOffset to dockpath[0][3].
		lock targetpoint to deOffset(targetoffset).
		dockpath:remove(0).

		rcs on.
		set data["rcsloop"] to true.
	}


	if phase = "Recover" {
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

		lock shipposition to cargoport:nodeposition.

		set dockpath to List(
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

		lock guide to vessel(mission).
		lock endPosition to targetdock:nodeposition.
		lock alignment to targetdock:portfacing.
		lock targetfacing to lookdirup(-(targetdock:facing:vector), targetdock:facing:upvector).
		set targetoffset to dockpath[0][0].
		set speedcap to dockpath[0][1].
		set tolerance to dockpath[0][2].
		set deOffset to dockpath[0][3].

		lock targetpoint to deOffset(targetoffset).
		dockpath:remove(0).
		set data["rcsloop"] to true.

		rcs on.
	
		when targetdock:state:startswith("Acquire") then {
			bays off.
			set data["rcsloop"] to false.
			set data["mission"] to "".
			when targetdock:state:startswith("Docked") then {
				setPhase("rtb").
			}
		}
	
	}

	if phase = "Predock" {
		when dock:state:startswith("Acquire") then {
			rcs off.
			set data["rcsloop"] to false.

		}
		when dock:state:startswith("Docked") then {
			setPhase("Refuel").
			set data["rcsloop"] to false.
			writejson(data, "1:/data.json").
		}
	}

	if phase = "Refuel" {
		set data["rcsloop"] to false.

		if data["mission"] = "Refueler" { set data["mission"] to "". }

		global stationside is List().
		for part in ship:parts {
			if not tank:contains(part) { stationside:add(part). }
		}

		set shipToStation to transferall("ore", tank, stationside).
		set shipRefuelLF to transferall("liquidfuel", stationside, tank).
		set shipRefuelOx to transfer("Oxidizer",stationside,tank,440).
		set shipToStation:active to true.
		set shipRefuelLF:active to true.
		set shipRefuelOx:active to true.

		print "Ore Offload: "+shipToStation:status.
		print "Liquid Load: "+shipRefuelLF:status.
		print "Oxidizer Ld: "+shipRefuelOx:status.

		set refuelstatustimer to time:seconds + 5.

		when time:seconds > refuelstatustimer then {
			set refuelstatustimer to time:seconds + 5.

			print "T: "+time:seconds.		
			if shipToStation:status = "failed" { print "Ore Offload: " + shipToStation:message. }
			else { print "Ore Offload: " + shipToStation:status. }	
			if shipRefuelLF:status = "failed" { print "Liquid Load: " + shipRefuelLF:message. }
			else { print "Liquid Load: " + shipRefuelLF:status. }	
			if shipRefuelOx:status = "failed" { print "Oxidizer Ld: " + shipRefuelOx:message. }
			else { print "Oxidizer Ld: " + shipRefuelOx:status. }	

			return shipToStation:status = "transferring"
				or shipRefuelLF:status = "transferring" 
				or shipRefuelOx:status = "transferring".
		}

		when shipToStation:status = "transferring" 
			or shipRefuelLF:status = "transferring" 
			or shipRefuelOx:status = "transferring" then {

		when shipToStation:status <> "transferring" and shipRefuelLF:status <> "transferring" and
		 shiprefuelOx:status <> "transferring"
		 then { 

			dock:undock.
			
			set pushback to time:seconds + 1.
			
			setPhase("Pushback").


			when time:seconds > pushback then { 
				dock:controlfrom.
				set pushback to time:seconds + 2.
				set ship:control:fore to -0.2.


				setPhase("Release").
				
				writejson(data, "1:/data.json").
			}
		}}
	}

	if phase = "Pushback" {
		set pushback to time:seconds + 1.
		
		when time:seconds > pushback then {
			dock:controlfrom.
			rcs on.
			set ship:control:fore to -0.2.
			setPhase("Release").

			station:connection:sendmessage("KIND RELEASE " + ship:name).
		}	
	}

	if phase = "Release" {
		lock shipposition to ship:position.
		lock alignment to station:facing.
		lock endPosition to station:position.
		lock targetfacing to station:facing.
		lock guide to station.

		set dockpath to List(
			List(V(0, 0, 50), 0.5, 0.5, XYZOffset@)
		).

		local traversal is Traverse(station, XYZOffset(V(50, 0, 0))).
		for node in traversal { dockpath:insert(0, node). }

		set targetoffset to dockpath[0][0].
		set speedcap to dockpath[0][1].
		set tolerance to dockpath[0][2].
		set deOffset to dockpath[0][3].
		lock targetpoint to deOffset(targetoffset).
		
		dockpath:remove(0).
	
		rcs on.
		set data["rcsloop"] to true.

	}

	if phase = "Deploy" {
		set speedcap to 0.1.
		local cargohandler is "".
		sas on.
		if cargofore = "cargo" {
			if ship:partstagged("cargo fore")[0]:children:empty() {
				set cargohandler to ship:partstagged("cargo fore")[1]:children[0].
				ship:partstagged("cargo fore")[1]:undock.
			} else {
				set cargohandler to ship:partstagged("cargo fore")[0]:children[0].
				ship:partstagged("cargo fore")[0]:undock.
			}
			lock targetpoint to station:position + -80 * station:facing:upvector - 30 * station:facing:vector.
			lock targetfacing to station:facing * R(45,0,0).
			set cargofore to "".
		} else if cargoaft = "cargo" {
			set cargohandler to ship:partstagged("cargo aft")[0]:children[0].
			ship:partstagged("cargo aft")[0]:undock.
			lock targetpoint to station:position + -80 * station:facing:upvector + 30 * station:facing:vector.
			lock targetfacing to station:facing * R(-45,0,0).
			set cargoaft to "".
		}

		if cargoaft { set data["klaws"] to false. }

		if cargohandler <> "" {
			set cargohandler:ship:name to mission.
			set cargohandler:ship:type to "ship".
		}
		set contactTime to time:seconds + 5.

		setPhase("Post-Deploy").

		when time:seconds > contactTime then {
	
			local dockmessage is Lexicon().
			dockmessage:add("type", "klaw").
			dockmessage:add("station", data["station"]).
			dockmessage:add("mission", mission).
			dockmessage:add("sender", ship:name).
			if data["stationport"] <> "" { dockmessage:add("stationport",data["stationport"]). }
			if data["missionport"] <> "" { dockmessage:add("missionport",data["missionport"]). }
			if data["stationport"]:contains("construction") or data["stationport"]:contains("slot") {
				dockmessage:add("slot",true).
			}
			station:connection:sendmessage(dockmessage).

			if cargoaft = "fuel" {
				set data["mission"] to "Refueler".
			} else if cargoaft = "" {
				set data["mission"] to "".



			}

			set data["stationport"] to "".
			set data["missionport"] to "".

			set speedcap to 1.0.

			print "Sending message :" + dockmessage.	
		}

	}
	if phase = "PreRTB" {
		core:part:controlfrom().
		bays off.
		
	}

	writejson(data, "1:/data.json").

	return true.
}

function PlotPreRTB {
	if ship:orbit:eccentricity >= 0.015 {
		print "Ship requires circularization.".

		if eta:apoapsis < eta:periapsis {
				getApsisNodeAt(ship:orbit:apoapsis, time:seconds + eta:apoapsis).
		} else {
				getApsisNodeAt(ship:orbit:periapsis, time:seconds + eta:periapsis).
		}

		return.
	}
	setPhase("RTB"). 
}

function PlotRTB {
	set addons:tr:prograde to true.

	// Start with burn directly over KSC.
	local burnHigh is getEtaToLon(ship, -74.6) + time:seconds.
	local burnLow is getEtaToLon(ship, 105.4) + time:seconds.
	if burnHigh < burnLow { set burnHigh to burnHigh + ship:orbit:period. }

	local offsetHigh is 360.
	local offsetLow is 360.

	local tempNode is getApsisNodeAt(18, burnHigh).
	wait until addons:tr:hasimpact.
	set offsetHigh to abs(clamp360(addons:tr:impactpos:lng) - clamp360(-82.96)).
	print "Impact: "+addons:tr:impactpos:lng. 
	remove tempNode.
	wait until not addons:tr:hasimpact.
	set tempNode to getApsisNodeAt(18, burnLow).
	wait until addons:tr:hasimpact.
	set offsetLow to abs(clamp360(addons:tr:impactpos:lng) - clamp360(-82.6)). 
	print "Impact: "+addons:tr:impactpos:lng. 
	remove tempNode.
	wait until not addons:tr:hasimpact.

	local burnMid is 0.
	local offsetMid is 360.

	until burnHigh - burnLow < 1 {
		set burnMid to (burnHigh - burnLow)/2 + burnLow.
		set tempNode to getApsisNodeAt(18, burnMid).
		wait until addons:tr:hasimpact.
		set offsetMid to abs(clamp360(addons:tr:impactpos:lng) - clamp360(-89.6)). 
		print "Impact: "+addons:tr:impactpos:lng. 
		remove tempNode.
		wait until not addons:tr:hasimpact.
		if offsetHigh < offsetLow {
			set burnLow to burnMid.
			set offsetLow to offsetMid.
		} else {
			set burnHigh to burnMid.
			set offsetHigh to offsetMid.
		}
	}

	getApsisNodeAt(18, burnMid).
}

until hasnode = false {
	remove nextnode.
	wait 0.
}


global cycler is 0.

print "Mission: " at 		(100, 0).
print "Phase: " at 		(100, 1).

print "Offset: " at 		(100, 3).
print "Speedcap: " at		(100, 4).

print "Distance:" at 		(100,5).
print "Longitude:" at		(100,11).

setPhase(phase).

until false {

	print mission at 	(120, 0).
	print phase at 		(120, 1).

	clearvecdraws().

	if hasnode {
		core:part:controlfrom.
		until not hasnode {
			RunNode(nextnode).
			wait 0.
		}
		if phase = "Intercept" { 
			setPhase("Finetune"). 
		} else if phase = "Finetune" {
			setPhase("Finetune").
		} else if phase = "Match" {
			if cargofore = "cargo" or cargoaft = "cargo" {
				setPhase("Parking").
			} 
			else if cargofore = "fuel" or cargoaft = "fuel" {
				setPhase("Dock").
			}
		} else if phase = "PreRTB" { 
				setPhase("RTB"). 
		} else if phase = "RTB" {
			setPhase("Descend").
		}
		writejson(data,"1:/data.json").
	} else if phase = "PreRTB" and KUniverse:activevessel = ship { 
		PlotPreRTB().
	} else if phase = "RTB" and KUniverse:activevessel = ship { 
		PlotRTB(). 
	}

	if rcsloop {
		sas off.

		lock steering to targetfacing.

		local relpos is targetpoint - shipposition.

		set aimvec to vecdraw(shipposition, relpos, green, "", 1.0, true, 0.2).

		local relvel is guide:velocity:obt - ship:velocity:obt.

		local targetspeed is max(min(0.20 * relpos:mag, speedcap),0.2).
		local targetvelocity is -1 * targetspeed * relpos:normalized.

		local translation is 1.0 * (relvel - targetvelocity).

		if translation:mag < 0.1 { set cycler to cycler - 1. }
		if cycler < 0 {
			set translation to translation * 10.
			set cycler to 10.
		}

		set ship:control:translation to V(
				vdot(translation, ship:facing:starvector),
				vdot(translation, ship:facing:upvector),
				vdot(translation, ship:facing:vector)
		).

		print targetoffset		   at (120, 3).
		print round(speedcap,		2) at (120, 4).

		print round(relpos:mag, 	2) at (120, 5).

		print round(relpos:x,		5) at (105, 7).
		print round(targetvelocity:x,	5) at (117, 7).
		print round(relvel:x,		5) at (129, 7).
		print round(relpos:y,		5) at (105, 8).
		print round(targetvelocity:y,	5) at (117, 8).
		print round(relvel:y,		5) at (129, 8).
		print round(relpos:z,		5) at (105, 9).
		print round(targetvelocity:z,	5) at (117, 9).
		print round(relvel:z,		5) at (129, 9).

		if phase = "Parking" and relpos:mag < 1 and klaws = true {
			setPhase("Deploy").
		} else if phase = "Dock" or phase = "Recover" {
			set aimveclist to List().
			for point in dockpath {
				aimveclist:add(vecdraw(
					targetdock:nodeposition, 
					point[0] * targetdock:portfacing, red, "", 1.0, true, 0.2)
				).
			}

			if dockpath:length > 0 and relpos:mag < tolerance
			{
				set targetoffset to dockpath[0][0].
				set speedcap to dockpath[0][1].
				set tolerance to dockpath[0][2].
				set deOffset to dockpath[0][3].
				lock targetpoint to deOffset(targetOffset).
				dockpath:remove(0).
			} else if dockpath:length = 0 and phase = "Dock" {
				setPhase("Predock").
			}
		}
		wait 0.1.
	} else if phase = "Descend" {
		print round(addons:tr:impactpos:lng, 5) at (120, 12).
		if ship:velocity:surface:mag < 600 { 
			setPhase("Land"). 
			writejson(data, "1:/data.json"). 
		} else if nosetemp > 2200 { 
			lock steering to ship:srfprograde * R(-20, 0, 0). 
			printData("state:", 15, "Shedding heat").
		} else if ship:altitude < 10000 { 
			printData("state:", 15, "Decceleration").
			lock steering to heading(90, 4).
		} else { 
			printData("state:", 15, "Basic Descent").
			lock steering to heading(90, -5). 
		}
		wait 1.
	} else {wait 1.}

}

