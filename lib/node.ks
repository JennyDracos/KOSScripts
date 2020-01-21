@lazyglobal off.

runoncepath("1:/lib/ui.ks").
runoncepath("1:/libsimplex.ks").

// Converting RAMP node.ks to a maneuver library.

// Library functions.
global thrustLookup is Lexicon(
	"liquidEngineMini", 20,
	"ntr-sc-125-1", 67,
	"ntr-sc-25-1", 310,
	"SYoms1", 65,
	"ionEngine (Duna Relay)", 5.656,
	"ionEngine", 1,
	"Rapier", 180,
	"toroidalAerospike", 180
).
//for engine in ship:modulesnamed("ModuleEnginesFX") {
//	if not thrustLookup:HasKey(engine:part:name) {
//		print "Add "+engine:part:name+" to the thrust lookup database!  Or else!".
//		print 1/0.
//	}
//}.

local F is 0.
local ff is 0.

function RecalcEngines {
	local engineList is list().
	for engine in ship:modulesnamed("ModuleEnginesFX") {
		if engine:HasEvent("Shutdown Engine") {
			engineList:add(engine:part).
		}
	}
	for engine in ship:modulesnamed("ModuleEngines") {
		if engine:HasEvent("Shutdown Engine") {
			engineList:add(engine:part).
		}
	}

	set F to 0.
	set ff to 0.
	for engine in engineList {
		set F to F + engine:maxThrust.
		set ff to ff + (engine:maxThrust / (constant:g0 * engine:visp)).
	}
}
RecalcEngines().

// Calculate burn time.
// Base formulas:
// Δv = ∫ F / (m0 - consumptionRate * t) dt
// consumptionRate = F / (Isp * g)
// ∴ Δv = ∫ F / (m0 - (F * t / g * Isp)) dt

// Integrate:
// ∫ F / (m0 - (F * t / g * Isp)) dt = -g * Isp * log(g * m0 * Isp - F * t)
// F(t) - F(0) = known Δv
// Expand, simplify, and solve for t
function ManeuverTime {
	parameter dV.

	RecalcEngines.
	local v_e is F / ff.

	return (ship:mass * v_e / F) * (1 - constant:e ^ (-dV / v_e)).
}

function ManeuverDist {
	parameter v_0, v_f is V(0,0,0).
	
	local f_thrust is GetMaxThrust().
	local dV is (v_0 - v_f):mag.
	local h is -(dV * dV) * ship:mass / ( 2 * F_thrust ).

	return h.
}

function GetThrottleForDist {
	parameter vel, acc, d.
	local tgtacc is vel * vel / 2 / max(d, 0.01).
	local thrtl is tgtacc / acc.
	return thrtl.
}

// Line up on maneuver.
function AlignForBurn {
	parameter nd is nextnode.

	sas off.
	lock steering to lookdirup(nd:deltav, ship:facing:topvector).
}

// Main burn.
function MainBurn {
	parameter nd is nextnode, halfburn is true.

	local burnDuration is 0.
	if halfburn { set burnDuration to ManeuverTime(nd:deltav:mag / 2). }
	else { set burnDuration to ManeuverTime(nd:deltav:mag). }

	for alarm in listAlarms("Maneuver") {
		deleteAlarm(alarm:ID).
	}
	AddAlarm("Maneuver", time:seconds + nd:eta - burnDuration, ship:name + " maneuver", "").

	AlignForBurn(nd).

	print "Waiting until " + nd:eta + " <= " + burnDuration.

	wait until nd:eta <= burnDuration.

	print "Done!".
	local nodeDone is false.
	local nodeDV0 is nd:deltaV.
	local nodeDVMin is nodeDV0:mag.

	unlock throttle.

	until nodeDone{
		local nodeAccel is ship:availableThrust / ship:mass.

		if nd:deltaV:mag < nodeDVMin {
			set nodeDVMin to nd:deltaV:mag.
		}

		if nodeAccel > 0 {
			// Feather the throttle.
			set ship:control:pilotmainthrottle to min(nodeDVMin/nodeAccel, 1.0).

			if vdot(nodeDv0, nd:deltaV) < 0 {
				print "Pointing in wrong direction!".
			} else if nd:deltaV:mag > nodeDvMin + 0.1 {
				print "We're making it worse!".
			} 	else if nd:deltaV:mag <= 0.2 {
				print "Finished main burn.  Clean up!".
			}

			// Stop on overshoot; stop on off-target; stop on too small for main engines.
			set nodeDone to (vdot(nodeDv0, nd:deltaV) < 0) or
							(nd:deltaV:mag > nodeDvMin + 0.1) or
							(nd:deltaV:mag <= 0.2).
		} else { // No accel - either engines died or bingo fuel.
			set nodeDone to true.
			print "Engine shutdown!".
		}
	}
}

