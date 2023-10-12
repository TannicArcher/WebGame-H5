module("systems.gm.gmhandler" , package.seeall)
setfenv(1, systems.gm.gmhandler)
--[[
	GM命令
--]]

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorfunc        = require("utils.actorfunc")
local gmsystem         = require("systems.gm.gmsystem")
local postscripttimer  = require("base.scripttimer.postscripttimer")

require("systems.chapters.chapter")

local SystemId      = SystemId
local LActor        = LActor
local System        = System
local LDataPack     = LDataPack
local announcementConfig  = announcementConfig
local gmCmdHandlers = gmsystem.gmCmdHandlers


function checkArg(actor, args, argc, tip)
	if args == nil or #args < argc then
		LActor.sendTipmsg(actor,
			string.format("gm cmd err:args count error:%d, except:%d", #args, argc), ttTipmsgWindow)
		return false
	end
	return true
end
--历练 

require("systems.actorsystem.tianti.tianti")
require("systems.actorsystem.tianti.tiantirank")

local function sendGmCmdToCross(cmd, args)
	--发送消息包到跨服请求匹配
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_TransferGM)
	LDataPack.writeString(pack, cmd)
	LDataPack.writeInt(pack, #args)
	for _,arg in ipairs(args) do
		LDataPack.writeString(pack, arg)
	end
	System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsMainBattleSrv))
end

local function onRecvGmCmd(sId, sType, dp)
	local cmd = LDataPack.readString(dp)
	local func = gmCmdHandlers[cmd]
	if func then
		local args = {}
		local count = LDataPack.readInt(dp)
		for i=1,count do
			table.insert(args, LDataPack.readString(dp))
		end
		func(nil, args)
	end
end
csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_TransferGM, onRecvGmCmd)

--不固定的测试
gmCmdHandlers.test = function(actor, args)
	local id = tonumber(args[1])
	local function a(actor)
		print(LActor.getActorName(LActor.getActorId(actor)))
	end
	asynevent.reg(id, a)
	return true
end
-- 排行榜
gmCmdHandlers.rsfranking = function(actor)
	LActor.updateRanking()
	return true
end

gmCmdHandlers.addtrain = function(actor,value)
	trainsystem.addTrainExp(actor,value[1])
	return true
end

gmCmdHandlers.tiantiwin = function(actor)
	tianti.challengesResult(actor,true)
end

gmCmdHandlers.settianti = function(actor,args)
	tianti.setTianti(actor,tonumber(args[1]),tonumber(args[2]))
end

gmCmdHandlers.buymonthcard = function(actor)
	monthcard.buyMonthCard(actor)
end

-- 
gmCmdHandlers.buyprivilegemonthcard = function(actor,args)
	privilegemonthcard.buyPrivilegeMonthCard(actor)
end

gmCmdHandlers.buymonthcard1 = function(actor,args)
	monthcard.buyMonth(tonumber(args[1]))
end

gmCmdHandlers.buyprivilege = function(actor) 
	monthcard.buyPrivilege(actor)
end

gmCmdHandlers.chapter2 = function(actor, args)
	local lv = args[1]
	chapter.gmChapter2(actor, lv)
	return true
end

gmCmdHandlers.setLimitTaskFinish = function(actor, args)
	local id = args[1]
	limittimetask.setLimitTaskFinish(actor, tonumber(id))
	return true
end

gmCmdHandlers.challengeFb = function(actor, args)
	challengefbsystem.gmTestChallenge(actor, args)
	return true
end

gmCmdHandlers.heirloomtreasure = function(actor, args)
	heirloomtreasure.test(actor, args)
	return true
end

gmCmdHandlers.treasurebox = function(actor, args)
	local fubenId = args[1]
	treasureboxsystem.treasureBoxTest(actor, fubenId)
	return true
end

gmCmdHandlers.rechargeday = function(actor, args)
	local index = tonumber(args[1])
	rechargedaysawards.test(actor, index)
	return true
end

gmCmdHandlers.treasureboxinit = function(actor)
	treasureboxsystem.treasureBoxInit(actor)
	return true
end

gmCmdHandlers.quitfb = function(actor)
	LActor.exitFuben(actor)
	return true
end

gmCmdHandlers.addgold = function(actor, args)
	local gold = args[1]
	LActor.changeGold(actor, gold, "gmhandler")
	return true
end

gmCmdHandlers.addyuanbao = function(actor, args)
	local yuanbao = args[1]
	LActor.changeYuanBao(actor, yuanbao, "gmhandler")
	return true
end

gmCmdHandlers.sendmail111 = function(actor, args)
	local basic_data = toActorBasicData(LActor.getActorData(actor))
	local mailData = {head="211112", context="12313"}
	mailsystem.sendMailById(basic_data.actor_id, mailData)
end

gmCmdHandlers.additem = function(actor, args)
	local itemId = args[1]
	local count = args[2]

    if itemId ~= nil and count or 0 > 0 then
        actorawards.giveAwardBase(actor, AwardType_Item, itemId, count, "gmhandler")
    end
	return true
end

gmCmdHandlers.setattr = function(actor, args)
	local type = args[1]
	local value = args[2]
	LActor.gmSetAttr(actor, type, value)
	return true
end

gmCmdHandlers.enhance = function(actor, args)
	local roleId = tonumber(args[1]) or 0
	local posId = tonumber(args[2]) or 0
	for i = 0, 7 do
		enhancesystem.equipEnhance(actor, roleId,i)
	end
	return true
