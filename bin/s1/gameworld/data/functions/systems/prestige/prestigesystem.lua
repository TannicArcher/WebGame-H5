module("prestigesystem", package.seeall)


--[[
个人信息 = {
	leftPerstigeExp --今天可找回威望值,每天重置
	taskVal ={
		[配置id] = 目前完成的累计数量
	}
	findBack = {
		[配置id] = 已完成该事件的次数
	}
系统信息 = {
	[ActivityEvent] = 开启天数
}

 ]]


ActivityEvent = {
	campbattle = 1,    --阵营战
	passionpint = 2,   --激情泡点
	guildbattle = 3,   --龙城争霸
}

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)

	if nil == var.perstigeData then var.perstigeData = {} end
	return var.perstigeData
end

local function getSystemData()
	local var = System.getStaticVar()
	if nil == var.perstigeData then var.perstigeData = {} end
	return var.perstigeData
end

local function updateInfo(actor)
	local data = getStaticData(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Prestige, Protocol.sPrestigeCMD_ReqPrestigeInfo)
	LDataPack.writeInt(npack, data.leftPerstigeExp or 0)
	LDataPack.flush(npack)
end

--保存各个副本活动的开启时间
function saveActivityOpenDay(eventType)
	local svar = getSystemData()
	if not svar.sysOpenTime then svar.sysOpenTime = {} end
	svar.sysOpenTime[eventType] = System.getOpenServerDay()
end

--保存玩家的参与信息
function updateTask(actor, taskType, param, count)
	local var = getStaticData(actor)
	if not var.taskVal then var.taskVal = {} end
	if not var.findBack then var.findBack = {} end
	for id, cfg in ipairs(PrestigeFind or {}) do
		if cfg.type == taskType and cfg.param == param then
			var.taskVal[id] = (var.taskVal[id] or 0) + count
			if (var.taskVal[id] or 0) >= cfg.target then var.findBack[id] = (var.findBack[id] or 0) + 1 end
		end
	end
end

--计算可以找回的威望值
local function getPrestigeValue(actor)
	--每天清空找回值
	local var = getStaticData(actor)
	var.leftPerstigeExp = 0

	local svar = getSystemData()
	if not svar.sysOpenTime then svar.sysOpenTime = {} end
	local level = LActor.getZhuanShengLevel(actor) * 1000 + LActor.getLevel(actor)

	for id, cfg in ipairs(PrestigeFind) do
		--参与条件是否满足
		local isCanJoin = (cfg.lv or 0) <= level and (not cfg.imbaId or imbasystem.checkActive(actor, cfg.imbaId))

		--昨天是否开启
		local isOpen = not cfg.eventType or (svar.sysOpenTime[cfg.eventType] and System.getOpenServerDay() - svar.sysOpenTime[cfg.eventType] == 1)

		if isCanJoin and isOpen then
			if not var.findBack then var.findBack = {} end
			local canFindNum = cfg.num - (var.findBack[id] or 0)
			if 0 < canFindNum then var.leftPerstigeExp = (var.leftPerstigeExp or 0) + canFindNum * cfg.exp end
		end
	end

	var.taskVal = nil
	var.findBack = nil
end

--检测开启条件
local function checkOpenCondition(actor)
	local actorId = LActor.getActorId(actor)
	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level < PrestigeBase.openLevel then return false end

	local openDay = System.getOpenServerDay() + 1
	if openDay < PrestigeBase.openDay then return false end

	return true
end

--根据经验获取配置
local function getPerstigeConfig(exp)
	local cfg = nil
	for i=#PrestigeLevel, 1, -1 do
		local conf = PrestigeLevel[i]
		if conf.exp <= exp then cfg = conf break end
	end

	return cfg
end

