local process = {}

local MAXMEM = 1024 --How much memory to store in KiB.

local IPID = require("process.IPID")


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
	self.serverlist = data.readList("./Config/Servers.txt")
	for i,v in pairs(self.serverlist) do
		self.serverlist[i] = split(v,"%;")
	end
end

function process:lowmemory()

end

function process:update()
	local clock = os.clock()
	local delta = (self.clock - clock)
	self.clock = clock



	self.time = self.time + delta
end

function process:updateClient(sock)

end

function process:get(sock,head,...)
	if head == "INFO" then protocol:send(sock,"INFO") end


	if head == "JOIN" then
		protocol:send(sock,"JOIN")
	end
	if head == "CHAR" then protocol:send(sock,"CHAR",...) end
	if head == "MSG" then protocol:send(sock,"MSG",...) end
	if head == "SFX" then protocol:send(sock,"SFX",...) end
	if head == "MUSIC" then protocol:send(sock,"MUSIC",...) end

	if head == "SIDE" then protocol:send(sock,"MSG",{message="/pos "..tostring(...)}) end

	if head == "PING" then protocol:send(sock,"PONG") end
end

function process:newClient(sock)
	local storage = protcol.storage[sock]
	if not storage then error("Socket is unprocessed!",2) end

	local ipid = IPID:get(sock:getipaddr())

	local client = {
		socket = sock,

		software = storage.software,
		version = storage.version,

		ip = ipid,

		user_agent = storage.user_agent,
		hdid = storage.hdid,
	}
end
function process:closeClient(sock,reason)

end

function process:newSession()
end
function process:closeSession()
end

function process:getClient()
end

return process
