module("test.test_petcross" , package.seeall)
setfenv(1, test.test_petcross)

local petcross = require("systems.petcross.petcrosssystem")
require("protocol")

local protocol = EntrustSystemProtocol
local LActor = LActor
local System = System 
local LDataPack = LDataPack 

local PetCrossConf = petCrossConf


--检查配置表
local function checkTable(tb)
	Assert(type(tb) == type(table), "the param is not table!")
	
end

local function test_petcross_config()
	print(" TEST :test_petcross_config")
	-- 检查配置表是否为空 
	--检查配置各个子项是否为空
end

--测试购买闯关次数
local function test_assert_buyCrossTimes(actor,except)
	local var = LActor.getSysVar(actor)
	if var == nil then return false end
	local petCrossInfo = petCrossInfoInit(var)				                               --获取宠物闯关相关信息
	--执行前记录原来的数据
	local oldYuanbao = LActor.getMoneyCount(actor, mtYuanbao)                              --元宝数量	
	local oldBuyTimes = petCrossInfo.buyTimes                                              --获取购买的闯关次数

	--执行购买闯关次数逻辑
	local ret = petcross.export_func.buyCrossTimes(actor)
	Assert(ret ~= nil, "test_assert_petcross, ret is null")							       --不允许不返回或者返回nil
	Assert_eq(except, ret, "test_assert_petcross error")    
	
	--执行结束后
	local currYuanbao = LActor.getMoneyCount(actor, mtYuanbao)
	local currBuyTimes = petCrossInfo.buyTimes 

	--判断 元宝是否被正确扣除
	--判断购买的闯关次数是否+1
	if except == ret and ret == true then
		Assert_eq(1,currBuyTimes - oldBuyTimes,"buyCrossTimes succ but buyTimes change error" )
		Assert_eq(PetCrossConf.buyTimesCost[oldBuyTimes + 1], 
			oldYuanbao - currYuanbao, "buyCrossTimes succ but mtYuanbao change error")
	else
		Assert_eq(oldBuyTimes,currBuyTimes,"buyCrossTimes succ but buyTimes change error" )
		Assert_eq(oldYuanbao, currYuanbao, "buyCrossTimes fail but mtYuanbao change")
	end
end

--测试开始闯关
local function test_assert_beginCross(actor, crossIndex, petId, except)
	--封装包
	local package = LDataPack.test_allocPack()
	LDataPack.writeByte(package, crossIndex)	--闯关副本索引
	LDataPack.writeByte(package, petId)			--出战宠物id
	LDataPack.setPosition(package, 0)	

	--执行开始闯关逻辑
	local ret = petcross.beginCross(actor,package)
	print(" TEST : "..tostring(ret))
end

local function test_unit(actor)
	test_beginCross(actor, 1, 1, true)	
end


TEST("petcross", "test_petcross_config", test_petcross_config)


--测试中暴露错误使用……测试完成需屏蔽







