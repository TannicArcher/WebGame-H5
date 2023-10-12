module("guildsystem", package.seeall)

require("systems.guild.guildskill")
require("systems.guild.guildtask")
require("systems.guild.guildchat")
require("systems.guild.guildstore")

-- 公会系统

-- 会长，副会长，长老，护法，堂主，精英

local MAX_MEMO_LEN = 128
local MAX_NAME_LEN = 6
local MAX_JOIN_APPLY = 100
local MAX_NEED_FIGHT = 10000000
local DEFAULT_NEED_FIGHT = 99999

local LActor = LActor
local System = System
local LDataPack = LDataPack
local systemId = Protocol.CMD_Guild
local common = guildcommon


shielding = shielding or  false
local langScript = LAN.ScriptTips

function setShielding(b)
	shielding = b
end

local UpdateType = 
{
	dtMapInfo = 1, -- 公会地图
	dtGuildInfo = 2, -- 公会基础
	dtMemberList = 3, -- 成员管理
	dtGuildList = 4, -- 公会列表
	dtGuildApply = 5, -- 申请列表
	dtBuilding = 6, -- 公会建筑
}

local BuildingType = {
	admin = 1,	--管理大厅
	train = 2, 	--练功房
	store = 3,	--商店
	affair = 4,	--议事堂
}
local MAX_BUILDING = 4

GuildLogType =
{
	ltAddMember 		= 1, -- 加入公会：xxx加入公会
	ltLeft 				= 2, -- 离开公会：xxx离开了公会
	ltAppoint 			= 3, -- 副会长任命：会长任命[xxx]为副会长
	ltAbdicate 			= 4, -- 会长禅让：会长禅让给[xxxx]
	ltImpeach 			= 5, -- 会长弹劾：[xxx]弹劾公会会长，成为新的会长
	ltFuben 			= 6, -- 公会副本进度首通：[xxx]首次通关公会副本第N关（仅本公会第一个通关会记录）
	ltDonate 			= 7, -- 元宝/金币捐献：[xxx]捐献了n元宝/金币，获得N贡献
	ltUpgrade 			= 8, -- 建筑升级：[xxx]升级了xx大厅至N级
	ltStore 			= 9, -- 公会商店：年-月-日 时-分 xxx在公会商店获得[xxxx]
	ltkillrobber        = 10,-- 杀死全部强盗
	ltDemoted			= 11,-- 成员降职: [xxx]被降职了。
}

local function log_actor(actor, fmt, ...)
	print(string.format("[%d] ", LActor.getActorId(actor))..string.format(fmt, ...))
end

local function isOpen(actor)
	return LActor.getLevel(actor) >= GuildConfig.openLevel
end

local function changeMemo(guild, memo)
	local guildVar = LGuild.getStaticVar(guild, true)
	guildVar.memo = memo
end

function handleGuildInfo(actor, packet)
	-- 公会ID, 公会名称, 公会建筑等级(array), 公会资金, 公会人数, 公告信息, 成员列表(名字, 职位, 贡献), 我的当前贡献
	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_GuildInfo)
	    LDataPack.writeByte(pack, 0)
	    LDataPack.flush(pack)
		return 
	end

	local guildId = LGuild.getGuildId(guild)
	local guildVar = LGuild.getStaticVar(guild)
	local building = guildVar.building or {}
	local isAuto, needFight = LGuild.getAutoApprove(guild)

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_GuildInfo)
    LDataPack.writeByte(pack, 1)
    LDataPack.writeInt(pack, guildId)
    LDataPack.writeString(pack, LGuild.getGuildName(guild))
    LDataPack.writeByte(pack, MAX_BUILDING)
    for i=1,MAX_BUILDING do
    	LDataPack.writeByte(pack, building[i] or 1)
    end
    LDataPack.writeInt(pack, guildVar.fund or 0) -- 公会资金
    LDataPack.writeString(pack, guildVar.memo or "")
	LDataPack.writeByte(pack, isAuto)
	LDataPack.writeInt(pack, needFight)
	LDataPack.writeShort(pack, guildVar.bonFireLevel or 0)
	LDataPack.writeInt(pack, guildVar.bonFireValue or 0)
	LDataPack.writeInt(pack, LGuild.getChangeNameCount(guild))
	LDataPack.flush(pack)
end

