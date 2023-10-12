module("zhuangbansystem", package.seeall)
local ZHUANGBAN_MAXPOS = 3
local ZHUANGBAN_MAXID = #ZhuangBanId

local systemId = Protocol.CMD_ZhuangBan
--[[
{
    nextTime = 0,
    zhuangban = {
        [zhuangbanid] = time,
    },
    zhuangbanlevel = {
        [zhuangbanid] = level,  --装扮等级
    }
    use = 
    {
        [0] = {
            { [pos] = zhuangbanid },
        }
    }
}
--]]

local function isOpenZhuangBan(actor)
    return true
end

local function initVar(var)
    var.nextTime = 0
    var.zhuangban = {}
    var.zhuangbanlevel = {}
    var.use = {}
    for i=0, 2 do
        var.use[i] = {}
        for pos = 1, ZHUANGBAN_MAXPOS do
            var.use[i][pos] = 0
        end
    end
end

function getStaticVar(actor)
    local actorVar = LActor.getStaticVar(actor)
    if actorVar.zhuangban == nil then
        actorVar.zhuangban = {}
        initVar(actorVar.zhuangban)
    end
    return actorVar.zhuangban
end

local function checkRoleIndexAndZhuangbanId(actor, roleindex, id)
     if roleindex < 0 or roleindex > LActor.getRoleCount(actor)-1 then
        print("zhuangban roleindex is err" .. tostring(roleindex))
        return
    end

    local conf = ZhuangBanId[id]
    if not conf then
        print("zhuangban conf is not found" .. tostring(id))
        return
    end

    local roledata = LActor.getRoleData(actor, roleindex)
    if roledata.job ~= conf.roletype then
        print("zhuangban job not match")
        return
    end

    return true
end

local function checkZhuangbanIdGetRoleIndex(actor, id)
    local conf = ZhuangBanId[id]
    if not conf then
        print("zhuangban conf is not found" .. tostring(id))
        return
    end

    local jobroleindex = nil
    local count = LActor.getRoleCount(actor)
    for roleindex = 0, count-1 do
        local roledata = LActor.getRoleData(actor, roleindex)
        if roledata.job == conf.roletype then
            jobroleindex = roleindex
            break
        end
    end

    return jobroleindex
end

--获取装扮等级
local function getLevel(actor, id)
    local data = getStaticVar(actor)
    if not data.zhuangbanlevel then data.zhuangbanlevel = {} end
    return data.zhuangbanlevel[id] or 1
end

function handleQuery(actor, packet)
    local var = getStaticVar(actor)

    local tmp, count = {}, 0
    for i = 1, ZHUANGBAN_MAXID do
        tmp[i] = var.zhuangban[i]
        if tmp[i] then
            count = count + 1
        end
    end
    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_QueryInfo)
    if not pack then return end
    -- 装扮拥有信息
    LDataPack.writeInt(pack, count)
    for id, t in pairs(tmp) do
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, t)
        LDataPack.writeInt(pack, getLevel(actor, id))
    end
    -- 装扮使用信息
    local rolenum = LActor.getRoleCount(actor)
    LDataPack.writeByte(pack, rolenum)
    for roleindex = 0, rolenum-1 do
        local use = var.use[roleindex]
        for pos = 1, ZHUANGBAN_MAXPOS do
            LDataPack.writeInt(pack, use[pos] or 0)
        end
    end
    LDataPack.flush(pack)
end

