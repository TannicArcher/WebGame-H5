module("role", package.seeall)


local function onOpenRole(actor, packet)
	local job = LDataPack.readByte(packet)
	local sex = LDataPack.readByte(packet)

	if job <1 or job > 3 then return end
	if sex < 0 or sex > 1 then return end

	local count = LActor.getRoleCount(actor)
	local conf = NewRoleConfig[count]
	if conf == nil then return end

	local actorLevel = LActor.getLevel(actor)
	local zsLevel  = LActor.getZhuanShengLevel(actor)
	local viplevel = LActor.getVipLevel(actor)
	if viplevel < conf.vip and (actorLevel < conf.level or zsLevel < conf.zsLevel) then
		print(LActor.getActorId(actor) .. " onOpenRole:  " .. job .. " " .. sex)
		return
	end

	for i=1,count do
		local roledata = LActor.getRoleData(actor, i-1)
		if roledata.job == job then
			print(LActor.getActorId(actor) .. " onOpenRole:  job repeated" .. job .. " " .. sex)
			return
		end
	end
	print(LActor.getActorId(actor) .. " onOpenRole:  ok" .. job .. " " .. sex)

	LActor.createRole(actor, job, sex)

	actorevent.onEvent(actor, aeOpenRole, count)
	
	LActor.reCalcAttr(actor)
	LActor.reCalcExAttr(actor)
end

local switchTargetBeforeFunc = {} --func(actor(玩家),fbId(副本ID),et(目标实体))
function registerSwitchTargetBeforeFunc(fbId, func)
	if switchTargetBeforeFunc[fbId] == nil then
		switchTargetBeforeFunc[fbId] = {}
	end
	for _,ofunc in ipairs(switchTargetBeforeFunc[fbId]) do 
		if ofunc == func then
			return
		end
	end
	table.insert(switchTargetBeforeFunc[fbId], func)
end

--切换目标前,判断条件
local function switchTargetBefore(actor,et,et_acotr)
	local fbId = LActor.getFubenId(actor)
	for _,func in ipairs(switchTargetBeforeFunc[fbId] or {}) do 
		if not func(actor, fbId, et, et_acotr) then
			return false
		end
	end
	return true
end

local function switchTarget(actor,et_hdl,et_acotr)
	if LActor.getLiveByJob(actor) == nil then  --自己所有子角色死了 不能切换目标
		return
	end
	local et = LActor.getEntity(et_hdl)
	if et == nil then
		return
	end
	if et == actor then --不能自己打自己
		return 
	end
	local role_count = LActor.getRoleCount(actor)
	for i = 0,role_count-1 do
		local role = LActor.getRole(actor,i)
		if role == et then --不能自己打自己
			return
		end
	end
	--根据不同的条件判断是否能进入
	if not switchTargetBefore(actor,et,et_acotr) then
		return
	end
	LActor.setAITarget(actor,et)
end

local function onSwitchTarget(actor,pack)
	local et_hdl = LDataPack.readInt64(pack)
	if et_hdl == 0 then 
		LActor.setAIAttackMonster(actor)
	else
		local et = LActor.getEntity(et_hdl)
		if et == nil then 
			return 
		end
		if LActor.getEntityType(et) == EntityType_Monster then
			LActor.setAITarget(actor,et)
			return
		end
		switchTarget(actor,LActor.getHandle(LActor.getLiveByJob(et)), et)

	end
end

--请求停止AI
local function reqStopAi(actor, packet)
	LActor.stopAI(actor)
end

local function onNewDay(actor, login)
	if login then return end
	--下发新的一天的事件
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_NewDay)
	LDataPack.flush(npack)
end

actorevent.reg(aeNewDayArrive, onNewDay)

netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_CreateRole, onOpenRole)
netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_SwitchTarget,onSwitchTarget)
netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_StopAi,reqStopAi)


function gmOpenRole(actor, job, sex)
	LActor.createRole(actor, job, sex)
end

