module("guildbattle", package.seeall)


local min_sec   = utils.min_sec
local hours_sec = utils.hours_sec
local week_sec  = utils.week_sec
local day_sec   = utils.day_sec

--活动类型
local guildBattleType = {
	normal = 0, --正常
	hefu = 1,  -- 合服
	open = 2,     -- 开服
}

BattleType = BattleType or guildBattleType.normal

local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		return nil
	end
	if var.guild_battle == nil then
		var.guild_battle = {}
	end
	return var.guild_battle
end

local function getGlobalData()
	local var = System.getStaticVar()
	if var == nil then
		return nil
	end
	if var.guild_battle == nil then
		var.guild_battle = {}
	end
	return var.guild_battle
end

--获取活动类型
function getActType()
	local var = getGlobalData()
	return var.type or 0
end

local function initGlobalData()
	System.log("guildbattle", "initGlobalData", "call")
	local var = getGlobalData()
	if var.open_sec == nil then
		var.open_sec = 0
	end
	if var.save_sec == nil then
		var.save_sec = 0
	end
	if var.open_size == nil then
		var.open_size = 0
		-- 开启的次数
	end
end

function getOpenSize()
	local var = getGlobalData()
	return var.open_size
end

function addOpenSize(num)
	local var = getGlobalData()
	var.open_size = var.open_size + num
	System.log("guildbattle", "addOpenSize", "mark1", var.open_size)
end

local function initData(actor)
end
-- 公共接口
function isLeader(actor) --是不是leader
	local guild_id = LActor.getGuildId(actor)
	if guild_id == 0 then
		return false
	end
	return LActor.getActorId(actor) == LGuild.getLeaderId(LActor.getGuildPtr(actor))
end

function checkOpen(actor)
	local level = LActor.getZhuanShengLevel(actor) * 1000
	level = level + LActor.getLevel(actor)
	if level <  GuildBattleConst.openLevel then
		print(LActor.getActorId(actor) .. " guildbattle openLevel " .. level)
		return false
	end
	local guild = LActor.getGuildPtr(actor)
	if guild == nil then
		--print(LActor.getActorId(actor) .. " guildbattle not has guild ")
		return false
	end
	return true
end

function getOnlineActor(guild_id) --得到公会所有在线玩家
	return LGuild.getOnlineActor(guild_id) or {}
end


function advanceNotice()
	noticemanager.broadCastNotice(GuildBattleConst.advanceNotice)
end

function getHefuActivityIdx()
	local var = getGlobalData()

	return var.hefuIdx or 0
end

