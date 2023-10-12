module("csmsgdispatcher" , package.seeall)

local MsgFuncT = {}

Reg = function( cmd, subCmd, fun )
	if not MsgFuncT[cmd] then
		MsgFuncT[cmd] = {}
	end

	local func = MsgFuncT[cmd][subCmd]
	if func then
		assert("the cmd "..cmd.." subCmd "..subCmd.."have reg func")
	else
		MsgFuncT[cmd][subCmd] = fun
	end
end


function OnRecvCrossServerMsg(sId, sType, pack)
	local cmdType = DataPack.readByte(pack)
	local subCmd = DataPack.readByte(pack)

	if not MsgFuncT[cmdType] then
		print("OnRecvCrossServerMsg not cmdType: "..cmdType)
		return
	end

	local func = MsgFuncT[cmdType][subCmd]

	if func then
		func(sId, sType, pack)
	else
		print("OnRecvCrossServerMsg not cmdType: "..cmdType.." subCmd "..subCmd)
	end

end

_G.OnRecvCrossServerMsg = OnRecvCrossServerMsg
