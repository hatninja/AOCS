local protocol = {}

function protocol.init(self)
	self.storage = {}
end

function protocol.acceptClient(self,sock)
	print("New Connection!:",sock)
	self.storage[sock] = {
		new=true,
		web=true,
	}
end
function protocol.closeClient(self,sock)
	print("Closed Connection!:",sock)
	self.storage[sock] = nil
end

function protocol.updateClient(self,sock)
	local storage = self.storage[sock]

	--New connection, check for websocket handshake.
	if storage.new and storage.web then
		local reply, user_agent = web.generateResponse(server.got[sock])
		if reply then
			--print("Upgrade Request: [["..server.got[sock].."]]")
			storage.web = ""
			storage.user_agent = user_agent
			server.buf[sock] = reply
			--server.got[sock] = string.match(server.got[sock],"\r\n\r\n(.*)")
			server.got[sock] = ""
		else
			storage.web = false
			print("Not Web!")
		end
	end

	--Decode websocket packets.
	if storage.web then
		repeat
			local data, op, masked, fin, packetlength = web.decode(server.got[sock])
			if op == 0 or op == 1 or op == 2 then
				storage.web = storage.web .. data

			elseif op == 9 then --PING
				local pong = web.encode(data,10,false,true)
				sock:send(pong,1,#pong)

			elseif op == 8 then --Client wants to close
				sock:close()
				break
			end
			if #server.got[sock]-(packetlength or 0) >= 0 then
				server.got[sock] = server.got[sock]:sub((packetlength or 0)+1,-1)
			end
		until not op
	end

	--Send handshakes to new clients.
	if storage.new then
		self:readAO(sock,"new") --For organization's sake, send to input table.
		storage.new = false
	end

	--Read data in AO protocol.
	local data = storage.web or server.got[sock]
	local p = 1

	repeat
		local packet = string.match(data,"%#?([^%%]+)",p)
		if packet then
			self:readAO(sock, unpack(split(packet,"%#")) )
			p = (string.find(data,"%",p,true) or 0)+1
		end
	until not packet

	if storage.web then
		storage.web = storage.web:sub(p,-1)
	else
		server.got[sock] = server.got[sock]:sub(p,-1)
	end
end
function protocol.buffer(self,sock, msg)
	if not sock then error("Socket object is invalid!",2) end

	local data = msg
	if self.storage[sock].web then
		data = web.encode(msg,1,false,true)
	end
	print("Sent: ",data)
	server:send(sock, data)
end

--Always output a string for safety's sake.
function protocol.escape(str)
	return (not str) and "nil" or str:gsub("%#","<num>")
	:gsub("%$","<dollar>")
	:gsub("%%","<percent>")
	:gsub("%&","<and>")
	:gsub("\\n","\n") --For funsies!
end
--Double as validation for empty values.
function protocol.unescape(str)
	return str and str ~= "" and str:gsub("%<num%>","#")
	:gsub("%<dollar%>","$")
	:gsub("%<percent%>","%%")
	:gsub("%<and%>","&")
end

function protocol.concatAO(t)
	local c = {}
	for i,v in ipairs(t) do
		c[i] = protocol.escape(tostring(v))
	end
	return table.concat(c,"#")
end

local input = {}
function protocol.readAO(self,sock,head,...)
	if input[head] then
		print("Message: \""..head.."\"",...)
		input[head](self,sock,...)
		return
	end
	print("Unknown Message: \""..head.."\"",...)
end

input["new"] = function(self,sock)
	process:get(sock,"INFO")
end

input["HI"] = function(self,sock, hdid)
	self.storage[sock].hdid = hdid
end
input["ID"] = function(self,sock, software,version)
	self.storage[sock].software = software
	self.storage[sock].version = version
end

input["askchaa"] = function(self,sock)
	if self.storage[sock].done then return end
	process:get(sock,"JOIN")
end
input["RC"] = function(self,sock)
--	self:buffer(sock,"SC#"..self.concatAO(process.characters).."#%")
end
input["RM"] = function(self,sock)
--	self:buffer(sock,"SM#Status#"..self.concatAO(process.music).."#%")
end
input["RD"] = function(self,sock)
	--self:buffer(sock,"CharsCheck#0#%")
	--self:buffer(sock,"DONE#%")
	self.storage[sock].done = true
end

input["CH"] = function(self,sock)
	process:get(sock,"PING")
end
input["CC"] = function(self,sock, pid,id) --Choose Character.
	process:get(sock,"CHAR", process.characters[(tointeger(id) or -1) + 1])
end
input["MC"] = function(self,sock, track, char_id, name, effects, looping, channel) --Play Music
	if track == "Status" then return end
	process:get(sock,"MUSIC",self.unescape(track))
end
input["ZZ"] = function(self,sock, reason) --Mod Call
	process:get(sock,"MODPLZ", reason)
end
input["DC"] = function(self,sock) --Close Client
	sock:close()
end
input["SP"] = function(self,sock, ...) --Send position
	process:get(sock,"SIDE",...)
end
input["FC"] = function(self,sock) --Free Character.
	--process:get(sock,"CHAR")
end; input["PW"] = input["FC"]

input["CT"] = function(self,sock, name,message) --OOC Message
	process:get(sock,"MSG",{
		name = self.unescape(name),
		message = self.unescape(message)
	})
end
input["MS"] = function(self,sock, ...) --IC Message (HERE WE GO!)
	local args = {...}
	local desk         = tointeger(args[1]) --"chat" will show as nil.
	local pre          = self.unescape(args[2])
	local char         = self.unescape(args[3])
	local emote        = self.unescape(args[4])
	local message      = self.unescape(args[5])
	local side         = self.unescape(args[6])
	local sfx_name     = self.unescape(args[7])
	local emote_mod    = tointeger(args[8])
	local char_id      = tointeger(args[9])
	local sfx_delay    = tonumber(args[10])
	local shout        = split(args[11],"%&")
	local present      = tointeger(args[12])
	local flip         = tointeger(args[13])
	local realize      = tointeger(args[14])
	local color        = tointeger(args[15])
	local name         = self.unescape(args[16])
	local pair_id      = tointeger(args[17])
	local offset       = split(args[18],"%&")
	local nointerrupt  = tointeger(args[19])
	local sfx_looping  = tointeger(args[20])
	local shake        = tointeger(args[21])
	local frames_shake = split(args[22],"%&")
	local frames_flash = split(args[23],"%&")
	local frames_sfx   = split(args[24],"%&")
	local append       = tointeger(args[25])
	local effect       = self.unescape(args[26])

	if name == "0" then name = nil end
	if emote == "-" then emote = nil end

	local id_char = process.characters[(char_id or -1) +1]
	local pair = process.characters[(pair_id or -1) +1]

	if not bool(emote_mod) or pre == "-" then
		pre = nil
		sfx_name = nil
		sfx_delay = nil
	end

	if sfx_name then
		process:get(sock,"SFX",{
			sfx    = sfx_name,
			delay  = sfx_delay or 0,
			wait   = true,
		})
	end
	process:get(sock,"MSG",{
		name    = name,
		message = message,

		side    = side,
		char    = char,
		emote   = emote,
		pre     = pre,

		id_char = id_char,
		author  = sock,
	})
end

--Default Encrypted Messages. Some clients still use these.
input["615810BC07D139"] = input["askchaa"]
input["48E0"] = input["HI"]
input["493F"] = input["ID"]
input["529E"] = input["RC"]
input["5290"] = input["RM"]
input["5299"] = input["RD"]
input["43CC"] = input["CC"]
input["5A37"] = input["ZZ"]
input["43C7"] = input["CH"]
input["43DB"] = input["CT"]
input["4D90"] = input["MS"]
input["4D80"] = input["MC"]
input["4422"] = input["DC"]


local output = {}
function protocol.send(self,sock,head,...)
	if output[head] then
		output[head](self,sock,...)
	else
		error("Attempt to send bogus packet! "..tostring(head), 2)
	end
end

output["INFO"] = function(self,sock)
	self:buffer(sock,"decryptor#34#%")
	self:buffer(sock,"ID#0#AOS3#git#%")
	self:buffer(sock,"PN#"..(process.count).."#0#"..self.escape(config.description).."%")
	self:buffer(sock,"FL#fastloading#noencryption#yellowtext#flipping#deskmod#customobjections#modcall_reason#cccc_ic_support#arup#additive#%")

	if bool(config.assets) then
		self:buffer(sock,"ASS#"..self.escape(config.assets).."#%")
	end
end

output["JOIN"] = function(self,sock)
	local chars = #process.characters
	local musics = #process.music+1 --"Status"
	self:buffer(sock,"SI#"..chars.."#1#"..musics.."#%")

	self:buffer(sock,"SC#"..self.concatAO(process.characters).."#%")
	self:buffer(sock,"SM#Status#"..self.concatAO(process.music).."#%")

	self:buffer(sock,"DONE#%")

	self.storage[sock].done = true

	output["PONG"](self,sock)
end

output["CHAR"] = function(self,sock, id_char)
	local id = 0
	for i,v in ipairs(process.characters) do
		if id_char == v then
			id = i
			break
		end
	end
	self:buffer(sock,"PV#0#CID#"..(id-1).."#%")
	self.storage[sock].char_id = id-1
end

output["DONE"] = function(self,sock)
	self:buffer(sock,"HP#0#0#%")
end

output["MSG"] = function(self,sock, msg)
	local t = {"MS"}

	if not msg.char then --OOC Message
		t[1]= "CT"
		t[2]= msg.name
		t[3]= msg.message
		t[4]= msg.server and 1 or nil

		self:buffer(sock,self.concatAO(t).."#%")
		return
	end

	--Pull sound effect to play
	local sfx = self.storage[sock].sfx

	--IC Message
	t[#t+1]= "chat"
	t[#t+1]= msg.pre or "none" --"-" completely disables sound.
	t[#t+1]= msg.char
	t[#t+1]= msg.emote
	local blank = not msg.emote

	t[#t+1]= msg.message or ""
	t[#t+1]= msg.side
	t[#t+1]= sfx and sfx.name or 1

	t[#t+1]= 0 --emote_mod

	--If this client is the author, match client's char_id to clear message.
	if msg.author == sock then
		t[#t+1]= self.storage[sock].char_id or 0
	else
		local id = msg.id_char or 0
		for i,v in ipairs(process.characters) do
			if v == msg.id_char then
				id = (i-1)
				break
			end
		end
		if id == self.storage[sock].char_id then
			id = (id+1) % #process.characters
		end
		t[#t+1]= id
	end

	t[#t+1]= sfx and sfx.delay or 0
	t[#t+1]= 0 --interject

	t[#t+1]= 0 --Evidence
	t[#t+1]= msg.flip and 1 or 0

	t[#t+1]= msg.realize and 1 or 0
	t[#t+1]= msg.color or 0

	t[#t+1]= msg.name or ""

	if blank then
		t[#t+1]= 0
		t[#t+1]= ""
		t[#t+1]= "-"
		t[#t+1]= "100"
		t[#t+1]= "100"
		t[#t+1]= 0
	else
		t[#t+1]= -1
		t[#t+1]= ""
		t[#t+1]= ""
		t[#t+1]= 0
		t[#t+1]= 0
		t[#t+1]= 0
	end
	t[#t+1]= 1 --no_interrupt
	t[#t+1]= (sfx and sfx.looping) and 1 or 0 --looping_sfx
	t[#t+1]= 1 --shake
 	t[#t+1]= ""
	t[#t+1]= "" --The emote stuff.
	t[#t+1]= ""
	t[#t+1]= msg.append and 1 or 0
	t[#t+1]= msg.effect or ""

	self:buffer(sock,self.concatAO(t).."#%")

	self.storage[sock].lastmsg = msg
	self.storage[sock].sfx = nil
end

output["MUSIC"] = function(self,sock, track)
	self:buffer(sock,"MC#"..self.escape(track).."#-1##1#0#2#%")
end

output["SCENE"] = function(self,sock, scene)
	self:buffer(sock,"BN#"..self.escape(scene).."#%")
end

output["ANI"] = function(self,sock, ani)
	if ani.name == "witnesstestimony" then
		server.send(sock,"RT#testimony1#%")
	elseif ani.name == "crossexamination" then
		server.send(sock,"RT#testimony2#%")
	elseif ani.name == "clear_testimony" then
		server.send(sock,"RT#testimony1#1#%")
	elseif ani.name == "add_testimony" then
		server.send(sock,"RT#testimony1#0#%")
		server.send(sock,"RT#-#%")
	else
		server.send(sock,"RT#"..self.escape(ani.name) or "-#%")
	end
end

output["SFX"] = function(self,sock, sfx)
	self.storage[sock].sfx = sfx

	if sfx.wait then return end
	--SFX only plays on emotes, so send an empty message to play immediately.

	local msg = self.storage[sock].lastmsg or {char = "",name = ""}
	msg.pre     = nil
	msg.message = nil
	msg.append  = true

	output["MSG"](self,sock, msg)
end

--Use ping as a way to update information to clients.
output["PONG"] = function(self,sock, side)
	--Server Stats in room count and lock status.
	self:buffer(sock,"ARUP#0#"..(process.count).."#%")
	self:buffer(sock,"ARUP#3#"..(#process.areas).." areas#%")
	--Get current session in room status.
	self:buffer(sock,"ARUP#1#Session [?]#%")
	--Get current CM in CM.
	self:buffer(sock,"ARUP#2#Free#%")
end

output["SIDE"] = function(self,sock, side)
	self:buffer(sock,"SP#"..self.escape(side).."#%")
end

output["BAN"] = function(self,sock, reason)
	self:buffer(sock,"KB#"..self.escape(reason).."#%")
end
output["NOTICE"] = function(self,sock, note)
	self:buffer(sock,"BB#"..self.escape(note).."#%")
end

return protocol