function handleCreateGuild(actor, packet)
	if not isOpen(actor) then return end

	local index = LDataPack.readByte(packet) -- 创建类型索引，从1开始
	local name = LDataPack.readString(packet)

	local sendResult = function(ret, guildId)
		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_CreateGuild)
		LDataPack.writeByte(pack, ret)
		LDataPack.writeInt(pack, guildId)
		LDataPack.flush(pack)
	end

	local conf = GuildCreateConfig[index]
	if not conf then
		log_actor(actor, "create guild conf error : "..index)
		return 
	end

	if conf.vipLv ~= nil and LActor.getVipLevel(actor) < conf.vipLv then
		log_actor(actor, "create guild vip error")
		return 
	end

	local guildId = LActor.getGuildId(actor)
	if guildId ~= 0 then
		log_actor(actor, "create guild error, exist guild : "..guildId)
		return 
	end

	if name == "" or System.getStrLenUtf8(name) > MAX_NAME_LEN then
		log_actor(actor, "create guild error, len")
		return 
	end 

	if not LActorMgr.checkNameStr(name) then
		log_actor(actor, "create guild error, len")
		LActor.sendTipWithId(actor, GuildConfig.nameNoticeId)
		return 
	end

	-- if LGuild.nameHasUsed(name) then
	if LGuild.getGuildByName(name) ~= nil then
		log_actor(actor, "create guild error, used")
		LActor.sendTipWithId(actor, GuildConfig.nameUsedNoticeId)
		return 
	end

	if LActor.getCurrency(actor, conf.moneyType) < conf.moneyCount then
		log_actor(actor, "create guild error, money")
		return 
	end

	LActor.changeCurrency(actor, conf.moneyType, -conf.moneyCount, "create guild")

	local guild = LGuild.createGuild(name, actor)
	if guild == nil then
		log_actor(actor, "create guild error, guild is nil")
		return 
	end
	common.initGuild(guild, conf.buildingLevels)
	changeMemo(guild, GuildConfig.defaultMemo)

	LGuild.addMember(guild, actor, smGuildLeader)
	common.changeContrib(actor, conf.award, "createguild")

	sendResult(0, LGuild.getGuildId(guild))

	--noticemanager.broadCastContent(2, string.format("[%s]创建了%d级公会[%s]，赶紧申请加入吧！", LActor.getName(actor), conf.level, name))


	--公会战的
	guildbattle.onCreateGuild(actor)
end

--公会改名
local function dochangeName(actor, name)
	if not isOpen(actor) then return end

	local pGuild = LActor.getGuildPtr(actor)
	if not pGuild then
		LActor.sendTipmsg(actor, langScript.gcn001, ttMessage)
		return
	end

	if LActor.getGuildPos(actor) ~= smGuildLeader then
		LActor.sendTipmsg(actor, langScript.gcn002, ttMessage)
		return
	end

	local oldGName = LGuild.getGuildName(pGuild)
	if oldGName == name then
		LActor.sendTipmsg(actor, langScript.gcn003, ttMessage)
		return
	end

	if name == "" or System.getStrLenUtf8(name) > MAX_NAME_LEN then
		LActor.sendTipmsg(actor, langScript.gcn004, ttMessage)
		return 
	end 

	if not LActorMgr.checkNameStr(name) then
		LActor.sendTipmsg(actor, langScript.gcn005, ttMessage)
		return 
	end

	if LGuild.getGuildByName(name) ~= nil then
		LActor.sendTipmsg(actor, langScript.gcn006, ttMessage)
		return 
	end

	if LGuild.getChangeNameCount(pGuild) <= 0 then
		LActor.sendTipmsg(actor, langScript.gcn007, ttMessage)
		return 
	end

	local gId = LGuild.getGuildId(pGuild)
	print(LActor.getActorId(actor).." guildsystem.dochangeName gid:"..gId..",name:"..name)
	if LGuild.changeName(pGuild, name) then
		local aId = LActor.getActorId(actor)
		local acName = LActor.getAccountName(actor)
		local strLvl = tostring(LActor.getLevel(actor))
		System.logCounter(aId, acName, strLvl, "guild", tostring(gId), "old:"..oldGName.."|new:"..name, "changeName", "")

		local str = string.format(langScript.gcn008, oldGName, name)
		noticemanager.broadcastNotice(2, str)
	end

	handleGuildInfo(actor, nil)
end

--请求公会改名
local function changeName(actor, packet)
	if not isOpen(actor) then return end
	local name = LDataPack.readString(packet)
	if name == nil then return end
	dochangeName(actor, name)
end

-- 自动同意入会申请设置
function handleAutoApprove(actor, packet)
	local auto = LDataPack.readByte(packet)
	local needFight = LDataPack.readInt(packet)
	-- print("公会设置 ::" .. auto .. ":" .. needFight)
	if needFight < 0 or needFight > MAX_NEED_FIGHT then
		print("max needFight is err")
		return
	end

	local guildPos = LActor.getGuildPos(actor)
	if guildPos < smGuildAssistLeader then
		print("pos limit")
		return
	end

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		print("guild is nil")
		return 
	end

	local g_var = LGuild.getStaticVar(guild)
	g_var.auto = auto
	g_var.needFight = needFight

	LGuild.setAutoApprove(guild, auto, needFight)

	local pack = LDataPack.allocBroadcastPacket(systemId, Protocol.sGuildCmd_AutoApprove)
	if not pack then return end
	LDataPack.writeByte(pack, auto)
	LDataPack.writeInt(pack, needFight)
	LGuild.broadcastData(guild, pack)
end

function notifyUpdateGuildInfo(guild, type, param)
	if not guild then return end
	local pack = LDataPack.allocBroadcastPacket(systemId, Protocol.sGuildCmd_Update)
	if not pack then return end
	LDataPack.writeByte(pack, type)
	--LDataPack.writeInt(pack, param or 0)
	LGuild.broadcastData(guild, pack)
end

local function getMaxMember(guild)
	local guildLevel = common.getGuildLevel(guild)
	local affairLevel = common.getBuildingLevel(guild, BuildingType.affair)

	return (GuildConfig.maxMember[guildLevel] or 0) + (GuildConfig.affairMember[affairLevel] or 0)
