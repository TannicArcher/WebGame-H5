--跨服竞技场匹配
module("crossarenamatch", package.seeall)

require("systems.crossarena.crossarenacommon")

local Protocol = Protocol
---------------------------本服-------------------------------------
GlobalTeamData = GlobalTeamData or {}	--组队信息
GlobalBeInvitationData = GlobalBeInvitationData or {}
--[[
	CrossArenaFbHandleData[玩家id] = fbHandle 	--保存跨服竞技场的fbHandle

	GlobalBeInvitationData[玩家id] = {收到哪些队长id的邀请}

	GlobalTeamData[玩家id] = {
		leaderId 队长id		--如果玩家不是队长的话， 其他的信息读GlobalTeamData[leaderId] 的信息吧
		match 	1 正在匹配中
		invitation[已邀请的玩家id] = 1
		
		members[]	队员信息 [玩家id] = {
							sId 服务器id, logout 离线, metal 段位, score 分数,
							multiWin 连胜

							monWin 本月战绩
							monDogFalll
							monLose

							historyWin 历史战绩
							historyDogFalll
							historyLose

							int fight 战力
							string  name 玩家名
							char job 职业
							char sex 性别
							int coat 衣服
							int weapon 武器
							int wingLevel 翅膀等级
							char wingStatus 翅膀开启状态
							int dress1 装扮1
							int dress2 装扮2
							int dress3 装扮3
							int zsLevel 转生等级
							int level 玩家等级}
	}
--]]

local matchScoreRange = CrossArenaBase.teamScoreRange		--积分相差x分以内的 可以组队
local maxMemberCount = 3		--队员个数
local worldInvitationCd = 10 	--发世界邀请的cd时间

local function actor_log(actor, str)
	if not actor or not str then return end

	print("error crossmatch, actorId:"..LActor.getActorId(actor).."log:"..str)
end

local function getGlobalTeamData()
	return GlobalTeamData
end

local function getGlboalBeInvitationData()
	return GlobalBeInvitationData
end

local function getActorTeamData(actor, actorId)
	if not actorId then
		actorId = LActor.getActorId(actor)
	end

	local allTeamData = getGlobalTeamData()
	if not allTeamData or not allTeamData[actorId] then return end

	local leaderId = allTeamData[actorId].leaderId
	if not allTeamData[leaderId] then
		allTeamData[actorId] = nil 
		actor_log(actor, "getActorTeamData actor not has this team")
		return
	end

	return allTeamData[leaderId]
end

--是否有队伍了
function hasTeam(actor)
	return getActorTeamData(actor) and 1 or 0
end

--获取队员信息
local function getMembers(actor, leaderId)
	local allTeamData = getGlobalTeamData()
	if not allTeamData then return end

	if leaderId and allTeamData[leaderId] then
		return allTeamData[leaderId].members
	end

	local actorId = LActor.getActorId(actor)
	if not allTeamData[actorId] then return end

	local data = allTeamData[actorId]
	if data.leaderId ~= actorId then
		data = allTeamData[data.leaderId]
	end

	return data.members
end

local function isLeader(allTeamData, actorId)
	if not allTeamData or not allTeamData[actorId] or allTeamData[actorId].leaderId ~= actorId then return false end

	return true
end

--发送玩家个人信息
local function sendActorInfo(actor)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_ActorInfo)
	if not pack then return end

	local monWin, monDogFalll, monLose = crossarenacommon.getNowWin(actor)
	local historyWin, historyDogFalll, historyLose = crossarenacommon.getHistoryWin(actor)
	LDataPack.writeInt(pack, crossarenacommon.getFightCount(actor))
	LDataPack.writeInt(pack, crossarenacommon.getMetal(actor))
	LDataPack.writeInt(pack, crossarenacommon.getScore(actor))
	LDataPack.writeInt(pack, monWin)
	LDataPack.writeInt(pack, monDogFalll)
	LDataPack.writeInt(pack, monLose)
	LDataPack.writeInt(pack, historyWin)
	LDataPack.writeInt(pack, historyDogFalll)
	LDataPack.writeInt(pack, historyLose)

	LDataPack.flush(pack)
end

--发送战队信息
local function sendTeamInfo(actor)
	if not actor then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_TeamInfo)
	if not pack then return end

	local data = getActorTeamData(actor)
	if not data then
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
		LDataPack.writeInt(pack, 0)
	else
		LDataPack.writeInt(pack, data.leaderId)
		LDataPack.writeInt(pack, data.match or 0)
		LDataPack.writeInt(pack, table.getnEx(data.members))
		for aid, v in pairs(data.members) do
			LDataPack.writeInt(pack, aid)
			LDataPack.writeInt(pack, v.sId)
			LDataPack.writeInt(pack, v.logout or 1)
			LDataPack.writeInt(pack, v.metal)
			LDataPack.writeInt(pack, v.score)

			LDataPack.writeInt(pack, v.monWin)
			LDataPack.writeInt(pack, v.monDogFalll)
			LDataPack.writeInt(pack, v.monLose)

			LDataPack.writeInt(pack, v.historyWin)
			LDataPack.writeInt(pack, v.historyDogFalll)
			LDataPack.writeInt(pack, v.historyLose)

			LDataPack.writeInt(pack, v.fight)
			LDataPack.writeInt(pack, crossarenacommon.getWinRate(actor))

			LDataPack.writeString(pack, v.name)
			LDataPack.writeChar(pack, v.job)
			LDataPack.writeChar(pack, v.sex)
			LDataPack.writeInt(pack, v.coat)
			LDataPack.writeInt(pack, v.weapon)
			LDataPack.writeInt(pack, v.wingLevel)
			LDataPack.writeChar(pack, v.wingStatus)
			LDataPack.writeInt(pack, v.dress1)
			LDataPack.writeInt(pack, v.dress2)
			LDataPack.writeInt(pack, v.dress3)
			LDataPack.writeInt(pack, v.zsLevel)
			LDataPack.writeInt(pack, v.level)
		end
	end
	
	LDataPack.flush(pack)
