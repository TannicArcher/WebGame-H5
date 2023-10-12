--处理GM相关的操作 
module("systems.gm.gmsystem" , package.seeall)
setfenv(1, systems.gm.gmsystem)

require("test.gm_cmd_config")

--GM指令是以@开头的命令,使用空格分隔，比如@additem 102 1
gmCmdHandlers = {}

local LActor = LActor

function setGmeventHander(cmd, hander)
	if gmCmdHandlers == nil then
		gmCmdHandlers = {}
	end

	gmCmdHandlers[cmd] = hander
end

function onGmCmd(actor, packet)
	if LActor.getGmLevel(actor) == 0 then 
		return
	end
	local msg = LDataPack.readString(packet)
	print("on GmMsg:"..msg.. " actor:"..LActor.getActorId(actor))
	ProcessGmCommand(actor, msg)
end

function ProcessGmCommand(actor, msg, args)
	if args then
		-- 替换参数
		for i,v in ipairs(args) do
			msg = string.gsub(msg, string.format(" {%d} ", i), string.format(" %s ", v))
		end
	end
	-- print("ProcessGmCommand:" .. msg)

	msg = msg:match("^%s*(.*)%s*$")
	if #msg < 2 then return end

	if "@" ~= string.sub(msg, 1, 1) then return end

	msg = string.sub(msg, 2)

	msg = msg:match("^%s*(.*)%s*$")
	local cmd, strArgs = msg:match("^(%S+)%s*(.*)%s*$")
	if nil == cmd or "" == cmd then return end

	local args = {}

	for arg in string.gmatch(strArgs, "%s*(%S+)") do
		table.insert(args, arg)
	end

	if nil == gmCmdHandlers then return end

	local handle = gmCmdHandlers[cmd]
	if nil == handle then
		local config_gm = GmCmdConfig[cmd]
		if config_gm ~= nil then
			-- gm命令的组合
			for _,cmdstr in ipairs(config_gm) do
				ProcessGmCommand(actor, cmdstr, args)
			end
			return
		end
		print("No such gm command")
		LActor.sendTipmsg(actor, "No such gm command", ttTipmsgWindow)
		return
	end

	local ret = handle(actor, args)
	local s = "gm cmd:%s successful!"
	if not ret then
		s = "gm cmd:%s fail!"
	end

	LActor.sendTipmsg(actor, string.format(s, cmd), ttTipmsgWindow)
end

netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_GmCmd, onGmCmd)
