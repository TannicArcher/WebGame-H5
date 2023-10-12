module("pactivitysystem", package.seeall) -- 个人活动

--[[
	数据：pactivityData
	[id] = {
		startTime 开始时间
		isExpired 过期状态
		data={}
	}
--]]

--处理函数列表
local writeRecordFuncs = {}
local getRewardFuncs = {}
local getRewardTimeOut = {}
local initFuncs = {}
local confList = {}

-- 注册
-- 初始化
function regInitFunc( type, cfg )
	initFuncs[type] = cfg
end

-- 配置
function regConf( type, cfg )
	confList[type] = cfg
end

-- 请求奖励
function regGetRewardFunc( type, fn )
	getRewardFuncs[type] = fn
end

-- 请求过期奖励
function regTimeOut( type, fn )
	getRewardTimeOut[type] = fn
end

-- 回发数据
function regWriteRecordFunc( type, fn )
	writeRecordFuncs[type] = fn
end

-- 获取静态数据
function getStaticVar( actor )
	local var = LActor.getStaticVar(actor)
	if var.pactivityData == nil then
		var.pactivityData = {}
	end
	return var.pactivityData
end

-- 初始化数据
local function initData( pactivityData, id )
	if pactivityData[id] == nil then
		pactivityData[id] = {}
	end
	if pactivityData[id].data == nil then
		pactivityData[id].data = {}
	end
	return pactivityData[id].data
end

-- 获取数据
function getSubVar( actor, id )
	local var = getStaticVar(actor)
	return initData(var, id)
end

-- 获取活动起始时间
function getBeginTime( actor, id )
	local var = getStaticVar(actor)
	return (var[id] and var[id].startTime) or 0
end

-- 获取结束时间
function getEndTime( actor, id )
	-- local var = getStaticVar(actor)
	-- return (var[id] and var[id].endTime) or 0
	local begTime = getBeginTime(actor, id)
	return (begTime <= 0 and 0) or (begTime + PActivityConfig[id].duration * 3600)
end

-- 活动是否结束
function isPActivityEnd( actor, id )
	local endTime = getEndTime(actor, id)
	local now = System.getNowTime()
	return endTime <= now
end

-- 活动是否开启过
function isPActivityOpened( actor, id )
	local var = getStaticVar(actor)
	return var[id] and (var[id].startTime or var[id].isExpired)
end

-- 检测是否满足开启活动条件,满足条件返回真值
local function checkOpen( actor, id, cfg, level, zsLevel )
	-- 已经开启或开启过，不再开启
	if isPActivityOpened(actor, id) then
		-- print("pactivitysystem.checkOpen hasExisted,actorid:" .. LActor.getActorId(actor) .. ",id:" .. id)
		return false
	end
	--开服x天前，活动不开启
	local openDay = System.getOpenServerDay() + 1
	if cfg.sdate and openDay < cfg.sdate then
		print("pactivitysystem.checkOpen openDay fail,actorid:"..LActor.getActorId(actor)..",openDay:"..openDay..",cfg.sdate:"..cfg.sdate..",id:"..id)
		return false
	end
	-- 等级判断, 打开类型为1时,达到或超过这个等级的，自动开启
	if (cfg.openType or 0) == 1 then
		-- 配置了等级要求
		if cfg.lv and level and level < cfg.lv then
			print("pactivitysystem.checkOpen level fail,openType is 1,actorid:" .. LActor.getActorId(actor) .. ",level:" .. level .. ",cfg.lv:" .. cfg.lv .. ",id:" .. id)
			return false
		end
		-- 配置了转生等级
		if cfg.zslv and zsLevel and zsLevel < cfg.zslv then
			print("pactivitysystem.checkOpen zsLevel fail,openType is 1,actorid:" .. LActor.getActorId(actor) .. ",zslevel:" .. zsLevel .. ",cfg.zslv:" .. cfg.zslv .. ",id:" .. id)
			return false
		end
	else
		-- 配置了等级要求
		if cfg.lv and level and level ~= cfg.lv then
			print("pactivitysystem.checkOpen level fail,openType is 0,actorid:" .. LActor.getActorId(actor) .. ",level:" .. level .. ",cfg.lv:" .. cfg.lv .. ",id:" .. id)
			return false
		end
		-- 配置了转生等级
		if cfg.zslv and zsLevel and zsLevel ~= cfg.zslv then
			print("pactivitysystem.checkOpen zsLevel fail,openType is 0,actorid:" .. LActor.getActorId(actor) .. ",level:" .. zsLevel .. ",cfg.zslv:" .. cfg.zslv .. ",id:" .. id)
			return false
		end
	end
	return true
