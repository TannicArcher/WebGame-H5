--other boss 1 (转生boss)

module("otherboss1", package.seeall)


local ERR_NOERR
local ERR_COUNT = 1 --次数不足
local ERR_CD = 2 --cd未到
local ERR_OVER = 3 --已结束
local ERR_LEVEL = 4 --没有符合条件的boss
local ERR_TIME = 5 --活动未开启
local ERR_FUBEN = 6 --在副本中
local ERR_OTHER = 7
local ERR_ACTIVATE= 8

--[[
staticRecord = {
	table bossRecord [id] = level (0)
}

staticData = {
    bool isOpen
    int openTime
    int openCount -- 当前已开启boss数
    table bossList [id] = {
        int id
        int hfuben
        table rank { {dmg, aid}[]}
        table lottery {
            number eid  计时器id
            number reward 道具id
            number 最大點數角色 aid
            number 最大點數 point
            table record { [aid]: true} 抽奖记录
        }
        int killerId
        table nextShield --下次的护盾配置
        table curShield --下次的护盾配置
        int shield, --当前护盾
    }
 }

 personData = {
    short count;
    int challengeCd
    int id -- 当前挑战boss, nil or id
    int idMark -- 用于对比当前挑战boss是否是本次活动的
    int deathMark --死亡标记, 用于异步计时器回调时验证
 }
--]]


local p = Protocol
local baseConf = OtherBoss1BaseConfig
local bossConf = OtherBoss1Config
OtherBoss1Data = OtherBoss1Data or {}
OtherBoss1Count = OtherBoss1Count or 0

local function getGlobalData()
    return OtherBoss1Data
end

local function getBossData(id)
    return OtherBoss1Data.bossList[id]
end

local function getGlobalRecord()
	local data = System.getStaticVar()
	if data.otherBoss1Record == nil then
		data.otherBoss1Record = {}
	end
	if data.otherBoss1Record.bossRecord == nil then
		data.otherBoss1Record.bossRecord = {}
	end

	return data.otherBoss1Record
end

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return nil end

    if var.otherBoss1 == nil then
        var.otherBoss1 = {}
    end
    return var.otherBoss1
end

local function notifyPersonInfo(actor)
    local npack = LDataPack.allocPacket(actor, p.CMD_OtherBoss, p.sOtherBoss1Cmd_UpdatePersonInfo)
    if npack == nil then return end

    local data = getStaticData(actor)
    LDataPack.writeShort(npack, data.count or baseConf.dayCount)

    if data.idMark ~= OtherBoss1Data.openTime then
        data.challengeCd = nil
    end

    local cd = (data.challengeCd or 0) - System.getNowTime()
    if cd < 0 then cd = 0 end
    LDataPack.writeShort(npack, cd)
    LDataPack.flush(npack)
end

local function notifyGlobalInfo(actor)
    local npack
    if actor then
        npack = LDataPack.allocPacket(actor, p.CMD_OtherBoss, p.sOtherBoss1Cmd_UpdateGlobalInfo)
        if npack == nil then return end
    else
        npack = LDataPack.allocPacket()
        LDataPack.writeByte(npack, p.CMD_OtherBoss)
        LDataPack.writeByte(npack, p.sOtherBoss1Cmd_UpdateGlobalInfo)
    end

    local gdata = getGlobalData()
    LDataPack.writeByte(npack, gdata.isOpen and 1 or 0)

    if actor then
        LDataPack.flush(npack)
    else
        System.broadcastData(npack)
    end
end

local function getNextShield(id, hp)
    if hp == nil then hp = 101 end

    local conf = bossConf[id]
    if conf == nil then return nil end

    for i, s in ipairs(conf.shield) do
        if s.hp < hp then return s end
    end

    return nil
end

local function updaterank(id)
    local data = getGlobalData()
    local bossinfo = data.bossList[id]
    if bossinfo == nil then return end
    local ins = instancesystem.getInsByHdl(bossinfo.hfuben)
    if ins == nil then return end
    if ins.boss_info == nil or ins.boss_info.damagerank == nil then return end

    local rank = ins.boss_info.damagerank
    local s = #rank
    if s > 5 then s = 5 end
    bossinfo.rank = {}
    for i = 1,s do
        table.insert(bossinfo.rank, {id= rank[i].id, name = rank[i].name, damage = rank[i].damage})
    end
end


