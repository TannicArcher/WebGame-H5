module("dkmlogfunc", package.seeall)

-- 角色升级
local function onLevelUp(actor, lvl, vipLvl)
	local actorId = LActor.getActorId(actor)
	local aName = LActor.getActorName(actorId)
	local t = os.date("%Y-%m-%d %H:%M:%S")
	--2016-12-11 12:36:34 levelup:from=101:userid=323523:roleid=6b4715084:account=xx:lev=2:platform=25pp:totalcash=40000:viplev=5
	local str = "%s levelup:from=%d:userid=%d:roleid=%d:account=%s:lev=%d:platform=%s:mac=null:os=null:totalcash=%d:viplev=%d"
	local logstr = string.format(str, t, System.getServerId(),LActor.getAccountId(actor),
		actorId, aName, lvl, LActor.getPfId(actor), 
		LActor.getRecharge(actor), vipLvl)
	System.logDKMLog(logstr, LActor.getPfId(actor))
end

local function onLevelUpLog(actor, lvl)
	onLevelUp(actor, lvl, LActor.getVipLevel(actor))
end
local function onVipLvlUpLog(actor)
	onLevelUp(actor, LActor.getLevel(actor), LActor.getVipLevel(actor))
end

-- 角色充值
local function onRecharge(actor, val, orderNum)
	local t = os.date("%Y-%m-%d %H:%M:%S")

	--//2016-12-11 12:36:34 addcash:from=101:userid=323523:roleid=6b4715084:account=xx:lev=20:platform=wl91:totalcash=1000:cash=200:yuanbao=100:id1=1213:id2=221:ip=1.1.1.1
	local strIp = LActor.getLastLoginIp(actor) or ""
	local lvl = LActor.getLevel(actor)
	local actorId = LActor.getActorId(actor)
	local accountId = LActor.getAccountId(actor)
	local aName = LActor.getActorName(actorId)
	local totalcash = LActor.getRecharge(actor)
	local str = "%s addcash:from=%d:userid=%d:roleid=%d:account=%s:lev=%d:platform=%s:mac=null:os=null:totalcash=%d:cash=%d:yuanbao=%d:id1=null:id2=%s:ip=%s"
	local logstr = string.format(str, t, System.getServerId(), accountId,
		actorId, aName, lvl, LActor.getPfId(actor), 
		totalcash, math.floor(val/100), val, orderNum, strIp)
	System.logDKMLog(logstr, LActor.getPfId(actor))
end

--登出
function onLogout(actor, actorId, onlineTime)
	local pfid = LActor.getPfId(actor)

	local t = os.date("%Y-%m-%d %H:%M:%S")
	local accountId = LActor.getAccountId(actor)
	local aName = LActor.getActorName(actorId)
	local sId = System.getServerId()
	local aData = LActor.getActorData(actor)

	--//2010-12-11 12:36:34 chardata:from=101:userid=154128:roleid=6b4715084:account=xx:platform=25pp:createtime=1483769092:lastlogintime=1483769093:totalonlinetime=3600:dayonlinetime=1800:lev=20:viplev=8:exp=1000:fight=1000:totalcash=2000:yuanbaoowned=110:jinbiowned=200
	local str = "%s chardata:from=%d:userid=%d:roleid=%d:account=%s:platform=%s:mac=null:os=null:createtime=%d:lastlogintime=%d:totalonlinetime=%d:dayonlinetime=%d:lev=%d:viplev=%d:exp=%d:fight=%d:totalcash=%d:yuanbaoowned=%d:jinbiowned=%d"
	local logstr = string.format(str, t, sId,accountId,
		actorId, aName, pfid, aData.create_time, 
		aData.last_online_time, aData.total_online, 
		aData.daily_online, aData.level, aData.vip_level, 
		aData.exp, aData.total_power, aData.recharge, 
		aData.yuanbao, aData.gold)
	System.logDKMLog(logstr, pfid)
	
	--//2016-12-11 12:36:34 rolelogout:from=101:userid=323523:roleid=6b4715084:account=xx:lev=20:platform=wl91:totalcash=1000:time=12000:hint=xx
	local logstr2 = string.format("%s rolelogout:from=%d:userid=%d:roleid=%d:account=%s:lev=%d:platform=%s:mac=null:os=null:totalcash=%d:time=%d"
		, t, sId, accountId, actorId, aName, LActor.getLevel(actor), pfid, LActor.getRecharge(actor), onlineTime);
	System.logDKMLog(logstr2, pfid)
end

-- 商店
function onShop(actor, shopType, itemTye, itemId, count, cType, cNeed)
	local t = os.date("%Y-%m-%d %H:%M:%S")

	--//2016-12-11 12:36:34 shop_trade:from=101:userid=1541238:roleid=6b4715084:account=xx:lev=20:platform=25pp:mac=DC2B617396C2:os=1:item_id=12345:item_type=1:item_count=1:cash_type=1:cash_need=10:order_id=0
	local strIp = LActor.getLastLoginIp(actor) or ""
	local lvl = LActor.getLevel(actor)
	local actorId = LActor.getActorId(actor)
	local accountId = LActor.getAccountId(actor)
	local aName = LActor.getActorName(actorId)
	local totalcash = LActor.getRecharge(actor)
	local str = "%s shop_trade:from=%d:userid=%d:roleid=%d:account=%s:lev=%d:platform=%s:mac=null:os=null:item_id=%d:item_type=%d:item_count=%d:cash_type=%d:cash_need=%d:order_id=0"
	local logstr = string.format(str, t, System.getServerId(), accountId,
		actorId, aName, lvl, LActor.getPfId(actor), itemId, itemTye, count, cType, cNeed)
	System.logDKMLog(logstr, LActor.getPfId(actor))
end

--登陆日志
local function onLogin(actor)
	local t = os.date("%Y-%m-%d %H:%M:%S")
	local actorId = LActor.getActorId(actor)
	--2016-12-11 12:36:34 rolelogin:from=101:userid=323523:roleid=6b4715084:account=xx:lev=20:platform=wl91 : totalcash = 1000 : ip = 1.1.1.1
	local logstr = string.format("%s rolelogin:from=%d:userid=%d:roleid=%d:account=%s:lev=%d:platform=%s:mac=null:os=null:totalcash=%d:ip=%s"
		, t, System.getServerId(), LActor.getAccountId(actor), actorId, LActor.getActorName(actorId), LActor.getLevel(actor),
		LActor.getPfId(actor), LActor.getRecharge(actor), LActor.getLastLoginIp(actor) or "");
	System.logDKMLog(logstr, LActor.getPfId(actor))
end

local function init()
	actorevent.reg(aeLevel, onLevelUpLog)
	actorevent.reg(aeUpdateVipInfo, onVipLvlUpLog)
	actorevent.reg(aeRecharge, onRecharge)
	actorevent.reg(aeUserLogout, onLogout)
	actorevent.reg(aeUserLogin, onLogin)
end

table.insert(InitFnTable, init)
