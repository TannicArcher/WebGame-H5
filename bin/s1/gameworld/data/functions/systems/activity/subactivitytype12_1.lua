--限时兑换
module("subactivitytype12", package.seeall)


--[[ 全局保存数据
	...data = {
		sum 全服购买数
	}
	个人
	...data = {
		flag    是否已购买
		count   累计登陆天数
		bitset  已领取位集
	}
--]]
local p = Protocol
local subType = 12

local function onNewDay(id, conf)
	return function(actor)
		-- if activitysystem.activityTimeIsEnd(id) then
		-- 	return
		-- end

		local record = activitysystem.getSubVar(actor, id)
		if record == nil then record = {} end
		assert(record)
		if record.data == nil then record.data = {} end
		assert(record.data)
		if record.data.flag == nil then record.data.flag = 0 end
		assert(record.data.flag)
		if record.data.count == nil then record.data.count = 0 end
		assert(record.data.count)
		if record.data.bitset == nil then record.data.bitset = 0 end
		assert(record.data.bitset)

		-- 判断是否购买投资
		if record.data.flag == 0 then return end
		record.data.count = record.data.count + 1

		-- 同步登陆天数到前端
		local npack = LDataPack.allocPacket(actor, p.CMD_Activity, p.sActivityCmd_UpdateInfo)
		LDataPack.writeInt(npack, id)
		LDataPack.writeShort(npack, subType)
		LDataPack.writeByte(npack, record.data.flag and 1 or 0)
		LDataPack.writeByte(npack, record.data.count)
		LDataPack.writeInt(npack, record.data.bitset)
		LDataPack.flush(npack)
	end
end


local function onCheckTimeOut(id, conf)
	return function(actor)
		if activitysystem.activityTimeIsEnd(id) then
			--检查一下上次活动数据有没保留
			local record = activitysystem.getSubVar(actor, id)
			if record == nil then return end
			if record.data == nil then return end
			if next(record.data) == nil then return end
			--遍历发送邮件
			local bitset = record.data.bitset
			local aId = LActor.getActorId(actor)
			for index,value in ipairs(conf) do
				if not System.bitOPMask(bitset, index) then
					record.data.bitset = System.bitOpSetMask(bitset, index, true)
					--发邮件
					local mailData = {head=v.mailInfo.head, context=v.mailInfo.context, tAwardList=v.rewards}
					mailsystem.sendMailById(aId, mailData)
				end
			end
			record = nil
		end
	end
end

-- 活动初始化
local function init(id, conf)
	-- 检查配置
	local param = activitysystem.getParamConfig(id)
	assert(param~=nil)
	-- 用于累计登录天数
	actorevent.reg(aeNewDayArrive, onNewDay(id, conf))
	-- 检查活动结束就发奖励邮件
	-- actorevent.reg(aeUserLogin, onCheckTimeOut(id, conf))
end



-- 登录回调or同步回调
local function writeRecord(npack, record, config, id)
	--角色登录初始化表并下发
	if record == nil then record = {} end
	assert(record)
	if record.data == nil then record.data = {} end
	assert(record.data)
	if record.data.flag == nil then record.data.flag = 0 end
	assert(record.data.flag)
	if record.data.count == nil then record.data.count = 0 end
	assert(record.data.count)
	if record.data.bitset == nil then record.data.bitset = 0 end
	assert(record.data.bitset)

	LDataPack.writeByte(npack, record.data.flag)
	LDataPack.writeByte(npack, record.data.count)
	LDataPack.writeInt(npack, record.data.bitset)
end


local function checkReward(id, index, config, actor, record)
	if record.data.flag ~= 1 then
		return false
	end

	if config[index] and config[index].day > record.data.count then
		return false
	end

	if System.bitOPMask(record.data.bitset, index) then
		return false
	end

	if not LActor.canGiveAwards(actor, config[index].rewards) then
		LActor.sendTipWithId(actor, 1)
		return false
	end

	return true
end


