module("auctionsystem", package.seeall)

--[[

local AuctionGoodsList = {
	[id] = {
		id = 999,					--序列号
		addTime = 9999999,          --上架时间
		guildEndTime = 9999999,     --公会拍卖到期时间
		globalEndTime = 9999999,    --全服拍卖到期时间
		owners = "123,456,789",     --拍卖品归属者列表
		guildId = 999,              --拍卖所属公会id
		auctionId = 999,            --拍卖物品id
		bid = 0,                    --当前竞拍次数
		bidder = 0,                 --全服竞拍者
		gbidder = 0,                --公会竞拍者
		hyLimit = 0,                --花费活跃额度
		ybLimit = 0,                --花费充值额度
		flag = 0,                   -- 标记位, 1.是否为个人拍品
		ischange = false,
	},
	...
}

local AuctionRecord = {
	{
		auctionId = 999,  --拍卖物品id
		name = "abc",     --成交者名字
		txType = 0,         -- 0=流拍  1=竞价  2=一口价
		price = 100,      --成交价
		time = 9999999,   --成交时间
		guildId = 999,    --公会id
	},
	...
}

auction = {
	opened = {
		--[已打开的拍品盒id] = 拍卖物品id
		[888] = 1,
		[999] = 1,
		...
	}
	init = 0,     --是否初始化过
	hyLimit = 0,  --活跃额度
	ybLimit = 0,  --充值额度
}

]]

AuctionGoodsList = AuctionGoodsList or {}  --商品列表
AuctionRecord = AuctionRecord or {}  --成交记录

--操作结果编号
local ResultNo = {
	success = 0,    --成功
	empty = 1,      --没有此商品或商品不正常
	update = 2,     --前后端数据不一致
	showtime = 3,   --商品还在展示时间
	lilian = 4,     --活跃额度不够
}

local FlagType = {
	isPersonal = 0,  --是否个人拍品
	isRecord = 1,    --是否以添加成交记录
}

--商品类型
local GoodsType = {
	lose = -1,    --失效物品
	guild = 0,    --公会拍卖商品
	global = 1,   --全服拍卖商品
}

--交易类型
local TxType = {
	failed = 0,  --流拍
	bid = 1,     --竞拍
	buy = 2,     --一口价购买
}

local dbCmd = DbCmd.AuctionCmd

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("auctionsystem aid:" .. aid .. " log:" .. str)
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.auction then
		var.auction = {}
	end
	return var.auction
end

local function getGlobalData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil 
	end
	if var.auction == nil then 
		var.auction = {}
	end
	return var.auction
end

--商品归属者反序列化
local function ownersS2T(str)
	local owners = {}
	for aid in string.gmatch(str, "%d+") do
		table.insert(owners, tonumber(aid))
	end
	return owners
end

--商品归属者序列化
local function ownersT2S(owners)
	local str = ""
	if type(owners) == "table" then
		for _,v in pairs(owners) do
			if str == "" then
				str = tostring(v)
			else
				str = str .. "," .. tostring(v)
			end
		end
	end
	return str
end

--增加成交记录
local function addRecord(auctionId, name, txType, price, guildId)
	if #AuctionRecord > AuctionConfig.successRecordMax then table.remove(AuctionRecord, 1) end
	table.insert(AuctionRecord, {
		auctionId = auctionId,
		name = name,
		txType = txType,
		price = price,
		time = System.getNowTime(),
		guildId = guildId
	})
end

