--神兵幻境副本
module("godweaponfuben", package.seeall)

local rankingListName = "godweaponfuben"
local rankingListFile = rankingListName..".rank"
local rankingListMaxSize = 100
local rankingListBoardSize = 10
local rankingListColumns = { "name" }

local p = Protocol

--[[玩家静态数据
	enterCount = 进入次数
	vipCount = vip购买次数
	maxGrid = 到达的层数
	record = 到达的层数的通关评分
	first = {
		[层]=1,是否发放了首通奖励
	}
	item_count = 道具增加的次数
]]
local function getActorVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var.gwFuben then var.gwFuben = {} end
	return var.gwFuben
end

--[[获取玩家缓存变量{
	reid = 玩家安全区定时奖励eid
}]]
local function getDynamicData(actor)
    local var = LActor.getDynamicVar(actor)
    if nil == var.gwFuben then var.gwFuben = {} end
    return var.gwFuben
end

--获取剩余可挑战次数
function getLeftEnterCount(actor)
	local var = getActorVar(actor)
	return GodWeaponBaseConfig.freeCount + (var.item_count or 0) - (var.enterCount or 0)
end

--发送副本信息到客户端
local function sendInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, p.CMD_GodWeapon, p.sGodWeaponCmd_FubenInfo)
	if not pack then return end

	LDataPack.writeData(pack, 4,
		dtInt, getLeftEnterCount(actor),
		dtInt, var.vipCount or 0,
		dtInt, var.maxGrid or 1,
		dtInt, var.record or 0)
	--发送buff的数据
	local cache = getDynamicData(actor)
	if not cache.buff then
		LDataPack.writeInt(pack, 0)
	else
		LDataPack.writeInt(pack, table.getnEx(cache.buff))
		for mt,count in pairs(cache.buff) do
			LDataPack.writeData(pack, 2,
			dtInt, mt,
			dtInt, count)
		end
	end
	LDataPack.flush(pack)
end

--设置道具额外增加的次数
function SetItemCount(actor, count)
	local var = getActorVar(actor)
	var.item_count = (var.item_count or 0) + count
	sendInfo(actor)
end

--根据 打了第几层和通关时间，计算在排行榜的分数
-- 层 * 10000 + (10000-时间) 保证排行在前面的分数
local function getPointByTime(grid, time)
	return grid * 10000 + (10000 - time)
end

--初始化排行榜
local function initRank()
	local rank = Ranking.getRanking(rankingListName)
	if rank  == nil then
		rank = Ranking.add(rankingListName, rankingListMaxSize)
		if rank == nil then
			print("can not add rank:"..rankingListName)
			return
		end
		if Ranking.load(rank, rankingListFile) == false then
			-- 创建排行榜
			for i=1, #rankingListColumns do
				Ranking.addColumn(rank, rankingListColumns[i])
			end
		end
	end
	--列数变更的处理
	local col = Ranking.getColumnCount(rank)
	for i = col + 1, #rankingListColumns do
		Ranking.addColumn(rank, rankingListColumns[i])
	end
	Ranking.save(rank, rankingListFile)
	Ranking.addRef(rank)
end

--更新排行榜
local function updateActorPoint(actor, point)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end

	local actorId = LActor.getActorId(actor)
	local item = Ranking.getItemPtrFromId(rank, actorId)
	if item ~= nil then
		local p = Ranking.getPoint(item)
		if p < point then
			Ranking.setItem(rank, actorId, point)
		end
		Ranking.setSub(item, 0, LActor.getName(actor))
	else
		item = Ranking.tryAddItem(rank, actorId, point)
		if item then
			Ranking.setSub(item, 0, LActor.getName(actor))
		end
	end
end

