module("item", package.seeall)

use_item_error_code = 
{
	not_error          = 0,
	use_succeed        = 0, -- 使用成功
	bag_full           = 1, -- 背包满了
	not_use            = 3, -- 不能被使用
	insufficient_level = 4, -- 级别不足
	lazy_weight        = 5, -- 数量不足够
	yuanbao_less       = 6, -- 元宝不足
	conf_nil	       = 7, -- 不存在配置
}



function isEquip(cfg)
	if not cfg then return false end
	return (cfg.type == ItemType_Equip) or (cfg.type == ItemType_WingEquip) or (cfg.type == ItemType_TogetherHit)
end


--- check func

local function checkDefault(actor,item_id,count)
	local conf = ItemConfig[item_id]
	local needLevel = (conf.zsLevel * 1000) + conf.level
	local level = (LActor.getZhuanShengLevel(actor) * 1000) + LActor.getLevel(actor)
	if level < needLevel then 
		print(LActor.getActorId(actor) .. "checkDefault: insufficient_leve " .. item_id)
		return use_item_error_code.insufficient_level
	end
	if not LActor.checkItemNum(actor,item_id,count,false) then 
		print(LActor.getActorId(actor) .. "checkDefault: lazy_weight " .. item_id )
		return use_item_error_code.lazy_weight
	end

	if conf.needyuanbao and conf.needyuanbao > 0 then
		local curYuanBao = LActor.getCurrency(actor, NumericType_YuanBao)
		if curYuanBao < conf.needyuanbao * count then
			print(LActor.getActorId(actor) .. "checkDefault: yuanbao_less " .. item_id)
			return use_item_error_code.yuanbao_less
		end
	end
	print(LActor.getActorId(actor) .. "checkDefault: ok " .. item_id)
	return use_item_error_code.not_error
end

local function checkUseCrateDrops(actor,item_id,count)
	local conf = ItemConfig[item_id]
	local ret = checkDefault(actor,item_id,count)
	if ret ~= use_item_error_code.not_error then 
		return ret
	end
	local args = conf.useArg
	if not args then
		print(LActor.getActorId(actor) .. "checkUseCrateDrops: config err " .. item_id)
		return use_item_error_code.not_use
	end
	if args.needGuild and args.needGuild == 1 and LActor.getGuildId(actor) == 0 then
		print(LActor.getActorId(actor) .. "checkUseCrateDrops: not have guild " .. item_id)
		return use_item_error_code.not_use
	end
	local useGrid = args.useGrid * count
	if useGrid ~= 0 and LActor.getEquipBagSpace(actor) < useGrid then
		print(LActor.getActorId(actor) .. "checkUseCrateDrops: bag_full " .. item_id)
		return use_item_error_code.bag_full
	end
	if conf.useCond then
		if not activitysystem.activityTimeIsEnd(conf.useCond) then
			print(LActor.getActorId(actor) .. "checkUseCrateDrops: act:"..conf.useCond.." not Over " .. item_id)
			return use_item_error_code.not_use
		end
	end
	print(LActor.getActorId(actor) .. "checkUseCrateDrops: ok " .. item_id)
	return use_item_error_code.not_error
end

local function checkOptionalGift(actor,item_id,count,...)
	local ret = checkDefault(actor,item_id,count)
	if ret ~= use_item_error_code.not_error then
		return ret
	end

	local opconf = OptionalGiftConfig[item_id]
	if not opconf then
		return use_item_error_code.conf_nil
	end

	local index = arg[1]
	if not index or opconf.options[index] == nil then
		return use_item_error_code.conf_nil
	end

	if LActor.getZhuanShengLevel(actor) < opconf.options[index].zslimit then
		return use_item_error_code.insufficient_level
	end

	if LActor.getLevel(actor) < opconf.options[index].level then
		return use_item_error_code.insufficient_level
	end

	if LActor.getEquipBagSpace(actor) < opconf.options[index].useGrid then
		print(LActor.getActorId(actor) .. "checkOptionalGift: bag_full " .. item_id)
		return use_item_error_code.bag_full
	end

	print(LActor.getActorId(actor) .. "checkOptionalGift: ok " .. item_id)
	return use_item_error_code.not_error
