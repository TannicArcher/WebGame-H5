--无极战场副本模块(跨服服)
module("crosswujifb", package.seeall)
WujiCamp = crosswujifbmgr.WujiCamp
--[[ins.data 结构
	actorInfo={
		[玩家ID]= {
			aid = 玩家ID
			name = 玩家名字
			sid = 服务器ID
			zslv = 转生等级
			isdon = 是否扩张匹配
			entryCount = 已轮空次数
			pid = 当前的匹配池ID
			mtime = 报名匹配时间
			power = 战斗力
			camp = 阵营ID
			killNum = 杀人数
			dieNum = 死亡数
			assistNum = 助攻数
			flagNum = 采旗数
			isMvp = 是否MVP
			isSub = 是否扣除了次数
		}
	}
	fubenActor={
		[阵营ID] = {玩家id,x4},
		[阵营ID] = {玩家id,x4}
	}
	oneHpAid = 拿1血的玩家ID
	saiEid = 预备时间定时器ID
	endEid = 结束定时器ID
	flagScoreEid = 旗帜积分获得定时器ID
	startTime = 正式开始的时间戳
	monInfo = { --采集怪信息
		i = 配置的索引
		monid = 怪物ID
		hdl = 怪物handle
		camp = 所属阵营
	}
	CampScore[阵营] = 分数
]]
--获取副本变量
local function getFuBenData(ins)
	return ins.data
end

--[[获取跨服玩家静态变量
	CanJoinNum = 可参与次数
]]
local function getCrossStaticData(actor)
    local var = LActor.getCrossVar(actor)
    if nil == var.wujisys then var.wujisys = {} end
    if nil == var.wujisys.CanJoinNum then 
    	var.wujisys.CanJoinNum = WujiBaseConfig.openRwTimes
    end
    return var.wujisys
end

--[[
cache={
	rebornCd = 复活CD时间
	eid = 复活定时器ID
}
]]
--获取临时动态数据
local function getDynamicData(actor)
	local var = LActor.getDynamicVar(actor)
	if var == nil then return nil end
	if var.crosswujifb == nil then
		var.crosswujifb = {}
	end
	return var.crosswujifb
end

--获取玩家的ins
local function getInsByActor(actor)
	return instancesystem.getInsByHdl(LActor.getFubenHandle(actor))
end

--通知玩家的复活信息
local function notifyRebornTime(actor, killerHdl)
	local cache = getDynamicData(actor)
    local rebornCd = (cache.rebornCd or 0) - System.getNowTime()
    if rebornCd < 0 then rebornCd = 0 end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_WuJi, Protocol.sWuJi_SendRebornCd)
    LDataPack.writeShort(npack, rebornCd)
    LDataPack.flush(npack)
end

