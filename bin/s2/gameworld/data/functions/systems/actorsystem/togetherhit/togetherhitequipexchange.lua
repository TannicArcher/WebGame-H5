module("togetherhitequipexchange", package.seeall)
--合击装备兑换

--计算齐鸣套装属性
local function togetherHitQmAttr(actor, isEquip, count, ...)
	local attr = LActor.getTogetherHitAttr(actor)
	if attr == nil then return end
	local ex_attr = LActor.getTogetherHitExAttr(actor)
	if ex_attr == nil then return end
	local zs_lv_num = {}
	for i = 1,count do
		local num = math.floor(arg[i] / 10000000)
		local zslv = math.floor((arg[i] % 10000000) / 10000)
		local level = arg[i] % 10000
		table.insert(zs_lv_num, {zs=zslv, lv=level, num=num})
	end
	--向下累加
	local tmp = utils.table_clone(zs_lv_num)
	for _,v in ipairs(tmp) do
		for _,val in ipairs(zs_lv_num) do 
			if v.zs > val.zs then
				val.num = val.num + v.num
			elseif v.zs == val.zs and v.lv > val.lv then
				val.num = val.num + v.num
			end
		end
	end
	--加属性
	for zslv,zcfg in pairs(TogetherHitEquipQmConfig) do --转生等级层
		for lv,lcfg in pairs(zcfg) do --等级层
			for num,cfg in pairs(lcfg) do --数量层
				--循环所有已经存在的装备数据
				for _,val in ipairs(zs_lv_num) do
					--转生等级比现有的小,或者, 等级比现有的小
					if zslv <= val.zs or (zslv == val.zs and lv <= val.lv) then
						if num <= val.num then --数量满足
							--加属性
							for k,v in ipairs(cfg.attr or {}) do
								attr:Add(v.type, v.value)
							end
							for k,v in ipairs(cfg.exAttr or {}) do
								ex_attr:Add(v.type, v.value)
							end

							if isEquip and cfg.noticeId then
								togetherhit.broadcastNotice(actor, val.zs, val.lv, cfg.noticeId)
							end

							--print("togetherHitQmAttr:zslv="..zslv..", lv="..lv..", num="..num)
							break --这个配置项已经满足
						end
					end
				end
				--end 循环所有已经存在的装备数据
			end
		end
	end
	--加属性结束
end

_G.togetherHitQmAttr = togetherHitQmAttr

--请求装备兑换
local function reqEquipExchange(actor, packet)
	local idx = LDataPack.readShort(packet) --兑换ID
	--获取对应项的配置
	local ExchangeCfg = TogetherHitEquipExchangeConfig[idx]
	if not ExchangeCfg then
		print("TogetherHitEquipExchange: reqEquipExchange id("..idx..") is not have config")
		return
	end
	--[[检测消耗
	local consumeTable = {} --所需要的消耗
	local haveCount = 0 --已经有了的数量
	for k,v in ipairs(ExchangeCfg.exchangeMaterial) do
		local needCount = ExchangeCfg.exchangeAmount - haveCount --还需要的数量
		local count = LActor.getItemCount(actor, v)
		local useCount = count --使用数量
		if count > needCount then
			useCount = needCount
		end
		--放入消耗表
		if useCount > 0 then
			table.insert(consumeTable, {item=v,count=useCount})
			haveCount = haveCount + useCount
		end
		--已经够了
		if haveCount >= ExchangeCfg.exchangeAmount then
			break
		end
	end
	--兑换材料不足
	if haveCount < ExchangeCfg.exchangeAmount then
		print("TogetherHitEquipExchange: reqEquipExchange id("..tostring(idx)..") consume is insufficient")
		return
	end
	--扣除消耗
	for k,v in ipairs(consumeTable) do
		LActor.costItem(actor, v.item, v.count, "together hit equip exchange")
	end]]
	--消耗
	for _, v in pairs(ExchangeCfg.exchangeMaterial) do
		local ret = true
		if v.type == AwardType_Numeric then
			local count = LActor.getCurrency(actor, v.id)
			if count < v.count then
				ret = false
			end			
		elseif v.type == AwardType_Item then
			local count = LActor.getItemCount(actor, v.id)
			if count < v.count then
				ret = false
			end
		else
			ret = false
		end
		if ret == false then 
			print(LActor.getActorId(actor).." TogetherHitEquipExchange: reqEquipExchange idx("..idx.."),type="..(v.type)..",id="..(v.id).." consume is insufficient")
			return
		end
	end
	--扣除消耗
	for _, v in pairs(ExchangeCfg.exchangeMaterial) do
		if v.type == AwardType_Numeric then
			LActor.changeCurrency(actor, v.id, -v.count, "together hit equip exchange")
		elseif v.type == AwardType_Item then
			LActor.costItem(actor, v.id, v.count, "together hit equip exchange")
		end
	end
	--获取道具
	local awards = {ExchangeCfg.getItem}
	if LActor.canGiveAwards(actor, awards) == false then
		print(LActor.getActorId(actor).." TogetherHitEquipExchange: reqEquipExchange id("..idx..") can not give awards")
		return
	end
	--获得奖励
	LActor.giveAwards(actor, awards, "together hit equip exchange")
end

--请求高级碎片替换低级碎片
local function reqTogeatterExchange(actor, packet)
	local count = LDataPack.readInt(packet)
	if not count or count <= 0 then
		return
	end
	if not TogerherHitBaseConfig.TogExgRate then
		print(LActor.getActorId(actor).." TogetherHitEquipExchange.reqTogeatterExchange not TogExgRate cfg")
		return
	end
	--扣除高级碎片
	local haveCount = LActor.getCurrency(actor, NumericType_TogeatterHigh)
	if haveCount < count then
		print(LActor.getActorId(actor).." TogetherHitEquipExchange.reqTogeatterExchange haveCount("..haveCount..") < count("..count..")")
		return
	end
	LActor.changeCurrency(actor, NumericType_TogeatterHigh, -count, "TogeatterExchange")
	--获得低级碎片
	LActor.changeCurrency(actor, NumericType_Togeatter, count*TogerherHitBaseConfig.TogExgRate, "TogeatterExchange")
end

local function init()
	netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_TogetherHitEquipExchange, reqEquipExchange)
	netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_TogeatterExchange, reqTogeatterExchange)
end

table.insert(InitFnTable, init)