--物品上架
function addGoods(owners, guildId, auctionId, isPersonal)
	if type(owners) ~= "table" then
		--非法参数
		print("auctionsystem addGoods owners is not a table")
		return false
	end

	if #owners <= 0 then
		--没有归属者
		print("auctionsystem addGoods #owners <= 0")
		return false
	end

	if #owners > 20 then
		print("auctionsystem addGoods #owners > 20")
		print(debug.traceback())
	end

	if type(guildId) ~= "number" then
		--非法参数
		print("auctionsystem addGoods guildId is not a number")
		return false
	end
	
	local aitemConf = AuctionItem[auctionId]
	if not aitemConf then
		--不是拍卖id
		print("auctionsystem addGoods aitemConf is nil, auctionId:"..tostring(auctionId))
		return false
	end

	local gdata = getGlobalData()
	gdata.autonum = (gdata.autonum or 0) + 1
	if gdata.autonum > 50000 then gdata.autonum = 0 end

	local serverId = System.getServerId()
	local id = System.bitOpOr(System.bitOpLeft(gdata.autonum, 16), serverId)
	local addTime = System.getNowTime()
	local guildEndTime = addTime
	if 0 ~= guildId then
		guildEndTime = addTime + AuctionConfig.guildShowTime + aitemConf.guildTime
	end
	local globalEndTime = guildEndTime + AuctionConfig.globalShowTime + aitemConf.globalTime
	local flag = 0
	if isPersonal then flag = System.bitOpSetMask(flag, FlagType.isPersonal, true) end
	AuctionGoodsList[id] = {
		id = id,
		addTime = addTime,
		guildEndTime = guildEndTime,
		globalEndTime = globalEndTime,
		owners = owners,
		guildId = guildId,
		auctionId = auctionId,
		bid = 0,
		bidder = 0,
		gbidder = 0,
		flag = flag,
		hyLimit = 0,
		ybLimit = 0, 
	}
	local ownersStr = ownersT2S(owners)
	print("auctionsystem addGoods id:"..tostring(id)..", auctionId:"..tostring(auctionId)..", owners:"..ownersStr
		..", guildId:"..tostring(guildId)..", isPersonal:"..tostring(isPersonal))
	local dbClient, dbPacket = System.allocDBPacket(serverId or 0, dbAuction, dbCmd.dcAuctionAdd)
	LDataPack.writeInt(dbPacket, id)
	LDataPack.writeInt(dbPacket, addTime)
	LDataPack.writeInt(dbPacket, guildEndTime)
	LDataPack.writeInt(dbPacket, globalEndTime)
	LDataPack.writeString(dbPacket, ownersStr)
	LDataPack.writeInt(dbPacket, guildId)
	LDataPack.writeInt(dbPacket, auctionId)
	LDataPack.writeInt(dbPacket, flag)
	System.flushDBPacket(dbClient, dbPacket)
	local genus = string.format("%s_%s", aitemConf.bid, aitemConf.buy)
	System.logCounter(id, tostring(id), "",	"auction", LGuild.getGuildName(LGuild.getGuildById(guildId or 0)), ownersStr,
		"add", (guildId ~= 0) and tostring(GoodsType.guild) or tostring(GoodsType.global),
		tostring(aitemConf.item.id), tostring(aitemConf.item.count), genus)
	return true
end

--物品下架
local function delGoods(id)
	local gdata = AuctionGoodsList[id]
	if not gdata then
		print("auctionsystem delGoods gdata is nil")
	end
	print("auctionsystem delGoods id:"..tostring(id))
	AuctionGoodsList[id] = nil
	local dbClient, dbPacket = System.allocDBPacket(serverId or 0, dbAuction, dbCmd.dcAuctionDel)
	LDataPack.writeInt(dbPacket, id)
	System.flushDBPacket(dbClient, dbPacket)
end

--使用拍卖盒
--@useType: 0 自己使用  1 拍卖
--@itemId: 拍卖盒物品id
function useAuctionBox(actor, useType, itemId)
	local itemConf = ItemConfig[itemId]
	if not itemConf then
		--没有这个物品，检查配置
		actor_log(actor, "useAuctionBox itemConf is nil, itemId:"..tostring(itemId))
		return
	end

	if itemConf.useType ~= AuctionConfig.auctionItemType then
		--不是拍卖盒
		actor_log(actor, "useAuctionBox useType error, itemId:"..tostring(itemId))
		return
	end

	--是否有此物品
	if LActor.getItemCount(actor, itemId) <= 0 then
		actor_log(actor, "useAuctionBox item not enough, itemId:"..tostring(itemId))
		return false
	end

	local data = getStaticData(actor)
	if not data then return false end
	if not data.opened or not data.opened[itemId] then
		--拍品盒还没打开过
		actor_log(actor, "useAuctionBox item had not opened, itemId:"..tostring(itemId))
		return false
	end

	local aitemConf = AuctionItem[data.opened[itemId]]
	if not aitemConf then
		--数据出错，赶紧报错警告
		actor_log(actor, "useAuctionBox aitemConf is nil, itemId:"..tostring(itemId)..", auctionId:"..tostring(data.opened[itemId]))
		data.opened[itemId] = nil  --先清数据再说
		assert(false)
		return false
	end

	if 0 == useType then
		--自己用
		LActor.giveAwards(actor, {aitemConf.item}, "auctionsystem useAuctionBox")
	else
		--拍卖
		if not addGoods({LActor.getActorId(actor)}, LActor.getGuildId(actor), data.opened[itemId], true) then return false end
	end

	data.opened[itemId] = nil
	LActor.costItem(actor, itemId, 1, "auctionsystem useAuctionBox")

	return true
end