end

-- 到期处理
local function handleTimeOut( actor, id )
	local var = getStaticVar(actor)
	if var[id] and (not var[id].isExpired) then
		-- 类型处理
		local cfg = PActivityConfig[id]
		if getRewardTimeOut[cfg.activityType] then
			local record = getSubVar(actor, id)
			getRewardTimeOut[cfg.activityType](id, confList[cfg.activityType], actor, record)			
		end
		var[id].isExpired = true
		var[id].startTime = nil
	end
end


-- 发送单个活动信息
function sendActivityData( actor, id )
	local activity = PActivityConfig[id]
	if not activity then 
		print("pactivitysystem.sendActivityData: has not activity["..id.."]")
		return 
	end
	-- local var = getStaticVar(actor)
	--发包给客户端
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PActivity,  Protocol.sPActivityCmd_SendActivityData)
    if npack == nil then 
    	print("pactivitysystem.sendActivityData allocPacket fail,actorid:" .. LActor.getActorId(actor) .. ",id:" .. id)
    	return 
    end
	LDataPack.writeInt(npack, id)
	-- LDataPack.writeInt(npack, var[id] and var[id].startTime or 0)
	-- LDataPack.writeInt(npack, var[id] and var[id].endTime or 0)
	LDataPack.writeInt(npack, getBeginTime(actor, id))
	LDataPack.writeInt(npack, getEndTime(actor, id))

	LDataPack.writeShort(npack, activity.activityType)
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeInt(npack, 0)  -- 长度
	if writeRecordFuncs[activity.activityType] then
		local config = confList[activity.activityType]
		local record = getSubVar(actor, id)
		writeRecordFuncs[activity.activityType](npack, record, config and config[id], id, actor)
	end
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeInt(npack, pos2 - pos - 4)
	LDataPack.setPosition(npack, pos2)
	LDataPack.flush(npack)
end

-- 定时器
local function onTimer(actor, id)
	handleTimeOut(actor, id)
end

-- 开启活动
local function openActivity( actor, id, cfg )
	if (cfg.duration or 0) <= 0 then
		print("pactivitysystem.openActivity cfg.duration fail,duration:" .. (cfg.duration or 0) .. ",actorid:" .. LActor.getActorId(actor) .. ",id:" .. id)
		return
	end
	-- 已经开启过，退出
	if isPActivityOpened(actor, id) then
		print("pactivitysystem.openActivity has opened,actorid:" .. LActor.getActorId(actor) .. ",id:" .. id)
		return
	end
	-- 时长，秒
	local duration = cfg.duration * 60 * 60
	local now = System.getNowTime()
	-- 初始化数据
	getSubVar(actor, id)
	local var = getStaticVar(actor)
	var[id].startTime = now
	-- var[id].endTime = now + duration
	-- var[id].isOpened = true
	--注册一个过期时间的定时器	
	LActor.postScriptEventLite(actor, duration * 1000, onTimer, id)
	-- 向客户端发送消息
	sendActivityData(actor, id)
	print("pactivitysystem.openActivity actor:" .. LActor.getActorId(actor) .. ",id:" .. id)
end

-- 等级升级,注意可能等级会退步
local function onLevelUp( actor, level )
	local zsLevel = LActor.getZhuanShengLevel(actor)
	for k, v in pairs(PActivityConfig) do
		if checkOpen(actor, k, v, level, zsLevel) then
			-- 开启活动
			openActivity(actor, k, v)
		end
	end
end

-- 转生等级升级
local function onZsLevelUp( actor, zsLevel )
	local level = LActor.getLevel(actor)
	for k, v in pairs(PActivityConfig) do
		if checkOpen(actor, k, v, level, zsLevel) then
			-- 开启活动
			openActivity(actor, k, v)
		end
	end
