module("refinesystem", package.seeall)

local function getData(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then 
		return nil
	end
	if var.refinesystem == nil then
		var.refinesystem      = {}
		var.refinesystem.exp  = 1
	end


	return var.refinesystem
end


local function getSurplusTime(actor)
	local createTime = LActor.getCreateTime(actor) + (8 * 60 * 60)
	local openTime = RefinesystemBasicConfig.openHour * (60 * 60)
	local currTime = os.time() + (8 * 60 * 60)
	local sub = currTime - createTime
	if sub <= openTime then 
		return openTime - sub
	else 
		return 0
	end
end

local function isOpen(actor) 
	if LActor.getVipLevel(actor) < RefinesystemBasicConfig.openVipLevel then 
		return false
	end
	if getSurplusTime(actor)  == 0 then 
		return false
	end
	return true
end

local function changeExp(actor) 
	if isOpen(actor) == false then 
		print("refinesystem.changeExp not open")
		return false
	end
	local var = getData(actor) 
	if var == nil then 
		print(LActor.getActorId(actor).."refinesystem.changeExp not data")
		return false
	end
	if RefinesystemExpConfig[var.exp] == nil then 
		print(LActor.getActorId(actor).."refinesystem.changeExp not config " .. var.exp)
		return false
	end
	local config = RefinesystemExpConfig[var.exp]
	local needMoney = config.yuanBao
	if needMoney > LActor.getCurrency(actor, NumericType_YuanBao) then
		print(LActor.getActorId(actor).."refinesystem.changeExp not yuanBao")
		return false
	end
	LActor.changeYuanBao(actor, 0-needMoney, "refinesystem exp")
	var.exp = var.exp + 1
	actorexp.addExp(actor,config.exp,"refinesystem exp")
	return true
end

--net 

local function sendRefinesystemData(actor) 
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Refinesystem, Protocol.sRefinesystemCmd_RefinesystemData)
	if npack == nil then 
		return 
	end
	LDataPack.writeUInt(npack,getSurplusTime(actor))
	local var = getData(actor)
	LDataPack.writeInt(npack,var.exp)
	LDataPack.flush(npack)
end


local function onRefine(actor,packet) 
	changeExp(actor) 
	sendRefinesystemData(actor)
end

local function onLogin(actor) 
	--changeExp(actor)
	sendRefinesystemData(actor)
	--[[
	if getSurplusTime(actor) ~= 0 then 
		LActor.postScriptEventEx(actor, getSurplusTime(actor) * 1000 , sendRefinesystemData,0, 1,actor)
		print("-=-=-=-=-=-=-=-=- ")
		print(getSurplusTime(actor) * 1000)
	end
	]]
end


netmsgdispatcher.reg(Protocol.CMD_Refinesystem, Protocol.cRefinesystemCmd_Refine, onRefine)
actorevent.reg(aeUserLogin, onLogin)






--这个工能已经干掉
