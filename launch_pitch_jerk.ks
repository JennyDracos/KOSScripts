parameter TargetOrbit is 100000,
		  LoseFairings is true.
// Clean up work area
clearscreen.

print "Launch.".

set ship:control:pilotmainthrottle to 0.

RUNONCEPATH("1:/lib/BisectionSolver.ks").



function g {
  local R to ship:body:position:mag.
  local GM to ship:body:mu.

  return GM/(R)^2.
}

function V_accel_inertial {
  local V is ship:velocity:orbit.
  local R is -ship:body:position.
  local tmp_vec is VCRS(VCRS(R,V),R):normalized.
  local centri_acc to VDOT(tmp_vec,V)^2/R:mag.

  return centri_acc - g().
}

function makeIntegrator_func {
    parameter getInput.
    local tLast is time:seconds.
    local int is 0.
    if getInput:call():istype("Vector") {
        set int to v(0,0,0).
    }
    return {
        local now is time:seconds.
        local dt is now - tLast.
        set int to int + getInput() * (now - tLast).
        set tLast to now.
        return int.
    }.
}

function makeIntegrator_val {
    parameter init_value.
    local tLast is time:seconds.
    local int is init_value.
    if init_value:istype("Vector") {
        set int to v(0,0,0).
    }
    return {
        parameter getInput.
        local now is time:seconds.
        local dt is now - tLast.
        set int to int + getInput * (now - tLast).
        set tLast to now.
        return int.
    }.
}

function makeDerivator_N {
    parameter init_value, N_count is 0.
    local tLast is time:seconds.
    local der is 0.
    local derLast to 0.
    local inputLast is init_value.
    if init_value:istype("Vector") {
        set der to v(0,0,0).
    }
    return {
      parameter getInput.
      local now is time:seconds.
      local dt is now - tLast.
      if dt > 0 {
        set der_next to (getInput - inputLast)/dt.
        set der to (N_count*der + der_next)/(N_count + 1).
        set inputLast to getInput.
        set tLast to now.
      }

      return der.
    }.
}

function makeDerivator_dt {
    parameter init_value, time_interval is 0.
    local tLast is time:seconds.
    local der is 0.
    local inputLast is init_value.
    if init_value:istype("Vector") {
        set der to v(0,0,0).
    }
    return {
      parameter getInput.
      local now is time:seconds.
      local dt is now - tLast.
      if dt > time_interval {
        set der to (getInput - inputLast)/dt.
        set inputLast to getInput.
        set tLast to now.
      }

      return der.
    }.
}

function machNumber {
    parameter idx is 1.4.
    if not body:atm:exists or body:atm:altitudepressure(altitude) = 0 {
        return 0.
    }
    return round(sqrt(2 / idx * ship:q / body:atm:altitudepressure(altitude)),3).
}

local v_accel_func to makeDerivator_N(0,10).
local v_jerk_func to makeDerivator_N(0,20).
// Functions

function PitchProgram_Rate {
	parameter Pitch_Data.
	local t_1 to Pitch_Data["Time"].
	local t_2 to time:seconds.
	local dt to max(0.0001,t_2 - t_1).
	local alt_final is Pitch_Data["Alt_Final"].
	local alt_diff is alt_final - altitude.

	local a to .5*getVertAccel().
	local b to verticalspeed.
	local c to -alt_diff.

	local time_to_alt to ((-b) + sqrt(max(0,b^2 - 4*a*c)))/(2*a).
	local pitch_des to Pitch_Data["Pitch"].
	local pitch_final to Pitch_Data["Pitch_Final"].
	local pitch_rate to max(0,(pitch_final - pitch_des)/time_to_alt).

	local pitch_des to min(pitch_final,max(0,pitch_des + dt*pitch_rate)).

	set Pitch_Data["Pitch"] to pitch_des.
	set Pitch_Data["Time"] to t_2.
  set Pitch_Data["Time_to_Alt"] to time_to_alt.

	return Pitch_Data.
}

