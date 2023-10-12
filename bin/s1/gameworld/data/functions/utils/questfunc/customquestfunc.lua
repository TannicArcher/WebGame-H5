module("utils.questfunc.customquestfunc", package.seeall)
setfenv(1, utils.questfunc.customquestfunc)

local actorevent = require("actorevent.actorevent")
local questsys = require("systems.questsystem.questsystem")
require("quest.customquestconf")
local KillOtherGuildQuest = KillOtherGuildQuest
local EnterFbQuest = EnterFbQuest
local FinishFbQuest = FinishFbQuest
local FbStepQuest = FbStepQuest
local EquipCount = EquipCount

-- 自定义任务相关操作函数
-- 检查能否完成任务
function checkQuest(actor, conf)
	if conf then
		for _, info in ipairs(conf) do
			LActor.addQuestValue(actor, info.qid, info.tid, info.count)
		end
	end
end

function checkFbStepQuest(actor, fbid, step)
	if not FuBen[fbid] then return end
	
	fbid = FuBen[fbid].publicFbid or fbid
	if not FbStepQuest or not FbStepQuest[fbid] then return end

	local conf = FbStepQuest[fbid]

	for _, info in ipairs(conf) do
		if step >= info.step then
			LActor.addQuestValue(actor, info.qid, fbid, info.count)
		end
	end
end

function killByOtherGuild(actor, killer)
	if not actor or not killer or not LActor.isActor(killer) or not LActor.isActor(killer) then return end

	local actorGid = LActor.getGuildId(actor)
	local killerGid = LActor.getGuildId(killer)

	if killerGid == 0 or actorGid ~= killerGid then
		checkQuest(killer, KillOtherGuildQuest)
	end
end

function onEnterFuben(actor, fbid)
	fbid = FuBen[fbid].publicFbid or fbid
	checkQuest(actor, EnterFbQuest[fbid])
end

function checkRoutineQuest(actor)
	if not actor or not FinishRoutineQuest then return end

	for _, info in ipairs(FinishRoutineQuest) do
		LActor.addQuestValue(actor, info.qid, info.tid, info.count)
	end
end

function addEquipCount(actor, itemid)
	if not actor then return end

	changeEquipCount(actor, itemid, true)
end
function delEquipCount(actor, itemid)
	if not actor then return end

	changeEquipCount(actor, itemid, false)
end

function changeEquipCount(actor, itemid, takeOn)
	if not actor or not EquipCount then return end

	local itemLevel = Item.getItemPropertyById(itemid, Item.ipItemActorLevel)
	for _, info in ipairs(EquipCount) do
		if itemLevel >= info.tid then
			if takeOn then
				LActor.addQuestValue(actor, info.qid, info.tid, info.count)
			else
				if LActor.getQuestValue(actor, info.qid, info.tid) - info.count >= 0 then
					LActor.addQuestValue(actor, info.qid, info.tid, -info.count)
				end
			end
		end
	end
end

function checkEquipCount(actor, qid)
	if not actor or not EquipCount then return end

	local equipconfig
	for _, info in ipairs(EquipCount) do
		if info.qid == qid then
			equipconfig = info
			break
		end
	end
	if equipconfig == nil then return end

	local targetLevel = equipconfig.tid
	local count = Item.getEquipCount(actor)
	for indx = 1, count do
		local pItem = Item.getEquipByIdx(actor, indx)
		if pItem then
			local itemLevel = Item.getItemProperty(actor, pItem, Item.ipItemActorLevel, 0)
			if itemLevel >= targetLevel then
				LActor.addQuestValue(actor, qid, targetLevel, equipconfig.count)
			end
		end
	end
end

function checkFinishFbQuest(actor, fbid)
	if not FuBen[fbid] then return end
	
	fbid = FuBen[fbid].publicFbid or fbid
	if not FinishFbQuest or not FinishFbQuest[fbid] then return end

	local conf = FinishFbQuest[fbid]

	for _, info in ipairs(conf) do
		LActor.addQuestValue(actor, info.qid, fbid, info.count)
	end
end


function initEquipQuest()
	for _, info in ipairs(EquipCount) do
		questsys.regAcceptQuest(info.qid, checkEquipCount)
	end
end
table.insert(InitFnTable, initEquipQuest)

actorevent.reg(aeKilledByActor, killByOtherGuild)
actorevent.reg(aeAddEquiment, addEquipCount)
actorevent.reg(aeDelEquiment, delEquipCount)

LActor.checkQuest = checkQuest


