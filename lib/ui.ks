@lazyglobal off.

//set terminal:width to 157.

local gui is gui(300).
set gui:x to -400.

local output is gui:addvlayout.
local dataOutput is output:addvlayout.
local commandInput is gui:addtextfield("").
local commandButton is gui:addbutton("SEND").
set commandButton:onclick to {
	ship:connection:sendmessage(commandInput:text).
}.

set gui:skin:label:margin:v to 1.
set gui:skin:label:padding:v to 0.
set gui:skin:label:font to "Lucida Console".

set gui:skin:flatlayout:padding:v to 2.

local displayList is Lexicon("data", List(dataOutput, Lexicon())).

function addDisplay {
	parameter boxName is displayList:length.

	set displayList[boxName] to List(output:addvlayout, Lexicon()).
	return boxName.
}

function removeDisplay {
	parameter boxName.

	if displayList:haskey(boxName) {
		displayList[boxName][0]:dispose.
		displayList:remove(boxName).
	}
}

function addDisplayData {
	parameter tag,
			  data is { return "". },
			  box is "data".
	
	local thisbox to displayList[box].

	if thisbox[1]:haskey(tag) set thisbox[1][tag][1] to data.
	else set thisbox[1][tag] to List(thisbox[0]:addlabel(), data).

}

function setDisplayLabel {
	parameter tag,
	          text,
			  box is "data".

	local thisbox to displayList[box].
	if thisbox[1]:haskey(tag) {
		set thisbox[1][tag][0]:text to text:tostring.
		set thisbox[1][tag][1] to "".
	}
	else {
		set thisbox[1][tag] to List(thisbox[0]:addlabel(),"").
		set thisbox[1][tag][0]:text to text:tostring.
	}
}

function setDisplayData {
	parameter tag,
			  text,
			  box is "data".
	
	local thisbox to displayList[box].
	if thisbox[1]:haskey(tag) {
		set thisbox[1][tag][0]:text to tag:padright(15) + text.
		set thisbox[1][tag][1] to "".
	} else {
		set thisbox[1][tag] to List(thisbox[0]:addlabel(),"").
		set thisbox[1][tag][0]:text to tag:padright(15) + text.
	}
}


// Lexicon
// label
// tag
// data

function boxUpdate {
	parameter box.

	local thisbox is displayList[box][1].

	for tag in thisbox:keys {
		local row is thisbox[tag].
		if row[1] <> "" set row[0]:text to tag:padright(15) + row[1]().
	}
}
function displayUpdate {
	for key in displayList:keys boxUpdate(key).
}

function printData {
	parameter label,
			  row,
			  data is { return "". }.
	print (label:padright(15) + data):padright(50) at (0, row).
}
function vecToString {
	parameter v.
	return "x"+(" "+round(v:x,2)):padleft(10) +
		  " y"+(" "+round(v:y,2)):padleft(10) +
		  " z"+(" "+round(v:z,2)):padleft(10).
}

function startUI {
	gui:show.
}


