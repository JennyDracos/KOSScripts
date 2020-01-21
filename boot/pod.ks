@lazyglobal off.

clearscreen.

// Build Library
for name in List(
	"libmath",
	"liborbit",
	"liborbit_interplanetary"
) compile "0:/"+name+".ks" to "1:/"+name.

//compile "0:/exenode_peg_standalone.ks" to "1:/exenode".
for name in List(
	"boot/pod.ks",
	"libsimplex.ks",
	"lib/node.ks",
	"lib/dock.ks",
	"lib/ui.ks",
	"lib/comms.ks",
	"lib/landing.ks",

	"lib/bisectionsolver.ks"
) copypath("0:/" + name, "1:/" + name).

set core:bootfilename to "/boot/pod.ks".

clearguis().
runoncepath("1:/lib/ui").
runoncepath("1:/liborbit_interplanetary").
runoncepath("1:/libsimplex.ks").
runoncepath("1:/lib/comms").
runoncepath("1:/lib/node").
runoncepath("1:/lib/landing").
runoncepath("1:/lib/dock").

print "Pod Controller standing up.".

wait until ship:loaded and ship:unpacked.

global data is "".
if exists("1:/data.json") {
	set data to readjson("1:/data.json").
} else {
	set data to Lexicon().
}

lock phase to data["phase"].

if not data:haskey("phase") {
	set data:phase to choose "AWACT" if ship:partstagged("Booster"):empty else "Launch".
}
if not data:haskey("body") { set data["body"] to "Kerbin". }
if not data:haskey("inc") { set data["inc"] to 0. }
if not data:haskey("peri") { set data["peri"] to 80000. }
if not data:haskey("apo") { set data["apo"] to 80000. }
if not data:haskey("target") { set data["target"] to "KH Highport". }
if not data:haskey("flipover") { set data["flipover"] to 10. }
if not data:haskey("commandq") { set data["commandq"] to Queue(). }
lock commandQueue to data["commandq"].
if not data:haskeY("parkTimer") { set data["parkTimer"] to 0. }
if not data:haskey("dvBudget") { set data["dvBudget"] to 0. }

if data:haskey("deltaTime") { set d_t to data["deltaTime"]. }

writejson(data, "1:/data.json").

print "Pod standing up with :" + data.

addDisplayData("Phase",{ return data["phase"]. }).

addDisplayData("Body",{ return data["body"]. }).
addDisplayData("Inclination",{ return data["inc"]. }).
addDisplayData("Periapsis",{ return data["peri"]. }).
addDisplayData("Apoapsis",{ return data["apo"]. }).

addDisplayData("Target",{ return data["target"]. }).
addDisplayData("Command Queue",{return data["commandq"]:length.}).
addDisplayData("Park Timer",{return max(0, (data["parkTimer"]-time):seconds).}).

startUI().

on round(time:seconds) {
	displayUpdate().
	return true.
}

