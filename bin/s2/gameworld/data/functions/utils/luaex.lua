--[[
	LUA系统增强
]]

module("utils.luaex", package.seeall)
setfenv(1, utils.luaex)

-- * 提供lua表的深拷贝方法
local function tabDeepcopy(object)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

table.deepcopy = tabDeepcopy

function defIsSameItemFunc(a, b)
	return a == b
end

-- * Comments:移除数组内item
-- * Param table array:母数组
-- * Param obj val:检测值
-- * Param bool all:是否只删除找到的第一个或者是全部
-- * @Return bool:
function tableRemoveItem(itemArray, item, all, func)
	if not func then func = defIsSameItemFunc end
	local flag = false
	for k,v in pairs(itemArray) do
		if func(item, v) then
			itemArray[k] = nil
			if type(k) == "number" then
				table.remove(itemArray, k)
			end
			flag = true
			if not all then return true end
		end
	end
	return flag
end

table.removeItem = tableRemoveItem

function getnEx(tab)
	if not tab then return 0 end

	local count = 0
	for _,_ in pairs(tab) do
		count = count + 1
	end

	return count
end

table.getnEx = getnEx

-- 获取排行榜数字
function GetRankNum(val)
	local num = tonumber(val)
	if num == nil then
		return 0
	end

	return num
end

function defTabContainsFunc(a, b)
	return a == b
end

-- * Comments:判断某item是否在array内
-- * Param table array:母数组
-- * Param obj val:检测值
-- * @Return bool:
function tabContains(itemArray, item, func)
	if not func then func = defTabContainsFunc end
	for _,v in ipairs(itemArray) do
		if func(item, v) then return true end
	end
	return false
end

table.contains = tabContains


-- * Comments:获取某个item的index
-- * Param table array:母数组
-- * Param obj item:检测值
-- * Param table out_array:另外一个数组
-- * @Return bool:
function getIndxOf(array, item, out_array)
	local indx
	for k,v in pairs(array) do
		if item == v then
			indx = k
			break
		end
	end
	if not out_array or not indx then
		return indx
	end
	return out_array[indx]
end

table.getindxof = getIndxOf

function lua_string_split(s, p)
	local rt = {}
	string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
	return rt
end

----------------------------------------------
local GRIDBIT = 6
function posg(val)
	return System.bitOpRig(val, GRIDBIT)
end

System.posg = posg
-----------------------------------------------
function getRandomOne(array)
	local num = System.getRandomNumber(#array) + 1
	return array[num], num
end

table.choice = getRandomOne

function getRandomItem(array, rateCnt)
	if not rateCnt then rateCnt = 10000 end

	local randomNum = System.getRandomNumber(rateCnt) + 1
	for i,v in ipairs(array) do
		if v.rate then
			if v.rate >= randomNum then
				return v
			else
				randomNum = randomNum - v.rate
			end
		end
	end
end

table.getrandomitem = getRandomItem

