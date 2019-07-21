@lazyglobal on.

set terminal:width to 156.

copypath("0:/boot/klaw.ks","1:/boot/klaw.ks").
copypath("0:/lib/ui.ks", "1:/lib/ui.ks").
copypath("0:/lib/dock.ks","1:/lib/dock.ks").
copypath("0:/lib/comms.ks","1:/lib/comms.ks").

runoncepath("1:/lib/ui").
runoncepath("1:/lib/dock").
runoncepath("1:/lib/comms").

set core:bootfilename to "/boot/klaw.ks".

function sendMessage {
	parameter commTarget,
		message.
	
	if commTarget:part:ship = ship { commTarget:connection:sendmessage(message). }
	else { commTarget:part:ship:connection:sendmessage(message). }

}
clearscreen.
print "Klaw Control v5.0.0.".

on abort {
	copypath("0:/boot/klaw.ks","1:/").
	reboot.
}
on ag9 {
	if ag9 = FALSE { return true. }
	ship:connection:sendmessage("PARTNER RTB").
	return true.
}

local tags is core:tag:split(" ").
local vesselList is List().
list targets in vesselList.
vesselList:add(ship).
local _vesselCount is vesselList:length.

wait until ship:loaded and ship:unpacked.

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

function findMother {
	if ship:partstagged(Tags[0]):length > 0 {
		return ship:partstagged(tags[0])[0]:getmodule("kosprocessor"). }
	for vess in vesselList {
		set partlist to vess:partstagged(Tags[0]).
		if partlist:length > 0 { 
			return vess:partstagged(tags[0])[0]:getmodule("kosprocessor"). }
	}
}

local Mother is findMother().

local grapple is "".
local perch is "".
local seat is "".
function labelParts {
	local element is queue().
	local iterator is core:part.
	until (iterator:hasparent = false) or 
		  (iterator:istype("dockingport")) or 
		  (iterator:name = "grapplingdevice") {
		set iterator to iterator:parent.
	}
	element:push(iterator).
	until element:empty {
		set iterator to element:pop.
		for child in iterator:children { element:push(child). }
		if iterator:name:startswith("grapplingdevice") { set grapple to iterator. }
		if iterator:name:startswith("dockingport2") { set seat to iterator. }
		if iterator:name:startswith("dockingport3") { set perch to iterator. }
	}
}
labelParts().

local PARTNER is "".
local CHOSENSIDE is R(0,0,0).
if TAGS[1] = "prt" { set PARTNER to TAGS[0]+" STB". }
else { set PARTNER to TAGS[0]+" PRT". }

function findPartner {
	if ship:partstagged(partner):length > 0 {
		return ship:partstagged(partner)[0]:getmodule("kosprocessor").
	}
	list targets in shiplist.
	for vess in shiplist {
		set partlist to vess:partstagged(Partner).
		if partlist:length > 0 {
			return vess:partstagged(Partner)[0]:GetModule("KosProcessor").
		}
	}
}
set partner to findPartner().

set NEST to mother:part:ship:partstagged(Core:Tag + " Nest")[0].

global data is Lexicon().
if core:volume:exists("data.json") {
	set data to readjson("1:/data.json").
}
print data.

if not data:haskey("Mode")	  { set data["Mode"] to "RTB". }
lock mode to data["mode"].
if not data:haskey("Mission") { set data["Mission"] to "". }
if not data:haskey("Station") { set data["Station"] to "". }
if not data:haskey("Park") { set data["Park"] to false. }
if not data:haskey("Kind") { set data["Kind"] to "". }
if not data:haskey("Queue") { set data["Queue"] to Queue(). }

local missionPort is "".
if not data:haskey("MissionPortUID") {
	set data["MissionPortUID"] to "".
} else if data["missionPortUID"] = "" {
	set data["Mission"] to "".
} else {
	set data["Mission"] to "".
	local uidSearch is FindUID(data["missionPortUID"]).
	if uidSearch:Empty() {
		print "Mission port out of range.  Abort.".
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
		print "Station port out of range.  Abort.".
		set data["stationPortUID"] to "".
		set data["Station"] to mother:part:ship:name.
		set data["mode"] to "RTB".
	} else {
		set stationPort to uidSearch[0].
		set data["Station"] to uidSearch[1]:name.
	}
}

