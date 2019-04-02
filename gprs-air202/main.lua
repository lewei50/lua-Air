MODULE_TYPE = "Air202"
PROJECT = "LEWEI_GPRS_AIR_MONITOR"
VERSION = "1.0.1"

--***********************
--replace vars from here

--key in https://iot.openluat.com/
--PRODUCT_KEY = "YOUR_PRODUCT_KEY"
PRODUCT_KEY = "k70H7ZT2AG6kKQofPmkaKKLbR2O5LuMo"

require"sys"
require"common" --test模块用到了common.binstohexs接口
require"misc"
require"pm" --test模块用到了pm.wake接口
--require"pincfg"
require"Ports"
require"sim"
require"wdt"
require"config"
require"nvm"
nvm.init("config.lua")

require 'AM2320'

require"mono_i2c_ssd1306"
require"lcd"
require"si7021"
if(config.bEnableLocate == true) then require"locator" end
require"run"
print("version:"..VERSION)
sys.init(0,0)
sys.run()
