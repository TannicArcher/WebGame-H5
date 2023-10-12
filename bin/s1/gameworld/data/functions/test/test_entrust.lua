module("test.test_entrust" , package.seeall)
setfenv(1, test.test_entrust)

local entrust = require("systems.entrust.entrustsystem")
require("protocol")

local protocol = EntrustSystemProtocol
local EntrustConf = EntrustConf

local LActor = LActor
local System = System 
local Fuben = Fuben
local LDataPack = LDataPack 

--检查配置表
local function checkTable(tb)
	Assert(type(tb) == type(table), "the param is not table!")
	for k,v in ipairs(tb) do
		if v.fbid == nil
			or v.daycount == nil
			or v.time == nil
			or v.level == nil
			or v.floor == nil
			or v.xb == nil
			or v.yb == nil
			or v.floors == nil then
			Assert(false, "items error") 
		end
	end	
end

local function test_entrust_config()
	print(" TEST :test_entrust_config")
	-- 检查配置表是否为空
	Assert(EntrustConf ~= nil, "EntrustConf is nil !") 
	--检查配置各个子项是否为空
	checkTable(EntrustConf)
end

local function test_assert_entrustOperation(actor, fbid, wtype, times, except)
	--封装包
	local package = LDataPack.test_allocPack()
	LDataPack.writeInt(package, fbid)
	LDataPack.writeByte(package, wtype)
	LDataPack.writeInt(package, times)
	LDataPack.setPosition(package, 0)	

	--记录原来的数据
	local oldBindCoin = LActor.getMoneyCount(actor, mtBindCoin)                            --仙币数量
	local oldYuanbao = LActor.getMoneyCount(actor, mtYuanbao)                              --元宝数量
	--委托操作,延时执行完成委托,不可测试委托仓库数量
	--local oldStoreCnt = LActor.getStoreItemCount(actor,ipEntrust)   --委托仓库数量
	
	-- if fbid 在范围内的话
	-- local oldEnterFubenCnt = Fuben.getEnterCount(actor,fbid)                            --进入副本次数

	local ret = entrust.export_func.entrustOperation(actor,package)
	Assert(ret ~= nil, "test_assert_entrust, ret is null")							       --不允许不返回或者返回nil
	Assert_eq(except, ret, "test_assert_entrust error")   
	

	local idx, conf, info = entrust.export_func.getInfo(actor, fbid)	
	--记录委托后的数据
	local currBindCoin = LActor.getMoneyCount(actor, mtBindCoin)
	local currYuanbao = LActor.getMoneyCount(actor, mtYuanbao)
	--local currEnterFubenCnt = Fuben.getEnterCount(actor,fbid)  
	--local currStoreCnt = LActor.getStoreItemCount(actor,ipEntrust)
	
	if except == ret and ret == true then
		-- 判断元宝、仙币
		if wtype == 0 then
			Assert_eq(conf.xb * times, oldBindCoin - currBindCoin, "entrust succ but mtBindCoin change error")
		else
			Assert_eq(conf.yb * times, oldYuanbao - currYuanbao, "entrust succ but mtYuanbao change error")
		end
		-- 判断委托状态
		local currCount, currState,currOffline,currWtype = System.byteInt32(info.data) --todo
		Assert_eq(1,currState, "entrust succ but state change error")
		-- Assert_eq(times,currEnterFubenCnt - oldEnterFubenCnt, "entrust succ but enterFubernCnt change error")
	else
		Assert_eq(oldBindCoin, currBindCoin, "entrust fail but mtBindCoin change")
		Assert_eq(oldYuanbao, currYuanbao, "entrust fail but mtYuanbao change")
		-- Assert_eq(oldStoreCnt,currStoreCnt, "entrust fail but StoreCnt change")	
	end
end