--发送排行榜数据到客户端
local function sendRankingList(actor)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end

	local rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
	if rankTbl == nil then rankTbl = {} end

	local pack = LDataPack.allocPacket(actor, p.CMD_GodWeapon, p.sGodWeaponCmd_FubenRankInfo)
	if pack == nil then return end
	LDataPack.writeInt(pack, #rankTbl)
	for i = 1, #rankTbl do
		local prank = rankTbl[i]
		LDataPack.writeData(pack, 3,
			dtInt, i,
			dtString, Ranking.getSub(prank,0),
			dtInt, Ranking.getPoint(prank))
	end
	LDataPack.flush(pack)
end


--判断是否到达系统开启条件
local function isOpen(actor)
	if System.getOpenServerDay() < GodWeaponBaseConfig.openDay 
		or LActor.getZhuanShengLevel(actor) < GodWeaponBaseConfig.zhuanshengLevel then
		--or godweaponbase.getGodWeaponCount(actor) < 1 then
		return false
	end
	return true
end

--客户端请求挑战副本
local function onEnterFuben(actor, packet)
	local grid = LDataPack.readInt(packet)
	--判断开启条件
	if not isOpen(actor) then return end
	--判断是否在副本里面
	if LActor.isInFuben(actor) then
		return
	end
	--获取副本ID
	local fbId = GodWeaponFubenConfig[grid].fbId
	if not fbId then return end
	--玩家数据
	local var = getActorVar(actor)
	if not var then return end
	--获取当前能打的关数
	local canEnterGrid = 0
	if var.record and var.record == 1 then
		--最高分通关了
		canEnterGrid = var.maxGrid + 1
	else
		--还未最高分通关
		canEnterGrid = var.maxGrid or 1
	end
	--判断能不能挑战客户端请求的关
	if grid > canEnterGrid then
		print(LActor.getActorId(actor).." godweaponfuben.onEnterFuben grid("..grid..") > canEnterGrid("..canEnterGrid..")")
		return
	end
	--进入次数判断
	if getLeftEnterCount(actor) <= 0 then
		if LActor.getItemCount(actor, GodWeaponBaseConfig.fubenItem) >= 1 then
			--消耗道具进入
			LActor.costItem(actor, GodWeaponBaseConfig.fubenItem, 1, "godweapon_enter")
		else
			if not GodWeaponBaseConfig.vipCount then 
				print(LActor.getActorId(actor).." godweaponfuben.onEnterFuben not GodWeaponBaseConfig.vipCount")
				return
			end
			--VIP可购买次数进入
			local vipLevel = LActor.getVipLevel(actor)
			--VIP可购买次数
			local vipCount = GodWeaponBaseConfig.vipCount[vipLevel + 1]
			if not vipCount then 
				print(LActor.getActorId(actor).." godweaponfuben.onEnterFuben not vipCount cfg, vipLevel:"..vipLevel)
				return
			end
			--VIP可购买次数到达上限
			if (var.vipCount or 0) >= vipCount then
				print(LActor.getActorId(actor).." godweaponfuben.onEnterFuben not vipCount, vipLevel:"..vipLevel)
				return
			end
			--获取购买元宝并扣钱
			local newBuyCount = (var.vipCount or 0) + 1
			local needMoney = GodWeaponBaseConfig.vipMoney[newBuyCount]
			if LActor.getCurrency(actor, NumericType_YuanBao) < needMoney then
				print(LActor.getActorId(actor).." godweaponfuben.onEnterFuben not have money, vipLevel:"..vipLevel)
				return
			end
			LActor.changeYuanBao(actor, -needMoney, "godweapon_enter")
			--设置最新的购买次数
			var.vipCount = newBuyCount
		end
	end
	--玩家缓存数据,清空buff记录
	local cache = getDynamicData(actor)
	cache.buff = nil
	--创建副本
	local hfuben = Fuben.createFuBen(fbId)
	if hfuben == 0 then
		print(LActor.getActorId(actor).." create godweapon fuben failed."..fbId)
		return
	end
	--获取ins
	local ins = instancesystem.getInsByHdl(hfuben)
	if not ins then
		print(LActor.getActorId(actor).." godweapon fuben ins is nil fbid:"..fbId)
		return 
	end
	--记录当前挑战的层数ID
	ins.data.grid = grid
	--进入副本
	LActor.enterFuBen(actor, hfuben)
	--通知最新信息到客户端
	sendInfo(actor)
end

--设置并记录当前通关的层数和评分
local function setCurMaxGridAndRecord(actor, grid, grade)
	--记录日志,方便追踪调试玩家
	print(LActor.getActorId(actor).." godweaponfuben.setCurMaxGridAndRecord grid:"..grid..", grade:"..grade)
	local var = getActorVar(actor)
	if not var.maxGrid or var.maxGrid < grid then
		var.maxGrid = grid 	--已打到第几层
		var.record = grade 	--最后那一层的评分
	elseif var.maxGrid == grid and (not var.record or var.record > grade) then
		var.record = grade 	--最后那一层的评分
	end
end

--发放输赢的弹框奖励
local function onSetAwardResult(ins, actor, grade, useTime)
	--清理buff记录
	local cache = getDynamicData(actor)
	cache.buff = nil
	--获取当前层数
	local grid = ins.data.grid
	--获取奖励
	local reward = {}
	if GodWeaponFubenConfig[grid] and GodWeaponFubenConfig[grid].award 
		and GodWeaponFubenConfig[grid].award[grade] then
		--普通奖励
		for _, v in ipairs(GodWeaponFubenConfig[grid].award[grade]) do
			table.insert(reward, v)
		end
	end
	--判断是否最高级别通关
	if grade == 1 then
		--只有s级评价才上排行榜
		local point = getPointByTime(grid, useTime)
		updateActorPoint(actor, point)
		--玩家静态数据
		local var = getActorVar(actor)
		--是否发放了首通奖励
		if not var.first then var.first = {} end
		--首通奖励
		if not var.first[grid] and GodWeaponFubenConfig[grid] then
			var.first[grid] = 1
			--reward = table.deepcopy(GodWeaponFubenConfig.firstAward)
			for _, v in ipairs(GodWeaponFubenConfig[grid].firstAward) do
				table.insert(reward, v)
			end
			print(LActor.getActorId(actor).." godweaponfuben.onSetAwardResult sendfirst reward")
		end
	end
	--设置副本奖励
	--instancesystem.setInsRewards(ins, actor, reward)
	ins.data.rewards = reward
	ins.data.grade = grade
	local pack = LDataPack.allocPacket(actor, p.CMD_GodWeapon, p.sGodWeaponCmd_SendFubenRewards)
	if not pack then return end
	LDataPack.writeChar(pack, useTime and 1 or 0)--只有赢才有useTime
	LDataPack.writeChar(pack, grade or 0)
	LDataPack.writeShort(pack, #reward)
	for _, v in ipairs(reward) do
		LDataPack.writeInt(pack, v.type or 0)
		LDataPack.writeInt(pack, v.id or 0)
		LDataPack.writeInt(pack, v.count or 0)
	end
	LDataPack.flush(pack)
end

--获取通关评分
local function getGrade(useTime)
	for k, value in ipairs(GodWeaponBaseConfig.fbGrade) do
		if useTime <= value then
			return k
		end
	end
	return nil
end

--副本通关的时候
local function onWin(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
	
	local grid = ins.data.grid 	--副本第几层
	--获取通关时长
	local leftTime = ins.end_time - System.getNowTime()
	local useTime = ins.config.totalTime - leftTime
	--获得评分
	local grade = getGrade(useTime)
	if not grade then
		print(LActor.getActorId(actor).." error godweaponfuben, the use time grade is wrong "..useTime)
		return
	end
	--发奖励
	onSetAwardResult(ins, actor, grade, useTime)
end

local function onLose(ins)
	local actor = ins:getActorList()[1]
	if not actor then return end
	--发最低评分的奖励
	onSetAwardResult(ins, actor, #GodWeaponBaseConfig.fbGrade)
end

local function giveFubenAwards(ins, actor)
	if ins == nil or ins.is_end == false then
		print(LActor.getActorId(actor).." godweaponfuben.giveFubenAwards ins is nil")
		return
	end
	if not ins.data or not ins.data.rewards then
		print(LActor.getActorId(actor).." godweaponfuben.giveFubenAwards ins.data.rewards is nil")
		return
	end
	--增加进入次数
	local var = getActorVar(actor)
	var.enterCount = (var.enterCount or 0) + 1
	--设置成绩
	setCurMaxGridAndRecord(actor, ins.data.grid, ins.data.grade)
	--获得奖励
	LActor.giveAwards(actor, ins.data.rewards, "godweaponfuben")
	ins.data.rewards = nil
	sendInfo(actor)
	LActor.exitFuben(actor)
end

local function onExitFuben(ins, actor)
	local var = getActorVar(actor)
	if not var then return end
	--第几层
	local grid = ins.data.grid
	if not grid then return end
	
	if ins.data.grade == 1 then
		giveFubenAwards(ins, actor)
	end
	--最后的评分
	--if not ins.is_end then
	--	local grade = #GodWeaponBaseConfig.fbGrade
	--	setCurMaxGridAndRecord(actor, grid, grade, ins.config.totalTime)
	--end
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end


local function onGetFubenRewards(actor, packet)
	local hfuben = LActor.getFubenHandle(actor)
	local ins = instancesystem.getInsByHdl(hfuben)
	giveFubenAwards(ins, actor)
end

local function buyBuff(actor, packet)
	if not GodWeaponBaseConfig.buyBuff then return end
	local moneyType = LDataPack.readInt(packet)
	--获取配置
	local buffConf = GodWeaponBaseConfig.buyBuff[moneyType]
	if not buffConf then return end
	--获取动态缓存
	local cache = getDynamicData(actor)
	if not cache.buff then	cache.buff = {} end
	
	local hasBuff = cache.buff[moneyType] or 0
	if hasBuff >= buffConf.maxCount then
		return
	end
	--判断与扣钱
	if LActor.getCurrency(actor, moneyType) < buffConf.moneyCount then return end
	LActor.changeCurrency(actor, moneyType, -buffConf.moneyCount, "godweapon_buff")
	--增加购买buff次数
	cache.buff[moneyType] = hasBuff + 1
	--总增加buff次数
	local totalHasBuff = 0
	for _,count in pairs(cache.buff or {}) do
		totalHasBuff = totalHasBuff + count
	end
	--获取buffID
	local buffId = GodWeaponBaseConfig.buffId[totalHasBuff]
	if not buffId then
		return
	end
	--增加buff
	LActor.addEffect(actor, buffId)
	--发送信息给客户端
	sendInfo(actor)
end

function actorChangeName(actor, name)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	local actorId = LActor.getActorId(actor)
	local item = Ranking.getItemPtrFromId(rank, actorId)
	if item ~= nil then
		Ranking.setSub(item, 0, name)
	end
end

--新的一天
local function onNewDay(actor)
	local var = getActorVar(actor)
	if not var then return end
	var.vipCount = nil
	var.enterCount = nil
	var.item_count = nil
	sendInfo(actor)
end

--玩家登陆的时候
local function onLogin(actor)
	sendInfo(actor)
end

--全局初始化
local function init()
	for _, v in pairs(GodWeaponFubenConfig) do
		insevent.registerInstanceWin(v.fbId, onWin)
		insevent.registerInstanceLose(v.fbId, onLose)
		insevent.registerInstanceExit(v.fbId, onExitFuben)
		insevent.registerInstanceOffline(v.fbId, onOffline)
	end

	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	
	netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_GetFubenInfo, sendInfo)
	netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_FubenEnter, onEnterFuben)
	netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_FubenBuyBuff, buyBuff)
	netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_GetFubenRankInfo, sendRankingList)
	netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_GetFubenRewards, onGetFubenRewards)
end

table.insert(InitFnTable, init)
engineevent.regGameStartEvent(initRank)
