local protocol = {}

function protocol:init()
	self.storage = {}
end

function protocol:acceptSock(sock)
	log.monitor(monitor_sock,"New Connection!:",sock)
	self.storage[sock] = {
		new=true,
		web=true,
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
			storage.web = ""
			storage.user_agent = user_agent
			server.buf[sock] = reply
			server.got[sock] = string.match(server.got[sock],"\r\n\r\n(.*)")
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
				break
			end

			--If a packet cant be read in the data, something has gone terribly wrong.,
			if not op and #server.got[sock] ~= "" then
				server.got[sock] = "" --Reset the buffer entirely.
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
function protocol:buffer(sock, msg)
	if not sock then error("Socket object is invalid!",2) end

	local data = msg
	if self.storage[sock].web then
		data = web.encode(msg,1,false,true)
	end
	log.monitor(monitor_ao,"Sent: ",data)
	server:send(sock, data)
end

--Always output a string for safety's sake.
function protocol:escape(str)
	return (not str) and "nil" or str:gsub("%#","<num>")
	:gsub("%$","<dollar>")
	:gsub("%%","<percent>")
	:gsub("%&","<and>")
	:gsub("\\n","\n") --For funsies!
end
--Double as validation for empty values.
function protocol:unescape(str)
	return str and str ~= "" and str:gsub("%<num%>","#")
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
	if input[head] then
		log.monitor(monitor_ao,"Message: \""..head.."\"",self:concatAO{...})
		input[head](self,sock,...)
		return
	end
	log.monitor(monitor_ao,"Unknown Message: \""..head.."\"",self:concatAO{...})
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
input["RC"] = function(self,sock) end
input["RM"] = function(self,sock) end
input["RD"] = function(self,sock)
	self.storage[sock].done = true
end

input["CH"] = function(self,sock)
	process:get(sock,"PING")
end
input["CC"] = function(self,sock, pid,id) --Choose Character.
	process:get(sock,"CHAR", process.characters[(tointeger(id) or -1) + 1])
end
input["PW"] = function(self,sock, ...) --Free Character (Choose Spectator)
	process:get(sock,"CHAR")
end input["FC"] = input["PW"]
input["MC"] = function(self,sock, track, char_id, name, effects, looping, channel) --Play Music
	if track == "Status" then return end
	process:get(sock,"MUSIC",self:unescape(track))
end
input["ZZ"] = function(self,sock, reason) --Mod Call
	process:get(sock,"MODPLZ", reason)
end
input["SP"] = function(self,sock, ...) --Send position
	process:get(sock,"SIDE",...)
end

input["CT"] = function(self,sock, name,message) --OOC Message
	process:get(sock,"MSG",{
		name = self:unescape(name),
		message = self:unescape(message)
	})
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
	local shout        = split(args[11],"%&")
	local present      = tointeger(args[12])
	local flip         = tointeger(args[13])
	local realize      = tointeger(args[14])
	local color        = tointeger(args[15])
	local name         = self:unescape(args[16])
	local pair_id      = tointeger(args[17])
	local offset       = split(args[18],"%&")
	local nowait       = tointeger(args[19])
	local append       = tointeger(args[20])
	local effect       = split(self:unescape(args[21]),"||")

	if name == "0" then name = nil end
	if emote == "-" then emote = nil end

	local id_char = process.characters[(char_id or -1) +1]
	local pair = process.characters[(pair_id or -1) +1]

	if not bool(emote_mod) or pre == "-" then
		pre = nil
		sfx_name = nil
	end

	if sfx_name then
		process:get(sock,"SFX",{
			name   = sfx_name,
			delay  = sfx_delay or 0,
			looping= sfx_looping,
			wait   = true,
		})
	end
	if effect[2] then
		process:get(sock,"SFX",{name=effect[2],wait=true})
	end
	if shout[1] then
		process:get(sock,"ANI",{
			name  = "interject",
			shout = shout[2] or tonumber(shout[1]),
			wait  = true,
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

		--Miscellaneous toggles.
		append  = append,
		nowait  = nowait,
		realize = realize,
		shake   = shake,

		effect  = effect[1],

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
function protocol:send(sock,head,...)
	if type(sock) ~= "userdata" then error("Expected client socket at arg #1!",2) end
	if type(head) ~= "string" then error("Expected string (packet header) at arg #2!",2) end

	if output[head] then
		output[head](self,sock,...)
	else
		error("Attempt to send bogus packet! "..tostring(head), 2)
	end
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
	local chars = #process.characters
	local musics = #process.music+1 --Bake-in "Status"

	self:buffer(sock,"SI#"..chars.."#1#"..musics.."#%")
	self:buffer(sock,"SC#"..self:concatAO(process.characters).."#%")
	self:buffer(sock,"SM#Status#"..self:concatAO(process.music).."#%")

	self:buffer(sock,"DONE#%")
	self:buffer(sock,"HP#0#0#%")
	self:buffer(sock,"HP#1#0#%")

	self.storage[sock].done = true

	output["PONG"](self,sock)
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
	local sfx = self.storage[sock].sfx
	--Read any screen animations to play, such as an interjection.
	local ani = self.storage[sock].ani

	--IC Message
	t[#t+1]= "chat"
	t[#t+1]= msg.pre or "none" --"-" completely disables sound.
	t[#t+1]= msg.char
	t[#t+1]= msg.emote or ""
	t[#t+1]= msg.message or ""
	t[#t+1]= msg.side
	t[#t+1]= sfx and sfx.name or 1
	t[#t+1]= 1 --emote_mod

	--If this client is the author, match client's char_id to clear message.
	if msg.author == sock then
		t[#t+1]= self.storage[sock].char_id or 0
	else
		local id = findindex(process.characters, msg.id_char) or msg.id_char or 0
		if self.storage[sock].char_id == id then
			id = (id+1) % #process.characters
		end
		t[#t+1]= id
	end

	t[#t+1]= sfx and sfx.delay or 0

	if ani and ani.name == "interject" then
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
		local lastmsg = self.storage[sock].lastmsg
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
	t[#t+1]= bool(sfx and sfx.looping) and 1 or 0 --looping_sfx
	t[#t+1]= bool(msg.shake) and 1 or 0 --shake
 	t[#t+1]= "" --Shake
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
	if not sfx or sfx.wait then
		self.storage[sock].sfx = sfx
		return
	end
	--SFX only plays on emotes, so send an empty message to play immediately.

	local msg = clone(self.storage[sock].lastmsg) or {char = "",name = ""}
	msg.pre     = nil
	msg.message = nil
	msg.append  = true

	output["MSG"](self,sock, msg)
end

output["ANI"] = function(self,sock, ani)
	if not ani or ani.wait then
		self.storage[sock].ani = ani
	end
	if ani.name == "witnesstestimony" then
		self:buffer(sock,"RT#testimony1#%")
	elseif ani.name == "crossexamination" then
		self:buffer(sock,"RT#testimony2#%")
	elseif ani.name == "clear_testimony" then
		self:buffer(sock,"RT#testimony1#1#%")
	elseif ani.name == "add_testimony" then
		self:buffer(sock,"RT#testimony1#0#%")
		self:buffer(sock,"RT#-#%")
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
output["PONG"] = function(self,sock, side)
	self:buffer(sock,"CHECK#%")
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
		if not taken then
			if i % 3 == 0 then
				t[#t+1] = -1
			else
				t[#t+1] = 0
			end
		else
			local take = 0
			for i2=1,#taken do
				if taken[i2] == v or taken[i2] == i then
					take = -1
					break
				end
			end
			t[#t+1] = take
		end
	end
	self:buffer(sock,"CharsCheck#"..table.concat(t,"#").."#%")
end
return protocol
