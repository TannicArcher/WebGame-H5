
module("systems.cdkey.cdkey" , package.seeall)
setfenv(1, systems.cdkey.cdkey)

--local mailsystem = require("systems.mail.mailsystem")
local httpclient = require("utils.net.httpclient")

require("protocol")

local protocol = MiscsSystemProtocol
local systemId = SystemId.miscsSystem 
local Lang = Lang.ScriptTips

local CDKEY_LEN = 16

function checkAndSetCDK(actor, itemId, flag)
	if not actor or not itemId then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if var.cdkey == nil then
		var.cdkey = {}
	end
	if not var.cdkey then return end

	if flag then
		var.cdkey[itemId] = 1
	end
	return var.cdkey[itemId]
end

function checkCdKey(actorid, cdkey, parser)
	if not actorid or not cdkey then return end

	local actor = LActor.getActorById(actorid)
	if not actor then return end

	if parser[1] ~= 0 then
		LActor.sendTipmsg(actor, Lang.cdkey002) --激活码无效
		return
	end

	local itemId = parser[2]
	if not itemId then return end

	if checkAndSetCDK(actor, itemId) then
		LActor.sendTipmsg(actor, Lang.cdkey006) --已经领取过激活码兑换奖励
		return
	end

	local needspace = Item.getAddItemNeedGridCount(actor, itemId, 1)
	if needspace > Item.getBagEmptyGridCount(actor) then
		LActor.sendTipmsg(actor, Lang.cdkey005) --兑换成功
		return
	end

	checkAndSetCDK(actor, itemId, true)

	--发放奖励
	LActor.addItem(actor,itemId, 0, 0, 1, 1, "cdkey", 779)

	LActor.sendTipmsg(actor, Lang.cdkey001) --兑换成功

	SendUrl("/cdk?", "&cdkey="..cdkey.."&type=2")

	--cdkey数据打点
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), 
		tostring(LActor.getLevel(actor)), 
		"success", "", "",
		cdkey, "itemId:"..itemId, "", "",
		"cdkey", lfBI)
end

--解析放回数据
function recvCdkeyToken(params, retParams)
	local content = retParams[1]
	local ret = retParams[2]

	if ret ~= 0 then return end

	local sub = httpclient.parseUrlContent(content)
	if #sub < 1 then return end

	local status = string.match(sub[1], "%d+")
	if not status then return end
	status = tonumber(status)

	local itemId = nil
	if sub[2] then
		itemId = string.match(sub[2], "%d+")
		if itemId then
			itemId = tonumber(itemId)
		end
	end

	checkCdKey(params[1], params[2], {status, itemId})
end

function exchange(actor, packet)
	if not packet or not actor then return end
	local cdkey = LDataPack.readString(packet)

	--过滤掉非字母数字字符
	cdkey = string.match(cdkey, "%w+")

	if string.len(cdkey) ~= CDKEY_LEN then
		LActor.sendTipmsg(actor, Lang.cdkey003) --非法的激活码格式
		return
	end

	local actorid = LActor.getActorId(actor)

	SendUrl("/cdk?", "&cdkey="..cdkey.."&type=1"
		, recvCdkeyToken, {actorid, cdkey})
end

function test_exchange(actor, cdkey)
	local actorid = LActor.getActorId(actor)

	local cdkey = "e85fcc5gcbfbf3hf"

	--过滤掉非字母数字字符
	cdkey = string.match(cdkey, "%w+")

	if string.len(cdkey) ~= CDKEY_LEN then
		LActor.sendTipmsg(actor, Lang.cdkey003) --非法的激活码格式
		return
	end

	SendUrl("/cdk?", "&cdkey="..cdkey.."&type=1"
		, recvCdkeyToken, {actorid, cdkey})
end

function resetCDK(actor)
	local var = LActor.getStaticVar(actor)
	if not var or not var.cdkey then return end
	var.cdkey = nil
end

_G.testCDK = test_exchange

_G.resetCDK = resetCDK

netmsgdispatcher.reg(systemId, protocol.cCdkeyExchange, exchange)