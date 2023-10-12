--神兽
module("shenshousystem", package.seeall)

--[[
shenshou = {
	-- [神兽编号] = {神兽数据}
	[1] = {
		equip = {
			-- 装备
			-- [部位] = 物品id
			[1] = 0,
			[2] = 0,
			[3] = 0,
			[4] = 0,
			[5] = 0,
		},
		battle = 0, --是否出战
	},
	[2] = {...}
	...
	exp = 0,
	itemCount = 0,
}
]]

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("shenshousystem aid:" .. aid .. " log:" .. str)
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.shenshou then
		var.shenshou = {}
		var.shenshou.exp = 0
		var.shenshou.itemCount = 0
	end
	return var.shenshou
end

--检查系统是否开启
function checkOpen(actor, noLog)
	if System.getOpenServerDay() + 1 < ShenShouConfig.openserverday
		or LActor.getZhuanShengLevel(actor) < ShenShouConfig.openzhuanshenglv then
		if not noLog then actor_log(actor, "checkOpen false") end
		return false
	end
	return true
end

--发送基本信息
local function sendInfo(actor)
	if not checkOpen(actor) then return end
	local data = getStaticData(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_SendInfo)
	if not pack then return end

	local pos1 = LDataPack.getPosition(pack)
	local count = 0
	LDataPack.writeChar(pack, count)
	for i=1, #ShenShouBase do
		local ssdata = data[i]
		if ssdata ~= nil then
			LDataPack.writeChar(pack, i)
			LDataPack.writeChar(pack, ShenShouConfig.posCount)
			for j=1, ShenShouConfig.posCount do
				LDataPack.writeInt(pack, ssdata.equip[j] or 0)
			end
			LDataPack.writeChar(pack, ssdata.battle or 0)
			count = count + 1
		end
	end
	local pos2 = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos1)
	LDataPack.writeChar(pack, count)
	LDataPack.setPosition(pack, pos2)
	LDataPack.writeChar(pack, data.itemCount or 0)
	LDataPack.writeInt(pack, data.exp or 0)
	LDataPack.flush(pack)
end

--更新属性
local function updateAttr(actor)
	local data = getStaticData(actor)
	if not data then return end

	local attr = LActor.getActorsystemAttr(actor, attrShenShou)
	if attr == nil then
		actor_log(actor, "updateAttr attr is nil")
		return
	end
	attr:Reset()
	local expower = 0  --额外战力
	local totalAttrPer = {}

	--计算总装备属性提升百分比
	for i=1, #ShenShouBase do
		if nil ~= data[i] and (data[i].battle or 0) ~= 0 then
			for _, sid in pairs(ShenShouBase[i].skill or {}) do
				local skillConf = ShenShouSkill[sid]
				if skillConf.target == 1 then
					for id, v in pairs(skillConf.equipPercent or {}) do
						totalAttrPer[id] = (totalAttrPer[id] or 0) + v
					end
				end
			end
		end
	end

	for i=1, #ShenShouBase do
		if nil ~= data[i] and (data[i].battle or 0) ~= 0 then
			--技能属性
			local attrPer = {}
			for _, sid in pairs(ShenShouBase[i].skill or {}) do
				local skillConf = ShenShouSkill[sid]
				for _, v in pairs(skillConf.attrs or {}) do
					attr:Add(v.type, v.value)
				end
				if skillConf.target == 2 then
					for id, v in pairs(skillConf.equipPercent or {}) do
						attrPer[id] = (attrPer[id] or 0) + v
					end
				end
				expower = expower + (skillConf.expower or  0)
			end
			
			if nil ~= data[i].equip then
				for pos=1, ShenShouConfig.posCount do
					if (data[i].equip[pos] or 0) ~= 0 then
						local equipConf = ShenShouEquip[data[i].equip[pos]]
						if not equipConf then
							actor_log(actor, "updateAttr equipConf is nil, i:"..tostring(i)..", pos:"..tostring(pos))
							--数据出错，赶紧报错警告
							assert(false)
							return
						end
						for _, v in pairs(equipConf.attrs or {}) do
							attr:Add(v.type, v.value * (1 + ((totalAttrPer[v.type] or 0)+(attrPer[v.type] or 0))/10000))
						end
						expower = expower + (equipConf.expower or  0)
					else
						--基本不可能遇到。装备没齐就出战？报错警告！
						data[i].battle = 0
						assert(false)
						return
					end
				end
			end
		end
	end
	attr:SetExtraPower(expower)
	LActor.reCalcAttr(actor)
