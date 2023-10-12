<?php
error_reporting(0);
header("Content-type: text/html; charset=utf-8");
ini_set('date.timezone','Asia/Shanghai');
if($_POST){
	include 'config.php';
	$quid=trim($_POST['qu']);
	if($quid==''){
		$return=array(
			'errcode'=>1,
			'info'=>'区号错误',
		);
		exit(json_encode($return));
	}
	$qu=$quarr[$quid];
	if(!$qu['ip']){
		$return=array(
			'errcode'=>1,
			'info'=>'区配置不存在',
		);
		exit(json_encode($return));
	}
	$uid=trim($_POST['uid']);
	if($uid==''){
		$return=array(
			'errcode'=>1,
			'info'=>'角色名错误',
		);
		exit(json_encode($return));
	}
				$vipfile='vip_'.$quid.'.json';
				$fp = fopen($vipfile,"a+");
				if(filesize($vipfile)>0){
					$str = fread($fp,filesize($vipfile));
					fclose($fp);
					$vipjson=json_decode($str);
					if($vipjson==null){
						$vipjson=array();
					}
				}else{
					$vipjson=array();
				}
				if(!in_array($uid,$vipjson)){
					$return=array(
						'errcode'=>1,
						'info'=>'你还不是授权客户.'
					);
					exit(json_encode($return));
				}
	$act=$_POST['type'];
	switch($act){
		case 'charge':
			$num=intval($_POST['num']);
			if(!$num){
				$return=array(
					'errcode'=>1,
					'info'=>'充值数量错误',
				);
				exit(json_encode($return));
			}
		    $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
			$sql="set names utf8;";
			mysqli_query($conn,$sql);
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql = "SELECT actors.actorid FROM actors WHERE actors.accountname = '{$uid}'";
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
			$return=array(
					'errcode'=>1,
					'info'=>'没有找到相关角色!',
				);
			exit(json_encode($return));
			}else{
			$actorid =$row[actorid];
			$serviceid=$qu['serviceid'];
			$sql="insert into feecallback(serverid,openid,itemid,actor_id) values ('{$serviceid}','{$uid}','{$num}','{$actorid}')";
			$obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			$return=array(
					'errcode'=>1,
					'info'=>'充值成功!',
				);
			exit(json_encode($return));
		    }
			break;
		case 'mail':
			$itemid=$_POST['item'];
			$num=intval($_POST['num']);
			if(!$num){
				$return=array(
					'errcode'=>1,
					'info'=>'数量错误',
				);
				exit(json_encode($return));
			}
		    $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
			$sql="set names utf8;";
			mysqli_query($conn,$sql);
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql = "SELECT actors.actorid FROM actors WHERE actors.accountname = '{$uid}'";
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
			$return=array(
					'errcode'=>1,
					'info'=>'没有找到相关角色!',
				);
			exit(json_encode($return));
			}else{
			$actorid =$row[actorid];
			$serviceid=$qu['serviceid'];
			$award='1,'.$itemid.','.$num;
			$sql="INSERT INTO gmcmd (serverid, cmdid, cmd, param1, param2, param3, param4, param5) VALUES ('{$serviceid}','1','sendMail','管理员邮件', '这是GM发给你的超级福利！！！','{$actorid}','{$award}','')";
			$obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			$return=array(
					'errcode'=>1,
					'info'=>'发送成功!'.$sql,
				);
			exit(json_encode($return));
		    }
			break;
		default:
			$return=array(
				'errcode'=>1,
				'info'=>'数据错误',
			);
			exit(json_encode($return));
			break;
	}
}else{
	$return=array(
		'errcode'=>1,
		'info'=>'提交错误',
	);
	exit(json_encode($return));
}