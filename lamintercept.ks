run once liborbit_interplanetary.

parameter instruction is "".

local firstBurn is time:seconds + 120.
local lastBurn is 0.
if ship:obt:eccentricity > 1 { set lastBurn to time:seconds + 6000. }
else { set lastBurn to ship:orbit:period * 10. }
local offsetVec is V(100,0,0).
 
local segments is 5.
// GetLambertInterceptNode(origin, destination, ut, dt, offsetVec).

function LeastDVHelper {
	parameter burnTime,
		  flightTime,
		  origin is ship,
		  destination is target.

	set testNode to GetLambertInterceptNode(origin, destination, burnTime, flightTime, offsetVec).
	set deltaV to testNode:deltav:mag + 
		      (velocityat(origin, burnTime+flightTime):orbit - velocityat(destination, burnTime + flightTime):orbit):mag.
	remove testNode.

	return deltaV.
}

function LeastDVGivenBurnTime {
	parameter burnTime is firstBurn,
		  flightTimeGuess is 0,
		  origin is ship,
		  destination is target.

	if flightTimeGuess = 0 {
		local originRadius is (origin:position - origin:body:position):mag.
		local destinationRadius is (destination:position - origin:body:position):mag.
		local radiusSum is originRadius + destinationRadius.
		
		local hohmannDuration is pi * sqrt(radiusSum*radiusSum*radiusSum/(8*origin:body:mu)).

		set flightTimeGuess to hohmannDuration.
	}

	set testFlightTime to flightTimeGuess.
	set testFlightBurn to LeastDVHelper(firstBurn, flightTimeGuess).
	set oldFlightTime to 0.

	set step to Queue(3600, 600, 60, 30, 10, 5, 1, 0.5, 0.1, 0.05, 0.01).

	until step:length = 0 {
		until testFlightTime = oldFlightTime {
			print "    Testing "+round(testFlightTime,.01)+"+/-"+step:peek().
			set oldFlightTime to testFlightTime.
			set upTime to testFlightTime + step:peek().
			set downTime to testFlightTime - step:peek().
			set upBurn to LeastDVHelper(firstBurn, upTime).
			print "      "+round(upTime,.01)+": "+upBurn+"m/s".
			if upBurn < testFlightBurn {
				set testFlightBurn to upBurn.
				set testFlightTime to upTime.
			} else if downTime > 0 {
				set downBurn to LeastDVHelper(firstBurn, downTime).
				print "      "+round(downTime,.01)+": "+downBurn+"m/s".
				if downBurn < testFlightBurn {
					set testFlightTime to downTime.
					set testFlightBurn to downBurn.
				}
			}
		}
		step:pop().
		set oldFlightTime to 0.
	}
	
	set LeastDVGivenStartNode to GetLambertInterceptNode(origin, destination, firstBurn, testFlightTime, offsetVec).
	return List(LeastDVGivenStartNode, testFlightTime, testFlightBurn).
}

