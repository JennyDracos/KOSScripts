@LAZYGLOBAL off.

run once libmath.
run once liborbit.

function IterateDeltaV {
	local startTime is time:seconds.
	local endTime is startTime + ship:body:obt:period.
	local currentTime is startTime.
	local done is false.
	until currentTime >= endTime or done {
		local dt is ship:body:obt:period.
		local dtMax is target:obt:period / 2.
		until dt >= dtMax {

		}
	}
}

function LambertSolver {
	parameter r0, r1, ta0, ta1, dt, mu.
	local debug is false.
	// based on http://ccar.colorado.edu/asen5050/ASEN5050/Lectures_files/lecture16.pdf
	// state 0: initial orbit at point of transfer burn
	// state 0b: transfer orbit at point of transfer burn
	// state 1: transfer orbit at destination point
	if debug {
		alert("r0:  " + r0).
		alert("r1:  " + r1).
		alert("ta0: " + ta0).
		alert("ta1: " + ta1).
		alert("dt:  " + dt).
		alert("mu:  " + mu).
	}
	local dta is clamp360(ta1 - ta0).
	if abs(dta - 180) < 0.1 {
		// this calculation is undefined if dta = 180 degrees, guard against that condition
		if (dta - 180 > 0) {
			set dta to 180.1.
		}
		else{
			set dta to 179.9.
		}
	}
	local tm is 1.
	if dta > 180 set tm to -1.
	//local cosdta is cos(dta).
	//alert("cos: " + cosdta).
	//local sindta is sin(dta).
	local a is tm * sqrt(r0 * r1 * (1 + cos(dta))).
	if debug {
		alert("a:   " + a).
		alert("dta: " + dta).
		alert("tm:  " + tm).
	}
	if a = 0 {
		error("Cannot solve this orbit").
		set x to 1/0.
	}
	local dtn is 0. // delta t
	local dean is dta / 2. // delta E
	local psin is dean ^ 2. // delta E squared
	//local psiup is (dean * 1.5) ^ 2
	local psiup is RadToDeg(RadToDeg(4 * pi ^ 2)).
	//local psiup is psin * 1.25^2.
	//local psilow is -4 * pi.
	local psilow is 0.
	//local psilow is (dean * 0.5) ^ 2
	local count is 0.
	local chin is 0.
	local yn is -1.
	until abs(dtn - dt) < 0.0001 or count >= 200 {
		if count > 0 {
			if (dtn <= dt) {
				set psilow to psin.
				//set psilow to (psilow + psin) / 2.
				//alert("psi low:  " + psilow).
			}
			else {
				set psiup to psin.
				//set psiup to (psihigh + psin) / 2.
				//alert("psi up:   " + psiup).
			}
			set psin to (psiup + psilow) / 2.
			set dean to sqrt(psin).
		}
		local dean_rad is DegToRad(dean).
		local psi_rad is dean_rad ^ 2.
		//alert("psi: " + psin).
		//alert("dea: " + dean_rad).
		//alert("psi: " + psi_rad).
		local c2 is (1 - cos(dean)) / psi_rad.
		//alert("c2:  " + c2).
		//local c3 is (DegToRad(dean) - sin(psin)) / DegToRad(psin).
		local c3 is (dean_rad - sin(dean)) / dean_rad ^ 3.
		//alert("c3:  " + c3).
		if c2 = 0 {
			print r0.
			print r1.
			print ta0.
			print ta1.
			print dt.
			print mu.
		}
		set yn to r0 + r1 + a * (psi_rad * c3 - 1) / sqrt(c2).
		//alert("yn:  " + yn).
		if a > 0 and yn < 0 {
			error("adjust psilow until yn > 0.").
			// adjust psilow until yn > 0.
			until yn > 0 or count > 30 {
				set psilow to (psiup + psilow) / 2.
				set psin to (psiup + psilow) / 2.
				set dean_rad to DegToRad(dean).  // dean_rad -> dean
				set psi_rad to DegToRad(dean) ^ 2. // dean_rad -> dean
				set c2 to (1 - cos(dean)) / psi_rad.
				set c3 to (dean_rad - sin(dean)) / dean_rad ^ 3.
				set yn to r0 + r1 + a * (psi_rad * c3 - 1) / sqrt(c2).
				alert("yn:  " + yn).
				set count to count + 1.
			}
		}
		set chin to sqrt(yn / c2).
		set dtn to (c3 * chin ^ 3 + a * sqrt(yn)) / sqrt(mu).
		//alert("dtn: " + dtn).
		set count to count + 1.
		//wait 0.
	}
	local sma0b is (chin / DegToRad(dean)) ^ 2.
	if debug {
		alert("solved in " + count + " iterations").
		//alert("cnt: " + count).
		//alert("psi: " + psin).
		alert("yn:  " + yn).
		alert("dtn: " + dtn).
		alert("sma: " + sma0b).
	}
	local ecc is sqrt(1 - r0 * r1 / sma0b / yn * (1 - cos(dta))).
	local f is 1 - yn/r0.
	local g is a * sqrt(yn/mu).
	local gprime is 1 - yn/r1.
	return list(sma0b, ecc, yn, a, dean, f, g, gprime).
}
function LambertSolverV2 {
	parameter r0, r1, ta0, ta1, dt, mu.
	local debug is false.
	// based on http://ccar.colorado.edu/asen5050/ASEN5050/Lectures_files/lecture16.pdf
	// state 0: initial orbit at point of transfer burn
	// state 0b: transfer orbit at point of transfer burn
	// state 1: transfer orbit at destination point
	if debug {
		alert("r0:  " + r0).
		alert("r1:  " + r1).
		alert("ta0: " + ta0).
		alert("ta1: " + ta1).
		alert("dt:  " + dt).
		alert("mu:  " + mu).
	}
	local dta is clamp360(ta1 - ta0).
	if abs(dta - 180) < 0.1 {
		// this calculation is undefined if dta = 180 degrees, guard against that condition
		if (dta - 180 > 0) {
			set dta to 180.1.
		}
		else{
			set dta to 179.9.
		}
	}
	// evaluate constants
	local k is r0 * r1 * (1 - cos(dta)).
	local l is r0 + r1.
	local m is r0 * r1 * (1 + cos(dta)).

	// determine limits

	// pick trial values

	local a is 0.
	// loop

		// solve for a
		set a to m * k * p / ((2 * m - l ^ 2) * p ^ 2 + 2 * k * l * p - k ^ 2).

		// solve for f, g, and f prime

		// solve for delta E or F

		// solve for t, compare to desired time of flight

		// adjust trial value

	// end loop

	// evaluate g prime to solve for v0b and v1.
	return list(sma0b, ecc, yn, a, dean, f, g, gprime).
}
function getClosestApproach {
	parameter origin is ship,
		  destination is target.
	function getClosestApproachHelper {
		parameter centerUT, windowDT, stepCount.
		//clearvecdraws().
		//global vecdraws is list().
		local period to max(origin:obt:period, destination:obt:period).
		local timestep to windowDT / stepCount.
		local closestDistance to 10^50.
		local closestTime to -1.
		local maxdt to stepCount / 2 * timestep.
		local mindt to -maxdt.
		from { local dt is mindt. } until dt > maxdt step { set dt to dt + timestep. } do {
			local sampleTime is centerUT + dt.
			local posOrigin to positionat(origin, sampleTime).
			local posDestination to positionat(destination, sampleTime).
			local orbitDestination to orbitat(origin, sampleTime).
			if (orbitDestination:body <> origin:body) {
				local tmpBody is orbitDestination:body.
				set posOrigin to posOrigin - tmpBody:position + positionat(tmpBody, sampleTime).
			}
			local distance to (posDestination - posOrigin):mag.
			if distance < closestDistance {
				set closestDistance to distance.
				set closestTime to centerUT + dt.
				//vecdraws:add(vecdraw(v(0,0,0), posDestination, green, round(sampleTime), 1, true)).
				//vecdraws:add(vecdraw(posOrigin, posDestination - posOrigin, purple, "", 1, true)).
			}
			//else {
				//vecdraws:add(vecdraw(v(0,0,0), posDestination, red, round(sampleTime), 1, true)).
				//vecdraws:add(vecdraw(v(0,0,0), posOrigin, yellow, "", 1, true)).
				//vecdraws:add(vecdraw(posOrigin, posDestination - posOrigin, yellow, "", 1, true)).
			//}
		}
		return list(closestTime, closestDistance, timestep).
	}
	local window to max(origin:obt:period, destination:obt:period).
	local centerUT is time:seconds + window / 2.
	alert("centerUT: " + round(centerUT)).
	local closestDistance is 10^50.
	local result is getClosestApproachHelper(centerUT, window, 180).
	set centerUT to result[0].
	set closestDistance to result[1].
	set window to result[2] * 3.
	//verboselong("Closest distance 1: " + result[1]).
	set result to getClosestApproachHelper(centerUT, window, 180).
	set centerUT to result[0].
	set closestDistance to result[1].
	set window to result[2] * 3.
	//verboselong("Closest distance 2: " + closestDistance).
	set result to getClosestApproachHelper(centerUT, window, 90).
	set centerUT to result[0].
	set closestDistance to result[1].
	set window to result[2].
	//alert("Closest distance 3: " + closestDistance).
	return result.
}
function getSoiIntercept {
	local origin is ship.
	local destination is target.
	local result is getClosestApproach().
	local centerUT is result[0].
	local closestDistance is result[1].
}
function getMeridianClosestApproach {
	local window to max(ship:obt:period, target:obt:period).
	local centerUT is time:seconds + window / 2.
	local closestDistance to 10^50.
	local result is getMeridianClosestApproachHelper(centerUT, window, 360).
	set centerUT to result[0].
	set closestDistance to result[1].
	set window to result[2] * 3.
	verboselong("Meridian closest distance 1: " + result[1]).
	set result to getMeridianClosestApproachHelper(centerUT, window, 360).
	set centerUT to result[0].
	set closestDistance to result[1].
	set window to result[2] * 3.
	verboselong("Meridian closest distance 2: " + closestDistance).
	set result to getMeridianClosestApproachHelper(centerUT, window, 180).
	set centerUT to result[0].
	set closestDistance to result[1].
	set window to result[2] * 3.
	verboselong("Meridian closest distance 3: " + closestDistance).
	return result.
}
function getMeridianClosestApproachHelper {
	parameter centerUT, windowDT, stepCount.
	local period to max(ship:obt:period, target:obt:period).
	local timestep to windowDT / stepCount.
	local closestDistance to 10^50.
	local closestTime to -1.
	local maxdt to stepCount / 2 * timestep.
	local mindt to -maxdt.
	from { local dt is mindt. } until dt > maxdt step { set dt to dt + timestep. } do {
		local xcl is ship:north:vector.
		local posOrigin to vxcl(xcl, positionat(ship, centerUT + dt)).
		local posDestination to vxcl(xcl, positionat(target, centerUT + dt)).
		local distance to (posDestination - posOrigin):mag.
		if distance < closestDistance {
			set closestDistance to distance.
			set closestTime to centerUT + dt.
		}
	}
	return list(closestTime, closestDistance, timestep).
}

