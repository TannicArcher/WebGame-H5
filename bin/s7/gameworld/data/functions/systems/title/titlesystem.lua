--称号系统
module("titlesystem", package.seeall)

local conf = TitleConf
local function getVar(actor)
    local var = LActor.getStaticVar(actor)
    if var then
        if var.titleData == nil then var.titleData = {} end
        return var.titleData
    end
    return nil
end

--更新属性
local function updateAttr(actor)

    local attrs = LActor.getTitleAttrs(actor)
    if attrs == nil then
        print("get title attr error.."..LActor.getActorId(actor))
        return
    end

    local var = getVar(actor)
    if var.titles == nil then var.titles = {} end

    -- local now_t = System.getNowTime()
    attrs:Reset()
    for k,v in pairs(conf) do
        -- if var.titles[k] and (var.titles[k].endTime == 0 or var.titles[k].endTime > now_t) then
        if var.titles[k] then
            for _, attr in pairs(v.attrs) do
                attrs:Add(attr.type, attr.value)
            end

            for pos, pre in pairs(v.attr_precent or {}) do
                local equipAttr = LActor.getEquipAttr(actor, roleId, pos)
                for attrType = Attribute.atHpMax, Attribute.atTough do
                    if 0 < (equipAttr[attrType] or 0) then
                        attr:Add(attrType, math.floor(equipAttr[attrType]*pre/10000))
                    end
                end
            end
        end
    end
    LActor.reCalcTitleAttr(actor)

end

--称号过期
local function checkTimeOut(actor)

    local attrs = LActor.getTitleAttrs(actor)
    if attrs == nil then
        print("get title attr error.."..LActor.getActorId(actor))
        return
    end

    local var = getVar(actor)
    if var.titles == nil then var.titles = {} end

    local recalc = false
    local now_t = System.getNowTime()
    for k,v in pairs(conf) do
        if var.titles[k] and var.titles[k].endTime ~= 0 and  now_t >= var.titles[k].endTime then
            recalc = true
            for _, attr in pairs(v.attrs) do
                attrs:Add(attr.type, -attr.value)
            end
            -- var.titles[k] = nil
            delitle(actor, k)
        end
    end
    if recalc then
        LActor.reCalcTitleAttr(actor)
    end

end

function onRun(actor)
    checkTimeOut(actor)
end

function addTitle(actor, tId)
    -- print("------------ addTitle")
    local tConf = conf[tId]
    if tConf == nil then return end

     local var = getVar(actor)
    if var.titles == nil then var.titles = {} end

    local isChange = false
    if tConf.keepTime == 0 then
        if var.titles[tId] == nil then
            var.titles[tId] = {}
            var.titles[tId].endTime = 0
            isChange = true
        end
    else
        if var.titles[tId] == nil then
            var.titles[tId] = {}
            var.titles[tId].endTime = System.getNowTime()
            isChange = true
        end
        var.titles[tId].endTime = var.titles[tId].endTime + tConf.keepTime
    end
    if isChange then
        updateAttr(actor)

        local pack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Add)
        if pack == nil then return end
        LDataPack.writeInt(pack, tId)
        LDataPack.writeInt(pack, var.titles[tId].endTime)
        LDataPack.flush(pack)
    end
    --以后加一个更新单个称号信息的协议，不用更新整个列表
    -- getTitlesInfo(actor, nil)
    autoWear(actor, tId)

end

function delitle(actor, tId, isUpdateAttr)
    if actor == nil then return end
    local tConf = conf[tId]
    if tConf == nil then return end

    local var = getVar(actor)
    if var.titles == nil then return end
    if var.titles[tId] == nil then return end
    var.titles[tId] = nil
    if isUpdateAttr then
        updateAttr(actor)
    end
    if var.roleTitle then
        for i=1, #var.roleTitle do
            if var.roleTitle[i].title == tId then
                -- var.roleTitle[i].title = 0
                setTitle(actor, var.roleTitle[i].id, 0)
                break
            end
        end
    end

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Del)
    if pack == nil then return end
    LDataPack.writeInt(pack, tId)
    LDataPack.flush(pack)
end

--自动穿戴
function autoWear(actor, tId)
    local tConf = conf[tId]
    if tConf == nil then return end

     local var = getVar(actor)
    if var.titles == nil then return end
    if var.titles[tId] == nil then return end


    if var.roleTitle == nil then var.roleTitle = {} end

    local info
    local curRole = nil
    --检查是不是有角色已经穿戴了称号，有就不做了
    for i=1, #var.roleTitle do
        if var.roleTitle[i] and var.roleTitle[i].title > 0 then return end
    end

    if tConf.job == nil then
        setTitle(actor, 0, tId)
    else
        local rCount = LActor.getRoleCount(actor)
        local job
        local role
        for i=1, rCount-1 do
            role = LActor.getRole(actor, i-1)
            if role then
                job = LActor.getJob(role)
                if job == tConf.job then
                    setTitle(actor, i-1, tId)
                end
            end
        end
    end

end

local function attrInit(actor)
    local var = getVar(actor)
    if var.roleTitle == nil then var.roleTitle = {} end
    local info
    for i=1, #var.roleTitle do
        info = var.roleTitle[i]
        if info then
            LActor.setRoleTitle(actor, info.id, info.title)
        end
    end

    updateAttr(actor)
	addtitlelogic.onLogin(actor)
end

