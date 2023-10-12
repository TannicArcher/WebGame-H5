module("instancetemplate", package.seeall)

require "utils.utils"

generateFunc = {}

function generateTemplate(config)
    local func = generateFunc[config.templateType]
    if func then return func(config) end
    return 0
end



function testPrint(config)
    local file = io.open("test/fuben_"..config.fbid..".lua", "w")
    if file == nil then return end
    file:write(utils.t2s(config))
    file:close()
end

local function makeCustemId(s,w,i)
    return s*10000 + w*100+i
end

----------------------------公会副本-------------------------------
generateFunc[1] = function(config)
	local template = config.templateConfig
	if template == nil then return false end 
	if not template.maxWave then return false end 

	if not config.events then 
		config.events = {} 
	end
	local events = config.events

	
	--插入逻辑功能
	for i = 1, template.maxWave do
		--设置refreshMonTime秒后刷怪
		event = {
			conditions = { type = 8, name="wave", value = i,},    
			actions    = {
				{type = 6, id = i, time = template.refreshMonTime,},  --设置refreshMonTime定时器
			},
		}
		table.insert(events, event)
		--触发刷怪
		event = {
			conditions = { type = 6, id = i,},
			actions    = {
				{type = 3, id = i+1,},                                 --刷新wave组怪
				{type = 6, id = 0, time=template.failTime-2,},           --设置failTime失败定时器，因为副本的刷新频率是1秒，所以会有2秒的误差
				{type = 14, name = "NextWave", },                      --通知下一组怪
			},
		}
		table.insert(events, event)
		--击杀wave组怪物
		event = {
			conditions = { type = 1, id = i+1,},
			actions    = {
				{type = 7,  id = 0,},                                   --移除failTime失败定时器
				{type = 14, name="KillMonGroup",},                      --调用杀怪函数
				{type = 12, name="wave", method="set", value=i+1,},     --设置下一组怪
			},
		}
		table.insert(events, event)
	end
	--插入胜利条件
	event = {
		conditions={type=1, id=template.maxWave + 1,},   --条件: 击杀最大关卡的怪(因为城门怪为组1，所以需要+1处理，刷怪也是同理）
		actions={{type=1},},                             --胜利
	}
	table.insert(events, event)
	--插入失败条件
	event = {
		conditions={type=5,id=1,},      --条件：玩家死亡 
		actions={{type=2},},            --失败
	}
	table.insert(events, event)
	event = {
		conditions={type=4, id=template.gateId,},  --条件：城门死亡
		actions={{type=2},},                       --失败
	}
	table.insert(events, event)
	event = {
		conditions={type=6, id=0,},       --条件：60秒没有击杀完怪物
		actions={{type=2},},              --失败
	}
	table.insert(events, event)
	--初始化城门
	event = {
		conditions={type=0,time=0,},       --条件：副本过了0秒
		actions={
			{type = 3, id = 1,},           --刷新wave组怪
		},
	}
	table.insert(events, event)
end

---------------------------------------------------章节副本----------------------------------------------------------
--[[generateFunc[1] = function(config)
    local template = config.templateConfig
    if template == nil then return false end
    if template.waveContent == nil then return false end
    local waveContent = template.waveContent
    local sectionDelay = template.sectionDelay or 1
    local monsterDelay = template.monsterDelay or 0
    local sectionCount = Fuben.getSceneSectionCnt(config.scenes[1])

    local sections = template.sections
    local events = config.events
    if events == nil then config.events = {} events = config.events end
    for s=1, sectionCount do
        local section = sections[s]
        if section ~= nil then
            for w=1,#section do
                local wave = section[w]
                local event = {conditions={}, actions = {} }
                table.insert(events, event)

                --conditions
                if s == 1 and w == 1 then
                    event.conditions = {type=0, time=sectionDelay} -- 时间开始
                elseif w == 1 then
                    event.conditions = {type=7, id = s-1} -- 触发分段开始
                else
                    local lastWave = section[w-1]   -- 上一波消灭
                    event.conditions = {flag = "and"}
                    for _, v in ipairs(lastWave) do
                        table.insert(event.conditions, {type=1, id = v})
                    end
                end

                --actions
                local waveDelay = template.waveDelay or 0
                if w == 1 then waveDelay = template.sectionDelay or 0 end
                event.actions = {
                    {type=5, delay=waveDelay, display=1, content = string.format(waveContent, w, #section)},
                }
                if wave.interval == nil or #wave == 1 then
                    local actions = event.actions --招出本波简单版
                    for _,v in ipairs(wave) do
                        table.insert(actions, {type=3, delay=waveDelay + monsterDelay, id = v})
                    end
                    --table.insert(event, actions)
                else
                    --复杂版
                    table.insert(event.actions, {type=3, delay=waveDelay + monsterDelay, id=wave[1]})
                    table.insert(event.actions, {type=6, delay=waveDelay + monsterDelay, id=makeCustemId(s,w,1), time = wave.interval} )
                    --table.insert(events, event)
                    for i = 2, #wave do
                        local event = {}
                        table.insert(events, event)
                        event.conditions = {flag = "or",
                            {type=1, id= wave[i-1]},
                            {type=6, id= makeCustemId(s,w,i-1)}
                        }
                        event.actions = {
                            {type=3, delay=monsterDelay, id=wave[i]},
                        }
                        if i~= #wave then
                            table.insert(event.actions, {type=6, id=makeCustemId(s, w, i), time = wave.interval }) --下一组条件
                        end
                    end
                end
            end
            --分段条件
            local lastWave = section[#section]   -- 最后一段打完生成后续事件
            if lastWave ~= nil then
                local event = {}
                table.insert(events, event)
                event.conditions = {flag = "and"}
                for _, v in ipairs(lastWave) do
                    table.insert(event.conditions, {type=1, id = v})
                end
                if s == sectionCount then
                    event.actions = {{type=1}}
                else
                    event.actions = {{type=4, id=s}, {type=5, display=1, content=""}}
                end

            end
        end
    end

	return true
end
--]]


--------------------------------------------------无尽之路---------------------------------------------------------
--[[
	需要总波数，分段数，最终波数，生成每波的激活事件方法
	每波的event id规划：  波数*1000 + 玩法id *
	具体：
	子事件数量控制在10以内，
	自定义事件预留在100以内，用正常方式配置，顺序都在数组内，
	模板事件从100开始，用key方式配置，顺序在哈希表内
	预留9个玩法*10~*90
	w00~w09为生成的固定事件id区
	奖励和boss为固定event
	波数从百位起 除以段数 wave/segment + 1
	对应的怪物组配置id也岁wave/segment 递增

	templateConfig = {--所有出现的id保证在100内不重复即可
		totalWave = 30,--不算boss和奖励
		segment = 10,
		bossId = 10, --生成boss死亡杀死所有小怪条件
		bossGroup=8,
		chestGroup=9,
		eliteWave = 5,
		eliteGroups = {[1]=50,[2]=50},
		playTypeConfig = {
			[1]={time = 60, gid=11, display="限制时间内清光所有怪物: %s", rate=50},
			[2]={time = 60, flagId=18,flagGid=12, display="在限制时间内打到帅旗, %s", rate=50},
		 }
	}

	--生成下一波的事件
	{
		conditions={
			flag = "or",
			{type=8, name="wjzlWave", value=1},
			{type=8, name="wjzlWave", value=2},
			{type=8, name="wjzlWave", value=3},
			{type=8, name="wjzlWave", value=4},
			{type=8, name="wjzlWave", value=5},
			{type=8, name="wjzlWave", value=6},
			{type=8, name="wjzlWave", value=8},
			{type=8, name="wjzlWave", value=7},
			{type=8, name="wjzlWave", value=9},
			{type=8, name="wjzlWave", value=10},
		},
		actions = {{type=13, events={[1]=50,[2]=50}}
	}
--]]
--[[
generateFunc[2] = function(config)
	local template = config.templateConfig
	if template == nil then return end

	local totalWave = template.totalWave
	local segment = template.segment
	local bossId = template.bossId
	local bossGroup = template.bossGroup
	local chestGroup = template.chestGroup
	local eliteWave = template.eliteWave
	local eliteGroups = template.eliteGroups
	local playType = template.playTypeConfig
	if not totalWave or not segment or not bossId or not bossGroup or
			not chestGroup or not eliteWave or not eliteGroups or not playType then
		print("fuben template config is invalid id: "..config.fbid)
		return false
	end
	local events = config.events
	if events == nil then
		config.events = {}
		events = config.events
	end

	-----------------------生成波次切换随机事件的事件-----------------------
	local segcount = math.ceil(totalWave / segment)
	for s = 1, segcount do
		local event = {loop = 0, conditions={}, actions = {} }
		local action = {type=13, events={}, delay=5 } --todo下一波延迟？下一波提示？没说怎么做
		--playEvents
		for p, c in ipairs(playType) do
			if p > 9 then return false end   --大于9个玩法 id要重新规划
			action.events[  s*100+p*10 ] = c.rate
		end
		table.insert(event.actions, action)

		event.conditions.flag = "or"
		for w = (s-1)*segment + 1, s*segment do
			if w >totalWave then break end
			table.insert(event.conditions, {type=8, name = "wjzlWave", value=w})
		end
		events[ s*100 + 1] = event
	end
	--触发第一波
	events[100] = {actions={{type=12, name="wjzlWave"}}}
	-----------------------生成波次切换随机事件的事件 end-----------------------

	---------------生成每个玩法-------------------------
	for s = 1, segcount do
		--------------------------玩法1------------------------
		local event1 = {active = false, actions={} }
		events[s*100+11] = {active = false,
			actions = {
				{type=3, id= (s-1)*100+playType[1].gid},
				{type=5, display=3,content=playType[1].display, time=playType[1].time },
				{type=6, id=s*100+10, time=playType[1].time},
			}
		}
		events[s*100+12] = {active = false,
			--conditions={type=1, id= (s-1)*100+playType[1].gid},
			conditions={type=3},    --condition is kill all monsters, include elites.
			actions = {
				{type=7, id=s*100+10},
				{type=5, display=3,content=playType[1].display, time=0},
				{type=12, name = "wjzlWave"},
			}
		}
		events[s*100+13] = {active = false,
			conditions={type=6, id= s*100+10},
			actions = {
				{type=2},
				{type=2}
			}
		}

		table.insert(event1.actions, {type=9, id=s*100+11})
		table.insert(event1.actions, {type=9, id=s*100+12})
		table.insert(event1.actions, {type=9, id=s*100+13})
		events[ s*100+10] = event1
		--------------------------玩法2------------------------
		local event2 = {active = false, actions={} }
		events[s*100+21] = {active = false,
			actions = {
				{type=3, id= (s-1)*100+playType[2].flagGid},
				{type=5, display=3,content=playType[2].display, time=playType[2].time },
				{type=6, id=s*100+20, time=playType[2].time},
			}
		}
		events[s*100+22] = {active = false,
			conditions={type=1, id= (s-1)*100+playType[2].flagGid},
			actions = {
				{type=7, id=s*100+20},
				{type=5, display=3,content=playType[2].display, time=0},
				{type=12, name = "wjzlWave"},
			}
		}
		events[s*100+23] = {active = false,
			conditions={type=6, id= s*100+20},
			actions = {
				{type=2},
				{type=8}
			}
		}

		table.insert(event2.actions, {type=9, id=s*100+21})
		table.insert(event2.actions, {type=9, id=s*100+22})
		table.insert(event2.actions, {type=9, id=s*100+23})
		events[ s*100+20] = event2
	end
	---------------生成每个玩法 end--------------------

	--------------------生成精英怪事件----------------------
	local eliteevent = {loop = 0, conditions={}, actions = {} }
	local action = {type=10, groups = eliteGroups, delay=5 } --todo下一波延迟？下一波提示？没说怎么做
	table.insert(eliteevent.actions, action)

	for i=1, totalWave do
		if i % eliteWave == 0 then
			table.insert(eliteevent.conditions, {type=8, name = "wjzlWave", value=i})
			eliteevent.conditions.flag = "or" --放外面有可能没有实际条件，会报错
		end
	end
	events[107] = eliteevent
	--------------------生成精英怪事件 end-----------------

	-----------------------生成boss关和奖励关-----------------------
	events[ 108] = { --boss开始
		conditions={type=8, name="wjzlWave", value=totalWave+1},
		actions={
			{type=3, id=bossGroup },
			--boss关要显示的文字
		}
	}
	events[ 208] = { --boss结束
		conditions={type=4, id=bossId, count=1},
		actions={
			{type=8, kill= true},
			{type= 12, name="wjzlWave" },
		}
	}
	events[109] = {
		conditions = {type=8, name="wjzlWave", value=totalWave+2},
		actions={
			{type=3, id=chestGroup},
			--奖励关要显示的文字
		}
	}
	events[209] = {
		conditions = {type=1, id= chestGroup},
		actions={
			{type=1},
		}
	}
	---------------boss和奖励关 end--------------------
end
--]]
