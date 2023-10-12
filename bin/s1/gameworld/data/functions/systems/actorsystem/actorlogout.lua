module("systems.actorlogout.actorlogout" , package.seeall)
setfenv(1, systems.actorlogout.actorlogout)
--本脚本片段实现了角色登出游戏的默认处理

local LActor = LActor
local system = system
local actorevent = require("actorevent.actorevent")
--local mountsys 		   = require("systems.mount.mountsystem")
--local wingcommon	   = require("systems.wingsystem.wingcommon")
--local spirit 		   = require("systems.spirit.spirit")

--保存玩家的PK模式数据
function savePKModeDataFunc(actor,var)
	local pkmode = var.pkmode
	if pkmode == nil then
		var.pkmode = {}
		pkmode = var.pkmode
	end

	pkmode[1] = LActor.getPkMode(actor)
end

function SaveData(actor)
	local var = LActor.getStaticVar( actor )
	savePKModeDataFunc(actor, var)			--玩家的PK模式数据
end

function sendToLogger(actor)
	--[[local mountlevel  = mountsys.getMountInfo(actor)
	
	local wingstage = 0
	local wingInfo = wingcommon.getWingInfo(actor)
	if wingInfo then
		wingstage = wingInfo.stage
	end
	local spiritlevel = spirit.getSpiritLevel(actor)
	local petlevel, jjExp  =  0, 0
	petlevel, jjExp = LActor.petGetJingjie(actor, petlevel, jjExp)

	local fightVal = LActor.getIntProperty(actor, P_FIGHT_VALUE)

	System.logCounter(LActor.getActorId(actor), 
				LActor.getAccountName(actor), 
				tostring(LActor.getLevel(actor)), 
				"system", "", string.format("zuoqi:%d,chibang:%d,jingling:%d,huoban:%d,fightVal:%d", mountlevel,wingstage,spiritlevel,petlevel, fightVal))

	--print(mountlevel, wingstage, spiritlevel, petlevel)
	--]]
end

function defaultHandlerPlayerLogout(actor, ...)
	local TeamId = LActor.getTeamId(actor)
	if TeamId ~= 0 then
		if Fuben.getTeamFubenStatus(TeamId) == tsReady then
			LActor.exitTeam(actor)
		end
	end
	local svar = LActor.getDyanmicVar(actor)
	local monster = svar.ProtectionMonster
	if monster ~= nil then
		Fuben.clearEntity(monster, false)
	end
	SaveData(actor)

	-- 发送日志
	if not arg then return end
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor),
		LActor.getLevel(actor), "logout", arg[2], "ip:"..LActor.getLastLoginIp(actor), "", tostring(LActor.getActorCurExp(actor)), tostring(LActor.getIntProperty(actor, P_BIND_COIN)), tostring(LActor.getIntProperty(actor, P_COIN)), string.format("job:%d,logintime:%d,pf:%s",LActor.getIntProperty(actor, P_VOCATION), LActor.getCreateTime(actor), LActor.getPf(actor)))

	sendToLogger(actor)

	print("defaultHandlerPlayerLogout " .. LActor.getLastLoginIp(actor))
end




actorevent.reg(aeUserLogout, defaultHandlerPlayerLogout)
