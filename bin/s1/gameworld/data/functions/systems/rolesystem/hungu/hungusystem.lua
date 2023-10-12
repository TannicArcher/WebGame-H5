--魂骨
module("hungusystem", package.seeall)

--[[
hungu = {
	-- [角色编号] = {魂骨数据}
	[0] = {
		-- [部位编号(0-7)] = {部位数据}
		[0] = {
			itemId = 0,  --装备id
			[1] = 0,  -- [魂玉孔位] = 魂玉等级
			[2] = 0,
			[3] = 0,
			[4] = 0, 
			[5] = 0,
		},
		[1] = {...}
		...
	},
	[1] = {...}
	...
}
]]

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("hungusystem aid:" .. aid .. " log:" .. str)
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.hungu then
		var.hungu = {}
	end
	return var.hungu
end

--检查系统是否开启
function checkOpen(actor, noLog)
	if System.getOpenServerDay() + 1 < HunGuConf.openserverday
		or LActor.getZhuanShengLevel(actor) < HunGuConf.openzhuanshenglv then
		if not noLog then actor_log(actor, "checkOpen false") end
		return false
	end
	return true
end

--相关数据合法性检查
local function checkData(actor, roleId)
	--系统是否已开启
	if not checkOpen(actor) then return false end

	--检查角色id合法性
	if not roleId or roleId < 0 or roleId >= LActor.getRoleCount(actor) then
		actor_log(actor, "checkData roleId error, roleId = " .. tostring(roleId))
		return false
	end
	return true
end

--玩家登陆下发总数据
local function onLogin(actor)
	if not checkOpen(actor, true) then return end

	local data = getStaticData(actor)
	if not data then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_HunGu, Protocol.sHunGuCmd_SendInfo)
	if not npack then return end

	local roleNum = 0
	local roleNumPos = LDataPack.getPosition(npack)
	LDataPack.writeChar(npack, roleNum)
	local roleCount = LActor.getRoleCount(actor)
	for roleId=0, roleCount-1 do
		if nil ~= data[roleId] then
			local roledata = data[roleId]
			LDataPack.writeChar(npack, roleId)
			LDataPack.writeChar(npack, HunGuConf.equipCount)
			for pos=0, HunGuConf.equipCount-1 do
				if not roledata[pos] then
					LDataPack.writeInt(npack, 0)
					LDataPack.writeChar(npack, 0)
				else
					local posdata = roledata[pos]
					LDataPack.writeInt(npack, posdata.itemId or 0)
					LDataPack.writeChar(npack, HunGuConf.hunyuCount)
					for hypos=1, HunGuConf.hunyuCount do
						LDataPack.writeInt(npack, posdata[hypos] or 0)
					end
				end
			end
			roleNum = roleNum + 1
		end
	end
	local endPos = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, roleNumPos)
	LDataPack.writeChar(npack, roleNum)
	LDataPack.setPosition(npack, endPos)
	LDataPack.flush(npack)
end

--计算并添加属性
local function addAttr(actor, roleId)
	local data = getStaticData(actor)
	if not data or not data[roleId] then return end
	local roledata = data[roleId]
	local tMixAttr = {}
	local expower = 0
	local suitList = {}
	local suitPro = 0
	for suitId, suitData in pairs(HunGuSuit) do
		--共鸣等级排序
		suitList[suitId] = {}
		for _, pos in pairs(HunGuConf.suit[suitId]) do
			local lv = 0
			if nil ~= roledata[pos] and 0 ~= (roledata[pos].itemId or 0) then
				local equipConf = HunGuEquip[roledata[pos].itemId]
				if not equipConf then
					actor_log(actor, "addAttr equipConf is nil, roleId:"..tostring(roleId)..", pos:"..tostring(pos)
						..", itemId:"..tostring(roledata[pos].itemId))
					--数据出错，赶紧报错警告
					assert(false)
					return
				end
				lv = equipConf.stage
			end
			table.insert(suitList[suitId], lv)
		end
		table.sort(suitList[suitId], function(a, b) return a > b end)

		--算共鸣属性
		for count, stageData in pairs(suitData) do
			local suitLv = suitList[suitId][count] or 0
			local suitConf = stageData[suitLv]
			if nil ~= suitConf then
				for _, v in pairs(suitConf.attrs or {}) do
					tMixAttr[v.type] = (tMixAttr[v.type] or 0) + v.value
				end
				suitPro = suitPro + (specialAttrs or 0)
				expower = expower + (suitConf.expower or 0)
			end
		end
	end

	for pos=0, HunGuConf.equipCount-1 do
		if nil ~= roledata[pos] and 0 ~= (roledata[pos].itemId or 0) then
			local posdata = roledata[pos]
			--装备属性
			local equipConf = HunGuEquip[posdata.itemId]
			if not equipConf then
				actor_log(actor, "addAttr equipConf is nil, roleId:"..tostring(roleId)..", pos:"..tostring(pos)
					..", itemId:"..tostring(posdata.itemId))
				--数据出错，赶紧报错警告
				assert(false)
				return
			end
			for _, v in pairs(equipConf.attrs or {}) do
				tMixAttr[v.type] = (tMixAttr[v.type] or 0) + (v.value * (1 + suitPro/10000))
			end
			expower = expower + (equipConf.expower or 0)

			--魂玉属性
			for hypos=1, HunGuConf.hunyuCount do
				if 0 < (posdata[hypos] or 0) then
					local hyType = HunGuConf.hunyuType[pos][hypos]
					local hyConf = HunYuEquip[hyType][posdata[hypos]]
					if not hyConf then
						actor_log(actor, "addAttr hyConf is nil, roleId:"..tostring(roleId)..", pos:"..tostring(pos)
							..", hypos:"..tostring(hypos))
						--数据出错，赶紧报错警告
						assert(false)
						return
					end
					for _, v in pairs(hyConf.attrs or {}) do
						tMixAttr[v.type] = (tMixAttr[v.type] or 0) + v.value
					end
					expower = expower + (equipConf.expower or 0)
				end
			end
		end
	end

	for k,v in pairs(tMixAttr) do
		LActor.addAttrsBaseAttr(actor, roleId, asHunGu, k, v)
	end
	LActor.addAttrsExaPower(actor, roleId, asHunGu, expower)
