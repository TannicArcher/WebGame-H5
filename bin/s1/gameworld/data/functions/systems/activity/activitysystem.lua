module("activitysystem", package.seeall)

--子活动处理
require("systems.activity.subactivities")
require("systems.activity.subactivitytype1")
require("systems.activity.subactivitytype2")
require("systems.activity.subactivitytype3")
require("systems.activity.subactivitytype4")
require("systems.activity.subactivitytype5")
require("systems.activity.subactivitytype6")
require("systems.activity.subactivitytype7")
require("systems.activity.subactivitytype8")
require("systems.activity.subactivitytype9")
require("systems.activity.subactivitytype10")
require("systems.activity.subactivitytype11")
require("systems.activity.subactivitytype12")
--require("systems.activity.subactivitytype13")
--require("systems.activity.subactivitytype14")
--require("systems.activity.subactivitytype15")
--require("systems.activity.subactivitytype16")
-- require("systems.activity.subactivitytype17")
require("systems.activity.subactivitytype18")
require("systems.activity.subactivitytype19")
require("systems.activity.subactivitytype20")
require("systems.activity.subactivitytype21")
require("systems.activity.subactivitytype22")


--[[
公共数据 (临时)
globalData = {
    activities = id:{
        startTime,
        endTime,
        type,
        mark,   // 时间标记
        --others if needed
    }
    activityCount
}

全局数据(写文件保存)
getGlobalVar(id) = {
	records = {
		[id] = {
			type,
			mark,
			data = {}
		}
	}
}

个人数据
activityData = {
    records = id: {
        type,        类型    --required
        mark,   更新时间的字符串， 用于和type一起判断记录是否和配置相匹配
        data = union {
            type1: {
                rewardsRecord,    int 领取位标记 只支持32位
             }
             type2: {
                rewardsRecord   [index]: count
             }
        }
    }
}
--]]

globalData = globalData or {}

local getHeFuTime = hefutime.getHeFuDayStartTime

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then return nil end

    if var.activityData == nil then
        var.activityData = {}
        initRecordData(actor, var.activityData)
    end
    return var.activityData
end

function getDyanmicVar(id)
    local var = System.getDyanmicVar()
    if var == nil then return nil end

    if var.ADData == nil then
        var.ADData = {}
    end
    if var.ADData[id] == nil then
        var.ADData[id] = {}
    end
    return var.ADData[id]
end

local function initRecord(id, record)
    local activity = globalData.activities[id]
    if activity == nil then return end

    record.type = activity.type
    record.mark = activity.mark
    record.data = {}
end

function getSubVar(actor, id)
    local data = getStaticData(actor)
    if data.records[id] == nil then
        data.records[id] = {}
        initRecord(id, data.records[id])
    end

    return data.records[id]
end

local function initGlobalData(id,data)
	local activity = globalData.activities[id]
	if activity == nil then return end
	data.type = activity.type
	data.mark = activity.mark
	data.data = {}
end

function getGlobalVar(id)
	local var = System.getStaticVar()
	if var == nil then return nil end

	if var.activityData == nil then
		var.activityData = {}
	end
	if var.activityData.records == nil then
		var.activityData.records = {}
	end

	if var.activityData.records[id] == nil or var.activityData.records[id].type == nil then
		var.activityData.records[id] = {}
		initGlobalData(id, var.activityData.records[id])
	end
	return var.activityData.records[id].data
end

function getParamConfig(id)
	if ActivityConfig[id] == nil then return nil end
	return ActivityConfig[id].params
end

function initRecordData(actor, data)
    data.records = {}
end

