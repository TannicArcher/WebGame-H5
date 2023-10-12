--Actor方法移植
--关于心跳的方法
module("systems.actorsystem.actorbeattime", package.seeall)
setfenv(1, systems.actorsystem.actorbeattime)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorfunc        = require("utils.actorfunc")
local actorevent       = require("actorevent.actorevent")
local postscripttimer  = require("base.scripttimer.postscripttimer")

require("protocol")

local sysId    = SystemId.enDefaultEntitySystemID
local protocol = defaultSystemProtocol

local miscsSystem      = SystemId.miscsSystem
local sSendOpenSrvTime = MiscsSystemProtocol.sSendOpenSrvTime

local function getBeatData(actor)
	local userData = LActor.getDyanmicVar(actor)
	if not userData then return end
	userData.beat = userData.beat or {}
	return userData.beat
end

-- * Comments: 服务器定时心跳
function sendHeartBeatPack(actor)
	local pack = LDataPack.allocPacket(actor, sysId, protocol.sHeartbeat)
	if not pack then return end
	local server_t = System.getNowTime()
	LDataPack.writeData(pack, 1,
		dtUint, server_t)
	LDataPack.flush(pack)
end

-- * Comments: 发送开服时间
function sendOpenSrvTimePack(actor)
	local pack = LDataPack.allocPacket(actor, miscsSystem, sSendOpenSrvTime)
	if not pack then return end
	local server_t = System.getOpenServerTime()
	LDataPack.writeData(pack, 1,
		dtUint, server_t)
	LDataPack.flush(pack)
end

-- * Comments: 收到心跳包
function recvBeat(actor, sendTick)
	local tickData = getBeatData(actor)
	if not tickData then return end

	local isValid    = true
	local tick       = System.getTick()
	local lastTick   = tickData.lastTick or 0
	local clientTick = tickData.clientTick or 0

	if lastTick > 0 then
		local dis = tick - lastTick
		if dis >= 120000 or dis < 50000 then
			isValid = false
		end
	end
	if clientTick > 0 then
		local dis = sendTick - clientTick
		if dis > 80000 then
			isValid = false
		end
	end
	if not isValid then
		--TODO 正式服取消掉该注释
		-- System.closeActor(actor)
	end

	tickData.lastTick   = tick
	tickData.clientTick = sendTick
end

function onRecvBeat(actor, pack)
	local sendTick = LDataPack.readUInt(pack)
	recvBeat(actor, sendTick)
end

--心跳包处理
function onLogin(actor)
	postscripttimer.postScriptEvent(actor, 0, function(...) sendHeartBeatPack(...) end, 60 * 1000, -1)
	postscripttimer.postScriptEvent(actor, 90 * 60 * 1000, function(...) loginRenew(...) end, 90 * 60 * 1000, -1)
	sendOpenSrvTimePack(actor)
end

--登陆续期(90分钟续期一次, 120分钟为过期)
function loginRenew(actor)
	SendUrl("/Login/openkeyout?", "&openid=" .. LActor.getAccountName(actor) .. "&serverid=" .. LActor.getServerId(actor))
end

actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(sysId, protocol.cHeartbeat, onRecvBeat)


