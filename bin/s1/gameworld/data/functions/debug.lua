-- 读取debug.txt文件加载调试相关信息

function loadDebug()
	local f = io.open("debug.txt")
	if f ~= nil then
		GAME_DEBUG = true

		local source = f:read("*a")
		local func = loadstring(source)
		func()
		f:close()
	end
end

loadDebug()