// Finish with RCS.
function RCSBurn {
	parameter nd is nextnode.

	lock throttle to 0.
	set ship:control:pilotmainthrottle to 0.
	unlock steering.
	unlock throttle.

	rcs on.
	if nd:deltaV:mag > 0.1 {
		local t0 is time.
		until nd:deltaV:mag < 0.1 or (time - t0):seconds > 15 {
			local sense is ship:facing.
			local dirV is V(
				vdot(nd:deltaV, sense:starvector),
				vdot(nd:deltaV, sense:upvector),
				vdot(nd:deltaV, sense:forevector)
			).
			
			set ship:control:translation to dirV:normalized.
		}

		set ship:control:translation to V(0,0,0).
	}
	rcs off.
}


// Run node, start to finish.
function RunNode {
	parameter nd is nextnode.

	RecalcEngines().

	set ship:control:translation to V(0,0,0).

	print "Running node in T-" + nextnode:eta.	

	AlignForBurn(nd).

	MainBurn(nd).

	print "Finishing with RCS.".

	RCSBurn(nd).

	if nd:deltaV:mag < 0.1 and hasnode { remove nextnode. }
}

local t_ig is 0.
local t_bo is 0.
local i_f is V(1,0,0).

local v_bo is V(0,0,0).
local r_bo is V(0,0,0).

local t_ref is V(0,0,0).
local v_ref is V(0,0,0).
local r_ref is V(0,0,0).

global d_t is 0.20.

global burnLoop is false.

function VelocityVerlet {
	parameter t_0, t_burn, t_f, i_f.

	local t is 0.
	local m is ship:mass.
	local v is velocityAt(ship, t_0):orbit.
	local r is positionAt(ship, t_0) - ship:body:position.

	local mu is orbitAt(ship, t_0):body:mu.
	local a is (i_f * F / m) - (mu / r:sqrmagnitude * r:normalized).
	
	until t >= t_burn {
		set v to v + a * d_t / 2.
		set r to r + v * d_t.
		set a to (i_f * F / (m - t * ff)) - (mu / r:sqrmagnitude * r:normalized).
		set v to v + a * d_t / 2.
		set t to t + d_t.
	}

	local t_coast is t_f - t_0.
	until t >= t_coast {
		set v to v + a * d_t / 2.
		set r to r + v * d_t.
		set a to -(mu / r:sqrmagnitude * r:normalized).
		set v to v + a * d_t / 2.
		set t to t + d_t.
	}
	
	return Lexicon("t", t, "r_f", r, "v_f", v).
}

function BurnNode {
	parameter nd is nextnode.

	local t_n is time:seconds + nextNode:eta.
	local dv_0 is velocityAt(ship, t_n + 0.05):orbit - velocityAt(ship, t_n - 0.05):orbit.

	local t_burn_0 is ManeuverTime(dv_0:mag).

	set t_ref to t_n + t_burn_0.
	set v_ref to velocityAt(ship, t_ref):orbit * 
		solarprimevector:direction:inverse.
	set r_ref to (positionAt(ship, t_ref) - ship:body:position) *
		solarprimevector:direction:inverse.

	BurnInit(t_n, dv_0).
}

function BurnMatch {
	parameter t_n, orb_t, offset is V(0,0,100).

	if hasNode { remove nextnode. wait 0. }

	local dv_0 is velocityAt(ship, t_n):orbit - velocityAt(orb_t, t_n):orbit.
	local t_burn_0 is ManeuverTime(dv_0:mag).
	
	set t_ref to t_n + t_burn_0.
	set v_ref to velocityAt(orb_t, t_ref):orbit *
		solarprimevector:direction:inverse.
	set r_ref to (positionAt(orb_t, t_ref) - ship:body:position + offset) *
		solarprimevector:direction:inverse.

	BurnInit(t_n, dv_0).
}.

