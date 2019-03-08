module(...,package.seeall)
--require"webRequest"
require"http"
require"common"
require"Sensors"

local ssub,schar,smatch,sbyte,slen = string.sub,string.char,string.match,string.byte,string.len
--local ADDR,leweiUrl,PORT ="114.55.54.60","http://ug25.lewei50.com/api/V1/gateway/UpdateSensors/",9970
local ADDR,leweiUrl,PORT ="ug25.lewei50.com","http://ug25.lewei50.com/api/V1/gateway/UpdateSensors/",80
local httpclient

local showQRCode = false
local bIsPms5003 = false
local bIsPms5003s = false
local aqi,pm25,hcho,co2 = nil

local bRefreshLcd = false

local validDev = false 

--发送时功耗较高，此时采样值忽略
local bSending = false

--0 data post,1 qrcode request,2 binding request,3 postion update,4 iccid update
local requestType = 0

--串口ID,1对应uart1
--如果要修改为uart2，把UART_ID赋值为2即可
local UART_ID = 1
--串口读到的数据缓冲区
local rdbuf = ""
local rdbuf1 = ""
local rdbuf2 = ""

--0 DS_HCHO,1 SenseAir S8
local uart1SensorId = 0
local uart1SensorNum = 2

local lat,lng

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上run前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("[run]",...)
end

function setRequestType(id)
	print("set requestType:"..requestType)
	requestType = id
end

local function changeUart1SensorId()
	uart1SensorId = uart1SensorId +1
	uart1SensorId = uart1SensorId %uart1SensorNum
end


local function DS_HCHO_Data_request()
	uart.write(UART_ID,string.char(0x42)..string.char(0x4d)..string.char(0x01)..string.char(0x00)..string.char(0x00)..string.char(0x00)..string.char(0x90))
	--sys.timer_start(changeUart1SensorId,2000)
	--Ports.nextPort()
	sys.timer_start(Ports.nextPort,300)
	sys.timer_start(portCycle,300)
end

local function SENSEAIR_S8_Data_request()
	uart.write(UART_ID,string.char(0xfe)..string.char(0x04)..string.char(0x00)..string.char(0x03)..string.char(0x00)..string.char(0x01)..string.char(0xd5)..string.char(0xc5))
	sys.timer_start(DS_HCHO_Data_request,300)
end


function portCycle()
	--print("PORT:"..Ports.getPort())
	t = si7021.getTemp()
	h = si7021.getHum()
	--print("statusChk:",t,h)
	if(h~=nil and t~=nil)then
		if(bSending == false)then
          if(Sensors.setSensorValue("Temp",t,"℃")) then bRefreshLcd = true end
          if(Sensors.setSensorValue("Hum",h,"%")) then bRefreshLcd = true end
    end
  end
	if(Ports.getPort()==0)then
          --refresh lcd
          if(bRefreshLcd)then
               --Lcd.showPage(1)
               lcd.refreshPage()
               bRefreshLcd = false
               --Ports.nextPort()
          end
  end
  sys.timer_start(SENSEAIR_S8_Data_request,1000)
end

local function UART1_Data_request()
	--print("uart1SensorId:"..uart1SensorId)
	if(uart1SensorId == 0) then
		DS_HCHO_Data_request()
	elseif(uart1SensorId == 1)then
		SENSEAIR_S8_Data_request()
	end
end


local function calcAQI(pNum)
     --local clow = {0,15.5,40.5,65.5,150.5,250.5,350.5}
     --local chigh = {15.4,40.4,65.4,150.4,250.4,350.4,500.4}
     --local ilow = {0,51,101,151,201,301,401}
     --local ihigh = {50,100,150,200,300,400,500}
     local ipm25 = {0,35,75,115,150,250,350,500}
     local laqi = {0,50,100,150,200,300,400,500}
     local result={"优","良","轻度污染","中度污染","重度污染","严重污染","爆表"}
     --print(table.getn(chigh))
     aqiLevel = 8
     for i = 1,table.getn(ipm25),1 do
          if(pNum<ipm25[i])then
               aqiLevel = i
               break
          end
     end
     --aqiNum = (ihigh[aqiLevel]-ilow[aqiLevel])/(chigh[aqiLevel]-clow[aqiLevel])*(pNum-clow[aqiLevel])+ilow[aqiLevel]
     aqiNum = (laqi[aqiLevel]-laqi[aqiLevel-1])*100/(ipm25[aqiLevel]-ipm25[aqiLevel-1])*(pNum-ipm25[aqiLevel-1])/100+laqi[aqiLevel-1]
     return aqiNum,result[aqiLevel-1]
