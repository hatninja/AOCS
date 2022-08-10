local module = {}

module.callbacks = {}
module.callbacks.command = function(self,cb, ses,cmd,args,msg,report)
	if cmd == "roll" or cmd == "diceroll" then
		local results = {}
		local min
		for i,v in ipairs(args) do
			local num = tonumber(v)
			if num then
				if not min then
					min = num
				else
					local rand = math.random(math.min(min,num),math.max(min,num))
					results[#results+1] = {(min==1 and "" or min.."-")..num.." die",rand}
					min = nil
				end
			end
			local count,dice,op,operand = string.match(v,"(%d*)d(%d*)([+-]?)(%d*)")
			if count and dice then
				local result = ""
				for i=1,tonumber(count) or 1 do
					local rand = math.random(1,tonumber(dice) or 20)
					if op == "+" then
						rand = rand + tonumber(operand) or 0
					elseif op == "-" then
						rand = rand - tonumber(operand) or 0
					end
					if i ~= 1 then
						result = result .. ", "
					end
					result = result .. rand
				end
				results[#results+1] = {(count or "").."d"..(dice or 20)..(op or "")..(operand or ""),result}
			end
		end
		if #results == 0 and not min then
			results[#results+1] = {"20 die",math.random(1,20)}
		end
		if min then
			results[#results+1] = {min.." die",math.random(1,min)}
		end
		for i,result in ipairs(results) do
			process:sendMsg(report,result[1]..": "..result[2])
		end
	end
	if cmd == "flip" or cmd == "coin" or cmd == "coinflip" then
		local times = math.min(tonumber(args[1]) or 1, 100)
		local flips = {}
		for i=1,times do
			flips[#flips+1] = math.random(0,1)
		end
		if times == 1 then
			process:sendMsg(report,"Flipped a coin and got "..(bool(flips[1]) and "Heads." or "Tails."))
		else
			local heads = 0
			local msg = "Flipped "..times.." coins and got the sequence:\n"
			for i=1,times do
				if i~=1 then msg=msg..", " end
				if flips[i] == 1 then
					heads=heads+1
					msg=msg.."H"
				else
					msg=msg.."T"
				end
			end
			process:sendMsg(report,msg .. "("..math.floor((heads/times)*100).."%)")
		end
		return
	end
end

return module
