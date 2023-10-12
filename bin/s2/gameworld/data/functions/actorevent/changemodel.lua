module("actorevent.changemodel", package.seeall)
setfenv(1, actorevent.changemodel)

local setIntProperty = LActor.setIntProperty
local getIntProperty = LActor.getIntProperty
local lockProperty   = LActor.lockProperty
local unLockProperty   = LActor.unLockProperty

local overEventTab = {}
local reliveTime = 3

function changeSpecialModel(actor, modelId)
	if not actor or not modelId then return end
	setIntProperty(actor, P_CHANGE_MODEL, modelId)
	if modelId ~= 0 then
		LActor.addActorState(actor, esChangeModel)
	else
		LActor.removeActorState(actor, esChangeModel)
	end

	LActor.postCheckPropertyMsg(actor)
end

function getDyanmicVar(actor)
	local var = LActor.getGlobalDyanmicVar(actor)
	if not var then return end

	var.changeModel = var.changeModel or {}
	return var.changeModel
end

--============================================
-- README        ** 变身换血 **
--============================================
function getHpAndMaxHp(actor)
	local maxHp = getIntProperty(actor, P_MAXHP)
	local hp = getIntProperty(actor, P_HP)

	return hp, maxHp
end

function setOtherHp(actor, otherHp, otherMaxHp)
	if not otherMaxHp then otherMaxHp = otherHp end

	local var = getDyanmicVar(actor)
	if not var then return end

	local oldHp, oldMaxHp = getHpAndMaxHp(actor)

	var.oldHp = oldHp
	var.oldMaxHp = oldMaxHp
	unLockProperty(actor, P_MAXHP)
	unLockProperty(actor, P_HP)
	setIntProperty(actor, P_MAXHP, otherMaxHp)
	lockProperty(actor, P_MAXHP)
	local defHp = getIntProperty(actor, P_HP)
	LActor.changeHp(actor, otherHp - defHp)
	LActor.addActorState(actor, esUsingOtherHp)
end

function removeOtherHp(actor)
	local var = getDyanmicVar(actor)
	if not var then return end

	local otherHp, otherMaxHp = getHpAndMaxHp(actor)

	unLockProperty(actor, P_MAXHP)
	setIntProperty(actor, P_MAXHP, var.oldMaxHp or 10000)
	setIntProperty(actor, P_HP, var.oldHp or 10000)

	var.oldMaxHp = nil
	var.oldHp = nil
	-- end
	--重新计算属性
	LActor.refreshAbility(actor)
	LActor.removeActorState(actor, esUsingOtherHp)
	return otherHp, otherMaxHp
end

function onUsingOtherHpOver(actor, killer)
	--添加一个免伤的BUFF
	--todo buff修改
	--removeOtherHp(actor)
	LActor.addBuff(actor, GlobalConfig.reliveBuffId, nil, reliveTime)

	for _,func in ipairs(overEventTab) do
		func(actor, killer)
	end
end

function regUsingOtherHpOverEvent(proc)
	for _,func in ipairs(overEventTab) do
		if func == proc then return end
	end

	table.insert(overEventTab, proc)
end



