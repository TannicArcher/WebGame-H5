--[[保存在玩家上的信息
	isOpen   1表示已开启宝箱功能，2未开启
	firstFree 1为第一次打开免费宝箱，打开后置为nil

	boxList = {
		type 宝箱类型 0表示格子没有宝箱，可以使用
		status 宝箱状态 1还没倒计时的宝箱，2正在倒计时的宝箱
		leftTime 宝箱开启剩余时间，可使用元宝提前开启, 未开启的宝箱倒计时为0
	}

	freeQueue ={
		id 		位置索引
		cdTime	获取免费宝箱的将来时间
	}
--]]

module("treasureboxsystem", package.seeall)

--初始化格子信息
local function initBox(info)
	info.type = 0
	info.status = 1
	info.leftTime = 0
end

local function getData(actor)
	local var = LActor.getStaticVar(actor)

	if nil == var.treasurebox then
		var.treasurebox = {}
	end

	if nil == var.treasurebox.boxList then
		var.treasurebox.boxList = {}
	end

	if nil == var.treasurebox.freeQueue then
		var.treasurebox.freeQueue = {}
	end

	if nil == var.treasurebox.isOpen then
		var.treasurebox.isOpen = 2
	end

	return var.treasurebox
end

--检测开启等级
local function checkLevel(actor)
	if TreasureBoxBaseConfig.openLevel > LActor.getLevel(actor) then
		print("treasureboxsystem.checkLevel: check level failed. actorId:"..LActor.getActorId(actor)..", level:"..LActor.getLevel(actor))
		return false
	end

	return true
end

function getLimitCount(actor)
	if false == checkLevel(actor) then return 0 end
	local count = TreasureBoxBaseConfig.openQueue
	local level = LActor.getVipLevel(actor)
	if TreasureBoxBaseConfig.thirdOpenLevel <= level then
		count = count + 1
	end
	return count
end

--检测该位置是否有宝箱
local function checkBoxIsExist(actor, index)
	local data = getData(actor)
	if data.boxList[index] and 0 ~= data.boxList[index].type then return true end
	return false
end

--检测是否还有剩余的宝箱队列
local function checkQueueIsFree(actor)
	local data = getData(actor)
	local count = 0
	local curTime = System.getNowTime()

	for k=1, #data.boxList do
		if data.boxList[k] and curTime < data.boxList[k].leftTime then count = count + 1 end
	end

	if count >= getLimitCount(actor) then return false end

	return true
end

