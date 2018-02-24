local moduleName = "Lcd"
local M = {}
_G[moduleName] = M

local currentPage = -1
local bDrawing = false
local dName = ""
local wifiState=4

uart.setup( 0, 9600, 8, 0, 1, 0 )


function M.setDName(dname)
     dName = dname
end

function M.getDName()
     return dName
end

function M.setWifiState(state)
     wifiState = state
end

function M.getWifiState()
     return wifiState
end
function sentData(data)
     if(Ports.openPort(0)) then
          uart.write(0,data..string.char(255)..string.char(255)..string.char(255))
          tmr.delay(200)
          uart.write(0,data..string.char(255)..string.char(255)..string.char(255))
          tmr.delay(200)
     end
end

function M.showPage(pid)
     if(currentPage ~= pid) then
          sentData("page "..pid)
          currentPage= pid
     end
end

function M.refreshPage()
     --print("refresh page")
     if(Sensors.data()["Hum"]) then pg = 1 end
     if(Sensors.data()["HCHO"]) then pg = 4 end
     if(Sensors.data()["CO2"]) then
          if(pg==4) then
          --co2 + hcho
               pg = 6
          else
          --co2 only
               pg = 5
          end
     end
     M.showPage(pg)
     M.setPic("wifiState",wifiState)
     for k,v in pairs(Sensors.data()) do
          print(k,v,Sensors.units()[k])
          if(k=="Hum")then M.setText("hum",math.ceil(v)..Sensors.units()[k]) end
          if(k=="Temp")then M.setText("temp",math.ceil(v)..Sensors.units()[k]) end
          if(k=="pm25")then M.setText("pm25",math.ceil(v)..Sensors.units()[k]) end
          if(k=="aqi")then M.setText("aqi",math.ceil(v)..Sensors.units()[k]) end
          if(k=="HCHO")then M.setText("HCHO",string.format("%.2f",v)..Sensors.units()[k]) end
          if(k=="CO2")then M.setText("CO2",math.ceil(v)..Sensors.units()[k]) end
     end
end

function M.setText(textName,txt)
     sentData(textName..".txt=\""..txt.."\"")
end

function M.setNumber(numName,num)
     sentData(numName..".val="..num)
end

function M.setPic(numName,num)
     sentData(numName..".pic="..num)
end
--[[
function M.crtPage()
     return currentPage
end

function M.setDrawing(state)
     bDrawing = state
end

function M.isDrawing()
     return bDrawing
end
]]--
