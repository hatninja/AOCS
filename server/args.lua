--args.lua
--Read launch arguments to configure program state. Return true to cancel launch.
return function(...)
	for i,arg in ipairs{...} do
		if arg == "monitor_all" then
			monitor_web=true
			monitor_ao=true
			monitor_proc=true
			monitor_sock=true
		end
		_G[arg]=true
	end
end