end

gmCmdHandlers.mailtest = function(actor, args)
	-- local tMailData = {}
	-- tMailData.head = "邮件测试邮件测试"
	-- tMailData.context = "邮件测试邮件测试邮件测试邮件测试"
	-- tMailData.tAwardList = {{type = AwardType_Item, id = 101001, count = 10}}

	--LActor.getActorId(actor)
	local id = tonumber(args[1] or 1)

	mailsystem.sendConfigMail(LActor.getActorId(actor), id)
	return true
end

gmCmdHandlers.sendmail = function(actor, args)
    local account = args[1]
    local id = tonumber(args[2] or 1)

    mailsystem.sendConfigMail(LActor.getActorIdByAccountName(account), id)
	return true
end

gmCmdHandlers.readmail = function(actor)
	local tMailList = LActor.getMailList(actor)
	if (not tMailList) then
		return
	end

	for index,tb in ipairs(tMailList) do
		local uid = tb[1]
		local status = tb[4]
		if (status == 0) then
			mailsystem.readMail(actor, uid)
			break;
		end
	end
	return true
end

gmCmdHandlers.mailaward = function(actor)
	local tMailList = LActor.getMailList(actor)
	if (not tMailList) then
		return
	end

	for index,tb in ipairs(tMailList) do
		local uid = tb[1]
		local status = tb[5]
		if (status == 0) then
			mailsystem.mailAward(actor, uid)
			break;
		end
	end
	return true
end

gmCmdHandlers.wingopen = function(actor, arg)
	wingsystem.wingOpen(actor, 0)
	return true
end

gmCmdHandlers.godwing = function(actor, arg)
	godwingsystem.test(actor, arg)
	return true
end

gmCmdHandlers.loginactivate = function(actor, arg)
	loginactivate.test(actor, arg)
	return true
end

gmCmdHandlers.wingtrain = function(actor, arg)
	local type = tonumber(arg[1])
	wingsystem.wingTrain(actor, 0, type)
	return true
end

gmCmdHandlers.addexp = function(actor, arg)
	local exp = tonumber(arg[1])
	actorexp.addExp(actor, exp)
	return true
end

--设置合击等级
gmCmdHandlers.setthlv = function(actor, arg)
	local level = tonumber(arg[1])
	togetherhit.gmSetLv(actor,level)
	return true
end
--使用合击技能
gmCmdHandlers.usedthskill = function(actor, arg)
	togetherhit.gmUsedskill(actor)
	return true
end

gmCmdHandlers.snewday = function(actor, arg)
	engineevent.testNewDay()
end

gmCmdHandlers.newday = function(actor, arg)
    --engineevent.testNewDay()
	OnActorEvent(actor, aeNewDayArrive, false)
    --publicboss.gmResetCount(actor)
	return true
end

gmCmdHandlers.imba = function(actor, arg)
	return imbasystem.gm_imba(actor, arg)
end

gmCmdHandlers.imba = function(actor, arg)
	return imbasystem.gm_imba(actor, arg)
end

gmCmdHandlers.imbaItem = function(actor, arg)
	return imbasystem.gm_imbaItem(actor, arg)
end

gmCmdHandlers.dropgroup = function(actor, arg)
	local dropid = tonumber(arg[1])
	local ret = drop.dropGroup(dropid)
	LActor.giveAwards(actor, ret, "testdropgroup")
	return true
end

gmCmdHandlers.testdrop = function(actor, arg)
	if #arg < 2 then return end
	local dropid = tonumber(arg[1])
	local times = tonumber(arg[2])

	local result = {}
	for i = 1,times do
		local ret = drop.dropGroup(dropid)
		for _, item  in ipairs(ret) do
            if item.type == AwardType_Numeric and item.id == NumericType_Gold then
                print("test gold: "..item.count)
            end
			result[item.type]	 = result[item.type] or {}
			result[item.type][item.id] = result[item.type][item.id] or 0
			result[item.type][item.id] = result[item.type][item.id] + 1
		end
	end

	print("total time:"..times)
	for t, g in pairs(result) do
		for id, count in pairs(g) do
			print("test result: type:"..t.." id:"..id.." drop times:"..count.."  p:"..count/times)
		end
	end
	return true
end

gmCmdHandlers.setvip = function(actor, arg)
	local vip = tonumber(arg[1])
	LActor.setVipLevel(actor, vip)
	return true
end

gmCmdHandlers.enterpublicboss = function(actor, arg)
	local bossid = tonumber(arg[1])
	publicboss.gmTestEnter(actor, bossid)
	return true
end

gmCmdHandlers.stonetest = function(actor)
	stonesystem.stoneLevelup(actor, 0)
	return true
end

gmCmdHandlers.jimgmailevelup = function(actor)
	jingmaisystem.jimgmaiLevelup(actor, 0)
	return true
end

gmCmdHandlers.jingmaistageup = function(actor)
	jingmaisystem.jingmaiStageup(actor, 0)
	return true
end

gmCmdHandlers.dailyaward = function(actor)
	dailytask.activeAward(actor, 1)
	return true
end

gmCmdHandlers.createrole = function(actor, arg)
	local job = arg[1]
	local sex = arg[2]
	role.gmOpenRole(actor, job, sex)
	return true
end

