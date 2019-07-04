parameter dockTarget is target, ownTag is "", otherTag is "".

runoncepath("0:/lib/dock.ks").

global cargoport is "".
for port in ship:partsDubbedPattern(ownTag) {
	if port:istype("DockingPort") and 
	   (port:state = "Ready" or port:state = "Disengage") {
		set cargoPort to port.
	}
}
print cargoPort:tag.
cargoPort:controlFrom.

set targetdock to "".
for port in dockTarget:partsDubbedPattern(otherTag) {
	if not port:istype("DockingPort") {
		print port:name + " not a dock.".
	} else if not port:nodetype = cargoport:nodetype {
		print port:name + " wrong size (" + port:nodetype + ")".
	} else if not port:state = "Ready" {
		print port:name + " is state " + port:state.
	} else {
		set targetdock to port.
	}
}
if targetDock = "" {
	print "Unable to find correct dock.  Terminating.".
	print 1/0.
}


set hlFrom to highlight(cargoport,green).
set hlTo to highlight(targetdock,red).

set startPos to { return cargoport:nodeposition. }.
set zeroVelocity to { return dockTarget:velocity:orbit. }.
set endPos to { return targetdock:nodeposition. }.
set alignment to { return targetdock:portfacing. }.
set targetfacing to { return lookdirup(-(targetdock:facing:vector), 
												targetdock:facing:upvector). }.

set pathQueue to List(
	List(V(  0,  0, 10), 1.0, 0.5, XYZOffset@),
	List(V(  0,  0,  5), 1.0, 0.5, XYZOffset@),
	List(V(  0,  0,  1), 0.5, 0.2, XYZOffset@),
	List(V(  0,  0,0.5), 0.2, 0.2, XYZOffset@),
	List(V(  0,  0,0.1), 0.2, 0.1, XYZOffset@),
	List(V(  0,  0,0.0), 0.1, 0.1, XYZOffset@)
).

set traversal to Traverse(dockTarget, XYZOffset(V(0,-10,0.3))).
if traversal:length > 0 { for node in traversal {
	pathQueue:insert(0, node).
}}

set rcsloop to true.
set terminate to {
	parameter distance.
	if targetDock:state:startswith("Acquire") {
		return false.
	} else { return true. }
}.
dockInit().

local run is true.
wait until not dockUpdate().

rcs off.
set ship:control:translation to V(0,0,0).
dockFinal().

wait 0.