declare function getMeanInterceptParameters {
	declare parameter origin, target.
	local m to 1.
	local rz to target:obt:semimajoraxis.
	local a to (target:obt:semimajoraxis + origin:obt:semimajoraxis) / 2.
	local mu is origin:body:mu.
	local phaseangle1 to 180 * (1 - (2 * m - 1) * ((a / rz) ^ (3/2))). // phase angle at time of burn
	local phaseangle0 is getMeanUniversalLon(target) - getMeanUniversalLon(origin).
	local traverseangle is clamp360(phaseangle0 - phaseangle1).
	local timetoburn to time:seconds + (traverseangle)/abs((360/origin:obt:period)-(360/target:obt:period)).
	local transferSpeed is sqrt(mu * (2 / rz - 1 / a)).
	local transferDuration is getOrbPer(a, mu) / 2.
	return list(timetoburn, transferSpeed, phaseangle1, transferDuration, phaseangle0, traverseangle).
}

declare function getMeanUniversalLon {
	declare parameter target.
	local ecc is target:obt:eccentricity.
	local ta is target:obt:trueanomaly.
	local ea is getEAnom(ecc, ta).
	local ma is getMAnom(ecc, ea).
	return clamp360(target:obt:lan + target:obt:argumentofperiapsis + ma).
}

