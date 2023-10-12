--熔炉功能,  加属性,通过熔炼特定的装备获得熔炼值exp升级
module("ronglu", package.seeall)


--[[
rongluData = {
	lv,
	exp,
}
--]]
local p = Protocol

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.rongluData == nil then
		var.rongluData = {}
	end
	return var.rongluData
end

local function updateInfo(actor)
	--local data = getStaticData(actor)
	--if data == nil then return end

	local npack = LDataPack.allocPacket(actor, p.CMD_Enhance, p.sEnhanceCmd_RongLuUpdate)
	if npack == nil then return end

	--LDataPack.writeInt(npack, data.lv or 0)
	--LDataPack.writeInt(npack, data.exp or 0)
	LDataPack.flush(npack)
end

local function reCalcAttr(actor, recalc)
	local attr = LActor.getRongLuAttr(actor)
	if attr == nil then return end

	local data = getStaticData(actor)
	if data == nil then return end

	attr:Reset()
	local conf = RongLuLevelConfig[data.lv or 0]
	if conf == nil then
		print("OnInit Ronglu Attr failed. level:"..tostring(data.lv).. " aid:"..LActor.getActorId(actor))
		return
	end

	--算出自己模块的属性
	attr:Reset()
	if conf.attr then
		for _, a in pairs(conf.attr) do
			attr:Set(a.type, a.value)
		end
	end
	if recalc then
		LActor.reCalcAttr(actor)
	end
end

local function onInit(actor)
	reCalcAttr(actor, false)
end

local function onLogin(actor)
	updateInfo(actor)
end

local function addExp(actor, exp)
	local data = getStaticData(actor)
	if data == nil then return end

	data.exp = (data.exp or 0) + exp
	local conf = RongLuLevelConfig
	local update = false
	while data.exp >= conf[data.lv or 0].exp do
		if conf[(data.lv or 0) + 1] ~= nil then
			data.exp = data.exp - conf[data.lv or 0].exp
			data.lv = (data.lv or 0) + 1
			update = true
			System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
				"ronglu", tostring(data.exp), tostring(data.lv), "", "levelup", "", "")
		else
			break
		end
	end
	if exp > 0 then
		updateInfo(actor)
	end
	if update then
		reCalcAttr(actor, true)
	end
end

local function onRongLian(actor, packet)
	local count = LDataPack.readShort(packet)
	if count == nil or count == 0 then return end

	--local data = getStaticData(actor)
	--if data == nil then return end

	local rewards = {}
	--local exp = 0
	for i=1,count do
		local itemId = LDataPack.readInt(packet)
		local smeltCount = LDataPack.readInt(packet)
		local itemCount = LActor.getItemCount(actor, itemId)
		local cfg = RongLuExpConfig[itemId]
		if cfg and itemCount > 0 then
			if itemCount < smeltCount then smeltCount = itemCount end
			LActor.costItem(actor, itemId, smeltCount, "ronglu ronglian")
			--exp = exp + cfg.exp*smeltCount
			if cfg.reward then
				for _, tb in ipairs(cfg.reward) do
					table.insert(rewards, {type=tb.type, id=tb.id, count=tb.count*smeltCount})
				end
			end

			System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
				"ronglu", tostring(itemId), tostring(cfg.exp), tostring(exp), "addexp", "", "")
		
		end
	end

	--addExp(actor, exp)
	LActor.giveAwards(actor, rewards, "ronglu rewards")
	updateInfo(actor)
end

--actorevent.reg(aeInit, onInit)
--actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(p.CMD_Enhance, p.cEnhanceCmd_RongLuRongLian, onRongLian)

function gmAddRongLuExp(actor, exp)
	addExp(actor, exp)
end
