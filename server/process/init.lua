local process = {}

local MAXMEM = 1024*10 --How much memory to store in KiB.

local IPID = require("process.IPID")
local replay = require("process.replay")

--[[Initialization]]
function process:init()
	self.uptime = 0
	self.time_last = socket.gettime()
	self.time_boot = self.time_last

	self.count = 0

	self.sessions = {}
	self.clients = {}

	self.areas = {}
	self:newArea("Lobby","lobby")

	self.modules = {}
	self:loadModules("./server/modules/",self.modules)

	self.replay = {}

	self:resetConfig()
	IPID:load()
end
function process:resetConfig()
	config          = data.readConf("./config/config.txt")
	self.characters = data.readList("./config/characters.txt")
	self.music      = data.readList("./config/music.txt")
end
function process:loadModules(folder, t)
	for i,dir in ipairs(data.getDir(folder)) do
		local name         = dir:match("^(.-)%.") or dir
		local chunk        = safe(loadfile,"./server/modules/"..name..".lua") or safe(loadfile,"./server/modules/"..name.."/init.lua")
		local module, err  = safe(chunk)
		t[name] = module
		if not module then
			print("Error with "..name..": "..err)
		end
	end
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

	if not server.socket then
		self:close()
	end
end
function process:close()
	for k,v in pairs(self.sessions) do
		self:removeSession(v)
	end
	for k,v in pairs(self.clients) do
		self:removeClient(v)
	end
	IPID:save()
end
function process:updateSock(sock)
	local client = self:getClient(sock)
	if not client then
		--Kick all observers if server reached max sockets.
		if server.full then
			sock:close()
		end
		return
	end

	local session = self:getSession(client)
	if not session then
		session = self:findMirror(client) or self:newSession()
		self:attachClient(session,client)

		if not session.area then --New session.
			self:moveto(session, self:getArea(1), true)
			self:event("new_session",session)
		end

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

