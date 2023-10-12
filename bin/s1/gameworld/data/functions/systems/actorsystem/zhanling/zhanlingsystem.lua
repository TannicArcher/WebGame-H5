module("zhanlingsystem", package.seeall)

local systemId = Protocol.CMD_ZhanLing

--[[
zhanling = {
	fashion = {
		-- [皮肤编号] = {皮肤数据}
		[0] = {
			-- 索引0为战灵数据
			talent = nil,  --战灵天赋等级与战灵等级挂钩，设置无意义
			lv = 0,  --战灵等级
			exp = 0,   --经验
			pill = {
				-- 使用过丹药列表
				-- [物品id] = 个数
				[99999] = 0
			},
			equip = {
				-- 装备
				-- [部位] = 物品id
				[1] = 0,
				[2] = 0,
				[3] = 0,
				[4] = 0,
			},
		},
		[1] = {
			-- 索引1开始为皮肤数据
			talent = 1,  --天赋等级，初始为1，当大于1视为激活皮肤
			lv = 0,  --皮肤等级
			exp = 0,   --经验
			pill = {},  --暂时无数据
			equip = {}，  --暂时无数据
		},
		[2] = {...}
		...
	},
	fid = 0,  --幻化皮肤编号
}
]]

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("zhanlingsystem aid:" .. aid .. " log:" .. str)
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.zhanling then
		var.zhanling = {}
		var.zhanling.fid = 0
	end
	if not var.zhanling.fashion then var.zhanling.fashion = {} end
	if not var.zhanling.fashion[0] then var.zhanling.fashion[0] = {} end
	return var.zhanling
end

--检查系统/皮肤是否开启
function checkOpen(actor, noLog, id, data)
	if System.getOpenServerDay() + 1 < ZhanLingConfig.openserverday
		or LActor.getZhuanShengLevel(actor) < ZhanLingConfig.openzhuanshenglv then
		if not noLog then actor_log(actor, "checkOpen false") end
		return false
	end
	if (id or 0) ~= 0 then
		--皮肤是否开放
		if not data then data = getStaticData(actor) end
		local fdata = data.fashion[id]
		if not fdata or (fdata.talent or 0) <= 0 then
			LActor.sendTipmsg(actor, "皮肤未激活", ttMessage)
			return false
		end
	end
	
	return true
end

--发送基本信息
local function sendInfo(actor)
	if not checkOpen(actor) then return end
	local data = getStaticData(actor)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhanLingCmd_SendInfo)
	if not pack then return end

	local pos1 = LDataPack.getPosition(pack)
	local count = 0
	LDataPack.writeChar(pack, count)
	for i=0, #ZhanLingBase do
		local fdata = data.fashion[i]
		if fdata ~= nil and (0 == i or (fdata.talent or 0) > 0) then
			LDataPack.writeInt(pack, i)
			LDataPack.writeChar(pack, fdata.talent or 0)
			LDataPack.writeShort(pack, fdata.lv or 0)
			LDataPack.writeInt(pack, fdata.exp or 0)
			if 0 == i then
				if not fdata.pill then fdata.pill = {} end
				local pillCount = 0
				local pill1 = LDataPack.getPosition(pack)
				LDataPack.writeChar(pack, pillCount)
				for itemId, _ in pairs(ZhanLingConfig.upgradeInfo) do
					LDataPack.writeInt(pack, itemId)
					LDataPack.writeShort(pack, fdata.pill[itemId] or 0)
					pillCount = pillCount + 1
				end
				local pill2 = LDataPack.getPosition(pack)
				LDataPack.setPosition(pack, pill1)
				LDataPack.writeChar(pack, pillCount)
				LDataPack.setPosition(pack, pill2)
				if not fdata.equip then fdata.equip = {} end
				LDataPack.writeChar(pack, ZhanLingConfig.equipPosCount)
				for j=1, ZhanLingConfig.equipPosCount do
					LDataPack.writeInt(pack, fdata.equip[j] or 0)
				end
			else
				LDataPack.writeChar(pack, 0)
				LDataPack.writeChar(pack, 0)
			end
			count = count + 1
		end
	end
	local pos2 = LDataPack.getPosition(pack)
	LDataPack.setPosition(pack, pos1)
	LDataPack.writeChar(pack, count)
	LDataPack.setPosition(pack, pos2)
	LDataPack.writeChar(pack, data.fid or 0)
	LDataPack.flush(pack)
