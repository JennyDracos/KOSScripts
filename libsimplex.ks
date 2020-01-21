@lazyglobal off.

function vertexToString {
	parameter _n, _v.

	set _n to _n:padright(15).

	for _d in _v {
		set _s to _s + round(_v[_d], 5):padright(9).
	}

	return _s.
}

function globalSection {
	parameter zero, step, fitnessFunction, tolerance is 0.01, maxSteps is 10.

	local testQueue is Queue().
	local now is zero + step.

	local lastGuess is fitnessFunction(zero).
	local zeroSlope is (fitnessFunction(zero + 1) < lastGuess).
	local guessNow is fitnessFunction(now).

	local gss is AddDisplay().
	local guessList is List().
	local _gsline is 0.

	print "Global Golden Section from " + zero + " to " + (zero + step * maxSteps).

	if (zeroSlope and guessNow > lastGuess) {
		testQueue:push(List(zero, zero + step)).
	}
	until now > (zero + maxSteps * step) {
		local guessNext is fitnessFunction(now + step).
		if (guessNext > guessNow) and (lastGuess > guessNow) {
			testQueue:push(List(now - step, now + step)).
		}
		set now to now + step.
		set lastGuess to guessNow.
		set guessNow to guessNext.
	}

	for guess in testQueue {
		local guessResult is goldenSection(guess[0], guess[1], 
												fitnessFunction, 
												tolerance).
		local guessFitness is fitnessFunction(guessResult).
		set _gsline to _gsline + 1.
		print guessResult + ": " + guessFitness.
		guessList:add(List(guessResult, fitnessFunction(guessResult))).
	}

	local bestGuess is 1e10.
	local bestFitness is 1e10.
	until guessList:empty {
		if guessList[0][1] < bestFitness {
			set bestGuess to guessList[0][0].
			set bestFitness to guessList[0][1].
		}
		guessList:remove(0).
	}
	RemoveDisplay(gss).

	if bestGuess > 1e9 {
		return zero.
	}
	return bestGuess.
}

local _gC is -4.
local _gD is "".

function gssOutput {
	parameter _n,
			  _x,
			  _y.

	SetDisplayLabel("_"+(_gC+_n), round(_x,2)+":"+_y, _gD).
}

function goldenSection {
	parameter firstGuess,
		lastGuess,
		fitnessFunction,
		tolerance is 0.01.

	if _gC < 0 { set _gD to AddDisplay(). }
	set _gC to _gC + 4.
	gssOutput(1,0,0).
	gssOutput(2,0,0).
	gssOutput(3,0,0).
	gssOutput(4,0,0).

	local x_1 is firstGuess.
	//printData(round(x_1,2)+":",25,"").
	gssOutput(1, x_1, "").
	local y_1 is fitnessFunction(x_1).
	//printData(round(x_1,2)+":",25, y_1).
	gssOutput(1, x_1, y_1).
	local x_4 is lastGuess.
	//printData(round(x_4,2)+":",28, "").
	gssOutput(4, x_4, "").
	local y_4 is fitnessFunction(x_4).
	//printData(round(x_4,2)+":",28, y_4).
	gssOutput(4, x_4, y_4).

	local dx is x_4 - x_1.
	if dx < tolerance {
		if y_1 < y_4 { return x_1. }
		else { return x_2. }
	}
	
	local phi is 1.618033988.
	local x_2 is x_4 - (x_4 - x_1) / phi.
	//printData(round(x_2,2)+":",26,"").
	gssOutput(2, x_2, "").
	local y_2 is fitnessFunction(x_2).
	//printData(round(x_2,2)+":",26, y_2).
	gssOutput(2, x_2, y_2).
	local x_3 is x_1 + (x_4 - x_1) / phi.
	//printData(round(x_3,2)+":",27,"").
	gssOutput(3, x_3, "").
	local y_3 is fitnessFunction(x_3).
	//printData(round(x_3,2)+":",27, y_3).
	gssOutput(3, x_3, y_3).
	until abs(x_3 - x_2) < tolerance {
		if (y_2 < y_3) {
			set x_4 to x_3.
			set y_4 to y_3.
			set x_3 to x_2.
			set y_3 to y_2.
			set x_2 to x_4 - (x_4 - x_1) / phi.
			gssOutput(1, x_1, y_1).
			gssOutput(2, x_2, "").
			gssOutput(3, x_3, y_3).
			gssOutput(4, x_4, y_4).
			set y_2 to fitnessFunction(x_2).
			gssOutput(2, x_2, y_2).
		} else {
			set x_1 to x_2.
			set y_1 to y_2.
			set x_2 to x_3.
			set y_2 to y_3.
			set x_3 to x_1 + (x_4 - x_1) / phi.
			gssOutput(1, x_1, y_1).
			gssOutput(2, x_2, y_2).
			gssOutput(3, x_3, "").
			gssOutput(4, x_4, y_4).
			set y_3 to fitnessFunction(x_3).
			gssOutput(3, x_3, y_3).
		}
	}

	set _gC to _gc - 4.
	if _gC < 0 RemoveDisplay(_gD).

	if y_2 < y_3 {
		return x_2.
	} else { 
		return x_3.
	}
}


