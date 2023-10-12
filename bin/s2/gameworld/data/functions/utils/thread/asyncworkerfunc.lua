--这里定义使用异步线程的接口，包括发送命令到异步线程，以及回调的处理
module("utils.thread.asyncworkerfunc", package.seeall)
setfenv(1, utils.thread.asyncworkerfunc)

local LAsyncWk = {}
local LAsyncWkMsg = {}

local webhost, webport = System.getWebServer()

-- 异步线程完成后的回调
_G.OnAsyncWorkFinish = function(guid, ...)
	if not guid then return end
	local callback = LAsyncWkMsg[guid]
	if callback ~= nil then
		callback[1](callback[2], arg)
		LAsyncWkMsg[guid] = nil
	end
end

-- 用于封装发给异步线程命令的函数
-- params 为执行回调函数时的参数列表，sendparams是发送给异步线程执行命令所需要的参数
-- func是执行完后的回调函数
function sendMessage(params, func, sendparams)
	local guid = System.sendMessageToAsyncWorker(sendparams)
	if guid ~= nil and guid ~= 0 and func ~= nil then
		LAsyncWkMsg[guid] = {func, params}
	end
end

-- 用于测试异步功能的gm命令
function gm_testThread(sysarg)
	local upval = 100
	sendMessage({"test"}, function (params, arg)
		-- 这里使用的是闭包，但是注意外部指针类型的值不能在这里使用
		-- 因为这里是异步操作，当执行这个函数的时候，可能指针已被释放了
		-- 比如sysarg类型的指针，可以用actorid来代替，根据这个重新获取玩家指针
		print(params[1])	-- print "test"
		print(arg[1])		-- 执行getUrlContent后返回的值,共2个值
		print(arg[2])		-- 错误码
		print(upval)		-- pirnt 100
	end, 
	-- getUrlContent为异步线程要执行的lua函数，具体看asyncworker.lua
	{"getUrlContent", "localhost", 8080, "/TencentOpen/test.jsp"})	
end

-- 以下是一些公共的接口
-- 访问某个web的地址，即调用接口，不需要web的返回值
_G.sendMsgToWeb = function(url, func, funcParams)
	sendMessage(funcParams, func, {"getUrlContent", webhost, webport, url})
	--sendMessage(funcParams, func, {"curlget", string.format("%s:%d%s", webhost, webport, url)})
end

-- 后台非要在不同服务器处理逻辑服发的请求
_G.sendMsgToHost = function(host, port, url, func, funcParams)
    sendMessage(funcParams, func, {"getUrlContent", host, port, url})
end