--活动开始回调
local function startCallback(rule)
    print("call otherboss1.startCallback , cur time:" .. os.time())
    local gdata = getGlobalData()
    if gdata.isOpen == true then return end
    gdata.isOpen = true
    gdata.openTime = System.getNowTime()
    local grecord = getGlobalRecord()
    --判断是否需要开启
    while (gdata.openCount or 0) < OtherBoss1Count do
	    local conf = bossConf[(gdata.openCount or 0) + 1]
	    local count = System.getActorCountOfZhuanShengLv(conf.llimit)
	    if count < conf.openCount then break end
	    gdata.openCount = (gdata.openCount or 0) + 1
    end
    --开始活动
    for id, conf in pairs(bossConf) do
	    if id <= (gdata.openCount or 0) then
		    local hfuben = Fuben.createFuBen(conf.fbid)
		    local boss = OtherBoss1Data.bossList[conf.id]
		    boss.hfuben = hfuben
		    local ins = instancesystem.getInsByHdl(hfuben)
		    if ins ~= nil then
			    ins.data.id = conf.id
			    ins.data.bossid = conf.baseBossId + (grecord.bossRecord[id] or 0)
			    local monster = Fuben.createMonster(ins.scene_list[1], ins.data.bossid)
			    if monster == nil then
				    print("create other1 boss monster failed:"..ins.data.bossid)
			    else
				    print("create otherboss1.index:"..tostring(id).." id:"..tostring(ins.data.bossid).." by record lv:"..tostring(grecord.bossRecord[id] or 0).. " hp:"..LActor.getHp(monster))
			    end
		    end
		    boss.rank = {}
		    boss.needUpdate = false
		    boss.nextShield = getNextShield(boss.id)
		    if boss.nextShield == nil then
			    print(boss.id)
			    --assert(false)
		    end
		    boss.curShield = nil
		    boss.shield = 0
	    end
    end
    noticemanager.broadCastNotice(baseConf.startNotice)
    notifyGlobalInfo()
end

--活动结束回调
local function endCallback(rule)
    local data = getGlobalData()
    --结束活动
    if data.isOpen == true then
        data.isOpen = false
        for id, boss in pairs(OtherBoss1Data.bossList) do
            local ins = instancesystem.getInsByHdl(boss.hfuben)
            if ins ~= nil then
                print("ins lose, OtherBoss1Data.bossList id:" .. id)
                ins:lose()
                boss.hfuben = 0
            end
        end
        noticemanager.broadCastNotice(baseConf.endNotice)
        notifyGlobalInfo()
    end
end

--预告公告回调
local function advanceNoticeCallback(rule)
    local data = getGlobalData()
    if data.isOpen == true then return end
    noticemanager.broadCastNotice(baseConf.advanceNotice)
end

local function reborn(actor, now_t)
    local data = getStaticData(actor)
    if data.deathMark ~= now_t then return end

    notifyPersonInfo(actor)
    LActor.relive(actor)
end

