@lazyglobal off.

global g0 to 9.80665.
global M_PI to constant:pi.
global M_E to constant:e.
global M_RTD to constant:radtodeg.
global M_DTR to constant:degtorad.
global M_GOLD to (1 + sqrt(5)) / 2.

function sign {
  parameter x.
  if x > 0 { return 1. }
  if x < 0 { return -1. }
  return 0.
}

function clamp {
  parameter x, b1, b2.
  local xmin to min(b1, b2).
  local xmax to max(b1, b2).

  if x < xmin { return xmin. }
  if x > xmax { return xmax. }
  return x.
}

function toIRF {
// changes to inertial right-handed coordinate system where ix = SPV, iy = vcrs(SPV, V(0, 1, 0)), iz = V(0, 1, 0)
  parameter oldVec, SPV to SolarPrimeVector.
  return V(vdot(oldVec, SPV), vdot(oldVec, V(-SPV:z, 0, SPV:x)), oldVec:y).
}

function fromIRF {
// changes from inertial right-handed coordinate system where ix = SPV, iy = vcrs(SPV, V(0, 1, 0)), iz = V(0, 1, 0)
  parameter irfVec, SPV to SolarPrimeVector.
  return V(vdot(irfVec, V(SPV:x, -SPV:z, 0)), irfVec:z, vdot(irfVec, V(SPV:z, SPV:x, 0))).
}

function ThrustIsp {
  local el to 0.
  list engines in el.
  local vex to 1.
  local ff to 0.
  local tt to 0.
  for e in el {
    set ff to ff + e:availablethrust/max(e:visp,0.01).
    set tt to tt + e:availablethrust*vdot(facing:vector,e:facing:vector).
  }
  if tt<>0 set vex to g0*tt/ff.
  return list(tt, vex).
}

function warpfor {
  parameter dt.
  // warp    (0:1) (1:5) (2:10) (3:50) (4:100) (5:1000) (6:10000) (7:100000)
  local t1 to time:seconds + dt.
  if dt < 0 {
    print "WARNING: wait time " + round(dt) + " is in the past.".
    return.
  }
  local tw to kuniverse:timewarp.
  local wp to tw:warp.
  local oldwp to wp.
  local rt to t1 - time:seconds.
  until rt <= 0 {
    set wp to clamp(round(log10(min((rt*0.356)^2,rt*50))), 0, 7).
    if wp <> oldwp or wp <> tw:warp {
      if not tw:issettled {
        wait tw:ratelist[min(oldwp,wp)]*0.1.
      }
      set wp to clamp(wp, oldwp-1, oldwp+1).
      set tw:warp to wp.
      wait 0.
      if tw:warp <> oldwp print "Warp " + tw:ratelist[tw:warp] + "x; remaining time " + round(rt) + "/" + round(dt).
      set oldwp to tw:warp.
    }
    if tw:mode <> "rails" and (altitude > body:atm:height or status = "prelaunch") {
      tw:cancelwarp.
      wait until tw:issettled.
      set tw:mode to "rails".
      wait 0.
    }
    wait 0.
    set rt to t1 - time:seconds.
  }
  tw:cancelwarp.
}

function solv_ridders {
  parameter fn, x0, x1, rtol to 0.0, flo to False, fhi to False, verbose to False.

  local MAXITER to 50.
  set rtol to max(rtol, 2^(-53)).

  local xlo to x0.
  local xhi to x1.
  local xmid to 0.
  if (not flo) {
    set flo to fn(x0).
  }
  if (not fhi) {
    set fhi to fn(x1).
  }
  local fmid to 0.
  local iter to 1.
  local delta to 0.
  local denom to 0.
  local xans to x0.

  if flo * fhi > 0 {
    print "ERROR in SOLV_RIDDERS: root not bracketed between endpoints".
    return 1 / 0.
  }

  if flo = 0 {return xlo.}
  if fhi = 0 {return xhi.}

  until iter > MAXITER {
    local dxm to (xhi - xlo) / 2.
    set xmid to xlo + dxm.
    set delta to rtol * (1 + abs(xmid)) / 2.
    set fmid to fn(xmid).
    if fmid = 0 {
     if verbose {
       print iter + ". x = " + xmid + "; Exact solution found".
     }
     return xmid.
    }
    local r1 to fmid / flo.
    local r2 to fhi / flo.
    set denom to sqrt(r1 * r1 - r2).

    local dx to dxm * r1 / denom.
    if abs(dx) < delta {
      if dx > 0 {set dx to delta.}
      else {set dx to -delta.}
    }
    set xans to xmid + dx.

    if verbose {
      print iter + ". x = " + xans + "; est_err = " + abs(xhi - xlo) / 2.
    }

    if (abs(dxm) < delta) {return xans.}
    if abs(xans - xhi) < delta {
      set xans to xhi - sign(dxm) * delta.
    }
    if abs(xans - xlo) < delta {
      set xans to xlo + sign(dxm) * delta.
    }
    local fans to fn(xans).
    if fans = 0 {
      if verbose {
        print "Exact solution found.".
      }
      return xans.
    }
    if fans * fmid < 0 {
      set xlo to xmid.
      set xhi to xans.
      set flo to fmid.
      set fhi to fans.
    }
    else if fans * flo < 0 {
      set xhi to xans.
      set fhi to fans.
    }
    else {
      set xlo to xans.
      set flo to fans.
    }
    set iter to iter + 1.
  }
  print "WARNING: exceeded MAXITER in SOLV_RIDDERS".
  return xans.
}