function makePitch_rate_function {
  parameter vertspeed_min.

  local pitch_des to 0.
  local pitch_final to 90.
  local begin_pitch to false.
  local timeLast to time:seconds.

  return {
    parameter time_to_alt.

    if not(begin_pitch) AND verticalspeed > vertspeed_min {
      set begin_pitch to true.
    }

    local timeNow to time:seconds.
    local dt to timeNow - timeLast.
    set timeLast to timeNow.

    if begin_pitch AND (machNumber() < 0.85 OR machNumber() > 1.1) {
      local pitch_rate to max(0,(pitch_final - pitch_des)/time_to_alt).
      set pitch_des to min(pitch_final,max(0,pitch_des + dt*pitch_rate)).
    }
    return pitch_des.
  }.
}

function getVertAccel {
  return v_accel_func:call(verticalspeed).
}

function getVertJerk {
  return v_jerk_func:call(getVertAccel).
}

function AltIntegration_Jerk {
  parameter time_input.

  local x is time_input.
  local d is altitude.
  local c is verticalspeed.
  local b is getVertAccel()/2.
  local a is getVertJerk()/6.

  return d + c*x + b*x^2 + a*x^3.
}

function T2Alt_Score {
  parameter time_input.

  return ship:body:atm:height - AltIntegration_Jerk(time_input).
}

//function Calculate_DeltaV {
//	parameter DeltaV_Data.
//
//	local thrust_accel_1 to DeltaV_Data["Thrust_Accel"].
//	local thrust_accel_2 to throttle*availablethrust/mass.
//	local a_vec1 to DeltaV_Data["Accel_Vec"].
//	local a_vec2 to throttle*ship:sensors:acc.
//	local time1 to DeltaV_Data["Time"].
//	local time2 to time:seconds.
//	local dt to max(0.0001,time2 - time1).
//	local thrust_accel to (thrust_accel_1 + thrust_accel_2)/2.
//	local a_vec to (a_vec1 + a_vec2)/2.
//	local thrust_vec to thrust_accel*ship:facing:vector.
//	set DeltaV_Data["Total"] to DeltaV_Data["Total"] + thrust_accel*dt.
//	local obt_vel_norm to ship:velocity:orbit:normalized.
//	set DeltaV_Data["Gain"] to DeltaV_Data["Gain"] + dt*(VDOT(obt_vel_norm,a_vec)).
//
//	set DeltaV_Data["Time"] to time2.
//	set DeltaV_Data["Accel_Vec"] to a_vec2.
//	set DeltaV_Data["Thrust_Accel"] to thrust_accel_2.
//
//	return DeltaV_Data.
//}

function circular_speed {
	parameter R.
	local R_val to ship:body:radius + R.
	return sqrt(ship:body:mu/R_val).
}

function vis_via_speed {
	parameter R, a is ship:orbit:semimajoraxis.
	local R_val to ship:body:radius + R.
	return sqrt(ship:body:mu*(2/R_val - 1/a)).
}

function Circularize_DV_Calc{
	local Vapo_cir to circular_speed(apoapsis).
	local Delta_V to  Vapo_cir - vis_via_speed(apoapsis).
	local CirPer to NODE(TIME:seconds + eta:apoapsis, 0, 0, Delta_V).
	ADD CirPer.
	return CirPer:deltav:mag.
}

function inst_az {
	parameter	inc. // target inclination

	// find orbital velocity for a circular orbit at the current altitude.
	local V_orb is max(ship:velocity:orbit:mag + 1,sqrt( body:mu / ( ship:altitude + body:radius))).

	// Use the current orbital velocity
	//local V_orb is ship:velocity:orbit:mag.

	// project desired orbit onto surface heading
	local az_orb is arcsin ( max(-1,min(1,cos(inc) / cos(ship:latitude)))).
	if (inc < 0) {
		set az_orb to 180 - az_orb.
	}

	// create desired orbit velocity vector
	local V_star is heading(az_orb, 0)*v(0, 0, V_orb).

	// find horizontal component of current orbital velocity vector
	local V_ship_h is ship:velocity:orbit - vdot(ship:velocity:orbit, up:vector:normalized)*up:vector:normalized.

	// calculate difference between desired orbital vector and current (this is the direction we go)
	local V_corr is V_star - V_ship_h.

	// project the velocity correction vector onto north and east directions
	local vel_n is vdot(V_corr, ship:north:vector).
	local vel_e is vdot(V_corr, heading(90,0):vector).

	// calculate compass heading
	local az_corr is arctan2(vel_e, vel_n).
	return az_corr.
}

