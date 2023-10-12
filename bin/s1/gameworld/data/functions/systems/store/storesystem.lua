module("storesystem", package.seeall)

local featsDayLimit = 1
local featsNoLimit = 2
local featsAllLimit = 3

--商店的数据分了两部分，一部分是刷新次数，在lua存
--另一部分是装备商店的商品数据，在C++存
function getStoreVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then
		return
	end

	if (var.store == nil) then
		var.store = {}
	end
	if var.store.refreshCount == nil then
		var.store.refreshCount = 0
	end

	if var.store.dayCount == nil then
		var.store.dayCount = 0
	end

	if var.store.refresh_start_time == nil then
		var.store.refresh_start_time = os.time()
	end
	if var.store.refresh_cd == nil then
		var.store.refresh_cd = 0
	end
	if var.store.refresh_integral == nil then
		var.store.refresh_integral = 0
	end

	if var.store.featsExchange == nil then
		var.store.featsExchange = {}
	end

	if var.store.vipLimitBuy == nil then
		var.store.vipLimitBuy = {}
	end

	return var.store
end

--下发道具商城的数据
local function sendItemStoreData(actor)
	local storeVar = getStoreVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_ItemStoreData)
	if npack == nil then return end
	local count = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, count)
	for _,v in ipairs(ItemStoreConfig) do
		if storeVar.vipLimitBuy[v.itemId] then
			count = count + 1
			LDataPack.writeInt(npack, v.itemId)
			LDataPack.writeInt(npack, storeVar.vipLimitBuy[v.itemId] or 0)
		end
	end
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, pos2)
	LDataPack.flush(npack)
end

--购买商品，通过商店类型和商品列表购买
function buyGoods(actor, storeType, goodsList)
	if (storeType == storecommon.itemStore) then
		itemShoreBuy(actor, goodsList)
	else
		equipShoreBuy(actor, goodsList)
	end
end

--道具商店购买
function itemShoreBuy(actor, goodsList)
	local yuanBao = 0
	local itemList = {}
	--获取玩家VIP等级
	local vipLv = LActor.getVipLevel(actor)
	local var = getStoreVar(actor)
	--遍历一下，看有没有非法数据，顺便把总的价钱算一下
	for _,tb in pairs(goodsList) do
		local config = storecommon.getGoodsConfig(storecommon.itemStore, tb.goodsId)
		if (not config) then
			return
		end
		if (tb.count <= 0) then
			return
		end
		--VIP等级限制
		if config.viplv and vipLv < config.viplv then
			return
		end
		local count = tb.count --购买数量
		if config.vipLimit then --VIP购买数量限制
			local left_count = (config.vipLimit[vipLv] or 0) - (var.vipLimitBuy[config.itemId] or 0)
			count = math.min(tb.count, left_count)
		end
		if count > 0 then
			table.insert(itemList, {itemId = config.itemId, count = count})
			yuanBao = yuanBao + count*config.price
		end
	end

	if #itemList <= 0 then
		return
	end

	local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
	if (curYuanBao < yuanBao) then
		return
	end

	--先扣钱
	LActor.changeCurrency(actor, NumericType_YuanBao, -yuanBao,
		"item store buy:"..tostring(itemList[1].itemId) .. ":".. tostring(itemList[1].count))

	print("item store buy:"..tostring(itemList[1].itemId) .. ":".. tostring(itemList[1].count))

	actorevent.onEvent(actor, aeStoreCost, NumericType_YuanBao, yuanBao)

	--再发货
	for _,tb in pairs(itemList) do
		LActor.giveAward(actor, AwardType_Item, tb.itemId, tb.count, "item store buy")
		var.vipLimitBuy[tb.itemId] = (var.vipLimitBuy[tb.itemId] or 0) + tb.count
	end

	sendItemStoreData(actor)
	--告诉前端购买成功
	reqBuyResult(actor)
end