end

-- 申请加入
function handleApplyJoin(actor, packet)
	if shielding then 
		return 
	end
	if not isOpen(actor) then return end

	if LActor.getGuildId(actor) ~= 0 then
		log_actor(actor, "exist guild")
		return 
	end

	local guildId = LDataPack.readInt(packet)
	local guild = LGuild.getGuildById(guildId)
	if guild == nil then
		log_actor(actor, "guild is not exist, "..guildId)
		return 
	end

	local actorId = LActor.getActorId(actor)
	if LGuild.getJoinMsg(guild, actorId) then
		log_actor(actor, "has apply once")
		return 
	end

	local isAuto, needFight = LGuild.getAutoApprove(guild)
	if isAuto == 1 then
		local actorId = LActor.getActorId(actor)
		local actorFight = LActor.getActorPower(actorId)
		if actorFight < needFight then
			log_actor(actor, "fight is less " .. actorFight .. ":" .. needFight)
			
			local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_JoinResult)
			if not pack then return end
			LDataPack.writeInt(pack, guildId)
			LDataPack.writeByte(pack, 0)
			LDataPack.flush(pack)
			return
		end

		-- 最大人数限制
		if LGuild.getGuildMemberCount(guild) < getMaxMember(guild) then
			LGuild.addMember(guild, actor, smGuildCommon)
			LGuild.addGuildLog(guild, GuildLogType.ltAddMember, LActor.getName(actor))

			local tips = string.format("欢迎[%s]加入公会，大家撒花、鼓掌", LActor.getName(actor))
			guildchat.sendNotice(guild, tips)
			
			notifyUpdateGuildInfo(guild, UpdateType.dtMemberList)
			return
		end
	end

	LGuild.postJoinMsg(guild, actor)

	local pack = LDataPack.allocBroadcastPacket(systemId, Protocol.sGuildCmd_Join)
	if not pack then return end
	LDataPack.writeInt(pack, actorId)
	LGuild.broadcastData(guild, pack)
	notifyUpdateGuildInfo(guild, UpdateType.dtGuildApply)
end

-- 回应加入申请
function handleRespondJoin(actor, packet)
	if shielding then 
		return
	end
	local applyId = LDataPack.readInt(packet)
	local ret = LDataPack.readByte(packet)

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then print("guild is nil") return end

	if not LGuild.getJoinMsg(guild, applyId) then
		log_actor(actor, "not apply")
		return 
	end

	-- LGuild.removeJoinMsg(guild, applyId)

	local applyer = LActor.getActorById(applyId)
	--if applyer == nil then
	--	if ret == 1 then -- 如果是同意申请就提示一下
	--		LActor.sendTipWithId(actor, GuildConfig.joinOfflineNoticeId)
	--	end
	--	return
	--end

	--if LActor.getGuildId(applyer) ~= 0 then
	--	LActor.sendTipWithId(actor, GuildConfig.joinOtherGuildNoticeId)
	--	-- log_actor(actor, "has join guild")
	--	return
	--end

	if ret == 1 then
		local function addMember(actor, gid, invitorId)
			local guild = LGuild.getGuildById(gid)
			if guild == nil then return end

			local actorId = LActor.getActorId(actor)
			local guildId = LActor.getGuildId(actor)
			local invitor = LActor.getActorById(invitorId)
			if guildId ~= 0 then
				if invitor then
					LActor.sendTipWithId(invitor, GuildConfig.joinOtherGuildNoticeId)
				end
				LGuild.removeJoinMsg(guild, actorId)
				return
			end

			-- 最大人数限制
			if LGuild.getGuildMemberCount(guild) >= getMaxMember(guild) then
				if invitor then
					LActor.sendTipWithId(invitor, GuildConfig.guildMaxMemberNoticeId)
				end
				log_actor(actor, "max member")
				return
			end

			LGuild.removeJoinMsg(guild, actorId)
			LGuild.addMember(guild, actor, smGuildCommon)
			LGuild.addGuildLog(guild, GuildLogType.ltAddMember, LActor.getName(actor))

			local tips = string.format("欢迎[%s]加入公会，大家撒花、鼓掌", LActor.getName(actor))
			guildchat.sendNotice(guild, tips)

			if invitor then
				local pack = LDataPack.allocPacket(invitor, systemId, Protocol.sGuildCmd_JoinResult)
				if not pack then return end
				LDataPack.writeInt(pack, guildId)
				LDataPack.writeByte(pack, 1) --同意
				LDataPack.flush(pack)
			end


			guildbattle.onAddGuild(actor)
		end

		asynevent.reg(applyId, addMember, LGuild.getGuildId(guild), LActor.getActorId(actor))

		-- 最大人数限制
		--if LGuild.getGuildMemberCount(guild) >= getMaxMember(guild) then
		--	log_actor(actor, "max member")
		--	return
		--end

		--LGuild.addMember(guild, applyer, smGuildCommon)
		--LGuild.addGuildLog(guild, GuildLogType.ltAddMember, LActor.getName(applyer))

		--local tips = string.format("欢迎[%s]加入公会，大家撒花、鼓掌", LActor.getName(applyer))
		--guildchat.sendNotice(guild, tips)
	else
		LGuild.removeJoinMsg(guild, applyId)
		local guildId = LGuild.getGuildId(guild)

		if applyer then
			local pack = LDataPack.allocPacket(applyer, systemId, Protocol.sGuildCmd_JoinResult)
			if not pack then return end
			LDataPack.writeInt(pack, guildId)
			LDataPack.writeByte(pack, 0)
			LDataPack.flush(pack)
			print("handleRespondJoin reject:" .. applyId)
		else
			print("handleRespondJoin not online:" .. applyId)
		end
	end

	notifyUpdateGuildInfo(guild, UpdateType.dtMemberList)
	notifyUpdateGuildInfo(guild, UpdateType.dtGuildApply)
