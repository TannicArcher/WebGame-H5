module("dailytask", package.seeall)


--[[
data define:
 activeVar={
    activeValue  int
    awardList  {}id: 0/1
 }

 dailyVar={
    id: {
        id        number
        curValue  number
        status   taskcommon.statusType
    }
  }
 ]]
--获取日常任务的数据缓存
function getDailyVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end

	if (var.dailyVar == nil) then
		var.dailyVar = {}
	end

	return var.dailyVar
end

--获取指定id的日常任务的数据缓存
function getDailyTaskVar(actor, id)
	local dailyVar = getDailyVar(actor)
	if (not dailyVar) then
		return 
	end

	return dailyVar[id]
end

--获取活跃度的数据缓存
function getActiveVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end

	if (var.activeVar == nil) then
		var.activeVar = {}
		var.activeVar.activeValue = 0

		var.activeVar.awardList = {}
		for _,tb in pairs(DailyAwardConfig) do
			var.activeVar.awardList[tb.id] = 0
		end
	end

	return var.activeVar	
end

--增加活跃度
function addActiveValue(actor, add)
	local activeVar = getActiveVar(actor)
	if (not activeVar) then
		return
	end

	activeVar.activeValue = activeVar.activeValue + add

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_ActiveValueSync)
	if pack == nil then return end

	LDataPack.writeInt(pack, activeVar.activeValue)
	LDataPack.flush(pack)	
end

--日程任务数据初始化，上线的时候调用，
--把策划新加的日常任务接一下
function dailyTaskInit(actor)
	local dailyVar = getDailyVar(actor)
	if (not dailyVar) then return end

	for id,_ in pairs(DailyConfig) do
		if (dailyVar[id] == nil) then
			dailyVar[id] = {}
			dailyVar[id].id = id
			dailyTaskReset(id, dailyVar)
		end
	end
end

--日常任务数据初始化
function dailyTaskReset(id, dailyVar)
	if (dailyVar[id] ~= nil) then
		dailyVar[id].curValue = 0
		dailyVar[id].status = taskcommon.statusType.emDoing
	else
		dailyVar[id] = {}
		dailyVar[id].id = id
		dailyVar[id].curValue = 0
		dailyVar[id].status = taskcommon.statusType.emDoing		
	end
end

--更新日常任务变量
function updateDailyTask(actor, taskType, param, value)
	for id,config in pairs(DailyConfig) do
		repeat
			--任务类型和辅助变量都一样的话才能更新
			if (config.type ~= taskType or config.param ~= param) then
				break
			end

			local dailyTaskVar = getDailyTaskVar(actor, id)
			if (dailyTaskVar == nil) then
				break
			end

			--已完成的任务不更新
			if (dailyTaskVar.status ~= taskcommon.statusType.emDoing) then
				break
			end

			if (dailyTaskVar.curValue >= config.target) then
				break
			end
			
			local oldValue = dailyTaskVar.curValue
			--同步数据给前端
			local bUpdate = updateTaskValue(taskType, dailyTaskVar, value)
			if (bUpdate) then
				if (dailyTaskVar.curValue >= config.target) then
					dailyTaskVar.curValue = config.target
					dailyTaskVar.status = taskcommon.statusType.emCanAward
				end

				dailyInfoSync(actor, id, dailyTaskVar.curValue, dailyTaskVar.status)

				--增加历练值
				trainsystem.addTrainExp(actor, config.trainExp*(dailyTaskVar.curValue-oldValue))
			end

		until(true)
	end
end

--根据任务类型的处理方式来更新任务变量
function updateTaskValue(taskType, dailyTaskVar, value)
	if (taskcommon.getHandleType(taskType) == taskcommon.eAddType) then

		--这是叠加类型的
		dailyTaskVar.curValue = dailyTaskVar.curValue + value

		return true
	elseif (taskcommon.getHandleType(taskType) == taskcommon.eCoverType) then

		--这是覆盖类型的
		if (value > dailyTaskVar.curValue) then
			dailyTaskVar.curValue = value
			return true
		end
	end
	return false
end

