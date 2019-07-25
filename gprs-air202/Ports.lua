require"pins"
require"pincfg"
module(...,package.seeall)


local rcv = ""
pLock = false
--uartTimer = tmr.create()
currentPortId = 0

function uartCBFunc() end


pins.set(false,pincfg.PIN7)
pins.set(false,pincfg.PIN6)

function openPort(portId)
	print("openPort "..portId)
	if(pLock==false) then
		if(portId == 1) then
			pins.set(false,pincfg.PIN7)
			pins.set(true,pincfg.PIN6)
		elseif(portId == 2) then
			pins.set(true,pincfg.PIN7)
			pins.set(false,pincfg.PIN6)
		elseif(portId == 3) then
			pins.set(true,pincfg.PIN7)
			pins.set(true,pincfg.PIN6)
		else
			pins.set(false,pincfg.PIN7)
			pins.set(false,pincfg.PIN6)
		end
	end
	return not pLock
end

function nextPort()
     currentPortId = (currentPortId + 1)%4
     openPort(currentPortId)
     return currentPortId
end


function resolveData(data)
     --print("resolveData"..data)
     if(uartCBFunc) then 
     	uartCBFunc(data)
     end
end

function setCallBack(fn)
	uartCBFunc = fn
     --print(uartCBFunc)
end


function disableUart()
     uart.on("data")
end

function resolveData(data)
     --print("resolveData"..data)
     if(uartCBFunc) then
     	uartCBFunc(data)
     else
          disableUart()
     end
end

function enablUart()
     --print("enablUart")
     --uart.setup( 0, 9600, 8, 0, 1, 0 )
     uart.on("data", 0,
       function(data)
          uartTimer:register(10, tmr.ALARM_SINGLE, function()
          resolveData(rcv)
          uartTimer:stop()
          rcv = ""
          end)
          rcv = rcv..data
          uartTimer:start()
     end, 0)
end

function clearBuf()
     rcv = ""
end

function write(data)
	uart.write(0,data)
end

function isLock()
	return pLock
end

function lock(lockstate)
	pLock = lockstate
end

function lockPort(pid)
	if(pLock == false) then
		openPort(pid)
		pLock = true
	end
end

function unlock()
	pLock = false
end

function getPort()
     return currentPortId
end