gmCmdHandlers.testpacket = function(actor)
	--test broadcast
	print("on test broadcast ")
	for i = 1,3 do
		local npack = LDataPack.allocPacket()
		if npack == nil then return end

		LDataPack.writeByte(npack, 25)
		LDataPack.writeByte(npack, 25)

		System.broadcastData(npack)
	end

	for i = 1,3 do
		local npack = LDataPack.allocPacket(actor, 25,25)
		LDataPack.flush(npack)
	end
end

gmCmdHandlers.addwingexp = function(actor, arg)
    local roleId = tonumber(arg[1])
	wingsystem.wingOpen(actor, roleId)

	local addExp = tonumber(arg[2])
	wingsystem.addExp(actor, roleId, addExp, 1)
	return true
end

gmCmdHandlers.addsoul = function(actor, arg)
	local addsoul = tonumber(arg[1])
	LActor.changeCurrency(actor, NumericType_Essence, addsoul, "gm handler")
	return true
end

gmCmdHandlers.addCurrency = function(actor, arg)
	local type = tonumber(arg[1])
	local value = tonumber(arg[2])
	LActor.changeCurrency(actor, type, value, "gm handler")
	return true
end


gmCmdHandlers.zhulingtest = function(actor)
	zhulingsystem.equipZhuling(actor, 0)
	return true
end

gmCmdHandlers.tupotest = function(actor)
	tuposystem.equipTupo(actor, 0)
	return true
end

gmCmdHandlers.storebuy = function(actor, arg)
	local tb = {{goodsId = 1, count = 50},{goodsId = 2, count = 4},{goodsId = 3, count = 10}}
	storesystem.buyGoods(actor, 1, tb)
	return true
end

gmCmdHandlers.storerefresh = function(actor, arg)
	storesystem.refreshGoods(actor)
	return true
end

gmCmdHandlers.addrecharge = function(actor, arg)
    --临时在vip里写的，接口
    local yb = tonumber(arg[1])
    if yb >0 then
    	vip.gmTestRecharge(actor, yb)
    end
	return true
end

gmCmdHandlers.noticetest = function(actor, arg)
	noticemanager.broadCastNotice(1, "哈哈哈哈", 15)
	return true
end

gmCmdHandlers.treasurehunttest = function(actor)
	treasurehuntsystem.treasureHunt(actor, 0)
	return true
end

gmCmdHandlers.addfame = function(actor)
    skirmish.gmTestFame(actor)
	return true
end

gmCmdHandlers.tipstest = function(actor, arg)
	local tipid = tonumber(arg[1]) or 1
	LActor.sendTipWithId(actor, tipid)
	return true
end

gmCmdHandlers.trainaddexp = function(actor, arg)
	local exp = tonumber(arg[1]) or 0
	trainsystem.addTrainExp(actor, exp)
	return true
end

gmCmdHandlers.leadfb = function(actor, arg)
	leadfuben.gmHandle(actor, arg)
	return true
end

gmCmdHandlers.testReward = function(actor)
	actorawards.gmTestReward(actor)
	return true
end

gmCmdHandlers.takeOutEquip = function(actor, arg)
	LActor.takeOutEquip(actor, tonumber(arg[1]), tonumber(arg[2]))
	return true
end

gmCmdHandlers.trainlevelup = function(actor)
	trainsystem.levelUp(actor)
	return true
end

gmCmdHandlers.trainlevelaward = function(actor)
	trainsystem.getLevelAward(actor)
	return true
end

gmCmdHandlers.challengefb = function(actor)
	challengefbsystem.createFuben(actor)
	return true
end

gmCmdHandlers.setlevel = function(actor, arg)
    local level = tonumber(arg[1]) or 1
    level = math.floor(level)
    if level < 1 or level > 200 then return end

    local preLevel = LActor.getLevel(actor)
    actorexp.confirmExp(actor, level, 0, 0)

    if level < preLevel then
    else
        for i= preLevel + 1, level do
            actorexp.onLevelUp(actor, i)
        end
    end

	return true
end

gmCmdHandlers.clearbag = function(actor, arg)
    local bagtype = tonumber(arg[1]) or 0
    LActor.gmClearBag(actor, bagtype)
end

gmCmdHandlers.addzhuanshengexp = function(actor, arg)
    local exp = tonumber(arg[1]) or 0
    actorzhuansheng.gmAddExp(actor, exp)
end

gmCmdHandlers.showfieldbosstime = function(actor)
    fieldboss.gmShowRefreshTime(actor)
end

gmCmdHandlers.testgiftcode = function(actor, arg)
    giftcode.gmTest(actor, arg[1])
	return true
end

gmCmdHandlers.clearKuang = function(actor, arg)
	local id = tonumber(arg[1])
    caikuangscene.clearKuang(id)
	return true
end
gmCmdHandlers.initKuang = function(actor, arg)
    caikuangsystem.initKuang(actor)
	return true
end

gmCmdHandlers.worldboss = function(actor, arg)
    return worldboss.worldBossGmHandle(actor,arg)
end

gmCmdHandlers.openNeigong = function(actor, arg)
	local id = tonumber(arg[1]) or 0
	neigongsystem.openNeigong(actor, id)
	return true
end

gmCmdHandlers.guildboss = function(actor, arg)
	guildboss.gmhandle(actor, arg)
	return true
end

gmCmdHandlers.aexring = function(actor, arg)
	actorexring.gmhandle(actor,arg)
	return true
