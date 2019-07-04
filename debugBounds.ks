parameter vess is ship.

runpath("0:/libdock.ks").

local bounds is getBounds(vess).

local height is bounds[0].
local radius is bounds[1].

function vdsa {
	parameter start, end.
	local vec is vecdraw(start, end-start).
	set vec:show to true.
	return vec.
}

for n in (1, 9) {
	
	local start is ZTROffset(vess, V(bounds[0], (n-1)*(360/8), bounds[1])).
	vecdraw(ZTROffset(vess, V(bounds[0], (n-1)*(360/8), bounds[1]))
	
}
