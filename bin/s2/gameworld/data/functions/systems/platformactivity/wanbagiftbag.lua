module("wanbagiftbag", package.seeall)





local refresh_sec = (60*60) * 21
local day_sec = (60*60) * 24



local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.wanbagiftbag == nil then 
		var.wanbagiftbag = {}
	end
	if var.wanbagiftbag.time == nil then 
		var.wanbagiftbag.time = 0
	end
	return var.wanbagiftbag
end








local function isGetGiftbag(actor) 
	local var = getData(actor)
	local curr_time = os.time()
	if var.time == 0 then 
		return true
	end
	if curr_time >= var.time then 
		return true
	end
	return false

end




local function getGiftbag(actor)
	-- print("+++++++++++++++++++++++++++++++++++++ getGiftbag")
	if isGetGiftbag(actor) then
		local var = getData(actor)
		--
		local add = 0
		local curr_time = os.time()
		if ((curr_time + System.getTimeZone()) % day_sec) >= refresh_sec  then
			add = 1
		else 
			add = 0
		end
		var.time = ((utils.getDay(curr_time) + add) * day_sec) - System.getTimeZone()
		var.time = var.time + refresh_sec
		local conf = WanBaGiftbagBasic[utils.getWeek(var.time)]
		if conf == nil then
			-- print("not conf " .. utils.getWeek(var.time))
			return false
		end
		LActor.giveAwards(actor,conf.items,"wanba giftbag")
		-- print("get awards " .. utils.getWeek(var.time))
		return true
	end

	return false
end





--net 
--
--
local function onGetGiftbag(actor,packet)
	local ret = getGiftbag(actor) 
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PlatformActivity, Protocol.sPlatformActivityCmd_GetGiftbag)
	if npack == nil then 
		return
	end
	LDataPack.writeByte(npack,utils.getWeek(var.time ))
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.flush(npack)
end


local function onLogin(actor)
--	getGiftbag(actor)
end


actorevent.reg(aeUserLogin, onLogin)


netmsgdispatcher.reg(Protocol.CMD_PlatformActivity, Protocol.cPlatformActivityCmd_GetGiftbag, onGetGiftbag)
