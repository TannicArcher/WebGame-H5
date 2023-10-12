--蓝钻特权
module("systems.txvipaward.txvipaward", package.seeall)
setfenv(1, systems.txvipaward.txvipaward)

require("protocol")
require("txvipaward.bluevipconfig")
require("txvipaward.yellowvipconfig")
require("txvipaward.qqvipconfig")

local actorevent = require("actorevent.actorevent")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local webSys = require("systems.web.websystem")

local gmsystem  = require("systems.gm.gmsystem")
gmCmdHandlers = gmsystem.gmCmdHandlers

local System = System
local ScriptTips  = Lang.ScriptTips
local timeRewardSystem = SystemId.timeRewardSystem
local TimeRewardSystemProtocol = TimeRewardSystemProtocol

TYPE_BLUE = 1
TYPE_YELLOW = 2
TYPE_QQVIP = 3
TYPE_MAX = 4

local totalConf = {}

local function initConfig( ... )
	totalConf[TYPE_BLUE] = BlueVipConf
	totalConf[TYPE_YELLOW] = YellowVipConf
	totalConf[TYPE_QQVIP] = QQVipConf
end

local function getStaticVar( actor )
	local var = LActor.getSysVar(actor)
	if var.txvipinfo == nil then
		var.txvipinfo = {}
	end

	return var.txvipinfo
end

function getVipInfo( actor, t )
	local var = getStaticVar(actor)
	if t < TYPE_BLUE or t >= TYPE_MAX then return end

	if not var[t] then
		var[t] = {}
	end

	return var[t]
end

local function sendStatu( actor, t )
	local var = getVipInfo(actor, t)

	local flag = var.vipawardinfo or 0
	local openFromMe = var.openFromMe or 0
	local reOpenFromMe = var.reOpenFromMe or 0

	local pack = LDataPack.allocPacket(actor, timeRewardSystem, TimeRewardSystemProtocol.sBlueVipInfo)
	if not pack then return end

	LDataPack.writeData(pack, 4, dtByte, t, dtInt, flag, dtByte, openFromMe, dtByte, reOpenFromMe)
	LDataPack.flush(pack)
end

local function setQQVipLvl( t, lvl )
	local offset = 12
	if lvl == 1 then
		t = System.bitOpSetMask(t, offset, true)
	elseif lvl == 2 then
		t = System.bitOpSetMask(t, offset + 1, true)
	elseif lvl == 3 then
		t = System.bitOpSetMask(t, offset, true)
		t = System.bitOpSetMask(t, offset + 1, true)
	elseif lvl == 4 then
		t = System.bitOpSetMask(t, offset + 2, true)
	elseif lvl == 5 then
		t = System.bitOpSetMask(t, offset, true)
		t = System.bitOpSetMask(t, offset + 2, true)
	elseif lvl == 6 then
		t = System.bitOpSetMask(t, offset + 1, true)
		t = System.bitOpSetMask(t, offset + 2, true)
	elseif lvl == 7 then
		t = System.bitOpSetMask(t, offset, true)
		t = System.bitOpSetMask(t, offset + 1, true)
		t = System.bitOpSetMask(t, offset + 2, true)
	elseif lvl == 8 then
		t = System.bitOpSetMask(t, offset + 3, true)
	end

	return t
end

