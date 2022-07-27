--Debug Features
local module = {}

module.callbacks = {}
module.callbacks.message = function(self,cb, from,msg)
	if not debug then return end

	--Load new config
	if msg.message == "reconfig" then
		process:resetConfig()
		process:sendMsg(from,"Reloaded Config","debug")
		cb:cancel() return
	end
	--Hot Reload
	if msg.message == "reload" then
		process:loadModules("./server/modules/",process.modules)
		process:sendMsg(from,"Reloaded Modules","debug")
		cb:cancel() return
	end
	--Simulate a full server.
	if msg.message == "fill" then
		server.full = not server.full
		if server.full then
			process:sendMsg(from,"Simulating full server.","debug")
		else
			process:sendMsg(from,"Simulating un-full server.","debug")
		end
		cb:cancel() return
	end
end
return module
