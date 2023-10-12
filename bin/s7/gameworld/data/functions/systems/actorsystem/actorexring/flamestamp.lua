--烈焰印记
module("flamestamp", package.seeall)

--[[
flamestamp = {
	open = 1, --是否已经激活系统
	lv = 0, --印记等级
	exp = 0, --当前经验
	eff = {
		-- [效果id] = 效果等级
		[1] = 0,
		[2] = 0,
		...
	}
}
]]

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("flamestamp aid:" .. aid .. " log:" .. str)
end

local function getStaticData(actor)
	if not actor then return end
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if not var.flamestamp then
		var.flamestamp = {}
	end
	return var.flamestamp
end

--检查系统是否开放
local function checkOpen(actor)
	local data = getStaticData(actor)
	if not data then
		actor_log(actor, "checkOpen data is nil")
		return false
	end
	return data.open == 1
end

--更新属性
local function updateAttr(actor)
	local data = getStaticData(actor)
	if not data then return end

	local attr = LActor.getActorsystemAttr(actor, attrFlameStamp)
	if attr == nil then
		actor_log(actor, "updateAttr attr is nil")
		return
	end
	attr:Reset()

	local fslvConf = FlameStampLevel[data.lv or 0]
	if not fslvConf then
		actor_log(actor, "updateAttr fslvConf is nil, level:"..tostring(data.lv))
		--数据出错，赶紧报错警告
		assert(false)
		return
	end

	local itemPer = actorexring.GetItemAttrPer(actor, ActorExRingType_HuoYanRing)
	--印记等级属性
	for k,v in pairs(fslvConf.attrs or {}) do
		attr:Add(v.type, v.value+v.value*itemPer/10000)
	end

	--印记效果额外战力
	if nil ~= data.eff then
		local extraPower = 0
		for effId, effConf in pairs(FlameStampEffect) do
			local efflvConf = effConf[data.eff[effId] or 0]
			if nil ~= efflvConf then
				extraPower = extraPower + (efflvConf.exPower or 0)
			end
		end
		attr:SetExtraPower(extraPower)
	end
	LActor.reCalcAttr(actor)
end