end

--更新属性
local function updateAttr(actor, roleId)
	LActor.clearAttrs(actor, roleId, asHunGu)
	addAttr(actor, roleId)
	LActor.reCalcRoleAttr(actor, roleId)
end

--初始化
local function onInit(actor)
	if not checkOpen(actor, true) then return end
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId)
	end
end

--协议 74-2
--请求戴上装备
local function onReqEquip(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local pos = LDataPack.readChar(packet)
	local itemId = LDataPack.readInt(packet)  --物品id
	
	if not checkData(actor, roleId) then return end

	local data = getStaticData(actor)
	if not data then return end

	if not data[roleId] then data[roleId] = {} end
	local roledata = data[roleId]

	if itemId ~= 0 then
		--穿装备
		local equipConf = HunGuEquip[itemId]
		if not equipConf or ItemConfig[itemId].subType ~= pos then
			actor_log(actor, "onReqEquip equipConf error, pos:"..tostring(pos)..", itemId:"..tostring(itemId))
			return
		end

		--是否有此物品
		if LActor.getItemCount(actor, itemId) <= 0 then
			actor_log(actor, "onReqEquip item not enough, itemId:"..tostring(itemId))
			return
		end

		--扣除物品
		LActor.costItem(actor, itemId, 1, "hungu onReqEquip")
	end

	if not roledata[pos] then roledata[pos] = {} end
	local posdata = roledata[pos]

	if 0 ~= (posdata.itemId or 0) then
		--返回原物品
		LActor.giveItem(actor, posdata.itemId, 1, "hungu unequip")
	end
	posdata.itemId = itemId
	--[[
	if 0 == (posdata[1] or 0) then
		--第一个魂玉孔免费开
		posdata[1] = 1
		local pack = LDataPack.allocPacket(actor, Protocol.CMD_HunGu, Protocol.sHunGuCmd_RepPosLevelUp)
		if not pack then return end
		LDataPack.writeChar(pack, roleId)
		LDataPack.writeChar(pack, pos)
		LDataPack.writeChar(pack, 1)
		LDataPack.writeInt(pack, 1)
		LDataPack.flush(pack)
	end
	]]

	updateAttr(actor, roleId)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_HunGu, Protocol.sHunGuCmd_RepEquip)
	if not pack then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, pos)
	LDataPack.writeInt(pack, itemId)
	LDataPack.flush(pack)
end

