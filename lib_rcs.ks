

function rcsSetup {
	
}


function rcsFrame {

	if (ship:controlpart <> controlpoint) {
		if controlpoint = grapple {
			grapple:getmodule("modulegrapplenode"):doevent("Control From Here").
		} else controlpoint:controlfrom.
	}
	// Calculate relative position and relative velocity.
	set relpos to dockpart:position - controlpoint:position.
	
	set RELVEL to SHIP:VELOCITY:obt - DOCKSHIP:VELOCITY:obt.
	
	set RELPOS to v(
		vdot(RELPOS, CONTROLPOINT:FACING:STARVECTOR),
		vdot(RELPOS, CONTROLPOINT:FACING:UPVECTOR),
		vdot(RELPOS, CONTROLPOINT:FACING:VECTOR)).

	set relpos to relpos - offset.

	set RELVEL to V(
		vdot(RELVEL, CONTROLPOINT:FACING:STARVECTOR),
		VDOT(RELVEL, CONTROLPOINT:FACING:UPVECTOR),
		VDOT(RELVEL, CONTROLPOINT:FACING:VECTOR)).

	set targetSpeed to min(relpos:mag * 0.5, speedcap).

	set targetVelocity to relpos / relpos:mag * targetSpeed.

	if alignpoint:length = 1 {
		unlock steering.
		sas on.
	} else {
		lock steering to ALIGNMENT.
		sas off.
	}

	if (mode = "approach" and alignpoint:length = 1) {
		alignpoint:empty().
		set mode to "deploy".
		partner:part:ship:connection:sendmessage("PARTNER DEPLOY").
		if grapple:getmodule("ModuleAnimateGeneric"):hasevent("Arm") {
			Grapple:GetModule("ModuleAnimateGeneric"):doevent("Arm").
		}
		unlock steering.
		wait until grapple:getmodule("ModuleAnimateGeneric"):hasevent("Disarm").
	} else if (relpos):mag < speedcap and alignpoint:length > 1 {
		alignpoint:pop().
	} else {
		set translation to (targetvelocity - relvel).

		set ship:control:translation to translation.
		wait 0.01.
	}
}


