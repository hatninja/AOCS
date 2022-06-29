--data.lua
--File Management and Data Storage.
local data = {}

data.isFile = function(dir)
	local f = io.open(dir)
	if f then
		f:close()
		return true
	end
end

data.read = function(dir)
	local f = io.open(dir,"r")
	if not f then return "" end
	local dat = f:read("*a");f:close()
	return dat
end

data.save = function(dir,dat)
	local f = io.open(dir,"w")
	if not f then return end
	f:write(dat);f:close()
end

data.readList = function(dir)
	local t = {}
	for line in ("\n"..data.read(dir)):gmatch("([^\n]+)\r?") do
		if string.find(line,"%S") and string.sub(line,1,1) ~= "#" then
			table.insert(t,line)
		end
	end
	return t
end

data.saveList = function(dir,list)
	local dat = table.concat(list,"\n")
	data.write(dir,dat.."\n")
end

data.readConf = function(dir)
	local t = {}
	for i,v in ipairs(data.readList(dir)) do
		local key = string.match(v,"(%S+)%s-%=")
		local value = string.match(v,"%=%s*(.+)")
		if key then
			t[key] = value
		end
	end
	return t
end

data.saveConf = function(dir,conf)
end

data.getDir = function(dir)
	local items = {}
	local file = io.popen("ls "..dir)
	for line in file:lines() do
		items[#items+1] = line
	end
	return items
end

return data
