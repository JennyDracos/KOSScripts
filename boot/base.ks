@lazyglobal off.

copypath("0:/boot/base.ks", "1:/boot/base.ks").
copypath("0:/lib/comms.ks", "1:/lib/comms.ks").

runoncepath("1:/lib/comms").

set core:bootfilename to "boot/base.ks".


on abort {
	copypath("0:/boot/base.ks", "1:/").
	reboot.
}

if core:volume:exists("data.json") {
	global data is readjson("1:/data.json").
} else {
	global data is Lexicon().
	writejson(data, "1:/data.json").
}

clearscreen.

print "Running Base v0.0.2.".


on ship:controlpart {
	if ship:controlpart:children:length = 0 or
		ship:controlpart:parent = "" {
		core:part:controlfrom.
	} else if ship:controlpart <> core:part {
		if highlitPart <> "" { set highlighting:enabled to false. }
		set highlitPart to ship:controlpart.
		if highlitPart:parent:istype("dockingnode") { set highlitpartner to highlitPart:parent. }
		else { set highlitPartner to highlitPart:children[0]. }
		core:part:controlfrom.
		set highlighting to highlight(highlitPart, blue).
	}
	return true.
}

on ship:parts {
	for hatch in ship:modulesnamed("moduledockinghatch") {
		if hatch:hasevent("open hatch") {
			hatch:doevent("open hatch").
		}
	}
}

set commsHandler to {
	parameter content.

	if content:istype("Lexicon") {
		return true.
	} else if content:startswith("Request Landing") {
		local request is content:replace("REQUEST LANDING ",""):split(" ").
		local site is request[0].
		local requester is request[1].
		if site = "PAD" {
			for port in ship:dockingports {
				if port:tag:contains("PAD") and port:state = "Ready" {
					set site to port:tag.
				}
			}
		} else if site = "FIELD" {
			// find airlock
			// get geoposition of point 5 meters past airlock
		} else if site = "SLOT" {
			for tube in ship:partsnamed("MKS.FlexOTube") {

			// find flexotube w/ no parent or no children
			}
		}
		vessel
		set data["Requester"] to requester.
		set data["Response"] to site.
	}
}.

until false {
	sas off.

	core:part:controlfrom.

	local translate is V(0,0,0).

	wait 1.
}


print "Station completed.  Um.".