--下发数据
local function sendInfo(actor)
	local data = getStaticData(actor)
	if not data then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_FlameStamp, Protocol.sFlameStampCmd_SendInfo)
	if not npack then return end
	LDataPack.writeShort(npack, data.lv or 0)
	LDataPack.writeInt(npack, data.exp or 0)
	LDataPack.writeChar(npack, #FlameStampEffect)
	if not data.eff then data.eff = {} end
	for i=1, #FlameStampEffect do
		LDataPack.writeShort(npack, data.eff[i] or 0)
	end
	LDataPack.flush(npack)
end

--属性初始化
local function onInit(actor)
	if not checkOpen(actor) then return end
	updateAttr(actor)
end

--玩家登陆下发数据
local function onLogin(actor)
	open(actor)  --尝试开启烈焰印记，对烈焰戒指已经超过指定等级的老玩家兼容操作
	if not checkOpen(actor) then return end
	sendInfo(actor)
end

-- 活动增加经验
local function getActivityExp(actor)
	for activityID, rates in pairs(FlameStamp.activityRate or {}) do
		if not activitysystem.activityTimeIsEnd(activityID) then
			local totalRate = 0
			for _,v in pairs(rates or {}) do totalRate = totalRate + v.rate end
			if totalRate > 0 then
				local rnd = math.random(1, totalRate)
				local tTotal = 0
				for _,v in pairs(rates or {}) do
					tTotal = tTotal + v.rate
					if rnd <= tTotal then
						local npack = LDataPack.allocPacket(actor, Protocol.CMD_FlameStamp, Protocol.sFlameStampCmd_RepAddExp)
						if nil ~= npack then
							LDataPack.writeChar(npack, v.times)
							LDataPack.flush(npack)
						end
						return v.times
					end
				end
			end
		end
	end
	return 1
end

--协议 71-2
--请求提升等级经验
local function onReqAddExp(actor)
	local data = getStaticData(actor)
	if not data or data.open ~= 1 then return end

	local level = data.lv or 1
	local fslvConf = FlameStampLevel[level]
	if not fslvConf then
		actor_log(actor, "onReqAddExp fslvConf is nil, level:"..tostring(data.lv))
		--数据出错，赶紧报错警告
		assert(false)
		return
	end

	local nextConf = FlameStampLevel[level + 1]
	if not nextConf then
		--满级
		LActor.sendTipmsg(actor, Lang.ScriptTips.lhx002, ttMessage)
		return
	end

	if 0 ~= fslvConf.costItem then
		--扣材料
		if LActor.getItemCount(actor, fslvConf.costItem) < fslvConf.costCount then
			LActor.sendTipmsg(actor, Lang.ScriptTips.lhx004, ttMessage)
			return
		end
		LActor.costItem(actor, fslvConf.costItem, fslvConf.costCount, "flamestamp addexp")
		data.exp = (data.exp or 0) + FlameStampMat[fslvConf.costItem].exp * fslvConf.costCount * getActivityExp(actor)
	end

	if data.exp >= fslvConf.exp then
		--升级
		data.lv = level + 1
		data.exp = data.exp - fslvConf.exp
		if not data.eff then data.eff = {} end
		for _,v in pairs(nextConf.openEffs or {}) do
			data.eff[v.id] = v.level
		end
	end

	sendInfo(actor)
	updateAttr(actor)
end

--协议 71-3
--请求提升印记效果
local function onReqLearnEff(actor, packet)
	local effId = LDataPack.readChar(packet)  --效果id
	local effConf = FlameStampEffect[effId]
	if not effConf then
		actor_log(actor, "onReqLearnEff effConf is nil, effId:"..tostring(effId))
		return
	end

	local data = getStaticData(actor)
	if not data or data.open ~= 1 then return end
	if not data.eff then data.eff = {} end
	local efflv = data.eff[effId] or 0
	local nextlv = efflv + 1

	local efflvConf = effConf[nextlv]
	if not efflvConf then
		--可能满级
		LActor.sendTipmsg(actor, Lang.ScriptTips.lhx002, ttMessage)
		return
	end

	if (data.lv or 0) < efflvConf.stampLevel then
		--还没解锁
		actor_log(actor, "onReqLearnEff stampLevel not enough, data.lv:"..tostring(data.lv))
		return
	end

	if 0 ~= efflvConf.costItem then
		--扣材料
		if LActor.getItemCount(actor, efflvConf.costItem) < efflvConf.costCount then
			LActor.sendTipmsg(actor, Lang.ScriptTips.lhx004, ttMessage)
			return
		end
		LActor.costItem(actor, efflvConf.costItem, efflvConf.costCount, "flamestamp learneff")
	end
	data.eff[effId] = nextlv
	sendInfo(actor)
	updateAttr(actor)
end

--向下合成
local function composeDown(actor, itemId)
	local fsmatConf = FlameStampMat[itemId]
	if not fsmatConf or not fsmatConf.costItem or fsmatConf.costItem == 0 then return 0 end

	local matCount = LActor.getItemCount(actor, fsmatConf.costItem)   --原本材料个数
	local totalMatCount = composeDown(actor, fsmatConf.costItem) + matCount  --转换后材料个数
	local itemCount = math.floor(totalMatCount/fsmatConf.costCount)  --获得物品个数
	local leave = totalMatCount - itemCount * fsmatConf.costCount  --剩余材料个数
	if leave > matCount then
		LActor.giveItem(actor, fsmatConf.costItem, leave - matCount, "flamestamp composeDown")
	else
		LActor.costItem(actor, fsmatConf.costItem, matCount - leave, "flamestamp composeDown")
	end
	return itemCount
end

--协议 71-4
--请求合成材料
local function onReqCompose(actor, packet)
	local itemId = LDataPack.readInt(packet)
	local data = getStaticData(actor)
	if not data or data.open ~= 1 then return end
	
	local fsmatConf = FlameStampMat[itemId]
	if not fsmatConf then
		actor_log(actor, "onReqCompose fsmatConf is nil, itemId:"..tostring(itemId))
		return
	end

	if (fsmatConf.costItem or 0) == 0 then
		LActor.sendTipmsg(actor, "无法合成", ttMessage)
		return
	end

	local itemCount = 0
	local matCount = LActor.getItemCount(actor, fsmatConf.costItem)
	if matCount >= fsmatConf.costCount then
		--直接合成
		itemCount = math.floor(matCount/fsmatConf.costCount)
		LActor.costItem(actor, fsmatConf.costItem, itemCount * fsmatConf.costCount, "flamestamp composeDown")
	else
		--向下合成
		itemCount = composeDown(actor, itemId)
	end

	if itemCount > 0 then
		LActor.giveItem(actor, itemId, itemCount, "flamestamp composeDown")
	end
end

--尝试开启系统，烈焰戒指系统调用
function open(actor)
	local data = getStaticData(actor)
	if not data then
		actor_log(actor, "open data is nil")
		return
	end

	if data.open ~= 1 then
		local level = LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing)
		if level >= FlameStamp.openLevel then
			data.lv = 1
			data.exp = 0
			data.eff = {}
			data.open = 1
			local fslvConf = FlameStampLevel[1]
			if not fslvConf then
				--配置出错，赶紧报错警告
				assert(false)
				return
			end
			for _,v in pairs(fslvConf.openEffs or {}) do
				data.eff[v.id] = v.level
			end
			sendInfo(actor)
			updateAttr(actor)
		end
	end