function setVip( actor, is3366 )
	--用一个int表示，低2字节表示蓝钻的信息，高2字节表示黄钻信息，
	--每两个字节再分别这样定：第一位表示是否蓝钻，第二为表示是否年费，第三个位表示是否超级蓝钻，第四位是否3366，第五位表示是否qq会员，
	--第六位表示年费qq会员，第七位表示超级qq会员
	--第二个字节的前四位表示蓝钻的等级，后四位表示qq会员的等级
	--黄钻的2个字节也是如此类推
	local function setVal(st, type_vip, old )
		local t = old or 0
		local offset = 0
		if type_vip == TYPE_QQVIP then
			offset = 4
		end

		if st.is_vip then
			t = System.bitOpSetMask(t, 0 + offset, true)
		end

		if st.is_year_vip then
			t = System.bitOpSetMask(t, 1 + offset, true)
		end

		if st.is_super_vip then
			t = System.bitOpSetMask(t, 2 + offset, true)
		end

		if type_vip == TYPE_BLUE and is3366 then
			t = System.bitOpSetMask(t, 3, true)
		end

		if st.vip_level ~= nil then
			if type_vip ~= TYPE_QQVIP then
				t = System.makeInt16(t, st.vip_level)
			else
				t = setQQVipLvl( t, st.vip_level )
			end
		end

		return t
	end
	
	local st1 = getVipInfo(actor, TYPE_BLUE)
	local ret1 = setVal(st1, TYPE_BLUE)

	local st2 = getVipInfo(actor, TYPE_YELLOW)
	local ret2 = setVal(st2, TYPE_YELLOW)

	local st3 = getVipInfo(actor, TYPE_QQVIP)
	local ret3 = setVal(st3, TYPE_QQVIP, ret1)

	local ret = System.makeInt32(ret3, ret2)
	LActor.setIntProperty(actor, P_QQ_VIP, ret)

	sendStatu(actor, TYPE_BLUE)
	sendStatu(actor, TYPE_YELLOW)
	sendStatu(actor, TYPE_QQVIP)
end

local function vipStr(t)
	if t == TYPE_BLUE then
		return ScriptTips.tav01
	elseif t == TYPE_YELLOW then
		return ScriptTips.tav02
	else
		return ScriptTips.tav03
	end
end

local function getConf( t )
	return totalConf[t]
end

local function getLogStr( t )
	if t == TYPE_BLUE then
		return "bluevip", 223
	elseif t == TYPE_YELLOW then
		return "yellowvip", 222
	else
		return "qqvip", 237
	end
end

local function getFreshAward( actor, t )
	local var = getVipInfo(actor, t)
	local flag = var.vipawardinfo or 0

	if System.bitOPMask(flag, 0) then
		--已经领过了
		LActor.sendTipmsg(actor, ScriptTips.ta001)
		return false
	end

	if not var.is_vip  and not var.is_year_vip then
		local str = string.format(ScriptTips.ta004, vipStr(t))
		LActor.sendTipmsg( actor, str )
		return
	end

	local baseConf = getConf(t)
	if not LActor.canAddItem(actor, baseConf.freshAward, 1, 0, 0, true) then
		LActor.sendTipmsg(actor, ScriptTips.ta002)
		return false
	end

	var.vipawardinfo = System.bitOpSetMask(flag, 0, true)

	local logstr, logId = getLogStr(t)
	logstr = logstr.."_new"
	LActor.addItem(actor, baseConf.freshAward, 0, 0, 1, 1, logstr, logId)

	sendStatu(actor, t)

	local str = string.format(ScriptTips.ta003, Item.getItemName(baseConf.freshAward))
	LActor.sendTipmsg(actor, str)
end

local function getDailyAward( actor, t )
	local var = getVipInfo(actor, t)
	local flag = var.vipawardinfo or 0

	if System.bitOPMask(flag, 1) then
		--已经领过了
		LActor.sendTipmsg(actor, ScriptTips.ta001)
		return false
	end

	if not var.is_vip  and not var.is_super_vip then
		local str = string.format(ScriptTips.ta004, vipStr(t))
		LActor.sendTipmsg( actor, str )
		return
	end

	local lvl = var.vip_level
	if not lvl then
		print("error:getDailyAward..vip_level is nil", t)
		return
	end

	local baseConf = getConf(t)
	local conf = baseConf.dailyAward[lvl]
	if not conf then
		print("error:getDailyAward..conf is nil", lvl, t)
		return
	end

	if not LActor.canAddItem(actor, conf.normalItem, 1, 0, 0, true) then
		LActor.sendTipmsg(actor, ScriptTips.ta002)
		return false
	end

	var.vipawardinfo = System.bitOpSetMask(flag, 1, true)
	local logstr, logId = getLogStr(t)
	logstr = logstr.."_daily"
	LActor.addItem(actor, conf.normalItem, 0, 0, 1, 1, logstr, logId)

	sendStatu(actor, t)

	local str = string.format(ScriptTips.ta003, Item.getItemName(conf.normalItem))
	LActor.sendTipmsg(actor, str)