function handleActive(actor, packet)
    local id = LDataPack.readInt(packet)
    local roleindex = checkZhuangbanIdGetRoleIndex(actor, id) 
    if not roleindex then
        print("zhuangban handleActive not found roletype" .. tostring(id))
        return
    end
    
    local conf = ZhuangBanId[id]
    local var = getStaticVar(actor)

    if var.zhuangban[id] then
        print("zhuangban handleActive already active" .. tostring(id))
        return
    end

    local itemId, num = conf.cost.itemId, conf.cost.num
    if LActor.getItemCount(actor, itemId) < num then
        print("zhuangban can not active, itemId not enough" .. tostring(id))
        return false
    end
    LActor.costItem(actor, itemId, num, "zhuangban active")

    local invalidTime = 0
    if conf.invalidtime then
        invalidTime = conf.invalidtime + System.getNowTime()
    end
    var.zhuangban[id] = invalidTime
    LActor.log(actor, "zhuangbansystem.handleActive", "mark1", id, var.zhuangban[id])

    --激活默认等级为1
    if not var.zhuangbanlevel then var.zhuangbanlevel = {} end
    var.zhuangbanlevel[id] = 1

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Active)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.writeInt(pack, invalidTime)
    LDataPack.writeInt(pack, var.zhuangbanlevel[id])
    LDataPack.flush(pack)

    calcAttr(actor)

    if invalidTime ~= 0 then
        setInvalidTimer(actor, true, true)
    end

    -- 广播
    local actorname = LActor.getActorName(LActor.getActorId(actor))
    local posname = ZhuangBanConfig.zhuangbanpos[conf.pos]
--    local msg = string.format(ZhuangBanConfig.activecontext, actorname, posname, conf.name)
    noticemanager.broadCastNotice(ZhuangBanConfig.noticeid, actorname, posname, conf.name)
end

function handleUse(actor, packet)
    local roleindex = LDataPack.readByte(packet)
    local id = LDataPack.readInt(packet)
    print("recv handleUse client" .. roleindex .. ", " .. id)
    if not checkRoleIndexAndZhuangbanId(actor, roleindex, id) then
        return
    end

    local conf = ZhuangBanId[id]
    local var = getStaticVar(actor)

    if not var.zhuangban[id] then
        print("zhuangban handleUse, not active" .. tostring(id))
        return
    end
    var.use[roleindex][conf.pos] = id

    LActor.log(actor, "zhuangbansystem.handleUse", "mark1", roleindex, conf.pos, id)

    local v = var.use[roleindex]
    local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
    LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3)

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Use)
    if not pack then return end
    LDataPack.writeByte(pack, roleindex)
    LDataPack.writeByte(pack, conf.pos)
    LDataPack.writeInt(pack, id)
    LDataPack.flush(pack)
end

function handleUnUse(actor, packet)
    local roleindex = LDataPack.readByte(packet)
    local id = LDataPack.readInt(packet)
    if not checkRoleIndexAndZhuangbanId(actor, roleindex, id) then
        return
    end

    local conf = ZhuangBanId[id]
    local var = getStaticVar(actor)

    local oldid = var.use[roleindex][conf.pos] or 0
    if oldid ~= id then
        print("zhuangban handleUnUse oldid~=id" .. tostring(oldid) .. "~=" .. tostring(id))
        return
    end
    if oldid == 0 then
        print("zhuangban handleUnUse not use" .. tostring(oldid))
        return
    end
    
    var.use[roleindex][conf.pos] = 0
    LActor.log(actor, "zhuangbansystem.handleUnUse", "mark1", roleindex, conf.pos)

    local v = var.use[roleindex]
    local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
    LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3)

    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_UnUse)
    if not pack then return end
    LDataPack.writeByte(pack, roleindex)
    LDataPack.writeByte(pack, conf.pos)
    LDataPack.writeInt(pack, 0)
    LDataPack.flush(pack)
end

local function handleUpLevel(actor, packet)
    local actorId = LActor.getActorId(actor)
    local id = LDataPack.readInt(packet)

    if not ZhuangBanId[id] then print("zhuangbansystem.handleUpLevel: conf is nil, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

    --是否已激活了
    local var = getStaticVar(actor)
    if not var.zhuangban[id] then print("zhuangbansystem.handleUpLevel: not active, id:"..tostring(id)..", actorId:"..tostring(actorId)) return end

    local level = getLevel(actor, id)

    if not ZhuangBanLevelUp[id] or not ZhuangBanLevelUp[id][level+1] then
        print("zhuangbansystem.handleUpLevel: level conf nil, id:"..tostring(id)..", level:"..tostring(level)..", actorId:"..tostring(actorId))
        return
    end

    local conf = ZhuangBanLevelUp[id][level+1]

    --消耗物品
    if conf.cost then
        if conf.cost.num > LActor.getItemCount(actor, conf.cost.itemId) then
            print("zhuangbansystem.handleUpLevel: item not enough, id:"..tostring(id)..", level:"..tostring(level)..", actorId:"..tostring(actorId))
            return
        end

        LActor.costItem(actor, conf.cost.itemId, conf.cost.num, "zhuangbanUpLevel")

        var.zhuangbanlevel[id] = level + 1
        calcAttr(actor)

        print("zhuangbansystem.handleUpLevel: success, id:"..tostring(id)..", level:"..tostring(level + 1)..", actorId:"..tostring(actorId))

        local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_UpLevel)
        LDataPack.writeInt(pack, id)
        LDataPack.writeInt(pack, var.zhuangban[id])
        LDataPack.writeInt(pack, level+1)
        LDataPack.flush(pack)
    end