function BurnInit {
	parameter t_n,
			  dv_0.

	print "Updating burn via simulation!".
	AddDisplay("Burn").
	RecalcEngines().

	local m_0 is ship:mass.

	local t_burn_0 is ManeuverTime(dv_0:mag).

	if t_burn_0 < 2 {
		print "Impulse burn!".

		local t_burn is t_burn_0.
		for alarm in addons:kac:Alarms() {
			if alarm:type = "Maneuver" and alarm:name:startswith(ship:name) {
				deleteAlarm(alarm:ID).
			}
			wait 0.
		}
		set t_ig to t_n - t_burn.
		set t_bo to t_n.
		AddAlarm("Maneuver", t_ig - 5, ship:name + " burn", "").

		local dv is dv_0.
		lock steering to lookdirup(dv, ship:facing:upvector).
		when (time:seconds + d_t >= t_ig) then { 
			lock throttle to 1.
		}

		set burnLoop to true.
		return dv.
	}

	print "Testing from " + (t_n - t_burn_0 - time):clock + " to " + (t_n - time):clock + ".".

	local t_0 is GoldenSection(
		t_n - 2 * t_burn_0,
		t_n - 1,
		{
			parameter t_0.

			// choose a start time t0.
			//printData("t_0:",35,(t_0-time):clock).
			SetDisplayData("t_0",(t_0 - time):clock,"Burn").

			local dv is dv_0.

			local v_err is V(1000000,0,0).
			local burnoutState is Lexicon("t", t_n, "r_f",V(0,0,0),"v_f",V(0,0,0)).
			until v_err:mag < 0.1 * max(1, dv:mag) {
				local dv_mag is dv:mag.
				local t_burn is ManeuverTime(dv_mag).

				set i_f to dv:normalized.

				set burnoutState to VelocityVerlet(t_0, t_burn, t_ref, i_f).

				// v_miss is v_node - v_cutoff.
				set v_err to v_ref * solarprimevector:direction - 
					burnoutState["v_f"].
				set dv to dv + 0.5 * v_err.

				if dv:mag > dv_0:mag * 5 { return 1e10 + dv:mag. }

			}
			local p_err is (r_ref * solarprimevector:direction) - 
				burnoutState["r_f"].

			return p_err:mag.
		},
		0.05
	).
	//set t_0 to burnPrep.
	print "Burn selected at t:" + t_0.
	SetDisplayData("t_0",(t_0 - time):clock,"Burn").
	//printData("t_0:",35,(t_0-time):clock).

	local v_0 is velocityAt(ship, t_0):orbit.
	local r_0 is positionAt(ship, t_0) - ship:body:position.

	local dv is dv_0.

	local v_err is V(100,0,0).
	local burnoutState is Lexicon("t", t_n, "r_f", V(0,0,0), "v_f", V(0,0,0)).
	until v_err:mag < max(1, dv:mag * 0.0015) {
		local dv_mag is dv:mag.
		local t_burn is ManeuverTime(dv_mag).
		//printData("dv_mag:",40,dv_mag).
		SetDisplayData("dv_mag",dv_mag,"Burn").
		//printData("t_burn",37,time(t_burn):clock).
		SetDisplayData("t_burn",time(t_burn):clock,"Burn").

		set i_f to dv:normalized.

		// integrate powered trajectory t_burn forward using verlet integrator.
		set burnoutState to VelocityVerlet(t_0, t_burn, t_ref, i_f).
		set v_err to v_ref * solarprimevector:direction - burnoutState["v_f"].
		set dv to dv + 0.5 * v_err.
		
		//printData("v_err:",39,v_err:mag).
		SetDisplayData("v_err",v_err:mag,"Burn").
	}
	print "Burn plotted!".

	local t_burn is ManeuverTime(dv:mag).
	for alarm in listAlarms("Maneuver") {
		deleteAlarm(alarm:ID).
	}
	AddAlarm("Maneuver", t_0 - 5, ship:name + " burn", "").

	set t_ig to t_0.
	set t_bo to t_0 + t_burn.
	set i_f to dv:normalized.

	core:part:controlfrom.
	lock steering to lookdirup(i_f, ship:facing:upvector).
	lock throttle to 0.
	when time:seconds > t_ig then { if burnloop { lock throttle to 1. } }

	set v_bo to burnoutState["v_f"].
	set r_bo to burnoutState["r_f"].

	set burnLoop to true.

	return dv.
}

local v_f_d is 0.
local d_v_d is 0.


