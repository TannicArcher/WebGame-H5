-- 跨服战的服务器初始化
   --#include "data\config\crossserver\crossserverconf.lua" once

module("csbase", package.seeall)

MianSrvHash = {}
AllSrvHash = {}
CommSrvList = CommSrvList or {}  --[id]=开服时间
hasCross = false

function GetMainBattleSvrId()
 	local sid = System.getServerId()
 	return MianSrvHash[sid] or 0
end

function GetBattleSvrId(bType)
	local sid = System.getServerId()
	local tbl = AllSrvHash[bType] or {}
	return tbl[sid] or 0
end

function SetBattleSvrId(bType, battleId)
	local sid = System.getServerId()
	if AllSrvHash[bType] == nil then
		AllSrvHash[bType] = {}
	end
	AllSrvHash[bType][sid] = battleId
end

function IsCommonSrv( srvid, commSrvList )
	for i,conf in ipairs(commSrvList) do
		if srvid >= conf.startid and srvid <= conf.endid then
			return true
		end
	end
	return false
end

--保存连接游戏服id
function setCommonSrvList(commSrvList)
	for i,conf in ipairs(commSrvList) do
		for i=conf.startid, conf.endid do CommSrvList[i]=0 end
	end
end

local function isAllConnected()
	for sid,otime in pairs(CommSrvList) do
		if otime == 0 then return false end
	end
	return true
end

--保存连接游戏服开服时间
function setCommonSrvOpenDay(sid, time)
	if not CommSrvList[sid] then print("csbase.setCommonSrvOpenDay: sid not included, id:"..sid) return end
	CommSrvList[sid] = time
	if isAllConnected() then
		OnCrossSrvAllConnected()
	end
end

--返回是否跨服
function isCross()
	return hasCross
end

--检测是否在配置id里
function checkCommonSrvExist(sid)
	return CommSrvList[sid]
end

function getCommonSrvList()
	return CommSrvList
end

--获取服务器id
function getCommonSrvIdList()
	local list = {}
	for id, _ in pairs(CommSrvList) do
		table.insert(list, id)
	end

	table.sort(list)
	return list
end

-- 加载跨服配置设置服务器flag
function loadCrossConfigPre()
	print("loadCrossConfigPre start")
	local sid = System.getServerId()

	for i=1, #crossServer do
		local conf = crossServer[i]
		-- 看看是战斗服还是普通服
		if IsCommonSrv(sid, conf.commonSrvList) then
			System.setBattleSrvFlag(bsCommSrv)
			-- 连接所有的战斗服
			for j=1,#conf.battleInfo do
				local bconf = conf.battleInfo[j]
				if bconf.isMainSrv then
					MianSrvHash[sid] = bconf.srvid
				end
				SetBattleSvrId(bconf.bType, bconf.srvid)
			end
			hasCross = true
		else
			local mainSrvInfo = nil
			local mySrvInfo = nil
			for j=1, #conf.battleInfo do
				local info = conf.battleInfo[j]

				if sid == info.srvid then
					mySrvInfo = info
					System.setBattleSrvFlag(info.bType)
				end
			end
		end
	end


	print("loadCrossConfigPre finish, serverType : "..System.getBattleSrvFlag())
end

-- 加载跨服配置
function loadCrossConfig()
	print("loadCrossConfig start")
	local sid = System.getServerId()

	for i=1, #crossServer do
		local conf = crossServer[i]
		-- 看看是战斗服还是普通服
		if IsCommonSrv(sid, conf.commonSrvList) then
			print("loadCrossConfig is Common server")
			System.setBattleSrvFlag(bsCommSrv)
			-- 连接所有的战斗服
			for j=1,#conf.battleInfo do
				local bconf = conf.battleInfo[j]
				System.startOneGameClient(bconf.ip, bconf.port, bconf.srvid, 0)
				print(string.format("startOneGameClient : ip = %s, port = %d, serverId = %d", bconf.ip, bconf.port, bconf.srvid))

				if bconf.isMainSrv then
					MianSrvHash[sid] = bconf.srvid
				end
				SetBattleSvrId(bconf.bType, bconf.srvid)
			end
			hasCross = true
		else
			print("loadCrossConfig not is Common server")
			local mainSrvInfo = nil
			local mySrvInfo = nil
			for j=1, #conf.battleInfo do
				local info = conf.battleInfo[j]

				-- if info.isMainSrv then
				-- 	mainSrvInfo = info
				-- end

				if sid == info.srvid then
					mySrvInfo = info
					System.startGameConnSrv("0.0.0.0", info.port)
					print(string.format("loadCrossConfig startGameConnSrv : port = %d", info.port))
					System.setBattleSrvFlag(info.bType)

					setCommonSrvList(conf.commonSrvList)
				end

			end

			--如果在跨服配置里才处理
			-- if mySrvInfo then
			-- 	--是跨服服务器则创建GameConn接受其他服的连接
			-- 	System.startGameConnSrv("0.0.0.0", mySrvInfo.port)
			-- 	print(string.format("################startGameConnSrv : port = %d", mySrvInfo.port))

			-- 	-- System.setBattleSrvFlag(bsMainBattleSrv)
			-- 	-- if mainSrvInfo.srvid == sid then
			-- 	-- 	System.setBattleSrvFlag(bsMainBattleSrv)
			-- 	-- else
			-- 	-- 	System.setBattleSrvFlag(bsBattleSrv)

			-- 	-- 	--副战斗服要创建连接到主战斗服(我们现在没有这个的需救)
			-- 	-- 	-- System.startOneGameClient(mainSrvInfo.ip, mainSrvInfo.port, mainSrvInfo.srvid)
			-- 	-- 	-- print(string.format("startOneGameClient : ip = %s, port = %d, serverId = %d", mainSrvInfo.ip, mainSrvInfo.port, mainSrvInfo.srvid))
			-- 	-- end
			-- end
		end
	end


	print("loadCrossConfig finish, serverType : "..System.getBattleSrvFlag())