local function loadTime(conf)
    if conf.timeType == 0 then
        --startTime
        local d,h,m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
        if d== nil or h == nil or m == nil then
            return 0,0,true
        end

        local st = System.getOpenServerStartDateTime()
        st = st + d*24*3600 + h*3600 + m*60

        --endTime
        d,h,m = string.match(conf.endTime, "(%d+)-(%d+):(%d+)")
        if d== nil or h == nil or m == nil then
            return 0,0,true
        end

        local et = System.getOpenServerStartDateTime()
        et = et + d*24*3600 + h*3600 + m*60

        return st, et
    elseif conf.timeType == 1 then
        --固定时间
        --startTime
        local Y,M,d,h,m = string.match(conf.startTime, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
        if Y == nil or M == nil or d == nil or h == nil or m == nil then
            return 0,0,true
        end

        local st = System.timeEncode(Y, M, d, h, m, 0)

        --endTime
        local Y,M,d,h,m = string.match(conf.endTime, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
        if Y == nil or M == nil or d == nil or h == nil or m == nil then
            return 0,0,true
        end

        local et = System.timeEncode(Y, M, d, h, m, 0)

        return st, et
    elseif conf.timeType == 2 then
        -- 合服时间
        local hefutime = getHeFuTime() or 0
        -- print("hefutime......" .. hefutime .. ", serveropentime..." .. System.getOpenServerStartDateTime() .. ", nowtime ..." .. System.getNowTime())
        if not hefutime then
            return 0,0,true
        end

        --startTime
        local d,h,m = string.match(conf.startTime, "(%d+)-(%d+):(%d+)")
        if d == nil or h == nil or m == nil then
            return 0,0,true
        end
        local st = hefutime + d*24*3600 + h*3600 + m*60

        -- endTime
        d,h,m = string.match(conf.endTime, "(%d+)-(%d+):(%d+)")
        if d== nil or h == nil or m == nil then
            return 0,0,true
        end
        local et = hefutime + d*24*3600 + h*3600 + m*60

        return st, et
    else
        return 0,0,true
    end
end

local function findId(id, idlist)
	if idlist and type(idlist) == "table" then
		for _, i in ipairs(idlist) do
			if id == i then
				return true
			end
		end
	end
	if idlist and type(idlist) == "string" then
		local ranges = utils.luaex.lua_string_split(idlist, ',')
		for _, range in ipairs(ranges) do
			local r = utils.luaex.lua_string_split(range, '-')
			if #r == 2 then
				if tonumber(r[1]) <= id and tonumber(r[2]) >= id then
					return true
				end
			elseif #r  == 1 then
				if id == tonumber(r[1]) then return true end
			else
				print("config error? can't recognise range:"..range)
				print("config:"..idlist)
			end
		end
	end
	return false
end

--检测开服时间比配置小的才开启活动
local function checkOpenTimeLt(conf)
	if not conf.openTimeLt then return true end
	local Y,M,d,h,m = string.match(conf.openTimeLt, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
	if Y == nil or M == nil or d == nil or h == nil or m == nil then
		return false
	end

	local st = System.timeEncode(Y, M, d, h, m, 0)	
	if System.getServerOpenTime() > st then
		return false
	end
	return true
end

--检测开服时间比配置大的才开启活动
local function checkOpenTimeGt(conf)
	if not conf.openTimeGt then return true end
	local Y,M,d,h,m = string.match(conf.openTimeGt, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
	if Y == nil or M == nil or d == nil or h == nil or m == nil then
		return false
	end

	local st = System.timeEncode(Y, M, d, h, m, 0)
	if System.getServerOpenTime() < st then
		return false
	end
	return true
end

--检测合服时间比配置小的才开启活动
local function checkHefuTimeLt(conf)
	if not conf.hefuTimeLt or not getHeFuTime() then return true end
	local Y,M,d,h,m = string.match(conf.hefuTimeLt, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
	if Y == nil or M == nil or d == nil or h == nil or m == nil then
		return false
	end

	local st = System.timeEncode(Y, M, d, h, m, 0)	
	if getHeFuTime() > st then
		return false
	end
	return true
end

--检测合服时间比配置大的才开启活动
local function checkHefuTimeGt(conf)
	if not conf.hefuTimeGt or not getHeFuTime() then return true end
	local Y,M,d,h,m = string.match(conf.hefuTimeGt, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
	if Y == nil or M == nil or d == nil or h == nil or m == nil then
		return false
	end

	local st = System.timeEncode(Y, M, d, h, m, 0)
	if  getHeFuTime() < st then
		return false
	end
	return true
end

--检测是否开启
local function checkCrossOpen(conf)
	if not conf.needCross then return true end
	if conf.needCross == 0 then return true end
	if csbase.hasCross then return true end
	return false
end

--检测指定服务器不开
local function checkServerIdNotOpen(conf)
	if not conf.idLimit then return true end
	if findId(System.getServerId(), conf.idLimit) then
		return false
	end
	return true
end

--检测指定服务器开
local function checkServerIdOpen(conf)
	if not conf.idOpenLimit then return true end
	if findId(System.getServerId(), conf.idOpenLimit) then
		return true
	end
	return false
end

--检测合服次数
local function checkHefuTimes(conf)
	if not conf.hfTimes then return true end
	if conf.hfTimes == hefutime.getHeFuCount() then return true end
	return false
end

local function loadConfig()
    local activities = {}
    local count = 0
    local varClear
    for id, conf in pairs(ActivityConfig) do
		if not System.isCommSrv() or 
			(checkOpenTimeLt(conf) and 
			checkOpenTimeGt(conf) and 
			checkHefuTimeLt(conf) and 
			checkHefuTimeGt(conf) and 
			checkCrossOpen(conf)) and
			checkServerIdNotOpen(conf) and
			checkServerIdOpen(conf) and
			checkHefuTimes(conf)
			then
			
			local st, et, err = loadTime(conf)
			if err then print("time err") return nil end
			local type= conf.activityType
			local typeConfig = subactivities.getConfig(type)
			if typeConfig == nil then print("type config err.."..type) return nil end
			if typeConfig[id] == nil then print("type config err.id:"..id) return nil end
			if conf.endClear == nil or conf.endClear == true then
				varClear = true
			else
				varClear = false
			end

			if et > System.getNowTime() then
				activities[id] = {
					id=id, startTime=st, endTime=et,
					type=conf.activityType,
					mark=conf.startTime..conf.endTime,
					varClear = varClear --就不应该有这破玩意
				}
				count = count + 1
			end
		end
    end

    local var = System.getStaticVar()
    if var then
	    if var.activityData == nil then
		    var.activityData = {}
	    end
	    if var.activityData.records == nil then
		    var.activityData.records = {}
	    end

	    local records = var.activityData.records
	    for id, conf in pairs(ActivityConfig) do
		    if records[id] then
				if not activities[id] then
					records[id] = nil
			    elseif records[id].type ~= activities[id].type or records[id].mark ~= activities[id].mark then
				    records[id] = nil
			    end
		    end
	    end
    end

    return activities, count
end

local function checkConfig(a1, a2)
	if not a1 or not a2 then return false end
    return a1.id == a2.id and a1.mark==a2.mark and a1.type==a2.type
end

function updateTask(actor, type, param, count)
	subactivitytype11.updateTask(actor, type, param, count)
	subactivitytype21.updateTask(actor, type, param, count)
end

-- global event
local function onStart()
    --加载配置 并广播一遍，考虑热更新
    local activities, count = loadConfig()
    if activities == nil then
        print("load activities config failed!!!")
        assert(false)
    end

    --热更新时，对比配置，如果有变化, 广播
    if globalData.activities ~= nil then
        local diffient = false
        if count ~= globalData.activityCount then
            diffient = true
        else
            for id, activity in pairs(activities) do
                if not checkConfig(activity, globalData.activities[id]) then
                    diffient = true
                    break
                end
            end
        end

        if diffient then
            --重新下发数据
        end
    end
    globalData.activities = activities
    globalData.activityCount = count
end

function activityTimeIsEnd(id)
    local aInfo = globalData.activities[id]
    if aInfo then
        local now_t = System.getNowTime()
        if now_t >= aInfo.startTime and now_t < aInfo.endTime then
            return false
        end
    end
    return true
end

function activityIsEnd(id)
    local aInfo = globalData.activities[id]
    if not aInfo then return true end

    local now_t = System.getNowTime()
    if now_t > aInfo.endTime then return true end

    return false
end

function getBeginTime(id)
	local info = globalData.activities[id]
	if info == nil then 
		return 0
	end
	return info.startTime
end

--获取活动当前是第几天
function getBeginDays(id)
	local beginTime = getBeginTime(id)
    return math.ceil((System.getNowTime() - beginTime) / (24 * 60 * 60))
end

function getEndTime(id)
	local info = globalData.activities[id]
	if info == nil then 
		return 0
	end
	return info.endTime
end

-- actor event
local function onLogin(actor)
    --检查记录有效性
    local now = System.getNowTime()
    local data = getStaticData(actor)

    --发送记
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity,  Protocol.sActivityCmd_InitActivityData)
    if npack == nil then return end
	
	local npos = LDataPack.getPosition(npack)
	local ncount = 0
    LDataPack.writeShort(npack, ncount)
    for id, activity in pairs(globalData.activities) do
	    if data.records then
			local record = data.records[id]
			if record ~= nil then
				if activity == nil or record.type ~= activity.type or
						record.mark ~= activity.mark then
					data.records[id] = nil
				elseif activity.varClear == true and (now < activity.startTime or now > activity.endTime) then
					data.records[id] = nil
				end
			end
		end
		
		if now < activity.endTime then
			ncount = ncount + 1
			LDataPack.writeInt(npack, id)
			LDataPack.writeInt(npack, activity.startTime)
			LDataPack.writeInt(npack, activity.endTime)
			LDataPack.writeShort(npack, activity.type)
			local pos = LDataPack.getPosition(npack)
			LDataPack.writeInt(npack, 0)  -- 长度

			subactivities.writeRecord(id, activity.type, npack, data.records[id], actor)
			local pos2 = LDataPack.getPosition(npack)
			
			LDataPack.setPosition(npack, pos)
			LDataPack.writeInt(npack, pos2 - pos - 4)
			LDataPack.setPosition(npack, pos2)
		else
			globalData.activities[id] = nil
		end
    end
	local npos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, npos)
	LDataPack.writeShort(npack, ncount)
	LDataPack.setPosition(npack, npos2)
	
    LDataPack.flush(npack)
    callBackSubActorLogin(actor)
end

function sendActivityData(actor, id)
	local activity = globalData.activities[id]
	if not activity then 
		print("sendActivityData: is not have globalData.activities["..id.."]")
		return 
	end
	--获取静态变量
	local data = getStaticData(actor)
	--检查记录有效性
    if data.records then
		local record = data.records[id]
		if record ~= nil then
			local now = System.getNowTime()
			if activity == nil or record.type ~= activity.type or record.mark ~= activity.mark then
				data.records[id] = nil
			elseif activity.varClear == true and (now < activity.startTime or now > activity.endTime) then
				data.records[id] = nil
			end
		end
    end	
	--发包给客户端
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity,  Protocol.sActivityCmd_SendActivityData)
    if npack == nil then return end
	LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, activity.startTime)
	LDataPack.writeInt(npack, activity.endTime)
	LDataPack.writeShort(npack, activity.type)
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeInt(npack, 0)  -- 长度
	subactivities.writeRecord(id, activity.type, npack, data.records[id], actor)
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeInt(npack, pos2 - pos - 4)
	LDataPack.setPosition(npack, pos2)
	LDataPack.flush(npack)
end

local function subInit()
    local now = System.getNowTime()
    local conf = ActivityConfig
    for k,v in pairs(globalData.activities) do
        -- if v.startTime > now or v.endTime < now then
        -- else
            --只调用在活动时间内的

            local type = conf[k].activityType
            if subactivities.getConfig(type) then
                subactivities.init(type, k,v)
            end
        -- end
    end
end

function callBackSubActorLogin(actor)
    local conf = ActivityConfig
    for k,v in pairs(globalData.activities) do

        --只调用在活动时间内的
        local type = conf[k].activityType
        if subactivities.getConfig(type) and subactivities.actorLoginFuncs[type] then
            subactivities.actorLoginFuncs[type](actor, type, k)
        end

    end
end

function getTypeActivities(subType)
    local activities = {}
    local now_t = System.getNowTime()
    for id, aInfo in pairs(globalData.activities) do
        if aInfo.type == subType and now_t >= aInfo.startTime and now_t < aInfo.endTime then
            activities[id] = aInfo
        end
    end
    return activities
end

-- on Cmd
local function onGetReward(actor, packet)
    local id = LDataPack.readInt(packet)
    --活动不存在
    if globalData.activities[id] == nil then
        return
    end
    --不在活动时间
    local now = System.getNowTime()
    if globalData.activities[id].startTime > now or globalData.activities[id].endTime < now then
        subactivities.onGetRewardTimeOut(id,actor,packet)
        return
    end

    --读取配置，获得类型
    local type = ActivityConfig[id].activityType
    if subactivities.getConfig(type) == nil then
        return
    end

    local data = getStaticData(actor)
    if data.records[id] == nil then
        data.records[id] = {}
        initRecord(id, data.records[id])
    end

    --根据类型调用特定类型处理接口
    subactivities.onGetReward(type, id, actor, data.records[id], packet)
end

local function onReqInfo(actor, packet)
	local id = LDataPack.readInt(packet)

	--活动不存在
	if globalData.activities[id] == nil then
		return
	end

	--不在活动时间
	local now = System.getNowTime()
	if globalData.activities[id].startTime > now or globalData.activities[id].endTime < now then
        subactivities.onReqInfoTimeOut(id,actor,packet)
		return
	end

	--读取配置，获得类型
	local type = ActivityConfig[id].activityType
	if subactivities.getConfig(type) == nil then
		return
	end

	local data = getStaticData(actor)
	if data.records[id] == nil then
		data.records[id] = {}
		initRecord(id, data.records[id])
	end

	--根据类型调用特定类型处理接口
	subactivities.onReqInfo(type, id, actor, data.records[id], packet)
end

--0=未开始，1=开启中，2=已结束
function getStatByTime(id)
    local aInfo = globalData.activities[id]
    statDef = commActivityStat
    if aInfo then

        local now_t = System.getNowTime()
        if now_t < aInfo.startTime then
            return statDef.casUnopened
        elseif now_t >= aInfo.endTime then
            return statDef.casEnd
        else
            return statDef.casOpen
        end
    end
    return statDef.casUnopened
end

function getActivityStaticVar(id)
    local var = System.getStaticVar()
    if var.CommActivityData == nil then
        var.CommActivityData = {}
    end
    if var.CommActivityData[id] == nil then
        var.CommActivityData[id] = {}
    end
    return var.CommActivityData[id]
end

local function onGetActivityData(actor, packet)
	local id = LDataPack.readInt(packet)
	sendActivityData(actor, id)
end

local function onCrossDataBack(sId, sType, dp)
	local id = LDataPack.readInt(dp)

	--活动不存在
	if globalData.activities[id] == nil then
		return
	end

	--不在活动时间
	local now = System.getNowTime()
	if globalData.activities[id].startTime > now or globalData.activities[id].endTime < now then
		return
	end

	--读取配置，获得类型
	local type = ActivityConfig[id].activityType
	if subactivities.getConfig(type) == nil then
		return
	end

	--根据类型调用特定类型处理接口
	subactivities.onCrossInfo(type, id, dp)
end

local function onBroadCast(sId, sType, dp)
	if System.isCommSrv() then
		onCrossDataBack(sId, sType, dp)
	else
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCActivityCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivityCmd_BroadCast)
		LDataPack.writePacket(npack, dp, false)
		System.sendPacketToAllGameClient(npack, 0)
	end
end

--启动初始化
local function init()
    actorevent.reg(aeUserLogin, onLogin)

    local p = Protocol
	netmsgdispatcher.reg(p.CMD_Activity, p.cActivityCmd_GetActivityData, onGetActivityData)
    netmsgdispatcher.reg(p.CMD_Activity, p.cActivityCmd_GetRewardRequest, onGetReward)
    netmsgdispatcher.reg(p.CMD_Activity, p.cActivityCmd_UpdateInfo, onReqInfo)
    onStart()
    subInit()

    csmsgdispatcher.Reg(CrossSrvCmd.SCActivityCmd, CrossSrvSubCmd.SCActivityCmd_BroadCast, onBroadCast) --跨服信息
end

table.insert(InitFnTable, init)

