module("achievetask", package.seeall)


--[[
data define:

 achieveVar ={
    achieveid: {
       taskId
       taskType    number  --判断记录有效性对照
       curValue    number
       status      taskcommon.statusType
    }
  }
 ]]

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end

	if (var.achieveData == nil) then
		var.achieveData = {}
	end

	return var.achieveData
end

local function achieveInfoSync(actor, id, taskId, value, status)
    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_AchieveDataSync)
    if pack == nil then return end

    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, taskId)
    LDataPack.writeInt(pack, status)
    LDataPack.writeInt(pack, value)
    LDataPack.flush(pack)
end

local function getMinId(conf)
    local id
    for i,_ in pairs(conf) do
        if id == nil or id > i then
            id = i
        end
    end
    return id
end

local function getNextId(id, taskId)
    local configs = taskcommon.getAchieveConfig()
    local config = configs[id]
    if config == nil then return taskId end
    local ret
    for i,_ in pairs(config) do
        if (i >taskId) and (ret == nil or ret > i) then
            ret = i
        end
    end
    if ret == nil then return taskId end
    return ret
end

local function initTask(actor, conf, taskId)
    local data = {}
    if taskId == nil then
        taskId = getMinId(conf)
    end
    data.taskId = taskId
    data.taskType = conf[taskId].type
    data.curValue = 0
    data.status = taskcommon.statusType.emDoing

    local taskHandleType = taskcommon.getHandleType(conf[taskId].type)
    if taskHandleType == eCoverType or conf[taskId].controlSync == 0 then
        local record = taskevent.getRecord(actor)

        if taskevent.needParam(conf[taskId].type) == taskcommon.Param.emFuben then
            if record[conf[taskId].type] == nil then
                record[conf[taskId].type] = {}
            end
            data.curValue = record[conf[taskId].type][conf[taskId].param] or 0
        elseif taskevent.needParam(conf[taskId].type) == taskcommon.Param.emChenZhuan then
            if (record[conf[taskId].type] or 0) >= conf[taskId].param then
                data.curValue = 1
            end
		elseif taskevent.needParam(conf[taskId].type) == taskcommon.Param.emParamEGt then
			local tbl = record[conf[taskId].type] or {}
			for param,value in pairs(tbl) do
				if param >= conf[taskId].param and (data.curValue or 0) < value then
					data.curValue = value
				end
			end
        elseif taskevent.needParam(conf[taskId].type) == taskcommon.Param.emParamELt then
            local tbl = record[conf[taskId].type] or {}
            for param,value in pairs(tbl) do
                if param <= conf[taskId].param and (data.curValue or 0) < value then
                    data.curValue = value
                end
            end
        else
            data.curValue = record[conf[taskId].type] or taskevent.initRecord(conf[taskId].type, actor)
        end
		--老是遇到这里报错;肯定某人做的某个类型有问题, 把这个报错先抛出来
		--local str = tostring(taskId)..","..tostring(conf[taskId].type)
		--assert((type(data.curValue) == "number"), str)
		data.curValue = tonumber(data.curValue) or 0
        if data.curValue >= conf[taskId].target then
			data.curValue = conf[taskId].target
            data.status = taskcommon.statusType.emCanAward
            actorevent.onEvent(actor, aeAchievetaskFinish, conf.achievementId, taskId)
            -- if conf.score and conf.score > 0 then
            --     knighthood.updateknighthoodData(actor,conf.score)
            -- end
        end
    end

    return data
end


local function achieveInit(actor)
	local achieveConfigs = taskcommon.getAchieveConfig()
	if (not achieveConfigs) then
		return
	end

	local data = getStaticData(actor)
	if (not data) then
		return
	end

	for id,taskConfigs in pairs(achieveConfigs) do
		if (data[id] == nil) then
			data[id] = initTask(actor, taskConfigs)
        --记录类型不匹配时
        elseif taskConfigs[data[id].taskId] == nil then
            local nextId = getNextId(id, data[id].taskId)
            if nextId > data[id].taskId then
                data[id] = initTask(actor, taskConfigs, nextId)
            end

        elseif data[id].taskType ~= taskConfigs[data[id].taskId].type then
            data[id] = initTask(actor, taskConfigs, data[id].taskId)

        --记录任务不存在  不处理
        --记录已完成,如果有新任务就接新任务
        elseif data[id].status == taskcommon.statusType.emHaveAward then
            local nextId = getNextId(id, data[id].taskId)
            if nextId > data[id].taskId then
                data[id] = initTask(actor, taskConfigs, nextId)
            end
        end
	end