--获取复活坐标点
local function getRandomPoint(camp)
	local cfg = WujiBaseConfig.birthPointA
	if camp == WujiCamp.CampB then
		cfg = WujiBaseConfig.birthPointB
	end
	local pos = cfg[math.random(1,#cfg)]
	return pos.x, pos.y
end

--复活倒计时到了
local function reborn(actor, rebornCd)
    local cache = getDynamicData(actor)
    if cache.rebornCd ~= rebornCd then print(LActor.getActorId(actor).." crosswujifb.reborn cache.rebornCd ~= rebornCd") return end
    notifyRebornTime(actor)
	local x,y = getRandomPoint(LActor.getCamp(actor))
    LActor.relive(actor, x, y)
    LActor.stopAI(actor)
end

--实时下发玩家的击杀助攻信息
local function sendActorInfo(ins, actor)
	local fdata = getFuBenData(ins)
	local info = fdata.actorInfo[LActor.getActorId(actor)]
	if not info then
		print(LActor.getActorId(actor).." crosswujifb.sendActorInfo is not info")
		return
	end
	local npack = LDataPack.allocPacket(actor,  Protocol.CMD_WuJi, Protocol.sWuJi_SendActorInfo)
	LDataPack.writeInt(npack, info.killNum or 0) --杀人数
	LDataPack.writeInt(npack, info.dieNum or 0)	 --死亡数
	LDataPack.writeInt(npack, info.assistNum or 0) --助攻数
	LDataPack.writeInt(npack, info.flagNum or 0) --采旗数
	LDataPack.flush(npack)
end

--玩家死亡时候的回调
local function onActorDie(ins, actor, killerHdl)
	local fdata = getFuBenData(ins)
	local dieAid = LActor.getActorId(actor)
	fdata.actorInfo[dieAid].dieNum = (fdata.actorInfo[dieAid].dieNum or 0) + 1 --记录死亡次数
	sendActorInfo(ins, actor)
	local dieCamp = LActor.getCamp(actor) --死亡玩家的阵营
	LActor.stopAI(actor)
	--给击杀人记录杀人数
	local killerEntity = LActor.getEntity(killerHdl)
	local killerActor = LActor.getActor(killerEntity)
	if killerActor then
		local killAid = LActor.getActorId(killerActor)
		fdata.actorInfo[killAid].killNum = (fdata.actorInfo[killAid].killNum or 0) + 1 --记录杀人数
		sendActorInfo(ins, killerActor)
		LActor.stopAI(killerActor)
	end
	--给助攻的人加助攻次数
	local fubenActors = Fuben.getAllActor(ins.handle)
	if fubenActors then
		for i = 1,#fubenActors do 
			if LActor.getCamp(fubenActors[i]) ~= dieCamp and fubenActors[i] ~= killerActor then 
				local assistAid = LActor.getActorId(fubenActors[i])
				fdata.actorInfo[assistAid].assistNum = (fdata.actorInfo[assistAid].assistNum or 0) + 1 --记录助攻
				sendActorInfo(ins, fubenActors[i])
				LActor.stopAI(fubenActors[i])
			end
		end
	end
	--注册复活定时
	local cache = getDynamicData(actor)
	-- 计时器自动复活
	local rebornCd = System.getNowTime() + (WujiBaseConfig.reInteVal or 0)
	cache.eid = LActor.postScriptEventLite(actor, (WujiBaseConfig.reInteVal or 0) * 1000, reborn, rebornCd)
	cache.rebornCd = rebornCd
	--通知复活时间
	notifyRebornTime(actor, killerHdl)
	--todo 清除buff和增加buff
end

--玩家进入副本的回调
local function onEnterFb(ins, actor)
	--获取玩家ID
	local aid = LActor.getActorId(actor)
	--分配阵营
	local info = ins.data.actorInfo[aid]
	if not info then --不可能找不到阵营,找不到直接踢回原服
		LActor.exitFuben(actor)
		return
	end
	--检测扣除次数
	if not info.isSub then
		local cvar = getCrossStaticData(actor)
		cvar.CanJoinNum = cvar.CanJoinNum - 1
		info.isSub = true
	end
	--设置阵营
	LActor.setCamp(actor, info.camp)
	--停止AI
	LActor.stopAI(actor)
	--下发初始化信息
	local fdata = ins.data
	local npack = LDataPack.allocPacket(actor,  Protocol.CMD_WuJi, Protocol.sWuJi_SendInitInfo)
    LDataPack.writeInt(npack, fdata.startTime or 0)
	LDataPack.writeInt(npack, info.camp)
	LDataPack.writeInt(npack, fdata.CampScore and fdata.CampScore[WujiCamp.CampA] or 0)
	LDataPack.writeInt(npack, fdata.CampScore and fdata.CampScore[WujiCamp.CampB] or 0)
	--遍历所有旗帜怪物
	local count = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeChar(npack, count)
	for _,minfo in pairs(fdata.monInfo or {}) do
		LDataPack.writeChar(npack, minfo.i)
		LDataPack.writeDouble(npack, minfo.hdl)
		count = count + 1
	end
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeChar(npack, count)
	LDataPack.setPosition(npack, pos2)
	LDataPack.flush(npack)
end

--检测是否胜利
local function checkWin(ins, camp, score)
	if score >= WujiBaseConfig.winScore then
		ins:win()
	end
end

--获取积分需要增长的倍数
local function getScoreIncrease(ins)
	local fdata = getFuBenData(ins)
	if System.getNowTime() + WujiBaseConfig.specialTime <= fdata.startTime then
		return WujiBaseConfig.scoreIncrease or 1
	end
	return 1
end

--增加指定阵营的积分
local function addCampScore(ins, camp, val)
	--获取副本变量
	local fdata = getFuBenData(ins)
	if not fdata.CampScore then fdata.CampScore = {} end
	fdata.CampScore[camp] = (fdata.CampScore[camp] or 0) + val * getScoreIncrease(ins)
	--下发积分变化消息
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_WuJi)
    LDataPack.writeByte(npack, Protocol.sWuJi_SendChangeScore)
    LDataPack.writeInt(npack, fdata.CampScore and fdata.CampScore[WujiCamp.CampA] or 0)
	LDataPack.writeInt(npack, fdata.CampScore and fdata.CampScore[WujiCamp.CampB] or 0)
    Fuben.sendData(hfuben, npack)
	--检查胜利
	checkWin(ins, camp, fdata.CampScore[camp])
end

--增加积分时间到
local function onAddScoreTimer(ins)
	--获取副本变量
	local fdata = getFuBenData(ins)
	--遍历所有旗帜怪物
	for _,minfo in pairs(fdata.monInfo or {}) do	
		--判断加积分
		for _,camp in pairs(WujiCamp) do
			if minfo.camp == camp then
				addCampScore(ins, camp, WujiBaseConfig.addScore[minfo.i] or 0)
			end
		end
	end
end

function onFuBenCreate(ins)
	--获取副本变量
	local fdata = getFuBenData(ins)
	--创建采集怪
	if not fdata.monInfo then fdata.monInfo = {} end
	for i,monid in ipairs(WujiBaseConfig.monId) do
		local pos = WujiBaseConfig.flagPoint[i]
		if pos then
			local flags = Fuben.createMonster(ins.scene_list[1], monid, pos.x, pos.y)
			local flags_handle = LActor.getHandle(flags)
			fdata.monInfo[flags_handle] = {i=i, monid=monid, hdl=flags_handle}
		end
	end
	--站场开启倒计时
	if WujiBaseConfig.readyTime then
		--停止副本AI
		Fuben.setIsNeedAi(ins.handle, false)
		--注册定时开启消息
		fdata.startTime = System.getNowTime() + WujiBaseConfig.readyTime
		fdata.saiEid = LActor.postScriptEventLite(nil, WujiBaseConfig.readyTime * 1000, function(_,ins) 
			Fuben.setIsNeedAi(ins.handle, true)
			fdata.saiEid = nil
		end, ins)
		--注册副本结束定时器
		fdata.endEid = LActor.postScriptEventLite(nil, (WujiBaseConfig.turnTime + WujiBaseConfig.readyTime) * 1000, function(_,ins)
			fdata.saiEid = nil
			ins:lose()
		end, ins)
	end
	--采集积分获取定时器
	local inter_val = WujiBaseConfig.addScoreInterval * 1000
	fdata.flagScoreEid = LActor.postScriptEventEx(nil, inter_val, function(_, ins) onAddScoreTimer(ins) end, inter_val, -1, ins)
end

--开始一次采集
local function onGatherStart(ins, gather, actor)
	local ghandle = LActor.getHandle(gather)
	local fdata = getFuBenData(ins)
	--获取采集怪信息
	if not fdata.monInfo or not fdata.monInfo[ghandle] then
		return false
	end
	local gatherInfo = fdata.monInfo[ghandle]
	--同阵营不能采集
	if gatherInfo.camp == LActor.getCamp(actor) then
		return false
	end
	return true
end

--完成一次采集回调
local function onGatherFinished(ins, gather, actor, success)
	--获取副本变量
	local fdata = getFuBenData(ins)
	--采集怪handle
	local ghandle = LActor.getHandle(gather)
	--获取采集怪信息
	if not fdata.monInfo or not fdata.monInfo[ghandle] then
		return
	end
	local gatherInfo = fdata.monInfo[ghandle]
	if success then
		local aid = LActor.getActorId(actor)
		fdata.actorInfo[aid].flagNum = (fdata.actorInfo[aid].flagNum or 0) + 1 --记录采旗数
		--下发自己的信息
	    sendActorInfo(ins, actor)
		--设置阵营
		gatherInfo.camp = LActor.getCamp(actor)
		--下发旗帜阵营变化消息
		local npack = LDataPack.allocPacket()
	    LDataPack.writeByte(npack, Protocol.CMD_WuJi)
	    LDataPack.writeByte(npack, Protocol.sWuJi_SendChangeScore)
	    LDataPack.writeChar(npack, gatherInfo.i)
		LDataPack.writeInt(npack, gatherInfo.camp)
	    Fuben.sendData(hfuben, npack)
	end
end

--回收所有定时器
local function cancelEvent(ins)
	local fdata = getFuBenData(ins)
	if fdata.flagScoreEid then
		LActor.cancelScriptEvent(nil, fdata.flagScoreEid)
		fdata.flagScoreEid = nil
	end
	if fdata.saiEid then
		LActor.cancelScriptEvent(nil, fdata.saiEid)
		fdata.saiEid = nil
	end
	if fdata.endEid then
		LActor.cancelScriptEvent(nil, fdata.endEid)
		fdata.endEid = nil
	end	
end

--获取MVP值
local function getMvpVal(info)
	local par = WujiBaseConfig.mvpScorePar
	--MVP算法，分数=杀人数*a-死亡数*b+助攻数*c+采旗数*d
	return par.a*(info.killNum or 0) - par.b*(info.dieNum or 0) + par.c*(info.assistNum or 0) + par.d*(info.flagNum or 0)
end

--计算MVP
local function calcMvp(ins)
	local fdata = getFuBenData(ins)
	for camp,aids in pairs(fdata.fubenActor) do
		local mvp_aid = nil
		local mvp_val = nil
		for _,aid in ipairs(aids) do
			local info = fdata.actorInfo[aid]
			if info then
				local mv = getMvpVal(info)
				if not mvp_val or mv > mvp_val then
					mvp_val = mv
					mvp_aid = aid
				end
			end
		end
		if mvp_aid then
			local info = fdata.actorInfo[mvp_aid]
			info.isMvp = true
		end
	end
end

--发放副本奖励
local function giveFuBenEndReward(ins)
	local fdata = getFuBenData(ins)
	--先判断阵营获取的奖励
	local campRewardKey = {}
	local aScore = fdata.CampScore and fdata.CampScore[WujiCamp.CampA] or 0
	local bScore = fdata.CampScore and fdata.CampScore[WujiCamp.CampB] or 0
	if aScore == bScore then
		--平局的时候
		campRewardKey[WujiCamp.CampA] = 2
		campRewardKey[WujiCamp.CampB] = 2
	elseif bScore < aScore then
		--A方胜利
		campRewardKey[WujiCamp.CampA] = 1
		campRewardKey[WujiCamp.CampB] = 3
	else
		--B方胜利
		campRewardKey[WujiCamp.CampA] = 3
		campRewardKey[WujiCamp.CampB] = 1		
	end
	--发放奖励邮件
	for aid,info in pairs(fdata.actorInfo) do
		if info.isSub then --没进来玩过就不发了
			local rkey = campRewardKey[info.camp]
			if rkey then
				local mail_data = {} 
				mail_data.head = WujiBaseConfig.mail_head
	            mail_data.context = WujiBaseConfig.mail_context
	            mail_data.tAwardList = utils.table_clone(WujiBaseConfig.endReward[rkey])
	            if info.isMvp then
	            	table.insert(mail_data.tAwardList, WujiBaseConfig.mvpReward[rkey])
	            elseif info.aid == fdata.oneHpAid then
	            	table.insert(mail_data.tAwardList, WujiBaseConfig.firstBloodReward)
	            end
	            mailsystem.sendMailById(aid, mail_data, info.sid)
			end
		end
	end
end

--给对应的服务器发送副本结束的消息
local function sendFuBenEndToServer(sid, aids)
	print("crosswujifb.sendFuBenEndToServer sid:"..sid)
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCWujiCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCWujiCmd_FuBenEnd)
	LDataPack.writeInt(npack, #aids)
	for i,aid in ipairs(aids) do
		LDataPack.writeInt(npack, aid)
	end
	System.sendPacketToAllGameClient(npack, sid)
end

--副本胜利(提前到达积分)或失败(时间到)时候回调
local function onFuBenEnd(ins)
	--回收定时器
	cancelEvent(ins)
	--计算MVP
	calcMvp(ins)
	--发放奖励
	giveFuBenEndReward(ins)
	local sidAid = {}
	--下发旗帜阵营变化消息
	local fdata = getFuBenData(ins)
	local npack = LDataPack.allocPacket()
    LDataPack.writeByte(npack, Protocol.CMD_WuJi)
    LDataPack.writeByte(npack, Protocol.sWuJi_SendResult)
    LDataPack.writeInt(npack, fdata.CampScore and fdata.CampScore[WujiCamp.CampA] or 0)
	LDataPack.writeInt(npack, fdata.CampScore and fdata.CampScore[WujiCamp.CampB] or 0)
	local count = #(fdata.fubenActor[WujiCamp.CampA])+#(fdata.fubenActor[WujiCamp.CampB])
	LDataPack.writeChar(npack, count)
	for aid,info in pairs(fdata.actorInfo) do
		if not sidAid[info.sid] then sidAid[info.sid] = {} end
		print("crosswujifb.onFuBenEnd aid:"..aid)
		table.insert(sidAid[info.sid], aid)
		LDataPack.writeInt(npack, info.sid)
		LDataPack.writeString(npack, info.name)
		LDataPack.writeInt(npack, info.camp)	--阵营ID
		LDataPack.writeInt(npack, info.killNum or 0) --杀人数
		LDataPack.writeInt(npack, info.dieNum or 0)	 --死亡数
		LDataPack.writeInt(npack, info.assistNum or 0) --助攻数
		LDataPack.writeInt(npack, info.flagNum or 0) --采旗数
		LDataPack.writeChar(npack, aid == fdata.oneHpAid and 1 or 0) --是否1血
		LDataPack.writeChar(npack, info.isMvp and 1 or 0) --是否MVP
	end
    Fuben.sendData(ins.handle, npack)
    --给对应的本服发结束消息
    for sid,aids in pairs(sidAid) do
    	sendFuBenEndToServer(sid, aids)
    end
    --给管理器调用一下副本结束
    crosswujifbmgr.onFuBenEnd(ins)
end

--攻击列表
local function onRoleDamage(ins, actor, role, value, attacker, res)
	if not attacker or not actor then return end
	local attackActor = LActor.getActor(attacker)
	if attackActor then
		local fdata = getFuBenData(ins)
		if not fdata.oneHpAid then
			fdata.oneHpAid = LActor.getActorId(attackActor)
			--广播一血
			local npack = LDataPack.allocPacket(attackActor,  Protocol.CMD_WuJi, Protocol.sWuJi_SendOneHp)
			LDataPack.flush(npack)
		end
	end
end

--请求聊天
local function onReqChat(actor, packet)
	local camp = LActor.getCamp(actor)
	local ins = getInsByActor(actor)
	if not ins then return end
	if ins.id ~= WujiBaseConfig.fbId then
		print(LActor.getActorId(actor).." crosswujifb.onReqChat is not wuji fuben")
		return
	end
	--遍历阵营里面的所有人发消息
	local msg = LDataPack.readString(packet)
	local fdata = getFuBenData(ins)
	local info = fdata.actorInfo[LActor.getActorId(actor)]
	if not info then
		print(LActor.getActorId(actor).." crosswujifb.onReqChat is not info")
		return
	end
	for _,aid in ipairs(fdata.fubenActor and fdata.fubenActor[camp] or {}) do
		print(aid.." on sendchat:"..msg)
		local sactor = LActor.getActorById(aid)
		if sactor then
			print(aid.." sendchat:"..msg)
			local npack = LDataPack.allocPacket(sactor,  Protocol.CMD_WuJi, Protocol.sWuJi_SendChat)
		    LDataPack.writeInt(npack, info.sid)
			LDataPack.writeString(npack, info.name)
			LDataPack.writeString(npack, msg)
			LDataPack.flush(npack)
		end
	end
end

--请求所有人面板信息
local function onReqAllInfo(actor, packet)
	local camp = LActor.getCamp(actor)
	local ins = getInsByActor(actor)
	if not ins then return end
	if ins.id ~= WujiBaseConfig.fbId then
		print(LActor.getActorId(actor).." crosswujifb.onReqAllInfo is not wuji fuben")
		return
	end
	local fdata = getFuBenData(ins)
	local npack = LDataPack.allocPacket(actor,  Protocol.CMD_WuJi, Protocol.sWuJi_SendAllInfo)
	local count = #(fdata.fubenActor[WujiCamp.CampA])+#(fdata.fubenActor[WujiCamp.CampB])
	LDataPack.writeChar(npack, count)
	for aid,info in pairs(fdata.actorInfo) do
		LDataPack.writeInt(npack, info.sid)
		LDataPack.writeString(npack, info.name)
		LDataPack.writeInt(npack, info.camp)	--阵营ID
		LDataPack.writeInt(npack, info.killNum or 0) --杀人数
		LDataPack.writeInt(npack, info.dieNum or 0)	 --死亡数
		LDataPack.writeInt(npack, info.assistNum or 0) --助攻数
		LDataPack.writeInt(npack, info.flagNum or 0) --采旗数
		LDataPack.writeChar(npack, aid == fdata.oneHpAid and 1 or 0) --是否1血
	end
	LDataPack.flush(npack)
end

--启动初始化
local function initGlobalData()
	if System.isCommSrv() then return end
	netmsgdispatcher.reg(Protocol.CMD_WuJi, Protocol.cWuJi_ReqChat, onReqChat) --请求聊天
	netmsgdispatcher.reg(Protocol.CMD_WuJi, Protocol.cWuJi_ReqAllInfo, onReqAllInfo)
	--监听副本事件
	insevent.registerInstanceActorDie(WujiBaseConfig.fbId, onActorDie) --玩家死亡时
	insevent.registerInstanceEnter(WujiBaseConfig.fbId, onEnterFb) --玩家进入副本时
	insevent.registerInstanceGatherFinish(WujiBaseConfig.fbId, onGatherFinished) --玩家采集完成时
	insevent.registerInstanceGatherStart(WujiBaseConfig.fbId, onGatherStart) --玩家开始采集时
	insevent.registerInstanceWin(WujiBaseConfig.fbId, onFuBenEnd) --副本胜利时候(提前到达分数)
	insevent.registerInstanceLose(WujiBaseConfig.fbId, onFuBenEnd) --副本输的时候(时间到了)
	insevent.registerInstanceActorDamage(WujiBaseConfig.fbId, onRoleDamage) --玩家受到伤害的时候
end

table.insert(InitFnTable, initGlobalData)

--wujifb(跨服)
function gmhandle(actor, args)
	local cmd = args[1]
	if cmd == "flag" then
		local ins = instancesystem.getInsByHdl(LActor.getFubenHandle(actor))
		local index = tonumber(args[2])
		for handle,minfo in pairs(ins.data.monInfo) do
			if minfo.i == index then
				local et = LActor.getEntity(handle)
				LActor.setAITarget(actor,et)
				return true
			end
		end
		return false
	else
		return false
	end
	return true
end
