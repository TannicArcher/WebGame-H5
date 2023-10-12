--微信激活码
module("systems.weixin.weixincode", package.seeall)
setfenv(1, systems.weixin.weixincode)

local netmsgdispatcher = require("utils.net.netmsgdispatcher")
local actorevent = require("actorevent.actorevent")
local dbretdispatcher  = require("utils.net.dbretdispatcher")

require("protocol")
local SystemId = SystemId.gmSystemID
local protocol = gmQuestionProtocol
local dbCmd = DbCmd.GlobalCmd

--领取微信礼包
function getWeiXinGift(actor, packet)
	if actor == nil or packet == nil then return end

	local code = LDataPack.readString(packet)

	print(LActor.getActorId(actor).." getWeiXinGift code:"..code)
end


netmsgdispatcher.reg(SystemId, protocol.cGetWeiXinGift, getWeiXinGift)
