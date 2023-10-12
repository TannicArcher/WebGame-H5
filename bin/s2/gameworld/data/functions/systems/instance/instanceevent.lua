module("insevent", package.seeall)


local insWinCallBack = {}
local insLoseCallBack = {}
local insInitCallBack = {}

local insEnterCallBack = {}
local insExitCallBack = {}
local insOfflineCallBack = {}

local insActorDieCallBack = {}
local insMonsterDieCallBack = {}

local insGatherStartCallBack = {}
local insGatherFinishCallBack = {} --采集完成回调

local insMonDamCallBack = {}
local insMonCreateCallBack = {}
local insSpecialVariantCallBack = {}
local insGetRewardsCallBack = {}
local insFitterGetRewardsCallBack = {}

local insCloneRoleDie = {}
local insCustomFunc = {}

local insRoleDie = {}
local insActorDamage = {}
local insLeapArea = {}


--local insReviveCallBack = {}
--local fbTeleportEvent = {}

local function regFbEvent(tbl, fbId, func)
	if fbId == nil then
		print("register ins event failed. fbId is nil")
		print( debug.traceback() )
		return
	end
	if tbl[fbId] == nil then tbl[fbId] = {} end
	if tbl[fbId][func] ~= nil then
		if tbl[fbId][func] == 1 then
			print( "function has registed for id:"..fbId )
			-- print( "不同难度的副本不要用相同id。")
		end
		tbl[fbId][func] = tbl[fbId][func] + 1
	else
		tbl[fbId][func] = 1
	end
end

-- 注册回调
function registerInstanceWin(fbId, func)
	regFbEvent(insWinCallBack, fbId, func)
end

function registerInstanceLose(fbId, func)
	regFbEvent(insLoseCallBack, fbId, func)
end

function registerInstanceInit(fbId, func)
	regFbEvent(insInitCallBack, fbId, func)
end

--func(ins, actor)
function registerInstanceEnter(fbId, func) --actor enter instance
	regFbEvent(insEnterCallBack, fbId, func)
end

function registerInstanceExit(fbId, func)
	regFbEvent(insExitCallBack, fbId, func) --actor exit
end
--下线/掉线回调 是否需要？
function registerInstanceOffline(fbId, func) --actor leave instance
	regFbEvent(insOfflineCallBack, fbId, func)
end

function registerInstanceMonsterDie(fbId, func)
	regFbEvent(insMonsterDieCallBack, fbId, func)
end
--func(ins, actor, killerHdl)
function registerInstanceActorDie(fbId, func)
	regFbEvent(insActorDieCallBack, fbId, func)
end
--func(ins, gather, actor, success)
function registerInstanceGatherFinish(fbId, func)
	regFbEvent(insGatherFinishCallBack, fbId, func)
end

--bool func(ins, gather, actor, success)
function registerInstanceGatherStart(fbId, func)
	regFbEvent(insGatherStartCallBack, fbId, func)
end

--func(ins, monster, value, attacker)
function registerInstanceMonsterDamage(fbId, func)
	System.regInstanceMonsterDamage(fbId)
	regFbEvent(insMonDamCallBack, fbId, func)
end
--func(ins, monster)
function registerInstanceMonsterCreate(fbId, func)
	regFbEvent(insMonCreateCallBack, fbId, func)
end
--func(ins, name, value)
function registerInstanceSpecialVariant(fbId, func)
	regFbEvent(insSpecialVariantCallBack, fbId, func)
end
--func(ins, actor)
function registerInstanceGetRewards(fbId, func)
	regFbEvent(insGetRewardsCallBack, fbId, func)
end

function regCloneRoleDie(fbId,func)
	regFbEvent(insCloneRoleDie,fbId,func)
end

--func(ins,role,killer_hdl)
function regRoleDie(fbId, func)
	regFbEvent(insRoleDie, fbId, func)
end

function registerInsFittertanceGetRewards(fbId, func)
	regFbEvent(insFitterGetRewardsCallBack, fbId, func)
end
--func(ins, actor, role, value, attacker, res)
function registerInstanceActorDamage(fbId, func)
	System.regInstanceActorDamage(fbId)
	regFbEvent(insActorDamage, fbId, func)
end

function registerInstanceActorLeapArea(fbId, func)
	regFbEvent(insLeapArea, fbId, func)
end

local function call(funcs, ins, ...)
	if funcs[ins.id] ~= nil then
        local ret = true
		for func,_ in pairs(funcs[ins.id]) do
			local sret = func(ins, ...)
			if sret ~= nil and sret == false then
				ret = false
			end
        end
        return ret
	end
	return true
