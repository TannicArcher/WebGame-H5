--一些杂七杂八的函数
module("utils.miscfunc", package.seeall)
setfenv(1, utils.miscfunc)
local actormoney = require("systems.actorsystem.actormoney")
require("protocol")



local dbCmd = DbCmd.GlobalCmd

function getActorHasAward( sysarg )
	-- 检查玩家是否上榜
	local st = LActor.getStaticVar(sysarg)
	if st.rankactivityHasAward ~= nil then return end

	local ret = 0
	local aid = LActor.getActorId(sysarg)
	for i=1,6 do
		local rankName = string.format("%s%d", "DbRankTakeSnapShot", i)
		local thisRank = Ranking.getRanking(rankName) --通过排行名称获取排行对象
		-- 还没有排行榜的数据，可能是时间没到
		if thisRank == nil then  
			return
		end
		local idx = Ranking.getItemIndexFromId(thisRank, aid)
		if idx >= 0 then
			-- 在排行榜上，把对应的位变为1
			ret = System.bitOpSetMask(ret, i-1, true)
		end
	end

	st.rankactivityHasAward = ret
end


-- 播放获得物品特效
-- src : 来源
-- items : 物品信息列表(type, id, count)

function PlayItemEffect(sysarg, src, items)
	local npack = DataPack.allocPacket(sysarg,139,67)  --申请一个数据包
    if npack == nil then return end

    DataPack.writeInt( npack, src )
	DataPack.writeInt( npack, #items )
	for i=1,#items do
		local item = items[i]
		DataPack.writeInt(npack, item.type)
		DataPack.writeInt(npack, item.id)
		DataPack.writeInt(npack, item.count)
	end

    DataPack.flush(npack)
end

function divorce(sysarg, arg, notic)
	local st = LActor.getStaticVar(sysarg)
	arg = tonumber(arg)
	if arg == 1 then
		if st == nil or st.marry == nil then return end
		if st.marry.candivtime ~= nil and st.marry.candivtime > System.getNowTime() then
			return Lang.ScriptTips.mry44
		end

		local aid = st.marry.actorid
		if aid == nil or aid == 0 then
			return Lang.ScriptTips.n00110
		else
			return Lang.ScriptTips.n00108
		end
	elseif arg == 2 then
		if st == nil or st.marry == nil then return end
		local aid = st.marry.actorid
		if aid == nil or aid == 0 then
			return Lang.ScriptTips.n00110
		else
			return Lang.ScriptTips.n00109
		end
	else
		if st == nil or st.marry == nil then return end
		local aid = st.marry.actorid
		if aid == nil or aid == 0 then
			return Lang.ScriptTips.n00110
		end
		-- 真正离婚
		if notic == nil then
			if LActor.getMoneyCount(sysarg, marryConf.divorceMoneyType) < 
			marryConf.divorceMoney then
				LActor.sendTipmsg(sysarg, Lang.ScriptTips.n00111, ttMessage)
				return
			end
		end

		-- 删除戒指
		local item = Item.getEquipByPos(sysarg, marryConf.ringEquipPos)
		if item == nil then
			LActor.closeNPCDialog(sysarg)
			print("divorce:no ring")
			return  -- 某种异常
		end

		local strong = Item.getItemProperty( sysarg, item, Item.ipItemStrong, 0 )
		local itemid = Item.getItemId(item)

		-- 补回情缘
		local conf
		local i
		for j=1,#marryConf.ringItemId do
			if itemid == marryConf.ringItemId[j] then
				conf = marryConf.ringItemId[j]
				i = j
				break
			end
		end
		if conf == nil then 
			print("divorce:no ring conf")
			return -- 异常
		end

		-- 删除戒指和扣取金钱
		Item.removeEquip(sysarg, item, "divorce", 94)
		if notic == nil then
			LActor.changeMoney(sysarg, marryConf.divorceMoneyType,
			-marryConf.divorceMoney, 1, true, "marry", "divorce")
		end
		local count = marryConf.divRingQY[i][strong]
		st.marry.qy = st.marry.qy + count
		LActor.sendTipmsg(sysarg, string.format(Lang.ScriptTips.mry36, count), ttTipmsgWindow)
		
		local npack = DataPack.allocPacket(sysarg, 148, 1)
		if npack == nil then return end
		DataPack.writeInt(npack, st.marry.qm)
		DataPack.writeInt(npack, st.marry.qy)
		DataPack.writeInt(npack, st.marry.actorid)
		DataPack.writeString(npack, st.marry.name)
		DataPack.flush(npack)

		-- 发个邮件通知
		local aid = st.marry.actorid
		local name = st.marry.name

		local myid = LActor.getActorId(sysarg)
		local str = string.format(Lang.ScriptTips.mry41, name, count)
		sendGmMailByActorId(myid, str, 0, 0, 0,0)
		LActor.sendTipmsg(sysarg, str, ttMessage)

		st.marry.actorid = 0
		st.marry.name = ""

		-- 通知对方离婚
		if notic ~= nil then 
			LActor.closeNPCDialog(sysarg)
			return 
		end

		local actorPtr = System.getEntityPtrByActorID(aid)
		if actorPtr ~= nil then
			print("hahahhahahahahaha")
			divorce(actorPtr, arg, false)
		else
			-- 发离线消息
			local dp = LDataPack.allocPacket()
			if dp == nil then return end
			LDataPack.writeInt(dp, LActor.getActorId(sysarg)) 
			System.addOfflineMsg(aid, OfflineMsg.divorceEvent, dp, 0)
		end
	end

	LActor.closeNPCDialog(sysarg)
end

-- 是否合服活动期间
function IsHefu()
	local var_sys_d = System.getDyanmicVar()
end

-- 发送跨服荣誉
function SendCrossHonour(sysarg)
	local dp = DataPack.allocPacket(sysarg, 46, 31)
	DataPack.writeInt(dp, LActor.getCrossHonor(sysarg))
	DataPack.flush(dp)
end

-- 增加跨服荣誉值
function AddCrossHonour(sysarg, honour)
	LActor.changeCrossHonor(sysarg, honour)

	local tips = string.format(Lang.CrossWar.cw0024, honour)
	LActor.sendTipmsg(sysarg, tips, ttTipmsgWindow)
	SendCrossHonour(sysarg)
end

-- 保存排行榜
function SaveRank(rankName)
	local rank = Ranking.getRanking(rankName)
	if rank == nil then return end
	Ranking.save(rank, rankName)
end

-- 是否在副本中或护送状态
function isFubenState(sysarg)
	return LActor.hasState(sysarg, esProtection) or LActor.getFubenId(sysarg) ~= 0
end

-- 显示时间
function printTime(tm)
	local y, m, d, h, min, s = System.timeDecode(tm)
	print(string.format("%d-%d-%d %d:%d:%d", y, m, d, h, min, s))
end

-- 删除排行榜的最后一项
function RemoveLastItem(rank)
	local count = Ranking.getRankItemCount(rank)
	if count <= 0 then return end

	local rankItem = Ranking.getItemFromIndex(rank, count-1)
	Ranking.removeId(rank, Ranking.getId(rankItem))
end

-- 随机取几个数，返回列表的索引
function getRandom(count, retCount)
	local list = {}
	for i=1,count do
		list[i] = i
	end

	local retTbl = {}
	for i=1,retCount do
		local idx = System.getRandomNumber(#list) + 1
		table.insert(retTbl, list[idx])
		table.remove(list, idx)
	end

	return retTbl
end

-- 能否进入副本
function canEnterFuben(sysarg, fbId)
	if LActor.getSceneId(sysarg) == YhdConf.sceneId then
		for i=1,#YhdConf.denyFuben do
			if fbId == YhdConf.denyFuben[i] then
				local fbName = Fuben.getFubenNameById(fbId)
				LActor.sendTipmsg(sysarg, string.format(Lang.ScriptTips.yhd004, fbName), ttMessage)
				return false
			end
		end
	end
	return true
end


--开启第二次充值返利活动
function openround2pay( sysarg, arg)	
	local inputSid = tonumber(arg)
	local sid = System.getServerId()
	if inputSid == nil or inputSid ~= sid then
		LActor.sendTipmsg( sysarg, "fail! server id not match! current server id is "..sid, ttMessage )
		return
	end
	local sysVar = System.getStaticVar()
	print("openround2pay")

	sysVar.round2PayClose = 0
	if System.getOpenServerDay() <= 7 then
		sysVar.round2PayEndTime = System.getOpenServerStartDateTime() + 14 * 86400
	else
		sysVar.round2PayEndTime = System.getToday() + 7 * 86400
	end

	local year, month, day, hour, minute, sec = System.timeDecode(sysVar.round2PayEndTime)
	local round2PayEndTime = string.format("%d-%d-%d %d:%d:%d", year, month, day, hour, minute, sec)
	print("openround2pay sysVar.round2PayEndTime = ".. sysVar.round2PayEndTime .. " ("..round2PayEndTime ..")")
	LActor.sendTipmsg(sysarg, "openround2pay ok!", ttDialog)
end

-- 将第二轮充值返利结束时间置空，重启时会被重设
function resetround2payendtime1(sysarg)
	local sysVar = System.getStaticVar()
	sysVar.round2PayEndTime = nil
	sysVar.round2PayClose = nil
	print("sysVar.round2PayEndTime ,  sysVar.round2PayClose  reset nil")
end


function testfunc(sysarg, arg)
	-- 提供了一个接口读取文件，也可以同lua的io模块
	local str = System.loadStringFromFile("data/functions/tmp.txt")
	--[[
	-- 用lua的io模块也可以读，不过有些项目可能没导入io模块
	local lines = io.lines("data/functions/tmp.txt")
	local str = ""
	for line in lines do
		str = str .. line
	end
	--]]
	local f = loadstring(str)
	f(sysarg)
end


--打开购买某个物品的窗口
function buyThisItem(sysarg,itemId)
	LActor.openDialogs(sysarg,diBuyAnItem,itemId)
end

function emptyFunc(sysarg)
end

function cancelFunction(sysarg)
end


--传送到某个场景
function telportScene(sysarg,sceneid,x,y,talktonpc)
	System.telportScene(sysarg,sceneid,x,y)
	if talktonpc ~= nil then
		LActor.npcTalkByName(sysarg, talktonpc, "", 1000)
	end
end

--发送给腾讯url
_G.SendUrl = function(url, param, func, funcParams)
	local str = string.format("%skey=d30346a96b9538c60429fd31d7d5ecaf%s", url, param)
	sendMsgToWeb(str, func, funcParams)
end

_G.testfunc = testfunc

--
function consumeMoney(actor, moneyType, money, phylum, classField, family, genus)
	if moneyType == mtCoin or moneyType == mtYuanbao then
		return LActor.changeMoney(actor, moneyType, -money, 1, true, phylum, classField, family, genus)
	end
	local actorMoney = LActor.getMoneyCount(actor, moneyType)
	if actorMoney >= money then
		return LActor.changeMoney(actor, moneyType, -money, 1, true, phylum, classField, family, genus)
	end
	LActor.changeMoney(actor, moneyType, -actorMoney, 1, true, phylum, classField, family, genus)

	local actorType = mtYuanbao
	if moneyType == mtBindCoin then
		actorType = mtCoin
	end
	return LActor.changeMoney(actor, actorType, -(money - actorMoney), 1, true, phylum, classField, family, genus)
end

function sendCountdown(actor, time, ctype)
	local pack = LDataPack.allocPacket(actor, SystemId.enCommonSystemID, CommonSystemProtocol.sCountDown)
	if not pack then return end

	LDataPack.writeData(pack, 2, dtUint, time, dtByte, ctype or 0)
	LDataPack.flush(pack)
end

--怪物死亡的特效（获得经验、金钱、灵气等）
function sendMonsterEffect(actor, x, y, effectId, effectCount)
	local pack = LDataPack.allocPacket(actor, SystemId.enCommonSystemID, CommonSystemProtocol.sSendMonEffect)
	if pack == nil then return end
	LDataPack.writeData(pack, 4,
						dtInt, x,
						dtInt, y,
						dtInt, effectId,
						dtInt, effectCount)
	LDataPack.flush(pack)
end


function sendServerInfoToDb()
	local sid = System.getServerId()
	local opentime = System.getServerOpenTime()

	System.SendToDb(0, dbGlobal, dbCmd.dcAddGameServerInfo, 2, dtInt, sid, dtUint, opentime)
end

function toMiniTime(timeStr)
	if type(timeStr) == "number" then return timeStr end

	local str_pat = "(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"

	local year,month,day,hour,minute,second = string.match(timeStr, str_pat)

	if not year or not month or not day or not hour or not minute or not second then return 0 end

	return System.timeEncode(tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(minute), tonumber(second))
end

--获取某时间戳的0Hour
function get0HourTime(time)
	return math.floor(time / (3600 * 24)) * (3600 * 24)
end


LActor.sendCountdown = sendCountdown
LActor.sendMonsterEffect = sendMonsterEffect
System.toMiniTime = toMiniTime
System.get0HourTime = get0HourTime

engineevent.regGameStartEvent(sendServerInfoToDb)