end

-- 弹劾
function handleImpeach(actor, packet)
	if shielding then 
		return
	end
	local guildPos = LActor.getGuildPos(actor)
	if guildPos < smGuildTz then
		print("pos limit")
		return -- 堂主及以上官员
	end

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then print("guild is nil") return end

	local actorId = LActor.getActorId(actor)
	local leaderId = LGuild.getLeaderId(guild)

	local name, _, _, _, lastLogoutTime = LGuild.getMemberInfo(guild, leaderId)
	if lastLogoutTime == nil then
		log_actor(actor, "lastLogoutTime is nil")
		return 
	end

	if System.getNowTime() - lastLogoutTime < GuildConfig.impeachTime then
		log_actor(actor, "impeach time error")
		return 
	end

	if LActor.getCurrency(actor, NumericType_YuanBao) < GuildConfig.impeachCost then
		log_actor(actor, "no enough money")
		return 
	end

	LActor.changeCurrency(actor, NumericType_YuanBao, -GuildConfig.impeachCost, "impeach")

	LGuild.changeGuildPos(guild, leaderId, smGuildCommon)
	LGuild.changeGuildPos(guild, actorId, smGuildLeader)

	notifyUpdateGuildInfo(guild, UpdateType.dtMemberList)

	LGuild.addGuildLog(guild, GuildLogType.ltImpeach, name or "")

	local content = string.format(GuildConfig.impeachMailContext, LActor.getName(actor))
    local mailData = {head=GuildConfig.impeachMailTitle, context = content, tAwardList={} }

    LActor.log(leaderId, "guildsystem.handleImpeach", "sendMail")
    mailsystem.sendMailById(leaderId, mailData)

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChangePos)
	if not pack then return end
	LDataPack.writeInt(pack, actorId)
	LDataPack.writeByte(pack, smGuildLeader)
	LDataPack.flush(pack)
end

-- 禅让/降职/任命副会长
function handleChangePos(actor, packet)
	if shielding then 
		return
	end
	local targetId = LDataPack.readInt(packet)
	local pos = LDataPack.readByte(packet)

	local guildPos = LActor.getGuildPos(actor)
	if guildPos ~= smGuildLeader then
		log_actor(actor, "guild pos error : "..guildPos)
		return 
	end

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		log_actor(actor, "guild is nil")
		return 
	end
	
	if not LGuild.isMember(guild, targetId) then
		LActor.sendTipmsg(actor, langScript.gcn014, ttScreenCenter)
		return
	end

	local actorId = LActor.getActorId(actor)

	if pos == smGuildLeader then -- 禅让
		if LGuild.getGuildPos(guild, targetId) ~= smGuildAssistLeader then
			log_actor(actor, "guild pos error")
			return 
		end
		LGuild.changeGuildPos(guild, actorId, smGuildAssistLeader)
		LGuild.changeGuildPos(guild, targetId, smGuildLeader)

		local name = LGuild.getMemberInfo(guild, targetId)
		LGuild.addGuildLog(guild, GuildLogType.ltAbdicate, name or "");

		local tips = string.format("%s禅让会长给%s", LActor.getName(actor), name)
		guildchat.sendNotice(guild, tips)
		
		common.sendBasicInfo(actor)
		
		local targetActor = LActor.getActorById(targetId)
		if targetActor then
			common.sendBasicInfo(targetActor)
		end

	elseif pos == smGuildAssistLeader then -- 任命副会长
		local guildLevel = common.getGuildLevel(guild)
		local countsConfig = GuildConfig.posCounts[guildLevel]
		if countsConfig == nil then
			print("countsConfig is nil")
			return 
		end
		local maxAssist = countsConfig[2] or 0 -- 2表示是副会长
		local assistLeaderList = LGuild.getAssistLeaderIdList(guild)
		local count = (assistLeaderList == nil and 0 or #assistLeaderList)
		if count >= maxAssist then
			print("max assist")
			return 
		end

		LGuild.changeGuildPos(guild, targetId, smGuildAssistLeader)

		local name = LGuild.getMemberInfo(guild, targetId)
		LGuild.addGuildLog(guild, GuildLogType.ltAppoint, name or "")

		local tips = string.format("任命%s为公会副会长", name)
		guildchat.sendNotice(guild, tips)
	else -- 降职
		if LGuild.getGuildPos(guild, targetId) ~= smGuildAssistLeader then
			log_actor(actor, "guild pos error")
			return 
		end
		LGuild.changeGuildPos(guild, targetId, smGuildCommon) -- 以后再根据贡献排职位
		local name = LGuild.getMemberInfo(guild, targetId)
		LGuild.addGuildLog(guild, GuildLogType.ltDemoted, name or "")
	end

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChangePos)
	if not pack then return end
	LDataPack.writeInt(pack, targetId)
	LDataPack.writeByte(pack, pos)
	LDataPack.flush(pack)

	notifyUpdateGuildInfo(guild, UpdateType.dtMemberList)