end

RegConnectedT = {}
RegAllConnectedT = {}
RegDisconnectedT = {}
--注册服务器连接建立事件
function RegConnected( func )
	for i,v in ipairs(RegConnectedT) do
		if v == func then
			print("csbase.RegConnected the func is already reg")
			return
		end
	end

	table.insert(RegConnectedT, func)
end

function RegAllConnected(func)
	for i,v in ipairs(RegAllConnectedT) do
		if v == func then
			print("csbase.RegAllConnected the func is already reg")
			return
		end
	end

	table.insert(RegAllConnectedT, func)
end

function RegDisconnect(func)
	for i, v in ipairs(RegDisconnectedT) do
		if v == func then
			print("csbase.RegDisconnect the func is already reg")
			return
		end
	end

	table.insert(RegDisconnectedT, func)
end

--连接成功后触发
function OnCrossSrvConnected(sId, sType)

	OnConnected(sId, sType)
	for i,func in ipairs(RegConnectedT) do
		func(sId, sType)
	end
end

function OnCrossSrvAllConnected()
	for i,func in ipairs(RegAllConnectedT) do
		func(CommSrvList)
	end
end

function OnCrossWarSrvDisConnect(sId)
	for i,func in ipairs(RegDisconnectedT) do
		func(sId)
	end
end

function cw_sendkey(sysarg, sid, sceneid, x, y)
	sid = tonumber(sid)
	if sceneid == nil then
		sceneid = 11
	else
		sceneid = tonumber(sceneid)
	end

	if x == nil then x = 0 else x = tonumber(x) end
	if y == nil then y = 0 else y = tonumber(y) end
	print("loginOtherSrv:cw_sendkey,"..LActor.getActorId(sysarg))

	local var = LActor.getStaticVar(sysarg)
	var.crosswar_ticketTime = System.getCurrMiniTime() + 10

	LActor.loginOtherSrv(sysarg, sid,
		0, sceneid, x, y)
end



-- 发送路由数据
function sendRouteData(srvId, dstSrv, routeData)
	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCrossNetCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCrossNetCmd_Route)
	LDataPack.writeInt(pack, srvId)
	-- LDataPack.writeInt(pack, System.getServerPfId())
	LDataPack.writeByte(pack, routeData.count)
	for i = 1, routeData.count do
		LDataPack.writeString(pack, routeData[i].host)
		LDataPack.writeInt(pack, routeData[i].port)
	end
	System.sendPacketToAllGameClient(pack, dstSrv)
	print("sendRouteData srvId:"..srvId..", dstSrv:"..dstSrv)
end

-- 收到路由数据
function recvRouteData(sId, sType, pack)
	local srvId = DataPack.readInt(pack)
	-- local pfId = DataPack.readInt(pack)
	-- if pfId ~= System.getServerPfId() then 		--避免收到其他平台的数据
	-- 	print("recvRouteData error pfId, srvId:"..srvId..", pfId:"..pfId)
	-- 	return
	-- end
	local count = DataPack.readByte(pack)
	local selfRoute = {}
	for i = 1, count do
		local host = DataPack.readString(pack)
		local port = DataPack.readInt(pack)
		table.insert(selfRoute, {host, port})
	end

	print("recvRouteData srvId:"..srvId)
	table.print(selfRoute)

	System.resetSingleGameRoute(srvId)
	for i, tb in ipairs(selfRoute) do
		System.geAddRoutes(srvId, tb[1] or "", tb[2])
	end
end


function OnConnected(serverId, serverType)
	print("csbase.OnConnected to "..serverId..", serverType:"..serverType)

	local sdvar = System.getDyanmicVar()
	if sdvar == nil then return end

	if sdvar.SelfRoute then 	--如果有路由数据，就发送过去
		local srvId = System.getServerId()
		sendRouteData(srvId, serverId, sdvar.SelfRoute)
	else 						--没有，就记录连接的服务器，加载完路由数据后再发过去
		if sdvar.ConnectSrv == nil then
			sdvar.ConnectSrv = {}
			sdvar.ConnectSrv.count = 0
		end
		for i = 1, sdvar.ConnectSrv.count do
			if serverId == sdvar.ConnectSrv[i] then
				return
			end
		end

		local count = sdvar.ConnectSrv.count + 1
		sdvar.ConnectSrv.count = count
		sdvar.ConnectSrv[count] = serverId
		print("save connect server:"..serverId)
	end
end

function backToNormalServer(actor)
	-- print("loginOtherSrv: backToNormalServer," .. LActor.getActorId(actor))
	print(LActor.getActorId(actor).." csbase.backToNormalServer")
	LActor.loginOtherSrv(actor, LActor.getServerId(actor), 0, 0, 0, 0, "csbase.backToNormalServer")
end

_G.onCrossSrvConnected = OnCrossSrvConnected

--设置是否跨服的flag要趁早，其他InitFnTable会访问到
--InitFnTable是无顺序的,还是存在是否跨服的判断无效,暂时先这样
table.insert(InitFnTable, loadCrossConfigPre)
--启动完成才监听
engineevent.regGameStartEvent(loadCrossConfig)


csmsgdispatcher.Reg(CrossSrvCmd.SCrossNetCmd, CrossSrvSubCmd.SCrossNetCmd_Route, recvRouteData)