end

--通知所有队员 战队信息
local function sendMemberTeamInfo(actor, leaderId)
	local members = getMembers(actor, leaderId)
	for aid, _ in pairs(members) do
		sendTeamInfo(LActor.getActorById(aid))
	end
end

--发送邀请信息
local function sendInvitation(actor, leaderId, leaderName, fight, score, win)
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_Invitation)
	if not pack then return end

	LDataPack.writeInt(pack, leaderId)
	LDataPack.writeString(pack, leaderName)
	LDataPack.writeInt(pack, fight)
	LDataPack.writeInt(pack, score)
	LDataPack.writeInt(pack, win)

	LDataPack.flush(pack)
end

local function getActorInfo(actor, actorId, logout)
	local role = LActor.getRole(actor,0)
	local level, _, _, status = LActor.getWingInfo(actor, 0)
	local d1,d2,d3 = LActor.getZhuangBan(actor, 0)
	local monWin, monDogFalll, monLose = crossarenacommon.getNowWin(actor)
	local historyWin, historyDogFalll, historyLose = crossarenacommon.getHistoryWin(actor)

	return {
		sId = LActor.getServerId(actor),
		logout =  logout or 1,
		metal = crossarenacommon.getMetal(actor),
		multiWin = crossarenacommon.getMultiWin(actor),
		monWin = monWin,
		monDogFalll = monDogFalll,
		monLose = monLose,
		historyWin = historyWin,
		historyDogFalll = historyDogFalll,
		historyLose = historyLose,
		score = crossarenacommon.getScore(actor),
		fight = LActor.getActorPower(actorId),
		name = LActor.getName(actor),
		job = LActor.getJob(actor),
		sex = LActor.getSex(actor),
		coat = LActor.getEquipId(role, EquipSlotType_Coat),
		weapon = LActor.getEquipId(role, EquipSlotType_Weapon),
		wingLevel = level or 0,
		wingStatus = status or 0,
		dress1 = d1 or 0,
		dress2 = d2 or 0,
		dress3 = d3 or 0,
		zsLevel = LActor.getZhuanShengLevel(actor),
		level = LActor.getLevel(actor)
	}
end

--更新队员信息
local function updateMemberInfo(actor, logout)
	local data = getActorTeamData(actor)
	if not data then return end

	local actorId = LActor.getActorId(actor)
	data.members[actorId] = getActorInfo(actor, actorId, logout)
	sendMemberTeamInfo(actor)
end

--创建队伍
local function createTeam(actor)
	if not crossarenacommon.isOpen() or LActor.getZhuanShengLevel(actor) < CrossArenaBase.zhuanshengLevel then return end

	local allTeamData = getGlobalTeamData()
	if not allTeamData then return end

	local actorId = LActor.getActorId(actor)
	if allTeamData[actorId] then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca1)
		return
	end

	allTeamData[actorId] = {
		leaderId = actorId,
		members = {
			[actorId] = getActorInfo(actor, actorId)
		}
	}

	sendTeamInfo(actor)
end

--是否可以邀请玩家
local function canInvitation(actor, otherActor)
	if not otherActor then return false end

	if LActor.getZhuanShengLevel(otherActor) < CrossArenaBase.zhuanshengLevel then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca2)
		return false
	end

	if getActorTeamData(otherActor) then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca3)
		return false
	end

	if LActor.getFubenId(otherActor) ~= 0 then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca4)
		return false
	end

	if crossarenacommon.getFightCount(otherActor) < 1 then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca5)
		return false
	end

	if math.abs(crossarenacommon.getScore(actor) - crossarenacommon.getScore(otherActor)) > matchScoreRange then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca6)
		return false
	end

	return true
end

--邀请
local function invitation(actor, packet)
	local otherId = LDataPack.readInt(packet)

	local data = getActorTeamData(actor)
	if not data then return end

	if not data.invitation then
		data.invitation = {}
	end

	if data.invitation[otherId] then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca7)
		return
	end

	local otherActor = LActor.getActorById(otherId)
	if not canInvitation(actor, otherActor) then return end

	data.invitation[otherId] = {}

	local invData = getGlboalBeInvitationData()
	if not invData[otherId] then
		invData[otherId] = {}
	end

	local leaderId = data.leaderId
	table.insert(invData[otherId], leaderId)

	sendInvitation(otherActor, leaderId, LActor.getName(actor), LActor.getActorPower(leaderId), 
		crossarenacommon.getScore(actor), crossarenacommon.getWinRate(actor))
end

--删除被邀请的信息
local function delBeInvitation(actor, actorId, leaderId, clear)
	local data = getGlboalBeInvitationData(actor)
	if not data or not data[actorId] then return end
	
	for k, aid in pairs(data[actorId]) do
		if aid == leaderId then
			if not clear then
				table.remove(data[actorId], k)
			end
			local otherData = getActorTeamData(nil, leaderId)
			if not otherData or not otherData.invitation then return end

			otherData.invitation[actorId] = nil
			break
		end
	end
