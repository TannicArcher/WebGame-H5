module("utils.systemfunc" , package.seeall)
setfenv(1, utils.systemfunc)

local systemStaticVar = _G.systemStaticVar -- 定时保存的系统数据
local staticChatVar = _G.staticChatVar

local SYSTEM_VAR_OLD_FILENAME = "runtime/sysvar_%d.bin"
local SYSTEM_VAR_FILENAME = "runtime/system_var_%d.bin"

--启动后临时数据
_G.systemDyanmicVar = _G.systemDyanmicVar or {}
local systemDyanmicVar = _G.systemDyanmicVar
local function getDyanmicVar()
	return systemDyanmicVar
end
require("utils.serverroute")
local common = require("utils.common")
local changeProcList = {}	--dyanmicVar数据转成staticVar保存，现在应该是不需要的了

function regChange(proc)
	common.reg(changeProcList, proc)
end

_G.OnChangeStaticVar = function()
	for _, func in pairs(changeProcList) do
		func()
	end
end

-------------- add begin --------------
local staticDataConfig = 
{
	-- 新版本的文件放在前面
	["CHAT_VAR"]   = { varName="CHAT_VAR",   fileName="runtime/system_chat_%d.bin", data=_G.staticChatVar, isLoad=nil },
	["SYSTEM_VAR"] = { varName="SYSTEM_VAR", fileName="runtime/system_var_%d.bin",  data=_G.systemStaticVar,   isLoad=nil },
}

-- 加载数据
function loadData(fileName)
	local file = io.open(fileName, "r")
	if file ~= nil then
		local s = file:read("*a")
		local data, err = utils.unserialize(s)
		file:close()
		print(string.format("load %s over", fileName))
		return data, err
	end
	print(string.format("file %s not exist", fileName))
	return {}
end

-- 保存数据
function saveData(fileName, data)
	if not data then
		print(string.format("save %s err data is nil", fileName))
		return
	end

	local file = io.open(fileName, "w")
	local s = utils.serialize(data)
	file:write(s)
	file:close()

	print(string.format("save %s over", fileName))
end

local function loadConfData(varName)
	local conf = staticDataConfig[varName]
	if not conf then
		print("load varName err no conf:" .. varName)
		return nil
	end
	if conf.isLoad or conf.data then
		return conf.data
	end

	local fileName = string.format(conf.fileName, System.getServerId())
	if conf.data == nil then
		local loadedData, err = loadData(fileName)
		if loadedData == nil or err then
			print(err)
			if varName == "SYSTEM_VAR" then
				assert(false)
			end
		end
		conf.data = loadedData or {}
	end
	conf.isLoad = true

	-- 兼容旧数据
	local function filterKey(t, s)
		local tmp = {}
		for k, v in pairs(t) do
			local i = tonumber(k)
			if i and i >= s then
				tmp[i] = v
			end
		end
		return tmp
	end
	if varName == "SYSTEM_VAR" and not next(conf.data) then
		local old_fileName = string.format(SYSTEM_VAR_OLD_FILENAME, System.getServerId())
		local ud = System.loadFileAsUserData(old_fileName)
		local data = bson.decode(ud)
		if data then
			local sysVar, chatVar = {}, {}
			for k, v in pairs(data) do
				if k == "chat" then
					chatVar[k] = v
					v.chat_list = filterKey(v.chat_list, v.chat_list_begin)
				elseif k == "Notice" then
					chatVar[k] = v
					v.notice_list = filterKey(v.notice_list, v.notice_list_begin)
				else
					sysVar[k] = v
				end
			end

			conf.data = sysVar
			staticDataConfig["CHAT_VAR"].data = chatVar
		end
	end

	return conf.data
end

local function saveConfData(varName)
	local conf = staticDataConfig[varName]
	if not conf then
		print("save varName err no conf:" .. varName)
		return
	end
	if not conf.data then
		print("save varName err not load:" .. varName)
		return
	end

	local fileName = string.format(conf.fileName, System.getServerId())
	saveData(fileName, conf.data)
end

local function loadAll()
	for varName, conf in ipairs(staticDataConfig) do
		loadConfData(varName)
	end
end

function saveAll()
	for varName, conf in pairs(staticDataConfig) do
		saveConfData(varName)
	end
end

local function getStaticVarByName(varName)
	if not staticDataConfig[varName] then
		print("get no conf var:" .. varName)
		return nil
	end

	if staticDataConfig[varName].data then
		return staticDataConfig[varName].data
	end

	return loadConfData(varName)
end
-------------- add end --------------

-- 程序退出的时候保存数据
_G.SaveOnGameStop = function()
	saveAll()
end

System.getDyanmicVar = getDyanmicVar

System.getStaticVar	= function() 
	if systemStaticVar then
		return systemStaticVar
	else
		_G.systemStaticVar = getStaticVarByName("SYSTEM_VAR")
		systemStaticVar = _G.systemStaticVar
		--print("+++++++++++++++++++systemStaticVar:" .. tostring(systemStaticVar))
		return systemStaticVar
	end
end

System.getStaticChatVar = function()
	if staticChatVar then
		return staticChatVar
	else
		_G.staticChatVar = getStaticVarByName("CHAT_VAR")
		staticChatVar = _G.staticChatVar
		--print("+++++++++++++++++++getStaticChatVar:" .. tostring(staticChatVar))
		return staticChatVar
	end
end
