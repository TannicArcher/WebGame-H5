--心法系统
module("heartmethodsystem", package.seeall)

--[[
heartmethod = {
	--角色id
	[0] = {
		--心法id
		[1] = {
			lv = 0, --心法等级
			stage = 0,  --需要进阶
			slot = {
				[1] = 116501,  --部位物品id
				[2] = ...,
				...
			}
		},
		[2] = {...}
		...
	},
	[1] = {...},
	[2] = {...},
}
]]

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("heartmethodsystem aid:" .. aid .. " log:" .. str)
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.heartmethod then
		var.heartmethod = {}
	end
	return var.heartmethod
end

--检查系统是否开放
local function checkOpen(actor, noLog)
	if System.getOpenServerDay() + 1 < HeartMethodBaseConfig.serverDay
		or LActor.getZhuanShengLevel(actor) < HeartMethodBaseConfig.zsLv then
		if not noLog then actor_log(actor, "checkOpen false") end
		return false
	end
	return true
end

--相关数据合法性检查
local function checkData(actor, roleId, hmId)
	--系统是否已开启
	if not checkOpen(actor) then return false end

	--心法是否开启
	local hmConf = HeartMethodConfig[hmId]
	if not hmConf then
		actor_log(actor, "checkData hmConf is nil, hmId = " .. tostring(hmId))
		return false
	end
	local open = hmConf.openCondition or {}
	if (System.getOpenServerDay() + 1) < (open.day or 0)
		or LActor.getZhuanShengLevel(actor) < (open.zs or 0) then
		actor_log(actor, "checkData open false, hmId = " .. tostring(hmId))
		return false
	end

	--检查角色id合法性
	if not roleId or roleId < 0 or roleId >= LActor.getRoleCount(actor) then
		actor_log(actor, "checkData roleId error, roleId = " .. tostring(roleId))
		return false
	end
	return true
end

--计算并添加属性
local function addAttr(actor, roleId)
	local data = getStaticData(actor)
	if not data or not data[roleId] then return end
	local roledata = data[roleId]
	local tMixAttr = {}
	local extraPower = 0
	for hmId, hmlvConf in pairs(HeartMethodLevelConfig) do
		local hmData = roledata[hmId]
		if nil ~= hmData and nil ~= hmlvConf[hmData.lv or 0] then
			for _,t in pairs(hmlvConf[hmData.lv or 0].attr) do
				--加等级属性
				tMixAttr[t.type] = (tMixAttr[t.type] or 0) + t.value
			end
			extraPower = extraPower + (hmlvConf[hmData.lv or 0].power or 0)  --等级额外战力
			local stage = math.floor(hmData.lv/10)
			if hmData.stage ~= 1 then stage = stage + 1 end
			for _,t in pairs(HeartMethodStageConfig[hmId][stage].attr) do
				--加阶数属性
				tMixAttr[t.type] = (tMixAttr[t.type] or 0) + t.value
			end
			local posCount = #HeartMethodConfig[hmId].posList
			local hadPos = 0
			local minQuality = 0
			for i=1,posCount do
				if nil ~= hmData.slot[i] then
					local hmStarConf = HeartMethodStarConfig[hmData.slot[i]]
					--if not hmStarConf then return end  --只有配置变了才会遇到这情况
					if 0 == minQuality or minQuality > hmStarConf.quality then
						minQuality = hmStarConf.quality
					end
					if nil ~= hmStarConf then
						for _,t in pairs(hmStarConf.attr) do
							--加部位属性
							tMixAttr[t.type] = (tMixAttr[t.type] or 0) + t.value
						end
						extraPower = extraPower + (hmStarConf.power or 0)  --部位额外战力
						hadPos = hadPos + 1
					end
				end
			end
			if hadPos >= posCount then
				local hmSuitConf = HeartMethodSuitConfig[hmId][minQuality]
				if nil ~= hmSuitConf then
					for _,t in pairs(hmSuitConf.attr) do
						--加套装属性
						tMixAttr[t.type] = (tMixAttr[t.type] or 0) + t.value
					end
					extraPower = extraPower + (hmSuitConf.power or 0)  --套装额外战力
				end
			end
		end
	end

	for k,v in pairs(tMixAttr) do
		LActor.addAttrsBaseAttr(actor, roleId, asHeartMethod, k, v)
	end
	LActor.addAttrsExaPower(actor, roleId, asHeartMethod, extraPower)
end