end

--更新c++数据
local function setZhanLingInfo(actor, data, lvConf)
	if not data then
		data = getStaticData(actor)
		if not data then return end
	end
	
	if not lvConf then
		lvConf = ZhanLingLevel[0][data.fashion[0].lv or 0]
		if not lvConf then
			actor_log(actor, "setZhanLingInfo lvConf is nil, level:"..tostring(data.fashion[0].lv))
			--数据出错，赶紧报错警告
			assert(false)
			return
		end
	end
	
	if lvConf.talentLevel > 0 then
		local effId = ZhanLingTalent[0][lvConf.talentLevel].effId
		local rate = ZhanLingTalent[0][lvConf.talentLevel].rate
		LActor.setZhanLingInfo(actor, data.fid or 0, data.fashion[0].lv or 0, effId, rate)
	end
end

local function updateZhanLingData(actor)
	local data = getStaticData(actor)
	if not data then return end

	local basic_data = LActor.getActorData(actor)
	basic_data.zhan_ling_star = data.fashion[0].lv or 0
end

--更新属性
local function updateAttr(actor)
	local data = getStaticData(actor)
	if not data then return end

	local attr = LActor.getActorsystemAttr(actor, attrZhanLing)
	if attr == nil then
		actor_log(actor, "updateAttr attr is nil")
		return
	end
	attr:Reset()
	local expower = 0  --额外战力

	--提升丹药属性
	local pill = data.fashion[0].pill or {}
	local pre = 0
	for itemId, info in pairs(ZhanLingConfig.upgradeInfo) do
		local count = pill[itemId] or 0
		if count > 0 then
			for _, v in pairs(info.attr or {}) do
				attr:Add(v.type, v.value * count)
			end
			pre = pre + (info.precent or 0) * count
		end
	end

	--战灵装备属性
	local equip = data.fashion[0].equip or {}
	local suitLevel = #ZhanLingSuit
	for i=1, ZhanLingConfig.equipPosCount do
		local equipConf = ZhanLingEquip[equip[i] or 0]
		if nil ~= equipConf then
			for k,v in pairs(equipConf.attrs or {}) do
				attr:Add(v.type, v.value)
			end
			expower = expower + (equipConf.expower or 0)
			if suitLevel > equipConf.level then suitLevel = equipConf.level end
		else
			suitLevel = 0
		end
	end

	--战灵套装属性
	local suitConf = ZhanLingSuit[suitLevel]
	if nil ~= suitConf then
		pre = pre + (suitConf.precent or 0)
		for k,v in pairs(suitConf.attrs or {}) do
			attr:Add(v.type, v.value)
		end
		expower = expower + (suitConf.expower or 0)
	end

	local config = ZhanLingLevel[0][data.fashion[0].lv or 0]
	if not config then
		actor_log(actor, "updateAttr config[0] is nil, level:"..tostring(data.lv))
		--数据出错，赶紧报错警告
		assert(false)
		return
	end

	--战灵等级属性
	for k,v in pairs(config.attrs or {}) do
		attr:Add(v.type, v.value + math.floor(v.value*pre/10000))
	end
	expower = expower + (config.expower or 0)  --战灵等级额外战力

	--战灵天赋属性
	local zltConf = ZhanLingTalent[ZhanLingBase[0].talent][config.talentLevel]
	if nil ~= zltConf then
		for k,v in pairs(zltConf.attrs or {}) do
			attr:Add(v.type, v.value)
		end
		expower = expower + (zltConf.expower or 0)
		--开启战灵外显
		LActor.initZhanLingInfo(actor, data.fid or 0, data.fashion[0].lv or 0, zltConf.effId or 0, zltConf.rate or 0)
	end

	--战灵技能
	local chengba = false
	if (data.fashion[0].lv or 0) >= ZhanLingConfig.plusLevel then chengba = true end
	for _, v in pairs(ZhanLingBase[0].skill or {}) do
		if (data.fashion[0].lv or 0) >= v.open then
			--到达开放此技能等级
			local skillConf = ZhanLingSkill[v.id]
			if chengba then
				--称霸有双倍属性
				for k,v in pairs(skillConf.attrs or {}) do
					attr:Add(v.type, v.value * 2)
				end
				if (skillConf.passivePlus or 0) ~= 0 then
					for i=0, LActor.getRoleCount(actor) - 1 do
						local role = LActor.getRole(actor, i)
						if nil ~= role then
							--不管有没有学了，删了再说
							LActor.DelPassiveSkillById(role, math.floor(skillConf.passivePlus/1000))
							--再学
							LActor.AddPassiveSkill(role, skillConf.passivePlus)
						end
					end
				end
			else
				for k,v in pairs(skillConf.attrs or {}) do
					attr:Add(v.type, v.value)
				end
				if (skillConf.passive or 0) ~= 0 then
					for i=0, LActor.getRoleCount(actor) - 1 do
						local role = LActor.getRole(actor, i)
						if nil ~= role then
							--不管有没有学了，删了再说
							LActor.DelPassiveSkillById(role, math.floor(skillConf.passive/1000))
							--再学
							LActor.AddPassiveSkill(role, skillConf.passive)
						end
					end
				end
			end
			expower = expower + (skillConf.expower or 0)
		end
	end

	--皮肤属性
	for i=1, #ZhanLingLevel do
		local fdata = data.fashion[i]
		if nil ~= fdata and (fdata.talent or 0) >= 1 then
			--皮肤已激活
			--皮肤等级属性
			local flConf = ZhanLingLevel[i][fdata.lv or 0]
			if nil ~= flConf then
				for k,v in pairs(flConf.attrs or {}) do
					attr:Add(v.type, v.value)
				end
				expower = expower + (flConf.expower or 0)
			end
			--皮肤天赋
			local talentId = ZhanLingBase[i].talent
			local tlvConf = ZhanLingTalent[talentId][fdata.talent]
			if tlvConf ~= nil then
				if (tlvConf.effId or 0) ~= 0 then
					LActor.addZhanLingEffect(actor, tlvConf.effId or 0, tlvConf.rate or 0)
				end
				for _, v in pairs(tlvConf.passive or {}) do
					if (v.type or 0) == 0 then
						for i=0, LActor.getRoleCount(actor) - 1 do
							local role = LActor.getRole(actor, i)
							if nil ~= role then
								--不管有没有学了，删了再说
								LActor.DelPassiveSkillById(role, math.floor(v.id/1000))
								--再学
								LActor.AddPassiveSkill(role, v.id)
							end
						end
					else
						local role = LActor.GetRoleByJob(actor, v.type)
						if nil ~= role then
							--不管有没有学了，删了再说
							LActor.DelPassiveSkillById(role, math.floor(v.id/1000))
							--再学
							LActor.AddPassiveSkill(role, v.id)
						end
					end
				end
				for k,v in pairs(tlvConf.attrs or {}) do
					attr:Add(v.type, v.value)
				end
				expower = expower + (tlvConf.expower or 0)
			end
			--皮肤技能
			for _, v in pairs(ZhanLingBase[i].skill or {}) do
				if (fdata.lv or 0) >= v.open then
					--到达开放此技能等级
					local skillConf = ZhanLingSkill[v.id]
					for k,v in pairs(skillConf.attrs or {}) do
						attr:Add(v.type, v.value)
					end
					expower = expower + (skillConf.expower or 0)
					--[[
					--皮肤暂时没有
					if (skillConf.passive or 0) ~= 0 then
						for i=0, LActor.getRoleCount(actor) - 1 do
							local role = LActor.getRole(actor, i)
							if nil ~= role then
								--不管有没有学了，删了再说
								LActor.DelPassiveSkillById(role, math.floor(skillConf.passive/1000))
								--再学
								LActor.AddPassiveSkill(role, skillConf.passive)
							end
						end
					end
					]]
				end
			end
		end
	end
	attr:SetExtraPower(expower)
	LActor.reCalcAttr(actor)