end

--[[
函数名：parse
功能  ：按照帧结构解析处理数据
参数  ：
		data：所有未处理的数据
]]

local function parse2(data)
	--print("parse2")
	if not data then return end	
	if((((string.byte(data,1)==0x42) and(string.byte(data,2)==0x4d)) or ((string.byte(data,1)==0x32) and(string.byte(data,2)==0x3d))) and string.byte(data,13)~=nil and string.byte(data,14)~=nil)  then
          if((string.byte(data,1)==0x32) and(string.byte(data,2)==0x3d)) then
               --Teetc.com
               pm25 = (string.byte(data,7)*256+string.byte(data,8))
          else
               pm25 = (string.byte(data,13)*256+string.byte(data,14))
               if(string.byte(data,29) ~=nil and string.byte(data,30)~=nil)then
                    if(string.byte(data,29) > 0x50 and string.byte(data,30) == 0x00)then
                         hcho = nil
                         bIsPms5003 = true
                         bIsPms5003s = false
                    else
                         bIsPms5003 = false
                         bIsPms5003s = true
                         --if(lcd.getCurrentPage()~=4) then
                         	--lcd.setPage(4)
                         --end
                         hcho_orig = (string.byte(data,29)*256+string.byte(data,30))
                         hcho = hcho_orig/1000 .."."..tostring(hcho_orig%1000/100) ..tostring(hcho_orig%100/10)
                         if(hcho~=nil)then
					                    --lcd.setText("HCHO",hcho.."mg/m3")
					                    if(bSending == false)then
					                    	if(Sensors.setSensorValue("HCHO",hcho,"mg/m3")) then bRefreshLcd = true end
					                    end
					               end
                         hcho = hcho_orig/1000 .."."..tostring(hcho_orig%1000/100) ..tostring(hcho_orig%100/10) ..tostring(hcho_orig%10)
                    end
               end
          end
          aqi,result = calcAQI(pm25)
					--lcd.setText("pm25",pm25..result)
					if(bSending == false)then
						if(Sensors.setSensorValue("pm25",pm25,result)) then bRefreshLcd = true end
						--lcd.setText("aqi",aqi)
						if(Sensors.setSensorValue("aqi",aqi,"")) then bRefreshLcd = true end
					end
     end
	--HH-HCHO-M sensor decode / Dart HCHO
	if(((string.byte(data,1)==0xff) and(string.byte(data,2)==0x17))) then
		if(string.byte(data,5) == nil or string.byte(data,6) == nil)then return end
		hcho_orig = (string.byte(data,5)*256+string.byte(data,6))
		hcho = hcho_orig/1000 .."."..tostring(hcho_orig%1000/100) ..tostring(hcho_orig%100/10)
		if(hcho~=nil)then
			--if(co2~=nil)then
				--if(lcd.getCurrentPage()~=6) then
					--lcd.setPage(6)
				--end
			--else
				--if(lcd.getCurrentPage()~=4) then
					--lcd.setPage(4)
				--end
			--end
			--lcd.setText("HCHO",hcho.."mg/m3")
			if(bSending == false)then
				if(Sensors.setSensorValue("HCHO",hcho,"mg/m3")) then bRefreshLcd = true end
			end
		end
		--get more accurate date to lewei end
		hcho = hcho_orig/1000 .."."..tostring(hcho_orig%1000/100) ..tostring(hcho_orig%100/10)..tostring(hcho_orig%10)
		--print("HCHO:"..hcho)
	end
	rdbuf2 = ""
end


