(function(){
	var h = function() {};
	h.prototype = {
		pay: function(name, price, extractInfo, sign) {
			window.parent.postMessage({op:'pay', params:{name:name, price:price, extractInfo:extractInfo, sign:sign}}, '*');
		},
		roleinfo: function(roleId, roleName, roleLevel, serverId, serverName, sign) {
			window.parent.postMessage({op:'roleinfo', params:{roleId:roleId, roleName:roleName, roleLevel:roleLevel, serverId:serverId, serverName:serverName, sign:sign}}, '*');
		},
		share: function(callback){
			window.addEventListener('message', function(e) {
				if ((e.data.op === 'share')) {
					callback(e.data.value.status);
				}
			}, false);
		},
		follow: function() {
			window.parent.postMessage({op:'follow', params:{}}, '*');
		},
		onuserinfo: function(callback) {
			window.addEventListener('message', function(e) {
				if ((e.data.op === 'onuserinfo')) {
					callback(e.data.value);
				}
			}, false);
		},
		userinfo: function() {
			window.parent.postMessage({op:'userinfo', params:{}}, '*');
		}
	};

	window.FengwanSDK = new h;
})();