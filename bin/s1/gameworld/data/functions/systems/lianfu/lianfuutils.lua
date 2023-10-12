module("systems.lianfu.lianfuutils", package.seeall)
setfenv(1, systems.lianfu.lianfuutils)


local OnLianFuNetInited = {}

_G.LianfuServerList = _G.LianfuServerList or {}
_G.CommonServerList = _G.CommonServerList or {}

function addLianfuServerConifg(index, lianfuSid, commonSidList, hostname, port, opentime)
	local info = {}
	info.commonServerId = commonSidList
	info.mainServerConf = {}
	info.mainServerConf.sid = lianfuSid
	info.mainServerConf.ip = hostname
	info.mainServerConf.port = port
	info.opentime = opentime

	local find = false
	--如果有旧配置(暂时不支持热更新修改)
	local oldConfig = LianfuServerList[lianfuSid]
	if oldConfig then 
		find = true
		oldConfig.conf.opentime = opentime
	end

	for idx, commonSid in ipairs(commonSidList) do
		if LianfuServerList[commonSid] then 
			find = true
			LianfuServerList[commonSid].conf.opentime = opentime
		end
	end

	if find then return end

	LianfuServerList[lianfuSid] = {}
	LianfuServerList[lianfuSid].conf = info
	LianfuServerList[lianfuSid].isMain = true

	for idx, commonSid in ipairs(commonSidList) do
		LianfuServerList[commonSid] = {}
		LianfuServerList[commonSid].conf = info
		LianfuServerList[commonSid].isMain = false
		LianfuServerList[commonSid].index = idx
	end

	local myServerId = System.getServerId()
	
	if myServerId == lianfuSid or table.contains(commonSidList, myServerId) then
		--设置服务器列表(连服服务器采用设置)
		local serverConf = LianfuServerList[myServerId]
		if serverConf and serverConf.isMain then
			LianfuFun.setServerList(serverConf.conf.commonServerId)
		end

		initLianfuNet()
	end
end

local function onLianFuNetInited( ... )
	for i,v in ipairs(OnLianFuNetInited) do
		v()
	end
end

function regOnLianFuNetInited( fun )
	for i,v in ipairs(OnLianFuNetInited) do
		if v == fun then return end
	end
	table.insert(OnLianFuNetInited, fun)
end

local function onCommonNetInited( ... )
	for i,v in ipairs(CommonServerList) do
		v()
	end
end

function regOnCommonNetInited( fun )
	for i,v in ipairs(CommonServerList) do
		if v == fun then return end
	end
	table.insert(CommonServerList, fun)
end

function initLianfuNet()
	local sid = System.getServerId()

	local serverConf = LianfuServerList[sid]
	if not serverConf then
		onCommonNetInited()
		return
	end

	if not serverConf.isMain then
		-- 普通服,启动一个连接到连服服务器 
		local conf = serverConf.conf.mainServerConf
		System.startOneGameClient(conf.ip, conf.port, conf.sid, bsCommSrv)
		System.setBattleSrvFlag(bsCommSrv)
		LianfuFun.setLianfuSid(conf.sid)
		print(string.format(" start lianfu client sid %d, ip %s, port %d, main sid %d, ", sid, conf.ip, conf.port, conf.sid))
	else
		local conf = serverConf.conf.mainServerConf
		System.startGameSessionSrv("0.0.0.0", conf.port)
		System.setBattleSrvFlag(bsLianFuSrv)
		print(string.format(" start lianfu server sid %d, ip %s, port %d, main sid %d, ", sid, conf.ip, conf.port, conf.sid))
	end

	assert(serverConf.conf.opentime)
	local var = System.getDyanmicVar()
	
	var.lianfuTime = serverConf.conf.opentime


	onLianFuNetInited()

	onCommonNetInited()
end

function isOpenLianfu()
	local sid = System.getServerId()

	local serverConf = LianfuServerList[sid]
	if not serverConf then return false end
	return true
end

function getLianfuTime()
	local var = System.getDyanmicVar()
	return var.lianfuTime or 0
end

function getLianfuTimeInConf()
	local conf = getLianfuConf(System.getServerId())

	if not conf or not conf.opentime then return 0 end

	return conf.opentime
end

function getLianfuDay()
	local lianfuTime = getLianfuTime()
	if lianfuTime == 0 then return 0 end

	return System.getDayDiff(System.getNowTime(), lianfuTime) + 1
end

function getLianfuConfIdx(sid)
	local serverConf = LianfuServerList[sid]
	if not serverConf then return 0 end
	return serverConf.index or 0
end

function getLianfuConf( sid )
	local serverConf = LianfuServerList[sid]
	if not serverConf then return end

	return serverConf.conf
end

function loadLianfuConfig(id)
	local db = System.getGameEngineGlobalDbConn()
	local ret = System.dbConnect(db)
	if not ret then
		print("error, preLoadLianfuConfig fail...............")
		return
	end

	local err = System.dbQuery(db, string.format("call loadlianfuconfig(%d)", id or 0) )
	if err ~= 0 then
		print("error, loadlianfuconfig dbQuery fail...............")
		return -1
	end

	local row = System.dbCurrentRow(db)
	local count = System.dbGetRowCount(db)

	print("LoadLianfuConfig start ...")
	local dbGetRow = System.dbGetRow
	for i=1, count do
		local idx = tonumber(dbGetRow(row, 0))
		local lianfuSid = tonumber(dbGetRow(row, 1))
		local server1id = tonumber(dbGetRow(row, 2)) or 0
		local server2id = tonumber(dbGetRow(row, 3)) or 0
		local server3id = tonumber(dbGetRow(row, 4)) or 0
		local hostname = dbGetRow(row, 5)
		local port = dbGetRow(row, 6)
		local opentime = dbGetRow(row, 7)
		print(string.format("%d : lfSid = %d, commonSid = \{%d, %d, %d\}, host = %s, port = %s, opentime = %s", idx, lianfuSid, server1id, server2id, server3id, hostname, port, opentime))

		local commonList = {}
		if server1id and server1id ~= 0 then table.insert(commonList, server1id) end
		if server2id and server2id ~= 0 then table.insert(commonList, server2id) end
		if server3id and server3id ~= 0 then table.insert(commonList, server3id) end

		addLianfuServerConifg(idx, lianfuSid, commonList, hostname, port, math.floor(System.toMiniTime(opentime) / (3600 * 24)) * (3600 * 24))

		row = System.dbNextRow(db)
	end
	print("LoadLianfuConfig success ...")

	System.dbResetQuery(db)
	System.dbClose(db)

	local serverConf = LianfuServerList[System.getServerId()]
	if serverConf then
		local var = System.getDyanmicVar()
		var.lianfuTime = serverConf.conf.opentime
	end
end


_G.loadLianfuConfig = loadLianfuConfig
