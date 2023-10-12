--处理聊天相关的操作 
module("base.notice.noticemanager" , package.seeall)
setfenv(1, base.notice.noticemanager)

local postscripttimer = require("base.scripttimer.postscripttimer")
 
require("protocol")

local noticeFile = "runtime/notice.txt"

_G.notice = _G.notice or {}
_G.noticePos = _G.noticePos or 0;

function broadcastNotice(info)
	local nowTime = System.getNowTime()
	if info.nextSendTime and info.nextSendTime > nowTime then return false end

	if info.startTime == 0 or info.endTime == 0 then
		System.broadcastTipmsg(msg, info.displayPos)
	else
		if nowTime > info.startTime and nowTime < info.endTime then
			System.broadcastTipmsg(info.msg, info.displayPos)
		elseif nowTime >= info.endTime then
			deleteNotice(info.msg)
			_G.noticePos = _G.noticePos - 1
			return false
		end
	end
	info.nextSendTime = nowTime + info.interval
	return true
end

--轮转公告
function rollNotice()
	_G.noticePos = _G.noticePos + 1
	if _G.noticePos > #_G.notice then
		_G.noticePos = 1
	end
	local startPos = _G.noticePos
	--循环查找可发送的公告startPos找到最后
	for pos = startPos, #_G.notice do
		local data = _G.notice[pos]
		--如果发送出去了就可以跳出了
		if data and broadcastNotice(data) then return end
	end

	--没有的话从头找到startPos
	for pos = 1, startPos-1 do
		local data = _G.notice[pos]
		--如果发送出去了就可以跳出了
		if data and broadcastNotice(data) then return end
	end
end

local function loadNotice()
	_G.notice = {}

	local f = io.open(noticeFile)
	if not f then return end
	for line in io.lines(noticeFile) do
		for msg, displayPos, startTime, endTime, interval in string.gmatch(line, "(.*)|(%d+)%*(%d+)&(%d+)&(%d+)") do
			local oneNotice = {}
			oneNotice.msg = msg
			oneNotice.displayPos = tonumber(displayPos)
			oneNotice.startTime = tonumber(startTime)
			oneNotice.endTime = tonumber(endTime)
			oneNotice.interval = tonumber(interval)
			table.insert(_G.notice, oneNotice)
		end
	end
	f:close()
end

local function saveNotice()
	local f = io.open(noticeFile, "w+")
	if nil == f then
		return
	end

	for key, value in pairs(_G.notice) do
		f:write(string.format("%s|%d*%d&%d&%d\n", value.msg, value.displayPos, value.startTime, value.endTime, value.interval))
	end
	f:close()
end

--添加一条公告
function addNotice(msg, displayPos, startTime, endTime, interval)
	if not msg or type(msg) ~= "string" then return false end

	if not displayPos or type(displayPos) ~= "number" then return false end

	if not startTime or type(startTime) ~= "number" then return false end

	if not endTime or type(endTime) ~= "number" then return false end

	if not interval or type(interval) ~= "number" then return false end

	local oneNotice = {}
	oneNotice.msg = msg
	oneNotice.displayPos = displayPos
	oneNotice.startTime = startTime
	oneNotice.endTime = endTime
	oneNotice.interval = interval
	table.insert(_G.notice, oneNotice)

	saveNotice()
	return true
end

--[[
Comments:删除指定的公告
sMsg:必须全文匹配才能成功删除
@Return void:
]]
function deleteNotice(msg)
	--添加一条公告
	if nil == msg or "string" ~= type(msg) then
		return false
	end

	local find = false

	for i = 1, #_G.notice do
		if _G.notice[i].msg == msg then
			table.remove(notice, i)
			find = true
			break
		end
	end

	-- 遍历完再做这事情更保险
	if find then 
		saveNotice() 
		if (noticePos > #_G.notice) then
			noticePos = #_G.notice
		end
	end
	return find
end

function delAllNotice()
	_G.notice = {}
	saveNotice()
end

local function initNoticeManager()
	loadNotice()
	postscripttimer.postScriptEvent(nil, 0, function(...) rollNotice(...) end, 10000, -1)
end

engineevent.regGameStartEvent(initNoticeManager)

