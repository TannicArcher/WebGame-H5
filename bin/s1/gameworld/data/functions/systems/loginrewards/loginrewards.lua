--7天登陆
module("loginrewards",package.seeall)


--[[
--个人数据
loginRewardsData = {

	short login_day -- 登陆的天数
	int login_time -- 登陆时间
	int is_get_reward -- 是否已经得到奖励按位算
}
]]
local day_sec      = 24 * (60 * 60)


local function initLoginRewardsData(actor)

	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return 
	end

	if var.loginRewardsData == nil then 
		var.loginRewardsData = {}
		var.loginRewardsData.login_day = 1
		var.loginRewardsData.login_time = System.getNowTime()  
		var.loginRewardsData.is_get_reward = 0  
	end
end

local function initnextLoginRewardsData(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil ) then
		return
	end

	if var.nextloginRewardData == nil then
		var.nextloginRewardData = {}
		var.nextloginRewardData.login_time = System.getNowTime() + day_sec
		var.nextloginRewardData.is_get_reward = 0  
		print("var.nextloginRewardData.login_time:"..System.getNowTime().."day_sec:"..day_sec)
	end
end

local function getLoginRewardsData(actor)
	initLoginRewardsData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	return var.loginRewardsData
end

local function getnextLoginRewardsData(actor)
	initnextLoginRewardsData(actor)
	local var = LActor.getStaticVar(actor)
	if (var == nil ) then
		return nil 
	end
	return var.nextloginRewardData
end

local  function sendLoginRewardData( actor )
	if actor == nil then 
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetLoginRewardDataResult)
	if npack == nil then 
		return
	end
	local data = getLoginRewardsData(actor)
	LDataPack.writeShort(npack,data.login_day)
	LDataPack.writeInt(npack, data.is_get_reward)
	LDataPack.flush(npack)
end

local function sendNextLoginRewardData(actor )
	if actor == nil then 
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetNextLoginRewardDataResult)
	if npack == nil then 
		return
	end
	local data = getnextLoginRewardsData(actor)
	LDataPack.writeInt(npack, data.is_get_reward)
	LDataPack.flush(npack)
end

local function updateLoginRewardData(actor)

	local data = getLoginRewardsData(actor)
	if not System.isSameDay(data.login_time,System.getNowTime())  and 
		data.login_day <= LoginRewardsBasicConfig.maxDay 
	then 
		data.login_time = System.getNowTime() 
		data.login_day = data.login_day + 1
	end
end

local function updatenextdayloginData(actor)
	local data = getnextLoginRewardsData(actor)
	if (System.isSameDay(data.login_time,System.getNowTime())) and data.is_get_reward ~= 2 then
		data.is_get_reward = 1
	elseif(not System.isSameDay(data.login_time,System.getNowTime()) and System.getNowTime() > data.login_time and data.is_get_reward ~= 1) then
		data.is_get_reward = 2
	end
end

local function getLoginRewards(actor,day)
	if day > LoginRewardsBasicConfig.maxDay then 
	--	print(1)
		return false
	end
	local data = getLoginRewardsData(actor) 
	if data.login_day < day then 
	--	print(2)
		return false
	end

	if System.bitOPMask(data.is_get_reward,day) then 
	--	print(3)
		return false
	end

	if LoginRewardsConfig[day] == nil then 
	--	print(4)
		return false
	end
	
	local tmp = LoginRewardsConfig[day].rewards or {}

	if LActor.canGiveAwards(actor,tmp) == false then
	--	print(5)
		return false
	end

	--print("-------------------")
	--print(utils.t2s(LoginRewardsConfig[day]))
	LActor.giveAwards(actor, tmp, "login Reward")
	--print("get   -------------------")
	data.is_get_reward = System.bitOpSetMask(data.is_get_reward,day,true)
	return true
end


local function getnexLoginRewardsData(actor)
	local data = getnextLoginRewardsData(actor)
	if (data == nil) then
		return false
	end
	print("data.is_get_reward:"..data.is_get_reward)
	if (data.is_get_reward ~= 1) then
		LActor.sendTipmsg(actor,"不满足领取条件",ttMessage)
		return false
	end

	
	local tmp = NextLoginRewardsConfig.rewards or {}

	if LActor.canGiveAwards(actor,tmp) == false then
		LActor.sendTipmsg(actor,"背包不足",ttMessage)
		return false
	end

	data.is_get_reward = 2
	LActor.giveAwards(actor, tmp, "login Reward")
	return true
end
---net 
--

local function onGetLoginReward(actor, packet)

	local data = getLoginRewardsData(actor)
	local day = LDataPack.readInt(packet) 

	local ret = getLoginRewards(actor,day)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetLoginRewardResult)
	if npack == nil then 
		return 
	end
	LDataPack.writeByte(npack,ret and 1 or 0) 
	if ret then 
		LDataPack.writeShort(npack,day)
		LDataPack.writeInt(npack,data.is_get_reward)
	end
	LDataPack.flush(npack)

end

local function onNextGetLoginReward(actor)
	local ret = getnexLoginRewardsData(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_GetNextLoginRewardResult)
	if npack == nil then 
	return 
	end
	LDataPack.writeShort(npack,ret and 1 or 0) 
	LDataPack.flush(npack)
end

--net end

local function onLogin(actor)
	--print(" loginRewards  onLogin ------------------------------")
	initLoginRewardsData(actor)
	initnextLoginRewardsData(actor)
	updateLoginRewardData(actor)
	sendLoginRewardData(actor)
	updatenextdayloginData(actor)
	sendNextLoginRewardData(actor)
--	getLoginRewards(actor,1)

	
	--sendLoginRewardData(actor)
end

local function onNewDay(actor)
	updateLoginRewardData(actor)
	sendLoginRewardData(actor)
	updatenextdayloginData(actor)
	sendNextLoginRewardData(actor)
end

local function init()

	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeUserLogin, onLogin)
	netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetLoginReward, onGetLoginReward)
	netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_GetNextLoginReward, onNextGetLoginReward)
end

table.insert(InitFnTable, init)