end

local function getYearDailyAward( actor, t )
	local var = getVipInfo(actor, t)
	local flag = var.vipawardinfo or 0

	if System.bitOPMask(flag, 2) then
		--已经领过了
		LActor.sendTipmsg(actor, ScriptTips.ta001)
		return false
	end

	if not var.is_year_vip then
		local str = string.format(ScriptTips.ta005, vipStr(t))
		LActor.sendTipmsg( actor, str )
		return
	end

	local lvl = var.vip_level
	if not lvl then
		print("error:getYearDailyAward..vip_level is nil", lvl, t)
		return
	end

	local baseConf = getConf(t)
	local conf = baseConf.dailyAward[lvl]
	if not conf then
		print("error:getYearDailyAward..conf is nil", lvl, t)
		return
	end

	if not LActor.canAddItem(actor, conf.yearItem, 1, 0, 0, true) then
		LActor.sendTipmsg(actor, ScriptTips.ta002)
		return false
	end

	var.vipawardinfo = System.bitOpSetMask(flag, 2, true)
	local logstr, logId = getLogStr(t)
	logstr = "year_"..logstr.."_daily"
	LActor.addItem(actor, conf.yearItem, 0, 0, 1, 1, logstr, logId)

	sendStatu(actor, t)

	local str = string.format(ScriptTips.ta003, Item.getItemName(conf.yearItem))
	LActor.sendTipmsg(actor, str)
end

local function getSuperDailyAward( actor, t )
	local var = getVipInfo(actor, t)
	local flag = var.vipawardinfo or 0

	if System.bitOPMask(flag, 3) then
		--已经领过了
		LActor.sendTipmsg(actor, ScriptTips.ta001)
		return false
	end

	if not var.is_super_vip then
		local str = string.format(ScriptTips.ta006, vipStr(t))
		LActor.sendTipmsg( actor, str )
		return
	end

	local lvl = var.vip_level
	if not lvl then
		print("error:getSuperDailyAward..vip_level is nil", lvl, t)
		return
	end

	local baseConf = getConf(t)
	local conf = baseConf.dailyAward[lvl]
	if not conf then
		print("error:getSuperDailyAward..conf is nil", lvl, t)
		return
	end

	if not LActor.canAddItem(actor, conf.superItem, 1, 0, 0, true) then
		LActor.sendTipmsg(actor, ScriptTips.ta002)
		return false
	end

	var.vipawardinfo = System.bitOpSetMask(flag, 3, true)
	local logstr, logId = getLogStr(t)
	logstr = "super_"..logstr.."_daily"
	LActor.addItem(actor, conf.superItem, 0, 0, 1, 1, logstr, logId)

	sendStatu(actor, t)

	local str = string.format(ScriptTips.ta003, Item.getItemName(conf.superItem))
	LActor.sendTipmsg(actor, str)
end

local function getLvlAward(actor, t, lvlIdx)
	local baseConf = getConf(t)
	local conf = baseConf.levelAward[lvlIdx]
	if not conf then return end

	local curLvl = LActor.getRealLevel(actor)
	if curLvl < conf.level then
		LActor.sendTipmsg( actor, ScriptTips.ta007 )
		return
	end

	local var = getVipInfo(actor, t)
	local flag = var.vipawardinfo or 0

	if not var.is_vip  and not var.is_super_vip then
		local str = string.format(ScriptTips.ta004, vipStr(t))
		LActor.sendTipmsg( actor, str )
		return
	end

	local bitIdx = 4 + lvlIdx
	if System.bitOPMask(flag, bitIdx) then
		--已经领过了
		LActor.sendTipmsg(actor, ScriptTips.ta001)
		return false
	end

	if not LActor.canAddItem(actor, conf.itemId, 1, 0, 0, true) then
		LActor.sendTipmsg(actor, ScriptTips.ta002)
		return false
	end

	var.vipawardinfo = System.bitOpSetMask(flag, bitIdx, true)

	local logstr, logId = getLogStr(t)
	logstr = logstr.."_lvl_award"
	LActor.addItem(actor, conf.itemId, 0, 0, 1, 1, logstr, logId)

	sendStatu(actor, t)

	local str = string.format(ScriptTips.ta003, Item.getItemName(conf.itemId))
	LActor.sendTipmsg(actor, str)
