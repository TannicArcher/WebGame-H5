--无极战场(游戏服)
module("wujisystem", package.seeall)
WujiCamp = crosswujifbmgr.WujiCamp

globalWuJiData = globalWuJiData or {}
--[[获取临时全局变量
	openpertime = 预告开始时间戳
	opentime = 开始时间戳
	endtime = 结束时间戳
	matchAid[aid] = 匹配时间
	playerInfo[aid] = {
		fbhdl = 跨服的副本handle
		idx = 第几人
		camp = 阵营
	}
]]
local function getGlobalData()
	return globalWuJiData
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

--判断活动是否可以开启
local function checkCanOpen()
	return System.getOpenServerDay() >= (WujiBaseConfig.serverDay or 0)
end

--判断活动是否开启
local function isOpen()
	if not checkCanOpen() then return false end
	local gdata = getGlobalData()
	local now_t = System.getNowTime()
	return (gdata.opentime or 0) <= now_t and now_t < (gdata.endtime or 0)
end

--下发匹配消息到客户端
local function sendWujiMatch(actor)
	local gdata = getGlobalData()
	local npack = LDataPack.allocPacket(actor,  Protocol.CMD_WuJi, Protocol.sWuJi_SendWuJiMatch)
	LDataPack.writeInt(npack, gdata.matchAid and gdata.matchAid[LActor.getActorId(actor)] or 0)
	LDataPack.flush(npack)
end

--前往跨服匹配
local function WuJiMatch(actor, isdon)
	print(LActor.getActorId(actor).." wujisystem.WuJiMatch")
	--判断活动是否进行中
	if not isOpen() then
		print(LActor.getActorId(actor).." wujisystem.WuJiMatch is not open")
		return
	end
	local aid = LActor.getActorId(actor)
	--获取玩家动态变量
	local gdata = getGlobalData()
	if gdata.matchAid and gdata.matchAid[aid] then
		print(aid.." wujisystem.WuJiMatch is on match")
		return
	end
	if gdata.playerInfo and gdata.playerInfo[aid] then
		print(aid.." wujisystem.WuJiMatch is can enter fuben")
		return
	end
	--判断次数
	local cvar = getCrossStaticData(actor)
	if cvar.CanJoinNum <= 0 then
		print(aid.." wujisystem.WuJiMatch not have join num")
		return
	end
	local basic_data = LActor.getActorData(actor)
	--发送消息包到跨服请求匹配
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCWujiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCWujiCmd_ToMatch)
	LDataPack.writeInt(pack, basic_data.actor_id) --玩家ID
	LDataPack.writeString(pack, LActor.getName(actor))
	LDataPack.writeInt(pack, basic_data.zhuansheng_lv)--转生等级
	LDataPack.writeChar(pack, isdon) --是否接受扩张匹配
	LDataPack.writeInt64(pack, basic_data.total_power)--战斗力
	System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsMainBattleSrv))
	--设置正在匹配中
	if not gdata.matchAid then gdata.matchAid = {} end
	gdata.matchAid[aid] = System.getNowTime()
	sendWujiMatch(actor)
end

--下发取消匹配消息到客户端
local function sendCancelWujiMatch(actor)
	local npack = LDataPack.allocPacket(actor,  Protocol.CMD_WuJi, Protocol.sWuJi_SendCancelWuJiMatch)
	LDataPack.flush(npack)
end

--前往跨服请求取消匹配
local function CancelWuJiMatch(actor)
	print(LActor.getActorId(actor).." wujisystem.CancelWuJiMatch")
	local aid = LActor.getActorId(actor)
	--获取玩家动态变量
	local gdata = getGlobalData()
	if not gdata.matchAid or not gdata.matchAid[aid] then
		print(aid.." wujisystem.CancelWuJiMatch is not on match")
		return
	end
	gdata.matchAid[aid] = nil
	--发送消息包到跨服请求取消匹配
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCWujiCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCWujiCmd_ToCancelMatch)
	LDataPack.writeInt(pack, LActor.getActorId(actor)) --玩家ID
	System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsMainBattleSrv))
	sendCancelWujiMatch(actor)
end

--请求无极战场匹配
local function onReqWuJiMatch( actor, packet )
	local isdon = LDataPack.readByte(packet) or 0
	WuJiMatch(actor, isdon)
end

--请求取消匹配无极战场
local function onReqCancelWuJiMatch( actor, packet )
	CancelWuJiMatch(actor)