function GetLambertInterceptNode {
	parameter origin, destination, ut, dt, offsetVec.
	local burntime is ut.
	local closestTime is ut + dt.
	local pos0 is positionat(origin, burntime).
	local pos1 is positionat(destination, closestTime) + offsetVec.
//	alert("closest time: " + closestTime).
//	alert("time:         " + time:seconds).
//	alert("target distance: " + (pos1 - pos0):mag).
//	local vd_pos0 is vecdraw(v(0,0,0), pos0, red, "", 1, true).
//	local vd_pos1 is vecdraw(v(0,0,0), pos1, blue, "", 1, true).
	//wait until abort.
	local posB is ship:body:position.
	local r0 is pos0 - posB.
	local r1 is pos1 - posB.
	local dta is vang(r0, r1).
	if (vdot(vcrs(r0, r1), v(0,1,0)) > 0) set dta to clamp360(-dta).
	local solution to LambertSolver(r0:mag, r1:mag, 0, dta, dt, ship:body:mu).
	local f is solution[5].
	local g is solution[6].
	local gprime is solution[7].
	local vburn is (r1 - f * r0) * (1 / g).
	local v0 is velocityat(ship, burntime):orbit.
	local dv is vburn - v0.
	local nd is getNodeDV(v0, vburn - v0, r0, burntime).
	add nd.
	return nd.
}
// http://www.amostech.com/TechnicalPapers/2011/Poster/DER.pdf lambert2
