module("wingsystem", package.seeall)

--计算清空经验时间
local function calcClearTime(actor, roleId)
	local level, exp, status, ctime = LActor.getWingInfo(actor, roleId)
	if (not level) then
		return
	end
	--翅膀状态，还没激活的话
	if (status == 0) then
		return
	end
	if exp <= 0 then
		return
	end
	--获取当前等级配置
	local config = wingcommon.getWingLevelConfig(level)
	if (not config) then
		return
	end
	--是否需要清空经验
	if not config.clearTime or config.clearTime <= 0 then
		return
	end
	--如果没有清空时间
	if ctime <= 0 then
		LActor.setWingCTime(actor, roleId, System.getNowTime()+config.clearTime)
		return true
	end
	return true
end

--翅膀升级的时候调用
local function OnWingLevelUp(actor, roleId, oldLevel, level)
	local role = LActor.getRole(actor, roleId)
	if not role then return end
	for lv = oldLevel+1,level do
		local conf = WingLevelConfig[lv]
		if conf.pasSkillId then
			LActor.AddPassiveSkill(role, conf.pasSkillId)
		end
	end
	--升级时候重置清空时间
	LActor.setWingCTime(actor, roleId, 0)
end

-- 活动增加经验
local function getActivityExp(  )
	local times
	for activityID,rates in pairs(WingCommonConfig.activityRate or {}) do
		if not activitysystem.activityTimeIsEnd(activityID) then
			local totalRate = 0
			for _,v in pairs(rates or {}) do totalRate = totalRate + v.rate end
			if totalRate > 0 then
				local rnd = math.random(1, totalRate)
				local tTotal = 0
				for _,v in pairs(rates or {}) do
					tTotal = tTotal + v.rate
					if rnd <= tTotal then times = (times or 0) + v.times break end
				end
			end
		end
	end
	return times
end

--高级培养的处理函数
local wingSpecialTrain = function (actor, roleId, useYb)
	local level, exp, status = LActor.getWingInfo(actor, roleId)
	if (not level) then
		return
	end

	--翅膀状态，还没激活的话，不给培养
	if (status == 0) then
		return
	end
	--获取当前等级配置
	local config = wingcommon.getWingLevelConfig(level)
	if (not config) then
		return false
	end
	--检查是不是已经满级
	if (wingcommon.isMaxLv(level)) then
		return
	end

	--判断资源是否满足
	local needItem = 0 --扣除道具个数
	local needYb = 0 --扣除元宝的个数
	local curCount = LActor.getItemCount(actor, config.itemId)
	if curCount >= config.itemNum then
		needItem = config.itemNum
	elseif useYb then
		needItem = curCount
		needYb = (config.itemNum - curCount) * config.itemPrice
		local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao) --当前元宝数
		if (needYb > curYuanBao) then --元宝也不够
			print("wingSpecialTrain: useYb yuanbao is not enough")
			return
		end	
	else
		print("wingSpecialTrain: not useYb item is not enough")
		return
	end
	--扣除消耗
	if needItem > 0 then
		LActor.costItem(actor, config.itemId, needItem, "wing train")
	end
	if needYb > 0 then
		LActor.changeYuanBao(actor, -needYb, "wing train")
	end
	--培养事件
	actorevent.onEvent(actor, aeWingTrain, 1)
	--判断是否一下子升级
	if config.oneKeyLvUpExpPer and config.oneKeyLvUpExpPer <= (exp/config.exp * 100) then
		if math.random(1,100) <= config.oneKeyLvUp then
			LActor.setWingLevel(actor, roleId, level+1)
			LActor.setWingExp(actor, roleId, 0)
			actorevent.onEvent(actor, aeWingLevelUp, roleId, level+1)
			--翅膀升级事件
			OnWingLevelUp(actor, roleId, level, level+1)
			updateAttr(actor, roleId)
			wingTrainResuleSync(actor, roleId, 0, 0)
			return
		end
	end
	--计算正常涨经验
	local expAddition = wingcommon.getExpTimes(specialType, level)

	-- 活动涨经验
	local actExtraExp = getActivityExp()
	if actExtraExp then
		expAddition = ((expAddition or 0) + (config.specialBaseExp or 0)) * actExtraExp - (config.specialBaseExp or 0)
	end
	
	addExp(actor, roleId, config.specialBaseExp or 0, expAddition)
	--计算清空经验时间
	calcClearTime(actor, roleId)
	updateAttr(actor, roleId)
	--给客户端回包
	wingTrainResuleSync(actor, roleId, (config.specialBaseExp or 0) + expAddition, expAddition, actExtraExp)