--返还竞价邮件
local function giveBackBidderYb(gdata, goodsType, aitemConf)
	local bidder = 0
	if GoodsType.guild == goodsType then
		bidder = gdata.gbidder
	else
		bidder = gdata.bidder
	end
	if 0 ~= bidder then
		--有竞价者，邮件退回竞价
		local oldPrice = aitemConf.bid * (1 + AuctionConfig.priceIncrease * (gdata.bid - 1) /10000)
		local mailContext = string.format(AuctionConfig.exceedContent, ItemConfig[aitemConf.item.id].name, aitemConf.item.count)
		local mailData = {head=AuctionConfig.exceedTitle, context=mailContext, tAwardList={{type=0,id=2,count=oldPrice}}}
		mailsystem.sendMailById(bidder, mailData)

		--退回消费额度
		asynevent.reg(bidder, function(imageActor, hyLimit, ybLimit)
			local data = getStaticData(imageActor)
			if not data then return end
			data.hyLimit = (data.hyLimit or 0) + hyLimit
			data.ybLimit = (data.ybLimit or 0) + ybLimit
			if data.hyLimit > AuctionConfig.quotaMax then data.hyLimit = AuctionConfig.quotaMax end
		end, gdata.hyLimit, gdata.ybLimit)
	end
end

--获取商品类型
local function getGoodsType(gdata, nowTime)
	if not nowTime then nowTime = System.getNowTime() end
	if nowTime < gdata.guildEndTime then
		return GoodsType.guild   --公会拍卖商品
	elseif nowTime < gdata.globalEndTime and (gdata.gbidder or 0) == 0 then
		return GoodsType.global  --全服拍卖商品
	end
	return GoodsType.lose  --失效商品
end

--写一个可以出售的商品的数据
local function writeOneGoodsPack(aid, guildId, goodsType, pack, gdata, nowTime)
	local gt = getGoodsType(gdata, nowTime)
	if goodsType == gt then
		--类型符合的商品
		if goodsType == GoodsType.global or guildId == gdata.guildId then
			LDataPack.writeChar(pack, goodsType)
			LDataPack.writeInt(pack, (goodsType == GoodsType.guild) and gdata.guildEndTime or gdata.globalEndTime)
			LDataPack.writeInt(pack, gdata.id)
			LDataPack.writeInt(pack, (goodsType == GoodsType.guild) and gdata.addTime or gdata.guildEndTime)
			LDataPack.writeInt(pack, gdata.auctionId)
			LDataPack.writeChar(pack, gdata.bid or 0)
			local bidder = (goodsType == GoodsType.guild) and gdata.gbidder or gdata.bidder
			LDataPack.writeChar(pack, aid == bidder and 1 or 0)
			if gdata.owners[1] == aid and System.bitOPMask(gdata.flag, FlagType.isPersonal) then
				--自己的个人商品
				LDataPack.writeChar(pack, 1)
			elseif guildId ~= 0 and guildId == gdata.guildId and not System.bitOPMask(gdata.flag, FlagType.isPersonal) then
				--同公会的非个人商品
				LDataPack.writeChar(pack, 2)
			else
				LDataPack.writeChar(pack, 0)
			end
			return true
		end
	end
	return false
end

