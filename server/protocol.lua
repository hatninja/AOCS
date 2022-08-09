--protocol.lua
--Communicates with clients in their protocols. Sends data to Process for important actions.

local protocol = {}

function protocol:init()
	self.storage = {}
end

function protocol:acceptSock(sock)
	log.monitor(monitor_sock,"New Connection!:",sock)
	self.storage[sock] = {
		new=true,
		web="",
	}
end
function protocol:removeSock(sock)
	log.monitor(monitor_sock,"Closed Connection!:",sock)
	self.storage[sock] = nil
end

function protocol:updateSock(sock)
	local storage = self.storage[sock]

	--New connection, check for websocket handshake.
	if storage.new and storage.web then
		local reply, user_agent = web.generateResponse(server.got[sock])
		if reply then
			log.monitor(monitor_web,"Upgrade Request: [[\n"..server.got[sock].."]]")
			storage.user_agent = user_agent
			server.buf[sock] = reply
			server.got[sock] = string.match(server.got[sock],"\r\n\r\n(.*)") or ""
		else
			storage.web = false
		end
	end

	--Decode websocket packets.
	if storage.web then
		repeat
			local data, op, masked, fin, packetlength = web.decode(server.got[sock])
			log.monitor(op and monitor_web,"OP("..tostring(op)..")FIN("..(fin and 1 or 0)..")Data[["..tostring(data).."]]")

			if op == 0 or op == 1 or op == 2 then
				storage.web = storage.web .. data
			elseif op == 9 then --PING
				local pong = web.encode(data,10,false,true)
				sock:send(pong,1,#pong)
			elseif op == 8 then --Client wants to close
				sock:close()
			end

			--If a packet cannot be read properly, something has gone terribly wrong.
			if not op and #server.got[sock] ~= "" then
				server.got[sock] = "" --Clear the buffer entirely.
			end

			local plength = packetlength or 0
			if #server.got[sock]-plength >= 0 then
				server.got[sock] = string.sub(server.got[sock], plength+1,-1)
			end
		until not op
	end

	--Send handshakes to new clients.
	if storage.new then
		self:readAO(sock,"_handshake") --For organization's sake, send to input table.
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
function protocol:buffer(sock, msg)
	local data = msg
	if self.storage[sock].web then
		data = web.encode(msg,1,false,true)
	end
	server.buf[sock] = server.buf[sock] .. data
	log.monitor(monitor_ao,"Sent to "..tostring(sock)..": "..data)
end

--Always output a string for safety's sake.
function protocol:escape(str)
	return type(str) ~= "string" and type(str) or str
	:gsub("%#","<num>")
	:gsub("%$","<dollar>")
	:gsub("%%","<percent>")
	:gsub("%&","<and>")
end
function protocol:unescape(str)
	return type(str) == "string" and str
	:gsub("%<num%>","#")
	:gsub("%<dollar%>","$")
	:gsub("%<percent%>","%%")
	:gsub("%<and%>","&")
end

function protocol:concatAO(t,char)
	local c = {}
	for i,v in ipairs(t) do
		if type(v) == "table" then
			c[i] = self:concatAO(v,"&")
		else
			c[i] = self:escape(tostring(v))
		end
	end
	return table.concat(c,char or "#")
end

local input = {}
function protocol:readAO(sock,head,...)
	log.monitor(monitor_ao,"Message from "..tostring(sock)..": \""..head.."\"",self:concatAO{...})
	if input[head] then
		input[head](self,sock,...)
	end
end

input["_handshake"] = function(self,sock)
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
	process:get(sock,"JOIN")
	--process:get(sock,"STATUS")
end

input["CH"] = function(self,sock) --Ping
	self:buffer(sock,"CHECK#%")
	process:get(sock,"STATUS")
end
input["CC"] = function(self,sock, pid,id) --Choose Character.
	process:get(sock,"CHAR", process.characters[(tointeger(id) or -1) + 1])
end
input["MC"] = function(self,sock, track, char_id, name, effects, looping, channel) --Play Music
	if track == "Status" then return end
	process:get(sock,"MUSIC", self:unescape(track))
end
input["ZZ"] = function(self,sock, reason) --Mod Call
	process:get(sock,"MODPLZ", self:unescape(reason))
end
input["SP"] = function(self,sock, ...) --Send position
	process:get(sock,"SIDE",...)
end

local msid = 1 --Message source identifier.

input["CT"] = function(self,sock, name,message) --OOC Message
	process:get(sock,"MSG",{
		name    = self:unescape(name),
		message = self:unescape(message),
		msid    = msid,
	})
	msid=msid+1
end
input["MS"] = function(self,sock, ...) --IC Message (HERE WE GO!)
	local args = {...}
	local desk         = tointeger(args[1]) --"chat" will show as nil.
	local pre          = self:unescape(args[2])
	local char         = self:unescape(args[3])
	local emote        = self:unescape(args[4])
	local message      = self:unescape(args[5])
	local side         = self:unescape(args[6])
	local sfx_name     = self:unescape(args[7])
	local emote_mod    = tointeger(args[8])
	local char_id      = tointeger(args[9])
	local sfx_delay    = tonumber(args[10])
	local shout        = split(args[11],"%&") or {}
	local present      = tointeger(args[12])
	local flip         = tointeger(args[13])
	local realize      = tointeger(args[14])
	local color        = tointeger(args[15])
	local name         = self:unescape(args[16])
	local pair_id      = tointeger(args[17])
	local offset       = split(args[18],"%&") or {}
	local nowait       = tointeger(args[19])
	local append       = tointeger(args[20])
	local effect       = split(self:unescape(args[21]),"||") or {}

	local id_char = process.characters[(char_id or -1) +1]
	local pair    = process.characters[(pair_id or -1) +1]

	if not bool(name) then
		name = nil
	end
	if not bool(emote_mod) or pre == "-" then
		pre = nil
		sfx_name = nil
	end

	if bool(sfx_name) and sfx_name ~= "1" then
		process:get(sock,"SFX",{
			name   = sfx_name,
			delay  = sfx_delay or 0,
			wait   = true,
			msid   = msid,
		})
	end
	if bool(effect[2]) then
		process:get(sock,"SFX",{
			name  = effect[2],
			wait  = true,
			msid  = msid,
		})
	end
	if bool(shout[1]) then
		process:get(sock,"ANI",{
			name  = "interject",
			shout = shout[2] or tonumber(shout[1]),
			wait  = true,
			msid  = msid,
		})
	end
	process:get(sock,"MSG",{
		name    = name,
		message = message,
		side    = side,
		char    = char,
		emote   = emote,
		pre     = pre,
		color   = color,

		append  = append,
		nowait  = nowait,
		realize = realize,
		shake   = shake,

		effect  = effect[1],

		id_char = id_char,
		author  = sock,
		msid    = msid,
	})
	msid=msid+1
end

--Default Encrypted Messages. Some clients still use these.
input["615810BC07D139"] = input["askchaa"]
input["48E0"] = input["HI"]
input["493F"] = input["ID"]
input["43CC"] = input["CC"]
input["5A37"] = input["ZZ"]
input["43C7"] = input["CH"]
input["43DB"] = input["CT"]
input["4D90"] = input["MS"]
input["4D80"] = input["MC"]

local output = {}
function protocol:send(sock,head,...)
	if type(sock) ~= "userdata" then error("Expected client socket at arg #1!",2) end
	if type(head) ~= "string" then error("Expected string (packet header) at arg #2!",2) end
	if not output[head] then return end
	output[head](self,sock,...)
end

output["INFO"] = function(self,sock)
	self:buffer(sock,"ID#0#AOCS#git#%")
	self:buffer(sock,"PN#"..(process.count).."#0#"..self:escape(config.description).."%")
	self:buffer(sock,"FL#fastloading#noencryption#yellowtext#flipping#deskmod#customobjections#cccc_ic_support#arup#additive#effects#%")

	if bool(config.assets) then
		self:buffer(sock,"ASS#"..self:escape(config.assets).."#%")
	end
end

output["JOIN"] = function(self,sock)
	self:buffer(sock,"SI#"..(#process.characters).."#1#"..(#process.music+1).."#%")
	self:buffer(sock,"SC#"..self:concatAO(process.characters).."#%")
	self:buffer(sock,"SM#Status#"..self:concatAO(process.music).."#%")

	self:buffer(sock,"DONE#%")
	self:buffer(sock,"HP#0#0#%")
	self:buffer(sock,"HP#1#0#%")
end

output["CHAR"] = function(self,sock, id_char)
	local id = findindex(process.characters, id_char) or 0
	self:buffer(sock,"PV#0#CID#"..(id-1).."#%")
	self.storage[sock].char_id = id-1
end

output["MSG"] = function(self,sock, msg)
	local t = {"MS"}

	if not msg.char then --OOC Message
		t[1]= "CT"
		t[2]= msg.name
		t[3]= msg.message
		t[4]= msg.server and 1 or nil

		self:buffer(sock,self:concatAO(t).."#%")
		return
	end

	--Sound effect to play
	local sfx = self.storage[sock].sfx or {}
	sfx = (not sfx.msid or sfx.msid == msg.msid) and sfx
	--Read any screen animations to play, such as an interjection.
	local ani = self.storage[sock].ani or {}
	ani = (not ani.msid or ani.msid == msg.msid) and ani

	--IC Message
	t[#t+1]= "chat"
	t[#t+1]= msg.pre or "none" --"-" completely disables sound.
	t[#t+1]= msg.char
	t[#t+1]= msg.emote or ""
	t[#t+1]= msg.message or ""
	t[#t+1]= msg.side or ""
	t[#t+1]= sfx.name or 1
	t[#t+1]= 1 --emote_mod

	--If this client isn't the author but char_id still matches, increment char_id so client's message wont be cleared.
	if msg.author ~= sock then
		local id = (findindex(process.characters, msg.id_char) or 1)-1
		if self.storage[sock].char_id == id then
			id = id+1 % #process.characters
		end
	end
	t[#t+1]= id or self.storage[sock].char_id or 0

	t[#t+1]= sfx.delay or 0

	if ani.name == "interject" then
		t[#t+1]= tointeger(ani.shout) or "4&"..tostring(ani.shout)
	else
		t[#t+1]= 0
	end
	t[#t+1]= 0 --Evidence
	t[#t+1]= msg.flip and 1 or 0
	t[#t+1]= bool(msg.realize) and 1 or 0
	t[#t+1]= msg.color or 0
	t[#t+1]= msg.name or ""

	--Pair Section:
	local blank = not msg.emote
	if bool(msg.preserve) then
		local lastmsg = self.storage[sock].lastmsg or {}
		t[#t+1]= 0
		t[#t+1]= lastmsg.char or ""
		t[#t+1]= lastmsg.emote or ""
		t[#t+1]= blank and "100" or 0
		t[#t+1]= 0
		t[#t+1]= lastmsg.flip and 1 or 0
	else
		t[#t+1]= blank and 0 or -1
		t[#t+1]= ""
		t[#t+1]= ""
		t[#t+1]= blank and "100" or 0
		t[#t+1]= blank and "100" or 0
		t[#t+1]= 0
	end

	t[#t+1]= bool(msg.nowait) and 1 or 0
	t[#t+1]= bool(sfx.looping) and 1 or 0 --looping_sfx
	t[#t+1]= bool(msg.shake) and 1 or 0 --shake
 	t[#t+1]= "" --Shake (Frames)
	t[#t+1]= bool(msg.realize) and "1" or "" --Flash
	t[#t+1]= "" --SFX
	t[#t+1]= bool(msg.append) and 1 or 0
	t[#t+1]= msg.effect or ""

	self:buffer(sock,self:concatAO(t).."#%")

	if not bool(msg.preserve) then
		self.storage[sock].lastmsg = msg
	end
	self.storage[sock].sfx = nil
	self.storage[sock].ani = nil
end

output["SFX"] = function(self,sock, sfx)
	self.storage[sock].sfx = sfx
	if not sfx or sfx.wait then return end

	--In AO2, SFX only plays on emotes, so send an empty message to play immediately.
	local msg = clone(self.storage[sock].lastmsg) or {}
	msg.pre     = nil
	msg.message = ""
	msg.append  = true

	output["MSG"](self,sock, msg)
end

output["ANI"] = function(self,sock, ani)
	if not ani or ani.wait then
		self.storage[sock].ani = ani
		return
	end
	if ani.name == "witnesstestimony" then
		self:buffer(sock,"RT#testimony1#%")
		self:buffer(sock,"RT#testimony1#1#%") --I don't want to bother.
	elseif ani.name == "crossexamination" then
		self:buffer(sock,"RT#testimony2#%")
	elseif ani.name == "notguilty" then
		self:buffer(sock,"RT#judgeruling#0#%")
	elseif ani.name == "guilty" then
		self:buffer(sock,"RT#judgeruling#1#%")
	else
		self:buffer(sock,"RT#"..self:escape(ani.name).."#%")
	end
end

output["MUSIC"] = function(self,sock, track)
	self:buffer(sock,"MC#"..self:escape(track).."#-1##1#0#2#%")
end
output["SCENE"] = function(self,sock, scene)
	self:buffer(sock,"BN#"..self:escape(scene).."#%")
end
output["SIDE"] = function(self,sock, side)
	self:buffer(sock,"SP#"..self:escape(side).."#%")
end

output["BAN"] = function(self,sock, reason)
	self:buffer(sock,"KB#"..self:escape(reason).."#%")
end
output["NOTICE"] = function(self,sock, note)
	self:buffer(sock,"BB#"..self:escape(note).."#%")
end

--AO Specific.
output["STATUS"] = function(self,sock, user_count,areas,session,cm)
	self:buffer(sock,"ARUP#0#"..(user_count).."#%")
	self:buffer(sock,"ARUP#3#"..(areas).."#%")
	self:buffer(sock,"ARUP#1#"..(session).."#%")
	self:buffer(sock,"ARUP#2#"..(cm).."#%")
end
output["TAKEN"] = function(self,sock, taken)
	local t = {}
	for i,v in ipairs(process.characters) do
		t[#t+1] = (taken and findindex(taken,v)) and -1 or 0
	end
	self:buffer(sock,"CharsCheck#"..table.concat(t,"#").."#%")
end
return protocol
