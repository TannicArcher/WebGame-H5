--玉佩系统
module("yupei", package.seeall)
--判断系统是否开启
local function isOpen(actor)
	return LActor.getLevel(actor) >= YuPeiBasicConfig.openLv
end
--[[玩家静态数据
	lv = 玉佩等级
]]
local function getYuPeiData(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then 
		return nil
	end
	if var.yupei == nil then
		var.yupei = {}
	end
	return var.yupei

end
--获取玉佩等级
local function getYuPeiLv(actor)
	local data = getYuPeiData(actor) 
	return data.lv or 0
end
--设置玉佩等级
local function setYuPeiLv(actor, level)
	local data = getYuPeiData(actor) 
	data.lv = level
end

local function isLevelUp(actor)
	if not isOpen(actor) then 
		print( LActor.getActorId(actor) .. " yupei.isLevelUp: not open ")
		return false
	end
	--获取等级
	local level = getYuPeiLv(actor)
	if level >= #YuPeiConfig then
		return false;
	end
	local config = YuPeiConfig[level]
	if  not config then 
		print( LActor.getActorId(actor) .. " yupei.isLevelUp("..tostring(level).."): not has config ")
		return false
	end
	if config.item_id and config.count then
		--检测消耗
		if LActor.getItemCount(actor,config.item_id) < config.count then
			return false
		end
		--扣除消耗
		LActor.costItem(actor, config.item_id, config.count, "yupei")
	end
	return true
end

--检测是否需要升阶
local function checkNeedStageUp(level)
	local pl = YuPeiBasicConfig.perLevel
	if (level-pl)%(pl+1) == 0 then
		return true
	end
	--[[ 阶级通项公式推倒过程,0级开始的情况
		0 - 1-2 -3- 4- 5- 6- 7- 8- 9->  10 = 10 + (1-1) * 11
		11-12-13-14-15-16-17-18-19-20-> 21 = 10 + (2-1) * 11
		22-23-24-25-26-27-28-29-30-31-> 32 = 10 + (3-1) * 11
		(当前等级 - N级每阶(10))/(N级每阶(9)+1) + 1 = 阶数
		0 --> 9  = 9 + (1 - 1) * 10 ==> 1 = (9-9)/10 + 1
		10--> 19 = 9 + (2 - 1) * 10 ==> 2 = (19-9)/10 + 1
		20--> 29 = 9 + (3 - 1) * 10 ==> 3 = (29-9)/10 + 1
		(当前等级 - N级每阶(9))/(N级每阶(9)+1) + 1 = 阶数
		得出:
		(当前等级 - N级每阶(9))%(N级每阶(9)+1) == 0 为需要升阶等级
		向上取整((当前等级 - N级每阶的配置) / (N级每阶的配置 + 1) + 1) = 阶数 (0阶开始的时候需要 阶数-1)
		当前等级 - (N级每阶的配置 + (阶数-2)*(N级每阶的配置+1) + 1) = 星数
		eq:
			(0-9)%(9+1) !== 0  (0-10)%(10+1) !== 0
			(9-9)%(9+1)  == 0  (32-10)%(10+1) == 0
	]]
	return false
end

--下发玉佩数据
local function SendYuPeiData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Train, Protocol.sTrainCmd_YuPeiData)
	if npack == nil then 
		return 
	end
	local level = getYuPeiLv(actor)
	LDataPack.writeInt(npack, level)
	LDataPack.flush(npack)
end

--玉佩属性
local function loadAttrs(actor) 
	local attr = LActor.getYuPeiAttr(actor)
	attr:Reset()
	local ex_attr = LActor.getYuPeiExAttr(actor)
	ex_attr:Reset()
	
	if not isOpen(actor) then return end
	local level = getYuPeiLv(actor)
	if YuPeiConfig[level] == nil then 
		return 
	end
	
	for _,v in pairs(YuPeiConfig[level].attrs or {}) do 
		attr:Set(v.type, v.value)
	end
	
	for _,v in ipairs(YuPeiConfig[level].exattrs or {}) do
		ex_attr:Add(v.type, v.value)
	end
		
	LActor.reCalcAttr(actor)
	LActor.reCalcExAttr(actor)
end

--请求升级玉佩
local function onLevelUpYuPei(actor, packet)
	if isLevelUp(actor) then 
		local level = getYuPeiLv(actor)
		level = level + 1
		setYuPeiLv(actor, level)
		actorevent.onEvent(actor,aeYuPeiLv,level)
		SendYuPeiData(actor)
		loadAttrs(actor)
		LActor.SetYuPeiLv(actor, level)
	end
end

--初始化时候的回调
local function onInit(actor)
	loadAttrs(actor)
	--同步等级到C++,战斗逻辑需要
	LActor.SetYuPeiLv(actor, getYuPeiLv(actor))
end

--登陆回调
local function onLogin(actor)
	SendYuPeiData(actor)
end

--初始化
local function init() 
	actorevent.reg(aeInit,onInit)
	actorevent.reg(aeUserLogin, onLogin)
	netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_LevelUpYuPei, onLevelUpYuPei)
end
table.insert(InitFnTable, init)

--yupei
function gmhandle(actor,arg)
	if arg[1] == 'lv' then
		onLevelUpYuPei(actor, nil)
	end
end
