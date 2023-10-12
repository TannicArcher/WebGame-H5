module("systems.lianfu.lianfumanager", package.seeall)
setfenv(1, systems.lianfu.lianfumanager)

local lianfuutils = require("systems.lianfu.lianfuutils")
local centerservermsg = require("utils.net.centerservermsg")
local LianfuCmdFunc = {}
local onCommomConnect = {}
local onConnectLianfu = {}
local dispatcherLianfu = {}
local commOnLineFuncTab = {}
local lianfuOnlineFuncTab = {}

--require("protocol")

--local systemId = SystemId.enCommonSystemID
--local protocol = CommonSystemProtocol.CenterSrvCmd

function baseReg(tab, proc, errStr)
	for _,func in ipairs(tab) do
		if func == proc then
			if errStr then print(errStr) end
			return
		end
	end

	table.insert(tab, proc)
end

function runFuncs(tab, ...)
	for _,func in ipairs(tab) do
		func(...)
	end
end

function loginLianfuServer(actor, fbHandle, sceneid, x, y)
	local sid = LianfuFun.getLianfuSid()
	if sid <= 0 then
		print("login lianfu server error : lianfusid <= 0")
		return
	end

	--保存一下pk模式
	local var = LActor.getSysVar(actor)
	var.lfpkMode = LActor.getPkMode(actor)

	LActor.loginOtherSrv(actor, sid, fbHandle, sceneid, x, y, "lianfumanager.loginLianfuServer")
	return true
end

function backToNormalServer(actor, fbHandle, sceneId, x, y)
	LActor.loginOtherSrv(actor, LActor.getServerId(actor), fbHandle or 0, sceneId or 0, x or 0, y or 0, "lianfumanager.backToNormalServer")
end

local function onCommomConnected( sid )
	runFuncs(onCommomConnect, sid)
	runFuncs(lianfuOnlineFuncTab)
end

local function onConnectedLianfu( ... )
	runFuncs(onConnectLianfu)
	runFuncs(commOnLineFuncTab)
end

function onLianfuServerConnect(serverid, serverType)
	--普通服连接到连服
	if System.isCommSrv() and serverType == bsLianFuSrv then
		print("common server connect lianfu")
		onConnectedLianfu()
	--连服服务器连接到普通服
	elseif System.isLianFuSrv() and serverType == bsCommSrv then
		print("lianfu server connect common")
		onCommomConnected(serverid)
	end
end

--获取玩家所在服务器再连服配置中的索引
function getConfIdx(actor)
	local sid = LActor.getServerId(actor)
	return lianfuutils.getLianfuConfIdx(sid)
end

function regCmd(lianfuCmd, func)
	LianfuCmdFunc[lianfuCmd] = func
end

--连服消息处理
function OnLianfuServerPacket(lianfuCmd, packet)
	local func = LianfuCmdFunc[lianfuCmd]
	if not func then
		print("lianfuFunc is nil : " .. lianfuCmd)
		return
	end
	func(packet)
end

function allocLianFuPacket(subId)
	local pack = LDataPack.allocExtraPacket()
	if not pack then return end

	LDataPack.writeData(pack, 1, dtInt, subId)
	return pack
end

function regOnCommonConnect( fun )
	baseReg(onCommomConnect, fun, "error regOnCommonConnect re reg.....")
end

function regOnConnectLianFu( fun )
	baseReg(onConnectLianfu, fun, "error regOnConnectLianFu re reg.....")
end

--当普通服处于连服时会触发该处注册的事件(包括刷新时)
function regCommOnLineFunc(proc)
	baseReg(commOnLineFuncTab, proc, "error commOnLineFuncTab re reg.....")
end

--当连服服务器处于连服时会触发该处注册的事件(包括刷新时)
function regLianfuOnlineFunc(proc)
	baseReg(lianfuOnlineFuncTab, proc, "error lianfuOnlineFuncTab re reg.....")
end

function onRunOnlineFunc( ... )
	--普通服连接到连服
	if System.isCommSrv() then
		runFuncs(commOnLineFuncTab)
	--连服服务器连接到普通服
	elseif System.isLianFuSrv() then
		runFuncs(lianfuOnlineFuncTab)
	end
end

-- 连服服务器触发用
-- 该方法用于连服上的网络事件
-- 接收的包参数为(actorId, packet, srvId)
function regLianFu(sysId, pId, proc)
	if not System.isBattleSrv() then return end

	if not proc then
		print(string.format("netmsgdispatcher.regLianFu is nil with %d:%d", sysId, pId))
		return
	end

	if not sysId or not pId then return end

	dispatcherLianfu[sysId] = dispatcherLianfu[sysId] or {}
	local lsysIdTab = dispatcherLianfu[sysId]

	lsysIdTab[pId] = lsysIdTab[pId] or {}
	local lPidTab = lsysIdTab[pId]

	for _,func in ipairs(lPidTab) do
		if func == proc then return end
	end

	table.insert(lPidTab, proc)
end

_G.OnLianfuServerPacket = OnLianfuServerPacket
LDataPack.allocLianFuPacket = allocLianFuPacket