--写一个商品的数据
local function writeGoodsData(actor, id, goodsType, pack, gdata)
	if not pack then
		actor_log(actor, "writeGoodsData pack is nil")
		return
	end

	if not gdata then
		--没有这个东西
		LDataPack.writeChar(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, id or 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeChar(pack, 0)
		LDataPack.writeChar(pack, 0)
		LDataPack.writeChar(pack, 0)
		return
	end
	if not writeOneGoodsPack(LActor.getActorId(actor), LActor.getGuildId(actor), goodsType, pack, gdata) then
		LDataPack.writeChar(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, id or 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeChar(pack, 0)
		LDataPack.writeChar(pack, 0)
		LDataPack.writeChar(pack, 0)
		actor_log(actor, "writeOneGoodsPack fail")
	end
end

--检测商品是否在展示时间
local function isInShowTime(gdata, goodsType)
	local nowTime = System.getNowTime()
	if not goodsType then goodsType = getGoodsType(gdata, nowTime) end
	
	if goodsType == GoodsType.guild and gdata.addTime + AuctionConfig.guildShowTime >= nowTime then
		return true
	elseif goodsType == GoodsType.global and gdata.guildEndTime + AuctionConfig.globalShowTime >= nowTime then
		return true
	end
	return false
end

--判断是否能对商品操作
local function canUse(actor, gdata, goodsType)
	if goodsType == GoodsType.guild and LActor.getGuildId(actor) ~= gdata.guildId then
		--不允许拍别公会的商品
		actor_log(actor, "canUse guildId error, id:"..tostring(id)..", guildId:"..tostring(gdata.guildId))
		return false
	end
	return true
end

--检查商品是否可购买或竞拍
local function checkGoods(actor, id, goodsType)
	local gdata = AuctionGoodsList[id]
	if not gdata then
		--物品不存在
		actor_log(actor, "checkGoods gdata is nil, id:"..tostring(id))
		return ResultNo.empty
	end
	local gt = getGoodsType(gdata)
	if gt == GoodsType.lose then
		--物品失效
		actor_log(actor, "checkGoods gt == GoodsType.lose, id:"..tostring(id))
		return ResultNo.empty, gdata
	end
	if goodsType ~= gt then
		--不匹配的操作
		actor_log(actor, "checkGoods goodsType ~= gt, id:"..tostring(id))
		return ResultNo.update, gdata
	end
	if isInShowTime(gdata, gt) then
		--还在展示时间
		actor_log(actor, "checkGoods isInShowTime, id:"..tostring(id))
		return ResultNo.showtime, gdata
	end
	if not canUse(actor, gdata, gt) then
		--非法操作
		actor_log(actor, "checkGoods can not use, id:"..tostring(id))
		return ResultNo.empty, gdata
	end
	return ResultNo.success, gdata
end

--检查额度
local function checkLimit(actor, adata, price)
	if not adata then adata = getStaticData(actor) end
	if not adata then return false end
	if (adata.hyLimit or 0) + (adata.ybLimit or 0) < price then
		return false
	end
	return true
end

--使用额度
local function useLimit(actor, adata, price, gdata)
	if not adata then adata = getStaticData(actor) end
	if not adata then return false end
	if (adata.hyLimit or 0) < price then
		if (adata.hyLimit or 0) + (adata.ybLimit or 0) < price then
			return false
		else
			gdata.hyLimit = adata.hyLimit or 0
			gdata.ybLimit = price - gdata.hyLimit
			adata.ybLimit = (adata.ybLimit or 0) - gdata.ybLimit
			adata.hyLimit = 0
		end
	else
		adata.hyLimit = adata.hyLimit - price
		gdata.hyLimit = price
	end
	return true
end

--拍卖成功处理
local function buySuccess(aid, price, gdata, aitemConf, goodsType)
	--购买成功邮件
	local buyContext = string.format(AuctionConfig.buySuccessContent, price, ItemConfig[aitemConf.item.id].name, aitemConf.item.count)
	local buyData = {head=AuctionConfig.buySuccessTitle, context=buyContext, tAwardList={aitemConf.item}}
	mailsystem.sendMailById(aid, buyData)

	--计算收益
	local tax = 0
	if goodsType == GoodsType.guild then
		tax = AuctionConfig.guildTax
	else
		tax = AuctionConfig.globalTax
	end
	local totalIncome = price * (1-tax/10000)  --扣税
	local ownerCount = #gdata.owners
	if ownerCount > 0 then
		local income = math.floor(totalIncome / ownerCount)
		if income < 1 then income = 1 end
		--拍卖成功邮件
		local sellContext = ""
		local sellData = nil
		if ownerCount == 1 and System.bitOPMask(gdata.flag, FlagType.isPersonal) then
			sellContext = string.format(AuctionConfig.sellSuccessContent, ItemConfig[aitemConf.item.id].name, aitemConf.item.count, price, income)
			sellData = {head=AuctionConfig.sellSuccessTitle, context=sellContext, tAwardList={{type=0,id=2,count=income}}}
		else
			sellContext = string.format(AuctionConfig.sellSuccessGuildContent, ItemConfig[aitemConf.item.id].name, aitemConf.item.count, price, income)
			sellData = {head=AuctionConfig.sellSuccessGuildTitle, context=sellContext, tAwardList={{type=0,id=2,count=income}}}
		end
		for _, v in pairs(gdata.owners) do
			mailsystem.sendMailById(tonumber(v), sellData)
		end
	else
		--没有归属者，不正常
		actor_log(actor, "buySuccess ownerCount <= 0, id:"..tostring(id))
	end
end

--购买商品
local function buyGoods(actor, id, goodsType)
	local ret, gdata = checkGoods(actor, id, goodsType)
	if ret == ResultNo.success then
		local aitemConf = AuctionItem[AuctionGoodsList[id].auctionId]
		if not aitemConf then
			--数据出错，赶紧报错警告
			actor_log(actor, "buyGoods aitemConf is nil, id:"..tostring(id)..", auctionId:"..tostring(AuctionGoodsList[id].auctionId))
			return
		end
		if (aitemConf.buy or 0) <= 0 then
			--此商品只能竞价
			actor_log(actor, "buyGoods aitemConf.buy = 0, id:"..tostring(id))
			return
		end

		--检查额度
		local adata = getStaticData(actor)
		if not adata then return end
		if not checkLimit(actor, adata, aitemConf.buy) then
			actor_log(actor, "buyGoods check limit fail, id:"..tostring(id))
			local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_Limit)
			if not pack then return end
			LDataPack.writeInt(pack, adata.hyLimit or 0)
			LDataPack.writeInt(pack, adata.ybLimit or 0)
			LDataPack.flush(pack)
			return
		end

		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if yb < aitemConf.buy then --钱不够
			actor_log(actor, "buyGoods no money")
			return
		end

		actor_log(actor, "buyGoods success id:"..tostring(id)..", price:"..tostring(aitemConf.buy)..", auctionid:"..tostring(gdata.auctionId))

		LActor.changeYuanBao(actor, 0-aitemConf.buy, "auctionsystem buyGoods", true)

		--返还竞价者元宝
		giveBackBidderYb(gdata, goodsType, aitemConf)

		if not useLimit(actor, adata, aitemConf.buy, gdata) then
			actor_log(actor, "buyGoods useLimit fail, id:"..tostring(id))
			--前面已经检查过了，基本不可能出现
			--return  先让流程走下去吧
		end

		buySuccess(LActor.getActorId(actor), aitemConf.buy, gdata, aitemConf, goodsType)
		addRecord(gdata.auctionId, LActor.getActorName(LActor.getActorId(actor)), TxType.buy, aitemConf.buy, (goodsType == GoodsType.guild) and LActor.getGuildId(actor) or 0)
		local genus = string.format("%s_%s", aitemConf.bid, aitemConf.buy)
		System.logCounter(id, tostring(id), tostring(aitemConf.buy), "auction", LActor.getName(actor), ownersT2S(gdata.owners),
			"buy", tostring(goodsType), tostring(aitemConf.item.id), tostring(aitemConf.item.count), genus)
		delGoods(id)
	end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_RepBuy)
	if not pack then return end
	LDataPack.writeChar(pack, ret)
	writeGoodsData(actor, id, goodsType, pack, gdata)
	LDataPack.flush(pack)
