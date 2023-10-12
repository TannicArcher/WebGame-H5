-- 节日商店
module("subactivitytype22", package.seeall)
--[[
data define:
	保存数据
	data = {
		totalScore -- 总积分
		totalCount -- 刷新总次数，活动结束清除，活动中间不清除
		freshTime -- 点击免费刷新的结束时间
		group = {} -- 刷新到的物品 {id=商品ID, flag=已购买}
	}
]]

-- 临时配置
--[[
[活动ID] = {
	转生等级对应的库
	zhuansheng = {
		[level] = {
			list={
				{
					id= [商品ID],
					conf= 商品ID的配置cfg
				}
			}
		}
	},
	积分对应的库
	jifen = {
		[level] = {
			list={
				{
					id= [商品ID],
					conf= 商品ID的配置cfg
				}
			}
		}
	}
}
]]
local fmtConfig = {}
local subType = 22

-- 获取玩家数据
local function getData( actor, id )
	local var = activitysystem.getSubVar(actor, id)
	if not var then return nil end
	if not var.data then var.data = {} end
	if not var.data.group then var.data.group = {} end
	return var
end

-- 加载活动中的配置
local function loadConfig( activityID, conf)
	fmtConfig[activityID] = {}
	fmtConfig[activityID].zhuansheng = {}
	fmtConfig[activityID].jifen = {}

	local tZhuanSheng = fmtConfig[activityID].zhuansheng
	local tJifen = fmtConfig[activityID].jifen
	-- 从商品ID配置中筛选不同的库
	for productId,cfg in pairs(conf or {}) do
		-- 转生等级
		if cfg.low and cfg.high then

			for zsLevel=cfg.low,cfg.high do
				-- 商品库
				if not tZhuanSheng[zsLevel] then tZhuanSheng[zsLevel] = {} end
				if not tZhuanSheng[zsLevel].list then tZhuanSheng[zsLevel].list = {} end
				-- print("subactivitytype22 productId 1:"..productId..",cfg.low:"..cfg.low..",cfg.high:"..cfg.high..",zsLevel:"..zsLevel)
				if cfg.rate then
					table.insert(tZhuanSheng[zsLevel].list, {id = productId, conf=cfg} )
					-- print("subactivitytype22 productId:"..productId..",zsLevel:"..zsLevel)
				end
				-- 积分库
				if cfg.score then
					if not tJifen[zsLevel] then tJifen[zsLevel] = {} end
					if not tJifen[zsLevel].list then tJifen[zsLevel].list = {} end
					table.insert(tJifen[zsLevel].list, {id = productId, conf=cfg} )
				end
			end
		end
	end
end


-- 获取最大的可整除倍数
local function getMaxRate( rates, num )
	local maxK = 0
	local rate
	for k,v in pairs(rates or {}) do
		if num%k == 0 and k > maxK then --能整除的最大的次数权重
			maxK = k
			rate = v
		end
	end
	return rate
end

-- 抽取一次
local function huntOnce( tRate, totalRate )
	-- 随机数
	local rnd = math.random(1, totalRate)
	local total = 0 -- 区间范围
	for pos,v in ipairs(tRate or {}) do
		total = total + v.trate
		if rnd <= total then

			return pos,v
		end
	end
end

-- 从配置list中抽取奖励，num为抽取个数,freshCount为刷新次数
local function hunt( list, num, freshCount)
	-- 结果，[商品ID] = 商品ID的配置cfg
	local result
	-- 总权重
	local totalRate = 0
	-- 临时权重表
	local tRate = {}
	for i=1,#(list or {}) do
		local productId = list[i].id -- 商品ID
		local conf = list[i].conf -- 商品ID的配置
		-- 权重 
		local rate = getMaxRate(conf.rate, freshCount)
		if rate then
			-- 权重大于0才在计算内
			if rate > 0 then
				table.insert(tRate, {tid=productId,tconf=conf,trate=rate})
				totalRate = totalRate + rate
			end
		else
			-- 配置错误
			print("subactivitytype22 conf err,productId:"..productId)
		end
	end

	if totalRate <= 0 then
		print("subactivitytype22 hunt,totalRate:"..totalRate)
		return
	end

	-- 从tRate中选择出num个数据
	for i=1,num do
		local pos,v = huntOnce(tRate, totalRate)
		if not pos then break end
		-- 保存选择出的数据
		if not result then result = {} end
		result[v.tid] = v.tconf
		-- 从tRate中删除
		totalRate = totalRate - v.trate
		table.remove(tRate, pos)
		if totalRate <= 0 then break end
	end
	return result
