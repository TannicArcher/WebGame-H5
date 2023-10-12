<!DOCTYPE HTML>
<html>
<head>
	<meta charset="utf-8">
	<title>屠龙传世</title>
	<!--防止index.html被浏览器缓存--begin-->
	<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
	<META HTTP-EQUIV="Cache-Control" CONTENT="no-cache">
	<META HTTP-EQUIV="Expires" CONTENT="0">
	<!--防止index.html被浏览器缓存--over-->

	<link href="favicon.ico" rel="shortcut icon"/>
	<meta name="viewport"
		  content="width=device-width,initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no"/>
	<meta name="apple-mobile-web-app-capable" content="yes"/>
	<meta name="full-screen" content="true"/>
	<meta name="screen-orientation" content="portrait"/>
	<meta name="x5-fullscreen" content="true"/>
	<meta name="360-fullscreen" content="true"/>
	<meta name="apple-mobile-web-app-capable" content="yes"/>
	<style>
		html,
		body {
			-ms-touch-action: none;
			background: #000000;
			padding: 0;
			border: 0;
			margin: 0;
			height: 100%;
		}
	</style>

	<!--这个标签为通过egret提供的第三方库的方式生成的 javascript 文件。删除 modules_files 标签后，库文件加载列表将不会变化，请谨慎操作！-->
	<!--modules_files_start-->
	<script egret="lib" src="libs/modules/egret/egret.min.js"></script>
	<script egret="lib" src="libs/modules/egret/egret.web.min.js"></script>
	<script egret="lib" src="libs/modules/eui/eui.min.js"></script>
	<script egret="lib" src="libs/modules/res/res.min.js"></script>
	<script egret="lib" src="libs/modules/game/game.min.js"></script>
	<script egret="lib" src="libs/modules/socket/socket.min.js"></script>
	<script egret="lib" src="libs/modules/tween/tween.min.js"></script>
	<!--modules_files_end-->

	<!--这个标签为不通过egret提供的第三方库的方式使用的 javascript 文件，请将这些文件放在libs下，但不要放在modules下面。-->


	<!--这个标签会被替换为项目中所有的 javascript 文件。删除 game_files 标签后，项目文件加载列表将不会变化，请谨慎操作！-->
	<!--game_files_start-->
	<script src="main.min.js"></script>
	<!--game_files_end-->
</head>

<body onunload="closeSocket()">
<script>
	window.addEventListener("message", function (event) {
		if (event.data.id != "eE")
			return;

		start(event.data.urlParam);
	});
	function start(param) {

		if (param) {
			paramInit(param);
			paraUrl = param;
		}

		var pIframe = document.getElementById("paramIframe");
		if (pIframe)
			document.body.removeChild(pIframe);

		document.body.innerHTML += '' +
			'<div style="margin: auto;width: 100%;height: 100%;" ' +
			'class="egret-player" ' +
			'data-entry-class="Main" ' +
			'data-orientation="' + urlParam['orientation'] + '" ' +
			'data-scale-mode="' + urlParam['scaleMode'] + '" ' +
//			'data-frame-rate="' + urlParam['frameRate'] + '" ' +
			'data-frame-rate="60" ' +
			'data-content-width="1920" ' +
			'data-content-height="1000" ' +
			'data-show-paint-rect="false" ' +
			'data-multi-fingered="2" ' +
			'data-show-fps="' + urlParam['fps'] + '" ' +
			'data-show-log="true" ' +
			'data-show-fps-style="x:0,y:0,size:12,textColor:0xffffff,bgAlpha:0.3">' +
			'</div>';

		egret.runEgret({renderMode: urlParam['renderMode']});
		egret.MainContext.instance.stage.dirtyRegionPolicy = urlParam['dirty'];
	}

	var paraUrl = location.href;
    var urlParam = {};
	paramInit(paraUrl);
	urlParam['orientation'] = urlParam['orientation'] || "auto";
	//urlParam['scaleMode'] = urlParam['scaleMode'] || "showAll";
	urlParam['scaleMode'] =  "fixedNarrow";
	urlParam['egretWidth'] = urlParam['egretWidth'] || "600";
	urlParam['egretHeight'] = urlParam['egretHeight'] || "980";
	urlParam['fps'] =  urlParam['fps'] || "false";
	if (!urlParam.user || !urlParam.srvid || !urlParam.srvaddr || !urlParam.srvport) {
		var backIndex = paraUrl.split('/');
		backIndex[backIndex.length - 1] = 'backIndex.html';
		backIndex = backIndex.join('/');
		document.body.innerHTML += '<iframe id="paramIframe" style="border: 0px; width: 100%;height: 100%;" ' +
			'src="http://127.0.0.1/games/h5game/h10.html?backIndex=' + backIndex + '"></iframe>';
	}
	else {
		start();
	}

	function paramInit(str) {
		var whIndex = str.indexOf("?");
		if (whIndex != -1) {
			var param = str.slice(whIndex + 1).split("&");
			var strArr;
			for (var i = 0; i < param.length; i++) {
				strArr = param[i].split("=");
				urlParam[strArr[0]] = strArr[1];
			}
		}
	}

	function showLoadProgress() {

	}

	function showGame() {

	}

	function stop() {
		return false;
	}
	document.oncontextmenu = stop;

	window.onorientationchange = function (e) {
		var d = document.getElementById("screenHint");
		if (window.orientation == 180 || window.orientation == 0) {
			//竖屏状态
			d.style.display = "none";
		}
		if (window.orientation == 90 || window.orientation == -90) {
			//横屏状态
			d.style.display = "block";
		}
	}

	function sdkInit(appid) {
	}

	function showRecharge(payItems) {
	}
	function showQrCode(use) {
	}

	function connectError() {
	}

	function closeSocket() {
		Main.closesocket();
	}

	function checkAWY() {

	}
	function reportSDK(str) {

	}
	function showQRCode() {

    }
    function isFocus() {

    }
    function isShare() {
		
    }
    function roleUp() {

    }
    function enterGame() {

    }
    function createRole() {

    }
	function getVipInfo() {

    }
	function isShowGameDesktop(){
	}
	function saveGameDesktop(){
	}
    function getClientVersion(callback){
        if(callback) callback(0);
    }
</script>
</body>