--发送宝箱信息
local function sendData(actor)
	local curTime = System.getNowTime()
	local data = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_TreasureBox, Protocol.sTreasureBoxCmd_DataUpdateSync)

	LDataPack.writeShort(npack, #data.boxList)

	for k=1, #data.boxList do
		LDataPack.writeShort(npack, k or 0)
		LDataPack.writeShort(npack, data.boxList[k].type or 0)
		LDataPack.writeShort(npack, data.boxList[k].status or 1)

		local times = data.boxList[k].leftTime - curTime
		if 0 > times then times = 0 end
		LDataPack.writeInt(npack, times)
	end

	LDataPack.writeShort(npack, #data.freeQueue)
	for k=1, #data.freeQueue do
		LDataPack.writeShort(npack, k or 0)

		local times = data.freeQueue[k].cdTime - curTime
		if 0 > times then times = 0 end
		LDataPack.writeInt(npack, times)
	end

	LDataPack.flush(npack)
end

--增加宝箱格子数量，给外部调用
function addGrid(actor, level)
	local data = getData(actor)
	for k, v in ipairs(TreasureBoxGridConfig or {}) do
		if v.chapter <= level then
			if not data.boxList[v.pos] then
				data.boxList[v.pos] = {}
				initBox(data.boxList[v.pos])
			end
		else
			break
		end
	end
end

--获取随机宝箱,0表示没宝箱拿
local function getRandomTreasureBox(actor, fubenId)
	local conf = TreasureBoxRateConfig[fubenId]

	--判断能不能获取箱子
	local point = math.random(10000)
	if point > (conf.boxRate or 0) then return 0 end

	point = math.random(10000)
	local value = 0
	for k, data in pairs(conf.typeRate or {}) do
		value = value + data.rate
		if value >= point then return k end
	end

	return 0
end

--通知宝箱的获取
local function sendBoxReceive(actor, boxType)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_TreasureBox, Protocol.sTreasureBoxCmd_BoxNoticeSync)
	LDataPack.writeShort(npack, boxType)
	LDataPack.flush(npack)
end

--获取宝箱
function getTreasureBox(actorId, fubenId)
	local actor = LActor.getActorById(actorId)
	if not actor then return end

	--等级判断
	if false == checkLevel(actor) then return end

	if not TreasureBoxRateConfig[fubenId] then return end
	local conf = TreasureBoxRateConfig[fubenId]

	local data = getData(actor)
	local boxType = getRandomTreasureBox(actor, fubenId)

	if 0 == boxType then return end

	local index = 0
	for k=1, #data.boxList do
		if data.boxList[k] and 0 == data.boxList[k].type then index = k break end
	end

	--判断是否还有剩余格子
	if 0 == index then return end

	data.boxList[index].type = boxType

	sendBoxReceive(actor, boxType)
	sendData(actor)

	--成就
	actorevent.onEvent(actor, aeGetTreasureBoxType, boxType)
end

--组装奖励信息
local function handleRewrd(award, reward)
	for k, v in pairs(reward or {}) do
		local isFind = false
		for _, data in pairs(award or {}) do
			if data.id == v.id and data.type == v.type then
				data.count = data.count + v.count
				isFind = true
				break
			end
		end

		if not isFind then
			local index = #award+1
			award[index] = {}
			award[index].type = v.type
			award[index].id = v.id
			award[index].count = v.count
		end
	end

end

--发送奖励信息
local function sendRewrdNotice(actor, reward, type)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_TreasureBox, Protocol.sTreasureBoxCmd_RewardNoticeSync)
	LDataPack.writeShort(npack, type)
	LDataPack.writeShort(npack, #reward)

	for _, v in ipairs(reward) do
		LDataPack.writeInt(npack, v.type or 0)
		LDataPack.writeInt(npack, v.id or 0)
		LDataPack.writeInt(npack, v.count or 0)
	end

	LDataPack.flush(npack)
end

local function sendRewardMail(actor, award)
	if award then
		local mail_data = {}
		mail_data.head = MAIL.treasureboxtitle
		mail_data.context = MAIL.treasureboxtitlecont
		mail_data.tAwardList = award
		mailsystem.sendMailById(LActor.getActorId(actor), mail_data)
	end
end

--发送开启宝箱得到的奖励
local function sendReward(actor, boxType)
	local conf = TreasureBoxConfig[boxType]
	if not conf then print("treasureboxsystem.sendReward:conf is null, type:"..tostring(boxType)) return end

	local award = {}
	if conf.dropId1 then
		local rewards = drop.dropGroup(conf.dropId1)
		handleRewrd(award, rewards)
	end

	if conf.dropId2 then
		local rewards = drop.dropGroup(conf.dropId2)
		handleRewrd(award, rewards)
	end

	if conf.dropId3 then
		local rewards = drop.dropGroup(conf.dropId3)
		handleRewrd(award, rewards)
	end

	if not LActor.canGiveAwards(actor, award) then
		sendRewardMail()
		return
	end

	LActor.giveAwards(actor, award , "treasurebox get rewards")

	sendRewrdNotice(actor, award, boxType)
end

--开启宝箱消耗元宝
local function costMoney(actor, leftTime, boxType)
	local curTime = System.getNowTime()
	local yb = LActor.getCurrency(actor, NumericType_YuanBao)
	local needMoney = math.ceil(math.ceil((leftTime - curTime) / 60) * (TreasureBoxConfig[boxType].quality or 0) * TreasureBoxBaseConfig.moneyCoefficient)

	if 0 > needMoney then needMoney = 0 end
	if needMoney > yb then print("treasureboxsystem.costMoney:needMoney > yb, needMoney:"..needMoney..", yb:"..yb) return false end

	LActor.changeYuanBao(actor, 0 - needMoney, "treasurebox buy cd")

	return true
end

--获取宝箱信息
local function onReqInfo(actor)
	sendData(actor)
end

--有三个操作，分别是把宝箱放入队列，开启倒计时已完毕的宝箱，花费元宝去除倒计时开启宝箱
local function onSetBox(actor, packet)
	local gridIndex = LDataPack.readShort(packet)

	if false == checkLevel(actor) then return end

	local data = getData(actor)
	if gridIndex > #data.boxList then
		print("treasureboxsystem.onSetBox:gridIndex is bigger than max:"..tostring(gridIndex))
		return
	end

	--检测该位置是否有宝箱
	if false == checkBoxIsExist(actor, gridIndex) then
		print("treasureboxsystem.onSetBox:checkBoxIsExist is false:"..tostring(gridIndex))
		return
	end

	local info = data.boxList[gridIndex]

	local boxType = info.type or 0
	local isOpen = false

	--1还没倒计时的宝箱，2正在倒计时的宝箱，如果为1则判断是否放入队列还是直接使用元宝开启
	if 1 == info.status then
		if true == checkQueueIsFree(actor) then  --放入队列
			info.leftTime = System.getNowTime() + (TreasureBoxConfig[boxType].time or 0)
			info.status = 2
		else  --使用元宝开启
			local leftTime = System.getNowTime() + (TreasureBoxConfig[boxType].time or 0)
			if false == costMoney(actor, leftTime, boxType) then return end
			isOpen = true
		end
	else
		if System.getNowTime() < info.leftTime then
			if false == costMoney(actor, info.leftTime or 0, boxType) then return end
		end

		isOpen = true
	end

	if isOpen then
		sendReward(actor, boxType)
		initBox(info)

		--成就
		actorevent.onEvent(actor, aeTreasureBoxReward)
	end

	sendData(actor)
end

local function onGetFreeReward(actor, packet)
	if false == checkLevel(actor) then return end

	local index = LDataPack.readShort(packet)
	if index > TreasureBoxBaseConfig.maxFreeNumber then
		print("treasureboxsystem.onGetFreeReward:index is more than max, index:"..tostring(index))
		return
	end

	local data = getData(actor)
	if not data.freeQueue[index] then
		print("treasureboxsystem.onGetFreeReward:data.freeQueue is null, index:"..tostring(index))
		return
	end

	--时间检测
	if data.freeQueue[index].cdTime > System.getNowTime() then
		print("treasureboxsystem.onGetFreeReward:data.freeQueue is in cd, index:"..tostring(index))
		return
	end

	local rewards = nil

	if data.firstFree and 1 == data.firstFree then
		rewards = drop.dropGroup(TreasureBoxBaseConfig.firstFreeDropId)
	else
		rewards = drop.dropGroup(TreasureBoxBaseConfig.freeDropId)
	end

	--背包容量够不够
	if not LActor.canGiveAwards(actor, rewards) then LActor.sendTipmsg(actor, "背包容量不足") return end

	--发奖励
	LActor.giveAwards(actor, rewards , "treasurebox free")

	if data.firstFree and 1 == data.firstFree then data.firstFree = nil end

	sendRewrdNotice(actor, rewards, 0)

	--累计其它免费宝箱的cd
	local cd = 0
	for k=1, #data.freeQueue do
		if k ~= index and data.freeQueue[k] then
			if (data.freeQueue[k].cdTime or 0) > System.getNowTime() then
				cd = cd + data.freeQueue[k].cdTime - System.getNowTime()
			end
		end
	end

	--初始化该队列
	data.freeQueue[index].cdTime = System.getNowTime() + (TreasureBoxBaseConfig.freeCd or 0) + cd
	sendData(actor)
end

local function onLevelUp(actor, level)
	if TreasureBoxBaseConfig.openLevel > level then return end

	local data = getData(actor)

	--开启过了就不开启了
	if 1 == data.isOpen then return end

	--初始化格子信息
	local cdata = chapter.getStaticData(actor)
	addGrid(actor, cdata.level or 0)

	--设置免费队列cd
	for k=1, TreasureBoxBaseConfig.maxFreeNumber do
		data.freeQueue[k] = {}
		if 1==k then --第一个免费宝箱特殊处理
			data.freeQueue[k].cdTime = System.getNowTime() + TreasureBoxBaseConfig.firstFreeCd
		else
			data.freeQueue[k].cdTime = System.getNowTime() + TreasureBoxBaseConfig.firstFreeCd + TreasureBoxBaseConfig.freeCd * (k-1)
		end
	end

	data.firstFree = 1
	data.isOpen = 1

	sendData(actor)
end

local function onLogin(actor)
	if TreasureBoxBaseConfig.openLevel > LActor.getLevel(actor) then return end
	onLevelUp(actor, LActor.getLevel(actor))
	sendData(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeLevel, onLevelUp)

netmsgdispatcher.reg(Protocol.CMD_TreasureBox, Protocol.cTreasureBoxCmd_ReqInfo, onReqInfo)
netmsgdispatcher.reg(Protocol.CMD_TreasureBox, Protocol.cTreasureBoxCmd_SetBox, onSetBox)
netmsgdispatcher.reg(Protocol.CMD_TreasureBox, Protocol.cTreasureBoxCmd_GetFreeReward, onGetFreeReward)

--测试,初始化玩家宝箱信息
function treasureBoxInit(actor)
	local var = LActor.getStaticVar(actor)
	var.treasurebox = {}
	var.treasurebox.boxList = {}
	var.treasurebox.boxQueue = {}
end

--测试,初始化玩家宝箱信息
function treasureBoxTest(actor, id)
	local actorId = LActor.getActorId(actor)
	getTreasureBox(actorId, tonumber(id))
end
