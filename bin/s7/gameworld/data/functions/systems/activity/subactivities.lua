--活动子类型函数定义
--如果扩展太多类型,再考虑分文件
module("subactivities", package.seeall)


--处理函数列表
writeRecordFuncs = {}
getRewardFuncs = {}
getRewardTimeOut = {}
reqInfoFuncs = {}
reqInfoTimeOut = {}
initFuncs = {}
actorLoginFuncs = {}
confList = {}
crossFuncs = {}


local p = Protocol


-- 子类型初始化函数注册
--func(id, conf)
function regInitFunc(type, func)
	initFuncs[type] = func
end

-- 更新数据回包函数注册
--func(npack, record, config)
function regWriteRecordFunc(type, func)
	writeRecordFuncs[type] = func
end

-- 领取奖励回调函数注册
--func(id, typeconfig, actor, record, packet)
function regGetRewardFunc(type, func)
	getRewardFuncs[type] = func
end

-- 请求信息回调函数注册
--func(id, typeconfig, actor, record, packet)
function regReqInfoFunc(type, func)
	reqInfoFuncs[type] = func
end

-- 跨服信息回调函数注册
--func(type, id, packet)
function regReqCrossFunc(type, func)
    crossFuncs[type] = func
end

-- 注册配置?
function regConf(type, conf)
    if confList[type] ~= nil then
        assert(false)
        return
    end
    confList[type] = conf
end

-- 活动结束后领取奖励回调函数注册
function regTimeOut(type, func)
    if timeOut[type] ~= nil then
        assert(false)
        return
    end
    timeOut[type] = func
end


----------------------------------------------------
--获取类型配置
function getConfig(type)
    return confList[type]
end


function init(type, id,data)
    if initFuncs[type] then
        local conf = getConfig(type)
        initFuncs[type](id, conf and conf[id])
    end
end

--下发数据处理
function writeRecord(id, type, npack, record, actor)
    if writeRecordFuncs[type] then
        local config = getConfig(type)
        writeRecordFuncs[type](npack, record, config and config[id], id, actor)
    end
end

function onGetReward(type, id, actor, record, packet)
    if getRewardFuncs[type] then
        local config = getConfig(type)
        getRewardFuncs[type](id, config, actor, record, packet)
    end
end

function onReqInfo(type, id, actor, record, packet)
	if reqInfoFuncs[type] then
		local config = getConfig(type)
		reqInfoFuncs[type](id, config, actor, record, packet)
	end
end

function onCrossInfo(type, id, packet)
    if crossFuncs[type] then
        local config = getConfig(type)
        crossFuncs[type](id, config, packet)
    end
end

-- 策划要求活动时间过了，还要求可以领取奖励
function onGetRewardTimeOut(id,actor,packet)
    --读取配置，获得类型
    local type = ActivityConfig[id].activityType
    if getConfig(type) == nil then
        return
    end
    local record = activitysystem.getSubVar(actor, id)
    
    if getRewardTimeOut[type] then
        local config = getConfig(type)
        getRewardTimeOut[type](id, config, actor, record, packet)
    end
end

-- 策划要求活动时间过了，还要求可以领取奖励
function onReqInfoTimeOut(id,actor,packet)
    --读取配置，获得类型
    local type = ActivityConfig[id].activityType
    if getConfig(type) == nil then
        return
    end
    local record = activitysystem.getSubVar(actor, id)
    
    if reqInfoTimeOut[type] then
        local config = getConfig(type)
        reqInfoTimeOut[type](id, config, actor, record, packet)
    end
end

