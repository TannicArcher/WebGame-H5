module("holycompose", package.seeall)

local costItemId = 200333

local function onReqCompose(actor, packet)
	local itemId1 = LDataPack.readInt(packet)
	local itemId2 = LDataPack.readInt(packet)
	local itemId3 = LDataPack.readInt(packet)
	local actorId = LActor.getActorId(actor)

	if not ItemConfig[itemId1] or not ItemConfig[itemId2] or not ItemConfig[itemId3] then
		print("holycompose.onReqCompose:ItemConfig nil, itemId1:"..tostring(itemId1)..", itemId2:"..tostring(itemId2)
			..", itemId3:"..tostring(itemId3)..", actorId:"..actorId)
		return
	end

	--类型判断
	if ItemType_Holy ~= ItemConfig[itemId1].type or ItemType_Holy ~= ItemConfig[itemId2].type or ItemType_Holy ~= ItemConfig[itemId3].type then
		print("holycompose.onReqCompose:type error, actorId:"..tostring(actorId))
		return
	end

	--是否有这些物品
	if 0 >= LActor.getItemCount(actor, itemId1) or 0 >= LActor.getItemCount(actor, itemId2) or 0 >= LActor.getItemCount(actor, itemId3) then
		print("holycompose.onReqCompose:count not enough, actorId:"..tostring(actorId))
		return
	end

	--先判断品质是否都相同
	if ItemConfig[itemId1].quality ~= ItemConfig[itemId2].quality or ItemConfig[itemId1].quality ~= ItemConfig[itemId3].quality
		or ItemConfig[itemId2].quality ~= ItemConfig[itemId3].quality then
		print("holycompose.onReqCompose:quality not same, actorId:"..tostring(actorId))
		return
	end

	local quality = ItemConfig[itemId1].quality
	local difConf = DiffHolyComposeConfig[quality]
	if not difConf then print("holycompose.onReqCompose:difConf nil, quality:"..tostring(quality)..", actorId:"..tostring(actorId)) return end

	--判断物品是否都一样
	local isSame, sameConf = false, nil
	if itemId1 == itemId2 and itemId2 == itemId3 and itemId1 == itemId3 then isSame = true sameConf = SameHolyComposeConfig[itemId1] end

	if isSame then
		if not sameConf then print("holycompose.onReqCompose:sameConf nil, itemId:"..tostring(itemId1)..", actorId:"..tostring(actorId)) return end
	end

	--扣物品
	LActor.costItem(actor, itemId1, 1, "holycomposeC")
	LActor.costItem(actor, itemId2, 1, "holycomposeC")
	LActor.costItem(actor, itemId3, 1, "holycomposeC")

	--是否合成成功
	local isSuccess = false
	local precent = math.random(1, 10000)
	if precent <= difConf.precent then isSuccess = true end

	--成功了
	local dropId = nil
	local reward = {}
	if isSuccess then
		if isSame then
			LActor.giveItem(actor, sameConf.successItemId, 1, "holycomposeG")
			table.insert(reward, {id=sameConf.successItemId, type=AwardType_Item, count=1})
		else
			dropId = difConf.successDropId
		end
	else  --失败咯
		dropId = difConf.failDropId
	end

	if dropId then
		reward = drop.dropGroup(dropId)
		LActor.giveAwards(actor, reward, "holycomposeG")
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_HolyCompose, Protocol.sHolyComposeCMD_ReqCompose)
	LDataPack.writeByte(npack, isSuccess and 1 or 0)
	LDataPack.writeShort(npack, table.getnEx(reward or {}))
	for k, v in pairs(reward or {}) do LDataPack.writeInt(npack, v.id) end

	LDataPack.flush(npack)
end

local function onReqFuse(actor, packet)
	local firstId = LDataPack.readInt(packet)
	local secondId = LDataPack.readInt(packet)
	local isCost = LDataPack.readShort(packet)
	local actorId = LActor.getActorId(actor)

	if not ItemConfig[firstId] or not ItemConfig[secondId] then print("holycompose.onReqFuse:ItemConfig nil, actorId:"..tostring(actorId)) return end

	--类型判断
	if ItemType_Holy ~= ItemConfig[firstId].type or ItemType_Holy ~= ItemConfig[secondId].type then
		print("holycompose.onReqFuse:type error, actorId:"..tostring(actorId))
		return
	end

	--是否是红色品质
	if QualityType_Red ~= ItemConfig[firstId].quality or QualityType_Red ~= ItemConfig[secondId].quality then
		print("holycompose.onReqFuse:quality is not 4, actorId:"..tostring(actorId))
		return
	end

	--是否职业相同
	if ItemConfig[firstId].job ~= ItemConfig[secondId].job then print("holycompose.onReqFuse:job not same, actorId:"..tostring(actorId)) return end

	--是否有这些物品
	if 0 >= LActor.getItemCount(actor, firstId) or 0 >= LActor.getItemCount(actor, secondId) then
		print("holycompose.onReqFuse:count not enough, actorId:"..tostring(actorId))
		return
	end

	local isSuccess = false

	--合成公式
	local itemId = 400000 + ItemConfig[firstId].job * 10000 + math.max(firstId, secondId) - math.min(firstId, secondId)
		+ 100 * math.fmod(math.min(firstId, secondId), 20)

	if 1 == (isCost or 0) then
		if 0 >= LActor.getItemCount(actor, costItemId) then
			print("holycompose.onReqFuse:costItemId not enough, actorId:"..tostring(actorId))
			return
		end

		LActor.costItem(actor, costItemId, 1, "holyfusecostItem")
		isSuccess = true
	else
		local conf = HolyFuseConfig[itemId]
		if not conf then print("holycompose.onReqFuse:conf nil, itemId:"..tostring(itemId)..", actorId:"..tostring(actorId)) return end

		--是否融合成功
		local precent = math.random(1, 10000)
		if precent <= conf.precent then isSuccess = true end
	end

	if isSuccess then
		LActor.costItem(actor, firstId, 1, "holyfuseC")
		LActor.costItem(actor, secondId, 1, "holyfuseC")

		LActor.giveItem(actor, itemId, 1, "holyfuseCG")
	else  --失败扣辅助物品
		LActor.costItem(actor, secondId, 1, "holyfuseC")
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_HolyCompose, Protocol.sHolyComposeCMD_ReqFuse)
	LDataPack.writeByte(npack, isSuccess and 1 or 0)
	if isSuccess then
		LDataPack.writeShort(npack, 1)
		LDataPack.writeInt(npack, itemId)
	else
		LDataPack.writeShort(npack, 0)
	end

	LDataPack.flush(npack)
end

--初始化副本
local function initFunc()
    netmsgdispatcher.reg(Protocol.CMD_HolyCompose, Protocol.cHolyComposeCMD_ReqCompose, onReqCompose)
    netmsgdispatcher.reg(Protocol.CMD_HolyCompose, Protocol.cHolyComposeCMD_ReqFuse, onReqFuse)
end
table.insert(InitFnTable, initFunc)

