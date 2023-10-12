--击杀野外boss活动
module("subactivitytype6", package.seeall)

local p = Protocol
local subType = 6
local function writeRecord(npack, record, config, id, actor)
	if npack == nil then return end
	local v = record and record.data and record.data.rewardsRecord or 0
	LDataPack.writeInt(npack, v)
	local okIdx = record and record.data and record.data.okIdx or {}
	local count = #config
	LDataPack.writeShort(npack, count)
	for idx=1,count do
		LDataPack.writeShort(npack, okIdx[idx] or 0)
	end
end

local function checkReward(index, config, actor, record)
	local cfg = config[index]
	if cfg == nil then
		print("checkReward config is nil index:"..tostring(index)..",subType:"..subType)
		return false
	end
	if index < 0 or index > 32 then
		print("checkReward index is invalid.."..tostring(index)..",subType:"..subType)
		return false
	end
	--判断是否已领
	if record.data.rewardsRecord == nil then
		record.data.rewardsRecord = 0
	end
	if System.bitOPMask(record.data.rewardsRecord, index) then
		return false
	end
	
	--判断是否已击杀所有boss
	local okIdx = record and record.data and record.data.okIdx or {}
	if (okIdx[index] or 0) < (math.pow(2,#(cfg.bossID or {})) - 1) then 
		return false
	end
	
	--判断是否能领取奖励
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

	local ret = checkReward(index, config, actor, record)
	if ret then
		--记录
		record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, index, true)
		LActor.giveAwards(actor, config[index].rewards, "activity type6 index:"..tostring(index))
		--公告
		if config[index].noticeId then
			noticemanager.broadCastNotice(config[index].noticeId, LActor.getName(actor))
		end
	end

	local npack = LDataPack.allocPacket(actor, p.CMD_Activity, p.sActivityCmd_GetRewardResult)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, record.data.rewardsRecord or 0)
	LDataPack.flush(npack)
end

local function onGetBelong(id, conf)
	return function(actor, cid, bid)
		if activitysystem.activityTimeIsEnd(id) then return end
		local var = activitysystem.getSubVar(actor, id)
		if not var.data then var.data = {} end
		if not var.data.okIdx then var.data.okIdx = {} end
		local okIdx = var.data.okIdx
		
		--寻找是否需要记录这个bossid
		local isFind = false
		for index,v in ipairs(conf) do
			--这一项还没完成
			if (okIdx[index] or 0) < (math.pow(2,#(v.bossID or {})) - 1) then 
				for gid,bossGroup in ipairs(v.bossID or {}) do
					--这一组还没完成
					if not okIdx[index] or not System.bitOPMask(okIdx[index], gid-1) then
						for _,bossID in ipairs(bossGroup) do --找组里面有没匹配得上的怪物ID
							if bossID == bid then
								--这组里面找到了这个BOSSID就当这组完成
								okIdx[index] = System.bitOpSetMask((okIdx[index] or 0), gid-1, true)
								isFind = true
								break
							end
						end
					end
				end
			end
		end
		if isFind then
			activitysystem.sendActivityData(actor, id)
		end
	end
end

local function initFunc(id, conf)
	actorevent.reg(aeGetWroldBossBelong, onGetBelong(id, conf))
	actorevent.reg(aeDayFuBenWin, onGetBelong(id, conf))
end


subactivities.regConf(subType, ActivityType6Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)

