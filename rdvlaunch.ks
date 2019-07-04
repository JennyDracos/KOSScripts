run once util.ks.
run once "test.ks".
 
set twrsetting to 1.3.
set lngsetting to 18.  //apo longitude dist from ksc (inc planetspin). ~8-18 are solid grav turns.
 
local cpitch is 0.
local cazimuth is 0.
local claunchtime is 0.
set target to Vessel("Low Orbit").
 
//get launch parameters
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").  //ty spaceishard
calculatelaunch(target,twrsetting,lngsetting).
 
//wait for launch time
set kuniverse:timewarp:mode to "RAILS".
kuniverse:timewarp:warpto(claunchtime-2).
wait until time:seconds >= claunchtime - 1.5.
 
//launch
set launchdata to launchtest(twrsetting,cpitch,cazimuth).
 
//circularize and fine tune approach.
wait until altitude >= 65000. lock steering to prograde.
wait until altitude >= 68000. boostapo(target,time:seconds + eta:apoapsis).
wait until altitude >= 70000. circRdvBurn(target).
 
wait 15. kuniverse:reverttolaunch().
 
//ensure elevation at apo is boosted at least to elevation of target.
function boostapo{
    parameter targetship, apotime.
   
    set interceptalt to (positionat(targetship,apotime)-Kerbin:position):mag - 600000.
    if apoapsis < interceptalt{
        print "boosting apoapsis".
        lock throttle to .1.
        wait until apoapsis >= interceptalt or altitude > 77000.
        lock throttle to 0.
    }
}
 
function circRdvBurn{
    parameter targetship.
    wait until altitude >= 70000.
    set apotime to time:seconds + eta:apoapsis.
    set shipapopos to positionat(ship,apotime).
 
    set targvel to velocityat(targetship,apotime):orbit.
    set shipvel to velocityat(ship,apotime):orbit.
    set burn to targvel:mag - shipvel:mag.
    set burnaccel to maxthrust/mass.
    set burntime to burn/burnaccel.
    set burnstarttime to apotime - burntime/2.
 
    print "Burn in " + round(burnstarttime - time:seconds, 1) + "s".
    wait until time:seconds >= burnstarttime.
    lock throttle to burnaccel * mass / availablethrust.
    wait until time:seconds >= burnstarttime + burntime.
    unlock throttle.
   
    print "Final distance: " + round((ship:position - targetship:position):mag) + "m".
    print "Relative speed: " + round((ship:velocity:orbit - targetship:velocity:orbit):mag,1) + "m/s".
}
 
 
 
function rdzbisection{
    parameter targetlng, margintime, accuracy,mintime is 0, maxtime is 0.
   
    set fun to {parameter t. return groundtrack(t-time:seconds,target):lng.}.
    set targetahead to {
        parameter lng,tlng.
        if lng<0 return tlng>lng and tlng<lng+180.
        else return not (tlng<lng and tlng>lng-180).
    }.
   
    //if 0, they havent been set so calculate min/max. else use provided vals
    if mintime = 0{
        if  targetahead(groundtrack(margintime+2,target):lng,targetlng)
            set mintime to time:seconds+margintime.
        else
            set mintime to time:seconds+target:orbit:period/2-10.
    }
    if maxtime = 0
        set maxtime to mintime+target:orbit:period.
   
   
   
    print " ". print "Target lng: "+ round(targetlng,2) + " Search space: " + round(mintime-time:seconds) + "-" + round(maxtime-time:seconds) + "s".
   
    return bisectionsearch(fun,targetahead,mintime,maxtime,targetlng,accuracy).
}
 
function calculatelaunch{
    parameter targetship, twr, dlng.
    set cpitch to calculatepitch(twr,dlng).
    set L2ApTime to calculatetime(twr,dlng).
   
    //calculate apoapsis intersection with target.
    set interceptlng to ship:geoposition:lng + dlng.
    set intercepttime to rdzbisection(interceptlng, L2ApTime,.001).
    set claunchtime to intercepttime - L2ApTime.
 
    //calculate launch azimuth for SLIGHT inclination.
    set difvec to positionat(targetship,intercepttime) - positionat(ship,intercepttime).   
    set cazimuth to 90 - vang(difvec,v(difvec:x,0,difvec:z)).  //works for prograde launches, I think it will fail retrograde ones.
   
    wait 0.
    print " ".
    print "Launch parameters calculated:".
    print "Target     " + targetship:name.
    print "Pitch      " + round(cpitch,2).
    print "LaunchETA  " + round(claunchtime - time:seconds) + "s".
    print "Launch to intercept: " + round(L2ApTime,1) + "s".
    print "Intercept longitude: " + round(ship:geoposition:lng + dlng,1).
    print "Intercept azimuth:   " + round(cazimuth,2).
}
 
 
//magic
function calculatepitch{
    parameter twr, dlng.
   
    set x to ln(twr).
    set y to ln(dlng).
    set p00 to     -0.1462.
    set p10 to         4.5.
    set p01 to     -0.8013.
    set p20 to      -10.66.
    set p11 to     -0.1052.
    set p02 to      0.2868.
    set p30 to       14.35.
    set p21 to       6.558.
    set p12 to      -2.396.
    set p03 to      0.2297.
    set p40 to      -7.551.
    set p31 to       -7.39.
    set p22 to       2.967.
    set p13 to      0.1478.
    set p04 to    -0.07455.
    set p50 to       1.247.
    set p41 to       2.363.
    set p32 to     -0.9006.
    set p23 to      -0.125.
    set p14 to   -0.007399.
    set p05 to    0.007187.
   
    set p to p00 + p10*x + p01*y + p20*x^2 + p11*x*y + p02*y^2 + p30*x^3 + p21*x^2*y
                + p12*x*y^2 + p03*y^3 + p40*x^4 + p31*x^3*y + p22*x^2*y^2
                + p13*x*y^3 + p04*y^4 + p50*x^5 + p41*x^4*y + p32*x^3*y^2
                + p23*x^2*y^3 + p14*x*y^4 + p05*y^5.
               
    return p^2.
}
 
function calculatetime{
    parameter twr,dlng.
   
    set x to ln(twr).
    set y to ln(dlng).
    set p00 to       17.07.
    set p10 to      -10.22.
    set p01 to       3.107.
    set p20 to       15.22.
    set p11 to      -11.09.
    set p02 to     -0.5024.
    set p30 to      -16.62.
    set p21 to       13.71.
    set p12 to       2.337.
    set p03 to     -0.1342.
    set p40 to       9.853.
    set p31 to      -7.422.
    set p22 to      -1.864.
    set p13 to     -0.2921.
    set p04 to     0.08525.
    set p50 to      -2.298.
    set p41 to       1.469.
    set p32 to      0.5305.
    set p23 to     0.08212.
    set p14 to     0.02153.
    set p05 to   -0.006024.
 
    set t to p00 + p10*x + p01*y + p20*x^2 + p11*x*y + p02*y^2 + p30*x^3 + p21*x^2*y
                    + p12*x*y^2 + p03*y^3 + p40*x^4 + p31*x^3*y + p22*x^2*y^2
                    + p13*x*y^3 + p04*y^4 + p50*x^5 + p41*x^4*y + p32*x^3*y^2
                    + p23*x^2*y^3 + p14*x*y^4 + p05*y^5.
 
                   
    return t^2.
}
