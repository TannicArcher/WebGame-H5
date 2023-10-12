--(神功)(历练)(爵位)
module("trainsystem", package.seeall)

local keyList = {}
for k in pairs(TrainDayAwardConfig or {}) do keyList[#keyList+1] = k end
table.sort(keyList)

--获取数据缓存
function getTrainVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end

	if (var.trainVar == nil) then
		var.trainVar = {}
	end

	if var.trainVar.level == nil then
		var.trainVar.level = 0
	end
	if var.trainVar.exp == nil then
		var.trainVar.exp = 0
	end
	if var.trainVar.award_id == nil then
		var.trainVar.award_id = 1
	end
	return var.trainVar
end

function updateBasicData(actor)
	local var = getTrainVar(actor)
	local basic_data = LActor.getActorData(actor)
	basic_data.train_level = var.level
	basic_data.train_exp   = var.exp
	var.isAct = imbasystem.checkActive(actor, TrainBaseConfig.actImbaId) and 1 or 0
end

function addTrainExp(actor, addExp)
	local var = getTrainVar(actor)
	if (var == nil) then
		return
	end

	var.exp = var.exp + addExp
	var.totalExp = (var.totalExp or 0) + addExp

	trainInfoSync(actor)
	updateBasicData(actor)

	actorevent.onEvent(actor, aeDayLiLian, addExp)
end

--神器是否激活
function isActive(actor)
	if not imbasystem.checkActive(actor, TrainBaseConfig.actImbaId) then return false end

	return true
end

function levelUp(actor)
	local var = getTrainVar(actor)
	if (var == nil) then
		return
	end
	--神器是否激活
	if not imbasystem.checkActive(actor, TrainBaseConfig.actImbaId) then
		print("trainsystem.levelUp:checkActive is false")
		return
	end

	local nextLevel = var.level+1
	local config = traincommon.getLevelConfig(nextLevel)
	if (not config) then
		return
	end

	if (config.exp > var.exp) then
		return
	end

	var.level = nextLevel
	var.exp = var.exp - config.exp

	if (LActor.canGiveAwards(actor, config.itemAward)) then
		LActor.giveAwards(actor, config.itemAward, "train level award: "..nextLevel)
	else
		local tMailData = {}
		tMailData.head = LAN.MAIL.trn001
		tMailData.context = LAN.MAIL.trn001
		tMailData.tAwardList = config.itemAward
		mailsystem.sendMailById(LActor.getActorId(actor), tMailData)
	end

	updateAttr(actor)

	trainInfoSync(actor)
	updateBasicData(actor)
	actorevent.onEvent(actor,aeMagicLevel,nextLevel,false)
end

function updateAttr(actor)
	local var = getTrainVar(actor)
	local attr = LActor.getTrainsystemAttr(actor)
	attr:Reset()
	if (var == nil) then
		return
	end
	local level = var.level
	local config = traincommon.getLevelConfig(level)
	if (not config) then
		return
	end
	for _,tAttr in pairs(config.attrAward) do
		attr:Set(tAttr.type,tAttr.value)
	end
	local exAttr = LActor.getTrainsystemExAttr(actor)
	exAttr:Reset()
	for i=#TrainLevelAwardConfig,1,-1 do
		local subconf = TrainLevelAwardConfig[i]
		if level >= subconf.level then
			for _,exattr in ipairs(subconf.exattrs) do
				exAttr:Set(exattr.type,exattr.value)
			end
			break
		end
	end
	LActor.reCalcAttr(actor)
	LActor.reCalcExAttr(actor)
end

local function getLevelAward(actor)
	local var = getTrainVar(actor)
	local conf = GuanYinAwardConfig[var.award_id]
	if conf == nil then
		print("trainsystem.getLevelAward:conf is null, id:"..tostring(var.award_id)..", actorId:"..tostring(LActor.getActorId(actor)))
		return
	end

	if conf.level > var.level then
		print("trainsystem.getLevelAward:level limit, level:"..tostring(var.level)..", conf.level:"..tostring(conf.level)..", actorId:"..tostring(LActor.getActorId(actor)))
		return
	end

	if not LActor.canGiveAwards(actor, {conf.award}) then
		print("trainsystem.getLevelAward:space is full,actorId:"..tostring(LActor.getActorId(actor)))
		return
	end

	LActor.giveAwards(actor,{conf.award},"train level award")
	var.award_id = var.award_id + 1

	trainInfoSync(actor)
end

local function getTrainDayConf(openDay, index)
	for i = #(keyList or {}), 1, -1 do
		if openDay >= keyList[i] then return TrainDayAwardConfig[keyList[i]][index] end
	end
end

local function getTrainAward(actor, packet)
	local index = LDataPack.readInt(packet)
	local openDay = System.getOpenServerDay() + 1

	local conf = getTrainDayConf(openDay, index)
	if not conf then
		print("trainsystem.getTrainAward:conf is full, index:"..tostring(index)..", actorId:"..tostring(LActor.getActorId(actor)))
		return false
	end

	local var = getTrainVar(actor)

	--是否领取过了
	if System.bitOPMask(var.rewardRecord or 0, index) then
		print("trainsystem.getTrainAward:reward already get, index:"..tostring(index)..",actorId:"..tostring(LActor.getActorId(actor)))
		return false
	end

	--历练值是否满足
	if (var.totalExp or 0) < conf.score then
		print("trainsystem.getTrainAward:score not enough, index:"..tostring(index)..",actorId:"..tostring(LActor.getActorId(actor)))
		return false
	end

	if not LActor.canGiveAwards(actor, conf.reward) then
		print("trainsystem.getTrainAward:canGiveAwards is false, actorId:"..tostring(LActor.getActorId(actor)))
		return false
	end

	--发奖励
    LActor.giveAwards(actor, conf.reward, "trainReward,id:"..tostring(index))

    var.rewardRecord = System.bitOpSetMask(var.rewardRecord or 0, index, true)

    trainInfoSync(actor)
    return true
end

function trainInfoSync(actor)
	local var = getTrainVar(actor)
	if (var == nil) then
		return
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Train, Protocol.sTrainCmd_InfoSync)
	if pack == nil then return end
	LDataPack.writeInt(pack, imbasystem.checkActive(actor, TrainBaseConfig.actImbaId) and var.level or -1)
	LDataPack.writeInt(pack, var.exp)
	local conf = GuanYinAwardConfig[var.award_id]
	if conf == nil then
		LDataPack.writeInt(pack, 0)
	else
		LDataPack.writeInt(pack, var.award_id)
	end
	LDataPack.writeInt(pack, var.totalExp or 0)
	LDataPack.writeInt(pack, var.rewardRecord or 0)
	LDataPack.flush(pack)
