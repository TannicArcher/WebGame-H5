module("drop", package.seeall)


local groupConf = DropGroupConfig
local tableConf = DropTableConfig


local function randomGold(item)
    if item.count and item.type == AwardType_Numeric and item.id == NumericType_Gold then
        local range = math.floor(item.count * 0.1)
        item.count = math.random(item.count - range, item.count + range)
    end
end

local function dropTable(id, out, eff)
	if (not tableConf or not tableConf[id]) then
		print("drop table config is nil. id:"..tostring(id))
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
			if r < v.rate * eff  then
				local item = {type=v.type,id=v.id,count=v.count,job=v.job}
				--randomGold(item)
				table.insert(ret, item)
				--print(string.format("item:%d %d %d", item.type, item.id, item.count))
				if out then table.insert(out, item) end
			end
		end
	elseif conf.type == 2 then
		local r = math.random() * 100
		for _, v in ipairs(conf.table) do
			if r < v.rate * eff then
				local item = {type=v.type,id=v.id,count=v.count,job=v.job}
                --randomGold(item)
				table.insert(ret, item)
				--print(string.format("item:%d %d %d", item.type, item.id, item.count))
				if out then table.insert(out, item) end
				break
			else
				r = r - (v.rate * eff)
                if r < 0 then r = 0 end
			end
		end
	end

	return ret
end

local function dropTableExpected(id, out, count)
    if (not tableConf or not tableConf[id]) then
        print("drop table config is nil. id:"..tostring(id))
        return {}
    end

    local conf = tableConf[id]
    local ret = {}
    for _, v in ipairs(conf.table) do
        local item = {type=v.type, id=v.id, count=v.count * v.rate/100*count}
		item.count = math.floor(item.count)
		if item.count > 0 then
			table.insert(ret, item)
			if out then table.insert(out, item) end
		end
    end

    return ret
end

--接口
--参数 掉落组id， 效率，默认1,代表100%，
function dropGroup(groupId, eff)
    if (not groupId or not groupConf or not groupConf[groupId] ) then
        print("drop group config is nil. id:"..tostring(groupId))
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

function dropGroupExpected(id, count)
    if (not groupConf or not groupConf[id] ) then
        print("drop group config is nil.."..id)
        return {}
    end

    local conf = groupConf[id]
    local out = {}
    for _, v in ipairs(conf.group) do
        dropTableExpected(v.id, out, count * v.rate/100)
    end

    return out
end
