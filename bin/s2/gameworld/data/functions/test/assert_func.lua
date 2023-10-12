-- 检测的一些基本逻辑
module("test.assert_func" , package.seeall)
setfenv(1, test.assert_func)
local Item = Item
local algorithm = require("utils.algorithm")
math.randomseed(tostring(System.getNowTime()):reverse():sub(1, 6))

-- 以下都是断言函数
--如果assertion为false或nil时失败。
function Assert(assertion, msg)
	if msg == nil then msg = "" end
	if not assertion then
		local str = string.format("[XXXXXXXX] %s.%s fail,msg:%s",
			testParams.case or "", testParams.test or "", msg)
		print(str)
		testParams.errorCnt = testParams.errorCnt + 1
	end
end

-- 断言相等,目前只支持数字，boolean，字符串
function Assert_eq(except, actual, msg)
	if msg == nil then msg = "" end
	if type(except) ~= type(actual) or except ~= actual then
		str = string.format("[XXXXXXXX] %s.%s fail,except:%s, actual:%s, msg:%s",
			testParams.case or "", testParams.test or "", tostring(except), tostring(actual), msg)
		print(str)
		testParams.errorCnt = testParams.errorCnt + 1
	end
end

--数字属性的基本检测
function numAttCheck(id, numAtts, conf, enableNil)
	if not enableNil then enableNil = false end
	for _, att in pairs(numAtts) do
		local attValue = conf[att]
		if enableNil == false then
			Assert( attValue ~= nil, string.format("err: id<%s> - att<%s> can't not nil.",id, att))
		end
		if attValue then
			local attNum = tonumber(attValue)
			Assert(attNum, string.format("err: id<%d>- att<%s> is not a number.",id, att))
			if attNum then
				Assert(attNum >= 0, string.format("err: id<%s> - att<%s> can't < 0.",id, att))
			end
		end
	end
end

--必备属性的空检测
function baseAttCheck(id, baseAtts, conf)
	for _, att in pairs(baseAtts) do
		Assert(conf[att], string.format("err: id<%s> - att<%s> can't not nil.",id, att))
	end
end

--检测包含关系
function childTabCheck(id, att, tab, childTab)
	local outList = {}
	for _,cv in pairs(childTab) do
		local flag = false
		for _,v in pairs(tab) do
			if cv == v then
				flag = true
				break
			end
		end
		Assert(flag, string.format("err: id<%s> - att<%s> - %s not in baseTab.",id, att, cv))
	end
	return outList
end

function childTabAttCheck(id, tabAtts, conf)
	for _,v in pairs(tabAtts) do
		local childTab = conf[v.name]
		if childTab then
			childTabCheck(id, v.name, v.range, childTab)
		end
	end
end

--数字属性的范围检测
function numAttRangeCheck(id, rangeAtts, conf)
	local minMaxSearch = algorithm.minMaxSearch
	for _, att in pairs(rangeAtts) do
		local attValue = conf[att.name]
		local attNum = tonumber(attValue)
		if attNum then
			if att.range then
				local flag = false
				for _, v in pairs(att.range) do
					if attNum == v then
						flag = true
						break
					end
				end
				if false == flag then
					--local rmin, rmax = minMaxSearch(att.range)
					Assert(false, string.format("err: id<%s> - att<%s> not in range.", id, att.name))
				end
			else
				Assert(attNum >= att.min, string.format("err: id<%s>- att<%s> < %d.", id, att.name, att.min))
				Assert(attNum <= att.max, string.format("err: id<%s>- att<%s> > %d.", id, att.name, att.max))
			end
		end
	end
end

--检测引用类型是否存在
function refAttCheck(id, refAtts, conf, enableNil)
	for _, att in pairs(refAtts) do
		if not enableNil then enableNil = false end
		if enableNil ~= false then
			Assert(conf[att], string.format("err: id<%s> - att<%s> can't not nil.", id, att))
		end
	end
end

-- 判断配置的物品id对不对
function itemIdCheck(id, item_id)
	local item_uid = tonumber(item_id)
	if not item_uid then
		Assert(false, string.format("err: id<%s> - item_id<%s> is not a number.", id, item_id))
		return
	end
	local name = Item.getItemName(item_uid)
	Assert(name, string.format("err: id<%s> - item_id<%s> can't find it.", id, item_id))
end

function getArg( ... )
	return arg
end

function runFunc(func , params)
	if not func then return end
	local ret
	if type(params) ~= 'table' then
		ret = getArg(func(params))
	else
		ret = getArg(func(unpack(params)))
	end
	return ret
end

function funcCheck(id, funcAtts, ...)
	for _,v in pairs(funcAtts) do
		--print(string.format("now:Testing [%s].[%s]...",v.caseName,v.func))
		local func = v.func
		--print(func)
		local checkfunc = v.check
		--print(checkfunc)
		local errStr = v.err
		local ret = runFunc(func, ...)
		local ret_check = runFunc(checkfunc, ret)
		Assert(ret_check, errStr)
	end
end

function getRandomOne(tab)
	local count = #tab
	if count == 0 then return end
	local indx = math.random(1, count)
	return tab[indx]
end

local function getFuncEx(func, ap)
	local ap = ap
	return function ( ... )
		func(ap, unpack(arg))
	end
end

-- * myMap 函数,用于初始化环境代码简化
function myMap(func, atts, ...)
	if not atts then
		func()
		return
	end
	--只有一个的时候
	local count = #arg
	for _,p in pairs(atts) do
		if count == 0 then
			func(p)
		else
			local funcEx = getFuncEx(func, p)
			myMap(funcEx, unpack(arg))
		end
	end
end

function print_lua_table(lua_table, indent)
	indent = indent or 0
	for k, v in pairs(lua_table) do
		if type(k) == "string" then
			k = string.format("%q", k)
		end
		local szSuffix = ""
		if type(v) == "table" then
			szSuffix = "{"
		end
		local szPrefix = string.rep("    ", indent)
		formatting = szPrefix.."["..k.."]".." = "..szSuffix
		if type(v) == "table" then
			print(formatting)
			print_lua_table(v, indent + 1)
			print(szPrefix.."},")
		else
			local szValue = ""
			if type(v) == "string" then
				szValue = string.format("%q", v)
			else
				szValue = tostring(v)
			end
			print(formatting..szValue..",")
		end
	end
end

function print_lua_table_init(lua_table)
	if not lua_table then
		print("table is nil!")
		return
	end
	print_lua_table(lua_table)
end

-- * 测试函数组
-- * 提供大部分的基础判定
_G.Assert_num    = numAttCheck
_G.Assert_nil    = baseAttCheck
_G.Assert_sub    = childTabAttCheck
_G.Assert_range  = numAttRangeCheck
_G.Assert_itemId = itemIdCheck
_G.Assert_ref    = refAttCheck
_G.Assert        = Assert
_G.Assert_eq     = Assert_eq

-- * table打印方法，用于调试
-- * 在正式服中失效
table.print = print_lua_table_init