end


---- use func
local function useDefault(actor,item_id,count)
	local conf = ItemConfig[item_id]
	if conf.needyuanbao and conf.needyuanbao > 0 then
		LActor.changeCurrency(actor, NumericType_YuanBao, -conf.needyuanbao * count, "use yuanbao item "..item_id)
		LActor.consumeItem(actor, item_id, count, false, "use yuanbao item " .. conf.needyuanbao)
	else
		LActor.consumeItem(actor, item_id, count, false,"use item")
	end
	print(LActor.getActorId(actor) .. "useDefault: ok " .. item_id)
	return use_item_error_code.use_succeed
end

local function useCrateDrops(actor,item_id,count)
	local ret = useDefault(actor,item_id,count) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	local conf = ItemConfig[item_id]
	local args = conf.useArg
	local logstr = "use item"
	if conf.needyuanbao and conf.needyuanbao > 0 then
		logstr = "use yuanbao item " .. item_id
	end

	local i = 0
	while (i < count) do 
		local rewards = drop.dropGroup(args.dropId)
		LActor.giveAwards(actor, rewards, logstr)
		if args.noticeId then
			for _,v in ipairs(rewards) do
				if v.type == 1 and ItemConfig[v.id] and ItemConfig[v.id].needNotice == 1 then
	        	local itemName = getItemDisplayName(v.id)
	            noticemanager.broadCastNotice(args.noticeId, LActor.getName(actor), conf.name, itemName)
	        end
    	end
    	end
		i = i + 1
	end
	return use_item_error_code.use_succeed
end

local function useTitle(actor,item_id,count)
	local ret = useDefault(actor,item_id,count) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	local conf = ItemConfig[item_id]
	local args = conf.useArg
	titlesystem.addTitle(actor,args)
	return use_item_error_code.use_succeed
end

local function useGetTuJianExp(actor, item_id, count)
	local ret = useDefault(actor,item_id,count) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	local conf = ItemConfig[item_id]
	local add_count = tonumber(conf.useArg) * count
	tujiansystem.AddExp(actor, add_count)
	return use_item_error_code.use_succeed
end

local function useLevelUp(actor, item_id, count)
	local ret = useDefault(actor,item_id,count) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	local conf = ItemConfig[item_id]
	local useArg = conf.useArg
	for i=1,count do
		local level = LActor.getLevel(actor)
		if level < useArg.maxLv and level < #ExpConfig then
			actorexp.confirmExp(actor, level+1, LActor.getExp(actor), 0)
			actorexp.onLevelUp(actor, level+1)
		else
			LActor.addExp(actor, useArg.exp or 0, "use item:"..item_id)
		end
	end
	return use_item_error_code.use_succeed
end

local function useAddBossCount(actor, item_id, count)
	local conf = ItemConfig[item_id]
	local useArg = conf.useArg
	local num = worldboss.GetDailyCount(actor, useArg.type)
	if num <= 0 then return use_item_error_code.not_use end
	local canUseCount = math.ceil(num/useArg.count)
	canUseCount = math.min(canUseCount, count)
	local ret = useDefault(actor,item_id, canUseCount) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	local freeNum = canUseCount * useArg.count
	if num > freeNum then 
		worldboss.SetDailyCount(actor, useArg.type, num - freeNum)
	else
		worldboss.SetDailyCount(actor, useArg.type, 0)
	end
	return use_item_error_code.use_succeed
end

local function useAddGodWeaponCount(actor, item_id, count)
	local conf = ItemConfig[item_id]
	local useArg = conf.useArg
	local num = godweaponfuben.getLeftEnterCount(actor) --获得剩余次数
	if num > 0 then return use_item_error_code.not_use end
	--扣除道具
	local ret = useDefault(actor,item_id, count) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	--增加次数
	godweaponfuben.SetItemCount(actor, useArg.count * count)
	return use_item_error_code.use_succeed
end

