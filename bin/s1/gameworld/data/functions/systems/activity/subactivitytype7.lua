--boss玩法积分活动
module("subactivitytype7", package.seeall)

--[[
data define:
	record:
		data = {
			rewardsRecord[i]  -- 个人奖励情况
			daily[i] -- 每日次数
			totalScore -- 总积分
		}
	global record:
		data = {
			rewardsRecord[i]  -- 全局奖励情况
		}
--]]

local p = Protocol
local subType = 7
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	if config == nil then
		LDataPack.writeShort(npack, 0)
		return
	end
	local gdata = activitysystem.getGlobalVar(id)
	local count = #config
	LDataPack.writeShort(npack, count)
	for i=1,count do
		LDataPack.writeShort(npack, record and record.data and record.data.rewardsRecord and record.data.rewardsRecord[i] or 0)
		LDataPack.writeShort(npack, gdata and gdata.rewardsRecord and gdata.rewardsRecord[i] or 0)
		-- daily data
		LDataPack.writeShort(npack, record and record.data and record.data.daily and record.data.daily[i] or 0);
	end
	LDataPack.writeInt(npack, record and record.data and record.data.totalScore or 0)
end

local function checkReward(index, config, actor, record, gdata)
	local cfg = config[index]
	if not cfg then
		return false
	end
	
	--个人兑换次数
	if cfg.count and (record.data.rewardsRecord[index] or 0)  >= cfg.count then
		return false
	end

	--全服兑换次数
	if cfg.scount and gdata.rewardsRecord and (gdata.rewardsRecord[index] or 0)  >= cfg.scount then
		return false
	end

	if (record.data.totalScore or 0) < (config[index].score or 0) then
		return false
	end

	if (config[index].itemId or 0) ~= 0 and (config[index].itemCount or 0 ) > 0 then
		if LActor.getItemCount(actor, config[index].itemId) < config[index].itemCount then
			return false
		end
	end		
	
	-- 每日兑换次数
	if (cfg.dailyCount or 0) > 0 and (record.data.daily and record.data.daily[index] or 0) >= cfg.dailyCount then
		print("subactivitytype7 dailyCount,actor:"..LActor.getActorId(actor)..",index:"..index..",cfg.dailyCount:"..cfg.dailyCount
			..",count:"..record.data.daily[index])
		return false
	end
	
	-- 多个兑换物
	if cfg.items then
		local items = cfg.items
		for _,v in pairs(items) do
			if (v.id or 0) ~= 0 and (v.count or 0) > 0 and LActor.getItemCount(actor, v.id) < v.count then 
				print("subactivitytype7 costItem,actor:"..LActor.getActorId(actor)..",index:"..index..",v.count:"..v.count
					..",count:"..LActor.getItemCount(actor, v.id)..",itemId:"..v.id)
				return false 
			end
		end
	end

	--是否能获取到奖励
	if not LActor.canGiveAwards(actor, config[index].rewards) then
		return false
	end

	return true
end