local function giveReward(actorid, id, first, last, index)
    local conf = bossConf[id]
    if conf == nil then return end

    local rewards = conf.rank4
    if index == 1 then
        rewards = conf.rank1
    elseif index == 2 then
        rewards = conf.rank2
    elseif index >=3 and index <=5 then
        rewards = conf.rank3
    end

    local actor = LActor.getActorById(actorid)
    if actor then
        local npack = LDataPack.allocPacket(actor, p.CMD_OtherBoss, p.sOtherBoss1Cmd_BossResult)
        if npack == nil then return end

        LDataPack.writeString(npack, first or "")
        LDataPack.writeString(npack, last or "")
        LDataPack.writeShort(npack, index)
        LDataPack.writeShort(npack, #rewards)
        for _, v in ipairs(rewards) do
            LDataPack.writeInt(npack, v.type or 0)
            LDataPack.writeInt(npack, v.id or 0)
            LDataPack.writeInt(npack, v.count or 0)
        end

        LDataPack.flush(npack)
    end
    --邮件
    local content = string.format(conf.rankMailContent, tostring(index))
    local mailData = {head=conf.rankMailHead, context=content, tAwardList=rewards}
    print("call otherboss1.giveReward, send mail, actorid:" .. actorid)
    mailsystem.sendMailById(actorid, mailData)

end
--副本回调
local function onWin(ins)
    --排名奖励
    local id = ins.data.id
    local conf = bossConf[id]
    if conf == nil then return end

    updaterank(id)

    local boss = getBossData(id)
    local rank = ins.boss_info.damagerank
    local first = LActor.getActorName(rank[1].id)
    local last = LActor.getActorName(boss.killerId or 0)
    for i,v in ipairs(rank) do
       --发奖励邮件和弹结算面板
        giveReward(v.id, id, first, last, i)
    end

    boss.hfuben = 0

	local nowt = System.getNowTime()
    local gdata = getGlobalData()
    local grecord = getGlobalRecord()


    local tmpTime = nowt - gdata.openTime
    for k,v in ipairs(baseConf.upgradeTime) do
        if tmpTime <= v[1] then
            for i=v[2], 1, -1 do
                if MonstersConfig[ins.data.bossid + i] ~= nil then
                    grecord.bossRecord[id] = (grecord.bossRecord[id] or 0) + i
                    break
                end
            end
            break
        end
    end
	-- if nowt - gdata.openTime < baseConf.upgradeTime then
	-- 	if MonstersConfig[ins.data.bossid + 1] ~= nil then
	-- 		--下一次提高1级, 按id
	-- 		grecord.bossRecord[id] = (grecord.bossRecord[id] or 0) + 1
	-- 	end
	-- end
end

local function onLose(ins)
    --排名奖励
    local id = ins.data.id
    local conf = bossConf[id]
    if conf == nil then return end

    updaterank(id)

    local boss = getBossData(id)
    local needDecline = false
    if ins.boss_info then
        local rank = ins.boss_info.damagerank
        if rank ~= nil then
	        local first = LActor.getActorName(rank[1].id)
	        local last = LActor.getActorName(boss.killerId or 0)
	        for i,v in ipairs(rank) do
		        --发奖励邮件和弹结算面板
		        giveReward(v.id, id, first, last, i)
		        needDecline = true
	        end
        end
    end
    Fuben.clearAllMonster(ins.scene_list[1])
    boss.hfuben = 0
	if needDecline then
		local grecord = getGlobalRecord()

        local maxHp = Fuben.getMonsterMaxHp(ins.boss_info.id)
        local curHp = ins.boss_info.hp
        if maxHp and curHp and maxHp > 0 and curHp > 0 then
            local hpPercent = math.floor((curHp / maxHp) * 100)

			for k,v in ipairs(baseConf.downgradeHp) do
			    if hpPercent <= v[1] then
			        for i=v[2], 1, -1 do
			            if MonstersConfig[ins.data.bossid - i] ~= nil then
			                grecord.bossRecord[id] = (grecord.bossRecord[id] or 0) - i
			                break
			            end
			        end
			        break
			    end
			end

        end


		-- if MonstersConfig[ins.data.bossid - 1] ~= nil then
		-- 	--下一次降低1级, 按id
		-- 	grecord.bossRecord[id] = (grecord.bossRecord[id] or 0) - 1
		-- end
	end
end

local function notifyShield(hfuben, shield)
    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, p.CMD_OtherBoss)
    LDataPack.writeByte(npack, p.sOtherBoss1Cmd_BossShield)

    LDataPack.writeInt(npack, shield)
    Fuben.sendData(hfuben, npack)
end

local function onEnterFb(ins, actor)
    local data = getStaticData(actor)
    data.challengeCd = 0

    local boss = getBossData(ins.data.id)
    local nowShield
    if boss.shield == 0 then
        nowShield = 0
    else
        nowShield = math.floor(boss.shield / boss.curShield.shield * 100)
    end
    notifyShield(ins.handle, nowShield)
end

local function endLottery(_, boss)
    if boss.lottery == nil then return end

    local a,min = boss.lottery.aid,boss.lottery.point
    LActor.log(a,"otherboss1.endLottery")
    
    if a ~= nil and a ~= 0 then
        local conf = bossConf[boss.id]
        if not conf then

            boss.lottery = nil
            return
        end
        --公告, 邮件
        local head = conf.lotteryMailTitle
        local content = conf.lotteryMailContent
        local mailData = {head=head, context=content, tAwardList={{type=1,id=boss.lottery.reward,count=1}} }
        print("call otherboss1.endLottery send mail to actorID:" .. a )
        mailsystem.sendMailById(a, mailData)

        local name = LActor.getActorName(a)
        local bossName, itemName
        if conf.bossId and MonstersConfig[conf.bossId] then
            bossName = MonstersConfig[conf.bossId].name
        end
        if ItemConfig[boss.lottery.reward] then
            itemName = ItemConfig[boss.lottery.reward].name
        end

        if name and bossName and itemName then
            noticemanager.broadCastNotice(baseConf.lotteryNotice, name, bossName, itemName)
            print("sendNotice:"..baseConf.lotteryNotice)
            print("sendNotice:"..name)
            print("sendNotice:"..bossName)
            print("sendNotice:"..itemName)
        else
            print("other boss1 lottery config error.. actor:".. name)
            print("bossname:".. bossName)
            print("itemName:".. itemName)
        end
    end
    boss.lottery = nil
