local process = {}

local MAXMEM = 1024*10 --How much memory to store in KiB.

local IPID = require("process.IPID")


function process:init()
	self.uptime = 0
	self.time_last = socket.gettime()
	self.time_boot = self.time_last
	self.delta = 0

	self.count = 0

	self.clients = {}
	self.sessions = {}

	self.modules = {}

	self.areas = {}
	self.replay = {}

	self.free = false

	self:resetConfig()
end

function process:resetConfig()
	config          = data.readConf("./Config/Config.txt")
	self.characters = data.readList("./Config/Characters.txt")
	self.music      = data.readList("./Config/Music.txt")
end

function process:freememory()
	self.free = true
	for k,client in pairs(self.clients) do
		local session = self:getSession(client)
		if not session then
			sock:close()
		end
	end
	collectgarbage("collect")
end

function process:update()
	local delta = (socket.gettime() - self.time_last)
	self.time_last = self.time_last + delta
	self.uptime = self.uptime + delta

	self.free = false
	local usage = collectgarbage("count")
	if usage > MAXMEM then
		print("Current memory usage ("..math.floor(usage).."KiB) is exceeding maximum "..MAXMEM.."KiB!")
		self:freememory()
		print((usage-collectgarbage("count")).."KiB in memory freed.")
	end

	if not server.socket then
		self:freememory()
		for k,v in pairs(self.sessions) do
			self:removeSession(v)
		end
		for k,v in pairs(self.clients) do
			self:removeClient(v)
		end
	end
end

function process:updateClient(sock)
	local client = self:getClient(sock)
	if not client then
		--Server List Observer.
		return
	end

	local session = self:getSession(client)
	if not session then
		local mses,mcli = self:findMirrorClient(client)
		session = mses or self:newSession()
		self:attachCli(session,client)

		self:refresh(client)
		self:catchup(client)
	end
end

function process:get(sock,head,...)
	if head == "INFO" then protocol:send(sock,"INFO") end
	if head == "PING" then protocol:send(sock,"PONG") end

	if head == "JOIN" then
		protocol:send(sock,"JOIN")
		self:newClient(sock)
		self:updateClient(sock)
		protocol:send(sock,"CHAR")
	end

	local client = self:getClient(sock)
	local session,index = self:getSession(client)

	if not client or not session then return end

	if head == "CHAR" then
		self:send(sock,"CHAR",...)
		self:send(sock,"TAKEN")
	end
	if head == "MSG"  then
		local msg = ...
		msg.append = 0
		msg.shake  = 1
		msg.nowait = 1
		self:send(self,"MSG",msg)
	end
	if head == "SFX"  then self:send(self,"SFX",...) end
	if head == "MUSIC"then self:send(self,"MUSIC",...) end

	if head == "SIDE" then self:get(sock,"MSG",{message="/pos "..tostring(...)}) end
	if head == "PING" then
		self:send(sock,"STATUS",
			(#self.areas.." areas"),
			("Session ["..session.id.."]("..index..")"),
			"Free"
		)
	end
end

function process:newClient(sock)
	local storage = protocol.storage[sock]
	if not storage then error("Socket is unprocessed!",2) end

	local ipid = IPID:get(sock:getsockname())
	local client = {
		sock       = sock,
		ip         = ipid,
		software   = storage.software,
		version    = storage.version,
		user_agent = storage.user_agent,
		hdid       = storage.hdid,
		created    = self.uptime,
	}
	client.id = firstempty(self.clients)
	self.clients[client.id] = client
	log.monitor(monitor_proc,"New Client of ID: "..client.id)
	return client
end
function process:removeClient(sock,reason)
	local id = find(self.clients,sock)
	self.clients[id].sock = nil
	self.clients[id] = nil
	log.monitor(monitor_proc,"Removed Client of ID: "..id)
end
function process:getClient(sock)
	local id = 0
	for k,v in pairs(self.clients) do
		if v.sock == sock then
			id = tonumber(k) or 0
			break
		end
	end
	return self.clients[id]
end

function process:newSession()
	local session = {
		clients = {},
		created = self.uptime,
	}
	session.id = firstempty(self.sessions)
	self.sessions[session.id] = session
	log.monitor(monitor_proc,"New Session of ID: "..session.id)
	return session
end
function process:removeSession(ses)
	for i,cli in ipairs(self.sessions[ses.id].clients) do
		self:detachCli(ses,cli)
	end
	self.sessions[ses.id] = nil
	log.monitor(monitor_proc,"Removed Session of ID: "..client.id)
end
function process:getSession(cli)
	for k,session in pairs(self.sessions) do
		for index,client in ipairs(session.clients) do
			if cli == client or cli == client.id then
				return session, index
			end
		end
	end
end
function process:attachCli(ses,cli)
	table.insert(ses.clients,cli)
	log.monitor(monitor_proc,"Attached Client["..cli.id.."] to Session["..ses.id.."]")
end
function process:detachCli(ses,cli)
	local index = find(ses.clients,cli)
	table.remove(ses.clients,index)
	log.monitor(monitor_proc,"Detached Client["..cli.id.."] from Session["..ses.id.."]")
end

--Search for a session that's eligible for mirroring. Ignore dual clients.
--TODO: Check for client association to avoid mirroring two users. Maybe just make this manual? How to account for ghosts?
function process:findMirrorClient(cli)
	for k,session in pairs(self.sessions) do
		for index,client in ipairs(session.clients) do
			if cli.ipid == client.IPID then
			--and not (cli.software == client.software and cli.hdid == client.hdid) then
				log.monitor(monitor_proc,"Found mirror Client["..client.id.."] and Session["..session.id.."]")
				return session, client
			end
		end
	end
end

--user can be process, area, session, or client.
function process:refresh(user) --Set the current scene
end
function process:catchup(user) --Send history
end

function process:send(obj,head,...)
	for i,sock in ipairs(self:getSocks(obj)) do
		protocol:send(sock,head,...)
	end
end

function process:getSocks(obj)
	if type(obj) == "userdata" then return {obj} end
	if type(obj) ~= "table" then error("Arg: Expected Object!",2) end

	local socks = {obj.sock}
	if obj.sessions then
		for k,v in pairs(obj.sessions) do
			for i,sock in ipairs(self:getSocks(v)) do
				socks[#socks+1] = sock
			end
		end
	elseif obj.clients then
		for k,v in pairs(obj.clients) do
			socks[#socks+1] = v.sock
		end
	end
	return socks
end

function process:closeSock(sock)
	sock:close()
end

return process