end

local function getOpenVipFromPageAward( actor, t )
	local var = getVipInfo(actor, t)
	local flag = var.vipawardinfo or 0

	if System.bitOPMask(flag, 4) then
		--已经领过了
		LActor.sendTipmsg(actor, ScriptTips.ta001)
		return false
	end

	if var.openFromMe == nil then
		LActor.sendTipmsg(actor, ScriptTips.blue06, ttMessage)
		return
	end

	if not var.is_vip  and not var.is_super_vip then
		LActor.sendTipmsg( actor, ScriptTips.ta009 )
		return
	end

	local baseConf = getConf(t)
	if not LActor.canAddItem(actor, baseConf.vipOnlyItemId, 1, 0, 0, true) then
		LActor.sendTipmsg(actor, ScriptTips.ta002)
		return false
	end

	var.vipawardinfo = System.bitOpSetMask(flag, 4, true)
	local logstr, logId = getLogStr(t)
	logstr = logstr.."recharge_award"
	LActor.addItem(actor, baseConf.vipOnlyItemId, 0, 0, 1, 1, logstr, logId)

	sendStatu(actor, t)

	local str = string.format(ScriptTips.ta003, Item.getItemName(baseConf.vipOnlyItemId))
	LActor.sendTipmsg(actor, str)
end

local function getReOpenVipAward( actor, t )
	local var = getVipInfo(actor, t)
	local reOpenFromMe = var.reOpenFromMe or 0

	if not var.is_vip  and not var.is_super_vip then
		local str = string.format(ScriptTips.ta004, vipStr(t))
		LActor.sendTipmsg( actor, str )
		return
	end

	if reOpenFromMe == 0 then
		--不能领或者领过了
		LActor.sendTipmsg(actor, ScriptTips.ta008)
		return false
	end

	local baseConf = getConf(t)
	if not LActor.canAddItem(actor, baseConf.reOpenItemId, 1, 0, 0, true) then
		LActor.sendTipmsg(actor, ScriptTips.ta002)
		return false
	end

	var.reOpenFromMe = nil
	local logstr, logId = getLogStr(t)
	logstr = logstr.."reopen_award"
	LActor.addItem(actor, baseConf.reOpenItemId, 0, 0, 1, 1, logstr, logId)

	sendStatu(actor, t)

	local str = string.format(ScriptTips.ta003, Item.getItemName(baseConf.reOpenItemId))
	LActor.sendTipmsg(actor, str)
end

local function getAward( actor, t, pack )
	local types = LDataPack.readInt(pack)

	if types == 1 then
		--新手礼包
		getFreshAward(actor, t)
	elseif types == 2 then
		--每日普通礼包
		getDailyAward(actor, t)
	elseif types == 3 then
		--年费每日额外礼包
		getYearDailyAward(actor, t)
	elseif types == 4 then
		--豪华版每日礼包
		getSuperDailyAward(actor, t)
	elseif types == 5 then
		--专属礼包
		getOpenVipFromPageAward(actor, t)
	elseif types == 6 then
		--等级礼包
		local lvlIdx = LDataPack.readInt(pack)
		getLvlAward(actor, t, lvlIdx)
	elseif types == 7 then
		getReOpenVipAward(actor, t)
	end
end

local function getBlueAward( actor, pack )
	local t = LDataPack.readByte(pack)
	if t < TYPE_BLUE or t >= TYPE_MAX then return end

	getAward( actor, t, pack )
end

local function onNewDay(actor)
	local function reset( t )
		local var = getVipInfo(actor, t)
		local flag = var.vipawardinfo or 0
		if flag == 0 then return end

		flag = System.bitOpSetMask(flag, 1, false)
		flag = System.bitOpSetMask(flag, 2, false)
		var.vipawardinfo = System.bitOpSetMask(flag, 3, false)

		sendStatu(actor, t)
	end

	reset(TYPE_BLUE)
	reset(TYPE_YELLOW)
	reset(TYPE_QQVIP)