function linesearch_brent {
  // straddle is a lexicon which has keys "xlo" and "xhi", optionally "flo" and "fhi" and a pair ("xbest", "fbest")
  parameter fn, straddle, rtol to 4e-8, maxpinterp to 40.

  set rtol to max(rtol, 4e-8).
  local CGOLD to 1 - 1 / M_GOLD.
  local MAXITER to 40.
  local TINY to 1e-20.
  local xlo to straddle["xlo"].
  local xhi to straddle["xhi"].
  local flo to 0.
  local fhi to 0.
  if straddle:haskey("flo") {
    set flo to straddle["flo"].
  }
  else {
    set flo to fn(xlo).
  }
  if straddle:haskey("fhi") {
    set flo to straddle["fhi"].
  }
  else {
    set fhi to fn(xhi).
  }
  if (xlo > xhi) {
    local tmp to xlo.
    set xlo to xhi.
    set xhi to tmp.
    set tmp to flo.
    set flo to fhi.
    set fhi to tmp.
  }

  local dxm to (xhi - xlo) / 2.
  local xmid to xlo + dxm.
  local atol to rtol * (1 + abs(xmid)).
  local atol2 to 0.
  local xbest to xlo.
  local xsecb to xhi.
  local xspre to xhi.
  local fbest to flo.
  local fsecb to fhi.
  local fspre to fhi.
  local dxpre to 0.
  if straddle:haskey("xbest") {
    set xbest to straddle["xbest"].
    set fbest to straddle["fbest"].
    if fhi < flo {
      set fspre to flo.
      set xspre to xlo.
    }
    else {
      set fsecb to flo.
      set xsecb to xlo.
    }
    set dxpre to max(xbest - xlo, xhi - xbest).
  }
  else if fhi < flo {
    set fbest to fhi.
    set fsecb to flo.
    set fspre to flo.

    set xbest to xhi.
    set xsecb to xlo.
    set xspre to xlo.
  }
  local fcur to fbest.
  local xcur to xbest.
  local dxcur to dxpre.

  local niter to 1.
  local df2 to 0.
  local df to 0.
  local npinterp to 1.

  local function use_goldsection {
    //print "Golden section search used".
    if xbest < xmid {
      set dxpre to xhi - xbest.
    }
    else {
      set dxpre to xlo - xbest.
    }
    set dxcur to CGOLD * dxpre.
  }

  until abs(xmid - xbest) < atol2 - dxm {
    if abs(dxpre) > atol {
      local r to (xbest - xsecb) * (fbest - fspre).
      local q to (xbest - xspre) * (fbest - fsecb).
      local p to (xbest - xspre) * q - (xbest - xsecb) * r.
      set q to 2 * (q - r).
      if q > 0 {
        set p to -p.
      }
      else {
        set q to -q.
      }
      if q = 0 {
        use_goldsection().
      }
      else {
        local dxtry to p / q. //-df / df2.
        //print "Parabolic approximation: " + (xbest + dxtry).
        if abs(dxtry) > 0.5 * abs(dxpre) or dxtry <= xlo + atol2 - xbest or dxtry >= xhi - atol2 - xbest {
          use_goldsection().
        }
        else {
          set npinterp to npinterp + 1.
          set dxpre to dxcur.
          set dxcur to dxtry.
        }
      }
    }
    else {
      use_goldsection().
    }
    if abs(dxcur) < atol {
      if dxcur >= 0 set dxcur to atol.
      else set dxcur to -atol.
    }
    set xcur to xbest + dxcur.
    //print "Trial coordinate: " + xcur.
    set fcur to fn(xcur).

    if fcur <= fbest {
      if dxcur >= 0 { set xlo to xbest. }
      else { set xhi to xbest. }
      set xspre to xsecb.
      set fspre to fsecb.
      set xsecb to xbest.
      set fsecb to fbest.
      set xbest to xcur.
      set fbest to fcur.
    }
    else {
      //print "no improvement".
      //print xlo + " " + xhi + " " + xcur.
      if dxcur < 0 { set xlo to xcur. }
      else { set xhi to xcur. }
      if (fcur <= fsecb) or (xsecb = xbest) {
        set xspre to xsecb.
        set fspre to fsecb.
        set xsecb to xcur.
        set fsecb to fcur.
      }
      else if (fcur <= fspre) or (xspre = xbest) or (xspre = xsecb) {
        set xspre to xcur.
        set fspre to fcur.
      }
    }
    //print "Iteration " + niter + ". Current best: " + xbest + " " + fbest.
    //print xlo + "  " + xhi.
    set dxm to (xhi - xlo) / 2.
    set xmid to xlo + dxm.
    set atol to rtol * (1 + abs(xmid)).
    set atol2 to 2 * atol.
    set niter to niter + 1.
    if npinterp > maxpinterp {
      //print "Number of parabolic fits exceeded".
      break.
    }
    if niter > MAXITER {
      print "WARNING: exceeded MAXITER in LINSEARCH".
      break.
    }
  }
  print fbest.
  return lex("x", xbest, "f", fbest).
}