end

--流拍商品处理
local function bidFailed(gdata, aitemConf)
	print("auctionsystem bidFailed id:"..tostring(gdata.id)..", auctionid:"..tostring(gdata.auctionId))
	local ownerCount = #gdata.owners
	if ownerCount > 0 then
		if ownerCount == 1 and System.bitOPMask(gdata.flag, FlagType.isPersonal) then
			--个人拍品邮件退回物品
			local mailContext = string.format(AuctionConfig.sellFailureContent, ItemConfig[aitemConf.item.id].name, aitemConf.item.count)
			local mailData = {head=AuctionConfig.sellFailureTitle, context=mailContext, tAwardList={aitemConf.item}}
			mailsystem.sendMailById(gdata.owners[1], mailData)
		end
	else
		--没有归属者，不正常
		print("auctionsystem bidFailed ownerCount <= 0, id:"..tostring(gdata.id))
	end
end

--定时检查商品
local function onGameTimer()
	local dbClient, dbPacket = System.allocDBPacket(serverId or 0, dbAuction, dbCmd.dcAuctionUpdate)
	local count = 0
	local pos1 = LDataPack.getPosition(dbPacket)
	LDataPack.writeInt(dbPacket, count)

	local nowTime = System.getNowTime()
	for id,v in pairs(AuctionGoodsList) do
		local aitemConf = AuctionItem[v.auctionId]
		local genus = string.format("%s_%s", aitemConf.bid, aitemConf.buy)
		if nowTime >= v.guildEndTime and (v.guildId or 0) ~= 0 and not System.bitOPMask(v.flag, FlagType.isRecord) then
			if (v.gbidder or 0) ~= 0 then
				--公会商品竞拍成功
				local price = aitemConf.bid * (1 + AuctionConfig.priceIncrease * (v.bid - 1) /10000)
				print("auctionsystem guild bid success, id:"..tostring(id)..", gbidder:"..tostring(v.gbidder))
				buySuccess(v.gbidder, price, v, aitemConf, GoodsType.guild)
				addRecord(v.auctionId, LActor.getActorName(v.gbidder), TxType.bid, price, v.guildId)
				System.logCounter(id, tostring(id), tostring(price), "auction", LActor.getActorName(v.gbidder), ownersT2S(v.owners),
					"success", tostring(GoodsType.guild), tostring(aitemConf.item.id), tostring(aitemConf.item.count), genus)
				delGoods(id)
			elseif not System.bitOPMask(v.flag, FlagType.isRecord) then
				--公会流拍至全服
				v.flag = System.bitOpSetMask(v.flag, FlagType.isRecord, true)
				addRecord(v.auctionId, "", TxType.failed, 0, v.guildId)
				v.ischange = true
				System.logCounter(id, tostring(id), tostring(v.addTime), "auction", "", "",
					"fail", tostring(GoodsType.guild), tostring(aitemConf.item.id), tostring(aitemConf.item.count), genus)
			end
		elseif nowTime > v.globalEndTime then
			if (v.gbidder or 0) ~= 0 then
				--不该出现
				print("auctionsystem onGameTimer gbidder ~= 0, id:"..tostring(v.id)..", gbidder:"..tostring(v.gbidder))
			end
			if (v.bidder or 0) ~= 0 then
				--全服商品竞拍成功
				local price = aitemConf.bid * (1 + AuctionConfig.priceIncrease * (v.bid - 1) /10000)
				print("auctionsystem global bid success, id:"..tostring(v.id)..", bidder:"..tostring(v.bidder))
				buySuccess(v.bidder, price, v, aitemConf, GoodsType.global)
				addRecord(v.auctionId, LActor.getActorName(v.bidder), TxType.bid, price, 0)
				System.logCounter(id, tostring(id), tostring(price), "auction", LActor.getActorName(v.gbidder), ownersT2S(v.owners),
					"success", tostring(GoodsType.global), tostring(aitemConf.item.id), tostring(aitemConf.item.count), genus)
			else
				--流拍
				bidFailed(v, AuctionItem[v.auctionId])
				addRecord(v.auctionId, "", TxType.failed, 0, 0)
				System.logCounter(id, tostring(id), tostring(v.addTime), "auction", "", "",
					"fail", tostring(GoodsType.global), tostring(aitemConf.item.id), tostring(aitemConf.item.count), genus)
			end
			delGoods(id)
		end

		if v.ischange then
			LDataPack.writeInt(dbPacket, v.guildEndTime)
			LDataPack.writeInt(dbPacket, v.globalEndTime)
			LDataPack.writeInt(dbPacket, v.bid)
			LDataPack.writeInt(dbPacket, v.bidder)
			LDataPack.writeInt(dbPacket, v.gbidder)
			LDataPack.writeInt(dbPacket, v.flag)
			LDataPack.writeInt(dbPacket, v.hyLimit)
			LDataPack.writeInt(dbPacket, v.ybLimit)
			LDataPack.writeInt(dbPacket, id)
			v.ischange = false
			count = count + 1
		end
	end
	local pos2 = LDataPack.getPosition(dbPacket)
	LDataPack.setPosition(dbPacket, pos1)
	LDataPack.writeInt(dbPacket, count)
	LDataPack.setPosition(dbPacket, pos2)
	System.flushDBPacket(dbClient, dbPacket)