if not data:haskey("Rotation") { data:add("Rotation",0). }
local r is data["Rotation"].
if not data:haskey("Slot") { data:add("Slot",false). }

local chosenside is "".
if data["slot"] and tags[1] = "PRT" { set chosenside to R(90, r, 0).  }
else if data["slot"]			   { set chosenside to R(-90, -r, 0). }
else if tags[1]	= "PRT"			   { set chosenside to R(r, 90, 0).  } 
else							   { set chosenside to R(-r, -90, 0). }

if data["mode"] = "Deploy" {
	if grapple:getmodule("modulegrapplenode"):hasevent("release") {
		set data["mode"] to "hold".
	} else { set data["mode"] to "Approach". }
}
 
on grapple:getmodule("modulegrapplenode"):hasevent("release") {
	if not grapple:getmodule("modulegrapplenode"):hasevent("release") { return true. }
	print "We've got something!".
	// We've got something!
	local missionShip is false.
	local partnerShip is false.
	for port in ship:dockingports {
		if port:uid = data["missionportuid"] { set missionShip to true. }
	}
	for proc in ship:modulesnamed("kOSProcessor") {
		if proc = partner { set partnerShip to true. }
	} 
	if missionShip {
		setMode("Hold").
	} else {
		print "Connected to "+ship:name+"!  Aborting!".
		setMode("Approach").
	}
	return true.
}

set commsHandler to {
	parameter message.

	if message:isType("Lexicon") {
		if not message:haskey("type") {
			print "Malformed message.".
			return true.
		} else if message:haskey("to") and message["to"] <> tags[0] {
			print "Sent elsewhere.".
			return true.
		} else if message:haskey("Queue") and message["Queue"] {
			message:remove("Queue").
			data["Queue"]:push(message).
			return true.
		} else if message["type"] = "Data" {
			message:remove("type").
			if message:haskey("to") { message:remove("to"). }
			for key in message:keys {
				set data[key] to message[key].
			}
			setMode(data["mode"]).
			return true.
		}
	} else if data["mode"] = "Sleep" and message = tags[0] + " WAKE" {
		setMode("AWACT").
	} else if message:startswith("QUEUE") {
		local command is message:replace("QUEUE ","").
		data["Queue"]:push(command).
	}

	if data["mode"] = "Sleep" { return true. }

	if message:istype("Lexicon") {
		if not message:haskey("type") {
			print "Malformed message.".
		} else if message["type"] = "Klaw" {
			if message:haskey("MissionPortUID") {
				set data["MissionPortUID"] to message["MissionPortUID"].
				set message["Mission"] to FindUID(data["MissionPortUID"])[1]:name.
			}
			if message:haskey("StationPortUID") {
				set data["StationPortUID"] to message["StationPortUID"].
				set message["Station"] to FindUID(data["StationPortUID"])[1]:name.
			}


			set data["mission"] to message["mission"].
			local missionship is vessel(message["mission"]).
			set data["station"] to message["station"].
			local station is vessel(message["station"]).

			set stationPort to "".
			set missionPort to "".	
	
			if message:haskey("StationPortUID") {
				set stationport to FindUID(message["StationPortUID"])[0].
			} else if message:haskey("stationport") {
				for port in station:partsdubbedpattern(message["stationport"]) {
					if port:typename = "dockingport" and 
					  port:state = "ready" { set stationPort to port. }
				}
			}
			if message:haskey("missionportUID") {
				set missionport to FindUID(message["missionPortUID"])[0].
			} else if message:haskey("missionport") {
				for port in missionShip:partsdubbedpattern(message["missionport"]) {
					if port:typename = "dockingport" and 
					  (port:state = "ready" or port:state = "locked")
					{ set missionPort to port. }
				}
			}
	
			if stationport = "" and missionport = "" {
				for port in missionShip:dockingports {
					for secondport in station:dockingports {
						if (port:nodetype = secondport:nodetype) and
						   (port:state <> "PreAttached" and not 
						   		port:state:startswith("Docked")) and
						   (secondport:state <> "PreAttacched" and not
						   		port:state:startsWith("Docked")) {
							set missionPort to port.
							set stationPort to secondPort.
						}	
					}
				}
			}
			else if stationport = "" {
				for port in station:dockingports {
					if port:nodetype = missionport:nodetype and
					   port:state = "ready" {
						set stationport to port.
					}
				}
			}
			else if missionport = "" {
				for port in missionShip:dockingports {
					if port:nodetype = stationport:nodetype and
						(not port:state:startswith("docked")) and
						(not (port:state = "preattached")) {

						set missionPort to port.
					}
				}
			}
	
			set data["missionPortUID"] to missionport:uid.
			highlight(missionport, green).
			set data["stationPortUID"] to stationport:uid.
			highlight(stationport, red).
	
			if message:haskey("slot") { set data["Slot"] to message["Slot"]. }
			else { set data["Slot"] to false. }

			if message:haskey("park") { 
				set data["Park"] to message["Park"].
				set data["Kind"] to message["Kind"].
			} else { 
				set data["Park"] to false. 
				set data["Kind"] to "".
			}
	
			if message:haskey("rotation") { set data["Rotation"] to message["Rotation"]. }
			else { set data["Rotation"] to 0. }

			local r is data["Rotation"].
			local slot is data["Slot"].
			if slot and tags[1] = "PRT" { set chosenside to R(90,r,0). }
			else if slot			    { set chosenside to R(-90,-r,0).}
			else if tags[1] = "PRT"	    { set chosenside to R(r,90,0). }
			else					    { set chosenside to R(-r,-90,0).}
	
	
			setMode("Depart").
		}
	}
	else if message:startswith("PARTNER RTB") {
		print message:padright(40) at (10,2).
		setMode("RTB").
	}
	else if message:contains(tags[0]) {
		if message:contains("SLEEP") {
			setMode("Sleep").
		}
	}
	else { print "No message handler for message: " + message at (0,1). }
	writejson(data,"data.json").
	return true.
}.