function patternSearch {
	parameter initialGuess,
		  fitnessFunction,
		  span is 2^16,
		  tolerance is 0.01.

	local dim is initialGuess:length + 1.
	initialGuess:insert(0, 0).
	set initialGuess[0] to fitnessFunction(initialGuess).

	until span < tolerance {
		local guessSet is List(initialGuess).

		printData("Span:", 25, span).
		printData("Null:", 26, guessSet[0][0]).
	
		for iter in range(1, dim) {
			local n is (iter - 1) * 2.
			local spanUp is initialGuess:copy.
			set spanUp[iter] to spanUp[iter] + span.
			set spanUp[0] to fitnessFunction(spanUp).
			guessSet:add(spanUp).
			printData(" ["+n+"]:",27 + n, spanUp[0]).
			local spanDown is initialGuess:copy.
			set spanDown[iter] to spanDown[iter] - span.
			set spanDown[0] to fitnessFunction(spanDown).
			guessSet:add(spanDown).
			printData(" ["+(n+1)+"]:",28 + n, spanDown[0]).
		}

		local bestGuess is 0.
		for iter in range(0, guessSet:length) {
			if guessSet[iter][0] < guessSet[bestGuess][0] {
				set bestGuess to iter.

			}
		}

		if bestGuess > 0 {
			set initialGuess to guessSet[bestGuess].
		} else {
			set span to span / 2.
		}
	}

	return initialGuess.
}

function globalSimplex {
	parameter guessList,
			  fitnessFunction,
			  guessModifier,
			  tolerance is 0.1,
			  alpha is 1,
			  gamma is 2,
			  rho is 0.5,
			  sigma is 0.5.
	
	local answerList is List().
	for node in guessList {
		local answer is simplexSolver(node, fitnessFunction, guessModifier, 
									  tolerance, alpha, gamma, rho, sigma).
		answerList:add(answer).
	}

	print "Selecting finalist!".
	local bestGuess is List(1e20).
	for node in answerList {
		print node.
		if node[0] < bestGuess[0] set bestGuess to node.
	}

	return bestGuess.
}

