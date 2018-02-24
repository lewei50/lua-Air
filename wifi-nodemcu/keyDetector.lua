local moduleName = "KeyDetector"
local M = {}
_G[moduleName] = M

local pulse1 = 0
local du = 0

local flashButton = 3
--bEnabledPMS = true

function M.setWebConfig()
     --file.remove("network_user_cfg.lua")
     if(file.exists("webConfigRequest.lua")) then
          file.remove("webConfigRequest.lua")
     else
          file.open("webConfigRequest.lua","w")
          file.writeline("1")
          file.close()
     end
     node.restart()
end

local function shrtPress()
     M.setWebConfig()
end

function noOp(level)
--print("no op")
end

function M.setShortPressFn(fn)
     shrtPress = fn
end

function shortPress()
     --print("short press")
     shrtPress()
     --[[
     tmr.stop(6)
          collectgarbage()
          
          if(wifi.sta.getip()==nil)then
          collectgarbage()
     print(node.heap())
               print("soft ap mode")
               --require("network_default_cfg")
               
               wifi.setmode(wifi.STATIONAP)
               wifi.ap.config({ssid="LEWEI50", auth=wifi.OPEN})
               
               
               
          end
          ]]--
end


function pin1cb(level)
--print(level)
     if level == 1 then 
          --print("up"..tmr.now().."-"..pulse1)
          tmr.stop(6)
          gpio.trig(flashButton, "down",pin1cb) 
          du = tmr.now()-pulse1
          if(du<40000)then
               --ignor
          elseif(du<600000)then
               shortPress()
          end
     
     else 
          --print("down"..tmr.now())
          pulse1 = tmr.now()
          tmr.alarm(6, 2500, 0, function()
               print("3s")
               setWebConfig()
               end )
          gpio.trig(flashButton, "up",pin1cb) 
     end
     print(node.heap())
end



function M.disableTrig()
--print("disable trig")
gpio.mode(flashButton,gpio.INT)
--print("disable trig1")
     gpio.trig(flashButton, "down",noOp)
--print("disable trig2")
end

function M.enableTrig()
print("enable trig")
gpio.mode(flashButton,gpio.INT)
     gpio.trig(flashButton, "low",pin1cb)
end
--enableTrig()

return M
