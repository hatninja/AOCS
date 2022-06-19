--IPID.
--Management and storage of IPs under IPIDs. Basically functioning as an IP replacement.
local IPID = {
	storage = {},
	last = 0,
}

function IPID:load()
	self.storage = {}
	self.last = 0

	local list = data:readList("./Data/IPID.txt")
	for i,line in ipairs(list) do
		local id,ip = line:match("(%d+) (.*)")
		id=tonumber(id)
		self.storage[ip] = id
		self.last=math.max(self.last,id)
	end
end
function IPID:save()
	local list = {}
	for ip,id in pairs(IPID.storage) do
		table.insert(list,id.." "..ip)
	end
	data:saveList("./Data/IPID.txt")
end

function IPID:get(ip)
	local id = storage[ip] or self:new(ip)
	return id
end

function IPID:new(ip)
	self.last=self.last+1
	storage[ip] = self.last
	return
end

return IPID
