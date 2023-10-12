module("actorevent", package.seeall)

local dispatcher = {} -- 所有状态触发

local function regEventToTab(tab, eid, proc, noBattle)
	tab[eid] = tab[eid] or {}
	for _, func in ipairs(tab[eid]) do
		if func[1] == proc then
			return false
		end
	end
	local func = {proc, noBattle}
	table.insert(tab[eid], func)
end

local function unRegEventFromTab(tab, eid, proc)
	tab[eid] = tab[eid] or {}
	for indx, func in ipairs(tab[eid]) do
		if func[1] == proc then
			table.remove(tab[eid], indx)
			break
		end
	end
end

-- noBattle 等于true表示战斗服不触发
function reg(eid, proc, noBattle)
	if eid == nil then
		print("actorevent id is nil")
		-- print(debug.traceback())
		return
	end
	if not proc then
		print(string.format("actorevent proc is nil with %d", eid))
		assert(false)
	end

	regEventToTab(dispatcher, eid, proc, noBattle)
end

-- 注销注册的方法
function unReg(eid, proc)
	if eid == nil then
		print("actorevent id is nil")
		return
	end
	if not proc then
		print(string.format("actorevent proc is nil with %d", eid))
		return
	end

	unRegEventFromTab(dispatcher, eid, proc)
end

function onEvent(actor, eid, ...)
	local procs = dispatcher[eid]
	if not procs then return end

	for _,v in ipairs(procs) do
		if (not v[2]) or (not System.isBattleSrv()) then
			v[1](actor, ...)
		end
	end
end

_G.OnActorEvent = onEvent