function LeastDVGivenIntercept {
	parameter intercept is -1,
		  origin is ship,
		  destination is target.

	if intercept = -1 {
		local originRadius is (origin:position - origin:body:position):mag.
		local destinationRadius is (destination:position - origin:body:position):mag.
		local radiusSum is originRadius + destinationRadius.

		local hohmannDuration is pi * sqrt(radiusSum * radiusSum * radiusSum / (8 * origin:body:mu) ).

		set intercept to firstBurn + lastBurn + hohmannDuration.
	}

	set firstBurn to max(firstBurn, time:seconds + 120).

	local testBurnTime is firstBurn.
	local increasing is true.
	local testBurnDV is LeastDVHelper(firstBurn, intercept - firstBurn).

	local oldBurnTime is 0.
	local firstBurnDV is testBurnDV.
	
	print "firstBurn: "+(firstBurn - time:seconds).
	print "lastBurn: "+(firstBurn + lastBurn - time:seconds).

	print "Comparing to "+testBurnDV.

	local burnTimeStep is Queue(3600, 1200, 600, 60, 30, 10, 5, 1, 0.5, 0.1, 0.05, 0.01).

	until burnTimeStep:length = 0 {
		until testBurnTime = oldBurnTime {
			print "Testing "+(testBurnTime-time:seconds)+"+/-"+burnTimeStep:peek()+".".
			set oldBurnTime to testBurnTime.
			local upBurnTime is testBurnTime + burnTimeStep:peek().
			local downBurnTime is testBurnTime - burnTimeStep:peek().

			local upBurnDV is 0.
			local downBurnDV is 0.

			if upBurnTime < intercept - 15 {
				local testResult is LeastDVHelper(upBurntime, intercept - upBurnTime).
				print "  "+(upBurntime - time:seconds)+": "+testResult+"m/s".
				if testResult < testBurnDV {
					set increasing to false.
					set testBurnTime to upBurnTime.
					set testBurnDV to testResult.
				} else if increasing {
					set testBurnTime to upBurnTime.
					set testBurnDV to testResult.
				}
			}
			if increasing = false and downBurnTime > firstBurn {
				local testResult is LeastDVHelper(downBurnTime, intercept - downBurnTime).
				print "  "+(downBurnTime - time:seconds)+": "+testResult + "m/s".
				if testResult < testBurnDV {
					set testBurnTime to upBurnTime.
					set testBurnDV to testResult.
				}
			}
		}

		burnTimeStep:pop().
		set oldBurnTime to 0.
	}

	if testBurnDV < firstBurnDV {
		GetLambertInterceptNode(origin, destination, testBurnTime, intercept - testBurnTime, offsetVec).
	} else {
		GetLambertInterceptNode(origin, destination, firstBurn, intercept - firstBurn, offsetVec).
	}
}