local function parse1(data)
	--print("parse1"..common.binstohexs(data))
	--sys.timer_stop(changeUart1SensorId)
	--DS HCHO sensor decode (from uart1)
	if((string.byte(data,1)==0x42) and(string.byte(data,2)==0x4d) and(string.byte(data,3)==0x08) and(string.byte(data,4)==0x14)) then
		unit_byte = string.byte(data,5)
		rate_byte = string.byte(data,6)
		data_byte_h = string.byte(data,7)
		data_byte_l = string.byte(data,8)
		if(unit_byte==1) then
			unit = "ppm"
		elseif(unit_byte == 2) then
			unit = "VOL"
		elseif(unit_byte == 3) then
			unit = "LEL"
		elseif(unit_byte == 4) then
			unit = "ppb"
		elseif(unit_byte == 5) then
			unit = "mg/m3"
		end
		
		if(rate_byte==1) then
			rate = 1
		elseif(rate_byte == 2) then
			rate = 10
		elseif(rate_byte == 3) then
			rate = 100
		elseif(rate_byte == 4) then
			rate = 1000
		end
		
		--print ("DSHCHO:HIGH:"..data_byte_h.." LOW:"..data_byte_l..unit)
		
		hcho_orig = data_byte_h*256+data_byte_l
		curr_rate = rate
		hcho = ""
		for i = 1,rate_byte,1 do
    	hcho = hcho .. hcho_orig/curr_rate
    	if(i==1)then 
    		hcho = hcho .."." 
    	end
    	hcho_orig = hcho_orig % curr_rate
    	curr_rate = curr_rate /10
    end
    --print("HCHO:"..hcho)
		if(hcho~=nil)then
			--if(lcd.getCurrentPage()~=4) then
				--lcd.setPage(4)
			--end
			--lcd.setText("HCHO",hcho..unit)
			if(bSending == false)then
				if(Sensors.setSensorValue("HCHO",hcho,unit)) then bRefreshLcd = true end
			end
		end
		
	end
	
	--SenseAir S8 decode
	if((string.byte(data,1)==0xfe) and(string.byte(data,2)==0x04) and(string.byte(data,3)==0x02)) then
		data_byte_h = string.byte(data,4)
		data_byte_l = string.byte(data,5)
		
		co2 = data_byte_h*256+data_byte_l
		--print("CO2:"..co2)
		if(co2~=nil)then
			--if(hcho~=nil)then
				--if(lcd.getCurrentPage()~=6) then
					--lcd.setPage(6)
				--end
			--else
				--if(lcd.getCurrentPage()~=5) then
					--lcd.setPage(5)
				--end
			--end
			--lcd.setText("CO2",co2.."ppm")
			if(bSending == false)then
				if(Sensors.setSensorValue("CO2",co2,"ppm")) then bRefreshLcd = true end
			end
		end
	end
	
	
	rdbuf1 = ""
	--测试是否单发送的传感器接到了uart1上
	parse2(data)
end

--[[
函数名：read
功能  ：读取串口接收到的数据
参数  ：无
返回值：无
]]

local function read1()
	local data = ""
	--底层core中，串口收到数据时：
	--如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
	--如果接收缓冲器不为空，则不会通知Lua脚本
	--所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
	while true do		
		data = uart.read(UART_ID,"*l",0)
		if not data or string.len(data) == 0 then break end
		--打开下面的打印会耗时
		--print("read:",string.len(data),common.binstohexs(data))
		rdbuf1 = rdbuf1..data	
	end
	sys.timer_start(parse1,50,rdbuf1)
end


local function read2()
	local data = ""
	--底层core中，串口收到数据时：
	--如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
	--如果接收缓冲器不为空，则不会通知Lua脚本
	--所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
	while true do		
		data = uart.read(2,"*l",0)
		if not data or string.len(data) == 0 then break end
		--打开下面的打印会耗时
		--print("read:",data,common.binstohexs(data))
		rdbuf2 = rdbuf2..data	
	end
	sys.timer_start(parse2,50,rdbuf2)
end




--[[
函数名：write
功能  ：通过串口发送数据
参数  ：
		s：要发送的数据
返回值：无
]]
function write(s)
	--print("write",s)
	uart.write(UART_ID,s.."\r\n")
end

function statusChk()
	lcd.displayTestDot()
	portCycle()
end


--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("run")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("run")后，在不需要串口时调用pm.sleep("run")
pm.wake("run")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
--sys.reguart(UART_ID,read)
--配置并且打开串口
--uart.setup(UART_ID,9600,8,uart.PAR_NONE,uart.STOP_1)


sys.reguart(UART_ID,read1)
--uart.on(UART_ID,"receive",read1)
--配置并且打开串口1
uart.setup(UART_ID,9600,8,uart.PAR_NONE,uart.STOP_1)
--sys.timer_loop_start(UART1_Data_request,5000)

--sys.reguart(2,read2)
--配置并且打开串口2
--uart.setup(2,9600,8,uart.PAR_NONE,uart.STOP_1)

lcd.setInfo("设备初始化中")

sys.timer_start(statusChk,3000)


lcd.setPage(1)