on abort {
	copypath("0:/boot/pod.ks", "1:/boot/pod.ks").
	set core:bootfilename to "/boot/pod.ks".
	reboot.
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
	if data["phase"] = "Return" and body:name = data["transferThrough"] {
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

local function lambertDV {
	parameter flightParam, mincoast.
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
						2 * ManeuverTime(dv:mag) {
		return 1e10 - flightParam[1].
	}

	local vfin is (1/g) * (gprime * r1 - r0).
	local dv2 is velocityat(transferTo, flightParam[1] + flightParam[2]):obt - vfin.


	return abs(dv:mag + dv2:mag - data["dvBudget"]).
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

	if rcsLoop {
		dockFinal().
	}

	if newMode:startswith("Execute") = false {
		until not hasnode { 
			remove nextnode. 
			wait 0.
		}
	}

	print "Updating phase to " + newMode.

	set data["phase"] to newMode.
	writejson(data, "1:/data.json").

	if newMode = "Prelaunch" {
		when ship:maxthrust > 0 then {
			SetMode("Launch").
		}
	}

	else if newMode = "Launch" {
		print "Running ascent.".
		runpath("booster:/launch_pitch_jerk.ks", 80000).
		SetMode("RaisePeri").
	}

	else if newMode = "RaisePeri" {
		getApsisNodeAt(data:peri, time:seconds + min(eta:apoapsis, eta:periapsis)).
	}

	else if phase = "route" {
	
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

		// If we are going from planet to moon, Transfer.
		// If we are going from moon to planet, Return.
		// If we are going from moon to moon, Lambert.
		// Else Intercept.
		if destination:body = transferThrough and ship:body = transferThrough {
			setMode("Intercept").
		} else if destination:body = transferThrough {
			setMode("Return").
		} else if ship:body = transferThrough {
			setMode("Transfer").
		} else {
			setMode("Lambert").
		}

		return true.

	} else if newMode = "Transfer" {
		// Plot a hohmann transfer to the target's altitude.
		local destination is body(data:body).
		local orb_d is destination:orbit.
		
		local firstCutoff is time:seconds + 6 * 60.
		local maxGuess is ship:orbit:period.
	
		function hohBurnAtTime {
			parameter ut.

			local sma_d is orb_d:semimajoraxis.
			local e_d is orb_d:eccentricity.

			local M_d_t is destination:obt:meananomalyatepoch +
			      sqrt(ship:body:mu / (sma_d * sma_d * sma_d)) * (ut - destination:obt:epoch).
			local ta_t is M_d_t + 2*e_d*sin(M_d_t) + 1.25 * e_d * e_d * sin(2 * M_d_t).
			local ta_t2 is clamp360(ta_t + 180).

			local r_d_t2 is sma_d * (1 - e_d * e_d) / (1 + e_d * cos(ta_t2)).

			local p_s_t is positionat(ship, ut).
			local r_s_t is (p_s_t - ship:body:position):mag.

			local hohmannFlightTime is 
				pi * sqrt((r_s_t + r_d_t2)  ^ 3 / (8 * ship:body:mu)).

			local t2 is ut + hohmannFlightTime.
			local p_s_t2 is p_s_t + (ship:body:position - p_s_t):normalized * (r_s_t + r_d_t2).

			return List(r_d_t2, (positionat(destination, t2) - p_s_t2):mag).
		}
			
		local boostTime is globalSection(firstCutoff, maxGuess/10, {
			parameter t_boost.

			return hohBurnAtTime(t_boost)[1].
		}).

		getApsisNodeAt(hohBurnAtTime(boostTime)[0], boostTime).

		set data:phase to "ExecuteTransfer".

	} else if newMode = "Lambert" {
		// Lambert.
		local hohmannFlightTime is
			pi * sqrt(((transferFrom:position - transferThrough:position):mag +
			(transferTo:position - transferThrough:position):mag) ^ 3 / 
			(8 * transferThrough:mu)).

		local firstCutoff is time:seconds + 6 * 60 * 60.
		if transferFrom = ship { set firstCutoff to time:seconds + 5 * 60. }
		
		AddDisplay("Lam").

		local lambertParam is simplexSolver(
			List(firstCutoff, hohmannFlightTime),
			{
				parameter flightParam.	

				//printData("ETA:",35,flightParam[1] - time:seconds).
				SetDisplayData("ETA",flightParam[1] - time:seconds,"Lam").
				//printData("Duration:",36, flightParam[2]).
				SetDisplayData("Duration",flightParam[2],"Lam").

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
									2 * ManeuverTime(dv:mag) {
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
	
		RemoveDisplay("Lam").

		SetMode("ExecuteLambert").
		return true.
	} else if phase = "preinject" {
		local injectNode is Node(time:seconds + 60, 0, 0, 0).
		add injectNode.
		local nodeMod is simplexSolver(
			List(0, 0, 0),
			{
				parameter tuple.

				set injectNode:prograde to tuple[1].
				set injectNode:radialout to tuple[2].
				set injectNode:normal to tuple[3].

				local incError is (injectNode:orbit:inclination - data:inc) / 90.
				print "Inc: " + incError * 90.
				local periError is choose
				  (injectNode:orbit:periapsis - data:peri) 
				  if incError > 1 else
				  (injectNode:orbit:periapsis + 2 * body:radius - data:peri).
				set periError to periError / body:soiRadius.
				print "Pe: " + periError * body:soiRadius.
				return 100 * incError * incError + 100 * periError * periError.
			},
			100
		).
		set injectNode:prograde to nodeMod[1].
		set injectNode:radialout to nodeMod[2].
		set injectNode:normal to nodeMod[3].

		return true.
	} else if phase = "Peri" {
		local ut is time:seconds + 120.
		local rB is positionat(ship, ut) - ship:body:position.
		local rB_n is rB:normalized.
		local a is (data["apo"] + ship:body:radius + rB:mag) / 2.
		local v_peri is vcrs(rB_n, V(0,1,0)).
		set v_peri:mag to getOrbVel(rb:mag, a, ship:body:mu).
		local nd is getNode(velocityat(ship, ut):orbit, v_peri, rB, ut).
		add nd.
		return true.
	}

	else if phase = "Return" {
		// Do this when we only need to eject into a transfer orbit.
		// This means from a moon to a planet.  Solar orbits are just too long.
	
		local rB is ship:body:position - ship:body:body:position.
		local v_horiz is vxcl(rB, ship:body:velocity:orbit).
		local a is (data["peri"] + ship:body:radius + rB:mag) / 2.
		set v_horiz:mag to getOrbVel(rB:mag, a, ship:body:body:mu).
		
		PlotEject(time:seconds + 100, v_horiz).
		
	}

	else if phase = "inject" {
		local ut is time:seconds + eta:periapsis.
		local rB is positionat(ship, ut) - ship:body:position.
		local rB_n is rB:normalized.
		local a is (data["apo"] + ship:body:radius + rB:mag) / 2.
		local v_apo is vcrs(rB_n, V(0,1,0)).
		set v_apo:mag to getOrbVel(rb:mag, a, ship:body:mu).
		local nd is getNode(velocityat(ship, ut):orbit, v_apo, rB, ut).
		add nd.
		return true.
	}

	else if phase = "intercept" {
		local targetOrbital is vessel(data:target).

		function hohTime {
			parameter uta.

			local sma is (positionat(ship, uta) - ship:body:position):mag +
			             (positionat(targetOrbital, uta) - ship:body:position):mag.

			return pi * sqrt((sma * sma * sma) / (8 * ship:body:mu)).
		}
		function searchSeed {
			parameter uta.

			return List(uta, hohTime(uta)).
		}

	 	local maxGuess is choose ship:orbit:nextpatcheta if ship:orbit:hasnextpatch else 
			1 / abs(1 / ship:orbit:period - 1 / targetOrbital:orbit:period).
		local interceptParams is globalSimplex(
			List(searchSeed(time:seconds + 60), searchSeed(time:seconds + maxGuess * 0.4),
				searchSeed(time:seconds + maxGuess * 0.8)),
			{
				parameter tuple.

				if tuple[1] < time:seconds + 60 { return 3e9 - tuple[1]. }
				if tuple[2] < 0.2 * hohTime(tuple[1]) { return 2e9 - tuple[2]. }

				local testNode is getLambertInterceptNode(
					ship,
					targetOrbital,
					tuple[1],
					tuple[2],
					V(0, 100, 0)
				).
				wait 0.

				if testNode:orbit:periapsis < max(ship:body:atm:height, 10000) {
					local periapsisError is 1e9 - testNode:orbit:periapsis.
					remove testNode.
					wait 0.
					return periapsisError.
				}

				local deltaV is testNode:deltaV:mag +
					(velocityAt(ship, tuple[1] + tuple[2]):orbit -
					 velocityAt(targetOrbital, tuple[1] + tuple[2]):orbit):mag.

				remove testNode.
				wait 0.
				return deltaV.
			},
			100
		).
		
		GetLambertInterceptNode(ship, targetOrbital, interceptParams[1], interceptParams[2], 
			V(0, 100, 0)).
		setMode("ExecuteIntercept").
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

		AddDisplay("Finetune").

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
					return 2e10 + tuneNode:eta.
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
					setDisplayData("Delta V Param", deltaVParam, "Finetune").
					setDisplayData("Inclination P", incParam, "Finetune").
					setDisplayData("Periapsis Par", periParam, "Finetune").

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

		RemoveDisplay("Finetune").

		set tuneNode:eta to maneuver[1].
		set tuneNode:prograde to maneuver[2] / 100.
		set tuneNode:normal to maneuver[3] / 100.
		set tuneNode:radialout to maneuver[4] / 100.

		if ship:orbit:hasNextPatch() and tuneNode:eta > ship:orbit:nextPatchETA() {
			remove tuneNode.
		} else if tuneNode:eta < data["flipover"] {
			remove tuneNode.
		}
		return true.

	} // Improve Intercept
	else if phase:contains("finetune") {
		local targetOrbital is choose vessel(data["target"]) if
			phase:startswith("rendezvous") or data["transferTo"] = "transfer"
		else body(data["transferTo"]).

		local interceptTime is globalSection(
			time:seconds, 
			choose ship:orbit:nextpatcheta / 10 if ship:orbit:hasnextpatch else 
			choose targetOrbital:orbit:nextpatcheta / 10 if targetOrbital:orbit:hasnextpatch else
			1 / (1 / ship:orbit:period + 1 / targetOrbital:orbit:period) / 10,
			{ 
				parameter t. 
				return (positionat(ship, t) - positionat(targetOrbital, t)):mag.
			}, 
			0.1, 
			100
		).
//		local interceptTime is getClosestApproach(ship, targetOrbital)[0].

		AddDisplay("Int").

		local intercept is patternSearch(
			List(time:seconds + 120),
			{
				parameter tuple.
				local flightTime is interceptTime - tuple[1].
				local offset is choose v(0,100,0) if targetOrbital:istype("vessel") else
				  lookdirup(-positionAt(targetOrbital, interceptTime):normalized, V(0,0,1)) * 
				    (targetOrbital:soiradius * v(0.7071, 0.7071, 0)).
				

				local testNode is GetLambertInterceptNode(
					ship,
					targetOrbital,
					tuple[1],
					flightTime,
					offset
				).

				local deltaV is testNode:deltaV:mag + 
					(velocityat(ship, interceptTime):orbit - 
					velocityat(targetOrbital, interceptTime):orbit):mag.

				remove testNode.
				wait 0.
				if tuple[1] < time:seconds + 120 set deltaV to deltaV * 100.

				//printData("t_bo:          ",35,round(tuple[1],0.1)).
				SetDisplayData("t_bo",round(tuple[1],0.1),"Int").
				//printData("t_coast:       ",35,round(flightTime,0.1)).
				SetDisplayData("t_coast",round(flightTime,0.1),"Int").
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

	else if phase = "Brake" {
	}

	else if phase = "Translation" {
	}

	else if phase = "Landing" {
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

	else if newMode = "planeChange" {
		local landingGeo is LatLng(data:lat, data:lng).
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
				} else if addons:tr:hasImpact {
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

	} else if newMode = "Deorbit" {
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
	} else if content:startswith("DATA") {
		local dataCmd is Lexicon(content:replace("DATA ",""):split(",")).
		print dataCmd.
		for key in dataCmd:keys {
			set data[key] to dataCmd[key].
		}
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
			print "Processing orbit.".
			local destinationName is content:replace("ORBIT ","").
			local destination is body(destinationName).

			set data:transferTo to destinationName.
			set data:body to destinationName.
			set data:transferFrom to ship:body:name.
		
			set data:target to "".
			set data:mission to "orbit".
			
			if ship:body = destination {
				// clean up the orbit, then.
			} else if destination:body = ship:body {
				setMode("Transfer").
			} else if destination:body = ship:body:body {
				setMode("Lambert").
			} else if destination = ship:body:body {
				setMode("Return").
			}
		} else if content:startsWith("LAND") {
			if content = "LAND" {
				setMode("Deorbit").
			} else {
				local details is content:replace("LAND AT","").
				if details:startswith("At") {
				} else {
					set details to details:replace("At ",""):split(" ").
					local lat is details[0].
					if lat:contains("N") set lat to lat:replace("N",""):toNumber(0).
					else if lat:contains("S") set lat to lat:replace("S",""):toNumber(0) * -1.
					else set lat to lat:toNumber(0).

					local lng is details[1].
					if lng:contains("E") set lng to lng:replace("E",""):toNumber(0).
					else if lng:contains("W") set lng to lng:replace("W",""):toNumber(0) * -1.
					else set lng to lng:toNumber(0).

					set data:lat to lat.
					set data:lng to lng.
					setMode("PlaneChange").
				}
			}
		} else if content = "CIRC" {
			if eta:apoapsis > eta:periapsis {
				set data["apo"] to data["peri"].
				core:connection:sendmessage("APO").
				core:connection:sendmessage("QUEUE PERI").
			} else {
				set data["peri"] to data["apo"].
				core:connection:sendmessage("PERI").
				core:connection:sendmessage("QUEUE APO").
			}
		} else if content:startsWith("CIRC") {
			local alt is content:replace("CIRC ",""):tonumber(80) * 1000.
			set data["apo"] to alt.
			set data["peri"] to alt.
			if eta:apoapsis > eta:periapsis {
				core:connection:sendmessage("APO").
				core:connection:sendmessage("QUEUE PERI").
			} else {
				core:connection:sendmessage("PERI").
				core:connection:sendmessage("QUEUE APO").
			}
		} else if content = "APO" {
			getApsisNodeAt(data["apo"], time:seconds + eta:periapsis).
			set data:phase to "ExecuteAWACT".
		} else if content = "PERI" {
			getApsisNodeAt(data["peri"], time:seconds + eta:apoapsis).
			set data:phase to "ExecuteAWACT".
		} else if content:startsWith("APO") {
			local alt is content:replace("APO ",""):tonumber(80) * 1000.
			set data["apo"] to alt.
			getApsisNodeAt(alt, time:seconds + eta:periapsis).
			set data:phase to "ExecuteAWACT".
		} else if content:startsWith("PERI") {
			local alt is content:replace("PERI ",""):tonumber(80) * 1000.
			set data["peri"] to alt.
			getApsisNodeAt(alt, time:seconds + eta:apoapsis).
			set data:phase to "ExecuteAWACT".
		} else if content = "DOCK" {
			setMode("Dock").
		} else if content = "PARK" {
			setMode("Park").
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

function PullPhase {
	if data:phase:startswith("execute") {
		setMode(data:phase:replace("execute","")).
	}
}
function PushPhase {
	print "Pushing phase " + data:phase.
	if data:phase:startswith("execute") {
		set data:phase to data:phase:replace("execute","").
		print "Make that " + data:phase.
	}
	if data["phase"] = "RaisePeri" {
		if ship:partstagged("Booster"):length > 0 stage.
		setMode("AWACT").
	} else if data["phase"] = "Transfer" {
		setMode("transfer-finetune").
	} else if data["phase"] = "transfer-finetune" {
		setMode("transfer-pause").
	} else if data["phase"] = "route" {
		setMode("transfer-finetune").
	} else if data["phase"] = "Return" {
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
	} else if data["phase"] = "runinter" {
		setMode("rendezvous-finetune").
	} else if data["phase"] = "rendezvous-finetune" {
		setMode("match").
	} else if data["phase"] = "match" {
		setMode("AWACT").
	} else if data["phase"] = "PlaneChange" {
		set data["phase"] to "Deorbit". 
	} else if data["phase"]:startsWith("Ion") {
		if ship:apoapsis < data["apo"] { setMode("IonApo"). }
		else if ship:periapsis < data["peri"] { setMode("IonPeri"). }
		else { setMode("AWACT"). }
	} else {
		setMode(data:phase).
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
} else if phase:startswith("Execute") and not hasnode {
	PullPhase().
} else {
	setMode(phase).
}

local refreshTimer is 0.


until false {

	if data["phase"] = "Sleep" {
		wait 10.
	} else if data["phase"] = "BOOST" {
		if ship:partstagged("Booster"):empty {
			set data["phase"] to "AWACT".
		} else {
			wait 10.
		}
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

		if nextnode:eta < 0 {
			remove nextnode.
			wait 0.
			PullPhase().
		}
		if nextnode:deltav:mag < 0.1 {
			remove nextnode.
			wait 0.
			PushPhase().
		} else {
			RunNode().
			PushPhase().
		}
		wait 0.
	} else {
		wait 1.
	}

}


