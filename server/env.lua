--env.lua
--Specialized functions for AOS3's enviroment.

--Merge two tables together.
function merge(t, t2)
	for k,v in pairs(t2) do
		t[k] = t[k] or v
	end
end

--Return first empty indice.
function empty(t)
	for i=1,i<#t do
		if t[i]==nil then
			return i
		end
	end
end

function fsend(sock,msg)
	sock:send(msg,1,#msg)
end

function selectif(i,...)
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

function clone(tc)
	local clone = {}
	for k,v in pairs(tc) do
		clone[k] = v
	end
	return clone
end

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

function tointeger(num)
	local num = tonumber(num)
	if num then
		return math.floor(num)
	end
end

function find(t,match)
	for k,value in pairs(t) do
		if value == match then
			return k
		end
	end
end

--Evaluate "false" states for other types.
function bool(v)
	if (type(v)=="string" or type(v)=="table") and #v == 0 then
		return false
	end
	return v ~= 0 and v ~= nil and v ~= "0" and v ~= "false" and v
end
