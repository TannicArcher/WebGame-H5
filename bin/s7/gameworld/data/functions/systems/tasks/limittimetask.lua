module("limittimetask", package.seeall)

--[[
data define:
 limitTimeTask={
    id=当前进行的ID
	over_time=过期时间戳
	is_over_mail=是否已经发送过期时间邮件 0为未发送，1为已发送
	task[任务id]={
		curValue = 当前进度
		status = 领取状态
	}
  }

  dayResetTaskId --全局变量，保存每日重置的任务id
 ]]

local dayResetTaskId = {}

--获取限时任务的数据缓存
local function getLimitTimeVar(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil) then return end

	if (var.limitTimeTask == nil) then
		var.limitTimeTask = {}
	end
	if var.limitTimeTask.task == nil then
		var.limitTimeTask.task = {}
	end
	if var.limitTimeTask.is_over_mail == nil then
		var.limitTimeTask.is_over_mail = 0
	end

	return var.limitTimeTask
end

--获取限时任务单个任务的数据变量
local function getLimitTimeTaskVar(actor, id)
	local SVar = getLimitTimeVar(actor)
	if SVar == nil then
		return nil
	end
	if SVar.task[id] == nil then
		SVar.task[id] = {}
	end
	if SVar.task[id].curValue == nil then SVar.task[id].curValue = 0 end
	if SVar.task[id].status == nil then SVar.task[id].status = 0 end
	return SVar.task[id]
end

--通知客户端任务进度和状态变化
local function limitInfoSync(actor, id, curValue, status)
	--申请数据包
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_LimitTaskInfo)
	if not npack then return end
	LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, curValue)
	LDataPack.writeByte(npack, status)
	LDataPack.flush(npack)
end

--判断任务ID是否是当前接受的限时任务的任务
local function CheckTaskIdIsActive(actor, id)
	local SVar = getLimitTimeVar(actor)
	--没有玩家变量 或者 没有接受过限时任务ID 或者 已经过期
	if not SVar or not SVar.id or getEndTime(SVar.begin_time, SVar.id) <= System.getNowTime() then
		return false
	end
	local ItemCfg = LimitTimeConfig[SVar.id]
	--没有限时任务组项配置
	if not ItemCfg then
		return false
	end
	--判断任务ID是不是存在这个组的配置里面
	for _,v in ipairs(ItemCfg.taskIds) do
		if v == id then
			return true
		end
	end
	return false
end

--更新限时任务数量
function updateTask(actor, taskType, param, value)
	for id,config in pairs(LimitTimeTaskConfig) do
		--任务类型和辅助变量都一样的话才能更新
		if (config.type == taskType and taskcommon.checkParam(taskType, param, config.param)) then
			local STaskVar = getLimitTimeTaskVar(actor, id)
			if STaskVar then
				--任务还在做
				if STaskVar.status == taskcommon.statusType.emDoing then
					--updateTaskValue(STaskVar, taskType, value) --更新任务进度
					if (taskcommon.getHandleType(taskType) == taskcommon.eAddType) then
						--这是叠加类型的
						STaskVar.curValue = STaskVar.curValue + value
					elseif (taskcommon.getHandleType(taskType) == taskcommon.eCoverType) then
						--这是覆盖类型的
						if (value > STaskVar.curValue) then
							STaskVar.curValue = value
						end
					end
					if STaskVar.curValue >= config.target then
						STaskVar.curValue = config.target --保证任务进度只到配置最大值
						STaskVar.status = taskcommon.statusType.emCanAward --任务进度满足;就完成任务

						actorevent.onEvent(actor, aeFinishLimitTask, config.tag)
					end
					--通知客户端更新(如果任务是属于当前进行的限时任务组里面的任务)
					if CheckTaskIdIsActive(actor, id) then
						print("updateTask: STaskVar.curValue="..tostring(STaskVar.curValue)..", STaskVar.status="..tostring(STaskVar.status))
						limitInfoSync(actor, id, STaskVar.curValue, STaskVar.status)
					end
				end
			end
		end
	end
