--Make message behaviour consistent.
local module = {}

module.callbacks = {}
module.callbacks.message = function(self,cb, from,msg)
	if not msg.char then return end
	if not bool(msg.message) then return end
	local message = msg.message

	--Blankpost consistency.
	if not message:find("%S") then
		msg.message = nil
	end
	--Empty emote consistency.
	if not msg.emote:find("%S") then
		msg.emote = nil
	end

	--Detect and mark OOC messages.
	if message:sub(1,2) == "((" then
		msg.message = "\\(\\("..message:sub(3,-1)
		msg.color = config.grey
		msg.ooc = true
	end
	if message:sub(-2,-1) == "))" then
		msg.color = config.grey
		msg.ooc = true
	end

	--Detect whispers
	if message:sub(1,1) == "[" and message:sub(-1,-1) == "]" then
		msg.whisper = true
	end


	--Fix accidental redification.
	message = message:gsub("~ ","\\~ ")
	--Add newline escape.
	message = message:gsub("\\n","\n")
end

return module
