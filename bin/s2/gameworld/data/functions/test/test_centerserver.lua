module("test.test_centerserver" , package.seeall)
setfenv(1, test.test_centerserver)
--[[
测试中心服务器
--]]

local centerservermsg = require("utils.net.centerservermsg")

function test_send()
	-- 协议是sysid, pid, 内容
	local pack = LDataPack.allocPacket()
	LDataPack.writeData(pack, 4,
		dtInt, 0, --System.getServerId(),	-- 发送的目的gameworld,如果服务器id是0，表示广播给所有的gameworld，慎用
		dtByte, 255,
		dtByte, 1,
		dtString, "test_string")
	System.sendDataToCenter(pack)
end

function recv_test_string(pack, sid)
	print("recv centerserver msg from " .. sid)
	Assert_eq(System.getServerId(), sid, "recv_test_string error")

	local s = LDataPack.readData(pack, 1, dtString)
	Assert_eq("test_string", s, "recv_test_string error")
end

-- 协议号255都是用来测试
centerservermsg.reg(255, 1, recv_test_string)

TEST("centerservermsg", "test_send", test_send)
