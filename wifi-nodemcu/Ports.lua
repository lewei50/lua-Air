local moduleName = "Ports"
local M = {}
_G[moduleName] = M

local rcv = ""
pLock = false
uartTimer = tmr.create()
currentPortId = 0

function uartCBFunc() end

gpio.mode(1, gpio.OUTPUT)
gpio.mode(2, gpio.OUTPUT)
gpio.write(1,gpio.LOW)
gpio.write(2,gpio.LOW)

function M.openPort(portId)
	if(pLock==false) then
		if(portId == 1) then
			gpio.write(1,gpio.HIGH)
			gpio.write(2,gpio.LOW)
		elseif(portId == 2) then
			gpio.write(1,gpio.LOW)
			gpio.write(2,gpio.HIGH)
		elseif(portId == 3) then
			gpio.write(1,gpio.HIGH)
			gpio.write(2,gpio.HIGH)
		else
			gpio.write(1,gpio.LOW)
			gpio.write(2,gpio.LOW)
		end
	end
	return not pLock
end

function M.nextPort()
     currentPortId = (currentPortId + 1)%4
     M.openPort(currentPortId)
     return currentPortId
end


function M.resolveData(data)
     --print("resolveData"..data)
     if(uartCBFunc) then 
     	uartCBFunc(data)
     end
end

function M.setCallBack(fn)
	uartCBFunc = fn
     --print(uartCBFunc)
end


function M.disableUart()
     uart.on("data")
end

function M.resolveData(data)
     --print("resolveData"..data)
     if(uartCBFunc) then
     	uartCBFunc(data)
     else
          disableUart()
     end
end

function M.enablUart()
     --print("enablUart")
     --uart.setup( 0, 9600, 8, 0, 1, 0 )
     uart.on("data", 0,
       function(data)
          uartTimer:register(10, tmr.ALARM_SINGLE, function()
          M.resolveData(rcv)
          uartTimer:stop()
          rcv = ""
          end)
          rcv = rcv..data
          uartTimer:start()
     end, 0)
end

function M.clearBuf()
     rcv = ""
end

function M.write(data)
	uart.write(0,data)
end
--[[
function M.isLock()
	return pLock
end

function M.lock(lockstate)
	pLock = lockstate
end
]]--
function M.getPort()
     return currentPortId
end


return M
