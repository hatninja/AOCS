#!/usr/bin/env lua
package.path = "./server/?.lua;./server/?/init.lua;" .. package.path

if require("args")(...) then
	return
end

print "Initializing..."

for i,v in ipairs{
	"env","compat",
	"data","log",
	"server",
	"web","protocol",
	"process",
} do
	_G[v] = require(v)
end

config = data.readConf("./Config/Config.txt")

process:init()
protocol:init()

server:init()
server:listen(config.ip or "*",tonumber(config.port) or 27016)
xpcall(
	function()
		server:start()
		print("Server now closed.")
	end,
	function(err)
		if string.find(err,"interrupted!") then
			print("\rReceived signal to close.")
			server:close()
			server:start()
			print("Server shutdown safely!")
		else
			print("An error has resulted in a crash!\n"..err.."\n"..simpletraceback())
		end
	end
)