end

--获取任务ID完成状态
local function GetLimitTimeTaskStatus(actor, id)
	local STaskVar = getLimitTimeTaskVar(actor, id)
	return STaskVar.status
end

--判断指定ID的所有限时任务是否都完成了
local function CheckLimitTimeTaskIsComplete(actor, id)
	if actor == nil or id == nil then return false end
	--获取任务配置
	local ItemCfg = LimitTimeConfig[id]
	if not ItemCfg then
		print("CheckLimitTimeTaskIsComplete: LimitTimeConfig not have id("..tostring(id)..") config")
		return false
	end
	for k,v in ipairs(ItemCfg.taskIds or {}) do
		if LimitTimeTaskConfig[v] then --任务ID是存在的
			--其中一个未完成就是未完成,或者没领奖
			if GetLimitTimeTaskStatus(actor, v) ~= taskcommon.statusType.emHaveAward  then
				return false
			end
		end
	end
	return true
end

--获取当前应当领取的限时ID
local function getLimitTimeTaskCanRecId(actor)
	local SVar = getLimitTimeVar(actor) --获取静态变量
	--如果初始化状态; 领取1号任务
	if SVar.id == nil then
		return 1
	end
	--如果存在任务,判断旧任务是不是过期
	if getEndTime(SVar.begin_time, SVar.id) <= System.getNowTime() then
		--过期
		return SVar.id + 1
	end
	--如果没有过期,判断旧任务是不是都完成了
	if CheckLimitTimeTaskIsComplete(actor, SVar.id) then
		return SVar.id + 1
	end
	--还有任务;还有时间;不能领取任务
	return nil
end

--发送限时任务初始化信息
local function SendLimitTimeTaskInitInfo(actor)
	--获取静态变量
	local SVar = getLimitTimeVar(actor)
	if not SVar then return end
	--判断当前是否有任务或者过期
	if not SVar.id or getEndTime(SVar.begin_time, SVar.id) <= System.getNowTime() then
		--没有任务或者过期了
		local next_id = getLimitTimeTaskCanRecId(actor) --获取应该可领取的id
		if not next_id then return end --没有可领取的ID
		--判断配置是否存在,就是是否还有下一个任务
		local ItemCfg = LimitTimeConfig[next_id]
		if not ItemCfg then
			return
		end
		--申请数据包
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_LimitTimeTaskInit)
		if not npack then return end
		LDataPack.writeByte(npack, 0)
		LDataPack.writeInt(npack, next_id)
		LDataPack.flush(npack)
	else
		--还有任务
		local ItemCfg = LimitTimeConfig[SVar.id] --获取任务项ID配置
		if not ItemCfg then
			return
		end
		--申请数据包
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Task, Protocol.sTaskCmd_LimitTimeTaskInit)
		if not npack then return end
		LDataPack.writeByte(npack, 1)
		LDataPack.writeInt(npack, SVar.id)
		LDataPack.writeInt(npack, getEndTime(SVar.begin_time, SVar.id) - System.getNowTime())
		LDataPack.writeShort(npack, table.getn(ItemCfg.taskIds))
		for k,v in ipairs(ItemCfg.taskIds) do 
			LDataPack.writeInt(npack, v)
			if not SVar.task[v] then
				LDataPack.writeInt(npack, 0)
				LDataPack.writeByte(npack, taskcommon.statusType.emDoing)
			else
				LDataPack.writeInt(npack, SVar.task[v].curValue or 0)
				LDataPack.writeByte(npack, SVar.task[v].status or taskcommon.statusType.emDoing)
			end
		end
		LDataPack.flush(npack)
	end
end

