module("utils.net.httpclient", package.seeall)

--封装http协议
local luaex = require("utils.luaex")

local addr = {}

function GetContent(host, port, url)
	if host == nil or port == nil or url == nil then
		return "", -100
	end

	local socket = LuaSocket:NewSocket()
	if socket == nil then
		print("create socket error!".. host)
		return "", -1
	end
	if addr[host] == nil then
		-- GetHostByName在linux中不是线程安全的，所以这里只获取一次便保存下来，下次不需要再调用
		addr[host] = LuaSocket:GetHostByName(host)
	end
	local ret = socket:connect(addr[host], port)
	if ret ~= 0 then
		LuaSocket:Release(socket, 1)
		print(string.format("connect to host error:%s:%d, ret:%d", host, port, ret))
		return "", -2
	end
	local str = string.format("GET %s HTTP/1.0\r\nHost:%s\r\n\r\n", url, host)
	-- print("GetContent send")
	-- print(str)
	ret = socket:send(str)
	if ret <= 0 then
		LuaSocket:Release(socket, 2)
		print(string.format("send to host error:%s:%d", host, port))
		return "", -3
	end

	local content = ""
	local len = 0
	content, len = socket:readall(len)
	if len <= 0 then
		LuaSocket:Release(socket, 3)
		print(string.format("recv content error:%s:%d", host, port))
		return "", -4
	end
	local _, es = string.find(content, "\r\n\r\n")
	if es ~= nil then
		content = string.sub(content, es + 1)
	end
	-- print("GetContent recv")
	-- print(content)
	LuaSocket:Release(socket, 4)

	return content, 0
end

