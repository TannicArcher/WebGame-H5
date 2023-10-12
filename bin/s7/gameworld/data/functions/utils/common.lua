module("utils.common", package.seeall)
setfenv(1, utils.common)


-- 定义一些很多地方会用的函数

-- 很多module会定义reg函数，这里定义一个公共的函数
function reg(tbl, proc, check)
	if check then
		for _ , v in ipairs(tbl) do 
			if v == proc then return end
		end
	end
	table.insert(tbl, proc)
end

function callFuncInTbl(tbl, ...)
	for _ , proc in ipairs(tbl) do
		proc(...)
	end
end
