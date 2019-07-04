function getthrust{
	list engines in englist.
	local sumthrust is 0.
	for eng in englist
		set sumthrust to sumthrust + eng:thrust.
	
	return sumthrust.
}

//ref: ksp cheatsheet
function getstagedv{
	list engines in englist.
	local sumthrust is 0.local sumthrustoverisp is 0.
	for eng in englist{
		if eng:ignition{
			set sumthrust to sumthrust + eng:maxthrust.
			set sumthrustoverisp to sumthrustoverisp + eng:maxthrust/eng:visp.
		}
	}
	local stageisp is sumthrust/sumthrustoverisp.
	
	set decoupler to false.
	list parts in partlist.  for p in partlist if p:hasmodule("moduledecouple") set decoupler to true.
	if decoupler set reslist to stage:resources.
	else list resources in reslist.
	
	local liqmass is 0. local oximass is 0. local solmass is 0.
	for res in reslist{
		if res:name = "liquidfuel"{
			set liqmass to res:amount * res:density.
		}
		if res:name = "oxidizer"{
			set oximass to res:amount * res:density.
		}
		if res:name = "solidfuel"{
			set solmass to res:amount * res:density.
		}
	}
	local fuelmass is solmass + liqmass + oximass.
	return ln(ship:mass/(ship:mass-fuelmass))*stageisp*9.81.             
}

function vectordistance{
	parameter v1, v2.
	return sqrt((v2:x-v1:x)^2+(v2:y-v1:y)^2+(v2:z-v1:z)^2).
}

function shipvec{
	parameter vector, veccolor is green, text is "", vscale is 2, data is vector:mag, precision is 2.
	VECDRAWARGS(ship:POSITION, vector*vscale, veccolor, text+round(vector:mag,precision), 1, TRUE).
}

function hudprint{
	parameter msg, disapeartime, style is -1, textsize is 10, textcolor is green, showinterminal is false.
	hudtext(msg,disapeartime,style,textsize,textcolor,showinterminal).
}

//find local minimum or maximum.
declare function hillclimb{
	parameter fun.
	parameter starttime.
	parameter steptime.
	parameter lastval is "null".
	parameter increasing is false.
	
	set result to 0.
	set currentval to fun(starttime).
	print round(starttime,1) +": "+ round(currentval,1).
	
	//first iteration
	if lastval:istype("String") and lastval = "null"{
		set nextval to fun(starttime+steptime).
		set increasing to nextval > currentval.
		set result to hillclimb(fun,starttime+steptime*2,steptime,nextval,increasing).
	}
	else{
		//is it still going in the same direction?
		if (currentval > lastval) and increasing or not(currentval>lastval) and not increasing
			set result to hillclimb(fun,starttime+steptime,steptime,currentval,increasing).
		else 
			return starttime - steptime. //solution found, returning time before inflection.
	}
	
	return result.
}

FUNCTION groundtrack { //ty Nuggreat,been holding onto this for a while ;-)
    PARAMETER posTime,ves is ship.
    LOCAL pos IS POSITIONAT(ves,posTime+time:seconds).
    LOCAL localBody IS ves:BODY.
    LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL). 
    LOCAL timeDif IS posTime - TIME:SECONDS.
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
    LOCAL longitudeShift IS rotationalDir * posTime * CONSTANT:RADTODEG.
    LOCAL newLNG IS MOD(posLATLNG:LNG + longitudeShift ,360).
    IF newLNG < - 180 { SET newLNG TO newLNG + 360. }
    IF newLNG > 180 { SET newLNG TO newLNG - 360. }
    RETURN LATLNG(posLATLNG:LAT,newLNG).
}

//good when you can easily determine if your target state is ahead or behind.
declare function bisectionsearch{
	parameter fun.        //function for the thing you're measuring. success when fun = goal
	parameter targetahead. //function that returns true when the target is ahead in time.
	parameter mintime.
	parameter maxtime.  //absolute min and max time that you expect the goal to be in
	parameter goal.
	parameter accuracy.
	
	local i is (mintime+maxtime)/2.
	
	set result to fun(i).
	if abs(result-goal) < accuracy{
		print "Goal found: " + round(i-time:seconds,3) +": "+ round(result,4).
		return i.
	}
	
	if targetahead(result,goal){
		//print round(i-time:seconds,1) + ": " + round(result,2) + ". Goal AHEAD.".
		set i to bisectionsearch(fun,targetahead,i,maxtime,goal,accuracy).
	}
	else{
		//print round(i-time:seconds,1) + ": " + round(result,2) + ". Goal BEHIND.".
		set i to bisectionsearch(fun,targetahead,mintime,i,goal,accuracy).
	}
	return i.
}
