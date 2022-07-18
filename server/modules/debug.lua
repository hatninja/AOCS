--Debug Features
local module = {}

module.callbacks = {}
module.callbacks.message = function(self,cb, from,msg)
	if not debug then return end

	--Let IC messages send to clear the draft.
	if not msg.char then
		cb:cancel()
	end

	--Hot Reload
	if msg.message == "!reload" then
		process:loadModules("./server/modules/",process.modules)
		process:sendOOC(from,"Reloaded Modules","debug")
		return
	end
	--Simulate a full server.
	if msg.message == "!fill" then
		server.full = not server.full
		if server.full then
			process:sendOOC(from,"Simulating full server.","debug")
		else
			process:sendOOC(from,"Simulating un-full server.","debug")
		end
		return
	end
end
return module
