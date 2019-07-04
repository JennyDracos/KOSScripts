@lazyglobals off.

declare function getSMAfromApoPeri {
	parameter _apoapsis, _periapsis, _body is ship:body.

	return (_apoapsis + _periapsis) / 2 + _body:radius.
}



declare function getEscapeVelocity {
	parameter _massOfPlanet,
		  _radialDistance.

	return sqrt(2 * Constant:G * _massOfPlanet / _radialDistance).
}

declare function getHyperbolicExcessVelocity {
	
}