//	Conic State Extrapolation
// Formulas follow H.D. Curtis, Orbital Mechanics for Engineering Students, Chapter 3.7

// Stumpff S and C functions
function SnC_ell {
  parameter z.
  if z < 1e-4 {
    return lex("S", (1 - z * ( 0.05 - z / 840) ) / 6, "C", 0.5 - z * ( 1 - z / 30) / 24).
  }
  local saz to sqrt(z).
  local x to saz * m_rtd.
  return lex("S", (saz - sin(x)) / (saz * z), "C", (1 - cos(x)) / z).
}

function SnC_hyp {
  parameter z.
  if z > 1e-4 {
    return lex("S", (1 - z * ( 0.05 - z / 840) ) / 6, "C", 0.5 - z * ( 1 - z / 30) / 24).
  }
  local saz to sqrt(-z).
  local x to m_e^saz.
  local sh to 0.5 * (x - 1 / x).
  return lex("S", (saz - sh) / (saz * z), "C", (1 - sh - 1 / x) / z).
}

// Conic State Extrapolation Routine
function CSER {
  parameter r0, v0, dt, mu to body:mu, x0 to False, tol to 1e-12.
  if dt = 0 {
    return list(r0, v0, 0).
  }
  local rscale to r0:mag.
  local vscale to sqrt(mu / rscale).
  local r0s to r0 / rscale.
  local v0s to v0 / vscale.
  local dts to dt * vscale / rscale.
  local v2s to v0:sqrmagnitude * rscale / mu.
  local alpha to 2 - v2s.
  local armd1 to v2s - 1.
  local rvr0s to vdot(r0, v0) / sqrt(mu * rscale).

  local period to 2 * M_PI / abs(alpha)^1.5.
  if alpha > 0 {
    until dts > 0 {
      set dts to dts + period.
    }
    until dts <= period {
      set dts to dts - period.
    }
  }


  local SnC to SnC_ell@.
  if alpha < 0 {
    set SnC to SnC_hyp@.
  }.

  local anomaly_eq to {
    parameter x.

    local x2 to x * x.
    local SCz to SnC(alpha * x2).
    return x2 * (rvr0s * SCz["C"] + x * armd1 * SCz["S"]) + x - dts.
  }.

  local x to dts * alpha.

  local ecc to sqrt(1 - alpha * (v2s - rvr0s * rvr0s)).

  if ecc > tol {
    if (not x0) {
      if alpha > 0 {
        set x0 to x.
      }
      else {
        local s to sign(dts).
        local r to sqrt(-1 / alpha).
        set x0 to s * r * ln(-2 * dts * alpha / (rvr0s + s * r * (1 - alpha))).
      }
    }

    local f0 to anomaly_eq(x0).
    local x1 to 0.
    local f1 to -dts.

    if alpha > 0 { // elliptic orbit
      local dx to max(2.01 * ecc / sqrt(alpha), tol * abs(x)).
      if f0 < 0 {
        set x1 to min(1.01 * period * alpha, x + dx).
        set f1 to anomaly_eq(x1).
      }
      else if x > dx {
        set x1 to x - dx.
        set f1 to anomaly_eq(x1).
      }
    }
    else { // hyperbolic orbit
      local dx to -x0.
      until sign(f1) * sign(f0) < 0 {
        set dx to dx * 2.
        set x0 to x1.
        set f0 to f1.
        set x1 to x1 + dx.
        set f1 to anomaly_eq(x1).
      }
    }

    if f0 * f1 > 0 {
      print ecc.
      print x0.
      print x.
      print x1.
      print f0.
      print f1.
    }
    set x to solv_ridders(anomaly_eq, x0, x1, tol, f0, f1).
  }
  local x2 to x * x.
  local z to alpha * x2.
  local SCz to SnC(z).
  local x2Cz to x2 * SCz["C"].

  local r1 to (1 - x2Cz) * r0s + (dts - x2 * x * SCz["S"]) * v0s.
  local ir1 to 1 / r1:mag.
  local Lfdot to ir1 * x * (z * SCz["S"] - 1).
  local Lgdot to 1 - x2Cz * ir1.

  local v1 to Lfdot * r0s + Lgdot * v0s.

  return list(r1 * rscale, v1 * vscale, x).
}

