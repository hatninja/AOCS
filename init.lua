#!/usr/bin/env lua
package.path = "./server/?.lua;./server/?/init.lua;" .. package.path

if require("args")(...) then
	return
end

print "Initializing..."

for i,v in ipairs{
	"env", "compat",
	"data","log",
	"web",
	"process",
	"protocol",
	"server"
} do
	_G[v] = require(v)
end

process:init() --Reads config for us.
protocol:init()

server:init()
server:listen(config.ip or "*", tointeger(config.port) or 27016)

local function start()
	repeat
		server:update()
		process:update()
	until not server.socket

	print("Safe shutdown!")
end

local function crash(err)
	server:close()
	if string.find(err,"interrupted!") then --Interrupt signal, such as via Ctrl+C
		print("\rReceived signal to close.")
		start()
		return
	end
	print("An error has resulted in a crash!\n"..err.."\n"..debug.traceback())
end

xpcall(start,crash)
