module("utils.algorithm", package.seeall)
setfenv(1, utils.algorithm)

--二分查找的基本判定方法
--找最后的插入位置
function defbinFunc(b1, b2)
	if b1 < b2 then return -1
	elseif b1 > b2 then return 1
	else return 0 end
end

--二分查找
--tab 要检索的表
--item 要搜索的玩意儿
--binFunc 用于比较的函数，当纯数字tab时该参数可以为空，默认检索到的位置是最后的插入位置
function binSearch(tab, item, binFunc)
	if tab == nil or #tab == 0 then return 1 end
	if binFunc == nil then binFunc = defbinFunc end
	local low, high = 1, #tab
	local ceil = math.ceil
	while low <= high do
		local mid = ceil((high + low) / 2)
		local val = tab[mid]
		if binFunc(val, item) <= 0 then
			low = mid + 1
		else
			high = mid - 1
		end
	end
	return low
end

--查找表中的最大最小值
function minMaxSearch(tab, func)
	if func == nil then
		func = defbinFunc
	end
	if tab == nil or #tab == 0 then return end
	local min = tab[1]
	local max = tab[1]
	for _,v in pairs(tab) do
		if func(min, v) > 0 then min = v
		elseif func(max, v) < 0 then max = v end
	end
	return min, max
end

--获取下一个年月
function getNextMonth(year, mon)
	mon = mon + 1
	if mon > 12 then
		mon = 1
		year = year + 1
	end
	return year, mon
end


