--答题活动测试

module("test.test_question" , package.seeall)
setfenv(1, test.test_question)

local test_func_question = {}
local questionSysTem = require("systems.question.questionsystem")
local fubensystem = require("systems.fubensystem.fubensystem")

local LDataPack     = LDataPack

--技能目标
local str = "九幽"

test_func_question.start = function ()
	questionSysTem.questionStart()
end

test_func_question.stop = function ()
	questionSysTem.questionStop()
end

test_func_question.enter = function (actor)
	local pack = LDataPack.test_allocPack()
	if pack == nil then return end
	LDataPack.writeInt(pack, 158)
	LDataPack.setPosition(pack, 0)
	fubensystem.clientEnterFuben(actor, pack)
end

test_func_question.exit = function(actor)

	fubensystem.exitFuben(actor)

	return true
end

test_func_question.stun = function(actor)

	local pack = LDataPack.test_allocPack()
	if pack == nil then return end
	LDataPack.writeString(pack, str)
	LDataPack.setPosition(pack, 0)
	questionSysTem.useQuestionSkillStun(actor, pack)

	return true
end

test_func_question.repulse = function(actor)

	local pack = LDataPack.test_allocPack()
	if pack == nil then return end
	LDataPack.writeString(pack, str)
	LDataPack.setPosition(pack, 0)
	questionSysTem.useQuestionSkillRepulse(actor, pack)

	return true
end

test_func_question.follow = function(actor)

	local pack = LDataPack.test_allocPack()
	if pack == nil then return end
	LDataPack.writeString(pack, str)
	LDataPack.setPosition(pack, 0)
	questionSysTem.useQuestionSkillFollow(actor, pack)

	return true
end

test_func_question.buy = function(actor)

	questionSysTem.buySkillFollow(actor)

	return true
end


TEST("question", "start", test_func_question.start, false)
TEST("question", "stop", test_func_question.stop, false)
TEST("question", "enter", test_func_question.enter)
TEST("question", "exit", test_func_question.exit)
TEST("question", "stun", test_func_question.stun)
TEST("question", "repulse", test_func_question.repulse)
TEST("question", "follow", test_func_question.follow)
TEST("question", "buy", test_func_question.buy)