end

--通知邀请结果
local function sendInvitationResult(actor, result)
	if not actor or not result then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_InvitationSuccess)
	if not pack then return end
	LDataPack.writeInt(pack, result)
	LDataPack.flush(pack)
end

--回复邀请
local function onAnswerInvitation(actor, otherId, result)
	local allTeamData = getGlobalTeamData()
	if not allTeamData or not allTeamData[otherId] then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca8)
		return
	end

	if allTeamData[actorId] then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca9)
		return
	end

	local actorId = LActor.getActorId(actor)
	if not allTeamData[otherId].invitation or not allTeamData[otherId].invitation[actorId] then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca10)
		return
	end

	if result == 1 then
		if table.getnEx(allTeamData[otherId].members) > maxMemberCount then
			LActor.sendTipmsg(actor, LAN.FUBEN.ca11)
			delBeInvitation(actor, actorId, otherId)
			return
		end
		if LActor.getFubenId(actor) ~= 0 then
			LActor.sendTipmsg(actor, LAN.FUBEN.ca12)
			delBeInvitation(actor, actorId, otherId)
			return
		end

		allTeamData[otherId].members[actorId] = getActorInfo(actor, actorId)
		delBeInvitation(actor, actorId, otherId, true)
		allTeamData[actorId] = {
			leaderId = otherId,
		}

		sendInvitationResult(actor, 1)
		sendMemberTeamInfo(actor)
	else
		delBeInvitation(actor, actorId, otherId)
	end
end

local function answerInvitation(actor, packet)
	local otherId = LDataPack.readInt(packet)
	local result = LDataPack.readInt(packet)

	onAnswerInvitation(actor, otherId, result)
end

--世界邀请
local function sendWorldInvitation(actor)
	-- local allTeamData = getGlobalTeamData()
	-- local actorId = LActor.getActorId(actor)
	-- if not isLeader(allTeamData, actorId) then return end

	local data = getActorTeamData(actor)
	if not data then return end

	local leaderId = data.leaderId

	local var = crossarenacommon.getActorVar(actor)
	if not var then return end

	local now = System.getNowTime()
	if var.worldCd and var.worldCd >= now then
		LActor.sendTipmsg(actor, string.format(LAN.FUBEN.ca13, var.worldCd - now))
		return
	end

	var.worldCd = now + CrossArenaBase.worldInvitationCd
	broadCastNotice(CrossArenaBase.worldInvitationId, LActor.getName(actor), leaderId)
end

--申请加入队伍
local function applyJoinTeam(actor, packet)
	local otherId = LDataPack.readInt(packet)
	local zsLevel = LActor.getZhuanShengLevel(actor)
	if not crossarenacommon.isOpen() or zsLevel < CrossArenaBase.zhuanshengLevel then return end

	local allTeamData = getGlobalTeamData()
	if not allTeamData then return end
	if not allTeamData[otherId] or allTeamData[otherId].leaderId ~= otherId then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca14)
		return
	end

	if table.getnEx(allTeamData[otherId].members) >= maxMemberCount then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca15)
		return
	end

	local otherActor = LActor.getActorById(otherId)
	if not otherActor then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca16)
		return
	end

	local actorId = LActor.getActorId(actor)
	if allTeamData[actorId] then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca17)
		return
	end

	if LActor.getFubenId(actor) ~= 0 then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca18)
		return false
	end

	if crossarenacommon.getFightCount(actor) < 1 then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca19)
		return false
	end

	if math.abs(crossarenacommon.getScore(actor) - crossarenacommon.getScore(otherActor)) > matchScoreRange then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca20)
		return false
	end

	allTeamData[otherId].members[actorId] = getActorInfo(actor, actorId)
	allTeamData[actorId] = {
		leaderId = otherId,
	}

	sendInvitationResult(actor, 1)
	sendTeamInfo(actor)
	sendMemberTeamInfo(actor)
end

--踢人
local function tickMember(actor, packet)
	local otherId = LDataPack.readInt(packet)

	local actorId = LActor.getActorId(actor)
	local allTeamData = getGlobalTeamData()
	if not isLeader(allTeamData, actorId) then return end

	if not allTeamData[actorId].members then
		actor_log(actor, "tickMember not has members !!!")
		return
	end
	if not allTeamData[actorId].members[otherId] then
		LActor.sendTipmsg(actor, LAN.FUBEN.ca21)
		return
	end

	allTeamData[actorId].members[otherId] = nil
	allTeamData[otherId] = nil

	sendTeamInfo(LActor.getActorById(otherId))
	sendMemberTeamInfo(nil, actorId)
end

--离开队伍 或 解散队伍
local function leaveTeam(actor)
	local actorId = LActor.getActorId(actor)
	local allTeamData = getGlobalTeamData()
	if not allTeamData or not allTeamData[actorId] then return end

	local leaderId = allTeamData[actorId].leaderId
	if not allTeamData[leaderId] then
		actor_log(actor, "leaveTeam not has members !!!!")
		return
	end

	if leaderId == actorId then
		--解散队伍
		for aid, _ in pairs(allTeamData[leaderId].members) do
			if aid ~= leaderId then
				allTeamData[aid] = nil
				sendTeamInfo(LActor.getActorById(aid))
			end
		end

		allTeamData[leaderId] = nil
		sendTeamInfo(actor)
	else
		allTeamData[actorId] = nil
		allTeamData[leaderId].members[actorId] = nil

		sendTeamInfo(actor)
		sendMemberTeamInfo(nil, leaderId)
	end
