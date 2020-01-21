parameter inputData is "", ForcePush is false.

set data to choose inputData if inputData <> "" else choose readjson("1:/data.json") if exists("1:/data.json") else Lexicon(
	"mode",		"Launch"
	,"mission", "orbit"
).

for name in List(
	"libmath",
	"liborbit",
	"liborbit_interplanetary"
) compile "0:/" + name + ".ks" to "1:/" + name + ".ksm".

for name in List(
	"lib/node.ks",
	"lib/comms.ks",
	"lib/ui.ks",
	"libsimplex.ks",

	"lib/bisectionsolver.ks",
	"launch_pitch_jerk.ks",

	"boot/booster.ks"
) copypath("0:/" + name, "1:/" + name).

runoncepath("1:/liborbit_interplanetary").
runoncepath("1:/lib/node.ks").

print "Library files loaded.".

if ship:status = "PRELAUNCH" set data:radarOffset to alt:radar.
else if not data:haskey("radarOffset") set data:radaroffset to 31.851.

// 10T booster - 17.038
// 20T booster - 31.851
// 50T booster - 28.486

writejson(data, "1:/data.json").


global kpo is 1.
global kio is 0.1.
global kdo is 0.5.

global kpi is 1.
global kii is 0.1.
global kdi is 0.5.

global kpt is 1.
global kit is 0.1.
global kdt is 0.5.

global anglemag is 5.

function cascade {
	parameter outer, inner, t, mag.

	return outer:update(t, inner:update(t, mag)).
}

local yawpidouter is pidloop(kpo, kio, kdo, -anglemag, anglemag).
local yawpidinner is pidloop(kpi, kii, kdi, -anglemag, anglemag).
local yawupdate is cascade@:bind(yawpidouter, yawpidinner).

local pitchpidouter is pidloop(kpo, kio, kdo, -anglemag, anglemag).
local pitchpidinner is pidloop(kpi, kii, kdi, -anglemag, anglemag).
local pitchupdate is cascade@:bind(pitchpidouter, pitchpidinner).

local throtpidouter is pidloop(kpt, kit, kdt, 0, 1).
local throtpidinner is pidloop(kpt, kit, kdt, 0, 1).
local throtupdate is cascade@:bind(throtpidouter, throtpidinner).

local throt is 0.

// Happens every time a state is entered.
function SetMode {
	parameter newMode.

	print "Setting mode from " + data:mode + " to " + newMode.
	set data:mode to newMode.

	print "Mode set.".

//	if newMode = "Prelaunch" {
//		when ship:maxthrust > 0 then {
//			SetMode("Launch").
//		}
//	}
//
//	if newMode = "Launch" {
//		print "Running ascent.".
//		runpath("1:/launch_pitch_jerk.ks", 80000).
//		if data:mission = "orbit" {
//			SetMode("Circ").
//		}
//	}
//
//	else if newMode = "Circ" {
//		getCircNodeAt(time:seconds + eta:apoapsis).
//	}

	if newMode = "PlotDeorbit" {
		print "Plotting deorbit burn.".
		until KUniverse:activevessel = ship {
			wait 1.
		}
		until not hasnode {
			remove nextnode.
			wait 0.
		}
		local tr is addons:tr.
		local deorbitTime is globalSection(time:seconds + 60, ship:orbit:period / 10, {
			parameter t.

			getApsisNodeAt(6000,t).
			until tr:hasimpact wait 0.
			local error is choose 1e6 if not tr:hasimpact else 
				sqrt((tr:impactpos:lat + 0.097)^2 + (tr:impactpos:lng + 74)^2).
			remove nextnode.
			until not tr:hasimpact wait 0.
			return error.
		}).
		wait 0.
		getApsisNodeAt(6000,deorbitTime).
		PushPhase().
	}

	else if newMode = "RunDeorbit" {
		if not hasnode or nextnode:eta < 0 SetMode("PlotDeorbit").
	}

	else if newMode = "Descent" {
		lock steering to srfretrograde.
		local atmoTime is goldenSection(time:seconds, time:seconds + eta:periapsis, {
			parameter t.
			return (positionat(ship,t) - body:position):mag - body:radius - body:atm:height.
		}).
		addalarm("Raw",atmoTime,ship:name + " Reentry","").
	}

	else if newMode = "Translation" {
		until not hasnode {
			remove nextnode.
			wait 0.
		}

		yawpidouter:reset.
		yawpidouter:update(time:seconds, 0).
		yawpidinner:reset.
		yawpidinner:update(time:seconds, 0).
		pitchpidouter:reset.
		pitchpidouter:update(time:seconds, 0).
		pitchpidinner:reset.
		pitchpidinner:update(time:seconds, 0).

		lock steering to ship:srfretrograde * R(pitchpidouter:output, yawpidouter:output, 0).

		lock lerr to sqrt(
			(addons:tr:impactpos:lat + 0.094) * (addons:tr:impactpos:lat + 0.094) +
			(addons:tr:impactpos:lng + 74.4) * (addons:tr:impactpos:lng + 74.4)).
		lock throttle to choose 0.1 if lerr > 0.05 and lerr < 2 else 0.
		yawupdate(time:seconds, addons:tr:impactpos:lat + 0.094).
		pitchupdate(time:seconds, addons:tr:impactpos:lng + 74.4).
	}

	else if newMode = "Braking" {
		until not hasnode {
			remove nextnode.
			wait 0.
		}

		yawpidouter:reset.
		yawpidouter:update(time:seconds, 0).
		yawpidinner:reset.
		yawpidinner:update(time:seconds, 0).
		pitchpidouter:reset.
		pitchpidouter:update(time:seconds, 0).
		pitchpidinner:reset.
		pitchpidinner:update(time:seconds, 0).

		lock steering to ship:srfretrograde * R(0.1 * pitchpidouter:output, 0.1 * yawpidouter:output, 0).

		when ship:velocity:surface:mag < 500 then {
			for realchute in ship:modulesnamed("") {
				if realchute:hasevent("Deploy Chute") realchute:doevent("Deploy Chute").
			}
		}
	}

	else if newMode = "Touchdown" {
		lock steering to lookdirup(ship:up, ship:north).
		gear on.
	}

	else if newMode = "Suicide" {
		rcs on.
		brakes on.
		lock steering to srfretrograde.
		gear on.

		lock throttle to 0.

		wait 4.
		local bounds_box is ship:bounds.

		lock avgMaxVertDecel to choose 0 if ship:velocity:surface:mag = 0 else 
		  (ship:availablethrust / ship:mass) * (2 * (-ship:verticalspeed / ship:velocity:surface:mag) + 1)
		  / 3 - (body:mu / (body:radius * body:radius)).

		lock idealThrottle to ((ship:verticalSpeed * ship:verticalSpeed) / (2 * avgMaxVertDecel)) /
		  (bounds_box:BottomAltRadar).
		when idealThrottle > 1 then {
			lock throttle to idealThrottle.
		}
	}

	writejson(data, "1:/data.json").
}

