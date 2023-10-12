module("test.test_skill" , package.seeall)
setfenv(1, test.test_skill)

_G.skill = function(actor)
	print("useSkill")
	local actorlist = LuaHelp.getAllActorList()
	if not actorlist then return end
	for _, ptr in ipairs(actorlist) do
		if actor ~= ptr then 
			LActor.setEntityTarget(actor, ptr)
		end
	end

	LActor.useSkill(actor, 1000, 0, 0, false,1)
end



