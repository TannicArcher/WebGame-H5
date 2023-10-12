module("test.test_dyanmic", package.seeall)
setfenv(1, test.test_dyanmic)

local fbConfig = FuBen
function test_fubenDyanmic()
	--创建一个副本
	--local randIdx = System.getRandomNumber(#fbConfig) + 1
	local handle = Fuben.createFuBen(1)--fbConfig[randIdx].fbid)
	local fuben = Fuben.getFubenPtr(handle)
	if not fuben then return end
	local var = Fuben.getDyanmicVar(fuben)
	var.test = "testing"
	local var_t = Fuben.getDyanmicVar(fuben)
	Assert_eq("testing", var_t.test, "test_fubenDyanmic error")
end

function test_guildDyanmic()

end


TEST("test_dyanmic", "test_fubenDyanmic", test_fubenDyanmic)
TEST("test_dyanmic", "test_guildDyanmic", test_guildDyanmic)