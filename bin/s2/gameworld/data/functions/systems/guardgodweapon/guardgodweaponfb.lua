module("guardgodweaponfb", package.seeall)
local gConf = GuardGodWeaponConf
local waveConf = GGWWaveConf

local specialBoss = 1
local commonBoss = 2
-- local monStatistics = {}
--每波的怪物ID，不能重复，因为要简单区分怪物是属于那一波的

local function sendFuBenInfo(actor)
	local ins = instancesystem.getActorIns(actor)
	if not ins or ins:isEnd() or not ins.data.zsLvl then return end
	local zsLvl = ins.data.zsLvl
	-- if not gConf.fbId[zsLvl] then return end

	local waveMonNum = 0
	local temWave = ins.data.wave
	local wMonNum = ins.data.wMonNum
	for i=1, ins.data.wave do
		if wMonNum[i] > 0 then
			waveMonNum = wMonNum[i]
			temWave = i
			break
		end
	end

	local d_var = guardgodweaponsys.getActorDVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_GGWUpdateFBInfo)
	if npack == nil then return end

	LDataPack.writeChar(npack, ins.data.wave)
	LDataPack.writeInt(npack, d_var.skillScore)
	LDataPack.writeChar(npack, d_var.summonCount)
	LDataPack.writeInt(npack, ins.data.totalMonNum)
	LDataPack.writeChar(npack, temWave)
	LDataPack.writeInt(npack, waveMonNum)
	LDataPack.flush(npack)
end

function initFBData(ins, actor)
	ins.data.wave = 0
	ins.data.monList = {}
	ins.data.wMonNum = {}
	ins.data.summonBoss = {}
	ins.data.commonBoss = {}
	ins.data.timerFlag = System.getRandomNumber(10000)
	ins.data.totalMonNum = 0
	ins.data.gwMonHdl = 0
	ins.data.summonLimit = 0
	ins.data.skillCD = {}
	ins.data.tAward = {}
	ins.data.isReward = false
	ins.data.zsLvl = LActor.getZhuanShengLevel(actor)
	guardgodweaponsys.clearActorDVar(actor)

	local aId = LActor.getActorId(actor)
	LActor.setCamp(actor, aId)
	local pScene = LActor.getScenePtr(actor)
	-- local mon = Fuben.getSceneMonsterById(pScene, gConf.gwMonId)
	local gwMon = Fuben.createMonster(ins.scene_list[1], gConf.gwMonId, gConf.gwMonPos[1], gConf.gwMonPos[2])
	if not gwMon then
		LActor.log(actor,"guardgodweaponfb.initFBData","create god weapon mon error", LActor.getFubenId(actor))
		return
	end
	LActor.setCamp(gwMon, aId)
	ins.data.gwMonHdl = LActor.getHandle(gwMon)

	sendFuBenInfo(actor)
end

local function newWaveStar(hfb, flag)
	local ins = instancesystem.getInsByHdl(hfb)
	if not ins or ins:isEnd() then return end
	if ins.data.timerFlag ~= flag then return end

	local zsLvl = ins.data.zsLvl
	local wave = ins.data.wave + 1
	if wave > #waveConf[zsLvl] then
		System.log("guardgodweaponfb", "newWaveStar", "fuben is end", ins.id)
		return
	else
		ins.data.wave = wave
		local addSummonNum = gConf.sSummonLimit[wave]
		if addSummonNum then
			ins.data.summonLimit = ins.data.summonLimit + addSummonNum
		end

		local conf = waveConf[zsLvl][wave]
		createWaveMon(ins, wave, conf.monLib)
		postWaveTimer(ins, ins.data.wave)

		local actors = Fuben.getAllActor(hfb)
		if actors and actors[1] then
			sendFuBenInfo(actors[1])
		end
	end
end

function postWaveTimer(ins, wave)
	local zsLvl = ins.data.zsLvl
	local conf = waveConf[zsLvl][wave]
	if not conf then
		LActor.log(actor,"guardgodweaponfb.postWaveTimer","not config", zsLvl, wave)
		return
	end

	local flag = ins.data.timerFlag + 1
	ins.data.timerFlag = flag
	local hfb = ins.handle
	LActor.postScriptEventLite(nil, conf.time * 1000, function() newWaveStar(hfb, flag) end)
end

function starPK(actorId, hfb, flag)
	local actor = LActor.getActorById(actorId)
	if not actor then return end

	local ins = instancesystem.getActorIns(actor)
	if not ins or ins.handle ~= hfb or ins:isEnd() then return end
	if ins.data.timerFlag ~= flag then
		return
	end

	newWaveStar(hfb, ins.data.timerFlag)
