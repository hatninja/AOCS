--webAO helper functions.
local web = {}

local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

function web.generateResponse(req)
	if req == "" or req:sub(1,3) ~= "GET" then return end

	local key = string.match(req,"Sec%-WebSocket%-Key: (.-)\r\n")
	if not key then return end

	local hash = sha1.binary(key..GUID) --Should be 20 bytes.
	local b64e = mime.b64(hash)

	--Optional information.
	local user_agent = string.match(req,"User-Agent: (.-)\r\n")

	return "HTTP/1.1 101 Switching Protocols\r\n"
		 .."Upgrade: websocket\r\n"
		 .."Connection: Upgrade\r\n"
		 .."Sec-WebSocket-Accept: "..b64e
		 .."\r\n\r\n", user_agent
end

--TODO: test
--print(web.generateResponse("GET Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=="))
--print("Expected: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")

local getBytes = function(str)
	local t = {}
	for i=#str,1,-1 do
		t[i] = string.byte(str:sub(i,i))
	end
	return unpack(t)
end

local bit = bit

function web.decode(dat)
	if #dat < 4 then return nil end

	local p = 0

	local byteA,byteB = getBytes(dat:sub(p+1,p+2))

	local FIN = bit.band(byteA,0x80) ~= 0
	local OPCODE = bit.band(byteA,0x0F)
	local MASKED = bit.band(byteB,0x80) ~= 0
	local LENGTH = bit.band(byteB,0x7F)
	p = p + 2
	if LENGTH == 126 then
		local a,b = getBytes(dat:sub(p+1,p+2))
		LENGTH = bit.bor(bit.lshift(a,8),b)
		p = p + 2

	elseif LENGTH == 127 then
		local a,b,c,d,e,f,g,h = getBytes(dat:sub(p+1,p+8))
		LENGTH = bit.bor(bit.lshift(e,24),bit.lshift(f,16),bit.lshift(g,8),h) --Lua doesn't use 64-bit integers
		p = p + 8
	end

	local MASKKEY
	if MASKED then
		local a,b,c,d = getBytes(dat:sub(p+1,p+4))
		MASKKEY = {a,b,c,d}
		p = p + 4
	end

	--A mis-match is bad news!
	if p+LENGTH ~= #dat then return nil end

	local data
	if LENGTH ~= 0 then
		local PAYLOAD = dat:sub(p+1,p+LENGTH)

		data = ""
		if MASKED then
			for i=1,#PAYLOAD do
				local j = (i-1) % 4 + 1
				local byte = string.byte(PAYLOAD:sub(i,i))
				if byte then
					data = data .. string.char(bit.bxor(byte,MASKKEY[j]))
				end
			end
		else
			data = PAYLOAD
		end
	end
	return data,OPCODE,MASKED,FIN,p+LENGTH
end

function web.encode(dat,opcode,masked,fin)
	local encoded = ""

	local OPCODE = opcode or 1
	local byteA = OPCODE
	if fin then byteA = bit.bor(byteA,0x80) end
	encoded = encoded .. string.char(byteA)

	local byteB = 0
	local bytes = {}
	if masked then byteB = bit.bor(byteB,0x80) end

	--Convert length into string data
	if #dat < 126 then
		byteB = bit.bor(byteB,#dat)
	elseif #dat < 0xFFFF then
		byteB = bit.bor(byteB,126)
		table.insert(bytes,bit.rshift(#dat,8))
		table.insert(bytes,bit.band(#dat,0xFF))
	else
		byteB = bit.bor(byteB,127)
		table.insert(bytes,bit.band(bit.rshift(#dat,24),0xFF))
		table.insert(bytes,bit.band(bit.rshift(#dat,16),0xFF))
		table.insert(bytes,bit.band(bit.rshift(#dat,8),0xFF))
		table.insert(bytes,bit.band(#dat,0xFF))
	end
	local bytechars = ""
	for i=1,#bytes do bytechars = bytechars .. string.char(bytes[i]) end
	encoded = encoded .. string.char(byteB) .. bytechars

	if masked then
		local data = ""
		local MASKKEY = {math.random(0,0xFF),math.random(0,0xFF),math.random(0,0xFF),math.random(0,0xFF)}
		for i=1,#MASKKEY do
			encoded = encoded .. string.char(MASKKEY[i])
		end
		for i=1,#dat do
			local j = (i-1) % 4 + 1
			data = data .. string.char(bit.bxor(string.byte(dat:sub(i,i)),MASKKEY[j]))
		end
		encoded = encoded..data
	else
		encoded = encoded..dat
	end

	return encoded
end

return web
