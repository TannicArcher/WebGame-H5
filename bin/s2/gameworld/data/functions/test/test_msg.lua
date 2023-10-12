module("test.test_msg" , package.seeall)
setfenv(1, test.test_msg)
--[[
	消息系统单元测试
--]]

local msgsystem = require("systems.msg.msgsystem")
local checkFunc = require("test.assert_func")
local common 	= require("test.test_common")

local TEST 	 	= _G.TEST
local System   	= System
local LActor   	= LActor
local Item 		= Item

local LDataPack   = LDataPack
local writeByte   = LDataPack.writeByte
local writeWord   = LDataPack.writeWord
local writeInt    = LDataPack.writeInt
local writeInt64  = LDataPack.writeInt64
local writeString = LDataPack.writeString
local writeData   = LDataPack.writeData

local readByte    = LDataPack.readByte
local readWord 	  = LDataPack.readWord
local readInt  	  = LDataPack.readInt
local readString  = LDataPack.readString
local readData    = LDataPack.readData

-- ************ BEGIN 离线消息类型枚举 BEGIN ********* --
local mtNoType       = 0 --无
local mtAddItem      = 1 --物品
local mtChangeMoney  = 2 --金钱
-- ***不发送到客户端的加在1024以后***
local mtMessageCount = 1024
-- ************ END   离线消息类型枚举 END   ********* --

-- 物品集合，dup表示是否可以叠加
local StdItems = 
{
	{id = 9100, dup = 0}, {id = 9110, dup = 0}, {id = 9111, dup = 0}, {id = 9122, dup = 0},
	{id = 9123, dup = 0}, {id = 9124, dup = 0}, {id = 9130, dup = 0}, {id = 9131, dup = 0},
	{id = 9132, dup = 0}, {id = 9133, dup = 0},
}

