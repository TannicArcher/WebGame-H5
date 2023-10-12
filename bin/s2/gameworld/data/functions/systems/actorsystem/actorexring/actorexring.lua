--玩家特戒,玩家级别的特戒
module("actorexring", package.seeall)

local config = ActorExRingConfig
local ringConf = {}
for k,_ in pairs(config) do
	ringConf[k] = _G["ActorExRing"..tostring(k).."Config"]
end

--[[获取玩家特戒静态变量数据
	login_day = 登陆天数
	ring_power = 特戒升级能量
	unlock = {} --解锁了的特戒ID
	skillBook = {
		[特戒ID]={
			info = {
				{index=位置, sbid=技能书ID, lv=等级}
			}
			pos[位置]=info的索引
			ybCount = 元宝开启的格仔数
		}
	}
	useItem = {--使用了增强道具
		[特戒ID]={
			[1] = 1,表示开启了1号功能
		}
	}
	summonerSkillLvAdd = 怪物技能提升等级
]]
local function getVarData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	--初始化静态变量的数据
	if var.actorExRingData == nil then
		var.actorExRingData = {}
		var.actorExRingData.login_day = 0
	end
	if var.actorExRingData.ring_power == nil then --特戒升级能量
		var.actorExRingData.ring_power = {}
	end
	return var.actorExRingData
end

--获取特戒道具对属性的加成比例总和
function GetItemAttrPer(actor,idx)
	--没有配置
	local cfg = ActorExRingItemConfig[idx]
	if not cfg then
		return 0
	end
	--没有使用过这样的道具
	local SVar = getVarData(actor)
	if not SVar.useItem or not SVar.useItem[idx] then
		return 0
	end
	--求和
	local per = 0
	for id,v in pairs(cfg) do
		local lv = SVar.useItem[idx][id]
		if lv and v[lv] then
			per = per + v[lv].attrPer
		end
	end
	return per
end

--计算特戒的属性
local function calcAttr(actor, recalc)
	local attr = LActor.getActorExRingAttr(actor)
	if attr == nil then return end
	local ex_attr = LActor.getActorExRingExAttr(actor)
	if ex_attr == nil then return end
	attr:Reset();
	ex_attr:Reset();
	local exPower = 0
	for k,v in pairs(config) do
		local level = LActor.getActorExRingLevel(actor, k)
		if level > 0 and ringConf[k] and ringConf[k][level] 
			and LActor.GetActorExRingIsEff(actor, k) then 
			--道具属性加成
			local itemPer = GetItemAttrPer(actor, k)
			--特戒的属性
			for k,v in ipairs(ringConf[k][level].attrAward or {}) do
				attr:Add(v.type, v.value+v.value*itemPer/10000)
			end
			for k,v in ipairs(ringConf[k][level].extAttrAward or {}) do
				ex_attr:Add(v.type, v.value)
			end
			exPower = exPower + (ringConf[k][level].exPower or 0)
			--技能书属性
			local SVar = getVarData(actor)
			SVar.summonerSkillLvAdd = 0
			local attrVal = {}
			local attrPer = {}
			if SVar.skillBook and SVar.skillBook[k] and SVar.skillBook[k].info then
				local count = #SVar.skillBook[k].info
				for i=1,count do
					local info_data = SVar.skillBook[k].info[i]
					--技能书配置
					local SkillBookCfg = ActorExRingBookConfig[info_data.sbid]
					if SkillBookCfg then
						--技能书等级配置
						local SkillBookLvCfg = SkillBookCfg[info_data.lv]
						if SkillBookLvCfg then
							for k,v in ipairs(SkillBookLvCfg.attr or {}) do
								attr:Add(v.type, v.value)
								attrVal[v.type] = (attrVal[v.type] or 0) + v.value
							end
							for k,v in ipairs(SkillBookLvCfg.extAttr or {}) do
								ex_attr:Add(v.type, v.value)
							end
							--额外增加技能书属性
							for k,v in ipairs(SkillBookLvCfg.bookAttrPer or {}) do
								attrPer[v.type] = (attrPer[v.type] or 0) + v.value
							end
							SVar.summonerSkillLvAdd = SVar.summonerSkillLvAdd + (SkillBookLvCfg.summonerSkillLvAdd or 0)
							exPower = exPower + (SkillBookLvCfg.exPower or 0)
						end
					end
				end
				for k,v in pairs(attrPer) do
					if attrVal[k] then
						attr:Add(k, attrVal[k] * v/10000)
					end
				end
			end
		end
	end
	attr:SetExtraPower(exPower)
	if recalc then
		LActor.reCalcAttr(actor)
		LActor.reCalcExAttr(actor)
	end
	return true
end

_G.calcActorExRingAttr = calcAttr

--下发玩家新的特戒项数据
local function sendActorExRingItemData(actor, idx, msgId, isBj)
	if actor == nil then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_ExRing, msgId)
	local level = LActor.getActorExRingLevel(actor, idx)
	LDataPack.writeShort(npack, idx) --特戒索引
	LDataPack.writeShort(npack, level) --特戒等级
	--获取静态变量
	local SVar = getVarData(actor)
	LDataPack.writeInt(npack, SVar.ring_power[idx] or 0)
	--判断是否需要发送暴击
	if msgId == Protocol.sExRingCmd_UpgradeActorRing then
		LDataPack.writeChar(npack, isBj and 1 or 0)
	end
	LDataPack.writeChar(npack, LActor.GetActorExRingIsEff(actor, idx) and 1 or 0)
	LDataPack.writeChar(npack, SVar.unlock and SVar.unlock[idx] or 0)
	LDataPack.flush(npack)