end

local function sendMatchInfo(actor, isMatch)
	local members = getMembers(actor)
	for aid, _ in pairs(members) do
		local member = LActor.getActorById(aid)
		if member then
			local pack = LDataPack.allocPacket(member, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_MatchInfo)
			if not pack then return end

			LDataPack.writeInt(pack, isMatch or 0)

			LDataPack.flush(pack)
		end
	end
end

--匹配队友
local function beginMatch(actor)
	local actorId = LActor.getActorId(actor)
	local data = getActorTeamData(nil, actorId)
	if not data or data.leaderId ~= actorId or data.match then return end

	local members = data.members
	local count = 0
	local score = 0
	local maxScore = 0
	for aid, v in pairs(members) do
		score = score + v.score
		if maxScore < v.score then
			maxScore = v.score
		end
		count = count + 1

		local member = LActor.getActorById(aid)
		if member and LActor.getFubenId(member) ~= 0 then
			LActor.sendTipmsg(actor, string.format(LAN.FUBEN.ca22, LActor.getName(member)))
			return
		end
	end

	score = math.floor(score / count)
	if score < (maxScore * 0.8) then
		score = maxScore * 0.8
	end

	data.match = 1

	sendMatchInfo(actor, 1)

	--发去跨服匹配
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCCross3vs3)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCCross3vs3_BeginMatch)
	LDataPack.writeInt(pack, actorId)
	LDataPack.writeInt(pack, count)
	for aid, v in pairs(members) do
		LDataPack.writeInt(pack, aid)
		LDataPack.writeInt(pack, v.sId)
		LDataPack.writeInt(pack, v.score)
		LDataPack.writeString(pack, v.name)
		LDataPack.writeInt(pack, v.multiWin)
	end
	LDataPack.writeInt(pack, score)
	System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsMainBattleSrv))
end

--发去跨服 通知停止匹配队友
local function stopMatch(actor, actorId)
	--发去跨服匹配
	local data = getActorTeamData(nil, actorId)
	if not data or not data.match then return end

	data.match = nil
	sendMatchInfo(actor, 0)

	actor_log(actor, "stopMatch")
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCCross3vs3)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCCross3vs3_StopMatch)
	LDataPack.writeInt(pack, data.leaderId)
	LDataPack.writeInt(pack, table.getnEx(data.members))
	System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsMainBattleSrv))
end

local function clientStopMatch(actor)
	local actorId = LActor.getActorId(actor)
	local data = getActorTeamData(nil, actorId)
	if not data or not data.match then return end

	if data.leaderId ~= actorId then return end

	stopMatch(actor, actorId)
end

