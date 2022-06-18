local process = {}

local MAXMEM = 1024 --How much memory to store in KiB.

function process:init()
	self.time = 0
	self.clock = os.clock()
	self.launched = os.time()

	self.count = 0

	self.clients = {}
	self.sessions = {}

	self.modules = {}

	self.areas = {}
	self.replay = {}

	self:resetConfig()
end

function process:resetConfig()
	config          = data.readConf("./Config/Config.txt")
	self.characters = data.readList("./Config/Characters.txt")
	self.music      = data.readList("./Config/Music.txt")
end

function process:update()
	local delta = (self.clock - os.clock())
	self.clock = os.clock()

	self.time = self.time + delta
end

function process:updateClient(sock)

end

function process:get(sock,head,...)
	if head == "INFO" then protocol:send(sock,"INFO") end
	if head == "JOIN" then protocol:send(sock,"JOIN") end
	if head == "PING" then protocol:send(sock,"PONG") end
	if head == "SIDE" then protocol:send(sock,"SIDE",...) end
	if head == "CHAR" then protocol:send(sock,"CHAR",...) end
	if head == "MSG" then protocol:send(sock,"MSG",...) end
	if head == "SFX" then protocol:send(sock,"SFX",...) end
	if head == "MUS" then protocol:send(sock,"MUS",...) end
	if head == "ANIM" then protocol:send(sock,"ANIM",...) end
end

function process:newClient()
end

function process:closeClient()
end

function process:newSession()
end

function process:closeSession()
end

--Low Memory callback
function process:consolidate()

end

--
function process:send(obj)

end

return process
