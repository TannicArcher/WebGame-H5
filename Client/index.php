<span style="font-size:18px;"><?php
require_once 'function.php';
if (isMobile()){
    //��ת���ֻ���
    header("Location: index1.php"); 
}else{
    //��ת��PC��
    header("Location: index2.php"); 
}
?></span>