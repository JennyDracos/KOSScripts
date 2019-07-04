
local torqueVecdraw is vecdraw(v(0,0,0),v(0,0,0),red,"current torque",1,true,0.5).
list ENGINES in engineList.
local throttledEngines is ship:partstagged("limited engine").
until false {
	set totalTorque to v(0,0,0). //this needs to be reset at the start of each new physics tick
        for engine in engineList {
		if engine:ignition and not engine:flameout {
			set totalTorque to totalTorque + vcrs(engine:availablethrust * -core:part:facing:vector,engine:position). //add this engine's torque vector to the total torque vector
		}
	}
	//now we have the total torque from every engine represented by the totalTorque vector. Now I can update the vecdraw to display the current torque visually:
	set torqueVecdraw:vec to totalTorque * 0.1. //multiply by some lower number to make the vecdraw shorter

	//this is the "length" of the torque vector along the starboard axis of the ship. Depending on the design you might want to use ship:facing:topvector instead.
	//note that the value of this can also be negative. If you find that the script is turning the thrust limits the wrong way, the add a negative sign in front of the vdot()
	set starboardTorqueMagnitude to vdot(ship:facing:starvector,totalTorque).

	for engine in throttledEngines {
		//apply the torque error multiplied by some number (technically the kP since this is in effect a P-controller) to every thrustlimited engine's _existing_ thrustlimit value. Assuming this is a spaceshuttle kind of a ship where you are only worried about torque along one axis (the pitch), they would be the engine(s) on the shuttle.
		set engine:thrustlimit to engine:thrustlimit + starboardTorqueMagnitude * 0.01. 
	}

	wait 0. //wait until next physics tick
}
