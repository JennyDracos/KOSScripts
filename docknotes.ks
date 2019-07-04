set trvel to 0.
set trpos to 0.
set xerr to 0.
set yerr to 0.
set zerr to 0.
set xcorr to 0.
set ycorr to 0.
set zcorr to 0.
set phase to "".

set maxvel to 5.0.
set errormargin to 0.20.

set shipdock to ship:partstagged(ship:name + " Spinal")[0].
shipdock:controlfrom.

if (hastarget) {
    if target:istype("Vessel") {
        set tship to target.
        set tdock to target:partstagged(target:name + " " + filter)[0].
    } else {
        set tship to target:ship.
        set tdock to target.
    }
} else {
    set tship to vessel(docktarget).
    set tdock to tship:partstagged(docktarget + " " + filter)[0].
}
set bow to tship:partstagged(tship:name + " Bow")[0].
lock axis to bow:facing:forevector.
lock steering to lookdirup(-(tdock:facing:forevector), axis).

lock avoidvector to vcrs(tdock:facing:forevector, axis).
lock avoidpoint to (2 + 2 + 2) * avoidvector + tdock:position.

lock alignpoint to tdock:position + 5 * tdock:facing:vector.

set targetpoint to alignpoint.
set correction to v(0,0,0).

wait until vectorangle(ship:facing:vector, -tdock:facing:forevector) < 0.2.