end

--加载数据
local function loadData()
	local db = System.createActorsDbConn()
	local sql = string.format("select * from auction where serverid=%d", System.getServerId())
	local err = System.dbQuery(db, sql)
	if err ~= 0 then
		print("auctionsystem loadData fail, dbQuery fail.")
		return
	end

	local count = System.dbGetRowCount(db)
	local row = System.dbCurrentRow(db)
	for i=1, count do
		local id = tonumber(System.dbGetRow(row, 0))
		local addTime = tonumber(System.dbGetRow(row, 1))
		local guildEndTime = tonumber(System.dbGetRow(row, 2))
		local globalEndTime = tonumber(System.dbGetRow(row, 3))
		local owners = System.dbGetRow(row, 4)
		local tOwners = ownersS2T(owners)
		local guildId = tonumber(System.dbGetRow(row, 5))
		local auctionId = tonumber(System.dbGetRow(row, 6))
		local bid = tonumber(System.dbGetRow(row, 7))
		local bidder = tonumber(System.dbGetRow(row, 8))
		local gbidder = tonumber(System.dbGetRow(row, 9))
		local flag = tonumber(System.dbGetRow(row, 11))
		local hyLimit = tonumber(System.dbGetRow(row, 12))
		local ybLimit = tonumber(System.dbGetRow(row, 13))
		print("auctionsystem loadData id = "..tostring(id))
		AuctionGoodsList[id] = {
			id = id,
			addTime = addTime,
			guildEndTime = guildEndTime,
			globalEndTime = globalEndTime,
			owners = tOwners,
			guildId = guildId,
			auctionId = auctionId,
			bid = bid,
			bidder = bidder,
			gbidder = gbidder,
			flag = flag,
			hyLimit = hyLimit,
			ybLimit = ybLimit,
		}
		row = System.dbNextRow(db)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
	System.delActorsDbConn(db)
	onGameTimer()
end

--玩家登录
local function onLogin(actor)
	local data = getStaticData(actor)
	if not data then return end
	if 1 ~= data.init then
		data.hyLimit = 0
		data.ybLimit = LActor.getRecharge(actor)
		data.init = 1
	end
end

--增加充值额度
local function onRecharge(actor, val)
	local data = getStaticData(actor)
	if not data then return end
	data.ybLimit = (data.ybLimit or 0) + val
end

--增加活跃额度
local function onDayLiLian(actor, num)
	local data = getStaticData(actor)
	if not data then return end
	data.hyLimit = (data.hyLimit or 0) + num * AuctionConfig.positiveParameter
	if data.hyLimit > AuctionConfig.quotaMax then data.hyLimit = AuctionConfig.quotaMax end
end

