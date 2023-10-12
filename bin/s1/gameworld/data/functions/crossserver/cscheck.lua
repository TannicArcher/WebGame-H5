module("cscheck", package.seeall)

--发生连接时候加个版本检查
function OnConnCsWar(serverId, serverType)
	if System.isCommSrv() then
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCCheckCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCCheckCmd_OpenTime)
		LDataPack.writeInt(pack, System.getServerOpenTime())
		System.sendPacketToAllGameClient(pack, serverId)
	elseif System.isCrossWarSrv() then
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCCheckCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCCheckCmd_CheckVersion)
		System.sendPacketToAllGameClient(pack, serverId)
	end

end

function onCheckVersion(sId, sType, dp)
	if System.isCommSrv() then --游戏服
		local version = System.version()
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCCheckCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCCheckCmd_CheckVersion)
		LDataPack.writeInt(pack, version)
		System.sendPacketToAllGameClient(pack, sId)
	elseif System.isCrossWarSrv() then --跨服服
		local tarVersion = LDataPack.readInt(dp)
		local srcVersion = System.version()
		if tarVersion ~= srcVersion then
			System.log("cscheck", "onCheckVersion", sId, srcVersion, tarVersion)
			assert(false)
		end
	end
end

local function onGetOpenTime(sId, sType, dp)
	if System.isCrossWarSrv() then --跨服服
		local opentime = LDataPack.readInt(dp)
		local var = csbase.setCommonSrvOpenDay(sId, opentime)
	end
end

csbase.RegConnected(OnConnCsWar) --连接到跨服的时候
csmsgdispatcher.Reg(CrossSrvCmd.SCCheckCmd, CrossSrvSubCmd.SCCheckCmd_CheckVersion, onCheckVersion) --收到其它服版本消息时的处理
csmsgdispatcher.Reg(CrossSrvCmd.SCCheckCmd, CrossSrvSubCmd.SCCheckCmd_OpenTime, onGetOpenTime) --收到其它服版本消息时的处理