until shipdock:state:startswith("Docked") {
    set trvel to tship:velocity:orbit - ship:velocity:orbit.
    set xcorr to vdot(trvel, ship:facing:starvector).
    set ycorr to vdot(trvel, ship:facing:upvector).
    set zcorr to vdot(trvel, ship:facing:forevector).
    clearscreen.
    print "Velocity: ".
    print "x: " + round(xcorr, 2).
    print "y: " + round(ycorr, 2).
    print "z: " + round(zcorr, 2).

    set trpos to tdock:position - shipdock:position.
    if (vdot(trpos, ship:facing:forevector) < 0) {
        set trpos to avoidpoint - shipdock:position.
        set phase to "Avoid".
    } else { 
        set trpos to alignpoint - shipdock:position.
        set phase to "Align".
    }
    print "Position: ".
    set xerr to vdot(trpos, ship:facing:starvector).
    set yerr to vdot(trpos, ship:facing:upvector).
    set zerr to vdot(trpos, ship:facing:forevector).
    print "x: " + round(xerr, 2).
    print "y: " + round(yerr, 2).
    print "z: " + round(zerr, 2).

    print "Moving to " + phase + " Point.".

    if abs(xerr) < errormargin {
        Print "X acceptable.  Zeroing.".
        if xcorr > 0.00 { rcs on. set ship:control:starboard to 0.1. }
        if xcorr < -0.00 { rcs on. set ship:control:starboard to -0.1. }
    } else if xerr > 100 * errormargin {
        if xcorr > -0.9 { 
            rcs on. 
            set ship:control:starboard to 0.1. 
            print "X very high.  Velocity low.  Accelerating.".
        } else if xcorr < -1.0 { 
            rcs on. 
            set ship:control:starboard to -0.1. 
            print "X very high, velocity high.  Decelerating.".
        } else { print "X high, velocity acceptable.  Waiting.". }
    } else if xerr > 10 * errormargin {
        if xcorr > -0.25 { 
            rcs on. 
            set ship:control:starboard to 0.1. 
            print "X high.  Velocity low.  Accelerating.".
        } else if xcorr < -0.5 { 
            rcs on. 
            set ship:control:starboard to -0.1. 
            print "X high, velocity high.  Decelerating.".
        } else { print "X high, velocity acceptable.  Waiting.". }
    } else if xerr > errormargin {
        if xcorr > -0.05 { 
            rcs on. 
            set ship:control:starboard to 0.1. 
            print "X slightly high.  Velocity low.  Accelerating.".
        } else if xcorr < -0.10 { 
            rcs on. 
            set ship:control:starboard to -0.1. 
            print "X slightly high, velocity high.  Decelerating.".
        } else { print "X slightly high, velocity acceptable.  Waiting.". }
    } else if xerr < -100 * errormargin {
        if xcorr < 0.9 { 
            rcs on. 
            set ship:control:starboard to -0.1. 
            Print "X very low, velocity low.  Accelerating.".
        } else if xcorr > 1.0 { 
            rcs on. 
            set ship:control:starboard to 0.1. 
            Print "X very low, velocity high.  Decelerating.".
        } else { print "X very low, velocity acceptable.  Waiting.". }
    } else if xerr < -10 * errormargin {
        if xcorr < 0.25 { 
            rcs on. 
            set ship:control:starboard to -0.1. 
            Print "X low, velocity low.  Accelerating.".
        } else if xcorr > 0.5 { 
            rcs on. 
            set ship:control:starboard to 0.1. 
            Print "X low, velocity high.  Decelerating.".
        } else { print "X low, velocity acceptable.  Waiting.". }
    } else if xerr < -errormargin {
        if xcorr < 0.05 { 
            rcs on. 
            set ship:control:starboard to -0.1. 
            Print "X slightly low, velocity low.  Accelerating.".
        } else if xcorr > 0.1 { 
            rcs on. 
            set ship:control:starboard to 0.1. 
            Print "X slightly low, velocity high.  Decelerating.".
        } else { print "X slightly low, velocity acceptable.  Waiting.". }
    }
    if abs(yerr) < errormargin {
        Print "Y acceptable.  Zeroing.".
        if ycorr > 0.00 { rcs on. set ship:control:top to 0.1. }
        if ycorr < -0.00 { rcs on. set ship:control:top to -0.1. }
    } else if yerr > 100 * errormargin {
        if ycorr > -0.90 { 
            rcs on.
            set ship:control:top to 0.1. 
            Print "Y very high.  Velocity low.  Accelerating.".
            } else if ycorr < -1.0 { 
                rcs on.
            set ship:control:top to -0.1. 
            Print "Y very high.  Velocity high.  Decelerating.".
        } else { Print "Y very high.  Velocity acceptable.  Waiting.".}
    } else if yerr > 10 * errormargin {
        if ycorr > -0.25 { 
            rcs on.
            set ship:control:top to 0.1. 
            Print "Y high.  Velocity low.  Accelerating.".
            } else if ycorr < -0.5 { 
                rcs on.
            set ship:control:top to -0.1. 
            Print "Y high.  Velocity high.  Decelerating.".
        } else { Print "Y high.  Velocity acceptable.  Waiting.".}
    } else if yerr > errormargin {
        if ycorr > -0.01 { 
            rcs on.
            set ship:control:top to 0.1. 
            Print "Y slightly high.  Velocity low.  Accelerating.".
            } else if ycorr < -0.05 { 
                rcs on.
            set ship:control:top to -0.05. 
            Print "Y slightly high.  Velocity high.  Decelerating.".
        } else { Print "Y slightly high.  Velocity acceptable.  Waiting.".}
    } else if yerr < -100 * errormargin {
        if ycorr < 0.90 { 
            rcs on.
            set ship:control:top to -0.1. 
            Print "Y very low.  Velocity low.  Accelerating.".
        } else if ycorr > 1.0 { 
            rcs on.
            set ship:control:top to 0.1. 
            Print "Y very low.  Velocity high.  Decelerating.".
        } else { Print "Y very low.  Velocity acceptable.  Waiting.". }
    } else if yerr < -10 * errormargin {
        if ycorr < 0.25 { 
            rcs on.
            set ship:control:top to -0.1. 
            Print "Y low.  Velocity low.  Accelerating.".
        } else if ycorr > 0.5 { 
            rcs on.
            set ship:control:top to 0.1. 
            Print "Y low.  Velocity high.  Decelerating.".
        } else { Print "Y low.  Velocity acceptable.  Waiting.". }
    } else if yerr < -errormargin {
        if ycorr < 0.02 { 
            rcs on.
            set ship:control:top to -0.1. 
            Print "Y slightly low.  Velocity low.  Accelerating.".
        } else if ycorr > 0.05 { 
            rcs on.
            set ship:control:top to 0.1. 
            Print "Y slightly low.  Velocity high.  Decelerating.".
        } else { Print "Y slightly low.  Velocity acceptable.  Waiting.". }
    }
    if (zerr > -5 and abs(xerr) < errormargin and abs(yerr) < errormargin) {
        print "Controlling z to 0.1!".
        rcs on.
        if zcorr > 0.1 {
            set ship:control:fore to -0.2.
        } else if zcorr < 0.05 {
            set ship:control:fore to 0.2.
        }
    } else if (zerr > -5 and zerr < 0) {
        Print "Z acceptable.  Zeroing.".
        if zcorr > 0.01 { rcs on. set ship:control:fore to -0.1. }
        if zcorr < -0.01 { rcs on. set ship:control:fore to 0.1. }
    } else if zerr > 100 * errormargin {
        if zcorr > -0.9 { 
        rcs on.
            set ship:control:fore to 0.1. 
            Print "Z very high.  Velocity low.  Accelerating.".
            } else if zcorr < -1.0 { 
                rcs on.
            set ship:control:fore to -0.1. 
            Print "Z very high.  Velocity high.  Decelerating.".
        } else { Print "Z very high.  Velocity acceptable.  Waiting.".}
    } else if zerr > 10 * errormargin {
        if zcorr > -0.25 { 
        rcs on.
            set ship:control:fore to 0.1. 
            Print "Z high.  Velocity low.  Accelerating.".
            } else if zcorr < -0.5 { 
                rcs on.
            set ship:control:fore to -0.1. 
            Print "Z high.  Velocity high.  Decelerating.".
        } else { Print "Z high.  Velocity acceptable.  Waiting.".}
    } else if zerr > errormargin {
        if zcorr > -0.25 { 
        rcs on.
            set ship:control:fore to 0.1. 
            Print "Z slightly high.  Velocity low.  Accelerating.".
            } else if zcorr < -0.5 { 
                rcs on.
            set ship:control:fore to -0.1. 
            Print "Z slightly high.  Velocity high.  Decelerating.".
        } else { Print "Z slightly high.  Velocity acceptable.  Waiting.".}
    } else if zerr < -100 * errormargin {
        if zcorr < 0.9 { 
            rcs on.
            set ship:control:fore to -0.1. 
            Print "Z very low.  Velocity low.  Accelerating.".
        } else if zcorr > 1.0 { 
            rcs on.
            set ship:control:fore to 0.1. 
            Print "Z very low.  Velocity high.  Decelerating.".
        } else { Print "Z very low.  Velocity acceptable.  Waiting.". }
    } else if zerr < -10 * errormargin {
        if zcorr < 0.25 { 
            rcs on.
            set ship:control:fore to -0.1. 
            Print "Z low.  Velocity low.  Accelerating.".
        } else if zcorr > 0.5 { 
            rcs on.
            set ship:control:fore to 0.1. 
            Print "Z low.  Velocity high.  Decelerating.".
        } else { Print "Z low.  Velocity acceptable.  Waiting.". }
    } else if zerr < -errormargin {
        if zcorr < 0.05 { 
            rcs on.
            set ship:control:fore to -0.1. 
            Print "Z slightly low.  Velocity low.  Accelerating.".
        } else if zcorr > 0.1 { 
            rcs on.
            set ship:control:fore to 0.1. 
            Print "Z slightly low.  Velocity high.  Decelerating.".
        } else { Print "Z slightly low.  Velocity acceptable.  Waiting.". }
    }
   
    
    if xcorr > maxvel {
        rcs on.
        print "Too Fast!  RCS Right!".
        set ship:control:starboard to 0.2.
    } else if xcorr < -maxvel {
        rcs on.
        print "Too Fast!  RCS Left!".
        set ship:control:starboard to -0.2.
    }

    if ycorr > maxvel {
        rcs on.
        print "Too Fast!  RCS Up!".
        set ship:control:top to 0.2.
    } else if ycorr < -maxvel {
        rcs on.
        print "Too Fast!  RCS Down!".
        set ship:control:top to -0.2.
    }

    if zcorr > maxvel {
        rcs on.
        print "Too Fast!  RCS Fore!".
        set ship:control:fore to 0.2.
    } else if zcorr < -maxvel {
        rcs on.
        print "Too Fast!  RCS Back!".
        set ship:control:fore to -0.2.
    }
    if shipdock:state = "PreAttached" {
        rcs off.
    } else {
        print ship:control:translation.
        wait 0.1.
    }
    rcs off.
    set ship:control:translation to v(0,0,0).
    wait 0.1.
}
unlock steering.