end

--外部调用接口
function getZhanLingLevel(actor)
	if not checkOpen(actor, true) then return 0 end
	local data = getStaticData(actor)
	if not data then return 0 end
	return data.fashion[0].lv or 0
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

--协议 43-2
--请求提升等级经验
local function onReqAddExp(actor, packet)
	local id = LDataPack.readChar(packet)
	local useYuanbao = LDataPack.readChar(packet)

	local data = getStaticData(actor)
	if not data then return end
	if not checkOpen(actor, false, id, data) then return end

	local levelConf = ZhanLingLevel[id]
	if not levelConf then
		actor_log(actor, "onReqAddExp levelConf is nil, id:"..tostring(id))
		return
	end

	local fdata = data.fashion[id]
	local level = fdata.lv or 0
	local config = levelConf[level]
	if not config then
		actor_log(actor, "onReqAddExp config is nil, id:"..tostring(id)..", level:"..tostring(level))
		--数据出错，赶紧报错警告
		assert(false)
		return
	end

	local nextConf = levelConf[level + 1]
	if not nextConf then
		--满级
		actor_log(actor, "onReqAddExp nextConf is nil")
		return
	end

	--检查
	local matCount = LActor.getItemCount(actor, ZhanLingConfig.stageitemid)
	if matCount < config.count then
		if 1 == useYuanbao then
			local yuanBao = (config.count - matCount) * ZhanLingConfig.unitPrice
 			local yb = LActor.getCurrency(actor, NumericType_YuanBao)
			if yb >= yuanBao then
				--扣完材料并扣钱
				if matCount > 0 then LActor.costItem(actor, ZhanLingConfig.stageitemid, matCount, "zhanling onReqAddExp") end
				LActor.changeYuanBao(actor, 0-yuanBao, "zhanling onReqAddExp")
			else
				--材料和钱都不够
				actor_log(actor, "onReqAddExp no money")
				return
			end
		else
			--材料不够
			actor_log(actor, "onReqAddExp no mat")
			return
		end
	else
		--直接扣材料
		LActor.costItem(actor, ZhanLingConfig.stageitemid, config.count, "zhanling onReqAddExp")
	end
	
	fdata.exp = (fdata.exp or 0) + ZhanLingConfig.stageitemexp * config.count

	if fdata.exp >= config.exp then
		--升级
		fdata.lv = level + 1
		fdata.exp = fdata.exp - config.exp
		updateZhanLingData(actor)
		updateAttr(actor)
	end

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhanLingCmd_RepAddExp)
	if not pack then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeShort(pack, fdata.lv or 0)
	LDataPack.writeInt(pack, fdata.exp)
	LDataPack.flush(pack)