end

-- function onEnterFuben(ins, actor)
-- end

local function onMonsterDie(ins, mon, killer_hdl)
	if not ins or ins:isEnd() then return end

	local hMon = LActor.getHandle(mon)
	local bInfo = ins.data.summonBoss[hMon]
	if bInfo then
		posBossAwardMsg(ins, specialBoss, mon)
		-- ins.data.summonBoss[hMon] = nil
	else
		local monId = LActor.getId(mon)
		local monInfo = ins.data.monList[hMon]
		if not monInfo then return end
		ins.data.totalMonNum = ins.data.totalMonNum - 1
		posBossAwardMsg(ins, commonBoss, mon)

		ins.data.monList[hMon] = nil
		local wMonNum = ins.data.wMonNum
		local monNum = wMonNum[monInfo.wave]
		if monNum <= 0 then return end
		monNum = monNum - 1
		wMonNum[monInfo.wave] = monNum

		local et = LActor.getEntity(killer_hdl)
		local kActor = LActor.getActor(et)

		if kActor then
			local d_var = guardgodweaponsys.getActorDVar(kActor)
			d_var.skillScore = d_var.skillScore + (monInfo.score or 0)
			sendFuBenInfo(kActor)
		end

		local zsLvl = ins.data.zsLvl
		if ins.data.wave >= #waveConf[zsLvl] then
			local overNum = 0
			for i=1, #waveConf[zsLvl] do
				overNum = overNum + wMonNum[i]
			end
			if overNum <= 0 then
				--所有怪都打晒了，完结了
				if kActor then
					local aName = LActor.getName(kActor)
					noticemanager.broadCastNotice(gConf.winNoticeId, aName, ins.data.zsLvl)
				end
				ins:win()
				return
			end
		end

		if monInfo.wave == ins.data.wave and wMonNum[monInfo.wave] <= 0 then
			newWaveStar(ins.handle, ins.data.timerFlag)
		end
	end
end

