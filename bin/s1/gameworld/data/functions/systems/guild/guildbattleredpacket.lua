module("guildbattleredpacket", package.seeall)

day_sec = utils.day_sec

local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	if var.guild_battle_red_packet == nil then 
		var.guild_battle_red_packet = {}
	end
	return var.guild_battle_red_packet
end

local function initData(actor)
	local var = getData(actor)
	--[[
	if var.get_red_packet == nil then 
		var.get_red_packet = 0
		--是否领取过红包
	end
	]]
end

local function getGlobalData(actor)
	local var = System.getStaticVar()
	if var == nil then 
		return nil
	end
	if var.guild_battle_red_packet == nil then 
		var.guild_battle_red_packet = {}
	end
	return var.guild_battle_red_packet
end

local function initGlobalData()
	local var = getGlobalData()
end

local function initGuildData(guild_id)
	System.log("guildbattleredpacket", "initGuildData", "call", guild_id)
	if guild_id == 0 then 
		return
	end
	local var = getGlobalData()
	if var[guild_id] == nil then 
		var[guild_id] = {}
	end

	if var[guild_id].yuan_bao == nil then 
		--有多少元宝
		var[guild_id].yuan_bao = 0
	end

	if var[guild_id].send_time == nil then 
		var[guild_id].send_time = 0
		--发送时间
	end

	if var[guild_id].red_packet == nil then 
		var[guild_id].red_packet = {}
		--红包数据
		--
		--[[
		yuan_bao -- 元宝
		]]
	end
	if var[guild_id].begin_index == nil then 
		var[guild_id].begin_index = 0
		--开始index
	end
	if var[guild_id].end_index == nil then 
		var[guild_id].end_index = 0
		--结束index
	end

	if var[guild_id].red_packet_msg == nil then 
		var[guild_id].red_packet_msg = {}
		--red_packet_msg
		--[[
			yuan_bao -- 元宝
			name --名字
			actor_id
		]]
	end

	if var[guild_id].msg_size == nil then 
		var[guild_id].msg_size = 0
		--消息大小
	end

	if var[guild_id].red_packet_total_yuan_bao == nil  then
		var[guild_id].red_packet_total_yuan_bao = 0
	end
	
end

function isGetRedPacket(guild_id,actor_id)
	if redPacketEmpyt(guild_id) then 
		return true
	end
	local var = getRedPacketData(guild_id)
	local ret = false
	for i,v in pairs(var.red_packet_msg) do 
		if v.actor_id  == actor_id then
			ret = true
			break
		end
	end
	return ret
end

function getRedPacketMaxCount(guild_id) 
	if guild_id == 0 then 
		return 0
	end
	local var = getRedPacketData(guild_id)
	return var.end_index
end

function getRedPacketRemainCount(guild_id)
	if guild_id == 0 then 
		return 0
	end
	local var = getRedPacketData(guild_id)
	return var.end_index - var.begin_index
end

function getRedPacketData(guild_id) --得到红包数据
	if guild_id == 0 then 
		return nil
	end
	initGuildData(guild_id)
	local var = getGlobalData()
	return var[guild_id]
end

function redPacketEmpyt(guild_id) --红包是否空
	if guild_id == 0 then 
		return false
	end
	local gvar = getGlobalData()
	if gvar[guild_id] == nil then 
		return true
	end
	local var = getRedPacketData(guild_id)
	return var.begin_index == var.end_index
end

function addRedPacketYuanBao(guild_id,num) --增加红包元宝
	if guild_id == 0 then 
		return
	end
	if not redPacketEmpyt(guild_id) then 
		return 
	end
	local var = getRedPacketData(guild_id)
	var.yuan_bao = var.yuan_bao + num 
	if var.yuan_bao < 0 then 
		var.yuan_bao = 0
	end
	System.log("guildbattleredpacket", "addRedPacketYuanBao", "mark1", guild_id, var.yuan_bao, num)
end