end

--协议 43-3
--请求使用提升丹
local function onReqUseItem(actor, packet)
	local id = LDataPack.readChar(packet)
	local itemId = LDataPack.readInt(packet)

	local data = getStaticData(actor)
	if not data then return end
	if not checkOpen(actor, false, id, data) then return end

	if id ~= 0 then
		--暂时只有战灵才能使用提升丹
		actor_log(actor, "onReqUseItem id ~= 0, id:"..tostring(id))
		return
	end

	local fdata = data.fashion[id]
	local level = fdata.lv or 0
	local config = ZhanLingLevel[id][level]
	if not config then
		actor_log(actor, "onReqUseItem config is nil, level:"..tostring(level))
		--数据出错，赶紧报错警告
		assert(false)
		return
	end

	if not fdata.pill then fdata.pill = {} end
	local maxCount = config.maxCount[itemId] or 0
	if (fdata.pill[itemId] or 0) >= maxCount then
		actor_log(actor, "onReqUseItem pill >= maxCount, itemId:"..tostring(itemId))
		return
	end

	--检查材料
	if LActor.getItemCount(actor, itemId) <= 0 then
		actor_log(actor, "onReqUseItem item not enough, itemId:"..tostring(itemId))
		return
	end
	--扣材料
	LActor.costItem(actor, itemId, 1, "zhanling use item")
	fdata.pill[itemId] = (fdata.pill[itemId] or 0) + 1

	updateAttr(actor)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhanLingCmd_RepUseItem)
	if not pack then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeInt(pack, itemId)
	LDataPack.writeShort(pack, fdata.pill[itemId])
	LDataPack.flush(pack)
