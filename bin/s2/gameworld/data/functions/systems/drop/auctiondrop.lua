module("auctiondrop", package.seeall)


local groupConf = AuctionGroupConfig
local tableConf = AuctionDropTableConfig

local function dropTable(id, out, eff)
	if (not tableConf or not tableConf[id]) then
		print("auctiondrop table config is nil. id:"..tostring(id))
		return {}
    end
    if eff == nil then eff = 1 end

	local conf = tableConf[id]
	local ret = {}
	if conf.timeLimit ~= nil then
		if not timedomain.checkTimes(conf.timeLimit) then
			return ret
		end
	end
	if conf.type == 0 then return {} end
	if conf.type == 1 then
		for _, v in ipairs(conf.table) do
			local r = math.random() * 100
			if r < v.rate * eff then
				if out then table.insert(out, v.id) end
			end
		end
	elseif conf.type == 2 then
		local r = math.random() * 100
		for _, v in ipairs(conf.table) do
			if r < v.rate * eff then
				if out then table.insert(out, v.id) end
				break
			else
				r = r - (v.rate * eff)
                if r < 0 then r = 0 end
			end
		end
	end

	return ret
end

--接口
--参数 掉落组id， 效率，默认1,代表100%，
function dropGroup(groupId, eff)
    if (not groupId or not groupConf or not groupConf[groupId] ) then
        print("auctiondrop group config is nil. id:"..tostring(groupId))
        return {}
    end
    if eff == nil then eff = 1 end

    local conf = groupConf[groupId]
    local out = {}
    if conf.type == 0 then return {} end
    if conf.type == 1 then
        for _, v in ipairs(conf.group) do
            local r = math.random() * 100
            if r < v.rate * eff then dropTable(v.id, out, eff) end
        end
    elseif conf.type == 2 then
        local r = math.random() * 100
        for _, v in ipairs(conf.group) do
            if r < v.rate * eff then
                dropTable(v.id, out, eff)
                break
            else
                r = r - (v.rate * eff)
            end
        end
	elseif conf.type == 3 then
		for _, innerGroup in ipairs(conf.group) do
			local r = math.random() * 100
			for _, v in ipairs(innerGroup) do
				if r < v.rate * eff then
					dropTable(v.id, out, eff)
					break
				else
					r = r - (v.rate * eff)
				end
			end
		end
    end

    return out
end