function sendRedPacket(guild_id,yuan_bao,count) --发送红包
	if guild_id == 0 then 
		return false
	end 
	if count == 0 or yuan_bao == 0 then 
		return false
	end
	local tmp_yuan_bao = yuan_bao
	if not guildbattlefb.isWinGuildId(guild_id) then 
		print(guild_id .. " 不是获胜公会")
		return false
	end
	if not redPacketEmpyt(guild_id) then 
		print(guild_id .. " 重复发红包 ")
		return false
	end
	if yuan_bao < count then 
		print(guild_id .. " 元宝小于要发放的数量 " .. yuan_bao .. " " .. count)
		return false
	end
	if count > LGuild.getGuildMemberCount(LGuild.getGuildById(guild_id)) then 
		print(guild_id .. " 红包份数大于帮成员 " .. count .. " " ..  LGuild.getGuildMemberCount(LGuild.getGuildById(guild_id)))
		return false
	end
	local var = getRedPacketData(guild_id)
	if var.yuan_bao < yuan_bao then 
		print(guild_id .. " 发红包元宝不足 " .. yuan_bao .. " " .. var.yuan_bao) 
		return false
	end

	var.yuan_bao = var.yuan_bao - yuan_bao
	local i = 0
	local basic_yuan_bao = math.floor((yuan_bao / count ) / 3)
	if basic_yuan_bao == 0 then 
		basic_yuan_bao = 1
	end
	while (i < count) do 

		local tbl = {
			yuan_bao = basic_yuan_bao,
		}
		var.red_packet[var.end_index] = tbl
		var.end_index  = var.end_index + 1
		i = i + 1
	end
	yuan_bao = yuan_bao - (basic_yuan_bao * count)
	if count ~= 1 then
		while (yuan_bao ~= 0) do 
			local index = math.random(0,count-1)
			local alloc = math.floor(yuan_bao / count) 
			if alloc == 0 then 
				alloc = yuan_bao
			end
			local yb = math.random(alloc)
			var.red_packet[index].yuan_bao = var.red_packet[index].yuan_bao + yb
			yuan_bao = yuan_bao - yb
		end
	else 
		var.red_packet[0].yuan_bao = yuan_bao + basic_yuan_bao
	end

	i = 0
	while (i < count) do 
		print(i .. " " .. var.red_packet[i].yuan_bao)
		i = i + 1
	end
	var.send_time = os.time()
	LActor.postScriptEventLite(nil,day_sec  * 1000,function() redPacketTimeOutCallBack(guild_id) end)
	if var.yuan_bao ~= 0 then 
		-- 发邮件
		local mail_data = {}
		mail_data.head = GuildBattleConst.sendRedPacketHead
		mail_data.context = GuildBattleConst.sendRedPacketContext
		mail_data.tAwardList = 
		{ 
			{
				type  = AwardType_Numeric,
				id    = NumericType_YuanBao,
				count = var.yuan_bao
			}
		}
		LActor.log(LGuild.getLeaderId(LGuild.getGuildById(guild_id)), "guildbattleredpacket.sendRedPacket", "sendmail")
		mailsystem.sendMailById(LGuild.getLeaderId(LGuild.getGuildById(guild_id)),mail_data)
		var.yuan_bao = 0
	end
	var.red_packet_total_yuan_bao = tmp_yuan_bao

	System.log("guildbattleredpacket", "sendRedPacket", "mark1", guild_id, tmp_yuan_bao, count)
	return true
end

function getRedPacket(actor) --得到红包
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then 
		LActor.log(actor, "guildbattleredpacket.getRedPacket", "mark1")
		return false
	end

	if redPacketEmpyt(guild_id) then 
		LActor.log(actor, "guildbattleredpacket.getRedPacket", "mark2")
		return false
	end
	local gvar = getRedPacketData(guild_id)
	local var = getData(actor)
	if isGetRedPacket(guild_id,LActor.getActorId(actor)) then 
		LActor.log(actor, "guildbattleredpacket.getRedPacket", "mark3", guild_id)
		return false
	end
	LActor.changeYuanBao(actor,gvar.red_packet[gvar.begin_index].yuan_bao,"red packet")
	local red_packet_msg = 
	{
		yuan_bao = gvar.red_packet[gvar.begin_index].yuan_bao,
		name     = LActor.getName(actor),
		actor_id = LActor.getActorId(actor)
	}
	gvar.red_packet[gvar.begin_index] = nil
	gvar.begin_index = gvar.begin_index + 1
	table.insert(gvar.red_packet_msg,red_packet_msg)
	return true
end



function rsfRedPacket(guild_id) --刷新红包
	if guild_id   == 0 then 
		return
	end

	local gvar = getGlobalData()
	if gvar[guild_id] == nil then
		return
	end
	local var = getRedPacketData(guild_id)
	local yuan_bao = var.yuan_bao
	while (not redPacketEmpyt(guild_id)) do 
		yuan_bao = yuan_bao + var.red_packet[var.begin_index].yuan_bao
		var.begin_index = var.begin_index + 1
	end
	System.log("guildbattleredpacket", "rsfRedPacket", "mark1", guild_id, var.begin_index, yuan_bao)

	if yuan_bao ~= 0 then
		local mail_data = {}
		mail_data.head = GuildBattleConst.redPacketTimeOutHead
		mail_data.context = GuildBattleConst.redPacketTimeContext
		mail_data.tAwardList = 
		{ 
			{
				type  = AwardType_Numeric,
				id    = NumericType_YuanBao,
				count = yuan_bao 
			}
		}
		LActor.log(LGuild.getLeaderId(LGuild.getGuildById(guild_id)), "guildbattleredpacket.rsfRedPacket", "sendmail")
		mailsystem.sendMailById(LGuild.getLeaderId(LGuild.getGuildById(guild_id)),mail_data)
	end
	gvar[guild_id] = nil
end

