<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		<meta HTTP-EQUIV="Pragma" CONTENT="no-cache"/>
		<meta HTTP-EQUIV="Expires" CONTENT="-1"/>
		<link rel="shortcut icon" href="images/favicon.png"/>
		<link rel="icon" href="images/favicon.png"/>
		<title>软件中心 - BxC-Node设置</title>
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
        <script type="text/javascript">
			function init() {
				show_menu();
				init_show();
			}

			function init_show() {
				var bxc_bcode = dbus_read("bxc_bcode");
				if (typeof(bxc_bcode) != 'undefined' && bxc_bcode != '') {
					/* 邀请码已经存在 */
					document.getElementById("bxc_bound").style.display = "none";
					document.getElementById("bxc_status").style.display = "";
					bxc_show_status();
				} else {
					/* 邀请码不存在 */
					document.getElementById("bxc_bound").style.display = "";
					document.getElementById("bxc_status").style.display = "none";
				}
			}

			function bxc_bound_bcode() {
				var bcode = $("#bxc_bcode").val();
				if (typeof(bcode) == 'undefined' || bcode == "") {
					bxc_bound_msg('请输入邀请码！');
				} else if (!bcode_islegal(bcode)) {
					bxc_bound_msg('邀请码<font color="#FF9900">"'+bcode+'"</font>格式不正确');
				} else {
					bound_bcode(bcode);
				}
			}

			function bcode_islegal(bcode) {
				/* 判断邀请码的内容合法性 */
				var pattern = RegExp("^[A-z0-9]{8}-[A-z0-9]{4}-[A-z0-9]{4}-[A-z0-9]{4}-[A-z0-9]{12}$");
				return pattern.test(bcode);
			}

			function bound_bcode(bcode) {
				/* 根据邀请码和设备WAN口MAC地址向服务端进行绑定，并将邀请码写入DBUS */
				var wan_mac = dbus_read("bxc_wan_mac");
				dbus_write("bxc_input_bcode", bcode);
				dbus_write("bxc_bound_status", "init");
				bxc_option("bound");
				bxc_bound_msg("校验通过，正在申请绑定...");
				var tryTime = 8;
				var interval = setInterval(function(){
					console.log('bound', tryTime, dbus_read('bxc_bound_status'));
					tryTime--;
					if(dbus_read("bxc_bound_status") == "success"){
    					bxc_bound_msg("绑定成功，页面自动刷新！");
						clearInterval(interval);
						//location.reload();
						document.getElementById("bxc_bound").style.display = "none";
						document.getElementById("bxc_status").style.display = "";
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
				var	bxc_status = dbus_read("bxc_status");
				if (bxc_status == "running") {
					document.getElementById("switch").checked=true;
					$("#status_msg").html("BxC-Node已启动，正在BxC网络挖矿中...")
				} else {
					document.getElementById("switch").checked=false;
					$("#status_msg").html("BxC-Node 没有启用！")
				}

				var bxc_bcode = dbus_read("bxc_bcode");
				if (bxc_bcode != "") {
					document.getElementById("bxc_bcode_show").innerHTML = bxc_bcode;
				}

				var	bxc_onboot = dbus_read("bxc_onboot");
				if (bxc_onboot == "yes") {
					document.getElementById("bxc_start_onboot")[0].selected=true;
				} else {
					document.getElementById("bxc_start_onboot")[1].selected=true;
				}

				// 一直检测BxC-Node运行情况
				var intervalCheck = setInterval(function(){
					console.log('bxc_check', dbus_read('bxc_status'));
					bxc_option("status")
					if(dbus_read("bxc_status") == "running"){
    					$("#status_msg").html("BxC-Node已启动，正在BxC网络挖矿中...");
					} else{
    					$("#status_msg").html("BxC-Node 没有启用！");
					}
				}, 4000);
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
				if(document.getElementById("switch").checked){
					$('#switch').prop('checked', true);
					$("#switch_msg_show").show();
    				$("#switch_msg").html("BxC-Node 开始启动...");
					bxc_option("start");
					var tryTime = 20;
					var interval = setInterval(function(){
						console.log('enable', tryTime, dbus_read('bxc_status'));
						tryTime--;
						if(dbus_read("bxc_status") == "running"){
	    					//$("#switch_msg").html("BxC-Node启动成功，进入BxC网络开始挖矿...");
	    					$("#switch_msg_show").hide();
							$('#switch').prop('disabled', false);
							clearInterval(interval);
						} else if (!tryTime) {
							$('#switch').prop('checked', false);
							$('#switch').prop('disabled', false);
	    					//$("#switch_msg").html("BxC-Node 启动失败。");
	    					$("#switch_msg_show").hide();
						}
						if (!tryTime) {
							clearInterval(interval);
						}
					}, 1000);
				} else {
					$('#switch').prop('checked', false);
					$("#switch_msg_show").show();
    				$("#switch_msg").html("开始停止BxC-Node程序...");
					bxc_option("stop");
					var tryTime = 60;
					var interval = setInterval(function(){
						console.log('disable', tryTime, dbus_read('bxc_status'));
						tryTime--;
						if(dbus_read("bxc_status") == "stoped"){
							$("#switch_msg").html("BxC-Node成功退出，退出后需等待1分钟后才能重新启动");
	    					//$("#switch_msg_show").hide();
							//$('#switch').prop('disabled', false);
							//clearInterval(interval);
						} else if (!tryTime) {
							$('#switch').prop('checked', true);
							$('#switch').prop('disabled', false);
							$("#switch_msg").html("BxC-Node 退出失败。");
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
				if(document.getElementById("bxc_start_onboot")[0].selected){
					bxc_option("booton");
				} else {
					bxc_option("bootoff");
				}
			}

			/* 版本检查以及更新 */
			function bxc_version_check() {
				var local_version = dbus_read("bxc_local_version");

				$.ajax({
			        url: 'https://raw.githubusercontent.com/BonusCloud/BonusCloud-Node/master/bxc/bxc/version',
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
	    		showLoading(25);
				setTimeout(function() {
					location.reload();
				}, 25000);
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

			function dbus_read(key){
				$.ajax({
					url: "/dbconf?p=bxc_",
					type: "GET",
					dataType: "script",
				})
				if(typeof(db_bxc_[key] !== "undefined")) {
					return db_bxc_[key]
				} else {
					return
				}
			}

			function bxc_bound_msg(msg) {
				$('#bound_msg').html('<h4><font color="#FF9900">【提示】</font></h4><p>'+msg+'</p><p>您可以前往<a href="http://bonuscloud.io"><u><em>BonusCloud</em></u></a>获取邀请码，进行设备绑定！</p>');
				document.getElementById("bound_warning").style.display = "";
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
		<!-- <form method="post" name="form" target="hidden_frame"> -->
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
												<div style="float:left;" class="formfonttitle">BxC Node</div>
												<div style="float:right; width:15px; height:25px;margin-top:10px"><img id="return_btn" onclick="reload_Soft_Center();" align="right" style="cursor:pointer;position:absolute;margin-left:-30px;margin-top:-25px;" title="返回软件中心" src="/images/backprev.png" onMouseOver="this.src='/images/backprevclick.png'" onMouseOut="this.src='/images/backprev.png'"></img></div>
												<div style="margin-left:5px;margin-top:10px;margin-bottom:10px"><img src="/images/New_ui/export/line_export.png"></div>
												<div class="formfontdesc" style="padding-top:5px;margin-top:0px;float: left;">
													<li>
														<i>说明：</i>
														本插件是以<a href="http://bonuscloud.io" target="_blank"><em><u>BxC币</u></em></a>为回报的网络闲置资源共享工具。设备通过<a href="http://bonuscloud.io" target="_blank"><em><u>邀请码</u></em></a>进行绑定后，即可开启挖矿模式
													</li>
												</div>
												<br/>											
												<br/>											

												<div id="bxc_bound" style="display: ''">
													<div id="bound_warning" style="display: none;background-color:#445053">
								 						<div id="bound_msg" style="padding:10px;width:95%;font-size:12px;">
								 						</div>
								 					</div>
													<table style="margin:10px 0px 0px 0px;" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" id="bxc_detail_table">
														<thead>
														<tr>
															<td colspan="2">绑定邀请码</td>
														</tr>
														</thead>
														<tr>
															<th width="35%">WAN网卡MAC地址</th>
															<td>
																<a>
																	<i><% dbus_get_def("bxc_wan_mac", "未知"); %></i>
																</a>
															</td>
														</tr>
														<tr>
															<th width="35%">邀请码</th>
															<td>
																<input  class="input_ss_table" style="width:auto;" size="40"  id="bxc_bcode" placeholder="请输入邀请码"/>
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
															<td colspan="2">运行控制</td>
														</tr>
														</thead>
														<tr>
															<th>开启挖矿模式</th>
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
																	<i>当前版本：<% dbus_get_def("bxc_local_version", "未知"); %></i>
																</a>
																<button class="button_gen" style="float: right;" onclick="bxc_version_check()">检查更新</button>
															</td>
														</tr>
														<tr>
														    <th width="20%">已绑定邀请码</th>
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
																	<i><% dbus_get_def("bxc_wan_mac", "未知"); %></i>
																</a>
															</td>
														</tr>
														<thead>
														<tr>
															<td colspan="4">启动设置</td>
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
			 										</table>
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
		<!-- </form> -->
		</div>
		<div id="footer"></div>
    </body>
</html>
