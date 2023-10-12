module("utils.changehpdispatcher", package.seeall)
setfenv(1, utils.changehpdispatcher)

local funcList = {}

function OnChangeHp(et, hp)
	for _,func in ipairs(funcList) do
		func(et, hp)
	end
end

function register(func)
	for i,v in ipairs(funcList) do
		if v == func then return end
	end
	table.insert(funcList, func)
end

_G.OnChangeHp = OnChangeHp

