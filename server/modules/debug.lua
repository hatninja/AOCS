--Debug Features
local module = {}

module.callbacks = {}
module.callbacks.message = function(self,cb, from,msg)
	if not debugging then return end

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

	if msg.message and msg.message:sub(1,3) == "lua" then
		local chunk,err = load(msg.message:sub(4,-1))
		if chunk then
			process:sendMsg(from,"Executing lua...","debug")
			local value,err = safe(chunk)
			if err then
				process:sendMsg(from,err,"debug")
			end
			if value then
				process:sendMsg(from,value,"debug")
			end
		end
		if err then
			process:sendMsg(from,err,"debug")
		end
	end
end
return module