--更新属性
local function updateAttr(actor, roleId)
	LActor.clearAttrs(actor, roleId, asHeartMethod)
	addAttr(actor, roleId)
	LActor.reCalcRoleAttr(actor, roleId)
end

--下发心法数据
local function sendInfo(actor, roleId, hmId, hmData)
	if not actor or not roleId or not hmId then return end
	if not hmData then
		local data = getStaticData(actor)
		if not data then return end
		local roledata = data[roleId]
		if not roledata then return end
		hmData = roledata[hmId]
		if not hmData then return end
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_HeartMethod, Protocol.sHeartMethodCmd_SendInfo)
	if not npack then return end
	LDataPack.writeChar(npack, roleId)
	LDataPack.writeShort(npack, hmId)
	LDataPack.writeShort(npack, hmData.lv or 0)
	LDataPack.writeChar(npack, hmData.stage or 0)
	local posCount = #HeartMethodConfig[hmId].posList
	LDataPack.writeShort(npack, posCount)
	for i=1,posCount do
		LDataPack.writeInt(npack, hmData.slot[i] or 0)
	end
	LDataPack.flush(npack)
end

--[[
--下发角色数据
local function sendRoleInfo(actor, roleId)
	if not actor or not roleId then return end
	local data = getStaticData(actor)
	if not data then return end

	local roledata = data[roleId]
	if not roledata then return end
	for hmId, _ in pairs(HeartMethodLevelConfig) do
		if nil ~= roledata[hmId] then
			sendInfo(actor, roleId, hmId, roledata[hmId])
		end
	end
end

--下发总数据
local function sendActorInfo(actor)
	if not actor then return end
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		sendRoleInfo(actor, roleId)
	end
end
]]

--升级心法
local function levelUpHm(actor, roleId, hmId)
	local hmlvConf = HeartMethodLevelConfig[hmId]
	if not hmlvConf then
		actor_log(actor, "levelUpHm hmlvConf is nil, hmId = " .. tostring(hmId))
		return
	end

	local data = getStaticData(actor)
	if not data then return end

	if not data[roleId] then data[roleId] = {} end
	local roledata = data[roleId]
	if not roledata[hmId] then
		--激活心法
		roledata[hmId] = {
			lv = 0,
			stage = 0,
			slot = {}
		}
		sendInfo(actor, roleId, hmId, roledata[hmId])
		updateAttr(actor, roleId)
		return
	end

	local hmdata = roledata[hmId]
	if not hmdata.slot then hmdata.slot = {} end
	local posCount = 0
	for i=1, #HeartMethodConfig[hmId].posList do
		if (hmdata.slot[i] or 0) > 0 then posCount = posCount + 1 end
	end
	if posCount < (HeartMethodConfig[hmId].upGradeCondition or 0) then
		actor_log(actor, "levelUpHm upGradeCondition fail, hmId = " .. tostring(hmId))
		return
	end

	local stars = (hmdata.lv or 0)%10
	local nextLevel = (hmdata.lv or 0) + 1
	local config = hmlvConf[nextLevel]
	if not config then
		--可能满级
		actor_log(actor, "levelUpHm config is nil, hmId:"..tostring(hmId)..", nl:"..tostring(nextLevel))
		return
	end

	if 0 == stars and 1 == hmdata.stage then
		--升阶
		hmdata.stage = 0
	else
		--升星
		--扣材料
		if LActor.getItemCount(actor, config.costItem) < config.costNum then
			LActor.sendTipmsg(actor, Lang.ScriptTips.lhx004, ttMessage)
			return
		end
		LActor.costItem(actor, config.costItem, config.costNum, "heartmethod levelUpHm")

		hmdata.lv = (hmdata.lv or 0) + 1
		if 0 == (hmdata.lv or 0)%10 then
			--转入升阶
			hmdata.stage = 1
		end
	end
	sendInfo(actor, roleId, hmId, roledata[hmId])
	updateAttr(actor, roleId)
end

--部位数据
local function getSlotData(actor, roleId, hmId)
	local data = getStaticData(actor)
	if not data or not data[roleId] then return end
	local roledata = data[roleId]
	if not roledata[hmId] then return end
	if not roledata[hmId].slot then roledata[hmId].slot = {} end
	return roledata[hmId].slot
end