// Mode - DEPART - leave MOTHER.  Go to APPROACH when clear.
// Mode - APPROACH - get close to MISSION.  Go to DEPLOY when in docking corridor.  Tell partner.
// Mode - DEPLOY - in docking corridor.  Kill transverse velocity and punch to 1.5m/s.
//	If succeed, tell partner and go to HOLD.
//	If fail, tell partner and go to APPROACH.
// Mode - HOLD - docked with mission.  If partner succeeds at DEPLOY, go to DOCK.
//	If partner succeeds at DOCK, go to RTB.
// Mode - DOCK - control from docking port on MISSION.  Dock with STATION. Code on message receipt.
// Mode - RTB - release MISSION.  Control from mini port.  Dock with MOTHER. Code on message receipt.
// Mode - AWACT - docked with MOTHER.  Go to sleep. No code.

function setMode {
	parameter newMode.

	print "Updating mode to "+newMode+".".
	set data["mode"] to newMode.

	DockFinal().

	if mode = "AWACT" and data["Queue"]:length > 0 {
		local nextCommand is data["Queue"]:pop().
		core:connection:sendmessage(nextCommand).
	} else if mode = "AWACT" and not perch:state:startswith("Docked") {
		ship:connection:sendmessage("PARTNER RTB").
	} else if mode = "AWACT" {
		rcs off.
		unlock steering.
		set ship:control:neutralize to true.
		set rcsloop to false.
	} else if mode = "Depart" {
		if perch:getmodule("moduledockingnode"):hasevent("undock") {
			perch:getmodule("moduledockingnode"):doevent("undock"). }
		if grapple:getmodule("modulegrapplenode"):hasevent("release") {
			grapple:getmodule("moduleanimategeneric"):doevent("disarm"). }

		when ship:parts:length < 20 then {
			Grapple:GetModule("ModuleGrappleNode"):DoEvent("Control From Here").

			// Can we skip all this?
			local relativeDest is XYZtoZTR(mother:part:ship, 
			   vessel(data["mission"]):position).
			print "Relative Destination: " + relativeDest.
			local relativeLoc is XYZtoZTR(mother:part:ship, ship:position).
			print "Relative Location: " + relativeLoc.
			local motherBounds is getBounds(mother:part:ship).
			print "Mother Bounds: " + motherBounds.

			if (abs(relativeLoc:x) < motherBounds[0] and 
				relativeLoc:z < motherBounds[1]) {

				set startPos to { return ship:position. }.
				set zeroVelocity to { return mother:part:ship:velocity:orbit. }.
				set endPos to { return nest:position. }.
				set alignment to { return nest:facing. }.
				set targetFacing to alignment.

				set pathQueue to List().
				local traversal is Traverse(
					mother:part:ship,
					ZTROffset(mother:part:ship, 
						V(relativeLoc:x, relativeDest:y, motherBounds[1]))
				).
				if traversal:length > 0 {
					for node in traversal {
						pathQueue:insert(0, node).
					}
				} else { setMode("Approach"). }

				set terminate to { 
					parameter distance.
					if distance < 1.0 {
						rcs off.
						setMode("Approach").
						return false.
					}
					return true.
				}.

				dockInit().

			} else { 
				setMode("Approach").
			}
		}
	} else if mode = "Approach" {

		if perch:getmodule("moduledockingnode"):hasevent("undock") {
			perch:getmodule("moduledockingnode"):doevent("undock"). }
		if grapple:getmodule("modulegrapplenode"):hasevent("release") {
			grapple:getmodule("moduleanimategeneric"):doevent("disarm"). }

		when ship:parts:length < 20 then {
			Grapple:GetModule("ModuleGrappleNode"):DoEvent("Control From Here").

			local mission is vessel(data["mission"]).
			set startPos to { return grapple:position. }.
			set zeroVelocity to { return mission:velocity:orbit. }.
			set endPos to { return mission:position. }.
			set alignment to { return missionport:portfacing * chosenside. }.
			set targetFacing to { return alignment() * R(0, 180, 0). }.

			set pathQueue to List(
				List(V(  0,  0, 10), 1.0, 0.2, XYZOffset@)
			).
			
			local traversal is Traverse(mission, XYZOffset(V(0,0,1))).
			for node in traversal { pathQueue:insert(0,node). }

			set terminate to {
				parameter distance.
				if distance < 0.2 {
					setMode("Deploy").
					return true.
				}
				return true.
			}.

			print "Path length: " + pathQueue:length.
			dockInit().
		}
	} else if mode = "Deploy" {
		Grapple:GetModule("ModuleGrappleNode"):DoEvent("Control From Here").
		
		if grapple:getmodule("moduleanimategeneric"):hasEvent("Arm") {
			grapple:getmodule("moduleanimategeneric"):doEvent("Arm").
		}
	
		local mission is FindUID(data["missionportUID"])[1].
		set startPos to { return grapple:position. }.
		set zeroVelocity to { return mission:velocity:orbit. }.
		set endPos to { return mission:position. }.
		set alignment to { return missionport:portfacing * chosenside. }.
		set targetFacing to { return alignment() * R(0, 180, 0). }.

		set pathQueue to List(
			List(V(0,0,0), 2.0, 0.1, XYZOffset@)
		).

		set terminate to {
			parameter distance. return true.
		}.

		print "Path length: " + pathQueue:length.
		dockInit().
	} else if mode = "Hold" {
		unlock steering.
		set ship:control:neutralize to true.
		rcs off.
	} else if mode = "Dock" {
		local station is vessel(data["station"]).
		mother:part:ship:connection:sendmessage(Lexicon(
			"type",	"Klaw-Dock",
			"mission", data["mission"],
			"station", data["station"]
		)).
		missionport:controlfrom.
	
		set startPos to { return missionport:nodeposition. }.
		set zeroVelocity to { return station:velocity:orbit. }.
		set endPos to { return stationport:nodeposition. }.
		set alignment to { return stationport:portfacing. }.
		set targetfacing to { 
			return lookdirup(-1 * alignment():forevector, alignment():upvector). 
		}.
			
		local transform is XYZOffset@.

		set pathQueue to List(
			List(V(  0,  0, 10), 1.0, 0.5, transform),
			List(V(  0,  0,  5), 1.0, 0.5, transform),
			List(V(  0,  0,  1), 0.5, 0.2, transform),
			List(V(  0,  0,0.5), 0.2, 0.2, transform),
			List(V(  0,  0,0.1), 0.2, 0.1, transform),
			List(V(  0,  0,0.0), 0.1, 0.1, transform)
		).

		local traversal is Traverse(station, endPos()).
		for node in traversal { pathQueue:insert(0, node). }

		when ship:name = data["station"] then {
			setmode("AWACT").
		}

		set terminate to {
			parameter distance.
			return missionport:state = "Ready".
		}.

		dockInit().
	} else if mode = "Park" {
		mother:part:ship:connection:sendmessage(Lexicon(
			"type", "Klaw-Park",
			"mission", data["mission"],
			"station", data["station"]
		)).
		missionport:controlfrom.

		local station is vessel(data["station"]).
		set startPos to { return ship:position. }.
		set endPos to { return station:position. }.
		set zeroVelocity to { return station:velocity:orbit. }.
		set alignment to { return station:facing. }.
		set targetFacing to alignment.

		set pathQueue to List(
			List(data["park"], 0.5, 0.5, XYZOffset@)
		).

		local traversal is Traverse(station, XYZOffset(data["park"])).
		for node in traversal { pathQueue:insert(0, node). }
		
		set terminate to {
			parameter distance.
			if distance > 0.5 { return true. }
			vessel(data["kind"]):connection:sendmessage(Lexicon(
				"type", "kind",
				"mission", data["mission"]
			)).
			ship:connection:sendmessage("PARTNER RTB").
			return false.
		}.

		dockInit().
	} else if mode = "RTB" {
		
		if grapple:getmodule("modulegrapplenode"):hasevent("release") {
			when grapple:getmodule("moduleanimategeneric"):hasevent("disarm") then {
				grapple:getmodule("moduleanimategeneric"):doevent("disarm").
			}
		}
		when ship:parts:length < 20 then {
			perch:controlfrom.

			set startPos to { return perch:nodeposition. }.
			set endPos to { return nest:nodeposition. }.
			set zeroVelocity to { return mother:part:ship:velocity:orbit. }.
			set alignment to { return nest:portfacing. }.
			set targetFacing to { return nest:portfacing * R(180,0,0). }.

			set pathQueue to List(
				List(V(  0,  0,  5), 0.5, 0.5, XYZOffset@),
				List(V(  0,  0,  1), 0.5, 0.2, XYZOffset@),
				List(V(  0,  0,0.5), 0.2, 0.2, XYZOffset@),
				List(V(  0,  0,0.1), 0.2, 0.1, XYZOffset@),
				List(V(  0,  0,0.0), 0.2, 0.1, XYZOffset@)
			).
		
			local traversal is Traverse(mother:part:ship, endPos()).
			for node in traversal { pathQueue:insert(0, node). }

			set terminate to {
				parameter distance.
				return true.
			}.

			dockInit().
		}
	} else if mode = "Roost" {
	}
	print "Mode updated.".

	writejson(data, "1:/data.json").
	return true.
}