end

--刷新召唤物的所有东西, 包括技能,AI,属性,等等等
local function RefreshMonsterAllData(actor, monster, rid)
	if LActor.getFubenId(actor) == 0 then return end
	--获取两个戒指的等级
	local rlv = LActor.getActorExRingLevel(actor, rid)
	if LActor.GetActorExRingIsEff(actor, rid) == false then return end
	if rlv <= 0 then return end --两个戒指都没有激活
	if not monster then --没有传召唤怪; 就获取
		monster = LActor.getActorExRingMonster(actor, rid)
	end
	if not monster then
		print(LActor.getActorId(actor).." actorexring.ActorExRingSystem RefreshMonsterAllData is not have monster rid="..rid)
		return
	end
	--获取属性
	local attr = LActor.getActorExRingMonsterAttr(actor, rid)
	attr:Reset()
	local ex_attr = LActor.getActorExRingMonsterExAttr(actor, rid)
	ex_attr:Reset()
	
	--技能
	if rlv > 0 then
		for i = 1,1 do 
			local cfg = ringConf[rid]
			local itemCfg = cfg[rlv]
			if not itemCfg then break end
			--计算属性
			for k,v in ipairs(itemCfg.summonerAttr or {}) do
				attr:Add(v.type, v.value)
			end
			for k,v in ipairs(itemCfg.summonerExAttr or {}) do
				ex_attr:Add(v.type, v.value)
			end
			local SVar = getVarData(actor)
			--技能书增加怪物属性
			if SVar.skillBook and SVar.skillBook[rid] and SVar.skillBook[rid].info then
				local count = #(SVar.skillBook[rid].info)
				print("skillBook count="..count)
				for i=1,count do
					local info_data = SVar.skillBook[rid].info[i]
					--技能书配置
					local SkillBookCfg = ActorExRingBookConfig[info_data.sbid]
					if SkillBookCfg then
						--技能书等级配置
						local SkillBookLvCfg = SkillBookCfg[info_data.lv]
						if SkillBookLvCfg then
							for k,v in ipairs(SkillBookLvCfg.summonerAttr or {}) do
								attr:Add(v.type, v.value)
							end
							for k,v in ipairs(SkillBookLvCfg.summonerExAttr or {}) do
								ex_attr:Add(v.type, v.value)
							end
						end
					end
				end
			end
			--更换技能
			--旧等级技能删掉
			LActor.DelAllSkill(monster)
			--学上新等级技能
			if itemCfg.summonerSkillId then
				LActor.AddSkill(monster, itemCfg.summonerSkillId + (SVar.summonerSkillLvAdd or 0))
			end
			flamestamp.setRingData(actor, monster)
		end
	end
	
	local fsattr = flamestamp.getSummonerAttr(actor)
	for _,v in ipairs(fsattr or {}) do
		attr:Add(v.type, v.value)
	end

	--刷新属性
	LActor.reCalcAttr(monster)
	LActor.reCalcExAttr(monster)
end

--获取特戒道具对怪物的ID加成总和
local function GetMonIdRes(actor,idx)
	--没有配置
	local cfg = ActorExRingItemConfig[idx]
	if not cfg then
		return 0
	end
	--没有使用过这样的道具
	local SVar = getVarData(actor)
	if not SVar.useItem or not SVar.useItem[idx] then
		return 0
	end
	--求和
	local res = 0
	for id,v in pairs(cfg) do
		local lv = SVar.useItem[idx][id]
		if lv and v[lv] then
			res = res + v[lv].monId
		end
	end
	return res
end

--创建一只特戒召唤物
local function createActorExRingMonster(actor, rid)
	if LActor.getFubenId(actor) == 0 then return end
	local rcfg = config[rid]
	if not rcfg or not rcfg.monsterId or rcfg.monsterId <= 0 then return end
	if LActor.getFubenId(actor) == 0 then return end
	if LActor.GetActorExRingIsEff(actor, rid) == false then return end
	local rlv = LActor.getActorExRingLevel(actor, rid)
	if rid == ActorExRingType_HuoYanRing then flamestamp.masterData(actor, actor) end
	if rlv > 0 and rlv >= (rcfg.showMonsterLv or 0) then
		local monster = LActor.createActorExRingMonster(actor, rid, rcfg.monsterId+GetMonIdRes(actor,rid))
		RefreshMonsterAllData(actor, monster, rid)
		return monster
	end
end
_G.createActorExRingMonster = createActorExRingMonster

