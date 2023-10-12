--无极战场活动副本管理模块(跨服服)
module("crosswujifbmgr", package.seeall)

WujiCamp = {
	CampA = 100,
	CampB = 200,
}

--[[获取全局数据
	openpertime = 预告开始时间
	opentime = 活动开始时间
	endtime = 活动结束时间
	--匹配副本房间信息维护start
	fubenActor[副本handle]={
		[阵营ID] = {玩家id,x4},
		[阵营ID] = {玩家id,x4}
	}
	actorfuben[玩家id] = 副本handle
	--匹配副本房间信息维护end
]]
globalWuJiFbMgrData = globalWuJiFbMgrData or {}
local function getGlobalData()
	return globalWuJiFbMgrData
end

--判断活动是否开启
local function isOpen()
	local gdata = getGlobalData()
	local now_t = System.getNowTime()
	return (gdata.opentime or 0) <= now_t and now_t < (gdata.endtime or 0)
end

--副本结束的时候调用的函数
function onFuBenEnd(ins)
	--重置一些数据
	local gdata = getGlobalData()
	gdata.fubenActor[ins.handle] = nil
	for aid,_ in pairs(ins.data.actorInfo) do
		gdata.actorfuben[aid] = nil
	end
end

--匹配成功后;调用这个产生战斗的房间
function CreateBattleRoom(tab1, tab2)
	local fbhdl = Fuben.createFuBen(WujiBaseConfig.fbId)
	local ins = instancesystem.getInsByHdl(fbhdl)
	if not ins then
		print("crosswujifbmgr.CreateBattleRoom error fbid:"..tostring(WujiBaseConfig.fbId))
		return nil
	end
	if not ins.data then ins.data = {} end
	local gdata = getGlobalData()
	if not gdata.fubenActor then gdata.fubenActor = {} end
	if not gdata.actorfuben then gdata.actorfuben = {} end
	ins.data.actorInfo = {}
	gdata.fubenActor[fbhdl] = {}
	--A阵营安置
	gdata.fubenActor[fbhdl][WujiCamp.CampA] = {} 
	for _,info in ipairs(tab1 or {}) do
		table.insert(gdata.fubenActor[fbhdl][WujiCamp.CampA], info.aid)
		gdata.actorfuben[info.aid] = fbhdl
		ins.data.actorInfo[info.aid] = info 
		ins.data.actorInfo[info.aid].camp = WujiCamp.CampA
	end
	--B阵营安置
	gdata.fubenActor[fbhdl][WujiCamp.CampB] = {} 
	for _,info in ipairs(tab2 or {}) do
		table.insert(gdata.fubenActor[fbhdl][WujiCamp.CampB], info.aid)
		gdata.actorfuben[info.aid] = fbhdl
		ins.data.actorInfo[info.aid] = info 
		ins.data.actorInfo[info.aid].camp = WujiCamp.CampB
	end
	ins.data.fubenActor = gdata.fubenActor[fbhdl]
	crosswujifb.onFuBenCreate(ins)
	return fbhdl
end

--活动开始预告(总控制)
local function WuJiOpenPer()
	local gdata = getGlobalData()
	gdata.openpertime = System.getNowTime()
	--发送预告消息到游戏服
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCWujiCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCWujiCmd_StartPer)
	LDataPack.writeInt(npack, gdata.openpertime)
	System.sendPacketToAllGameClient(npack, 0)
end
_G.WuJiOpenPer = WuJiOpenPer

--活动结束(总控制)
local function WuJiClose()
	if not isOpen() then 
		print("crosswujifbmgr.WuJiClose is not opened")
		return
	end
	local gdata = getGlobalData()
	gdata.endtime = System.getNowTime()
	--停止匹配池的工作
	crosswujimatch.onWuJiClose()
	--发送结束消息到游戏服
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCWujiCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCWujiCmd_Stop)
	System.sendPacketToAllGameClient(npack, 0)
	--删除事件
	if gdata.closeEid then
		LActor.cancelScriptEvent(nil, gdata.closeEid)
		gdata.closeEid = nil
	end
end

--活动开始(总控制)
local function WuJiOpen()
	if isOpen() then 
		print("crosswujifbmgr.WuJiOpen is opened")
		return
	end
	local gdata = getGlobalData()
	--注册结束事件
	gdata.closeEid = LActor.postScriptEventLite(nil, WujiBaseConfig.closeTime * 1000, WuJiClose)
	--设置开始时间和结束时间
	gdata.opentime = System.getNowTime()
	gdata.endtime = gdata.opentime + WujiBaseConfig.closeTime
	--发送开启消息到游戏服
	local npack = LDataPack.allocPacket()
	LDataPack.writeByte(npack, CrossSrvCmd.SCWujiCmd)
	LDataPack.writeByte(npack, CrossSrvSubCmd.SCWujiCmd_Start)
	LDataPack.writeInt(npack, gdata.opentime)
	LDataPack.writeInt(npack, gdata.endtime)
	System.sendPacketToAllGameClient(npack, 0)
	--匹配池开始工作
	crosswujimatch.onWuJiStart()
end
_G.WuJiOpen = WuJiOpen

--启动初始化
local function initGlobalData()
	if System.isCommSrv() then return end
	--注册定时器
	local cfg = WujiBaseConfig
	scripttimer.reg({week = cfg.open, hour = cfg.heraldTime.hour, minute = cfg.heraldTime.minute, func= "WuJiOpenPer"})
	scripttimer.reg({week = cfg.open, hour = cfg.startTime.hour, minute = cfg.startTime.minute, func= "WuJiOpen"})
	--跨服消息注册
end

table.insert(InitFnTable, initGlobalData)

function onGmHandle(args)
	local cmd = args[1]
	if cmd == "open" then
		WuJiOpenPer()
		WuJiOpen()
	elseif cmd == "close" then
		WuJiClose()
	end
end
