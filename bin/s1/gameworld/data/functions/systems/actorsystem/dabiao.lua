module("dabiao", package.seeall)

function sendRankingReward(id, rankType, conf)
	LActor.updateRanking()
	local var = LActor.getRankDataByType(rankType)
	if var == nil then return end

	print("start send dabiao mail rankType:"..rankType)
	local ranking_conf = conf
	for i, v in pairs(ranking_conf) do
		if var[v.ranking] ~= nil then
			local basic_data = toActorBasicData(var[i])
			local mail_data = {}
			mail_data.head = v.head
			mail_data.context = string.format(v.context, i)
			mail_data.tAwardList = v.rewards
			mailsystem.sendMailById(basic_data.actor_id, mail_data)
			print(id .. ":" .. rankType .. ":" .. " send dabiao ranking mail " .. basic_data.actor_id)
			--公告广播
			if v.notice then
				noticemanager.broadCastNotice(v.notice, basic_data.actor_name)
			end
		end
	end
end

function isDaBiao(actor, id, rankType, conf, index)
	local arr = conf[0].value
	if not arr or index > #arr then 
		return false
	end

	local cmp = 0
	local basic_data = LActor.getActorData(actor)
	if rankType == RankingType_Power then
		cmp = basic_data.total_power 
	elseif rankType == RankingType_Wing then
		cmp = basic_data.total_wing_power 
	elseif rankType == RankingType_Warrior then
		cmp = basic_data.warrior_power 
	elseif rankType == RankingType_Mage then
		cmp = basic_data.mage_power  
	elseif rankType == RankingType_Taoistpriest then
		cmp = basic_data.taoistpriest_power 
	elseif rankType == RankingType_Level then
		cmp = basic_data.level + (basic_data.zhuansheng_lv * 1000)
	elseif rankType == RankingType_Stone then 
		cmp = basic_data.total_stone_level  
	elseif rankType == RankingType_ZhanLing then
		--以后要用到这里得改，比如这样子:
		--cmp = zhanlingsystem.getZhanLingLevel(actor)
		cmp = (basic_data.zhan_ling_stage * 1000) + basic_data.zhan_ling_star
		if not zhanlingcommon.isOpenZhanLing(actor) then 
			return false
		end
	elseif rankType == RankingType_LoongSoul then
		cmp = basic_data.total_loongsoul_level
	elseif rankType == RankingType_ConsumeYB then
		local record = activitysystem.getSubVar(actor, id)
		cmp = record.data.useyuanbao or 0
	else 
		return false
	end

	if cmp >= arr[index].value then 
		return true
	end
end

local function senDaBiaoData(actor,id)
	local conf = ActivityType4Config[id]
	if conf == nil then 
		print("not has conf " .. id)
		return false
	end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_Activity,Protocol.sActivityCmd_SendDaBiaoData)
	if npack == nil then 
		return
	end
end 

function sendDaBiaoData(npack, actor, id, rankType, conf, index)
	local basic_data = LActor.getActorData(actor)
	if rankType == RankingType_Power then
		LDataPack.writeDouble(npack, basic_data.total_power)
	elseif rankType == RankingType_Wing then 
		LDataPack.writeDouble(npack, basic_data.total_wing_power)
	elseif rankType == RankingType_Warrior then 
		LDataPack.writeDouble(npack, basic_data.warrior_power)
	elseif rankType == RankingType_Mage then 
		LDataPack.writeDouble(npack, basic_data.mage_power)
	elseif rankType == RankingType_Taoistpriest then 
		LDataPack.writeDouble(npack, basic_data.taoistpriest_power)
	elseif rankType == RankingType_Level then 
		LDataPack.writeInt(npack, basic_data.level)
		LDataPack.writeInt(npack, basic_data.zhuansheng_lv)
	elseif rankType == RankingType_Stone then 
		LDataPack.writeInt(npack, basic_data.total_stone_level)
	elseif rankType == RankingType_ZhanLing then 
		--以后要用到这里得改
		LDataPack.writeInt(npack, basic_data.zhan_ling_stage)
		LDataPack.writeInt(npack, basic_data.zhan_ling_star)
	elseif rankType == RankingType_LoongSoul then 
		LDataPack.writeInt(npack, basic_data.total_loongsoul_level)
	elseif rankType == RankingType_Zhuling then
		LDataPack.writeInt(npack, basic_data.total_zhuling_level)
	end
	local cache = LActor.getRankCacheByType(rankType, 0, 20)

	if cache == nil then
		LDataPack.writeShort(npack, 0)
	else
		LDataPack.writePacket(npack, cache)
	end
end
