/**
 * Created by Administrator on 2017/8/11.
 */
    //当文档窗口改变大小时触发
$(window).on('resize', function () {
    setTimeout(function () {
        updateWindowSize(true);
    }, 10);
});
/**
 * 显示选服页
 */
function showServerList(){
    $("#server_all").toggle();
}

/**
 * 选服区服区间
 * @param obj
 * @param stage
 */
function choseServer(obj,stage){
    $(".items").hide();
    $(".items_"+stage).show();
    $(".tag").removeClass("tagc");
    $(obj).addClass("tagc");
}

/**
 * 显示公告
 */
function showNotice(){
    $("#announce").toggle();
}

/**
 * 获取浏览器方向
 * @returns {*}
 */
function getOrientation(){
    var ua = navigator.userAgent;
    if(ua.match(/qzone/i))
        return 'portrait';
    var orien;
    switch(window.orientation) {
        case 90: case -90:
            orien = 'landscape';
            break;
        default:
            orien = 'portrait';
            break;
    }
    return orien;
}

/**
 * 改变窗口大小
 */
function updateWindowSize(showBox){
    if($(".gameDiv").length){
        var frameWidth = $("body").width();
        var frameHeight = $("body").height();
        window.scrollTo(0, 1);
        //var orien = getOrientation();
        //if(orien != 'portrait'){
        //    alert("请使用竖屏游戏更激情!");
        //    return false;
        //}
        var w = frameWidth > frameHeight ? frameHeight * 0.56 : frameWidth;
        var h = frameHeight;
        //简单适配 游戏div
        $(".gameDiv").css("height",h + "px");
        $(".gameDiv").css("width",w + "px");
        if(showBox && $("#gbox").length){
            var _uniScale = Math.min(h/1136, w/640);
            var _topY,_leftX;
            var _scaleY = _uniScale;
            var _scaleX = _uniScale;
            _topY = (h - _uniScale * 1136) / 2;
            _leftX = (w - _uniScale * 640) / 2;
            $("#gbox").css({
                "width" : "640px",
                "height" : "1136px",
                "left" : _leftX + "px",
                "top" : _topY + "px",
                "transform" : 'scale('+_scaleX+','+_scaleY+')',
                "-webkit-transform" : 'scale('+_scaleX+','+_scaleY+')',
                "-ms-transform" : 'scale('+_scaleX+','+_scaleY+')',
                "-moz-transform" : 'scale('+_scaleX+','+_scaleY+')',
                "-o-transform" : 'scale('+_scaleX+','+_scaleY+')'
            });
        }
    }
}

/**
 * 动态加载js
 * @param url
 * @param callback
 * @returns {Element}
 */
function loadScript(url, callback) {
    var script = document.createElement("script");
    script.type = "text/javascript";
    script.setAttribute('crossorigin', '');
    script.onload = function () {
        callback && callback();
    };
    script.onerror = function () {
        script.parentNode.removeChild(script);
        setTimeout(function () {
            loadScript(url, callback);
        }, 1000);
    };
    script.src = url;
    document.getElementsByTagName("head")[0].appendChild(script);
    return script;
}
