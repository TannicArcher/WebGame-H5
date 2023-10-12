module("test.test_friend", package.seeall)
setfenv(1, test.test_friend)

require("protocol")
local friendsystem = require("systems.friend.friendsystem")
local chatsystem = require("systems.chat.chatsystem")
local tsystem = require("test.tsystem")


--***********************************************
--README------------构造测试环境-----------------
--***********************************************

--随机抽出在线玩家列表中的一员（todo 非执行此操作的玩家）
function randomSearchMem(actor)
	--获取在线玩家列表
	local members = LuaHelp.getAllActorList()
	if not members then print("no game player online") end	
	if #members <= 1 then 
		print("========================================")
		print("online: ".. #members.." you need more than 2 actor")
		print("========================================")
		return nil 
	end

	local memIdx = System.getRandomNumber(#members)
	if members[memIdx+1] == actor then 
		return members[(memIdx+1)%(#members) + 1]
	end
	return members[memIdx+1]
end

--1、清空玩家好友列表
function clearFriendList(actor)
	local actorId = LActor.getActorId(actor)
	local var_d = LActor.getDyanmicVar(actor)
	local friendList = var_d.friendList
	local friendCount = var_d.friendCount

	if not friendList or friendCount == 0 then return false end
	for friendType, friendInfo in pairs(friendList) do
		for friendId, info in pairs(friendInfo) do
			if friendId then
				friendsystem.saveFriends(actorId, friendId, friendType, 0)
			end
		end
	end

	friendsystem.initFriendList(actor)
end

--------------------------------------------------------------------------------------
-- 请求加好友
function handle_sAddReq(actor, actorBId, actorBName, actorBServerId, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorBId)
	LDataPack.writeString(npack, actorBName)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)
	
	local ret = friendsystem.sAddReq(actor, npack)
	Assert(ret ~= nil, "test_sAddReq, ret is null")							   
	Assert_eq(except, ret, "test_sAddReq error")   
end

function test_sAddReq(actor)	
	--随机找到一个好友
	local other_actor = randomSearchMem(actor)
	if not other_actor then return end

	--初始化环境 清空好友列表（临时表和数据库表）
	clearFriendList(actor)
	clearFriendList(other_actor)

	handle_sAddReq(actor, LActor.getActorId(other_actor), "", 123, true)
end	

--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
-- 回应加好友
function handle_sAddResp(actor, actorBId, isReceive, inviteType, actorBServerId, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorBId)
	LDataPack.writeWord(npack, isReceive)
	LDataPack.writeWord(npack, inviteType)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)

	local var_d = LActor.getDyanmicVar(actor)
	local friendList = var_d.friendList
	local friendCount = var_d.friendCount

	local oldFriendCnt = friendCount[1]
	print("oldFriendCnt "..oldFriendCnt)
	
	local ret = friendsystem.sAddResp(actor, npack)
	Assert(ret ~= nil, "test_sAddResp, ret is null")							   
	Assert_eq(except, ret, "test_sAddResp error")   

	local currFriendCnt = friendCount[1]
	print("currFriendCnt "..currFriendCnt)

	if except == ret and ret == true then
		Assert(currFriendCnt - oldFriendCnt == 1, "test_sAddResp succ,but FriendCnt change error") 
	else 
		Assert_eq(oldFriendCnt, currFriendCnt, "test_sAddResp fail, but FriendCnt change")
	end
end

function test_sAddResp(actor)
	local other_actor = randomSearchMem(actor)
	if not other_actor then return end

	--初始化环境 清空好友列表（临时表和数据库表）
	clearFriendList(actor)
	clearFriendList(other_actor)

	handle_sAddResp(actor, LActor.getActorId(other_actor), 1, 1, 123, true)
end	

------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- 	好友聊天  聊天系统
function handle_clientPrivateChat(actor, actorId, fee, name, msg, actorBServerId, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorId)
	LDataPack.writeInt(npack, fee)
	LDataPack.writeString(npack, name)
	LDataPack.writeString(npack, msg)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)
	
	local var_d = LActor.getDyanmicVar(actor)
	local friendList = var_d.friendList
	local friendCount = var_d.friendCount

	local oldLastCnt = friendCount[4]  --ftLast

	local ret = chatsystem.clientPrivateChat(actor, npack)


	Assert(ret ~= nil, "test_clientPrivateChat, ret is null")							   
	Assert_eq(except, ret, "test_clientPrivateChat error")   

	local currLastCnt = friendCount[4]  --ftLast

	if except == ret and ret == true then
		Assert(currLastCnt - oldLastCnt == 1, "test_clientPrivateChat succ,but LastCnt change error") 
	else 
		Assert_eq(oldLastCnt, currLastCnt, "test_clientPrivateChat fail, but LastCnt change")
	end
end

function test_clientPrivateChat(actor)
	local other_actor = randomSearchMem(actor)
	if not other_actor then return end

	--初始化环境 清空好友列表（临时表和数据库表）
	clearFriendList(actor)
	clearFriendList(other_actor)

	actorBId = LActor.getActorId(other_actor)
	actorBName = LActor.getName(other_actor)
	handle_clientPrivateChat(actor, actorBId, 0, actorBName, "A sent msg to B", 123, true)
end	

--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- 	添加到仇人名单
function handle_sAddEnemy(actor, actorBId, actorBName, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorBId)
	LDataPack.writeString(npack, actorBName)
	LDataPack.setPosition(npack, 0)
	
	local var_d = LActor.getDyanmicVar(actor)
	local friendList = var_d.friendList
	local friendCount = var_d.friendCount

	local oldEnemyCnt = friendCount[2]  --ftEnemy

	local ret = friendsystem.sAddEnemy(actor, npack)
	Assert(ret ~= nil, "test_sAddEnemy, ret is null")							   
	Assert_eq(except, ret, "test_sAddEnemy error")   

	local currEnemyCnt = friendCount[2]  --ftEnemy

	if except == ret and ret == true then
		Assert(currEnemyCnt - oldEnemyCnt == 1, "test_sAddEnemy succ,but LastCnt change error") 
	else 
		Assert_eq(oldEnemyCnt, currEnemyCnt, "test_sAddEnemy fail, but LastCnt change")
	end
end

function test_sAddEnemy(actor)
	local other_actor = randomSearchMem(actor)
	if not other_actor then return end

	--初始化环境 清空好友列表（临时表和数据库表）
	clearFriendList(actor)
	clearFriendList(other_actor)

	actorBId = LActor.getActorId(other_actor)
	actorBName = LActor.getName(other_actor)
	handle_sAddEnemy(actor,actorBId, actorBName, true)
end	

--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- 	添加到黑名单
function handle_sAddBlack(actor, actorBId, actorBName, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorBId)
	LDataPack.writeString(npack, actorBName)
	LDataPack.setPosition(npack, 0)
	
	local var_d = LActor.getDyanmicVar(actor)
	local friendList = var_d.friendList
	local friendCount = var_d.friendCount

	local oldBlackCnt = friendCount[3]  --ftBlack

	local ret = friendsystem.sAddBlack(actor, npack)
	Assert(ret ~= nil, "test_sAddBlack, ret is null")							   
	Assert_eq(except, ret, "test_sAddBlack error")   

	local currBlackCnt = friendCount[3]  --ftEnemy

	if except == ret and ret == true then
		Assert(currBlackCnt - oldBlackCnt == 1, "test_sAddBlack succ,but LastCnt change error") 
	else 
		Assert_eq(oldBlackCnt, currBlackCnt, "test_sAddBlack fail, but LastCnt change")
	end
end

function test_sAddBlack(actor)
	local other_actor = randomSearchMem(actor)
	if not other_actor then return end

	--初始化环境 清空好友列表（临时表和数据库表）
	clearFriendList(actor)
	clearFriendList(other_actor)

	actorBId = LActor.getActorId(other_actor)
	actorBName = LActor.getName(other_actor)
	handle_sAddBlack(actor,actorBId, actorBName, true)
end	

--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- 	查找好友
function handle_sSearch(actor, actorBName, actorBServerId, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeString(npack, actorBName)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)
	

	local ret = friendsystem.sSearch(actor, npack)
	Assert(ret ~= nil, "test_sSearch, ret is null")							   
	Assert_eq(except, ret, "test_sSearch error")   
end

function test_sSearch(actor)
	local other_actor = randomSearchMem(actor)
	if not other_actor then return end

	handle_sSearch(actor, LActor.getName(other_actor), 0, true)
end	

--------------------------------------------------------------------------------------


TEST("friend", "test_sAddReq", test_sAddReq)
TEST("friend", "test_sAddResp", test_sAddResp)
TEST("friend", "test_clientPrivateChat", test_clientPrivateChat)
TEST("friend", "test_sAddEnemy", test_sAddEnemy)
TEST("friend", "test_sAddBlack", test_sAddBlack)
TEST("friend", "test_sSearch", test_sSearch)




--测试跨服（基本只能构造包发放）
--  A服 123 B服 345
local CrossServerId = 345

--------------------------------------------------------------------------------------
-- 	跨服查找好友
function handle_sCrossSearch(actor, actorBName, actorBServerId, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeString(npack, actorBName)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)
	

	local ret = friendsystem.sSearch(actor, npack)
	Assert(ret ~= nil, "test_sCrossSearch, ret is null")							   
	Assert_eq(except, ret, "test_sCrossSearch error")   
end

function test_sCrossSearch(actor)
	local actorBName = "池雨甜"
	local actorBServerId = tonumber(CrossServerId)
	handle_sCrossSearch(actor, actorBName, actorBServerId, true)
end	

--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- 请求加好友
function handle_sCrossAddReq(actor, actorBId, actorBName, actorBServerId, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorBId)
	LDataPack.writeString(npack, actorBName)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)
	
	local ret = friendsystem.sAddReq(actor, npack)
	Assert(ret ~= nil, "test_sCrossAddReq, ret is null")							   
	Assert_eq(except, ret, "test_sCrossAddReq error")   
