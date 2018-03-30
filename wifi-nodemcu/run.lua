require("Ports")
require("Sensors")
require("keyDetector")
require("lcd")
uart.setup( 0, 9600, 8, 0, 1, 0 )
KeyDetector.enableTrig()

pId = 0
bRefreshLcd = false



function getHT()
     local si7021 = require("si7021")
                    
     SDA_PIN = 5 -- sda pin, GPIO12
     SCL_PIN = 6 -- scl pin, GPIO14
     
     si7021.init(SDA_PIN, SCL_PIN)
     si7021.read(OSS)
     Hum = si7021.getHumidity()
     Temp = si7021.getTemperature() -3
     return Hum,Temp
end

local function DS_HCHO_Data_request()
     Ports.clearBuf()
     Ports.write(string.char(0x42)..string.char(0x4d)..string.char(0x01)..string.char(0x00)..string.char(0x00)..string.char(0x00)..string.char(0x90))
end

local function SENSEAIR_S8_Data_request()
     Ports.clearBuf()
     Ports.write(string.char(0xfe)..string.char(0x04)..string.char(0x00)..string.char(0x03)..string.char(0x00)..string.char(0x01)..string.char(0xd5)..string.char(0xc5))
end


--function shtPress()
     --KeyDetector.setWebConfig()
--end

--KeyDetector.setShortPressFn(shtPress)


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
     return math.floor(aqiNum),result[aqiLevel-1]
end


function cb(data)
     --duplexSensorsTmr:stop()
	--print("callback function"..data)
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
                         --Lcd.showPage(4)
                         hcho_orig = (string.byte(data,29)*256+string.byte(data,30))
                         hcho = hcho_orig/1000
                         if(hcho~=nil)then
                              --lcd.setText("HCHO",hcho.."mg/m3")
                              if(Sensors.setSensorValue("HCHO",hcho,"mg/m3")) then bRefreshLcd = true end
                         end
                         --hcho = hcho_orig/1000 .."."..tostring(hcho_orig%1000/100) ..tostring(hcho_orig%100/10) ..tostring(hcho_orig%10)
                    end
               end
          end
          aqi,result = calcAQI(pm25)
          --lcd.setText("pm25",pm25..result)
          if(Sensors.setSensorValue("pm25",pm25,result)) then bRefreshLcd = true end
          --lcd.setText("aqi",aqi)
          if(Sensors.setSensorValue("aqi",aqi,"")) then bRefreshLcd = true end
     end
     --HH-HCHO-M sensor decode / Dart HCHO
     if(((string.byte(data,1)==0xff) and(string.byte(data,2)==0x17))) then
          hcho_orig = (string.byte(data,5)*256+string.byte(data,6))
          --hcho = hcho_orig/1000 .."."..tostring(hcho_orig%1000/100) ..tostring(hcho_orig%100/10)
          hcho = hcho_orig/1000
          if(hcho~=nil)then
               --if(co2~=nil)then
                    --if(lcd.getCurrentPage()~=6) then
                         --lcd.setPage(6)
                    --end
               --else
                    --if(lcd.getCurrentPage()~=4) then
                        -- lcd.setPage(4)
                    --end
               --end
               --lcd.setText("HCHO",hcho.."mg/m3")
               --Lcd.showPage(4)
               if(Sensors.setSensorValue("HCHO",hcho,"mg/m3")) then bRefreshLcd = true end
          end
          --get more accurate date to lewei end
          --hcho = hcho_orig/1000 .."."..tostring(hcho_orig%1000/100) ..tostring(hcho_orig%100/10)..tostring(hcho_orig%10)
          print("HCHO:"..hcho)
     end

   

     --DS HCHO sensor decode
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
          --[[
          hcho = ""
          for i = 1,rate_byte,1 do
               hcho = hcho .. hcho_orig/curr_rate
               if(i==1)then 
                    hcho = hcho .."." 
               end
               hcho_orig = hcho_orig % curr_rate
               curr_rate = curr_rate /10
           end
           ]]--
           hcho = hcho_orig/curr_rate
          --print("HCHO:"..hcho)
          if(hcho~=nil)then
               --if(Lcd.getCurrentPage()~=4) then
                    --Lcd.setPage(4)
               --end
               --Lcd.setText("HCHO",hcho..unit)
               --Lcd.showPage(4)
               if(Sensors.setSensorValue("HCHO",hcho,unit)) then bRefreshLcd = true end
          end
          
     end
     
     --SenseAir S8 decode
     if((string.byte(data,1)==0xfe) and(string.byte(data,2)==0x04) and(string.byte(data,3)==0x02)) then
          data_byte_h = string.byte(data,4)
          data_byte_l = string.byte(data,5)
          
          co2 = data_byte_h*256+data_byte_l
          --print("CO2:"..co2)
          if(co2~=nil)then
         
               if(hcho~=nil)then
                    --Lcd.showPage(6)
                    --if(Lcd.getCurrentPage()~=6) then
                         --Lcd.setPage(6)
                    --end
               else
                    --if(Lcd.getCurrentPage()~=5) then
                         --Lcd.setPage(5)
                    --end
                    --Lcd.showPage(5)
               end
               --Lcd.setText("CO2",co2.."ppm")
          if(Sensors.setSensorValue("CO2",co2,"ppm")) then bRefreshLcd = true end
          end
     end

     --Ports.nextPort()
end

Ports.setCallBack(cb)


duplexSensorsTmr = tmr.create()

function portCycle()
     --print("PORT:"..Ports.getPort().." "..node.heap())
     if(Ports.getPort()==0)then
          --refresh lcd
          if(bRefreshLcd)then
               --Lcd.showPage(1)
               Lcd.refreshPage()
               bRefreshLcd = false
               --Ports.nextPort()
          end
     end
     duplexSensorsTmr:register(1000, tmr.ALARM_SINGLE, function()
          --send hex string to sensor
          --print("waiting data timed out,try to send hex to sensor")
          DS_HCHO_Data_request()
          duplexSensorsTmr:register(300, tmr.ALARM_SINGLE, function()
               --send hex string to sensor
               --print("waiting DS_HCHO_Data timed out,try to send hex to sensor")
               SENSEAIR_S8_Data_request()
               duplexSensorsTmr:register(300, tmr.ALARM_SINGLE, function()
                    --send hex string to sensor
                    --print("waiting SENSEAIR_S8_Data_request timed out,try to change port")
                    Ports.nextPort()
                    portCycleTimer:start()
               end)
               duplexSensorsTmr:start()
          end)
          duplexSensorsTmr:start()
     end)
     if not duplexSensorsTmr:start() then print("duplexSensorsTmr fail") end
end


portCycleTimer = tmr.create()
portCycleTimer:register(3000, tmr.ALARM_SEMI, function()

     Ports.enablUart()
     --Sensors.clear()
     h,t  = getHT()
     --print(h,t)
     print(node.heap())
     if(h~=nil and t~=nil)then
          if(Sensors.setSensorValue("Temp",t,"℃")) then bRefreshLcd = true end
          if(Sensors.setSensorValue("Hum",h,"%")) then bRefreshLcd = true end
     end
     --print (bRefreshLcd)
     portCycle()
end)
if not portCycleTimer:start() then print("portCycleTimer fail") end
