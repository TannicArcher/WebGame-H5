--勋章系统
module("knighthood", package.seeall)

local function isOpen(actor)
	return imbasystem.checkActive(actor, KnighthoodBasicConfig.actImbaId)
end


local function getKnighthoodData(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then 
		return nil
	end
	if var.knighthood == nil then
		var.knighthood = {}
	end
	return var.knighthood

end

local function getKnighthoodLv(actor)
	local basic_data = LActor.getActorData(actor) 
	return basic_data.knighthood_lv
end

local function setKnighthoodLv(actor, level)
	local basic_data = LActor.getActorData(actor) 
	basic_data.knighthood_lv = level
end

local function isLevelUp(actor)
	if not isOpen(actor) then 
		log_print( LActor.getActorId(actor) .. " knighthood.isLevelUp: not open ")
		return false
	end
	--获取等级
	local level = getKnighthoodLv(actor)
	if level >= #KnighthoodConfig then
		return false;
	end
	if KnighthoodConfig[level] == nil then 
		log_print( LActor.getActorId(actor) .. " knighthood.isLevelUp("..tostring(level).."): not has config ")
		return false
	end

	local achievementIds = KnighthoodConfig[level].achievementIds
	for i,v in pairs(achievementIds or {}) do 
		if not achievetask.isFinish(actor,v.achieveId,v.taskId)then 
			log_print( LActor.getActorId(actor) .. " knighthood.isLevelUp: not finish " .. utils.t2s(v))
			return false
		end
	end
	log_print( LActor.getActorId(actor) .. " knighthood.isLevelUp: ok ")
	return true
end

local function checkNeedStageUp(level)
	local pl = KnighthoodBasicConfig.perLevel
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


local function SendKnighthoodData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Train, Protocol.sTrainCmd_KnighthoodData)
	if npack == nil then 
		return 
	end
	local level = getKnighthoodLv(actor)
	LDataPack.writeInt(npack, level)
	LDataPack.flush(npack)
end

local function loadAttrs(actor) 
	local attr = LActor.getKnighthoodAttr(actor)
	attr:Reset()
	local ex_attr = LActor.getKnighthoodExAttr(actor)
	ex_attr:Reset()
	
	if not isOpen(actor) then 
		return 
	end
	local level = getKnighthoodLv(actor)
	if KnighthoodConfig[level] == nil then 
		return 
	end
	
	for _,v in pairs(KnighthoodConfig[level].attrs or {}) do 
		attr:Set(v.type, v.value)
	end
	
	for _,v in ipairs(KnighthoodConfig[level].exattrs or {}) do
		ex_attr:Add(v.type, v.value)
	end
		
	LActor.reCalcAttr(actor)
	LActor.reCalcExAttr(actor)
end


function updateknighthoodData(actor,addexp)
--[[
	local data = getKnighthoodData(actor)
	if (nil == data) then
		return
	end
	
	data.exp   = data.exp + addexp
	SendKnighthoodData(actor)
]]
end

--[[
local function onLevelUpKnighthood(actor,packet)
	local data = getKnighthoodData(actor)
	local level = data.level

	local conf = KnighthoodConfig[level]
	if not conf then
		print("KnighthoodConfig is error!!!!!!")
		return
	end

	local exp = data.exp
	if exp < conf.costScore then
		--LActor.sendTipmsg(actor,"Lang.ScriptTips.xz001",ttMessage)
		print("================")
		return
	end

	data.level = data.level + 1
	print("LevelUpKnighthood:"..data.level)

	SendKnighthoodData(actor)
	loadAttrs(actor)	
end
]]

--net,客户端请求处理
--local function onStageUpKnighthood(actor,packet)
--	local level = getKnighthoodLv(actor)
--	if (not checkNeedStageUp(level)) then
--		print("onStageUpKnighthood error:"..level..","..KnighthoodBasicConfig.perLevel)
--		return
--	end
--	level = level + 1
--	setKnighthoodLv(actor, level)
--	actorevent.onEvent(actor,aeKnighthoodLv, level)
--	SendKnighthoodData(actor)
--	loadAttrs(actor)
--end

local function onLevelUpKnighthood(actor, packet)
	if isLevelUp(actor) then 
		local level = getKnighthoodLv(actor)
		--if checkNeedStageUp(level) then
		--	return
		--end
		local achievementIds = KnighthoodConfig[level].achievementIds
		for i,v in pairs(achievementIds or {}) do 
			if not v.re or v.re ~= 1 then
				achievetask.finishAchieveTask(actor,v.achieveId,v.taskId)
			end
		end
		level = level + 1
		setKnighthoodLv(actor, level)
		actorevent.onEvent(actor,aeKnighthoodLv,level)
		SendKnighthoodData(actor)
		loadAttrs(actor)
	end
end
--net end
local function onBeforeLogin( actor )
	loadAttrs(actor)
end
local function onLogin(actor)
	SendKnighthoodData(actor)
end

local function onAchievetaskFinish(actor,achieveId,taskId)
	if isLevelUp(actor) then
		SendKnighthoodData(actor)
	end
end

local function onActImba(actor, id)
	if id == KnighthoodBasicConfig.actImbaId then
		SendKnighthoodData(actor)
	end
end

local function init() 
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeActImba, onActImba)
	--actorevent.reg(aeAchievetaskFinish, onAchievetaskFinish)
	actorevent.reg(aeInit,onBeforeLogin)
	netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_LevelUpKnighthood, onLevelUpKnighthood)
	--netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_ReqActKnigthood, onActKnighthood)
	--netmsgdispatcher.reg(Protocol.CMD_Train, Protocol.cTrainCmd_StageUpKnighthood, onStageUpKnighthood)
end
table.insert(InitFnTable, init)

function gmhandle(actor,arg)
	if arg[1] == "lv" then
		local level = tonumber(arg[2])
		setKnighthoodLv(actor, level)
		actorevent.onEvent(actor,aeKnighthoodLv,level)
		SendKnighthoodData(actor)
		loadAttrs(actor)
	elseif arg[1] == "c" then
		local level = getKnighthoodLv(actor)
		local achievementIds = KnighthoodConfig[level].achievementIds
		for i,v in pairs(achievementIds or {}) do 
			achievetask.finishAchieveTask(actor,v.achieveId,v.taskId)
		end		
	end
end