--协议 76-1
--请求商品列表
local function onReqGoodsList(actor, packet)
	local goodsType = LDataPack.readChar(packet)
	local goodsCount = 0
	local nowTime = System.getNowTime()
	local actorId = LActor.getActorId(actor)
	local guildId = LActor.getGuildId(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_RepGoodsList)
	if not pack then return end
	LDataPack.writeChar(pack, goodsType)
	local pos1 = LDataPack.getPosition(pack)
	LDataPack.writeInt(pack, goodsCount)

	for k,v in pairs(AuctionGoodsList) do
		if writeOneGoodsPack(actorId, guildId, goodsType, pack, v, nowTime) then
			goodsCount = goodsCount + 1
		end
	end

	local pos2 = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos1)
	LDataPack.writeInt(pack, goodsCount)
	LDataPack.setPosition(pack, pos2)
	LDataPack.flush(pack)
end

--协议 76-2
--打开拍卖盒
local function onReqOpenBox(actor, packet)
	local itemId = LDataPack.readInt(packet)

	local itemConf = ItemConfig[itemId]
	if not itemConf then
		--没有这个物品，检查配置
		actor_log(actor, "onReqOpenBox itemConf is nil, itemId:"..tostring(itemId))
		return
	end

	if itemConf.useType ~= AuctionConfig.auctionItemType then
		--不是拍卖盒
		actor_log(actor, "onReqOpenBox useType error, itemId:"..tostring(itemId))
		return
	end

	--是否有此物品
	if LActor.getItemCount(actor, itemId) <= 0 then
		actor_log(actor, "onReqOpenBox item not enough, itemId:"..tostring(itemId))
		return
	end

	local data = getStaticData(actor)
	if not data then return end
	if not data.opened then data.opened = {} end
	if not data.opened[itemId] then
		--随机一个拍卖id
		local randTab = {}
		local randCount = 0
		local ret = auctiondrop.dropGroup(itemConf.useArg)
		data.opened[itemId] = ret[1]
		if not data.opened[itemId] then
			actor_log(actor, "onReqOpenBox get auctionid error, itemId:"..tostring(itemId))
			return
		end
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_RepOpenBox)
	if not pack then return end
	LDataPack.writeInt(pack, itemId)
	LDataPack.writeInt(pack, data.opened[itemId])
	LDataPack.flush(pack)
end

--协议 76-3
--使用拍卖盒
local function onReqUseBox(actor, packet)
	local useType = LDataPack.readChar(packet)
	local itemId = LDataPack.readInt(packet)

	useAuctionBox(actor, useType, itemId)

	-- local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_RepOpenBox)
	-- if not pack then return end
	-- LDataPack.writeInt(pack, itemId)
	-- LDataPack.writeShort(pack, data.opened[itemId])
	-- LDataPack.flush(pack)
end

--协议 76-4
--竞拍
local function onReqBid(actor, packet)
	local id = LDataPack.readInt(packet)
	local goodsType = LDataPack.readChar(packet)
	local bidTimes = LDataPack.readChar(packet)
	
	local ret, gdata = checkGoods(actor, id, goodsType)
	if ret == ResultNo.success then
		--检测配置
		local aitemConf = AuctionItem[gdata.auctionId]
		if not aitemConf then
			--数据出错，赶紧报错警告
			actor_log(actor, "onReqBid aitemConf is nil, id:"..tostring(id)..", auctionId:"..tostring(gdata.auctionId))
			return
		end
		--检测竞价次数
		if (gdata.bid or 0) + 1 ~= bidTimes then
			--竞价次数过时，更新数据
			local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_RepBid)
			if not pack then return end
			LDataPack.writeChar(pack, ResultNo.update)
			writeGoodsData(actor, id, goodsType, pack, gdata)
			LDataPack.flush(pack)
			return
		end

		--直接购买的情况
		local bidPrice = aitemConf.bid * (1 + AuctionConfig.priceIncrease * (bidTimes - 1) /10000)
		if (aitemConf.buy or 0) > 0 and bidPrice >= aitemConf.buy then
			--竞价大于等于一口价，直接购买
			buyGoods(actor, id, goodsType)
			actor_log(actor, "onReqBid buyGoods, id:"..tostring(id)..", auctionId:"..tostring(gdata.auctionId))
			return
		end

		--检查额度
		local adata = getStaticData(actor)
		if not adata then return end
		if not checkLimit(actor, adata, bidPrice) then
			actor_log(actor, "onReqBid checkLimit fail, id:"..tostring(id))
			local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_Limit)
			if not pack then return end
			LDataPack.writeInt(pack, adata.hyLimit or 0)
			LDataPack.writeInt(pack, adata.ybLimit or 0)
			LDataPack.flush(pack)
			return
		end

		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if yb < bidPrice then
			--钱不够
			actor_log(actor, "onReqBid no money")
			return
		end

		actor_log(actor, "onReqBid success id:"..tostring(id)..", price:"..tostring(bidPrice)..", auctionid:"..tostring(gdata.auctionId))

		LActor.changeYuanBao(actor, 0-bidPrice, "auctionsystem onReqBid", true)
		--返还竞拍元宝
		giveBackBidderYb(gdata, goodsType, aitemConf)

		if not useLimit(actor, adata, bidPrice, gdata) then
			actor_log(actor, "onReqBid useLimit fail, id:"..tostring(id))
			--前面已经检查过了，基本不可能出现
			--return  先让流程走下去吧
		end

		--更新竞拍信息
		gdata.bid = (gdata.bid or 0) + 1
		if GoodsType.guild == goodsType then
			gdata.gbidder = LActor.getActorId(actor)
		else
			gdata.bidder = LActor.getActorId(actor)
		end

		--是否抢拍
		local nowTime = System.getNowTime()
		if (goodsType == GoodsType.guild and gdata.guildEndTime - nowTime < AuctionConfig.rushTime) then
			gdata.guildEndTime = nowTime + AuctionConfig.rushTime
			gdata.globalEndTime = gdata.guildEndTime + AuctionConfig.globalShowTime + aitemConf.globalTime
		elseif (goodsType == GoodsType.global and gdata.globalEndTime - nowTime < AuctionConfig.rushTime) then
			gdata.globalEndTime = nowTime + AuctionConfig.rushTime
		end
		gdata.ischange = true
		local genus = string.format("%s_%s", aitemConf.bid, aitemConf.buy)
		System.logCounter(id, tostring(id), tostring(bidPrice),	"auction", LActor.getName(actor), "",
			"bid", tostring(goodsType), tostring(aitemConf.item.id), tostring(aitemConf.item.count), genus)

	end
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_RepBid)
	if not pack then return end
	LDataPack.writeChar(pack, ret)
	writeGoodsData(actor, id, goodsType, pack, gdata)
	LDataPack.flush(pack)