--请求领取限时任务
local function reqReceive(actor)
	--获取当前应当领取的限时ID
	local rec_id = getLimitTimeTaskCanRecId(actor)
	if not rec_id then 
		print("LimitTimeTask, reqReceive: can not reqReceive id")
		return
	end
	--获取任务配置
	local ItemCfg = LimitTimeConfig[rec_id]
	if not ItemCfg then
		print("LimitTimeTask, reqReceive: LimitTimeConfig not have rec_id("..tostring(rec_id)..") config")
		return
	end
	
	local SVar = getLimitTimeVar(actor) --获取静态变量
	--设置ID
	SVar.id = rec_id
	SVar.is_over_mail = 0
end

--请求领取限时任务的单项任务奖励
local function reqTaskReward(actor, packet)
	local TaskId = LDataPack.readInt(packet) --领取对应任务ID的任务奖励
	--获取当前是否有接任务组
	local SVar = getLimitTimeVar(actor)
	if not SVar or not SVar.id then
		print("LimitTimeTask,reqTaskReward: is not have task group")
		return
	end
	--判断当前接的任务组是否已经过期
	if getEndTime(SVar.begin_time, SVar.id) <= System.getNowTime() then
		print("LimitTimeTask,reqTaskReward: is not have time")
		return
	end
	--获取限时任务组配置
	local ItemCfg = LimitTimeConfig[SVar.id]
	if not ItemCfg then
		print("LimitTimeTask, reqTaskReward: LimitTimeConfig not have SVar.id("..tostring(SVar.id)..") config")
		return
	end
	--判断当前任务ID属不属于当前接的任务组
	local is_find = false
	for k,v in ipairs(ItemCfg.taskIds) do
		if v == TaskId then
			is_find = true
			break
		end
	end
	if not is_find then
		print("LimitTimeTask, reqTaskReward: LimitTimeConfig not have TaskId("..tostring(TaskId)..") config")
		return
	end
	--判断任务ID是否存在任务列表
	local TaskCfg = LimitTimeTaskConfig[TaskId]
	if not TaskCfg then
		print("LimitTimeTask, reqTaskReward: LimitTimeTaskConfig not have TaskId("..tostring(TaskId)..") config")
		return
	end
	--获取限时任务变量
	local STaskVar = getLimitTimeTaskVar(actor, TaskId)
	if not STaskVar then return end
	--判断任务状态
	if STaskVar.status ~= taskcommon.statusType.emCanAward  then
		print("LimitTimeTask, reqTaskReward: GetLimitTimeTaskStatus TaskId("..tostring(TaskId)..") can not award")
		return
	end
	--获取奖励
	if LActor.canGiveAwards(actor, TaskCfg.awardList) == false then
		print("LimitTimeTask, reqTaskReward: TaskId("..tostring(TaskId)..") can not give award")
		return
	end
	LActor.giveAwards(actor, TaskCfg.awardList, "limit time task awards")
	--更改任务变量状态
	STaskVar.status = taskcommon.statusType.emHaveAward
	--通知客户端更新
	limitInfoSync(actor, TaskId, STaskVar.curValue, STaskVar.status)
	--任务是不是都完成了
	if CheckLimitTimeTaskIsComplete(actor, SVar.id) then
		SVar.is_over_mail = 1 --已经手工完成的;不发邮件
		startTask(actor)
	end
end

--把第二个参数表合并到第一个参数表
local function MergeTable(target, src) 
	for _,v in ipairs(src) do 
		local is_find = false
		for _,tv in ipairs(target) do
			if tv.type == v.type and tv.id == v.id then
				tv.count = tv.count + v.count 
				is_find = true
				break
			end
		end
		if is_find == false then
			table.insert(target, {type = v.type, id = v.id, count = v.count})
		end
	end
end

