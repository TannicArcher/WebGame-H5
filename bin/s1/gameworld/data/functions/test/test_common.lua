module("test.test_common" , package.seeall)
setfenv(1, test.test_common)

-- 清除玩家背包某个物品
function test_clearBagItem(actor, itemId)
	while true do
		local count = LActor.getItemCount(actor, itemId)
		if count <= 0 then break end
		if count >= 128 then count = 128 end -- 程序用一个uint8_t表示数量，避免溢出
		LActor.removeItem(actor, itemId, count, -1, -1, -1)
	end
end

-- 设置系统时间
function stt(actor, ...)
	local year = tonumber(arg[1])
	local mon = tonumber(arg[2])
	local mday = tonumber(arg[3])
	local hour = tonumber(arg[4])
	local min = tonumber(arg[5])
	local sec = tonumber(arg[6])
	local str = string.format("settime.bat %d/%d/%d %d:%d:%d", year, mon, mday, hour, min, sec)
	System.execute(str)
end

function test_sendDialog(actor)
	LActor.sendTipmsg(actor, "test!!!", ttDialog)
end

function test_err(actor)
	print(a .. b)
end

_G.test_err = test_err