--[[
函数名：rcvcb
功能  ：接收回调函数
参数  ：result：数据接收结果(此参数为0时，后面的几个参数才有意义)
				0:成功
				2:表示实体超出实际实体，错误，不输出实体内容
				3:接收超时
		statuscode：http应答的状态码，string类型或者nil
		head：http应答的头部数据，table类型或者nil
		body：http应答的实体数据，string类型或者nil
返回值：无
]]
local function rcvcb(result,statuscode,head,body)
	--print("rcvcb",result,statuscode,head,slen(body or ""))
	
	if result==0 then
		--if head then
			--print("rcvcb head:")
			--遍历打印出所有头部，键为首部名字，键所对应的值为首部的字段值
			--for k,v in pairs(head) do		
				--print(k..": "..v)
			--end
		--end
		print("requestType:"..requestType)
		print(body)
		
		fbStr = body
		if(nvm.get("qrCode")~=nil) then
			if(requestType == 1) then
				if(string.find(fbStr,"Invalid device ID")~=nil) then
							require"qrcode"
							--disp.puttext("restart after binding",10,28)
							disp.update()
				      --have qrcode file
				      Ports.lockPort(0)
				      lcd.setPage(2)
				      sys.timer_stop(http_run)
				      sys.timer_stop(statusChk)
				      lcd.setPage(2)
				      lcd.qrCodeDisp(nvm.get("qrCode"),tonumber(nvm.get("qrLength")))
				      --lcd.setText("info","绑定完成后,手工重启设备")
				      lcd.setText("info","IMEI:"..misc.getimei())
				      lcd.disableRefresh()
				elseif(string.find(fbStr,"typeName")~=nil) then
				      print("set device name ok")
				      validDev = true
				      Ports.unlock()
				      nameStr = string.match(fbStr,"\"name\":\".+\"typeName\":\"lw%-board")
				      if(nameStr ~= nil)then
					      dName = string.sub(nameStr,9,-23)
			          lcd.setText("info","")
			          if(dName ~= nil) then
			          		 lcd.setDevName(dName)
			               lcd.setText("deviceName",dName)
			               lcd.oledShow(" ",dName)
			          end
			        end
			        sys.timer_loop_start(getIccid,30000)
			  else
					lcd.oledShow(" ","QRCODE MISSING")
			  end
			elseif(requestType == 4) then
				if(string.find(fbStr,"\"Successful\":true")~=nil) then
					sys.timer_stop(getIccid)
					if(config.bEnableLocate == true) then
						print("update location in 30s later")
						sys.timer_loop_start(updateLoc,30000)
					else
						setRequestType(0)
					end
					print("stop getIccid timer")
				end
				sys.timer_stop_all(http_run)
			  sys.timer_loop_start(http_run,120000)
			elseif(requestType == 3) then
				setRequestType(0)
			end
		else
			if(string.find(fbStr,"Invalid SN")~=nil) then
			    lcd.setText("info","无效二维码")
					lcd.oledShow(" ","Invalid SN")
			else
			    qrCode = string.sub(string.match(fbStr,"QRCode\":\"%w+\""),10,-2)
			    qrCodeUrl = string.sub(string.match(fbStr,"QRCodeUrl\":\"[%w%d:\/.]+\""),13,-2)
			    qrLength = string.sub(string.match(fbStr,"QRLength\":%d+"),11,-1)
			    lcd.setText("info","校验二维码..")
			    print("qrCodeUrl:"..qrCodeUrl)
			    nvm.set("qrCode",qrCode)
			    nvm.set("qrCodeUrl",qrCodeUrl)
			    nvm.set("qrLength",qrLength)
			    nvm.flush()
			    lcd.setText("info","获取成功.")
					lcd.oledShow(" ","Got QRCODE!")
			    sys.restart("Got QRCode")
			end
		end
	end
	
	httpclient:disconnect(discb)
end

--[[
函数名：sckerrcb
功能  ：SOCKET失败回调函数
参数  ：
		r：string类型，失败原因值
		CONNECT: socket一直连接失败，不再尝试自动重连
返回值：无
]]
local function sckerrcb(r)
	print("sckerrcb",r)
end