end

local function startLottery(ins, reward)
    local id = ins.data.id
    local boss = getBossData(id)
    if boss.lottery then
        LActor.cancelScriptEvent(nil, boss.lottery.eid)
        endLottery(nil, boss)
    end
    --抽奖信息初始化
    boss.lottery = {}
    boss.lottery.eid = LActor.postScriptEventLite(nil, 10000, endLottery, boss)
    boss.lottery.reward = reward
    boss.lottery.aid = nil
    boss.lottery.point = 0
    boss.lottery.record = {}

    local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, p.CMD_OtherBoss)
    LDataPack.writeByte(npack, p.sOtherBoss1Cmd_UpdateLottery)

    LDataPack.writeInt(npack, reward or 0)
    Fuben.sendData(ins.handle, npack)
end

local function onBossDamage(ins, monster, value, attacker, res)
    local bossId = ins.data.bossid
    local monid = Fuben.getMonsterId(monster)
    if monid ~= bossId then
        return
    end

    local boss = getBossData(ins.data.id)
    if boss == nil then return end

    local oldhp = LActor.getHp(monster)
    if oldhp <= 0 then return end
    local hp  = res.ret --实际血量

    --血量百分比
    hp = hp / LActor.getHpMax(monster) * 100

    --print(boss.shield)
    --print("on boss Damage1".. value)
    --print("shield: "..tostring(boss.shield))
    --if boss.nextShield then
     --   print("next shield: "..tostring(boss.nextShield.hp))
    --end
    if boss.shield == 0 or boss.shield == nil then
        --触发护盾
        if boss.nextShield and boss.nextShield.hp ~= 0 and hp < boss.nextShield.hp then
            print("otherboss1.onBossDamage ,on boss Damage2")
            boss.curShield = boss.nextShield
            boss.shield = boss.nextShield.shield
            boss.nextShield = getNextShield(ins.data.id, boss.curShield.hp)
            res.ret = math.floor(LActor.getHpMax(monster) * boss.curShield.hp / 100)
            notifyShield(boss.hfuben, 100)
        end
    else
        local lastShield = math.floor(boss.shield / boss.curShield.shield * 100)
        --print("lastShield:"..lastShield)
        if boss.shield > value then
            boss.shield = boss.shield - value
            res.ret = oldhp
        else
            --护盾消失
            boss.shield = 0
            value = value - boss.shield
            hp = oldhp - value
            if hp < 0 then hp = 0 end
            res.ret = hp
            --触发抽奖
            startLottery(ins, boss.curShield.reward)
        end
        --护盾百分比变化时广播
        local nowShield = math.floor(boss.shield / boss.curShield.shield * 100)
        if lastShield ~= nowShield then
	        print("otherboss1.onBossDamage nowShield: "..nowShield)
            notifyShield(boss.hfuben, nowShield)
        end
    end

    if res.ret <= 0 then
        local actor = LActor.getActor(attacker)
        if actor ~= nil then
            --最后击杀
            boss.killerId = LActor.getActorId(actor)
            --公告, 邮件
            local conf = bossConf[boss.id]
            local head = conf.killMailTitle
            local content = conf.killMailContent
            print("otherboss1.onBossDamage send main to boss.killerId: ".. boss.killerId)
            local mailData = {head=head, context=content, tAwardList={{type=1,id=conf.killReward,count=1}} }
            mailsystem.sendMailById(boss.killerId, mailData)

            local name = LActor.getActorName(boss.killerId)
            local bossName, itemName
            if conf.bossId and MonstersConfig[conf.bossId] then
                bossName = MonstersConfig[conf.bossId].name
            end
            if ItemConfig[conf.killReward] then
                itemName = ItemConfig[conf.killReward].name
            end

            if name and bossName and itemName then
                noticemanager.broadCastNotice(baseConf.killNotice, name, bossName, itemName)
                print("sendNotice:"..baseConf.killNotice)
                print("sendNotice:"..name)
                print("sendNotice:"..bossName)
                print("sendNotice:"..itemName)
            else
                print("other boss1 killNotice config error.. actor:".. name)
                print("bossname:".. bossName)
                print("itemName:".. itemName)
            end
        else
            print("otherboss1.onBossDamage,other boss1 killer is nil, id:" .. boss.id)
        end
        --触发副本胜利, 没法配置在副本内了
        ins:win()
    end