// Startup
for converter in ship:modulesnamed("ModuleResourceConverter") {
	if converter:hasevent("start fuel cell (lfo)")
		converter:doevent("start fuel cell (lfo)").
	if converter:hasevent("start fuel cell")
		converter:doevent("start fuel cell").
}

// Ignition
local pitch_ang to 0.
local inc_des   to 0. // Desired inclination
local compass to inst_az(inc_des).
lock throttle to 1.
lock steering to lookdirup(heading(compass,90-pitch_ang):vector,ship:facing:upvector).
stage.
gear off.

// Pitch Program Parameters: Sqrt
local switch_alt is altitude.

// Pitch Program Parameters: Rate
local min_VS is 10.
set Pitch_Data to lexicon().
Pitch_Data:ADD("Time",time:seconds).
Pitch_Data:ADD("Time_to_Alt",0).
Pitch_Data:ADD("Pitch",0).
Pitch_Data:ADD("Pitch_Final",90).
Pitch_Data:ADD("Alt_Final",ship:body:atm:height).

// Pitch Program Parameters: Jerk Integration

local T2Alt_Solver to makeBiSectSolver(T2Alt_Score@,100,101).
local T2Alt_TestPoints to T2Alt_Solver:call().
local pitch_controller to makePitch_rate_function(10).

// Run Mode Variables
local AscentStage is 1.
local ThrottleStage is 1.
local StageCount is 0.
local StageEngineList is ship:partstagged("stage0Engine").

local line is 1.
local FPA is VANG(UP:vector,ship:velocity:surface).
clearscreen.

until AscentStage = 2 AND altitude > ship:body:ATM:height {
	if StageEngineList:length > 0 and StageEngineList[0]:Flameout {
		lock throttle to 0.
		stage.
		lock throttle to 1.
		set StageCount to StageCount + 1.
		set StageEngineList to ship:partstagged("stage"+StageCount+"Engine").
	}
	
	if apoapsis > TargetOrbit AND ThrottleStage = 1 {
		lock throttle to 0.
		set ThrottleStage to 2.
		set AscentStage to 2.
	}

  if AscentStage = 1 {
      set T2Alt_TestPoints to T2Alt_Solver:call().
      set pitch_ang to pitch_controller:call(T2Alt_TestPoints[2][0]).
  }

  if AscentStage = 2 {
    set pitch_ang to FPA.
  }

  set FPA to VANG(UP:vector,ship:velocity:surface).
	set compass to inst_az(inc_des).

	// Variable Printout
	set line to 1.
	print "ThrottleStage = " + ThrottleStage + "   " at(0,line).
	set line to line + 1.
	print "AscentStage   = " + AscentStage + "   " at(0,line).
	set line to line + 1.
  print "pitch_ang     = " + round(pitch_ang,2) + "   " at(0,line).
	set line to line + 1.
    print "Pitch Program: Pitch Rate with Jerk                     " at(0,line).
    set line to line + 1.
    print "Vert Accel  = " + round(getVertAccel(),3) + "     " at(0,line).
    set line to line + 1.
    print "Vert Jerk   = " + round(getVertJerk(),3) + "     " at(0,line).
  	set line to line + 1.
    print "Time to Alt = " + round(T2Alt_TestPoints[2][0],2) + "     " at(0,line).
  	set line to line + 1.
  print "Gamma         = " + round(FPA,2) + "   " at(0,line).
	set line to line + 1.
	print "Compass       = " + round(compass,2) + "   " at(0,line).
	set line to line + 1.
	print "Altitude      = " + round(altitude) + "   " at(0,line).
	set line to line + 1.
	print "Apoapsis      = " + round(apoapsis) + "   " at(0,line).
	set line to line + 1.
	print "Target Ap o   = " + TargetOrbit + "   " at(0,line).
  set line to line + 1.
	print "Periapsis     = " + round(periapsis) + "   " at(0,line).


	// Delta V Calculations
	//set DeltaV_Data to Calculate_DeltaV(DeltaV_Data).

	wait 0.
}

if LoseFairings {
	for decoupler in ship:modulesnamed("ProceduralFairingDecoupler") {
		if decoupler:hasevent("Jettison Fairing") decoupler:doevent("Jettison Fairing").
	}
}

