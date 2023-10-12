module("test.tlactor" , package.seeall)
setfenv(1, test.tlactor)
--[[
模拟c++接口LActor
--]]
-- 构造一个模拟的Actor
function createActor()
	local actor = {}
	actor.props = {}
	return actor
end

function getIntProperty(actor, pid)
	return actor.props[pid] or 0
end

function setIntProperty(actor, pid, val)
	actor.props[pid] = val
end

function sendTipmsg(actor, msg)
	print(string.format("tip msg:%s", msg))
end