local function RefreshCloneMonsterAllData(actor, clone, monster, rid, rlv)
	local cfg = ringConf[rid]
	local itemCfg = cfg[rlv]
	if not itemCfg then return end
	local SVar = getVarData(actor)
	--计算属性
	for k,v in ipairs(itemCfg.summonerAttr or {}) do
		LActor.AddAerMonAttr(clone, rid, v.type, v.value)
	end
	for k,v in ipairs(itemCfg.summonerExAttr or {}) do
		LActor.AddAerMonExAttr(clone, rid, v.type, v.value)
	end
	--技能书增加怪物属性
	if SVar.skillBook and SVar.skillBook[rid] and SVar.skillBook[rid].info then
		local count = #(SVar.skillBook[rid].info)
		for i=1,count do
			local info_data = SVar.skillBook[rid].info[i]
			--技能书配置
			local SkillBookCfg = ActorExRingBookConfig[info_data.sbid]
			if SkillBookCfg then
				--技能书等级配置
				local SkillBookLvCfg = SkillBookCfg[info_data.lv]
				if SkillBookLvCfg then
					for k,v in ipairs(SkillBookLvCfg.summonerAttr or {}) do
						LActor.AddAerMonAttr(clone, rid, v.type, v.value)
					end
					for k,v in ipairs(SkillBookLvCfg.summonerExAttr or {}) do
						LActor.AddAerMonExAttr(clone, rid, v.type, v.value)
					end
				end
			end
		end
	end

	local fsattr = flamestamp.getSummonerAttr(actor)
	for _,v in ipairs(fsattr or {}) do
		LActor.AddAerMonAttr(clone, rid, v.type, v.value)
	end

	--更换技能
	--旧等级技能删掉
	LActor.DelAllSkill(monster)
	--学上技能
	if itemCfg.summonerSkillId then
		LActor.AddSkill(monster, itemCfg.summonerSkillId + (SVar.summonerSkillLvAdd or 0))
	end
	flamestamp.setRingData(actor, monster)
	--刷新属性
	LActor.reCalcAttr(monster)
	LActor.reCalcExAttr(monster)
end
--创建特戒召唤物到指定场景,克隆玩家的处理
local function createCloneActorExRingMonster(actor, sceneHandle, x, y, clone)
	for rid,conf in pairs(config) do
		if conf.monsterId then 
			if LActor.GetActorExRingIsEff(actor, rid) == true then
				local rlv = LActor.getActorExRingLevel(actor, rid)
				if rlv > 0 and rlv >= (conf.showMonsterLv or 0) then
					--先用玩家创建,其实和玩家并没关联,后面附加到克隆玩家身上
					--local monster = LActor.createActorExRingMonster(actor, rid, conf.monsterId)
					if rid == ActorExRingType_HuoYanRing then flamestamp.masterData(actor, clone) end
					local monster = Fuben.createMonster(sceneHandle, conf.monsterId, x, y, 0, clone)
					if monster then
						--LActor.enterScene(monster, sceneHandle, x, y)--进入场景
						--LActor.SetMasterHandle(monster, clone) --重新设置召唤怪的主人
						LActor.setCamp(monster, LActor.getCamp(clone)) --设置阵营
						LActor.SetAexringMon(clone, rid, monster) --克隆角色附加上这个召唤怪
						RefreshCloneMonsterAllData(actor, clone, monster, rid, rlv)--最后把属性加上
					end
				end
			end
		end
	end
end
_G.createCloneActorExRingMonster = createCloneActorExRingMonster

--请求解锁特戒
local function onReqUnlock(actor, packet)
	local idx = LDataPack.readShort(packet) --解锁第几个戒指
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.onReqUnlock idx("..idx..") not config")
		return
	end
	--先判断是否需要解锁
	if not ExRingCfg.openCond then
		print(LActor.getActorId(actor).." actorexring.onReqUnlock idx("..idx..") do not unlock")
		return
	end
	--local level = LActor.getActorExRingLevel(actor, idx)
	--if level > 0 then
	--	print(LActor.getActorId(actor).." actorexring.onReqUnlock idx("..idx..") has lv")
	--	return
	--end
	--获取静态变量
	local SVar = getVarData(actor)
	--是否重复解锁
	if SVar.unlock and SVar.unlock[idx] then
		print(LActor.getActorId(actor).." actorexring.onReqUnlock idx("..idx..") is repeated unlock")
		return
	end

	--判断解锁条件是否满足
	for _,id in ipairs(ExRingCfg.openCond) do
		if LActor.getActorExRingLevel(actor, id) <= 0 then
			print(LActor.getActorId(actor).." actorexring.onReqUnlock idx("..idx..") not act id("..id..")")
			return
		end
	end

	--清空关联的任务的进度
	for i,v in pairs(ExRingCfg.openTask or {}) do 
		achievetask.clearInitTask(actor,v.achieveId,v.taskId)
	end

	--解锁
	if not SVar.unlock then SVar.unlock = {} end
	SVar.unlock[idx] = 1
	sendActorExRingItemData(actor, idx, Protocol.sExRingCmd_UnlockActorRing, false)
end

