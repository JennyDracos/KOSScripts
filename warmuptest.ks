set mysteer to ship:facing.
lock steering to mysteer.

set thruster to ship:partsnamed("ThermalRamjetNozzle")[0].

set maxthrust to thruster:maxthrust.

print "Pushing until thrust reaches " + maxthrust + ".".

set startTime to time:seconds.

lock throttle to 1.

wait until thruster:thrust > maxthrust.

print "Reached maximum thrust.".

set endTime to time:seconds.

lock throttle to 0.

wait until thruster:thrust = 0.

set stopTime to time:seconds.

print "Warmed up in " + (endTime - startTime) + " seconds.".
print "Shut down in " + (stopTime - endTime) + " seconds.".
