module("neigongsystem", package.seeall)

local function getData(actor)
	local var = LActor.getStaticVar(actor)

	if nil == var.neigongdata then
		var.neigongdata = {}
	end

	return var.neigongdata
end

local function getRoleData(actor, roleId)
	local data = getData(actor)
	if nil == data[roleId] then
		data[roleId] = {}
		data[roleId].level = 0
		data[roleId].stage = 0
		data[roleId].exp = 0
		data[roleId].val = 0
		data[roleId].isOpen = 0
	end

	return data[roleId]
end

local function getStageConfig(stage, level)
	if not NeiGongStageConfig[stage] then
		print("neigongsystem.getStageConfig: stage is null, stage:"..stage)
		return nil
	end

	if not NeiGongStageConfig[stage][level] then
		print("neigongsystem.getStageConfig: level is null, level:"..level)
		return nil
	end

	return NeiGongStageConfig[stage][level]
end

--内功是否激活
local function checkIsOpen(actor, roleId)
	local data = getRoleData(actor, roleId)

	if 1 == data.isOpen then return true end

	return false
end

--检测是否可以升阶
local function checkNeedStageUp(stage, level)
	local config = getStageConfig(stage, level)
	if not config then return true end

	local levelPerStage = NeiGongBaseConfig.levelPerStage
	if 0 == levelPerStage then print("neigongsystem.checkNeedStageUp: 0 == levelPerStage") return false end
	if 0 == level % levelPerStage and 0 ~= level then
		return true
	end

	return false
end

local function neiGongDataSync(actor, roleId)
	roleData = getRoleData(actor, roleId)
	local isOpen = checkIsOpen(actor, roleId)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_NeiGong, Protocol.sNeiGongCmd_DataSync)
	LDataPack.writeData(pack, 5,
						dtShort, roleId,
						dtInt, roleData.level or 0,
						dtInt, roleData.stage or 0,
						dtInt, roleData.exp or 0,
						dtInt, isOpen and 1 or 0)
	LDataPack.flush(pack)
end

--内功升级
function neiGongLevelup(actor, roleId)
	local actorId = LActor.getActorId(actor)

	--是否已激活
	if not checkIsOpen(actor, roleId) then
		print("neigongsystem.neiGongLevelup: not open, roleId:"..roleId..", actorid:"..tostring(actorId))
		return
	end

	local roleData = getRoleData(actor, roleId)

	--检查看是不是需要升阶才能继续升级
	if checkNeedStageUp(roleData.stage, roleData.level) then
		print("neigongsystem.neiGongLevelup: checkNeedStageUp false, level:"..roleData.level..", actorid:"..tostring(actorId))
		return
	end

	local config = getStageConfig(roleData.stage, roleData.level)
	if not config then return end
	local needMoney = monthcard.updateNeiGongGold(actor, config.costMoney)

	local gold = LActor.getCurrency(actor, NumericType_Gold)
	if (gold < needMoney) then print("neigongsystem.neiGongLevelup:money is not enough, money:"..gold..", actorid:"..tostring(actorId)) return end

	--扣钱
	LActor.changeGold(actor, -needMoney, "neigong normal train")

	local isLevelUp = false
	roleData.exp = roleData.exp + config.addExp
	if roleData.exp >= config.totalExp then
		--获取下一级的配置
		local nextLevel = roleData.level + 1
		if not getStageConfig(roleData.stage, nextLevel) then return end

		roleData.level = nextLevel
		roleData.exp = roleData.exp - config.totalExp
		isLevelUp = true

		--检查是不是到了需要升阶的星级，是的话把经验置零，升级了再继续加经验
		if checkNeedStageUp(roleData.stage, roleData.level) then roleData.exp = 0 end
	end

	--升级就更新属性
	if isLevelUp then
		updateAttr(actor, roleId)
		actorevent.onEvent(actor,aeNeiGongUp)
	end

	neiGongDataSync(actor, roleId)
end

--内功升阶
function neiGongStageup(actor, roleId)
	local actorId = LActor.getActorId(actor)
	--是否已激活
	if not checkIsOpen(actor, roleId) then
		print("neigongsystem.neiGongStageup: not open, roleId:"..roleId..", actorid:"..tostring(actorId))
		return
	end

	local roleData = getRoleData(actor, roleId)

	--检查看是不是到了需要升阶的时候了
	if not checkNeedStageUp(roleData.stage, roleData.level) then
		print("neigongsystem.neiGongStageup: checkNeedStageUp false, level:"..roleData.level..", actorid:"..tostring(actorId))
		return
	end

	local nextStage = roleData.stage + 1

	local config = getStageConfig(nextStage, 0)
	if not config then return end

	roleData.stage = nextStage
	roleData.level = 0

	updateAttr(actor, roleId)
	neiGongDataSync(actor, roleId)
	actorevent.onEvent(actor,aeNeiGongUp)