end

-- 加载配置
local function loadConfig(actor, nowTime)
	local actorid = LActor.getActorId(actor)
    local activities = {}
    -- local actTimeOut = {}
    local openAct = {}
    -- 检测活动列表中的活动
    for id, conf in pairs(PActivityConfig) do
    	local subType = conf.activityType
		local endTime = getEndTime(actor, id)
		if not isPActivityOpened(actor, id) then
			-- 未开启过
			activities[id] = conf
		elseif isPActivityEnd(actor, id) then
			-- 被关闭
			--print("pactivityData.loadConfig is closed,actorid:" .. actorid .. ",id:" .. id .. ",subType:" .. subType)
		elseif endTime <= nowTime then
			-- 到期
			handleTimeOut(actor, id)
		else
			-- 开启状态
			openAct[id] = conf
			print("pactivityData.loadConfig is opened,actorid:" .. actorid .. ",id:" .. id .. ",subType:" .. subType)
		end
	end
    return activities, openAct
end

-- 处理未开启活动
local function handleNotOpen( actor, config )
	local var = getStaticVar(actor)	
	local level = LActor.getLevel(actor)
	local zsLevel = LActor.getZhuanShengLevel(actor)
	for id, cfg in pairs(config) do
		if checkOpen(actor, id, cfg, level, zsLevel) then
			openActivity(actor, id, cfg)
		end
	end
end

-- 发送已开启的活动信息
local function writeRecord( actor, config )
	local var = getStaticVar(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PActivity,  Protocol.sPActivityCmd_InitActivityData)
    if npack == nil then 
    	print("pactivitysystem.writeRecord LDataPack.allocPacket fail")
    	return 
    end
    local npos = LDataPack.getPosition(npack)
	local ncount = 0
    LDataPack.writeShort(npack, ncount)
    for id, cfg in pairs(config) do
    	local record = getSubVar(actor, id)
    	local typeConfig = confList[cfg.activityType]
    	ncount = ncount + 1
		LDataPack.writeInt(npack, id)
		LDataPack.writeInt(npack, getBeginTime(actor, id))
		LDataPack.writeInt(npack, getEndTime(actor, id))
		LDataPack.writeShort(npack, cfg.activityType)
		local pos = LDataPack.getPosition(npack)
		LDataPack.writeInt(npack, 0)  -- 长度
		if writeRecordFuncs[cfg.activityType] then
    		writeRecordFuncs[cfg.activityType](npack, record, typeConfig and typeConfig[id], id, actor)
    	end
    	local pos2 = LDataPack.getPosition(npack)

		LDataPack.setPosition(npack, pos)
		LDataPack.writeInt(npack, pos2 - pos - 4)
		LDataPack.setPosition(npack, pos2)
    end
    local npos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, npos)
	LDataPack.writeShort(npack, ncount)
	LDataPack.setPosition(npack, npos2)
	
    LDataPack.flush(npack)
end

-- 打开已开启活动
local function openExistActivity( actor, config )
	
	for id, cfg in pairs(config) do
		-- 时长，秒
		local now = System.getNowTime()
		local endTime = getEndTime(actor, id)
		local duration = endTime - now
		if duration <= 0 then
			duration = 1
		end

		--注册一个过期时间的定时器	
		LActor.postScriptEventLite(actor, duration * 1000, onTimer, id)
		print("pactivitysystem.openExistActivity actor:" .. LActor.getActorId(actor) .. ",id:" .. id .. ",endTime:" ..  endTime)
	end
	
end

-- 处理已开启的活动
local function handleOpened( actor, config )
	if next(config) ~= nil then
		openExistActivity(actor, config)
		-- 发送已经开启的活动信息
		writeRecord(actor, config)
	end
end

-- 登录
local function onLogin( actor )

	local nowTime = System.getNowTime()
	-- local act, actTimeOut, openAct = loadConfig(actor, nowTime)
	local act, openAct = loadConfig(actor, nowTime)
	-- 处理已开启的活动
	handleOpened(actor, openAct)
	-- 检测未开启的活动，开启活动
	handleNotOpen(actor, act)
