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

	self.full = false
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
	self.socket:close()
	self.socket=nil
end

function server:update()
	--Select sockets which are open to receiving/sending data.
	local recv_t,send_t,err = socket.select(self.sockets,self.sockets, RATE)

	--Read received client data.
	for i,sock in ipairs(recv_t) do
		local data,err,part = sock:receive(MAXREAD)
		self.got[sock]      = self.got[sock] .. (data or part)
		self.closed[sock]   = (err=="closed") or nil
	end

	--Update clients.
	for i,sock in ipairs(self.sockets) do
		protocol:updateSock(sock)
	end
	for i,sock in ipairs(self.sockets) do
		process:updateSock(sock)
	end

	--Send buffered data to clients.
	for i,sock in ipairs(send_t) do
		local dat = self.buf[sock]
		if #dat > 0 then
			local sent_bytes,err = sock:send(dat,1,MAXSEND)
			self.buf[sock]       = string.sub(dat,sent_bytes+1,-1)
			self.closed[sock]    = (err=="closed") or nil
		end
	end

	--Remove closed clients.
	for sock in pairs(self.closed) do
		table.remove(self.sockets, findindex(self.sockets,sock) )

		self.closed[sock]  = nil
		self.sockets[sock] = nil
		self.buf[sock]     = nil
		self.got[sock]     = nil

		protocol:removeSock(sock)
		process:removeClient(sock)

		self.full = false
	end

	--Accept new connections.
	if self.socket and not self.full then
		repeat
			local sock,err = self.socket:accept()
			if sock then
				sock:settimeout(0)
				table.insert(self.sockets,sock)

				self.sockets[sock] = true
				self.buf[sock]     = ""
				self.got[sock]     = ""

				protocol:acceptSock(sock)
			end
		until not sock
		self.full = #self.sockets >= MAXLISTEN
	end
end

return server
