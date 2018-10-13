<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		<meta HTTP-EQUIV="Pragma" CONTENT="no-cache"/>
		<meta HTTP-EQUIV="Expires" CONTENT="-1"/>
		<link rel="shortcut icon" href="images/favicon.png"/>
		<link rel="icon" href="images/favicon.png"/>
		<title>BonusCloud-Node</title>
		<link rel="stylesheet" type="text/css" href="index_style.css"/>
		<link rel="stylesheet" type="text/css" href="form_style.css"/>
		<link rel="stylesheet" type="text/css" href="usp_style.css"/>
		<link rel="stylesheet" type="text/css" href="ParentalControl.css">
		<link rel="stylesheet" type="text/css" href="css/icon.css">
		<link rel="stylesheet" type="text/css" href="css/element.css">
		<script type="text/javascript" src="/state.js"></script>
		<script type="text/javascript" src="/popup.js"></script>
		<script type="text/javascript" src="/help.js"></script>
		<script type="text/javascript" src="/validator.js"></script>
		<script type="text/javascript" src="/js/jquery.js"></script>
		<script type="text/javascript" src="/general.js"></script>
		<script type="text/javascript" src="/switcherplugin/jquery.iphone-switch.js"></script>
		<script type="text/javascript" src="/dbconf?p=bxc_&v=<% uptime(); %>"></script>
		<style>
			input[type=button]:focus {
				outline: none;
			}	
			.show-btn1, .show-btn2, .show-btn3 {
				border-radius: 5px 5px 0px 0px;
				font-size:10pt;
				color: #fff;
				padding: 10px 3.75px;
				width:8.45601%;
				border: 1px solid #222;
				background: linear-gradient(to bottom, #919fa4 0%, #67767d 100%);
			}
			.active {
				background: linear-gradient(to bottom, #61b5de 0%, #279fd9 100%);
				border: 1px solid #222;
			}
			#log_content1 {
				width:97%;
				padding-left:4px;
				padding-right:37px;
				font-family:'Lucida Console';
				font-size:11px;
				color:#FFFFFF;
				outline:none;
				overflow-x:hidden;
				border:0px solid #222;
				background:#475A5F;
			}
		</style>
        <script type="text/javascript">
        	var bxc_db;
        	var online_table;
        	var _responseLen;
        	var status_check_waite = 3000;
        	var status_check_interval;

        	function E(e) {
				return (typeof(e) == 'string') ? document.getElementById(e) : e;
			}

			function init() {
				show_menu();
				dbus_read();
				init_show();
				tab_switch();

			}

			function init_show() {
				var bxc_bcode = dbus_read("bxc_bcode");
				if (typeof(bxc_bcode) != 'undefined' && bxc_bcode != '') {
					/* BCode已经存在 */
					E("bxc_bound").style.display = "none";
					E("bxc_status").style.display = "";
					bxc_show_status();
				} else {
					/* BCode不存在 */
					E("bxc_bound").style.display = "";
					E("bxc_status").style.display = "none";
					$("#bound_mac").html(bxc_db["bxc_wan_mac"]);
				 	var bxc_log_lev = bxc_db["bxc_log_level"];
					if (bxc_log_lev == "debug") {
						E("bound_log")[1].selected=true;
					} else {
						E("bound_log")[0].selected=true;
					}
				}
			}

			function tab_switch(){
				if($('.show-btn1').hasClass("active")){
					E("tablet_1").style.display = "";
					E("tablet_2").style.display = "none";
				}else if($('.show-btn2').hasClass("active")){
					E("tablet_1").style.display = "none";
					E("tablet_2").style.display = "";
				}else{
					$('.show-btn1').addClass('active');
					$('.show-btn2').removeClass('active');
					E("tablet_1").style.display = "";
					E("tablet_2").style.display = "none";
				}
				$(".show-btn1").click(
				function() {
					$('.show-btn1').addClass('active');
					$('.show-btn2').removeClass('active');
					E("tablet_1").style.display = "";
					E("tablet_2").style.display = "none";
				});
				$(".show-btn2").click(
				function() {
					setTimeout("get_log();", 200);
					$('.show-btn1').removeClass('active');
					$('.show-btn2').addClass('active');
					E("tablet_1").style.display = "none";
					E("tablet_2").style.display = "";
				});
			}

			function bxc_bound_bcode() {
				var bcode = $("#bxc_bcode").val().replace(/^\s+|\s+$/g,"");
				var email = $("#user_email").val().replace(/^\s+|\s+$/g,"");
				if (typeof(bcode) == 'undefined' || bcode == "") {
					bxc_bound_msg('请输入BCode！');
				} else if (!bcode_islegal(bcode)) {
					bxc_bound_msg('BCode<font color="#FF9900">"'+bcode+'"</font>格式不正确');
				} else if (typeof(email) == 'undefined' || email == "") {
					bxc_bound_msg('请输入用户邮箱信息!');
				} else {
					bound_bcode(bcode, email);
				}
			}

			function bcode_islegal(bcode) {
				/* 判断BCode的内容合法性 */
				var pattern = RegExp("^[0-9]{4}-[A-z0-9]{8}-[A-z0-9]{4}-[A-z0-9]{4}-[A-z0-9]{4}-[A-z0-9]{12}$");
				return pattern.test(bcode);
			}

			function bound_bcode(bcode, email) {
				/* 根据BCode和设备WAN口MAC地址向服务端进行绑定，并将BCode写入DBUS */
				var wan_mac = dbus_read("bxc_wan_mac");
				dbus_write("bxc_input_bcode", bcode);
				dbus_write("bxc_user_mail", email);
				dbus_write("bxc_bound_status", "init");
				bxc_option("bound");
				bxc_bound_msg("校验通过，正在申请绑定...");
				var tryTime = 12;
				var interval = setInterval(function(){
					console.log('bound', tryTime, dbus_read('bxc_bound_status'));
					tryTime--;
					if(dbus_read("bxc_bound_status") == "success"){
    					bxc_bound_msg("绑定成功，页面自动刷新！");
						clearInterval(interval);
						//location.reload();
						E("bxc_bound").style.display = "none";
						E("bxc_status").style.display = "";
						bxc_show_status();
					} else if (!tryTime) {
						var fail_msg = dbus_read("bxc_bound_status");
						bxc_bound_msg("绑定失败："+fail_msg)
					}
					if (!tryTime) {
						clearInterval(interval);
					}
				}, 1000);
			}


			/* BxC Node 运行状态及更新配置等功能*/
			function bxc_show_status() {
				/*
					检查BxC Node运行状态，开机启动状态
				*/
				bxc_option("status")

				$('#switch').prop('disabled', true); // 不能操作开关
				E("switch").checked=false;
				$("#status_msg").html("检测BonusCloud-Node运行状态...")

				// 获取新的dbus信息
				dbus_read();
				$("#current_version").html(bxc_db["bxc_local_version"]);
				$("#status_mac").html(bxc_db["bxc_wan_mac"]); 
				var bxc_bcode = dbus_read("bxc_bcode");
				if (bxc_bcode != "") {
					E("bxc_bcode_show").innerHTML = bxc_bcode;
				}
				var bxc_user_mail = dbus_read("bxc_user_mail");
				if (bxc_user_mail != "") {
					E("bxc_user_mail").innerHTML = bxc_user_mail;
				}

				var	bxc_onboot = dbus_read("bxc_onboot");
				if (bxc_onboot == "yes") {
					E("bxc_start_onboot")[0].selected=true;
				} else {
					E("bxc_start_onboot")[1].selected=true;
				}

				var bxc_log_lev = dbus_read("bxc_log_level")
				if (bxc_log_lev == "debug") {
					E("bxc_log")[1].selected=true;
				} else {
					E("bxc_log")[0].selected=true;
				}

				status_check_interval = E("status_interval").value * 1000;

				setTimeout(function() {
					// 第一次检测需要确定status信息以及开关状态
					var bxc_status = dbus_read('bxc_status');
					$('#switch').prop('disabled', false);// 打开按键操作
					if (bxc_status == "running") {
						E("switch").checked=true;
						$("#status_msg").html("BonusCloud-Node已启动，正在运行中...")
					} else {
						E("switch").checked=false;
						$("#status_msg").html("BonusCloud-Node 没有启用！")
					}

					// 一直检测BxC-Node运行情况
					var intervalCheck = setInterval(check_func, status_check_interval);
					function check_func(){
						bxc_option("status");
						var bxc_status = dbus_read('bxc_status');
						console.log('bxc_check', bxc_status);
						if(bxc_status == "running"){
	    					$("#status_msg").html("BonusCloud-Node已启动，正在运行中...");
						} else{
	    					$("#status_msg").html("BonusCloud-Node 没有启用！");
						}
						clearInterval(intervalCheck);
						if ( status_check_interval > 0 ) {
							intervalCheck = setInterval(check_func, status_check_interval);
						}
					}
				}, status_check_waite);
			}
			
			function bxc_option(action) {
				dbus_write("bxc_option", action)
				var data = {"SystemCmd":"bxc.sh", "current_page":"Module_BxC.asp", "action_mode":" Refresh ", "action_script":""};
				$.ajax({
					type: "POST",
					url: "applydb.cgi?p=bxc_",
    				dataType: 'text',
    				data: data,
				});
			}

			function bxc_switch_status() {
				$('#switch').prop('disabled', true);
				if(E("switch").checked){
					$('#switch').prop('checked', true);
					$("#switch_msg_show").show();
    				$("#switch_msg").html("BonusCloud-Node 开始启动...");
					bxc_option("start");
					var tryTime = 30;
					var interval = setInterval(function(){
						console.log('enable', tryTime, dbus_read('bxc_status'));
						tryTime--;
						if(dbus_read("bxc_status") == "running"){
	    					$("#switch_msg_show").hide();
							$('#switch').prop('disabled', false);
							clearInterval(interval);
						} else if (!tryTime) {
							$('#switch').prop('checked', false);
							$('#switch').prop('disabled', false);
	    					$("#switch_msg_show").hide();
						}
						if (!tryTime) {
							clearInterval(interval);
						}
					}, 1000);
				} else {
					$('#switch').prop('checked', false);
					$("#switch_msg_show").show();
    				$("#switch_msg").html("开始停止BonusCloud-Node程序...");
					bxc_option("stop");
					var tryTime = 60;
					var interval = setInterval(function(){
						console.log('disable', tryTime, dbus_read('bxc_status'));
						tryTime--;
						if(dbus_read("bxc_status") == "stoped"){
							$("#switch_msg").html("BonusCloud-Node成功退出，退出后需等待1分钟后才能重新启动");
						} else if (!tryTime) {
							$('#switch').prop('checked', true);
							$('#switch').prop('disabled', false);
							$("#switch_msg").html("BonusCloud-Node 退出失败。");
							clearInterval(interval);
	    					//$("#switch_msg_show").hide();
						}
						if (!tryTime) {
							$("#switch_msg_show").hide();
							$('#switch').prop('disabled', false);
							clearInterval(interval);
						}
					}, 1000);
				}
			}

			function bxc_switch_onboot() {
				if(E("bxc_start_onboot")[0].selected){
					bxc_option("booton");
				} else {
					bxc_option("bootoff");
				}
			}

			function bxc_switch_log() {
				if(E("bxc_log")[0].selected){
					bxc_option("errorlog");
				} else {
					bxc_option("debuglog");
				}
			}


			function bxc_bound_log() {
				if(E("bound_log")[0].selected){
					bxc_option("errorlog");
				} else {
					bxc_option("debuglog");
				}
			}

			function bxc_switch_interval() {
				status_check_interval = E("status_interval").value * 1000;
			}

			/* 版本检查以及更新 */
			function bxc_version_check() {
				var local_version = dbus_read("bxc_local_version");

				$.ajax({
			        url: 'https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/aarch32-merlin/bxc/bxc/version',
			        type: 'GET',
			        success: function(res) {
			        	if(res) {
			        		if(local_version === res) {
			    				alert("当前版本："+local_version+" 已是最新版本，不需要更新。");
			    			} else {
			    				var r = confirm("最新版本："+res+", 确定进行更新吗？");
		    					if (r) {
			    					bxc_update();
			    				}
			 				}
			 			}
			        }
			    });
			}

			function bxc_update(){
	    		bxc_option("update");
	    		showLoading(40);
				setTimeout(function() {
					location.reload();
				}, 40000);
			}

			function dbus_write(key, value) {
				var data = {};
				data[key] = value;
				$.ajax({
					url: "/applydb.cgi?p=bxc_",
					type: "POST",
					data: data,
				});
			}

			function dbus_read(key=""){
				$.ajax({
					url: "/dbconf?p=bxc_",
					type: "GET",
					dataType: "script",
				})
				if (key == "") {
					bxc_db = db_bxc_;
					return bxc_db;
				} else if (typeof(db_bxc_[key] !== "undefined")) {
					return db_bxc_[key];
				} else {
					return "";
				}
			}

			function bxc_bound_msg(msg) {
				$('#bound_msg').html('<h4><font color="#FF9900">【提示】</font></h4><p>'+msg+'</p><p>您可以前往<a href="http://bonuscloud.io"><u><em>BonusCloud</em></u></a>获取BCode，进行设备绑定！</p>');
				E("bound_warning").style.display = "";
			}

			function get_log(refresh) {
				$.ajax({
					url: '/res/bxc_run.htm',
					type: 'GET',
					dataType: 'html',
					success: function(response) {
						var retArea = E("log_content1");
						if (response.search("XU6J03M6") != -1) {
							retArea.value = response.replace("XU6J03M6", " ");
							retArea.scrollTop = retArea.scrollHeight;
							if(refresh == "1"){
								refreshpage(2);
							}
							return true;
						}
						if (_responseLen == response.length) {
							noChange++;
						} else {
							noChange = 0;
						}
						if (noChange > 1000) {
							return false;
						} else {
							setTimeout("get_log(1);", 3000);
						}
						retArea.value = response.replace("XU6J03M6", " ");
						retArea.scrollTop = retArea.scrollHeight;
						_responseLen = response.length;
					}
				});
			}


			function reload_Soft_Center() {
				location.href = "/Main_Soft_center.asp";
			}
        </script>
    </head>
    <body onload="init();">
		<div id="TopBanner"></div>
		<div id="Loading" class="popup_bg"></div>
		<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
		<div>
			<input type="hidden" name="current_page" value="Module_bxc.asp"/>
			<input type="hidden" name="next_page" value="Module_bxc.asp"/>
			<input type="hidden" name="group_id" value=""/>
			<input type="hidden" name="modified" value="0"/>
			<input type="hidden" name="action_mode" value=""/>
			<input type="hidden" name="action_script" value=""/>
			<input type="hidden" name="action_wait" value="5"/>
			<input type="hidden" name="first_time" value=""/>
			<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>"/>
			<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>"/>

			<table class="content" align="center" cellpadding="0" cellspacing="0">
				<tr>
					<td width="17">&nbsp;</td>
					<td valign="top" width="202">
						<div id="mainMenu"></div>
						<div id="subMenu"></div>
					</td>
					<td valign="top">
						<div id="tabMenu" class="submenuBlock"></div>
						<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
							<tr>
								<td align="left" valign="top">
									<table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
										<tr>
											<td bgcolor="#4D595D" colspan="3" valign="top">
												<div>&nbsp;</div>
												<div style="float:left;" class="formfonttitle">BonusCloud-Node</div>
												<div style="float:right; width:15px; height:25px;margin-top:10px"><img id="return_btn" onclick="reload_Soft_Center();" align="right" style="cursor:pointer;position:absolute;margin-left:-30px;margin-top:-25px;" title="返回软件中心" src="/images/backprev.png" onMouseOver="this.src='/images/backprevclick.png'" onMouseOut="this.src='/images/backprev.png'"></img></div>
												<div style="margin-left:5px;margin-top:10px;margin-bottom:10px"><img src="/images/New_ui/export/line_export.png"></div>
												<br/>										
												<div id="tablets">
													<table style="margin:10px 0px 0px 0px;border-collapse:collapse" width="100%" height="37px">
														<tr width="235px">
															<td colspan="4" cellpadding="0" cellspacing="0" style="padding:0" border="1" bordercolor="#000">
																<input id="show_btn1" class="show-btn1" style="cursor:pointer" type="button" value="节点管理" />
																<input id="show_btn2" class="show-btn2" style="cursor:pointer" type="button" value="日志信息" />
															</td>
														</tr>
													</table>
												</div>
												<div id="tablet_1">
													<div id="bxc_bound" style="display: ''">
														<div id="bound_warning" style="display: none;background-color:#445053">
									 						<div id="bound_msg" style="padding:10px;width:95%;font-size:12px;">
									 						</div>
									 					</div>
														<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="bxc_detail_table">
															<thead>
															<tr>
																<td colspan="2">绑定BCode</td>
															</tr>
															</thead>
															<tr>
																<th width="35%">WAN网卡MAC地址</th>
																<td>
																	<a>
																		<span id="bound_mac">未知</span>
																	</a>
																</td>
															</tr>
															<tr>
																<th width="35%">BCode</th>
																<td>
																	<input  class="input_ss_table" style="width:auto;" size="40"  id="bxc_bcode" placeholder="请输入BCode"/>
																</td>
															</tr>
															<tr>
																<th width="35%">用户账号</th>
																<td>
																	<input  class="input_ss_table" style="width:auto;" size="40"  id="user_email" placeholder="请输入用户邮箱"/>
																</td>
															</tr>
															<tr>
															    <th width="35%">日志打印</th>
																<td>
																	<select id="bound_log" name="bound_log" class="input_option" onchange="bxc_bound_log()" >
																		<option value="1">ERROR</option>
																		<option value="0">DEBUG</option>
																	</select>
																</td>
															</tr>
				 										</table>
				 										<div class="apply_gen">
															<input type="button" class="button_gen" id="boundBtn" onclick="bxc_bound_bcode();" value="绑定设备" />
														</div>
														<!-- </form> -->
													</div>
													<div id="bxc_status" style="display: none;">
														<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="routing_table">
															<thead>
															<tr>
																<td colspan="2">服务管理</td>
															</tr>
															</thead>
															<tr>
																<th>运行控制</th>
																<td colspan="2">
																	<div class="switch_field" style="display:table-cell;float: left;">
																		<label for="switch">
																			<input id="switch" class="switch" type="checkbox" style="display: none;" onclick="bxc_switch_status();">
																			<div class="switch_container" >
																				<div class="switch_bar"></div>
																				<div class="switch_circle transition_style">
																					<div></div>
																				</div>
																			</div>
																		</label>
																	</div>
																	<a id="switch_msg_show" style="display: none;line-height: 32px">
																		<span id="switch_msg"></span>
																	</a>
																</td>
															</tr>
															<tr>
															    <th width="20%">运行状态</th>
																<td>
																	<a href="javascript:void(0);">
																		<span id="status_msg"></span>
																	</a>
																	<a style="line-height: 32px;" href="javascript:void(0);" title="运行状态更新会有延迟，取决于检测间隔">[说明]</a>
																</td>
															</tr>
															<tr>
															    <th width="20%">检测间隔</th>
																<td>
																	<select id="status_interval" name="status_interval" class="input_option" onchange="bxc_switch_interval()" >
																		<option value="3">3</option>
																		<option value="5" selected="selected">5</option>
																		<option value="10">10</option>
																		<option value="30">30</option>
																		<option value="60">60</option>
																	</select>
																	<a style="line-height: 32px">秒</a>
																</td>
															</tr>
															<thead>
																<tr>
																	<td colspan="2">节点信息</td>
																</tr>
															</thead>
															<tr>
															    <th width="20%">版本更新</th>
																<td>
																	<a style="line-height: 32px">
																		<span>当前版本：<span id="current_version">未知</span></span>
																	</a>
																	<button class="button_gen" style="float: right;" onclick="bxc_version_check()">检查更新</button>
																</td>
															</tr>
															<tr>
															    <th width="20%">用户邮箱</th>
																<td>
																	<a>
																		<span id="bxc_user_mail" >未知</span>
																	</a>
																</td>
															</tr>
															<tr>
															    <th width="20%">已绑定BCode</th>
																<td>
																	<a>
																		<span id="bxc_bcode_show" >未知</span>
																	</a>
																</td>
															</tr>
															<tr>
																<th width="35%">WAN网卡MAC地址</th>
																<td>
																	<a>
																		<span id="status_mac">未知</span>
																	</a>
																</td>
															</tr>
															<thead>
															<tr>
																<td colspan="4">运行设置</td>
															</tr>
															</thead>
															<tr>
															    <th width="35%">开机自启</th>
																<td>
																	<select id="bxc_start_onboot" name="bxc_start_onboot" class="input_option" onchange="bxc_switch_onboot()" >
																		<option value="1">是</option>
																		<option value="0">否</option>
																	</select>
																</td>
															</tr>
															<tr>
															    <th width="35%">日志打印</th>
																<td>
																	<select id="bxc_log" name="bxc_log" class="input_option" onchange="bxc_switch_log()" >
																		<option value="1">ERROR</option>
																		<option value="0">DEBUG</option>
																	</select>
																</td>
															</tr>
				 										</table>
													</div>
												</div>
												
<!-- 												<div id="tablet_2" style="display: none;">
													<br/>
													<table id="online_table" border="1" width="100%" style="display: none;">
														<thead>
															<tr>
																<th width="40%">BCode</th>
																<th width="20%">网络在线（分钟）</th>
																<th width="20%">任务分数</th>
																<th width="20%">时间段（小时）</th>
															</tr>
														</thead>
														<tbody id="online_tbody">
														</tbody>
													</table>
													<div id="online_msg" style="display: none;background-color:#445053;padding:10px;width:95%;font-size:12px;">
									 					<h4><font color="#FF9900">【提示】</font></h4><p>该设备尚未绑定BCode！</p><p>您可以前往<a href="http://bonuscloud.io"><u><em>BonusCloud</em></u></a>获取BCode，进行设备绑定！</p>
									 				</div>
												</div> -->

												<div id="tablet_2" style="display: none;">
													<br/>
													<div id="log_content" style="margin-top:-1px;display:block;overflow:hidden;outline: 1px solid #222;">
														<textarea cols="63" rows="36" wrap="on" readonly="readonly" id="log_content1" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false"></textarea>
													</div>
												</div>

												<div style="margin-left:5px;margin-top:10px;margin-bottom:10px"><img src="/images/New_ui/export/line_export.png"></div>
												<div class="KoolshareBottom">
													<br/>论坛技术支持： <a href="http://www.koolshare.cn" target="_blank"> <i><u>www.koolshare.cn</u></i> </a> <br/>
													后台技术支持： <i>Xiaobao</i> <br/>
													Shell, Web by： <i>wangchll</i><br/>
												</div>
											</td>
										</tr>
									</table>
								</td>
								<td width="10" align="center" valign="top"></td>
							</tr>
						</table>
					</td>
				</tr>
			</table>
		</div>
		<div id="footer"></div>
    </body>
</html>