local function calcAttr(actor, preExp)
	if false == checkOpenCondition(actor) then return end
	local attr = LActor.getPerstigeAttr(actor)
	attr:Reset()

	local exp = LActor.getCurrency(actor, NumericType_PrestigeExp)
	local conf = getPerstigeConfig(exp)

	--exp > preExp表示可能会升级，升级需要广播
	if conf and preExp < exp then
		local preConf = getPerstigeConfig(preExp)
		if conf.level > preConf.level and conf.notice then noticemanager.broadCastNotice(conf.notice, LActor.getName(actor) or "") end
	end

	for _, v in pairs(conf.attr or {}) do attr:Add(v.type, v.value) end
	LActor.reCalcAttr(actor)
end

local function onLevelUp(actor)
	calcAttr(actor, LActor.getCurrency(actor, NumericType_PrestigeExp))
end

local function onLogin(actor)
	updateInfo(actor)
end

local function onNewDay(actor)
	--计算可以找回的威望
	getPrestigeValue(actor)

	updateInfo(actor)
end

local function onChangePrestige(actor, preValue)
	--在线玩家才重新计算战力
	if false == LActor.isImage(actor) then calcAttr(actor, preValue) end
end

local function onReqGetBack(actor, packet)
	local actorId = LActor.getActorId(actor)

	--检测条件
	if false == checkOpenCondition(actor) then print("prestigesystem.onReqGetBack:condition false, actorId:"..tostring(actorId)) return end

	local data = getStaticData(actor)
	if 0 < (data.leftPerstigeExp or 0) and PrestigeBase.cost then
		local needCost = math.ceil(data.leftPerstigeExp * PrestigeBase.cost)

		if needCost > LActor.getCurrency(actor, NumericType_YuanBao) then
			print("prestigesystem.onReqGetBack: money not enough, actorId:"..LActor.getActorId(actor))
			return
		end

		LActor.changeYuanBao(actor, 0 - needCost, "prestigeExp backcost")

		LActor.changeCurrency(actor, NumericType_PrestigeExp, data.leftPerstigeExp, "prestigeExp back")
		data.leftPerstigeExp = nil

		updateInfo(actor)
	end
end

--回收
local function onChangePrestigeExp(actor)
	if not actor then return end

	--回收威望
	local exp = LActor.getCurrency(actor, NumericType_PrestigeExp)
	local conf = getPerstigeConfig(exp)
	if conf and 0 < (conf.retrieve or 0) then
		local value = conf.retrieve > exp and exp or conf.retrieve
		LActor.changeCurrency(actor, NumericType_PrestigeExp, -value, "retrieve prestigeExp")

		--镜像需要保存数据
		if true == LActor.isImage(actor) then LActor.saveDb(actor) end
	end
end
_G.OnChangePrestigeExp = onChangePrestigeExp

--全服回收威望
local function changePrestigeExpData()
	local openDay = System.getOpenServerDay() + 1
	if openDay < PrestigeBase.openDay then return end

	System.changePrestigeExp()

	print("prestigesystem:start to changePrestigeExpData")
end
_G.ChangePrestigeExpData = changePrestigeExpData

local function onInit(actor)
	if false == checkOpenCondition(actor) then return end
	local attr = LActor.getPerstigeAttr(actor)
	attr:Reset()

	local conf = getPerstigeConfig(LActor.getCurrency(actor, NumericType_PrestigeExp))


	for _, v in pairs(conf.attr or {}) do attr:Add(v.type, v.value) end
	LActor.reCalcAttr(actor)
end

local function initFunc()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeChangePrestige, onChangePrestige)
	actorevent.reg(aeLevel, onLevelUp)

	netmsgdispatcher.reg(Protocol.CMD_Prestige, Protocol.cPrestigeCMD_ReqGetBack, onReqGetBack)
end
table.insert(InitFnTable, initFunc)


local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.prestige = function(actor, args)
	if 1 == tonumber(args[1]) then
		LActor.changeCurrency(actor, NumericType_PrestigeExp, tonumber(args[2]), "gm add")
	elseif 2 == tonumber(args[1]) then
		local var = getStaticData(actor)
		var.leftPerstigeExp = (var.leftPerstigeExp or 0) + tonumber(args[2])
		updateInfo(actor)
elseif 3 == tonumber(args[1]) then
	System.changePrestigeExp()
	end
end
