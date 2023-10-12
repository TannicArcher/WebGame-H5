--奖励发放接口
module("actorawards", package.seeall)


function giveAwardBase(actor, type, id, count, log, ...)
	--print("---giveAwardBase type:"..type.." id:"..id.." count:"..count)
	if actor == nil  then return end
	if log == nil then print( LActor.getActorId(actor) .. " giveAwardBase: log in nil " .. type .. " " .. id .. " " .. count ) return end
	if type == AwardType_Numeric then
		if not count then return end
		if id == NumericType_Achieve then
			knighthood.updateknighthoodData(actor,count)
		else
        	LActor.changeCurrency(actor, id, count, log)
        end
	elseif type == AwardType_Item then
		LActor.giveItem(actor, id, count, log)
	end
	print( LActor.getActorId(actor) .. " giveAwardBase: ok " .. type .. " " .. id .. " " .. count )
end

function giveAwardEx(actor, reward, log, ...)
	local type = reward.type or 0
	local id = reward.id or 0
	local count = reward.count or 1
	local job = reward.job or 0
	if job ~= 0 then
		local actor_job = LActor.getJob(actor)
		if job ~= actor_job then return end
	end
	giveAwardBase(actor, type, id, count, log, ...)
end

function giveAward(actor, reward, ...)
	if type(reward) == "table" then
		giveAwardEx(actor, reward, ...)
	else
		giveAwardBase(actor, reward, ...)
	end
end

function giveAwards(actor,rewards, ...)
	for _,reward in ipairs(rewards) do
		giveAward(actor, reward, ...)
	end
end

function awardsNeedCount(rewards, job)
	local count = 0
	for _, reward in ipairs(rewards) do
		if (reward.type or 0) == AwardType_Item and (not reward.job or reward.job == job) then
			local itemConf = ItemConfig[reward.id or 0]
			if itemConf and item.isEquip(itemConf) then
				count = count + 1
			end
		end
	end
	return count
end

function canGiveAwards(actor, rewards)
	local count = awardsNeedCount(rewards, LActor.getJob(actor))
	if LActor.getEquipBagSpace(actor) < count then
		return false
	else
		return true
	end
end

function changeCurrency(actor, type, value, log)
	if type == NumericType_GuildContrib then -- 公会贡献
		guildcommon.changeContrib(actor, value, log)
	elseif type == NumericType_GuildFund then -- 公会资金
		local guild = LActor.getGuildPtr(actor)
		if guild == nil then return end
		guildcommon.changeGuildFund(guild, value, actor, log)
	elseif type == NumericType_GodWeaponExp then	--神兵经验
		godweaponbase.addGodWeaponExp(actor, value, log)
	elseif type == NumericType_Chips then
		peakracesystem.changeChips(actor, value, log)
	elseif type == NumericType_ShenShouExp then
		shenshousystem.changeShenShouExp(actor, value, log)
	end
end

function getCurrency(actor, type)
	if type == NumericType_Chips then -- 筹码
		return peakracesystem.getChips(actor)
	end
end

--根据玩家职业筛选奖励
function chooseRewardByFirstJob(actor, reward)
	--获取创角职业
   	local actor_job = LActor.getJob(actor)

    local tItemList = {}
    for _, tb in pairs(reward or {}) do
    	local job = tb.job or 0
    	if 0 == job or job == actor_job then table.insert(tItemList, tb) end
    end

    return tItemList
end

--合并奖励
function mergeRewrd(award, reward, job)
	for k, v in pairs(reward or {}) do
		local isFind = false
		for _, data in pairs(award or {}) do
			if data.id == v.id and data.type == v.type then
				data.count = data.count + v.count
				isFind = true
				break
			end
		end

		if not isFind and (job or 0) == (v.job or 0) then
			award = award or {}
			local index = #award+1
			award[index] = {}
			award[index].type = v.type
			award[index].id = v.id
			award[index].count = v.count
		end
	end
end

--奖励翻倍
local function getRewardByTimes(rewards, times)
	local reward = {}
	if 0 >= times then return reward end
	for k, v in pairs(rewards or {}) do
		table.insert(reward, {id=v.id, type=v.type, count=v.count * times})
	end

	return reward
end

--获取指定类型和id的物品数量
local function getCountByType(rewards, conf)
	if not conf then return 0 end
	local count = 0
	for k, v in pairs(rewards or {}) do
		if (conf.type or 0) == v.type and (conf.id or 0) == v.id then count = count + v.count end
	end

	return count
end

_G.changeCurrency = changeCurrency
_G.getCurrency = getCurrency

--参数： actor, {type=0,id=0,count=0}, log
--  或  actor, type, id, count, log
LActor.giveAward = giveAward
--args: actor, {{type,id,count},{},{}}， log
LActor.giveAwards = giveAwards
LActor.canGiveAwards = canGiveAwards
LActor.chooseRewardByFirstJob = chooseRewardByFirstJob
LActor.mergeRewrd = mergeRewrd
LActor.getRewardByTimes = getRewardByTimes
LActor.getCountByType = getCountByType

function gmTestReward(actor)
	
end
