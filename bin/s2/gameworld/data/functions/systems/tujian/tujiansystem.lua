module("tujiansystem", package.seeall)

local function getStaticDataById(actor,id)
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.TuLuData then
		var.TuLuData = {}
	end
	if not var.TuLuData[id] then
		var.TuLuData[id] = {}
		var.TuLuData[id].isActivate = 0
		var.TuLuData[id].starlevel = 0
		--var.TuLuData[id].Exp = 0
	end
	return var.TuLuData[id]
end

local function getSuitDataById(actor,id)
	local var = LActor.getStaticVar(actor)
	if not var then return end

	if id < 1 then	
		LActor.log(actor,"tujiansystem.getSuitDataById", "id error",id)
		return
	end

	if not var.SuitData then
		var.SuitData = {}
	end

	if not var.SuitData[id] then
		var.SuitData[id] = {}
		var.SuitData[id].cout = 0
	end

	return var.SuitData[id]
end

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.TuLuData then
		var.TuLuData = {}
	end
	--所有卡牌的数量
	if var.TuLuData.CardsCount == nil then
		var.TuLuData.CardsCount = 0
	end

	--源数据表
	if var.TuLuData.Cards == nil then
		var.TuLuData.Cards = {}
	end
	
	--分解获得的经验
	if var.TuLuData.Exp == nil then
		var.TuLuData.Exp = 0
	end
	
	return var.TuLuData
end

--通过id判断是哪个套装
local function CheckKitById(actor,id)
	for i=1, #SuitConfig do
		for j=1,#SuitConfig[i][1].idList do
			if id == SuitConfig[i][1].idList[j] then
				return i
			end
		end
	end

	return 0
end

local function getKitAttrByCout(actor,id,cout)
	local conf = nil
	for _,sv in ipairs(SuitConfig[id] or {}) do
		if (nil == conf or sv.count > conf.count) then
			if cout >= sv.count then
				conf = sv
			end
		end
	end
	return conf and conf.attrs or nil
end

local function SendAllCardsInfo(actor)
	local var = getStaticData(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_TuJian, Protocol.sTuJianCmd_ReqInfo)
	if not pack then return end
	LDataPack.writeInt(pack, var.CardsCount)
	for i=1, var.CardsCount do
		local cardId = var.Cards[i].id
		local varData = getStaticDataById(actor,cardId)
		LDataPack.writeShort(pack,cardId)
		LDataPack.writeShort(pack,varData.starlevel)
	end
	LDataPack.writeInt(pack, var.Exp or 0)
	LDataPack.writeDouble(pack, LActor.TuJianPower(actor))
	LDataPack.flush(pack)
end

local function updateAttr(actor)
	local attr = LActor.getActorsystemAttr(actor,attrTuJian)
	if attr == nil then
		print(LActor.getActorId(actor).." tujiansystem.updateAttr attr is nil")
		return
	end

	local varData = getStaticData(actor)

	-- 卡牌属性
	attr:Reset()
	for i=1, varData.CardsCount do
		local cardId = varData.Cards[i].id
		local StaticData = getStaticDataById(actor,cardId)
		local star = StaticData.starlevel or 0
		
		--[[
		while (true) do
			if star < DecomposeConfig[cardId].topStar and StaticData.Exp >= CardConfig[cardId][star+1].cost then
				StaticData.Exp = StaticData.Exp - CardConfig[cardId][star+1].cost
				StaticData.starlevel = StaticData.starlevel + 1
				star = StaticData.starlevel
			else
				break
			end
		end
		]]
		
		local attrs = CardConfig[cardId][star].attrs
		if attrs ~= nil then
			for _,v in pairs(attrs) do
				attr:Add(v.type, v.value)
			end
		end
	end

	-- 套装属性
	for j=1, #SuitConfig do
		local SuitData = getSuitDataById(actor,j)
		local KitAttr = getKitAttrByCout(actor,j,SuitData.cout)
		if KitAttr ~= nil then
			for _,v in pairs(KitAttr) do
				attr:Add(v.type, v.value)
			end
		end
	end
	
	LActor.reCalcAttr(actor)
	SendAllCardsInfo(actor)
	specialattribute.updateAttribute(actor)
end

function updateAttributes(actor, sysType)
	local varData = getStaticData(actor)
	for i=1, varData.CardsCount do
		local cardId = varData.Cards[i].id
		local StaticData = getStaticDataById(actor,cardId)
		local star = StaticData.starlevel or 0

		if CardConfig[cardId][star] then
			local specialattr = CardConfig[cardId][star].specialAttr
			if specialattr ~= nil then
				for _,v in pairs(specialattr) do
					specialattribute.add(actor,v.type,v.value,sysType)
				end
			end
		end
	end
end

local function Init(actor)
	updateAttr(actor)
end

local function onLogin(actor)
	updateAttr(actor)
end

local function onReqAllInfo(actor)
	updateAttr(actor)
end