end

local function doZhuangbanInvalid(actor, id)
    local var = getStaticVar(actor)
    var.zhuangban[id] = nil

    local _roleindex, _pos = nil, nil
    for roleindex = 0, 2 do
        for pos = 1, ZHUANGBAN_MAXPOS do
            if var.use[roleindex][pos] == id then
                var.use[roleindex][pos] = 0
                _roleindex, _pos = roleindex, pos
            end
        end
    end
 
    -- send mail
    local title = ZhuangBanConfig.mailinvalidtitle
    local posname = ZhuangBanConfig.zhuangbanpos[ZhuangBanId[id].pos]
    local content = string.format(ZhuangBanConfig.mailinvalidcontext, posname, ZhuangBanId[id].name)
    local mailData = { head=title, context = content, tAwardList={} }
    LActor.log(actor, "zhuangbansystem.doZhuangbanInvalid", "sendMail")
    mailsystem.sendMailById(LActor.getActorId(actor), mailData)

    return _roleindex, _pos
end

local function noticeZhuangbanInvalid(actor, id)
    local pack = LDataPack.allocPacket(actor, systemId, Protocol.sZhuangBanCmd_Invalid)
    if not pack then return end
    LDataPack.writeInt(pack, id)
    LDataPack.flush(pack)
end

function calcAttr(actor)
    local var = getStaticVar(actor)

    local function tableAddMulit(t, attrs, n)
        for _, v in ipairs(attrs) do
            t[v.type] = (t[v.type] or 0) + (v.value * n)
        end
    end

    local function tableAddPre(t, attrs)
        for _, v in ipairs(attrs or {}) do
            t[v.pos] = (t[v.pos] or 0) + (v.pre or 0)
        end
    end

    local roleAttrs = {}
    local posAttrPre = {}
    local wingAttrPre = {}
    for id, v in ipairs(ZhuangBanId) do
        if var.zhuangban[id] then
            --基础属性
            roleAttrs[v.roletype] = roleAttrs[v.roletype] or {}
            tableAddMulit(roleAttrs[v.roletype], v.attr, 1)

            --部位属性
            if not posAttrPre[v.roletype] then posAttrPre[v.roletype] = {} end
            tableAddPre(posAttrPre[v.roletype], v.attr_precent)
            wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (v.wing_attr_per or 0)

            --等级属性
            local level = getLevel(actor, id)
            if ZhuangBanLevelUp[id] and ZhuangBanLevelUp[id][level] then
                tableAddMulit(roleAttrs[v.roletype], ZhuangBanLevelUp[id][level].attr, 1)
                tableAddPre(posAttrPre[v.roletype], ZhuangBanLevelUp[id][level].attr_precent)
                wingAttrPre[v.roletype] = (wingAttrPre[v.roletype] or 0) + (ZhuangBanLevelUp[id][level].wing_attr_per or 0)
            end
        end
    end

    local count = LActor.getRoleCount(actor)
    for roleindex = 0, count-1 do
        local attr = LActor.getRoleZhuangBanAttr(actor, roleindex)
        attr:Reset()
        local roledata = LActor.getRoleData(actor, roleindex)
        local zhuangbanAttr = roleAttrs[roledata.job]
        if zhuangbanAttr then
            for k, v in pairs(zhuangbanAttr) do
                attr:Set(k, v)
            end

            --部位属性加成
            for pos, pre in pairs(posAttrPre[roledata.job] or {}) do
                local equipAttr = LActor.getEquipAttr(actor, roleindex, pos)
                for attrType = Attribute.atHpMax, Attribute.atTough do
                    if 0 < (equipAttr[attrType] or 0) then
                        attr:Add(attrType, math.floor(equipAttr[attrType]*pre/10000))
                    end
                end
            end
        end
        --增加翅膀百分比属性
        local per = wingAttrPre[roledata.job] or 0
        if per > 0 then
            local level, _, status = LActor.getWingInfo(actor, roleindex)
            if status == 1 then
                local wingCfg = WingLevelConfig[level]
                if wingCfg then
                    for _,att in ipairs(wingCfg.attr or {}) do
                        attr:Add(att.type, math.floor(att.value*per/10000))
                    end
                end
            end
        end
    end

    LActor.reCalcAttr(actor)
