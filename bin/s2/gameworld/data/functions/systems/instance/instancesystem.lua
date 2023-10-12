module("instancesystem", package.seeall)
--setfenv(1, systems.instance.instancesystem)
require("systems.instance.instanceconfig")
--require("systems.instance.other.bossinfo")
require("systems.instance.instance")


--_G.instanceList = _G.instanceList or {}	-- hdl:instance
instanceList = instanceList or {}
releaseList = releaseList or {}


local function createInstance(fid, hdl)
	--print("on create Instance #####################################hdl:"..tostring(hdl))
	local scenelist = Fuben.Getscenelist(hdl)
	local ins = instance:new()
	if ins:init(fid, hdl, scenelist) then
		instanceList[hdl] = ins
		return true
	end

	print("create Instance failed, fid:"..fid)
	return false
end

--统一运行避免频繁调用脚本
local function onRun()
	for _, hdl in ipairs(releaseList) do
		instanceList[hdl] = nil
	end
	releaseList = {}

	local now_t = System.getNowTime()
	for _, ins in pairs(instanceList) do
		ins:runOne(now_t)
        bossinfo.onTimer(ins, now_t)
	end
end

local function onReqInsReward(actor, packet)
	local hfuben = LActor.getFubenHandle(actor)
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins == nil or ins.is_end == false then
		return
	end
	local info = ins.actor_list[LActor.getActorId(actor)]
	if info.rewards == nil then
		print("==非法请求副本boss奖励. actor:"..tostring(LActor.getActorId(actor)))
		return
	end
	
	local ret = insevent.onFitterRewards(ins, actor, info.rewards)
	if not (ret == nil or ret == true) then
		return
	end
	local info = ins.actor_list[LActor.getActorId(actor)]
	if info.rewards == nil then
		print("actor:"..tostring(LActor.getActorId(actor)))
		return
	end

	--给奖励
	local log = "fuben finish :"..ins.id
	for _,v in ipairs(info.rewards) do
		if not v.ng then
			LActor.giveAward(actor, v, log)
		end
	end

	print("onReqInsReward, actor_id:"..LActor.getActorId(actor))
	insevent.onGetRewards(ins, actor)
    ins:setRewards(actor, nil)
end

--回调函数
local function onEnterInstance(hdl, actor, isLogin)
	local ins = instanceList[hdl]
	if ins == nil then return end
	ins:onEnter(actor, isLogin)
    bossinfo.onEnter(ins, actor)
end

local function onExitInstance(hdl, actor)
	local ins = instanceList[hdl]
	if ins == nil then return end
	if ins.is_end then
		local info = ins.actor_list[LActor.getActorId(actor)]
		if info and info.rewards then
			onReqInsReward(actor, nil)
		end
	end

	ins:onExit(actor)
end

local function onOfflineInstance(hdl, actor)
	local ins = instanceList[hdl]
	if ins == nil then return end
	ins:onOffline(actor)
end

local function onEntityDie(hdl, et, killerHdl)
	local ins = instanceList[hdl]
	if ins == nil then 
		print("instancesystem.onEntityDie ins is nil ettype:"..LActor.getEntityType(et)..",eid:"..LActor.getId(et))
		return
	end
	ins:onEntityDie(et, killerHdl)
end

--副本内采集开始之前
local function onGatherStart(hdl, et, actor)
	local ins = instanceList[hdl]
	if ins == nil then return false end
	return insevent.onGatherStart(ins, et, actor)	
end

--副本内采集完回调
local function onGatherFinished(hdl, et, actor, success)
	local ins = instanceList[hdl]
	if ins == nil then return end
	return insevent.onGatherFinished(ins, et, actor, success)	
end

local function onMonsterDamage(hdl, monster, value, attacker, ret)
	local ins = instanceList[hdl]
	if ins == nil then return end
	--return ins:onMonsterDamage(monster, value, attacker) 副本本身暂时不需要
	return insevent.onMonsterDamage(ins, monster, value, attacker, ret)
end

local function onMonsterCreate(hdl, monster)
	local ins = instanceList[hdl]
	if ins == nil then return end
	bossinfo.onMonsterCreate(ins, monster)
	return ins:onMonsterCreate(monster)
end

local function onActorDamage(hdl, actor, role, value, attacker, ret)
	local ins = instanceList[hdl]
	if ins == nil then return end
	return insevent.onActorDamage(ins, actor, role, value, attacker, ret)
end

local function onLeapArea(hdl, actor)
	local ins = instanceList[hdl]
	if ins == nil then return end
	return insevent.onActorLeapArea(ins, actor)
end

--当前游戏中没有
local function onNextSection(hdl, sect, scenePtr)
	local ins = instanceList[hdl]
	if ins == nil then return end
	return ins:onSectionTrigger(sect, scenePtr)
end

_G.createInstance = createInstance
_G.onInstanceEnter = onEnterInstance
_G.onInstanceExit = onExitInstance
_G.onInstanceOffline = onOfflineInstance
_G.onInstanceEntityDie = onEntityDie
_G.onInstanceRun = onRun
_G.onInstanceMonsterDamage = onMonsterDamage
_G.onInstanceMonsterCreate = onMonsterCreate
_G.onInstanceActorDamage = onActorDamage
_G.onInstanceLeapArea = onLeapArea
_G.onInstanceGatherFinished = onGatherFinished
_G.onInstanceGatherStart = onGatherStart

--副本通用消息处理 --退出
local function onReqExit(actor, packet)
    --关于退出时血量处理，1.要添加Actor:IsDeath 2.要确认什么时候恢复
	--[[if LActor.isDeath(actor) then
		LActor.relive(actor)
		local maxhp = LActor.getHpMax(actor)
		LActor.setHp(actor, maxhp)
	end
	--]]
	
  	LActor.exitFuben(actor)	
end

local p = Protocol
netmsgdispatcher.reg(p.CMD_Fuben, p.cFubenCmd_QuitFuben, onReqExit)
netmsgdispatcher.reg(p.CMD_Fuben, p.cFubenCmd_GetBossReward, onReqInsReward)
--netmsgdispatcher.reg(SystemId.fubenSystemId, FubenSystemProtocol.cINS_UseSkill, onUseSkill)


--外部其他接口回调
function setInsRewards(ins, actor, rewards)
	print("instancesystem.setInsRewards, actor_id:"..LActor.getActorId(actor))
	ins:setRewards(actor, rewards)
	ins:notifyRewards(actor)
end

function releaseInstance(hdl)
    local fb = Fuben.getFubenPtr(hdl)
    if fb == nil then return end
    print("releaseInstance fb:".. hdl)
    table.insert(releaseList, hdl)
    --通知c++端清理副本
    Fuben.releaseInstance(fb)
end

--获取lua副本对象
function getInsByHdl(fhdl)
    --local fb = Fuben.getFubenPtr(fhdl)
    --if fb == nil then return nil end
    return instanceList[fhdl]
end

function getIns(fb)
    local hdl = Fuben.getFubenHandle(fb)
    return instanceList[hdl]
end

function getActorIns(actor)
    local fb = LActor.getFubenPtr(actor)
    local hdl = Fuben.getFubenHandle(fb)
    return instanceList[hdl]
end
