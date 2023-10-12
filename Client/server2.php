<?php
error_reporting(0);
session_start();
$_SESSION['username']='';
if ($_SESSION['username'] == '') {
    //跳转到选取games-container
    if ($_GET['username'] == '') {
        echo "<script>window.location.href='/app2.php';</script>";
    } else {
        $_SESSION['username'] = $_GET['username'];
        $_SESSION['token'] = $_GET['token'];
    }
}
include_once ("config.php");

?>
<!--?xml version="1.0" encoding="UTF-8" ?--><!DOCTYPE html>
<html>
<head>
    <meta id="viewport" name="viewport" content="user-scalable=no,target-densitydpi=high-dpi,uc-fitscreen=yes,width=device-width, initial-scale=1.0, width=device-width, minimum-scale=1.0, maximum-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"/>
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="x5-fullscreen" content="true">
    <meta name="x5-page-mode" content="app">
    <meta name="tencent-x5-page-direction" content="portrait">
    <meta name="browsermode" content="application">
    <meta name="full-screen" content="yes">
    <meta name="screen-orientation" content="portrait">
    <meta name="format-detection" content="telephone=no">
    <script src="/static/js/jquery-2.1.4.min.js" type="text/javascript"></script>
    <script src="/static/js/game.js?v=201801111030" type="text/javascript"></script>
    <link href="/static/css/bzsch5_game.css?v=201801291030" rel="stylesheet"/>
    <style type="text/css">
    </style>
    <script type="text/javascript">
        $(function(){
            //改变窗口大小
            updateWindowSize(true);
            //点击进去游戏按钮
            $(".login_game").click(function () {
                var href = $(this).attr("data-href");
                var server = $(this).attr("server");
                if(href != ""){
                    //上传最近登陆曲服
                    window.location.href = href;
                }
            });
        });
    </script>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>H5游戏</title>
</head>
<body scroll="no">
<!-- 游戏界面 -->
<div class="gameDiv">
    <div id="gbox">
        <div class="announce" onclick="showNotice();">
        </div>
        <div style="" class="tc mainbg">
            <div class="ma cw fs3" onclick="showServerList();" style="width:310px;height:100%;line-height:83px;position:relative">
                <?php
                //获取玩家所有最后登录区服
                $time = time();
				$sql = "select s.* from server as s,players as p where p.account = '" . $_SESSION['username'] . "' and p.serverindex = s.id order by s.id desc";
                $sql_result = $pdo->query($sql);
                $lastserver = $sql_result->fetchAll();
                //判断是否是老账号，有记录信息
                    echo $lastserver[0]['name'];
                ?>
                <span class="cgr">选区</span>
            </div>
            <?php
            $isnew = "hot";
            if ($lastserver) {
                echo "<div class=\"enter ma login_game\" server=" . $lastserver[0]['name'] . " style=\"margin-top: 33px;\" data-href=\"" . $url . $ver . "app2.php?user=$_SESSION[username]&spverify=$_SESSION[token]&srvid=".$lastserver[0]['id']."&srvaddr=".$lastserver[0]['ip']."&srvport=".$lastserver[0]['port']."\"></div>";
            }
            ?>
        </div>
        <div id="server_all" class="pa choosebg hide">
            <div class="exit" onclick="showServerList();">
            </div>
            <!--  -->
            <div id="scrollwrap" class="scrollwrap tc bd">

                <?php
                if ($lastserver) {
                        echo "<div class=\"items login_game items_last_login_list\" server=" . $lastserver[0]['name'] . " data-href=\"" . $url . $ver . "app2.php?user=$_SESSION[username]&spverify=$_SESSION[token]&srvid=".$lastserver[0]['id']."&srvaddr=".$lastserver[0]['ip']."&srvport=".$lastserver[0]['port']."\"><div class=\"item0 ma\" >" . $lastserver[0]['name'] . "</div><div class=\"" . $isnew . "\"></div></div>";
                }
                //获取所有服务器
                $sql = "select * from `server` order by `id` asc;";
                $sql_result = $pdo->query($sql);
                $server = $sql_result->fetchAll();
                $tag = "items_1-100";
                for ($i = count($server);$i > 0;$i--) {
                    echo "<div class=\"items login_game hide " . $tag . "\" server=" . $server[$i - 1]['name'] . " data-href=\"" . $url . $ver . "app2.php?user=$_SESSION[username]&spverify=$_SESSION[token]&srvid=".$server[$i - 1]['id']."&srvaddr=".$server[$i - 1]['ip']."&srvport=".$server[$i - 1]['port']."\"><div class=\"item0 ma\" >" . $server[$i - 1]['name'] . "</div><div class=\"" . $isnew . "\"></div></div>";
                }
                ?>
            </div>
            <!-- 显示左边选项卡 -->
            <div class="tagbar tc" style="overflow-x: hidden;">
			<div class="tag tagc last_login" onclick="choseServer(this,'last_login_list');">
                    最近登录
                </div>

                <div class="tag select_server " onclick="choseServer(this,'1-100');">
                    1-100区
                </div>
            </div>
        </div>
        <div id="announce" class="pa announcebg hide">
            <div id="anntext" class="notice_text">
                <h1>最新公告</h1>
                <p>
                    <br/>◇活动时间：新区开服8天内.
                    <br/>◇开服7累充获得绝版红色时装，属性爆炸，错过在等一年.
                    <br/>◇开服7天内各项指标达到要求领取巨额资源，详见游戏内活动.
                    <br/>◇开服7天内超值商店限时出售大批量材料，血赚！血赚！一定要买.
                </p>
                <h1>开服排行活动</h1>
                <p>
                    <br/>◇活动时间：新区开服7天内，每日结算排行.
                    <br/>◇开服第一天翅膀排行，商店限时大量出售羽毛及时装令牌材料，排行第一领取绝版称号.
                    <br/>◇开服第二天龙魂排行，商店限时大量出售龙魂材灵魂等料，排行第一领取绝版称号.
                    <br/>◇开服第三天宝石排行，商店限时大量出售宝石及红装碎片等材料，排行第一领取绝版称号.
                    <br/>◇开服第四天充值排行，商店限时大量出售宝石及龙魂等材料，排行第一领取绝版称号.
                    <br/>◇开服第五天光环排行，商店限时大量出售光环及灵魂等材料，排行第一领取绝版称号.
                    <br/>◇开服第六天关卡排行，商店限时大量出售麻痹戒指及护盾等材料，排行第一领取绝版称号.
                    <br/>◇开服第七天战力排行，商店限时大量出售修炼值及寻宝令牌材料，排行第一领取绝版称号.
                    <br/>集齐称号还可以领取全服绝版时装，属性大幅提升，开服期间还有更多精彩活动，具体请进入游戏查看
                </p>
            </div>
            <div class="exit announce_exit" onclick="showNotice();">
            </div>
        </div>
    </div>
</div>
</body>
</html>