@lazyglobal off.

copypath("0:/boot/station.ks", "1:/boot/station.ks").
copypath("0:/lib/ui.ks","1:/lib/ui.ks").
copypath("0:/liborbit.ks","1:liborbit.ks").

runoncepath("1:/lib/ui.ks").
runoncepath("1:/liborbit.ks").


set core:bootfilename to "boot/station.ks".


on abort {
	copypath("0:/boot/station.ks", "1:/").
	reboot.
}

if core:volume:exists("data.json") {
	global data is readjson("1:/data.json").

	if not data:haskey("Release")  { set data["Release"] to "". }
	if not data:haskey("Recover") { set data["Recover"] to "". }
	if not data:haskey("Stoptime") { set data["Stoptime"] to 15. }
	if not data:haskey("Settle")   { set data["Settle"]   to 10. }
	if not data:haskey("Altitude") { set data["Altitude"] to 100.}
} else {
	global data is Lexicon().
	data:add("Kind","").
	data:add("Retrieve","").
	
	writejson(data, "1:/data.json").
}

set steeringmanager:pitchts to data["Settle"].
set steeringmanager:yawts to data["Settle"].
set steeringmanager:rollts to data["Settle"].

lock kind to data["Kind"].
lock recover to data["Recover"].
lock release to data["Release"].
lock tAlt to data["Altitude"] * 1000.

local highlitPart is "".
local highlitPartner is "".

local highlighting is highlight(core, blue).
set highlighting:enabled to false.
local releaseHighlight is highlight(core, yellow).
set releaseHighlight:enabled to false.
local recoverHighlight is highlight(core, cyan).
set recoverHighlight:enabled to false.

local vesselList is List().
list targets in vesselList.
local deadKind is true.
for vess in vesselList {
	if vess:name = kind { set deadKind to false. }
}
if deadKind { set data["kind"] to "". }

function FindUID {
	parameter UID.
	list targets in vesselList.
	vesselList:add(ship).
	for vess in vesselList {
		if vess:loaded and vess:unpacked {
			for part in vess:parts {
				if part:UID = UID { return List(part, vess). }
			}
		}
	}
	return List().
}

clearscreen.

print "Running Station v0.0.6c.".

on ship:controlpart {
	if ship:controlpart = core:part {
		return true.
	} else {
		if highlitPart <> "" { set highlighting:enabled to false. }
		set highlitPart to ship:controlpart.
		print "Highlit " + highlitPart.
		core:part:controlfrom.
		set highlighting to highlight(highlitPart, blue).
		set highlighting:enabled to true.
	}
	return true.
}

on ag7 {
	if highlitPart <> "" and
		(highlitPart:Parent = "" or highlitPart:Children:length = 0) and
		highlitPart:istype("DockingPort")
	{
		set highlighting:enabled to false.
		local recoverPort is highlitPart.
		set data["Recover"] to recoverPort:uid.
		print "Flagged " + highlitPart + " to recover to.".
		set recoverHighlight to highlight(highlitPart, cyan).
		set recoverHighlight:enabled to true.
		set highlitPart to "".
	}
	if data["Recover"] <> "" and data["Release"] <> "" {
		local recoverSearch is findUID(data["Recover"]).
		if recoverSearch:empty or recoverSearch[1] <> ship { 
			set data["Recover"] to "".
			return true.
		}
		local releaseSearch is findUID(data["Release"]).
		if releaseSearch:empty or releaseSearch[1] <> ship {
			set data["Release"] to "".
			return true.
		}
		local recoverPort is recoverSearch[0].
		local releasePort is releaseSearch[0].
		local releasePartner is releasePort:Parent.
		if not releasePartner:istype("DockingPort") {
			set releasePartner to releasePort:Children[0].
		}
		when releasePort:state = "Ready" and
			ship:partstagged(core:tag + " Prt"):length > 0 and
			ship:partstagged(core:tag + " Stb"):length > 0
			then 
		{
			if releasePort:ship = ship and releasePartner:ship = ship {
				return true.
			} else if releasePort:ship = ship {
				set releasePort to releasePartner.
			}
			ship:connection:sendmessage(Lexicon(
				"type", "klaw",
				"mission",releasePort:ship:name,
				"station",ship:name,
				"missionport","stern",
				"stationport",recoverPort:tag)
			).
			set data["Release"] to "".
			set data["Recover"] to "".
			set recoverHighlight:enabled to false.
			set releaseHighlight:enabled to false.
		}
		releasePort:undock.
		print releasePort:state.
	}
	writejson(data, "1:/data.json").
	return true.
}

