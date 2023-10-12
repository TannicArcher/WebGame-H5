module("execsql", package.seeall)
setfenv(1, execsql)

require("dbprotocol")
local dbretdispatcher = require("utils.net.dbretdispatcher")

local dbCmd = DbCmd.DefaultCmd

--发送给dbserver
function sendExecSqlToDb(sql)
	--不是字符串或空串直接返回
	if type(sql) ~= "string" or sql == "" then return end
	System.SendToDb(0, dbDefault, dbCmd.dcExecDB, 1, dtString, sql)
end

--dbserver返回
function sendSqlToDbReturn(packet)
	local err = LDataPack.readByte(packet)
	local sql = LDataPack.readString(packet)

	--成功
	if err == 0 then
		print(string.format("%s success", sql))
	else
		print(string.format("%s error! return : %d", sql, err))
	end
end

-- 发送查询命令到dbserver
function sendQueryToDb(id, conds, sysId, cmdId, serverId)
	local dbClient, dbPacket = System.allocDBPacket(serverId or 0, dbCommonDB, 1)
	LDataPack.writeInt(dbPacket, id)
	LDataPack.writeByte(dbPacket, sysId)
	LDataPack.writeByte(dbPacket, cmdId)
	LDataPack.writeString(dbPacket, conds)
	System.flushDBPacket(dbClient, dbPacket)
end

-- 发送插入命令到dbserver, packet : 数量(int), 各列数据
function sendInsertToDb(id, packet, sysId, cmdId, serverId)
	local dbClient, dbPacket = System.allocDBPacket(serverId or 0, dbCommonDB, 1)
	LDataPack.writeInt(dbPacket, id)
	LDataPack.writeByte(dbPacket, sysId)
	LDataPack.writeByte(dbPacket, cmdId)

	LDataPack.writePacket(dbPacket, packet)
	System.flushDBPacket(dbClient, dbPacket)
end

-- 发送更新命令到dbserver TODO:如果知道类型就不用传packet了
function sendUpdateToDb(id, packet, conds, sysId, cmdId, serverId)
	local dbClient, dbPacket = System.allocDBPacket(serverId or 0, dbCommonDB, 1)
	LDataPack.writeInt(dbPacket, id)
	LDataPack.writeByte(dbPacket, sysId)
	LDataPack.writeByte(dbPacket, cmdId)
	
	LDataPack.writePacket(dbPacket, packet)
	LDataPack.writeString(dbPacket, conds or "")
	System.flushDBPacket(dbClient, dbPacket)
end

-- 发送删除命令到dbserver
function sendDeleteToDb(id, conds, sysId, cmdId, serverId)
	local dbClient, dbPacket = System.allocDBPacket(serverId or 0, dbCommonDB, 1)
	LDataPack.writeInt(dbPacket, id)
	LDataPack.writeByte(dbPacket, sysId)
	LDataPack.writeByte(dbPacket, cmdId)
	
	LDataPack.writeString(dbPacket, conds or "")
	System.flushDBPacket(dbClient, dbPacket)
end

function sendExecToDb(id, dp, sysId, cmdId, serverId)
	local dbClient, dbPacket = System.allocDBPacket(serverId or 0, dbCommonDB, 1)
	LDataPack.writeInt(dbPacket, id)
	LDataPack.writeByte(dbPacket, sysId)
	LDataPack.writeByte(dbPacket, cmdId)
	LDataPack.writePacket(dbPacket, dp)
	System.flushDBPacket(dbClient, dbPacket)
end

System.sendQueryToDb = sendQueryToDb
System.sendInsertToDb = sendInsertToDb
System.sendUpdateToDb = sendUpdateToDb
System.sendDeleteToDb = sendDeleteToDb
System.sendExecSqlToDb = sendExecSqlToDb
dbretdispatcher.reg(dbDefault, dbCmd.dcExecDB, sendSqlToDbReturn)


_G.testsql = function()
	System.sendQueryToDb(0, "ti = 99", dbDefault, 100, 0)

	-- 插入
	-- local dp = LDataPack.allocPacket()
	-- LDataPack.writeInt(dp, 1)
	-- LDataPack.writeInt(dp, 99)
	-- LDataPack.writeString(dp, "嘻嘻")
	-- System.sendInsertToDb(1, dp, dbDefault, 100, 0)

	-- 更新
	-- local dp = LDataPack.allocPacket()
	-- LDataPack.writeString(dp, "哈哈哈")
	-- System.sendUpdateToDb(2, dp, "ti = 11", dbDefault, 100, 0)

	-- 删除
	-- local dp = LDataPack.allocPacket()
	-- LDataPack.writeInt(dp, 1)
	-- LDataPack.writeString(dp, "hehe")
	-- sendInsertToDb(2, {0, 1}, 1, dp, dbDefault, 120, 0)

	-- 存储过程
	-- local dp = LDataPack.allocPacket()
	-- LDataPack.writeInt(dp, 5)
	-- sendExecToDb(2, dp, dbDefault, 100, 0)
end

--dbserver返回
function onSqlQueryReturn(packet)
	local err = LDataPack.readByte(packet)
	--成功
	if err == 0 then
		local cnt = LDataPack.readInt(packet)
		for i=1,cnt do
			print(LDataPack.readInt(packet))
			print(LDataPack.readInt(packet))
		end
	else
		print(string.format("sql error! return : %d", err))
	end
end

dbretdispatcher.reg(dbDefault, 100, onSqlQueryReturn)