local function test_assert_entrustFinish(actor,fbid,except)
	--封装包
	local package = LDataPack.test_allocPack()
	LDataPack.writeInt(package, fbid)
	LDataPack.setPosition(package, 0)

	--记录原来的数据
	local oldYuanbao = LActor.getMoneyCount(actor, mtYuanbao)                              --元宝数量
	--立即执行完成委托,可以测试委托仓库数量
	local oldStoreCnt = LActor.getStoreItemCount(actor,ipEntrust)     --委托仓库数量

	local ret = entrust.export_func.entrustFinish(actor,package)
	Assert(ret ~= nil, "test_assert_entrust, ret is null")							       --不允许不返回或者返回nil
	Assert_eq(except, ret, "test_assert_entrust error")   
	if ret~=except then print(string.format("fbid : %d",fbid)) end
	
	--记录委托完成后的数据
	local currYuanbao = LActor.getMoneyCount(actor, mtYuanbao)
	local currStoreCnt = LActor.getStoreItemCount(actor,ipEntrust)
	

	if except == ret and ret == true then
		Assert(oldYuanbao - currYuanbao >= 1, "entrust succ but mtYuanbao change error")
		Assert(currStoreCnt - oldStoreCnt >= 0, "entrust succ but store change error") 
		--print(string.format(" TEST:currStoreCnt - oldStoreCnt -  = %d-%d=%d",currStoreCnt,oldStoreCnt,currStoreCnt - oldStoreCnt))
	else
		Assert_eq(oldYuanbao, currYuanbao, "entrust fail but mtYuanbao change")
		Assert_eq(oldStoreCnt,currStoreCnt, "entrust fail but StoreCnt change")
	end
end

local test_entrust_values = {
	--[6 委托]
	-- fbid, wtype, times ,except	
	--错误值	
	--fbid error
	{1,0,1,false},
	{5,1,1,false},
	{91,0,1,false},
	--wtype error
	{4,3,1,false},
	{65,5,1,false},
	{58,8,1,false},
	--times error
	{66,0,0,false},
	{64,1,-1,false}, --委托小于１
	{8,1,15,false},  --副本剩余次数
	--正确值
	{4,0,1,true},
	{65,1,1,true},
	{58,0,1,true},
}

local test_entrust_tb_fbid = {4,8,58,64,65,66} --副本ID列表
local test_entrust_tb_wtype = {0,1}            --委托类型