function simplexSolver {
	parameter zeroGuess,
		  fitnessFunction,
		  guessModifier,
		  tolerance is 0.1,
		  alpha is 1,
		  gamma is 2,
		  rho is 0.5,
		  sigma is 0.5.

	function addTupleTimes {
		parameter tupleTo,
			  tupleFrom,
			  times is 1.

		local tupleReturn is List().
		for n in range(0, tupleFrom:length) {
			tupleReturn:add(tupleTo[n] + times * tupleFrom[n]).
		}
		return tupleReturn.
	}
	function subtractTuple {
		parameter tupleSubtractand,
			  tupleSubtractor.
		
		local tupleReturn is List().
		for n in range(0, tupleSubtractand:length) { 
			tupleReturn:add(tupleSubtractand[n] - tupleSubtractor[n]).
		}
		return tupleReturn.
	}
	function zero {
		parameter tupleZero.

		for n in range(0, tupleZero:length) { set tupleZero[n] to 0. }
	}

	local dimensions is zeroGuess:length.

	zeroGuess:insert(0,0).	
	local simplex is List(zeroGuess).
	if guessModifier:istype("List") {
		for n in range(0, dimensions) {
			local newGuess is zeroGuess:copy.
			set newGuess[n+1] to newGuess[n+1] + guessModifier[n].
			simplex:add(newGuess).
		}
	} else {
		for n in range(0, dimensions) {
			local newGuess is zeroGuess:copy.
			set newGuess[n+1] to newGuess[n+1] + guessModifier.
			simplex:add(newGuess).
		}
	}

	local termination is false.

	local centroid is simplex[0]:copy().
	zero(centroid).
	simplex:insert(0, centroid).
	local reflection is centroid:copy().
	local contraction is centroid:copy().
	local expansion is centroid:copy().

	Terminal:Input:Clear().

	local simplexOutput is AddDisplay("Sim").
	
	until termination {
		// Simplex fitness
		for vertex in simplex {
			if vertex[0] = 0 { set vertex[0] to fitnessFunction(vertex). }
		}
		// Order
		function swap {
			parameter a, b.
			local temp is simplex[a].
			set simplex[a] to simplex[b].
			set simplex[b] to temp.
		}
		local newSimplex is List(simplex[0]).
		simplex:remove(0).
		until simplex:length = 0 {
			local n is 1.
			until n = newSimplex:length or simplex[0][0] < newSimplex[n][0] {
				set n to n + 1.
			}
			newSimplex:insert(n, simplex[0]).
			simplex:remove(0).
		}
		set simplex to newSimplex.
		for n in range(0, dimensions + 1) {
			SetDisplayData("Simplex["+(n+1)+"]:",round(simplex[n+1][0],2),"Sim").
		}
		// Centroid
		zero(centroid).
		for n in range(0, dimensions) {
			set centroid to addTupleTimes(centroid, simplex[n+1], 1/(dimensions)).
		}
		SetDisplayData("Centroid:",round(centroid[0],2),"Sim").
		// Reflection
		zero(reflection).
		set reflection to addTupleTimes(centroid, 
						subtractTuple(centroid, simplex[dimensions + 1]),
						alpha).
		set reflection[0] to fitnessFunction(reflection).
		SetDisplayData("Reflection: ", round(reflection[0],2),"Sim").
		if simplex[1][0] < reflection[0] and reflection[0] < simplex[dimensions][0] {
			set simplex[dimensions + 1] to reflection:copy().
		}
		// Expansion
		else if reflection[0] < simplex[1][0] {
			set expansion to addTupleTimes(centroid,
						       subtractTuple(reflection, centroid),
						       gamma).
			set expansion[0] to fitnessFunction(expansion).
			SetDisplayData("Expansion:",round(expansion[0],2),"Sim").
			if expansion[0] < reflection[0] {
				set simplex[dimensions + 1] to expansion:copy().
			} else {
				set simplex[dimensions + 1] to reflection:copy().
			}
		}
		// Contraction
		else {
			set contraction to addTupleTimes(centroid,
							 subtractTuple(simplex[dimensions + 1], centroid),
							 rho).
			set contraction[0] to fitnessFunction(contraction).
			SetDisplayData("Contraction:",round(contraction[0],2),"Sim").
			if contraction[0] < simplex[dimensions + 1][0] {
				set simplex[dimensions + 1] to contraction:copy().
			}
			// Shrink
			else {
				print "Shrinking.".
				for dim in range(2, dimensions + 2) {
					set simplex[dim] to addTupleTimes(simplex[1],
									  subtractTuple(simplex[dim], simplex[1]),
									  sigma).
					set simplex[dim][0] to fitnessFunction(simplex[dim]).
					SetDisplayData("Simplex["+(dim)+"]:",round(simplex[dim][0],2),"Sim").
//					print "Simplex ["+dim+"]: " + simplex[dim]:join(", ").
				}
			}
		}
	
		// Check for termination
		set termination to true.
		for n in range(1, dimensions) {
			if abs(simplex[1][n] - simplex[dimensions+1][n]) > tolerance {
				set termination to false.
			}
		}

		// terminal:input:getchar().
//		print "".
		BoxUpdate(simplexOutput).
	}

	RemoveDisplay(simplexOutput).

	return simplex[1].
}
