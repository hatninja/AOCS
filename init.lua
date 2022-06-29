#!/usr/bin/env lua
package.path = "./server/?.lua;./server/?/init.lua;" .. package.path

if require("args")(...) then
	return
end

local toload = {
	"env", "compat",
	"data","log",
	"web", "protocol",
	"process",
	"server"
}
for i,name in ipairs(toload) do
	_G[name] = require(name)
end

print "Initializing..."

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

print("Started!")
xpcall(start,crash)
