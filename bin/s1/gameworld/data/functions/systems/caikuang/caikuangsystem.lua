--[[保存在玩家上的信息
	isFirst			是否第一次刷新矿
	caikuangCount   采矿次数
	lueduoCount     掠夺次数
	kuangId         当前矿id
	refreshTimes    当前矿总刷新次数
	singleRefreshTimes  当前矿品质刷新次数
	startTime       开始时间
	endTimer        结束时间
	sceneId  		场景id
	eid				定时器id
	isReward        是否可以领取奖励，1可以领取，领取后置为nil
	tActorId        正在被掠夺的目标id  下线会置为nil
	tKuangId        正在被掠夺的矿id  下线会置为nil

	attacker = { {name,result} }，当前矿掠夺我的攻击者, result为1表示成功，2表示失败
	record = {
		{ time, recordEvent, kuangid, actorid, actorname, win, fuchou, job, sex, fight }   别人抢夺我的记录
		{ time, recordEvent, kuangid, actorid, actorname, win }  我抢夺别人的记录
	}

	record.minIndex 记录的最小索引
	record.maxIndex 记录的最大索引
--]]

module("caikuangsystem", package.seeall)

--记录事件
local recordEvent = {
	beRob = 1,  -- 被抢夺
	rob = 2,     -- 抢夺
	revenge = 3, --复仇
}

local systemId = Protocol.CMD_Kuang
local BaseConf = CaiKuangConfig
local kuangLevelConf = KuangYuanConfig


