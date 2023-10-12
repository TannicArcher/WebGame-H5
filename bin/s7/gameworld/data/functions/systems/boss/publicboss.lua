module("publicboss", package.seeall)


--公共数据 不要求保存，重启清除
--boss列表记录，排行榜数据
--[[
publicBossData = {
	[bossId] = {
		int hpPercent
		table  damageList { [aid]=dmg }
		table record { {time, name, power}[5]}
		int reliveTime
		int hfuben
		table rank { {dmg, aid}[] }
		bool needUpdate -- 是否需要更新排行榜
		}
}
publicBossDataCount = count
 ]]

--个人数据
--[[
publicBossData = {
	short count
	int last_time
	int challengeCd
	int todayEssence
	int clientdata -- notify flag
 }
 ]]
local p = Protocol

--外部回调
function onJoinActivity(actor)
	actorevent.onEvent(actor, aeEnterPublicBoss)
end

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.publicBossData == nil then
		var.publicBossData = {}
	end
	return var.publicBossData
end

local function updatePersonInfo(actor)
	local data = getStaticData(actor)
	if data.count == nil then data.count = PublicBossBaseConfig.maxCount end
	if data.count >= PublicBossBaseConfig.maxCount then
		return
	end
	local nowt = System.getNowTime()
	local cd = (PublicBossBaseConfig.recoverTime or 0) * 60
	while ((data.last_time or 0) + cd < nowt) do
		data.last_time = data.last_time + cd
		data.count = data.count + 1
		if data.count >= PublicBossBaseConfig.maxCount then
			data.last_time = 0
			break
		end
	end
end

local function notifyRank(id, actor)
	local rank = publicBossData[id].rank
	if rank == nil then return end

	local npack
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sBossCmd_UpdateRank)
	else
		npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, Protocol.CMD_Boss)
		LDataPack.writeByte(npack, Protocol.sBossCmd_UpdateRank)
	end
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, #rank)

	for _, d in ipairs(rank) do
		LDataPack.writeInt(npack, d.aid)
		LDataPack.writeString(npack, LActor.getActorName(d.aid))
		LDataPack.writeDouble(npack, d.dmg)
	end

	if actor then
		LDataPack.flush(npack)
	else
		Fuben.sendData(publicBossData[id].hfuben, npack)
	end
end

--协议处理
local function onReqPersonInfo(actor, packet)
	updatePersonInfo(actor)
	local data = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sBossCmd_PersonalInfo)
	if npack == nil then return end
	LDataPack.writeShort(npack, data.count)

	if data.last_time == nil then data.last_time = 0 end
	local cd = (PublicBossBaseConfig.recoverTime or 0) * 60
	local leftTime = cd - (System.getNowTime() - (data.last_time or 0))

	if data.last_time == 0 then leftTime = 0 end

	LDataPack.writeShort(npack, leftTime)
	LDataPack.writeInt(npack, data.todayEssence or 0)
	local challengeCd = data.challengeCd or 0
	challengeCd = challengeCd - System.getNowTime()
	if challengeCd < 0 then challengeCd = 0 end
	LDataPack.writeShort(npack, challengeCd)
	LDataPack.writeInt(npack, data.clientdata or 0xffff)
	LDataPack.flush(npack)
end

local function notifyBossList(actor)
	local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sBossCmd_BossList)
	if npack == nil then return end

	LDataPack.writeShort(npack, publicBossDataCount)
	for id, boss in pairs(publicBossData) do
		LDataPack.writeInt(npack, id)
		LDataPack.writeShort(npack, boss.hpPercent)

		local count,found = 0,false
		local actorId = LActor.getActorId(actor)
		for aid,v in pairs(boss.damageList) do
			if aid == actorId then found = true end
			count = count + 1
		end

		LDataPack.writeShort(npack, count)
		LDataPack.writeInt(npack, boss.reliveTime - System.getNowTime())

		LDataPack.writeByte(npack, found and 1 or 0)
	end
	LDataPack.flush(npack)
