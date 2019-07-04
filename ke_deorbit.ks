function offset {
	parameter angle.

	if angle < 0 { return 360 + angle. }
	return angle.
}


set sasmode to "stabilityassist".

sas off.

for cargoBay in ship:modulesnamed("ModuleCargoBay") {
	if cargoBay:Part:GetModule("ModuleAnimateGeneric"):HasEvent("Close") {
		cargoBay:Part:GetModule("ModuleAnimateGeneric"):DoEvent("Close"). 
	}
}

for fuelCell in ship:modulesnamed("ModuleResourceConverter") {
	if fuelCell:hasField("Start Fuel Cell") { fuelCell:DoEvent("Start Fuel Cell"). }
}

lock throttle to 0.

list engines in engineList.
for engine in engineList {
	if engine:name = "RAPIER" {
		if engine:mode = "AirBreathing" { engine:togglemode. }
		engine:activate.
	}
}

lock steering to retrograde.

clearscreen.

print "Waiting for proper horizon.".

lock relativelongitude to offset(offset(-ship:longitude) - 74.7).

set phaseDifference to 160.

print "Waiting for next orbit." at (0,0).

until relativelongitude > phaseDifference {
	print relativelongitude at (0,1).
	print phaseDifference at (0,2).
}

print "Waiting for proper horizon." at (0,0).

until relativelongitude < phaseDifference {
	print relativelongitude at (0,1).
	print phaseDifference at (0,2).
	wait 1.
}

kuniverse:timewarp:cancelwarp.


print "Deorbiting.".

lock throttle to 0.2.

until ship:periapsis < 30000 {
	wait 1.
}

lock throttle to 0.0.

lock steering to srfprograde.

until ship:altitude < 20000 {
	wait 1.
}

for engine in engineList {
	if engine:name = "RAPIER" { engine:togglemode. }
}

until ship:altitude < 10000 {
	wait 1.
}
set ship:control:pilotmainthrottle to 0.

run pilot.