--协议 74-3
--升级魂玉
local function onPosLevelUp(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local pos = LDataPack.readChar(packet)
	local hypos = LDataPack.readChar(packet)

	if not checkData(actor, roleId) then return end
	local data = getStaticData(actor)
	if not data then return end

	if not data[roleId] or not data[roleId][pos] then
		actor_log(actor, "onPosLevelUp data is empty, roleId:"..tostring(roleId)..", pos:"..tostring(pos))
		return
	end

	local posdata = data[roleId][pos]

	if 0 == (posdata.itemId or 0) then
		--没有装备不能升级
		actor_log(actor, "onPosLevelUp itemId is 0, roleId:"..tostring(roleId)..", pos:"..tostring(pos))
		return
	end

	local equipConf = HunGuEquip[posdata.itemId]
	if not equipConf then
		actor_log(actor, "onPosLevelUp equipConf is nil, roleId:"..tostring(roleId)..", pos:"..tostring(pos)
			..", itemId:"..tostring(posdata.itemId))
		--数据出错，赶紧报错警告
		assert(false)
		return
	end

	if hypos < 1 or hypos > equipConf.hunyuNum then
		--孔位出错
		actor_log(actor, "onPosLevelUp hypos error, roleId:"..tostring(roleId)..", pos:"..tostring(pos)
			..", hypos:"..tostring(hypos))
		return
	end

	if hypos ~= 1 and 0 == (posdata[hypos] or 0) then
		--激活
		local yuanBao = HunGuConf.unlockCost[hypos]
 		local yb = LActor.getCurrency(actor, NumericType_YuanBao)
		if yb >= yuanBao then
			LActor.changeYuanBao(actor, 0-yuanBao, "hungu onPosLevelUp")
			posdata[hypos] = 1
		else
			--钱不够
			actor_log(actor, "onPosLevelUp no money")
			return
		end
	else
		--升级
		local nextLevel = (posdata[hypos] or 0) + 1
		local hyType = HunGuConf.hunyuType[pos][hypos]
		local hyConf = HunYuEquip[hyType][nextLevel]
		if not hyConf then
			--可能满级
			actor_log(actor, "onPosLevelUp hyConf is nil, roleId:"..tostring(roleId)..", pos:"..tostring(pos)
				..", hypos:"..tostring(hypos))
			return
		end
		--检查材料
		if LActor.getItemCount(actor, hyConf.cost.id) < hyConf.cost.count then
			actor_log(actor, "onPosLevelUp item not enough, roleId:"..tostring(roleId)..", pos:"..tostring(pos)
				..", hypos:"..tostring(hypos))
			return
		end
		--扣材料
		LActor.costItem(actor, hyConf.cost.id, hyConf.cost.count, "hungu onPosLevelUp")
		posdata[hypos] = nextLevel
	end

	updateAttr(actor, roleId)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_HunGu, Protocol.sHunGuCmd_RepPosLevelUp)
	if not pack then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, pos)
	LDataPack.writeChar(pack, hypos)
	LDataPack.writeInt(pack, posdata[hypos])
	LDataPack.flush(pack)
end

--协议 74-4
--请求装备升阶
local function onEquipLevelUp(actor, packet)
	local roleId = LDataPack.readChar(packet)
	local pos = LDataPack.readChar(packet)

	if not checkOpen(actor) then return end

	local data = getStaticData(actor)
	if not data then return end
	if not data[roleId] or not data[roleId][pos] then
		actor_log(actor, "onEquipLevelUp data is nil, roleId:"..tostring(roleId)..", pos:"..tostring(pos))
		return
	end
	local posdata = data[roleId][pos]
	if 0 == (posdata.itemId or 0) then
		--没装备
		actor_log(actor, "onEquipLevelUp itemId == 0, roleId:"..tostring(roleId)..", pos:"..tostring(pos))
		return
	end

	local equipConf = HunGuEquip[posdata.itemId]
	if not equipConf then
		actor_log(actor, "onEquipLevelUp equipConf is nil, roleId:"..tostring(roleId)..", pos:"..tostring(pos))
		--数据出错，赶紧报错警告
		assert(false)
		return
	end

	if 0 == (equipConf.nextId or 0) then
		--可能满级
		actor_log(actor, "onEquipLevelUp nextId == 0, roleId:"..tostring(roleId)..", pos:"..tostring(pos))
		return
	end

	--检查材料
	for _, v in pairs(equipConf.addStageCost or {}) do
		if LActor.getItemCount(actor, v.id) < v.count then
			--材料不足
			actor_log(actor, "onEquipLevelUp mat not enough, roleId:"..tostring(roleId)..", pos:"..tostring(pos))
			return
		end
	end

	--扣除材料
	for _, v in pairs(equipConf.addStageCost or {}) do
		LActor.costItem(actor, v.id, v.count, "hungu onEquipLevelUp")
	end

	posdata.itemId = equipConf.nextId

	updateAttr(actor, roleId)

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_HunGu, Protocol.sHunGuCmd_RepEquipLevelUp)
	if not pack then return end
	LDataPack.writeChar(pack, roleId)
	LDataPack.writeChar(pack, pos)
	LDataPack.writeInt(pack, posdata.itemId)
	LDataPack.flush(pack)
end

local function init()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)

	netmsgdispatcher.reg(Protocol.CMD_HunGu, Protocol.cHunGuCmd_ReqEquip, onReqEquip)             --协议 74-2
	netmsgdispatcher.reg(Protocol.CMD_HunGu, Protocol.cHunGuCmd_ReqPosLevelUp, onPosLevelUp)      --协议 74-3
	netmsgdispatcher.reg(Protocol.CMD_HunGu, Protocol.cHunGuCmd_ReqEquipLevelUp, onEquipLevelUp)  --协议 74-4
end
table.insert(InitFnTable, init)
