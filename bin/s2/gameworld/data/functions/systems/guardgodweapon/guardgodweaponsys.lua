module("guardgodweaponsys", package.seeall)
local gConf = GuardGodWeaponConf
local waveConf = GGWWaveConf

function getStaticVar(actor)
	local var = LActor.getStaticVar(actor)
	if var.ggwVar == nil then
		var.ggwVar = {}
		var.ggwVar.useCount=0
	end
	return var.ggwVar
end

function getActorDVar(actor)
	local svar = LActor.getDynamicVar(actor)
	if svar.ggwVar == nil then
		svar.ggwVar = {}
		-- svar.ggwVar.timerFlag = 0
		svar.ggwVar.skillScore = 0
		svar.ggwVar.summonCount = 0
		svar.ggwVar.diePos = {}
	end
	return svar.ggwVar
end

function getGlobalData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil 
	end
	if var.ggwVar == nil then 
		var.ggwVar = {}
	end

	return var.ggwVar
end

function clearActorDVar(actor)
	local svar = LActor.getDynamicVar(actor)
	svar.ggwVar = nil
end

function sysIsOpen()
	local day = System.getOpenServerDay() + 1
	if day >= gConf.opencondition[2] then
		return true
	end
	return false
end

function actorIsOpen(actor)
	local curZSLvl = LActor.getZhuanShengLevel(actor)
	if curZSLvl >= gConf.opencondition[1] then
		return true
	end
	return false
end

function sendSysInfo(actor)
	local var = getStaticVar(actor)
	if not var then return end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_GGWSysInfo)
	if npack == nil then return end
	LDataPack.writeChar(npack, var.useCount)
	if LActor.getZhuanShengLevel(actor) < gConf.privilegeSweepZsLimit then
		LDataPack.writeChar(npack, 0)
	else
		LDataPack.writeChar(npack, var.canSweep or 0)
	end
	LDataPack.flush(npack)
end

--请求进入副本
function onEnterFB(actor, pack)
	if not sysIsOpen() then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw005, ttScreenCenter)
		return
	end
	if not actorIsOpen(actor) then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw006, ttScreenCenter)
		return 
	end

	local var = getStaticVar(actor)
	if var.useCount >= gConf.dailyCount then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw007, ttScreenCenter)
		return
	end

	local zsLvl = LActor.getZhuanShengLevel(actor)
	local fbId = gConf.fbId[zsLvl]
	if fbId == nil then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw008, ttScreenCenter)
		return
	end

	local hfb = Fuben.createFuBen(fbId)
	local ins = instancesystem.getInsByHdl(hfb)
	if not ins then
		LActor.log(actor,"guardgodweaponsys.onEnterFB","create fuben error", fbId)
		return
	end

	if LActor.enterFuBen(actor, hfb) then
		var.useCount = var.useCount + 1

		guardgodweaponfb.initFBData(ins, actor)
		local aId = LActor.getActorId(actor)
		local flag = ins.data.timerFlag + 1
		ins.data.timerFlag = flag
		LActor.postScriptEventLite(nil, gConf.starDelayRsf * 1000, function() guardgodweaponfb.starPK(aId, hfb, flag) end)
		sendSysInfo(actor)

		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_GGWEnterFuben)
		if npack == nil then return end
		LDataPack.writeUInt(npack, ins.end_time - System.getNowTime())
		LDataPack.flush(npack)
	end
end

