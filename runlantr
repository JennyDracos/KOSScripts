// Get next maneuver node.
set nd to nextnode.

// Calculate burn at full throttle.
print "Node in: " + round(nd:eta) + ", DeltaV: " + round(nd:deltav:mag).

// Calculate ship's max acceleration.
set max_acc to ship:maxthrust / ship:mass.
// TODO: add code to account for nuke warmup.

// Now estimate burn time.
// TODO: add Tsiolkovsky rocket equation.
// TODO: add nuke warmup.  ...This may take advanced calculus.
set burn_duration to nd:deltav:mag/max_acc + 10.
print "Crude Estimated burn duration: " + round(burn_duration) + "s".

// TODO: warp to burn time.
//wait until nd:eta <= (burn_duration / 2 + 120 + 10000).
//set kuniverse:timewarp:warp to min(kuniverse:timewarp:warp, 4).
//wait until nd:eta <= (burn_duration / 2 + 120 + 1000).
//set kuniverse:timewarp:warp to min(kuniverse:timewarp:warp, 3).
//wait until nd:eta <= (burn_duration / 2 + 120 + 100).
//set kuniverse:TimeWarp:Warp to min(kuniverse:timewarp:warp, 2).
//wait until nd:eta <= (burn_duration / 2 + 120).
//kuniverse:TimeWarp:CancelWarp().
kuniverse:timewarp:warpto(time:seconds + nd:eta - 60 - burn_duration / 2).

// Turn to burn.
set np to nd:deltav.  // This sets the direction and ignores roll.
lock steering to np:direction.

// Now wait until aligned.
wait until abs(np:direction:pitch - facing:pitch) < 0.15 and abs(np:direction:yaw - facing:yaw) < 0.15.

// Wait for burn time.
// TODO: account for spooling only if present.
wait until nd:eta <= (burn_duration / 2 + 10).

// We only need to lock throttle once to a certain variable
// in the beginning of the loop, then adjust the variable while in the loop.
set throttlesetpoint to 0.
lock throttle to throttlesetpoint.

set done to false.
// Initial deltav.
set dv0 to nd:deltav.
until done {
     // Recalculate current max acceleration.
     set max_acc to ship:maxthrust / ship:mass.

     // Throttle is 100% until there is less tahn 1 second of time left
     // in the burn.  At that point, decrease linearly.
     set throttlesetpoint to min(nd:deltav:mag / max_acc, 1).

     // Here's the tricky part.
     // We need to cut throttle as soon as our nd:deltav and initial deltav
     // start facing opposite directions.
     // We'll do this be checking the dot product of those two vectors.
     if vdot(dv0, nd:deltav) < 0
     {
          print "End burn, remain dv " + round(nd:deltav:mag, 1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav), 1).
          lock throttle to 0.
          break.
     }

     // We have less than 0v1m/s to burn.
     if nd:deltav:mag < 0.1
     {
          print "Finalizing burn, remain dv " + round (nd:deltav:mag, 1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
          // Slow burn until node drifts significantly.
          wait until vdot(dv0, nd:deltav) < 0.5.

          lock throttle to 0.
          print "End burn, remain dv " + round(nd:deltav:mag, 1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav), 1).
          set done to True.
     }
}
unlock steering.
unlock throttle.
wait 1.

// We no longer need the maneuver node.
remove nd.

// Set throttle to 0 just in case.
set ship:control:pilotmainthrottle to 0.