module("test.test_userbag" , package.seeall)
setfenv(1, test.test_userbag)
--[[
	背包系统单元测试
--]]

local userbagsys = require("systems.userbagsystem.userbagsystem")
local checkFunc  = require("test.assert_func")
local common     = require("test.test_common")

local TEST 	 	 = _G.TEST
local System     = System
local LActor   	 = LActor
local Item 		 = Item

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

-- 物品集合，dup表示是否可以叠加
local StdItems = 
{
	{id = 9100, dup = 0}, {id = 9110, dup = 0}, {id = 9111, dup = 0}, {id = 9122, dup = 0},
	{id = 9123, dup = 0}, {id = 9124, dup = 0}, {id = 9130, dup = 0}, {id = 9131, dup = 0},
	{id = 14405, dup = 99}, {id = 14407, dup = 99}, {id = 14408, dup = 99}, 
}

-- Comments: 随机一个物品
function randomItem()
	return StdItems[System.getRandomNumber(#StdItems) + 1]
end

-- Comments: 构造测试背包环境
function initUserBag(actor, dupItems, min_used_cnt, min_item_cnt)
	if not actor or not dupItems or #dupItems <= 0 or not min_used_cnt or not min_item_cnt then return end
	if min_used_cnt > Item.getBagMaxGrid(actor) then return end

	-- 随机一个测试物品
	local iteminfo = dupItems[System.getRandomNumber(#dupItems) + 1]
	if min_item_cnt > iteminfo.dup then return end
	
	-- 清空背包
	LActor.cleanBag(actor)

	-- 记录背包所有物品ID和数量
	local bagItem = {}
	
	-- 随机测试物品ID和数量
	local max_grid_cnt  = Item.getBagMaxGrid(actor)
	local used_grid_cnt = System.getRandomNumber(max_grid_cnt - min_used_cnt + 1) + min_used_cnt
	for i = 1 , used_grid_cnt do
		table.insert(bagItem, {id = iteminfo.id, count = System.getRandomNumber(iteminfo.dup -  min_item_cnt + 1) +  min_item_cnt} )
	end

	-- 剩余位置随机填充N个格子
	local fill_grid_cnt = 0
	if max_grid_cnt > used_grid_cnt then
		fill_grid_cnt = System.getRandomNumber(max_grid_cnt - used_grid_cnt) + 1
		if fill_grid_cnt > 0 then
			for i = 1 , fill_grid_cnt do
				local iteminfo = randomItem()
				if iteminfo and iteminfo.id and iteminfo.dup then 
					table.insert(bagItem, {id = iteminfo.id, count = System.getRandomNumber(iteminfo.dup) + 1} )
				end
			end
		end
	end

	-- 利用shuffle洗牌,打乱顺序
	for i = #bagItem, 1, -1 do
		local rand_idx = System.getRandomNumber(i) + 1
		bagItem[i], bagItem[rand_idx] = bagItem[rand_idx], bagItem[i]
	end

	-- 填充玩家背包
	for _, iteminfo in ipairs(bagItem) do
		if iteminfo and iteminfo.id and iteminfo.count then
			LActor.addItem(actor, iteminfo.id, 0, 0, iteminfo.count, 1,"initUserBag",1, false) 
		end
	end

	return iteminfo
end

-- Comments: 随机获取一个数
function getOutOfIntervalNum(beg_num)
	if System.getRandomNumber(2) == 1 then
		return System.getRandomNumber(2147483647 - beg_num + 1) +  beg_num 
	else
		return System.getRandomNumber(2147483649) * -1 
	end
end

-- Comments: 随机获得一系列物品集合中的一个
function getRandItemPtrByID(actor, item_id)
	local itemlist = Item.getItemListByID(actor, item_id)
	if #itemlist > 0 then
		return itemlist[System.getRandomNumber(#itemlist) + 1]
	end
	return
end

-- Comments: 获得一个错误Guid
function getErrItemGuid(actor)
	for i = 1, 1000 do
		local err_guid = System.getRandomNumber(2147483647) + 1
		if not Item.getItemPtrByGuid(actor, err_guid) then
			return err_guid
		end
	end
	return -1
end

-- Comments: 统计玩家物品类型和总数
function getItemList(actor, item_pos)
	if not actor or not item_pos then return end

	local result_list = {}
	local item_list = Item.getItemListByPos(actor, item_pos)
	if item_list == nil then return result_list	end

	for _, item_ptr in ipairs(item_list) do
		local itemid = Item.getItemId(item_ptr)
		local count  = Item.getItemCount(item_ptr)

		result_list[itemid] = (result_list[itemid] or 0) + count					
	end

	return result_list
end

-- Comments: 对比两个表的物品类型和数量是否一致
function isSameItemList(fir_list, sec_list)
	if type(fir_list) ~= 'table' or type(sec_list) ~= 'table' then return false end

	for id, cnt in pairs(fir_list) do
		if cnt > 0 then
			if sec_list[id] == nil then
				return false
			end
			if sec_list[id] ~= cnt then
				return false
			end
		end
	end

	for id, cnt in pairs(sec_list) do
		if cnt > 0 then
			if fir_list[id] == nil then
				return false
			end
			if fir_list[id] ~= cnt then
				return false
			end
		end
	end

	return true
end
-----------------------------------------BEGIN 拆分物品 BEGIN-----------------------------------------

-- 拆分和叠加物品的集合，dup表示是否可以叠加
local DupItems = 
{
	{id = 11200, dup = 99}, {id = 14400, dup = 99}, {id = 14401, dup = 99}, 
	{id = 14402, dup = 99}, {id = 14403, dup = 99}, {id = 14404, dup = 99}, 
	{id = 14409, dup = 99}, {id = 14410, dup = 99}, {id = 29660, dup = 200},
}

-- Comments: 物品拆分
function handleSplitItems(actor, guid, cnt)
	local packet = LDataPack.test_allocPack()
	LDataPack.writeInt64(packet, guid)
	LDataPack.writeWord(packet, cnt)
	LDataPack.setPosition(packet, 0)
	userbagsys.bagSplit(actor, packet)
end

-- Comments: 物品拆分测试
function test_split_item(actor)
	for test_times = 1, 1000 do
		print("test_split_item case：NO."..test_times)
		if test_times % 10 == 0 then coroutine.yield() end

		-- 构造背包环境
		local split_item = initUserBag(actor, DupItems, 1, 1)
		Assert(split_item,"split:err test_bag initUserBag")
		
		-- 随机获取测试数据
		local item_ptr  = getRandItemPtrByID(actor, split_item.id)
		if item_ptr then
			-- 记录原来数量
			local item_guid = Item.getItemGuid(item_ptr)
			local item_cnt  = Item.getItemCount(item_ptr)
			local item_list = getItemList(actor, ipBag)
			
			local old_used_grid = Item.getBagUsedGridCnt(actor)

			-- 1 错误Guid或者数量的情况
			handleSplitItems(actor, getErrItemGuid(actor), getOutOfIntervalNum(1))
			Assert_eq(old_used_grid, Item.getBagUsedGridCnt(actor), string.format("split: grid cnt is chg itemid = %d, in %d", split_item.id, test_times))
			Assert(isSameItemList(getItemList(actor, ipBag), item_list), string.format("split: test_item is change itemid = %d, in %d", split_item.id, test_times))

			-- 2 正确Guid和数量的情况
			local chg_cnt = System.getRandomNumber(item_cnt - 1)  + 1

			-- 当没有空格
			local except_used_grid = old_used_grid
			local except_item_cnt  = item_cnt
			-- 当有空格
			if Item.getBagEmptyGridCount(actor) > 0 and item_cnt > 1 then
				except_used_grid = old_used_grid + 1
				except_item_cnt  = item_cnt - chg_cnt
			end

			handleSplitItems(actor, item_guid, chg_cnt)

			Assert_eq(except_used_grid, Item.getBagUsedGridCnt(actor), string.format("split: grid err change itemid = %d, in %d", split_item.id, test_times))
			Assert_eq(except_item_cnt, Item.getItemCount(item_ptr), string.format("split: item_cnt err change itemid = %d, in %d", split_item.id, test_times))
			Assert(isSameItemList(getItemList(actor, ipBag), item_list), string.format("split: test_item cnt is change itemid = %d, in %d", split_item.id, test_times))
		end
	end
end

-----------------------------------------END 拆分物品 END-----------------------------------------

-----------------------------------------BEGIN 叠加物品 BEGIN-----------------------------------------
-- Comments: 物品叠加处理
function handleMergeItems(actor, src_guid, des_guid)
	local packet = LDataPack.test_allocPack()
	LDataPack.writeInt64(packet, src_guid)
	LDataPack.writeInt64(packet, des_guid)
	LDataPack.setPosition(packet, 0)
	userbagsys.bagMerge(actor, packet)
end

-- Comments: 物品叠加测试
function test_merge_item(actor)
	for test_times = 1, 1000 do
		print("test_merge_item case：NO."..test_times)
		if test_times % 10 == 0 then coroutine.yield() end

		-- 构造背包环境
		local merge_item = initUserBag(actor, DupItems, 2, 1)
		Assert(merge_item,"merge err test_bag initUserBag")

		-- 记录原数据
		local item_list = getItemList(actor, ipBag)
		local old_used_grid = Item.getBagUsedGridCnt(actor)

		-- 1 错误的des_guid和scr_guid情况下
		handleMergeItems(actor, getErrItemGuid(actor), getErrItemGuid(actor))
		Assert_eq(old_used_grid, Item.getBagUsedGridCnt(actor),"merge : grid cnt is change")
		Assert(isSameItemList(getItemList(actor, ipBag), item_list),"merge : test_item cnt is change")

		local src_item = getRandItemPtrByID(actor, merge_item.id)
		local des_item = getRandItemPtrByID(actor, merge_item.id)
		if src_item and des_item then
			-- 2 错误des_guid或者scr_guid情况下
			handleMergeItems(actor, Item.getItemGuid(src_item), getErrItemGuid(actor))
			handleMergeItems(actor, getErrItemGuid(actor),  Item.getItemGuid(des_item))
			Assert_eq(old_used_grid, Item.getBagUsedGridCnt(actor), "merge: des_guid or scr_guid: grid cnt is change")
			Assert(isSameItemList(getItemList(actor, ipBag), item_list), "merge: err des_guid or scr_guid: test_item cnt is change")

			if src_item == des_item then
				-- 3 des_guid和scr_guid相等情况下							
				handleMergeItems(actor, Item.getItemGuid(src_item), Item.getItemGuid(des_item))
				Assert_eq(old_used_grid, Item.getBagUsedGridCnt(actor), "merge in des_guid = scr_guid: grid cnt is change")
				Assert(isSameItemList(getItemList(actor, ipBag), item_list), "merge in des_guid = scr_guid: test_item cnt is change")
			else
				-- 4 正确的des_guid和scr_guid情况下	
				local except_used_grid = old_used_grid
				if merge_item.dup - Item.getItemCount(des_item) >= Item.getItemCount(src_item) then
					except_used_grid = old_used_grid - 1
				end

				handleMergeItems(actor, Item.getItemGuid(src_item), Item.getItemGuid(des_item))
				
				Assert_eq(except_used_grid, Item.getBagUsedGridCnt(actor),"merge: grid is not change")			
				Assert(isSameItemList(getItemList(actor, ipBag), item_list), "merge: test_item cnt is change")
			end
		end
	end
end

-----------------------------------------END 叠加物品 END-----------------------------------------

-----------------------------------------BEGIN 使用一个物品 BEGIN-----------------------------------------

-- 使用物品
local useItems = 
{
	{id = 18300, dup = 99, colGroup = 1}, {id = 18301, dup = 99, colGroup = 1},	{id = 18302, dup = 99, colGroup = 1},
	--{id = 18323, dup = 99, colGroup = 3}, {id = 18324, dup = 99, colGroup = 3}, {id = 18325, dup = 99, colGroup = 3}, 
}

-- Comments: 使用一个物品
function handleUseItem(actor, guid)
	local packet = LDataPack.test_allocPack()
	LDataPack.writeInt64(packet, guid)
	LDataPack.setPosition(packet, 0)
	userbagsys.useItem(actor, packet)
end

-- Comments: 使用一个物品测试
function test_use_item(actor)
	local old_lv = LActor.getLevel(actor)
	LActor.setIntProperty(actor, P_LEVEL, 85)
	
	for test_times = 1, 1000 do
		print("test_use_item case：NO."..test_times)
		-- 构造背包环境
		local use_item = initUserBag(actor, useItems, 1, 1)
		Assert(use_item,"err test_bag initUserBag")

		-- 随机获取测试物品
		local item_ptr  = getRandItemPtrByID(actor, use_item.id)
		if item_ptr then
			-- 冷却时间消失
			local lmtcnt = 0
			while Item.checkUseItemCD(actor, use_item.colGroup) and lmtcnt < 600 do 
				coroutine.yield()
				lmtcnt = lmtcnt + 1
			end
			if lmtcnt >= 600 then Assert(false, "use checkUseItemCD is err") return end

			-- 记录以前的数量
			local item_guid = Item.getItemGuid(item_ptr)
			local item_list = getItemList(actor, ipBag)

			-- 使用后期望剩余数量
			item_list[use_item.id] = item_list[use_item.id] - 1

			-- 使用物品
			handleUseItem(actor, item_guid)

			-- 期望数量
			Assert(isSameItemList(getItemList(actor, ipBag), item_list),"use: err test_use_item del item")
		end
	end

	LActor.setIntProperty(actor, P_LEVEL, old_lv)
end

-----------------------------------------END 使用一个物品 END-----------------------------------------

-----------------------------------------BEGIN 批量使用物品 BEGIN-----------------------------------------

-- Comments: 批量使用物品
function handleBatchUse(actor, guid, cnt)
	local packet = LDataPack.test_allocPack()
	LDataPack.writeInt64(packet, guid)
	LDataPack.writeWord(packet, cnt)
	LDataPack.setPosition(packet, 0)
	userbagsys.batchUse(actor, packet)
end

-- Comments: 批量使用物品测试
function test_batch_use(actor)
	for test_times = 1, 1000 do
		print("test_batch_use case：NO."..test_times)
		-- 构造背包环境
		local use_item = initUserBag(actor, useItems, 1, 1)
		Assert(use_item,"batch err test_bag initUserBag")

		-- 随机获取测试数据
		local item_ptr  = getRandItemPtrByID(actor, use_item.id)
		if item_ptr then
			-- 冷却时间消失
			local lmtcnt = 0
			while Item.checkUseItemCD(actor, use_item.colGroup) and lmtcnt < 600 do 
				coroutine.yield()
				lmtcnt = lmtcnt + 1
			end
			if lmtcnt >= 600 then Assert(false, "batch checkUseItemCD is err") return end

			-- 记录以前的数量
			local item_guid = Item.getItemGuid(item_ptr)
			local item_cnt  = Item.getItemCount(item_ptr)
			local item_list = getItemList(actor, ipBag)
			local use_cnt   = System.getRandomNumber(65535) + 1

			-- 使用后期望剩余数量
			item_list[use_item.id] = item_list[use_item.id] - math.min(item_cnt, use_cnt)

			-- 批量使用物品
			handleBatchUse(actor, item_guid, use_cnt)

			-- 期望数量
			Assert(isSameItemList(getItemList(actor, ipBag), item_list),"batch: test_item cnt is change")
		end
	end
end

-----------------------------------------END 批量使用物品 END-----------------------------------------

-----------------------------------------BEGIN 删除物品 BEGIN-----------------------------------------

-- 物品删除数据
local delItem = 
{
	-- 加入+7以上强化装备不允许销毁
	{id = 1351, quality = 0, strong = 5, count = 1, bind = 1, is_delete = true},
	{id = 1352, quality = 0, strong = 6, count = 1, bind = 1, is_delete = true},
	{id = 1321, quality = 0, strong = 7, count = 1, bind = 1, is_delete = false},
	{id = 1344, quality = 0, strong = 8, count = 1, bind = 1, is_delete = false},

	-- 五级或五级以上宝石不允许销毁
	{id = 18531, quality = 0, strong = 1, count = 1, bind = 1, is_delete = true},  -- 二级法防宝石
	{id = 18513, quality = 0, strong = 0, count = 1, bind = 1, is_delete = true},  -- 四级攻击宝石
	{id = 18524, quality = 0, strong = 0, count = 1, bind = 1, is_delete = false}, -- 五级物防宝石
	{id = 18536, quality = 0, strong = 0, count = 1, bind = 1, is_delete = false}, -- 七级法防宝石

	-- 不能被销毁 
	{id = 11101, quality = 0, strong = 0, count = 1, bind = 1, is_delete = false}, -- denyDestroy
	{id = 11102, quality = 0, strong = 0, count = 1, bind = 1, is_delete = false}, -- denyDestroy
}

-- Comments: 物品删除
function handleDelItem(actor, guid)
	local packet = LDataPack.test_allocPack()
	LDataPack.writeInt64(packet, guid)
	LDataPack.setPosition(packet, 0)
	userbagsys.delItem(actor, packet)
end

-- Comments: 物品删除测试
function test_del_item(actor)
	-- 清空背包
	LActor.cleanBag(actor)

	for key, items in ipairs(delItem) do
		print("test_del_item case：NO."..key)
		-- 添加物品
		LActor.addItem(actor, items.id, items.quality, items.strong, items.count, items.bind, "test_del_item", 12)			
		local item_ptr  = Item.getItemById(actor, items.id, items.bind)
		local item_guid = Item.getItemGuid(item_ptr)
		local item_cnt  = Item.getItemCount(item_ptr)
		local item_list = getItemList(actor, ipBag)
		
		-- 删除物品
		local old_tot_cnt  = Item.getBagUsedGridCnt(actor)
		handleDelItem(actor, item_guid)
		local new_tot_cnt  = Item.getBagUsedGridCnt(actor)

	    if items.is_delete then
	    	-- 能够被删除
	    	item_list[items.id] = item_list[items.id] - item_cnt
	    	Assert(isSameItemList(getItemList(actor, ipBag), item_list), string.format("del:total cnt is chg itemid:%d in %d ",items.id, key))
	   		Assert(not Item.getItemPtrByGuid(actor, item_guid), string.format("del:del: is not be del itemid:%d in %d ",items.id, key))
	    	Assert_eq(old_tot_cnt - 1, new_tot_cnt, string.format("del: is grid cnt err itemid:%d in %d ",items.id, key))
	    else
	    	-- 不能够被删除
	    	Assert(isSameItemList(getItemList(actor, ipBag), item_list), string.format("del:total cnt is chg itemid:%d in %d ",items.id, key))
	  		Assert(Item.getItemPtrByGuid(actor, item_guid), string.format("del:del: is not be del itemid:%d in %d ",items.id, key))
	    	Assert_eq(old_tot_cnt, new_tot_cnt, string.format("del: is grid cnt err itemid:%d in %d ",items.id, key))
	    end
	end
end

-----------------------------------------END 删除物品 END-----------------------------------------

-- Comments: 主测试函数
function test_bag(actor)
	--测试拆分物品
	test_split_item(actor)
	--测试叠加物品
	test_merge_item(actor)
	--测试使用物品
	test_use_item(actor)
	--测试批量物品
	test_batch_use(actor)
	--测试删除物品
	test_del_item(actor)
end

TEST("bag", "test_bag", test_bag, true)