--请求激活特戒
local function onReqAct(actor, packet)
	local idx = LDataPack.readShort(packet) --激活第几个戒指
	local useYb = LDataPack.readChar(packet) --是否使用元宝
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.onReqAct idx("..idx..") not config")
		return
	end
	local level = LActor.getActorExRingLevel(actor, idx)
	if level > 0 then
		print(LActor.getActorId(actor).." actorexring.onReqAct idx("..idx..") is repeated activation")
		return
	end
	--获取静态变量
	local SVar = getVarData(actor)
	--判断是否需要先解锁
	if ExRingCfg.openCond then
		--看看有没有解锁
		if not SVar.unlock or not SVar.unlock[idx] then
			print(LActor.getActorId(actor).." actorexring.onReqAct idx("..idx..") need unlock")
			return
		end
	end

	--获取玩家VIP等级
	local vipLv = LActor.getVipLevel(actor)
	local initLv = 1 --激活初始等级
	if useYb == 1 then
		if not ExRingCfg.useYb then
			print(LActor.getActorId(actor).." actorexring.onReqAct can not useYb")
			return
		end
		if ExRingCfg.useYb > LActor.getCurrency(actor, NumericType_YuanBao) then
			print(LActor.getActorId(actor).." actorexring.onReqAct idx("..idx..") is not have enough YuanBao")
			return
		end
		LActor.changeYuanBao(actor, -ExRingCfg.useYb, "yb act actorExRing "..idx)
		initLv = ExRingCfg.useYbInitLv
	else
		--判断激活条件
		if (SVar and SVar.login_day >= ExRingCfg.openDay and ExRingCfg.openDay >= 0) or --登陆天数满足
			(vipLv >= ExRingCfg.openVip and ExRingCfg.openVip >= 0) then	--VIP等级满足
			--判断是否完成了任务
			for i,v in pairs(ExRingCfg.openTask or {}) do 
				if not achievetask.isFinish(actor,v.achieveId,v.taskId) then 
					print(LActor.getActorId(actor).." actorexring.onReqAct idx("..idx..") not finish openTask aid:"..v.achieveId..",tid:"..v.taskId)
					return
				end
			end
			--判断是否要钱激活
			if ExRingCfg.openYb and ExRingCfg.openYb > 0 then
				if ExRingCfg.openYb > LActor.getCurrency(actor, NumericType_YuanBao) then
					print(LActor.getActorId(actor).." actorexring.onReqAct idx("..idx..") is not have enough YuanBao")
					return
				end
				LActor.changeYuanBao(actor, -ExRingCfg.openYb, "act actorExRing "..idx)
			end
		else
			return
		end
	end
	LActor.setActorExRingLevel(actor, idx, initLv) --设置为等级1,激活这个特戒
	if (ExRingCfg.mtCombat or 0) == 0 then
		--不需要手工出战的戒指;登陆时候自动出战
		LActor.SetActorExRingIsEff(actor, idx, 1)
	end
	calcAttr(actor, true) --重新计算玩家属性
	sendActorExRingItemData(actor, idx, Protocol.sExRingCmd_ActActorRing, false)
	if ExRingCfg.monsterId then
		createActorExRingMonster(actor, idx)
	end
	actorevent.onEvent(actor, aeActAExring, idx)
end

--请求升级特戒
local function onReqUpgrade(actor, packet)
	local idx = LDataPack.readShort(packet) --升级第几个戒指
	--获取配置
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.onReqUpgrade idx("..idx..") not config")
		return
	end
	--获取特戒等级
	local level = LActor.getActorExRingLevel(actor, idx)
	if level <= 0 then
		print(LActor.getActorId(actor).." actorexring.onReqUpgrade idx("..idx..") not activation")
		return
	end
	--判断全局升级条件
	if ExRingCfg.needLevel and ExRingCfg.needLevel > 0 then
		if LActor.getLevel(actor) < ExRingCfg.needLevel then
			print(LActor.getActorId(actor).." actorexring.onReqUpgrade idx("..idx..") actor level too low")
			return
		end
	end
	if ExRingCfg.needZs and ExRingCfg.needZs > 0 then
		if LActor.getZhuanShengLevel(actor) < ExRingCfg.needZs then
			print(LActor.getActorId(actor).." actorexring.onReqUpgrade idx("..idx..") actor zhuansheng too low")
			return
		end		
	end
	--获取特戒等级配置
	local ExRingLvItemCfg = ringConf[idx]
	if not ExRingLvItemCfg then
		print(LActor.getActorId(actor).." actorexring.onReqUpgrade idx("..idx..") not all level config")
		return
	end
	--判断是否已经满级
	if not ExRingLvItemCfg[level+1] then 
		print(LActor.getActorId(actor).." actorexring.onReqUpgrade idx("..idx..") is max level")
		return
	end
	--获取特戒当前等级配置子配置
	local ExRingLvCfg = ExRingLvItemCfg[level]
	if not ExRingLvItemCfg then
		print(LActor.getActorId(actor).." actorexring.onReqUpgrade idx("..idx..") level("..level..") not level config")
		return
	end	
	--获取静态变量
	local SVar = getVarData(actor)
	if SVar.ring_power[idx] == nil then
		SVar.ring_power[idx] = 0
	end
	--如果是需要进阶确认的等级; 满能量了不能再加了
	if ExRingLvCfg.judgeup == 1 and SVar.ring_power[idx] >= (ExRingLvCfg.upPower or 0) then
		print(LActor.getActorId(actor).." actorexring.onReqUpgrade need req Advanced")
		return
	end
	--检测升级消耗
	local count = LActor.getItemCount(actor, ExRingLvCfg.costItem)
	if count < ExRingLvCfg.cost then
		print(LActor.getActorId(actor).." actorexring.onReqUpgrade not enough cost item")
		return
	end
	--扣除消耗
	LActor.costItem(actor, ExRingLvCfg.costItem, ExRingLvCfg.cost, "upgrade actor ex ring")
	local addPower = (ExRingLvCfg.addPower or 0)
	local isBj = false
	--计算是否暴击
	if ExRingLvCfg.bjRate and ExRingLvCfg.bjRate > System.getRandomNumber(10000) then
		addPower = (ExRingLvCfg.bjAddPower or 0)
		isBj = true
	end
	--增加能量
	SVar.ring_power[idx] = SVar.ring_power[idx] + addPower
	--判断能量是否足够升级
	if ExRingLvCfg.judgeup ~= 1 and SVar.ring_power[idx] >= (ExRingLvCfg.upPower or 0) then
		--多余的能量保存到下一级
		SVar.ring_power[idx] = SVar.ring_power[idx] - (ExRingLvCfg.upPower or 0)
		--设置等级
		LActor.setActorExRingLevel(actor, idx, level + 1) --特戒升级
		--重新计算玩家属性
		calcAttr(actor, true)
		--尝试开启烈焰印记
		if idx == ActorExRingType_HuoYanRing then flamestamp.open(actor) end
		--召唤怪的刷新
		if ExRingCfg.monsterId then
			RefreshMonsterAllData(actor, nil, idx)
		end
	end
	sendActorExRingItemData(actor, idx, Protocol.sExRingCmd_UpgradeActorRing, isBj)
