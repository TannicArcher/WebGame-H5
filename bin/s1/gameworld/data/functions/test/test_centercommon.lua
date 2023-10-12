module("test.test_centercommon" , package.seeall)
setfenv(1, test.test_centercommon)

function test_sendCenterTipmsg(actor)
	--这个测试如果需要自己服看到,需修改centerservermsg的自己服限制
	centercommon.sendCenterTipmsg(0, 0, "test", ttMessage)
end

TEST("centercommon", "tipmsg", test_sendCenterTipmsg)