end

local function sendExitGuild(actor, targetId)
	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_Exit)
	LDataPack.writeInt(pack, targetId)
	LDataPack.flush(pack)
end

-- 踢出
function handleKick(actor, packet)
	if shielding then 
		return
	end
	local targetId = LDataPack.readInt(packet)

	local guildPos = LActor.getGuildPos(actor)
	if guildPos ~= smGuildLeader and guildPos ~= smGuildAssistLeader then
		log_actor(actor, "guild pos error : "..guildPos)
		return 
	end

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		log_actor(actor, "guild is nil")
		return 
	end

	local targetPos = LGuild.getGuildPos(guild, targetId)
	if targetPos == smGuildLeader or (targetPos == smGuildAssistLeader and guildPos ~= smGuildLeader) then
		log_actor(actor, "guild pos error : "..guildPos)
		return 
	end

	local name = LGuild.getMemberInfo(guild, targetId)
	if name == nil then
		print("kick error, not member")
		return 
	end

	LGuild.deleteMember(guild, targetId)

	LGuild.addGuildLog(guild, GuildLogType.ltLeft, name);

	local targetActor = LActor.getActorById(targetId)
	if targetActor ~= nil then
		sendExitGuild(targetActor, targetId)
	end
	sendExitGuild(actor, targetId)

	local mailData = {head=GuildConfig.kickMailTitle, context = GuildConfig.kickMailContext, tAwardList={} }
    mailsystem.sendMailById(targetId, mailData)
	
	notifyUpdateGuildInfo(guild, UpdateType.dtMemberList)
end

function handleExit(actor, packet)
	if shielding then 
		return
	end
	local guild = LActor.getGuildPtr(actor)
	if guild == nil then print("guild is nil") return end

	local actorId = LActor.getActorId(actor)
	local isLeader = (LGuild.getLeaderId(guild) == actorId)

	if isLeader and LGuild.getGuildMemberCount(guild) > 1 then
		return --2017年7月11日 15:31:48 策划彪 决定修改为,必须先禅让才能退出
	end
	
	LGuild.deleteMember(guild, actorId) -- 玩家都是在线的，不会走到异步流程，下面获得的人数是正确的
	LGuild.addGuildLog(guild, GuildLogType.ltLeft, LActor.getName(actor));

	if LGuild.getGuildMemberCount(guild) <= 0 then
		guildboss.onDeleteGuild(guild)
		LGuild.deleteGuild(guild, "no member")
	--elseif isLeader then
		--[[ 如果是会长,会长之位自动转移给历史贡献最大的公会成员，如果贡献度一样，则按玩家id来
		local newLeaderId = LGuild.getLargestContribution(guild)
		if newLeaderId ~= 0 then
			LGuild.changeGuildPos(guild, newLeaderId, smGuildLeader)
		end
		]]
	end
	
	sendExitGuild(actor, LActor.getActorId(actor))
	
	notifyUpdateGuildInfo(guild, UpdateType.dtMemberList)
end

-- 获取捐献次数
local function getDanoteCount(actor, index)
	local actorData = common.getActorVar(actor)
	local danoteCounts = actorData.danoteCounts
	if danoteCounts == nil then return 0 end

	return danoteCounts[index] or 0
end