end

function setInvalidTimer(actor, needSend, needSetTimer)
    local var = getStaticVar(actor)

    -- 找出过期数据
    local invalidIds = {}
    local nowtime = System.getNowTime()
    local nextTime = nil
    for id, v in ipairs(ZhuangBanId) do
        local invalidTime = var.zhuangban[id] or 0
        if invalidTime and invalidTime > 0 then
            if nowtime >= invalidTime then
                table.insert(invalidIds, id)
            elseif nextTime == nil or invalidTime < nextTime then
                nextTime = invalidTime
            end
        end
    end

    local updateRoles = {}
    for _, id in ipairs(invalidIds) do
        local roleindex, pos = doZhuangbanInvalid(actor, id)
        if roleindex then
            updateRoles[roleindex] = pos
        end
    end

    for roleindex, _ in pairs(updateRoles) do
        local v = var.use[roleindex]
        local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
        LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3)
    end

    if needSend then
        for _, id in ipairs(invalidIds) do
            noticeZhuangbanInvalid(actor, id)
        end
    end

    if needSetTimer and nextTime then
        local nextTime = nextTime - nowtime
        if nextTime < 0 then nextTime = 0 end
        LActor.postScriptEventLite(actor, nextTime * 1000, function() setInvalidTimer(actor, true, true) end)
    end

    calcAttr(actor)
end

function printVar(actor)
    local var = getStaticVar(actor)
    -- print("zhuangban=============================")
    for id, v in ipairs(ZhuangBanId) do
        if var.zhuangban[id] then
            -- print(id .. ":" .. var.zhuangban[id])
            LActor.log(actor, "zhuangbansystem.printVar", "mark1", var.zhuangban[id])
        end
    end
    -- print("use=============================")
    for roleindex = 0, 2 do
        local v = var.use[roleindex]
        -- print(v[1] .. ":" .. v[2] .. ":" .. v[3])
        LActor.log(actor, "zhuangbansystem.printVar", "mark2", v[1], v[2], v[3])
    end
end

local function onInit(actor)
    -- 清理过期数据
    setInvalidTimer(actor, false, false)

    local var = getStaticVar(actor)
    for roleindex = 0, 2 do
        local v = var.use[roleindex]
        local pos1, pos2, pos3 = (v[1] or 0), (v[2] or 0), (v[3] or 0)
        LActor.setZhuangBan(actor, roleindex, pos1, pos2, pos3)
    end
end
 
local function onWingLevelUp(actor, roleId, level)
    calcAttr(actor)
end

local function onLogin(actor)
    setInvalidTimer(actor, false, true)
    handleQuery(actor, nil)
end

netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_QueryInfo, handleQuery)
netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_Active, handleActive)
netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_Use, handleUse)
netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_UnUse, handleUnUse)
netmsgdispatcher.reg(systemId, Protocol.cZhuangBanCmd_UpLevel, handleUpLevel)

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeWingLevelUp, onWingLevelUp)

local gmsystem = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.zhuanban = function(actor, args)
    local var = getStaticVar(actor)
    for id, v in ipairs(ZhuangBanId) do
        if var.zhuangban[id] then
            local invalidTime = 0
            if v.invalidtime then
                invalidTime = v.invalidtime + System.getNowTime()
            end
            var.zhuangban[id] = invalidTime

            if not var.zhuangbanlevel then var.zhuangbanlevel = {} end
           if not var.zhuangbanlevel[id] then var.zhuangbanlevel[id] = 1 end
        end
    end

    handleQuery(actor)
end