local function getKuangVarData(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.caikuang then var.caikuang = {} end

	return var.caikuang
end

--随机获取品质
local function getRandomKuangId()
	local n = math.random(1, 10000)
	local sum = 0
	local kuang_id = 1
	for id, v in ipairs(kuangLevelConf or {}) do
		sum = sum + v.rate
		if n <= sum then kuang_id = id break end
	end

	return kuang_id
end

local function sendKuangBaseInfo(actor)
	local var = getKuangVarData(actor)
    local npack = LDataPack.allocPacket(actor, systemId, Protocol.sKuang_KuangInfo)

	LDataPack.writeShort(npack, var.caikuangCount or 0)
	LDataPack.writeShort(npack, var.lueduoCount or 0)
	LDataPack.writeInt(npack, var.kuangId or 0)
	LDataPack.writeInt(npack, var.refreshTimes or 0)
	LDataPack.writeInt(npack, var.singleRefreshTimes or 0)
	LDataPack.writeInt(npack, var.endTime or 0)

	LDataPack.flush(npack)
end

--矿信息初始化
local function initKuangInfo(actor)
	local var = getKuangVarData(actor)
	var.refreshTimes = 0
	var.singleRefreshTimes = 0
	var.startTime = 0
	var.attacker = {}
	var.kuangId = 0
	var.isReward = nil

	sendKuangBaseInfo(actor)
end

--每天重置
local function dayReset(actor)
	local var = getKuangVarData(actor)
	if not var then return end

	var.caikuangCount = 0
	var.lueduoCount = 0
end

function kuangIsFinish(kuangId, endTime)
	if 0 == kuangId then return true end

	--if System.getNowTime() >= startTime + kuangLevelConf[kuangId].needTime then return true end
	if System.getNowTime() >= (endTime or 0) then return true end

	return false
end

--开启条件判断
local function isOpenCaiKuang(actor)
	local level = LActor.getLevel(actor)
	local openday = System.getOpenServerDay() + 1
	if level < BaseConf.openLevel then return false end
	if openday < BaseConf.openServerDay then return false end

	return true
end

--发送品质刷新信息
local function sendKuangRefreshInfo(actor)
	local var = getKuangVarData(actor)
	local npack = LDataPack.allocPacket(actor, systemId, Protocol.sKuang_RefreshKuangLevel)
	LDataPack.writeInt(npack, var.kuangId or 0)
	LDataPack.writeInt(npack, var.refreshTimes or 0)
	LDataPack.writeInt(npack, var.singleRefreshTimes or 0)

	LDataPack.flush(npack)
end

--请求进入副本
local function requestEnterFuben(actor)
	local actorId = LActor.getActorId(actor)
	if false == isOpenCaiKuang(actor) then
		print("caikuangsystem.requestEnterFuben:isOpenCaiKuang is false, actorId:"..tostring(actorId))
		return
	end

	local var = getKuangVarData(actor)

	if true == LActor.isInFuben(actor) then print("caikuangsystem.requestEnterFuben:is in fuben, actorId:"..tostring(actorId)) return end

	local isFinish = kuangIsFinish(var.kuangId or 0, var.endTime or 0)
	if 1 == (var.isReward or 0) then isFinish = true end

	--获取可以进入的副本handle
	local handle = caikuangscene.getValidFubenHandle(actor, isFinish)

	--进入
	local ret = LActor.enterFuBen(actor, handle)
	if not ret then print("caikuangsystem.requestEnterFuben:enterFuBen false, actorId:"..tostring(actorId)) return end
end

--是否可以提高品质
local function checkLevelIsUpgrade(kuangId, singleRefreshTimes)
	local n = math.random(1, 10000)
	local isUpgrade = false
	if n <= kuangLevelConf[kuangId].uprate then isUpgrade = true end

	--判断保底次数,不存在一次刷新跳越两个品质的情况
	if kuangLevelConf[kuangId].baseTime <= (singleRefreshTimes or 0) then isUpgrade = true end

	return isUpgrade
end

--结束定时器
local function endTimer(actor)
	if not actor then return end
	local var = getKuangVarData(actor)
	var.isReward = 1
	var.eid = nil

	local npack = LDataPack.allocPacket(actor, systemId, Protocol.sKuang_CaiKuangEnd)
	LDataPack.writeShort(npack, var.kuangId)
	LDataPack.writeShort(npack, #(var.attacker or {}))

	for i=1, #(var.attacker or {}) do
		LDataPack.writeString(npack, var.attacker[i].name or "")
		LDataPack.writeByte(npack, var.attacker[i].result or 0)
	end

	LDataPack.flush(npack)
end

--采矿定时器
local function setTimer(actor)
	local var = getKuangVarData(actor)
	if 0 == (var.kuangId or 0) then return end
	if 0 == (var.startTime or 0) then return end
	if 1 == (var.isReward or 0) then endTimer(actor) return end

	--保存结束时间
	if not var.endTime then
		local conf = kuangLevelConf[var.kuangId]
		var.endTime = var.startTime + conf.needTime - privilegemonthcard.getKuangReduceTime(actor)
	else
		if (var.endTime or 0) < System.getNowTime() then endTimer(actor) return end
	end

	var.eid = LActor.postScriptEventLite(actor, ((var.endTime or 0) - System.getNowTime()) * 1000, function() endTimer(actor) end)
end

--采矿公告
local function kuangBroadcast(actor)
	local var = getKuangVarData(actor)
	if var.kuangId >= BaseConf.noticeLevel then
		local kuangName = kuangLevelConf[var.kuangId].name
		noticemanager.broadCastNotice(BaseConf.noticeId, LActor.getActorName(LActor.getActorId(actor)), kuangName)
	end
end

--获取被掠夺成功的次数
local function getBeRobCount(actor)
	local var = getKuangVarData(actor)
	local count = 0
	for i=1, #(var.attacker or {}) do
		if var.attacker[i] and 1 == var.attacker[i].result then count = count + 1 end
	end

	return count
end

--获取奖励内容
local function getRewardInfo(actor)
	local var = getKuangVarData(actor)
	local conf = kuangLevelConf[var.kuangId or 0]
	if not conf then return nil end

	--获取被掠夺成功的次数
	local count = getBeRobCount(actor)

	local reward = utils.table_clone(conf.rewards)

	--扣奖励
	for k, v in pairs(reward or {}) do
		v.count = v.count - math.ceil(count * v.count * conf.robPrecent / 100)
	end

	LActor.mergeRewrd(reward, conf.rewardItem)

	return reward
end

--获取掠夺奖励内容
local function getRobRewardInfo(kuangId)
	local conf = kuangLevelConf[kuangId]
	if not conf then
		print("caikuangsystem.getRobRewardInfo:conf is nil, kuangId:"..tostring(kuangId))
		return nil
	end

	local reward = {}
	for k, v in pairs(conf.rewards or {}) do
		table.insert(reward, {id=v.id, type=v.type, count=math.ceil(v.count * conf.robPrecent / 100)})
	end

	return reward
end

--获取复仇奖励内容
local function getRevengeRewardInfo(kuangId)
	local conf = kuangLevelConf[kuangId]
	if not conf then
		print("caikuangsystem.getRevengeRewardInfo:conf is nil, kuangId:"..tostring(kuangId))
		return nil
	end

	local reward = {}
	for k, v in pairs(conf.rewards or {}) do
		table.insert(reward, {id=v.id, type=v.type, count=math.ceil(v.count * conf.revengePrecent / 100)})
	end

	return reward
end

--返回该索引的记录
local function getRecordByIndex(actor, index)
	local var = getKuangVarData(actor)
	if not var then return end
	if nil == var.record then var.record = {} end

	local minIndex = (var.record.minIndex or 1)
	local record = var.record[index+minIndex-1]

	return record
end

--增加记录
local function addRecord(actor, recordType, args)
	local var = getKuangVarData(actor)
	if not var then return end

	local time = System.getNowTime()
	local record = {time, recordType, unpack(args)}
	if nil == var.record then var.record = {} end

	local maxIndex = (var.record.maxIndex or 1)

	var.record[maxIndex] = {}

	for k, v in ipairs(record) do var.record[maxIndex][k] = v end

	var.record.maxIndex = (var.record.maxIndex or 1) + 1
	local minIndex = (var.record.minIndex or 1)

	--只保留固定条记录
	local count = var.record.maxIndex - minIndex
	if BaseConf.recordMaxCount < count then
		local cnt = count - BaseConf.recordMaxCount
		for i=0, cnt-1 do var.record[minIndex+i] = nil end
		var.record.minIndex = minIndex + cnt
	end
end

--通知矿记录更新
local function sendKuangRecordUpdate(actor)
	local npack = LDataPack.allocPacket(actor, systemId, Protocol.sKuang_KuangRecordUpdate)
	LDataPack.flush(npack)
end

--记录更新
local function recordUpdate(actor, result, tActorId, tKuangId)
	if not actor then return end

	local actorId = LActor.getActorId(actor)
	local roleData = LActor.getRoleData(actor, 0)
	local job = roleData.job
	local sex = roleData.sex
	local power = LActor.getActorPower(actorId)

	local var = getKuangVarData(actor)
	local tActor = LActor.getActorById(tActorId, true, true)

	--增加自己的掠夺记录
	addRecord(actor, recordEvent.rob, {tKuangId, tActorId, LActor.getActorName(tActorId), result})

	--增加对方的被掠夺记录
	if tActor then
		addRecord(tActor, recordEvent.beRob, {tKuangId, actorId, LActor.getActorName(actorId), result, 0, job, sex, power})

		--被掠夺需要保存数据在矿结束时显示
		local tVar = getKuangVarData(tActor)
		if tVar then
			if nil == tVar.attacker then tVar.attacker = {} end
			tVar.attacker[#tVar.attacker+1] = {}
			tVar.attacker[#tVar.attacker].name = LActor.getActorName(actorId)
			tVar.attacker[#tVar.attacker].result = result
		end

		--目标玩家在线需要通知记录更新,镜像则需要保存数据
		if false == LActor.isImage(tActor) then
			if 1 == result then sendKuangRecordUpdate(tActor) end
		else
			LActor.saveDb(tActor)
		end
	end

	--通知
	--sendKuangRecordUpdate(actor)
end

local function initSceneInfo(actor)
	local var = getKuangVarData(actor)
	local actorId = LActor.getActorId(actor)
	if not var then return end

	if var.tActorId and var.tKuangId then
		caikuangscene.kuangAttackStatus(actorId, var.tActorId, var.sceneId or 0, false)

		recordUpdate(actor, 0, var.tActorId, var.tKuangId)
	end

	var.tActorId = nil
	var.tKuangId = nil
	var.sceneId = nil
end

-- 刷新矿品质
local function requestRefreshKuangLevel(actor, packet)
	local actorId = LActor.getActorId(actor)
	local type = LDataPack.readInt(packet)
	if false == isOpenCaiKuang(actor) then
		print("caikuangsystem.requestRefreshKuangLevel:isOpenCaiKuang is false, actorId:"..tostring(actorId))
		return
	end

	local var = getKuangVarData(actor)

	--次数判断
	if BaseConf.maxOpenKuangCount + privilegemonthcard.getKuangAddCount(actor) <= (var.caikuangCount or 0) then
		print("caikuangsystem.requestRefreshKuangLevel:caikuangCount is max, actorId:"..tostring(actorId))
		return
	end

	--判断是否有正在开采的矿
	if 0 < (var.startTime or 0) then
		print("caikuangsystem.requestRefreshKuangLevel:kuang is not finish, actorId:"..tostring(actorId))
		return
	end

	--品质已经最高刷不了
	if #kuangLevelConf <= (var.kuangId or 0) then
		print("caikuangsystem.requestRefreshKuangLevel:kuangId is max, actorId:"..tostring(actorId))
		return
	end

	--没有刷新过就初始化下
	if 0 == (var.kuangId or 0) then
		var.kuangId = getRandomKuangId()
		sendKuangRefreshInfo(actor)
		return
	end

	--1使用道具，其它使用元宝
	if 1 == type then
		local haveItemCount = LActor.getItemCount(actor, CaiKuangConfig.needItem.id)
		if haveItemCount < CaiKuangConfig.needItem.count then
			print("caikuangsystem.requestRefreshKuangLevel:item not enough, actorId:"..tostring(actorId))
			return
		end

		LActor.costItem(actor, CaiKuangConfig.needItem.id, CaiKuangConfig.needItem.count, "refreshKuangLevel")
	else
		local index = math.min((var.refreshTimes or 0) + 1, #BaseConf.refreshCost)
		local needCost = BaseConf.refreshCost[index]

		if 0 < needCost then
			if LActor.getCurrency(actor, NumericType_YuanBao) < needCost then
				print("caikuangsystem.requestRefreshKuangLevel:refresh money not enough, actorId:"..tostring(actorId))
				return
			end

			LActor.changeCurrency(actor, NumericType_YuanBao, -needCost, "refreshKuangLevel")
		end
	end

	var.refreshTimes = (var.refreshTimes or 0) + 1
	var.singleRefreshTimes = (var.singleRefreshTimes or 0) + 1

	--第一次刷新必然最高品质
	if not var.isFirst then
		var.kuangId = #kuangLevelConf
		var.singleRefreshTimes = 0
		var.isFirst = 1
	else
		--是否可以提高品质
		if true == checkLevelIsUpgrade(var.kuangId, var.singleRefreshTimes) then
			var.kuangId = var.kuangId + 1
			var.singleRefreshTimes = 0
		end
	end

	sendKuangRefreshInfo(actor)
end

--开始采矿
local function requestStartCaiKuang(actor)
	local actorId = LActor.getActorId(actor)
	if false == isOpenCaiKuang(actor) then
		print("caikuangsystem.requestStartCaiKuang:isOpenCaiKuang is false, actorId:"..tostring(actorId))
		return
	end

	local var = getKuangVarData(actor)

	if 0 == (var.sceneId or 0) then
		print("caikuangsystem.requestStartCaiKuang:sceneId is 0, actorId:"..tostring(actorId))
		return
	end

	--次数判断
	if BaseConf.maxOpenKuangCount + privilegemonthcard.getKuangAddCount(actor) <= (var.caikuangCount or 0) then
		print("caikuangsystem.requestStartCaiKuang:caikuangCount is max, actorId:"..tostring(actorId))
		return
	end

	--当前矿是否已结束
	if 0 < (var.startTime or 0) then
		print("caikuangsystem.requestStartCaiKuang:kuang is not finish, actorId:"..tostring(actorId))
		return
	end

	--有没有矿
	if 0 == (var.kuangId or 0) then
		print("caikuangsystem.requestStartCaiKuang:kuangid is 0, actorId:"..tostring(actorId))
		return
	end

	--当前场景矿数目是否满了
	local count = caikuangscene.getKuangCount(var.sceneId)
	if BaseConf.maxKuangCount <= count then
		print("caikuangsystem.requestStartCaiKuang:scene count is max, actorId:"..tostring(actorId))
		return
	end

	var.startTime = System.getNowTime()
	var.caikuangCount = (var.caikuangCount or 0) + 1

	setTimer(actor)

	--增加矿
	caikuangscene.addKuang(actor, var)

	--公告
	kuangBroadcast(actor)

	sendKuangBaseInfo(actor)

	actorevent.onEvent(actor, aeCaiKuang, var.kuangId)

	print("caikuangsystem.requestStartCaiKuang:start caikuang, kuangId:"..tostring(var.kuangId)..", actorId:"..tostring(actorId))
end

--领取奖励
local function requestGetReward(actor, pack)
	local actorId = LActor.getActorId(actor)
	if false == isOpenCaiKuang(actor) then
		print("caikuangsystem.requestGetReward:isOpenCaiKuang is false, actorId:"..tostring(actorId))
		return
	end

	local isDouble = false
	if 1 == LDataPack.readShort(pack) then isDouble = true end

	local var = getKuangVarData(actor)

	if 0 == (var.sceneId or 0) then print("caikuangsystem.requestGetReward:sceneId is 0, actorId:"..tostring(actorId)) return end

	--有没有矿
	if 0 == (var.kuangId or 0) then print("caikuangsystem.requestGetReward:kuangid is 0, actorId:"..tostring(actorId)) return end

	--是否可以领取奖励
	if 1 ~= (var.isReward or 0) then print("caikuangsystem.requestGetReward:can not get reward, actorId:"..tostring(actorId)) return end

	--获得奖励
	local reward = getRewardInfo(actor)
	if not reward then
		print("caikuangsystem.requestGetReward:reward is nil, kuangid:"..tostring(var.kuangId)..", actorId:"..tostring(actorId))
		return
	end

	if isDouble then
		--钱够不够
		if LActor.getCurrency(actor, NumericType_YuanBao) < CaiKuangConfig.doubleCost then
			print("caikuangsystem.requestGetReward:double reward money not enough, actorId:"..tostring(actorId))
			return
		end

		LActor.changeCurrency(actor, NumericType_YuanBao, -CaiKuangConfig.doubleCost, "kuang doubleAward")

		for _, v in pairs(reward) do v.count = v.count * 2 end
	end

	if not LActor.canGiveAwards(actor, reward) then
		print("caikuangsystem.requestGetReward:canGiveAwards is false, actorId:"..tostring(actorId))
		return
	end

	LActor.giveAwards(actor, reward, "kuang reward, id:".. tostring(var.kuangId))
	print("caikuangsystem.requestGetReward:kuang get reward success, kuangid:"..tostring(var.kuangId)..", actorId:"..tostring(actorId))

	var.endTime = nil

	initKuangInfo(actor)

	sendKuangBaseInfo(actor)

	--不管有没有被打，都移除被攻击信息
	caikuangscene.removeBeAttacker(actorId)
end

--领取奖励
local function requestQuickFinish(actor)
	local actorId = LActor.getActorId(actor)
	if false == isOpenCaiKuang(actor) then print("caikuangsystem.requestQuickFinish:isOpenCaiKuang is false, actorId:"..tostring(actorId)) return end

	local var = getKuangVarData(actor)

	if 0 == (var.sceneId or 0) then print("caikuangsystem.requestQuickFinish:sceneId is 0, actorId:"..tostring(actorId)) return end

	--有没有矿
	if 0 == (var.kuangId or 0) then print("caikuangsystem.requestQuickFinish:kuangid is 0, actorId:"..tostring(actorId)) return end

	--矿是否结束
	if true == kuangIsFinish(var.kuangId, var.endTime) then
		print("caikuangsystem.requestQuickFinish:kuang is finish, time:"..tostring(var.endTime)..", actorId:"..tostring(actorId))
		return
	end

	--需消耗元宝
	local leftTime = var.endTime - System.getNowTime()
	local needCost = BaseConf.quickCost * math.ceil(leftTime/60)

	if LActor.getCurrency(actor, NumericType_YuanBao) < needCost then
		print("caikuangsystem.requestQuickFinish:finish money not enough, actorId:"..tostring(actorId))
		return
	end

	LActor.changeCurrency(actor, NumericType_YuanBao, -needCost, "kuang quickFinish")

	--取消定时器
	if var.eid then LActor.cancelScriptEvent(actor, var.eid) end

	--通知结束
	endTimer(actor)

	caikuangscene.kuangEnd(actor)

	print("caikuangsystem.requestQuickFinish:kuang quick finish success, kuangid:"..tostring(var.kuangId)..", actorId:"..tostring(actorId))
end

--请求掠夺
local function requestAttack(actor, tActorId)
	local actorId = LActor.getActorId(actor)
	if false == isOpenCaiKuang(actor) then print("caikuangsystem.requestAttack:isOpenCaiKuang is false, actorId:"..tostring(actorId)) return false end

	local var = getKuangVarData(actor)

	--不在矿洞无法挑战
	if 0 == (var.sceneId or 0) then print("caikuangsystem.requestAttack:sceneId is 0, actorId:"..tostring(actorId)) return false end

	--掠夺次数够了
	if BaseConf.maxRobCount <= (var.lueduoCount or 0) then
		print("caikuangsystem.requestAttack:lueduoCount is max, actorId:"..tostring(actorId))
		return false
	end

	--是否在其它挑战事件
	if 0 ~= (var.tActorId or 0) then
		print("caikuangsystem.requestAttack:tActorId is not 0 tactorid:"..tostring(var.tActorId)..", actorId:"..tostring(actorId))
		return false
	end

	--不能自己ko自己
	if tActorId == actorId then print("caikuangsystem.requestAttack:can not fight with myself, actorId:"..tostring(actorId)) return false end

	--是否可以攻击目标
	if false == caikuangscene.checkCanBeAttacked(actorId, tActorId, var.sceneId or 0) then
		print("caikuangsystem.requestAttack:checkCanBeAttacked is false, tActorId:"..tostring(tActorId)..", actorId:"..tostring(actorId))
		return false
	end

	var.lueduoCount = (var.lueduoCount or 0) + 1
	var.tActorId = tActorId
	var.tKuangId = caikuangscene.getActorKuangInfo(var.tActorId, var.sceneId).kuangId or 0

	return true
end

local function requestAttackKuang(actor, pack)
	local tActorId = LDataPack.readInt(pack)
	local isSuccess = requestAttack(actor, tActorId)
	local npack = LDataPack.allocPacket(actor, systemId, Protocol.sKuang_Attack)
	LDataPack.writeByte(npack, isSuccess and 1 or 0)
	LDataPack.flush(npack)

	if isSuccess then
		--发送目标数据
		LActor.createKuangActorData(actor, tActorId)

		--通知矿状态变化
		local var = getKuangVarData(actor)
		caikuangscene.kuangAttackStatus(LActor.getActorId(actor), tActorId, var.sceneId or 0, true)

		sendKuangBaseInfo(actor)
	end
end

--上报掠夺结果
local function reportAttackResult(actor, pack)
	local result = LDataPack.readInt(pack)

	local var = getKuangVarData(actor)
	local actorId = LActor.getActorId(actor)

	--没有请求过掠夺
	if 0 == (var.tActorId or 0) then
		print("caikuangsystem.reportAttackResult:tActorId is nil, tActorId:"..tostring(var.tActorId)..", actorId:"..tostring(actorId))
		return
	end

	local tActorId = var.tActorId
	local tKuangId = var.tKuangId

	var.tActorId = nil
	var.tKuangId = nil

	if 0 == (tKuangId or 0) then
		print("caikuangsystem.reportAttackResult:tActor kuangId is nil, tActorId:"..tostring(tActorId)..", actorId:"..tostring(actorId))
		return
	end

	--胜利
	if 1 == result then
		local reward = getRobRewardInfo(tKuangId)
		if not reward then return end

		LActor.giveAwards(actor, reward, "lueduo reward, id:".. tostring(tKuangId))
		print("caikuangsystem.reportAttackResult:kuang get lueduo reward success, kuangid:"..tostring(tKuangId)..", actorId:"..tostring(actorId))
	end

	--通知矿状态变化
	caikuangscene.kuangAttackStatus(actorId, tActorId, var.sceneId or 0, false, result)

	recordUpdate(actor, result, tActorId, tKuangId)
end

--查询采矿记录
local function requestQueryRecord(actor)
	local actorId = LActor.getActorId(actor)
	if false == isOpenCaiKuang(actor) then
		print("caikuangsystem.requestQueryRecord:isOpenCaiKuang is false, actorId:"..tostring(actorId))
		return
	end

	local var = getKuangVarData(actor)
	if nil == var.record then var.record = {} end

	local npack = LDataPack.allocPacket(actor, systemId, Protocol.sKuang_QueryRecord)

	--只显示配置要求的最大数目
	local count = (var.record.maxIndex or 1) - (var.record.minIndex or 1)
	if BaseConf.recordMaxCount < count then count = BaseConf.recordMaxCount end

	LDataPack.writeShort(npack, count)

	--{ time, recordEvent, kuangid, actorid, actorname, win, fuchou, job, sex, fight }   别人抢夺我的记录
		--{ time, recordEvent, kuangid, actorid, actorname, win }  我抢夺别人的记录

	local cnt = var.record.maxIndex or 1
	for i = cnt - 1, cnt - count, -1 do
		local record = var.record[i]
		if record then
			LDataPack.writeShort(npack, i)
			LDataPack.writeByte(npack, record[2] or 0)
			LDataPack.writeInt(npack, record[1] or 0)

			if recordEvent.beRob == (record[2] or 0) then  --被掠夺
				LDataPack.writeByte(npack, record[3])
				LDataPack.writeInt(npack, record[4])
				LDataPack.writeString(npack, record[5])
				LDataPack.writeByte(npack, record[6])
				LDataPack.writeByte(npack, record[7])
				LDataPack.writeByte(npack, record[8])
				LDataPack.writeByte(npack, record[9])
				LDataPack.writeInt(npack, record[10])
			elseif recordEvent.rob == (record[2] or 0) then   --掠夺
				LDataPack.writeByte(npack, record[3])
				LDataPack.writeInt(npack, record[4])
				LDataPack.writeString(npack, record[5])
				LDataPack.writeByte(npack, record[6])
			end
		end
	end

	LDataPack.flush(npack)
end

--请求复仇
local function requestRevenge(actor, pack)
	local actorId = LActor.getActorId(actor)
	if false == isOpenCaiKuang(actor) then print("caikuangsystem.requestRevenge:isOpenCaiKuang is false, actorId:"..tostring(actorId)) return end

	local var = getKuangVarData(actor)

	if 0 == (var.sceneId or 0) then print("caikuangsystem.requestRevenge:sceneId is 0, actorId:"..tostring(actorId)) return end

	--是否在其它挑战事件
	if 0 ~= (var.tActorId or 0) then
		print("caikuangsystem.requestRevenge:tActorId is not 0 tactorid:"..tostring(var.tActorId)..", actorId:"..tostring(actorId))
		return
	end

	--记录是否存在
	local index = LDataPack.readInt(pack)
	--local record = getRecordByIndex(actor, index)
	local record = var.record[index]
	if not record then
		print("caikuangsystem.requestRevenge:record is nil, index:"..tostring(index)..", actorId:"..tostring(actorId))
		return
	end

	--是否复仇记录
	if recordEvent.beRob ~= (record[2] or 0) then
		print("caikuangsystem.requestRevenge:is not beRob event, index:"..tostring(index)..", actorId:"..tostring(actorId))
		return
	end

	--是否已复仇过
	if 1 == (record[7] or 0) then
		print("caikuangsystem.requestRevenge:already revenge, index:"..tostring(index)..", actorId:"..tostring(actorId))
		return
	end

	local tActorId = record[4] or 0
	var.tActorId = tActorId

	--发送目标数据
	LActor.createKuangActorData(actor, tActorId)
end

--上报复仇结果
local function reportRevengeResult(actor, pack)
	local result = LDataPack.readInt(pack)
	local index = LDataPack.readInt(pack)

	local var = getKuangVarData(actor)
	local actorId = LActor.getActorId(actor)

	--没有请求过复仇
	if 0 == (var.tActorId or 0) then
		print("caikuangsystem.reportRevengeResult:tActorId is nil, tActorId:"..tostring(var.tActorId)..", actorId:"..tostring(actorId))
		return
	end

	local tActorId = var.tActorId
	var.tActorId = nil

	--记录是否存在
	local record = var.record[index]
	if not record then print("caikuangsystem.reportRevengeResult:record is nil, actorId:"..tostring(actorId)) return end

	--只有胜利才有奖励
	if 0 == result then return end

	--是否复仇记录
	if recordEvent.beRob ~= (record[2] or 0) then
		print("caikuangsystem.reportRevengeResult:is not beRob event, index:"..tostring(index)..", actorId:"..tostring(actorId))
		return
	end

	--是否已复仇过
	if 1 == (record[7] or 0) then
		print("caikuangsystem.reportRevengeResult:already revenge, index:"..tostring(index)..", actorId:"..tostring(actorId))
		return
	end

	local kuangId = record[3] or 0
	local reward = getRevengeRewardInfo(kuangId)

	LActor.giveAwards(actor, reward, "revenge reward, id:".. tostring(kuangId))

	record[7] = 1

	--公告
	noticemanager.broadCastNotice(BaseConf.revengeNoticeId, LActor.getActorName(actorId), LActor.getActorName(tActorId) or "")
end

--请求场景切换
local function requestSwitchScene(actor, pack)
	local actorId = LActor.getActorId(actor)
	if false == isOpenCaiKuang(actor) then print("caikuangsystem.requestSwitchScene:isOpenCaiKuang is false, actorId:"..tostring(actorId)) return end

	local var = getKuangVarData(actor)

	--if 0 == (var.sceneId or 0) then print("caikuangsystem.requestSwitchScene:sceneId is 0, actorId:"..tostring(actorId)) return end

	--0表示进入上一个场景，1进入下一个场景
	local direction = LDataPack.readShort(pack)

	--获取handle
	local handle = caikuangscene.getNextHandle(var.sceneId or 0, direction)
	if 0 == handle then print("caikuangsystem.requestSwitchScene:handle is 0, actorId:"..tostring(actorId)) return end

	--选择坐标点
	local x, y = 0, 0
	if 1 == direction then
		x = BaseConf.nextPos.x
		y = BaseConf.nextPos.y
	else
		x = BaseConf.backPos.x
		y = BaseConf.backPos.y
	end

	--进入
	local ret = LActor.enterFuBen(actor, handle, 0, x, y)
	if not ret then print("caikuangsystem.requestSwitchScene:enterFuBen false, actorId:"..tostring(actorId)) return end
end

--请求最新战力
local function requestActorPower(actor, pack)
	local tarId = LDataPack.readInt(pack)
	local power = LActor.getActorPower(tarId)

	local npack = LDataPack.allocPacket(actor, systemId, Protocol.sKuang_GetActorData)
	LDataPack.writeDouble(npack, power)
	LDataPack.flush(npack)
end

local function onFuBenEnter(ins, actor)
	local var = getKuangVarData(actor)
	var.sceneId = ins.data.sceneId
	caikuangscene.sendSceneInfo(actor, ins.data.sceneId)
end

local function onFuBenExit(ins, actor)
	initSceneInfo(actor)
end

local function onLogin(actor)
	if false == isOpenCaiKuang(actor) then return end
 	sendKuangBaseInfo(actor)
 	setTimer(actor)

 	--登陆时也处理下
 	local var = getKuangVarData(actor)
 	var.tActorId = nil
	var.tKuangId = nil
end

local function onNewday(actor, isLogin)
	if false == isOpenCaiKuang(actor) then return end
	dayReset(actor)

	if not isLogin then sendKuangBaseInfo(actor) end
end

local function onLogout(actor)
	initSceneInfo(actor)
end

local function onFightPower(actor, fightPower)
	if false == isOpenCaiKuang(actor) then return end

	local var = getKuangVarData(actor)
	if not var then return end

	--有没有矿
	if 0 == (var.kuangId or 0) then return end

	--是否结束了
	if 1 == (var.isReward or 0) then return end

	caikuangscene.updateKuangInfo(actor, var)
end

local function onLevelUp(actor, level)
	if BaseConf.openLevel ~= level then return end
	sendKuangBaseInfo(actor)
end

actorevent.reg(aeNewDayArrive, onNewday)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeUserLogout, onLogout)
--actorevent.reg(aeFightPower, onFightPower)
actorevent.reg(aeLevel, onLevelUp)

netmsgdispatcher.reg(systemId, Protocol.cKuang_EnterFuben, requestEnterFuben)
netmsgdispatcher.reg(systemId, Protocol.cKuang_RefreshKuangLevel, requestRefreshKuangLevel)
netmsgdispatcher.reg(systemId, Protocol.cKuang_StartCaiKuang, requestStartCaiKuang)
netmsgdispatcher.reg(systemId, Protocol.cKuang_GetCaiKuangReward, requestGetReward)
netmsgdispatcher.reg(systemId, Protocol.cKuang_QuickFinish, requestQuickFinish)
netmsgdispatcher.reg(systemId, Protocol.cKuang_Attack, requestAttackKuang)
netmsgdispatcher.reg(systemId, Protocol.cKuang_ReportAttackResult, reportAttackResult)
netmsgdispatcher.reg(systemId, Protocol.cKuang_QueryRecord, requestQueryRecord)
netmsgdispatcher.reg(systemId, Protocol.cKuang_Revenge, requestRevenge)
netmsgdispatcher.reg(systemId, Protocol.cKuang_ReportRevengeResult, reportRevengeResult)
netmsgdispatcher.reg(systemId, Protocol.cKuang_SwitchScene, requestSwitchScene)
netmsgdispatcher.reg(systemId, Protocol.cKuang_GetActorData, requestActorPower)

local function fuBenInit()
	insevent.registerInstanceEnter(BaseConf.fubenId, onFuBenEnter)
	insevent.registerInstanceExit(BaseConf.fubenId, onFuBenExit)

	caikuangscene.initData()
end

table.insert(InitFnTable, fuBenInit)


function test(actor, id, args)
	local var = getKuangVarData(actor)
	if 1 == id then requestEnterFuben(actor) end
	if 2 == id then requestRefreshKuangLevel(actor) end
	if 3 == id then var.record = nil end
	if 4 == id then
		var.caikuangCount = 0
		var.lueduoCount = 0
		sendKuangBaseInfo(actor)
	end
	if 5 == id then var.record = nil end
end

function initKuang(actor)
	initKuangInfo(actor)
end