end

gmCmdHandlers.ktlv = function(actor, arg)
	return knighthood.gmhandle(actor,arg)
end

gmCmdHandlers.setother1 = function(actor, arg)
	local count = tonumber(arg[1])
	if count and count >= 0 and count < 5 then
		otherboss1.OtherBoss1Data.openCount = count
	end
	return true
end

gmCmdHandlers.reEnterScene = function(actor, arg)
	LActor.reEnterScene(actor)
	return true
end

gmCmdHandlers.blesstest = function(actor, arg)
    local roleid= tonumber(arg[1]) or 0
    local pos = tonumber(arg[2]) or 0
    blesssystem.gmEquipBless(actor, roleid, pos)
    return true
end

gmCmdHandlers.showid = function(actor, arg)
    local aid = LActor.getActorId(actor)
    print("aid:"..aid)
    if aid < 0 then
        aid = System.bitOpAnd(aid, System.bitOpLeft(1, 31)-1) * 2
        print(":::::"..System.bitOpAnd(aid, System.bitOpLeft(1,31) -1))
        print("aid:"..aid)
    end

    if aid < 0 then
        aid = aid
    end
    --local serverid =  (aid & ((1 << 13) -1))  |  ((aid >> 27) << 13)
    local serverid = System.bitOpOr( System.bitOpAnd(aid, System.bitOpLeft(1, 13) - 1), System.bitOpLeft(System.bitOpRig(aid,27), 13))
    --local series = (aid >> 13) & ((1 << 14) - 1)
    local series = System.bitOpAnd(System.bitOpRig(aid, 13), System.bitOpLeft(1,14)-1)
    print("serverid:"..serverid)
    print("actor series:"..series)
end

gmCmdHandlers.addTitle = function(actor, arg)
	local tId = tonumber(arg[1]) or 0
	titlesystem.addTitle(actor, tId)
	return true
end

gmCmdHandlers.delTitle = function(actor, arg)
	local tId = tonumber(arg[1]) or 0
	titlesystem.delitle(actor, tId, true)
	return true
end
local function sendpkg(actor)
	for i = 1, 1000 do
		local npack = LDataPack.allocPacket(actor, 200, 200)
		if npack == nil then return end
		for j = 1, 1000 do
			LDataPack.writeInt(npack, 1)	
		end
		LDataPack.flush(npack)
	end	
end

gmCmdHandlers.sendtestpkg = function(actor, arg)
	print("test sendtestpkg")
	postscripttimer.postScriptEvent(actor, 0, sendpkg, 0, 100, actor)
end

gmCmdHandlers.monupdate = function()
	return System.monUpdate() and System.reloadGlobalNpc(nil, 0)
end

gmCmdHandlers.itemupdate = function()
	return System.itemUpdate()
end
gmCmdHandlers.setmiji = function(actor, arg)
	local id = tonumber(arg[1]) or 0
	local index = tonumber(arg[2]) or 1
	local roleid = tonumber(arg[3]) or 0
	miji.gmSetMiji(actor, roleid, index, id)
end

gmCmdHandlers.USRank = function(actor, arg)
	Ranking.updateStaticRank()
end

gmCmdHandlers.auctiondrop = function(actor, arg)
	local temp = auctiondrop.dropGroup(tonumber(arg[1]))
	print(utils.t2s(temp))
end

gmCmdHandlers.addrongluexp = function(actor, arg)
	local exp = tonumber(arg[1]) or 0
	ronglu.gmAddRongLuExp(actor, exp)
end

gmCmdHandlers.zhanlingH = function(actor, arg)
	local funcName = arg[1]
	if zhanlingsystem[funcName] then
		zhanlingsystem[funcName](actor, nil)
	end
end

gmCmdHandlers.zhanlingF = function(actor, arg)
	local funcName = arg[1]
	if zhanlingsystem[funcName] then
		zhanlingsystem[funcName](actor, unpack(arg))
	end
end

gmCmdHandlers.zhanlingM = function(actor, arg)
	local var = zhanlingcommon.getStaticVar(actor, false)
	if not var then
		return 
	end

	var[arg[1]] = tonumber(arg[2]) or arg[2]
	zhanlingsystem.handleQueryInfo(actor, nil)
end

gmCmdHandlers.setzhanlinglv = function (actor, args)
	return zhanlingsystem.gmSetZhanLing(actor, tonumber(args[1]), tonumber(args[2]))
end

gmCmdHandlers.egb = function(actor,args)
	guildbattlefb.enterFb(actor,tonumber(args[1]))
end

gmCmdHandlers.ott = function(dp)
	tianti.setGlobalTimer()
end

gmCmdHandlers.ogb = function(actor) 
	guildbattlefb.open()
end

gmCmdHandlers.cgb = function(actor) 
	guildbattlefb.setGuildBattleWinGuildId( guildbattlepersonalaward.getImperialPalaceAttributionGuildId())
end

gmCmdHandlers.engb = function(actor)
	guildbattlefb.enterNextFb(actor)
end

gmCmdHandlers.kga = function(actor)
	guildbattlefb.killGate()
end

gmCmdHandlers.storeM = function(actor, arg)
	local name, value = arg[1], arg[2]
	if name == "feats" then
		value = tonumber(value)
		if value then
			LActor.changeCurrency(actor, NumericType_Feats, value, "gm stroeM")
		end
	elseif name == "printfeats" then
		print("printfeats:" .. LActor.getCurrency(actor, NumericType_Feats))
	end
