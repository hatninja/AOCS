--args.lua
--Read launch arguments to configure program state. Return true to cancel launch.
return function(...)
	for i,arg in ipairs{...} do
		if arg == "?" or arg == "help" then
			print([[AOCS Launch Options:
debugging    - Enable development tools.
monitor_web  - View data received from websockets.
monitor_ao   - View AO2 protocol data.
monitor_proc - Track process actions.
monitor_sock - Track connected sockets.]])
			return true
		end
		if arg == "debugging"
		or arg == "monitor_web"
		or arg == "monitor_ao"
		or arg == "monitor_proc"
		or arg == "monitor_sock" then
			_G[arg]=true
		end
	end
end
