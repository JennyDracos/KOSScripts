@lazyglobal off.

set terminal:width to 156.

clearscreen.

// Build Library
copypath("0:/boot/otv.ks","1:/boot/otv.ks").

compile "0:/libmath.ks" to "1:/libmath".
compile "0:/liborbit.ks" to "1:/liborbit".
compile "0:/liborbit_interplanetary.ks" to "1:/liborbit_interplanetary".

//compile "0:/exenode_peg_standalone.ks" to "1:/exenode".

copypath("0:/lib_ui.ks","1:/").
copypath("0:/libsimplex.ks","1:/").
copypath("0:/lib/node.ks","1:/lib/node.ks").
copypath("0:/lib/dock.ks","1:/lib/dock.ks").
copypath("0:/lib/ui.ks","1:/lib/ui.ks").

copypath("0:/lib/comms.ks","1:/lib/comms.ks").

set core:bootfilename to "/boot/otv.ks".

runoncepath("1:/lib/ui").
runoncepath("1:/liborbit_interplanetary").
runoncepath("1:/libsimplex.ks").
runoncepath("1:/lib/comms").
runoncepath("1:/lib/node").
runoncepath("1:/lib/dock").
runoncepath("0:/exenode_peg_standalone").

print "OTV Controller standing up.".

wait until ship:loaded and ship:unpacked.

global data is "".
if exists("1:/data.json") {
	set data to readjson("1:/data.json").
} else {
	set data to Lexicon().
}

if not data:haskey("phase") { set data["phase"] to "Inject". }
lock phase to data["phase"].

if not data:haskey("body") { set data["body"] to "Mun". }
if not data:haskey("inc") { set data["inc"] to 0. }
if not data:haskey("peri") { set data["peri"] to 400000. }
if not data:haskey("apo") { set data["apo"] to 400000. }
if not data:haskey("target") { set data["target"] to "KH Highport". }
if not data:haskey("steering") { set data["steering"] to 10. }
if not data:haskey("flipover") { set data["flipover"] to 300. }
if not data:haskey("cstab") { set data["cstab"] to false. }
if not data:haskey("klaw") { set data["klaw"] to false. }
if not data:haskey("commandq") { set data["commandq"] to Queue(). }
lock commandQueue to data["commandq"].
if not data:haskeY("parkTimer") { set data["parkTimer"] to 0. }
if not data:haskey("dvBudget") { set data["dvBudget"] to 0. }

if data:haskey("deltaTime") { set d_t to data["deltaTime"]. }

writejson(data, "1:/data.json").

set steeringmanager:maxstoppingtime to 5.
set steeringmanager:pitchpid:kd to 1.
set steeringmanager:yawpid:kd to 1.
function setSteer {
	set steeringmanager:pitchts to data["steering"].
	set steeringmanager:rollts to data["steering"].
	set steeringmanager:yawts to data["steering"].
}
setSteer().
on data["steering"] { setSteer(). }

print "OTV standing up with :" + data.

on abort {
	copypath("0:/boot/otv.ks", "1:/boot/otv.ks").
	set core:bootfilename to "/boot/otv.ks".
	reboot.
}

local execute is false.
on ag10 {
	print "Executing next node!".
	set execute to true.
	return true.
}

if hasnode { 
	remove nextnode. 
	wait 0.
}

function FindUID {
	parameter UID.
	local vessellist is "".
	list targets in vesselList.
	for vess in vesselList {
		if vess:loaded and vess:unpacked {
			for port in vess:DockingPorts {
				if port:UID = UID { return vess. }
			}
		}
	}
}

function ModuleCount {
	local newModuleList is Lexicon().
	for moduleEnd in ship:partstaggedpattern("Stern") {
		local moduleName is moduleEnd:tag:replace(" Stern","").
		local moduleEndUID is moduleEnd:uid.
		newModuleList:add(moduleName, moduleEndUID).
	}
	return newModuleList.
}
global moduleList is ModuleCount().

print moduleList.

set data["cstab"] to ship:partstagged(core:tag + " FORE"):length > 0.
set data["klaw"] to ship:partstagged(core:tag + " Prt"):length > 0 and
	ship:partstagged(core:tag + " Stb"):length > 0.