function onSendRecord(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_GGWSendRecord)
	if npack == nil then return end
	local gdata = getGlobalData()
	if not gdata.record then gdata.record = {} end
	LDataPack.writeChar(npack, #gdata.record)
	for i=1, #gdata.record do
		LDataPack.writeInt(npack, gdata.record[i].notice or 0)
		LDataPack.writeString(npack, gdata.record[i].aName or "")
		LDataPack.writeString(npack, gdata.record[i].monName or "")
		LDataPack.writeString(npack, gdata.record[i].itemName or "")
	end
	LDataPack.flush(npack)
end

local function doBroadCastNotice(aName, monId, itemId)
	local item = ItemConfig[itemId]
	local notice = gConf.noticeId[item.quality]
	if notice then
		local monName = MonstersConfig[monId].name
		noticemanager.broadCastNotice(notice, aName, monName, item.name)
		local gdata = getGlobalData()
		if not gdata.record then gdata.record = {} end
		table.insert(gdata.record, {notice=notice, aName=aName, monName=monName, itemName=item.name})
		if #gdata.record > 3 then table.remove(gdata.record, 1) end
	end
end

local function onSweep(actor, packet)
	local bossCount = LDataPack.readChar(packet)

	if not sysIsOpen() then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw005, ttScreenCenter)
		return
	end
	if not actorIsOpen(actor) then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw006, ttScreenCenter)
		return 
	end
	local zsLvl = LActor.getZhuanShengLevel(actor)
	if zsLvl < gConf.privilegeSweepZsLimit then
		LActor.sendTipmsg(actor, "还未开启扫荡功能", ttScreenCenter)
		return
	end

	local var = getStaticVar(actor)
	
	if 1 ~= var.canSweep then
		LActor.sendTipmsg(actor, "通关后才能扫荡", ttScreenCenter)
		return
	end
	if var.useCount >= gConf.dailyCount then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw007, ttScreenCenter)
		return
	end

	var.useCount = var.useCount + 1
	sendSysInfo(actor)

	local totalAward = {}
	local waConf = waveConf[zsLvl]
	local sbConf = gConf.sBoss[zsLvl]
	local fbId = gConf.fbId[zsLvl]
	local aName = LActor.getName(actor)
	for idx, v in pairs(waConf) do
		for _, monData in pairs(v.monLib) do
			local baId = gConf.cBossAward[monData.monId]
			if nil ~= baId then
				for _, award in ipairs(drop.dropGroup(baId)) do
					table.insert(totalAward, award)
					if award.type == AwardType_Item then
						doBroadCastNotice(aName, monData.monId, award.id)
					end
				end
			end
		end
		for _, award in ipairs(v.award or {}) do
			table.insert(totalAward, award)
		end
	end

	if bossCount > #gConf.sSummonCost then bossCount = #gConf.sSummonCost end
	for i=1, bossCount do
		local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
		local cost = gConf.sSummonCost[i]
		if curYuanBao >= cost then
			LActor.changeCurrency(actor, NumericType_YuanBao, -cost, "ggwSweep sBoss")
			for _, award in ipairs(drop.dropGroup(gConf.sBossAward[sbConf[i]] or 0)) do
				table.insert(totalAward, award)
				if award.type == AwardType_Item then
					doBroadCastNotice(aName, sbConf[i], award.id)
				end
			end
		end
	end

	local mAward = utils.awardMerge(totalAward)
	LActor.giveAwards(actor, mAward, "ggwSweep")

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_FubenResult)
	if npack == nil then return end

	LDataPack.writeByte(npack, 1)
	LDataPack.writeShort(npack, InstanceConfig[fbId].type)
	LDataPack.writeShort(npack, #mAward)
	for _, v in ipairs(mAward) do
		LDataPack.writeInt(npack, v.type or 0)
		LDataPack.writeInt(npack, v.id or 0)
		LDataPack.writeInt(npack, v.count or 0)
	end
	LDataPack.flush(npack)
end

function onLogin(actor)
	sendSysInfo(actor)
end
function onNewDay(actor, islogin)
	local var = getStaticVar(actor)
	var.useCount = 0
	if not islogin then
		sendSysInfo(actor)
	end
end

local function onZhuanSheng(actor)
	local var = getStaticVar(actor)
	if not var then return end
	var.canSweep = 0
	sendSysInfo(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeZhuansheng, onZhuanSheng)
netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_GGWEnterFuben, onEnterFB)
netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_GGWSendRecord, onSendRecord)
netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_GGWSweep, onSweep)

