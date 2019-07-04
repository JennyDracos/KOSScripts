runoncepath("1:/lib/ui.ks").

global endPos is { return ship:position. }.
global alignment is { return ship:facing. }.

global rcsLoop is false.

clearVecDraws().

function getBounds {
	parameter vessel is ship.

	local vesselLength is 0.
	local vesselRadius is 0.

	for part in vessel:parts {
		local position is part:position - vessel:position.
		local height is vdot(position, vessel:facing:vector).
		local radialVector is position - height * vessel:facing:vector.
		local radius is radialVector:mag.

		if abs(height) > vesselLength { set vesselLength to abs(height). }
		if radius > vesselRadius { set vesselRadius to radius. }
	}

	set vesselRadius to max(vesselRadius, 2.5).
	set vesselLength to max(vesselLength, 1.0).

	return List(vesselLength * 1.1, vesselRadius * 1.5).
}

function XYZOffset {
	parameter offsetVector.	

	return endPos() + offsetVector * alignment:call().
}

function ZTROffset {
	parameter fromStation,
		  offsetVector. // with x = height, y = theta, z = radius.

	return fromStation:controlPart:position + offsetVector:x * fromStation:facing:vector + 
		offsetVector:z * (fromStation:facing * R(0,0,offsetVector:y)):upvector.
}

function XYZtoZTR {
	parameter fromStation,
		  fromPosition.

	local offset is fromPosition - fromStation:controlPart:position.
	local height is vdot(offset, fromStation:facing:vector).
	local radialVector is offset - height * fromStation:facing:vector.

	local sign is vdot(vcrs(radialVector, fromStation:facing:upvector), fromStation:facing:vector) < 0.
	if sign { return V(height, vang(radialVector, fromStation:facing:upvector), radialVector:mag). }
	else { return V(height, 360 - vang(radialVector, fromStation:facing:upvector), radialVector:mag). }

}

function Traverse {
	parameter toStation, // Example, vessel("KH Highport").
		  toPoint. // Example, dockingport:portnode.

	local traversal is List().
	
	local start is XYZtoZTR(toStation, ship:position).
	local end is XYZtoZTR(toStation, toPoint).

	local arrivalBounds is getBounds(toStation).
	local ownBounds is getBounds(ship).
	set arrivalBounds[0] to arrivalBounds[0] + max(ownBounds[0], ownBounds[1]).
	set arrivalBounds[1] to arrivalBounds[1] + max(ownBounds[0], ownBounds[1]).

	local relBounds is ZTROffset@:bind(toStation).

	if start:x > arrivalBounds[0] { // We can fly around.
		traversal:add(List(V(end:x,	     	end:y, arrivalBounds[1]), 1.0, 1.0, relBounds)).
		traversal:add(List(V(arrivalBounds[0], 	end:y, arrivalBounds[1]), 5.0, 5.0, relBounds)).
	} else if start:x < -arrivalBounds[0] { // We can fly around the back.
		traversal:add(List(V(end:x,		end:y, arrivalBounds[1]), 1.0, 1.0, relBounds)).
		traversal:add(List(V(-arrivalBounds[0],	end:y, arrivalBounds[1]), 5.0, 5.0, relBounds)).
	} else if end:z < 1 { // We can assume spinal.
		traversal:add(List(V(end:x * 1.1, start:y, arrivalBounds[1]), 1.0, 1.0, relBounds)).
		traversal:add(List(V(start:x    , start:y, arrivalBounds[1]), 1.0, 1.0, relBounds)).
	} else if ((start:x > end:x * 1.1 OR start:x < end:x * 0.9) OR
		   (start:y > end:y * 1.1 OR start:y < end:y * 0.9)) { // We need to traverse the station.
		if abs(start:z) < arrivalBounds[1] { // We need to back away to move around.
			traversal:add(List(V(start:x, start:y, arrivalBounds[1]), 1.0, 1.0, relBounds)).
		}
		local heightStep is (start:x - end:x)/5.
		local radialStep is (start:y - end:y)/5.
		for n in range(1,6) {
			traversal:insert(0, List(V(start:x - heightStep * n, 
					     start:y - radialStep * n, 
					     arrivalBounds[1]), 
					   1.0, 1.0, relBounds)).
		}
	}
	
	return traversal.
}

global zeroVelocity is { return ship:velocity:orbit. }.
global startPos is { return ship:position. }.

local hlFrom is 0.
local hlTo is 0.

local positionVector is vecDraw(V(0,0,0), V(0,0,0), green, "", 1.0, false, 0.2).
local velocityVector is vecDraw(V(0,0,0), V(0,0,0), yellow, "", 1.0, false, 0.2).
local destinationVector is vecDraw(V(0,0,0), V(0,0,0), white, "", 1.0, false, 0.2).
local translationVector is vecDraw(V(0,0,0), V(0,0,0), red, "", 1.0, false, 0.2).

global pathQueue is List(List(V(0,0,0),0,0,{ parameter v. return v.},positionVector)).

global targetFacing is { return ship:facing. }.
global terminate is { parameter distance.  return true. }.

local deOffset is { parameter v. return v. }.
local targetOffset is V(0,0,0).
local speedcap is 0.
local tolerance is 0.
local targetPos is { return deOffset(targetOffset). }.

local cycler is 100.

function shiftQueue {
	set targetOffset to pathQueue[0][0].
	set speedcap to pathQueue[0][1].
	set tolerance to pathQueue[0][2].
	set deOffset to pathQueue[0][3].
	pathQueue:remove(0).
}

function dockInit {
	sas off.
	rcs on.

	set rcsLoop to true.

	set positionVector:startUpdater to startPos.
	set positionVector:vecUpdater to { return targetPos() - startPos(). }.
	set positionVector:show to true.
	set destinationVector:startUpdater to endPos.
	set destinationVector:vecUpdater to { return targetPos() - endPos(). }.
	set destinationVector:show to true.
	set velocityVector:startUpdater to startPos.
	set velocityVector:vecUpdater to { return zeroVelocity() - ship:velocity:obt. }.
	set velocityVector:show to true.

	lock steering to targetfacing().
	shiftQueue().
}

function dockFinal {
	set positionVector:show to false.
	set velocityVector:show to false.
	set destinationVector:show to false.
	set translationVector:show to false.


	rcs off.
	unlock steering.
	set ship:control:neutralize to true.
	set rcsloop to false.
}

function dockUpdate {

	local relPos is targetPos() - startPos().

	local relVel is zeroVelocity() - ship:velocity:obt.

	local targetSpeed is max(min(0.20 * relPos:mag, speedcap), 0.1).
	local targetVelocity is -1 * targetSpeed * relPos:normalized.

	printData("Position:",  40, vecToString(relPos)).
	printData("Distance:",	41, relpos:mag).

	printData("Velocity:",  43, vecToString(relVel)).
	printData("Speed:",		44, relVel:mag).

	printData("Want Vel:",	46, vecToString(targetVelocity)).
	printData("Want Spd:",	47, targetSpeed).

	local translation is 1.0 * (relVel - targetVelocity).
	set translationVector to vecDraw(startPos() + relVel, 10 * translation, 
									 red, "", 1.0, true, 0.2).

	if translation:mag < 0.1 { set cycler to cycler - 1. }
	if cycler < 0 {
		set translation to translation * 10.
		set cycler to 100.
	}

	set ship:control:translation to translation * ship:facing:inverse.

	wait 0.

	if pathQueue:length > 0 {
		if relPos:mag < tolerance { ShiftQueue(). }
		return true.
	}
	return terminate(relPos:mag).
}



