module("specialattribute", package.seeall)

goldEx = 1
expEx  = 2

--图鉴
tujianSys = 1
--月卡
monthcardSys = 2
--符文
fuwenSys = 3
--新神器
imbaSys = 4
--模块数
moduleCount  = 4

local function getData(actor)
	local var = LActor.getDynamicVar(actor)
	if var == nil then 
		return nil
	end
	if var.specialattribute == nil then
		var.specialattribute = {}
	end
	return var.specialattribute
end

local function clearData(actor)
	local var = LActor.getDynamicVar(actor)
	if var ~= nil and var.specialattribute ~= nil then 
		var.specialattribute = nil
	end

end

function get(actor,type,sysType)
	local var = getData(actor)
	return var and var.sum and var.sum[type] or 0
end

function set(actor,type,value)
	local var = getData(actor)
	if var ~= nil and var.sum ~= nil then 
		var.sum[type] = value
	end
end

function add(actor,type,value,sysType) 
	local var = getData(actor) 
	if var ~= nil then
		var.sum = var.sum or {}
		var.sum[type] = (var.sum[type] or 0) + value
		--
		var.sub = var.sub or {}
		var.sub[sysType] = var.sub[sysType] or {}
		var.sub[sysType][type] = (var.sub[sysType][type] or 0) + value
	end
end

function getBySysType(actor,sysType)
	local var = getData(actor)
	if var and var.sub and var.sub[sysType] then
		return var.sub[sysType][expEx] or 0, var.sub[sysType][goldEx] or 0
	end
	return 0,0
end

function updateAttribute(actor)
	clearData(actor)
	monthcard.updateAttributes(actor, monthcardSys)
	fuwensystem.updateAttributes(actor, fuwenSys)
	tujiansystem.updateAttributes(actor, tujianSys)
	imbasystem.updateAttributes(actor, imbaSys)
end


local function onBeforeLogin(actor) 
	updateAttribute(actor)
end

actorevent.reg(aeInit,onBeforeLogin)



