local server = {}

local RATE      = 1/9
local MAXLISTEN = 128 --Maximum connected clients.
local MAXSEND   = 2048 --Bytes to send per-update.
local MAXREAD   = 2048 --Bytes to read per-update.

function server.init(self)
	self.sockets = {}
	self.closed = {}
	self.buf = {}
	self.got = {}
end

function server.listen(self, ip, port)
	local sock = socket.tcp()
	sock:settimeout(0)
	socket._SETSIZE = MAXLISTEN

	assert(sock:bind(ip,port))
	assert(sock:listen(MAXLISTEN))

	self.socket = sock
end
function server.close(self)
	if not self.socket then return end
	self.socket:close()
	self.socket=nil
end

function server.send(self, sock, msg)
	self.buf[sock] = self.buf[sock] .. msg
end

function server.update(self)
	--Select sockets which are open to receiving/sending data.
	local recv_t,send_t,err = socket.select(self.sockets,self.sockets, RATE)

	--Read received client data.
	for i,sock in ipairs(recv_t) do
		local dat,err,part = sock:receive(MAXREAD)
		self.got[sock] = self.got[sock] .. (dat or part)
		if err == "closed" then
			self.closed[sock] = true
		end
	end

	--Update clients.
	for i,sock in ipairs(self.sockets) do
		protocol:updateClient(sock)
	end
	for i,sock in ipairs(self.sockets) do
		process:updateClient(sock)
	end

	--Send buffered data to clients.
	for i,sock in ipairs(send_t) do
		local dat = self.buf[sock]
		if #dat > 0 then
			local bytes,err = sock:send(dat,1,MAXSEND)
			self.buf[sock] = string.sub(dat,bytes+1,-1)
			if err == "closed" then
				self.closed[sock] = true
			end
		end
	end

	--Remove closed clients.
	for sock in pairs(self.closed) do
		for i,v in ipairs(self.sockets) do
			if v == sock then
				table.remove(self.sockets,i)
				break
			end
		end

		self.closed[sock] = nil
		self.sockets[sock] = nil
		self.buf[sock] = nil
		self.got[sock] = nil

		protocol:closeClient(sock)
	end

	--Accept new connections.
	if self.socket and #self.sockets < MAXLISTEN then
		repeat
			local sock,err = self.socket:accept()
			if sock then
				table.insert(self.sockets,sock)

				sock:settimeout(0)
				self.sockets[sock] = sock
				self.buf[sock] = ""
				self.got[sock] = ""

				protocol:acceptClient(sock)
			end
		until not connection
	end
end

return server
