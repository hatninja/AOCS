--env.lua
--Specialized functions for AOS3's enviroment.

--[[Table Handling]]

--Merge two tables together.
function merge(t, t2)
	for k,v in pairs(t2) do
		t[k] = t[k] or v
	end
end

--Return first empty indice.
function firstempty(t)
	local i=0
	repeat
		i=i+1
	until not t[i]
	return i
end

--Find match in a table and return its key.
function findindex(t,match)
	for index=1,#t do
		if t[index] == match then
			return index
		end
	end
end
function findkey(t,match)
	for key,value in pairs(t) do
		if value == match then
			return key
		end
	end
end
function findamong(t,match,key)
	for key,value in pairs(t) do
		if type(value) == "table"
		and value[name] == match then
			return key
		end
	end
end

--Clone a table's data.
function clone(t)
	if type(t) ~= "table" then return end
	local new_t = {}
	for k,v in pairs(t) do
		if type(v) == "table" then
			new_t[k] = clone(v)
		else
			new_t[k] = v
		end
	end
	return new_t
end


local function selectif(i,...)
	if ... then
		return select(i,...)
	end
	return ...
end
function safe(func,...)
	if type(func) ~= "function" then return end
	return selectif(2,pcall(func,...))
end

--[[Value Handling]]
function split(input,delimit)
	if not input then return end

	local t = {}
	local pass = 1

	if type(delimit) ~= "string" then
		for c in input:gmatch "." do
			table.insert(t,c)
		end
		return t
	end

	repeat
		local st, en = input:find(delimit, pass)
		if st then
			table.insert(t,input:sub(pass,st-1))
			pass=en+1
		end
	until not st
	if pass <= #input then
		table.insert(t,input:sub(pass,-1))
	end
	return t
end

--Integer version of tonumber
function tointeger(num)
	local num = tonumber(num)
	if num then
		return math.floor(num)
	end
end

--Evaluate "false" states of other types. Return value back as a convenience.
function bool(v)
	if (type(v)=="string" or type(v)=="table") and #v == 0 then
		return false
	end
	return v ~= 0 and v ~= nil and v ~= "0" and v ~= "false" and v
end

function toprint(v)
	if type(v) == "table" then
		local length = #v
		local count = 0
		local values = ""
		for k,v in pairs(v) do
			count=count+1
			values=values..k.."="..toprint(v)..","
		end
		return string.format("[%d,%d]{%s}",length,count,values:sub(1,-2))
	elseif type(v) == "string" then
		local length = #v
		return string.format("[%d]\"%s\"",length,v)
	end
	return tostring(v)
end

function each(func,...)
	local args = {...}
	local out = {}
	for i=1,#args do
		out[#out+1] = func(args[i])
	end
	args=nil
	return unpack(out)
end
