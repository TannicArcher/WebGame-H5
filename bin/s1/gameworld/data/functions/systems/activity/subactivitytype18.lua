module("subactivitytype18", package.seeall)
--[[
data define:
	count = 累计寻宝次数,
	rewardsRecord = 已经领取的奖励标记位 
	perID = 命库ID
	logItem = {} 日志
	logItem2 = {} 极品道具日志
}
--]]

local subType = 18
local items = nil -- 极品道具

local function initLog(  id )
	local var = activitysystem.getGlobalVar(id)
	if not var.logItem then var.logItem = {}  end
	return var.logItem
end

local function initLog2(  id )
	local var = activitysystem.getGlobalVar(id)
	if not var.logItem2 then var.logItem2 = {} end
	return var.logItem2
end

local function getLog(  id )
	local var = activitysystem.getGlobalVar(id)
	return var and var.logItem
end

local function getLog2(  id )
	local var = activitysystem.getGlobalVar(id)
	return var and var.logItem2
end

--
local function addLogItem( actor, id , itemId)
	local logMaxCount = ActivityType18Config[id][0].logCount
	if not logMaxCount then return end
	local actorid = LActor.getActorId(actor)
	local log = initLog( id)
	if #log >= logMaxCount then
		for i=1,#log - 1 do
			log[i].name = log[i+1].name
			log[i].itemid = log[i+1].itemid
		end
		log[#log].name = LActor.getActorName(actorid)
		log[#log].itemid = itemId
		return
	end
	log[#log + 1] = {name=LActor.getActorName(actorid), itemid=itemId}
end

local function addLog2( actor, id, itemId )
	local logMaxCount = ActivityType18Config[id][0].logItemCnt
	if not logMaxCount or not ActivityType18Config[id][0].items then return end
	if not items then
		items = {}
		for _,v in pairs(ActivityType18Config[id][0].items) do
			items[v] = true
		end
	end
	if not items[itemId] then return end
	local actorid = LActor.getActorId(actor)
	local log = initLog2( id)
	if #log >= logMaxCount then
		for i=1,#log - 1 do
			log[i].name = log[i+1].name
			log[i].itemid = log[i+1].itemid
		end
		log[#log].name = LActor.getActorName(actorid)
		log[#log].itemid = itemId
		return
	end
	log[#log + 1] = {name=LActor.getActorName(actorid), itemid=itemId}
end

-- 获取全服次数的掉落组
local function getSerDropID(conf, record, id)
	if not conf then return end
	--获取全局数据
	local gdata = activitysystem.getGlobalVar(id)
	if not gdata.useIdx and conf.serNum and #(conf.serNum) > 0 then 
		gdata.useIdx = math.random(1, #(conf.serNum))
	end
	if not gdata.useIdx then return end
	local cfg = conf.serNum[gdata.useIdx]
	if not cfg then
		print("subactivitytype18.getSerDropID cfg is nil, id:"..id..",gdata.useIdx:"..tostring(gdata.useIdx))
		return
	end
	local did = cfg[(gdata.count or 0)+1]
	return did
end

-- 获取命库中的掉落组
local function getPerDropID(count, conf, record)
	-- 没有配置命库
	if not conf[0].perDrop then return end
	local perDrop = conf[0].perDrop
	-- 选择命库
	if not record.perID then
		record.perID = math.random(1, #perDrop)
	end
	-- 配置
	if not perDrop[record.perID] then return end
	local drops = perDrop[record.perID]
	return drops[count]
end

-- 获取掉落组ID
local function getDropID(count , conf, record, id)
	local serDropId = getSerDropID(conf[0], record, id)
	if serDropId then
		return serDropId
	end
	local dropID = getPerDropID(count, conf, record)
	-- 选中命库中的掉落组
	if dropID then
		return dropID
	end
	local maxID = 0
	for id,groupID in pairs(conf[0].dropGroup or {}) do
		if count >= id and id > maxID then
			local _,res = math.modf(count / id)
			if res == 0 then
				maxID, dropID = id, groupID
			end
		end
	end
	return dropID
end

-- 获取掉落组奖励
local function getDropRewards(actor, record, conf, num , id)
	local typeconfig = ActivityType18Config[id]
	local baseCfg = typeconfig[0]
	local noticeCfg = typeconfig[0].notice
	local rewards = {}
	local count = (record.count or 0) + 1
	for i=1,num do
		-- 掉落组
		local dropID = getDropID(count, typeconfig, record, id)
		-- 奖励
		local reward = drop.dropGroup(dropID)
		-- 发奖励
		LActor.giveAwards(actor, reward, "type18,index:"..tostring(index))
		-- 公告
		for _,tb in pairs(reward) do
			local itemCfg = ItemConfig[tb.id]
			if noticeCfg and itemCfg.needNotice == 1 and itemCfg.quality and noticeCfg[itemCfg.quality] then
				local needNotice = true
				if baseCfg.level and itemCfg.level and itemCfg.zsLevel and itemCfg.type and itemCfg.type == 0 then
					if (itemCfg.zsLevel * 1000 + itemCfg.level) < baseCfg.level then
						needNotice = false
					end
				end
				if needNotice then
					noticemanager.broadCastNotice(noticeCfg[itemCfg.quality], LActor.getActorName(LActor.getActorId(actor)), item.getItemDisplayName(tb.id))

					addLogItem(actor, id,  tb.id)
				end
			end
			rewards[#rewards + 1] = tb
			addLog2(actor, id, tb.id)
		end
		record.count = count
		count = count + 1
		--获取全局数据
		local gdata = activitysystem.getGlobalVar(id)
		gdata.count = (gdata.count or 0) + 1
		if gdata.count > 999999 then gdata.count = 999999 end
	end
	return rewards
end

-- 寻宝
local function hunt( actor, record, conf, id, indx )
	-- 寻宝
	if not conf or (conf.count or 0) <= 0 then
		-- 配置错误
		print("subactivitytype18.hunt conf.count error," .. (conf.count or 0))
		return
	end

	local needItem = false
	local count = conf.count
	-- 优先判断道具
	if conf.item then
		local haveItemCount = LActor.getItemCount(actor, conf.item)
		if haveItemCount > 0 then --有道具
			needItem = true
			count = math.min(count, haveItemCount)
		end
	end
	-- 不使用道具，则判断元宝数
	if not needItem and (conf.yb or 0) > 0 then
		-- 元宝不足
		if LActor.getCurrency(actor, NumericType_YuanBao) < conf.yb then
			print("subactivitytype18.hunt yb not enough,actor:" .. LActor.getActorId(actor) .. ",id:" .. id .. ",indx:" .. indx
				.. ",conf.yb:" .. (conf.yb or 0) .. ",yb:" .. LActor.getCurrency(actor, NumericType_YuanBao))
			return
		end
	end
	-- 背包容量判断
	local bagSpaceCount = 20
	if LActor.getEquipBagSpace(actor) < bagSpaceCount then
		print("subactivitytype18.hunt bag capacity not enough,actor:" .. LActor.getActorId(actor) .. ",space:" .. LActor.getEquipBagSpace(actor))
		return
	end

	-- 消耗道具或元宝
	if needItem then
		-- 使用道具
		LActor.costItem(actor, conf.item, count, "type18")
	else
		-- 使用元宝
		LActor.changeCurrency(actor, NumericType_YuanBao, - (conf.yb or 0), "type18")
	end
	-- 抽取奖励
	local rewards = getDropRewards(actor, record, conf, count, id)
	-- 向客户端发送消息

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetRewardResult)
	LDataPack.writeByte(npack, 1)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, indx)
	LDataPack.writeInt(npack, record.count or 0)
	LDataPack.writeInt(npack, record.rewardsRecord or 0)
	LDataPack.writeShort(npack, #rewards)

	for _, tb in pairs(rewards) do
		LDataPack.writeInt(npack, tb.id)
		LDataPack.writeShort(npack, tb.count)
	end
	LDataPack.flush(npack)

	activitysystem.sendActivityData(actor, id)
end

-- 领取达标奖励
local function giveDaBiaoReward( actor, record, conf, id, indx)
	-- 达标奖励
	-- 寻宝次数是否达标
	if record.count < conf.dbCount then
		print("subactivitytype18.giveDaBiaoReward count has not enough,actor:" .. LActor.getActorId(actor) ..
			",id:" .. id .. ",indx:" .. indx .. ",conf.dbCount:" .. conf.dbCount .. ",record.count:" .. record.count)
		return
	end
	-- 判断是否已经领取过
	if System.bitOPMask(record.rewardsRecord or 0, indx) then
		print("subactivitytype18.giveDaBiaoReward has received,actor:" .. LActor.getActorId(actor) .. 
			",id:" .. id .. ",indx:" .. indx)
		return
	end
	-- 判断是否能接收
	if not LActor.canGiveAwards(actor, conf.rewards) then 
		print("subactivitytype18.giveDaBiaoReward canGiveAwards is false,actor:" .. LActor.getActorId(actor) .. ",id:" .. id
			.. ",indx:" .. indx) 
		return 
	end
	-- 发放奖励
	LActor.giveAwards(actor, conf.rewards, "subact18,index:"..tostring(index))

    record.rewardsRecord = System.bitOpSetMask(record.rewardsRecord or 0, indx, true)
    activitysystem.sendActivityData(actor, id)
end

-- 领取奖励/寻宝
local function getReward( id, typeconfig, actor, record, packet )
	local indx = LDataPack.readShort(packet)
	local conf = typeconfig[id]
	if indx <= 0 or (not conf) or (not conf[indx]) then
		print("subactivitytype18.getReward fail,actor:" .. LActor.getActorId(actor) .. ",id:" .. id .. ",indx:" .. indx)
		return
	end
	if (conf[indx].count or 0) > 0 then
		-- 寻宝
		hunt(actor, record, conf[indx], id, indx)
	elseif (conf[indx].dbCount or 0) > 0 then
		-- 达标奖励
		giveDaBiaoReward(actor, record, conf[indx], id, indx)
	end
end 

-- 下发数据
local function writeRecord( npack, record, conf, id, actor )
	local log = getLog( id) or {}

	LDataPack.writeInt(npack, record and record.count or 0)
	LDataPack.writeInt(npack, record and record.rewardsRecord or 0)
	LDataPack.writeShort(npack, #log)
	for i=1,#log do
		local v = log[i]
		LDataPack.writeString(npack, v.name)
		LDataPack.writeInt(npack, v.itemid)
	end
	-- 极品道具日志
	local log2 = getLog2( id) or {}
	LDataPack.writeShort(npack, #log2)
	for i=1,#log2 do
		local v = log2[i]
		LDataPack.writeString(npack, v.name)
		LDataPack.writeInt(npack, v.itemid)
	end
end

-- 登录
local function onLogin( id, conf )
	return function ( actor )
		if activitysystem.activityTimeIsEnd(id) then
			local record = activitysystem.getSubVar(actor, id)
			record.count = nil
			record.rewardsRecord = nil
			record.perID = nil
			local var = activitysystem.getGlobalVar(id)
			var.logItem = nil
			var.logItem2 = nil

			items = nil
		end
	end
end

-- 初始
local function initFunc( id, conf )
	actorevent.reg(aeUserLogin, onLogin(id, conf))
end

subactivities.regConf(subType, ActivityType18Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)
