module("systems.web.websystem", package.seeall)
setfenv(1, systems.web.websystem)

require("protocol")

local regcommon = require("utils.common")
local dbretdispatcher = require("utils.net.dbretdispatcher")


local dbprotocol = DbCmd.TxApiCmd

local retFunc = {}

APITYPE = {
	TX_MARKET = 0, --集市
	OPEN_YELLOW_VIP = 1,
	OPEN_QQ_VIP = 2,
	OPEN_BLUE_VIP = 15,
}

function reg(cmdtype, func)
	if not cmdtype or not func then return end
	retFunc[cmdtype] = retFunc[cmdtype] or {}
	regcommon.reg(retFunc[cmdtype], func, true)
end

function onTxApiMsg(packet)
	local accountname, cmdtype, p1, p2, p3, p4, p5 = LDataPack.readData(packet, 7, 
													dtString, dtInt, dtString, dtString, dtString, dtString, dtString)

	print("onTxApiMsg")
	print("accountname = " .. accountname)
	print("type = " .. cmdtype)
	print(string.format("p1 = %s, p2 = %s, p3 = %s, p4 = %s, p5 = %s", p1, p2, p3, p4, p5))
	--下面是api返回的逻辑处理
	local procList = retFunc[cmdtype]
	if not procList then 
		print("onTxApiMsg no function to deal with by cmdtype = " .. cmdtype)
		return 
	end

	--对应返回所注册的处理函数(注意函数需要处理在线与非在线的情况, 具体通过openid来获取actor)
	for _, func in ipairs(procList) do
		func(accountname, p1, p2, p3, p4, p5)
	end
end

dbretdispatcher.reg(dbTxApi, dbprotocol.sTxApiMsg, onTxApiMsg)

