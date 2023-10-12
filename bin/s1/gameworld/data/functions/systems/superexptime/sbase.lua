--[[
	author = 'Roson'
	time   = 11.04.2014
	name   = 多倍挂机系统
	mod    = 基础包
	ver    = 0.1
]]
module("systems.superexptime.sbase" , package.seeall)
setfenv(1, systems.superexptime.sbase)

netmsgdispatcher = require("utils.net.netmsgdispatcher")
actorevent       = require("actorevent.actorevent")

SuperExpTimeConf = nil
require("superexptime.superexptimeconf")
SuperExpTimeConf = SuperExpTimeConf

sysId = nil
protocol = nil
require("protocol")
sysId    = SystemId.superExpTimeSystem
protocol = SuperExpTimeProtocol

TO_END_TYPE =
{
	DEF      = 1,
	PROHIBIT = 2,
	STOP     = 3,
	RESET    = 4,
}

--********************************************--
--README ---------- * 数据接口 * ---------------
--********************************************--

function getSysVar(actor)
	if type(actor) == "number" then
		actor = LActor.getActorById(actor)
		if not actor then return end
	end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if var.superexptime == nil then var.superexptime = {} end
	return var.superexptime
end

function getDyanmicVar(actor)
	local var
	if type(actor) == "number" then
		var = getGlobalDyanmicVarById(actor)
	else
		var = LActor.getGlobalDyanmicVar(actor)
	end

	if not var then return end

	if var.superexptime == nil then var.superexptime = {} end
	return var.superexptime
end

function getSysDyanmicVar( ... )
	local var = System.getDyanmicVar()
	if not var then return end

	var.superexptime = var.superexptime or {}
	return var.superexptime
end

