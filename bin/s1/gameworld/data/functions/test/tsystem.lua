module("test.tsystem" , package.seeall)
setfenv(1, test.tsystem)
--[[
模拟c++接口System
--]]

-- 用来保存玩家的名字对应的玩家的表（table）
local actorname = {}

-- 覆盖c++的System.getActorPtr 接口
function getActorPtr(name)
	return actorname[name]
end

-- 设置玩家名字对应的table
function setActorPtr(name, actor)
	actorname[name] = actor
end


--=================模拟测试好友合服情况===================


-- 覆盖c++的System.getServerId 接口
-- 目的就是为了让获取到的服务器ID与玩家当前的服务器ID不一样
-- 模拟合服通知
function getServerId(actor)
	local new_server_id = LActor.getServerId(actor) + 1
	print("new_serverId "..new_server_id)
	return new_server_id 
end

-- 覆盖c++的System.sendDataToCenter 接口
function sendDataToCenter(npack)
	System.sendDataToCenter(npack)
end

--=================模拟测试好友合服情况===================