end

--改变经验
function changeShenShouExp(actor, exp, log)
	local data = getStaticData(actor)
	if not data then return end

	data.exp = (data.exp or 0) + exp

	local expLog = string.format("%s_%s", data.exp, exp)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "shenshou", expLog, log or "")

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_SendExp)
	if not pack then return end
	LDataPack.writeInt(pack, data.exp)
	LDataPack.flush(pack)
end

--初始化
local function onInit(actor)
	if not checkOpen(actor, true) then return end
	updateAttr(actor)
end

--玩家登录
local function onLogin(actor)
	if not checkOpen(actor, true) then return end
	sendInfo(actor)
end

--协议 73-2
--请求戴上装备
local function onReqEquip(actor, packet)
	local id = LDataPack.readChar(packet)
	local pos = LDataPack.readChar(packet)
	local itemId = LDataPack.readInt(packet)  --物品id
	
	if not checkOpen(actor) then return end

	local data = getStaticData(actor)
	if not data then return end

	local baseConf = ShenShouBase[id]
	if not baseConf then
		actor_log(actor, "onReqEquip ShenShouBase is nil, id:"..tostring(id))
		return
	end

	if not data[id] then data[id] = {} end
	local ssdata = data[id]
	if not ssdata.equip then ssdata.equip = {} end

	if itemId ~= 0 then
		--穿装备
		local equipConf = ShenShouEquip[itemId]
		if not equipConf or math.floor(itemId/100000)%10 ~= pos then
			actor_log(actor, "onReqEquip equipConf error, pos:"..tostring(pos)..", itemId:"..tostring(itemId))
			return
		end

		local level = math.floor(itemId/1000)%100
		if level < baseConf.minLevel[pos] then
			actor_log(actor, "onReqEquip equip level error, id:"..tostring(id)..", itemId:"..tostring(itemId))
			return
		end

		--是否有此物品
		if LActor.getItemCount(actor, itemId) <= 0 then
			actor_log(actor, "onReqEquip item not enough, itemId:"..tostring(itemId))
			return
		end

		--扣除物品
		LActor.costItem(actor, itemId, 1, "shenshou onReqEquip")
	else
		--脱装备
		if (ssdata.battle or 0) ~= 0 then
			--出战不能脱装备
			actor_log(actor, "onReqEquip battle = 0, id:"..tostring(id))
			return
		end
	end

	if 0 ~= (ssdata.equip[pos] or 0) then
		--返回原物品
		LActor.giveItem(actor, ssdata.equip[pos], 1, "shenshou unequip")
	end
	ssdata.equip[pos] = itemId

	updateAttr(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_RepEquip)
	if not pack then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, pos)
	LDataPack.writeInt(pack, itemId)
	LDataPack.flush(pack)
end