end

--======================================================================
--增加经验接口
function addExp(actor, roleId, addExp, expAddition)
	expAddition = expAddition or 0
	addExp = addExp + expAddition

	local level, exp, status = LActor.getWingInfo(actor, roleId)
	if (not level) then
		return
	end

	--翅膀状态，还没激活的话，不给培养
	if (status == 0) then
		return
	end
	--是否最大等级了
	if (wingcommon.isMaxLv(level)) then
		return 
	end
	--获取当前等级配置
	local levelConfig = wingcommon.getWingLevelConfig(level)
	if (not levelConfig) then
		return 
	end
	--记录旧等级
	local exLevel = level
	exp = exp + addExp --获取最新经验
	while (exp >= levelConfig.exp) do
		exp = exp - levelConfig.exp

		--加等级
		level = level + 1

		System.logCounter(LActor.getActorId(actor),
			LActor.getAccountName(actor),
			tostring(LActor.getLevel(actor)),
			"wing levelup", 
			tostring(level),
			"","","", "", "")

		--检查是不是到了需要升级的星级，是的话把经验置零，升级了再继续加经验
		-- if (wingcommon.checkNeedLevelUp(level, star)) then
		-- 	exp = 0
		-- 	break
		-- end

		--到达最大等级的话，就不加了
		if (wingcommon.isMaxLv(level)) then
			exp = 0
			break 
		end

		levelConfig = wingcommon.getWingLevelConfig(level)
		if (not levelConfig) then
			break 
		end	
	end

	--改变经验
	LActor.setWingExp(actor, roleId, exp)

	--星级变化的话才改属性和星级
	if (exLevel ~= level) then
		LActor.setWingLevel(actor, roleId, level)
		--actorevent.onEvent(actor, aeWingStarUp, roleId, star - exStar)
		actorevent.onEvent(actor, aeWingLevelUp, roleId, level)
		--翅膀升级事件
		OnWingLevelUp(actor, roleId, exLevel, level)
		updateAttr(actor, roleId)
	end
end

--属性更新
function updateAttr(actor, roleId)
	--先清空翅膀系统的属性
	LActor.clearWingAttr(actor, roleId)

	addWingAttr(actor, roleId)
	--刷新角色属性
	LActor.reCalcRoleAttr(actor, roleId)
end
_G.updateWingAttr = updateAttr

--添加翅膀的属性
function addWingAttr(actor, roleId)
	local level, exp, status, ctime, p0, p1 = LActor.getWingInfo(actor, roleId)
	if (not level) then
		return
	end

	--翅膀状态，还没激活的话，不给培养
	if (status == 0) then
		return
	end
	--获取等级配置
	local levelConfig = wingcommon.getWingLevelConfig(level)
	if (not levelConfig) then
		return 
	end

	--计算神羽额外加成属性，飞升丹额外加成
	local precent = godwingsystem.getPrecent(actor, roleId) + p1 * WingCommonConfig.flyPill

	--增加属性
	for _,tb in pairs(levelConfig.attr) do
		LActor.addWingAttr(actor, roleId, tb.type, tb.value + math.floor(tb.value*precent/10000))
	end

	--资质丹
	if p0 > 0 then
		for _,tb in pairs(WingCommonConfig.attrPill or {} ) do
			LActor.addWingAttr(actor, roleId, tb.type, tb.value * p0)
		end
	end

	--飞升丹
	if p1 > 0 then
		for _,tb in pairs(WingCommonConfig.flyPillAttr or {} ) do
			LActor.addWingAttr(actor, roleId, tb.type, tb.value * p1)
		end
	end
	
	--if ctime > 0 then
		local nextCfg = wingcommon.getWingLevelConfig(level+1)
		if nextCfg then
			for _,tb in pairs(nextCfg.attr or {}) do
				local value = ((exp/levelConfig.exp)*((WingCommonConfig.tempattr or 0)*tb.value))
				LActor.addWingTempAttr(actor, roleId, tb.type, value)
			end
		end
	--end