end


gmCmdHandlers.cleanfb = function (actor)
	dailyfuben.gmcleanfbcount(actor)
end


--重新载入全局npc的脚本
gmCmdHandlers.rsf = function(actor, args)
	return System.reloadGlobalNpc(actor, 0)
end

gmCmdHandlers.addscroe = function (actor,args)
	local scroe = tonumber(args[1])
	knighthood.updateknighthoodData(actor,scroe)
end


gmCmdHandlers.test = function (actor,args)
	--guildbattlefb.testcm(actor)
	--noticemanager.broadCastNotice(TianTiConstConfig.openBroadcastNotice[1])
	--local tt = System.getStaticVar()
	--if not tt.test_tt then
		--tt.test_tt = 0
	--end

	--print("tt:"..tt.test_tt)
	--local fb = LActor.getFubenId(actor)
	--print("fb:"..fb)
	--noticemanager.broadCastNotice(31)
	local hscene = LActor.getSceneHandle(actor)
	Fuben.createMonster(hscene,50002,7,8)
end

gmCmdHandlers.superman = function(actor, args)
	local superMan = not LActor.hasBitState(actor, ebsSuperman)
	if superMan then
		LActor.changeHp(actor, LActor.getIntProperty(actor, P_MAXHP))
		LActor.changeMp(actor, LActor.getIntProperty(actor, P_MAXMP))
		LActor.addBitState(actor, ebsSuperman)

		LActor.lockProperty(actor, P_HP)
		LActor.lockProperty(actor, P_MP)
	else
		LActor.removeBitState(actor, ebsSuperman)

		LActor.unLockProperty(actor, P_HP)
		LActor.unLockProperty(actor, P_MP)
	end

	LActor.sendTipmsg(actor, "Supperman is changed", ttTipmsgWindow)
	return true
end

gmCmdHandlers.enterFb = function (actor,args)
	local fbid = tonumber(args[1])
	local hfb = Fuben.createFuBen(fbid)
	LActor.enterFuBen(actor,hfb)
end

gmCmdHandlers.instantMove = function (actor,args)
	local x = tonumber(args[1])
	local y = tonumber(args[2])
	LActor.instantMove(actor,x,y)
end

gmCmdHandlers.tianti = function (actor,args)
	return tianti.tiantiGmHandle(actor,args)
end

gmCmdHandlers.publicboss = function (actor,args)
	local fbid = tonumber(args[1])
	local hfb = Fuben.createFuBen(fbid)
	publicboss.refreshBoss(3,fbid)
	--LActor.postScriptEventLite(nil,10* 1000, function() refreshBoss4(fbid) end)
end

gmCmdHandlers.campbattleenter = function(actor)
	campbattlefb.onEnter(actor)
end

gmCmdHandlers.campbattleclose = function(actor)
	campbattlefb.campbattleclose()
end

gmCmdHandlers.campbattleopen = function(actor, args)
	campbattlefb.campbattleopen(actor, args)
end

gmCmdHandlers.caikuang = function (actor,args)
	local id = tonumber(args[1])
	local actorId = tonumber(args[2])
	caikuangsystem.test(actor, id, {actorId})
	return true
end

gmCmdHandlers.acceptquest = function (actor,args)
	local achieve_id = tonumber(args[1])
	local taskid = tonumber(args[2])
	achievetask.gmaccept(actor,achieve_id,taskid)
end

gmCmdHandlers.addShatter = function(actor, arg)
	local value = tonumber(arg[1])
	LActor.changeCurrency(actor, NumericType_Shatter, value, "gm handler")
	return true
end

gmCmdHandlers.addSpeShatter = function(actor, arg)
	local value = tonumber(arg[1])
	LActor.changeCurrency(actor, NumericType_SpeShatter, value, "gm handler")
	return true
end

--获得奖励
gmCmdHandlers.addAward = function(actor, arg)
	if not arg[1] or not arg[2] then
		return false
	end
	local count = 1
	if arg[3] then
		count = tonumber(arg[3])
	end
	LActor.giveAward(actor, tonumber(arg[1]), tonumber(arg[2]), count, "gm handler")
	return true
end

--野外玩家测试命令
gmCmdHandlers.fieldplayer = function(actor, arg)
	fieldplayer.gm_fieldplayer(actor, arg)
	return true
end

--创建一个掉落物品
gmCmdHandlers.dropbag = function(actor, arg)
	local hscene = LActor.getSceneHandle(actor)
	Fuben.createDropBag(hscene, tonumber(arg[1]), tonumber(arg[2]), tonumber(arg[3]), 0, 0)
	return true
end

gmCmdHandlers.dropbags = function(actor, arg)
	local hscene = LActor.getSceneHandle(actor)
	local num = tonumber(arg[1])
	local rewards = {}
	for i = 1,num do
		table.insert(rewards, {type=0, id=1, count=i})
	end
	local x,y = LActor.getPosition(actor)
	Fuben.RewardDropBag(hscene, x, y, LActor.getActorId(actor), rewards)
	return true
end