-- 交互操作 购买or领取
local function op(id, typeconfig, actor, record, packet)
	local index = LDataPack.readShort(packet)

	assert(record)
	if record.data == nil then record.data = {} end
	assert(record.data)
	if record.data.flag == nil then record.data.flag = 0 end
	assert(record.data.flag)
	if record.data.count == nil then record.data.count = 0 end
	assert(record.data.count)
	if record.data.bitset == nil then record.data.bitset = 0 end
	assert(record.data.bitset)
	
	if index == 0 then
		--购买
		local param = activitysystem.getParamConfig(id)
		-- 检查是否已经购买
		if record.data.flag == 1 then return end
		-- 检查等级
		if LActor.getLevel(actor) < param.lv then
			print(LActor.getActorId(actor) .. "activity12 invest: lv limit")
			return
		end
		-- 检查元宝足够投资
		if LActor.getCurrency(actor, NumericType_YuanBao) < param.yuanbao then
			print(LActor.getActorId(actor) .. "activity12 invest: not enough yuanbao")
			return
		end

		-- 扣元宝
		if LActor.changeCurrency(actor, NumericType_YuanBao, -param.yuanbao, "type12 "..tostring(id)) then
			print(LActor.getActorId(actor) .. "activity12 invest: fail to changeCurrency yuanbao")
			return
		end
		
		-- 购买成功设置flag
		record.data.flag = 1
		-- 记录累计登录天数
		record.data.count = 1
		local npack = LDataPack.allocPacket(actor, p.CMD_Activity, p.sActivityCmd_GetRewardResult)
		LDataPack.writeByte(npack, 1)
		LDataPack.writeInt(npack, id)
		LDataPack.writeShort(npack, index)
		LDataPack.writeByte(npack, record.data.flag)
		LDataPack.writeByte(npack, record.data.count)
		LDataPack.writeInt(npack, record.data.bitset)
		LDataPack.flush(npack)

		-- 广播
		local name = LActor.getActorName(LActor.getActorId(actor))
		noticemanager.broadCastNotice( param.broast, name )
		-- 全服统计
		local gdata = activitysystem.getGlobalVar(id)
		gdata.sum = gdata.sum or 0
		gdata.sum = gdata.sum + 1
	else
		--领取道具
		local config = typeconfig[id]
		local ret = checkReward(id, index, config, actor, record)
		if ret then
			--发道具
			LActor.giveAwards(actor, config[index].rewards, "type12 "..tostring(id).."_"..tostring(index))
			-- 设置已领取
			record.data.bitset = System.bitOpSetMask(record.data.bitset, index, true)

			--回包
			local npack = LDataPack.allocPacket(actor, p.CMD_Activity, p.sActivityCmd_GetRewardResult)
			LDataPack.writeByte(npack, ret and 1 or 0)
			LDataPack.writeInt(npack, id)
			LDataPack.writeShort(npack, index)
			LDataPack.writeByte(npack, record.data.flag)
			LDataPack.writeByte(npack, record.data.count)
			LDataPack.writeInt(npack, record.data.bitset)
			LDataPack.flush(npack)
		end
	end
end

local function onReqInfo(id, typeconfig, actor, record, packet)
	local config = typeconfig[id]
	if config == nil then return end

	assert(record)
	if record.data == nil then record.data = {} end
	assert(record.data)
	if record.data.flag == nil then record.data.flag = 0 end
	assert(record.data.flag)
	if record.data.count == nil then record.data.count = 0 end
	assert(record.data.count)
	if record.data.bitset == nil then record.data.bitset = 0 end
	assert(record.data.bitset)

	local npack = LDataPack.allocPacket(actor, p.CMD_Activity, p.sActivityCmd_UpdateInfo)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, subType)
	LDataPack.writeByte(npack, record.data.flag)
	LDataPack.writeByte(npack, record.data.count)
	LDataPack.writeInt(npack, record.data.bitset)
	LDataPack.flush(npack)
end

--
subactivities.getRewardTimeOut[subType] = function(id, typeconfig, actor, record, packet)
	--检查一下上次活动数据有没保留
	if record == nil then return end
	if record.data == nil then return end
	if record.data.flag == nil then return end
	if record.data.count == nil then return end
	if record.data.bitset == nil then return end
    op(id, typeconfig, actor, record, packet)
end

subactivities.reqInfoTimeOut[subType] = function(id, typeconfig, actor, record, packet)
	--检查一下上次活动数据有没保留
	if record == nil then return end
	if record.data == nil then return end
	if record.data.flag == nil then return end
	if record.data.count == nil then return end
	if record.data.bitset == nil then return end
    onReqInfo(id, typeconfig, actor, record, packet)
end

subactivities.regConf(subType, ActivityType12Config)
subactivities.regInitFunc(subType, init)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, op)
subactivities.regReqInfoFunc(subType, onReqInfo)