function process:get(sock,head,data)
	local client = self:getClient(sock)
	if not client then
		if head == "INFO" then
			self:send(sock,"INFO")
			return
		end
		if head == "JOIN" then
			self:send(sock,"JOIN")

			self:newClient(sock)
			self:updateSock(sock)
		end
		return
	end

	local session,index = self:getSession(client)
	local area = self:getArea(session.area)

	log.monitor(monitor_proc and head ~= "STATUS","Client["..client.id.."]: "..head, each(toprint,data))

	if head == "CHAR" then
		self:send(session,"CHAR",data)
		session.char = data

		local taken = {}
		for k,ses in pairs(area.sessions) do
			taken[#taken+1] = ses.char
		end
		self:send(area,"TAKEN",taken)
	end
	if head == "MSG" then
		local c = data.message and data.message:sub(1,1)
		if c ~= "/" and self:event("message",session,data) then
			for k,ses in pairs(area.sessions) do
				local msg = clone(data)
				if self:event("messageto",session,ses,msg) then
					self:send(ses,"MSG",msg)
				end
			end
		end
		if c == "/" or c == "!" then
			local args = split(data.message,"%s+")
			local cmd = args[1]:sub(2,-1)
			table.remove(args,1)

			self:event("command",session,cmd,args,data,c=="!" and area or session)
		end
	end
	if head == "SFX" and self:event("sound",session,data) then
		for k,ses in pairs(area.sessions) do
			local sfx = clone(data)
			if self:event("soundto",session,ses,sfx) then
				self:send(ses,"SFX",sfx)
			end
		end
	end
	if head == "ANI" and self:event("animation",session,data) then
		for k,ses in pairs(area.sessions) do
			local ani = clone(data)
			if self:event("animationto",session,ses,ani) then
				self:send(ses,"ANI",ani)
			end
		end
	end
	if head == "MUSIC" and self:event("music",session,data) then
		area.music = data
		for k,ses in pairs(area.sessions) do
			ses.music = area.music
		end
		self:send(area,"MUSIC",area.music)
	end
	if head == "SIDE" then
		self:get(sock,"MSG",{message="/pos "..tostring(data)})
	end
	if head == "STATUS" then
		self:send(sock,"STATUS",
			(self.count), (#self.areas.." areas"),
			("User ["..session.id.."]("..index..")"), area.cm or "None"
		)
	end
end

--[[Session Handling]]
function process:newSession(area)
	local session = {
		clients  = {},
		replay   = {},
		area     = area,
		created  = self.uptime,
		_session = true,
	}
	session.id = firstempty(self.sessions)
	self.sessions[session.id] = session
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
	if type(cli)~="table" then error("Expecting a client object!",2) end
	return cli.session, findindex(self:getClients(cli.session or {}),cli)
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
	if type(sock)=="number" then
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

--[[Area Management]]
function process:newArea(name,type)
	local area = {
		sessions = {},
		replay   = {},
		name     = name or self:genAreaName("New Room"),
		type     = type,
		created  = self.uptime,
		scene    = "",
		music    = "",
		_area    = true,
	}
	area.id = firstempty(self.areas)
	self.areas[area.id] = area

	log.monitor(monitor_proc,"New Area '"..area.name.."' with ID: "..area.id)
	return client
end
function process:removeArea(area)
	if not area._area then error("Area object required!", 2) end
	for i,session in pairs(area.sessions) do
		self:moveto(session,self:getArea(1), true)
	end
	self.areas[area.id] = nil
end
function process:getArea(id)
	return self.areas[tonumber(id) or 0]
end
function process:genAreaName(name,area)
	name=name:match("^%s*(.-)%s*$")

	local tick = 1
	repeat
		local match = false
		for k,v in pairs(self.areas) do
			if (name == v.name or string.format("%s <%d>",name,tick) == v.name)
			and v ~= area then
				tick  = tick+1
				match = true
				break
			end
		end
	until not match
	if tick > 1 then
		return string.format("%s <%d>",name,tick)
	end
	return name
end
function process:searchArea(name)
	for k,area in pairs(self.areas) do
		if name == area.name then
			return area
		end
	end

	local searchstr = name:match("^%s*(.-)%s*$"):lower():gsub("%W","")
	for k,area in pairs(self.areas) do
		if searchstr == area.name:sub(1,#searchstr):lower():gsub("%W","") then
			return area
		end
	end
end
function process:moveto(session,area,override)
	if not session._session then error("Requiring a session to move!", 2) end
	if not area._area then error("Area object required!", 2) end

	local good, value = self:event("areamove",session,area)
	if override or good then
		local new_area = value or area
		local old_area = session.area
		if old_area then
			table.remove(area.sessions,findindex(area,session))
		end
		session.area = area.id
		table.insert(area.sessions,1,session)

		log.monitor(monitor_proc,"Session["..session.id.."] moved to Area["..area.id.."]")
	end
end

function process:findMirror(cli)
	for k,session in pairs(self.sessions) do
		for index,client in ipairs(session.clients) do
			if cli.ip == client.ip then
			--and not (cli.software == client.software and cli.hdid == client.hdid) then
				log.monitor(monitor_proc,"Found mirror Client["..client.id.."] and Session["..session.id.."]")
				return session, client
			end
		end
	end
end

function process:refresh(user) --Set the current scene
	local ses = self:getSession(user)
	local area = self:getArea(ses.area)
	--self:send(user,"CHAR",ses.char)

	--self:send(area,"SCENE")
	--self:send(area,"MUSIC")
end
function process:catchup(cli) --Send history
end

function process:sendMsg(to,msg,name,char,emote)
	local ooc_name
	if not char and not emote then
		ooc_name = config.short_name
	end
	self:send(to,"MSG",{message=msg,name=name or ooc_name,char=char,emote=emote,server=true})
end

--[[Module Helpers]]
local createCallbackHandler = function()
	return {
		cancel = function(self)
			self.cancelled = true
		end,
		setValue = function(self,value)
			self.value = value
		end,
		getValue = function(self)
			return self.value
		end
	}
end
function process:event(name,...)
	local callbacks = {}
	for key,module in pairs(self.modules) do
		if module.callbacks and module.callbacks[name] then
			callbacks[#callbacks+1] = {key, module.priority and module.priority[name] or 3}
		end
	end

	table.sort(callbacks,function(a,b) return a[2] < b[2] end)

	local cb = createCallbackHandler()
	for i,t in ipairs(callbacks) do
		local module = self.modules[t[1]]
		local value, err = safe(module.callbacks[name],module,cb,...)
		if not value and err then
			print("Event '"..name.."' callback error "..t[1]..": "..err)
		end
		if cb.cancelled then
			break
		end
	end
	return not cb.cancelled, cb:getValue()
end
function process:modulecall(module_name,func_name,...)
	local module = self.modules[module_name]
	if not module then return end
	local func = module[func_name]
	if func then
		return func(module,...)
	end
end

return process
