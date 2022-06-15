local process = {}

local MAXMEM = 1024 --How much memory to store in KiB.

function process:init()
	self.time = 0
	self.clock = os.clock()
	self.launched = os.time()

	self.clients = {}
	self.sessions = {}

	self.modules = {}

	self.characters = data.readList("./Config/Characters.txt")
	self.music = data.readList("./Config/Music.txt")

	self.areas = {}
	self.replay = {}


end

function process:update()
	local delta = (self.clock - os.clock())
	self.clock = os.clock()

	self.time = self.time + delta

end

function process:updateClient()

end

function process:get()

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
