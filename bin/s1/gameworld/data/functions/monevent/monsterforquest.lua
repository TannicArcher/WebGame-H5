module("monevent.monsterforquest", package.seeall)
setfenv(1, monevent.monsterforquest)

local monevent = require("monevent.monevent")

require("quest.questmonsterconf")
local KillMonsterQuest = KillMonsterQuest
local MonsterForQuest = MonsterForQuest

-- 杀死某种怪物就完成的任务
local function MonsterQuestFunc(monster, actor, monId)
	if actor == nil then return end

	local quests = KillMonsterQuest[monId]
	if quests == nil then return end

	for _, quest in ipairs(quests) do
		LActor.setQuestValue(actor, quest.qid, quest.tid, quest.count)
	end
end

local function QuestDieFunc(monster, actor, monId)
	local actorList = LuaHelp.getVisiActorList(monster)
	if actorList == nil then return end
	local questlist = MonsterForQuest[monId]
	if questlist == nil then return end

	for i=1,#actorList do
		for j=1,#questlist do
			LActor.addQuestValue(actorList[i], questlist[j], monId, 1)
		end
	end
end

local function initMonsterQuest()
	-- 杀死某种怪物就完成的任务
	for k,v in pairs(KillMonsterQuest) do
		for j = 1, #v do
			monevent.regDieEvent(k, MonsterQuestFunc)
		end
	end

	for k,v in pairs(MonsterForQuest) do
		for j = 1, #v do
			monevent.regDieEvent(k, QuestDieFunc)
		end
	end
end

table.insert(InitFnTable, initMonsterQuest)