end

--协议 43-4
--请求戴上装备
local function onReqEquip(actor, packet)
	local id = LDataPack.readChar(packet)
	local itemId = LDataPack.readInt(packet)  --物品id

	local data = getStaticData(actor)
	if not data then return end
	if not checkOpen(actor, false, id, data) then return end

	if id ~= 0 then
		--暂时只有战灵才能穿装备
		actor_log(actor, "onReqEquip id ~= 0, id:"..tostring(id))
		return
	end

	local equipConf = ZhanLingEquip[itemId]
	if not equipConf then
		actor_log(actor, "onReqEquip equipConf is nil, itemId:"..tostring(itemId))
		return
	end

	--是否有此物品
	if LActor.getItemCount(actor, itemId) <= 0 then
		actor_log(actor, "onReqEquip item not enough, itemId:"..tostring(itemId))
		return
	end

	--扣除物品
	LActor.costItem(actor, itemId, 1, "zhanling onReqEquip")
	if not data.fashion[id].equip then data.fashion[id].equip = {} end
	local equip = data.fashion[id].equip

	if 0 ~= (equip[equipConf.pos] or 0) then
		--返回原物品
		LActor.giveItem(actor, equip[equipConf.pos], 1, "zhanling unequip")
	end
	equip[equipConf.pos] = itemId

	updateAttr(actor)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhanLingCmd_RepEquip)
	if not pack then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeInt(pack, itemId)
	LDataPack.flush(pack)
end

--协议 43-5
--请求合成装备
local function onReqCompose(actor, packet)
	local itemId = LDataPack.readInt(packet)

	if not checkOpen(actor) then return end
	local data = getStaticData(actor)
	if not data then return end
	
	local equipConf = ZhanLingEquip[itemId]
	if not equipConf then
		actor_log(actor, "onReqCompose equipConf is nil, itemId:"..tostring(itemId))
		return
	end

	if not equipConf.mat then
		LActor.sendTipmsg(actor, "无法合成", ttMessage)
		return
	end

	local pos = equipConf.pos
	local fdata = data.fashion[0]
	if not fdata.equip then fdata.equip = {} end
	local downEquip = false

	--检查材料
	for _, v in pairs(equipConf.mat) do
		local matCount = LActor.getItemCount(actor, v.id)
		if matCount < v.count then
			--背包材料不足
			if (v.count - matCount) == 1 then
				--如果差一个，看身上有没有穿，有的话也拿来合成
				if (fdata.equip[pos] or 0) ~= v.id then
					--身上也没有
					actor_log(actor, "onReqCompose mat not enough, itemId:"..tostring(itemId))
					return
				end
				downEquip = true
			else
				--差两个以上，肯定合不了了
				actor_log(actor, "onReqCompose mat not enough, itemId:"..tostring(itemId))
				return
			end
		end
	end

	for _, v in pairs(equipConf.mat) do
		--扣除材料
		local matCount = LActor.getItemCount(actor, v.id)
		if v.count > matCount then
			LActor.costItem(actor, v.id, matCount, "zhanling onReqCompose")
		else
			LActor.costItem(actor, v.id, v.count, "zhanling onReqCompose")
		end
	end

	--合成
	LActor.giveItem(actor, itemId, 1, "zhanling onReqCompose")

	if downEquip then
		fdata.equip[pos] = nil

		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhanLingCmd_SendEquipInfo)
		if not pack then return end
		LDataPack.writeChar(pack, 0)
		LDataPack.writeChar(pack, ZhanLingConfig.equipPosCount)
		for i=1, ZhanLingConfig.equipPosCount do
			LDataPack.writeInt(pack, fdata.equip[i] or 0)
		end
		LDataPack.flush(pack)
	end