-- 获取对应vip每日最大捐献次数
local function getDonateDayCount(index, vip)
	local conf = GuildDonateConfig[index]
	if conf == nil then print("conf is nil") return 0 end

	if vip == nil then return 0 end

	if type(conf.dayCount) == "number" then
		return conf.dayCount
	end

	local dayCount = conf.dayCount[vip+1]
	if dayCount then
		return dayCount
	else
		dayCount = conf.dayCount[#conf.dayCount]
		if not dayCount then
			print("vip count is nil" .. index .. ":" .. vip)
			return 0
		end
		return dayCount
	end
end

-- 
local function sendLeftDonateCount(actor)
	local actorData = common.getActorVar(actor)
	local danoteCounts = actorData.danoteCounts or {}

	local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_DonateCount)
	LDataPack.writeByte(pack, #GuildDonateConfig)
	local vip = LActor.getVipLevel(actor)
	for i=1,#GuildDonateConfig do
		local dayCount = getDonateDayCount(i, vip) or 0
		--print("leftcount", i, vip, dayCount, danoteCounts[i])
		LDataPack.writeInt(pack, dayCount - (danoteCounts[i] or 0))
	end
	LDataPack.flush(pack)
end

local function changeDanoteCount(actor, index, count, isSend)
	local actorData = common.getActorVar(actor)
	local danoteCounts = actorData.danoteCounts
	if danoteCounts == nil then
		actorData.danoteCounts = {}
		danoteCounts = actorData.danoteCounts
	end

	local danoteCount = danoteCounts[index] or 0
	danoteCounts[index] = danoteCount + count
	LActor.log(actor, "guildsystem.changeDanoteCount", "make1", danoteCounts[index], index)

	if danoteCounts[index] < 0 then
		danoteCounts[index] = 0
	end

	if isSend then
		sendLeftDonateCount(actor)
	end
end

local function resetDonateCount(actor)
	local actorData = common.getActorVar(actor)
	actorData.danoteCounts = {}
end

-- 捐献
function handleDonate(actor, packet)
	local index = LDataPack.readByte(packet) -- 捐献类型
	local conf = GuildDonateConfig[index]
	if conf == nil then print("conf is nil") return end

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then print("guild is nil") return end

	local vip = LActor.getVipLevel(actor)
	local dayCount = getDonateDayCount(index, vip) or 0
	if not dayCount then
		print("vip count is nil" .. vip)
		return
	end

	if getDanoteCount(actor, index) >= dayCount then
		log_actor(actor, "no donate times")
		return 
	end

	if conf.type == AwardType_Numeric then -- 捐献货币
		if LActor.getCurrency(actor, conf.id) < conf.count then
			log_actor(actor, "no enough money")
			return 
		end

		LActor.changeCurrency(actor, conf.id, -conf.count, "guild donate")

		local taskType = (conf.id == NumericType_YuanBao and guildtask.emDonateYuanBao or guildtask.emDonateGold)

		LGuild.addGuildLog(guild, GuildLogType.ltDonate, LActor.getName(actor), "", conf.id, conf.count, conf.awardContri); -- [xxx]捐献了n元宝/金币，获得N贡献
	elseif conf.type == AwardType_Item then -- 捐献道具
		if LActor.getItemCount(actor, conf.id) < conf.count then
			log_actor(actor, "no enough item, "..conf.id)
			return 
		end

		LActor.costItem(actor, conf.id, conf.count, "guild donate")
	else
		log_actor(actor, "donate type error")
		return 
	end

	actorevent.onEvent(actor, aeGuildDonate, conf.type, conf.id, conf.count) 

	changeDanoteCount(actor, index, 1, true)
	common.changeContrib(actor, conf.awardContri, "Donate")
	common.changeGuildFund(guild, conf.awardFund, actor)

	LActor.sendTipmsg(actor, string.format("公会贡献 +%d", conf.awardContri), ttScreenCenter)
	LActor.sendTipmsg(actor, string.format("公会资金 +%d", conf.awardFund), ttScreenCenter)
end

function handleDonateBonFire(actor, packet)
	local actorId = LActor.getActorId(actor)
	local guild = LActor.getGuildPtr(actor)
	local needCount = LDataPack.readShort(packet)
	if nil == guild then print("guildsystem.handleDonateBonFire: guild is nil, actorId:"..tostring(actorId)) return end

	local curCount = LActor.getItemCount(actor, GuildConfig.bonfireItem)
	if needCount > curCount then
		print("guildsystem.handleDonateBonFire: item is not enough, needCount:"..tostring(needCount)..", actorId:"..tostring(actorId))
		return
	end

	LActor.costItem(actor, GuildConfig.bonfireItem, needCount, "bonfire")

	local reward = LActor.getRewardByTimes(GuildConfig.bonfireReward, needCount)
	LActor.giveAwards(actor, reward, "bonfire rewards")

	actorevent.onEvent(actor, aeGuildDonate, AwardType_Item, GuildConfig.bonfireItem, needCount)

	guildcommon.changeGuildBonFire(guild, GuildConfig.bonfireValue*needCount, actor)
end

-- 发送捐献次数
function handleDonateCount(actor, packet)
	sendLeftDonateCount(actor)
end

-- 获取公会基本信息
function handleBasicInfo(actor, packet)
	if not isOpen(actor) then return end

	common.sendBasicInfo(actor)
end

-- 修改公告
function handleChangeMemo(actor, packet)
	local memo = LDataPack.readString(packet)

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		log_actor(actor, "guild is nil")
		return 
	end

	local sendResult = function(ret, str)
		local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_ChangeMemoResult)
	    LDataPack.writeByte(pack, ret)
	    LDataPack.writeString(pack, str or "")
	    LDataPack.flush(pack)
	end

	local guildPos = LActor.getGuildPos(actor)
	if guildPos ~= smGuildLeader and guildPos ~= smGuildAssistLeader then
		log_actor(actor, "guild pos error : "..guildPos)
		return 
	end

	if System.getStrLenUtf8(memo) > MAX_MEMO_LEN then
		log_actor(actor, "memo len error")
		sendResult(-1)
		return 
	end

	local memo = System.filterText(memo)
	changeMemo(guild, memo)
	sendResult(0, memo)
	notifyUpdateGuildInfo(guild, UpdateType.dtGuildInfo)
end