// Happens only when a stage is exited.
function PushPhase {
	if data:mode = "Launch" {
		SetMode("Circ").
	} else if data:mode = "Circ" {
		// Deploy payload
		stage.
		SetMode("PlotDeorbit").
	} else if data:mode = "PlotDeorbit" {
		SetMode("RunDeorbit").
	} else if data:mode = "RunDeorbit" {
		SetMode("Braking").
	} else if data:mode = "Braking" {
		SetMode("Translation").
	} else if data:mode = "Translation" {
		SetMode("Suicide").
	} else if data:mode = "Suicide" {
		lock steering to lookdirup(ship:up:vector, ship:facing:upvector).
		SetMode("Landed").
	} else if false {
		SetMode("Descent").
	} else if data:mode = "Descent" {
		SetMode("FinalTranslation").
	} else if data:mode = "FinalTranslation" {
		SetMode("Touchdown").
	}
	else { print "No state to follow " + data:mode. }
}

if core:part:tag = "Support Booster" and ship:modulesnamed("KOSProcessor"):length > 1
	SetMode("Support").
else if ForcePush 
	PushPhase().
else 
	SetMode(data:mode).

until false {

	if ship:modulesnamed("KOSProcessor"):length > 1 {
		wait 10.
	} else if data:mode = "Launch" {
		SetMode("PlotDeorbit").
	} else if data:mode = "Support" {
		if ship:modulesnamed("KOSProcessor"):length > 1 wait 10.
		else if KUniverse:ActiveVessel = ship SetMode("PlotDeorbit").
		else wait 10.
	} else if data:mode = "Braking" {
		yawupdate(time:seconds, addons:tr:impactpos:lat + 0.094).
		pitchupdate(time:seconds, addons:tr:impactpos:lng + 74.2).
		if data:mode = "Braking" and ship:velocity:surface:mag < 500 {
			pushPhase().
		}
		wait 0.
	} else if data:mode = "Translation" {
		yawupdate(time:seconds, addons:tr:impactpos:lat + 0.094).
		pitchupdate(time:seconds, addons:tr:impactpos:lng + 74.3).
		if ship:altitude < 5000 PushPhase().
	} else if data:mode = "Suicide" {
		if ship:verticalSpeed > -0.01 {
			set ship:control:pilotmainthrottle to 0.
			rcs off.
			lock throttle to 0.
			PushPhase().
		}
	} else if burnLoop and BurnUpdate() {
		set burnLoop to false.

		lock throttle to 0.
		unlock steering.

		PushPhase().
		wait 0.
	} else if burnLoop {
		wait 0.
	} else if hasnode {
		core:part:controlfrom.

		rcs on.

		if nextnode:deltav:mag < 0.1 {
			remove nextnode.
			wait 0.
			PushPhase().
		} else if true {
		//ManeuverTime(nextnode:deltav:mag) < 2 {
			RunNode().
			PushPhase().
		} else {
			BurnNode().
		}
	} else {
		wait 1.
	}

}