function posBossAwardMsg(ins, type, mon)
	if not ins or ins:isEnd() then return end

	local monId = LActor.getId(mon)
	local hMon = LActor.getHandle(mon)
	local award = {}
	local res = false
	if type == specialBoss then
		local info = ins.data.summonBoss[hMon] or {}
		award = info.award or {}
		res = true
	elseif type == commonBoss then
		-- local hMon = LActor.getHandle(mon)
		if gConf.cBossAward[monId] then
			--drop.dropGroup(gConf.cBossAward[monId])
			ins.data.commonBoss[hMon] = {}
			local tbl = ins.data.commonBoss[hMon]
			tbl.monId = monId
			tbl.name = MonstersConfig[monId].name
			tbl.award = drop.dropGroup(gConf.cBossAward[monId] or 0)
			award = tbl.award
			res = true
		end
	end

	if res == true then
		local actors = Fuben.getAllActor(ins.handle)
		if actors and actors[1] then
			local npack = LDataPack.allocPacket(actors[1], Protocol.CMD_Fuben, Protocol.sFubenCmd_GGWBossAward)
			if npack == nil then return end

			LDataPack.writeChar(npack, type)
			LDataPack.writeInt64(npack, hMon)
			LDataPack.writeChar(npack, #award)
			for k,v in ipairs(award) do
				LDataPack.writeInt(npack, v.type)
				LDataPack.writeInt(npack, v.id)
				LDataPack.writeInt(npack, v.count)
			end
			LDataPack.flush(npack)
		end
	end
end

local function onActorDie(ins,actor,killer_hdl)
	if not ins or ins:isEnd() then return end

	local gwMon = LActor.getEntity(ins.data.gwMonHdl)
	for k,v in pairs(ins.data.monList) do
		local mon = LActor.getEntity(k)
		LActor.setAITarget(mon, gwMon)
	end
end

local function onRoleDie(ins, role, killer_hdl)
	if not ins or ins:isEnd() then return end

	local id = LActor.getId(role)
	local actor = LActor.getActor(role)
	local d_var = guardgodweaponsys.getActorDVar(actor)
	d_var.diePos[id] = {}
	local x,y = LActor.getPosition(role)
	-- d_var.diePos[id].x, d_var.diePos[id].y = LActor.getPosition(role)

	local flag = d_var.diePos[id].timerFlag or 0
	flag = flag + 1
	d_var.diePos[id].timerFlag = flag

	LActor.postScriptEventLite(actor, (gConf.recoverCD * 1000),function() recoverCallBack(actor, id, x, y, flag) end)
end

function recoverCallBack(actor, id, x, y, flag)
	if not actor then return end
	local ins = instancesystem.getActorIns(actor)
	if not ins or ins:isEnd() or not ins.data.zsLvl then return end
	-- if not gConf.fbId[ins.data.zsLvl] then return end

	local d_var = guardgodweaponsys.getActorDVar(actor)
	local info = d_var.diePos[id]
	if not info or info.timerFlag ~= flag then return end
	
	local role = LActor.getRole(actor, id)
	if LActor.isDeath(actor) then
		LActor.relive(role, x, y)
		for k,v in pairs(ins.data.monList) do
			local mon = LActor.getEntity(k)
			if mon then
				LActor.setAITarget(mon, role)
			end
		end
	else
		local count = LActor.getRoleCount(actor)
		x,y=0,0
		for i=0, count-1 do
			local r = LActor.getRole(actor, i)
			if r and LActor.isDeath(r) == false then
				x,y = LActor.getPosition(r)
				break
			end
		end
		LActor.relive(role, x, y)
	end
end

function onSettlement(ins, actor, isLogout, isExit)
	local zsLvl = ins.data.zsLvl
	local wConf = waveConf[zsLvl]

	local wMonNum = ins.data.wMonNum
	-- local actors = Fuben.getAllActor(ins.handle)
	-- if actors and actors[1] then
		local totalAward = {}
		-- local actor = actors[1]
		if ins.data.isReward == true then return end
		ins.data.isReward = true
		
		if not isLogout then
			for i=1, ins.data.wave do
				if wMonNum[i] <= 0 then
					LActor.giveAwards(actor, wConf[i].award, "ggwSettlement"..i)
					for k,v in ipairs(wConf[i].award) do
						table.insert(totalAward, v)
					end
				end
			end

			local aId = LActor.getActorId(actor)
			local mailData = { head=gConf.sbHead, context=gConf.sbContext}
			for k,v in pairs(ins.data.summonBoss) do
				mailData.tAwardList = utils.awardMerge(v.award)
				mailsystem.sendMailById(aId, mailData)
				-- LActor.giveAwards(actor, v.award, "ggwSummonBoss"..v.monId)

				for k,v in ipairs(v.award) do
					table.insert(totalAward, v)
				end
			end
			ins.data.summonBoss = {}
			for k,v in pairs(ins.data.commonBoss) do
				LActor.giveAwards(actor, v.award, "ggwCommonBoss"..v.monId)
				for k,v in ipairs(v.award) do
					table.insert(totalAward, v)
				end
			end

			for k,v in ipairs(ins.data.tAward) do
				table.insert(totalAward, v)
			end

			ins.data.commonBoss = {}
			if not isExit then
				instancesystem.setInsRewards(ins, actor, totalAward)
				ins:setRewards(actor, nil)
			end
		else
			local aId = LActor.getActorId(actor)
			for i=1, ins.data.wave do
				if wMonNum[i] <= 0 then
					for k,v in ipairs(wConf[i].award) do
						table.insert(totalAward, v)
					end
				end
			end
			local mAward = utils.awardMerge(totalAward)
			local mailData = { head=gConf.cHead, context=gConf.cContext, tAwardList=mAward }
			mailsystem.sendMailById(aId, mailData)
			mailData.head = gConf.sbHead
			mailData.context = gConf.sbContext
			for k,v in pairs(ins.data.summonBoss) do
				-- mailData.tAwardList = v.award
				mailData.tAwardList = utils.awardMerge(v.award)
				mailsystem.sendMailById(aId, mailData)
			end
			ins.data.summonBoss = {}

			mailData.head = gConf.cbHead
			mailData.context = gConf.cbContext
			for k,v in pairs(ins.data.commonBoss) do
				-- mailData.tAwardList = v.award
				mailData.tAwardList = utils.awardMerge(v.award)
				mailsystem.sendMailById(aId, mailData)
			end
			ins.data.commonBoss = {}
		end
	-- end
end

--根据波数创建怪物
function createWaveMon(ins, wave, monLibConf)
	local hScene = ins.scene_list[1]
	local wMonNum = ins.data.wMonNum
	wMonNum[wave] = 0
	local mons = {}
	for k,v in ipairs(monLibConf) do
		local mon = Fuben.createMonster(hScene, v.monId, v.x, v.y)
		if mon then
			mons[#mons+1] = mon
			local hMon = LActor.getHandle(mon)
			-- table.insert(ins.data.monList, hdl)
			ins.data.monList[hMon] = {}
			ins.data.monList[hMon].wave = wave
			ins.data.monList[hMon].score = v.score
			wMonNum[wave] = wMonNum[wave] + 1
			ins.data.totalMonNum = ins.data.totalMonNum + 1
		end
	end

	if ins.data.totalMonNum > gConf.fbMaxMon then
		ins:lose()
		return
	end

	local actors = Fuben.getAllActor(ins.handle)
	local et = nil
	if actors and actors[1] and not LActor.isDeath(actors[1]) then
		--找玩家活动的角色打
		local actor = actors[1]
		local count = LActor.getRoleCount(actor)
		for i=0, count-1 do
			local role = LActor.getRole(actor, i)
			if role and LActor.isDeath(role) == false then
				et = role
				break
			end
		end
	else
		--玩家死了，去打神剑
		et = LActor.getEntity(ins.data.gwMonHdl)
	end
	if et then
		for _,v in ipairs(mons) do
			LActor.setAITarget(v, et)
		end
	end
end

local skillLogic = {}
local function onUseSkill(actor, pack)
	local idx = LDataPack.readByte(pack)
	local cost = gConf.sSkillCost[idx]
	if not cost then return end

	local ins = instancesystem.getActorIns(actor)
	if not ins or not ins.data.zsLvl then return end
	-- if not gConf.fbId[ins.data.zsLvl] then return end

	local d_var = guardgodweaponsys.getActorDVar(actor)
	if cost > d_var.skillScore then

		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw001, ttScreenCenter)
		return
	end

	if LActor.isDeath(actor) then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw002, ttScreenCenter)
		return false
	end
	local skillCD = ins.data.skillCD
	local now = System.getNowTime()
	if skillCD[idx] and (now - skillCD[idx]) < 0 then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw003, ttScreenCenter)
		return
	end

	local func = skillLogic[idx]
	if func and func(ins, actor, gConf.sSkillVal[idx]) then
		d_var.skillScore = d_var.skillScore - cost
		skillCD[idx] = now

		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_GGWUseSkillRes)
		if npack == nil then return end
		LDataPack.writeByte(npack, idx)
		LDataPack.flush(npack)
		sendFuBenInfo(actor)

	end
