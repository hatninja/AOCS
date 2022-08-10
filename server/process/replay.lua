--Replay management through a replay class.
local replay = {}
replay.__index=replay

function replay:new()
	return setmetatable({
		data = {},   --table
		timing = {}, --number
		hiding = {}, --true/false
		spans  = {}, --{class,id,start,end}

		created = socket.gettime(),
	},self)
end

function replay:record(rep, pointer, head, data)
	local dat = self:convert(head,data)
	if not dat then return end --Data was not recordable.

	local timing = rep.created - socket.gettime()

	local p = self:readpointer(rep,pointer)

	table.insert(rep.data,p,dat)
	table.insert(rep.timing,p,timing)
end

function replay:readpointer(rep, pointer)
	local p = tonumber(pointer)
	if p < 0 then
		p = #rep.data+1 - p
	end
	if p > #rep.data then p = #rep.data+1 end
	if p < 1 then p = 1 end
	return p
end

function replay:startspan(rep, class,id, st,en)
	local span = {class,id,st,en}
	if not span[3] then span[3] = #rep.data+1 end
	if not span[4] then span[4] = -1 end
	local matching_spans = self:getspansat(#rep.data+1)
end

function replay:getspansat(rep, pointer, class, id)
	local spans = {}
	local ids = {}
	local p = self:readpointer(rep,pointer)
	for i,v in ipairs(rep.spans) do
		if (not class or class == v[1])
		and (not id or id == v[2]) then
			spans[#spans+1] = v
			ids[#ids+1] = i
		end
	end
	return spans,ids
end

--Convert messages to replay data.
function replay:convert(head,data)
	if head == "MSG" then
		return {
			head    = "MSG",
			name    = data.name,
			message = data.message,
			color   = data.color,
			char    = data.char,
			emote   = data.emote,
			pre     = data.pre,
			side    = data.side,
			flip    = data.flip,
			effect  = data.effect,
			append  = data.append,
			nowait  = data.nowait,
			realize = data.realize,
			shake   = data.shake,
		}
	end
	if head == "SFX" then
		return {
			head  = "SFX",
			name  = data.name,
			delay = data.delay,
		}
	end
	if head == "ANI" then
		return {
			head  = "ANI",
			name  = data.name,
			shout = data.shout,
		}
	end
	if head == "SCENE" then
		return {
			head = "SCENE",
			name = data,
		}
	end
	if head == "MUSIC" then
		return {
			head = "MUSIC",
			name = data,
		}
	end
end

--Convert replay data to shareable form.
local PAGE_SIZE = 1024

function replay:share()
end

return replay
