<span style="font-size:18px;"><?php
require_once 'function.php';
if (isMobile()){
    //跳转到手机端
    header("Location: index1.php"); 
}else{
    //跳转到PC端
    header("Location: index2.php"); 
}
?></span>