end

--内功激活
function neiGongOpen(actor, roleId)
	local actorId = LActor.getActorId(actor)
	--等级开启判断
	if (LActor.getLevel(actor) < NeiGongBaseConfig.openLevel) then
		print("neigongsystem.neiGongOpen: open level limit, level:"..LActor.getLevel(actor)..", actorid:"..tostring(actorId))
		return false
	end

	--关卡数判断
	local cdata = chapter.getStaticData(actor)
	if cdata.level < NeiGongBaseConfig.openGuanqia then
		print("neigongsystem.neiGongOpen: chapter level limit, level:"..cdata.level..", actorid:"..tostring(actorId))
		return false
	end

	if MAX_ROLE-1 < roleId then
		print("neigongsystem.neiGongOpen: roleId is illegal, roleId:"..roleId..", actorid:"..tostring(actorId))
		return false
	end

	--是否已激活
	if checkIsOpen(actor, roleId) then
		print("neigongsystem.neiGongOpen: roleId already open, roleId:"..roleId..", actorid:"..tostring(actorId))
		return false
	end

	local data = getRoleData(actor, roleId)
	data.isOpen = 1

	updateAttr(actor, roleId)
	return true
end

--清空属性
local function clearAttribute(actor, roleId)
	local attr = LActor.getNeigongAttr(actor, roleId)
	if attr then attr:Reset() end
end

function addNeiGongAttr(actor, roleId)
	local roleData = getRoleData(actor, roleId)

	local stageConfig = getStageConfig(roleData.stage, roleData.level)
	if stageConfig then
		local attr = LActor.getNeigongAttr(actor, roleId)
		attr:Reset()

		for _, tb in pairs(stageConfig.attribute or {}) do
			attr:Add(tb.type, tb.value or 0)
		end
	end
end

--属性更新
function updateAttr(actor, roleId)
	--先清空内功系统的属性
	clearAttribute(actor, roleId)

	addNeiGongAttr(actor, roleId)

	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end

function neiGongLevelup_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	neiGongLevelup(actor, roleId)
end

function neiGongStageup_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	neiGongStageup(actor, roleId)
end

function neiGongOpen_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	local ret = neiGongOpen(actor, roleId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_NeiGong, Protocol.sNeiGongCmd_open)
	LDataPack.writeData(pack, 2,
						dtShort, roleId,
						dtInt, ret and 1 or 0)
	LDataPack.flush(pack)
end

function onLogin(actor)
	for roleId = 0, MAX_ROLE-1 do
		neiGongDataSync(actor, roleId)
	end
end

local function onInit(actor)
	for roleId = 0,LActor.getRoleCount(actor) - 1 do
		if checkIsOpen(actor, roleId) then
			local role = LActor.getRole(actor, roleId)
			if role then
				clearAttribute(actor, roleId)
				addNeiGongAttr(actor, roleId)
				roleData = getRoleData(actor, roleId)
				LActor.setNp(role, roleData.val or 0)
			end
		end
	end
end

--登出游戏保存当前内功值
local function onLogout(actor, onlineTime)
	for roleId = 0,LActor.getRoleCount(actor) - 1 do
		local role = LActor.getRole(actor, roleId)
		if role then
			roleData = getRoleData(actor, roleId)
			roleData.val = LActor.getNp(role)
		end
	end
end

function neiGongAttrInit(actor, roleId)
end

_G.neiGongAttrInit = neiGongAttrInit

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogout, onLogout)


netmsgdispatcher.reg(Protocol.CMD_NeiGong, Protocol.cNeiGongCmd_LevelUp, neiGongLevelup_c2s)
netmsgdispatcher.reg(Protocol.CMD_NeiGong, Protocol.cNeiGongCmd_StageUp, neiGongStageup_c2s)
netmsgdispatcher.reg(Protocol.CMD_NeiGong, Protocol.cNeiGongCmd_open, neiGongOpen_c2s)

function openNeigong(actor, roleId)
	neiGongOpen(actor, roleId)
end