end

local function getGlobalVipVar( t )
	local sys_var = System.getStaticVar()
	if not sys_var then return end

	if t == TYPE_BLUE then
		if not sys_var.blueofflinevip then
			sys_var.blueofflinevip = {}
		end

		return sys_var.blueofflinevip
	elseif t == TYPE_YELLOW then
		if not sys_var.yellowofflinevip then
			sys_var.yellowofflinevip = {}
		end

		return sys_var.yellowofflinevip
	end
end

local function checkReOpenVip( var )
	local now = System.getNowTime()
	local vipTime = var.time or 0 

	--前3天后三天
	if (now - vipTime >= 0 and now - vipTime <= 3 * 86400) or (vipTime - now >= 0 and vipTime - now <= 3 * 86400) then
		var.reOpenFromMe = 1
	end
end

local function onOpenYellowVip( accountname, p1, p2, p3, p4, p5 )
	local actor = LActor.getActorByAccountName(accountname)
	if actor then
		local var = getVipInfo(actor, TYPE_YELLOW)
		var.openFromMe = 1
		checkReOpenVip(var)
		sendStatu(actor, TYPE_YELLOW)
	else
		local sys_var = getGlobalVipVar(TYPE_YELLOW)
		local cnt = sys_var.cnt or 0
		sys_var[cnt + 1] = accountname
		sys_var.cnt = cnt + 1
	end
end

local function onOpenBlueVip( accountname, p1, p2, p3, p4, p5 )
	local actor = LActor.getActorByAccountName(accountname)
	if actor then
		local var = getVipInfo(actor, TYPE_BLUE)
		var.openFromMe = 1
		checkReOpenVip(var)
		sendStatu(actor, TYPE_BLUE)
	else
		local sys_var = getGlobalVipVar(TYPE_BLUE)
		local cnt = sys_var.cnt or 0
		sys_var[cnt + 1] = accountname
		sys_var.cnt = cnt + 1
	end
end

local function checkOfflineOpenVip( actor )
	local accountname = LActor.getAccountName(actor)
	function check( sys_var, t )
		local cnt = sys_var.cnt or 0

		if cnt > 10 then
			print("log:OfflineOpenVip cnt may too big........", cnt, t)
		end

		local findIdx = 0
		for i=1, cnt do
			if sys_var[i] == accountname then
				local var = getVipInfo(actor, t)
				var.openFromMe = 1
				checkReOpenVip(var)
				sendStatu(actor, t)
				findIdx = i
				break
			end
		end

		if findIdx ~= 0 then
			for i=findIdx + 1, cnt do
				sys_var[i-1] = sys_var[i]
			end

			sys_var[cnt] = nil
			sys_var.cnt = cnt - 1
		end
	end

	check(getGlobalVipVar(TYPE_BLUE), TYPE_BLUE)
	check(getGlobalVipVar(TYPE_YELLOW), TYPE_YELLOW)
end

webSys.reg(webSys.APITYPE.OPEN_YELLOW_VIP, onOpenYellowVip)
webSys.reg(webSys.APITYPE.OPEN_BLUE_VIP, onOpenBlueVip)

actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeUserLogin, checkOfflineOpenVip)

netmsgdispatcher.reg(timeRewardSystem, TimeRewardSystemProtocol.cGetBlueVipAward, getBlueAward)
table.insert(InitFnTable, initConfig)


gmCmdHandlers.sethlzuan = function ( actor, args )
	if not args or #args ~= 5 then return end

	local t = tonumber(args[1])  --类型 1表示蓝钻，2表示黄钻
	local a1 = tonumber(args[2]) --是否普通蓝钻
	local a2 = tonumber(args[3]) --是否豪华蓝钻
	local a3 = tonumber(args[4]) --是否年费蓝钻
	local a4 = tonumber(args[5]) --蓝钻等级

	if t ~=TYPE_BLUE and t ~= TYPE_YELLOW then return end 

	local st = getVipInfo(actor, t)
	st.is_vip = a1
	st.is_year_vip = a2
	st.is_super_vip = a3
	st.vip_level = a4

	setVip(actor)

	return true
end