end

--培养的回包
function wingTrainResuleSync(actor, roleId, addExp, expAddition, actExtraExp)
	local level, exp, status, ctime = LActor.getWingInfo(actor, roleId)
	if (not level) then
		return
	end

	--翅膀状态，还没激活的话，不给培养
	if (status == 0) then
		return
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_ReqTrain)
	if pack == nil then return end

	LDataPack.writeData(pack, 6,
						dtShort, roleId,
						dtInt, level,
						dtUint, exp,
						dtInt, addExp,
						dtUint, ctime,
						dtShort, actExtraExp or 0)
	LDataPack.flush(pack)	
end

--翅膀开启
function wingOpen(actor, roleId)
	local level, exp, status = LActor.getWingInfo(actor, roleId)
	if (not level) then
		return
	end	

	--翅膀状态，激活了的就不再激活了
	if (status == 1) then
		return
	end	

	LActor.setWingStatus(actor, roleId, 1)
	status = 1
	
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_ReqOpen)
	if pack == nil then return end

	LDataPack.writeData(pack, 2,
						dtShort, roleId,
						dtInt, status
						)
	LDataPack.flush(pack)	

	actorevent.onEvent(actor, aeWingLevelUp, roleId, level)
	--更新属性
	updateAttr(actor, roleId)
end

--学习被动技能,只在登陆时候初始化
local function LearnPassiveSkills(actor, roleId)
	local role = LActor.getRole(actor, roleId)
	if not role then return end
	local level, exp, status = LActor.getWingInfo(actor, roleId)
	if not level then return end
	for _,conf in pairs(WingLevelConfig) do
		if conf.level <= level and conf.pasSkillId then
			LActor.AddPassiveSkill(role, conf.pasSkillId)
		end
	end
end

--玩家登陆回调
function onLogin(actor)
	local count = LActor.getRoleCount(actor)
	for roleId=0,count-1 do
		--同步数据
		wingInfoSync(actor, roleId)
		--学习被动技能
		LearnPassiveSkills(actor, roleId)
	end
end

function wingAttrInit(actor, roleId)
	--先清空翅膀系统的属性
	LActor.clearWingAttr(actor, roleId)

	addWingAttr(actor, roleId)
end

--_G.wingAttrInit = wingAttrInit

--数据同步的接口
function wingInfoSync(actor, roleId)
	LActor.wingInfoSync(actor, roleId)
end

local function useItemWingLvUp(actor, roleId)
	local level, exp, status, ctime = LActor.getWingInfo(actor, roleId)
	--翅膀状态，还没激活的话
	if (status == 0) then
		return
	end
	if wingcommon.isMaxLv(level) then
		return
	end
	if not LActor.checkItemNum(actor, WingCommonConfig.levelItemid, 1,false) then 
		print(LActor.getActorId(actor) .. " wingsystem.useItemWingLvUp is no item:" .. WingCommonConfig.levelItemid )
		return
	end
	
	LActor.consumeItem(actor, WingCommonConfig.levelItemid, 1, false, "useItemWingLvUp")
	
	if (level+1) < WingCommonConfig.levelItemidStage then
		local newLv = level + 1
		if newLv > #WingLevelConfig then
			newLv = #WingLevelConfig
		end
		LActor.setWingLevel(actor, roleId, newLv)
		LActor.setWingExp(actor, roleId, 0)
		actorevent.onEvent(actor, aeWingLevelUp, roleId, newLv)
		--翅膀升级事件
		OnWingLevelUp(actor, roleId, level, newLv)
		--计算清空经验时间
		calcClearTime(actor, roleId)	
		updateAttr(actor, roleId)
		wingTrainResuleSync(actor, roleId, 0, 0)
		print(LActor.getActorId(actor).." wingsystem.useItemWingLvUp roleId:"..roleId..",newLv:"..newLv..",level:"..level)
	else
		LActor.giveAwards(actor, WingCommonConfig.levelExpChange, "useItemWingLvUp")
	end