end

--协议 76-5
--一口价购买
local function onReqBuy(actor, packet)
	local id = LDataPack.readInt(packet)
	local goodsType = LDataPack.readChar(packet)
	buyGoods(actor, id, goodsType)
end

--协议 76-6
--请求成交记录
local function onReqRecordList(actor, packet)
	local goodsType = LDataPack.readChar(packet)
	local guildId = 0
	local count = 0
	if GoodsType.guild == goodsType then guildId = LActor.getGuildId(actor) end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Auction, Protocol.sAuctionCmd_RepRecordList)
	if not pack then return end
	if 0 == guildId then
		LDataPack.writeChar(pack, 1)  --全服记录
	else
		LDataPack.writeChar(pack, 0)  --公会记录
	end
	local pos1 = LDataPack.getPosition(pack)
	LDataPack.writeShort(pack, count)
	for _,v in pairs(AuctionRecord) do
		if guildId == v.guildId then
			LDataPack.writeInt(pack, v.auctionId)
			LDataPack.writeString(pack, v.name)
			LDataPack.writeChar(pack, v.txType)
			LDataPack.writeInt(pack, v.price)
			LDataPack.writeInt(pack, v.time)
			count = count + 1
		end
	end
	local pos2 = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos1)
	LDataPack.writeShort(pack, count)
	LDataPack.setPosition(pack, pos2)
	LDataPack.flush(pack)
end

engineevent.regGameStopEvent(onGameTimer)
engineevent.regGameTimer(onGameTimer)
engineevent.regGameStartEvent(loadData)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeRecharge, onRecharge)
actorevent.reg(aeDayLiLian, onDayLiLian)

netmsgdispatcher.reg(Protocol.CMD_Auction, Protocol.cAuctionCmd_ReqGoodsList, onReqGoodsList)    --协议 76-1
netmsgdispatcher.reg(Protocol.CMD_Auction, Protocol.cAuctionCmd_ReqOpenBox, onReqOpenBox)        --协议 76-2
netmsgdispatcher.reg(Protocol.CMD_Auction, Protocol.cAuctionCmd_ReqUseBox, onReqUseBox)          --协议 76-3
netmsgdispatcher.reg(Protocol.CMD_Auction, Protocol.cAuctionCmd_ReqBid, onReqBid)                --协议 76-4
netmsgdispatcher.reg(Protocol.CMD_Auction, Protocol.cAuctionCmd_ReqBuy, onReqBuy)                --协议 76-5
netmsgdispatcher.reg(Protocol.CMD_Auction, Protocol.cAuctionCmd_ReqRecordList, onReqRecordList)  --协议 76-6

function gmSetLimit(actor, limitType, limit)
	local data = getStaticData(actor)
	if not data then return false end
	if limitType == 0 then
		data.hyLimit = limit
		if (data.hyLimit or 0) > AuctionConfig.quotaMax then data.hyLimit = AuctionConfig.quotaMax end
	else
		data.ybLimit = limit
	end
	return true
end