end

--请求进阶特戒
local function onReqAdvanced(actor, packet)
	local idx = LDataPack.readShort(packet) --升级第几个戒指
	--获取配置
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.onReqAdvanced idx("..idx..") not config")
		return
	end
	--获取特戒等级
	local level = LActor.getActorExRingLevel(actor, idx)
	if level <= 0 then
		print(LActor.getActorId(actor).." actorexring.onReqAdvanced idx("..idx..") not activation")
		return
	end
	--获取特戒等级配置
	local ExRingLvItemCfg = ringConf[idx]
	if not ExRingLvItemCfg then
		print(LActor.getActorId(actor).." actorexring.onReqAdvanced idx("..idx..") not all level config")
		return
	end
	--判断是否已经满级
	if not ExRingLvItemCfg[level+1] then 
		print(LActor.getActorId(actor).." actorexring.onReqAdvanced idx("..idx..") is max level")
		return
	end
	--获取特戒当前等级配置子配置
	local ExRingLvCfg = ExRingLvItemCfg[level]
	if not ExRingLvItemCfg then
		print(LActor.getActorId(actor).." actorexring.onReqAdvanced idx("..idx..") level("..tostring(level)..") not level config")
		return
	end	
	--获取静态变量
	local SVar = getVarData(actor)
	if SVar.ring_power[idx] == nil then
		SVar.ring_power[idx] = 0
	end
	--如果是需要进阶确认的等级; 满能量了不能再加了
	if not ExRingLvCfg.judgeup or SVar.ring_power[idx] < (ExRingLvCfg.upPower or 0) then
		print(LActor.getActorId(actor).." actorexring.onReqAdvanced can not full power")
		return
	end
	--判断能量是否足够升级
	--if ExRingLvCfg.judgeup and SVar.ring_power[idx] >= ExRingLvCfg.upPower then
		--多余的能量保存到下一级
		SVar.ring_power[idx] = SVar.ring_power[idx] - (ExRingLvCfg.upPower or 0)
		--设置等级
		LActor.setActorExRingLevel(actor, idx, level + 1) --特戒升级
		--尝试开启烈焰印记
		if idx == ActorExRingType_HuoYanRing then flamestamp.open(actor) end
		--重新计算玩家属性
		calcAttr(actor, true)
		--召唤怪的刷新
		if ExRingCfg.monsterId then
			RefreshMonsterAllData(actor, nil, idx)
		end
	--end
	sendActorExRingItemData(actor, idx, Protocol.sExRingCmd_AdvancedActorRing, false)
end

--出战or收回特戒
local function OutOrIn(actor, idx, type)
	--获取配置
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.onReqOutOrIn idx("..idx..") not config")
		return
	end
	if not ExRingCfg.mtCombat and ExRingCfg.mtCombat == 0 then 
		return
	end
	--获取特戒等级
	local level = LActor.getActorExRingLevel(actor, idx)
	if level <= 0 then
		print(LActor.getActorId(actor).." actorexring.onReqOutOrIn idx("..idx..") not activation")
		return
	end
	if type ~= 0 then
		--出战戒指
		--判断出战最大数量
		local outNum = 0
		for rid,conf in pairs(config) do
			if conf.mtCombat and conf.mtCombat ~= 0 then
				if LActor.GetActorExRingIsEff(actor, rid) then
					outNum = outNum + 1
				end
			end
		end
		if outNum >= (ActorExRingCommon.MaxOutNum[LActor.getVipLevel(actor)+1] or 0) then
			print(LActor.getActorId(actor).." actorexring.onReqOutOrIn outNum("..tostring(outNum)..") is max")
			return
		end
		LActor.SetActorExRingIsEff(actor, idx, 1)
		if ExRingCfg.monsterId then
			createActorExRingMonster(actor, idx)
		end
	else
		--收回戒指
		LActor.SetActorExRingIsEff(actor, idx, 0)
		if ExRingCfg.monsterId then
			LActor.DestroyBattleRing(actor, idx)
		end
	end
	sendActorExRingItemData(actor, idx, Protocol.sExRingCmd_OutOrInActorRing, false)
	--重新计算玩家属性
	calcAttr(actor, true)
end
--请求出战or收回特戒
local function onReqOutOrIn(actor, packet)
	local idx = LDataPack.readShort(packet) --第几个戒指
	local type = LDataPack.readChar(packet) --出战OR收回
	OutOrIn(actor, idx, type)
end

--更新登陆天数
local function updateLoginDayData(actor) 
	local SVar = getVarData(actor)
	if SVar then
		--if not System.isSameDay(SVar.login_time or 0,System.getNowTime()) then 
		--	SVar.login_time = System.getNowTime() 
			SVar.login_day = SVar.login_day + 1
		--end
	end
