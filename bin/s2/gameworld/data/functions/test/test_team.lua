module("test.test_team" , package.seeall)
setfenv(1, test.test_team)

local teamsystem = require("systems.team.teamsystem")
require("protocol")
local tlactor = require("test.tlactor")
local tsystem = require("test.tsystem")


--***********************************************
--README------------通用测试环境-----------------
--***********************************************

--组建 n 个成员的队伍 或 创建两组成员互斥的队伍 mem_cnt/other_mem_cnt 不可以小于0
function initActorTeam(actor, mem_cnt, other_actor, other_mem_cnt)
	if not actor then return false end
	LActor.exitTeam(actor)
	if (not mem_cnt or mem_cnt == 0 ) and 
		not other_actor and not other_mem_cnt then 
		return false
	end
	--获取在线玩家列表
	local members = LuaHelp.getAllActorList()
	--print("/*********** online actor cnt *************/ "..#members)
	if not members then return false end
	if #members < mem_cnt then
		print("/************* initActorTeam fail ***************/")
		print("online game player can't constitute these team")
		print("/************* initActorTeam fail ***************/\n")
		return false
	end

	local first_team_pos = 1
	if mem_cnt >= 1 then
		local curr_mem_cnt = 1  --默认创建以自己为队长的队伍
		local actor_team = TeamFun.createTeam(actor)		
		for pos, member in ipairs(members) do
			if curr_mem_cnt < mem_cnt and 				
				member ~= actor and
				member ~= other_actor then
				LActor.exitTeam(member)
				TeamFun.addMember(actor_team, member)	
				-- local team_id = LActor.getIntProperty(actor, P_TEAM_ID)
				-- print("1>>>>>>>>>> "..Fuben.getTeamMemberCount(team_id))
				curr_mem_cnt = curr_mem_cnt + 1
				first_team_pos = pos
			end
		end
	end

	if not other_actor then return false end
	LActor.exitTeam(other_actor)
	if (not other_mem_cnt or other_mem_cnt == 0) then
		return false
	end

	--如果玩家A不创建队伍时，因为不能把A添加到玩家B的队伍去所能在线成员数必须大于 1+玩家B组队的成员数
	if mem_cnt == 0 then mem_cnt = 1 end 
	local all_cnt = mem_cnt + other_mem_cnt
	if #members < all_cnt then
		print("/************* initActorTeam fail ***************/")
		print("curr online game player can't constitute second team")
		print("/************* initActorTeam fail ***************/\n")
		return false
	end

	local curr_other_mem_cnt = 1  --默认创建以自己为队长的队伍
	local other_team = TeamFun.createTeam(other_actor)
	for i = first_team_pos ,#members do
		if curr_other_mem_cnt < other_mem_cnt and 
			members[i] ~= other_actor and
			members[i] ~= actor then
			LActor.exitTeam(members[i])
			TeamFun.addMember(other_team, members[i])
			-- local team_id = LActor.getIntProperty(other_actor, P_TEAM_ID)
			-- print("2>>>>>>>>>> "..Fuben.getTeamMemberCount(team_id))
			curr_other_mem_cnt = curr_other_mem_cnt + 1
		end
	end
	return true
end
		

--2个玩家的操作,随机一个玩家与主玩家组成拥有n 个成员的队伍
function initActorTeam2(actor, other_actor, mem_cnt) --mem_cnt >= 2
	if not actor and not other_actor then return false end
	if mem_cnt and mem_cnt < 2 then return false end
	mem_cnt = mem_cnt or 2
	--让玩家所在队伍的成员数为：mem_cnt	
	--获取在线玩家列表
	local members = LuaHelp.getAllActorList()
	if members == nil then return end
	if #members < mem_cnt then 
		print("/************* initActorTeam fail ***************/")
		print("online game player can't constitute these team")
		print("/************* initActorTeam fail ***************/\n")
		return false
	end

	LActor.exitTeam(actor)
	LActor.exitTeam(other_actor)
	local new_team = TeamFun.createTeam(actor)
	TeamFun.addMember(new_team, other_actor)
	local curr_mem_cnt = 2
	for _,member in ipairs(members) do
		if member ~= actor and 
			member ~= other_actor and
			curr_mem_cnt < mem_cnt then
			LActor.exitTeam(member)
			TeamFun.addMember(new_team, member)
			curr_mem_cnt = curr_mem_cnt + 1
		end
	end
	return true
end


--随机抽出在线玩家列表中的一员（todo 非执行此操作的玩家）
function randomSearchMem(actor)
	--获取在线玩家列表
	local members = LuaHelp.getAllActorList()
	if not members then print("no game player online") end	
	if #members <= 1 then return nil end

	local memIdx = System.getRandomNumber(#members)
	if members[memIdx+1] == actor then 
		return members[(memIdx+1)%(#members) + 1]
	end
	return members[memIdx+1]
end


--***********************************************
--README------------通用测试环境-----------------
--***********************************************


-----------------------------------------BEGIN 创建队伍 BEGIN-----------------------------------------
-- Comments: 创建队伍
function handle_createTeam(actor, except)
	local ret = teamsystem.createTeam(actor)
	Assert(ret ~= nil, "test_createTeam, ret is null")							    
	Assert_eq(except, ret, "test_createTeam error") 

	local team_id = LActor.getIntProperty(actor, P_TEAM_ID)
	local team = TeamFun.getTeam (team_id)
	local curr_member_cnt = Fuben.getTeamMemberCount(team_id)

	--如果成功
	if except == ret then
		Assert(team ~= nil, "test_createTeam succ,but not find the team") 
		Assert(curr_member_cnt == 1, "test_createTeam succ,but memberCnt is error") 
	else
		Assert(team == nil, "test_createTeam error,but find the team") 
		Assert(curr_member_cnt == 0, "test_createTeam error,memberCnt ~= 0") 
	end
end

function test_createTeam(actor)	
	for i=0,10 do
		--1、未创建队伍
		local ret = initActorTeam(actor)
		if ret then handle_createTeam(actor, true) end
		--2、己存在队伍
		local ret = initActorTeam(actor, 1)
		if ret then handle_createTeam(actor, false) end
	end
end
-----------------------------------------END 创建队伍 END-----------------------------------------



-----------------------------------------BEGIN 离开队伍 BEGIN-------------------------------------
-- Comments: 离开队伍
function handle_leaveTeam(actor, except)
	local team_id = LActor.getIntProperty(actor, P_TEAM_ID)
	local team = TeamFun.getTeam (team_id)
	local old_member_cnt = Fuben.getTeamMemberCount(team_id)
	local old_leader = TeamFun.getTeamCaptain(team)

	local ret = teamsystem.leaveTeam(actor)
	Assert(ret ~= nil, "test_leaveTeam, ret is null")							    
	Assert_eq(except, ret, "test_leaveTeam error") 

	team_id = LActor.getIntProperty(actor, P_TEAM_ID)
	team = TeamFun.getTeam (team_id)
	local curr_member_cnt = Fuben.getTeamMemberCount(team_id)
	local curr_leader = TeamFun.getTeamCaptain(team)

	--如果成功
	if except == ret and ret == true then		
			Assert(team == nil, "test_leaveTeam succ,but find the team") 
			Assert(curr_member_cnt == 0, "test_leaveTeam succ,but memberCnt is error") 
	else
		Assert(team ~= nil, "test_leaveTeam error,but not find the team") 
		Assert_eq(old_member_cnt, curr_member_cnt, "test_leaveTeam error,but the memberCnt change") 
		Assert_eq(old_leader, curr_leader, "test_leaveTeam fail, but change leader change")
	end
end

function test_leaveTeam(actor)	
	--1、保证队伍1个人 且玩家为队长
	local ret = initActorTeam(actor, 1)
	if ret then handle_leaveTeam(actor, true) end

	--2、（1－2）个人的队伍：队伍解散	
	local ret = initActorTeam(actor, 2)
	if ret then handle_leaveTeam(actor, true) end

	--超2人的队伍，如果为队长离开，设下一位为队长
	local ret = initActorTeam(actor, 3)
	if ret then handle_leaveTeam(actor, true) end
end

-----------------------------------------END 离开队伍 END-----------------------------------------


--------------------------------BEGIN 邀请其他玩家加入队伍 BEGIN-----------------------------------
-- Comments: 邀请其他玩家加入队伍
function handle_inviteJoinTeam(actor, name, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeString(npack, name)
	LDataPack.setPosition(npack, 0)

	local ret = teamsystem.inviteJoinTeam(actor, npack)
	Assert(ret ~= nil, "test_inviteJoinTeam, ret is null")							   
	Assert_eq(except, ret, "test_inviteJoinTeam error")   

	--如果成功 客户端收到邀请入队请求
end

--适用于需要以两玩家各自创建n成员组的情况
InviteJoinTeamTbl = 
{
	--第一个参数为A玩家队伍成员的数量，0表示没有创建队伍
	--第二个参数为B玩家队伍成员的数量，0表示没有创建队伍
	--期望值
	{0, 0, true},  --邀请的人为其他玩家（在线的情况）
	{0, 1, true},  --当被邀请的人有队伍但只有一人时是可以的 
	{0, 2, true},  --当被邀请的人有队伍且不止一人时也是可能邀请的（new）
	--{0, 2, false}, --当被邀请的人有队伍且不止一人时不可以
	{4, 0, false}, --当邀请人己有队伍且己满员时不可以
}


function test_inviteJoinTeam(actor)
	--1、名字为空
	handle_inviteJoinTeam(actor, nil, false)
	--2、邀请的人为自己
	handle_inviteJoinTeam(actor, LActor.getName(actor), false)

	--保证其他玩家没有加入队伍
	local other_actor = randomSearchMem(actor)
	--通过测试值配置表调用方法，测试输入值出界的情况
	for k,value in ipairs(InviteJoinTeamTbl) do	
		local ret = initActorTeam(actor, value[1], other_actor, value[2])
		if ret then handle_inviteJoinTeam(actor, LActor.getName(other_actor), value[3]) end
	end
end

-----------------------------------------END 邀请加入队伍 END-----------------------------------------


-----------------------------------------BEGIN 回复邀请加入队伍 BEGIN---------------------------------
-- Comments: 回复邀请加入队伍 
function handle_inviteJoinTeamReply(actor, name, ret, auto, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeString(npack, name)
	LDataPack.writeByte(npack, ret)  --同意：1 不同意：0
	LDataPack.writeByte(npack, auto) --是否同意,0:非自动，1：自动同意
	LDataPack.setPosition(npack, 0)

	local invite_actor = LActor.getActorByName(name)
	local team_id = LActor.getIntProperty(invite_actor, P_TEAM_ID)
	local old_member_cnt = Fuben.getTeamMemberCount(team_id)
	local old_team = TeamFun.getTeam(team_id) --可能原来没有队伍
	local old_leader = TeamFun.getTeamCaptain(old_team)
	-- print("************=====================***********")
	-- print(string.format("team_id  %s  captain is : %s", team_id or "XXX", LActor.getName(old_leader) or "XXX"))
	-- print("************=====================***********")

	local ret = teamsystem.inviteJoinTeamReply(actor, npack)                             
	Assert(ret ~= nil, "test_inviteJoinTeamReply, ret is null")							    
	Assert_eq(except, ret, "test_inviteJoinTeamReply error")   

	local curr_team_id = LActor.getIntProperty(invite_actor, P_TEAM_ID)
	local curr_member_cnt = Fuben.getTeamMemberCount(curr_team_id)
	local curr_team = TeamFun.getTeam(curr_team_id) 
	local curr_leader = TeamFun.getTeamCaptain(curr_team)
	-- print("************=====================***********")
	-- print(string.format("team_id  %s  captain is : %s", curr_team_id or "XXX", LActor.getName(curr_leader) or "XXX"))
	-- print("************=====================***********")

	--如果成功
	if except == ret and ret == true then	
		--如果原来没有队伍－〉队伍成员+2，如果有队伍－〉队伍成员+1
		if team_id == 0 then
			Assert(curr_member_cnt - old_member_cnt == 2, "test_inviteJoinTeamReply succ but member_cnt change error") 
			Assert(old_leader == nil, "when not team then old_leader not nil")
			Assert_eq(invite_actor, curr_leader, "set the captain error")
		else
			Assert(curr_member_cnt - old_member_cnt == 1, "test_inviteJoinTeamReply succ but member_cnt change error") 
			Assert_eq(old_leader, curr_leader, "test_inviteJoinTeamReply succ but leader change")
		end
	else
		--队伍成员不变
		Assert_eq(old_member_cnt, curr_member_cnt, "test_inviteJoinTeamReply fail but member_cnt change")
	end
end

--适用于需要以两玩家各自创建n成员组的情况
InviteJoinTeamReplyTbl = 
{
	--第一个参数为A玩家队伍成员的数量，0表示没有创建队伍
	--第二个参数为B玩家队伍成员的数量，0表示没有创建队伍
	--第三个参数为是否同意加入
	--第四个参数为是否自动
	--期望值
	{0, 0, 0, 1, false},  
	{0, 0, 1, 1, true},   
	{0, 1, 1, 1, true}, --玩家无队伍,邀请玩家的人队伍人数 = 1
	{1, 0, 1, 1, false}, --玩家有队伍则不能加入，邀请玩家的人无队伍
	--{1, 0, 1, 1, true}, --玩家有队伍 人数 = 1，邀请玩家的人无队伍
	{3, 0, 1, 1, false}, --玩家己有组，且人物多于1
	{0, 4, 1, 1, false}, --邀请自己的玩家队员己满
}


-- Comments: 回复邀请加入队伍
function test_inviteJoinTeamReply(actor)
	--构造环境 确保玩家与邀请玩家的人一开始都没有加入队伍
	local invite_actor = randomSearchMem(actor)
	--通过测试值配置表调用方法，测试输入值出界的情况
	for k,value in ipairs(InviteJoinTeamReplyTbl) do	
		local ret = initActorTeam(actor, value[1], invite_actor, value[2])
		if ret then handle_inviteJoinTeamReply(actor, LActor.getName(invite_actor), value[3], value[4], value[5]) end
	end
end

-----------------------------------------END 回复邀请加入队伍 END--------------------------------------


-----------------------------------------BEGIN 申请加入队伍 BEGIN---------------------------------------
-- Comments: 申请加入队伍
function handle_applyJoinTeam(actor, name, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeString(npack, name)
	LDataPack.setPosition(npack, 0)

	local ret = teamsystem.applyJoinTeam(actor, npack)                           			 
	Assert(ret ~= nil, "test_applyJoinTeam, ret is null")							    
	Assert_eq(except, ret, "test_applyJoinTeam error")   

	--如果成功 客户端收到申请入队请求
end

--适用于需要以两玩家各自创建n成员组的情况
ApplyJoinTeamTbl = 
{
	--第一个参数为A玩家队伍成员的数量，0表示没有创建队伍
	--第二个参数为B玩家队伍成员的数量，0表示没有创建队伍
	--期望值
	{0, 0, false},  --玩家所申请的人必须有队伍
	{0, 1, true},   --对方有队伍且不满员时
	{0, 4, false},  --对方有队伍,满员
	-- {1, 1, false},  --自己已有队伍
}

function test_applyJoinTeam(actor)
	--1、名字为空
	handle_applyJoinTeam(actor, nil, false)
	--2、向自己申请
	handle_applyJoinTeam(actor, LActor.getName(actor), false)

	local other_actor = randomSearchMem(actor)
	for k,value in ipairs(ApplyJoinTeamTbl) do
		local ret = initActorTeam(actor, value[1], other_actor , value[2])
		if ret then handle_applyJoinTeam(actor, LActor.getName(other_actor), value[3]) end
	end
end

--------------------------------------------END 申请加入队伍 END----------------------------------------

-----------------------------------------BEGIN 回复申请加入队伍 BEGIN---------------------------------
-- Comments: 回复申请加入队伍 
function handle_applyJoinTeamReply(actor, aid, ret, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, aid)
	LDataPack.writeByte(npack, ret)  --同意：1 不同意：0
	LDataPack.setPosition(npack, 0)

	local team_id = LActor.getIntProperty(actor, P_TEAM_ID)
	local old_member_cnt = Fuben.getTeamMemberCount(team_id)
	local old_team = TeamFun.getTeam(team_id) 
	local old_leader = TeamFun.getTeamCaptain(old_team)
	
	local ret = teamsystem.applyJoinTeamReply(actor, npack)                          
	Assert(ret ~= nil, "test_applyJoinTeamReply, ret is null")						   
	Assert_eq(except, ret, "test_applyJoinTeamReply error")   

	local curr_member_cnt = Fuben.getTeamMemberCount(team_id)
	local curr_leader = TeamFun.getTeamCaptain(old_team)
	
	--如果成功
	if except == ret and ret == true then	
		Assert(curr_member_cnt - old_member_cnt == 1, "test_applyJoinTeamReply succ but member_cnt change error") 
		Assert_eq(old_leader, curr_leader, "test_applyJoinTeamReply succ but captain change")
	else
		Assert_eq(old_member_cnt, curr_member_cnt, "test_applyJoinTeamReply fail but member_cnt change")
	end
end

--适用于需要以两玩家各自创建n成员组的情况
ApplyJoinTeamReplyTbl = 
{
	--第一个参数为A玩家队伍成员的数量，0表示没有创建队伍
	--第二个参数为B玩家队伍成员的数量，0表示没有创建队伍
	--第三个参数为是否同意加入
	--期望值
	{0, 0, 1, false},  --自己没队伍不能接受别人申请
	{1, 0, 1, true},   --接受
	{1, 0, 0, false},  --拒绝
	{1, 1, 1, false},  --申请的人己有队伍
	{4, 0, 1, false},  --自己的队伍己满员
}

-- Comments: 回复邀请加入队伍
function test_applyJoinTeamReply(actor)
	--构造环境 
	local other_actor = randomSearchMem(actor)
	for k,value in ipairs(ApplyJoinTeamReplyTbl) do		
		local ret = initActorTeam(actor, value[1], other_actor , value[2])
		if ret then handle_applyJoinTeamReply(actor,LActor.getActorId(other_actor), value[3], value[4]) end
	end
end

-----------------------------------------END 回复申请加入队伍 END--------------------------------------


----------------------------------------------BEGIN 设置队长 BEGIN--------------------------------------
-- Comments: 设置队长
function handle_setCaptain(actor, aid, except, other_actor)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, aid)
	LDataPack.setPosition(npack, 0)

	local team_id = LActor.getIntProperty(actor, P_TEAM_ID)
	local team = TeamFun.getTeam (team_id)
	local old_leader = TeamFun.getTeamCaptain(team)

	local ret = teamsystem.setCaptain(actor, npack)                                    
	Assert(ret ~= nil, "test_setCaptain, ret is null")						          
	Assert_eq(except, ret, "test_setCaptain error")

	local curr_leader = TeamFun.getTeamCaptain(team)

	--如果成功
	if except == ret and ret == true then	
		Assert_eq(other_actor, curr_leader, "test_setCaptain succ but leader change error")
	else
		Assert_eq(old_leader, curr_leader, "test_setCaptain fail but leader change")
	end
end

--适用于需要以两玩家创建一个 n 成员队伍的情况
SetCaptainTbl = 
{
	--第一个参数为该队伍成员的数量 >=2
	{2, true},
	{3, true},
}

function test_setCaptain(actor)
	--构造环境 
	local other_actor = randomSearchMem(actor)
	for k,value in ipairs(SetCaptainTbl) do
		local ret = initActorTeam2(actor, other_actor ,value[1])
		if ret then handle_setCaptain(actor, LActor.getActorId(other_actor), value[2], other_actor) end
	end
end
--------------------------------------------END 设置队长 END--------------------------------------------


----------------------------------------------BEGIN 设置队长 BEGIN--------------------------------------
-- Comments: 踢人
function handle_kickMember(actor, aid, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, aid)
	LDataPack.setPosition(npack, 0)

	local team_id = LActor.getIntProperty(actor, P_TEAM_ID)
	local old_member_cnt = Fuben.getTeamMemberCount(team_id)

	local ret = teamsystem.kickMember(actor, npack)                                     
	Assert(ret ~= nil, "test_kickMember, ret is null")						           
	Assert_eq(except, ret, "test_kickMember error")

	local curr_team_id = LActor.getIntProperty(actor, P_TEAM_ID)
	local curr_member_cnt = Fuben.getTeamMemberCount(curr_team_id)

	--如果成功
	if except == ret and ret == true then	
		if old_member_cnt == 2 then
			Assert(curr_team_id == 0,"test_kickMember succ but not destroyTeam")
		else
			Assert(old_member_cnt - curr_member_cnt == 1, "test_kickMember succ but member_cnt change error")
		end
	else
		Assert_eq(old_member_cnt, curr_member_cnt, "test_kickMember fail but member_cnt change")
	end
end

KickMemberTbl = 
{
	{2, true},--队伍里共有两个人..踢掉一个解散队伍
	{3, true},--队伍里超过两个人..踢掉一个后，人数减一
	{4, true},--同上
}

function test_kickMember(actor)
	--构造环境 
	local other_actor = randomSearchMem(actor)
	for k,value in ipairs(KickMemberTbl) do
		local ret = initActorTeam2(actor, other_actor ,value[1])
		if ret then handle_kickMember(actor, LActor.getActorId(other_actor), value[2]) end
	end
end
--------------------------------------------END 设置队长 END--------------------------------------------


----------------------------------------------BEGIN 发送队伍成员信息 BEGIN------------------------------
-- Comments: 发送队伍成员信息
function handle_teamMembers(actor, team_id, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeUInt(npack, team_id)
	LDataPack.setPosition(npack, 0)

	local ret = teamsystem.teamMembers(actor, npack)                                    
	Assert(ret ~= nil, "test_teamMembers, ret is null")						           
	Assert_eq(except, ret, "test_teamMembers error")
end


function test_teamMembers(actor)	
	for i = 1,4 do
		local ret = initActorTeam(actor, i)
		local team_id = LActor.getIntProperty(actor, P_TEAM_ID)
		if ret then handle_teamMembers(actor, team_id, true) end
	end
end


--------------------------------------------END 发送队伍成员信息 END-------------------------------------



----------------------------------------------BEGIN 发送附近成员信息 BEGIN-------------------------------
function test_nearbyActors(actor)
	local ret = teamsystem.nearbyActors(actor)                                    
	Assert(ret ~= nil, "test_teamMembers, ret is null")						           
	Assert_eq(true, ret, "test_teamMembers error")
end

--------------------------------------------END 发送附近成员信息 END-------------------------------------



----------------------------------------------BEGIN 发送附近队伍成员信息 BEGIN---------------------------
function handle_nearbyTeams(actor, except)
	local ret = teamsystem.nearbyTeams(actor)                                    
	Assert(ret ~= nil, "test_teamMembers, ret is null")						           
	Assert_eq(except, ret, "test_teamMembers error")
end


function test_nearbyTeams(actor)
	local ret = initActorTeam(actor, 1)
	if ret then handle_nearbyTeams(actor, true) end
end
--------------------------------------------END 发送附近队伍成员信息 END----------------------------------


--当需要测试时调用
--由玩家《东方浩月》测试
TEST("team", "test_createTeam", test_createTeam)
TEST("team", "test_leaveTeam", test_leaveTeam)
TEST("team", "test_inviteJoinTeam", test_inviteJoinTeam)
TEST("team", "test_applyJoinTeam", test_applyJoinTeam)
TEST("team", "test_setCaptain", test_setCaptain)
TEST("team", "test_kickMember", test_kickMember)
TEST("team", "test_teamMembers", test_teamMembers)
TEST("team", "test_inviteJoinTeamReply", test_inviteJoinTeamReply)
TEST("team", "test_applyJoinTeamReply", test_applyJoinTeamReply)

TEST("team", "test_nearbyActors", test_nearbyActors)
TEST("team", "test_nearbyTeams", test_nearbyTeams)




function test_nearbyTeams(actor)
	--获取在线玩家列表
	local members = LuaHelp.getAllActorList()
	--print("/*********** online actor cnt *************/ "..#members)
	if not members then return false end
	for _,member in ipairs(members) do
		LActor.exitTeam(member)
		--TeamFun.createTeam(member)	
	end
	teamsystem.nearbyTeams(actor)
end


_G.test_ttunit = test_nearbyTeams
_G.test_ttunit1 = teamsystem.nearbyActors