end

local function updateTaskValue(taskType, taskVar, value)
	if (taskcommon.getHandleType(taskType) == taskcommon.eAddType) then
		--这是叠加类型的
		taskVar.curValue = taskVar.curValue + value

		return true
	elseif (taskcommon.getHandleType(taskType) == taskcommon.eCoverType) then
		--这是覆盖类型的
		if (value > taskVar.curValue) then
			taskVar.curValue = value
			return true
		end
	end
	return false
end

--外部接口
function updateAchieveTask(actor, taskType, param, value)
	local taskList = taskcommon.getTaskListByType(taskType)
	if (not taskList) then
		return
    end

    local data = getStaticData(actor)

	for _,config in pairs(taskList) do
		repeat
			--if (param ~= config.param and taskType ~= 40 and taskType ~= 41) 
            --    or (param < config.param and (taskType == 40 or taskType == 41)) then
			--	break
			--end
			if not taskcommon.checkParam(taskType, param, config.param) then
				break
			end

			local achieveId = config.achievementId
			local achieveVar = data[achieveId]
			if (achieveVar == nil) then
				break
			end

            if achieveVar.taskId ~= config.taskId then
                break
            end
            
            if achieveVar.status ~= taskcommon.statusType.emDoing then
                break
            end
			--if taskType == 1 then
			--	print("更新任务ID:"..achieveVar.taskId..",val:"..tostring(achieveVar.curValue))
			--end
			updateTaskValue(taskType, achieveVar, value) 
			if (achieveVar.curValue >= config.target) then
				--if taskType == 1 then
				--	print("完成任务ID:"..achieveVar.taskId..",val:"..tostring(achieveVar.curValue)..",target:"..tostring(config.target))
				--end
				achieveVar.curValue = config.target
				achieveVar.status = taskcommon.statusType.emCanAward
				actorevent.onEvent(actor, aeAchievetaskFinish,achieveId,config.taskId)
                -- if config.score and config.score > 0 then
                --     knighthood.updateknighthoodData(actor,config.score)
                -- end
			end
            achieveInfoSync(actor, achieveId, achieveVar.taskId, achieveVar.curValue, achieveVar.status)
            print(LActor.getActorId(actor).." achievetask.updateAchieveTask, achieveId:"..achieveId..", taskId:"..achieveVar.taskId..", curValue:"..achieveVar.curValue..", status:"..achieveVar.status)
		until(true)
	end
end

local function achieveFinishEvent(actor, type, param)
	--if (type == taskcommon.taskEventType.emFieldBoss) then
	--	fieldboss.refreshBoss(actor)
	--else

	--end
end

local function achieveInfoListSync(actor)
	local achieveConfig = taskcommon.getAchieveConfig()
	if (not achieveConfig) then
		return
    end
    local data = getStaticData(actor)
    if data == nil then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_AchieveDataListSync)
	if pack == nil then return end

	LDataPack.writeInt(pack, taskcommon.getAchieveCount())
	for id, config in pairs(achieveConfig) do
        if data[id] == nil then
            data[id] = initTask(actor, config)
        end

        local achieveVar = data[id]
       
        LDataPack.writeData(pack, 4,
            dtInt, id,
            dtInt, achieveVar.taskId,
            dtInt, achieveVar.status,
            dtInt, achieveVar.curValue
        )
	end

	LDataPack.flush(pack)	
end

--[[function deleteAchieveTaskSync(actor, id, taskId)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_DeleteAchieveTask)
	if pack == nil then return end

	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, taskId)
	LDataPack.flush(pack)	
end
--]]

local function acceptAchieveTaskSync(actor, id, taskId, value, status)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_AcceptAchieveTask)
	if pack == nil then return end

	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, taskId)
	LDataPack.writeInt(pack, status)
	LDataPack.writeInt(pack, value)
	
	LDataPack.flush(pack)	
end

