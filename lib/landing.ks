

function tupleToDeorbit {
	parameter tuple.

	// preLan is longitude of ascending node for orbit over destination.
	// this is 90 degrees before longitude of landing site when lat < 0, 270 for lat > 0.
	local newInc is abs(data["lat"]).
	local preLan is data["lng"] - 90.
	if data["lat"] < 0 { set preLan to preLan - 180. }

	// Problem is this needs to be compensated because LAN is based on solar prime vector.
	set preLan to preLan + ship:body:rotationAngle.

	// Also needs to be compensated for flight time.
	local apoHeight is ship:apoapsis + ship:body:radius.
	local periHeight is tuple[1] + ship:body:radius.
	local sma is (apoHeight + periHeight) / 2.
	local descentFlightTime is pi * sqrt(sma * sma * sma / ship:body:mu).
	local deltaAngle is descentFlightTime / ship:body:rotationperiod * 360.

	set preLan to preLan + deltaAngle.

	local ta_an to clamp360(preLan - ship:obt:argumentofperiapsis - ship:obt:lan).
	if data["lat"] > 0 {
		set ta_an to clamp360(ta_an - 180).
		set newInc to -1 * newInc.
		print "switching to DN".
	}
	local ut_an to time:seconds + getEtaTrueAnomOrbitable(ta_an, ship).

	local startV is velocityAt(ship, ut_an):orbit.
	local incDV is (2 * startV * sin(newInc / 2)):mag.
	if newInc < 0 { set incDV to -incDV. }
	local r1 is positionAt(ship, ut_an).

	//	local inclinationBurn is getNodeDV(startV, incDV, r1, ut_an).
	local inclinationBurn is node(ut_an, 0, incDV * cos(newInc), incDV * sin(-newInc)).
	add inclinationBurn.

	local apsisTime is time:seconds + inclinationBurn:eta + 0.25 * 
		inclinationBurn:orbit:period.
	local deorbitBurn is getApsisNodeAt(tuple[1], apsisTime). 
	return List(inclinationBurn, deorbitBurn).
}.


function brakeStart {
	yawpidouter:reset.
	yawpidouter:update(time:seconds, 0).
	yawpidinner:reset.
	yawpidinner:update(time:seconds, 0).
	pitchpidouter:reset.
	pitchpidouter:update(time:seconds, 0).
	pitchpidinner:reset.
	pitchpidinner:update(time:seconds, 0).

	lock steering to ship:srfretrograde * R(0.1 * pitchpidouter:output, 0.1 * yawpidouter:output, 0).

	when ship:velocity:surface:mag < 500 then {
		for realchute in ship:modulesnamed("") {
			if realchute:hasevent("Deploy Chute") realchute:doevent("Deploy Chute").
		}
	}
}

function suicideStart {

	rcs on.
	brakes on.
	lock steering to lookdirup(srfretrograde:vector, ship:facing:upvector).
	gear on.

	wait 4.
	local bounds_box is ship:bounds.

	lock avgMaxVertDecel to choose 0 if ship:velocity:surface:mag = 0 else 
	  (ship:availablethrust / ship:mass) * (2 * (-ship:verticalspeed / ship:velocity:surface:mag) + 1)
	  / 3 - (body:mu / (body:radius * body:radius)).

	lock idealThrottle to ((ship:verticalSpeed * ship:verticalSpeed) / (2 * avgMaxVertDecel)) /
	  (bounds_box:BottomAltRadar + 1).
	when idealThrottle > 1 then {
		lock throttle to idealThrottle.
	}
}

function suicideUpdate {
	if ship:verticalSpeed > -0.01 {
		set ship:control:pilotmainthrottle to 0.
		rcs off.
		lock throttle to 0.
		return true.
	}
	return false.
}