end

local function onExitFb(ins, actor)
    local data = getStaticData(actor)
    if data.challengeCd == 0 then
        data.challengeCd = System.getNowTime() + baseConf.challengeCd
        notifyPersonInfo(actor)
    end
    data.deathMark = nil
end

local function onOffline(ins, actor)
    --手动调用退出副本，否则虽然会触发退出副本，但是上线会自动进入副本中
    LActor.exitFuben(actor)
end

local function onActorDie(ins, actor, killerHdl)
    local data = getStaticData(actor)
    local nowt = System.getNowTime()
    data.challengeCd = nowt + baseConf.challengeCd
    notifyPersonInfo(actor)
    -- 计时器,自动复活?
    LActor.postScriptEventLite(actor, baseConf.challengeCd * 1000, reborn, nowt)
    data.deathMark = nowt
end

--内部统一处理函数
local function enter(actor)
    local data = getStaticData(actor)
    if data.id == nil then
        return false
    end
    local gdata = getGlobalData()
    local hfuben = gdata.bossList[data.id].hfuben

    local x,y = bossConf[data.id].enterPos.posX, bossConf[data.id].enterPos.posY
    x = (math.random(-6,6) + x)
    y = (math.random(-6,6) + y)
    return LActor.enterFuBen(actor, hfuben, 0, x,y)
end

--消息处理
local function onReqBossList(actor, packet)
    local npack = LDataPack.allocPacket(actor, p.CMD_OtherBoss, p.sOtherBoss1Cmd_ResBossList)
    if npack == nil then return end

    local gdata = getGlobalData()
    local data = getStaticData(actor)
    if data.idMark ~= gdata.openTime then
        data.id = nil
    end

    LDataPack.writeShort(npack, OtherBoss1Count)
    for id, boss in pairs(gdata.bossList) do
        LDataPack.writeInt(npack, id)
        LDataPack.writeByte(npack, boss.hfuben == 0 and 1 or 0)
        LDataPack.writeByte(npack, (data.id == id) and 1 or 0)
    end
    LDataPack.writeShort(npack, gdata.openCount or 0)
    LDataPack.flush(npack)
end

local function getid(actor)
    local zslevel = LActor.getZhuanShengLevel(actor)
    for _, boss in pairs(bossConf) do
        if boss.llimit <= zslevel and boss.hlimit >= zslevel then
	        local gdata = getGlobalData()
	        if boss.id > (gdata.openCount or 0) then
		        return gdata.openCount or 0
	        else
		        return boss.id
	        end
        end
    end

    return nil
end
local function checkEnter(actor)
    local gdata = getGlobalData()
    if not gdata.isOpen then return ERR_TIME end

    local data = getStaticData(actor)
    if data == nil then return ERR_OTHER end

    --校验记录id
    if (data.idMark ~= gdata.openTime) then
        data.id = nil
    end

    if ((data.count or baseConf.dayCount) <= 0) and data.id == nil then
        return ERR_COUNT
    end

    if LActor.isInFuben(actor) then
        return ERR_FUBEN
    end

    local id = data.id
    if id == nil then id = getid(actor) end
    if id == nil then
        return ERR_LEVEL
    end

    if gdata.bossList[id] == nil then return ERR_OTHER end
    if gdata.bossList[id].hfuben == 0 then return ERR_OVER end

    if (data.challengeCd or 0) > System.getNowTime() then
        return ERR_CD
    end

    return ERR_NOERR
end

