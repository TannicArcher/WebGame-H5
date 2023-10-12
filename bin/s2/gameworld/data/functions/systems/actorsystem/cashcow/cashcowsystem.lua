-- 摇钱树
module("cashcowsystem", package.seeall)

--初始值
local cashCowVarDef = 
{
	--当天已使用次数
	curDayTime = 0,
	--增幅等级
	ampLv     = 1,
	--经验值
	exp       = 0,
	--宝箱次数
	boxTime   = 0,
	--宝箱领取位集
	boxMask   = 0,
}


local function getCashCowVar(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if var.cashCowVar == nil then
		var.cashCowVar            = {}
		var.cashCowVar.curDayTime = cashCowVarDef.curDayTime
		var.cashCowVar.boxTime    = cashCowVarDef.boxTime
		var.cashCowVar.boxMask    = cashCowVarDef.boxMask
		var.cashCowVar.ampLv      = cashCowVarDef.ampLv
		var.cashCowVar.exp        = cashCowVarDef.exp
	end

	return var.cashCowVar
end

local function checkShakeCondition(actor) 
	local var = getCashCowVar(actor) 
	if var == nil then 
		return false
	end


	local config
	--检查vip等级次数
	local vipLv = LActor.getVipLevel(actor)
	config = cashcowcommon.getLimitConfig(vipLv)
	if config == nil then 
		return false
	end
	if var.curDayTime >= config.maxTime then
		log_print(LActor.getActorId(actor) .. " cashcowsystem.checkShakeCondition: time " .. var.curDayTime .. ":" .. config.maxTime)
		return false
	end

	--检查下一次消耗元宝是否足够
	local nextTime = var.curDayTime + 1
	if nextTime > cashcowcommon.getMaxBasicConfig() then return end
	config = cashcowcommon.getBasicConfig(nextTime)
	if config == nil then
		return false
	end
	if config.yuanbao > LActor.getCurrency(actor, NumericType_YuanBao) then
		log_print(LActor.getActorId(actor) .. " cashcowsystem.checkShakeCondition: yuanbao " .. config.yuanbao .. ":" .. LActor.getCurrency(actor, NumericType_YuanBao))
		return false
	end

	--
	if cashcowcommon.getAmplitudeConfig() == nil then
		return false
	end
	log_print(LActor.getActorId(actor) .. " cashcowsystem.checkShakeCondition: ok" )

	return true
end

local function calcCurCrit(actor) 
	local vipLv = LActor.getVipLevel(actor)
	local limitconfig = cashcowcommon.getLimitConfig(vipLv)
	local rate = 1
	local result = 0
	local rand = math.random(1,100)
	for _, info in ipairs(limitconfig.crit) do
		result = result + info.odds
		if result >= rand then
			return info.rate
		end
	end
	return rate
end

local function updateAmpLv(actor)
	local amplitudeConfig = cashcowcommon.getAmplitudeConfig()
	local var = getCashCowVar(actor)
	local nextAmpLv = var.ampLv + 1
	if nextAmpLv > #amplitudeConfig then return end
	if var.exp >= amplitudeConfig[nextAmpLv].needExp then
		var.ampLv = var.ampLv + 1
		var.exp = var.exp - amplitudeConfig[nextAmpLv].needExp
	end
end

local function calcCurAmplitude(ampLv)
	local amplitudeConfig = cashcowcommon.getAmplitudeConfig()
	local rate = amplitudeConfig[ampLv].rate/100
	return rate
end

local function sendShakeResult(actor,crit)
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sCashCowCmd_Shake)
	if npack == nil then 
		return 
	end
	local var = getCashCowVar(actor)
	LDataPack.writeData(npack, 5,
						dtShort, var.curDayTime,
						dtShort, var.boxTime,
						dtShort, var.ampLv,
						dtShort, var.exp,
						dtShort, crit)
						-- dtShort, reserve)
	LDataPack.flush(npack)
end

local function handleShake(actor)
	-- 检查
	if not checkShakeCondition(actor) then
		return
	end

	-- update
	local var = getCashCowVar(actor)
	local nextTime = var.curDayTime + 1
	local config = cashcowcommon.getBasicConfig(nextTime)
	LActor.changeYuanBao(actor, -config.yuanbao, "cashcowsystem handleShake")

	-- 玩家每次使用摇钱树获得的金币=基础金币数x增幅倍数x暴击倍率
	local gold = config.gold
	local amp = calcCurAmplitude(var.ampLv)
	local crit = calcCurCrit(actor)
	gold = gold * amp * crit
	LActor.changeGold(actor, gold, "cashcowsystem handleShake")

	var.curDayTime = var.curDayTime + 1
	var.boxTime = var.boxTime + 1
	var.exp = var.exp + 1

	updateAmpLv(actor)

	-- 回包
	sendShakeResult(actor,crit)
end

local function checkGetBoxCondition(actor) 
	local var = getCashCowVar(actor)
	if var == nil then
		return false
	end

	if cashcowcommon.getBoxConfig() == nil then
		return false
	end

	return true
end

local function sendGetBoxResult(actor)
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sCashCowCmd_GetBox)
	if npack == nil then 
		return 
	end
	local var = getCashCowVar(actor)
	LDataPack.writeInt(npack,var.boxMask)
	LDataPack.flush(npack)
end

local function handleGetBox(actor, index)
	if not checkGetBoxCondition(actor) then
		return
	end

	boxConfig = cashcowcommon.getBoxConfig()
	if boxConfig[index] == nil then return end

	local var = getCashCowVar(actor)
	if var.boxTime < boxConfig[index].time then 
		return 
	end

	local bitIndex = index - 1
	if System.bitOPMask(var.boxMask, bitIndex) then
	    return
	end

	var.boxMask = System.bitOpSetMask(var.boxMask, bitIndex, true)

	local boxDetailConf = boxConfig[index].box
	for _,gold in ipairs(boxDetailConf) do
		LActor.changeGold(actor, gold, "cashcowsystem handleGetBox")
	end
	
	-- 回包
	sendGetBoxResult(actor)
end

--netmsg

local function onShake(actor,packet)
	handleShake(actor)
end



local function onGetBox(actor,packet)
	local index = LDataPack.readInt(packet)
	handleGetBox(actor, index)
end



function cashCowAllInfoSync(actor)
	local var = getCashCowVar(actor)
	if var == nil then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_CashCow, Protocol.sCashCowCmd_AllInfoSync)
	if pack == nil then return end
	LDataPack.writeData(pack, 5,
						dtShort, var.curDayTime,
						dtShort, var.boxTime,
						dtShort, var.ampLv,
						dtShort, var.exp,
						dtInt,   var.boxMask)
	LDataPack.flush(pack)
end

--actorevent

local function resetCashCowVar(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if var.cashCowVar == nil then return end
	
	var.cashCowVar.curDayTime = cashCowVarDef.curDayTime
	var.cashCowVar.boxTime    = cashCowVarDef.boxTime
	var.cashCowVar.boxMask    = cashCowVarDef.boxMask
end

local function onLogin(actor)
	if actor == nil then return end

	cashCowAllInfoSync(actor)
end

local function onNewDay(actor)
	if actor == nil then return end

	resetCashCowVar(actor)
	cashCowAllInfoSync(actor)
end


netmsgdispatcher.reg(Protocol.CMD_CashCow, Protocol.cCashCowCmd_Shake, onShake)
netmsgdispatcher.reg(Protocol.CMD_CashCow, Protocol.cCashCowCmd_GetBox, onGetBox)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive,onNewDay)


----------