function getTitlesInfo(actor, pack)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.sTitleCmd_Info)
    if npack == nil then return end
    local count = 0
    local pos = LDataPack.getPosition(npack)
    LDataPack.writeInt(npack, count)    --临时个数

    local var = getVar(actor)
	--策划改错配置的,补锅
	if not var.tbug then
		print(LActor.getActorId(actor).." start repair title config bug")
		if var.titles then
			print(LActor.getActorId(actor).." need repair title config bug")
			local temp = {}
			if var.titles[8] then temp[10]=var.titles[8].endTime end
			if var.titles[9] then temp[11]=var.titles[9].endTime end
			if var.titles[10] then temp[12]=var.titles[10].endTime end
			if var.titles[11] then temp[13]=var.titles[11].endTime end
			if var.titles[12] then temp[14]=var.titles[12].endTime end
			var.titles = {}
			for tId,endTime in pairs(temp) do
				print(LActor.getActorId(actor).." repair title config bug, tId:"..tId..", endTime:"..endTime)
				var.titles[tId] = {}
				var.titles[tId].endTime = endTime
			end
		end
		var.tbug = 1
	end
	--补锅结束

    --二次补锅
    local isBug = false
    if not var.tbug2 then
        print(LActor.getActorId(actor).." start repair title config bug2")
        if var.titles then
            print(LActor.getActorId(actor).." need repair title config bug2")
            if var.titles[22] then var.titles[22] = nil end
            if var.titles[23] then var.titles[23] = nil end

            isBug = true
        end
        var.tbug2 = 1
    end
    --二次补锅结束

    if var.titles == nil then var.titles = {} end
    for k,v in pairs(conf) do
        if var.titles[k] then
            LDataPack.writeInt(npack, k)
            LDataPack.writeInt(npack, var.titles[k].endTime or 0)
            count = count + 1
        end
    end

    local newpos = LDataPack.getPosition(npack)
    LDataPack.setPosition(npack, pos)
    LDataPack.writeInt(npack, count)
    LDataPack.setPosition(npack, newpos)

    LDataPack.flush(npack)

    if isBug and var.roleTitle then
        for i=1, #var.roleTitle do
            local info = var.roleTitle[i]
            if info.title == 22 or info.title == 23 then
                print(LActor.getActorId(actor).." need change bug2")
                setTitle(actor, info.id, 0)
            end
        end

        updateAttr(actor)
    end
end

function setTitle(actor, roleId, titleId)
    if titleId == 0 then
        local var = getVar(actor)
        if var == nil then return end
        if var.roleTitle == nil then var.roleTitle = {} end

        local info
        local curRole = nil
        for i=1, #var.roleTitle do
            info = var.roleTitle[i]
            if not curRole and info.id == roleId then
                curRole = var.roleTitle[i]
            end
        end

        if curRole then
            curRole.title = titleId
        else
            local idx = #var.roleTitle
            var.roleTitle[idx + 1] = {}
            var.roleTitle[idx + 1].id = roleId
            var.roleTitle[idx + 1].title = titleId
        end

        LActor.setRoleTitle(actor, roleId, titleId)
        updateRoleTitle(actor, roleId, titleId)
        return 
    end

    if conf[titleId] == nil then return end
    local rold = LActor.getRole(actor, roleId)
    if rold == nil then return end

    if conf[titleId].job ~= nil and LActor.getJob(rold) ~= conf[titleId].job then
        return
    end

    local var = getVar(actor)
    if var == nil then return end
    if var.roleTitle == nil then var.roleTitle = {} end

    if var.titles == nil then return end
    if var.titles[titleId] == nil then return end
    local info
    local isUse = false
    local curRole = nil
    for i=1, #var.roleTitle do
        info = var.roleTitle[i]
        if isUse == false and titleId == info.title then
            isUse = true
        end
        if not curRole and info.id == roleId then
            curRole = var.roleTitle[i]
        end
    end
    if isUse then
        print("当前称号已被其他角色使用")
        return
    end
    if curRole then
        curRole.title = titleId
    else
        local idx = #var.roleTitle
        var.roleTitle[idx + 1] = {}
        var.roleTitle[idx + 1].id = roleId
        var.roleTitle[idx + 1].title = titleId
    end

    LActor.setRoleTitle(actor, roleId, titleId)
    updateRoleTitle(actor, roleId, titleId)
end

function setRoleTitle(actor, pack)
    local roleId = LDataPack.readShort(pack)
    local titleId = LDataPack.readInt(pack)

    setTitle(actor, roleId, titleId)
end

function updateRoleTitle(actor, roleId, titleId)
    local role = LActor.getRole(actor, roleId)
    if role == nil then return end
    local handle = LActor.getHandle(role)

    local pack = LDataPack.allocPacket(actor, Protocol.CMD_Title, Protocol.cTitleCmd_SetTitle)
    if pack == nil then return end
    LDataPack.writeInt64(pack, handle)
    LDataPack.writeInt(pack, titleId)
    LDataPack.flush(pack)
end

function cbChangeTitle(actor, oper, tId)
    if oper == 1 then
        print("离线删除称号")
        delitle(actor, tId, true)
    elseif oper == 2 then
        addTitle(actor, tId)
    end
end

local function onLogin(actor)
	getTitlesInfo(actor, nil)
end

_G.titleAttrInit = attrInit
_G.addTitle = addTitle
_G.onTitleRun = onRun

_G.cbChangeTitle = cbChangeTitle

actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Title, Protocol.cTitleCmd_Info, getTitlesInfo)
netmsgdispatcher.reg(Protocol.CMD_Title, Protocol.cTitleCmd_SetTitle, setRoleTitle)



