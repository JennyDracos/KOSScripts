global endPosition is ship:position.
global alignment is ship:facing. 


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

	local draw is vecdraw(endPosition, offsetVector * alignment).
	set draw:show to true.

	return endPosition + offsetVector * alignment.
}

function ZTROffset {
	parameter fromStation,
		  offsetVector. // with x = height, y = theta, z = radius.

	local draw is vecdraw(fromStation:controlpart:position, offsetVector:x * fromStation:facing:vector +
		offsetVector:z * (fromStation:facing * R(0,0,offsetVector:y)):upvector). 
	set draw:show to true. 

	return fromStation:controlPart:position + offsetVector:x * fromStation:facing:vector + 
		offsetVector:z * (fromStation:facing * R(0,0,offsetVector:y)):upvector.
}

function XYZtoZTR {
	parameter fromStation,
		  fromPosition.

	local offset is fromPosition - fromStation:controlPart:position.
	local height is vdot(offset, fromStation:facing:vector).
	local radialVector is offset - height * fromStation:facing:vector.

	local drawHeight is vecdraw(fromStation:controlPart:position, 
		height * fromStation:facing:vector, 
		green).
	local drawRadial is vecdraw(fromStation:controlPart:position + height * fromStation:facing:vector,
		radialVector, 
		blue).
	set drawHeight:show to true. set drawRadial:show to true.

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
