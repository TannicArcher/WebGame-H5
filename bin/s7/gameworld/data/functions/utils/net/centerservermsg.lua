module("utils.net.centerservermsg", package.seeall)

local LDataPack = LDataPack
local readInt = LDataPack.readInt

local dispatcher = {}

-- 注册网络包的处理函数，cmd是系统id，pid是系统内的消息号，
-- 其中pid==0，表示把这个系统的所有消息都用proc函数处理
function reg(sysid, pid, proc)
	if not proc then
		print(string.format("centerservermsg is nil with %d:%d", sysid, pid))
	end

	local syslist = dispatcher[sysid]
	if not syslist or type(syslist) ~= "table" then
		dispatcher[sysid] = {}
		syslist = dispatcher[sysid]
	end

	local plist = nil

	if pid == 0 then
		plist = syslist.allproc
		if plist == nil or type(plist) ~= "table" then
			syslist.allproc = {}
			plist = syslist.allproc
		end
	else
		if syslist.allproc ~= nil then
			print(string.format("error:has set allproc before!%d:%d", sysid, pid))
		end
		plist = syslist[pid]
		if plist == nil or type(plist) ~= "table" then
			syslist[pid] = {}
			plist = syslist[pid]
		end
	end

	for _, func in ipairs(plist) do
		if func == proc then
			return false
		end
	end
	table.insert(plist, proc)

	return true
end

function OnNetMsg(pack)
	local sid, sysid, pid = LDataPack.readData(pack, 3, dtInt, dtByte, dtByte)
	-- print(string.format("OnNetMsg:%d,%d,%d", sid, sysid, pid))

	-- 只有测试的情况下，才接收自己服发出的数据包
	if (sid == System.getServerId() and sysid ~= 255) then return end

	local syslist = dispatcher[sysid]
	if syslist == nil then return end

	local plist = syslist.allproc
	if plist == nil then
		plist = syslist[pid]
	end

	if plist == nil then return end

	for _,v in ipairs(plist) do
		v(pack, sid, sysid, pid)
	end
end

_G.OnCenterMsg = OnNetMsg