end

local function onReqBossList(actor, packet)
	notifyBossList(actor)
end

local function onSetClientData(actor, packet)
	local clientdata = LDataPack.readInt(packet)
	local data = getStaticData(actor)
	data.clientdata = clientdata
end

local function onReqChallengeRecord(actor, packet)
	local id = LDataPack.readInt(packet)
	local bossData = publicBossData[id]
	if bossData == nil then
		print("recv req challengeRecord not found .id:"..id.. "  aid:"..LActor.getActorId(actor))
		return
	end

	local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sBossCmd_ChallengeRecord)
	if npack == nil then return end

	if bossData.record == nil then bossData.record = {} end
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, #bossData.record)
	--print("challenge record count:"..#bossData.record)
	for _, record in ipairs(bossData.record) do
		LDataPack.writeInt(npack,record.time)
		LDataPack.writeString(npack,record.name)
		LDataPack.writeDouble(npack,record.power)
	end

	LDataPack.flush(npack)
end

local function onReqChallengeBoss(actor, packet)
	local bid = LDataPack.readInt(packet)
	local conf = PublicBossConfig[bid]
	if conf == nil then print("public on reqChallengeBoss config is nil:"..bid.. " aid:"..LActor.getActorId(actor)) return end
	if LActor.getLevel(actor) < conf.level then
		print("public boss req failed.. level. aid:"..LActor.getActorId(actor))
		return
	end
    if LActor.getZhuanShengLevel(actor) < conf.zsLevel then
        print("public boss req failed.. zslevel. aid:"..LActor.getActorId(actor))
        return
    end
	local pdata = publicBossData[bid]
	if pdata.hpPercent == 0 or pdata.hfuben == 0 then
		print("public boss req failed.. is over. aid:"..LActor.getActorId(actor))
		return
	end

	if LActor.isInFuben(actor) then
		print("public boss req failed.. in fb. aid:"..LActor.getActorId(actor))
		return
	end

	local aid = LActor.getActorId(actor)
	if pdata.damageList[aid] == nil then
		--需要检查次数
		updatePersonInfo(actor)
		local data = getStaticData(actor)
		if data.count < 1 then
			print("public boss req failed.. count. aid:".. LActor.getActorId(actor))
			return
        end

		if data.count == PublicBossBaseConfig.maxCount then
			data.last_time = System.getNowTime()
		end
		data.count = data.count - 1
        System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
            "publicboss", 1, data.count, "", "cost count", "", "")
		--清除其他boss的伤害信息
		for _, boss in pairs(publicBossData) do
			if boss.damageList[aid] ~= nil then
				boss.needUpdate = true
			end

			local ins = instancesystem.getInsByHdl(boss.hfuben)
			if ins ~= nil and ins.boss_info ~= nil then
                if ins.boss_info.damagelist then
                    if ins.boss_info.damagelist[aid] then
                        ins.boss_info.damagelist[aid] = nil
                        ins.boss_info.need_update = true
                    end
                end
			end

			boss.damageList[aid] = nil
        end
        pdata.damageList[aid] = 0

        onJoinActivity(actor)
    else

        --检查cd
        local data = getStaticData(actor)
        local challengeCd = data.challengeCd or 0
        if System.getNowTime() < challengeCd then
            print("public boss req failed.. cd. aid:"..LActor.getActorId(actor))
            return
        end
	end

    --处理进入
    local x,y = conf.enterPos.posX, conf.enterPos.posY
    x = (math.random(-3,3) + x)
    y = (math.random(-3,3) + y)

	local ret = LActor.enterFuBen(actor, pdata.hfuben, 0, x, y)
	if not ret then
		print("public boss enterFuben failed.. aid:"..LActor.getActorId(actor))
	end
end