--装备商店购买
function equipShoreBuy(actor, goodsList)
	--需要多少钱的汇总
	local totalCost = {}
	local moneyList = {}
	--需要多少背包格仔
	local needSpace = 0
	for _,tb in pairs(goodsList) do
		local config = storecommon.getGoodsConfig(storecommon.equipStore, tb.goodsId)
		if (not config) then return end
		--获取道具配置
		local itemConfig = ItemConfig[config.itemId]
		if (itemConfig and itemConfig.type == ItemType_Equip) then
			needSpace = needSpace + 1
		end
		--获取商品的消耗货币类型和货币金额
		local currencyType, currency = LActor.getStoreItemData(actor, tb.goodsId)
		if not currencyType then return end
		--记录类型
		totalCost[currencyType] = (totalCost[currencyType] or 0) + currency
		table.insert(moneyList, {type=currencyType, value=currency, itemId=config.itemId})
	end

	--装备背包空间不够的话，就不给买
	if (LActor.getEquipBagSpace(actor) < needSpace) then
		return
	end

	--判断是否所有钱都足够
	local sub_yuan_bao = 0
	for currencyType,currency in pairs(totalCost) do
		local curCurrency = LActor.getCurrency(actor, currencyType)
		if currency > curCurrency then return end
		if currencyType ==  NumericType_YuanBao then
			sub_yuan_bao = sub_yuan_bao + currency
		end
	end

	--扣钱
	for _,money in pairs(moneyList) do
		LActor.changeCurrency(actor, money.type, -money.value, "equip store buy:"..tostring(money.itemId) )
		actorevent.onEvent(actor, aeStoreCost, money.type, money.value)
	end
	
	--记录积分
	local var = getStoreVar(actor)
	local numb = math.floor(sub_yuan_bao * StoreCommonConfig.IntegralProportion)
	var.refresh_integral = var.refresh_integral + numb
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"store integral", tostring(numb), tostring(var.refresh_integral), "", "equip store buy", "", "")

	--发放购买的东西
	for _,tb in pairs(goodsList) do
		LActor.giveStoreItem(actor, tb.goodsId)
	end

	--同步一下数据给前端
	--local storeVar = getStoreVar(actor)
	LActor.StoreDataSync(actor, var.refreshCount)

	reqBuyResult(actor)
end

--刷新装备商店的商品
function refreshGoods(actor, isFirst)
	local storeVar = getStoreVar(actor)
	if (storeVar == nil) then
		return
	end
	--每天次数用完了就没了，不给刷
	if (storeVar.refreshCount >= StoreCommonConfig.refreshLimit) then
		return
	end

	--是否第一次刷新
	if not isFirst then
		--时间是否到了
		if os.time() < storeVar.refresh_start_time + StoreCommonConfig.refreshCd then
			--先判断有没有道具
			if StoreCommonConfig.refreshItem and LActor.getItemCount(actor, StoreCommonConfig.refreshItem) > 0 then
				LActor.costItem(actor, StoreCommonConfig.refreshItem, 1, "store refresh")
			else
				local needMoney = StoreCommonConfig.refreshYuanBao
				if needMoney > LActor.getCurrency(actor, NumericType_YuanBao) then
					return
				end
				LActor.changeYuanBao(actor,-needMoney,"store refresh")
			end
		end

		--storeVar.refresh_integral = storeVar.refresh_integral + StoreCommonConfig.refreshIntegral
	end

	--记录最新的数据
	storeVar.refreshCount = storeVar.refreshCount + 1
	storeVar.refresh_start_time = os.time()
	storeVar.dayCount = storeVar.dayCount + 1

	--先清空，再加新的
	LActor.StoreClearList(actor)

	--随机一些商品
	local groupId = getGroupIdByActor(actor)
	refreshStoreGoods(actor, groupId, isFirst)

	--同步给前端
	LActor.StoreDataSync(actor, storeVar.refreshCount)
end

function getGroupIdByActor(actor)
	local level = LActor.getLevel(actor)
	local zhuanShengLevel = LActor.getZhuanShengLevel(actor)
	return storecommon.getGroupIdByLevel(zhuanShengLevel*1000 + level)
end

