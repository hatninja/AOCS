local process = {}

local MAXMEM = 1024*10 --How much memory to store in KiB.

local IPID     = require("process.IPID")

--[[Initialization]]
function process:init()
	self.uptime = 0
	self.time_last = socket.gettime()
	self.time_boot = self.time_last

	self.count = 0

	self.clients = {}
	self.sessions = {}

	self.modules = {}
	for i,dir in ipairs(data.getDir("./server/modules/")) do
		local name = dir:match("^(.-)%.")
		local chunk = safe(loadfile,"./server/modules/"..name..".lua") or safe(loadfile,"./server/modules/"..name.."/init.lua")
		local module, err = safe(chunk)
		self.modules[name] = module
		if not module then
			print("Error with "..name..": "..err)
		end
	end

	self.areas = {}
	self.replay = {}

	self:resetConfig()
	IPID:load()
end
function process:resetConfig()
	config          = data.readConf("./config/config.txt")
	self.characters = data.readList("./config/characters.txt")
	self.music      = data.readList("./config/music.txt")
end

--[[Updating]]
function process:update()
	local delta = (socket.gettime() - self.time_last)
	self.time_last = self.time_last + delta
	self.uptime = self.uptime + delta

	local usage = collectgarbage("count")
	if usage > MAXMEM then
		print("Current memory usage ("..math.floor(usage).."KiB) is exceeding maximum "..MAXMEM.."KiB!")
		collectgarbage("collect")
		print((usage-collectgarbage("count")).."KiB in memory freed.")
	end

	if not server.socket then --Server is closing.
		for k,v in pairs(self.sessions) do
			self:removeSession(v)
		end
		for k,v in pairs(self.clients) do
			self:removeClient(v)
		end
	end
end
function process:updateSock(sock)
	local client = self:getClient(sock)
	if not client then
		--Server List Observer.
		return
	end

	local session = self:getSession(client)
	if not session then
		session = self:findMirror(client) or self:newSession()
		self:attachClient(session,client)

		self:refresh(client)
		self:catchup(client)
	end
end

--[[Communication]]
function process:send(obj,head,...)
	for i,sock in ipairs(self:getSocks(obj)) do
		local good, err = pcall(protocol.send,protocol, sock,head,...)
		if not good then
			local sender = self:getClient(sock) or sock
			print("Error with sending to "..tostring(sender)..": "..err)
		end
	end
end
function process:getSocks(obj)
	if type(obj) == "userdata" then return {obj} end
	if type(obj) ~= "table" then error("Expected Object!",2) end
	if obj.sock then return {obj.sock} end

	local socks = {}
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

function process:get(sock,head,...)
	if head == "INFO" then self:send(sock,"INFO");return end
	if head == "PING" then self:send(sock,"PONG");return end

	local client = self:getClient(sock)

	log.monitor(monitor_proc,(client and"Client["..client.id.."]: "or"GET: ")..head, each(toprint,...))

	if head == "JOIN" and not client then
		self:send(sock,"JOIN")

		self:newClient(sock)
		self:updateSock(sock)
	end

	if not client then return end
	local session,index = self:getSession(client)

	if head == "CHAR" then
		self:send(sock,"CHAR",...)
		self:send(sock,"TAKEN")
	end
	if head == "MSG" then
		local msg = ...
		self:send(self,"MSG",msg)
	end
	if head == "SFX"  then self:send(self,"SFX",...) end
	if head == "MUSIC"then self:send(self,"MUSIC",...) end

	if head == "SIDE" then self:get(sock,"MSG",{message="/pos "..tostring(...)}) end
	if head == "PING" then
		self:send(sock,"STATUS",
			(self.count), (#self.areas.." areas"),
			("Session ["..session.id.."]("..index..")"), "Free"
		)
	end
end

--[[Session Handling]]
function process:newSession()
	local session = {
		clients  = {},
		area     = 0,
		created  = self.uptime,
		_session = true,
	}
	session.id = firstempty(self.sessions)
	self.sessions[session.id] = setmetatable(session,session_mt)
	log.monitor(monitor_proc,"New Session of ID: "..session.id)
	return session
end
function process:removeSession(ses)
	for i,cli in ipairs(self:getClients(ses)) do
		self:detachClient(ses,cli)
	end
	self.sessions[ses.id] = nil
	log.monitor(monitor_proc,"Removed Session of ID: "..client.id)
end
function process:getSession(cli)
	if type(cli)=="number" then
		return self.session[cli]
	elseif type(cli)=="table" then
		return cli.session, findindex(self:getClients(cli.session or {}),cli)
	end
	error("Expecting a client object or session id!",2)
end
function process:getSessions(obj)
	local t = {}
	if obj.sessions then
		for id,session in pairs(obj.sessions) do
			if session then
				t[#t+1] = session
			end
		end
	end
	return t
end

--[[Client Handling]]
function process:newClient(sock)
	if type(sock) ~= "userdata" then error("Expected socket object!",2) end

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
		_client    = true,
	}
	client.id = firstempty(self.clients)
	self.clients[client.id] = client

	log.monitor(monitor_proc,"New Client of ID: "..client.id)
	return client
end
function process:removeClient(sock,reason)
	local client = self:getClient(sock)
	if not client then return end

	client.sock:close()
	client.sock = nil
	self.clients[client.id] = nil

	local session,index = self:getSession(client)
	if session then
		self:detachClient(session,client)
	end

	log.monitor(monitor_proc,"Removed Client of ID: "..client.id)
end
function process:getClient(sock)
	if type(cli)=="number" then
		return self.clients[sock]
	end
	for id,client in pairs(self.clients) do
		if sock == client.sock then
			return client,id
		end
	end
end
function process:getClients(obj)
	local t = {}
	if obj.sessions then
		for k,v in pairs(obj.sessions) do
			t[#t+1] = sock
		end
	elseif obj.clients then
		for k,client in pairs(obj.clients) do
			t[#t+1] = client
		end
	end
	return t
end
function process:attachClient(ses,cli)
	if cli.session then
		error("Client["..cli.id.."] is still attached to another session!",2)
	end
	ses.clients[#ses.clients+1] = cli
	cli.session = ses
	log.monitor(monitor_proc,"Attached Client["..cli.id.."] to Session["..ses.id.."]")
end
function process:detachClient(ses,cli)
	if cli.session ~= ses then
		error("Client["..cli.id.."] isn't attached to Session["..ses.id.."]!",2)
	end
	table.remove(ses.clients, findindex(ses.clients,cli))
	cli.session = nil
	log.monitor(monitor_proc,"Detached Client["..cli.id.."] from Session["..ses.id.."]")
end

--Search for a session that's eligible for mirroring. Ignore dual clients.
--TODO: Check for client association to avoid mirroring two users.
--TODO: Also check if the session is ghosted.
function process:findMirror(cli)
	for k,session in pairs(self.sessions) do
		for index,client in ipairs(session.clients) do
			if cli.ipid == client.ipid then
			--and not (cli.software == client.software and cli.hdid == client.hdid) then
				log.monitor(monitor_proc,"Found mirror Client["..client.id.."] and Session["..session.id.."]")
				return session, client
			end
		end
	end
end

function process:refresh(user) --Set the current scene
end
function process:catchup(user) --Send history
end



return process
