module("actorexringfuben", package.seeall)

--[[
data = {
	usedCount		--已使用次数
	buyCount        --购买的次数
	isReward        --是否已领取了奖励
	itemCount		--道具可使用次数
}
]]

local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if nil == data.exringfuben then data.exringfuben = {} end
	return data.exringfuben
end

--获取可挑战次数
function getChallengeCount(actor)
	--是否开启了烈焰戒指
	if 0 >= LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing) then return 0 end
	local data = getData(actor)
	return  (ActorExRingFubenConfig.freeCount or 0) + (data.buyCount or 0) +
				(data.itemCount or 0) - (data.usedCount or 0) + privilegemonthcard.getExringFubenCount(actor)
end

--下发副本信息
function sendFubenInfo(actor)
	local data = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_SendActorExRingFbInfo)
	LDataPack.writeShort(npack, data.buyCount or 0)
	LDataPack.writeShort(npack, getChallengeCount(actor))
	LDataPack.writeByte(npack, data.isReward and 1 or 0)
	LDataPack.flush(npack)
end

--获取玩家一共可购买挑战次数
local function getTotalBuyCount(actor)
	local level = LActor.getVipLevel(actor)
	return ActorExRingFubenConfig.vipCount[level] or 0
end

--设置道具额外增加的次数
function SetItemCount(actor, count)
	local var = getData(actor)
	var.itemCount = (var.itemCount or 0) + count
	sendFubenInfo(actor)
end

--请求挑战副本
local function reqEnterFuBen(actor, packet)
	local actorId = LActor.getActorId(actor)
	--是否开启了烈焰戒指
	if 0 >= LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing) then
		print("actorexringfuben.reqEnterFuBen: not open ring, actorId:"..tostring(actorId))
		return
	end

	--是否在副本
	if LActor.isInFuben(actor) then
		print("actorexringfuben.reqEnterFuBen: already in fuben, actorId:"..tostring(actorId))
		return
	end

	local data = getData(actor)

	--判断是否还有奖励未领取
	if data.isReward then
		print("actorexringfuben.reqEnterFuBen: reward not get, actorId:"..tostring(actorId))
		return
	end

	--是否需要购买
	if 0 >= getChallengeCount(actor)  then
		--是否还有次数
		local totalCount = getTotalBuyCount(actor)
		if (data.buyCount or 0) >= totalCount then
			print("actorexringfuben.reqEnterFuBen: count not enough, actorId:"..tostring(actorId))
			return
		end

		if ActorExRingFubenConfig.vipcost > LActor.getCurrency(actor, NumericType_YuanBao) then
			print("actorexringfuben.reqEnterFuBen: money not enough, actorId:"..tostring(actorId))
			return
		end

		--扣钱
		LActor.changeYuanBao(actor, 0-ActorExRingFubenConfig.vipcost, "exfuben buy")

		data.buyCount = (data.buyCount or 0) + 1
	end

	--创建副本
	local hfuben = Fuben.createFuBen(ActorExRingFubenConfig.fbId)
	if 0 == hfuben then
		print("actorexringfuben.reqEnterFuBen: createFuBen failed, actorId:"..tostring(actorId))
		return
	end

	--进入副本
	LActor.enterFuBen(actor, hfuben)
end


--请求领取奖励
local function reqReceive(actor, packet)
	local times = LDataPack.readShort(packet)
	local data = getData(actor)
	local actorId = LActor.getActorId(actor)
	--是否有奖励领取
	if not data.isReward then print("actorexringfuben.reqReceive: no reward get, actorId:"..tostring(actorId)) return end

	local price = ActorExRingFubenConfig.recPrice[times]
	if not price then print("actorexringfuben.reqReceive: price is nil, times:"..tostring(times)..", actorId:"..tostring(actorId)) return end

	--扣钱
	if price > 0 then
		if price > LActor.getCurrency(actor, NumericType_YuanBao) then
			print("actorexringfuben.reqReceive: money not enough, actorId:"..tostring(actorId))
			return
		end

		LActor.changeYuanBao(actor, 0-price, "exfuben rewardtimes:"..tostring(times))
	end

	--根据次数获取奖励
	local reward = LActor.getRewardByTimes(ActorExRingFubenConfig.reward, times)
	LActor.giveAwards(actor, reward, "exfuben, rewardtimes:".. tostring(times))

	data.isReward = nil

	sendFubenInfo(actor)
