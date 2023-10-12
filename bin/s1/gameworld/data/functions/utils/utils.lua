module("utils", package.seeall)
setfenv(1, utils)

function table_clone( table_obj )
	if table_obj == nil then return {} end
	if type(table_obj) ~= "table" then return {} end
	local table_clone = {}
	for key, element in pairs(table_obj) do
		if type(element) == "table" then
			table_clone[ key ] = utils.table_clone( element )
		else
			table_clone[ key ] = element
		end
	end
	return table_clone
end

--table转字符串(只取标准写法，以防止因系统的遍历次序导致ID乱序)
function t2s(t, blank)
	if t == nil then return "nil" end
	local ret = "{\n"
	local b = (blank or 0) + 1
	local function tabs(n)
		local s = ""
		for i=1,n do
			s = s..'\t'
		end
		return s
	end

	for k, v in pairs(t) do
		if type(k) == "string" then
			ret = ret .. tabs(b) .. k .. "="
		else
			ret = ret ..tabs(b) .."[" .. k .. "] = "
		end

		if type(v) == "table" then
			ret = ret ..t2s(v, b) .. ",\n"
		elseif type(v) == "string" then
			ret = ret ..'"' ..v .. '",\n'
		else
			ret = ret .. tostring(v) ..",\n"
		end
	end

	ret = ret .. tabs(b-1).. "}"
	return ret
end

function tableToJson(obj)
	local json = ""
	local t = type(obj)
	if t == "number" then
		json = json .. obj
	elseif t == "boolean" then
		json = json .. tostring(obj)
	elseif t == "string" then
		json = json .. string.format("%q", obj)
	elseif t == "table" then
		if #obj > 0 then
			json = json .. "["
			local pix = ""
			for k, v in pairs(obj) do
				json = json..pix..tableToJson(v)
				pix = ","
			end
			json = json.."]"			
		else
			json = json .. "{"
			local pix = ""
			for k, v in pairs(obj) do
				json = json ..pix.."\"" .. tostring(k) .. "\":" .. tableToJson(v)
				pix = ","
			end
			json = json.."}"
		end
	else
		print("can not tableToJson a " .. t .. " type.")
	end	
	return json
end

--保存数据用转换方式
function serialize(obj)
	local lua = ""
	local t = type(obj)
	if t == "number" then
		lua = lua .. obj
	elseif t == "boolean" then
		lua = lua .. tostring(obj)
	elseif t == "string" then
		lua = lua .. string.format("%q", obj)
	elseif t == "table" then
		lua = lua .. "{\n"
		for k, v in pairs(obj) do
			lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ",\n"
		end
		local metatable = getmetatable(obj)
		if metatable ~= nil and type(metatable.__index) == "table" then
			for k, v in pairs(metatable.__index) do
				lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ",\n"
			end
		end
		lua = lua .. "}"
	elseif t == "nil" then
		return nil
	else
		print("can not serialize a " .. t .. " type.")
	end
	return lua
end

function unserialize(lua)
	local t = type(lua)
	if t == "nil" or lua == "" then
		return nil, "args is nil"
	elseif t == "number" or t == "string" or t == "boolean" then
		lua = tostring(lua)
	else
		print("can not unserialize a " .. t .. " type.")
		return nil, "type error"
	end
	lua = "return " .. lua
	local func = loadstring(lua)
	if func == nil then
		return nil, "loadstring return nil"
	end
	return func(), nil
end



-- 
--

min_sec   = 60
hours_sec = min_sec * 60
day_sec   = hours_sec * 24
week_sec  = 7 * day_sec


function getDay(t)
	return math.floor((t + System.getTimeZone()) /  day_sec)
end

function getWeeks(t)
	return math.floor((getDay(t) + 3) / 7)
end
function getDaySec(t)
	return math.floor((t + System.getTimeZone()) % day_sec) + 1
end



function getHours(t) --得到今天是整点
	return math.floor(getDaySec(t) / hours_sec)
end

function getMin(t) --得到这是每几分钟
	return math.floor((getDaySec(t) % hours_sec) / min_sec)
end

function getWeek(t) 
	return math.floor((getDay(t) +3) % 7) + 1
end

function getAmSec(t)
	return (getDay(t)  * day_sec) - System.getTimeZone()
end

function awardMerge(rawTbl)
	if not rawTbl then return {} end
	local resTbl = {}
	local temTbl = {}
	for k,v in ipairs(rawTbl) do
		temTbl[v.type] = temTbl[v.type] or {}
		temTbl[v.type][v.id] = (temTbl[v.type][v.id] or 0) + v.count
	end 
	local idx = 1
	for type,v in pairs(temTbl) do
		for id,count in pairs(v) do
			resTbl[idx] = {}
			resTbl[idx].type = type
			resTbl[idx].id = id
			resTbl[idx].count = count
			idx = idx + 1
		end
	end
	return resTbl
end