function GetStateFromOrbit {
  parameter torb, utime, x to False.

  local mu to torb:body:mu.
  local sma to abs(torb:semimajoraxis).
  local mm to sqrt(mu / sma^3).
  local mna to torb:meananomalyatepoch.
  local dts to (utime - torb:epoch) * mm + mna * M_DtR.
  local ecc to torb:eccentricity.
  if ecc < 1 {
    local period to 2 * M_PI.
    until dts <= period set dts to dts - period.
    until dts >= 0 set dts to dts + period.
  }

  local PeNRM to R(0, 0, torb:lan) * R(torb:inclination, 0, torb:argumentofperiapsis).

  local r0s to PeNRM:rightvector * abs(1 - ecc).
  local v0s to PeNRM:upvector * sqrt((1 + ecc) / abs(1 - ecc)).
  local vscale to sqrt(mu / sma).

  local r1v1s to CSER(r0s, v0s, dts, 1, x).
  return list(r1v1s[0] * sma, r1v1s[1] * vscale, r1v1s[2]).
}

function PEG_init {
  parameter peg_state, obj_orbit, TI, flow_rate, vex.
  set peg_state["Vgo"] to GetStateFromOrbit(obj_orbit, peg_state["tnow"])[1] - peg_state["Vnow"].
  set peg_state["Vd"] to peg_state["Vnow"] + peg_state["Vgo"].
  set peg_state["Rd"] to peg_state["Rnow"].
  set peg_state["Rp"] to peg_state["Rnow"].
  set peg_state["Vmag"] to peg_state["Vgo"]:mag.
  set peg_state["tgo_pre"] to 1.
  set peg_state["omega_fctr"] to body:mu / peg_state["Rnow"]:sqrmagnitude^1.5.
  set peg_state["dRg"] to -peg_state["Rnow"] * peg_state["omega_fctr"].
  set peg_state["firstpass"] to True.
  set TI["F1"] to 1.
  set TI["F2"] to 1.
  set TI["F3"] to 1.
  local Vgo_converged to False.
  local niter to 0.
  until Vgo_converged {
    PEG_integ(peg_state, TI, flow_rate, vex).
    PEG_turnr(peg_state, TI).
    PEG_predictor(peg_state, TI).
    set Vgo_converged to (PEG_corrector(peg_state, obj_orbit) < 1e-6).
    set niter to niter + 1.
  }
  if homeconnection:isconnected {
    log "" to "0:/testing/peg_node_log.txt".
    open("0:/testing/peg_node_log.txt"):clear.
  }
  return niter.
}