on ship:body {
	if body:name = data["transferThrough"] {
		if vessel(data["target"]):body = body { setMode("preinject"). }
		else { setMode("transferInject"). }
	}
	if data["phase"] = "eject" and body:name = data["transferThrough"] {
		setMode("transferIntercept").
	} else if data["phase"] = "transferIntercept" {
		setMode("transferInject").
	} else if data["phase"] = "transfer-pause" {
		setMode("transfer-finetune").
	}
	if body:name = data["body"] {
		setMode("preinject").
	}
}


local function findparent {
	parameter _b1, _b2r.

	local _b2 is _b2r.

	until false {
		if _b1:body = _b2:body {
			set data["transferFrom"] to _b1:name.
			set data["transferTo"] to _b2:name.
			set data["transferThrough"] to _b1:body:name.
			print data.
			return true.
		}
		until _b2:body:name = "Sun" {
			print " " + _b2:body:name.
			if _b1:body = _b2:body {
				set data["transferFrom"] to _b1:name.
				set data["transferTo"] to _b2:name.
				set data["transferThrough"] to _b1:body:name.
				print data.
				return true.
			}
			set _b2 to _b2:body.
		}
		
		set _b1 to _b1:body.
		set _b2 to _b2r.
	}
}.

on stage {
	if phase = "route" { setMode("transfer-finetune"). }
	else if phase = "transfer-finetune" { setMode("transfer-pause"). }
	else if phase = "transfer-pause" { setMode("transfer-finetune"). }
}

function PlotEject {
	parameter t_param, v_param, transferThrough is ship:body:body.

	function PlotEjectHelper {
		parameter t_0, v_s.

		local v_p is velocityat(ship:body, t_0):orbit.
		local v_sp is v_s - v_p.

		local r_0 is positionAt(ship, t_0) - ship:body:position.

		local v_esc_sq is 2 * ship:body:mu / r_0:mag.
		local v_0_m is sqrt(v_sp:sqrmagnitude + v_esc_sq).

		// knowing ta of periapsis is 0,
		local e is r_0:mag * v_0_m * v_0_m / ship:body:mu - 1.
		local a is 1 / (2 / r_0:mag - v_0_m * v_0_m / ship:body:mu).

		local eta is arccos(-1/e). // ta at infinity.

		local dir_up is vcrs(r_0:normalized, v_sp:normalized).
		local v_0_n is -vcrs(r_0, dir_up):normalized.

		local v_0 is v_0_n * v_0_m.

		return node(t_0, 0,0, v_0_m - velocityat(ship, t_0):orbit:mag).
	}.

	local zeroTime is t_param.
	print "Plotting ejection for time "+(zeroTime)+".".
	

	local t_e is GoldenSection(
		zeroTime,
		zeroTime + ship:orbit:period,
		{
			parameter t_e.

			local maneuver is PlotEjectHelper(t_e, v_param).
			add maneuver.
			wait 0.
			local dv is maneuver:deltav:mag.
			local burnTime is ManeuverTime(dv).
			if maneuver:eta < data["Flipover"] + burnTime {
				remove maneuver.
				return 1e10 - maneuver:eta.
			}
			local t_esc is time:seconds + maneuver:eta.
			local obt is maneuver:orbit.
			until obt:body = transferThrough or not obt:hasnextpatch {
				set t_esc to t_esc + obt:nextpatcheta.
				set obt to obt:nextpatch.
			}
			if obt:body <> transferThrough {
				remove maneuver.
				return 1e9.
			}
			local velDiff is (v_param - velocityat(ship, t_esc):orbit):mag.
			remove maneuver.
			wait 0.
			return velDiff.
		}
	).

	add PlotEjectHelper(t_e, v_param).
}