local etfb_handle = nil
gmCmdHandlers.etfb = function(actor, arg)
	if etfb_handle == nil or instancesystem.getInsByHdl(etfb_handle) == nil then
		etfb_handle = Fuben.createFuBen(99999)
	end
	--local ins = instancesystem.getInsByHdl(etfb_handle)
	
	--local pos = {{posX=20,posY=17},{posX=21,posY=17},{posX=22,posY=17},{posX=23,posY=17},
	--{posX=24,posY=17},{posX=20,posY=13},{posX=21,posY=13},{posX=22,posY=13},{posX=23,posY=13},
	--{posX=24,posY=13},{posX=20,posY=14},{posX=20,posY=15},{posX=20,posY=16},{posX=24,posY=14},
	--{posX=24,posY=15},{posX=24,posY=16}}
	--local rand = math.random(1, #pos)
	--local epos = pos[rand]
--[[	
	local rconf = TianTiRobotConfig[1]
	for i ,v in pairs(rconf) do
		local d = RobotData:new_local()
		d.name  = v.name
		d.level = v.level
		d.job = v.job
		d.sex = v.sex 
		d.clothesId = v.clothesId 
		d.wingOpenState = v.wingOpenState
		d.wingLevel = v.wingLevel 
		d.attrs:Reset()
		for j,jv in pairs(v.attrs) do 
			d.attrs:Set(jv.type,jv.value)
		end
		for j,jv in pairs(v.skills) do 
			d.skills[j] = jv
		end
		local robot = LActor.createRobot(d, ins.scene_list[1], 31,15)
		LActor.setCamp(robot, tonumber(arg[1]))
	end
]]	
	LActor.enterFuBen(actor,etfb_handle)
	--LActor.setCamp(actor, tonumber(arg[1]))
	--[[
	for i=0, LActor.getRoleCount(actor)-1 do
		local role = LActor.getRole(actor, i)
		if role then
			LActor.changeMonsterAi(role, 0)
		end
	end
	]]
	--Fuben.clearAllMonster(LActor.getSceneHandle(actor))
	return true
end

gmCmdHandlers.cmon = function(actor, arg)
	local mid = tonumber(arg[1])
	local hscene = LActor.getSceneHandle(actor)
	local x,y = LActor.getPosition(actor)
	local num = tonumber(arg[2]) or 1
	for i=1,num do
		local rp = tonumber(arg[3]) or 0
		local xx = x + math.random(rp*-1,rp)
		local yy = y + math.random(rp*-1,rp)
		local monster = Fuben.createMonster(hscene, mid, xx, yy)
		LActor.setCamp(monster, tonumber(arg[4]) or 0)
	end
	return true
end

gmCmdHandlers.calc = function(actor, arg)
	LActor.reCalcAttr(actor)
	return true
end

gmCmdHandlers.todrop = function(actor, arg)

	local data = chapter.getStaticData(actor)
	local chapterLevel = data.level - 1
	local conf = ChaptersConfig[chapterLevel]
	if conf == nil then
		conf = ChaptersConfig[chapterLevel -1]
		if conf == nil then
			return
		end
	end
	local effTime = tonumber(arg[1])
	--普通怪
	local dropCount = math.floor(conf.dropEff / 60 * effTime)
	local reward = drop.dropGroupExpected(conf.offlineDropId, dropCount)
	print("普通怪掉落:")
	for _,v in ipairs(reward) do 
		print("type:"..v.type..",id:"..v.id..",count:"..v.count)
	end
	--精英怪
	local dropEliteCount = math.floor((conf.dropEliteEff or 0) / 60 * effTime)
	local rewardElite = drop.dropGroupExpected(conf.offlineEliteDropId or 0, dropEliteCount)
	print("精英怪掉落:")
	local all = 0
	for _,v in ipairs(rewardElite) do 
		print("type:"..v.type..",id:"..v.id..",count:"..v.count)
		all = all + v.count
	end
	print(all)
end

gmCmdHandlers.newworldboss=function(actor, args)
	return newworldboss.gmHandle(actor, args)
end

gmCmdHandlers.move=function(actor, args)
	local x = tonumber(args[1])
	local y = tonumber(args[2])
	--for i=0, LActor.getRoleCount(actor)-1 do
		local role = LActor.getLiveByJob(actor)
		if role then
			LActor.RequestFubenPathLine(role, x, y)
		end
	--end
end

gmCmdHandlers.rich=function(actor, args)
	richmansystem.gmHandle(actor, args)
	return true
end

gmCmdHandlers.city=function(actor, args)
	citysystem.gmhandle(actor, args)
	return true
end

gmCmdHandlers.yupei=function(actor, args)
	yupei.gmhandle(actor, args)
	return true
end

gmCmdHandlers.cswuji=function( actor, args )
	print("gmCmdHandlers.cswuji")
	if System.isCommSrv() then sendGmCmdToCross("cswuji", args) return end
	print("gmCmdHandlers.cswuji call")
	crosswujifbmgr.onGmHandle(args)
end

gmCmdHandlers.crossboss=function(actor, args)
	print("gmCmdHandlers.crossboss")
	if System.isCommSrv() then sendGmCmdToCross("crossboss", args) return end
	print("gmCmdHandlers.crossboss call")
	crossbossfb.onGmHandle(args)
end

gmCmdHandlers.devilbossopen=function(actor, args)
	print("gmCmdHandlers.devilbossopen")
	if System.isCommSrv() then sendGmCmdToCross("devilbossopen", args) return end
	print("gmCmdHandlers.devilboss call")
	devilbossfb.devilBossOpen(args)
end

gmCmdHandlers.wuji=function(actor, args)
	return wujisystem.gmhandle(actor,args)
end

--无极战场副本内命令,只能在跨服服使用
gmCmdHandlers.wujifb=function( actor, args )
	if System.isCommSrv() then return false end 
	return crosswujifb.gmhandle(actor, args)
end

gmCmdHandlers.peak = function( actor, args )
	if actor then
		sendGmCmdToCross("peak", args)
	end
	if not System.isCommSrv() then
		sendGmCmdToCross("peak", args)
		return peakracecrosssystem.gmHandle(args)
	else
		return peakracesystem.gmHandle(actor, args)
	end 
end

gmCmdHandlers.peaksign = function( actor, args )
	return peakracesystem.gmPeakSignHandle(actor, args)
end

gmCmdHandlers.teamfb = function( actor, args )
	return teamfuben.gmHandle(actor, args)
end

gmCmdHandlers.auctionadd=function(actor, args)
	return auctionsystem.addGoods({LActor.getActorId(actor)}, LActor.getGuildId(actor), tonumber(args[2]), (tonumber(args[1]) == 0) and true or false)
end

gmCmdHandlers.auctionset=function(actor, args)
	return auctionsystem.gmSetLimit(actor, tonumber(args[1]), tonumber(args[2]))
end

function showvarsize(actor)
	local names = {}
	local var = LActor.getStaticVar(actor)
	var = var.taskEventRecord
	for _,i in pairs(taskcommon.taskType or {}) do
		table.insert(names, "taskEventRecord." .. i)
	end
	for _,name in ipairs(names) do
		local size = System.getClvariantSize(actor, name)
		if size > 0 then
			print(LActor.getActorId(actor).." showvarsize " .. string.format("name:%s, size=%d", name, size))
		end
	end
end
_G.showvarsize = showvarsize
gmCmdHandlers.showvarsize=function(actor,args)
	showvarsize(actor)
end

gmCmdHandlers.printAllLua=function(actor,args)
	System.printAllLua(actor)
end

gmCmdHandlers.biandage=function(actor, args)
	--固定值
	local ad = LActor.getActorData(actor)
	ad.zhuansheng_lv = #ZhuanShengLevelConfig --转生等级
	ad.essence = 100000
	ad.knighthood_lv = #KnighthoodConfig --勋章等级
	ad.reincarnate_lv = #ReincarnationLevel --轮回等级
	ad.chapter_level = 3000
	ad.bag_grid = 900 --背包格仔
	--变牛逼的命令
	gmsystem.ProcessGmCommand(actor, "@addgold 990000000")
	gmsystem.ProcessGmCommand(actor, "@setlevel 200")
	gmsystem.ProcessGmCommand(actor, "@addyuanbao 100000000")
	gmsystem.ProcessGmCommand(actor, "@addrecharge 100000000")
	gmsystem.ProcessGmCommand(actor, "@addsoul 100000000")
	gmsystem.ProcessGmCommand(actor, "@trainaddexp 100000000")
	gmsystem.ProcessGmCommand(actor, "@addzhuanshengexp 100000000")
	gmsystem.ProcessGmCommand(actor, "@addtrain 100000000")
	gmsystem.ProcessGmCommand(actor, "@additem 600024 3") --官印
	local var = LActor.getStaticVar(actor)
	for _,item in pairs(ItemConfig) do
		if item.zsLevel >= 12 then
			gmsystem.ProcessGmCommand(actor, "@additem "..item.id.." 1")
		elseif (item.type == 6 and item.quality == 5 and item.id%100 == 99) then
			gmsystem.ProcessGmCommand(actor, "@additem "..item.id.." 3")
		end
	end
	for i=0,2 do
		--传世满级
		for _,c in pairs(HeirloomEquipFireConfig) do
			LActor.setHeirloomLv(actor, i, c.slot - 1, #HeirloomEquipConfig[c.slot])
		end
		--遍历部位
		for _,fi in ipairs(ForgeIndexConfig) do
			--强化满级
			LActor.setEnhanceLevel(actor, i, fi.posId, #EnhanceCostConfig)
			--精炼
			LActor.setStoneLevel(actor, i, fi.posId, #StoneLevelCostConfig)
			--铸造
			LActor.setZhulingLevel(actor, i, fi.posId, #ZhulingCostConfig)
		end
		--经脉
		LActor.setJingmaiLevel(actor, i, #JingMaiLevelConfig)
		--翅膀
		LActor.setWingStatus(actor, i, 1)
		LActor.setWingLevel(actor, i, #WingLevelConfig)
		--内功
		if nil == var.neigongdata then
			var.neigongdata = {}
		end
		if nil == var.neigongdata[i] then
			var.neigongdata[i] = {}
		end
		local max = #NeiGongStageConfig
		local maxlv = #NeiGongStageConfig[max]
		var.neigongdata[i].level = maxlv
		var.neigongdata[i].stage = max
		var.neigongdata[i].exp = 0
		var.neigongdata[i].val = 0
		var.neigongdata[i].isOpen = 1
		--兵魂
		if nil == var.weaponsoulsystem then var.weaponsoulsystem = {} end
		var.weaponsoulsystem[i] = {}
		local bh = var.weaponsoulsystem[i]
		bh.wsact = {}
		bh.pos = {}
		for _,c in ipairs(WeaponSoulConfig) do
			bh.wsact[c.id] = 1
			for _,cc in ipairs(c.actcond) do
				bh.pos[cc] = #WeaponSoulPosConfig[cc]
			end
		end
		--戒指
		for id,_ in pairs(ExRingConfig) do
			LActor.setExRingLevel(LActor.getRole(actor, i), id, 1)
		end
		--龙魂
		LActor.setSoulShieldAct(actor,i,ssLoongSoul,1)
		LActor.setSoulShieldStage(actor,i,ssLoongSoul,#LoongSoulStageConfig)
		LActor.setSoulShieldLevel(actor,i,ssLoongSoul,#LoongSoulConfig)
		--玉佩
		if nil == var.jadeplate then var.jadeplate = {} end
		var.jadeplate[i] = {}
		var.jadeplate[i].level = #JadePlateLevelConfig
	end
	--爬塔
	if nil == var.challengeFb then var.challengeFb = {} end
	var.challengeFb.curId = #FbChallengeConfig
	var.challengeFb.ydayLv = #FbChallengeConfig
	--神器
	if var.imbaData == nil then var.imbaData = {} end
	if var.imbaData.act == nil then var.imbaData.act = {} end
	if var.imbaData.get == nil then var.imbaData.get = {} end
	local data = var.imbaData
	for k , conf in pairs(ImbaJigsawConf or {}) do
		local groupId = math.floor(conf.jigsawId/10)*10
		local groupIdx = math.floor(conf.jigsawId%10)
		data[groupId] = System.bitOpSetMask(data[groupId] or 0, groupIdx-1, true)
	end
	for k , conf in pairs(ImbaConf or {}) do
		data.act[conf.id] = 1
		actorevent.onEvent(actor, aeActImba, conf.id)
	end
	--历练
	if (var.trainVar == nil) then
		var.trainVar = {}
	end
	var.trainVar.level = #TrainLevelConfig
	--图鉴
	var.TuLuData = {}
	var.SuitData = {}
	var.TuLuData.CardsCount = 0
	var.TuLuData.Cards = {}
	for id,item in ipairs(DecomposeConfig) do
		--记录顺序ID
		var.TuLuData.CardsCount = var.TuLuData.CardsCount + 1
		var.TuLuData.Cards[var.TuLuData.CardsCount] = {}
		var.TuLuData.Cards[var.TuLuData.CardsCount].id = id
		--激活和等级
		var.TuLuData[id] = {}
		var.TuLuData[id].isActivate = 1 --激活
		var.TuLuData[id].starlevel = #CardConfig[id] --等级
	end
	for id,suit in ipairs(SuitConfig) do
		var.SuitData[id] = {}
		var.SuitData[id].cout = 0
		for _,item in pairs(suit) do
			if var.SuitData[id].cout < item.count then
				var.SuitData[id].cout = item.count
			end
		end
	end
	--玩家特戒
	for id,cfg in pairs(ActorExRingConfig) do
		LActor.setActorExRingLevel(actor, id, #(_G["ActorExRing"..tostring(id).."Config"]))
		LActor.SetActorExRingIsEff(actor, id, 1)
	end
	--装扮
	var.zhuangban = {}
	var.zhuangban.zhuangban = {}
    var.zhuangban.zhuangbanlevel = {}
    var.zhuangban.use = {}
    for i=0, 2 do
        var.zhuangban.use[i] = {}
        for pos = 1, 3 do
            var.zhuangban.use[i][pos] = 0
        end
    end
    for id,_ in ipairs(ZhuangBanId) do
    	var.zhuangban.zhuangban[id] = 999999999
    	var.zhuangban.zhuangbanlevel[id] = ZhuangBanLevelUp[id] and #(ZhuangBanLevelUp[id]) or 1
    end
    --战灵
    for id, zhanling in pairs(ZhanLingLevel) do
    	zhanlingsystem.gmSetZhanLing(actor, id, #zhanling)
    end

	gmsystem.ProcessGmCommand(actor, "@chapter2 3000")
end

gmCmdHandlers.hideboss = function(actor, args)
	hideboss.gmHandle(actor, args)
	return true
end

gmCmdHandlers.killMon = function(actor, args)
	Fuben.killAllMonster(LActor.getSceneHandle(actor))
	return true
end

-- 测试活动7中BOSS个人积分，第一个参数为分数，第二个为活动ID
gmCmdHandlers.addbossscore = function ( actor, args )
	local score, act_id = (tonumber(args[1]) or 0), (tonumber(args[2]) or 251)
	subactivitytype7.gmAddBossScore(actor, score, act_id)
end

--测试玩家跳转跨服就否正常
gmCmdHandlers.loginBattle = function (actor, args)
	local srvType = tonumber(args[1])
	local mainbattle = csbase.GetBattleSvrId(srvType)
	if mainbattle ~= 0 then
		LActor.loginOtherSrv(actor, mainbattle, 0, LActor.getSceneId(actor), 0, 0)
		print("=============LActor.loginOtherSrv============")
	end
	return true
end

-- 清除个人活动数据
gmCmdHandlers.clearpact = function ( actor, args )
	pactivitysystem.eraseData(actor)
end

gmCmdHandlers.clearggwcount = function ( actor, args )
	local var = guardgodweaponsys.getStaticVar(actor)
	var.useCount = 0
	guardgodweaponsys.sendSysInfo(actor)
end