end

local function onGetActivityData( actor, packet )
	local id = LDataPack.readInt(packet)
	sendActivityData(actor, id)
end

-- 获取奖励
local function onGetReward( actor, packet )
	local id = LDataPack.readInt(packet)
    --活动不存在
    if PActivityConfig[id] == nil then
    	print("pactivitysystem.onGetReward activity does not exist.actorid:" .. LActor.getActorId(actor) .. ",id:" .. id)
        return
    end
    local config = PActivityConfig[id]
    if not isPActivityOpened(actor, id) then
    	-- 没有启动活动
    	print("pactivitysystem.onGetReward activity is not opened.actorid:".. LActor.getActorId(actor) .. ",id:" .. id)
    	return
    end
    local var = getStaticVar(actor)
    if var[id] and var[id].isExpired then
    	-- 活动已被关闭
    	print("pactivitysystem.onGetReward activity is closed.actorid:".. LActor.getActorId(actor) .. ",id:" .. id)
    	return
    end
    if isPActivityEnd(actor, id) then
    	-- 发送过期奖励
    	handleTimeOut(actor, id)
    	return
    end
    -- 发送奖励
    local record = getSubVar(actor, id)
    if getRewardFuncs[config.activityType] then
    	getRewardFuncs[config.activityType](id, confList[config.activityType], actor, record, packet)
    end
end


-- 启动时，检测配置，用于发现配置是否存在
local function checkConf( )
	for id, conf in pairs(PActivityConfig) do
		local subType = conf.activityType
		local typeConfig = confList[subType]
		if not typeConfig then
			print("pactivitysystem.checkConf fail,id:" .. id .. ",subType:" .. subType)
			assert(false)
		end
		if not conf.duration or conf.duration <= 0 then
			print("pactivitysystem.checkConf duration fail,id:" .. id .. ",subType:" .. subType .. ",duration:" .. (conf.duration or 0))
			assert(false)
		end
	end
end

-- 初始化类型
local function subInit( )
	for id, conf in pairs(PActivityConfig) do
		local subType = conf.activityType
		if initFuncs[subType] then
			local typeConfig = confList[subType]
			initFuncs[subType](id, typeConfig and typeConfig[id])
		end
	end
end

-- 第二天, 只判断满足开服天数的活动
local function onNewDay( actor )
	local zsLevel = LActor.getZhuanShengLevel(actor)
	local level = LActor.getLevel(actor)
	local openDay = System.getOpenServerDay() + 1

	for k, v in pairs(PActivityConfig) do
		if v.sdate and openDay >= v.sdate and checkOpen(actor, k, v, level, zsLevel) then
			-- 开启活动
			openActivity(actor, k, v)
		end
	end
end

-- 启动
local function onInit( )
	-- 登录
	actorevent.reg(aeUserLogin, onLogin)
	-- 等级升级
	actorevent.reg(aeLevel, onLevelUp)
	-- 转生升级
	actorevent.reg(aeZhuansheng, onZsLevelUp)
	-- 第二天
	actorevent.reg(aeNewDayArrive, onNewDay)

    local p = Protocol
	netmsgdispatcher.reg(p.CMD_PActivity, p.cPActivityCmd_GetActivityData, onGetActivityData)
    netmsgdispatcher.reg(p.CMD_PActivity, p.cPActivityCmd_GetRewardRequest, onGetReward)

    -- 检测配置
    checkConf()
    -- 初始化类型
    subInit()
end

table.insert(InitFnTable, onInit)

-- 测试
function eraseData( actor, id )
	local var = getStaticVar(actor)
	for id, conf in pairs(PActivityConfig) do
		var[id] = {}
		var[id].data = {}
	end
	onLogin(actor)
end

---[[
-- 测试

local gmsystem    = require("systems.gm.gmsystem")
local gm = gmsystem.gmCmdHandlers
function gm.ptestcls( actor, args )
	local id = tonumber(args[1]) or 0
	if id > 0 then
		local var = getStaticVar(actor)
		var[id] = nil
		print("xxxxxxxxx gm.ptestcls,actor:"..LActor.getActorId(actor)..",id:"..id)
	end
end
--]]
