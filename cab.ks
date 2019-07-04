

// Equitorial burn to raise/lower longitude to peak at target.


// Create node at highest/lowest point in orbit (as appropriate).
// Burn retrograde until periapsis is ~500m.
// Until we know ship will miss any mountains, reduce burn slightly.  Iterate to find?

// Execute burn.



// Wait until periapsis.

set mynode to node(time:seconds+eta:periapsis, 0, 0, 
	-(velocityat(ship, time:seconds+eta:periapsis):orbit:mag)).
add mynode.

// Calculate the burn time to complete a burn of a fixed Δv

// Base formulas:
// Δv = ∫ F / (m0 - consumptionRate * t) dt
// consumptionRate = F / (Isp * g)
// ∴ Δv = ∫ F / (m0 - (F * t / g * Isp)) dt

// Integrate:
// ∫ F / (m0 - (F * t / g * Isp)) dt = -g * Isp * log(g * m0 * Isp - F * t)
// F(t) - F(0) = known Δv
// Expand, simplify, and solve for t

FUNCTION MANEUVER_TIME {
	PARAMETER dV.

	LIST ENGINES IN en.

	LOCAL f IS en[0]:MAXTHRUST * 1000.  // Engine Thrust (kg * m/s²)
	LOCAL m IS SHIP:MASS * 1000.        // Starting mass (kg)
	LOCAL e IS CONSTANT():E.            // Base of natural log
	LOCAL p IS en[0]:ISP.               // Engine ISP (s)
	LOCAL g IS 9.80665.                 // Gravitational acceleration constant (m/s²)

	RETURN g * m * p * (1 - e^(-dV/(g*p))) / f.
}

lock steering to mynode:deltav.

kuniverse:timewarp:warpto(time:seconds + eta:periapsis - maneuver_time(mynode:deltav:mag) - 10).

lock steering to -ship:velocity:surface.

wait until time:seconds + eta:periapsis - maneuver_time(mynode:deltav:mag).

lock throttle to ship:velocity:surface:mag.

wait until ship:velocity:surface:mag < 0.1.

lock steering to up.

unlock throttle.

// Determine if within reasonable range of landing site.  If so, use RCS to fine-tune impact point.

// Perform suicide burn to land.