local function useAddZhuanShengExp(actor, item_id, count)
	local conf = ItemConfig[item_id]
	local useArg = conf.useArg
	local ret = useDefault(actor,item_id, count) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	local addexp = useArg.exp * count
	actorzhuansheng.addExp(actor, addexp)
	return use_item_error_code.use_succeed
end

-- 无限制轮回丹，增加轮回经验
local function useAddReincarnateExp( actor, item_id, count )
	local conf = ItemConfig[item_id]
	local useArg = conf.useArg
	local ret = useDefault(actor,item_id, count) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	local addexp = useArg.exp * count
	actorreincarnate.addExp(actor, addexp)
	return use_item_error_code.use_succeed
end

local function useAddActorExRingFbCount(actor, item_id, count)
	--是否开启了烈焰戒指
	if 0 >= LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing) then 
		return use_item_error_code.not_use
	end
	local conf = ItemConfig[item_id]
	local useArg = conf.useArg
	local num = actorexringfuben.getChallengeCount(actor) --获得剩余次数
	if num > 0 then return use_item_error_code.not_use end
	--扣除道具
	local ret = useDefault(actor,item_id, count) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	--增加次数
	actorexringfuben.SetItemCount(actor, useArg.count * count)
	return use_item_error_code.use_succeed
end

local function useUseOptionalGift(actor, item_id, count, ...)
	local conf = ItemConfig[item_id]
	if conf.needyuanbao and conf.needyuanbao > 0 then
		LActor.changeCurrency(actor, NumericType_YuanBao, -conf.needyuanbao * count, "optionalgift.use "..item_id)
	end
	LActor.consumeItem(actor, item_id, count, false, "optionalgift.use")

	local opconf = OptionalGiftConfig[item_id]
	local index = arg[1]
	local itemid,itemcount = opconf.options[index].itemid,opconf.options[index].itemcount
	LActor.giveAward(actor, AwardType_Item, itemid, itemcount * count, "optionalgift.use")

	return use_item_error_code.use_succeed
end

local function useActorExRingItem(actor, item_id, count)
	local conf = ItemConfig[item_id]
	local useArg = conf.useArg
	if not actorexring.canUseItem(actor, useArg.rid, useArg.id) then
		return use_item_error_code.not_use
	end
	--扣除道具
	local ret = useDefault(actor,item_id, 1) 
	if ret ~= use_item_error_code.use_succeed then 
		return ret
	end
	--使用效果
	if not actorexring.onUseItem(actor, useArg.rid, useArg.id) then
		return use_item_error_code.conf_nil
	end
	return use_item_error_code.use_succeed
end

use_item_func = 
{
	[1] = useCrateDrops,
	[2] = useTitle,
	[3] = useGetTuJianExp,--图鉴经验
	[4] = useLevelUp,--直升一级丹
	[5] = useAddBossCount, --增加世界boss次数
	[6] = useAddZhuanShengExp,--增加转生修为
	[7] = useUseOptionalGift,--使用选择礼包
	[8] = useAddGodWeaponCount, --增加神兵副本进入次数
	[9] = useAddActorExRingFbCount, --增加烈焰戒指副本进入次数
	[10] = useActorExRingItem,--使用增强玩家特戒道具
	[11] = nil,
	[12] = useAddReincarnateExp, -- 使用无限制轮回丹，增加轮回经验
}
check_use_item_func = 
{
	[1] = checkUseCrateDrops, -- 宝箱
	[2] = checkDefault,
	[3] = checkDefault,
	[4] = checkDefault,
	[5] = checkDefault,
	[6] = checkDefault,
	[7] = checkOptionalGift,--使用选择礼包
	[8] = checkDefault,
	[9] = checkDefault,
	[10] = checkDefault,
	[11] = checkDefault,
	[12] = checkDefault,
}