end

--下发个人基本数据
local function sendBaseInfoData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_WuJi, Protocol.sWuJi_SendBaseInfo)
	if not npack then return end
	local cvar = getCrossStaticData(actor)
	local gdata = getGlobalData()
	local aid = LActor.getActorId(actor)
	LDataPack.writeInt(npack, cvar.CanJoinNum or 0)
	LDataPack.writeChar(npack, gdata.playerInfo and gdata.playerInfo[aid] and 1 or 0)
	LDataPack.flush(npack)
end

--下发活动状态变化数据
local function sendOpenStatusData(actor)
	local npack = nil
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_WuJi, Protocol.sWuJi_SendStatusInfo)
	else
		npack = LDataPack.allocBroadcastPacket(Protocol.CMD_WuJi, Protocol.sWuJi_SendStatusInfo)
	end
	if not npack then return end
	local gdata = getGlobalData()
	LDataPack.writeChar(npack, isOpen() and 1 or 0)
	LDataPack.writeInt(npack, gdata.openpertime or 0)
	LDataPack.writeInt(npack, gdata.opentime or 0)
	LDataPack.writeInt(npack, gdata.endtime or 0)
	if actor then
		LDataPack.flush(npack)
	else
		System.broadcastData(npack)
	end	
end

--活动开始前的预告通知(来自跨服)
local function onWuJiStartPer(sId, sType, dp)
	if not checkCanOpen() then return end
	print("wujisystem.onWuJiStartPer")
	local openpertime = LDataPack.readInt(dp)
	--获取全局变量
	local gdata = getGlobalData()
	gdata.openpertime = openpertime
	gdata.opentime = nil
	gdata.endtime = nil
	--发公告
	noticemanager.broadCastNotice(WujiBaseConfig.heraldNotice)
	--广播活动状态
	sendOpenStatusData()
end

--活动开始消息(来自跨服)
local function onWuJiStart(sId, sType, dp)
	if not checkCanOpen() then return end
	print("wujisystem.onWuJiStart")
	local opentime = LDataPack.readInt(dp)
	local endtime = LDataPack.readInt(dp)
	--获取全局变量
	local gdata = getGlobalData()
	gdata.opentime = opentime
	gdata.endtime = endtime
	--发公告
	noticemanager.broadCastNotice(WujiBaseConfig.startNotice)
	--广播活动状态
	sendOpenStatusData()
end

--活动结束消息(来自跨服)
local function onWuJiStop(sId, sType, dp)
	if not checkCanOpen() then return end
	--获取全局变量
	local gdata = getGlobalData()
	gdata.endtime = System.getNowTime()
	--给正在匹配中的玩家发消息取消匹配
	for aid,_ in pairs(gdata.matchAid or {}) do
		local actor = LActor.getActorById(aid)
		if actor then
			sendCancelWujiMatch(actor)
		end
	end
	--清除匹配中的所有玩家
	gdata.matchAid = nil
	gdata.playerInfo = nil
	--发公告
	noticemanager.broadCastNotice(WujiBaseConfig.closeNotice)
	--广播活动状态
	sendOpenStatusData()
end

--把玩家传送到跨服
local function transportActorToOtherServer( actor, pinfo )
	--pinfo = {fbhdl=fbhdl, camp=camp, idx=idx}
	--获取坐标
	local posCfg = nil
	if pinfo.camp == WujiCamp.CampA then
		posCfg = WujiBaseConfig.birthPointA
	else
		posCfg = WujiBaseConfig.birthPointB
	end
	--把玩家传到副本里面
	LActor.loginOtherSrv(actor, csbase.GetBattleSvrId(bsMainBattleSrv), pinfo.fbhdl, 0, posCfg[pinfo.idx].x, posCfg[pinfo.idx].y)
end

--玩家匹配成功(来自跨服)
local function onMatchSuccess(sId, sType, dp)
	local aid = LDataPack.readInt(dp) --玩家ID
	local fbhdl = LDataPack.readUInt(dp) --副本handle
	local camp = LDataPack.readInt(dp) --阵营
	local idx = LDataPack.readInt(dp) --阵营里排位
	local gdata = getGlobalData()
	if not gdata.playerInfo then gdata.playerInfo = {} end
	gdata.playerInfo[aid] = {fbhdl=fbhdl, camp=camp, idx=idx} --记录副本hdl数据,预留再次进入的坑
	--查找这个玩家
	local actor = LActor.getActorById(aid)
	if not actor then --不在线了,就算了吧
		print(aid.." wujisystem.onMatchSuccess is not actor")
		return
	end
	--直接去跨服
	transportActorToOtherServer(actor, gdata.playerInfo[aid])
	if gdata.matchAid then
		gdata.matchAid[aid] = nil
	end