--设置合服龙城归属
function setHefuBelongInfo(guildName)
	local var = getGlobalData()
	if nil == var.belongList then var.belongList = {} end

	var.belongList[#var.belongList+1] = guildName
end

function rsfBelongData()
	local var = getGlobalData()
	var.belongList = nil
end

function setGlobalTimer()
	if not System.isCommSrv() then return end

	local open_server_day = System.getOpenServerDay() + 1
	local oinfo           = GuildBattleConst.openServer
	local info            = GuildBattleConst.open
	local hefu_info       = GuildBattleConst.hefuOpen
	local timer_sec       = 1
	local not_open_server = false
	local curr_time       = os.time()
	local var             = getGlobalData()
	local oday            = oinfo.day

	--默认为正常活动
	BattleType = guildBattleType.normal

	System.log("guildbattle", "setGlobalTimer", "oinfo", utils.t2s(oinfo))
	System.log("guildbattle", "setGlobalTimer", "info", utils.t2s(info))
	System.log("guildbattle", "setGlobalTimer", "hefu_info", utils.t2s(hefu_info))
	System.log("guildbattle", "setGlobalTimer", "var", utils.t2s(var))
	System.log("guildbattle", "setGlobalTimer", "open_server_day", open_server_day)
	if open_server_day <= (oday) then
		System.log("guildbattle", "setGlobalTimer", "mark1")
		local open_day_sec = (oinfo.hours * hours_sec) + (oinfo.min * min_sec)
		local curr_day_sec = utils.getDaySec(curr_time)
		timer_sec = (oday - open_server_day) * day_sec --算天
		timer_sec = timer_sec - curr_day_sec
		timer_sec = timer_sec + open_day_sec
		if timer_sec <= 0 then
			not_open_server = true
		else
			BattleType = guildBattleType.open  --开服活动
		end
	else
		not_open_server = true
	end
	local open_day = System.getOpenServerDay()
	local hefu_day = hefutime.getHeFuDay()
	local hefuIdx = 0
	if not_open_server and hefu_day ~= nil then
		System.log("guildbattle", "setGlobalTimer", "mark2")
		open_day = hefutime.getHeFuDay()
		for k, hefuDayConf in ipairs(hefu_info) do
			oday = hefuDayConf.day
			if hefu_day <= (oday) then
				System.log("guildbattle", "setGlobalTimer", "mark3")
				local open_day_sec = (hefuDayConf.hours * hours_sec) + (hefuDayConf.min * min_sec)
				local curr_day_sec = utils.getDaySec(curr_time)
				timer_sec = (oday - hefu_day) * day_sec --算天
				timer_sec = timer_sec - curr_day_sec
				timer_sec = timer_sec + open_day_sec
				if timer_sec > 0 then
					hefuIdx = k
					not_open_server = false

					BattleType = guildBattleType.hefu  --合服活动
					break
				end
			end
		end

		System.log("guildbattle", "setGlobalTimer", "mark4")

		if open_day < 9 then
			var.open_sec = 0
		end
	end

	if not_open_server then
		System.log("guildbattle", "setGlobalTimer", "mark5")
		local next_week = false
		local curr_week = false
		if var.open_sec == 0 then
			next_week = false
			curr_week = false
			local week = utils.getWeek(curr_time)
			if open_day >= 8 then
				if week < info.week then
					curr_week = true
					--当前的星期比info的小是这周开启
				elseif week > info.week then
					next_week = true
					--当前的星期比info的大是下周开启
				else
					--同一天
					local curr_day_sec = utils.getDaySec(curr_time)
					local open_day_sec = (info.hours * hours_sec) + (info.min * min_sec)
					if curr_day_sec <= open_day_sec then
						curr_week = true
					else
						next_week = true
					end
				end
				System.log("guildbattle", "setGlobalTimer", "mark6")
			else
				local tmp = utils.getAmSec(curr_time) + ((7 - open_day) * day_sec)
				week = utils.getWeek(tmp)
				if week < info.week then
					curr_week = true
					--当前的星期比info的小是这周开启
				elseif week > info.week then
					next_week = true
					--当前的星期比info的大是下周开启
				else
					--同一天
					local curr_day_sec = utils.getDaySec(tmp)
					local open_day_sec = (info.hours * hours_sec) + (info.min * min_sec)
					if curr_day_sec <= open_day_sec then
						curr_week = true
					else
						next_week = true
					end
				end
				curr_time = tmp
				System.log("guildbattle", "setGlobalTimer", "mark7")
			end
		elseif var.open_sec <= curr_time then
			--算下一周
			System.log("guildbattle", "setGlobalTimer", "mark8")
			next_week = true
		end
		if next_week then
			System.log("guildbattle", "setGlobalTimer", "mark9")
			local sec = (utils.getWeeks(curr_time) + 1) * week_sec
			sec = sec + ((info.week - 1) * day_sec) + (info.hours * hours_sec) + (info.min * min_sec)
			sec = sec - ((3 * day_sec) + System.getTimeZone()) --时差
			var.open_sec = sec
		end
		if curr_week then
			System.log("guildbattle", "setGlobalTimer", "mark10")
			local sec = utils.getWeeks(curr_time) * week_sec
			sec = sec + ((info.week - 1) * day_sec) + (info.hours * hours_sec) + (info.min * min_sec)
			sec = sec - ((3 * day_sec) + System.getTimeZone()) --时差
			var.open_sec = sec
		end
		curr_time = os.time()
		timer_sec = var.open_sec - curr_time
	end
	System.log("guildbattle", "setGlobalTimer", "timer_sec:" .. timer_sec)
	if timer_sec == 0 then
		return
	end
	var.save_sec = curr_time + timer_sec
	if timer_sec >= (3 * 60) then
		LActor.postScriptEventLite(nil,(timer_sec - (3 * 60))  * 1000,function()  advanceNotice() end)
	end

	LActor.postScriptEventLite(nil,(timer_sec)  * 1000,function(entity, hefuIdx)  globalTimer(hefuIdx) end, hefuIdx)
	System.log("guildbattle", "setGlobalTimer", "var.save_sec:" .. os.date("%x",var.save_sec))
end

function makeOpenData(npack)
	local var = getGlobalData()
	local is_open = guildbattlefb.isOpen()
	LDataPack.writeByte(npack,is_open and 1 or 0)
	LDataPack.writeInt(npack,var.save_sec)
	LDataPack.writeInt(npack,guildbattlefb.getEndTime())

end

function sendOpen(actor)
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle,Protocol.sGuildBattleCmd_Open)
	if npack == nil then
		return
	end
	makeOpenData(npack)
	LDataPack.flush(npack)
end


function broadcastOpen()
	local npack = LDataPack.allocPacket()
	if npack == nil then
		return
	end
	local var = getGlobalData()
	LDataPack.writeByte(npack,Protocol.CMD_GuildBattle)
	LDataPack.writeByte(npack,Protocol.sGuildBattleCmd_Open)
	makeOpenData(npack)
	System.broadcastData(npack)
end



function initAndSendGuildBattle(actor)
	onInit(actor)
	onLogin(actor)

	guildbattleredpacket.onInit(actor)
	guildbattleredpacket.onLogin(actor)

	guildbattlepersonalaward.onInit(actor)
	guildbattlepersonalaward.onLogin(actor)

	guildbattlefb.onInit(actor)
	guildbattlefb.onLogin(actor)

	guildbattledayaward.onInit(actor)
	guildbattledayaward.onLogin(actor)
end

function onCreateGuild(actor)
	initAndSendGuildBattle(actor)
end


function onAddGuild(actor)
	initAndSendGuildBattle(actor)
end




function globalTimer(hefuIdx)
	if not System.isCommSrv() then return end

	System.log("guildbattle", "globalTimer", "call")

	--记录这次活动类型
	local var = getGlobalData()
	var.type = BattleType

	setGlobalTimer()
	guildbattlefb.open()

	local var = getGlobalData()
	var.hefuIdx = tonumber(hefuIdx)
end

local function onReqBelongInfo(actor, packet)
	local var = getGlobalData()
	if nil == var.belongList then var.belongList = {} end
	local npack = LDataPack.allocPacket(actor,Protocol.CMD_GuildBattle, Protocol.sGuildBattleCmd_GetHefuBelongInfo)
	LDataPack.writeShort(npack, #var.belongList)
	for i=1, #var.belongList do LDataPack.writeString(npack, var.belongList[i] or "") end
	LDataPack.flush(npack)
end

function onLogin(actor)
	if not System.isCommSrv() then return end
	sendOpen(actor)
end

function onInit(actor)
	initData(actor)
end

local function onNewDay(actor)
end



initGlobalData()

netmsgdispatcher.reg(Protocol.CMD_GuildBattle, Protocol.cGuildBattleCmd_GetHefuBelongInfo, onReqBelongInfo)

engineevent.regGameStartEvent(setGlobalTimer)

------------------------------------------------
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeInit,onInit)
--
--
