@lazyglobal off.

global commsHandler is {}.

on commsHandler {

	when not ship:messages:empty then {
		local message to ship:messages:pop().
		for processor in ship:modulesnamed("kosprocessor") {
			processor:connection:sendmessage(message:content).
		}
		return true.
	}

	when not core:messages:empty then {
		local message is core:messages:pop().
		local content is message:content.

		print "Message recieved: " + content.
		commsHandler(content).

		return true.
	}

}
