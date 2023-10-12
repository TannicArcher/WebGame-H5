module("jingmaisystem", package.seeall)

--经脉升级
function jimgmaiLevelup(actor, roleId)
	--等级未达到经脉开启不给升级
	if (LActor.getLevel(actor) < JingMaiCommonConfig.openLevel) then
		return
	end

	--从C++获取经脉信息
	local stage, level = LActor.getJingmaiInfo(actor, roleId)
	if (not stage or level < 0) then
		return
	end

	--获取下一级的配置，看看还有没有下一级
	local nextLevel = level + 1
	if (not jingmaicommon.getLevelConfig(nextLevel)) then
		return
	end

	--检查看是不是需要升阶才能继续升级
	if (jingmaicommon.checkNeedStageUp(stage, level)) then
		return
	end

	--拿到当前等级的配置
	local config = jingmaicommon.getLevelConfig(level)
	if (not config) then
		return
	end

	local itemId = config.itemId
	local count = config.count
	local useYuanBao = false
	local log = "jing mai level up"
	
	if (LActor.getItemCount(actor,itemId) < count) then
		return
	end
	
	LActor.costItem(actor, itemId, count, log)

	LActor.setJingmaiLevel(actor, roleId, nextLevel)

	updateAttr(actor, roleId)

	jingmaiDataSync(actor, roleId)

	actorevent.onEvent(actor, aeUpgradeJingmai, roleId, 1, stage)
end

--经脉升阶的接口
function jingmaiStageup(actor, roleId)
	--等级未达到经脉开启不给升级
	if (LActor.getLevel(actor) < JingMaiCommonConfig.openLevel) then
		return
	end

	--从C++获取经脉信息
	local stage, level = LActor.getJingmaiInfo(actor, roleId)
	if (not stage or level < 0) then
		return
	end

	--检查看是不是到了需要升阶的时候了
	if (not jingmaicommon.checkNeedStageUp(stage, level)) then
		return
	end

	local nextStage = stage + 1
	local config = jingmaicommon.getStageConfig(nextStage)
	if (not config) then
		return
	end

	LActor.setJingmaiStage(actor, roleId, nextStage)

	updateAttr(actor, roleId)
	
	jingmaiDataSync(actor, roleId)

	actorevent.onEvent(actor, aeUpgradeJingmai, roleId, 1, nextStage)
end

function jingmaiDataSync(actor, roleId)
	local stage, level = LActor.getJingmaiInfo(actor, roleId)
	if (not stage) then
		return
	end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Jingmai, Protocol.sJingmaiCmd_DataSync)
	if pack == nil then return end

	LDataPack.writeData(pack, 3,
						dtShort, roleId,
						dtInt, level,
						dtInt, stage)
	LDataPack.flush(pack)	
end

--属性更新
function updateAttr(actor, roleId)
	--先清空经脉系统的属性
	LActor.clearJingmaiAttr(actor, roleId)

	addJingmaiAttr(actor, roleId)
	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end

function addJingmaiAttr(actor, roleId)
	local stage, level = LActor.getJingmaiInfo(actor, roleId)
	if (not stage or level <= 0) then
		return
	end

	--先把等级和阶级的属性汇总
	local attrList = {}

	local levelConfig = jingmaicommon.getLevelConfig(level)
	if (levelConfig) then
		for _,tb in pairs(levelConfig.attr) do
			attrList[tb.type] = attrList[tb.type] or 0
			attrList[tb.type] = attrList[tb.type] + tb.value
		end
	end

	local stageConfig = jingmaicommon.getStageConfig(stage)
	if (stageConfig) then
		for _,tb in pairs(stageConfig.attr) do
			attrList[tb.type] = attrList[tb.type] or 0
			attrList[tb.type] = attrList[tb.type] + tb.value
		end
	end

	--汇总后统一加
	for type,value in pairs(attrList) do
		LActor.addJingmaiAttr(actor, roleId, type, value)
	end

end

function jingmaiLevelup_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	jimgmaiLevelup(actor, roleId)
end

function jingmaiStageup_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	jingmaiStageup(actor, roleId)
end

function onLogin(actor, firstLogin)
	for roleId = 0,2 do
		jingmaiDataSync(actor, roleId)
	end
end

function jingmaiAttrInit(actor, roleId)
	--先清空经脉系统的属性
	LActor.clearJingmaiAttr(actor, roleId)

	addJingmaiAttr(actor, roleId)
end

local function sendResult(actor, code, type)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Jingmai, Protocol.sJingmaiCmd_onelevel)
	if not pack then return end

	LDataPack.writeInt(pack, code)
	LDataPack.writeInt(pack, type)
	LDataPack.flush(pack)
end

local function jingmailevel_c2s(actor, pack) 
	local roleid = LDataPack.readInt(pack)

	local levelItemid = JingMaiCommonConfig.levelItemid

	if not actorcost.checkItemNum(actor, levelItemid, 1) then
		sendResult(actor, 1, 0)
		return false
	end

	LActor.costItem(actor, levelItemid, 1, "jingmailevel")
	local type = 0
	local stage, level = LActor.getJingmaiInfo(actor, roleid)
	if stage < JingMaiCommonConfig.levelItemidStage then
		stage = stage + 1
		level = level + JingMaiCommonConfig.levelPerStage
		LActor.setJingmaiStage(actor, roleid, stage)
		LActor.setJingmaiLevel(actor, roleid, level)

		updateAttr(actor, roleid)

		jingmaiDataSync(actor, roleid)

		actorevent.onEvent(actor, aeUpgradeJingmai, roleid, JingMaiCommonConfig.levelPerStage, stage)
	else
		LActor.giveItem(actor, JingMaiCommonConfig.itemid, JingMaiCommonConfig.levelItemChange, "jingmailevel")
		type = 1
	end
	sendResult(actor, 0, type)
end

_G.jingmaiAttrInit = jingmaiAttrInit

actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_Jingmai, Protocol.cJingmaiCmd_levelup, jingmaiLevelup_c2s)
netmsgdispatcher.reg(Protocol.CMD_Jingmai, Protocol.cJingmaiCmd_stageup, jingmaiStageup_c2s)
netmsgdispatcher.reg(Protocol.CMD_Jingmai, Protocol.cJingmaiCmd_onelevel, jingmailevel_c2s)
