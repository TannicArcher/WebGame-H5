module("utils.plus.export_G", package.seeall)
setfenv(1, utils.plus.export_G)



require("developlist")
local luaex = require("utils.luaex")

local function sortFunc(st1, st2)
	return st2[1] < st1[1]
end
-- 导出_G的内容到_G.lua 文件，供客户端导出工具使用
function export_G( ... )
	if not luaex.tabContains(DevelopList, System.getServerId()) then
		return
	end
	
	local fo = io.open("./data/functions/_G.lua", "w+")
	fo:write("--自动生成的文件，不要修改!!\n")
	local sortTable = {}
	for k,v in pairs(_G) do
		if (type(v) == "number") then
			table.insert(sortTable, {k,v})
		end
	end
	table.sort(sortTable, sortFunc)
	for _ , info in ipairs(sortTable) do
		fo:write(string.format("_G[\"%s\"] = %d\n", info[1], info[2]))
	end
	fo:flush()
	fo:close()
end

engineevent.regGameStartEvent(export_G)
