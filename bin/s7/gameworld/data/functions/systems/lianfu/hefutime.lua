module("hefutime", package.seeall)

function getHeFuTime()
    local serverid = System.getServerId()
    if not HeFuConfig[serverid] then
        return
    end

    local hefutime = HeFuConfig[serverid].time
    local Y,M,d,h,m = string.match(hefutime, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
    if Y == nil or M == nil or d == nil or h == nil or m == nil then
        return
    end

    return System.timeEncode(Y, M, d, h, m, 0)
end

function getHeFuDayStartTime()
    local serverid = System.getServerId()
    if not HeFuConfig[serverid] then
        return
    end

    local hefutime = HeFuConfig[serverid].time
    local Y,M,d,h,m = string.match(hefutime, "(%d+)%.(%d+)%.(%d+)-(%d+):(%d+)")
    if Y == nil or M == nil or d == nil or h == nil or m == nil then
        return
    end

    return System.timeEncode(Y, M, d, 0, 0, 0)
end

function getHeFuDay()
    local hefutime = getHeFuDayStartTime()
    if not hefutime then
        return nil
    end

    local nowtime = System.getNowTime()

    local day = math.floor((nowtime - hefutime) / (24 * 3600))
    return day + 1
end

--获取合服次数
function getHeFuCount()
    local serverid = System.getServerId()
    if not HeFuConfig[serverid] then
        --找不到配置
        return 0
    end

    --默认合服一次
    return HeFuConfig[serverid].mergeCount or 1
end
