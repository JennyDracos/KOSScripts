@LAZYGLOBAL off.

if not (defined libdeltav_var_def) {
	global libdeltav_var_def is true.
	global DVTrack is list(-1).
	global ldv_totalDeltaV is 0.
	global ldv_lastMass is -1.
	global ldv_lastISP is 0.
	global ldv_lastStageDeltaV is 0.
	global ldv_previousStagesDeltaV is 0.
	global ldv_lastDryMass is -1.
	global ldv_engineList is list().
	global ldv_steeringloss is 0.
	global ldv_gravityloss is 0.
	global ldv_partcount is 0.
	global ldv_lastUpdateTime is -1.
	global ldv_lastGravityAccel is 0.
}

declare function libdeltav_def {
	return true.
}

//if not (defined libmath_def) { run libmath. }

// Update the DVTrack
declare function UpdateDVTrack {
	local drymass is ship:drymass.
	local totalmass is ship:mass.
	if ldv_lastDryMass > 0 and drymass <> ldv_lastDryMass {
		RefreshEngines().
		set ldv_lastMass to totalmass.
		set ldv_lastISP to GetISPAtTrtl(throttle).
		set ldv_lastStageDeltaV to ldv_totalDeltaV - ldv_previousStagesDeltaV.
		set ldv_previousStagesDeltaV to ldv_totalDeltaV.
		set ldv_lastDryMass to drymass.
		//if ldv_lastISP > 0 {
			//verbose("dv avail: " + round(GetDVAvail(), 2)).
		//}
		return 0.
	}
	local isp is GetISPAtTrtl(throttle).
	if ldv_lastMass > 0 {
		if (isp > 0) {
			local dvisp is ldv_lastISP.
			set ldv_lastISP to isp.
			//if dvisp <= 0 {
				//verbose("dv avail: " + round(GetDVAvail(), 2)).
			//}
			//else {
			if dvisp > 0 {
				set isp to (dvisp + isp) / 2.
			}
			local dm is ldv_lastMass-totalmass.
			if (dm > 0.1 * totalmass) { verbose("large dm: " + dm). }
			local dv is 9.81*isp*ln(ldv_lastMass/totalmass).
			set ldv_totalDeltaV to ldv_totalDeltaV + dv.
			local velObt is ship:velocity:orbit.
			set ldv_steeringloss to ldv_steeringloss + dv * (1 - cos(vang(ship:facing:vector, velObt))).
			if (ldv_lastUpdateTime > 0 and dm > 0) {
				set ldv_gravityloss to ldv_gravityloss + ldv_lastGravityAccel * (time:seconds - ldv_lastUpdateTime) * (1 - cos(vang(-ship:up:vector, velObt))).
				//set ldv_gravityloss to vdot(ship:velocity:orbit:normalized, -ship:up:vector * ldv_lastGravityAccel * (time:seconds - ldv_lastUpdateTime)).
			}
			set ldv_lastGravityAccel to ship:body:mu / ship:body:position:mag ^ 2.
			set ldv_lastUpdateTime to time:seconds.
			set ldv_lastMass to totalmass.
			set ldv_lastStageDeltaV to ldv_totalDeltaV - ldv_previousStagesDeltaV.
			set ldv_lastDryMass to drymass.
			return dv.
		}
	}
	set ldv_lastMass to totalmass.
	set ldv_lastISP to isp.
	set ldv_lastDryMass to drymass.
	RefreshEngines().
	return 0.
}

// update the DVTrack when staging, resets the mass and isp.
declare function UpdateDVTrackStage {
	UpdateDVTrack().
	return ldv_lastStageDeltaV.
}

declare function ResetDVTrack {
	set ldv_totalDeltaV to 0.
	set ldv_lastMass to -1.
	set ldv_lastISP to 0.
	set ldv_lastStageDeltaV to 0.
	set ldv_previousStagesDeltaV to 0.
	set ldv_lastDryMass to -1.
}