on ag8 {
	if highlitPart <> "" and
		highlitPart:Parent <> "" and
		highlitPart:Children:length > 0
	{
		set highlighting:enabled to false.
		local retrievePort is highlitPart.
		set data["Release"] to retrievePort:uid.
		print "Flagged " + highlitPart + " for release.".
		set releaseHighlight to highlight(highlitPart, yellow).
		set releaseHighlight:enabled to true.
		set highlitPart to "".
	}
	writejson(data, "1:/data.json").
	return true.
}

when not ship:messages:empty then {
	local message is ship:messages:pop().
	for processor in ship:modulesnamed("kosprocessor") {
		processor:connection:sendmessage(message:content).
	}
	return true.
}

when not core:messages:empty then {
	local message is core:messages:pop().
	local content is message:content.

	print "Message recieved: " + content.

	if content:istype("Lexicon") {
		if not content:haskey("type") {
			print "Unformed message.".
		}
		else if content["type"] = "Kind" {
			// Don't care.  Flush.
		}
		else if content["type"] = "Klaw" {
			// Just got a call to deploy Klaw pods.  Save the sender.
			if content:haskey("Sender") { set data["Kind"] to content["sender"]. }
		}
		else if content["type"] = "Klaw-Dock" {
			if kind <> "" { vessel(kind):connection:sendmessage("KLAW DOCKED"). }
		}
	} else if content = "KLAW HOME" {
	} else if content:startswith("KIND RELEASE") {
		set data["kind"] to content:replace("kind release ","").
		if data["Release"] <> "" {
			local releaseSearch is FindUID(data["Release"]).
			if releaseSearch:empty or releaseSearch[1] <> ship {
				vessel(data["kind"]):connection:sendmessage("BYE").
				set data["kind"] to "".
				return true.
			}
			local releasePort is releaseSearch[0].
			local releasePartner is releasePort:parent.
			if not releasePartner:istype("DockingPort") {
				set releasePartner to releasePort:Children[0].
			}
			when releasePort:state = "Ready" and
				ship:partstagged(core:tag + " Prt"):length > 0 and
				ship:partstagged(core:tag + " Stb"):length > 0
				then 
			{
				if releasePort:ship = ship { 
					set releasePort to releasePartner. 
				}
				local parkmessage is Lexicon(
					"type", "klaw",
					"park", V(40, 0, 0),
					"mission", releasePort:ship:name,
					"station", ship:name,
					"kind", kind
				).
				ship:connection:sendmessage(parkmessage).
				set data["kind"] to "".
				set data["Release"] to "".
				set releaseHighlight:enabled to false.
			}
			releasePort:undock.
		} else { 
			vessel(kind):connection:sendmessage("BYE"). 
			set data["kind"] to "".
		}
	}
	writejson(data, "1:/data.json").

	return true.
}

on ship:parts {
	for hatch in ship:modulesnamed("moduledockinghatch") {
		if hatch:hasevent("open hatch") {
			hatch:doevent("open hatch").
		}
	}
}

function stationKeeping {
	rcs on.
	if ship:altitude > data["altitude"] * 100 and vdot(ship:velocity:orbital,-ship:body:position) > 0 {
		set ship:translate to V(
			vdot(-ship:body:orbit, ship:facing:starvector),
			vdot(-ship:body:orbit, ship:facing:upvector),
			vdot(-ship:body:orbit, ship:facing:forevector)
		).
	}
	if ship:altitude < data["altitude"] * 100 and vdot(ship:velocity:orbital,-ship:body:position) < 0 {
		set ship:translate to V(
			vdot( ship:body:orbit, ship:facing:starvector),
			vdot( ship:body:orbit, ship:facing:upvector),
			vdot( ship:body:orbit, ship:facing:forevector)
		).
	}
	wait 1.
}

local transVec is 0.
local wantVec is 0.
local velVec is 0.

core:part:controlfrom.

until false {
	//		   123456789012345
	printData("Altitude:",		  1, data["Altitude"]).

	printData("Release:",		  3, data["Release"]).
	printData("Retrieve:",		  4, data["Retrieve"]).
	printData("Kind:",			  5, data["Kind"]).

	sas off.

	lock steering to lookdirup(north:vector, solarprimevector).

	local translate is V(0,0,0).
	
	local rB is -ship:body:position.
	local vel is getHoriVelVecAt(time:seconds).
	local sma is (tAlt + ship:body:radius + rB:mag) / 2.
	set vel:mag to sqrt(ship:body:mu * (2 / rB:mag - 1 / sma)).

	set translate to (vel - ship:velocity:orbit) / 1.
	
	if translate:mag < 0.2 {
		rcs off.
		set ship:control:translation to V(0,0,0).
		wait 1.
	} else {
		rcs on.
		set ship:control:translation to translate * ship:facing:inverse.
		wait 0.
	}
}


print "Station completed.  Um.".