end

function test_sCrossAddReq(actor)	
	local actorBName = "池雨甜"
	local other_actor = LActor.getActorByName(actorBName)
	local actorBId = LActor.getActorId(other_actor)
	local actorBServerId = tonumber(CrossServerId)

	--初始化环境 清空好友列表（临时表和数据库表）
	--clearFriendList(actor)
	--clearFriendList(other_actor)

	--跨服请求好友
	handle_sCrossAddReq(actor, actorBId, actorBName, actorBServerId, true)
end	

--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- 跨服请求回应加好友
function handle_sCrossAddResp(actor, actorBId, isReceive, inviteType, actorBServerId, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorBId)
	LDataPack.writeWord(npack, isReceive)
	LDataPack.writeWord(npack, inviteType)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)
	
	local ret = friendsystem.sAddResp(actor, npack)
	Assert(ret ~= nil, "test_sCrossAddResp, ret is null")							   
	Assert_eq(except, ret, "test_sCrossAddResp error")   
end

function test_sCrossAddResp(actor)	
	print("=====================================")
	local actorBId = 345 --"池雨甜"
	local actorBServerId = tonumber(CrossServerId)

	handle_sCrossAddResp(actor, actorBId, 1, 1, actorBServerId, true)
end	



--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- 跨服聊天
function handle_sCrossPrivateChat(actor, actorId, fee, name, msg, actorBServerId, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorId)
	LDataPack.writeInt(npack, fee)
	LDataPack.writeString(npack, name)
	LDataPack.writeString(npack, msg)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)

	local ret = chatsystem.clientPrivateChat(actor, npack)
	Assert(ret ~= nil, "test_sCrossPrivateChat, ret is null")							   
	Assert_eq(except, ret, "test_sCrossPrivateChat error")  