function setMode {
	parameter newMode.

	if newMode = "AWACT" {
		if phase = "Sleep" {
			set data["phase"] to "AWACT".
		}
		if commandQueue:length > 0 {
			ship:connection:sendmessage(commandQueue:pop()).
			return true.
		}
	}

	until not hasnode { 
		remove nextnode.
		wait 0.
	}
	if rcsLoop {
		dockFinal().
	}

	print "Updating phase to " + newMode.

	set data["phase"] to newMode.
	writejson(data, "1:/data.json").

	if phase = "route" {
	
		if hasnode { remove nextnode. }	

		local destination is "".

		if data["mission"] = "orbit" { 
			set destination to body(data["target"]). 
		} else {
			set destination to vessel(data["target"]). 
			if destination:body = ship:body {
				setMode("Intercept").
				return true.
			}
		}

		local done is findParent(ship, destination).

		if data["mission"] <> "Orbit" and data["transferTo"] = data["target"] { 
			set data["transferTo"] to "transfer".
			set data["body"] to destination:body:name.
		} else {
			set data["body"] to data["transferTo"].
		}

		local transferTo is "transfer".
		if data["transferTo"] = "transfer" { set transferTo to destination. }
		else { set transferTo to Body(data["transferTo"]). }

		local transferFrom is ship.
		if data["transferFrom"] <> ship:name { 
			set transferFrom to Body(data["transferFrom"]). 
		}
		local transferThrough is body(data["transferThrough"]).

		print data.

		if destination:body = transferThrough and 
			ship:body <> transferThrough and 
			destination:body:name <> "Sun" {

			setMode("Eject").

		} else { // Lambert.
			local hohmannFlightTime is
				pi * sqrt(((transferFrom:position - transferThrough:position):mag +
				(transferTo:position - transferThrough:position):mag) ^ 3 / 
				(8 * transferThrough:mu)).

			local firstCutoff is time:seconds + 6 * 60 * 60.
			if transferFrom = ship { set firstCutoff to time:seconds + 5 * 60. }
			
			local lambertParam is simplexSolver(
				List(firstCutoff, hohmannFlightTime),
				{
					parameter flightParam.	

					printData("ETA:",35,flightParam[1] - time:seconds).
					printData("Duration:",36, flightParam[2]).

					if flightParam[2] < hohmannFlightTime / 2 { 
						return 2e10 - flightParam[2]. 
					}

					local pos0 is positionat(transferFrom, flightParam[1]).
					local pos1 is positionat(transferTo, flightParam[1] + flightParam[2]).
					local posB is transferThrough:position.

					local r0 is pos0 - posB.
					local r1 is pos1 - posB.

					local dta is vang(r0, r1).
					if vdot(vcrs(r0, r1), v(0,1,0)) > 0 { set dta to clamp360(-dta). }

					local solution is LambertSolver(
					  r0:mag, r1:mag, 0, dta, flightParam[2], transferThrough:mu).

					local f is solution[5].
					local g is solution[6].
					local gprime is solution[7].
					local vburn is (r1 - f * r0) * (1 / g).
					local v0 is velocityat(transferFrom, flightParam[1]):orbit.
					local dv is vburn - v0.

					if flightParam[1] < time:seconds + 
										2 * ManeuverTime(dv:mag) + 
										data["flipover"] {
						return 1e10 - flightParam[1].
					}

					local vfin is (1/g) * (gprime * r1 - r0).
					local dv2 is velocityat(transferTo, 
							 flightParam[1] + flightParam[2]):obt - vfin.


					return abs(dv:mag + dv2:mag - data["dvBudget"]).
				},
				100,
				1
			).
			
			if data["transferFrom"] = ship:name {
				GetLambertInterceptNode(transferFrom, transferTo, 
				lambertParam[1], lambertParam[2], V(0,100,0)).
			} else { // Plan ejection!
				local pos0 is positionat(transferFrom, lambertParam[1]).
				local pos1 is positionat(transferTo, lambertParam[1] + lambertParam[2]).
				local posB is transferThrough:position.

				local r0 is pos0 - posB.
				local r1 is pos1 - posB.

				local dta is vang(r0, r1).
				if vdot(vcrs(r0, r1), v(0,1,0)) > 0 { set dta to clamp360(-dta). }

				local solution is LambertSolver(r0:mag, r1:mag, 0, dta, 
				   lambertParam[2], transferThrough:mu).

				local f is solution[5].
				local g is solution[6].
				local vburn is (r1 - f * r0) * (1 / g).

				PlotEject(lambertParam[1], vburn, transferThrough).
			}

		}
		return true.
	} else if phase = "IonPeri" {
		local periNode is GetApsisNodeAt(data["Peri"], 
			time:seconds + eta:apoapsis).
		if periNode:prograde > 100 { set periNode:prograde to 100. }
	} else if phase = "IonApo" {
		local apoNode is GetApsisNodeAt(data["Apo"], 
			time:seconds + eta:periapsis).
		if apoNode:prograde > 100 { set apoNode:prograde to 100. }
		add apoNode.
	} else if phase = "preinject" {
		getApsisNodeAt(data["peri"], time:seconds + 120).
		return true.
	}

	else if phase = "eject" {
		// Do this when we only need to eject into a transfer orbit.
		// This means from a moon to a planet.  Solar orbits are just too long.
	
		local rB is ship:body:position - ship:body:body:position.
		local v_horiz is vxcl(rB, ship:body:velocity:orbit).
		local a is (data["peri"] + ship:body:radius + rB:mag) / 2.
		set v_horiz:mag to getOrbVel(rB:mag, a, ship:body:body:mu).
		
		PlotEject(time:seconds + 100, v_horiz).
		
//		local departNode is node(time:seconds + 1800, 500, 0, 0).
//		local departTime is time:seconds + 1800.
//		add departNode.
//		
//		local escapeVelocity is sqrt(2 * constant:G * ship:body:mass / 
//			(ship:orbit:periapsis + ship:body:radius)) - 
//			ship:velocity:orbit:mag.
//
//		local burnCap is 0.
//		if ship:orbit:semimajoraxis < 0 { set burnCap to ship:orbit:nextpatcheta. }
//		else { set burnCap to ship:orbit:period. }
//
//		local maneuver is simplexSolver(
//			List(0,escapeVelocity * 1.1,0,0),
//			{
//				parameter tuple.
//				
//				set departNode:eta to tuple[1] + departTime - time:seconds.
//				set departNode:prograde to tuple[2].
//				set departNode:radialOut to tuple[3].
//				set departNode:normal to tuple[4].
//
//				if departNode:eta < data["flipover"] + 
//						ManeuverTime(departNode:deltaV:mag) {
//					return 6e10 - departNode:eta.
//				}
//				if departNode:eta > burnCap {
//					return 7e10.
//				}
//				if departNode:orbit:hasNextPatch() = false {
//					return 3e10.
//				}
//				local transferOrbit is departNode:orbit:nextPatch.
//				until transferOrbit:body:name = data["transferThrough"] {
//					if transferOrbit:hasNextPatch() = false {
//						return 1e10.
//					}
//					set transferOrbit to transferOrbit:nextPatch.
//				}
//				
//				if transferOrbit:hasNextPatch() {
//					return 3e10.
//				}
//
//				local incError to abs(transferOrbit:inclination) / 180 * 10. 
//				// 10x weighting.
//				local periError to abs(transferOrbit:periapsis - 400000) /
//					transferOrbit:body:soiradius.  // 1x weighting.
//				local deltaVError to departNode:deltaV:mag * .00001.  
//				local apoError to abs(transferOrbit:apoapsis - 
//					ship:body:apoapsis) / 10. // 10x weighting
//					
//				// /10000 weighting.
//
//				local error is sqrt(incError * incError + 
//									periError * periError + 
//									deltaVError * deltaVError).
//				printData("Inclination:",35,incError).
//				printData("Periapsis:",36,periError).
//				printData("Delta V:",37,deltaVError).
//				printData("Error:",39,error).
//
//				return error.
//			},
//			List(burnCap * .9, escapeVelocity * 2, 100, 100),
//			0.01
//		).
//
//		set departNode:eta to maneuver[1] + departTime - time:seconds.
//		set departNode:prograde to maneuver[2].
//		set departNode:radialOut to maneuver[3].
//		set departNode:normal to maneuver[4].
	}

	else if phase = "inject" {
		getApsisNodeAt(data["apo"], time:seconds + eta:periapsis).
//		local maneuver is SimplexSolver(
//			List(time:seconds + eta:periapsis, 0, 0, -100),
//			{
//				parameter tuple.
//				
//				local man is node(tuple[1], tuple[2], tuple[3], tuple[4]).
//				add man.
//				local orbit is man:obt.
//				local soi is Kerbin:altitude * 5.
//				if ship:body <> Sun {
//					set soi to ship:body:soiradius.
//				}
//				local incError is (data["inc"] - orbit:inclination) / 90.
//				local periError is (data["peri"] - orbit:periapsis) / soi.
//				local apoError is (data["apo"] - orbit:apoapsis) / soi.
//
//				remove man.
//				wait 0.
//
//				local error is incError * incError +
//								periError * periError +
//								apoError * apoError.
//				return sqrt(error).
//			},
//			List(10, 10, 10, 10),
//			0.01
//		).
//		local man is node(maneuver[1], maneuver[2], maneuver[3], maneuver[4]).
//		add man.
		return true.
	}

	else if phase:contains("intercept") {
		local targetOrbital is vessel(data["target"]).
		if phase:startswith("transfer") {
			set targetOrbital to Body(data["transferTo"]).
		}

		local interceptGuess is 0.
		if ship:orbit:hasnextpatch {
			set interceptGuess to time:seconds + 
											0.5 * ship:orbit:nextpatcheta.
		} else {
			set interceptGuess to time:seconds + 0.5 * ship:orbit:period.
		}

		local hohmannFlightTime is 
			pi * sqrt(((ship:position - ship:body:position):mag + 
			(targetOrbital:position - ship:body:position):mag) ^ 3 / 
			(8 * ship:body:mu)).
	
		local lambertParam is patternSearch(
			List(interceptGuess, hohmannFlightTime),
			{
				parameter flightParam.

				printData("t_bo:          ",35,(flightParam[1] - time):clock).
				printData("t_coast:       ",36,time(flightParam[2]):clock).

				if flightParam[1] < time:seconds + 120 { 
					return 2e10 + time:seconds - flightParam[1]. 
				}
				else if flightParam[2] < hohmannFlightTime / 2 { 
					return 3e10 + flightParam[2]. 
				}

				local testNode is GetLambertInterceptNode(
					  ship, 
					  targetOrbital, 
					  flightParam[1], 
					  flightParam[2],
					  V(0, 100, 0)
				).
				if testNode:orbit:periapsis < 
						min(ship:periapsis, targetOrbital:periapsis) * 0.99 { 
					local periapsisError is 1e10 + targetOrbital:periapsis - 
							testNode:orbit:periapsis.
					remove testNode.
					wait 0.
					return periapsisError.
				}
				local deltaV is testNode:deltaV:mag + 
					  (velocityat(ship, flightParam[1] + flightParam[2]):orbit -
					   velocityat(targetOrbital, flightParam[1] + flightParam[2]):orbit):mag.

				remove testNode.
				wait 0.
				return deltaV.
			},
			1024
		).

		GetLambertInterceptNode(ship, targetOrbital, lambertParam[1], 
			lambertParam[2], V(0, 100, 0)).
		return true.
	} else if phase:startsWith("transfer") and ship:body:name = data["Body"] {
		setMode("Preinject").
		return true.
	// Improve inject to transfer orbit
	} else if phase = "transfer-finetune" and ship:orbit:HasNextPatch and 
		(ship:orbit:nextPatch:body:name = data["TransferTo"] or data["TransferTo"] = "transfer") {

		local transferOrbital is data["transferTo"].
		if transferOrbital = "transfer" {
			set transferOrbital to body(data["transferThrough"]).
		} else {
			set transferOrbital to body(data["transferTo"]).
		}

		local burnAt is time:seconds + 180.
		local tuneNode is node(burnAt, 0, 0, 0).
		add tuneNode.

		local maneuver is simplexSolver(
			List(0, 0, 0, 0),
			{
				parameter tuple.
				
				set tuneNode:eta to burnAt + tuple[1] - time:seconds.
				set tuneNode:prograde to tuple[2] / 100.
				set tuneNode:normal to tuple[3] / 100.
				set tuneNode:radialout to tuple[4] / 100.

				if tuneNode:eta < data["flipover"] + 
				   ManeuverTime(tuneNode:deltaV:mag) {
					print "Too soon".
					return 2e10.
				}

				local patch is tuneNode:orbit.
				until (not patch:hasNextPatch) or (patch:body = transferOrbital) {
					set patch to patch:nextPatch.
				}

				if patch:body = transferOrbital {
					local deltaVParam is tuneNode:deltaV:mag * 0.001. 
					// /1000 weight.
					local incParam is (patch:inclination - data["inc"]) /
					   90 * 10. // 10x weight
					local soirad is Kerbin:altitude * 2.
					if transferOrbital <> Sun {
						set soirad to transferOrbital:soiradius.
					}.
					local periParam is (patch:periapsis - data["peri"]) /
					   soirad.  // 1x weight
					printData("Delta V Param:", 35, deltaVParam).
					printData("Inclination P:", 36, incParam).
					printData("Periapsis Par:", 37, periParam).

					return sqrt(incParam * incParam + periParam * periParam + 
					   deltaVParam * deltaVParam).
				} else {
					print "Miss".
					return 1e10.
				}
			},
			List(500,100,100,100),
			0.1
		).

		set tuneNode:eta to maneuver[1].
		set tuneNode:prograde to maneuver[2] / 100.
		set tuneNode:normal to maneuver[3] / 100.
		set tuneNode:radialout to maneuver[4] / 100.

		if ship:orbit:hasNextPatch() and tuneNode:eta > ship:orbit:nextPatchETA() {
			set tuneNode:prograde to 0.
			set tuneNode:normal to 0.
			set tuneNode:radialOut to 0.
		}
		return true.

	} // Improve Intercept
	else if phase:contains("finetune") {
		local targetOrbital is 0.
		if phase:startswith("rendezvous") or data["transferTo"] = "transfer" {
			set targetOrbital to vessel(data["target"]).
		} else {
			set targetOrbital to body(data["transferTo"]).
		}
		local interceptTime is globalSection(
			time:seconds, 
			100,
			{ 
				parameter t. 
				return (positionat(ship, t) - positionat(targetOrbital, t)):mag.
			}, 
			0.1, 
			100
		).
//		local interceptTime is getClosestApproach(ship, targetOrbital)[0].

		local intercept is patternSearch(
			List(time:seconds + 120),
			{
				parameter tuple.
				local flightTime is interceptTime - tuple[1].

				local testNode is GetLambertInterceptNode(
					ship,
					targetOrbital,
					tuple[1],
					flightTime,
					V(0, 100, 0)
				).

				local deltaV is testNode:deltaV:mag + 
					(velocityat(ship, interceptTime):orbit - 
					velocityat(targetOrbital, interceptTime):orbit):mag.

				remove testNode.

				if tuple[1] < time:seconds + 120 set deltaV to deltaV * 100.

				printData("t_bo:          ",35,round(tuple[1],0.1)).
				printData("t_coast:       ",35,round(flightTime,0.1)).
				return deltaV.
			},
			120
		).

		GetLambertInterceptNode(ship, targetOrbital, intercept[1], 
			interceptTime - intercept[1], V(0, 100, 0)).
		return true.
	}

	else if phase:contains("match") {
		local targetVessel is vessel(data["target"]).
		local interceptTime is getClosestApproach(ship, targetVessel)[0].

		local node is getNode(velocityAt(ship, interceptTime):orbit, 
			velocityAt(targetVessel, interceptTime):orbit,
			positionAt(ship, interceptTime) - ship:body:position, interceptTime).

		add node.
		return true.
	}

	else if phase = "Park" {
		core:part:controlfrom.
		local targetVessel is vessel(data["target"]).
		
		set startPos to { return ship:position. }.
		set zeroVelocity to { return targetVessel:velocity:orbit. }.
		set endPos to { return targetVessel:position. }.
		set alignment to { return targetVessel:facing. }.
		set targetfacing to { return targetVessel:facing. }.

		local d is getBounds(targetVessel)[1] + getBounds()[1].

		set pathQueue to List(
			List(V(  0,d, 0), 1.0, 1.0, XYZOffset@)
		).

		local traversal is Traverse(targetVessel, XYZOffset(V(0,100, 0))).
		if traversal:length > 0 { for node in traversal {
			pathQueue:insert(0, node).
		}}

		set rcsloop to true.
		set data["parkTimer"] to time:seconds + 120.
		set terminate to { 
			parameter distance.
			if distance < 0.5 and data["parkTimer"] < time:seconds and
				(targetVessel:velocity:orbit - ship:velocity:orbit):mag < 0.1 {
				set data["parkTimer"] to time:seconds + 120.
				if commandQueue:length > 0 {
					ship:connection:sendmessage(commandQueue:pop()).
				}
			}
			return true. 
		}.
		dockInit().
		return true.
	}
	print "All else.".
	if phase = "Dock" {
		print "Running Dock.".
		local ownDock is "".
		local stationDock is "".
		for port in ship:partsTaggedPattern("Cap") {
			if port:istype("DockingPort") and port:state = "Ready" {
				set ownDock to port.
			}
		}
		local moduleDock is (ownDock = "").
		if moduleDock {
			for port in ship:partsTaggedPattern("Bow") {
				if port:istype("DockingPort") and port:state = "Ready" {
					set ownDock to port.
				}
			}
		}

		local station is vessel(data["target"]).
		local pattern is "Small Dock".
		if moduleDock { set pattern to "Module Dock". }
		for port in station:partsTaggedPattern(pattern) {
			if port:istype("DockingPort") and port:state = "Ready" {
				set stationDock to port.
			}
		}
		if station:partsTaggedPattern("Bow Dock"):length > 0 {
			local bowDock is station:partsTaggedPattern("Bow Dock")[0].
			if bowDock:isType("DockingPort") and bowDock:state = "Ready" {
				set stationDock to bowDock.
			}
		}


		ownDock:controlFrom.

		set startPos to { return ownDock:position. }.
		set zeroVelocity to { return station:velocity:orbit. }.
		set endPos to { return stationDock:nodePosition. }.
		set alignment to { return stationDock:portFacing. }.
		set targetFacing to { return lookdirup(-(stationDock:facing:vector), 
							  stationDock:facing:upVector). }.

		set pathQueue to List(
			List(V(0, 0, 5), 0.5, 0.5, XYZOffset@),
			List(V(0, 0, 1), 0.2, 0.2, XYZOffset@),
			List(V(0, 0, 0), 0.1, 0.1, XYZOffset@)
		).

		local traversal is Traverse(station, endPos()).
		for node in traversal { pathQueue:insert(0, node). }

		set terminate to { 
			parameter distance. 
			if ownDock:state:startswith("Docked") { return false. }
			return true. 
		}.

		dockInit().
		return true.
	}

	writejson(data, "1:/data.json").

	return true.
}


