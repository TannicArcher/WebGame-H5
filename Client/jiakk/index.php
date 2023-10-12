﻿<?php
error_reporting(0);
header("Content-type: text/html; charset=utf-8"); 
?>
<html>
<head>
<title>雷霆传奇_GM工具</title>
<style>
  *{padding:0;margin:0}
  body{padding-left:20px;padding-top:20px}
  span{height;24px;line-height:24px;font-size:12px;min-width:100px;display:inline-block;text-align:justify;text-align-last:justify;margin-bottom:12px}
  select,input,button{height:24px;line-height:24px;font-size:12px;width:150px;display:inline-block}
  #maildesc{text-align:none;color:#ff0000;}
</style>
</head>
<body>
<div>
  <!--[if IE]>
  <div><font color='red'>本工具不支持IE,请更换其他浏览器</font></div>
  <![endif]-->
  <div><span>选区: </span><select id='qu'><option value='1'>2区</option><!--<option value='2'>2区</option><option value='3'>3区</option>--></select></div>
  <div><span>账号: </span><input type='text' value='' id='uid' placeholder='请输入账号'></div>
    <div><span>充值: </span><input type='number' id='chargenum' placeholder='请输入充值数量'><input type='button' value='充值' id='chargebtn'></div>

  <div><span>开通: </span><td><select class="form-control selectpicker" id="chargenum2" name="num"><option value="8800">至尊特权</option><option value="2800">月卡</option></select>
  <input type='button' value='开通' id='chargebtn2'></div>


  
  
  <hr/><br>
  <div><span>温馨提示: </span><span id='maildesc'>点击发送或充值按钮后，请等待弹出提示以后在进行下一个操作。</span></div>
  <div><span>物品搜索: </span><input type='text' value='' id='searchipt' placeholder='物品搜索'></div>
  <div><span>物品选择: </span><select id='mailid'><option value='0' data-desc='请选择'>请选择</option>
  <?php
    $file = fopen("item.txt", "r");
    while(!feof($file))
    {
      $line=fgets($file);
      $txts=explode(';',$line);
      echo '<option value="'.$txts[0].'">'.$txts[1].'</option>';
    }
    fclose($file);
    ?>
  </select></div>
  <div><span>物品描述: </span><span id='maildesc'>请选择</span></div>
  <div><span>物品数量: </span><input type='text' value='' id='mailnum' placeholder='请输入发放数量'></div>
  <div><input type='button' value='发送邮件' id='mailbtn'></div>
</div>
<script src='jquery-1.7.2.min.js'></script>
<script>
  var uid='';
  var qu=$('#qu').val();
  $('#uid').change(function(){
	  uid=$.trim($(this).val());
  });
  $('#qu').change(function(){
	  qu=$.trim($(this).val());
  });
  $('#chargebtn').click(function(){
	  if(uid==''){
		  alert('角色名不能为空。');
		  return false;
	  }
	  var chargenum=$('#chargenum').val();
	  $.ajax({
		  url:'playerquery.php',
		  type:'post',
		  'data':{type:'charge',uid:uid,num:chargenum,qu:qu},
          'cache':false,
          'dataType':'json',
		  success:function(data){
			  console.log('data',data);
			  alert(data.info);
		  },
		  error:function(){
			  alert('操作失败');
		  }
	  });
  });
  $('#chargebtn2').click(function(){
	  if(uid==''){
		  alert('角色名不能为空。');
		  return false;
	  }
	  var chargenum2=$('#chargenum2').val();
	  $.ajax({
		  url:'playerquery.php',
		  type:'post',
		  'data':{type:'charge',uid:uid,num:chargenum2,qu:qu},
          'cache':false,
          'dataType':'json',
		  success:function(data){
			  console.log('data',data);
			  alert(data.info);
		  },
		  error:function(){
			  alert('操作失败');
		  }
	  });
  });

  $('#mailbtn').click(function(){
	  if(uid==''){
		  alert('角色名不能为空。');
		  return false;
	  }
	  var itemid=$('#mailid').val();
	  if(itemid=='' || itemid=='0'){
		  alert('请选择物品。');
		  return false;
	  }
	  var mailnum=$('#mailnum').val();
	  if(mailnum=='' || isNaN(mailnum)){
		  alert('数量不能为空。');
		  return false;
	  }
	  if(mailnum<1 || mailnum>9999){
		  alert('数量范围:1-9999。');
		  return false;
	  }
	  $.ajax({
		  url:'playerquery.php',
		  type:'post',
		  'data':{type:'mail',uid:uid,item:itemid,num:mailnum,qu:qu},
          'cache':false,
          'dataType':'json',
		  success:function(data){
			  console.log('data',data);
			  alert(data.info);
		  },
		  error:function(){
			  alert('操作失败');
		  }
	  });	  
  });
  $('#searchipt').on('change',function(){
	  var keyword=$(this).val();
	  $.ajax({
		  url:'itemquery.php',
		  type:'post',
		  'data':{keyword:keyword},
          'cache':false,
          'dataType':'json',
		  success:function(data){
			  if(data){
				  $('#mailid').html('');
				for (var i in data){
				  $('#mailid').append('<option value="'+data[i].key+'" data-desc="'+data[i].desc+'">'+data[i].val+'</option>');
				}
			  }else{
				  $('#mailid').html('<option value="0" data-desc="未找到">未找到</option>');
			  }
			  $('#maildesc').html('请选择');
		  },
		  error:function(){
			  alert('操作失败');
		  }
	  });
  });
  $('#mailid').live('change',function(){
	  console.log('test');
	  var desc=$('#mailid option:selected').data('desc');
	  $('#maildesc').html(desc);
  });
</script>
</body>
</html>