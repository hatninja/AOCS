--compat.lua
--Ensures the program has everything it needs to run properly.
--This includes required libraries and environment compatibility between lua versions.

print ("("..(jit and jit.version or _VERSION)..")")

--Libraries:
socket = safe(require,"socket")
if not socket then
	print "luasocket is required! Make sure it is installed for the lua version above."
end

http = safe(require,"socket.http")
mime = safe(require,"mime")

bit = safe(require,"bit") or require("lib.bitop").bit
sha1 = require("lib.sha1")

--Environment:
if table.unpack then
	unpack = table.unpack
end

math.randomseed(os.time())
math.random();math.random()