--协议 73-3
--请求合成装备
local function onReqCompose(actor, packet)
	local count = LDataPack.readChar(packet)

	if not checkOpen(actor) then return end
	local data = getStaticData(actor)
	if not data then return end

	if count ~= ShenShouConfig.matCount then
		actor_log(actor, "onReqCompose count is error, count:"..tostring(count))
		return
	end

	local itemList = {}
	for i=1, count do
		local itemId = LDataPack.readInt(packet)
		itemList[itemId] = (itemList[itemId] or 0) + 1
	end

	local mask = 0
	local exp = 0

	--检查并计算合成获得经验
	for itemId, itemCount in pairs(itemList) do
		if mask == 0 then
			mask = math.floor(itemId/1000)
		else
			--检查合成物品是否同一个道具组
			if mask ~= math.floor(itemId/1000) then
				actor_log(actor, "onReqCompose mask ~= (itemId/1000), mask:"..tostring(mask)..", mask:"..tostring(mask))
				return
			end
		end
		
		local equipConf = ShenShouEquip[itemId]
		if not equipConf then
			actor_log(actor, "onReqCompose equipConf is nil, itemId:"..tostring(itemId))
			return
		end

		--是否有此物品
		if LActor.getItemCount(actor, itemId) < itemCount then
			actor_log(actor, "onReqCompose item not enough, itemId:"..tostring(itemId))
			return
		end

		exp = exp + (equipConf.totalExp or 0)
	end

	--合成物
	local product = (mask + 1) * 1000 + 1
	local productConf = ShenShouEquip[product]
	if not productConf then
		actor_log(actor, "onReqCompose productConf is nil, product:"..tostring(product))
		return
	end

	--扣除材料
	for itemId, itemCount in pairs(itemList) do
		LActor.costItem(actor, itemId, itemCount, "shenshou onReqCompose")
	end

	--合成
	LActor.giveItem(actor, product, 1, "shenshou onReqCompose")
	changeShenShouExp(actor, exp, "shenshou onReqCompose")
end

--协议 73-4
--请求出战
local function onReqBattle(actor, packet)
	local id = LDataPack.readChar(packet)
	if not checkOpen(actor) then return end

	local data = getStaticData(actor)
	if not data then return end
	if not ShenShouBase[id] then
		actor_log(actor, "onReqBattle ShenShouBase[id] is nil, id:"..tostring(id))
		return
	end

	local ssdata = data[id]
	if not ssdata or not ssdata.equip then
		actor_log(actor, "onReqBattle ssdata is nil, id:"..tostring(id))
		return
	end

	if (ssdata.battle or 0) ~= 0 then
		--取消出战
		ssdata.battle = 0
	else
		--出战
		local battleCount = 0
		for i=1, #ShenShouBase do
			if nil ~= data[i] and 0 ~= (data[i].battle or 0) then
				battleCount = battleCount + 1
			end
		end
		if battleCount >= ShenShouConfig.minCount + (data.itemCount or 0) then
			--超过出战上限
			actor_log(actor, "onReqBattle battleCount is max")
			return
		end
		for i=1, ShenShouConfig.posCount do
			if (ssdata.equip[i] or 0) == 0 then
				--装备还没齐
				actor_log(actor, "onReqBattle ssdata.equip[i] is nil, i:"..tostring(i))
				return
			end
		end
		ssdata.battle = 1
	end

	updateAttr(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_RepBattle)
	if not pack then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, ssdata.battle)
	LDataPack.flush(pack)
end

--协议 73-5
--请求使用出战上限提升道具
local function onReqUseItem(actor)
	if not checkOpen(actor) then return end

	local data = getStaticData(actor)
	if not data then return end

	if ShenShouConfig.minCount + (data.itemCount or 0) >= ShenShouConfig.maxCount then
		--超出出战上限
		actor_log(actor, "onReqUseItem itemCount is max")
		return
	end

	--检查材料
	if LActor.getItemCount(actor, ShenShouConfig.battleCountItem) <= 0 then
		actor_log(actor, "onReqUseItem item not enough")
		return
	end
	--扣材料
	LActor.costItem(actor, ShenShouConfig.battleCountItem, 1, "shenshou onReqUseItem")
	data.itemCount = (data.itemCount or 0) + 1

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_RepUseItem)
	if not pack then return end
	LDataPack.writeChar(pack, data.itemCount)
	LDataPack.flush(pack)
end

