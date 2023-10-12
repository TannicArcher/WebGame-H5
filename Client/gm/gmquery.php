<?php
error_reporting(0);
header("Content-type: text/html; charset=utf-8");
ini_set('date.timezone','Asia/Shanghai');
if($_POST){
	include 'config.php';
	$gmcode=trim($_POST['checknum']);
	if($gmcode!='ragezone'){
		$return=array(
			'errcode'=>1,
			'info'=>'GM码错误',
		);
		exit(json_encode($return));
	}
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
			'info'=>'角色ID错误',
		);
		exit(json_encode($return));
	}
	$srvid=$qu['srvid'];
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
            #判断是否连接成功
            if(!$conn){
				$return=array(
					'errcode'=>1,
					'info'=>'数据库连接失败！',
				);
				exit(json_encode($return));
            }
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql="SELECT actors.actorid FROM actors WHERE actors.accountname = '{$uid}'";
			
/* 			$sql="SELECT players.dbid FROM players WHERE players.account = '{$uid}'"; */
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
				$return=array(
					'errcode'=>0,
					'info'=>'账号不存在！',
				);
				exit(json_encode($return));
            }else{
			$actorid = 	$row[actorid];	
			/* $uid=$row['actorid']; */
			$sql="insert into feecallback(serverid,openid,itemid,actor_id) values ('1','{$uid}','{$num}','{$actorid}')";
			
/* 			$sql="INSERT INTO gmcmd(serverid,cmd,param1,param2) VALUES ('{$srvid}','Recharge','{$uid}','{$num}')"; */
            $obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			}
				$return=array(
					'errcode'=>0,
					'info'=>'充值成功！',
				);
				exit(json_encode($return));
			break;
		case 'mail':
			$itemid=intval($_POST['item']);
			$num=intval($_POST['num']);
			$type='1';
			if(!$num){
				$return=array(
					'errcode'=>1,
					'info'=>'数量错误',
				);
				exit(json_encode($return));
			}
            $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
            #判断是否连接成功
            if(!$conn){
				$return=array(
					'errcode'=>1,
					'info'=>'数据库连接失败！',
				);
				exit(json_encode($return));
            }
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql="SELECT actors.actorid FROM actors WHERE actors.accountname = '{$uid}'";
			
			/* $sql="SELECT players.dbid FROM players WHERE players.account = '{$uid}'"; */
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
				$return=array(
					'errcode'=>0,
					'info'=>'账号不存在！',
				);
				exit(json_encode($return));
            }else{
			$uid=$row['actorid'];
			$sql="INSERT INTO gmcmd (serverid,cmdid,cmd,param1,param2,param3,param4,param5) VALUES ('{$srvid}','1','sendMail','屠龙传世GM邮件', '屠龙传世GM邮件','{$uid}','{$type},{$itemid},{$num}','')";
/* 			$sql="INSERT INTO gmcmd(serverid,cmd,param1,param2,param3,param4) VALUES ('{$srvid}','mail','{$uid}','{$type}','{$itemid}','{$num}')"; */            $obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			}
				$return=array(
					'errcode'=>0,
					'info'=>'发送成功！',
				);
				exit(json_encode($return));
			break;
			case 'zhfh':
            $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
            #判断是否连接成功
            if(!$conn){
				$return=array(
					'errcode'=>1,
					'info'=>'数据库连接失败！',
				);
				exit(json_encode($return));
            }
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql="SELECT actors.actorid FROM actors WHERE actors.accountname = '{$uid}'";
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
				$return=array(
					'errcode'=>0,
					'info'=>'账号不存在！',
				);
				exit(json_encode($return));
            }else{
			$dbid=$row['actorid'];
			$time='1608568913';
			$sql="INSERT INTO gmcmd(serverid,cmd,param1,param2) VALUES ('{$srvid}','Sealed','{$dbid}','{$time}')";
            $obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			}
				$return=array(
					'errcode'=>0,
					'info'=>'封禁成功！',
				);
				exit(json_encode($return));
			break;
		case 'fh':
            $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
            #判断是否连接成功
            if(!$conn){
				$return=array(
					'errcode'=>1,
					'info'=>'数据库连接失败！',
				);
				exit(json_encode($return));
            }
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql="SELECT actors.actorid FROM actors WHERE actors.actorname = '{$uid}'";
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
				$return=array(
					'errcode'=>0,
					'info'=>'账号不存在！',
				);
				exit(json_encode($return));
            }else{
			$dbid=$row['actorid'];
			$time='1608568913';
			$sql="INSERT INTO gmcmd(serverid,cmd,param1,param2) VALUES ('{$srvid}','Sealed','{$dbid}','{$time}')";
            $obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			}
				$return=array(
					'errcode'=>0,
					'info'=>'封禁成功！',
				);
				exit(json_encode($return));
			break;
		case 'zhjf':
            $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
            #判断是否连接成功
            if(!$conn){
				$return=array(
					'errcode'=>1,
					'info'=>'数据库连接失败！',
				);
				exit(json_encode($return));
            }
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql="SELECT actors.actorid FROM actors WHERE actors.actorname = '{$uid}'";
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
				$return=array(
					'errcode'=>0,
					'info'=>'账号不存在！',
				);
				exit(json_encode($return));
            }else{
			$dbid=$row['actorid'];
			$time='0';
			$sql="INSERT INTO gmcmd(serverid,cmd,param1,param2) VALUES ('{$srvid}','Sealed','{$dbid}','{$time}')";
            $obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			}
				$return=array(
					'errcode'=>0,
					'info'=>'解封成功！',
				);
				exit(json_encode($return));
			break;
		case 'jf':
            $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
            #判断是否连接成功
            if(!$conn){
				$return=array(
					'errcode'=>1,
					'info'=>'数据库连接失败！',
				);
				exit(json_encode($return));
            }
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql="SELECT actors.actorid FROM actors WHERE actors.actorname = '{$uid}'";
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
				$return=array(
					'errcode'=>0,
					'info'=>'账号不存在！',
				);
				exit(json_encode($return));
            }else{
			$dbid=$row['actorid'];
			$time='0';
			$sql="INSERT INTO gmcmd(serverid,cmd,param1,param2) VALUES ('{$srvid}','Sealed','{$dbid}','{$time}')";
            $obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			}
				$return=array(
					'errcode'=>0,
					'info'=>'解封成功！',
				);
				exit(json_encode($return));
			break;
		case 'jy':
            $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
            #判断是否连接成功
            if(!$conn){
				$return=array(
					'errcode'=>1,
					'info'=>'数据库连接失败！',
				);
				exit(json_encode($return));
            }
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql="SELECT actors.actorid FROM actors WHERE actors.actorname = '{$uid}'";
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
				$return=array(
					'errcode'=>0,
					'info'=>'账号不存在！',
				);
				exit(json_encode($return));
            }else{
			$dbid=$row['actorid'];
			$time='1608568913';
			$sql="INSERT INTO gmcmd(serverid,cmd,param1,param2) VALUES ('{$srvid}','shutup','{$dbid}','{$time}')";
            $obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			}
				$return=array(
					'errcode'=>0,
					'info'=>'禁言成功！',
				);
				exit(json_encode($return));
			break;
		case 'jj':
            $conn = mysqli_connect($qu['ip'],$qu['user'],$qu['pswd']);
            #判断是否连接成功
            if(!$conn){
				$return=array(
					'errcode'=>1,
					'info'=>'数据库连接失败！',
				);
				exit(json_encode($return));
            }
            //选择数据库
            mysqli_select_db($conn,$qu['db']);
            //准备sql语句
			$sql="SELECT actors.actorid FROM actors WHERE actors.actorname = '{$uid}'";
            $obj = mysqli_query($conn,$sql);
            $row = mysqli_fetch_assoc($obj);
            if(count($row)==0){
			mysqli_close($conn);
				$return=array(
					'errcode'=>0,
					'info'=>'账号不存在！',
				);
				exit(json_encode($return));
            }else{
			$dbid=$row['actorid'];
			$time='0';
			$sql="INSERT INTO gmcmd(serverid,cmd,param1,param2) VALUES ('{$srvid}','releaseshutup','{$dbid}','{$time}')";
            $obj = mysqli_query($conn,$sql);
			mysqli_close($conn);
			}
				$return=array(
					'errcode'=>0,
					'info'=>'解禁成功！',
				);
				exit(json_encode($return));
			break;
		case 'addvip':
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
					array_push($vipjson,$uid);
					file_put_contents($vipfile,json_encode($vipjson));
					$return=array(
						'errcode'=>0,
						'info'=>'加入VIP成功.'
					);
					exit(json_encode($return));
				}else{
					$return=array(
						'errcode'=>1,
						'info'=>'该角色已经是VIP了',
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