local function useItem(actor,item_id,count,...)
	local conf = ItemConfig[item_id]
	if conf == nil then 
		-- print("useItem not config " .. item_id)
		return use_item_error_code.not_use
	end
	if count == nil or type(count) ~= "number" or count <= 0 then
		print("use item invalid count:"..tostring(count).." aid:"..LActor.getActorId(actor))
		count = 1
	end
	local check_func = check_use_item_func[conf.useType]

	if check_func == nil then 
		-- print("useItem not check func " .. conf.useType)
		print(LActor.getActorId(actor) .. "useItem: not has check func " .. conf.useType .. " " .. item_id)
		return use_item_error_code.not_use
	end
	local ret = check_func(actor,item_id,count,...)
	if ret ~= use_item_error_code.not_error then 
		return ret
	end
	local use_func = use_item_func[conf.useType] 
	if use_func == nil then 
		-- print("useItem not use func " .. conf.useType)
		print(LActor.getActorId(actor) .. "useItem: not has use func " .. conf.useType " " .. item_id)
		return use_item_error_code.not_use
	end
	-- print("use item " .. item_id .. " " .. count)
	return use_func(actor,item_id,count,...)
end


local function onUseItem(actor,packet)
	local item_id = LDataPack.readInt(packet)
	local count   = LDataPack.readInt(packet)
	local ret     = useItem(actor,item_id,count)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_UseItem)
	if npack == nil then 
		return 
	end
	LDataPack.writeByte(npack,ret)
	LDataPack.flush(npack)
end

local function compostItem(actor,srcItemId,srcItemCount)
	local conf = ItemComposeConfig[srcItemId]
	if conf == nil then return end
	if conf.srcItemId == nil or conf.srcCount == nil then return end

	local num = math.floor(srcItemCount / conf.srcCount)
	if num <= 0 then return end
	
	local rewards = {}
	for _,v in pairs(conf.rewards) do
		table.insert(rewards,{type=v.type,id=v.id,count=v.count*num})
	end

	local consumtCount = num * conf.srcCount
	if not LActor.canGiveAwards(actor, rewards) then return end
	if not LActor.consumeItem(actor,srcItemId,consumtCount,false,"item_consume_compostItem") then return end
	LActor.giveAwards(actor, rewards, "item_give_compostItem")



	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_ComposeItem)
	if npack == nil then return end
	--LDataPack.writeByte(npack,1)
	LDataPack.writeInt(npack,srcItemId)
	LDataPack.writeInt(npack,consumtCount)
	LDataPack.writeInt(npack,#rewards)
	for i=1,#rewards do
		LDataPack.writeInt(npack,rewards[i].type)
		LDataPack.writeInt(npack,rewards[i].id)
		LDataPack.writeInt(npack,rewards[i].count)
	end
	LDataPack.flush(npack)
	return true
end

local function onComposeItem(actor,packet)
	local srcItemId = LDataPack.readInt(packet)
	local srcItemCount = LDataPack.readInt(packet)
	local ret = compostItem(actor,srcItemId,srcItemCount)
	if ret == true then return end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_ComposeItem)
	if npack == nil then return end
	LDataPack.writeByte(npack,0)
	LDataPack.flush(npack)
end

local function onUseOptionalGift(actor,packet)
	local item_id = LDataPack.readInt(packet)
	local count   = LDataPack.readInt(packet)
	local index   = LDataPack.readInt(packet)
	local ret     = useItem(actor,item_id,count,index)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Bag, Protocol.sBagCmd_UseOptionalGift)

	LDataPack.writeByte(npack,ret)
	LDataPack.flush(npack)
end

netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_UseItem, onUseItem)
netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_ComposeItem, onComposeItem)
netmsgdispatcher.reg(Protocol.CMD_Bag, Protocol.cBagCmd_UseOptionalGift, onUseOptionalGift)

----------------------------------------------------------------------------------------------------------
--获取物品公告名
function getItemDisplayName(id)
    local conf = ItemConfig[id]
    if conf == nil then return nil end

    local name = conf.name
	if (conf.type or 0) ~= 0 then
		return name
	end
    if (conf.zsLevel or 0) > 0 then
        return name .. string.format("(%d%s)", conf.zsLevel, LAN.SYS.dwZhuan)
    else
        return name .. string.format("(%d%s)", conf.level or 0, LAN.SYS.dwJi)
    end
end