end

function getSummonerAttr(actor)
	if not actor then return end
	local data = getStaticData(actor)
	if not data or data.open ~= 1 then return end

	local fslvConf = FlameStampLevel[data.lv or 1]
	if not fslvConf then
		actor_log(actor, "getSummonerAttr fslvConf is nil, data.lv:"..tostring(data.lv))
		return
	end
	return fslvConf.summonerAttr
end

--烈焰戒指属性设置
function setRingData(actor, mon)
	if not actor or not mon then return end
	local data = getStaticData(actor)
	if not data or data.open ~= 1 then return end
	if not data.eff then data.eff = {} end

	local fslvConf = FlameStampLevel[data.lv or 1]
	if not fslvConf then
		actor_log(actor, "setRingData fslvConf is nil, data.lv:"..tostring(data.lv))
		return
	end

	local skillId = 0
	if (data.eff[2] or 0) == 0 then
		skillId = FlameStampEffect[1][1].skillId  --初始阶段
	else
		local effConf = FlameStampEffect[2][data.eff[2] or 0]
		if not effConf then
			actor_log(actor, "setRingData effConf is nil, data.eff[2]:"..tostring(data.eff[2]))
			return
		end
		skillId = effConf.skillId
	end

	local skillConf = SkillsConfig[skillId]
	if not skillConf then
		actor_log(actor, "setRingData skillConf is nil, skillId = "..tostring(skillId))
		assert(false)
		return
	end
	LActor.AddSkill(mon, skillId)  --给戒指上加特林技能

	local cd = 0
	local a = (fslvConf.bulletDamage or {}).a or 0
	local b = (fslvConf.bulletDamage or {}).b or 0
	for i=1, #FlameStampEffect do
		local effConf = FlameStampEffect[i][data.eff[i] or 0]
		if nil ~= effConf then
			cd = cd + (effConf.reloadTime or 0)  --加特林cd技能修正
			a = a + ((effConf.bulletDamage or {}).a or 0)  --子弹伤害技能修正
			b = b + ((effConf.bulletDamage or {}).b or 0)  --子弹伤害技能修正
		end
	end
	LActor.AddSkillRevise(mon, skillId, cd)  --加特林技能修正

	for _, bulletId in pairs(SkillsConfig[skillId].otherSkills or {}) do
		--上子弹
		LActor.AddSkill(mon, bulletId)
		LActor.AddSkillRevise(mon, bulletId, 0, a, b)  --子弹技能修正
		for i=1, #FlameStampEffect do
			local effConf = FlameStampEffect[i][data.eff[i] or 0]
			if nil ~= effConf then
				if (effConf.effId or 0) ~= 0 then 
					LActor.AddSkillReviseTarBuff(mon, bulletId, effConf.effId)
				end
				--if (effConf.selfEffId or 0) ~= 0 then
				--暂时不用
				--	LActor.AddSkillReviseSelfBuff(mon, bulletId, effConf.selfEffId)
				--end
			end
		end
	end
	LActor.SetSkillCdById(mon, skillId, skillConf.cd - cd)
end

--实体下发
function masterData(actor, et)
	local data = getStaticData(actor)
	if not data or data.open ~= 1 then return end
	LActor.SetFlameStampLv(et, data.lv or 1);
	for i=1, #FlameStampEffect do
		LActor.SetFlameStampSkillLv(et, i, data.eff[i] or 0)
	end
end

--给遭遇战等玩家附加的数据
function CloneData(actor, npack)
	local data = getStaticData(actor)
	if not data or data.open ~= 1 then
		LDataPack.writeShort(npack, 0)
		LDataPack.writeChar(npack, 0)
		return 
	end

	LDataPack.writeShort(npack, data.lv or 1)
	LDataPack.writeChar(npack, #FlameStampEffect)
	if not data.eff then data.eff = {} end
	for i=1, #FlameStampEffect do
		LDataPack.writeShort(npack, data.eff[i] or 0)
	end
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_FlameStamp, Protocol.cFlameStampCmd_ReqAddExp, onReqAddExp)      --协议 71-2
netmsgdispatcher.reg(Protocol.CMD_FlameStamp, Protocol.cFlameStampCmd_ReqLearnEff, onReqLearnEff)  --协议 71-3
netmsgdispatcher.reg(Protocol.CMD_FlameStamp, Protocol.cFlameStampCmd_ReqCompose, onReqCompose)    --协议 71-4

