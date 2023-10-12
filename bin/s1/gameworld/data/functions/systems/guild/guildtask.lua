-- 公会任务

module("guildtask", package.seeall)

local LActor = LActor
local LDataPack = LDataPack
local systemId = Protocol.CMD_Guild
local taskcommon = taskcommon

local statusType = taskcommon.statusType

local TypeTaskList = {}

for id,config in pairs(GuildTaskConfig) do
	local taskType = config.type
	if taskType ~= nil and taskType ~= 0 then
		if TypeTaskList[taskType] == nil then
			TypeTaskList[taskType] = {}
		end
		table.insert(TypeTaskList[taskType], config)
	end
end

function getActorVar(actor)
    local actorVar = LActor.getStaticVar(actor)
    if actorVar == nil then
        print("actor var is nil")
        return nil
    end

    if actorVar.guildtask == nil then
        actorVar.guildtask = {}
    end
    return actorVar.guildtask
end

function getTaskVar(actor, id)
	local actorVar = getActorVar(actor)
	if (not actorVar) then
		return 
	end

	return actorVar[id]
end

local function sendTaskInfo(actor, id, nValue, status)
	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_TaskInfoChanged)
	if pack == nil then return end

	LDataPack.writeData(pack, 3,
						dtInt, id,
						dtInt, nValue,
						dtInt, status)
	LDataPack.flush(pack)
	-- print(string.format("sendTaskInfo:%d,%d,%d", id, nValue, status))
end

function sendTaskInfoList(actor)
	local actorVar = getActorVar(actor)
	if not actorVar then return end

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_TaskInfoList)
	if pack == nil then return end

	LDataPack.writeInt(pack, #GuildTaskConfig)
	for id,_ in ipairs(GuildTaskConfig) do
		local taskVar = actorVar[id] or {}
		LDataPack.writeData(pack, 3,
							dtInt, id,
							dtInt, taskVar.curValue or 0,
							dtInt, taskVar.status or statusType.emDoing)
		-- print(string.format("xxxxxxxxxxxxxxxxxxxxx:%d,%d,%d", id, taskVar.curValue or 0, taskVar.status or statusType.emDoing))
	end

	LDataPack.flush(pack)
end

--根据任务类型的处理方式来更新任务变量
local function updateTaskValue(taskType, taskVar, value)
	if taskcommon.taskTypeHandleType[taskType] == taskcommon.eAddType then
		--这是叠加类型的
		taskVar.curValue = taskVar.curValue + value
		System.log("guildtask", "updateTaskValue", "mark1", taskType, taskVar.curValue)
		return true
	elseif (taskcommon.taskTypeHandleType[taskType] == taskcommon.eCoverType) then
		--这是覆盖类型的
		if value > taskVar.curValue then
			taskVar.curValue = value
			System.log("guildtask", "updateTaskValue", "mark2", taskType, taskVar.curValue)
			return true
		end
	end
	return false
end

function updateTask(actor, taskType, param, value)
	-- print(string.format("updateTask:%d,%d", taskType, value))
	if LActor.getGuildId(actor) == 0 then return end

	local confList = TypeTaskList[taskType]
	if confList == nil then return end

	local actorVar = getActorVar(actor)
	if actorVar == nil then return end

	local checkTask = function(config)
		if config.param ~= param then return end

		local id = config.id

		-- print(string.format("checkTask:%d", id))

		local taskVar = actorVar[id]
		if taskVar == nil then
			actorVar[id] = {}
			taskVar = actorVar[id]
		end

		if taskVar.status == nil then
			taskVar.status = statusType.emDoing
		elseif taskVar.status ~= statusType.emDoing then
			return 
		end

		if taskVar.curValue == nil then
			taskVar.curValue = 0
		elseif taskVar.curValue >= config.target then
			return 
		end

		LActor.log(actor, "guildtask.updateTask", "make1", taskType, taskVar.status, taskVar.curValue)

		local curCount = taskVar.curValue or 0
		-- 同步数据给前端
		local bUpdate = updateTaskValue(taskType, taskVar, value)
		if bUpdate then
			if taskVar.curValue >= config.target then
				taskVar.curValue = config.target
				taskVar.status = statusType.emHaveAward
			end
			local rewardCount = taskVar.curValue - curCount

			LActor.log(actor, "guildtask.updateTask", "make2", taskType, taskVar.status, taskVar.curValue)

			for i=1, rewardCount do
				if config.awardList ~= nil then
					for _,award in pairs(config.awardList) do
						LActor.log(actor, "guildtask.updateTask", "giveAward", award.type, award.id, award.count)
						LActor.giveAward(actor, award.type, award.id, award.count, "guild task award")
					end
				end
			end

			sendTaskInfo(actor, id, taskVar.curValue, taskVar.status)
		end
	end

	for i=1,#confList do
		checkTask(confList[i])
	end
end

function onNewDay(actor, login)
	local actorVar = LActor.getStaticVar(actor)
    if actorVar == nil then return end

    actorVar.guildtask = {} -- 重置所有任务的状态

	if not login then
		sendTaskInfoList(actor)
	end
end

function onLogin(actor)
	if LActor.getGuildId(actor) == 0 then return end

	sendTaskInfoList(actor)
end

-- 领取奖励(废弃)
function handleGetTaskAward(actor, packet)
	-- if LActor.getGuildId(actor) == 0 then return end

	-- local taskId = LDataPack.readInt(packet)
	-- local config = GuildTaskConfig[taskId]
	-- if not config then return end

	-- local taskVar = getTaskVar(actor, taskId)
	-- if taskVar == nil then return end

	-- if taskVar.status == nil or taskVar.status ~= statusType.emCanAward then
	-- 	print("status error")
	-- 	return
	-- end
	-- taskVar.status = statusType.emHaveAward

	-- for _,award in pairs(config.awardList) do
	-- 	LActor.giveAward(actor, award.type, award.id, award.count, "guild task award")
	-- end

	-- sendTaskInfo(actor, taskId, taskVar.curValue or 0, taskVar.status)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_GetTaskAward, handleGetTaskAward)