end

function test_sCrossPrivateChat(actor)	
	local actorBName = "池雨甜"
	local actorBId = 345
	local actorBServerId = tonumber(CrossServerId)

	handle_sCrossPrivateChat(actor, actorBId, 0, actorBName, "A sent msg to B", actorBServerId, true)
end	

--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- 跨服删除好友
function handle_sCrossDelFriend(actor, actorBId, friendType, actorBServerId)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, actorBId)
	LDataPack.writeInt(npack, friendType)
	LDataPack.writeInt(npack, actorBServerId)
	LDataPack.setPosition(npack, 0)

	friendsystem.sDelFriend(actor, npack)
end

function test_sCrossDelFriend(actor)	
	local actorBId = 8537  -- "跨服玩家ID"
	local actorBServerId = tonumber(CrossServerId)
	handle_sCrossDelFriend(actor, actorBId, 5, actorBServerId)  --ftCrossFriend
end	

--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--测试合服的时候通知跨服的在线好友修改数据
function test_mergeSrvBroadcast(actor)
	friendsystem.mergeSrvBroadcast(actor, tsystem)
end

--------------------------------------------------------------------------------------


_G.test_sCrossSearch = test_sCrossSearch
_G.test_sCrossAddReq = test_sCrossAddReq
_G.test_sCrossAddResp = test_sCrossAddResp
_G.test_sCrossPrivateChat = test_sCrossPrivateChat
_G.test_sCrossDelFriend = test_sCrossDelFriend
_G.test_mergeSrvBroadcast = test_mergeSrvBroadcast


--手动清空玩家的临时表与数据库表
function test_clearList(actor)
	clearFriendList(actor)
end	

_G.test_clearList = test_clearList