local function onReqChallenge(actor, packet)
    local ret = checkEnter(actor)
    if ret == ERR_NOERR then
        local data = getStaticData(actor)
        local gdata = getGlobalData()
        if data.id == nil then
            data.id = getid(actor)
            print("otherboss1.onReqChallenge data.id="..data.id)
            data.idMark = gdata.openTime
            data.count = (data.count or baseConf.dayCount) -1
            notifyPersonInfo(actor)
        end
        if not enter(actor) then
            ret = ERR_OTHER
        end
    end

    local npack = LDataPack.allocPacket(actor, p.CMD_OtherBoss, p.sOtherBoss1Cmd_ResChallenge)
    if npack == nil then return end
    LDataPack.writeByte(npack, ret or 0)
    LDataPack.flush(npack)
end

local function onReqRankList(actor, packet)
    local id = LDataPack.readInt(packet)

    local gdata = getGlobalData()
    if gdata.bossList[id] == nil then return end

    local rank = gdata.bossList[id].rank
    if rank == nil then return end

    local npack = LDataPack.allocPacket(actor, p.CMD_OtherBoss, p.sOtherBoss1Cmd_ResRankList)
    if npack == nil then return end
    LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, #rank)

    for _, d in ipairs(rank) do
        LDataPack.writeInt(npack, d.id)
        LDataPack.writeString(npack, d.name)
        LDataPack.writeDouble(npack, d.damage)
    end

    LDataPack.flush(npack)
end

function actorChangeName(actor, name)
    -- local gdata = getGlobalData()
    -- if gdata.bossList == nil then return end
    -- local targetId = LActor.getActorId(actor)
    -- for k,v in pairs(gdata.bossList) do

    --     if v == nil then return end
    --     local ins = instancesystem.getInsByHdl(v.hfuben)
    --     if ins == nil then return end
    --     if ins.boss_info == nil or ins.boss_info.damagerank == nil then return end

    --     local rank = ins.boss_info.damagerank
    --     for _, d in ipairs(rank) do
    --         if d.id == targetId then
    --             d.name = name
    --         end
    --     end
    -- end

    local targetId = LActor.getActorId(actor)
    for id, conf in pairs(bossConf) do
        local data = OtherBoss1Data.bossList[conf.id]
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

local function onReqLottery(actor, packet)
    local data = getStaticData(actor)
    if data.id == nil then
    	print("otherboss1.onReqLottery data.id is nil")
        return
    end

    local gdata = getGlobalData()
    if not gdata.isOpen then
    	print("otherboss1.onReqLottery not gdata.isOpen ")
        return
    end
    if gdata.bossList[data.id].lottery == nil then
    	print("otherboss1.onReqLottery gdata.bossList[data.id].lottery is nil, data.id:" .. data.id)
        return
    end

    local aid = LActor.getActorId(actor)
    if gdata.bossList[data.id].lottery.record[aid] ~= nil then
    	print("otherboss1.onReqLottery gdata.bossList[data.id].lottery.record[aid] is nil, aid:" .. aid)
        return
    end

    local roll = math.random(100)
    gdata.bossList[data.id].lottery.record[aid] = roll

    local npack = LDataPack.allocPacket(actor, p.CMD_OtherBoss, p.sOtherBoss1Cmd_ReqLottery)
    if npack == nil then return end
    LDataPack.writeShort(npack, roll)
    LDataPack.flush(npack)

    if roll > gdata.bossList[data.id].lottery.point then
        gdata.bossList[data.id].lottery.point = roll
        gdata.bossList[data.id].lottery.aid = aid
        local recordname = LActor.getActorName(LActor.getActorId(actor))

        local ins = instancesystem.getInsByHdl(gdata.bossList[data.id].hfuben)
        if ins == nil then return end

        local npack = LDataPack.allocPacket()
        if npack == nil then return end

        LDataPack.writeByte(npack, p.CMD_OtherBoss)
        LDataPack.writeByte(npack, p.sOtherBoss1Cmd_ReqLotteryBroast)
        LDataPack.writeString(npack, recordname or "")
        LDataPack.writeShort(npack, roll)
        Fuben.sendData(ins.handle, npack)
    end
end

local function onReqBuyCd(actor, packet)
    local gdata = getGlobalData()
    if not gdata.isOpen then return end

    local data = getStaticData(actor)
    if data == nil then return end

    local ret = true
    if (data.challengeCd or 0) < System.getNowTime() then
        ret = false
    end
    if ret then
        local yb = LActor.getCurrency(actor, NumericType_YuanBao)
        if yb >= baseConf.clearCdCost then
        	print("otherboss1.onReqBuyCd changeYuanBao count:" .. baseConf.clearCdCost)
            LActor.changeYuanBao(actor, 0-baseConf.clearCdCost, "otherboss1 buy cd")
            data.challengeCd = 0
        else
            return
        end
    end

    notifyPersonInfo(actor)

    if data.deathMark then
        LActor.relive(actor)
        data.deathMark = nil
    else
	    --enter(actor)
    end
