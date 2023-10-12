module("test.test_gtest" , package.seeall)
setfenv(1, test.test_gtest)

local gmsystem         = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers

function test_gtest( ... )
	System.runGTest()
	return true
end


TEST("gtest", "test_gtest", test_gtest)

-- 用gm命令执行
gmCmdHandlers.gtest = test_gtest
