module("test.test_lottery" , package.seeall)
setfenv(1, test.test_lottery)

local lottery = require("systems.lottery.lotterysystem")
local commFun = require("test.test_common")
local actormoney = require("systems.actorsystem.actormoney")
require("protocol")

local protocol = LotterySystemProtocol
local LotteryConf = LotteryConf
local LotterySYConf = LotterySYConf

local LotteryConfig = {}

--根据lottery_type(协议类型)获取配置
local function getConfig(lottery_type)
	if lottery_type == 0 then
		LotteryConfig = LotteryConf
	elseif lottery_type == 1 then
		LotteryConfig = LotterySYConf               
	end	
end

--检查配置表
local function checkTable(tb)
	Assert(type(tb) == type(table), "the param is not table!")
	for i=1, #tb.names do
		if tb.itemId[i] == nil
			or tb.displayItemList[i] == nil
			or tb.openLevel[i] == nil
			or tb.price[i] == nil 
			or tb.names[i] == nil
			or tb.itemList[i] == nil then
			Assert(false, "items error") 
		end
		for j=1,#tb.countConf do
			if tb.countConf[i][j] == nil
				or tb.price[i][j] == nil
				or tb.vipLevel[j] == nil then
				Assert(false,"sub items error")
			end
		end
	end	
end

--判断配置的物品id对不对
local function checkItemId(tb)
	Assert(type(tb) == type(table), "the param is not table!")
	for _,mjItemList in ipairs(tb.displayItemList) do
		for _,mjItem in ipairs(mjItemList) do
			local name = Item.getItemName(mjItem)
			Assert(name ~= nil, string.format("LotteryConf displayItemList:itemid<%d> is null",mjItem)) 
		end
	end
end