set commsHandler to {
	parameter content.

	if content:istype("Lexicon") {
		if not content:haskey("type") {
			print "Malformed message. Dump.".
			return true.
		} else if content["type"] = "Data" and
		   (content:haskey("to") = false or content["to"] = core:tag) 
		{
			content:remove("type").
			if content:haskey("to") { content:remove("to"). }
			for key in content:keys {
				set data[key] to content[key].
			}	
		} else if content["type"] = "Queue" and
		   (content:haskey("to") = false or content["to"] = core:tag) 
		{
			commandQueue:push(content["command"]).
		}
	} else if content:startsWith("QUEUE") {
		commandQueue:push(content:replace("QUEUE ","")).
	} else if content = core:Tag + " WAKE" {
		setMode("AWACT").
	} else if content = "CSTAB HOME" {
		set data["cstab"] to (ship:partstagged(core:tag + " Fore"):length > 0).
	} else if content = "KLAW HOME" {
		set data["klaw"] to 
			ship:partsTagged(core:tag + " stb"):length > 0 and
			ship:partsTagged(core:tag + " prt"):length > 0.
	}

	if phase <> "Sleep" {
		if content:istype("Lexicon") {
			if content["type"] <> "otv" {
				print "Misdirected mail.  Dump.".
			}
		} else if content = core:tag + " SLEEP" {
			setMode("Sleep").
		} else if content:startsWith("RDV") {
			set data["target"] to content:replace("RDV ","").
			set data["mission"] to "rendezvous".
			setMode("route").
		} else if content:startsWith("ORBIT") {
			set data["target"] to content:replace("ORBIT ","").
			set data["mission"] to "orbit".
			setMode("route").
		} else if content = "DOCK" {
			setMode("Dock").
		} else if content = "PARK" {
			setMode("Park").
		} else if content:startsWith("ION") {
			local alt is content:replace("ION ",""):tonumber(400) * 1000.
			set data["apo"] to alt.
			set data["peri"] to alt.
			if ship:apoapsis > alt { setMode("IonPeri"). }
			else { setMode("IonApo"). }
		} else if content:startswith("DEPLOY ") {
			local deployModule is content:replace("DEPLOY ","").
			if moduleList:haskey(deployModule) = false {
				print "Unable to deploy module " + deployModule.
				return true.
			}
			local modulePortUID is moduleList[deployModule].
			local modulePort is "".
			for port in ship:dockingports {
				if port:uid = modulePortUID {
					set modulePort to port.
				}
			}
			on ship:parts:length {
				local module is findUID(modulePortUID).

				local dockMessage is Lexicon(
					"type", "klaw",
					"mission", module:name,
					"station", data["target"],
					"missionport",modulePort:tag,
					"stationport","Module Dock",
					"cstab",data["cstab"]
				).
				if data["klaw"] {
					ship:connection:sendmessage(dockMessage).
				} else {
					vessel(data["target"]):connection:sendmessage(dockMessage).
				}
				set data["cstab"] to false.
				return false.
			}
			modulePort:undock.
		}
	}

	writejson(data, "1:/data.json").

	return true.
}.

