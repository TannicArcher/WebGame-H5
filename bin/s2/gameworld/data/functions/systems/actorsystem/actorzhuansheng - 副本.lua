module("actorzhuansheng", package.seeall)
--具有"传奇"特色的转生系统


--[[
zhuanShengData = {
	int conversionCount
	int normalCount
	int advanceCount
}
 ]]

local zsconfig = ZhuanShengConfig
--保持配置和其他模块用到的常量一致
assert(zsconfig.level == ZHUAN_SHENG_BASE_LEVEL)

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.zhuanShengData == nil then
		var.zhuanShengData = {}
	end
	return var.zhuanShengData
end

local function updateInfo(actor)
	local actordata = LActor.getActorData(actor)
	if actordata == nil then return end
	local data = getStaticData(actor)
	if data == nil then return end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_ZhuanSheng, Protocol.sZhuanShengCmd_UpdateInfo)
	if npack == nil then return end
	LDataPack.writeInt(npack, actordata.zhuansheng_lv)
	LDataPack.writeInt(npack, actordata.zhuansheng_exp)
	LDataPack.writeShort(npack, data.conversionCount or 0)
	LDataPack.writeShort(npack, data.normalCount or 0)
	LDataPack.writeShort(npack, data.advanceCount or 0)
	LDataPack.flush(npack)
end

local function onReqPromote(actor, packet)
	local method = LDataPack.readByte(packet)
	local level = LActor.getLevel(actor)
	local useyuanbao = LDataPack.readByte(packet)
	if useyuanbao == 1 then useyuanbao = true else useyuanbao = false end
	if level < zsconfig.level then return end
	local data = getStaticData(actor)
	local exp
	if method == 1  then --等级转换
		if level < zsconfig.level + 1 then return end

		if (data.conversionCount or 0) >= zsconfig.conversionCount then
			print("actor:"..LActor.getActorId(actor).." converte failed count:"..data.conversionCount)
			return
		end

		LActor.setLevel(actor, level - 1)
		LActor.onLevelUp(actor)
		LActor.addExp(actor, 0, "zhuansheng reset exp")
		data.conversionCount = (data.conversionCount or 0) + 1
		if ZhuanShengExpConfig[level] == nil then return end
		exp = ZhuanShengExpConfig[level].exp
	elseif method == 2 then --普通物品提升
		if (data.normalCount or 0)	>= zsconfig.normalCount then
			print("actor:"..LActor.getActorId(actor).." convert failed count:"..data.normalCount)
			return
		end
		if not LActor.checkItemNum(actor, zsconfig.normalItem, 1, useyuanbao) then
			return
		end
		LActor.consumeItem(actor, zsconfig.normalItem, 1, useyuanbao, "zhuansheng cost normal item")
		data.normalCount = (data.normalCount or 0) + 1

		exp = zsconfig.normalExp
	elseif method == 3 then --高级物品提升
		if (data.advanceCount or 0) >= zsconfig.advanceCount then
			print("actor:"..LActor.getActorId(actor).." convert failed count:"..data.advanceCount)
			return
		end
		if not LActor.checkItemNum(actor, zsconfig.advanceItem, 1, useyuanbao) then
			return
		end
		LActor.consumeItem(actor, zsconfig.advanceItem, 1, useyuanbao, "zhuansheng cost advance item")
		data.advanceCount = (data.advanceCount or 0) + 1
		exp = zsconfig.advanceExp
	else
		return
	end

	local actordata = LActor.getActorData(actor)
	if actordata == nil then print("get actorData error") return end

	actordata.zhuansheng_exp = actordata.zhuansheng_exp + exp
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"get zs exp", tostring(exp), tostring(actordata.zhuansheng_exp), "", "method"..tostring(method), "", "")

	updateInfo(actor)
end

local function onReqUpgrade(actor, packet)
	local actordata = LActor.getActorData(actor)
	if actordata == nil then return end
	local config = ZhuanShengLevelConfig[actordata.zhuansheng_lv + 1]
	if config == nil then return end

	if actordata.zhuansheng_exp < config.exp then
		return
	end

	local attr = LActor.getZhuanShengAttr(actor)
	if attr == nil then return end

	actordata.zhuansheng_exp = actordata.zhuansheng_exp - config.exp
	actordata.zhuansheng_lv = actordata.zhuansheng_lv + 1
	updateInfo(actor)

	attr:Set(Attribute.atAtk, config.atk)
	attr:Set(Attribute.atHpMax, config.hp)
	attr:Set(Attribute.atDef, config.def)
	attr:Set(Attribute.atRes, config.res)

	LActor.reCalcAttr(actor)

	actorevent.onEvent(actor, aeZhuansheng, actordata.zhuansheng_lv)
    System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
        "cost zs exp", tostring(config.exp), tostring(actordata.zhuansheng_exp), "", "upgrade zs level", "", "")
end

local function onLogin(actor)
	updateInfo(actor)
end

local function onNewDay(actor)
	local data = getStaticData(actor)
	if data == nil then return end

	data.conversionCount = 0
	data.normalCount = 0
	data.advanceCount = 0

	updateInfo(actor)
	print("on zhuanshengsys new day. aid:"..LActor.getActorId(actor))
end

local function calcAttr(actor)
--	print("----------------------------------------zhuansheng calcAttr")
	local attr = LActor.getZhuanShengAttr(actor)
	if attr == nil then return end

	local actordata = LActor.getActorData(actor)
	if actordata == nil then return end

	local config = ZhuanShengLevelConfig[actordata.zhuansheng_lv]
	if config == nil then return end

	attr:Set(Attribute.atAtk, config.atk)
	attr:Set(Attribute.atHpMax, config.hp)
	attr:Set(Attribute.atDef, config.def)
	attr:Set(Attribute.atRes, config.res)
end

function addExp(actor, val)
    if not val then return end
    local actordata = LActor.getActorData(actor)
    if actordata == nil then
		print("actorzhuansheng.addExp: get actorData error")
		return
	end
    actordata.zhuansheng_exp = actordata.zhuansheng_exp + val
    updateInfo(actor)
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)

netmsgdispatcher.reg(Protocol.CMD_ZhuanSheng, Protocol.cZhuanShengCmd_ReqPromote, onReqPromote)
netmsgdispatcher.reg(Protocol.CMD_ZhuanSheng, Protocol.cZhuanShengCmd_ReqUpgrade, onReqUpgrade)


_G.calcZhuanShengAttr = calcAttr

function gmAddExp(actor, v)
    if not v then return end
    local actordata = LActor.getActorData(actor)
    if actordata == nil then print("get actorData error") return end

    actordata.zhuansheng_exp = actordata.zhuansheng_exp + v

    updateInfo(actor)
end
