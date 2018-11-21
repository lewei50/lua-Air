module(...,package.seeall)
require"net"

local i2cid = 2
local bInited = false


local Si7021_ADDR = 0x40
local CMD_MEASURE_HUMIDITY_HOLD = 0xE5
local CMD_MEASURE_HUMIDITY_NO_HOLD = 0xF5
local CMD_MEASURE_TEMPERATURE_HOLD = 0xE3
local CMD_MEASURE_TEMPERATURE_NO_HOLD = 0xF3

local h,t=nil

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	_G.print("si7021",...)
end

function updateRssi()
	rssi = net.getrssi()
	--print("rssi:"..rssi)
	if(rssi == 0)then
		lcd.setPic("wifiState",4)
	elseif(rssi>24)then
		lcd.setPic("wifiState",11)
	elseif(rssi>16)then
		lcd.setPic("wifiState",10)
	elseif(rssi>8)then
		lcd.setPic("wifiState",9)
	else
		lcd.setPic("wifiState",8)
	end
end

local function readHum()
	i2c.write(i2cid,Si7021_ADDR,CMD_MEASURE_HUMIDITY_HOLD)
  dataH = i2c.read(i2cid,CMD_MEASURE_HUMIDITY_HOLD,2)

  if(string.byte(dataH,1)~= nil and string.byte(dataH,2)~= nil) then
		UH = string.byte(dataH, 1) * 256 + string.byte(dataH, 2)
	  h = ((UH*12500+65536/2)/65536 - 600)
	  --print("got h"..h)
	  UH = nil
	  dataH = nil
	end
end

function getHum()
	if(h~=nil)then
	--return string.sub(h, 1, 2).."."..string.sub(h, 3, 3)
	return  tostring(h/100).."."..tostring(h/10%10)
	else
	return h
	end
end

function getTemp()
	if(t~=nil)then
	--return string.sub(t, 1, 2).."."..string.sub(t, 3, 3)
	if(t<0)then return "-"..tostring(-t/100).."."..tostring(-t/10%10) end
	return  tostring(t/100).."."..tostring(t/10%10)
	else
	return t
	end
end

local function readTemp()
	i2c.write(i2cid,Si7021_ADDR,CMD_MEASURE_TEMPERATURE_HOLD)
	dataT = i2c.read(i2cid,CMD_MEASURE_TEMPERATURE_HOLD,2)
	if(string.byte(dataT, 1)~= nil and string.byte(dataT, 2)~=nil)then
	  UT = string.byte(dataT, 1) * 256 + string.byte(dataT, 2)
	  t = ((UT*17572+65536/2)/65536 - 4685)
	  --print("got t"..t)
	  UT = nil
	  dataT = nil
  end
end


--[[
函数名：init
功能  ：打开i2c，写初始化命令给从设备寄存器，并从从设备寄存器读取值
参数  ：无
返回值：无
]]
local function init()
	if(bInited == false) then
		if i2c.setup(i2cid,i2c.SLOW,Si7021_ADDR) ~= i2c.SLOW then
			print("init fail")
			return
		else
			bInited = true
			print("i2c init ok")
		end
	end
  
	readTemp()
  sys.timer_start(readHum,500)
  
  updateRssi()
  
end


init()
sys.timer_loop_start(init,5000,i2cid)