-- actor event
local function onLogin(actor)
	achieveInit(actor)
	achieveInfoListSync(actor)

    --临时处理
    local aid = LActor.getActorId(actor)
    if todoList[aid] == true then
        gmAddRecord(aid)
        todoList[aid] = nil
    end
end

-- net handle
local function achieveAward_c2s(actor, packet)
	local id = LDataPack.readInt(packet)

    local data = getStaticData(actor)
    local achieveVar = data[id]
    if achieveVar == nil then
        return
    end

    local configs = taskcommon.getAchieveConfig()
    if configs[id] == nil then return end

    local config = configs[id][achieveVar.taskId]
    if config == nil then   --记录可能会有无效的
        return
    end

    if achieveVar.status ~= taskcommon.statusType.emCanAward then
        return
    end

	achieveVar.status = taskcommon.statusType.emHaveAward

    LActor.giveAwards(actor, config.awardList, "achieve task awards")

	achieveInfoSync(actor, id, achieveVar.taskId, achieveVar.curValue, achieveVar.status)


	local nextTaskId = getNextId(id, achieveVar.taskId)
    if nextTaskId > achieveVar.taskId then
        data[id] = initTask(actor, configs[id], nextTaskId)
        achieveVar = data[id]
        acceptAchieveTaskSync(actor, id, nextTaskId, achieveVar.curValue, achieveVar.status)
    end

	if (config.eventType) then
		achieveFinishEvent(actor, config.eventType, config.eventParam1)
	end

    --print("领取成就==============task:"..config.taskId)
    --if config.score and config.score > 0 then
        --knighthood.updateknighthoodData(actor,config.score)
    --end

end

function finishAchieveTask(actor, id, taskId)
    local data = getStaticData(actor)
    local achieveVar = data[id]
    if achieveVar == nil then
        return
    end
    local configs = taskcommon.getAchieveConfig()
    if configs[id] == nil then return end
    local config = configs[id][taskId]

    achieveVar.taskId = taskId
    achieveVar.status = taskcommon.statusType.emHaveAward

    --LActor.giveAwards(actor, configs[id][taskId].awardList, "achieve task awards")

	achieveInfoSync(actor, id, achieveVar.taskId, achieveVar.curValue, achieveVar.status)

	local nextTaskId = getNextId(id, achieveVar.taskId)
    if nextTaskId > achieveVar.taskId then
        data[id] = initTask(actor, configs[id], nextTaskId)
        achieveVar = data[id]
        acceptAchieveTaskSync(actor, id, nextTaskId, achieveVar.curValue, achieveVar.status)
    end

	if (config.eventType) then
		achieveFinishEvent(actor, config.eventType, config.eventParam1)
	end
end

--外部接口
function isFinish(actor, achieveId, taskId)
    local data = getStaticData(actor)
    if data[achieveId] == nil then
        return false
    end
    if data[achieveId].taskId > taskId then
        return true
    end

    if data[achieveId].status == taskcommon.statusType.emDoing then
        return false
    end

    return true
end

--清空初始化指定成就的任务ID的数据
function clearInitTask(actor, id, taskId)
    local configs = taskcommon.getAchieveConfig()
    local data = getStaticData(actor)
    data[id] = initTask(actor, configs[id], taskId)
    achieveVar = data[id]
    acceptAchieveTaskSync(actor, id, taskId, achieveVar.curValue, achieveVar.status) 
end

actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Task, Protocol.cTaskCmd_AchieveAward, achieveAward_c2s)

todoList = todoList or {}
function gmAddRecord(actor_id)
    local actor = LActor.getActorById(actor_id)
    if actor then
        local clevel = LActor.getChapterLevel(actor)
        for i=1,clevel-1 do
            taskevent.onFinishFuben(actor, i)
            taskevent.onEnterFuben(actor, i)
            print("on finish "..i)
        end
    else
    todoList[actor_id] = true
    end
end

function gmaccept(actor,id,taskid)
	local configs = taskcommon.getAchieveConfig()
	local data = getStaticData(actor)
	data[id] = initTask(actor, configs[id], taskid)
    achieveVar = data[id]
    acceptAchieveTaskSync(actor, id, taskid, achieveVar.curValue, achieveVar.status) 
end