end

--请求使用直升多少级丹
local function useItemUp_c2s(actor, pack)
	local roleId = LDataPack.readByte(pack)
	useItemWingLvUp(actor, roleId)
end

--客户端培养的回调
function wingTrain_c2s(actor, pack)
	local roleId = LDataPack.readShort(pack)
	local useYb = LDataPack.readByte(pack)
	
	wingSpecialTrain(actor, roleId, (useYb~=0) and true	or false)
end

--请求激活翅膀
function wingOpen_c2s(actor, pack)
	if (LActor.getLevel(actor) < WingCommonConfig.openLevel) then
		return
	end

	local roleId = LDataPack.readShort(pack)
	wingOpen(actor, roleId)
end

local function onReqUsePill(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local pillId = LDataPack.readChar(packet)

	local level, exp, status, ctime, p0, p1 = LActor.getWingInfo(actor, roleId)
	if not level then return end
	if not status or status == 0 then return end

	local pillCount = 0

	--获取当前等级配置
	local config = WingLevelConfig[level]
	if not config then return end

	if pillId == 0 then
		--资质丹
		if p0 >= config.attrPill then
			LActor.sendTipmsg(actor, "已到达上限", ttMessage)
			return
		end
		--检查材料
		if LActor.getItemCount(actor, WingCommonConfig.attrPillId) <= 0 then
			LActor.sendTipmsg(actor, "物品不够", ttMessage)
			return
		end
		--扣材料
		LActor.costItem(actor, WingCommonConfig.attrPillId, 1, "wingsystem onReqUsePill")
		pillCount = p0 + 1
		LActor.setWingPill(actor, roleId, pillId, pillCount)
	elseif pillId == 1 then
		--飞升丹
		if p1 >= config.flyPill then
			LActor.sendTipmsg(actor, "已到达上限", ttMessage)
			return
		end
		--检查材料
		if LActor.getItemCount(actor, WingCommonConfig.flyPillId) <= 0 then
			LActor.sendTipmsg(actor, "物品不够", ttMessage)
			return
		end
		--扣材料
		LActor.costItem(actor, WingCommonConfig.flyPillId, 1, "wingsystem onReqUsePill")
		pillCount = p1 + 1
		LActor.setWingPill(actor, roleId, pillId, pillCount)
	else
		return
	end

	updateAttr(actor, roleId)
	--给客户端回包
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Wing, Protocol.sWingCmd_RepUsePill)
	if not pack then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, pillId)
	LDataPack.writeShort(pack, pillCount)
	LDataPack.flush(pack)
end

local function onInit(actor)
	for i=0,LActor.getRoleCount(actor) -1 do
		wingAttrInit(actor, i)
	end
end

local function sendWingCTimeOver(actor, job)
	if WingCommonConfig.ctimeClearMail then
		local mailId = WingCommonConfig.ctimeClearMail[job]
		if mailId then
			mailsystem.sendConfigMail(LActor.getActorId(actor), mailId)
		end
	end
end
_G.sendWingCTimeOver = sendWingCTimeOver

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit, onInit)
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_Train, wingTrain_c2s) --请求培养翅膀
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_Open, wingOpen_c2s) --请求激活翅膀
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_UseItemUp, useItemUp_c2s) --直升多级单
netmsgdispatcher.reg(Protocol.CMD_Wing, Protocol.cWingCmd_ReqUsePill, onReqUsePill) --提升丹

