var slider={
 num:-1,
 cur:0,
 cr:[],
 al:null,
 at:3*1000,
 ar:true,
 obj:'',
 width:'500',
 height:'250',
 init:function(param){
	var o = $.extend({obj:""},param);
	slider.obj = $(o.obj);
	slider.width=slider.obj.find('a img').width();
	slider.height=slider.obj.find('a img').height();
	slider.num=slider.obj.find('a img').length;
	var pos=Math.floor(Math.random()*1);//slider.num);
	slider.obj.css({width : slider.width,height : slider.height,overflow : 'hidden',position : 'absolute'});
	slider.obj.append('<div id="slide-controls"><p id="slide-desc" class="text"></p><p id="slide-nav"></p></div>');
	$("#slide-controls").css({left: "0",bottom: "0px",width: "100%",height: "46px",display: "none",position: "absolute",/*background: 'url(http://files.gamedog.cn/game2013/img/slide-bg.png) 0 0'*/});
	$("#slide-desc").css({float: 'left',color: '#fff',display: 'block','line-height': '18px',margin: '15px 0 0 20px','text-transform': 'uppercase','word-wrap': 'break-word'});
	$("#slide-nav").css({float: 'right',height: '24px',display: 'inline',margin: '17px 15px 0 0'});
	slider.obj.find('a img').each(function(i,o){
		$(this).css({left:((i-pos)*(slider.width)),margin: '0',display: 'none',position: 'absolute',width : slider.width,height : slider.height});
		$('#slide-nav').append('<a id="slide-link-'+i+'" href="javascript:;" onMouseOver="slider.slide('+i+');" onfocus="this.blur();"></a>');
	});
	$("#slide-nav a").css({position: 'relative',display: 'inline',width: '14px',height: '14px',margin: '0 4px',outline: '0',float: 'left'});
	$('div#slide-runner img,div#slide-controls').fadeIn();
	slider.text(0);
	slider.on(pos);
	slider.cur=pos;
	window.setTimeout('slider.auto();',slider.at);
 },
 auto:function(){
	if(!slider.ar)
	return false;
	
	var next=slider.cur+1;
	if(next>=slider.num) next=0;
	slider.slide(next);
 },
 slide:function(pos){
  if(pos<0 || pos>=slider.num || pos==slider.cur)
   return;

  window.clearTimeout(slider.al);
  slider.al=window.setTimeout('slider.auto();',slider.at);

  slider.obj.find('a img').each(function(i,o){
	  $(this).stop().animate({left:((i-pos)*(slider.width))},1000,'swing');
  });
  slider.on(pos);
  slider.text(pos);
  slider.cur=pos;
 },
 on:function(pos){
  $('#slide-nav a').css({background: 'url(http://files.gamedog.cn/game2013/img/h5slide-nav.gif) no-repeat -21px 0'});
  $('#slide-nav a#slide-link-'+pos).css({background: 'url(http://files.gamedog.cn/game2013/img/h5slide-nav.gif) no-repeat 0 0'});
 },
 text:function(di){
	 var text = slider.obj.find('a img').eq(di).attr('alt') || "";
	 if(text.length==0){
		 $("#slide-controls").css("background",null);	
	 }else{
		 $("#slide-desc").html(text);
	 }
 }
};
