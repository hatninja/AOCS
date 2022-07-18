--Debug Features
local module = {}

module.callbacks = {}
module.callbacks.message = function(self,cb, from,msg)
	if not debug then return end
	--Hot Reload
	if msg.message == "reload" then
		process:loadModules("./server/modules/",process.modules)
		process:sendOOC(from,"Reloaded Modules","debug")
		if not msg.char then
			cb:cancel()
		end
		return
	end
end

return module
