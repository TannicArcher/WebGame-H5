            function funcChina(str) {
                if (/.*[\u4e00-\u9fa5]+.*$/.test(str))
                {
                    //alert("不能含有汉字！");
                    return false;
                }
                return true;
            }

            /**
             * 判断数字和字母
             */
            function checkUserName(str) {
                if (/^[A-Za-z0-9]+$/.test(str))
                {
                    //alert("不能含有汉字！");
                    return false;
                }
                return true;
            }
            
            
            //判断微信浏览器
            function isWeiXin(){
                var ua = window.navigator.userAgent.toLowerCase();
                if(ua.match(/MicroMessenger/i) == 'micromessenger'){
                    return true;
                }else{
                    return false;
                }
            }

