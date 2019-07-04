@lazyglobal off.

set terminal:width to 157.

function printData {
	parameter label,
			  row,
			  data is { return "". }.
	print (label:padright(15) + data):padright(50) at (100, row).
}
function vecToString {
	parameter v.
	return "x"+(" "+round(v:x,2)):padleft(10) +
		  " y"+(" "+round(v:y,2)):padleft(10) +
		  " z"+(" "+round(v:z,2)):padleft(10).
}

function clearUI {
	for n in range(0, terminal:height) {
		print " ":padright(50) at (100, n).
	}
}

global commandInput is "".
global inputHandler is {}.