end

skillLogic[1] = function(ins, actor, valTbl)
	local count = LActor.getRoleCount(actor)
	for i=0, count-1 do
		local role = LActor.getRole(actor, i)
		if role and LActor.isDeath(role) == false then
			local maxHp = LActor.getHpMax(role)
			LActor.changeHp(role, maxHp * valTbl[1])
		end
	end
	return true
end

skillLogic[2] = function(ins, actor, valTbl)
	local count = LActor.getRoleCount(actor)
	for i=0, count-1 do
		local role = LActor.getRole(actor, i)
		if role and LActor.isDeath(role) == false then
			LActor.addSkillEffect(role, valTbl[1])
		end
	end

	return true
end

skillLogic[3] = function(ins, actor, valTbl)
	local skillId = togetherhit.getSkillId(actor)
	local skillConf = SkillsConfig[skillId] or {}
	local cd =  skillConf.cd or 0
	if cd > 0 then
		local val = cd * valTbl[1]
		local count = LActor.getRoleCount(actor)
		for i=0, count-1 do
			local role = LActor.getRole(actor, i)
			if role and LActor.isDeath(role) == false then

				local tLeft = LActor.GetSkillLaveCD(role, skillId)
				if tLeft > 0 then
					tLeft = tLeft - val
					LActor.SetAllRoleSkillCdById(actor, skillId, (tLeft < 0) and 0 or tLeft)
					togetherhit.sendTogetherHitLv(actor)
					return true
				end
				return false
			end
		end

	end
	return false
end

local function onSummonBoss(actor, pack)
	local ins = instancesystem.getActorIns(actor)
	if not ins or not ins.data.zsLvl then return end
	local zsLvl = ins.data.zsLvl
	-- if not gConf.fbId[zsLvl] then return end

	local d_var = guardgodweaponsys.getActorDVar(actor)
	if d_var.summonCount >= ins.data.summonLimit then
		LActor.sendTipmsg(actor, Lang.ScriptTips.ggw004, ttScreenCenter)
		return
	end

	local idx = d_var.summonCount + 1
	local cost = gConf.sSummonCost[idx]
	if not cost then return end

	local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
	if (cost > curYuanBao) then
		LActor.log(actor,"guardgodweaponfb.onSummonBoss","not yuanbao")
		return
	end

	local bossId = gConf.sBoss[zsLvl][idx]
	local pos = gConf.sSummonPos[idx]
	local boss = Fuben.createMonster(ins.scene_list[1], bossId, pos[1], pos[2])
	if boss then
		LActor.changeCurrency(actor, NumericType_YuanBao, -cost, "ggwSummonBoss")
		d_var.summonCount = idx
		local hBoss = LActor.getHandle(boss)
		-- ins.data.summonBoss[hBoss] = drop.dropGroup(gConf.sBossAward[bossId] or 0)
		ins.data.summonBoss[hBoss] = {}
		local tbl = ins.data.summonBoss[hBoss]
		tbl.monId = bossId
		tbl.name = MonstersConfig[bossId].name
		tbl.award = drop.dropGroup(gConf.sBossAward[bossId] or 0)

		sendFuBenInfo(actor)
	else
		LActor.log(actor,"guardgodweaponfb.onSummonBoss","create boss error", bossId, idx)
		return
	end