local function onReqActivate(actor, packet)
	local id = LDataPack.readShort(packet)
	--Id是否非法
	if id < 1 then
		print(LActor.getActorId(actor).."tujiansystem.onReqActivate error id:"..id)
		return
	end
	--检测配置是否存在
	local cfg = DecomposeConfig[id]
	if not cfg then 
		print(LActor.getActorId(actor).."tujiansystem.onReqActivate not have DecomposeConfig, id:"..id)
		return
	end
	--检测激活道具是否足够
	local itemId = cfg.itemId
	if LActor.getItemCount(actor, itemId) < 1 then
		--LActor.sendTipmsg(actor, ScriptTips.tujian001, ttMessage)
		print(LActor.getActorId(actor).."tujiansystem.onReqActivate not have item, itemId:"..itemId.."id:"..id)
		return 
	end
	--获取当前需要激活的图鉴数据
	local var = getStaticDataById(actor,id)
	if not var.isActivate or 0 == var.isActivate then
		local varData = getStaticData(actor)
		varData.CardsCount = varData.CardsCount + 1
		var.isActivate = 1
		var.starlevel = 0
		
		--{[图鉴激活顺序]=>ID,...}
		local curidx = varData.CardsCount
		if varData.Cards[curidx] == nil then
			varData.Cards[curidx] = {}
		end
		varData.Cards[curidx].id = DecomposeConfig[id].id
		
		--套装
		local Kitid = CheckKitById(actor,id)
		if Kitid > 0 then
			local SuitData = getSuitDataById(actor,Kitid)
			SuitData.cout = SuitData.cout + 1
		end

		--真实扣除道具
		LActor.costItem(actor, itemId, 1, "tujiansystem onReqActivate")

		--更新属性
		updateAttr(actor)

		--成就
		actorevent.onEvent(actor, aeTuJian)

		if cfg.noticeId then
			noticemanager.broadCastNotice(cfg.noticeId, LActor.getName(actor) or "", cfg.name or "")
		end
	else
		--LActor.sendTipmsg(actor, ScriptTips.tujian002, ttMessage)
		print(LActor.getActorId(actor).."tujiansystem.onReqActivate isActivate, id:"..id)
	end
end

local function onReqDecompose(actor, packet)
	--local cardId = LDataPack.readShort(packet) --要升级卡牌的ID
	local tCount = LDataPack.readInt(packet) --要分解的卡牌类型数量
	for k=1, tCount do
		local Id = LDataPack.readShort(packet) --要分解的卡牌的ID
		local dCount = LDataPack.readShort(packet) --要分解的卡牌的数量
		local itemId = DecomposeConfig[Id].itemId
		if LActor.getItemCount(actor, itemId) < dCount then
			LActor.log(actor,"tujiansystem onReqDecompose","itemId not enough",itemId)
			return
		end

		LActor.costItem(actor, itemId, dCount, "tujiansystem Decompose")
		--local var = getStaticDataById(actor,cardId)
		--var.Exp = var.Exp + DecomposeConfig[cardId].value * dCount
		local var = getStaticData(actor)
		var.Exp = (var.Exp or 0) + DecomposeConfig[Id].value * dCount
	end

	updateAttr(actor)
end

--请求升星卡牌
local function onReqUpLv(actor, packet)
	local cardId = LDataPack.readShort(packet) --要升级卡牌的ID
	local dcfg = DecomposeConfig[cardId]
	if not dcfg then 
		print(LActor.getActorId(actor).." tujiansystem.onReqUpLv, DecomposeConfig["..cardId.."] is nil")
		return
	end
	local StaticData = getStaticDataById(actor,cardId)
	--没有这个卡牌数据
	if not StaticData then
		print(LActor.getActorId(actor).." tujiansystem.onReqUpLv, getStaticDataById("..cardId..") is nil")
		return
	end
	local star = StaticData.starlevel or 0
	--最高级了
	if star >= dcfg.topStar then
		print(LActor.getActorId(actor).." tujiansystem.onReqUpLv, id:"..cardId.." is topStar")
		return
	end
	--判断等级配置里面有没有这个卡牌配置
	if not CardConfig[cardId] then
		print(LActor.getActorId(actor).." tujiansystem.onReqUpLv, id:"..cardId.." is not cardconfig")
		return
	end
	--判断是否到达了真是的最高级
	if not CardConfig[cardId][star+1] then
		print(LActor.getActorId(actor).." tujiansystem.onReqUpLv, id:"..cardId..",star:"..star.." is not next star conf")
		return
	end
	--获取静态数据
	local var = getStaticData(actor)
	--经验不足消耗
	if (var.Exp or 0) < (CardConfig[cardId][star+1].cost or 0) then
		print(LActor.getActorId(actor).." tujiansystem.onReqUpLv, id:"..cardId.." is Exp < cost")
		return
	end
	--扣经验
	var.Exp = (var.Exp or 0) - CardConfig[cardId][star+1].cost
	--升等级
	StaticData.starlevel = StaticData.starlevel + 1
	--更新属性
	updateAttr(actor)
end

function AddExp(actor, count)
	local var = getStaticData(actor)
	var.Exp = (var.Exp or 0) + count
	SendAllCardsInfo(actor) --updateAttr(actor)
end

actorevent.reg(aeInit, Init)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_TuJian, Protocol.cTuJianCmd_ReqInfo, onReqAllInfo)
netmsgdispatcher.reg(Protocol.CMD_TuJian, Protocol.cTuJianCmd_ReqActivate, onReqActivate)
netmsgdispatcher.reg(Protocol.CMD_TuJian, Protocol.cTuJianCmd_ReqDecompose, onReqDecompose)
netmsgdispatcher.reg(Protocol.CMD_TuJian, Protocol.cTuJianCmd_ReqUpLv, onReqUpLv)