end

--副本结束的时候
local function onFuBenEnd(sId, sType, dp)
	print("wujisystem.onFuBenEnd")
	local gdata = getGlobalData()
	if not gdata.playerInfo then return end
	local count = LDataPack.readInt(dp)
	for i = 1,count do
		local aid = LDataPack.readInt(dp)
		print("wujisystem.onFuBenEnd aid:"..aid)
		gdata.playerInfo[aid] = nil
	end
end

--玩家下线处理
local function onLogout(actor)
	local gdata = getGlobalData()
	if gdata.matchAid then
		local aid = LActor.getActorId(actor)
		if gdata.matchAid[aid] then
			CancelWuJiMatch(actor) --取消匹配
			gdata.matchAid[aid] = nil
		end
	end
end

--新的一天到来
local function onNewDay(actor, islogin)
	local cvar = getCrossStaticData(actor)
	cvar.CanJoinNum = cvar.CanJoinNum + WujiBaseConfig.dayAddRwTimes
	if cvar.CanJoinNum > WujiBaseConfig.maxRwTimes then
		cvar.CanJoinNum = WujiBaseConfig.maxRwTimes
	end
	if not islogin then
		sendBaseInfoData(actor)
		if isOpen() then
			sendOpenStatusData(actor)
		end
	end
end

--在登陆的时候
local function onLogin(actor)
	sendBaseInfoData(actor)
	if isOpen() then
		sendOpenStatusData(actor)
	end
end

--请求进入副本
local function onReqEnterFuBen(actor, packet)
	local aid = LActor.getActorId(actor) --玩家ID
	local gdata = getGlobalData()
	if not gdata.playerInfo then
		print(aid.." wujisystem.onReqEnterFuBen is not have fuben")
		return
	end
	--获取保存的信息
	local pinfo = gdata.playerInfo[aid]
	if not pinfo then
		print(aid.." wujisystem.onReqEnterFuBen is not have fuben")
		return
	end
	--去跨服
	transportActorToOtherServer(actor, pinfo)
end

--启动初始化
local function initGlobalData()
	if not System.isCommSrv() then return end
	--玩家事件处理
	actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeUserLogout, onLogout)
    --本服消息处理
    netmsgdispatcher.reg(Protocol.CMD_WuJi, Protocol.cWuJi_ReqWuJiMatch, onReqWuJiMatch) --请求匹配
    netmsgdispatcher.reg(Protocol.CMD_WuJi, Protocol.cWuJi_ReqCancelWuJiMatch, onReqCancelWuJiMatch) --请求取消匹配
    netmsgdispatcher.reg(Protocol.CMD_WuJi, Protocol.cWuji_ReqEnterFuBen, onReqEnterFuBen)
    --跨服消息处理(跨服服来的消息)
    csmsgdispatcher.Reg(CrossSrvCmd.SCWujiCmd, CrossSrvSubCmd.SCWujiCmd_StartPer, onWuJiStartPer)
    csmsgdispatcher.Reg(CrossSrvCmd.SCWujiCmd, CrossSrvSubCmd.SCWujiCmd_Start, onWuJiStart)
	csmsgdispatcher.Reg(CrossSrvCmd.SCWujiCmd, CrossSrvSubCmd.SCWujiCmd_Stop, onWuJiStop)
	csmsgdispatcher.Reg(CrossSrvCmd.SCWujiCmd, CrossSrvSubCmd.SCWujiCmd_MatchSuccess, onMatchSuccess)
	csmsgdispatcher.Reg(CrossSrvCmd.SCWujiCmd, CrossSrvSubCmd.SCWujiCmd_FuBenEnd, onFuBenEnd)
end

table.insert(InitFnTable, initGlobalData)

--Gm命令处理: wuji
function gmhandle(actor, args)
	local cmd = args[1]
	if cmd == "match" then
		WuJiMatch(actor, tonumber(args[2]))
	elseif cmd == "test" then
		LActor.loginOtherSrv(actor, csbase.GetBattleSvrId(bsMainBattleSrv), 0, 0, 0, 0)
	end
	return true
end
