<?php
include 'config.ini.php';
$user = getstr('user');
$pass = getstr('spverify');
$pass1 = md5($pass);
$sid = getstr('srvid');
$srvaddr = getstr('srvaddr');
$srvport = getstr('srvport');
$sqlcx = "SELECT * FROM globaldata.players WHERE account = '$user' and passwd = '$pass1'";
$result = mysql_query($sql, $conn);
$row = mysql_fetch_array($result);
$datetime = date('Y-m-d h:i:s');
if($row['account']!=$user && $row['passwd']!=$pass1){
	$sql = "INSERT INTO actor".$sid.".globaluser (`account`, `passwd`, `identity`, `createtime`) VALUES ('$user','$pass1','430481198112113256','$datetime')";
    mysql_query($sql, $conn);	
}else{
	$sql1 = "UPDATE actor".$sid.".globaluser SET updatetime='$datetime' WHERE account='$user' and passwd = '$pass1';";
	mysql_query($sql1, $conn);
}
if($row['serverindex']!='$sid'){
	$sql2 = "UPDATE players SET serverindex='$sid' WHERE account='$user' and passwd = '$pass1'";
	mysql_query($sql2, $conn);
}
header("Location: ./game.php?user=$user&spverify=$pass&srvid=$sid&srvaddr=$srvaddr&srvport=$srvport");
?>