-- Comments: 发送指定内容的消息
function handleSend(actor, msg_type, arg_cnt, ...)
	if not actor or not msg_type or not arg_cnt then return false end
	if (#arg) ~= (arg_cnt * 2) then return  false end

	local npack = LDataPack.allocPacket()
	writeData(npack, 3, dtWord, msg_type, dtString, "", dtString, "")

	if arg_cnt > 0 then
		for i = 1, (arg_cnt * 2 - 1), 2 do
			writeData(npack, 1, arg[i], arg[i + 1])
		end
	end

	System.sendOffMsg(LActor.getActorId(actor), "", "", 0, npack)
end

-- Comments: 验证是否接受到指定内容的消息
function isRecTheMsg(actor, idx, msg_type, arg_cnt, args)
	if not actor or not idx or not msg_type or not arg_cnt or not args then return false end
	if (#args) ~= (arg_cnt * 2) then return  false end

	local msgid, offmsg = LActor.getOffMsg(actor, idx)
	if not msgid or not offmsg then return false end

	local msgtype = readData(offmsg, 3, dtWord, dtString, dtString)
	if msgtype ~= msg_type then return false end

	if arg_cnt > 0 then
		for i = 1, (arg_cnt * 2 - 1), 2 do
			if readData(offmsg, 1, args[i]) ~= args[i + 1] then
				return false
			end
		end
	end

	return true
end

-- Comments: 读取物品消息 主要测试消息接受，处理，删除
function handleReceive(actor, old_max_idx, msg_type, arg_cnt, ...)
	if not actor or not old_max_idx or not msg_type or not arg_cnt then return end

	-- 协程异步接收离线消息 
	local lmtcnt, idx = 0, -1
	while lmtcnt < 600 do
		lmtcnt = lmtcnt + 1

	 	coroutine.yield()
		
		local new_max_idx = LActor.getOffMsgCnt(actor)
		if new_max_idx > old_max_idx then 
			for i = old_max_idx, new_max_idx - 1 do
				if isRecTheMsg(actor, i, msg_type, arg_cnt, arg) then
					idx = i
					break
				end
			end
			
			if idx ~= -1 then
				break
			end
			old_max_idx = new_max_idx
		end
	end

	if lmtcnt >= 600 then  Assert(false, "handleReceive.send msg is err") return end

	-- 处理离线消息
	local msgid, offmsg = LActor.getOffMsg(actor, idx)
	local handle_ret = msgsystem.handleMsg(actor, idx, msg_type, offmsg)

 	-- 消息是否删除
 	local msg_idx = LActor.getOffMsgIndex(actor, msgid)
	if handle_ret then
		Assert(msg_idx < 0, "handleReceive.del msg is err")
	else
		Assert(msg_idx >= 0, "handleRec.del msg is err")
	end

	-- 最后从数据库中删除测试消息
	if msg_idx > 0 then  LActor.deleteOffMsg(actor, msg_idx) return end
end

-----------------Begin 物品消息 Begin------------------

-- Comments: 随机一个物品
local function randomItem()
	return StdItems[System.getRandomNumber(#StdItems) + 1]
end

-- Comments: 随机物品，并用随机出的物品填充玩家背包内的grid_cnt个格子
local function fillUpBackPack(actor, grid_cnt)
	if not actor or not grid_cnt then return false end

	while Item.getBagUsedGridCnt(actor) < grid_cnt do
		--随机物品
		local item = randomItem()
		if not item then return false end
		local id = item.id

		--随机所占最大的格子
		local max_rand_grid = grid_cnt - Item.getBagUsedGridCnt(actor)
		local rand_grid = (System.getRandomNumber(max_rand_grid) % 3 + 1) -- 最多占3个格子，更加真实

		--根据最大的格子求出最大可填充物品数量
		local dup = item.dup
		if dup < 1 then dup = 1 end
		local max_count = rand_grid * dup

		--随机最终数量
		local count = System.getRandomNumber(max_count) + 1

		--填充背包
		LActor.addItem(actor, id, 0, 0, count, 1,"test_items_msg",1) 
	end

	return true
end

-- Comments: 物品消息测试
local function test_item_msg(actor)

	-- 测试正常离线消息，数量是否正确
	for i = 1, 500 do
		print("test_item_msg in not full case：NO."..i)
		
		-- 清空背包
		LActor.cleanBag(actor)
		
		-- 随机填充背包内物品
		local actor_max_grid = Item.getBagMaxGrid(actor)
		local empty_grid	 = System.getRandomNumber(actor_max_grid) + 1
		fillUpBackPack(actor, actor_max_grid - empty_grid)
		Assert_eq(empty_grid, Item.getBagEmptyGridCount(actor), "err random item")

		-- 随机确定离线消息的物品
		local item = randomItem()
		if not item then Assert(false, "random item is err") return end
		local item_id  = item.id

		-- 随机确定离线消息的物品数量
		if item.dup > 1 then
			rand_max_cnt = item.dup * empty_grid
		else
			rand_max_cnt = empty_grid
		end
		local item_cnt = System.getRandomNumber(rand_max_cnt) + 1

		-- 发送并处理物品消息
		local old_tot_cnt = Item.getBagItemCount(actor)
		local old_cnt     = Item.getBagCntByItemID(actor, item_id)
		handleSend(actor, mtAddItem, 2, dtInt, item_id, dtInt, item_cnt)
		handleReceive(actor, LActor.getOffMsgCnt(actor), mtAddItem, 2, dtInt, item_id, dtInt, item_cnt)
		local new_tot_cnt = Item.getBagItemCount(actor)
		local new_cnt     = Item.getBagCntByItemID(actor, item_id)

	    -- 测试验证
	    Assert_eq(old_cnt + item_cnt, new_cnt, "err item msg in nor")
	    Assert_eq(old_tot_cnt + item_cnt, new_tot_cnt, "err item msg in nor")
	end

	-- 测试背包空间不足的情况
	for i = 1, 500 do
		print("test_item_msg in full case：NO."..i)

		-- 清空背包
		LActor.cleanBag(actor)

		-- 随机填充背包内物品
		local actor_max_grid = Item.getBagMaxGrid(actor)
		local count	 = System.getRandomNumber(actor_max_grid) + 1
		fillUpBackPack(actor, actor_max_grid - count)

		-- 随机离线消息物品
		local item = randomItem()
		if not item then Assert(false, "random item is err") return end
		local item_id  = item.id

		-- 确定消息内含有物品数量
		local item_cnt = 0
		if item.dup > 1 then
			local old_cnt = Item.getBagCntByItemID(actor, id)
			local left_item_cnt = 0
			if old_cnt % item.dup ~= 0 then left_item_cnt = item.dup - old_cnt % item.dup end
			item_cnt = count * item.dup + left_item_cnt
		end
		item_cnt = count + System.getRandomNumber(1000) + 1

		-- 发送并读取消息
		local old_cnt = Item.getBagEmptyGridCount(actor)
		handleSend(actor, mtAddItem, 2, dtInt, item_id, dtInt, item_cnt)
		handleReceive(actor, LActor.getOffMsgCnt(actor), mtAddItem, 2, dtInt, item_id, dtInt, item_cnt)
		local new_cnt = Item.getBagEmptyGridCount(actor)

	    -- 测试验证 物品总数量不变
	    Assert_eq(old_cnt, new_cnt,"err item msg in full")
	end
end
-----------------End  物品消息  End------------------

-----------------Begin  金钱消息  Begin------------------

-- Comments: 金钱消息测试
function test_money_msg( actor )
	for i = 1, 500 do
		print("test_money_msg case：NO."..i)

		-- 随机货币类型
		local money_type  = System.getRandomNumber(mtMoneyTypeCount)

		-- 随机货币改变数量
		local old_amounts = LActor.getMoneyCount(actor, money_type)
		local chg_amounts = System.getRandomNumber(2147483647) + 1 - old_amounts --防止溢出 2147483647为32位无符号整数的上线
		--local real_chg_amounts = LActor.getFcmExpMoneyRate(actor, money_type, chg_amounts) --防沉迷收益衰减

		-- 发送并处理金钱消息
		local except_amounts = old_amounts
		handleSend(actor, mtChangeMoney, 2, dtByte, money_type, dtInt, chg_amounts)
		handleReceive(actor, LActor.getOffMsgCnt(actor), mtChangeMoney, 2, dtByte, money_type, dtInt, chg_amounts)
		local real_amounts   = LActor.getMoneyCount(actor,money_type)

		-- 测试验证玩家实际获得货币数量
	    Assert_eq(except_amounts, real_amounts,"err money msg")
	end
end

-----------------End  金钱消息  End------------------


-- Comments: 主测试函数
function test_msg(actor)
	--测试物品消息
	test_item_msg(actor)

	--测试金钱消息
	test_money_msg(actor)
end

TEST("msg", "test_msg",  test_msg,  true)