function PEG_update {
  parameter peg_state.
  wait 0.
  local SPV to solarprimevector.
  local Rnow to -body:position.
  local Vnow to velocity:orbit.
  local dt to time:seconds - peg_state["tnow"].
  local cmass to mass.

  set Vnow to toIRF(Vnow, SPV).
  set Rnow to toIRF(Rnow, SPV).
  set peg_state["mass"] to cmass.
  set peg_state["tgo_pre"] to peg_state["tgo"].
  set peg_state["tnow"] to peg_state["tnow"] + dt.
  set peg_state["omega_fctr"] to body:mu / Rnow:sqrmagnitude^1.5.
  set peg_state["Vgo"] to peg_state["Vgo"] + peg_state["Vnow"] - Vnow - dt * peg_state["omega_fctr"] * Rnow .
  set peg_state["Vmag"] to peg_state["Vgo"]:mag.
  set peg_state["Vnow"] to Vnow.
  set peg_state["Rnow"] to Rnow.
  set peg_state["firstpass"] to True.
}

function PEG_integ {
  parameter peg_state, TI, flow_rate, vex.
  local tau to peg_state["mass"] / flow_rate.
  local Vgom to peg_state["Vmag"].
  local tgo to tau * (1 - M_E^(-Vgom / vex)).
  set peg_state["tgo"] to tgo.
  //print "Vgo: " + Vgom.
  if Vgom / vex > 0.02 {
    set TI["S"] to -Vgom * (tau - tgo) + vex * tgo.
    set TI["Q"] to TI["S"] * tau - 0.5 * vex * tgo * tgo.
  }
  else {
    set TI["S"] to 0.5 * Vgom * tgo.
    set TI["Q"] to TI["S"] * tgo / 3.
  }
  set TI["J"] to Vgom * tgo - TI["S"].
}

function PEG_turnr {
  parameter peg_state, TI.
  local phi_max to 0.25.
  local uniL to peg_state["Vgo"]/peg_state["Vmag"].
  set peg_state["uniL"] to uniL.
  local tgo to peg_state["tgo"].

  if tgo > 2 {
    local JoL to TI["J"] / peg_state["Vmag"].
    local os to sqrt(peg_state["omega_fctr"]).
    local omega_max to min(2 * os, phi_max / JoL).
    set TI["Q"] to TI["F2"] * (TI["Q"] - TI["S"] * JoL).
    local dRg to (tgo / peg_state["tgo_pre"])^2 * peg_state["dRg"].
    local Rgo to peg_state["Rd"] - (peg_state["Rnow"] + peg_state["Vnow"] * tgo + dRg).
    set TI["S"] to TI["F3"] * TI["S"].
    set Rgo to Rgo + peg_state["iz"] * (TI["S"] - vdot(uniL, Rgo)) / vdot(peg_state["iz"], uniL).
    local dotL to (Rgo - TI["S"] * uniL) / TI["Q"].
    local omega to dotL:mag.
    local theta to omega * peg_state["tgo"] / 2.
    local delta to omega * JoL - theta.
    if omega > omega_max {
      set dotL to dotL / omega * tan(omega_max * JoL * M_RtD) / JoL.
      set theta to omega_max * peg_state["tgo"] / 2.
      set delta to omega_max * JoL - theta.
      set omega to 1e-6.
    }
    if omega < 1e-6 or omega > os {
      set omega to 1e-6.
    }
    local f1 to sin(theta * M_RtD) / theta.
    local cosd to cos(M_RtD * delta).
    set peg_state["F1"] to f1 * cosd.
    set peg_state["F2"] to cosd * 3 * (f1 - cos(M_RtD * theta)) / (theta * theta).
    set peg_state["F3"] to peg_state["F1"] * (1 - theta * delta / 3).
    set peg_state["dotL"] to dotL.
    set peg_state["omega"] to omega.
    set peg_state["Rgo"] to Rgo.
    set peg_state["tL"] to peg_state["tnow"] + tan(omega * JoL * M_RtD) / omega.
  }
  else {
    set peg_state["omega"] to 1e-8.
    set peg_state["dotL"] to V(0,0,0).
    set peg_state["Rgo"] to uniL * TI["S"].
  }
  print "Distance to go: " + peg_state["Rgo"]:mag at (0,16).
}

