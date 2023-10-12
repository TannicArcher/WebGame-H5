<?php
function getRandomString($len, $chars=null)
{
    if (is_null($chars)){
        $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    }
    mt_srand(10000000*(double)microtime());
    for ($i = 0, $str = '', $lc = strlen($chars)-1; $i < $len; $i++){
        $str .= $chars[mt_rand(0, $lc)];
    }
    return $str;
}

if ($_POST){
    $post = $_POST;
    $conn = mysqli_connect('127.0.0.1','root','0987abc123','globaldata','3306') or die("数据库连接错误");
    $conn->query('set names utf8');
    switch ($_GET['act']){
        case 'login':{
            $user = $post['username'];
            $pass = $post['password'];
			$enpass = md5($pass);
            $result = mysqli_fetch_assoc($conn->query("SELECT * FROM players WHERE account = '$user' AND passwd = '$enpass'"));
            if ($result){
                $token = md5("xcas2d1z32c1566@#".$user);
                $data = array(
                    'code' => '1',
                    'msg' => 'success',
                    'token' => $pass,
                    'user' => $user
                );
            }else{
                $data = array(
                    'code' => '0',
                    'msg' => '错误的账号或密码!'
                );
            }
            exit(json_encode($data));
            break;
        }
        case 'reg':{
            $user = $post['username'];
            $pass = $post['password'];
            $pass1 = $post['password1'];
            if ($pass == $pass1){
                if (mysqli_fetch_assoc($conn->query("SELECT * FROM players WHERE account = '$user'"))){
                    $data = array(
                        'code' => '0',
                        'msg' => '用户名已被注册!'
                    );
                }else{
				    $enpass = md5($pass);
                    if ($conn->query("INSERT INTO players (account,passwd) VALUES ('$user','$enpass')")){
                        $token = md5("xcas2d1z32c1566@#".$user);
                        $data = array(
                            'code' => '1',
                            'msg' => 'success',
                            'token' => $pass,
                            'user' => $user
                        );
                    }else{
                        $data = array(
                            'code' => '0',
                            'msg' => '插入错误,请联系管理员!'
                        );
                    }
                }
            }else{
                $data = array(
                    'code' => '0',
                    'msg' => '两次密码不一致!'
                );
            }
            exit(json_encode($data));
            break;
        }
    }
}