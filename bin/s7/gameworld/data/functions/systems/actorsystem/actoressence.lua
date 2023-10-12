--精华 灵魄 精魄
module("actoressence", package.seeall)


local function addEssence(actor, nadd, log)
	if type(nadd) ~= "number"	then return 0 end
	if nadd < 0 then return 0 end

	LActor.changeCurrency(actor, NumericType_Essence, nadd, log)

	print(string.format("actor:%d add essence:%d log:%s", LActor.getActorId(actor), nadd, tostring(log)))
end

LActor.addEssence = addEssence
_G.MyAddEssence = addEssence