--刷新装备商店的商品
function refreshStoreGoods(actor, groupId, isFirst)
	local actorId = LActor.getActorId(actor)
	local storeVar = getStoreVar(actor)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"store integral", tostring(StoreCommonConfig.refreshIntegral), tostring(storeVar.refresh_integral), "", "equip store refresh", "", "")

	local count = storeVar.dayCount or 0
	local goodsList,maxProb = storecommon.getGoodsListByGroupId(actor, groupId, count, isFirst)
	if (not goodsList) then
		return
	end

	--不够6个就直接加上，超过的话就随机一下咯
	local tStoreGoods = {}
	if (#goodsList <= storecommon.maxGoodsNum) then
		tStoreGoods = goodsList
	else
		for i=1,storecommon.maxGoodsNum do

			--bug输出日志
			if maxProb < 1 then
				print("storesystem.refreshStoreGoods:maxProb < 1, actorId:"..tostring(actorId)..",maxProb:"..tostring(maxProb)..",groupId:"..tostring(groupId)
					..",dayCount:"..tostring(count)..",isFirst:"..tostring(isFirst))
				print(utils.t2s(goodsList))

				break
			end

			local curProb = 0
			local prob = math.random(1, maxProb)
			for index=1,#goodsList do
				local tb = goodsList[index]
				local value = tb.prob
				if tb.Preprob and tb.Preprob[count] then value = tb.Preprob[count] end

				curProb = curProb + value
				if (curProb >= prob) then
					table.insert(tStoreGoods, {id=tb.id})

					maxProb = maxProb - value
					table.remove(goodsList, index)
					break
				end
			end
		end
	end

	--第一次刷新
	local job = LActor.getJob(actor)
	if isFirst and FirstBookListConfig[job] and tStoreGoods[1] then tStoreGoods[1].id = FirstBookListConfig[job].id end

	--随机好了就更新C++上面的数据
	for _,tb in ipairs(tStoreGoods) do
		local config = storecommon.getGoodsConfig(storecommon.equipStore, tb.id)
		if (config) then
			local type, value, discount = getCurrencyConfig(config)
			LActor.addStoreItem(actor, tb.id, config.itemId, config.count, type, value, discount)
		end
	end
end

--获取商品的价格配置，类型，数量和折扣
function getCurrencyConfig(config)
	local type, value, discount
	local currencyRate = math.random(1,100)
	if (config.ybProb >= currencyRate) then
		type, value = NumericType_YuanBao, config.ybPrice
	else
		type, value = NumericType_Gold, config.goldPrice
	end

	discount = storecommon.discount_0
	local rate = 100
	local prob = math.random(1,100)
	local curProb = 0
	for index,tb in ipairs(config.discount) do
		curProb = tb[2]
		if (prob <= curProb) then
			rate = tb[1]
			value = math.ceil(value*rate/100)
			if (rate == 50) then
				discount = storecommon.discount_50
			else
				discount = storecommon.discount_80
			end
			break
		end
		prob = math.random(1,100)
	end

	return type, value, discount
end

function buyGoods_c2s(actor, pack)
	local storeType = LDataPack.readInt(pack)

	local goodsList = {}
	local num = LDataPack.readInt(pack)
	for i=1,num do
		local goodsId = LDataPack.readInt(pack)
		local count = LDataPack.readInt(pack)

		table.insert(goodsList, {goodsId = goodsId, count = count})
	end

	buyGoods(actor, storeType, goodsList)
end

--贵族商店
function buyIntegralItem(actor,index)

	--判断是否贵族
	if false == monthcard.isOpenPrivilege(actor) then
		LActor.sendTipmsg(actor, "您没有激活贵族特权，无法购买")
		return
	end

	local conf = IntegralStore[index]
	if conf == nil then
		print("not config " .. index)
		return false
	end

	local YuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
	if YuanBao < conf.price then
		print(LActor.getActorId(actor).." storesystem.buyIntegralItem not have yuanbao " .. YuanBao .. " " .. conf.price)
		return false
	end

	LActor.changeYuanBao(actor, -conf.price, "store buy noble item:"..tostring(conf.itemId))

	local item = {
		{
			type = conf.type,
			id       = conf.itemId,
			count    = conf.count
		}
	}
	LActor.giveAwards(actor,item,"store buy noble item")
	return true
end

function onBuyIntegralItem(actor,pack)
	local index = LDataPack.readInt(pack)
	local ret = buyIntegralItem(actor,index)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_BuyIntegralItem)
	if npack == nil then return end
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.writeInt(npack,index)
	LDataPack.flush(npack)

end

function refreshGoods_c2s(actor, pack)
	refreshGoods(actor, false)
end

function onLogin(actor, firstLogin)
	local var = getStoreVar(actor)
	local svar = System.getStaticVar()
	if svar.store ~= nil then
		if svar.store[LActor.getActorId(actor)] ~= nil then
			var.refresh_integral = var.refresh_integral + svar.store[LActor.getActorId(actor)]
			print("store gm add interal " .. svar.store[LActor.getActorId(actor)])
			svar.store[LActor.getActorId(actor)] = nil
		end
	end

	--第一次登陆刷新
	if firstLogin == 1 then
		refreshGoods(actor, true)
	end

	local storeVar = getStoreVar(actor)
	LActor.StoreDataSync(actor, storeVar.refreshCount)

	--发送已购买(限制)数量
	sendItemStoreData(actor)
end