--升级部位
local function levelUpPos(actor, roleId, hmId, pos)
	local slotdata = getSlotData(actor, roleId, hmId)
	if not slotdata or not slotdata[pos] then return end

	local itemId = slotdata[pos]
	local hmStarConf = HeartMethodStarConfig[itemId]
	if not hmStarConf then
		actor_log(actor, "levelUpPos hmStarConf is nil, itemId:"..tostring(itemId))
		return
	end
	local nextItem = hmStarConf.nextItem
	if not nextItem or 0 == nextItem then
		--满级
		LActor.sendTipmsg(actor, Lang.ScriptTips.lhx002, ttMessage)
		return
	end
	--是否有此物品
	if LActor.getItemCount(actor, hmStarConf.costItem) < hmStarConf.costNum then
		LActor.sendTipmsg(actor, Lang.ScriptTips.lhx004, ttMessage)
		return
	end
	--扣除物品
	LActor.costItem(actor, hmStarConf.costItem, hmStarConf.costNum, "heartmethod levelUpPos")

	slotdata[pos] = hmStarConf.nextItem
	sendInfo(actor, roleId, hmId)
	updateAttr(actor, roleId)
end

--可以装备/替换
local function canEquip(actor, hmId, pos, old, new)
	local hmStarConf_new = HeartMethodStarConfig[new]
	if not hmStarConf_new then
		actor_log(actor, "canEquip hmStarConf_new is nil, hmId:"..tostring(hmId)..", pos:"..tostring(pos)..", old:"..tostring(old)..", new:"..tostring(new))
		return false
	end
	local hmId_new = hmStarConf_new.heartmethodId  --心法
	local pos_new = hmStarConf_new.posSort  --部位索引
	local quality_new = hmStarConf_new.quality  --品质
	local star_new = hmStarConf_new.star  --星级

	if hmId_new ~= hmId or pos_new ~= pos then
		--心法或部位和物品不匹配
		actor_log(actor, "canEquip posId is nil, hmId:"..tostring(hmId)..", posId:"..tostring(posId)..", new:"..tostring(new))
		return false
	end

	if not old then
		--装备
		return true
	else
		--替换
		local hmStarConf_old = HeartMethodStarConfig[old]
		if not hmStarConf_old then
			--原数据错误，覆盖
			actor_log(actor, "canEquip hmStarConf_old is nil, hmId:"..tostring(hmId)..", pos:"..tostring(pos)..", old:"..tostring(old)..", new:"..tostring(new))
			return true
		end
		local star_old = hmStarConf_old.star  --星级
		local quality_old = hmStarConf_old.quality  --品质
		if quality_new > quality_old then
			--品质较高
			return true
		elseif quality_new < quality_old then
			--品质较低
			return false
		else
			--品质相同
			if star_new > star_old then
				--星级较高
				return true
			end
		end
	end
	return false
end

--属性初始化
local function onInit(actor)
	if not actor then return end
	if not checkOpen(actor, true) then return end
	local count = LActor.getRoleCount(actor)
	for roleId=0, count-1 do
		updateAttr(actor, roleId)
	end
end

--玩家登陆下发总数据
local function onLogin(actor)
	if not checkOpen(actor, true) then return end

	local data = getStaticData(actor)
	if not data then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_HeartMethod, Protocol.sHeartMethodCmd_SendAllInfo)
	if not npack then return end

	local roleNum = 0
	local roleNumPos = LDataPack.getPosition(npack)
	LDataPack.writeChar(npack, roleNum)
	local roleCount = LActor.getRoleCount(actor)
	for roleId=0, roleCount-1 do
		if nil ~= data[roleId] then
			LDataPack.writeChar(npack, roleId)
			local hmNum = 0
			local hmNumPos = LDataPack.getPosition(npack)
			LDataPack.writeShort(npack, hmNum)
			local roledata = data[roleId]
			for hmId, hmlvConf in pairs(HeartMethodLevelConfig) do
				local hmData = roledata[hmId]
				if nil ~= hmData then
					LDataPack.writeShort(npack, hmId)
					LDataPack.writeShort(npack, hmData.lv or 0)
					LDataPack.writeChar(npack, hmData.stage or 0)
					local posCount = #HeartMethodConfig[hmId].posList
					LDataPack.writeShort(npack, posCount)
					for i=1,posCount do
						LDataPack.writeInt(npack, hmData.slot[i] or 0)
					end
					hmNum = hmNum + 1
				end
			end
			local endPos = LDataPack.getPosition(npack)
			LDataPack.setPosition(npack, hmNumPos)
			LDataPack.writeShort(npack, hmNum)
			LDataPack.setPosition(npack, endPos)
			roleNum = roleNum + 1
		end
	end
	local endPos = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, roleNumPos)
	LDataPack.writeChar(npack, roleNum)
	LDataPack.setPosition(npack, endPos)
	LDataPack.flush(npack)