function LeastDVGivenNothing {
	parameter origin is ship,
		  destination is target,
		  flightTimeGuess is 0.
	
	if flightTimeGuess = 0 {
		local originRadius is (origin:position - origin:body:position):mag.
		local destinationRadius is (destination:position - origin:body:position):mag.
		local radiusSum is originRadius + destinationRadius.
		
		local hohmannDuration is pi * sqrt(radiusSum*radiusSum*radiusSum/(8*origin:body:mu)).

		set flightTimeGuess to hohmannDuration.
	}

	local bounds is {
		parameter boundsx, boundsy.
		return boundsx > firstBurn and
			boundsx < firstBurn + lastBurn and
			boundsy > 10.
	}.
	local fitness is {
		parameter fitx, fity.
		return LeastDVHelper(fitx, fity).
	}.
	local patternSearch is {
		parameter patternX, patternY, optimizer.
		local bestVertex is V(x,y,1e10).
		local step is (2^16).
		until step < 0.25 {
			print "Step size: " + step.
			local pattern is List(
				V(x, y, 0),
				V(x, y + step, 0),
				V(x + step, y, 0),
				V(x, y - step, 0),
				V(x - step, y, 0)
			).
			for vertex in pattern {
				if bounds(vertex:x, vertex:y) {
					set vertex:z to fitness(vertex:x, vertex:y).
					print "Testing " + vertex:x + " departure for " + vertex:y + " flight: " + vertex:z.
				} else { set vertex:z to 1e10. }
			}
			set bestVertex to pattern[0].
			for vertex in pattern {
				if optimizer(vertex:z, bestVertex:z) { set bestVertex to vertex. }
			}
			if bestVertex = pattern[0] {
				set step to step / 2.
			} else {
				set x to bestVertex:x.
				set y to bestVertex:y.
			}
		}
		return bestVertex.
	}.
	local x is firstBurn.
	local y is flightTimeGuess. 
	// Find local minimum.
	set firstMinimum to patternSearch(x, y, { parameter minx, miny. return minx < miny. }).
	print "First Minimum: +" + firstMinimum:x + " departure for " + firstMinimum:y + " flight.".
	// Find local maximum.
	set firstMaximum to patternSearch(x, y, { parameter maxx, maxy. return maxx > maxy. }).
	print "First Maximum: +" + firstMaximum:x + " departure for " + firstMaximum:y + " flight.".
	// Find next local minimum.
	set secondMinimum to patternSearch(firstMaximum:x + 1, firstMaximum:y, { parameter minx, miny. return minx < miny. }).
	print "Second Minimum: +" + secondMinimum:x + " departure for " + secondMinimum:y + " flight.".

	if firstMinimum:z <= secondMinimum:z {
		set node to GetLambertInterceptNode(origin, destination, firstMinimum:x, firstMinimum:y, offsetVec).
		return List(node, firstMinimum:x, firstMinimum:y).
	} else {
		set node to GetLambertInterceptNode(origin, destination, secondMinimum:x, secondMinimum:y, offsetVec).
		return List(node, firstMinimum:x, firstMinimum:y).
	}

	local testBurnTime is firstBurn.
	local testBurnDV is LeastDVGivenBurnTime(testBurnTime)[2].

	local firstBurnDV is testBurnDV.

	local oldBurnTime is 0.

	local burnTimeStep is Queue(3600, 1200, 600, 300, 60, 30, 10, 5, 1, 0.5, 0.1, 0.05, 0.01).

	local increasing is true.

	print "firstBurn: "+(firstBurn - time:seconds).
	print "lastBurn: "+(firstBurn + lastBurn - time:seconds).

	print "Comparing to "+testBurnDV.

	until burnTimeStep:length = 0 {
		until testBurnTime = oldBurnTime {
			print "Testing "+(testBurnTime-time:seconds)+"+/-"+burnTimeStep:peek()+".".
			set oldBurnTime to testBurnTime.
			local upBurnTime is testBurnTime + burnTimeStep:peek().
			local downBurnTime is testBurnTime - burnTimeStep:peek().
			local upBurnDV is 0.
			local downBurnDV is 0.
			if upBurnTime <= firstBurn + lastBurn {
				local testResult is LeastDVGivenBurnTime(upBurnTime).
				remove testResult[0].
				print "  "+(upBurnTime - time:seconds)+": "+testResult[2]+"m/s".
				if testResult[2] < testBurnDV {
					set increasing to false.
					set testBurnTime to upBurnTime.
					set testBurnDV to testResult[2].
				} else if increasing {
					set testBurnTime to upBurnTime.
					set testBurnDV to testResult[2].
				}
			}
			if increasing = false and downBurnTime >= firstBurn {
				local testResult is LeastDVGivenBurnTime(downBurnTime).
				remove testResult[0].
				print "  "+(downBurnTime - time:seconds)+": "+testResult[2]+"m/s".
				if testResult[2] < testBurnDV {
					set testBurnTime to downBurnTime.
					set testBurnDV to testResult[2].
				}
			}
		}

		burnTimeStep:pop().
		set oldBurnTime to 0.
	}	
	
	return LeastDVGivenBurnTime(testBurnTime)[0]. 
}

function matchVelocityAtClosestApproach {
	local closestApproachUT is getClosestApproach()[0].
	set node to getNode(velocityAt(ship, closestApproachUT):orbit, velocityAt(target, closestApproachUT):orbit,
		positionAt(ship, closestApproachUT)- ship:body:position, closestApproachUT).
	add node.
	return node.
}

if instruction <> "" {
	if instruction:istype("string") { set operation to instruction. }
	else { set operation to instruction["run"]. }

	if operation = "plotintercept" {
		LeastDVGivenBurnTime()[0].
	} else if operation = "bestintercept" {
		LeastDVGivenNothing().
	} else if operation = "match" {
		matchVelocityAtClosestApproach().
	} else if operation = "finetune" {
		LeastDVGivenIntercept(getClosestApproach()[0]).
	} else if operation = "hohmann" {
		getInterceptNode(target).
	} else if operation = "apsis" {
		getApsisNodeAt(instruction["alt"], instruction["uta"]).
	} else if operation = "inc" {
		getChangeIncNode(instruction["inc"], instruction["lan"]).
	} else if operation = "circ" {
		getCircNodeAt(instruction["alt"], instruction["uta"]).
	}
}
