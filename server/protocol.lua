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
		c[i] = self.escape(v)
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
	self:buffer(sock,"SC#"..self.concatAO(process.characters).."#%")
end
input["RM"] = function(self,sock)
	self:buffer(sock,"SM#Status#"..self.concatAO(process.music).."#%")
end
input["RD"] = function(self,sock)
	self:buffer("CharsCheck#0#%")
	self:buffer("DONE#%")
	self.storage[sock].done = true
end

input["CH"] = function(self,sock)
	process:get(sock,"PING")
end
input["CC"] = function(self,sock, pid,id) --Choose Character.
	process:get(sock,"CHAR", process.characters[tointeger(id) or 0])
end
input["MC"] = function(self,sock, track, char_id, name, effects, looping, channel) --Play Music
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
input["FC"] = function(self,sock) --Free Character. (Functionally choosing spectator.)
	process:get(sock,"CHAR")
end; input["PW"] = input["FC"]

input["CT"] = function(self,sock, name,message) --OOC Message
	process:get(client,"MSG",{
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
	local flash        = tointeger(args[14])
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

	local id_char = process.characters[char_id or 0]
	local pair = process.characters[pair_id or 0]

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
	if pre then
		process:get(sock,"ANIM",{
			anim   = pre,
			char   = char,
			wait   = true,
			--length = -1,
			stop   = not bool(nointerrupt),
		})
	end

	process:get(sock,"MSG",{
		name    = name,
		message = message,

		char    = char,
		side    = side,
		emote   = emote,
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

	--input["RC"](self,sock)
	--input["RM"](self,sock)

	--self:buffer(sock,"DONE#%")
end

output["CHAR"] = function(self,sock, char)
	if char then
		client:bufferraw("PV#0#CID#"..char.."#%")
		return
	end
	client:bufferraw("PV#0#CID#-1#%")
end

output["DONE"] = function(self,sock)
	self:buffer(sock,"HP#0#0#%")
end

output["MSG"] = function(self,sock, msg)
	if not msg.char then --OOC
		return
	end
	--IC
	local ms = "MS#"
	local t  = {}
	if client.software == "AO" or client.software == "webAO" then
		t[#t+1] = "chat"
	else
		t[#t+1] = data.desk or data.fg and 1 or 0
	end
	t[#t+1] = self:escape(data.pre_emote or "none") --"-" completely disables sound.
	t[#t+1] = self:escape(data.character or " ")
	t[#t+1] = self:escape(data.emote or "normal")
	--Dialogue
	local dialogue = data.dialogue or ""
	t[#t+1] = self:escape(dialogue)
	--Position
	local side = data.side
	t[#t+1] = side
	--Sound name
	t[#t+1] = data.sfx_name or 1
	--Emote modification
	local emote_modifier = 0
	if not data.no_interrupt then
		if data.pre_emote then
			emote_modifier = 1
		end
		if data.bg then
			emote_modifier = 5
		end
		if data.interjection and data.interjection ~= 0 then
			emote_modifier = emote_modifier + 1
		end
		if data.sfx_name and data.bg then
			emote_modifier = 6
		end
	end
	t[#t+1] = emote_modifier
	local char_id = data.char_id and self:getCharacterId(client, data.char_id) or self:getCharacterId(client, data.character) or -1
	if char_id == -1 then
		char_id = 0
	end
	t[#t+1] = char_id
	--Sound delay
	t[#t+1] = data.sfx_delay or 0
	--Shout modifier
	t[#t+1] = data.interjection or 0
	--Evidence
	t[#t+1] = data.item or 0
	--Flip
	if client.software == "AO" then
		t[#t+1] = char_id
	else
		t[#t+1] = data.flip and 1 or 0
	end
	t[#t+1] = data.realization and 1 or 0
	local text_color = self:tointeger(data.text_color) or 0
	if client.software == "AO" and text_color == 5 then text_color = 3 end
	t[#t+1] = text_color
	--Shownames.
	t[#t+1] = data.name or ""
	--Character pairing.
	local pair_id = data.pair_id and self:getCharacterId(client, data.pair_id) or self:getCharacterId(client, data.pair) or -1
	if pair_id ~= -1 and data.pair and data.pair_emote then
		t[#t+1] = pair_id or -1
		t[#t+1] = data.pair or ""
		t[#t+1] = data.pair_emote or "-"
		t[#t+1] = data.hscroll or 0
		t[#t+1] = data.pair_hscroll or 0
		t[#t+1] = data.pair_flip and 1 or 0
		t[#t+1] = data.no_interrupt and 1 or 0
	else
		t[#t+1] = -1
		t[#t+1] = ""
		t[#t+1] = ""
		t[#t+1] = 0
		t[#t+1] = 0
		t[#t+1] = 0
		t[#t+1] = 1
	end
	t[#t+1] = data.sfx_looping and 1 or 0
	t[#t+1] = data.shake and 1 or 0
	t[#t+1] = ""
	t[#t+1] = ""
	t[#t+1] = ""
	t[#t+1] = data.append and 1 or 0
	t[#t+1] = data.effect or ""

	self:buffer(sock,ms..table.concat(t,"#").."#%")
end

output["MUSIC"] = function(self,sock, track)
	self:buffer(sock,"MC#"..self.escape(track).."#-1##1#0#1#%")
end

output["SCENE"] = function(self,sock, scene)
	self:buffer(sock,"BN#"..self.escape(scene).."#%")
end

output["ANIM"] = function(self,sock, anim)
	if anim.anim == "witnesstestimony" then
		server.send(sock,"RT#testimony1#%")
	elseif anim.anim == "crossexamination" then
		server.send(sock,"RT#testimony2#%")
	elseif anim.anim == "clear_testimony" then
		server.send(sock,"RT#testimony1#1#%")
	elseif anim.anim == "add_testimony" then
		server.send(sock,"RT#testimony1#0#%")
		server.send(sock,"RT#-#%")
	elseif anim.anim == "splash" then
		server.send(sock,"RT#"..anim.dir.."#%")
	end
end

--Use ping as a way to update information to clients.
output["PONG"] = function(self,sock, side)
	--Server Stats in room count and lock status.
	self:buffer(sock,"ARUP#0#"..(process.count).."#%")
	self:buffer(sock,"ARUP#3#"..(#process.areas).." areas.#%")
	--Get current session in room status.
	self:buffer(sock,"ARUP#1#Session: ?#%")
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
