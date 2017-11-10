module(...,package.seeall)
require"webRequest"

local showQRCode = false
local bIsPms5003 = false
local bIsPms5003s = false
local aqi,pm25,hcho = nil

--串口ID,1对应uart1
--如果要修改为uart2，把UART_ID赋值为2即可
local UART_ID = 1
--串口读到的数据缓冲区
local rdbuf = ""


--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上run前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("run",...)
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
     aqiNum = (laqi[aqiLevel]-laqi[aqiLevel-1])/(ipm25[aqiLevel]-ipm25[aqiLevel-1])*(pNum-ipm25[aqiLevel-1])+laqi[aqiLevel-1]
     return aqiNum,result[aqiLevel-1]
end

--[[
函数名：parse
功能  ：按照帧结构解析处理数据
参数  ：
		data：所有未处理的数据
]]
local function parse(data)
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
                         if(lcd.getCurrentPage()~=4) then
                         	lcd.setPage(4)
                         end
                         hcho = (string.byte(data,29)*256+string.byte(data,30))/1000
                         if(hcho~=nil)then
								lcd.setText("HCHO",hcho)
						   end
                    end
               end
          end
          aqi,result = calcAQI(pm25)
					lcd.setText("pm25",pm25..result)
					lcd.setText("aqi",aqi)
					
    end
	
	rdbuf = ""
end

--[[
函数名：read
功能  ：读取串口接收到的数据
参数  ：无
返回值：无
]]
local function read()
	local data = ""
	--底层core中，串口收到数据时：
	--如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
	--如果接收缓冲器不为空，则不会通知Lua脚本
	--所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
	while true do		
		data = uart.read(UART_ID,"*l",0)
		if not data or string.len(data) == 0 then break end
		--打开下面的打印会耗时
		--print("read",data,common.binstohexs(data))
		rdbuf = rdbuf..data	
	end
	sys.timer_start(parse,50,rdbuf)
end

--[[
函数名：write
功能  ：通过串口发送数据
参数  ：
		s：要发送的数据
返回值：无
]]
function write(s)
	print("write",s)
	uart.write(UART_ID,s.."\r\n")
end

function statusChk()
	temp = si7021.getTemp()
	hum = si7021.getHum()
	if(temp~=nil and hum~=nil) then
		lcd.setText("temp",temp.."℃")
		lcd.setText("hum",hum.."%")
	end
	lcd.displayTestDot()
end

function dataUpload()
	if(aqi~=nil)then webRequest.appendSensorValue("AQI",aqi) end
	if(pm25~=nil)then webRequest.appendSensorValue("dust",pm25) end
	if(hcho~=nil)then webRequest.appendSensorValue("hcho",hcho) end
	temp = si7021.getTemp()
	hum = si7021.getHum()
	if(temp~=nil and hum~=nil) then
		webRequest.appendSensorValue("T1",temp)
		webRequest.sendSensorValue("H1",hum)
	end
end

--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("run")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("run")后，在不需要串口时调用pm.sleep("run")
pm.wake("run")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
sys.reguart(UART_ID,read)
--配置并且打开串口
uart.setup(UART_ID,9600,8,uart.PAR_NONE,uart.STOP_1)

lcd.setInfo("设备初始化中")

sys.timer_loop_start(statusChk,2000)

sys.timer_loop_start(dataUpload,120000)

lcd.setPage(1)


if(nvm.get("qrCode")~=nil)then
_G.print("qrCode = "..nvm.get("qrCode"))
_G.print("qrLength = "..nvm.get("qrLength"))
else
	--get qrCode
	--sys.timer_stop(statusChk)
	
end

--pins.set(false,pincfg.PIN24)

webRequest.connect()


--qrc = ""
--qrl = 841
--lcd.qrCodeDisp(qrc,qrl)