end

--下发玩家特戒数据到客户端
local function sendActorExRingData(actor)
	if actor == nil then return end
	--申请一个包
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_ExRing, Protocol.sExRingCmd_ActorData)
	if npack == nil then return	end
	local SVar = getVarData(actor)
	LDataPack.writeInt(npack,SVar.login_day)
	local pos = LDataPack.getPosition(npack)
	local data_count = 0
    LDataPack.writeShort(npack, data_count)  --长度
	for k,v in pairs(config) do
		local level = LActor.getActorExRingLevel(actor, k)
		LDataPack.writeShort(npack, k) --特戒索引
		LDataPack.writeShort(npack, level) --特戒等级
		LDataPack.writeInt(npack, SVar.ring_power[k] or 0)
		LDataPack.writeChar(npack, LActor.GetActorExRingIsEff(actor, k) and 1 or 0)
		LDataPack.writeChar(npack, SVar.unlock and SVar.unlock[k] or 0)
		data_count = data_count + 1
	end
	local end_pos = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeShort(npack, data_count)  --长度
	LDataPack.setPosition(npack, end_pos)
	--LDataPack.writeInt(npack, getExMonsterSkillCd(actor) or 0)
	LDataPack.flush(npack)
end

--同步技能书信息到客户端
local function sendActorExRingSkillBookData(actor, idx)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_ExRing, Protocol.sExRingCmd_SkillBookData)
	if npack == nil then return	end
	local SVar = getVarData(actor)
	LDataPack.writeShort(npack, SVar.skillBook and SVar.skillBook[idx] and SVar.skillBook[idx].ybCount or 0) --元宝开启的格仔数
	local count = SVar.skillBook and SVar.skillBook[idx] and SVar.skillBook[idx].info and #(SVar.skillBook[idx].info) or 0
	LDataPack.writeShort(npack, count)  --长度
	for i=1,count do
		local info_data = SVar.skillBook[idx].info[i]
		LDataPack.writeShort(npack, info_data.index) --位置
		LDataPack.writeShort(npack, info_data.sbid) --技能书ID
		LDataPack.writeShort(npack, info_data.lv) --等级
	end
	LDataPack.flush(npack)
end

--下发使用了的道具能力
local function sendItemUseData(actor)
	local idx = ActorExRingType_HuoYanRing
	--获取特戒道具能力配置
	local cfg = ActorExRingItemConfig[idx]
	if not cfg then return end
	--没有使用过这样的道具
	local SVar = getVarData(actor)
	if not SVar.useItem or not SVar.useItem[idx] then
		return
	end
	--给客户端发数据
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_ExRing, Protocol.sExRingCmd_ItemUseData)
	if npack == nil then return end
	local count = 0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, count)
	for id,_ in pairs(cfg) do
		if SVar.useItem[idx][id] then
			LDataPack.writeShort(npack, id)
			LDataPack.writeShort(npack, SVar.useItem[idx][id])
			count = count + 1
		end
	end
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, pos2)
	LDataPack.flush(npack)
end

--玩家登陆时候触发
local function onLogin(actor)
	--updateLoginDayData(actor) --更新登陆天数
	sendItemUseData(actor)
	for rid,cfg in pairs(config) do
		if (cfg.mtCombat or 0) == 0 then
			--不需要手工出战的戒指;登陆时候自动出战
			local level = LActor.getActorExRingLevel(actor, rid)
			if level > 0 then
				LActor.SetActorExRingIsEff(actor, rid, 1)
			else
				LActor.SetActorExRingIsEff(actor, rid, 0)
			end
		end
		--createActorExRingMonster(actor, rid)
	end
	sendActorExRingData(actor) --下发玩家特戒数据到客户端
	sendActorExRingSkillBookData(actor, ActorExRingType_HuoYanRing)
end

--新的一天到来时候触发
local function onNewDay(actor)
	updateLoginDayData(actor) --更新登陆天数
	sendActorExRingData(actor) --下发玩家特戒数据到客户端
end

--请求开启技能书格仔
local function onReqOpenSkillGrid(actor, packet)
	local idx = ActorExRingType_HuoYanRing --LDataPack.readShort(packet) --戒指ID
	--获取配置
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.onReqOpenSkillGrid idx("..idx..") not config")
		return
	end
	--获取特戒等级
	local level = LActor.getActorExRingLevel(actor, idx)
	if level <= 0 then
		print(LActor.getActorId(actor).." actorexring.onReqOpenSkillGrid idx("..idx..") not activation")
		return
	end
	--获取特戒等级配置
	local ExRingLvItemCfg = ringConf[idx]
	if not ExRingLvItemCfg then
		print(LActor.getActorId(actor).." actorexring.onReqOpenSkillGrid idx("..idx..") not all level config")
		return
	end
	--获取特戒当前等级配置子配置
	local ExRingLvCfg = ExRingLvItemCfg[level]
	if not ExRingLvItemCfg then
		print(LActor.getActorId(actor).." actorexring.onReqOpenSkillGrid idx("..idx..") level("..level..") not level config")
		return
	end	
	--获取静态变量
	local SVar = getVarData(actor)
	if not SVar.skillBook then SVar.skillBook = {} end
	if not SVar.skillBook[idx] then SVar.skillBook[idx] = {} end
	--判断是否买完所有格仔
	if (SVar.skillBook[idx].ybCount or 0) >= (ExRingLvCfg.tollSkillGrid or 0) then
		print(LActor.getActorId(actor).." actorexring.onReqOpenSkillGrid idx("..idx..") level("..level..") grid Sold out")
		return
	end
	--判断钱
	if ExRingCfg.skillGridYb > LActor.getCurrency(actor, NumericType_YuanBao) then
		print(LActor.getActorId(actor).." actorexring.onReqOpenSkillGrid idx("..idx..") is not have enough YuanBao")
		return
	end
	--扣钱
	LActor.changeYuanBao(actor, -ExRingCfg.skillGridYb, "aexring skill grid "..idx)
	--设置格仔数
	SVar.skillBook[idx].ybCount = (SVar.skillBook[idx].ybCount or 0) + 1
	--同步技能书信息到客户端
	sendActorExRingSkillBookData(actor, idx)
