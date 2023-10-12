<?php
$conn=@mysql_connect('127.0.0.1','root','0987abc123') or die("数据库连接失败,请联系管理员！");
mysql_select_db('globaldata',$conn);
mysql_query("SET NAMES utf8");
function getstr($str){
    if(isset($_GET[$str])){
        return $_GET[$str];
    }
    die("this link server do not exist");
}
?>