--测试配置表
local function test_lottery_config()
	print(" TEST :test_lottery_config")
	-- 检查配置表是否为空
	Assert(LotteryConf ~= nil, "LotteryConfig is nil !") 
	Assert(LotterySYConf ~= nil, "LotterySYConfig is nil !") 

	Assert_eq(3,#LotteryConf.names,"mjCount is error")
	Assert_eq(3,#LotteryConf.countConf[1],"countConf is error")
	Assert_eq(3,#LotteryConf.countConf[2],"countConf is error")
	Assert_eq(3,#LotteryConf.countConf[3],"countConf is error")
	Assert_eq(2,#LotterySYConf.names,"mjCount is error")
	Assert_eq(3,#LotterySYConf.countConf[1],"countConf is error")
	Assert_eq(3,#LotterySYConf.countConf[2],"countConf is error")



	--检查配置各个子项是否为空
	checkTable(LotteryConf)
	checkTable(LotterySYConf)

	-- 判断配置的物品id对不对
	checkItemId(LotteryConf)
	checkItemId(LotterySYConf)
end

-- mj 第几个梦境 
-- ltype 哪种形式的抽奖
-- 协议类型：抽奖 1、十一抽奖 8
local function test_assert_lottery(actor, mj, ltype, lottery_type, except)
	--封装包
	local npack = LDataPack.test_allocPack()
	LDataPack.writeByte(npack, mj)
	LDataPack.writeByte(npack, ltype)
	LDataPack.writeByte(npack, lottery_type)
	LDataPack.setPosition(npack, 0)	

	getConfig(lottery_type)                      --根据lottery_type(协议类型)获取配置
	if lottery_type == 1 then                    --十一抽奖梦境为1
		mj = lottery.getMj()
	end
	
	--记录原来的数据
	local oldMoney = LActor.getMoneyCount(actor, mtYuanbao)                             --元宝数量	
	local oldStoreCnt = LActor.getStoreItemCount(actor,ipLottery)             --抽奖仓库数量	
	local oldBagCnt = LActor.getBagItemCount(actor)	                                    --背包数量
	local oldMjScore = lottery.getMjScore(actor)                                        --获取梦境积分

	--mj 没校验
	--local oldItemCnt =  LActor.getItemCount(actor, LotteryConfig.itemId[mj])          --指定物品的数量

	local ret = lottery.lotteryOpComm(actor,npack)                          			--返回true表示抽奖成功，否则失败
	Assert(ret ~= nil, "test_assert_lottery, ret is null")							    --不允许不返回或者返回nil
	Assert_eq(except, ret, "test_assert_lottery error")     

	--记录抽奖后的数据
	local currMoney = LActor.getMoneyCount(actor, mtYuanbao)	
	local currStoreCnt = LActor.getStoreItemCount(actor,ipLottery)
	local currBagCnt = LActor.getBagItemCount(actor)
	local currMjScore = lottery.getMjScore(actor)

	--如果抽奖成功,测试元宝或物品移动扣除等是否成功
	if except == ret and ret == true then	
		--if ltype == 1 and oldItemCnt > LotteryConfig.countConf[mj][ltype] then
		if ltype ==1 and (oldMoney - currMoney)==0 then
			--扣物品是否正确
			Assert_eq(1, oldBagCnt - currBagCnt, "lottery succ but bag change error")
		else
			--其他情况全部是扣元宝	
			Assert_eq(LotteryConfig.price[mj][ltype], oldMoney - currMoney, "lottery succ but money change error")			
		end		
		--print(string.format(" TEST:oldStoreCnt - currStoreCnt = %d-%d=%d",oldStoreCnt,currStoreCnt,oldStoreCnt-currStoreCnt))
		Assert(currStoreCnt - oldStoreCnt ~= 0, "lottery succ but store change error") 
		Assert_eq(LotteryConfig.mjScore[mj] * LotteryConfig.countConf[mj][ltype],
			currMjScore - oldMjScore,"lottery succ but Score change error")
	else
		Assert_eq(oldMoney, currMoney, "lottery fail but money change")
		Assert_eq(oldStoreCnt, currStoreCnt, "lottery fail but store change")
		Assert_eq(oldBagCnt, currBagCnt, "lottery fail but bag change")
		Assert_eq(oldMjScore,currMjScore,"lottery fail but Score change")
	end
end 

local test_lottery_values = {
	--梦境类型,盗梦类型,抽奖类型,期望返回值
	--<mj(1-3),ltype(1-3),lottery_type(0/1),except(bool)>
	--错误值
	{4, 1, 0,false},	
	{3, 4, 0,false},
	{5, 1, 0,false},
	{6, 3, 0,false},
	{4, 2, 1,false},--todo
	{3, 7, 1,false},
	{9, 1, 6,false},
	--正确值
	{1, 1, 0,true},
	{2, 1, 0,true},
	{1, 1, 1,true},
}


local function test_lottery_unit(actor)
	print("==============TEST:  clear space ==================")
	-- 清除抽奖的仓库
	LActor.cleanDepot(actor,ipLottery)
	-- 要给仙灵结晶，所以背包要保持有空间
	LActor.cleanBag(actor)

	local storeCount = LActor.getStoreCount(actor,ipLottery)   
	local storeItemCount = LActor.getStoreItemCount(actor,ipLottery)   
	local BagCount = LActor.getBagItemCount(actor)	

	print(string.format("storeCount : %d,storeItemCount : %d",storeCount,storeItemCount))
	print(string.format("BagCount   : %d",BagCount))

	--记录原来的数据
	local oldLevel = LActor.getLevel(actor) 			                            --记录原来等级
	local oldVipLevel = LActor.getVIPLevel( actor )            			            --记录原来的Vip等级

	print("=============TEST:  error input value =============")
	--step 1 : 让其他条件满足的情况下的抽奖情况
	LActor.changeMoney( actor, mtYuanbao, 5000, 1, true, "lottery","", "","")       --元宝充足的情况下
	LActor.setIntProperty(actor, P_LEVEL,100) 										--设置一个超过最大等级限制的值 > 65
	LActor.recharge(actor, 1000000)         									    --开启仙尊等级 Vip等级
	-- 通过测试值配置表调用方法，测试输入值出界的情况
	for k,value in ipairs(test_lottery_values) do		
		test_assert_lottery(actor, value[1], value[2], value[3],value[4])
	end

	print("=============TEST:  level is not enough ============")
	--step 2 ：测试<mj,ltype>正确的情况下，等级不满足的情况  
	-- 随机让抽奖成功或者失败
	local flag = System.getRandomNumber(2)
	local lottery_type = 0
	if flag == 1 then
		lottery_type = 0
	else
		lottery_type = 1
	end
	getConfig(lottery_type)

	for i=1,#LotteryConfig.names do
		for j=1,#LotteryConfig.countConf[i] do
			-- mj 和ltype都是对的情况下，检测等级的判断
			local randLevel = System.getRandomNumber(LotteryConfig.openLevel[i] - 1) + 1
			-- 用户随机一个不满足的等级，判断是否程序有判断等级开放条件
			LActor.setIntProperty(actor, P_LEVEL,randLevel)
			test_assert_lottery(actor, i, j, lottery_type,false) 
		end
	end

	--恢复原来的数据
	LActor.changeMoney( actor, mtYuanbao, -5000, 1, true, "lottery","", "","")
	LActor.setIntProperty(actor, P_LEVEL, oldLevel)	   
	--todo 恢复原来的vip等级

	print("=============TEST:  Random circumstances===========")	
	local loopCnt = 0
	-- 仓库有360个空间，而且物品会叠加，如果要放满，估计要运行很久。
	-- 这里很多都是用随机，每种情况应该都会随机到了
	--for i=1,100 do
	while LActor.getStoreRestCount(actor,ipLottery) > 0 do
		loopCnt = loopCnt + 1

		-- 每秒只执行100次循环
		if loopCnt % 50 == 0 then 
			print("lottery system testing....")
			coroutine.yield() 
		end

		-- 使其其他所有条件（等级，vip等）都满足的情况下，测试抽奖逻辑，循环到仓库满为止
		local restcnt = LActor.getStoreRestCount(actor,ipLottery)
		local mj = System.getRandomNumber(3) + 1  
		if lottery_type == 1 then          
			mj = lottery.getMj()
		end
		local countConf = LotteryConfig.countConf[mj]

		-- 调整等级满足条件
		local randLevel = System.getRandomNumber(20) + LotteryConfig.openLevel[mj]
		LActor.setIntProperty(actor, P_LEVEL,randLevel)
		-- 抽奖类型是1-3，3种可能
		-- 如果仓库剩余空间大于50，则3种抽奖随机一个，
		-- 否则看空间是否大于第二种抽奖，类推，这样，仓库空间的条件肯定满足
		local ltype = 1
		for i=#LotteryConfig.countConf[mj],1,-1 do
			if restcnt >= LotteryConfig.countConf[mj][i] then
				ltype = System.getRandomNumber(i) + 1 
				break
			end
		end
		-- 随机让抽奖成功或者失败
		local succ = System.getRandomNumber(2)
		if succ == 1 then
			-- 让其元宝不够
			local mymoney = System.getRandomNumber(LotteryConfig.price[mj][ltype])
			LActor.setIntProperty(actor,P_YB, mymoney)
			if ltype == 1 then
				-- 清除所有的仙灵结晶,让其物品不够
				commFun.test_clearBagItem(actor, LotteryConfig.itemId[mj])
			end
			test_assert_lottery(actor, mj, ltype, lottery_type,false) 
		else
			-- 使其抽奖能成功，给元宝给物品
			local succType = 0	-- 如果ltype==1这个值才有效，表示用1元宝还是用1个星蕴结晶抽奖
			if ltype == 1 then
				succType = System.getRandomNumber(2) + 1
				if succType == 1 then
					-- 用仙灵结晶抽奖
					local xyjj = LActor.getItemCount(actor, LotteryConfig.itemId[mj])
					if xyjj < 1 then
						LActor.addItem(actor, LotteryConfig.itemId[mj], 0, 0, 1, 0)
					end
				end
			end

			local mymoney = 0
			if succType ~= 1 then
				-- 给足够的元宝
				mymoney = System.getRandomNumber(1000) + LotteryConfig.price[mj][ltype]
				LActor.setIntProperty(actor,P_YB, mymoney)
			end			
			-- 成功检查有没有扣元宝或者物品，有没有给到仓库
			test_assert_lottery(actor, mj, ltype, lottery_type,true) 
		end
	end

	-- 仓库满了，测试最后一个情况
	print("===============TEST:  Depot is full==============")
	Assert_eq(0, LActor.getStoreRestCount(actor,ipLottery), "lottery restcount more than 0")
	for i=1,3 do
		for j=1,3 do
			-- mj 和ltype都是对的情况下，检测等级的判断
			local randLevel = LotteryConfig.openLevel[i] + System.getRandomNumber(10) 
			-- 用户随机一个满足的等级
			LActor.setIntProperty(actor, P_LEVEL,randLevel)
			-- 给足够的元宝
			local mymoney = System.getRandomNumber(1000) + LotteryConfig.price[i][j]
			LActor.setIntProperty(actor,P_YB, mymoney)
			test_assert_lottery(actor, i, j, 1,false) 
		end
	end
	--恢复原来的数据
	LActor.setIntProperty(actor, P_LEVEL, oldLevel)	  
end

local function test_sendLotteryLog(actor)
	--封装包
	local npack = LDataPack.test_allocPack()
	LDataPack.writeByte(npack, 0) --抽奖类型 lottery_type
	LDataPack.writeByte(npack, 1) --梦境类型 mj
	LDataPack.setPosition(npack, 0)	
	lottery.sendLotteryLog(actor,npack)
end


--先 hash LotteryConf 中的 itemList 
--以 itemid 为 key ,present为value
local function hashLotteryConf()
	local HashLotteryConf = {} 
	for _,subitemlist in ipairs(LotteryConf.itemList[1]) do  --限制为星蕴梦境
		local hashitemid = subitemlist.itemid
		HashLotteryConf[hashitemid] = subitemlist.present
		--print("============== "..hashitemid.."  "..HashLotteryConf[hashitemid])
	end
	return HashLotteryConf
end

--哈希商城配置
local HashLotteryConf = hashLotteryConf()


--测试抽奖概率
local function test_lottery_chance(actor)
	--概率基数 10000
	--测试次数 100000 次
	--测试误差 50 次
	local baseCnt = 10000
	local testCnt = 10000
	local testRate = baseCnt / testCnt
	local testDviation = 50
	--梦境抽奖物品记录表  存储各物品id , 及其数量
	local lottery_item = {}	
	--测试环境〈满足所有条件〉暂限定于〈普通抽奖〉
	print("==============TEST:  test_lottery_chance ==================")	

	--清除抽奖的仓库
	LActor.cleanDepot(actor,ipLottery)
	local storeItemCount = LActor.getStoreItemCount(actor,ipLottery)  
	Assert_eq(0, storeItemCount, "test_assert_lottery cleanDepot error")

	--等级保证足够(固定不变的)
	LActor.setIntProperty(actor, P_LEVEL,100) 										--设置一个超过最大等级限制的值 > 65
	LActor.recharge(actor, 1000000)         									    --开启仙尊等级 Vip等级
	for i=1,testCnt do 

		-- 每秒只执行100次循环
		if i % 100 == 0 then 
			print("lottery system testing....")
			coroutine.yield() 
		end

		if LActor.getMoneyCount(actor,mtYuanbao) < 2000 then                        
			--元宝保证足够 > 所需最大元宝数 1350 <根据配置>
			LActor.changeMoney( actor, mtYuanbao, 1000000, 1, true, "lottery","", "","")       --元宝充足的情况下
		end

		--do something 
		local mj = 1 --限定梦境类型为星蕴梦境
		local ltype=1
		--封装包
		local npack = LDataPack.test_allocPack()
		LDataPack.writeByte(npack, mj)
		LDataPack.writeByte(npack, ltype)
		LDataPack.writeByte(npack, 0)
		LDataPack.setPosition(npack, 0)	

		--执行抽奖
		local ret = lottery.lotteryOpComm(actor,npack)                          			--返回true表示抽奖成功，否则失败
		Assert(ret ~= nil, "test_assert_lottery, ret is null")							    --不允许不返回或者返回nil
		Assert_eq(true, ret, "test_assert_lottery error")  
		--do something 
		--在清除仓库前，记录仓库物品及其各自的数量到 表 item_lottery 中
		--获得该物品容器的所有物品
		local itemList = Item.getItemListByPos(actor, ipLottery)
		Assert(itemList ~= nil, "test_lottery_lottery getItemListByPos error")

		for _,item_ptr in ipairs(itemList) do
			local depot_itemid = Item.getItemId(item_ptr)     --仓库中X物品ID
			local depot_count  = Item.getItemCount(item_ptr)  --仓库中X物品数量
			
			if lottery_item[depot_itemid] == nil then 
				lottery_item[depot_itemid] = 0
			end
			lottery_item[depot_itemid] = lottery_item[depot_itemid] + depot_count						
		end

		--清除抽奖的仓库
		-- LActor.cleanDepot(actor,ipLottery)
		local storeItemCount = LActor.getStoreItemCount(actor,ipLottery)  
		Assert_eq(0, storeItemCount, "test_assert_lottery cleanDepot error")
	end

	--判断概率是否在允许的范围内
	for k,v in pairs(lottery_item) do
		--允许误差 testDviation 
		print("itemid "..k.." itemcount "..v.." config_present "..HashLotteryConf[k])
		Assert(math.abs((v * testRate) - HashLotteryConf[k]) < testDviation , "chance test error")
	end		
end

-- 当需要测试时调用
TEST("lottery", "test_lottery_config", test_lottery_config)
TEST("lottery", "test_lottery_unit", test_lottery_unit, true)
TEST("lottery", "test_lottery_chance", test_lottery_chance, true)