function onNewDay(actor, login)
	local storeVar = getStoreVar(actor)
	if (storeVar ~= nil) then
		storeVar.refreshCount = 0
		storeVar.dayCount = 0
		for index,conf in pairs(FeatsStore) do
			if conf.buyType == featsDayLimit then
				storeVar.featsExchange[index] = nil
			end
		end
		storeVar.vipLimitBuy = {}
		sendItemStoreData(actor)
	end

	if not login then
		LActor.StoreDataSync(actor, storeVar.refreshCount)
	end
end

function reqBuyResult(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sStoreCmd_ReqBuy)
	if pack == nil then return end

	LDataPack.writeData(pack, 1, dtInt, 1)

	LDataPack.flush(pack)
end



-- exern

function getRefreshIntegral(actor)
	local var = getStoreVar(actor)
	return var.refresh_integral
end

function getRefreshCd(actor)
	local var = getStoreVar(actor)
	local curr_time = os.time()
	if curr_time >= (var.refresh_start_time + StoreCommonConfig.refreshCd) then
		return 0
	end

	return (var.refresh_start_time + StoreCommonConfig.refreshCd) - curr_time
end

_G.getStoreRefreshIntegral = getRefreshIntegral
_G.getStoreRefreshCd = getRefreshCd

function handleQueryFeatsInfo(actor, packet)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sCMD_StoreFeatsInfo)
	if not pack then return end
	local var = getStoreVar(actor)
	local count = 0
	local pos1 = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, count)
	for k,v in pairs(FeatsStore) do
		if var.featsExchange[k] then
			LDataPack.writeInt(pack, k)
			LDataPack.writeInt(pack, var.featsExchange[k])
			count = count + 1
		end
	end
	local pos2 = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos1)
	LDataPack.writeInt(pack, count)
	LDataPack.setPosition(pack, pos2)
	LDataPack.flush(pack)
end

function handleFeatsExchange(actor, packet)
	local index = LDataPack.readInt(packet)
	local num = LDataPack.readInt(packet)
	if num <= 0 then return end

	local conf = FeatsStore[index]
	if not conf then
		print(LActor.getActorId(actor).." storesystem.handleFeatsExchange no conf index:"..index)
		return
	end

	--是否限购商品
	local var = getStoreVar(actor)
	if conf.buyType ~= featsNoLimit then
		local count = var.featsExchange[index] or 0
		if (count+num) > conf.daycount then
			print(LActor.getActorId(actor).." storesystem.handleFeatsExchange count use over")
			return
		end
	end

	local rewards = utils.table_clone(conf.goods)
	for _, v in pairs(rewards or {}) do v.count = v.count * num end

	if not LActor.canGiveAwards(actor, rewards) then
		print(LActor.getActorId(actor).." storesystem.handleFeatsExchange bag not enough")
		return
	end

	--是否需要消耗货币
	if conf.costMoney then
		local needMoney = conf.costMoney.count * num
		if LActor.getCurrency(actor, conf.costMoney.type) < needMoney then
			print(LActor.getActorId(actor).." storesystem.handleFeatsExchange money less")
			return
		end

		LActor.changeCurrency(actor, conf.costMoney.type, -needMoney, "featstore "..index)
	end

	--是否需要消耗道具
	if conf.costItem then
		local needCount = conf.costItem.count * num
		if LActor.getItemCount(actor, conf.costItem.id) < needCount then
			print(LActor.getActorId(actor).." storesystem.handleFeatsExchange item less")
			return
		end

		LActor.costItem(actor, conf.costItem.id, needCount, "featstore "..index)
	end

	--获得奖励
	LActor.giveAwards(actor, rewards, "featstore "..index)

	--记录限购次数
	if conf.buyType ~= featsNoLimit then
		var.featsExchange[index] = (var.featsExchange[index] or 0) + num
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Store, Protocol.sCMD_StoreFeatsExchange)
	if not pack then return end
	LDataPack.writeInt(pack, index)
	LDataPack.writeInt(pack, var.featsExchange[index] or 0)
	LDataPack.flush(pack)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_Buy, buyGoods_c2s)
netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_Refresh, refreshGoods_c2s)
netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cStoreCmd_BuyIntegralItem, onBuyIntegralItem)
netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cCMD_StoreFeatsInfo, handleQueryFeatsInfo)
netmsgdispatcher.reg(Protocol.CMD_Store, Protocol.cCMD_StoreFeatsExchange, handleFeatsExchange)

-- actorevent.reg(aeNewDayArrive, onNewDayArrive)
