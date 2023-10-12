module("storecommon", package.seeall)

itemStore = 1
equipStore = 2
maxGoodsNum = 5

discount_0 = 0
discount_80 = 1
discount_50 = 2

local tGroupConfig = {}
for _,tb in pairs(EquipGroupConfig) do
	if (not tGroupConfig[tb.groupId]) then
		tGroupConfig[tb.groupId] = {}
		tGroupConfig[tb.groupId].groupId = tb.groupId
		tGroupConfig[tb.groupId].low = tb.low
		tGroupConfig[tb.groupId].high = tb.high
		tGroupConfig[tb.groupId].goodsList = {}
	end
	
	table.insert(tGroupConfig[tb.groupId].goodsList, {id = tb.id, prob = tb.prob, job = tb.job, Preprob = tb.Preprob})
end

function getGoodsConfig(storeType, goodsId)
	if (itemStore == storeType) then
		return ItemStoreConfig[goodsId]
	else
		return EquipItemConfig[goodsId]
	end
end

function getYuanBaoPrice(itemId)
	for _,tb in pairs(ItemStoreConfig) do
		if (tb.itemId == itemId) then
			return tb.price
		end
	end
end

function getGoodsListByGroupId(actor, groupId, counts, isFirst)
	local config = tGroupConfig[groupId]
	if (not config) then
		return
	end

	local maxProb = 0
	local goodsList = {}
	local job = LActor.getJob(actor)
	for _,tb in pairs(config.goodsList) do
		if not tb.job or tb.job <= 0 or job == tb.job then
			if not isFirst or tb.id ~= FirstBookListConfig[job].id then  --第一次刷新必然出现的物品这里不加进去,免得重复
				table.insert(goodsList, tb)
				if tb.Preprob and tb.Preprob[counts] then
					maxProb = maxProb + tb.Preprob[counts]
				else
					maxProb = maxProb + tb.prob
				end
			end
		end
	end
	return goodsList,maxProb
end

function getGroupIdByLevel(level)
	for _,config in pairs(tGroupConfig) do
		if (config.low <= level and config.high >= level) then
			return config.groupId
		end
	end
	return tGroupConfig[1].groupId
end

