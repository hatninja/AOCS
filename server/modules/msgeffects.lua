--Create effects automatically based on message contents.
local module = {}

module.callbacks = {}
module.callbacks.messageto = function(self,cb, from,to,msg)
	if not msg.char then return end
	if not bool(msg.message) then return end
	local message = msg.message

	--[[Guilty & Not Guilty overlay]]
	local g = message:gsub("%s",""):lower():find("notguilty")
	local ng = message:gsub("%s",""):lower():find("guilty")
	if g then
		self:send(recv,"ANI",{name="guilty",delay=g})
	elseif ng then
		self:send(recv,"ANI",{name="notguilty",delay=ng})
	end
end

module.callbacks.message = function(self,cb, from,msg)
	if not msg.char then return end
	if not bool(msg.message) then return end
	local message = msg.message

	local cc = message:sub(1,2)

	--Shakify entire message.
	if cc == "!~" then
		message = message:sub(3,-1):gsub(".","\\s%1")
	end
	--Quick rp-status message.
	if cc == "!%" or cc == "%%" then
		message = message:sub(3,-1):gsub("[%[%]%(%)%{%}]","\\%1")
		message = "~~}}}"..message
		msg.color = bool(msg.color) or config.yellow
	end
	--Quick typewriter message.
	if cc == "!$" or cc == "$$" then
		--msg.char = "Typewriter"
		message = "~~"..message:sub(3,-1)
		msg.color = bool(msg.color) or config.green
	end
	--Fast blank emote.
	if cc == "!-" then
		message = message:sub(3,-1)
		msg.emote = nil
	end
	--Fast off-screen. (Preserve last message.)
	if cc == "!_" or cc == "__" then
		message = message:sub(3,-1)
		msg.emote = nil
		msg.preserve = 1
	end
	--Fast append.
	if cc == "!+" or cc == "++" then
		message = message:sub(3,-1)
		msg.append = 1
	end
	--Fast nointerrupt
	if cc == "!>" then
		message = message:sub(3,-1)
		msg.nowait = 1
	end
	--Convert message to plain text by escaping all characters.
	if cc == "!`" then
		message = message:sub(3,-1):gsub("[%`%~%!%@%#%$%%%^%&%*%(%)%-%_%+%=%[%]%{%}%\\%|%;%:%'%\"%,%.%<%>%/%?]","\\%1")
	end

	msg.message=message
	print(message,toprint(msg))
end

return module
