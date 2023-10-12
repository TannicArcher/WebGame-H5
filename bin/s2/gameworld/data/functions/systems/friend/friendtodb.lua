--好友系统
module("friendtodb", package.seeall)

local LActor = LActor
local LangFriend = Friend


local dbEntity = dbEntity or 1
local dbCmd = DbCmd.FriendCmd

-- Comments: 删
function delFromDb(actorId, actorBId, friendType)
	-- print("delFromDb=============",actorId, actorBId, friendType)
	System.SendToDb(serverId, dbEntity, dbCmd.dcDelFriend, 3,
		dtInt, actorId,
		dtInt, actorBId,
		dtInt, friendType)

	System.logCounter(actorId, tostring(accountName or ""), "",
					"friendtodb", "delFromDb", tostring(friendType), string.format("friendid %d", actorBId))
	return true
end

-- Comments: 加
function addToDb(actorId, actorBId, friendType, addfriendtime,lastcontact)
	-- print("addToDb=============",actorId, actorBId, friendType, addfriendtime,lastcontact)
	System.SendToDb(serverId, dbEntity, dbCmd.dcUpdateFriend, 5,
		dtInt, actorId,
		dtInt, actorBId,
		dtByte, friendType,
		dtInt, addfriendtime,
		dtInt, lastcontact)
	System.logCounter(actorId, tostring(accountName or ""), "",
					"friendtodb", "addToDb", tostring(friendType), string.format("friendid %d", actorBId))
	return true
end