end

function onWin(ins)
	--结束之前的处理
	call(insWinCallBack, ins)
	--通关事件
    local actors = ins:getActorList()
    for _, actor in ipairs(actors) do
        actorevent.onEvent(actor, aeFinishFuben, ins:getFid(), ins:getType())
    end
end

function onLose(ins)
	--失败事件
    local actors = ins:getActorList()
    for _, actor in ipairs(actors) do
        actorevent.onEvent(actor, aeLoseFuben, ins:getFid(), ins:getType())
    end
	call(insLoseCallBack, ins)
end

function onInitFuben(ins)
	call(insInitCallBack, ins) 
end

function onEnter(ins, actor, isLogin)
	print("onEnter event fid:"..tostring(ins:getFid()).." aid:".. tostring(LActor.getActorId(actor)))
	if ins.handle and ins.id ~= 0 then
		local anum = Fuben.getActorCount(ins.handle)
		if anum > 10 then
			print(ins:getFid().." fuben actor num:"..anum.." on enter")
			ins.print_anum = true
		end
	end
	call(insEnterCallBack, ins, actor)

	actorevent.onEvent(actor, aeEnterFuben, ins:getFid(), isLogin)
end

function onExit(ins, actor)
	if ins.handle and ins.id ~= 0 and ins.print_anum then
		local anum = Fuben.getActorCount(ins.handle)
		print(ins:getFid().." fuben actor num:"..anum.." on exit")
		if anum < 10 then
			ins.print_anum = nil
		end
	end
	call(insExitCallBack, ins, actor)
	--自动退队
	--LActor.exitTeam(actor)
end

function onOffline(ins, actor)
	call(insOfflineCallBack, ins, actor)
end

function onMonsterDie(ins, mon, killerHdl)
	call(insMonsterDieCallBack, ins, mon, killerHdl)
end

function onActorDie(ins, actor, killerHdl)
	call(insActorDieCallBack, ins, actor, killerHdl)
end

function onGatherFinished(ins, gather, actor, success)
	call(insGatherFinishCallBack, ins, gather, actor, success)
end

function onGatherStart(ins, gather, actor)
	return call(insGatherStartCallBack, ins, gather, actor)
end

function onMonsterDamage(ins, monster, value, attacker, ret)
    local res = {ret=ret}
	call(insMonDamCallBack, ins, monster, value, attacker, res)
    return res.ret
end

function onMonsterCreate(ins, monster)
	call(insMonCreateCallBack, ins, monster)
end

function onVariantChange(ins, name, value)
	call(insSpecialVariantCallBack, ins, name, value)
end

function onGetRewards(ins, actor)
	call(insGetRewardsCallBack, ins, actor)
end


function onCloneRoleDie(ins, et, killer_hdl)
	call(insCloneRoleDie, ins, et, killer_hdl)
end

function onRoleDie(ins,role,killer_hdl)
	call(insRoleDie,ins,role,killer_hdl)
end

function onFitterRewards(ins, actor, rewards)
	return call(insFitterGetRewardsCallBack, ins, actor, rewards)
end

function onActorDamage(ins, actor, role, value, attacker, ret)
	local res = {ret=ret}
	call(insActorDamage, ins, actor, role, value, attacker, res)
	return res.ret
end

function onActorLeapArea(ins, actor)
	call(insLeapArea, ins, actor)
	local idx = LActor.getSceneAreaIParm(actor, aaTransfer)
	if idx then
		local cfg = TransferPoint[idx]
		if cfg then
			local list = cfg.pointList[math.random(1, #cfg.pointList)]
			print("666666666666:"..tostring(idx))
			LActor.instantMove(actor, list.posX, list.posY)
		end
	end
end

--********************************************************************************--
--注册用户自定义函数
--********************************************************************************--
function regCustomFunc(fbId, func, name)
  if insCustomFunc[fbId] == nil then insCustomFunc[fbId] = {} end
  if insCustomFunc[fbId][name] ~= nil then
  		--print("该函数名已经注册了")
  		return
  else
  	    --print(fbId.."注册函数:"..name)
  		insCustomFunc[fbId][name] = func
  end
end

--********************************************************************************--
--调用用户自定义函数
--********************************************************************************--
function callCustomFunc(ins, name) 
  if not insCustomFunc[ins.id] or not insCustomFunc[ins.id][name] then 
  	print("fb:"..ins.id.." can't find func:"..name)
  	return 
  end
  return insCustomFunc[ins.id][name](ins)
end