function PEG_predictor {
  parameter peg_state, TI.
  local tgo to peg_state["tgo"].
  local Vthrust to TI["F1"] * peg_state["Vgo"].
  local Rthrust to peg_state["Rgo"].
  if homeconnection:isconnected {
    log peg_state to "0:/testing/peg_node_log.txt".
  }

  if tgo > 5 {
    local Rc1 to peg_state["Rnow"] - (Rthrust + Vthrust * tgo / 3) / 10.
    local Vc1 to peg_state["Vnow"] + 1.2 * Rthrust / tgo - 0.1 * Vthrust.
    local rvgrav to CSER(Rc1, Vc1, tgo, body:mu, peg_state["xcse"], 1e-7).
    set peg_state["dRg"] to rvgrav[0] - Rc1 - Vc1 * tgo.
    set peg_state["dVg"] to rvgrav[1] - Vc1.
    set peg_state["xcse"] to rvgrav[2].
  }
  else {
    local gVec to -0.5 * (peg_state["Rnow"] * peg_state["omega_fctr"] +
                          body:mu * peg_state["Rp"] / peg_state["Rp"]:sqrmagnitude^1.5).
    set peg_state["dVg"] to gVec * tgo.
    set peg_state["dRg"] to gVec * tgo * tgo / 2.
  }
  set peg_state["Rp"] to peg_state["Rnow"] + peg_state["Vnow"] * tgo + Rthrust + peg_state["dRg"].
  set peg_state["Vp"] to peg_state["Vnow"] + peg_state["dVg"] + Vthrust.
}

function PEG_corrector {
  parameter peg_state, obj_orbit.
  local Rerr to peg_state["Rp"] - peg_state["Rd"].
  print "Position error: " + round(vdot(Rerr, peg_state["uniL"]), 3) + "         " at (0,9).
  local Verr to peg_state["Vp"] - peg_state["Vd"].
  local v2 to Verr:sqrmagnitude.
  print "Velocity error: " + round(sqrt(v2), 3) + "         " at (0,10).
  local tgo to peg_state["tgo"].
  set v2 to v2 / max(peg_state["Vmag"]^2, 100).
  set peg_state["Vgo"] to peg_state["Vgo"] - 0.5 * Verr.
  if v2 >= 1e-6 or peg_state["firstpass"] {
    local RVd to GetStateFromOrbit(obj_orbit, peg_state["tnow"] + peg_state["tgo"]).
    set peg_state["Rd"] to RVd[0].
    set peg_state["Vd"] to RVd[1].
    set peg_state["firstpass"] to False.
  }
  set peg_state["Vmag"] to peg_state["Vgo"]:mag.
  set peg_state["tgo_pre"] to tgo.
  return v2.
}