end

--请求镶嵌技能书
local function onReqInsertSkillBook(actor, packet)
	local idx = ActorExRingType_HuoYanRing --LDataPack.readShort(packet) --戒指ID
	local sbid = LDataPack.readShort(packet) --技能书ID
	local index = LDataPack.readShort(packet) --镶嵌位置
	--获取配置
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx("..idx..") not config")
		return
	end
	--获取特戒等级
	local level = LActor.getActorExRingLevel(actor, idx)
	if level <= 0 then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx("..idx..") not activation")
		return
	end
	--获取特戒等级配置
	local ExRingLvItemCfg = ringConf[idx]
	if not ExRingLvItemCfg then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx("..idx..") not all level config")
		return
	end
	--获取特戒当前等级配置子配置
	local ExRingLvCfg = ExRingLvItemCfg[level]
	if not ExRingLvItemCfg then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx("..idx..") level("..level..") not level config")
		return
	end
	--获取静态变量
	local SVar = getVarData(actor)
	if not SVar.skillBook then SVar.skillBook = {} end
	if not SVar.skillBook[idx] then SVar.skillBook[idx] = {} end
	local sbdata = SVar.skillBook[idx]
	--判断格仔数是否够
	if #(sbdata.info or {}) >= (sbdata.ybCount or 0) + ExRingLvCfg.freeSkillGrid then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx("..idx..") level("..level..") not have grid")
		return
	end
	--判断是否重复镶嵌
	for i=1,#(sbdata.info or {}) do
		if sbdata.info[i].sbid == sbid or sbdata.info[i].index == index then
			print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx("..idx..") skillBook is have")
			return
		end
	end
	--判断是否足够的镶嵌道具
	local sbCfg = ActorExRingBookConfig[sbid] and ActorExRingBookConfig[sbid][1] or nil
	if not sbCfg then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook sbid("..sbid..") not sbCfg")
		return
	end
	--检测升级消耗
	local count = LActor.getItemCount(actor, sbCfg.itemId)
	if count < sbCfg.num then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook not enough cost item")
		return
	end
	--扣除消耗
	LActor.costItem(actor, sbCfg.itemId, sbCfg.num, "actor ex ring insert skillBook")
	--设置数据
	if not sbdata.info then sbdata.info = {} end
	local pos = #sbdata.info + 1
	sbdata.info[pos] = {}
	sbdata.info[pos].index = index
	sbdata.info[pos].sbid = sbid
	sbdata.info[pos].lv = 1
	if not sbdata.pos then sbdata.pos = {} end
	sbdata.pos[index] = pos
	--重新计算玩家属性
	calcAttr(actor, true)
	--刷新怪物的数据
	if sbCfg.summonerAttr or sbCfg.summonerExAttr or sbCfg.summonerSkillLvAdd then
		RefreshMonsterAllData(actor, nil, idx)
	end
	--同步技能书信息到客户端
	sendActorExRingSkillBookData(actor, idx)
end

--请求升级技能书
local function onReqLvUpSkillBook(actor, packet)
	local idx = ActorExRingType_HuoYanRing --LDataPack.readShort(packet) --戒指ID
	local index = LDataPack.readShort(packet) --镶嵌位置
	--获取配置
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx("..idx..") not config")
		return
	end
	--获取特戒等级
	local level = LActor.getActorExRingLevel(actor, idx)
	if level <= 0 then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx("..idx..") not activation")
		return
	end
	--获取静态变量
	local SVar = getVarData(actor)
	if not SVar.skillBook then SVar.skillBook = {} end
	if not SVar.skillBook[idx] then SVar.skillBook[idx] = {} end
	local sbdata = SVar.skillBook[idx]
	--查询是否有镶嵌这个位置
	if not sbdata.pos or not sbdata.pos[index] then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx:"..idx..",index:"..index.." not book")
		return
	end
	--获取位置信息
	local pos = sbdata.pos[index]
	if not sbdata.info or not sbdata.info[pos] then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook idx:"..idx..",index:"..index.." not sbinfo")
		return
	end
	local sbid = sbdata.info[pos].sbid
	local newLv = sbdata.info[pos].lv + 1
	--判断是否足够的镶嵌道具
	local sbCfg = ActorExRingBookConfig[sbid] and ActorExRingBookConfig[sbid][newLv] or nil
	if not sbCfg then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook sbid("..tostring(sbid)..") not sbCfg")
		return
	end
	--检测升级消耗
	local count = LActor.getItemCount(actor, sbCfg.itemId)
	if count < sbCfg.num then
		print(LActor.getActorId(actor).." actorexring.onReqInsertSkillBook not enough cost item")
		return
	end
	--扣除消耗
	LActor.costItem(actor, sbCfg.itemId, sbCfg.num, "actor ex ring uplv skillBook")
	--设置数据
	sbdata.info[pos].lv = newLv
	--重新计算玩家属性
	calcAttr(actor, true)
	if sbCfg.summonerAttr or sbCfg.summonerExAttr or sbCfg.summonerSkillLvAdd then
		RefreshMonsterAllData(actor, nil, idx)
	end
	--同步技能书信息到客户端
	sendActorExRingSkillBookData(actor, idx)
