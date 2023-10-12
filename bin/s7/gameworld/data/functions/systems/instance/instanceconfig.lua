--c++使用无索引形式的Fubens， lua里使用有索引的instanceConfig
instanceConfig = {}
require("systems.instance.instancetemplate")


local instanceInitConfig = function(conf)
	if type(conf.monsterGroup) ~= "table" then
		conf.monsterGroup = {}
	else
		local monsterGroup = {}
		for _, v in ipairs(conf.monsterGroup) do
			if  v.id == nil then print(conf.fbid) end
			monsterGroup[v.id] = v
		end
		conf.monsterGroup = monsterGroup
	end

	if conf.events == nil or conf.events == 0 then conf.events = {} end
	for _, event in pairs(conf.events) do
		if event.conditions == nil then
			event.conditions = {type=0, time = 0}
		end
	end
end

local instanceTestConfig = function(conf)
	for _, event in pairs(conf.events) do
		for _, action in pairs(event.actions) do
			if action.type==3 and conf.monsterGroup[action.id] == nil then
				print("副本事件中的怪物组未配置, id:"..conf.fbid)
				return false
			end
		end
	end
	return true
end

for i,v in pairs(InstanceConfig) do
    --print(instancetemplate.generateTemplate(v))
    instancetemplate.generateTemplate(v)
    instanceInitConfig(v)
    --instanceConfig[v.fbid] = v
    --assert(instanceTestConfig(v) == true)
    instancetemplate.testPrint(v) --如果创建了test目录就会生成test配置
end