end

--协议 43-11
--请求激活皮肤/升级皮肤天赋
local function onReqLevelUpTalent(actor, packet)
	local id = LDataPack.readChar(packet)

	local data = getStaticData(actor)
	if not data then return end
	if not checkOpen(actor) then return end

	if id <= 0 or id > #ZhanLingBase then
		actor_log(actor, "onReqLevelUpTalent id error, id:"..tostring(id))
		return
	end

	if not data.fashion[id] then data.fashion[id] = {} end
	local fdata = data.fashion[id]
	local talentId = ZhanLingBase[id].talent
	local talentConf = ZhanLingTalent[talentId]
	local talentLevelConf = talentConf[(fdata.talent or 0) + 1]
	if not talentLevelConf then
		--可能满级
		actor_log(actor, "onReqLevelUpTalent talentLevelConf is nil, id:"..tostring(id)..", level:"..tostring(fdata.talent))
		return
	end

	--是否有此物品
	if LActor.getItemCount(actor, ZhanLingBase[id].mat) < talentLevelConf.costCount then
		actor_log(actor, "onReqLevelUpTalent item not enough, id:"..tostring(id))
		return
	end
	--扣除材料
	LActor.costItem(actor, ZhanLingBase[id].mat, talentLevelConf.costCount, "zhanling onReqLevelUpTalent")

	fdata.talent = (fdata.talent or 0) + 1

	updateAttr(actor)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhanLingCmd_RepLevelUpTalent)
	if not pack then return end
	LDataPack.writeChar(pack, id)
	LDataPack.writeShort(pack, fdata.talent)
	LDataPack.flush(pack)
end

--协议 43-12
--请求切换战灵皮肤
local function onReqChangeFashion(actor, packet)
	local id = LDataPack.readChar(packet)
	local data = getStaticData(actor)
	if not data then return end
	if not checkOpen(actor, false, id, data) then return end
	if not ZhanLingBase[id] then
		actor_log(actor, "onReqChangeFashion ZhanLingBase[id] is nil, id:"..tostring(id))
		return
	end
	data.fid = id
	LActor.setZhanLingId(actor, id)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhanLingCmd_RepChangeFashion)
	if not pack then return end
	LDataPack.writeChar(pack, id)
	LDataPack.flush(pack)
end

local function init()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)

	netmsgdispatcher.reg(systemId, Protocol.cZhanLingCmd_ReqAddExp, onReqAddExp)     --协议 43-2
	netmsgdispatcher.reg(systemId, Protocol.cZhanLingCmd_ReqUseItem, onReqUseItem)   --协议 43-3
	netmsgdispatcher.reg(systemId, Protocol.cZhanLingCmd_ReqEquip, onReqEquip)       --协议 43-4
	netmsgdispatcher.reg(systemId, Protocol.cZhanLingCmd_ReqCompose, onReqCompose)   --协议 43-5
	netmsgdispatcher.reg(systemId, Protocol.cZhanLingCmd_ReqLevelUpTalent, onReqLevelUpTalent)   --协议 43-11
	netmsgdispatcher.reg(systemId, Protocol.cZhanLingCmd_ReqChangeFashion, onReqChangeFashion)   --协议 43-12

	LActor.setZhanLingConfig(ZhanLingConfig.showzhanlingcd, ZhanLingConfig.delayTime)
end
table.insert(InitFnTable, init)

function gmSetZhanLing(actor, id, level)
	if not checkOpen(actor, true) then return false end
	local data = getStaticData(actor)
	if not data then return false end
	local levelConf = ZhanLingLevel[id]
	if not levelConf or not levelConf[level] then return false end
	if not data.fashion[id] then
		data.fashion[id] = {}
		data.fashion[id].talent = 1
	end
	data.fashion[id].lv = level
	data.fashion[id].exp = 0
	sendInfo(actor)
	return true
end

