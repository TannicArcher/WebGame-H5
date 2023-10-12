--开服激活角色奖励
module("loginactivate",package.seeall)


--[[
--个人数据
loginActivateData = {
	status  1表示可以参与领取奖励，0不满足条件
	loginDays  登陆天数，创角开始算
	reward 0未领取，1领取过
}
]]


--获取玩家信息
local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.loginActivateData then var.loginActivateData = {} end

	return var.loginActivateData
end

local function sendData(actor)
	local data = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_RoleActivate, Protocol.sRoleActivateCMD_Info)

	LDataPack.writeByte(npack, data.reward or 0)
	LDataPack.writeShort(npack, data.loginDays or 0)
	LDataPack.writeByte(npack, data.status or 0)

	LDataPack.flush(npack)
end

local function getReward(actor)
	local data = getStaticData(actor)
	local actorId = LActor.getActorId(actor)

	if 0 == (data.status or 0) then print("loginactivate.onGetReward:status illegal, actorId:"..tostring(actorId)) return false end

	if LoginActivateConfig.loginDays > (data.loginDays or 0) then
		print("loginactivate.onGetReward:loginDays not enough, actorId:"..tostring(actorId))
		return false
	end

	if 1 == (data.reward or 0) then print("loginactivate.onGetReward:already reward, actorId:"..tostring(actorId)) return false end

	if not LActor.canGiveAwards(actor, LoginActivateConfig.reward) then
        print("loginactivate.onGetReward:can not give awards,actorId:"..tostring(actorId))
        return false
	end

	LActor.giveAwards(actor, LoginActivateConfig.reward, "roleActivateReward")
	data.reward = 1

	--置为0，不再显示图标了
	data.status = 0

	sendData(actor)

	return true
end

local function onGetReward(actor)
	local isReward = getReward(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_RoleActivate, Protocol.sRoleActivateCMD_Reward)
	LDataPack.writeByte(npack, isReward and 1 or 0)
	LDataPack.flush(npack)
end

local function onLogin(actor)
	local var = System.getStaticVar()
	local data = getStaticData(actor)
	if 1 == (var.loginacctivate or 0) and not data.ischeck then
		if LActor.getVipLevel(actor) >= LoginActivateConfig.vipLevel then data.status = 1 end
		data.ischeck = 1
	end
	sendData(actor)
end

local function onNewDay(actor, login)
	local data = getStaticData(actor)
	data.loginDays = (data.loginDays or 0) + 1

	if not login then sendData(actor) end
end

local function onVipLevelChanged(actor, level)
	local openDay = System.getOpenServerDay() + 1

	--开服天数限制
	if openDay > LoginActivateConfig.openDay then return end

	--vip等级限制
	if level < LoginActivateConfig.vipLevel then return end

	local data = getStaticData(actor)

	--参与过不能再参与
	if 1 == (data.status or 0) then return end

	data.status = 1

	sendData(actor)
end

local function initGlobalData()
	local sys = System.getStaticVar()
	if not sys.loginacctivate then
		local openDay = System.getOpenServerDay() + 1
		if openDay <= LoginActivateConfig.openDay then
			sys.loginacctivate = 1
		else
			sys.loginacctivate = 0
		end
	end

	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeUpdateVipInfo, onVipLevelChanged)

	netmsgdispatcher.reg(Protocol.CMD_RoleActivate, Protocol.cRoleActivateCMD_Reward, onGetReward)
end

table.insert(InitFnTable, initGlobalData)

function test(actor, args)
	if 1 == tonumber(args[1]) then
		local data = getStaticData(actor)
		data.loginDays = LoginActivateConfig.loginDays
	elseif 2 == tonumber(args[1]) then
		getReward(actor)
	end
end

function setFlag(flag)
	local sys = System.getStaticVar()
	sys.loginacctivate = flag
end