end

--logic timer
local function onTimer()
    local data = getGlobalData()
    for id, boss in pairs(data.bossList) do
        if boss.hfuben ~= 0 then
            updaterank(id)
        end
    end
end

--actor事件
local function onLogin(actor)
    notifyPersonInfo(actor)
    notifyGlobalInfo(actor)
end

local function onNewDay(actor, isLogin)
    local data = getStaticData(actor)
    data.count = baseConf.dayCount
    print("call otherboss1 onNewDay aid:"..LActor.getActorId(actor))
    if not isLogin then
        onLogin(actor)
    end
end

--启动初始化
local function initGlobalData()
    --副本事件
    for _, conf in pairs(bossConf) do
        insevent.registerInstanceWin(conf.fbid, onWin)
        insevent.registerInstanceLose(conf.fbid, onLose)
        insevent.registerInstanceEnter(conf.fbid, onEnterFb)
        insevent.registerInstanceMonsterDamage(conf.fbid, onBossDamage)
        insevent.registerInstanceExit(conf.fbid, onExitFb)
        insevent.registerInstanceOffline(conf.fbid, onOffline)
        insevent.registerInstanceActorDie(conf.fbid, onActorDie)
    end


    --消息处理
    netmsgdispatcher.reg(p.CMD_OtherBoss, p.cOtherBoss1Cmd_ReqBossList, onReqBossList)
    netmsgdispatcher.reg(p.CMD_OtherBoss, p.cOtherBoss1Cmd_ReqChallenge , onReqChallenge)
    netmsgdispatcher.reg(p.CMD_OtherBoss, p.cOtherBoss1Cmd_ReqRankList , onReqRankList)
    netmsgdispatcher.reg(p.CMD_OtherBoss, p.cOtherBoss1Cmd_ReqLottery, onReqLottery)
    netmsgdispatcher.reg(p.CMD_OtherBoss, p.cOtherBoss1Cmd_ReqBuyCd, onReqBuyCd)

    --actor事件
    actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)


    --初始化记录
    local count = 0
    if OtherBoss1Data.bossList == nil then
        OtherBoss1Data.bossList = {}
    end
    local bossList = OtherBoss1Data.bossList
    for _, boss in pairs(bossConf) do
        if bossList[boss.id] == nil then
            --local hfuben = Fuben.createFuBen(boss.fbid)
            bossList[boss.id] = {
                id = boss.id,
                hfuben = 0,
                needUpdate = false,
                nextShield = getNextShield(boss.id),
                shield = 0,
                curShield = nil
            }
        end
        count = count + 1
    end
    OtherBoss1Count = count

    --活动时间注册
    local s, e = timedomain.getTimes(baseConf.openTime)
    if s == -1 or e == -1 then print("other boss1 open time config error.") return end
    for _, t in ipairs(baseConf.openTime) do
        timedomain.regStart(t, startCallback)
        timedomain.regEnd(t, endCallback)
    end

    for _, t in ipairs(baseConf.advanceNoticeTime) do
        timedomain.regStart(t, advanceNoticeCallback)
    end

    
    engineevent.regGameStartEvent(function()
        print("reg otherboss1 ontime func")
        LActor.postScriptEventEx(nil, 5, function() onTimer() end, 5000, -1)

        while (OtherBoss1Data.openCount or 0) < OtherBoss1Count do
	        local conf = bossConf[(OtherBoss1Data.openCount or 0) + 1]
	        local count = System.getActorCountOfZhuanShengLv(conf.llimit)
	        print("init otherboss1 zhuansheng lv count:".. count)
	        if count < conf.openCount then break end
	        OtherBoss1Data.openCount = (OtherBoss1Data.openCount or 0) + 1
        end
    end)
end

table.insert(InitFnTable, initGlobalData)


function gmrestart(param)
    print(param)
    if param == nil then
        endCallback()
        startCallback()
        return
    end
    if param == '0' then
        endCallback()
    elseif param == '1' then
        startCallback()
    end
end
