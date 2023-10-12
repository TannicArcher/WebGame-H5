module("test.test_word_filter" , package.seeall)
setfenv(1, test.test_word_filter)

require("test.fw")

function test_word_filter( ... )
	local st = System.getTick()
	for _,v in ipairs(fw) do
		System.filterText(v)
	end
	Assert((System.getTick() - st) <= 100, "test_word_filter time too long")
end


TEST("filter", "test_word_filter", test_word_filter)


