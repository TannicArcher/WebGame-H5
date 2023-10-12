--奖励发放接口
module("actorcost", package.seeall)

--检查道具数量接口，自动查找商城价格
--接口先放这里，后面有更适合的地方再移走吧~
function checkItemNum(actor, itemId, count, useYuanBao)
	if (useYuanBao == nil) then
		useYuanBao = false
	end

	--道具数量足够的话，就直接返回true
	local curCount = LActor.getItemCount(actor, itemId)
	if (count <= curCount) then
		return true
	end

	--道具数量不够，用元宝代替的话，看看商城有没有卖，有卖再看元宝够不够
	--够了才返回true
	local itemPrice = storecommon.getYuanBaoPrice(itemId)
	if (curCount < count and useYuanBao and itemPrice) then
		local yuanBao = itemPrice*(count - curCount)
		local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
		if (yuanBao <= curYuanBao) then
			return true
		end		
	end

	return false
end

--扣除道具接口，自动查找商城价格
--接口先放这里，后面有更适合的地方再移走吧~
function consumeItem(actor, itemId, count, useYuanBao, log)
	if (useYuanBao == nil) then
		useYuanBao = false
	end
	if count < 0 then return false end

	if (not checkItemNum(actor, itemId, count, useYuanBao)) then
		log_print(LActor.getActorId(actor) .. " consumeItem: checkItemNum " .. itemId .. " " .. count )
		return false
	end

	--获取道具数量,不够的话看看商城有没有得卖，没有直接返回
	local curCount = LActor.getItemCount(actor, itemId)
	local itemPrice = storecommon.getYuanBaoPrice(itemId)
	if (curCount >= count) then
		LActor.costItem(actor, itemId, count, log)
		log_print(LActor.getActorId(actor) .. " consumeItem: ok " .. itemId .. " " .. count )
		return true
	elseif (useYuanBao and itemPrice) then
		local needYBNum = (count - curCount) * itemPrice
		if (curCount ~= 0) then
			LActor.costItem(actor, itemId, curCount, log)
		end
		LActor.changeYuanBao(actor, -needYBNum, log)
		log_print(LActor.getActorId(actor) .. " consumeItem: ok " .. itemId .. " " .. count )
		return true
	end	
	log_print(LActor.getActorId(actor) .. " consumeItem: store " .. itemId .. " " .. count )
	return false
end

LActor.checkItemNum = checkItemNum
LActor.consumeItem = consumeItem