function PushPhase {
	if data["phase"] = "transfer-finetune" {
		setMode("transfer-pause").
	} else if data["phase"] = "route" {
		setMode("transfer-finetune").
	} else if data["phase"] = "eject" {
		setMode("transfer-finetune").
	} else if data["phase"] = "preinject" {
		setMode("inject").
	} else if data["phase"] = "inject" {
		if data["mission"] = "Orbit" {
			ship:connection:sendmessage(core:tag + " SLEEP").
		} else {
			setMode("intercept").
		}
	} else if data["phase"] = "intercept" {
		setMode("rendezvous-finetune").
	} else if data["phase"] = "rendezvous-finetune" {
		setMode("match").
	} else if data["phase"] = "match" {
		setMode("AWACT").
	} else if data["phase"]:startsWith("Ion") {
		if ship:apoapsis < data["apo"] { setMode("IonApo"). }
		else if ship:periapsis < data["peri"] { setMode("IonPeri"). }
		else { setMode("AWACT"). }
	}
}

print data["phase"].
if phase = "transfer-finetune" and body:name = data["transferTo"] {
	setMode("preinject").
} else if phase = "transfer-finetune" and 
		  data["transferTo"] = "transfer" and 
		  body:name = data["transferThrough"] {
	setMode("preinject").
} else if phase = "transfer-pause" {
	setMode("transfer-finetune").
} else {
	setMode(phase).
}