--日常任务领奖
function dailyAward(actor, id)
	local config = taskcommon.getDailyTaskConfig(id)
	if (not config) then
		return
	end

	local dailyTaskVar = getDailyTaskVar(actor, id)
	if (dailyTaskVar == nil) then
		return
	end

	if (dailyTaskVar.status ~= taskcommon.statusType.emCanAward) then
		return
	end

	dailyTaskVar.status = taskcommon.statusType.emHaveAward

	for _,award in pairs(config.awardList) do
		LActor.giveAward(actor, award.type, award.id, award.count, "daily task award")
	end

	addActiveValue(actor, config.activeValue)

	dailyInfoSync(actor, id, dailyTaskVar.curValue, dailyTaskVar.status)
end

function dailyInfoSync(actor, id, nValue, status)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_DailyDataSync)
	if pack == nil then return end

	LDataPack.writeData(pack, 3,
						dtInt, id,
						dtInt, nValue,
						dtInt, status)

	LDataPack.flush(pack)		
end

function dailyInfoListSync(actor)
	local dailyVar = getDailyVar(actor)
	if (not dailyVar) then return end

	local activeVar = getActiveVar(actor)
	if (not activeVar) then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_DailyDataListSync)
	if pack == nil then return end

	LDataPack.writeInt(pack, #DailyConfig)
	for id,_ in pairs(DailyConfig) do
		local dailyTaskVar = dailyVar[id]
		if (dailyTaskVar ~= nil) then
			LDataPack.writeData(pack, 3,
								dtInt, id,
								dtInt, dailyTaskVar.curValue,
								dtInt, dailyTaskVar.status)
		end
	end

	LDataPack.writeInt(pack, activeVar.activeValue)
	LDataPack.writeInt(pack, #DailyAwardConfig)

	for activeId,_ in pairs(DailyAwardConfig) do
		LDataPack.writeInt(pack, activeId)
		LDataPack.writeInt(pack, activeVar.awardList[activeId] or 0)
	end

	LDataPack.flush(pack)
end

function activeAward(actor, activeId)
	local config = taskcommon.getActiveAwardConfig(activeId)
	if (not config) then 
		return 
	end

	local activeVar = getActiveVar(actor)
	if (activeVar == nil) then 
		return 
	end

	if (config.valueLimit > activeVar.activeValue) then
		return
	end

	if (activeVar.awardList[activeId] == 1) then
		return
	end

	activeVar.awardList[activeId] = 1

	for _,award in pairs(config.awardList) do
		LActor.giveAward(actor, award.type, award.id, award.count, "active award")
	end

	activeAwardSync(actor, activeId, activeVar.awardList[activeId])
end

function activeAwardSync(actor, activeId, status)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_ReActiveAward)
	if pack == nil then return end

	LDataPack.writeData(pack, 2,
						dtInt, activeId,
						dtInt, status)

	LDataPack.flush(pack)	
end

function onNewDay(actor, login)
	local dailyVar = getDailyVar(actor)
	if (not dailyVar) then return end

	for id,cfg in pairs(DailyConfig) do
		dailyTaskReset(id, dailyVar)
		--通关关卡副本类型的
		if cfg.type == taskcommon.taskType.emFinishTypeDup and cfg.param == 1 then
			local data = chapter.getStaticData(actor)
			if ChaptersConfig[data.level + 1] == nil then --所有关卡都通关了
				updateDailyTask(actor, cfg.type, cfg.param, cfg.target)
			end
		end
	end

	local activeVar = getActiveVar(actor)
	if (activeVar ~= nil) then
		activeVar.activeValue = 0

		for _,tb in pairs(DailyAwardConfig) do
			activeVar.awardList[tb.id] = 0
		end
	end

	print("on dailytask new day. aid:"..LActor.getActorId(actor))
	if not login then
		dailyInfoListSync(actor)
	end
end

function dailyAward_c2s(actor, packet)
	local id = LDataPack.readInt(packet)
	dailyAward(actor, id)
end

function activeAward_c2s(actor, packet)
	local activeId = LDataPack.readInt(packet)
	activeAward(actor, activeId)
end

function onLogin(actor)
	dailyTaskInit(actor)
	dailyInfoListSync(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
netmsgdispatcher.reg(Protocol.CMD_Task, Protocol.cTaskCmd_DailyAward, dailyAward_c2s)
netmsgdispatcher.reg(Protocol.CMD_Task, Protocol.cTaskCmd_ActiveAward, activeAward_c2s)