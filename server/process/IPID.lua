--IPID.
--Management and storage of IPs under IPIDs. Basically functioning as an IP replacement.
local IPID = {
	storage = {},
	last = 0,
}

function IPID:load()
	self.storage = {}
	self.last = 0

	local list = data.readList("./data/IPID.txt")
	for i,line in ipairs(list) do
		local id,ip = line:match("(%d+) (.*)")
		id=tonumber(id)
		self.storage[ip] = id
		self.last=math.max(self.last,id)
	end
end
function IPID:save()
	local list = {}
	for ip,id in pairs(self.storage) do
		table.insert(list,id.." "..ip)
	end
	data.saveList("./data/IPID.txt")
end

function IPID:get(ip)
	local id = self.storage[ip] or self:new(ip)
	return id
end

function IPID:new(ip)
	self.last=self.last+1
	self.storage[ip] = self.last
	return
end

return IPID
