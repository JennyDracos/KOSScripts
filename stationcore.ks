// Generate set of letters for keys.
set alpha to list("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z").

// Generate way to add more keys if needed.
set prefix to queue().
for letter in alpha { prefix:push(letter). }

// And make list of keys to build graph.
set newKey to queue().
for letter in alpha { newKey:push(letter). }

// And the graph itself.  Each element consists of the key, the position relative to the ship, and the list of edges.
set surfaceGraph to lexicon().


clearvecdraws().
// Add all docking ports.  Then visualize.
for dockingport in ship:dockingports {
	set clearance to 0.
	if (dockingport:tag = "spinal") and (dockingport:state = "ready") {
		set clearance to 10.
	}
	if dockingport:tag:startswith("hl20") {
		set clearance to 10.
	}
	if dockingport:tag:endswith("nest") {
		set clearance to 10.
	}
	if dockingport:tag:startswith("Small Dock") {
		if dockingport:state = "ready" {
			set clearance to 5.
		} else {
			set clearance to 30.
		}
	}
	if dockingport:tag:startswith("Large Dock") {
		if dockingport:state = "ready" {
			set clearance to 5.
		} else {
			set clearance to 30.
		}
	}
	if dockingport:tag:endswith("bow") and (dockingport:state = "ready") {
		set clearance to 10.
	}
	if dockingport:tag:endswith("stern") and (dockingport:state = "ready") {
		set clearance to 10.
	}
	if (clearance > 0) {
		// Determine position in context of ship:facing.
		set absolutePosition to dockingport:position + clearance * dockingport:portfacing:forevector.
		set relativePosition to V(
			vdot(absolutePosition - ship:position,ship:facing:rightvector),
			vdot(absolutePosition - ship:position,ship:facing:upvector),
			vdot(absolutePosition - ship:position,ship:facing:vector)
		).
		vecdraw(
			dockingport:position,
			(relativePosition * ship:facing) + ship:position - dockingport:position, 
			RGB(1,0,0), "", 1.0, true, 0.2
		).
		surfaceGraph:add(newKey:pop(), list(relativePosition)).
		if (newKey:Empty) {
			for letter in alpha {
				newKey:push(prefix:peek() + letter).
			}
			prefix:pop().
		}
		print relativePosition:tostring:padright(12) + dockingport:tag.
	}
}

