<?php?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>
        登录
    </title>
    <meta content="yes" name="apple-mobile-web-app-capable" />
    <meta content="yes" name="apple-touch-fullscreen" />
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,minimum-scale=1"
    />
    <meta name="description" content="" />
    <meta name="keywords" content="" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="black" />
    <meta name="format-detection" content="telephone=no" />
    <link rel="stylesheet" href="/static/v2/css/common_style.css">
    <link rel="stylesheet" href="/static/v2/css/h5_center.css">
    <script type="text/javascript" src="http://libs.baidu.com/jquery/2.1.4/jquery.min.js">
    </script>
    <script type="text/javascript" src="/static/js/h5_common.js">
    </script>
</head>

<body class="full">
<!--临时游戏背景图-->
<img src="static/img/bg1.jpg"
     style="width:100%; z-index:1;height:100%; z-index:1;">
<!-- 账号登陆 -->
<div class="show_box" id="user_login">
    <div class="account-login">
        <form id="frmLogin" method="post" action="login.php?act=login" target="_top">
            <input type="hidden" id="channel" name="channel" value="1">
            <input type="hidden" id="appid" name="appid" value="181">
            <input type="hidden" id="type" name="type" value="1">
            <span class="ltit ltit2">
                        账号登录
                    </span>
            <p class="acccount-p">
                        <span>
                            <img src="/static/v2/img/h5c_p1.png">
                        </span>
                <input id="username" name="username" type="text" placeholder="账号">
            </p>
            <p class="acccount-p">
                        <span>
                            <img src="/static/v2/img/h5c_p2.png">
                        </span>
                <input id="password" name="password" type="password" placeholder="请输入密码">
            </p>
            <div style="text-align:center">
                <a href="javascript:;" class="login-btn2" id="btnlogin">
                    登陆
                </a>
                <a href="javascript:;" class="login-btn2" id="btnlogin" onclick="getsjreg()">
                    注册
                </a>
            </div>
        </form>
    </div>
</div>
<!-- 账号注册 -->
<div class="show_box popup_bg" id="mobile_login" style="display: none;">
    <div class="phone-login">
        <form id="frmLogin" method="post" action="login.php?act=reg" target="_top">
            <input type="hidden" id="channel" name="channel" value="1">
            <input type="hidden" id="appid" name="appid" value="181">
            <input type="hidden" id="type" name="type" value="2">
            <a href="javascript:;" class="closed_b" onclick="getzhlogin()">
                <img src="/static/v2/img/h5c_closed.png">
            </a>
            <span class="ltit">
                        账号注册
                    </span>
            <span class="inpt">
                        <input name="m_username" id="m_username" type="text" placeholder="请输入账号">
                    </span>
            <span class="inpt">
                        <input name="m_password" id="m_password" type="password" placeholder="请输入密码">
                    </span>
            <span class="inpt">
                        <input name="m_password2" id="m_password2" type="password" placeholder="请重复输入密码">
                    </span>
            <a href="javascript:;" class="login-btn" id="btnreg">
                注册
            </a>
        </form>
    </div>
</div>
<script type="text/javascript">
var $_GET = (function(){
    var url = window.document.location.href.toString();
    var u = url.split("?");
    if(typeof(u[1]) == "string"){
        u = u[1].split("&");
        var get = {};
        for(var i in u){
            var j = u[i].split("=");
            get[j[0]] = j[1];
        }
        return get;
    } else {
        return {};
    }
})();

    function getzhlogin() {
        $(".show_box").hide();
        $("#user_login").show();
    }

    function getsjreg() {
        $(".show_box").hide();
        $("#mobile_login").show();
    }

    //登陆
    $("#btnlogin").click(function() {
        checkLoginForm();
    });
    //提交表单
    function checkLoginForm() {
        var lvUsername = $("#username").val();
        var lvPWD = $("#password").val();
        if (lvUsername == "") {
            alert("请输入用户名！");
        } else if (lvUsername.length < 4) {
            alert("用户名长度不得小于4位！");
        } else if (!funcChina(lvUsername)) {
            alert("用户名不能含有汉字！");
        } else if (checkUserName(lvUsername)) {
            alert("用户名只能是字母和数字！");
        } else if (lvPWD == "" || lvPWD == "输入密码") {
            alert("输入密码！");
        } else if (lvPWD.length < 6) {
            alert("密码长度不得小于6位！");
        } else {
            $.post("api.php?act=login", {
                    "username": lvUsername,
                    "password": lvPWD
                },
                function(data) {
                    console.log(data);
                    data = JSON.parse(data);
                    if (data.code < 1) {
                        alert(data.msg);
                    } else {
                        window.location.href="server.php?username="+data.user+"&token="+data.token;
                    }
                });
        }
    }

    /**
     * 注册并登录
     */
    $("#btnreg").click(function() {
        $("#type").val("1");
        checkRegForm();
    });

    function checkRegForm() {
        var lvUsername = $("#m_username").val();
        var lvPWD = $("#m_password").val();
        var lvPWD2 = $("#m_password2").val();

        if (!lvPWD) {
            alert("请输入密码!");
            return false;
        } else if (lvPWD != lvPWD2) {
            alert("两次输入密码不同!");
            return false;
        } else if (lvUsername == lvPWD) {
            alert("帐号密码不能相同!");
            return false;
        } else if (lvUsername == "") {
            alert("请输入用户名！");
            return false;
        } else if (lvUsername.length < 4) {
            alert("用户名长度不得小于4位！");
        } else if (!funcChina(lvUsername)) {
            alert("用户名不能含有汉字！");
        } else if (checkUserName(lvUsername)) {
            alert("用户名只能是字母和数字！");
        } else if (lvPWD == "" || lvPWD == "输入密码") {
            alert("输入密码！");
        } else if (lvPWD.length < 6) {
            alert("密码长度不得小于6位！");
        } else {
            $.post("api.php?act=reg", {
                    "username": lvUsername,
                    "password": lvPWD,
                    "password1": lvPWD2
                },
                function(data) {
                    console.log(data);
                    data = JSON.parse(data);
                    if (data.code < 1) {
                        alert(data.msg);
                    } else {
                        window.location.href="server.php?username="+data.user+"&token="+data.token;
                    }
                });
        }
    }
</script>
</body>
</html>