local function getReward(id, typeconfig, actor, record, packet)
	local index = LDataPack.readShort(packet) 
	local config = typeconfig[id]
	--初始化记录
	if record.data == nil then record.data = {} end
	if record.data.rewardsRecord == nil then record.data.rewardsRecord = {} end
	--全局变量
	local gdata = activitysystem.getGlobalVar(id)
	if gdata.rewardsRecord == nil then gdata.rewardsRecord = {} end

	local ret = checkReward(index, config, actor, record, gdata)
	if ret then
		--记录
		record.data.rewardsRecord[index] = (record.data.rewardsRecord[index] or 0) + 1
		gdata.rewardsRecord[index] = (gdata.rewardsRecord[index] or 0) + 1
		-- daily
		if not record.data.daily then record.data.daily = {} end
		record.data.daily[index] = (record.data.daily[index] or 0) + 1
		
		--  scoreType为1,不扣积分
		if (config[index].score or 0) > 0 and (config[index].scoreType or 0) ~= 1 then
			--如果配置了积分就要扣积分
			record.data.totalScore = (record.data.totalScore or 0) - config[index].score
		end
		if (config[index].itemId or 0) ~= 0 and (config[index].itemCount or 0 ) > 0 then
			--如果配置了物品就要扣物品
			LActor.costItem(actor, config[index].itemId, config[index].itemCount, "type7 buy")
		end
		-- 扣除多个物品
		if config[index].items then
			local items = config[index].items
			for _,v in pairs(items) do
				if (v.id or 0) ~= 0 and (v.count or 0) > 0 then 
					LActor.costItem(actor, v.id, v.count, "type7 buy2")
				end
			end
		end
		--获得奖励
		LActor.giveAwards(actor, config[index].rewards, "activity type7 rewards")
	end

	local npack = LDataPack.allocPacket(actor, p.CMD_Activity, p.sActivityCmd_GetRewardResult)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, record.data.rewardsRecord[index] or 0)
	LDataPack.writeShort(npack, gdata.rewardsRecord[index] or 0)
	-- daily
	LDataPack.writeShort(npack, record.data.daily and record.data.daily[index] or 0) 
	LDataPack.flush(npack)
end

local function onGetWBossActScore(id, conf)
	return function(actor, val)
		if activitysystem.activityTimeIsEnd(id) then return end
		--获取活动变量
		local var = activitysystem.getSubVar(actor, id)
		--记录总积分
		if not var.data then var.data = {} end
		-- 积分类型为1时，积分改变
		if conf[1] and conf[1].scoreType == 1 then val = math.floor(val / conf[1].divisor) end
		var.data.totalScore = (var.data.totalScore or 0) + val
		--发送信息给客户端
		activitysystem.sendActivityData(actor, id)
	end
end

-- daily
local function onNewDay(id, conf)
	return function (actor)
		local var = activitysystem.getSubVar(actor, id)
		if activitysystem.activityTimeIsEnd(id) then
			return
		end
		-- reset daily
		if var and var.data and var.data.daily then
			local daily = var.data.daily
			for index,_ in pairs(ActivityType7Config[id] or {}) do
				daily[index] = nil
			end
		end
	end
end

local function init(id, conf)
	actorevent.reg(aeGetWBossActScore, onGetWBossActScore(id, conf))
	-- daily
	actorevent.reg(aeNewDayArrive, onNewDay(id, conf))
end

subactivities.regConf(subType, ActivityType7Config)
subactivities.regInitFunc(subType, init)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)

--[[

local gmsystem    = require("systems.gm.gmsystem")
local gm = gmsystem.gmCmdHandlers

-- gm 调用
function gmAddBossScore( actor, score, actv_id)
	--获取活动变量
	local var = activitysystem.getSubVar(actor, actv_id)
	if not var then
		print("subactivitytype7.gmAddBossScore fail,maybe activity id is error," .. actv_id)
		return
	end
	actorevent.onEvent(actor, aeGetWBossActScore, score)
	print(LActor.getActorId(actor) .. " subactivitytype7.gmAddBossScore:" .. var.data.totalScore)
end

function gm.test7( actor, args )
	local id, index = tonumber(args[1]) or 0, tonumber(args[2]) or 0
	if index > 0 and id > 0 then
		local record = activitysystem.getSubVar(actor, id)
		print("xxxxxxxxxxxxx test7get,actor:"..LActor.getActorId(actor)..",index:"..index..",rewardsRecord:"..
			(record.rewardsRecord and record.rewardsRecord[index] or 0)..",daily:"..(record.daily and record.daily[index] or 0))
	end
end

function gm.test7get( actor, args )
	local id, index = tonumber(args[1]) or 0, tonumber(args[2]) or 0
	if id > 0 and index > 0 then
		local cfg = ActivityType7Config
		local record = activitysystem.getSubVar(actor, id)
		getReward(id, cfg, actor, record, nil, index)
	end
end

--]]