end

--补发每日历练奖励
local function sendDailyRewardMail(actor)
	--因为要补发昨天的奖励，所以这里的openDay指的是到昨天为止的开服天数
	local openDay = System.getOpenServerDay()

	--开服第一天跳过
	if 0 == openDay then return end

	local conf = nil
	for i = #(keyList or {}), 1, -1 do
		if openDay >= keyList[i] then conf = TrainDayAwardConfig[keyList[i]] end
	end

	if not conf then return end

	local var = getTrainVar(actor)

	 --发邮件
	for k, data in pairs(conf) do
		if not System.bitOPMask(var.rewardRecord or 0, k) then
			if (var.totalExp or 0) >= data.score then
			    local mailData = {head=TrainBaseConfig.mailTitle, context=TrainBaseConfig.mailContent, tAwardList=conf[k].reward}

			    mailsystem.sendMailById(LActor.getActorId(actor), mailData)

			    print("trainsystem.sendDailyRewardMail:send success, day:"..openDay..", index:"..k..", actorId:"..tostring(LActor.getActorId(actor)))
			end
		end
	end
end

function levelUp_c2s(actor, pack)
	levelUp(actor)
end

local function onGetLevelAward(actor, pack)
	getLevelAward(actor, pack)
end

local function onGetTrainAward(actor, pack)
	local ret = getTrainAward(actor, pack)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Train, Protocol.sTrainCmd_GetTrianAward)
	LDataPack.writeByte(pack, ret and 1 or 0)
	LDataPack.flush(pack)
end

function onLogin(actor)
	updateBasicData(actor)
	trainInfoSync(actor)
end

function onBeforeLogin(actor)
	updateAttr(actor)
end

local function onNewDay(actor, isLogin)
	sendDailyRewardMail(actor)
	local var = getTrainVar(actor)
	var.totalExp = 0
	var.rewardRecord = 0
	if not isLogin then trainInfoSync(actor) end
end

local function onActImba(actor, id)
	if id == TrainBaseConfig.actImbaId then
		local var = getTrainVar(actor)
		var.isAct = 1
		trainInfoSync(actor)
	end
end

actorevent.reg(aeActImba, onActImba)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeInit, onBeforeLogin)
netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_LevelUp, levelUp_c2s)
--netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_ReqAct, acttrain)
netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_GetLevelAward,onGetLevelAward)
netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_GetTrianAward,onGetTrainAward)

