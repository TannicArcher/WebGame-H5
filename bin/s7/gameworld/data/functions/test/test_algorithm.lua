module("test.test_algorithm" , package.seeall)
setfenv(1, test.test_algorithm)

local algorithm = require("utils.algorithm")

local list = {-1, 1, 2, 2, 3, 5}

local defbinFuncAtts = {
	{params = {5, 3}, ret = 1, err = "err:when bi > b2"},
	{params = {1, 3}, ret = -1, err = "err:when bi < b2"},
	{params = {3, 3}, ret = 0, err = "err:when bi = b2"},
}

local binSearchAtts = {
	{para = -5, ret = 1 ,err = "err:when value < tab[1]."},
	{para = -1, ret = 2 ,err = "err:when value = tab[1]."},
	{para = 2, ret = 5 ,err = "err:when value more then one in tab."},
	{para = 3, ret = 6 ,err = "err:when value only one in tab."},
	{para = 4, ret = 6 ,err = "err:when value not in tab."},
	{para = 5, ret = 7 ,err = "err:when value = tab[last]."},
	{para = 9, ret = 7 ,err = "err:when value > tab[last]."},
}

local minMaxSearchAtts = {
	{plist = {}, ret = {nil, nil}, err = "err:when list is {}."},
	{plist = {1}, ret = {1, 1}, err = "err:when list item count is 1."},
	{plist = {3, 3, 3}, ret = {3, 3}, err = "err:when list items are all the same."},
	{plist = {1, 2}, ret = {1, 2}, err = "err:...Unknown."},
	{plist = {1, 4, 2, -1, -1, 8, 8}, ret = {-1, 8}, err = "err:if min and max more than one in list."},
}

local nextMonthAtts = {
	{params = {2014, 2}, ret = {2014, 3}, err = "...Unknown"},
	{params = {2014, 12}, ret = {2015, 1}, err = "...goto Next Year haven some err."},
}

local function test_defbinFunc( ... )
	for _,v in pairs(defbinFuncAtts) do
		Assert_eq(v.ret, algorithm.defbinFunc(unpack(v.params)),string.format("algorithm.defbinFunc-> %s",v.err))
	end
end

local function test_binSearch( ... )
	for _,v in pairs(binSearchAtts) do
		Assert_eq(v.ret, algorithm.binSearch(list, v.para), string.format("algorithm.binSearch-> %s", v.err))
	end
end

local function test_binFunc(b1, b2)
	return algorithm.defbinFunc(b1.num, b2.num)
end

local function test_random_binSearch( ... )
	local test_list = {}
	local TEST_COUNT = 500
	for i=1,TEST_COUNT do
		local item = {}
		item.id = i
		item.num = math.random(-100, 100) 
		local indx = algorithm.binSearch(test_list, item, test_binFunc)
		table.insert(test_list, indx, item)
	end
	local flag = true
	local str = ""
	for i=1, TEST_COUNT do
		if i == TEST_COUNT then return end
		if test_list[i].num == test_list[i + 1].num then
			flag = test_list[i].id < test_list[i + 1].id
			str = "algorithm.binSearch haven error by same number."
		else 
			flag = test_list[i].num < test_list[i + 1].num
			str = "algorithm.binSearch haven error by order."
		end
		Assert(flag, str)
		if flag == false then break end
	end
end

local function test_minMaxSearch( ... )
	for _,v in pairs(minMaxSearchAtts) do
		local min, max = algorithm.minMaxSearch(v.plist)
		Assert(min == v.ret[1] and max == v.ret[2], v.err)
	end
end

local function test_getNextMonth( ... )
	for _,v in pairs(nextMonthAtts) do
		local year, mon = algorithm.getNextMonth(unpack(v.params))
		Assert(year == v.ret[1] and mon == v.ret[2], v.err)
	end
end


TEST("algorithm", "test_defbinFunc", test_defbinFunc, false)
TEST("algorithm", "test_binSearch", test_binSearch, false)
TEST("algorithm", "test_random_binSearch", test_random_binSearch, false)
TEST("algorithm", "test_minMaxSearch", test_minMaxSearch, false)
TEST("algorithm", "test_getNextMonth", test_getNextMonth, false)