end

local function onGetBossAward(actor, pack)
	local ins = instancesystem.getActorIns(actor)
	if not ins or not ins.data.zsLvl then return end
	if not ins.data.summonBoss or not ins.data.commonBoss then return end

	local monType = LDataPack.readChar(pack)
	local hdl = LDataPack.readInt64(pack)
	local noticeItems = {}
	local monName = ""
	if monType == specialBoss then
		local tbl = ins.data.summonBoss[hdl]
		if tbl then
			LActor.giveAwards(actor, tbl.award, "getggwSBoss"..tbl.monId)
			ins.data.summonBoss[hdl] = nil
			for k,v in ipairs(tbl.award) do
				if v.type == AwardType_Item then
					table.insert(noticeItems, v.id)
				end
				table.insert(ins.data.tAward, v)
			end
			monName = tbl.name
		end
	elseif monType == commonBoss then
		local tbl = ins.data.commonBoss[hdl]
		if tbl then
			LActor.giveAwards(actor, tbl.award, "getggwCBoss"..tbl.monId)
			ins.data.commonBoss[hdl] = nil
			for k,v in ipairs(tbl.award) do
				if v.type == AwardType_Item then
					table.insert(noticeItems, v.id)
				end
				table.insert(ins.data.tAward, v)
			end
			monName = tbl.name
		end
	end
	local itemConf = ItemConfig
	-- local descConf = ItemDescConfig
	local aName = LActor.getName(actor)
	local item = nil
	for k,v in pairs(noticeItems) do
		item = itemConf[v]
		local notice = gConf.noticeId[item.quality]
		if notice then
			noticemanager.broadCastNotice(notice, aName, monName, item.name)
			local gdata = guardgodweaponsys.getGlobalData()
			if not gdata.record then gdata.record = {} end
			table.insert(gdata.record, {notice=notice, aName=aName, monName=monName, itemName=item.name})
			if #gdata.record > 3 then table.remove(gdata.record, 1) end
		end
	end
end

local function onWin(ins)
	local actors = Fuben.getAllActor(ins.handle)
	if actors and actors[1] then
		onSettlement(ins, actors[1])
		local data = guardgodweaponsys.getStaticVar(actors[1])
		if LActor.getZhuanShengLevel(actors[1]) >= gConf.privilegeSweepZsLimit and nil ~= data then
			data.canSweep = 1
			guardgodweaponsys.sendSysInfo(actors[1])
		end
	end
end

local function onLose(ins)
	local actors = Fuben.getAllActor(ins.handle)
	if actors and actors[1] then
		onSettlement(ins, actors[1])
	end
end

local function onExit(ins, actor)
	onSettlement(ins, actor, false, true)
	
end

local function actorOffline(ins, actor)
	-- ins:lose()
	onSettlement(ins, actor, true)
	LActor.exitFuben(actor)
end


function initGlobalData()
	-- monStatistics = {}
	local fbs = gConf.fbId
	--防止策划配相同的副本ID
	local tbl = {}
	for k,v in pairs(fbs) do
		if not tbl[v] then
			tbl[v] = 1
			-- insevent.registerInstanceEnter(v, onEnterFuben)
			insevent.registerInstanceMonsterDie(v, onMonsterDie)
			insevent.registerInstanceActorDie(v, onActorDie)
			insevent.regRoleDie(v, onRoleDie)

			insevent.registerInstanceWin(v, onWin)
			insevent.registerInstanceLose(v, onLose)
			insevent.registerInstanceExit(v, onExit)
			insevent.registerInstanceOffline(v, actorOffline)
		end
	end
end

table.insert(InitFnTable, initGlobalData)

netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_GGWUseSkill, onUseSkill)
netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_GGWSummonBoss, onSummonBoss)
netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_GGWBossAward, onGetBossAward)