function exenode_peg {
  clearscreen.
  local nd1 to nextnode.
  local obj_orbit to nd1:orbit.
  local TIsp to ThrustIsp().
  local tt to TIsp[0].
  local vex to TIsp[1].
  if tt = 0 {
    print "ERROR: No active engines!".
    set ship:control:pilotmainthrottle to 0.
    return.
  }
  local flow_rate to tt / vex.
  local m0 to mass.
  local ndv to nd1:deltav:mag.
  local tau to m0 / flow_rate.
  local dob to tau * (1 - M_E^(-ndv / vex)).
  local JoL to tau - vex * dob / ndv.
  wait 0.
  local cur_orbit to ship:orbit.
  local iz to toIRF(nd1:deltav):normalized.

  local function get_position_error {
    parameter dt.
    local utstart to obj_orbit:epoch - dt.
    local RVnow to GetStateFromOrbit(cur_orbit, utstart).
    local peg_state to lex("Rnow", RVnow[0], "Vnow", RVnow[1], "tnow", utstart, "mass", m0, "xcse", False, "omega", 1e-6, "iz", iz).
    local TI to lex().
    PEG_init(peg_state, obj_orbit, TI, flow_rate, vex).
    return (peg_state["Rp"] - peg_state["Rd"]):sqrmagnitude.
  }

  local dt to linesearch_brent(get_position_error@, lex("xlo", dob / 2, "xhi", m0 * ndv / (2 * tt)), max(0.02 / JoL, 1e-3), 3)["x"].
  local utstart to nd1:orbit:epoch - dt.
  wait 0.
  local SPV to solarprimevector.
  local Rb to body:position.
  local Rnow to positionat(ship, utstart) - Rb.
  local Vnow to velocityat(ship, utstart):orbit.

  local peg_state to lex("Rnow", toIRF(Rnow, SPV), "Vnow", toIRF(Vnow, SPV), "tnow", utstart, "mass", mass, "xcse", False, "omega", 1e-6, "iz", iz).
  local TI to lex().
  local maxiter to min(4, PEG_init(peg_state, obj_orbit, TI, flow_rate, vex)).
  local peg_steer to lex("L", peg_state["uniL"], "dL", peg_state["dotL"], "tL", peg_state["tL"]).
  local done to False.
  local once to True.
  local lock tm to round(missiontime).

  set ship:control:pilotmainthrottle to 0.

  warpfor(utstart - time:seconds - 60 - dob / 30).
  sas off.
  rcs off.

  print "T+" + tm + " Turning ship to burn direction.".
  local lock steer_vector to fromIRF(peg_steer["L"] + peg_steer["dL"] * (time:seconds - peg_steer["tL"])).
  lock steering to lookdirup(steer_vector, -body:position).
  wait until (vang(steer_vector, facing:vector) < 0.05 and
             ship:angularvel:mag < max(0.05, 1.5 * peg_state["omega"])) or
             utstart - time:seconds < 10.
  warpfor(utstart - time:seconds - 10).
  print "T+" + tm + " Burn start " + round(obj_orbit:epoch - utstart, 2) + " s before node.".
  local tset to 0.
  lock throttle to tset.
  wait until time:seconds >= utstart.
  set tset to clamp(peg_state["Vmag"] * m0 / tt, 0.05, 1).
  until done {
    local PEG_conv to False.
    local niter to 0.
    PEG_update(peg_state).
    until PEG_conv or niter > maxiter {
      set niter to niter + 1.
      PEG_integ(peg_state, TI, flow_rate, vex).
      PEG_turnr(peg_state, TI).
      PEG_predictor(peg_state, TI).
      set PEG_conv to (PEG_corrector(peg_state, obj_orbit) < 1e-6).
    }
    set maxiter to clamp(niter, 1, maxiter).
    set tset to clamp(1.5 * peg_state["Vmag"] * mass / tt, 0.02, 1).
    if PEG_conv {
      print "PEG converged in " + niter + " iterations" at (0,15).
      set peg_steer["L"] to peg_state["uniL"].
      set peg_steer["dL"] to peg_state["dotL"].
      set peg_steer["tL"] to peg_state["tL"].
    }
    if vdot(iz, peg_state["Vgo"]) < 0 {
      print "T+" + tm + " Burn aborted, remain dv " + round(peg_state["Vgo"]:mag,1) + "m/s, vdot: " + round(vdot(iz, peg_state["Vgo"]),1).
      lock throttle to 0.
      break.
    }
    if tset < 1 {
      wait 0.
      local Rb to body:position.
      unlock steer_vector.
      local steer_vector to velocityat(ship, time:seconds + tset / 1.5):orbit - (velocity:orbit + tset / 1.5 * body:mu * Rb / Rb:sqrmagnitude^1.5).
      lock steering to lookdirup(steer_vector, -body:position).
      local ndsma to nd1:orbit:semimajoraxis.
      local s0 to sign(orbit:semimajoraxis - ndsma).
      local steer0 to steer_vector.
      local fin_condition to {
        return s0 <> sign(orbit:semimajoraxis - ndsma).
      }.
      if s0 = sign(vdot(velocity:orbit, steer0)) {
        set fin_condition to { return vdot(steer_vector, steer0) < 0. }.
      }
      until fin_condition() {
        wait 0.
        local dtr to steer_vector:mag * mass / tt.
        set Rb to body:position.
        set steer_vector to velocityat(ship, time:seconds + dtr):orbit - (velocity:orbit + dtr * body:mu * Rb / Rb:sqrmagnitude^1.5).
        set tset to clamp(1.5 * dtr, 0.05, 1).
      }
      lock throttle to 0.
      print "T+" + tm + " Burn finished, remain dv " + round(steer_vector:mag, 2) + "m/s".
      set done to True.
    }
  }
  print "Position error: " + round(positionat(ship, time:seconds):mag, 1) + "m".
  print "Velocity error: " + round((velocityat(ship, time:seconds):orbit - velocity:orbit):mag, 2) + "m/s".
  print "Total dv spent: " + round(vex * ln(m0 / mass), 1) + "m/s".
  print "T+" + tm + " Ap: " + round(apoapsis/1000,2) + " km, Pe: " + round(periapsis/1000,2) + " km".
  print "T+" + tm + " Remaining LF: " + round(stage:liquidfuel, 1).
  unlock all.
  set ship:control:pilotmainthrottle to 0.
  wait 1.
}