--[[
函数名：connectedcb
功能  ：SOCKET connected 成功回调函数
参数  ：
返回值：
]]
local function connectedcb()
	--[[调用此函数才会发送报文,request(cmdtyp,url,head,body,rcvcb),回调函数rcvcb(result,statuscode,head,body)
		url就是路径，例："/XXX/XXXX"，head为表的形式，例：{"Connection: keep-alive","Content-Type: text/html; charset=utf-8"}，注意:后面
		需加一个空格。body就是需要传的数据，为字符串类型。
	]]
	--定义数据变量格式
	print("requestType"..requestType)
	if(validDev == false) then
		if(nvm.get("qrCode")~=nil) then
			setRequestType(1)
			Ports.lockPort(0)
			httpclient:request("GET","/api/v1/device/getbysn/"..misc.getimei().."?encode=gbk",{"Connection: close"},"",rcvcb)
	    lcd.setText("info","检查绑定状态...") 
			lcd.oledShow(" ","Check Binding")
		else
			setRequestType(2)
			Ports.lockPort(0)
			httpclient:request("GET","/api/v1/sn/info/"..misc.getimei().."?type=hex",{"Connection: close"},"",rcvcb)
			lcd.setText("info","获取二维码")
			lcd.oledShow(" ","Request QRCODE")
		end
	end
	
	if(validDev==true)then
		if(requestType == 0) then
			PostData = "["
			for i,v in pairs(Sensors.data()) do 
			    --convert more device id here
			    if(i=="Hum")then i = "H1" end
			    if(i=="Temp")then i = "T1" end
		      if(i=="pm25")then i = "dust" end
			    PostData = PostData .. "{\"Name\":\""..i.."\",\"Value\":\"" .. v .. "\"},"
			end
			
			PostData = string.sub(PostData,1,-2) .. "]"
			httpclient:request("POST","/api/V1/gateway/UpdateSensorsBySN/"..misc.getimei(),{"Connection: close"},PostData,rcvcb)
		elseif(requestType == 3) then
			if( lat ~= nil and lng ~= nil) then
				httpclient:request("POST","/api/v1/gateway/updatebysn/"..misc.getimei(),{"Connection: close"},"{\"position\":\""..lng..","..lat.."\"}",rcvcb)
			else
				print("can't get postion,try next time")
			end
			setRequestType(0)
			sys.timer_start(updateLoc,3600000)
		end
	end
	PostData = ""
end 

--[[
函数名：connect
功能：连接服务器
参数：
	 connectedcb:连接成功回调函数
	 sckerrcb：http lib中socket一直重连失败时，不会自动重启软件，而是调用sckerrcb函数
返回：
]]
local function connect()
	if(httpclient) then
		bSending = true
		httpclient:connect(connectedcb,sckerrcb)
		print("Sending start")
	else
		print("no httpclient exist,checking network or sim card")
	end
end
--[[
函数名：discb
功能  ：HTTP连接断开后的回调
参数  ：无		
返回值：无
]]
function discb()
	print("http discb")
	bSending = false
	print("Sending stop")
end

function http_run()
print("http_run")
	--因为http协议必须基于“TCP”协议，所以不必传入PROT参数
	if(httpclient==nil)then
		httpclient=http.create(ADDR,PORT)
	end
	--httpclient:setconnectionmode(true)
	--建立http连接
	connect()	
end



if(nvm.get("qrCode")~=nil)then
_G.print("qrCode = "..nvm.get("qrCode"))
_G.print("qrLength = "..nvm.get("qrLength"))
else
	--get qrCode
	--sys.timer_stop(statusChk)
	
end

Ports.openPort(0)


sys.timer_start(http_run,5000)

function updateLoc()
	setRequestType(3)
	lat,lng = locator.getLocation()
end

function getIccid()
	iccid = sim.geticcid()
	if(iccid) then
		setRequestType(4)
		print("sending iccid to server")
		httpclient:request("POST","/api/v1/gateway/updatebysn/"..misc.getimei(),{"Connection: close"},"{\"iccid\":\""..iccid.."\"}",rcvcb)
		lcd.setInfo(iccid)
	end
end

function getAM2302()
	--log.info("------i2cDemo代码正在运行-------")
	local temp, hum = AM2320.read(2, 0x5c)
	if not temp then temp, hum = 250, 300 end
	t = temp / 10 .. "." .. temp % 10
	h = hum / 10 .. "." .. hum % 10
	--msg.ext.temp = temp
	--msg.ext.hum = hum
	--log.info("hmi ambient temperature and humidity:", temp, hum)
	--local c = misc.getClock()
	--local date = string.format('%04d年%02d月%02d日', c.year, c.month, c.day)
	--lcd.oledShow("date", "Temp:" .. t, "Humi:" .. h, "LuatBoard-Air202")
	if(h~=nil and t~=nil)then
		if(bSending == false)then
          if(Sensors.setSensorValue("Temp",t,"℃")) then bRefreshLcd = true end
          if(Sensors.setSensorValue("Hum",h,"%")) then bRefreshLcd = true end
    end
  end
end
--sys.timer_loop_start(getAM2302,5000)
mono_i2c_ssd1306.init(0xFFFF)
lcd.oledShow(" ","WWW.LEWEI50.COM")
--[[
sys.timerLoopStart(getAM2302,5000)

sys.taskInit(function()
    if i2c.setup(2, i2c.SLOW) ~= i2c.SLOW then
        log.error("I2C.init is: ", "fail")
    end
    mono_i2c_ssd1306.init(0xFFFF)
end)
]]--