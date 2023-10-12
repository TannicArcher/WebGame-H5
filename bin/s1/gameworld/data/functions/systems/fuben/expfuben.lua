module("expfuben", package.seeall)

--[[
data = {
	usedCount,		--已使用次数
	raidCount,		--已扫荡次数
	winid,		--赢了的副本ID
	raidId,		--扫荡的ID
}
]]

local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if data == nil then return nil end
	if data.expfuben == nil then
		data.expfuben = {}
	end
	return data.expfuben
end

local function getFbIdByLv(actor)
	local lv = LActor.getLevel(actor)
	for _,v in ipairs(ExpFubenConfig) do
		if v.slv <= lv and lv <= v.elv then
			return v
		end
	end
	return nil
end

--获取玩家一共可扫荡次数
local function getRaidTotalCount(actor)
	local vip = LActor.getVipLevel(actor)
	return (ExpFubenBaseConfig.vipBuyCount[vip] or 0)
end

--获取玩家一共可挑战次数
local function getTotalCount(actor)
	local vip = LActor.getVipLevel(actor)
	return (ExpFubenBaseConfig.vipCount[vip] or 0) + ExpFubenBaseConfig.freeCount
end

--下发经验副本信息
local function sendExpFubenInfo(actor)
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_SendExpFbInfo)
	local data = getData(actor)
	LDataPack.writeByte(npack, data.usedCount or 0)
	LDataPack.writeByte(npack, data.raidCount or 0)
	LDataPack.writeByte(npack, data.winid or 0)
	LDataPack.writeByte(npack, data.raidId or 0)
	LDataPack.flush(npack)
end

--获取副本配置里的怪物总数
local function getTotalMonCount(ins)
	local insCfg = InstanceConfig[ins.id]
	if not insCfg then return 0 end
	local totalCount = 0
	for _,v in ipairs(insCfg.monsterGroup or {}) do
		totalCount = totalCount + #v
	end
	return totalCount
end

--请求挑战副本
local function reqEnterFuBen(actor, packet)
	local data = getData(actor)
	--判断是否需要挑战
	if data.usedCount and data.usedCount >= getTotalCount(actor) then
		print(LActor.getActorId(actor).." expfuben.reqEnterFuBen not have count")
		return
	end
	--判断是否还有奖励未领取
	if data.winid then
		print("expfuben.reqEnterFuBen has reward. actor: ".. LActor.getActorId(actor))
		return
	end
	if LActor.isInFuben(actor) then
		print(LActor.getActorId(actor).." expfuben.reqEnterFuBen failed. actor is in fuben")
		return
	end
	local conf = getFbIdByLv(actor)
	if not conf then
		print(LActor.getActorId(actor).." expfuben.reqEnterFuBen, conf is nil, actor_lv:"..LActor.getLevel(actor))
		return
	end
	--创建副本
	local hfuben = Fuben.createFuBen(conf.fbId)
	if hfuben == 0 then
		print(LActor.getActorId(actor).." expfuben.reqEnterFuBen create fuben failed."..conf.fbId)
		return
	end
	
	--记录进入前的数据, 在副本里有可能升级
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins ~= nil then
		ins.data.id = conf.id
	end
	--进入副本
	LActor.enterFuBen(actor, hfuben)
	--下发怪物总数
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_SendMonsterCount)
	LDataPack.writeInt(npack, getTotalMonCount(ins))
	LDataPack.flush(npack)
end

--请求扫荡副本
local function reqRaid(actor, packet)
	--local times = LDataPack.readByte(packet)
	--判断扫荡倍率消耗
	--local price = ExpFubenBaseConfig.buyPrice[times]
	--if not price then
	--	print("expfuben.reqRaid times("..times..") not have conf. actor: ".. LActor.getActorId(actor))
	--	return
	--end
	local data = getData(actor)
	--判断是否还有通关奖励未领取
	if data.winid then
		print(LActor.getActorId(actor).." expfuben.reqRaid has winid")
		return
	end
	--判断是否还有扫荡奖励未领取
	if data.raidId then
		print(LActor.getActorId(actor).." expfuben.reqRaid has raidId")
		return
	end
	--判断是否需要挑战
	if not data.usedCount or data.usedCount < ExpFubenBaseConfig.freeCount then
		print(LActor.getActorId(actor).." expfuben.reqRaid have count")
		return
	end
	--判断是否还有扫荡次数
	if (data.raidCount or 0) >= getRaidTotalCount(actor) then
		print(LActor.getActorId(actor).." expfuben.reqRaid not have raidCount")
		return
	end
	--扣钱
	--if price > 0 then
	--	if price > LActor.getCurrency(actor, NumericType_YuanBao) then
	--		print("expfuben.reqRaid yuanbao insufficient. actor: ".. LActor.getActorId(actor))
	--		return
	--	end
	--	LActor.changeYuanBao(actor, 0-price, "raid expfuben times:"..tostring(times))
	--end
	--获取扫荡的经验副本
	local conf = getFbIdByLv(actor)
	if not conf then
		print(LActor.getActorId(actor).." expfuben.reqRaid, conf is nil, actor_lv:"..LActor.getLevel(actor))
		return
	end
	--加扫荡次数
	data.raidCount = (data.raidCount or 0) + 1
	--发放扫荡奖励
	--LActor.addExp(actor, conf.exp * times, "raid expfb id:"..conf.id)
	data.raidId = conf.id
	--下发最新信息
	sendExpFubenInfo(actor)