local t_retest is time.
function BurnUpdate {
	local t_0 is time:seconds.
	if t_0 < t_ig { set t_0 to t_ig. }

	if t_ig > time {
		//printData("t_ignition:", 20, (t_ig - time):clock).
		SetDisplayData("t_ignition",(t_ig - time):clock,"Burn").

	} else {
		//printData("t_ignition:", 20, "-"+(time - t_ig):clock).
		SetDisplayData("t_ignition","-"+(time-t_ig):clock,"Burn").
	}
	//printData("t_burnout:", 22, (t_bo - time):clock).
	SetDisplayData("t_burnout",(t_bo - time):clock,"Burn").
	
	if time < t_ig and time > t_retest { // Active guidance
		set t_retest to time + 5.
		local v_e is F / ff.
		local dv is i_f * v_e * ln(ship:mass /
			(ship:mass - ff * (t_bo - t_0))).

		local v_err is V(1000, 0, 0).
		local t_burn is 0.
		until v_err:mag < max(1, dv:mag * 0.0015) {
			local dv_mag is dv:mag.
			set t_burn to ManeuverTime(dv_mag).
			//printData("dv_mag:",40,dv_mag).
			SetDisplayData("dv_mag",dv_mag,"Burn").
			//printData("t_burn",37,time(t_burn):clock).
			SetDisplayData("t_burn",time(t_burn):clock,"Burn").

			set i_f to dv:normalized.

			local burnoutState is VelocityVerlet(t_0, t_burn, t_ref, i_f).

			// v_miss is v_node - v_cutoff.
			set v_err to v_ref * solarprimevector:direction - 
				burnoutState["v_f"].
			set dv to dv + 0.5 * v_err.

			//printData("v_err:",39,v_err:mag).
			SetDisplayData("v_err",v_err:mag,"Burn").
		}
		set t_bo to t_0 + t_burn.
	} else if time > t_ig {
		local burnoutState is VelocityVerlet(t_0, t_bo - t_0, t_ref, i_f).
		//printData("dv_mag:",40,(burnoutState["v_f"] - ship:velocity:orbit):mag).
		SetDisplayData("dv_mag",(burnoutState["v_f"] - ship:velocity:orbit):mag, "Burn").
		//printData("t_burn:",37,(t_bo - time):clock).
		SetDisplayData("t_burn",(t_bo - time):clock, "Burn").
		//printData("v_err:", 39,((v_ref * solarprimevector:direction) - 
		//	burnoutState["v_f"]):mag).
		SetDisplayData("v_err",((v_ref * solarprimevector:direction) - 
		      burnoutState["v_f"]):mag, "Burn").
	} else { return false. }
	
	if t_bo > time:seconds {
		SetDisplayData("t_ignition","-"+(time - t_ig):clock, "Burn").
		//printData("t_ignition:", 20, "-"+(time - t_ig):clock).
		SetDisplayData("t_burnout",(t_bo - time):clock, "Burn").
		//printData("t_burnout:", 22, (t_bo - time):clock).
		return false.
	} else {
		RemoveDisplay("Burn").
		lock throttle to 0.
		return true.
	}
}


// Reach specified point with specified velocity.
function Match {
	parameter targetPoint, targetVelocity is { return V(0,0,0). }.

	AddAlarm("Maneuver", time:seconds + eta:periapsis, "Brake maneuver", "").

	local v_r is ship:velocity:orbit.
	local e is targetPoint().

	local s_vec is ship:facing:vector.
	lock steering to s_vec.
	local throt is 0.
	lock throttle to 0.

	local v_w_m is v_r:mag.

	local burnDone is false.
	when vang(ship:velocity:orbit, targetPoint()) < 15 then {
		when steeringmanager:angleerror < 1 and throt > 0.9 then { 
			lock throttle to throt.
			lock steering to -v_r. 
			
			when throt < 0.1 then {
				set burnDone to true.
			}
		}
	}

	clearscreen.
	local suicide is false.

	until e:mag < 1 or v_r:mag < 10 or v_w_m < 0 {
		clearvecdraws().
		local o is ship:position.
		local v_i is ship:velocity:orbit.
		local v_f is targetVelocity().

		set v_r to v_i - v_f.

		local west is vcrs(ship:up:vector, ship:north:vector):normalized.

//		set v_w_m to vdot(v_r, west).

		local p is targetPoint().
		local e is west * vdot(p, west).
		local e_h is -vxcl(west, p).

		set s_vec to -v_r - 1.5 * e_h.

		local a is ship:facing:vector * F / ship:mass.

		local v_i_g is vecdraw(o, v_i, green, "", 1.0, true, 0.2).
		local v_f_g is vecdraw(p, v_f, green, "", 1.0, true, 0.2).
		local v_f_g is vecdraw(o, v_r, yellow, "", 1.0, true, 0.2).

		local p_g is vecdraw(o, p, white, "", 1.0, true, 0.2).
		local e_g is vecdraw(o, e, red, "", 1.0, true, 0.2).
		local e_h_g is vecdraw(p, e_h, red, "", 1.0, true, 0.2).

		local s_v is vecdraw(o, s_vec, yellow, "", 1.0, true, 0.2).

		set throt to GetThrottleForDist(v_r:mag, a:mag, vdot(p, west)).
		
		printData("v_r:"          ,30,v_r:mag).
		printData("v_f:"          ,31,v_f:mag).
		printData("v_i:"          ,32,v_i:mag).
		printData("v_w:"          ,33,vdot(v_r, west)).

		printData("e_h:"          ,35,e_h:mag).

		printData("p . v_i:"      ,37,vdot(p, v_i)).
		printData("suicide:"      ,38,(v_f:sqrmagnitude - v_i:sqrmagnitude) /
			(2 * vdot(a, west))).
		printData("p . west:"     ,39,vdot(p, west)).

		printData("throt:"        ,41,throt).

		wait 0.
	}

	for n in range(30, 42) { printData(" ",n," "). }
}
