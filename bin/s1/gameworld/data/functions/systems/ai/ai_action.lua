module("ai_action", package.seeall)


MonsterActionImpl = {}
MonsterActionImpl.EventCalls = {}
MonsterActionFunc = {}		--怪物行为函数
MonsterActionCondition = {}  --怪物行为条件

--#include "data\functions\monevent\monsteractiontimemsg.txt" once
local AiConfigs = AiConfig

local stateName = {"born", "idle", "battle", "back", "dead", "","",""}
local getConfig = function(id, param)
	local ai = AiConfigs[id]	--sample ai=0
	if ai == nil then return nil end
	local action_idx = param % 32 + 1
	local event_idx = math.floor(param / 32) % 256 + 1
	local state = stateName[math.floor(param / 8192) % 8 + 1]

	if ai[state] == nil then return nil end
	if ai[state][event_idx] == nil then return nil end
	if ai[state][event_idx].actions == nil then return nil end
	return ai[state][event_idx].actions[action_idx]
end

--返回0未执行下次重新执行 1 执行完毕 2 下次继续执行（与0区别在于有超时机制)
MonsterActionImpl.dispatch = function(monster, monId, aiId, param)
	local item = getConfig(aiId, param)
	if item == nil then
		print( "can't find actionconfig: id:"..aiId.." , param: "..param)
		return 0
	end
	if item.type == nil then
		print( "action type not define. id:"..aiId.." , param: "..param)
		return 0
	end
	local eventCall = MonsterActionImpl.EventCalls[item.type]	--根据类型选择处理函数
	if eventCall == nil then
		print( "can't find eventCall:"..item.type )
		return 0
	end
	--local item, err = loadstring(" local args = {"..param.."} return args ")

	--if (item == nil) then
	--	print(err)
	--end
	return eventCall(monster, monId, item)
end


-----------------------------行为实现-----------------------------------
--[[--对白
MonsterActionImpl.EventCalls[1] = function( monster, monId, item )
	LActor.monsterSay( monster, item.talk, item.talkType )
	--print("monster say:"..tostring(item.talk))
	return 1
end

--特效
MonsterActionImpl.EventCalls[2] = function( monster, monId, item )
	--print( "monster effect" )
	local players = LuaHelp.getSceneActorList( monster )
	if players == nil then return end
	for i=1,#players do
		LActor.playScrEffectCode( players[i], item.id, item.time )
	end
	return 1
end
--]]

--释放技能
MonsterActionImpl.EventCalls[1] = function(monster, monId, item)
	local ret = LActor.useSkill(monster, item.id)
	--print("ai action 1: skill:"..item.id.."ret:"..tostring(ret))
	if ret then return 1
	else return 0
	end
end

--切换目标
MonsterActionImpl.EventCalls[2] = function(monster, monId, item)
	LActor.changeAITarget(monster, item.mtype or 0)
	return 1
end

local function getNoticeArg(arg, monster)
   if arg == "hp" then
       return tostring(LActor.getHp(monster))
   elseif arg == "hpPercent" then
       local hp = LActor.getHp(monster)
       local hpMax = LActor.getHpMax(monster)
       return tostring(math.ceil(hp * 100/ hpMax))
   else
       return "NULL"
   end
end
MonsterActionImpl.EventCalls[3] = function(monster, monId, item)
    local args = {}
    if item.args then
        for _, v in ipairs(item.args) do
            table.insert(args, getNoticeArg(v, monster))
        end
    end
    noticemanager.broadCastNotice(item.id, unpack(args))
    return 1
end

MonsterActionImpl.EventCalls[4] = function(monster, monId, item)
	if not item.id then return 1 end

	local scene  =  LActor.getScenePtr(monster)
	if not scene then return 1 end

	local target = Fuben.getSceneMonsterById(scene, item.id)
	if not target then return 1 end

	LActor.setAITarget(monster, target)
	return 1
end

MonsterActionImpl.EventCalls[5] = function(monster, monId, item)
	if not item.id then return end

	LActor.addSkillEffect(monster, item.id)
	return 1
end
----------------------------------------------------------------------------------
--怪物行为
--返回0未执行下次重新执行 1 执行完毕 2 下次继续执行（与0区别在于有超时机制)
function OnMonsterAction( monster, monId, actionId, squeId, itemId, all )
	return MonsterActionImpl.dispatch( monster, monId, actionId, squeId, itemId, all )
end

_G.OnMonsterAction = OnMonsterAction

