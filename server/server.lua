local server = {}

local RATE      = 1/9
local MAXLISTEN = 128 --Maximum connected clients.
local MAXSEND   = 2048 --Bytes to send per-update.
local MAXREAD   = 2048 --Bytes to read per-update.

function server:init()
	self.sockets = {}
	self.closed = {}
	self.buf = {}
	self.got = {}
end

function server:listen(ip, port)
	local sock = socket.tcp()
	sock:settimeout(0)
	socket._SETSIZE = MAXLISTEN

	assert(sock:bind(ip,port))
	assert(sock:listen(MAXLISTEN))

	self.socket = sock
end
function server:close()
	if not self.socket then return end
	self.socket:close()
	self.socket=nil
end

function server:send(sock, msg)
	self.buf[sock] = self.buf[sock] .. msg
end

function server:update()
	--Select sockets which are open to receiving/sending data.
	local recv_t,send_t,err = socket.select(self.sockets,self.sockets, RATE)

	--Read received client data.
	for i,sock in ipairs(recv_t) do
		local dat,err,part = sock:receive(MAXREAD)
		self.got[sock]     = self.got[sock] .. (dat or part)
		self.closed[sock]  = (err == "closed")
	end

	--Update clients.
	for i,sock in ipairs(self.sockets) do
		process:updateClient(sock)
	end

	--Send buffered data to clients.
	for i,sock in ipairs(send_t) do
		local dat = self.buf[sock]
		if #dat > 0 then
			local bytes,err   = sock:send(dat,1,MAXSEND)
			self.buf[sock]    = string.sub(dat,bytes+1,-1)
			self.closed[sock] = (err == "closed")
		end
	end

	--Remove closed clients.
	for sock in pairs(self.closed) do
		table.remove(self.sockets, find(self.sockets,sock) )

		self.closed[sock]  = nil
		self.sockets[sock] = nil
		self.buf[sock]     = nil
		self.got[sock]     = nil

		protocol:closeClient(sock)
	end

	--Accept new connections.
	if self.socket and #self.sockets < MAXLISTEN then
		repeat
			local sock,err = self.socket:accept()
			if sock then
				sock:settimeout(0)
				table.insert(self.sockets,sock)

				self.sockets[sock] = true
				self.buf[sock]     = ""
				self.got[sock]     = ""

				protocol:acceptClient(sock)
			end
		until not connection
	end
end

return server