end

--检测是否能使用道具
function canUseItem(actor, idx, id)
	--获取配置
	local ExRingCfg = config[idx]
	if not ExRingCfg then
		print(LActor.getActorId(actor).." actorexring.canUseItem idx("..idx..") not config")
		return false
	end
	--判断道具能力配置
	if not ActorExRingItemConfig[idx] or not ActorExRingItemConfig[idx][id] then
		return false
	end
	--获取特戒等级
	local level = LActor.getActorExRingLevel(actor, idx)
	if level <= 0 then
		print(LActor.getActorId(actor).." actorexring.canUseItem idx("..idx..") not activation")
		return false
	end
	--获取静态变量
	local SVar = getVarData(actor)
	if (SVar.useItem and SVar.useItem[idx] and SVar.useItem[idx][id] or 0) >= #(ActorExRingItemConfig[idx][id]) then
		print(LActor.getActorId(actor).." actorexring.canUseItem idx("..idx.."),id("..id..") is lv max")
		return false
	end
	return true
end

--使用增强道具
function onUseItem(actor, idx, id)
	--获取静态变量
	local SVar = getVarData(actor)
	if not SVar.useItem then SVar.useItem = {} end
	if not SVar.useItem[idx] then SVar.useItem[idx] = {} end
	SVar.useItem[idx][id] = (SVar.useItem[idx][id] or 0) + 1 --标记使用了这个道具能力
	--重新计算玩家属性
	calcAttr(actor, true)
	--下发道具使用信息
	sendItemUseData(actor)
end

--给遭遇战等玩家附加特戒的数据(技能书,使用道具)
local function CloneExRingData(actor, npack)
	local idx = ActorExRingType_HuoYanRing
	local SVar = getVarData(actor)
	--技能书
	local count = SVar.skillBook and SVar.skillBook[idx] and SVar.skillBook[idx].info and #(SVar.skillBook[idx].info) or 0
	LDataPack.writeShort(npack, count)
	for i=1,count do
		local info_data = SVar.skillBook[idx].info[i]
		LDataPack.writeShort(npack, info_data.index) --位置
		LDataPack.writeShort(npack, info_data.sbid) --技能书ID
		LDataPack.writeShort(npack, info_data.lv) --等级
	end
	--使用的道具能力
	local count = 0 --先写0
	local pos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, count)
	--获取特戒道具能力配置
	local cfg = ActorExRingItemConfig[idx]
	if cfg then 
		--没有使用过这样的道具
		if SVar.useItem and SVar.useItem[idx] then
			for id,_ in pairs(cfg) do
				if SVar.useItem[idx][id] then
					LDataPack.writeShort(npack, id)
					LDataPack.writeShort(npack, SVar.useItem[idx][id])
					count = count + 1
				end
			end
			--重新写长度
			local pos2 = LDataPack.getPosition(npack)
			LDataPack.setPosition(npack, pos)
			LDataPack.writeShort(npack, count)
			LDataPack.setPosition(npack, pos2)
		end
	end
	flamestamp.CloneData(actor, npack)
end
_G.CloneExRingData = CloneExRingData

--系统初始化函数
local function init()
	--注册玩家事件
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeUserLogin, onLogin)
	--注册消息
	netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_UnlockActorRing, onReqUnlock) --解锁特戒
	netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_ActActorRing, onReqAct) --激活特戒
	netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_UpgradeActorRing, onReqUpgrade) --升级特戒
	netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_AdvancedActorRing, onReqAdvanced) --进阶特戒
	netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_OutOrInActorRing, onReqOutOrIn) --请求出战or收回特戒
	netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_OpenSkillGrid, onReqOpenSkillGrid) --请求开启技能书格仔
	netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_InsertSkillBook, onReqInsertSkillBook) --请求镶嵌技能书
	netmsgdispatcher.reg(Protocol.CMD_ExRing, Protocol.cExRingCmd_LvUpSkillBook, onReqLvUpSkillBook) --请求升级技能书
end
table.insert(InitFnTable, init)

--aexring
function gmhandle(actor, arg)
	local param = arg[1]
    if param == nil then
        return
    end
    if param == 'oc' then
		OutOrIn(actor, tonumber(arg[2]), tonumber(arg[3]))
	elseif param == 'slv' then
		LActor.setActorExRingLevel(actor, tonumber(arg[2]), tonumber(arg[3]))
	elseif param == 'clear' then
		local var = LActor.getStaticVar(actor)
		var.actorExRingData = nil
		for k,_ in pairs(config) do
			LActor.setActorExRingLevel(actor, k, 0)	
			LActor.SetActorExRingIsEff(actor, k, 0)
			LActor.DestroyBattleRing(actor, k)
		end
	elseif param == 'rsf' then
		local module_name = "systems.actorsystem.actorexring.actorexring"
		package.loaded[module_name] = nil
		require (module_name)
	else
		return
    end
end
