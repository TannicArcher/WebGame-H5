package.path = package.path .. ";./data/config/?.lua;./data/functions/?.lua"
-- 用于执行异步操作的脚本，比如访问url获取结果这类型的操作

-- funcname是执行的函数名，后面是参数
function main(funcname, ...)
	local func = _G[funcname]
	if func ~= nil then
		return func(arg)
	end
end

local httpclient = require("utils.net.httpclient")

-- 访问url接口，返回url的内容
function getUrlContent(params)
	return httpclient.GetContent(params[1], params[2], params[3])
end

-- 使用curl获取网页信息
function curlget(params)
	return System.curlGet(params[1])
end