end

--请求领取奖励
local function reqReceive(actor, packet)
	local type = LDataPack.readByte(packet)
	local times = LDataPack.readByte(packet)
	--判断领取倍率消耗
	local price = nil
	if type == 0 then
		price = ExpFubenBaseConfig.recPrice[times]
	else
		price = ExpFubenBaseConfig.buyPrice[times]
	end
	if not price then
		print(LActor.getActorId(actor).." expfuben.reqReceive type("..type..") times("..times..") not have conf")
		return
	end
	local data = getData(actor)
	--判断是否还有奖励领取
	local id = nil
	if type == 0 then
		id = data.winid
	else
		id = data.raidId
	end
	if not id then
		print(LActor.getActorId(actor).." expfuben.reqReceive type("..type..") not have id")
		return
	end
	--扣钱
	if price > 0 then
		if price > LActor.getCurrency(actor, NumericType_YuanBao) then
			print(LActor.getActorId(actor).." expfuben.reqReceive yuanbao insufficient")
			return
		end
		LActor.changeYuanBao(actor, 0-price, "expfuben reward times:"..tostring(times))
	end
	--获取领取的经验副本配置
	local conf = ExpFubenConfig[id]
	if not conf then
		print(LActor.getActorId(actor).." expfuben.reqReceive, conf is nil, type:"..type.." id:"..tostring(id))
		return
	end
	--清空
	data.winid = nil
	data.raidId = nil

	--贵族加成
	local exp = monthcard.updateFubenExp(actor, conf.exp)

	--发放领取奖励
	LActor.addExp(actor, exp * times, "rec expfb id:"..conf.id)

	actorevent.onEvent(actor, aeExpFubenAwardType, times, 1)
	--下发最新信息
	sendExpFubenInfo(actor)
end

--副本胜利回调
local function onWin(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then print("expfuben.onWin can't find actor") return end
	local data = getData(actor)
	data.usedCount = (data.usedCount or 0) + 1
	data.winid = ins.data.id
	instancesystem.setInsRewards(ins, actor, nil)
	--下发最新信息
	sendExpFubenInfo(actor)
end

--副本失败回调
local function onLose(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then print("expfuben.onLose can't find actor") return end
	instancesystem.setInsRewards(ins, actor, nil)
end

--日刷新回调
local function onNewDay(actor)
	local data = getData(actor)
	data.raidCount = nil
	data.usedCount = nil
	sendExpFubenInfo(actor)
end

--登陆回调
local function onLogin(actor)
	if ExpFubenBaseConfig.openLv <= LActor.getLevel(actor) then
		--下发最新信息
		sendExpFubenInfo(actor)
	end
end

function onLevelUp(actor, level)
	if ExpFubenBaseConfig.openLv == level then
		--下发最新信息
		sendExpFubenInfo(actor)
	end
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

--初始化全局数据
local function initGlobalData()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeLevel, onLevelUp)

	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_ExpFbChallenge, reqEnterFuBen) --请求挑战经验副本
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_ExpFbRaid, reqRaid) --请求扫荡副本
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_ExpFbReceive, reqReceive)--请求领取副本奖励

	for _, v in pairs(ExpFubenConfig) do
		insevent.registerInstanceWin(v.fbId, onWin)
		insevent.registerInstanceLose(v.fbId, onLose)
		insevent.registerInstanceOffline(v.fbId, onOffline)
	end
end

table.insert(InitFnTable, initGlobalData)