setMode(mode).

terminal:Input:clear.

until false {
	
	if terminal:input:haschar and 
		(terminal:input:getchar = terminal:input:backspace) 
	{
		clearscreen.
	}
	 
	if mode = "Sleep" { wait 1. }
	else {
	
		printData("Mode:",			01, mode).
		printData("Mission:",		03, data["Mission"]).
		printData("Station:",		04, data["Station"]).
		printData("Mission UID",	06, data["MissionPortUID"]).
		printData("Station UID:",	07, data["StationPortUID"]).
		printData("Slot:",			09, data["Slot"]).
		printData("Rotation:",		10, data["Rotation"]).
		printData("Park:",			11, data["Park"]).
		printData("Kind:",			13, data["Kind"]).

	}

	if (mode = "dock" and missionPort:state:startswith("Docked")) {
		// You deed it!
		unlock steering.
		set ship:control:neutralize to true.
		set data["RCSLoop"] to false.
		rcs off.
		setMode("AWACT").
		ship:connection:sendmessage("PARTNER RTB").
	}
	else if mode = "hold" and 
			ship:partstagged(tags[0] + " STB"):length > 0 and 
			tags[1] = "PRT" 
	{
		if data["Park"]:istype("Vector") { setMode("Park"). }
		else { setMode("Dock"). }
	}
	else if (mode = "rtb" and perch:state:startswith("Docked")) {
		// You're home!
		setMode("AWACT").
		mother:connection:sendmessage("KLAW HOME").
	}
	if rcsloop {
		set rcsLoop to dockUpdate().
		if rcsLoop = false { 
			print "RCS off".
		}
	} else { wait 1. }
	wait 0.
}


