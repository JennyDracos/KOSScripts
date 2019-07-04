run once libmath.
run once libdeltav.
{
alert("Execute node.").
lock throttle to 0.
local done is False.

//ship:makeactive().
wait 1.
set mannode to nextnode.
alert("Node - eta:" + round(mannode:eta) + ", dv:" + round(mannode:deltav:mag)).
RefreshEngines().
set DVAvail to GetDVAvail().
set stageThreshold to mannode:deltav:mag / 10.
if (DVAvail < stageThreshold)
{
	verbose("Stage!").
	stage.
	wait until stage:ready.
	RefreshEngines().
	until ship:maxthrustat(0) > 0 or stage:number = 0
	{
		verbose("Stage!").
		stage.
		wait until stage:ready.
		RefreshEngines().
	}
	alert("DV Available: " + GetDVAvail()).
}
set maxaccel to ship:availablethrust/mass.
set maxthrottle to 1.0.
set burnduration to GetBurnTimeDeltaVThrtl(mannode:deltav:mag, 1).
until burnduration > 2 {
	//set burnduration to burnduration * 2.
	set maxthrottle to maxthrottle / 2.
    //alert("maxthrottle: " + maxthrottle).
	set burnduration to GetBurnTimeDeltaVThrtl(mannode:deltav:mag, maxthrottle).
    //alert("duration:    " + burnduration).
}
set burnduration to burnduration * 1.05.
when mannode:eta - burnduration/2 < 30 then {
	set warp to 0.  //lock steering to steerdir.
	when mannode:eta - burnduration/2 < 10 then {
		set warp to 0. //lock steering to steerdir.
	}
}
alert("duration:"+ round(burnduration) + ", throttle: " + round(maxthrottle, 3)).
set steerdir to ship:facing.
lock steering to steerdir.
set dv0 to mannode:deltav.
lock steerdir to lookdirup(dv0, up:vector).
rcs on.
WaitForSteering().
warpfor(mannode:eta - burnduration/2 - 45).
rcs off.
set tset to 0.
lock throttle to tset.
set dv0 to mannode:deltav.
set stagemaxthrust to ship:maxthrustat(0).
set beginBurnTime to mannode:eta - burnduration / 2.
set endBurnTime to beginBurnTime + burnduration.
on abort {
	set done to true.
}
when (ship:maxthrustat(0) < stagemaxthrust or ship:maxthrustat(0) < 1 or done) then {
	if not done {
		if stage:number > 0 {
			if stage:ready {
				verbose("Stage! dv: " + round(UpdateDVTrackStage())).
				stage.
				if ship:availablethrust > 0 {
					//set tset to min(1.0, maxthrottle * maxaccel * mass / ship:availablethrust).
                    //RefreshEngines().
                    //set maxthrottle to GetThrottleDeltaVBurnTime(mannode:deltav:mag, max(5, endBurnTime - time:seconds)).
					set maxthrottle to maxthrottle * maxaccel * mass / ship:availablethrust.
					alert("Max throttle: " + maxthrottle).
				}
				//else set maxthrottle to 0.
				set stagemaxthrust to ship:maxthrustat(0).
			}
			preserve.
		}
		else lock failed to true.
	}
}
set threshold to max(mannode:deltav:mag/300,.1).
lock steerdir to lookdirup(mannode:deltav, up:vector).
verboselong("Waiting to reach node time...").
if defined ct and ct:stationarycameraenabled {
	set ct:maxrelv to 0.
	set ct:referencemode to "initialvelocity".
	ct:stationarycamera.
}
wait until mannode:eta - burnduration/2 < 0.5.
alert("Beginning Node Burn").
set dv0 to mannode:deltav.
if defined ct and ct:stationarycameraenabled {
	set ct:maxrelv to dv0:mag / 3.
}
lock tsetFactor to min(10*mannode:deltav:mag/dv0:mag, 1).
lock tset to min(maxthrottle * tsetFactor, 1).
//set tset to maxthrottle.
until done {
	UpdateDVTrack().
	set phystime to time:seconds.
	if mannode:deltav:mag/dv0:mag < 0.10 {
		set tset to min(10*mannode:deltav:mag/dv0:mag, 1) * maxthrottle.
	}
	if vdot(dv0, mannode:deltav) < 0 {
		lock throttle to 0.
		set done to True.
	}
	else if mannode:deltav:mag < threshold {
		if vdot(dv0, mannode:deltav) < 0.5 {
			verbose("vdot < 0.5").
			lock throttle to 0.
			set done to True.
		}
	}
	wait 0.
}
UpdateDVTrack().
set ship:control:pilotmainthrottle to 0.
unlock steering.
unlock throttle.
wait 1.
remove mannode.
if defined ct and ct:stationarycameraenabled {
	set ct:maxrelv to 50.
	set ct:referencemode to "orbit".
}
alert("Node burn complete.").
//ptp("Node execution complete! dv: " + round(GetTotalDV())).
}
