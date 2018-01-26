MODULE_TYPE = "Air200"
PROJECT = "LEWEI_GPRS_AIR_MONITOR"
VERSION = "1.0.0"

--***********************
--replace vars from here

--key in https://iot.openluat.com/
--PRODUCT_KEY = "YOUR_PRODUCT_KEY"
PRODUCT_KEY = "epFaKbBz7nIidfBdom0B3i1lPifZnSx3"

require"sys"
require"common" --test模块用到了common.binstohexs接口
require"misc"
require"pm" --test模块用到了pm.wake接口
require"sim"
require"wdt"
require"config"
require"nvm"
--require"pincfg"
nvm.init("config.lua")

require"lcd"
require"si7021"
if(config.bEnableLocate == true) then require"locator" end
require"run"

sys.init(0,0)
sys.run()
