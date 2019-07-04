print "**Transfer to target...".
run libmath.
run liborbit.
// TODO: intercept burn
set m to 1.
set rz to target:obt:semimajoraxis.
set a to (rz + ship:obt:semimajoraxis) / 2.
set burnoffset to 180 * (1 - (2 * m - 1) * ((a / rz) ^ (3/2))).
print "Burn offset: " + burnoffset.
set phaseangle to target:obt:lan + target:obt:argumentofperiapsis + target:obt:trueanomaly - (ship:obt:lan + ship:obt:argumentofperiapsis + ship:obt:trueanomaly).
set traverseangle to mod(phaseangle - burnoffset + 3600, 360).  // hack to stop me from getting negative traverse angles
set timetoburn to time:seconds + (traverseangle)/((360/ship:obt:period)-(360/target:obt:period)).
set futurepos to positionat(ship, timetoburn).
set futuretgt to positionat(target, timetoburn).
set futuredown to ship:body:position - futurepos.
set futurenorm to vcrs(futuredown, velocityat(ship, timetoburn):orbit).
set futurevel to velocityat(ship, timetoburn):orbit.
set trnsvel to vcrs(futurenorm, futuredown):normalized * sqrt(ship:body:mu * (2 / futuredown:mag - 1 / a)).
set burnvel to trnsvel - futurevel.
set burnangle to vectorangle(burnvel, futurevel).
if (vectorangle(burnvel, futuredown) < vectorangle(futurevel, futuredown)) set burnangle to burnangle * -1.
print "Target SMA: " + rz.
print "Initial SMA: " + ship:obt:semimajoraxis.
print "Transfer SMA: " + ship:obt:semimajoraxis.
print "Phase angle: " + phaseangle.
print "Angle to traverse: " + (traverseangle).
print "Angle at burn: " + vectorangle(ship:body:position - futurepos, ship:body:position - futuretgt).
print "Future Vel: " + futurevel:mag.
print "Transfer Vel: " + trnsvel:mag.
print "Transfer eta: " + (timetoburn - time:seconds).
add getNode(futurevel, trnsvel, futuredown * -1, timetoburn).
// set burnpro to burnvel:mag * cos(burnangle).
// set burnrad to burnvel:mag * sin(burnangle).
// set xfrnode to node(timetoburn, burnrad, 0, burnpro).
// add xfrnode.
// if abs(burnvel:mag - xfrnode:deltav:mag)/burnvel:mag > 0.1 {
	// print "Error with dv!!! " + xfrnode:deltav:mag.
	// remove xfrnode.
	// wait 30.
	// add getNode(futurevel, trnsvel, futuredown * -1, timetoburn).
	// add xfrnode.
// }
// run exenode.
// unlock steering.
// unlock throttle.
// print "End redezvous operation.".
