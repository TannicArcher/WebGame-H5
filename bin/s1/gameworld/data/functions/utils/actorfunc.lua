module("utils.actorfunc", package.seeall)
setfenv(1, utils.actorfunc)

local luaex = require("utils.luaex")
local lua_string_split = luaex.lua_string_split

local actorDyanmicVar = _G.actorDyanmicVar
if actorDyanmicVar == nil then
	_G.actorDyanmicVar = {}
	actorDyanmicVar = _G.actorDyanmicVar
end

_G.systemDyanmicVar = _G.systemDyanmicVar or {}
local systemDyanmicVar = _G.systemDyanmicVar
systemDyanmicVar.actorVar = systemDyanmicVar.actorVar or {}
local actorVar = systemDyanmicVar.actorVar


local getStaticVar = LActor.getStaticVar
local getActorId = LActor.getActorId
local actorevent = require("actorevent.actorevent")

local function getSysVar(actor)
	if not actor then
		return nil
	end
	local var = getStaticVar(actor)
	if var == nil then return end

	if var.sys == nil then var.sys = {} end
	return var.sys
end

local function getAutoVar(actor)
	if not actor then return end

	local actorId = 0
	if type(actor) == "number" then
		actorId = actor
	else
		actorId = LActor.getActorId(actor)
	end

	if actorId == 0 then return end

	local var = System.getStaticVar()
	if var == nil then return end

	if var.autoVar == nil then var.autoVar = {} end
	local autoVar = var.autoVar
	if autoVar[actorId] == nil then autoVar[actorId] = {} end

	return autoVar[actorId]
end

local function getPlatVar(actor)
	if not actor then
		return nil
	end
	local var = getStaticVar(actor)
	if var.plat == nil then var.plat = {} end
	return var.plat
end

local function getTmpVar(actor)
	if not actor then
		return nil
	end
	local var = getStaticVar(actor)
	if var.tmp == nil then var.tmp = {} end
	return var.tmp
end


--不下线清理的接口，在关闭服务器后消失
local function getGlobalDyanmicVar(actor)
	if not actor then return nil end

	local aid = actor
	if type(aid) == "userdata" then
		aid = getActorId(actor)
	end

	if actorVar[aid] == nil then actorVar[aid] = {} end
	return actorVar[aid]
end


local function getDynamicVar(actor, isGlobal)
	if not actor then return nil end
	-- 目前只支持玩家存储数据，如果其他（如怪物）需要保存数据另外想办法
	-- 以前代码全部修改完，确定只有玩家才会调用这个函数后，这个assert可以删除
	if (LActor.getEntityType(actor) ~= EntityType_Actor) then
		print("getDynamicVar et type error")
		return
	end

	local aid = getActorId(actor)
	if actorDyanmicVar[aid] == nil then actorDyanmicVar[aid] = {} end
	return actorDyanmicVar[aid]
end

local function getGamePf(actor)
	local pf = LActor.getPf(actor)
	local gamePf = pf
	if string.sub(pf, 1, 5) == "union" and string.find(pf, "*") ~= nil then
		start = string.find(pf, "*")
		length = string.len(pf)
		gamePf = string.sub(pf, start+1, length)
	end
	return gamePf
end


_G.getDyanmicVarById = function(actorid)
	if actorDyanmicVar[actorid] == nil then actorDyanmicVar[actorid] = {} end
	return actorDyanmicVar[actorid]
end

_G.getGlobalDyanmicVarById = function(actorid)
	if actorVar[actorid] == nil then actorVar[actorid] = {} end
	return actorVar[actorid]
end

-- _G.cleanActorDyanmicVar = function(actorid)
-- 	actorDyanmicVar[actorid] = {}
-- end

_G.GetIntVar = function(actor, str, def)
	if not actor or not str then return def end

	local var = LActor.getStaticVar(actor)
	if not var then return def end

	local sub_str = lua_string_split(str, ".")
	local result = var
	for _, sub in ipairs(sub_str) do
		result = result[sub]
		if not result then return def end
	end
	return result
end

_G.OnLogin = function(actorId, actor)
end
_G.OnLogout = function(actorId, actor)
	actorDyanmicVar[actorId] = nil
end

LActor.getDynamicVar       = getDynamicVar
LActor.getGlobalDyanmicVar = getGlobalDyanmicVar
LActor.getSysVar           = getSysVar
LActor.getTmpVar           = getTmpVar
LActor.getPlatVar          = getPlatVar
LActor.getAutoVar          = getAutoVar
LActor.getGamePf		   = getGamePf