end

--请求扫荡副本
local function reqRaids(actor, packet)
	local actorId = LActor.getActorId(actor)
	--判断是否有特权
	if true ~= privilegemonthcard.isOpenPrivilegeCard(actor) then
		print("actorexringfuben.reqRaids: not have privilege, actorId:"..tostring(actorId))
		return
	end
	--判断是否还有次数
	if getChallengeCount(actor) <= 0 then
		print("actorexringfuben.reqRaids: not have challenge count, actorId:"..tostring(actorId))
		return
	end
	local times = LDataPack.readShort(packet)
	local data = getData(actor)
	--是否有奖励领取
	if data.isReward then print("actorexringfuben.reqRaids: have reward not get, actorId:"..tostring(actorId)) return end

	local price = ActorExRingFubenConfig.recPrice[times]
	if not price then print("actorexringfuben.reqRaids: price is nil, times:"..tostring(times)..", actorId:"..tostring(actorId)) return end
	--扣钱
	if price > 0 then
		if price > LActor.getCurrency(actor, NumericType_YuanBao) then
			print("actorexringfuben.reqRaids: money not enough, actorId:"..tostring(actorId))
			return
		end

		LActor.changeYuanBao(actor, 0-price, "raids exfuben rewardtimes:"..tostring(times))
	end
	--根据次数获取奖励
	local reward = LActor.getRewardByTimes(ActorExRingFubenConfig.reward, times)
	LActor.giveAwards(actor, reward, "raids exfuben rewardtimes:".. tostring(times))
	data.usedCount = (data.usedCount or 0) + 1
	sendFubenInfo(actor)
end

--副本胜利回调
local function onWin(ins)
	local actor = ins:getActorList()[1]
	if nil == actor then print("exfuben.onWin can't find actor") return end

	local data = getData(actor)
	data.usedCount = (data.usedCount or 0) + 1
	data.isReward = 1
	instancesystem.setInsRewards(ins, actor, nil)

	sendFubenInfo(actor)
end

--副本失败回调
local function onLose(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then print("exfuben.onLose can't find actor") return end
	instancesystem.setInsRewards(ins, actor, nil)
end

--刷新回调
local function onNewDay(actor, isLogin)
	--是否开启了烈焰戒指
	if 0 >= LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing) then return end

	local data = getData(actor)
	data.usedCount = nil
	data.itemCount = nil
	data.buyCount = nil
	if not isLogin then sendFubenInfo(actor) end
end

--登陆回调
local function onLogin(actor)
	--是否开启了烈焰戒指
	if 0 >= LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing) then return end

	sendFubenInfo(actor)
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

--激活戒指有次数
local function actExRing(actor, idx)
	if idx and idx == ActorExRingType_HuoYanRing then
		sendFubenInfo(actor)
	end
end

--初始化全局数据
local function initGlobalData()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeActAExring, actExRing)

	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_ActorExRingFbChallenge, reqEnterFuBen) --请求挑战副本
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_ActorExRingFbReceive, reqReceive)--请求领取副本奖励
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_ActorExRingFbRaids, reqRaids)--请求扫荡副本

	insevent.registerInstanceWin(ActorExRingFubenConfig.fbId, onWin)
	insevent.registerInstanceLose(ActorExRingFubenConfig.fbId, onLose)
	insevent.registerInstanceOffline(ActorExRingFubenConfig.fbId, onOffline)
end

table.insert(InitFnTable, initGlobalData)