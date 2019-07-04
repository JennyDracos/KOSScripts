@lazyglobal off.

set terminal:width to 156.

copypath("0:/boot/cstab.ks","1:/boot/cstab.ks").

copypath("0:/lib/ui.ks", "1:/lib/ui.ks").
copypath("0:/lib/comms.ks","1:/lib/comms.ks").
copypath("0:/lib/dock.ks","1:/lib/dock.ks").

runoncepath("0:/lib/ui.ks").
runoncepath("0:/lib/comms.ks").
runoncepath("0:/lib/dock.ks").

set core:bootfilename to "/boot/cstab.ks".

function sendMessage {
	parameter commTarget,
		message.
	
	if commTarget:part:ship = ship { commTarget:connection:sendmessage(message). }
	else { commTarget:part:ship:connection:sendmessage(message). }

}
clearscreen.
print "Cargo Stabilizer Control v4.0.2.".

on abort {
	copypath("0:/boot/cstab.ks","1:/").
	reboot.
}
on ag9 {
	ship:connection:sendmessage("PARTNER RTB").
	return true.
}

local shipList is List().
list targets in shipList.
local shipCount is shipList:length.

global TAGS is CORE:TAG:SPLIT(" ").
function findMother {
	if ship:partstagged(Tags[0]):length > 0 {
		return ship:partstagged(tags[0])[0]:getmodule("kosprocessor"). }
	list targets in shiplist.
	for vess in shiplist {
		local partlist is vess:partstagged(Tags[0]).
		if partlist:length > 0 { 
			return vess:partstagged(tags[0])[0]:getmodule("kosprocessor"). }
	}
} local Mother is findMother().

// TODO: Part recognition pending.
local base is ship:partsTagged(tags[0] + " Base")[0].
local cap is ship:partsTagged(tags[0] + " Cap")[0].
local controlDock is cap.

set ship:control:translation to V(0,0,0).

global data is Lexicon().
if core:volume:exists("data.json") {
	set data to readjson("1:/data.json").
}

if not data:haskey("Mission") { data:add("Mission",""). }
if not data:haskey("Station") { data:add("Station",mother:part:ship:name). }

if not data:haskey("mode") { data:add("mode","RTB"). }
if data["mission"] = "" and data["mode"] <> "Sleep" { set data["mode"] to "RTB". }
if not data:haskey("park") { data:add("park",V(10, 0, 1)). }
if data["mode"] = "SLEEP" { // Eh, sit there?
} else if ship = mother:part:ship { // Why are we docked?  ...Probably completed and mebbe crashed.
	set data["mode"] to "RTB".
	set data["mission"] to "".
} else {
}

writejson(data, "1:/data.json").

// lock mode to data["mode"]. // Do this after the phase change code so it triggers on startup.
local missionPort is "".
if not data:haskey("MissionPortUID") {
	set data["MissionPortUID"] to "".
} else if data["missionPortUID"] = "" {
	set data["Mission"] to "".
} else {
	set data["Mission"] to "".
	local uidSearch is FindUID(data["missionPortUID"]).
	if uidSearch:Empty() {
		set data["missionPortUID"] to "".
		set data["mode"] to "RTB".
	} else {
		set missionPort to uidSearch[0].
		set data["Mission"] to uidSearch[1]:name.
	}
}

local stationPort is "".
if not data:haskey("StationPortUID") {
	set data["StationPortUID"] to "".
} else if data["stationPortUID"] = "" {
	set data["Station"] to "".
} else {
	set data["Station"] to "".
	local uidSearch is FindUID(data["stationPortUID"]).
	if uidSearch:Empty() {
		set data["stationPortUID"] to "".
		set data["Station"] to mother:part:ship:name.
		set data["mode"] to "RTB".
	} else {
		set stationPort to uidSearch[0].
		set data["Station"] to uidSearch[1]:name.
	}
}


set commsHandler to {
	parameter content.

	if data["mode"] = "SLEEP" {
		if content:istype("String") and (content = tags[0] + " WAKE") {
			setMode("AWACT").
		}
	}
	else if content:istype("Lexicon") {
		if not content:haskey("type") {
			print "Malformed content.".
		} else if content["type"] = "Klaw" {
			set data["mission"] to content["mission"].
			local missionship is vessel(content["mission"]).
			set data["station"] to content["station"].
			if ship:name = data["mission"] {
				setMode("Hold").
			} else if data["station"] = mother:part:ship:name {
				setMode("Park").
			} else {
				setMode("RTB").
			}
		}
	}
	else if content:startswith("PARTNER RTB") {
		print content:padright(40) at (10,2).
		setMode("RTB").
	}
	else if content:startswith("DEPLOY") {
		set data["mission"] to content:replace("DEPLOY ","").
		setMode("Deploy").
	}
	else if content:contains(tags[0]) {
		if content:contains("SLEEP") {
			setMode("SLEEP").
		}
	}
	else { print "No content handler for content: " + content at (0,1). }
	writejson(data,"data.json").
	return true.
}.