end

--协议 69-3
--请求升星
local function onReqLevelUp(actor, packet)
	local roleId = LDataPack.readChar(packet)  --角色
	local hmId = LDataPack.readShort(packet)  --心法
	local pos = LDataPack.readShort(packet)  --部位

	if not checkData(actor, roleId, hmId) then return end

	if pos == 0 then
		--升级心法
		levelUpHm(actor, roleId, hmId)
	else
		--升级部位
		levelUpPos(actor, roleId, hmId, pos)
	end
end

--协议 69-4
--请求装备/替换部位
local function onReqEquipPos(actor, packet)
	local roleId = LDataPack.readChar(packet)  --角色
	local hmId = LDataPack.readShort(packet)  --心法
	local pos = LDataPack.readShort(packet)  --部位
	local itemId = LDataPack.readInt(packet)  --物品

	if not itemId then return end

	if not checkData(actor, roleId, hmId) then return end
	local slotdata = getSlotData(actor, roleId, hmId)
	if not slotdata then
		--可能还没激活心法
		actor_log(actor, "onReqEquipPos slotdata is nil, roleId:"..tostring(roleId)..", hmId:"..tostring(hmId)..", pos:"..tostring(pos))
		return
	end

	--是否有此物品
	if LActor.getItemCount(actor, itemId) <= 0 then
		actor_log(actor, "onReqEquipPos item not enough, itemId:"..tostring(itemId))
		return
	end

	--能不能装备/替换
	if not canEquip(actor, hmId, pos, slotdata[pos], itemId) then return end

	--扣除物品
	LActor.costItem(actor, itemId, 1, "heartmethod onReqEquipPos")

	if 0 ~= (slotdata[pos] or 0) then
		--返回原物品
		LActor.giveItem(actor, slotdata[pos], 1, "heartmethod unequip")
	end
	slotdata[pos] = itemId
	sendInfo(actor, roleId, hmId)
	updateAttr(actor, roleId)
end

--协议 69-5
--请求分解材料
local function onReqDecomPose(actor, packet)
	local hmId = LDataPack.readShort(packet)
	local count = LDataPack.readInt(packet)
	if count <= 0 then
		actor_log(actor, "onReqDecomPose count <= 0, count:"..tostring(count))
		return
	end
	local list = {}
	for i =1, count do
		local itemId = LDataPack.readInt(packet)
		list[itemId] = (list[itemId] or 0) + 1
	end

	local splitItemId = HeartMethodConfig[hmId].splitItem
	if not splitItemId then
		actor_log(actor, "onReqDecomPose splitItemId is nil, hmId:"..tostring(hmId))
		return
	end

	if not checkOpen(actor) then
		actor_log(actor, "onReqDecomPose system is not open")
		return
	end

	local totalCount = 0
	for itemId, itemCount in pairs(list) do
		local conf = HeartMethodStarConfig[itemId]
		if nil ~= conf and conf.heartmethodId == hmId and itemCount > 0 and LActor.getItemCount(actor, itemId) >= itemCount then
			LActor.costItem(actor, itemId, itemCount, "heartmethod decompose")
			local splitItemCount = conf.splitNum * itemCount
			totalCount = totalCount + splitItemCount
		end
	end

	LActor.giveItem(actor, splitItemId, totalCount, "heartmethod decompose")
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_HeartMethod, Protocol.sHeartMethodCmd_RepDecomPose)
	if not npack then return end

	if totalCount > 0 then
		LDataPack.writeChar(npack, 1)
		LDataPack.writeShort(npack, hmId)
		LDataPack.writeShort(npack, totalCount)
	else
		LDataPack.writeChar(npack, 0)
	end
	LDataPack.flush(npack)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_HeartMethod, Protocol.cHeartMethodCmd_ReqLevelUp, onReqLevelUp)      --协议 69-3
netmsgdispatcher.reg(Protocol.CMD_HeartMethod, Protocol.cHeartMethodCmd_ReqEquipPos, onReqEquipPos)    --协议 69-4
netmsgdispatcher.reg(Protocol.CMD_HeartMethod, Protocol.cHeartMethodCmd_ReqDecomPose, onReqDecomPose)  --协议 69-5