--限时任务时间到
local function onTimer(actor)
	--获取静态变量
	local SVar = getLimitTimeVar(actor)
	if not SVar then return end
	--如果已经发送过邮件
	if 1 == SVar.is_over_mail then
		return
	end

	--如果有接任务组,并且过期
	if SVar.id and getEndTime(SVar.begin_time, SVar.id) <= System.getNowTime() then
		--获取任务组配置
		local ItemCfg = LimitTimeConfig[SVar.id]
		if not ItemCfg then return end
		--获取所有任务的奖励和完成度
		local not_rec_reward = {} --未领取奖励
		for k,v in ipairs(ItemCfg.taskIds) do
			local TaskCfg = LimitTimeTaskConfig[v]
			if TaskCfg then
				if SVar.task[v] and SVar.task[v].status == taskcommon.statusType.emCanAward then
					MergeTable(not_rec_reward, TaskCfg.awardList)
				end
			end
		end
	
		--有奖励才发邮件
		if next(not_rec_reward) ~= nil then
			local mailData = {head=ItemCfg.mail_head, context=ItemCfg.mail_context, tAwardList=not_rec_reward}
			mailsystem.sendMailById(LActor.getActorId(actor), mailData)
		end
		--标记邮件已经发送
		SVar.is_over_mail = 1

		startTask(actor)
	end
end

--初始化一个定时器
local function initScriptEvent(actor)
	--获取静态变量
	local SVar = getLimitTimeVar(actor)
	if not SVar then return end
	if not SVar.id then return end

	local leftTime = getEndTime(SVar.begin_time, SVar.id) - System.getNowTime()
	if leftTime > 0 then
		--注册一个过期时间的定时器
		LActor.postScriptEventLite(actor, leftTime * 1000, onTimer)
		SendLimitTimeTaskInitInfo(actor)
	elseif leftTime <= 0 and 0 == SVar.is_over_mail then
		onTimer(actor)
	end
end

function  getEndTime(begin_time, id)
	return (begin_time or 0) + (LimitTimeConfig[id].time or 0)
end

function startTask(actor)
	reqReceive(actor)
	initScriptEvent(actor)
end

--玩家升级时触发
local function onLevelUp(actor, level)
	if LimitTimeConfig[1] and LimitTimeConfig[1].openLevel then
		if LimitTimeConfig[1].openLevel == level then
			local SVar = getLimitTimeVar(actor)
			SVar.begin_time = System.getNowTime()
			startTask(actor)
		end
	end
end

local function onNewDayArrive(actor)
	local SVar = getLimitTimeVar(actor)
	if not SVar.id then return end
	if getEndTime(SVar.begin_time, SVar.id) < System.getNowTime() then return end
	
	--重置数据
	for _,id in ipairs(dayResetTaskId or {}) do 
		local STaskVar = getLimitTimeTaskVar(actor, id)
		if taskcommon.statusType.emDoing == STaskVar.status then
			STaskVar.curValue = 0 
		end
	end

end

--玩家登陆时候触发
local function onLogin(actor)
	initScriptEvent(actor)
end

--系统初始化函数
local function init()
	--注册玩家事件
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeLevel, onLevelUp)
	actorevent.reg(aeNewDayArrive, onNewDayArrive)
	--注册消息
	--netmsgdispatcher.reg(Protocol.CMD_Task, Protocol.cTaskCmd_LimitRecevie, reqReceive) --接限时任务组
	netmsgdispatcher.reg(Protocol.CMD_Task, Protocol.cTaskCmd_LimitReward, reqTaskReward) --领取单项任务奖励

	for id, conf in pairs(LimitTimeTaskConfig or {}) do
		if 1 == (conf.dayReset or 0) then table.insert(dayResetTaskId,conf.id) end
	end
end
table.insert(InitFnTable, init)


function setLimitTaskFinish(actor, taskId)
	if not LimitTimeTaskConfig[taskId] then return end
	local STaskVar = getLimitTimeTaskVar(actor, taskId)
	STaskVar.curValue = LimitTimeTaskConfig[taskId].target
	STaskVar.status = taskcommon.statusType.emCanAward
	actorevent.onEvent(actor, aeFinishLimitTask)

	limitInfoSync(actor, taskId, STaskVar.curValue, STaskVar.status)
end