function setMode {
	parameter newMode.

	set data["mode"] to newMode.
	writejson(data, "1:/data.json").

	if rcsLoop {
		dockFinal().
		rcs off.
	}

	print "Updating mode to "+mode+".".
	if mode = "AWACT" {
		rcs off.
		unlock steering.
		set ship:control:neutralize to true.
		set rcsloop to false.
	}
	else if mode = "Deploy" {
		local deployTime is time:seconds + 5.
		when time:seconds > deployTime then {

			if ship:partstagged(tags[0]+" Stb"):empty and
			   ship:partstagged(tags[0]+" Prt"):empty {
				lock steering to North.
			}
		}
	}
	else if mode = "Park" {
//		mother:part:ship:connection:sendmessage(Lexicon(
//			"type", "CStab-Park",
//			"mission", data["mission"],
//			"station", data["station"]
//		)).
		base:controlfrom.
		
		cap:undock.
		base:undock.

		local station is mother:part:ship.

		set startPos to { return ship:position. }.
		set zeroVelocity to { return station:velocity:orbit. }.
		set endPos to { return station:position. }.
		set alignment to { return station:facing. }.
		set targetFacing to { return station:facing. }.

		set pathQueue to List(
			List(data["park"], 0.5, 0.5, XYZOffset@)
		).

		local traversal is Traverse(station, XYZOffset(data["park"])).
		for node in traversal { pathQueue:insert(0, node). }

		set terminate to { parameter distance. return true. }.

		dockInit().
	}
	else if mode = "RTB" {
		if ship = mother:part:ship { 
			setMode("AWACT").
			return true.
		}
		print "Picking dock.".
		local targetdock is "".
		for dock in mother:part:ship:partsdubbedpattern("Bow") {
			if dock:state = "Ready" { set targetDock to dock. }
		}
		if targetDock = "" {
			for dock in mother:part:ship:partsdubbedpattern("Stern") {
				if dock:state = "Ready" { set targetDock to dock. }
			}
		}
		if targetDock = "" {
			print "No available dock!".
			print 1/0.
		}

		base:undock.
		cap:undock.

		// TODO: do I need to be forward or backward?

		if targetDock:nodetype = base:nodetype {
			set controlDock to base.
		} else {
			set controlDock to cap.
		}

		controlDock:controlFrom.

		set startPos to { return controlDock:nodePosition. }.
		set zeroVelocity to { return mother:part:ship:velocity:orbit. }.
		set endPos to { return targetDock:nodePosition. }.
		set alignment to { return targetDock:portFacing. }.
		set targetFacing to { return lookdirup(-targetDock:portFacing:vector, 
							  targetDock:portFacing:upvector). }.

		set pathQueue to List(
			List(V(0,0,1), 1.0, 0.2, XYZOffset@),
			List(V(0,0,0), 0.2, 0.2, XYZOffset@)
		).

		local traversal is Traverse(mother:part:ship, endPos()).
		for node in traversal { pathQueue:insert(0, node). }

		set terminate to { 
			parameter distance.
			if targetDock:state = "PreAttached" {
				setMode("AWACT").
			}
			return true.
		}.

		dockInit().
	}
	else if mode = "Roost" {
	}
	else if mode = "AWACT" {
	}
	print "Mode updated.".

	writejson(data, "1:/data.json").
	return true.
}

lock mode to data["mode"].
setMode(mode).

until false {
	printData("Mode:",		1, mode).
	printData("Station:",	3, data["station"]).
	printData("Mission:",	4, data["mission"]).

	printData("RCS Loop:",	6, rcsLoop).

	if mode = "Deploy" and 
		not (ship:partstagged(tags[0]):empty and
			 ship:partstagged(tags[0] + " Prt"):empty)
	{
		unlock steering.
	}

	if rcsloop {
		set rcsLoop to dockUpdate().
	} else { wait 1. }
	writejson(data,"data.json").
}