--请求可邀请的好友或公会成员
local function getCanInvitationMembers(actor, packet)
	local iType = LDataPack.readInt(packet)

	local allMembers = {}
	if iType == 0 then
		--好友
		local list = friendcommon.getList(actor, friendcommon.ltFriend)
		if not list or not list.data then return end

		for actorBId, _ in pairs(list.data) do
			local member = LActor.getActorById(actorBId)
			if member then
				table.insert(allMembers, member)
			end
		end
	else
		local guildId = LActor.getGuildId(actor)
		if guildId == 0 then return end

		allMembers = LGuild.getOnlineActor(guildId) or {}
	end

	local myScore = crossarenacommon.getScore(actor)
	local canInvitationMember = {}
	for _, member in pairs(allMembers) do
		local basicData = LActor.getActorData(member)
		if basicData.zhuansheng_lv >= CrossArenaBase.zhuanshengLevel 
			and math.abs(myScore - crossarenacommon.getScore(member)) <= matchScoreRange
			and crossarenacommon.getFightCount(member) > 0
			and hasTeam(member) == 0 then
			table.insert(canInvitationMember, member)
		end
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Cross3Vs3, Protocol.sCross3Vs3_GuildMember)
	if not pack then return end

	LDataPack.writeInt(pack, iType)
	LDataPack.writeInt(pack, #canInvitationMember)
	for _, member in pairs(canInvitationMember) do
		local basicData = LActor.getActorData(member)
		LDataPack.writeInt(pack, basicData.actor_id)
		LDataPack.writeInt(pack, basicData.vip_level)
		LDataPack.writeInt(pack, basicData.total_power)
		LDataPack.writeByte(pack, basicData.sex)
		LDataPack.writeByte(pack, basicData.job)
		LDataPack.writeString(pack, basicData.actor_name)
		LDataPack.writeInt(pack, basicData.zhuansheng_lv)
		LDataPack.writeInt(pack, crossarenacommon.getScore(member))
		LDataPack.writeInt(pack, crossarenacommon.getWinRate(member))
		LDataPack.writeByte(pack, crossarenacommon.getFightCount(member))
		LDataPack.writeByte(pack, hasTeam(member))
	end

	LDataPack.flush(pack)
end

local function onLogout(actor)
	updateMemberInfo(actor, 0)

	local actorId = LActor.getActorId(actor)
	stopMatch(actor, actorId)

	--删除所有的被邀请信息
	local data = getActorTeamData(actor)
	if not data or not data.beInvitation then return end

	for _, aid in pairs(data.beInvitation) do
		delBeInvitation(actor, actorId, aid, true)
	end

	data.beInvitation = nil
end

CrossArenaFbHandleData = CrossArenaFbHandleData or {}

local function getAllFbHandleData()
	return CrossArenaFbHandleData
end
local function getActorFbHandle(actor)
	local data = getAllFbHandleData()
	return data[LActor.getActorId(actor)]
end

local function onLogin(actor)
	updateMemberInfo(actor, 1)

	sendActorInfo(actor)
	sendTeamInfo(actor)

	local fbHandle = getActorFbHandle(actor)
	if fbHandle then
		-- LActor.loginOtherSrv(actor, csbase.GetBattleSvrId(bsMainBattleSrv), fbHandle, 0, 0, 0)
	end
end

--清空队伍信息
local function delTeamData(actorId)
	local allTeamData = getGlobalTeamData()
	local leaderData = allTeamData[actorId]

	-- print("delTeamData  "..actorId)
	if not leaderData or not leaderData.members then
		-- print("crossarena error not has this actorId data !!!!!!!!!!!!!!")
		return
	end

	for aid, _ in pairs(leaderData.members) do
		if aid ~= actorId then
			allTeamData[aid] = nil
		end
	end

	allTeamData[actorId] = nil
end

--保存竞技场副本hande，并把玩家拉到跨服副本
local function saveFbHandle(sId, sType, dp)
	local actorId = LDataPack.readInt(dp)
	local fbHandle = LDataPack.readInt(dp)

	local data = getAllFbHandleData()
	data[actorId] = fbHandle

	delTeamData(actorId)
	LActor.loginOtherSrv(LActor.getActorById(actorId), csbase.GetBattleSvrId(bsMainBattleSrv), fbHandle, 0, 0, 0)
end



---------------------------跨服-------------------------------------
--[[
	AllBattleMatchTeamData = {	--进入到所有匹配池的初始队伍信息
		[leaderId] = {leaderId, members, score, 
		teamPoolId 所在的队友匹配池idx，被其他队伍取消匹配之后，要返回这个匹配池}
	}

	BattleMatchTeamPool[分配池] = {
		team = {
			[人数个数] = {{time, leaderId, members, score}}
		},
		gid 定时器id
	}

	BattleMatchEnemyPool[分配池] = {
		team = {
			{time, leaderId, members, score, leaderIds 队友匹配池的队长id},
		},
		gid 定时器id
	}
--]]

AllBattleMatchTeamData = AllBattleMatchTeamData or {}	--全部队伍信息
BattleMatchTeamPool = BattleMatchTeamPool or {}		--匹配队友的池
BattleMatchEnemyPool = BattleMatchEnemyPool or {}	--匹配对手的池

local teamPoolConfig = CrossArenaBase.teamPoolScore	--队友匹配档次时间的
local teamPoolTime = CrossArenaBase.teamPoolTime 		--队伍x秒换到下一个奖励池
local eneymyPoolConfig = CrossArenaBase.enemyPoolScore		--对手匹配档次时间的
local enemyPoolTime = CrossArenaBase.enemyPoolTime		--对手x秒换到下一个奖励池

local function getMatchTeamPoolData(pool)
	if not BattleMatchTeamPool[pool] then
		BattleMatchTeamPool[pool] = {}
	end

	return BattleMatchTeamPool[pool]
end
local function getMatchTeamPool(pool)
	local teamPool = getMatchTeamPoolData(pool)

	if not teamPool.team then
		teamPool.team = {}
	end

	return teamPool.team
end

local function getMatchEnemyPoolData(pool)
	if not BattleMatchEnemyPool[pool] then
		BattleMatchEnemyPool[pool] = {}
	end

	return BattleMatchEnemyPool[pool]
end
local function getMatchEnemyPool(pool)
	local enemyPool = getMatchEnemyPoolData(pool)

	if not enemyPool.team then
		enemyPool.team = {}
	end

	return enemyPool.team
end

local function getBattleMatchTeamData(leaderId, clear)
	if clear then
		AllBattleMatchTeamData[leaderId] = nil
		return
	end

	if not AllBattleMatchTeamData[leaderId] then
		AllBattleMatchTeamData[leaderId] = {}
	end

	return AllBattleMatchTeamData[leaderId]
end

local function changeTeamPoolId(leaderId, teamPoolId)
	local data = getBattleMatchTeamData(leaderId)
	data.teamPoolId = teamPoolId
end
local function getTeamPoolId(leaderId)
	local data = getBattleMatchTeamData(leaderId)
	return data.teamPoolId
end

------------------------------------匹配对手-----------------------------
--匹配对手定时器
local function checkAddEnemyTimer(pool, delay)
	local enemyPool = getMatchEnemyPool(pool)
	if not eneymyPoolConfig[pool + 1] or #enemyPool < 1 then return end

	if not delay then
		local nextTime
		for _, v in pairs(enemyPool) do
			if not nextTime or nextTime < v.time then
				nextTime = v.time
			end
		end
		delay = (nextTime - System.getNowTime()) * 1000
	end

	local allData = getMatchEnemyPoolData(pool)
	if allData.gid then
		LActor.cancelScriptEvent(nil, allData.gid)
	end
	allData.gid = LActor.postScriptEventLite(nil, delay, checkChangeEnemyPool, pool)
	print("crossarenamatch checkAddEnemyTimer "..pool.." "..delay.." "..#enemyPool)
end

local function sendFbHandleToComServer(sId, actorId, fbHandle)
	print("crossarena sendFbHandleToComServer  "..sId.." "..actorId.." "..fbHandle)

	local pack = LDataPack.allocPacket()
	LDataPack.writeByte(pack, CrossSrvCmd.SCCross3vs3)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCCross3vs3_SaveActorFbHandle)

	LDataPack.writeInt(pack, actorId)
	LDataPack.writeInt(pack, fbHandle)

	System.sendPacketToAllGameClient(pack, sId)
end

--创建副本
function createCrossArenaFb(team1, team2)
	local fbHandle = Fuben.createFuBen(CrossArenaBase.fbId)
	if not fbHandle or fbHandle == 0 then
		print("crossarena error, createCrossArenaFb fail")
		return
	end

	--返回本服保存玩家的fbHandle，并把玩家拉到跨服副本中
	local ins = instancesystem.getInsByHdl(fbHandle)
	for _, v in pairs(team1.members) do
		ins.data[v.aid] = {camp = 1, srvId = v.sId, actorId = v.aid, score = v.score, name = v.name, multiWin = v.multiWin}

		sendFbHandleToComServer(v.sId, v.aid, fbHandle)
	end

	for _, v in pairs(team2.members) do
		ins.data[v.aid] = {camp = 2, srvId = v.sId, actorId = v.aid, score = v.score, name = v.name, multiWin = v.multiWin}

		sendFbHandleToComServer(v.sId, v.aid, fbHandle)
	end
end

--匹配对手成功
local function matchEnemySuccess(team1, team2)
	for _, leaderId in pairs(team1.leaderIds) do
		getBattleMatchTeamData(leaderId, true)
	end
	for _, leaderId in pairs(team2.leaderIds) do
		getBattleMatchTeamData(leaderId, true)
	end

	createCrossArenaFb(team1, team2)
	-- print("-----------------------")
	-- print(utils.t2s(BattleMatchEnemyPool))
	-- print(utils.t2s(BattleMatchTeamPool))

	-- print("-----------------------")
end

--遍历加入下一个匹配池
function checkChangeEnemyPool(entity, pool)
	local enemyPool = getMatchEnemyPool(pool)
	local count = #enemyPool
	if count < 1 then return end

	local now = System.getNowTime()
	local nextPool = pool + 1
	local range = eneymyPoolConfig[nextPool]
	local nextEnemyPool = getMatchEnemyPool(nextPool)
	for i = count, 1, -1 do
		local enemy = enemyPool[i]
		if not enemy then break end

		if enemy.time <= now then
			--加入下一个匹配池
			--匹配失败 再加入
			local matchSuccess = false
			
			for k, v in pairs(nextEnemyPool) do
				if math.abs(v.score - enemy.score) < range then
					print("crossarenamatch checkChangeEnemyPool matchSuccess "..nextPool.." "..v.leaderId)

					matchEnemySuccess(v, enemy)
					table.remove(nextEnemyPool, k)
					matchSuccess = true
					break
				end
			end

			if not matchSuccess then
				print("crossarenamatch checkChangeEnemyPool insert nextPool "..nextPool.." "..enemy.leaderId)	

				table.insert(nextEnemyPool, enemy)
			end
			table.remove(enemyPool, i)
		end
	end

	local countTmp = #nextEnemyPool
	print("checkChangeEnemyPool "..countTmp)
	if countTmp == 1 then
		checkAddEnemyTimer(nextPool, enemyPoolTime[nextPool])
	end
	checkAddEnemyTimer(pool)
end

--匹配对手
local function onBattleMatchEnemy(leaderId, members, score, leaderIds)
	local now = System.getNowTime()
	local enemyPool = getMatchEnemyPool(1)
	local range = eneymyPoolConfig[1]
	local matchSuccess = false
	for i = 1, #enemyPool do
		local enemy = enemyPool[i]
		if math.abs(score - enemy.score) < range then
			--匹配成功
			print("crossarenamatch onBattleMatchEnemy matchSuccess  "..leaderId)

			matchEnemySuccess(enemy, {leaderId = leaderId, members = members, score = score, leaderIds = leaderIds})
			table.remove(enemyPool, i)
			matchSuccess = true
			break
		end
	end

	if not matchSuccess then
		table.insert(enemyPool, 
			{time = now + enemyPoolTime[1], leaderId = leaderId, members = members, score = score, leaderIds = leaderIds})

		local countTmp = #enemyPool
		print("crossarenamatch onBattleMatchEnemy nextPool "..leaderId.." "..countTmp)
		if countTmp == 1 then
			checkAddEnemyTimer(1)
		end
	end
end


--------------------------------匹配队友---------------------------------
--返回队伍匹配池的队伍个数
local function getPoolTeamCount(pool)
	local teamPool = getMatchTeamPool(pool)
	if not teamPool then return 0 end

	local count = 0
	for i = 1, maxMemberCount do
		count = count + (teamPool[i] and #teamPool[i] or 0)
	end
	return count
end

--匹配队友的定时器
local function checkAddTimer(pool, delay)
	local countTmp = getPoolTeamCount(pool)
	print("crossarenamatch checkAddTimer begin "..pool.." "..countTmp)
	if not teamPoolConfig[pool + 1] or countTmp < 1 then return end

	local teamPool = getMatchTeamPool(pool)
	if not teamPool then return end
	
	if not delay then
		local nextTime = teamPool[1] and teamPool[1][1] and teamPool[1][1].time
		for i = 2, maxMemberCount do
			local tmp = teamPool[i] and teamPool[i][1] and teamPool[i][1].time
			if tmp and (not nextTime or tmp < nextTime) then
				nextTime = tmp
			end
		end
		delay = (nextTime - System.getNowTime()) * 1000
	end

	if delay < 0 then
		return
	end

	local allData = getMatchTeamPoolData(pool)
	if allData.gid then
		LActor.cancelScriptEvent(nil, allData.gid)
	end
	allData.gid = LActor.postScriptEventLite(nil, delay, checkChangeTeamPool, pool)

	print("crossarenamatch checkAddTimer end "..pool.." "..countTmp.." "..delay)
end

--尝试匹配三个单人的
local function matchOnePeople(newInsert, pool, range)
	local teamPool = getMatchTeamPool(pool)
	local oneTeamPool = teamPool[1]
	local scoreTeam = {}
	for _, iv in pairs(newInsert) do
		scoreTeam[iv.leaderId] = {}
		for k, v in ipairs(oneTeamPool) do
			if iv.leaderId == v.leaderId or math.abs(v.score - iv.score) < range then
				table.insert(scoreTeam[iv.leaderId], k)
			end
		end
	end

	local matchSuccess = false
	for leaderId, lv in pairs(scoreTeam) do
		local countTmp = #lv
		if countTmp >= maxMemberCount then
			local score = 0
			local members = {}
			local leaderIds = {}
			for i = countTmp, 1, -1 do
				local k = lv[i]
				score = score + oneTeamPool[k].score
				table.insert(members, oneTeamPool[k].members[1])
				table.insert(leaderIds, oneTeamPool[k].leaderId)
				print("crossarenamatch matchOnePeople check "..pool.." "..#members.." "..oneTeamPool[k].leaderId)

				table.remove(oneTeamPool, k)

				if #members == maxMemberCount then
					onBattleMatchEnemy(members[1].aid, members, math.floor(score / maxMemberCount), leaderIds)
					matchSuccess = true
					break
				end
			end
		end
	end

	if matchSuccess then
		checkAddTimer(pool)
	end
end

--更换队伍匹配池
function checkChangeTeamPool(entity, pool)
	local teamPool = getMatchTeamPool(pool)
	if not teamPool then return end

	local now = System.getNowTime()
	local nextPool = pool + 1
	local nextTeamPool = getMatchTeamPool(nextPool)
	local newInsert = {}	--新加入到下一个匹配池的 {{leaderId, score}}
	local range = teamPoolConfig[nextPool]

	for memberCount = 1, maxMemberCount - 1 do
		if not nextTeamPool[memberCount] then
			nextTeamPool[memberCount] = {}
		end
		
		local leftCount = maxMemberCount - memberCount
		local tmp = teamPool[memberCount] and #teamPool[memberCount] or 0
		for k = tmp, 1, -1 do
			local v = teamPool[memberCount][k]
			if v.time <= now then
				--加入下一层匹配池
				changeTeamPoolId(v.leaderId, nextPool)

				--先尝试匹配1个人和两个人的
				local matchSuccess = false
				for nextK, nextV in pairs(nextTeamPool[leftCount] or {}) do
					if math.abs(v.score - nextV.score) <= range then
						print("crossarenamatch checkChangeTeamPool success "..nextPool.." "..v.leaderId.." "..nextV.leaderId)

						local members = {}
						for _, v1 in pairs(nextV.members) do
							table.insert(members, v1)
						end
						for _, v1 in pairs(v.members) do
							table.insert(members, v1)
						end

						local scoreTmp = math.floor((v.score * #v.members + nextV.score * #nextV.members) / (#v.members + #nextV.members))
						onBattleMatchEnemy(nextV.leaderId, members, scoreTmp, {v.leaderId, nextV.leaderId})
						table.remove(nextTeamPool[leftCount], nextK)
						matchSuccess = true
						break
					end
				end

				if not matchSuccess then
					table.insert(nextTeamPool[memberCount], 
						{time = now + teamPoolTime[nextPool], leaderId = v.leaderId, members = v.members, score = v.score})

					table.insert(newInsert, {leaderId = v.leaderId, score = v.score})

					print("crossarenamatch checkChangeTeamPool "..nextPool.." "..v.leaderId)
					if #v.members == 1 then
						matchOnePeople(newInsert, nextPool, range)
					end		
				end
				table.remove(teamPool[memberCount], k)
			end
		end
	end

	local countTmp = getPoolTeamCount(nextPool)
	if countTmp == 1 then
		checkAddTimer(nextPool, teamPoolTime[nextPool] * 1000)
	end

	--检查下一个定时器的时间
	checkAddTimer(pool)
end

--跨服收到，开始匹配
local function onBattleMatch(sId, sType, dp)
	local actorId = LDataPack.readInt(dp)
	local count = LDataPack.readInt(dp)
	local members = {}
	for i = 1, count do
		members[i] = {}
		members[i].aid = LDataPack.readInt(dp)
		members[i].sId = LDataPack.readInt(dp)
		members[i].score = LDataPack.readInt(dp)
		members[i].name = LDataPack.readString(dp)
		members[i].multiWin = LDataPack.readInt(dp)
	end
	local score = LDataPack.readInt(dp)
	if count >= maxMemberCount then
		--满队员了的， 直接匹配对手
		onBattleMatchEnemy(actorId, members, score, {actorId})
		return
	end

	--匹配队友
	local teamPool = getMatchTeamPool(1)
	if not teamPool[count] then
		teamPool[count] = {}
	end

	--检查是否能找到队伍
	changeTeamPoolId(actorId, 1)
	local canFind = false
	local leftCount = maxMemberCount - count
	if teamPool[leftCount] and #teamPool[leftCount] > 0 then
		for k, v in pairs(teamPool[leftCount]) do
			if math.abs(score - v.score) <= teamPoolConfig[1] then
				--成功匹配
				for _, tmp in pairs(v.members) do
					table.insert(members, tmp)
				end

				local scoreTmp = math.floor((score * count + v.score * #v.members) / (count + #v.members))
				onBattleMatchEnemy(v.leaderId, members, scoreTmp, {v.leaderId, actorId})
				table.remove(teamPool[leftCount], k)
				canFind = true

				print("crossarenamatch onBattleMatch success "..actorId.." "..v.leaderId)
				break
			end
		end
	end

	if not canFind then
		table.insert(teamPool[count],
			{time = System.getNowTime() + teamPoolTime[1], leaderId = actorId, members = members, score = score})

		print("crossarenamatch onBattleMatch nextPool "..actorId.." "..getPoolTeamCount(1))
		if count == 1 then
			matchOnePeople({{leaderId = actorId, score = score}}, 1, teamPoolConfig[1])
		end

		if getPoolTeamCount(1) == 1 then
			checkAddTimer(1, teamPoolTime[1] * 1000)
		end
	end
end

--停止匹配
local function onBattleStopMatch(sId, sType, dp)
	local actorId = LDataPack.readInt(dp)
	local count = LDataPack.readInt(dp)

	print("crossarenamatch onBattleStopMatch "..actorId)
	local now = System.getNowTime()
	--先找对手匹配池
	for pool = 1, #eneymyPoolConfig do
		local enemyPool = getMatchEnemyPool(pool) or {}
		for k, v in pairs(enemyPool) do
			for _, id in pairs(v.leaderIds) do
				if id == actorId then
					for _, leaderId in pairs(v.leaderIds) do
						--把其他的队伍返回队友匹配池
						local teamInfo = getBattleMatchTeamData(leaderId)
						if leaderId ~= actorId and teamInfo.teamPoolId then
							local teamPool = getMatchTeamPool(teamInfo.teamPoolId)
							if not teamPool[#teamInfo.members] then
								teamPool[#teamInfo.members] = {}
							end

							table.insert(teamPool[#teamInfo.members], 
								{time = now + teamPoolTime[teamInfo.teamPoolId], leaderId = teamInfo.leaderId, 
								members = teamInfo.members, score = teamInfo.score})

							print("crossarenamatch onBattleStopMatch enemyPool "..teamInfo.teamPoolId..""..teamInfo.leaderId)
						end
					end

					

					--要不要？？？通知本服停止匹配成功

					table.remove(enemyPool, k)
					return
				end
			end
		end
	end

	--找队友匹配池
	local teamInfo = getBattleMatchTeamData(actorId)
	if not teamInfo.teamPoolId then return end

	local teamPool = getMatchTeamPool(teamInfo.teamPoolId)
	if not teamPool then
		return
	end
	for i = 1, maxMemberCount do
		local poolTmp = teamPool[i] or {}
		for k, v in pairs(poolTmp) do
			if v.leaderId == actorId then
				table.remove(teamPool[i], k)
				getBattleMatchTeamData(actorId, true)
				return
			end
		end
	end
end

local function init()
	if System.isCommSrv() then
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_CreateTeam, createTeam)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_OneMatch, createTeam)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_DissolveTeam, leaveTeam)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_BeginMatch, beginMatch)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_Invitation, invitation)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_WorldInvitation, sendWorldInvitation)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_AnswerInvitation, answerInvitation)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_TickTeam, tickMember)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_CancelMatch, clientStopMatch)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_JoinTeam, applyJoinTeam)
		netmsgdispatcher.reg(Protocol.CMD_Cross3Vs3, Protocol.cCross3Vs3_GuildMember, getCanInvitationMembers)

		csmsgdispatcher.Reg(CrossSrvCmd.SCCross3vs3, CrossSrvSubCmd.SCCross3vs3_SaveActorFbHandle, saveFbHandle)
		
		actorevent.reg(aeUserLogout, onLogout)
		actorevent.reg(aeUserLogin, onLogin)
	else
		csmsgdispatcher.Reg(CrossSrvCmd.SCCross3vs3, CrossSrvSubCmd.SCCross3vs3_BeginMatch, onBattleMatch)
		csmsgdispatcher.Reg(CrossSrvCmd.SCCross3vs3, CrossSrvSubCmd.SCCross3vs3_StopMatch, onBattleStopMatch)
	end
end

table.insert(InitFnTable, init)

local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.camatch = function(actor, args)
	local tmp = tonumber(args[1])
	if tmp == 1 then
		local members = {}
		for i = 1, tonumber(args[3]) do
			members[i] = i
		end
		onBattleMatch(tonumber(args[2]), tonumber(args[3]), members, tonumber(args[4]))
	elseif tmp == 2 then
		AllBattleMatchTeamData = {}
		BattleMatchTeamPool = {}
		BattleMatchEnemyPool = {}
	elseif tmp == 3 then
		GlobalTeamData = {}
	end
end


