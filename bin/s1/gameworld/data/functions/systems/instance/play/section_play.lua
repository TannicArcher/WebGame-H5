module("systems.instance.play.section_play", package.seeall)
setfenv(1, systems.instance.play.section_play)

--设置分段完成
function SetSectionPass( shdl, sect)
	print(" curr section "..Fuben.getSceneCurrSection(shdl).." param sect "..sect)
	if Fuben.getSceneCurrSection(shdl) == sect then
		Fuben.setSectionState(shdl, 1)
	end
end


--切换分段触发
function OnNextSection( fbptr, sid, sect, scenePtr )
	print("***********to next sect*****"..sid.." sect "..sect)
	instancesystem.onNextSection(fbptr, sect, scenePtr)
end



_G.onNextSection = OnNextSection