local function test_entrust_unit(actor)	
	-- 清除委托仓库
	LActor.cleanDepot(actor,ipEntrust)

	local oldLevel = LActor.getLevel(actor) 			                            --记录原来等级
	LActor.setIntProperty(actor, P_LEVEL,100) 										--设置一个附合的等级
	
	-- 1、通过测试值配置表调用方法，测试输入值出界的情况
	for k,value in ipairs(test_entrust_values) do
		local idx, conf, info = entrust.export_func.getInfo(actor, value[1])		
		if idx ~= nil and conf ~=nil then
			local currCount, currState,currOffline,currWtype = System.byteInt32(info.data) --todo
			info.maxfloor = 0                                                      --通关层数先清零再设置（要不然只能增
			entrust.export_func.setFubenValue(actor, value[1], conf.floor)         --确保通关层数  --todo
			currState = 0														   --确保委托状态为０  
			info.data = System.int32Byte(currCount, currState, currOffline, currWtype) --todo
			--确保委托所需仙币或元宝充足  
			if value[2] == 0 then
				-- 让其仙币足够
				local mymoney = System.getRandomNumber(1000) + conf.xb * value[3]
				LActor.setIntProperty(actor,P_BIND_COIN, mymoney)
			elseif value[2] == 1 then
				-- 让其元宝足够
				local mymoney = System.getRandomNumber(1000) + conf.yb * value[3]
				LActor.setIntProperty(actor,P_YB, mymoney)
			end
			Fuben.setEnterCount(actor, value[1], 0)                               --确保进入副本的次数为0                                      	
		end	
		test_assert_entrustOperation(actor, value[1], value[2],value[3],value[4])
	end


	-- 恢复原来的数据
	LActor.setIntProperty(actor, P_LEVEL, oldLevel)	  


	-- 其他情况满足
	for _,v_fbid in ipairs(test_entrust_tb_fbid) do
		for _,v_wtype in ipairs(test_entrust_tb_wtype) do
			local idx, conf, info = entrust.export_func.getInfo(actor, v_fbid)
			local currCount, currState,currOffline,currWtype = System.byteInt32(info.data) --todo
			-- 2、修改委托状态
			LActor.setIntProperty(actor, P_LEVEL,conf.level + 1)							--设置符合的等级
			LActor.setIntProperty(actor,P_BIND_COIN, conf.xb + 1)                           --设置足够的仙币
			LActor.setIntProperty(actor,P_YB, conf.xb + 1)									--设置足够的元宝
			--确保副本进入次数符合 假设times 为1 并且每次执行前都把进入副本的次数归零
			local times = 1
			Fuben.setEnterCount(actor, v_fbid, 0)
			info.maxfloor = 0                                                               --通关层数先清零再设置（要不然只能增）
			entrust.export_func.setFubenValue(actor, v_fbid, conf.floor)                    --设置符合的通关层数


			local v_state = System.getRandomNumber(3)
			currState = v_state
			info.data = System.int32Byte(currCount, currState, currOffline, currWtype)      --todo
			if v_state == 1 or v_state ==2 then	
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,false) 
			elseif v_state == 0 then
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,true)
			end 

			-- 3、测试等级不足情况
			LActor.setIntProperty(actor,P_BIND_COIN, conf.xb + 1)                           --设置足够的仙币
			LActor.setIntProperty(actor,P_YB, conf.xb + 1)									--设置足够的元宝
			--确保副本进入次数符合 假设times 为1 并且每次执行前都把进入副本的次数归零
			times = 1
			Fuben.setEnterCount(actor, v_fbid, 0)
			info.maxfloor = 0                                                               --通关层数先清零再设置（要不然只能增）
			entrust.export_func.setFubenValue(actor, v_fbid, conf.floor)                    --设置符合的通关层数
			currState = 0
	 	info.data = System.int32Byte(currCount, currState, currOffline, currWtype)          --todo

			local succ = System.getRandomNumber(2)
			if succ == 0 then
				local randLevel = System.getRandomNumber(conf.level - 1) + 1
				LActor.setIntProperty(actor, P_LEVEL,randLevel)
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,false)
			else
				LActor.setIntProperty(actor, P_LEVEL,conf.level + 1)
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,true)
			end

			-- 4、修改进入副本次数
			LActor.setIntProperty(actor, P_LEVEL,conf.level + 1)							--设置符合的等级
			LActor.setIntProperty(actor,P_BIND_COIN, conf.xb + 1)                           --设置足够的仙币
			LActor.setIntProperty(actor,P_YB, conf.xb + 1)									--设置足够的元宝
			info.maxfloor = 0                                                               --通关层数先清零再设置（要不然只能增）
			entrust.export_func.setFubenValue(actor, v_fbid, conf.floor)                    --设置符合的通关层数
			currState = 0
			info.data = System.int32Byte(currCount, currState, currOffline, currWtype)      --todo
			times = 1

			succ = System.getRandomNumber(2)
			if succ == 0 then
				Fuben.setEnterCount(actor, v_fbid, conf.daycount) 
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,false)
				Fuben.setEnterCount(actor, v_fbid, 0) 
			else
				Fuben.setEnterCount(actor, v_fbid, conf.daycount-times) 
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,true)
				Fuben.setEnterCount(actor, v_fbid, 0) 
			end

			-- 5、修改通关层数
			LActor.setIntProperty(actor, P_LEVEL,conf.level + 1)							--设置符合的等级
			LActor.setIntProperty(actor,P_BIND_COIN, conf.xb + 1)                           --设置足够的仙币
			LActor.setIntProperty(actor,P_YB, conf.xb + 1)									--设置足够的元宝
			currState = 0
			info.data = System.int32Byte(currCount, currState, currOffline, currWtype)      --todo
			times = 1
			Fuben.setEnterCount(actor, v_fbid, 0)

			succ = System.getRandomNumber(2)
			if succ == 0 and conf.floor ~= 0 then
				local randFloor = System.getRandomNumber(conf.floor -1 )
				info.maxfloor = 0
				entrust.export_func.setFubenValue(actor, v_fbid, randFloor)                 --设置通关层数 < 所需要最大的通关层数 6
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,false)
			else
				info.maxfloor = 0
				entrust.export_func.setFubenValue(actor, v_fbid, conf.floor)                --设置通关层数 > 所需要最大的通关层数 6
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,true)
			end

			-- 6、先清空昨天的仓库
			-- 7、修改拥有的元宝、仙币
			LActor.setIntProperty(actor, P_LEVEL,conf.level + 1)							--设置符合的等级
			times = 1
			Fuben.setEnterCount(actor, v_fbid, 0)
			info.maxfloor = 0                                                               --通关层数先清零再设置（要不然只能增）
			entrust.export_func.setFubenValue(actor, v_fbid, conf.floor)                    --设置符合的通关层数
			currState = 0
			info.data = System.int32Byte(currCount, currState, currOffline, currWtype)      --todo

			succ = System.getRandomNumber(2)
			if succ == 1 then
				if v_wtype == 0 and conf.xb ~=0 then
					-- 让其仙币不够					
					local mymoney = System.getRandomNumber(conf.xb * times) --如果假设times 为1则进入副本次数是满足的
					LActor.setIntProperty(actor,P_BIND_COIN, mymoney)
					test_assert_entrustOperation(actor, v_fbid, v_wtype,times,false)
				elseif v_wtype == 1 and conf.yb~=0 then
					-- 让其元宝不够
					local mymoney = System.getRandomNumber(conf.yb * times)
					LActor.setIntProperty(actor,P_YB, mymoney)
					test_assert_entrustOperation(actor, v_fbid, v_wtype,times,false)
				else
					test_assert_entrustOperation(actor, v_fbid, v_wtype,times,true)
				end
			else
				if v_wtype == 0 then
					-- 让其仙币足够
					local mymoney = System.getRandomNumber(1000) + conf.xb * times
					LActor.setIntProperty(actor,P_BIND_COIN, mymoney)
				elseif v_wtype == 1 then
					-- 让其元宝足够
					local mymoney = System.getRandomNumber(1000) + conf.yb * times
					LActor.setIntProperty(actor,P_YB, mymoney)
				end
				test_assert_entrustOperation(actor, v_fbid, v_wtype,times,true)
			end		
			
		end
	end


	--测试 方法<委托立即完成>
	for _,v_fbid in ipairs(test_entrust_tb_fbid) do
		local idx, conf, info = entrust.export_func.getInfo(actor, v_fbid)
		local currCount, currState,currOffline,currWtype = System.byteInt32(info.data) --todo
		LActor.setIntProperty(actor,P_YB, 10000)					    			   --设置足够的元宝
		--修改委托状态
		local v_state = System.getRandomNumber(3)
		currState = v_state		
		info.data = System.int32Byte(currCount, currState, currOffline, currWtype)     --todo
		if v_state == 0 and v_state == 2 then
			test_assert_entrustFinish(actor,v_fbid,false)
		elseif v_state == 1 then	
			test_assert_entrustFinish(actor,v_fbid,true) 
		end 		
	end
end


TEST("entrust", "test_entrust_config", test_entrust_config)
TEST("entrust", "test_entrust_unit", test_entrust_unit)

--测试中暴露错误使用……测试完成需屏蔽
--_G.test_unit = test_entrust_unit