--协议 73-7
--请求升级装备
local function onReqLevelUpEquip(actor, packet)
	local id = LDataPack.readChar(packet)
	local pos = LDataPack.readChar(packet)

	if not checkOpen(actor) then return end

	local data = getStaticData(actor)
	if not data then return end

	--参数检查
	if not data[id] or not data[id].equip then
		actor_log(actor, "onReqLevelUpEquip data error, id:"..tostring(id))
		return
	end
	if pos > ShenShouConfig.posCount or pos <= 0 then
		actor_log(actor, "onReqLevelUpEquip pos error, pos:"..tostring(pos))
		return
	end

	--装备检查
	for i=1, ShenShouConfig.posCount do
		if (data[id].equip[i] or 0) == 0 then
			--装备没齐不能升级
			actor_log(actor, "onReqLevelUpEquip equip error, id:"..tostring(id))
			return
		end
	end

	local itemId = data[id].equip[pos]
	local equipConf = ShenShouEquip[itemId]
	if not equipConf then
		actor_log(actor, "onReqLevelUpEquip equipConf is nil, id:"..tostring(id)..", pos:"..tostring(pos))
		--数据出错，赶紧报错警告
		assert(false)
		return
	end

	local nextConf = ShenShouEquip[itemId+1]
	if not nextConf then
		--可能满级
		actor_log(actor, "onReqLevelUpEquip nextConf is nil, id:"..tostring(id)..", pos:"..tostring(pos))
		return
	end

	if (data.exp or 0) < equipConf.exp then
		--经验不够
		actor_log(actor, "onReqLevelUpEquip data.exp < equipConf.exp, id:"..tostring(id)..", pos:"..tostring(pos))
		return
	end
	changeShenShouExp(actor, 0-equipConf.exp, "onReqLevelUpEquip")

	--替换
	data[id].equip[pos] = itemId+1

	updateAttr(actor)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_RepLevelUpEquip)
	if not pack then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeChar(pack, pos)
	LDataPack.writeInt(pack, itemId+1)
	LDataPack.flush(pack)
end

--协议 73-8
--请求熔炼装备
local function onReqSmelt(actor, packet)
	local count = LDataPack.readChar(packet)

	if not checkOpen(actor) then return end
	local data = getStaticData(actor)
	if not data then return end

	if count <= 0 then
		actor_log(actor, "onReqSmelt count is error")
		return
	end

	local itemList = {}
	for i=1, count do
		local itemId = LDataPack.readInt(packet)
		itemList[itemId] = (itemList[itemId] or 0) + 1
	end

	--检查并计算合成获得经验
	local exp = 0
	for itemId, itemCount in pairs(itemList) do
		local equipConf = ShenShouEquip[itemId]
		local smeltCount = 0
		if nil ~= equipConf then
			--是否有此物品
			local matCount = LActor.getItemCount(actor, itemId)
			if matCount > 0 then
				if matCount < itemCount then
					smeltCount = matCount
				else
					smeltCount = itemCount
				end
				LActor.costItem(actor, itemId, smeltCount, "shenshou onReqSmelt")
				local quality = math.floor(itemId/1000)%100
				exp = exp + (equipConf.totalExp + ShenShouSmelt[quality].exp) * smeltCount
			end
		end
	end

	changeShenShouExp(actor, exp, "shenshou onReqSmelt")

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_ShenShou, Protocol.sShenShouCmd_RepSmelt)
	if not pack then return end
	LDataPack.flush(pack)
end

local function init()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)

	netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_ReqEquip, onReqEquip)                --协议 73-2
	--netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_ReqCompose, onReqCompose)            --协议 73-3  暂时先屏蔽
	netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_ReqBattle, onReqBattle)              --协议 73-4
	netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_ReqUseItem, onReqUseItem)            --协议 73-5
	netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_ReqLevelUpEquip, onReqLevelUpEquip)  --协议 73-7
	netmsgdispatcher.reg(Protocol.CMD_ShenShou, Protocol.cShenShouCmd_ReqSmelt, onReqSmelt)                --协议 73-8
end
table.insert(InitFnTable, init)

