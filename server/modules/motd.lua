--Send the MOTD.
local module = {}

module.callbacks = {}
module.callbacks.new_session = function(self,cb, ses)
	if config.motd then
		process:sendMsg(ses,config.motd,"MOTD")
		return
	end
	if config.description then
		process:sendMsg(ses,config.description,"Description")
	end
end

return module
