--log.lua
--Logging tools.
local log = {}

function log.monitor(expr,...)
	if expr then
		print(...)
	end
end

return log
