clearscreen.

print "Phase difference".

function nonZeroOffset {
	parameter angle.
	if angle < 0 { return 360 + angle. }
	return angle.
}


from { local x is -180. } until x >= 180
step { set x to x + 10. }
do {
	print x + " - " + nonZeroOffset(x) + " " + nonZeroOffset(nonZeroOffset(x)-70).
	
}

