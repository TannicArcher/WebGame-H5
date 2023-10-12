<!DOCTYPE HTML>
<html style="font-size: 11px;">
<head>
    <meta name="applicable-device" content="mobile">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta content="width=device-width, initial-scale=1,maximum-scale=1.0,user-scalable=no" name="viewport"/>
    <!-- 游戏全屏 -->
    <meta content="true" name="full-screen"/>
    <meta content="true" name="x5-fullscreen"/>
    <meta content="true" name="360-fullscreen"/>
    <!--iphone qq -->
    <meta name="x5-orientation" content="portrait">
    <meta name="x5-fullscreen" content="true">
    <meta name="x5-page-mode" content="app">
    <title>屠龙传世</title>
    <meta name="description" content=""/>
    <link rel="stylesheet" href="/static/css/index.css?v20161122v3">
    <link rel="stylesheet" href="/static/css/h5sdk.css?v20161122v3">
    <link rel="stylesheet" href="/static/css/game.css?v20161122v3">
    <script type="text/javascript" src="http://libs.baidu.com/jquery/2.1.4/jquery.min.js"></script>
    <script type="text/javascript">
        function is_mobile() {
            var screen = '';
            if(screen =='1'){
                $(".iframe_box").css("max-width", $(window).width())
                return true
            }
            var mobileAgent = new Array("iphone", "ipod", "ipad", "android", "mobile", "blackberry", "webos", "incognito", "webmate", "nokia", "ucweb", "skyfire");
            var ua = navigator.userAgent.toLowerCase();
            for (var i = 0; i < mobileAgent.length; i++) {
                if (ua.indexOf(mobileAgent[i]) != -1) {
                    return true
                }
            };
            return false
        }
        var game_id = '1';
        var game_name = 'H5';
        var domain = "url";
        var channel = '1';
        var uid = '';
        var mid = '1';
        var weixin = 'h5wyxzx';
        var weixinurl = '/static/img/gz_weixin.png';
        var showIcon = 1;
    </script>
</head>
<body>

<div id="games-root" style="opacity: 1;">
    <div class="iframe_box" id="games-container">
        <iframe id="game_iframe" name ="game_iframe" frameborder="no" src="/login2.php" scrolling="no" width='100%' height='100%'>
        </iframe>
    </div>
    
</body>
</html>