local function updateRank(id, force)
	if not force and not publicBossData[id].needUpdate then return end

	publicBossData[id].needUpdate = false
	local damageList = publicBossData[id].damageList
	if damageList == nil then return end

	local rank = {}
	for actorId, damage in pairs(damageList) do
		table.insert(rank, {aid=actorId,dmg=damage})
	end
	table.sort(rank, function(a,b) return a.dmg>b.dmg end )
	publicBossData[id].rank = rank

	--发给副本
	notifyRank(id)
end

local function onReqRank(actor, packet)
	local id = LDataPack.readInt(packet)

	if publicBossData[id] == nil then return end
	notifyRank(id, actor)
end

--副本事件
local function getMonsterName(id)
    if MonstersConfig[id] then
        return tostring(MonstersConfig[id].name)
    end
    return "nil"
end
local function checkRewardNotice(reward, aid, config)
    for _, v in ipairs(reward) do
        if v.type == 1 and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
            local itemName = item.getItemDisplayName(v.id)
            noticemanager.broadCastNotice(PublicBossBaseConfig.rewardNotice,
                LActor.getActorName(aid), getMonsterName(config.bossId), itemName)
        end
    end
end

local function giveReward(config, aid, firstname, firstLevel, rank, firstReward,reward)
	local actor = LActor.getActorById(aid)
	if actor == nil or not LActor.canGiveAwards(actor, reward) then
		--发邮件
		local content = string.format(config.mailContent, rank)
		local mailData = {head=config.mailTitle, context=content, tAwardList=reward}
		mailsystem.sendMailById(aid, mailData)
	end
	if actor then
		--发窗口 直接给奖励
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Boss, Protocol.sBossCmd_ChallengeReward)
		if npack == nil then return end
		LDataPack.writeShort(npack, rank)
		LDataPack.writeString(npack, firstname)
		LDataPack.writeShort(npack, firstLevel)
		LDataPack.writeShort(npack, #firstReward)
		for _, v in ipairs(firstReward) do
			LDataPack.writeInt(npack, v.type or 0)
			LDataPack.writeInt(npack, v.id or 0)
			LDataPack.writeInt(npack, v.count or 0)
		end
		LDataPack.writeShort(npack, #reward)
		for _, v in ipairs(reward) do
			LDataPack.writeInt(npack, v.type or 0)
			LDataPack.writeInt(npack, v.id or 0)
			LDataPack.writeInt(npack, v.count or 0)
		end
		LDataPack.flush(npack)

		if LActor.canGiveAwards(actor, reward) then
			LActor.giveAwards(actor, reward, "publicboss reward")
		end
    end

    checkRewardNotice(reward, aid, config)
end

local function appendReward(reward, config, dmg)
	table.insert(reward, {type=AwardType_Numeric, id=NumericType_Essence, count = config.soul})
	local gold = config.goldRate * dmg
	if gold > config.goldMax then gold = config.goldMax end
	table.insert(reward, {type=AwardType_Numeric, id=NumericType_Gold, count = gold})
end

local function updateBoss(id)
	print("on updateBoss "..id)
	local npack = LDataPack.allocPacket()
	if npack == nil then return end

	LDataPack.writeByte(npack, Protocol.CMD_Boss)
	LDataPack.writeByte(npack, Protocol.sBossCmd_UpdateBoss)

	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, publicBossData[id].hpPercent)
	LDataPack.writeShort(npack, 0)
	LDataPack.writeInt(npack, publicBossData[id].reliveTime - System.getNowTime())
	LDataPack.writeByte(npack, 0)

	System.broadcastData(npack)
end

local function refreshBoss(_, id)
	print("refreshboss:"..id)
	local data = publicBossData[id]
	local hfuben = Fuben.createFuBen(PublicBossConfig[id].fbId)

	data.hpPercent = 100
	data.damageList = {}
	data.hfuben = hfuben
	data.needUpdate = false

	local ins = instancesystem.getInsByHdl(hfuben)
	if ins ~= nil then
		ins.data.pbossid = id
	end
	updateBoss(id)
end

local function onBossDie(ins)
	local bossid = ins.data.pbossid
	print("publicboss onBossDie.. "..bossid)
--计算最终伤害排名，发奖励 --发金钱 --发精魄
	updateRank(bossid, true)
	local rank = publicBossData[bossid].rank
	local config = PublicBossConfig[bossid]
	if config == nil then return end
	if rank ~= nil and rank[1] ~= nil then
		--第一名
		local firstAid = rank[1].aid
		local firstDmg = rank[1].dmg
		local firstName = LActor.getActorName(firstAid)
		local firstLevel = LActor.getActorLevel(firstAid)
		local firstReward = drop.dropGroup(config.dropId)
		appendReward(firstReward, config, firstDmg)
		giveReward(config, firstAid, firstName, firstLevel, 1, firstReward, firstReward)
		actorevent.onEvent(LActor.getActorById(firstAid),aeFullBoss,bossid,false)

		--发宝箱
		treasureboxsystem.getTreasureBox(firstAid, ins.id)

		--其他
		--local reward = utils.table_clone(config.rewards)
		for i=2,#rank do
            local reward = drop.dropGroup(config.rewards) -- 改为掉落组
			local aid = rank[i].aid
			local dmg = rank[i].dmg
			appendReward(reward, config, dmg)
			giveReward(config, aid, firstName, firstLevel, i, firstReward, reward)
			actorevent.onEvent(LActor.getActorById(aid),aeFullBoss,bossid,false)
			table.remove(reward, #reward) -- 删除金钱
			table.remove(reward, #reward) -- 删除精魄

			--发宝箱
			treasureboxsystem.getTreasureBox(aid, ins.id)
		end
	end

	--boss信息重置
	local bossData = publicBossData[bossid]
	bossData.hpPercent = 0
	bossData.damage = {}
	--处理record
	if rank ~= nil and rank[1] ~= nil then
		if #bossData.record >= 5 then
			table.remove(bossData.record, 1)
		end
		table.insert(bossData.record,
			{time=System.getNowTime(),
				name = LActor.getActorName(rank[1].aid),
				power=LActor.getActorPower(rank[1].aid) }
		)
	end

	--计算下次复活时间
	bossData.reliveTime = PublicBossConfig[bossid].refreshTime * 60  + System.getNowTime()
	bossData.hfuben = 0
	bossData.rank = nil
	bossData.needUpdate = false
	--注册定时器通知复活
	LActor.postScriptEventLite(nil, PublicBossConfig[bossid].refreshTime * 60 * 1000, refreshBoss, bossid)
	--更新给客户端boss信息？
	updateBoss(bossid)

	
end

function actorChangeName(actor, name)
    local targetId = LActor.getActorId(actor)
    for k,v in pairs(PublicBossConfig) do
        local data = publicBossData[k]
        if data then
	        local ins = instancesystem.getInsByHdl(data.hfuben)
	        if ins and ins.boss_info and ins.boss_info.damagelist then
	            for aid, v in pairs(ins.boss_info.damagelist) do
	                if targetId == aid then
	                    v.name = name
	                end
	            end
	        end
	    end
    end

end

local function onEnterFb(ins, actor)
	local id = ins.data.pbossid
	updateRank(id, actor)
end

local function onExitFb(ins, actor)
	print("public boss onExitFb.. aid:"..LActor.getActorId(actor))
	local data = getStaticData(actor)
	data.challengeCd = System.getNowTime() + PublicBossBaseConfig.challengeCd
end

local function onOffline(ins, actor)
	print("public boss onOffline.. aid:"..LActor.getActorId(actor))
	--手动调用退出副本，否则虽然会触发退出副本，但是上线会自动进入副本中
	LActor.exitFuben(actor)
end

local function onActorDie(ins, actor, killHdl)
    local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_ActorDie)
    if npack == nil then return end

    LDataPack.flush(npack)
end

--副本伤害事件
local function onBossDamage(ins, monster, value, attacker)
	local bossId = ins.data.pbossid
	local monid = Fuben.getMonsterId(monster)
	if monid ~= PublicBossConfig[bossId].bossId then
		return
	end
	--更新boss血量信息
	local oldhp = LActor.getHp(monster)
	if oldhp <= 0 then return end

	local hp = oldhp - value
	if hp < 0 then hp = 0 end

	hp = hp / LActor.getHpMax(monster) * 100
	publicBossData[bossId].hpPercent = math.ceil(hp)
	publicBossData[bossId].needUpdate = true

	--更新伤害信息
	local actor = LActor.getActor(attacker)
	if actor == nil then return end
    local data = publicBossData[bossId].damageList
    local actorId = LActor.getActorId(actor)
    if data[actorId] == nil then return end  --进入时一定会初始化,如果不在此副本,仍然有

	data[actorId] = (data[actorId] or 0) + value
end

--actor事件
local function onNewDay(actor)
	local data = getStaticData(actor)
	data.todayEssence = 0
	print("on publicboss new day. aid:"..LActor.getActorId(actor))
end

local function onLogin(actor)
	--发送boss信息
	notifyBossList(actor)
end

--定时事件
local function onTimer()
	--定时更新副本内排行榜
	for _, conf in pairs(PublicBossConfig) do
		if (publicBossData[conf.id].hpPercent or 100)~= 0 then
			updateRank(conf.id)
		end
	end
end

--其他回调
local function onAddEssence(actor, add)
    if add < 0 then return end
	local data = getStaticData(actor)
	data.todayEssence = (data.todayEssence or 0) + add
end

--启动初始化
local function initGlobalData()
	--副本事件
	for _, conf in pairs(PublicBossConfig) do
		insevent.registerInstanceWin(conf.fbId, onBossDie)
		insevent.registerInstanceEnter(conf.fbId, onEnterFb)
		insevent.registerInstanceMonsterDamage(conf.fbId, onBossDamage)
		insevent.registerInstanceExit(conf.fbId, onExitFb)
		insevent.registerInstanceOffline(conf.fbId, onOffline)
        insevent.registerInstanceActorDie(conf.fbId, onActorDie)
	end


	--消息处理
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cBossCmd_ReqPersonalInfo, onReqPersonInfo)
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cBossCmd_ReqBossList, onReqBossList)
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cBossCmd_SetClientData, onSetClientData)
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cBossCmd_ReqChallengeRecord, onReqChallengeRecord)
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cBossCmd_ReqChallengeBoss, onReqChallengeBoss)
	netmsgdispatcher.reg(Protocol.CMD_Boss, Protocol.cBossCmd_ReqRank, onReqRank)

	--actor事件
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeAddEssence, onAddEssence)
	--定时事件
	
	engineevent.regGameStartEvent(function()
		print("reg public ontime func")
		LActor.postScriptEventEx(nil, 5, function() onTimer() end, 5000, -1)
	end)

	-- 要先注册事件，然后创建副本才有效果(伤害回调)
	publicBossData =  publicBossData or {}
	local count = 0
	for _, boss in pairs(PublicBossConfig) do
        if publicBossData[boss.id] == nil then
            local hfuben = Fuben.createFuBen(boss.fbId)
            publicBossData[boss.id] = {
                hpPercent = 100,
                damageList = {},
                record = {},
                reliveTime = System.getNowTime(),
                hfuben = hfuben,
                needUpdate = false
            }
            local ins = instancesystem.getInsByHdl(hfuben)
            if ins ~= nil then
                ins.data.pbossid = boss.id
            end
        end
		count = count + 1
	end
	publicBossDataCount = count
end

table.insert(InitFnTable, initGlobalData)

--测试
function gmTestEnter(actor, id)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, id)
	LDataPack.setPosition(pack, 0)
	onReqChallengeBoss(actor, pack)
end

function gmResetCount(actor)
    local data = getStaticData(actor)
    data.count = PublicBossBaseConfig.maxCount
end
