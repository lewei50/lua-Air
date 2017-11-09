PROJECT = "UART"
VERSION = "1.0.0"
require"sys"
require"common" --test模块用到了common.binstohexs接口
require"misc"
require"pm" --test模块用到了pm.wake接口
require"wdt"
require"config"
require"nvm"
require"pincfg"
nvm.init("config.lua")

require"lcd"
require"si7021"
require"run"

sys.init(0,0)
sys.run()
