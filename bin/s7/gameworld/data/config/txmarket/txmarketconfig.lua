--集市任务
TxMarkConfig = {
	login = {
		{
			missonId = {"1102501967T320150901164629", "1102501967T320151021175838"},
			itemId = {22126, 22126},
			step = {1, 1},
			val = 1,	--登录1次

			mIdx = 1, --服务端用，递增就好
			mailTips = Lang.ScriptTips.jsrw003,
		},

		{
			missonId = {"1102501967T320150901164629", "1102501967T320151021175838"},
			itemId = {22129, 22129},
			step = {4, 4},
			val = 3,	--连续登录3天

			mIdx = 2, --服务端用，递增就好
			mailTips = Lang.ScriptTips.jsrw006,
		},
	},
	
	level = {
		{
			missonId = {"1102501967T320150901164629", "1102501967T320151021175838"},
			itemId = {22127, 22127},
			step = {2, 2},
			val = 30,	--达到30级

			mIdx = 3, --服务端用，递增就好
			mailTips = Lang.ScriptTips.jsrw004,
		},

		{
			missonId = {"1102501967T320151021175838"},
			itemId = {0},
			step = {3},
			val = 45,	--达到45级,金卷任务

			mIdx = 5, --服务端用，递增就好
			mailTips = Lang.ScriptTips.jsrw005,
		},

		{
			missonId = {"1102501967T320150901164629"},
			itemId = {22128},
			step = {3},
			val = 50,	--达到50级

			mIdx = 4, --服务端用，递增就好
			mailTips = Lang.ScriptTips.jsrw005,
		},
	},
}
