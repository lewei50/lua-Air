

leweiUrl = "http://ug25.lewei50.com/api/V1/gateway/UpdateSensors/"
--leweiUrl = "http://192.168.0.5/api/V1/gateway/UpdateSensors/"

function sendSensors()
     --定义数据变量格式
     PostData = "["
     for i,v in pairs(Sensors.data()) do 
          --convert more device id here
          if(i=="Hum")then i = "H1" end
          if(i=="Temp")then i = "T1" end
          if(i=="pm25")then i = "dust" end
          PostData = PostData .. "{\"Name\":\""..i.."\",\"Value\":\"" .. v .. "\"},"
     end
     
     PostData = string.sub(PostData,1,-2) .. "]"
     --print(PostData)
     http.post(leweiUrl..gateWay,
       "userkey:"..userKey.."\r\n",
       PostData,
       function(code, data)
         if (code < 0) then
           print("HTTP request failed")
         else
           print(code, data)
         end
       end)
     PostData = ""
end

function dataUpload()

sendTimer = tmr.create()
sendTimer:register(60000, tmr.ALARM_AUTO, function() 
     sendSensors()
end)
sendTimer:start()
end

fstTimer = tmr.create()
fstTimer:register(5000, tmr.ALARM_SINGLE, function()
     require("lcd")
     require("keyDetector")
     KeyDetector.enableTrig()
     if(file.open("network_user_cfg.lua"))then
          --require("EasyWebConfig")
          dofile("network_user_cfg.lua")
          wifi.setmode(wifi.STATION)
          --please config ssid and password according to settings of your wireless router.
          wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(T)
               dataUpload()
               print("connected wifi")
               Lcd.setWifiState(5)
           end)
           wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(T)
               Lcd.setWifiState(4)
           end)
          station_cfg={}
          station_cfg.ssid=ssid
          station_cfg.pwd=password
          wifi.sta.config(station_cfg)
          wifi.sta.connect()
          
     end
     if( file.open("webConfigRequest.lua") ~= nil) then
          require("lcd")
          require("Ports")
          print("web config request")
          require("EasyWebConfig")
          Lcd.showPage(0)
          Lcd.setText("info","http://192.168.4.1")
     else
          dofile("run.lua")
     end
end)
fstTimer:start()