-- 升级建筑
function handleUpgradeBuilding(actor, packet)
	local index = LDataPack.readByte(packet)

	local buildingConfig = GuildLevelConfig[index]
	if buildingConfig == nil then
		log_actor(actor, "building index error : "..index)
		LActor.sendTipmsg(actor, langScript.gcn009, ttScreenCenter)
		return
	end

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then print("guild is nil") return end

	local buildingLevel = common.getBuildingLevel(guild, index)
	if buildingLevel >= #buildingConfig then
		log_actor(actor, "max level")
		LActor.sendTipmsg(actor, langScript.gcn010, ttScreenCenter)
		return 
	end

	if index ~= 1 then
		local hallLevel = common.getBuildingLevel(guild, 1)
		if buildingLevel >= hallLevel then
			log_actor(actor, "hall level need")
			LActor.sendTipmsg(actor, langScript.gcn011, ttScreenCenter)
			return
		end
		if index == 3 and (System.getOpenServerDay() + 1) < GuildStoreConfig.day then
			log_actor(actor, "openday limit")
			LActor.sendTipmsg(actor, string.format(langScript.gcn012,GuildStoreConfig.day), ttScreenCenter)
			return
		end
	end

	local nextLevelConfig = buildingConfig[buildingLevel + 1]
	local guildVar = LGuild.getStaticVar(guild)
	local guildFund = guildVar.fund or 0
	local needFund = nextLevelConfig.upFund
	if guildFund < needFund then
		log_actor(actor, "no enough fund")
		LActor.sendTipmsg(actor, langScript.arousal013, ttScreenCenter)
		return 
	end

	common.changeGuildFund(guild, -needFund, actor)

	buildingLevel = buildingLevel + 1
	LActor.log(actor, "guildsystem.changeDanoteCount", "make1", LGuild.getGuildId(guild), buildingLevel, index)
	common.updateBuildingLevel(guild, index, buildingLevel)
	guildstore.storeLevelChange(actor)
	--notifyUpdateGuildInfo(guild, UpdateType.dtBuilding)
	LGuild.addGuildLog(guild, GuildLogType.ltUpgrade, LActor.getName(actor), "", index, buildingLevel)

	--local pack = LDataPack.allocPacket(actor, systemId, Protocol.sGuildCmd_UpgradeBuilding)
    --LDataPack.writeByte(pack, index)
    --LDataPack.writeByte(pack, buildingLevel)
    --LDataPack.flush(pack)

    guildcommon.broadcastBuildLevel(guild, buildingLevel, index)

    local tips = string.format("[%s]升级了[%s]至Lv.%d", LActor.getName(actor), GuildConfig.buildingNames[index], buildingLevel)
    guildchat.sendNotice(guild, tips)
end

function onLogin(actor)
	local guildId = LActor.getGuildId(actor)
	if guildId == 0 then return end

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then return end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_GuildInfo)
    LDataPack.writeInt(pack, guildId)
    LDataPack.writeString(pack, LGuild.getGuildName(guild))
    LDataPack.flush(pack)
end

function onLogout(actor)
	-- 
end

function onJoinGuild(actor)
	common.resetContrib(actor)
	guildtask.sendTaskInfoList(actor)
end

function onLeftGuild(actor)
	common.resetContrib(actor)
end

function onNewDay(actor)
	resetDonateCount(actor)
end

local function onAchievetaskFinish(actor,achieveId,taskId)
	if not actor then return end
	if achieveId == GuildConfig.guildGiftCondition.achievementId and taskId == GuildConfig.guildGiftCondition.taskId then
		local mailData = {head=GuildConfig.guildGiftTitle, context=GuildConfig.guildGiftContent, tAwardList=GuildConfig.guildGiftAward}
        mailsystem.sendMailById(LActor.getActorId(actor), mailData)
	end
end

-- 每天6点根据贡献排职位
function updateAllGuildPos()
	print("updateAllGuildPos")
	local guildList = LGuild.getGuildList()
	if guildList == nil then return end

	for i=1,#guildList do
		local guild = guildList[i]
		LGuild.updateGuildPos(guild)
	end
end

-- 每天凌晨清数据
function updateGuildData()
	print("updateGuildData")
	local guildList = LGuild.getGuildList()
	if guildList == nil then return end

	for i=1,#guildList do
		local guild = guildList[i]
		LGuild.resetTodayContrib(guild)
		guildfuben.clearGuildfbVar(guild)
		guildcommon.resetBonFire(guild)
	end
end

-- 公会脚本数据加载完成后的处理
function onLoadGuildVar(guild)
	common.initBuildingLevel(guild,GuildCreateConfig[1].buildingLevels)

	local g_var = LGuild.getStaticVar(guild)
	LGuild.setAutoApprove(guild, g_var.auto or 0, g_var.needFight or 0)
end

-- 公会数据加载完成后的处理
function onLoadGuild(guild)
	-- 
end

--初始化
local function initGlobalData()
    timedomain.regStart("*.*.*-0:0 ^ *.*.*-6:0", updateGuildData) -- 0点触发
    timedomain.regEnd("*.*.*-0:0 ^ *.*.*-6:0", updateAllGuildPos) -- 6点触发，以后可以做成配置的
end

table.insert(InitFnTable, initGlobalData)

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeUserLogout, onLogout)
actorevent.reg(aeJoinGuild, onJoinGuild)
actorevent.reg(aeLeftGuild, onLeftGuild)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeAchievetaskFinish, onAchievetaskFinish)

netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_GuildInfo, handleGuildInfo)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_CreateGuild, handleCreateGuild)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ExitGuild, handleExit)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ApplyJoin, handleApplyJoin)
-- netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ApplyInfo, handle
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_RespondJoin, handleRespondJoin)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ChangePos, handleChangePos)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_Impeach, handleImpeach)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_Kick, handleKick)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_Donate, handleDonate)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ChangeMemo, handleChangeMemo)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_SkillInfo, guildskill.handleSkillInfo)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_UpgradeSkill, guildskill.handleUpgradeSkill)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_PracticeBuilding, guildskill.handlePracticeSkill)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_UpgradeBuilding, handleUpgradeBuilding)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_DonateCount, handleDonateCount)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_BasicInfo, handleBasicInfo)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_AutoApprove, handleAutoApprove)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_DonateBonFire, handleDonateBonFire)
netmsgdispatcher.reg(systemId, Protocol.cGuildCmd_ChangeName, changeName)

_G.onLoadGuild = onLoadGuild
_G.onLoadGuildVar = onLoadGuildVar

local gmsystem    = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

gmCmdHandlers.testguild = function(actor, args)
	-- local dp = LDataPack.allocPacket()
	-- LDataPack.writeByte(dp, 1)
	-- LDataPack.writeString(dp, "fffxx")
	-- LDataPack.setPosition(dp, 0)

	-- handleCreateGuild(actor, dp)

	-- common.changeContrib(actor, 100)
	-- local guild = LActor.getGuildPtr(actor)
	-- common.changeGuildFund(guild, 1000)
	-- updateAllGuildPos()

	-- local content = args[1] or ""

	-- local guild = LActor.getGuildPtr(actor)
	-- if guild == nil then print("guild is nil") return end

	-- guildchat.sendNotice(guild, content)

	-- print(LActor.getGuildId(actor))
	-- updateGuildData()
	-- updateAllGuildPos()

	local value = (args[1] and tonumber(args[1]) or 0)
	common.changeContrib(actor, value, "gmtest")
end

-- 删除公会
-- @delguild 公会名
gmCmdHandlers.delguild = function(actor, args)
	local name = args[1]
	if name == nil then
		print("param error")
		return 
	end
	local guild = LGuild.getGuildByName(name)
	if guild == nil then
		print("guild is nil")
		return 
	end

	LGuild.deleteGuild(guild, "gm")
end

-- 修改职位
-- @changeguildpos 公会名 玩家ID 职位
gmCmdHandlers.changeguildpos = function(actor, args)
	local guildName, actorId, pos = args[1], args[2], args[3]
	if guildName == nil or actorId == nil or pos == nil then
		print("param error")
		return 
	end

	local guild = LGuild.getGuildByName(guildName)
	if guild == nil then
		print("guild is nil")
		return 
	end

	actorId = tonumber(actorId)
	pos = tonumber(pos)

	LGuild.changeGuildPos(guild, actorId, pos)
end

-- 删除公会成员
-- @delguildmember 公会名 玩家ID
gmCmdHandlers.delguildmember = function(actor, args)
	local name, actorId = args[1], args[2]
	if name == nil then
		print("param error")
		return false
	end
	local guild = LGuild.getGuildByName(name)
	if guild == nil then
		print("guild is nil")
		return false
	end

	actorId = tonumber(actorId)

	LGuild.deleteMember(guild, actorId)

	return true
end

-- 添加公会成员(需要在线)
-- @addguildmember 公会名 玩家ID 职位
gmCmdHandlers.addguildmember = function(actor, args)
	local name, actorId, pos = args[1], args[2], args[3]
	if name == nil then
		print("param error")
		return false
	end
	local guild = LGuild.getGuildByName(name)
	if guild == nil then
		print("guild is nil")
		return false
	end

	actorId = tonumber(actorId)
	pos = (pos and tonumber(pos) or smGuildCommon)

	local target = LActor.getActorById(actorId)
	if target == nil then
		print("target is offline")
		return 
	end

	LGuild.addMember(guild, target, pos)

	return true
end

-- 增加公会资金
-- @addguildfund 公会资金
gmCmdHandlers.addguildfund = function(actor, args)
	local value = args[1]
	if value == nil then
		print("param error")
		return false
	end

	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		print("guild is nil")
		return false
	end

	common.changeGuildFund(guild, tonumber(value), actor)

	return true
end

-- 增加公会贡献
-- @addguildgx 公会贡献
gmCmdHandlers.addguildgx = function(actor, args)
	local value = args[1]
	if value == nil then
		print("param error")
		return false
	end

	common.changeContrib(actor, tonumber(value), "gm")

	return true
end


-- 升级公会建筑
-- @upgradeBuilding 
gmCmdHandlers.upgradeBuilding = function(actor, args)
	local pack = LDataPack.allocPacket()
	LDataPack.writeInt(pack, args[1] or 1)
	LDataPack.setPosition(pack, 0)
	handleUpgradeBuilding(actor, pack)

	return true
end

gmCmdHandlers.addguildbonfire = function(actor)
	handleDonateBonFire(actor)
	return true
end

gmCmdHandlers.changeGuildName = function(actor, arg)
	local name = arg[1]
	dochangeName(actor, name)
end

--设置公会改名次数
gmCmdHandlers.setGCN = function(actor, arg)
	local count = tonumber(arg[1])
	local pGuild = LActor.getGuildPtr(actor)
	if not pGuild then
		return false
	end
	LGuild.setChangeNameCount(pGuild, count)
	return true
end