end

-- 下发数据
local function writeRecord( npack, record, conf, id, actor )
	
	-- 数据
	-- 免费刷新的剩余时间
	local freshTime
	local now = System.getNowTime()
	if record and record.data and record.data.freshTime then
		freshTime = record.data.freshTime - now
		if freshTime < 0 then freshTime = 0 end
	end

	-- 刷新得到的物品
	local group = record and record.data and record.data.group or {}
	local items = {}
	for i=1,#group do
		local productId = group[i].id
		if not productId or not (conf and conf[productId]) then
			print("subactivitytype22 productId does not exist,id:"..id..",productId:"..(productId or -1))
		else
			table.insert(items, {id=productId, flag=group[i].flag, cfg=conf[productId]})
		end
	end

	-- 积分商店
	local zsLevel = LActor.getZhuanShengLevel(actor)
	local jifen = fmtConfig[id] and fmtConfig[id].jifen[zsLevel] and fmtConfig[id].jifen[zsLevel].list or {}

	-- 发送给客户端
	-- 总积分
	LDataPack.writeInt(npack, record and record.data and record.data.totalScore or 0)
	-- 是否可以免费刷新
	LDataPack.writeByte(npack, ((freshTime or 0) <= 0) and 1 or 0)
	-- 刷新剩余时间
	LDataPack.writeInt(npack, freshTime or 0)

	-- 商店商品表
	LDataPack.writeShort(npack, #items)
	for i=1,#items do
		-- 发送已经刷新的物品及状态(是否已经被购买过)
		local cfg = items[i].cfg
		-- 商品ID
		LDataPack.writeInt(npack, items[i].id or 0)
		-- 物品ID
		LDataPack.writeInt(npack, cfg.itemId or 0)
		-- 物品数量
		LDataPack.writeShort(npack, cfg.count or 0)
		-- 元宝价格
		LDataPack.writeInt(npack, cfg.ybPrice or 0)
		-- 折扣
		LDataPack.writeByte(npack, cfg.discountImg or 0)
		-- 是否已经购买
		LDataPack.writeByte(npack, items[i].flag and 1 or 0)
	end

	-- 积分
	LDataPack.writeShort(npack, #jifen)
	for i=1,#jifen do
		local cfg = jifen[i].conf
		-- 商品ID
		LDataPack.writeInt(npack, jifen[i].id or 0)
		-- 物品ID
		LDataPack.writeInt(npack, cfg and cfg.itemId or 0)
		-- 物品数量
		LDataPack.writeShort(npack, cfg and cfg.count or 0)
		-- 积分 
		LDataPack.writeInt(npack, cfg and cfg.score or 0)
	end

	-- print("subactivitytype22 writeRecord,actor:"..LActor.getActorId(actor)..",zsLevel:"..(zsLevel)
	-- 	..",totalScore:"..(record and record.data and record.data.totalScore or 0)
	-- 	..",totalCount:"..(record and record.data and record.data.totalCount or 0)
	-- 	..",isfresh:"..(((freshTime or 0) <= 0) and 1 or 0)
	-- 	..",group len:"..(#items)..",jifen len:"..(#jifen)
	-- 	..",freshTime:"..(freshTime or 0)
	-- 	..",store freshTime:"..(record and record.data and record.data.freshTime or -1)
	-- 	..",now:"..now)
	-- for i=1,#items do
	-- 	local cfg = items[i].cfg
	-- 	print("subactivitytype22 writeRecord group,actor:"..LActor.getActorId(actor)
	-- 		..",productId:"..(items[i].id or 0) 
	-- 		..",itemId:"..(cfg.itemId or 0)
	-- 		..",count:"..(cfg.count or 0)
	-- 		..",ybPrice:"..(cfg.ybPrice or 0)
	-- 		..",discount:"..(cfg.discountImg or 0)
	-- 		..",flag:"..(group[i].flag and 1 or 0))
	-- end
	-- for i=1,#jifen do
	-- 	local cfg = jifen[i].conf
	-- 	print("subactivitytype22 writeRecord jifen,actor:"..LActor.getActorId(actor)
	-- 		..",productId:"..(jifen[i].id or 0)
	-- 		..",itemId:"..(cfg and cfg.itemId or 0)
	-- 		..",count:"..(cfg and cfg.count or 0)
	-- 		..",score:"..(cfg and cfg.score or 0))
	-- end
end

-- 检测是否能够购买商品
local function checkBuyItem( actor, id, productId, conf, record )
	-- 变量出错，一般 不会出错
	if not (record and record.data and record.data.group) then
		print("subactivitytype22 checkBuyItem record fail,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId)
		return
	end
	-- 元宝
	if conf.ybPrice and LActor.getCurrency(actor, NumericType_YuanBao) < conf.ybPrice then
		print("subactivitytype22 checkBuyItem ybPrice not enouth,actor:"..LActor.getActorId(actor)..",id:"..id
			..",productId:"..productId..",conf[productId].ybPrice:"
			..",yb:"..LActor.getCurrency(actor, NumericType_YuanBao))
		return false
	end
	-- 没有物品
	if not (conf.itemId and conf.count) then
		print("subactivitytype22 checkBuyItem no item,id:"..id..",productId:"..productId)
		return false
	end
	-- 是否在刷新列表,且没有购买过
	local group = record.data.group
	local isInGroup, isPurchased
	for i=1,#group do
		if group[i].id == productId then
			isInGroup = true
			isPurchased = group[i].flag
			break
		end
	end
	-- 不在刷新列表中
	if not isInGroup then
		print("subactivitytype22 checkBuyItem isInGroup false,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId)
		return false
	end
	-- 已经购买过
	if isPurchased then
		print("subactivitytype22 checkBuyItem has purchased,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId)
		return false
	end
	-- 是否能放进背包
	local item = {{type=AwardType_Item,id=conf.itemId,count=conf.count}}
	if not LActor.canGiveAwards(actor, item) then
		print("subactivitytype22 checkBuyItem not canGiveAwards,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId)
		return false
	end

	return true
end

-- 购买商品
local function buyItem( actor, id, productId, conf, record)
	if not conf[productId] then
		-- 传入的参数错误
		print("subactivitytype22 buyItem error,actor:"..LActor.getActorId(actor)..",zsLevel:"..LActor.getZhuanShengLevel(actor)
			..",id:"..id..",productId:"..productId)
		return
	end
	-- 商品配置
	local cfg = conf[productId]
	if checkBuyItem(actor, id, productId, cfg, record) then
		print("subactivitytype22 buyItem,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId)
		-- 扣元宝
		if cfg.ybPrice then
			LActor.changeYuanBao(actor, -cfg.ybPrice, "type22 buy"..id)
			-- 增加积分
			record.data.totalScore = (record.data.totalScore or 0) + cfg.ybPrice
		end
		-- 改变购买状态
		local group = record.data.group
		for i=1,#group do
			if group[i].id == productId then
				group[i].flag = true
			end
		end
		-- 给奖励
		LActor.giveAward(actor, AwardType_Item, cfg.itemId, cfg.count, "type22 buy")
	end
end

-- 兑换
local function exchange( actor, id, productId, conf, record )
	if not conf[productId] then
		-- 传入的参数错误
		print("subactivitytype22 exchange error,actor:"..LActor.getActorId(actor)..",zsLevel:"..LActor.getZhuanShengLevel(actor)
			..",id:"..id..",productId:"..productId)
		return
	end
	-- 配置
	local cfg = conf[productId]
	-- 不在兑换区
	if not cfg.score then
		print("subactivitytype22 exchange no score,actor:"..LActor.getActorId(actor)..",zsLevel:"..LActor.getZhuanShengLevel(actor)
			..",id:"..id..",productId:"..productId)
		return
	end
	-- 积分是否足够
	if (record and record.data and record.data.totalScore or 0) < cfg.score then
		print("subactivitytype22 exchange score not enouth,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId
			..",cfg.score:"..cfg.score..",score:"..(record and record.data and record.data.totalScore or 0))
		return
	end
	-- 没有物品
	if not (cfg.itemId and cfg.count) then
		print("subactivitytype22 exchange no item,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId)
		return
	end
	-- 是否能放进背包
	if not LActor.canGiveAwards(actor, {{type=AwardType_Item,id=cfg.itemId,count=cfg.count}}) then
		print("subactivitytype22 exchange not canGiveAwards,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId)
		return
	end
	-- 扣积分
	print("subactivitytype22 exchange,actor:"..LActor.getActorId(actor)..",id:"..id..",productId:"..productId)
	if record and record.data and record.data.totalScore then
		record.data.totalScore = record.data.totalScore - cfg.score
		-- 发奖励
		LActor.giveAward(actor, AwardType_Item, cfg.itemId, cfg.count, "type22 exch")
	end
end

-- 免费时间到, 此过程不修改数据，否则会出现以前莫名其妙的问题，不用打印日志
local function onFreeTimer( actor, id )
	if not actor then
		-- print("subactivitytype22 onFreeTimer actor is nil")
		return
	end
	if not activitysystem.activityTimeIsEnd(id) then
		-- 免费刷新的时间到，通知客户端刷新
		activitysystem.sendActivityData(actor, id)
		-- print("subactivitytype22 onFreeTimer2,actor:"..LActor.getActorId(actor))
	end
	-- print("subactivitytype22 onFreeTimer,actor:"..LActor.getActorId(actor))
end

-- 检测是否能够刷新
local function checkFresh( actor, id, conf, record, now )
	-- 记录为空，传入参数错误
	if not record then
		print("subactivitytype22 freshItems record fail,actor:"..LActor.getActorId(actor)..",id:"..id)
		return false
	end
	-- 配置错误
	if not (ActivityType22_1Config[id] and ActivityType22_1Config[id][1]) then
		print("subactivitytype22 freshItems conf err,id:"..id)
		return false
	end
	local conf2 = ActivityType22_1Config[id][1]
	-- 配置错误
	if not (conf2.itemCount and conf2.freshTime) then
		print("subactivitytype22 freshItems conf err,id:"..id..",itemCount:"..(conf2.itemCount or 0)..",freshTime:"..(conf2.freshTime or 0))
		return false
	end
	-- 转生等级
	local zsLevel = LActor.getZhuanShengLevel(actor)
	if not (fmtConfig[id] and fmtConfig[id].zhuansheng[zsLevel]) then
		-- 没有相应的转生等级库
		print("subactivitytype22 freshItems conf zsLevel fail,actor:"..LActor.getActorId(actor)..",id:"..id..",zsLevel:"..zsLevel)
		return false
	end
	-- 刷新时，初始化数据
	if not record.data then record.data = {} end
	if not record.data.group then record.data.group = {} end
	-- 花费元宝刷新或免费刷新，freshTime存在，则判断是否过期，不过期则不能免费刷新，否则能免费刷新
	if record.data.freshTime then
		-- 不过期
		if now < record.data.freshTime then
			-- 优先使用道具,道具充足，直接返回
			if conf2.freshItem and LActor.getItemCount(actor, conf2.freshItem) > 0 then
				return true
			end
			-- 元宝不足
			if conf2.freshPrice and LActor.getCurrency(actor, NumericType_YuanBao) < conf2.freshPrice then
				print("subactivitytype22 freshItems yuanbao not enough,actor:"..LActor.getActorId(actor)..",id:"..id..",conf2.freshPrice:"..conf2.freshPrice
					..",yuanbao:"..LActor.getCurrency(actor, NumericType_YuanBao))
				return false
			end
		end
	end
	return true
end

-- 刷新新的商品,isInit表示初始化时，不设置刷新的状态，正常流程中不设置isInit
local function freshItems( actor, id, conf, record, isInit )
	local now = System.getNowTime()
	-- 不能刷新，则返回,错误信息，在检测函数内
	if not checkFresh(actor, id, conf, record, now) then return end
	-- 刷新配置
	local conf2 = ActivityType22_1Config[id][1]
	-- 转生等级
	local zsLevel = LActor.getZhuanShengLevel(actor)
	-- 刷新物品
	local list = fmtConfig[id].zhuansheng[zsLevel] and fmtConfig[id].zhuansheng[zsLevel].list
	local newItems = hunt(list, conf2.itemCount, (record.data.totalCount or 0) + 1)
	if not newItems then
		print("subactivitytype22 hunt no items,actor:"..LActor.getActorId(actor)..",id:"..id..",zsLevel:"..zsLevel
			..",totalCount:"..(record.data.totalCount or 0))
		return
	end
	print("subactivitytype22 freshItems,actor:"..LActor.getActorId(actor)..",id:"..id..",zsLevel:"..zsLevel)
	-- 扣元宝，或是免费刷新
	if record.data.freshTime and now < record.data.freshTime then
		-- 不过期
		-- 优先使用道具,道具充足
		if conf2.freshItem and LActor.getItemCount(actor, conf2.freshItem) > 0 then
			-- 扣道具
			LActor.costItem(actor, conf2.freshItem, 1, "type22")
		else
			-- 扣元宝
			if conf2.freshPrice then
				LActor.changeYuanBao(actor, -conf2.freshPrice, "type22 fresh"..id)
				-- 增加积分
				record.data.totalScore = (record.data.totalScore or 0) + conf2.freshPrice
			end
		end
	elseif not isInit then
		-- 免费刷新,初始化时，不设置状态
		record.data.freshTime = System.getNowTime() + conf2.freshTime
		local eid = LActor.postScriptEventLite(actor, conf2.freshTime * 1000, onFreeTimer, id)

		-- 保存一个定时器
		local dyvar = activitysystem.getDyanmicVar(id)
		local aid = LActor.getActorId(actor)
		if dyvar then
			if not dyvar.eids then dyvar.eids = {} end
			dyvar.eids[aid] = eid
		end
	end
	-- 增加刷新次数
	record.data.totalCount = (record.data.totalCount or 0) + 1
	-- 更新物品
	record.data.group = nil
	record.data.group = {}
	local pos = 1
	for productId,_ in pairs(newItems) do
		record.data.group[pos] = {id=productId}
		pos = pos + 1
	end
end

-- 购买，兑换，刷新，index表示某种类型，分别为3，4，5，购买，兑换时，后面需要紧接商品ID
local function getReward( id, typeconfig, actor, record, packet )
	-- 奖励序号不使用
	local index = LDataPack.readShort(packet)
	-- 操作类型
	index = LDataPack.readShort(packet)
	if index == 3 then
		-- 购买
		local productId = LDataPack.readInt(packet)
		buyItem(actor, id, productId, typeconfig and typeconfig[id] or {}, record)
	elseif index == 4 then
		-- 兑换
		local productId = LDataPack.readInt(packet)
		exchange(actor, id, productId, typeconfig and typeconfig[id] or {}, record)
	elseif index == 5 then 
		-- 刷新
		freshItems(actor, id, typeconfig and typeconfig[id] or {}, record)
	else
		-- 错误
		print("subactivitytype22 getReward error,actor:"..LActor.getActorId(actor)..",id:"..id..",index:"..index)
	end
	activitysystem.sendActivityData(actor, id)
end

-- 初始化数据
-- local function onNewDay( id, conf )
-- 	return function ( actor )
-- 		-- 活动结束，直接退出
-- 		if activitysystem.activityTimeIsEnd(id) then return end
-- 		-- 活动数据
-- 		local record = getData(actor, id)
-- 		if not record then
-- 			-- 这是一个很诡异的错误
-- 			print("subactivitytype22 onNewDay record is nil,actor:"..LActor.getActorId(actor)..",id:"..id)
-- 			return
-- 		end
-- 		-- 没有触发过的，主动刷新一次
-- 		if not (record.data and record.data.freshTime) then
-- 			if (record.data and record.data.totalCount or 0) <= 0 then
-- 				freshItems(actor, id, conf, record, true)
-- 				-- print("subactivitytype22 onNewDay fresh active,actor:"..LActor.getActorId(actor))
-- 			end
-- 		end
-- 	end
-- end

-- 初始化数据
local function onInit( id, conf )
	return function ( actor )
		-- 活动结束，退出
		if activitysystem.activityTimeIsEnd(id) then
			 local dyvar = activitysystem.getDyanmicVar(id)
			 if dyvar then dyvar.eids = nil end
			return 
		end
		-- 活动数据
		local record = getData(actor, id)
		if not record then
			-- 这是一个很诡异的错误
			print("subactivitytype22 onInit record is nil,actor:"..LActor.getActorId(actor)..",id:"..id)
			return
		end
		-- 没有触发过的，主动刷新一次
		if not (record.data and record.data.freshTime) then
			if (record.data and record.data.totalCount or 0) <= 0 then
				freshItems(actor, id, conf, record, true)
				print("subactivitytype22 onInit fresh active,actor:"..LActor.getActorId(actor)..",id:"..id)
				activitysystem.sendActivityData(actor, id)
			end
		else
			-- 起服时，补一个结束定时器
			local dyvar = activitysystem.getDyanmicVar(id)
			local aid = LActor.getActorId(actor)
			if not (dyvar and dyvar.eids and dyvar.eids[aid]) then
				local now = System.getNowTime()
				local tSec = record.data.freshTime - now
				-- 已经过期的，可以免费刷新，不补定时器
				if tSec > 0 then
					local eid = LActor.postScriptEventLite(actor, tSec * 1000, onFreeTimer, id)
					if dyvar then 
						if not dyvar.eids then dyvar.eids = {} end
						dyvar.eids[aid] = eid 
					end
					print("subactivitytype22 onInit actor:"..LActor.getActorId(actor)..",id:"..id..",tSec:"..tSec..",eid:"..eid)
				end
			end
		end
	end
end

-- 登出
local function onLogout( id, conf )
	return function ( actor )
		-- 活动结束，退出
		if activitysystem.activityTimeIsEnd(id) then
			return 
		end
		local dyvar = activitysystem.getDyanmicVar(id)
		if dyvar and dyvar.eids then
			dyvar.eids[LActor.getActorId(actor)] = nil
		end
	end
end

-- 初始化
local function initFunc( id, conf )
	-- 检查配置是否错误
	local conf2 = ActivityType22_1Config[id]
	if not (conf2 and conf2[1] and (conf2[1].itemCount or 0) > 0 and (conf2[1].freshTime or 0) > 0) then
		print("subactivitytype22 initFunc conf err,id:"..id)
		return
	end
	-- 加载刷新时对应的库
	loadConfig(id, conf)

	-- 注册初始化事件
	actorevent.reg(aeUserLogin, onInit(id, conf))
	actorevent.reg(aeNewDayArrive, onInit(id, conf))
	actorevent.reg(aeUserLogout, onLogout(id, conf))
	-- print("subactivitytype22 initFunc,id:"..id)
end

subactivities.regConf(subType, ActivityType22_2Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)

--[[
-- 测试

local gmsystem    = require("systems.gm.gmsystem")
local gm = gmsystem.gmCmdHandlers

function gm.test22( actor, args )
	local id,index = tonumber(args[1]) or 0, tonumber(args[2]) or 0
	if not (id > 0 and index > 0) then
		print("subactivitytype22 test22 para fail")
		return
	end
	print("subactivitytype22 test22 para,index:"..index..",id:"..id)
	local conf = ActivityType22_2Config[id]
	if not conf then 
		print("subactivitytype22 test22 conf fail")
	end
	local record = getData(actor, id)
	local typeconfig = conf
	if index==3 then
		local productId = tonumber(args[3]) or 0
		if productId > 0 then
			print("subactivitytype22 test22 buy 3 times,actor:"..LActor.getActorId(actor)..",productId:"..productId)
			for i=1,3 do
				buyItem(actor, id, productId, conf, record)
			end
		end
	elseif index==4 then
		local productId = tonumber(args[3]) or 0
		if productId > 0 then
			print("subactivitytype22 test22 exchange 3 times,actor:"..LActor.getActorId(actor)..",productId:"..productId)
			for i=1,3 do
				exchange(actor, id, productId, conf, record)
			end
		end
	elseif index==5 then
		freshItems(actor, id, conf, record)
	else
		print("subactivitytype22 test22 para fail,index:"..index)
	end
	activitysystem.sendActivityData(actor, id)
end

function gm.clear22( actor, args )
	local id,index = tonumber(args[1]) or 0, tonumber(args[2]) or 0
	if not (id > 0 ) then
		print("subactivitytype22 test22 para fail")
		return
	end
	print("subactivitytype22 test22 para,index:"..index..",id:"..id)
	local conf = ActivityType22_2Config[id]
	if not conf then 
		print("subactivitytype22 test22 conf fail")
	end
	local record = getData(actor, id)
	if record then
		record.data = {}
		activitysystem.sendActivityData(actor, id)
	end
	print("subactivitytype22 clear22,id:"..id)
end

--]]