declare function GetDVAvail {
	local isp is GetISP().
	local liq is stage:liquidfuel.
	local ox is stage:oxidizer.
	local fuelmass is ox * 0.005 + liq * 0.005.
	return ln(ship:mass/(ship:mass - fuelmass))*9.81*isp.
}

declare function GetDVAvailAtTrtl {
	declare parameter trtl.
	local isp is GetISPAtTrtl().
	local liq is stage:liquidfuel.
	local ox is stage:oxidizer.
	local fuelmass is ox * 0.005 + liq * 0.005.
	return ln(ship:mass/max(ship:mass - fuelmass, 0.0001))*9.81*isp.
}

declare function GetTotalDV {
	if ldv_totalDeltaV > 0 {
		return ldv_totalDeltaV.
	}
	return 0.
}
declare function GetLastStageDV {
	if ldv_totalDeltaV > 0 {
		return ldv_lastStageDeltaV.
	}
	return 0.
}
declare function GetPreviousStagesDV {
	if ldv_totalDeltaV > 0 {
		return ldv_previousStagesDeltaV.
	}
	return 0.
}
declare function GetSteeringLoss {
	return ldv_steeringloss.
}
declare function GetGravityLoss {
	return ldv_gravityloss.
}

declare function RefreshEngines {
	list engines in ldv_engineList.
}

declare function GetISP {
	return GetISPAtTrtl(1).
}

declare function GetISPAtTrtl {
	declare parameter trtl.
	local l is GetEngineParametersAtTrtl(trtl).
	return l[0].
}

declare function GetEngineParametersAtTrtl {
	declare parameter trtl.
	//local elist is list().
	local activeThrust is 0.
	local ispCounter is 0.
	//list engines in elist.
	//for e in elist {
	for e in ldv_engineList {
		if e:ignition and e:isp > 0 {
			if e:throttlelock {
				set activeThrust to activeThrust + e:availablethrust.
				set ispCounter to ispCounter + e:availablethrust / e:isp.
			}
			else {
				set activeThrust to activeThrust + e:availablethrust * trtl.
				set ispCounter to ispCounter + e:availablethrust * trtl / e:isp.
			}
			//set activeThrust to activeThrust + e:availablethrust.
			//set ispCounter to ispCounter + e:availablethrust / e:isp.
		}
	}
	if ispCounter > 0 { return list(activeThrust / ispCounter, activeThrust). }
	else { return list(0, 0). }
}

function GetBurnTimeDeltaVThrtl {
    parameter dv, thrtl.
    local g0 is 9.81.
    local engineParams is GetEngineParametersAtTrtl(thrtl).
	local engineISP is engineParams[0].
	local engineThrust is engineParams[1].
	if (engineThrust = 0) or (engineISP = 0) { return 0. }
	local engineFuelFlow is engineThrust / g0 / engineISP.
	local engineExhaustVel is engineThrust / engineFuelFlow.
    return ship:mass * (1 - BaseE ^ (-dv / engineExhaustVel)) / engineFuelFlow.
}
function GetDeltaMDeltaV {
    parameter dv.
    local g0 is 9.81.
    local engineParams is GetEngineParametersAtTrtl(1).
	local engineISP is engineParams[0].
	local engineThrust is engineParams[1].
	if (engineThrust = 0) or (engineISP = 0) { return 0. }
	local engineFuelFlow is engineThrust / g0 / engineISP.
	local engineExhaustVel is engineThrust / engineFuelFlow.
    return ship:mass * (1 - BaseE ^ (-dv / engineExhaustVel)).
}
function GetThrottleDeltaVBurnTime {
    parameter dv, dt.
    local engineParams is GetEngineParametersAtTrtl(1).
	local engineISP is engineParams[0].
	local engineThrust is engineParams[1].
	if (engineThrust = 0) or (engineISP = 0) { return 0. }
    local dm is GetDeltaMDeltaV(dv).
    local F is dm * 9.81 * engineISP / dt.
    return F / ship:availablethrust.
}
//}
