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
	for i=1,i<#t do
		if t[i]==nil then
			return i
		end
	end
end

--Find match in a table and return its key.
function find(t,match)
	for key,value in pairs(t) do
		if value == match then
			return key
		end
	end
end

--Clone a table's data.
function clone(t)
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

--[[Control Flow and Error Handling]]
local function selectif(i,...)
	if ... and true then
		return select(i,...)
	end
end
function safe(func,...)
	return selectif(2,pcall(func,...))
end

function simpletraceback()
	local tb = debug.traceback()
	tb = tb:match("\n.-\n(.+)\n")
	tb = tb:gsub("\t","")
	tb = tb:gsub("%[C%]%: in function '(.-)'\n(.-%:%d+%:)","%2 using '%1'")
	--tb = tb:gsub(".-%:%d+%:(.-)\n.-%"
	tb = tb:gsub("%[C%]%: .-\n","")
	tb = tb:gsub("in function '(.-)'","at %1()")
	return tb
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