function checkRedPacketTimeOut(guild_id) --红包是否超时
	if guild_id == 0 then 
		return true
	end
	if  redPacketEmpyt(guild_id) then 
		return true
	end
	local var = getRedPacketData(guild_id)
	local now = os.time()
	if now >= (var.send_time + day_sec) then 
		return true
	end
	return false
end


function redPacketTimeOutCallBack(guild_id)
	if checkRedPacketTimeOut(guild_id) then 
		rsfRedPacket(guild_id)
	end
end

local function initTimer() 
	print("init red pack time out call back")
	local var = getGlobalData()
	local now = os.time()
	for i,v in pairs(var) do 
		if v.send_time ~= 0 then 
			local sec = (v.send_time + day_sec) - now 
			LActor.postScriptEventLite(nil,sec  * 1000,function() redPacketTimeOutCallBack(i) end)
		end
	end
end

local function freeTimeOut() -- 回收过期的红包
	local var = getGlobalData()
	for i,v in pairs(var) do 
		if v.send_time ~= 0 then 
			if checkRedPacketTimeOut(i) then 
				rsfRedPacket(i)
			end
		end
	end
end

-- net 
--
function sendRedPacketData(actor)
	if not guildbattle.checkOpen(actor) then 
		return
	end
	local guild_id = LActor.getGuildId(actor)
	local gvar = getRedPacketData(guild_id) 
	if not guildbattlefb.isWinGuild(actor) then 
		LActor.log(actor, "guildbattleredpacket.sendRedPacketData", "mark1", guild_id)
		return false
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_SendRedPacketData)
	if npack == nil then 
		return
	end
	if guildbattle.isLeader(actor) then 
		LDataPack.writeInt(npack,gvar.yuan_bao)
		local is_send = false

		if gvar.yuan_bao ~= 0  and redPacketEmpyt(guild_id) then 
			is_send = true
		end

		LDataPack.writeByte(npack,is_send and 1 or 0)

		--LDataPack.writeByte(npack,(gvar.yuan_bao ~= 0 and redPacketEmpyt(guild_id)) and 1 or 0)
	else
		LDataPack.writeInt(npack,0)
		LDataPack.writeByte(npack,0)
	end
	if redPacketEmpyt(guild_id) then 
		LDataPack.writeByte(npack,0)
		LDataPack.writeInt(npack,0)
		--红包空了就为0
	else
		local is_get = not isGetRedPacket(guild_id,LActor.getActorId(actor)) 
		LDataPack.writeByte(npack, is_get and 1 or 0)
		LDataPack.writeInt(npack,gvar.red_packet_total_yuan_bao)
	end
	LDataPack.writeInt(npack,getRedPacketMaxCount(guild_id))
	LDataPack.writeInt(npack,getRedPacketRemainCount(guild_id))
	LDataPack.writeInt(npack,#gvar.red_packet_msg)
	for i = 1,#gvar.red_packet_msg do 
		LDataPack.writeInt(npack,gvar.red_packet_msg[i].yuan_bao)
		LDataPack.writeString(npack,gvar.red_packet_msg[i].name)
		LDataPack.writeInt(npack,gvar.red_packet_msg[i].actor_id)
	end
	LDataPack.flush(npack)

end

local function retSendRedPacket(actor,ok)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_SendRedPacket)
	if npack == nil then 
		return
	end
	LDataPack.writeByte(npack,ok and 1 or 0)
	LDataPack.flush(npack)
end

local function onSendRedPacket(actor,pack)
	local yuan_bao = LDataPack.readInt(pack)
	local count    = LDataPack.readInt(pack)
	if not guildbattle.checkOpen(actor) then 
		retSendRedPacket(actor,false)
		return
	end
	if not guildbattle.isLeader(actor) then 
		retSendRedPacket(actor,false)
		return 
	end
	local guild_id = LActor.getGuildId(actor) 
	retSendRedPacket(actor,sendRedPacket(guild_id,yuan_bao,count))
	updateOnlineActor(guild_id)
	--sendRedPacket(actor,yuan_bao,count)
end

local function onGetRedPacket(actor,pack)

	local ret   = getRedPacket(actor)
	local guild_id = LActor.getGuildId(actor)
	updateOnlineActor(guild_id)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_GetRedPacket)
	if npack == nil then 
		return
	end
	LDataPack.writeByte(npack,ret and 1 or 0)
	LDataPack.flush(npack)
end


function updateOnlineActor(guild_id) 
	local actors = guildbattle.getOnlineActor(guild_id) 
	for i = 1,#actors  do 
--		print(i .. " " .. LActor.getActorId(actors[i]))
		sendRedPacketData(actors[i])
	end
end





function onInit(actor)
	initData(actor)
end

function onLogin(actor)
	sendRedPacketData(actor)
end


actorevent.reg(aeInit,onInit)
actorevent.reg(aeUserLogin,onLogin)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_SendRedPacket, onSendRedPacket)
netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetRedPacket, onGetRedPacket)
initGlobalData()


engineevent.regGameStartEvent(freeTimeOut)
engineevent.regGameStartEvent(initTimer)