local refreshTimer is 0.

until false {
	//		   123456789012345
	printData("Phase:"         , 01, data["phase"]).
	
	printData("Body:"          , 03, data["body"]).
	printData("Inclination:"   , 04, data["inc"]).
	printData("Periapsis:"     , 05, data["peri"]).
	printData("Apoapsis:"      , 06, data["apo"]).

	printData("Target:"        , 08, data["target"]).

	printData("Steering:"      , 10, data["steering"]).
	printData("Flip Time:"     , 11, data["flipover"]).

	printData("Stabilizer:"    , 13, data["cstab"]).
	printData("Klaws:"         , 14, data["klaw"]).
	
	printData("Command Queue:" , 16, data["commandq"]:length).
	printData("Park Timer:"    , 17, 
	 min(0, (data["parkTimer"] - time):seconds)
	).

	if refreshTimer < time:seconds {
		clearUI().
		set refreshTimer to time:seconds + 10.
	}

	if data["phase"] = "Sleep" {
		wait 1.
	}

	if execute {
		set burnloop to false.
		set execute to false.

		print "Calling exenode...".
		exenode_peg().
		print "Exenode terminated.".

		lock throttle to 0.
		unlock steering.

		PushPhase().
		wait 0.
	} else if rcsLoop {
		set rcsLoop to dockUpdate().
	} else if burnLoop and BurnUpdate() {
		set burnLoop to false.


		lock throttle to 0.
		unlock steering.

		PushPhase().
		wait 0.
	} else if burnLoop {
		wait 0.
	} else if hasnode {
		core:part:controlfrom.

		rcs on.

		if nextnode:deltav:mag < 0.1 {
			remove nextnode.
			wait 0.
			PushPhase().
		} else if ManeuverTime(nextnode:deltav:mag) < 2 {
			RunNode().
			PushPhase().
		} else if data["phase"] = "Match" {
			BurnMatch(time:seconds + nextNode:eta,
					 vessel(data["target"])).
		} else {
			BurnNode().
		}
	} else {
		wait 1.
	}

}


