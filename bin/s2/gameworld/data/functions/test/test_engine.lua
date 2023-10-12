module("test.test_engine" , package.seeall)
setfenv(1, test.test_engine)

function test_setglobalvar()
	local var = System.getStaticVar()
	var.test_globalvar = "abc"
end

function test_globalvar()
	local var = System.getStaticVar()
	Assert_eq("abc", var.test_globalvar, "test_globalvar err")
end

TEST("test_engine", "test_setglobalvar", test_setglobalvar)
TEST("test_engine", "test_globalvar", test_globalvar)

