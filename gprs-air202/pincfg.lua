require"pins"
module(...,package.seeall)

--[[
重要提醒!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

使用某些GPIO时，必须在脚本中写代码打开GPIO所属的电压域，配置电压输出输入等级，这些GPIO才能正常工作
必须在GPIO使用前(即本文件的pins.reg前)调用pmd.ldoset(电压等级,电压域类型)
电压等级与对应的电压如下：
0--------关闭
1--------1.8V
2--------1.9V
3--------2.0V
4--------2.6V
5--------2.8V
6--------3.0V
7--------3.3V
IO配置为输出时，高电平时的输出电压即为配置的电压等级对应的电压
IO配置为输入或者中断时，外设输入的高电平电压必须与配置的电压等级的电压匹配

电压域与控制的GPIO的对应关系如下：
pmd.LDO_VMMC：GPIO8、GPIO9、GPIO10、GPIO11、GPIO12、GPIO13
pmd.LDO_VLCD：GPIO14、GPIO15、GPIO16、GPIO17、GPIO18
pmd.LDO_VCAM：GPIO19、GPIO20、GPIO21、GPIO22、GPIO23、GPIO24
一旦设置了某一个电压域的电压等级，受该电压域控制的所有GPIO的高电平都与设置的电压等级一致

例如：GPIO8输出电平时，要求输出2.8V，则调用pmd.ldoset(5,pmd.LDO_VMMC)
]]

--如下配置了开源模块中所有可用作GPIO的引脚，每个配置只是演示需要
--用户最终需根据自己的需求自行修改
--模块的所有GPIO都支持中断

--pin值定义如下：
--pio.P0_XX：表示GPIOXX，可表示GPIO 0 到 GPIO 31，例如pio.P0_15，表示GPIO15
--pio.P1_XX：表示GPIO(XX+32)，可表示GPIO 32以上的GPIO，例如pio.P1_2，表示GPIO34

--dir值定义如下（默认值为pio.OUTPUT）：
--pio.OUTPUT：表示输出，初始化是输出低电平
--pio.OUTPUT1：表示输出，初始化是输出高电平
--pio.INPUT：表示输入，需要轮询输入的电平状态
--pio.INT：表示中断，电平状态发生变化时会上报消息，进入本模块的intmsg函数

--valid值定义如下（默认值为1）：
--valid的值跟pins.lua中的set、get接口配合使用
--dir为输出时，配合pins.set接口使用，pins.set的第一个参数如果为true，则会输出valid值表示的电平，0表示低电平，1表示高电平
--dir为输入或中断时，配合get接口使用，如果引脚的电平和valid的值一致，get接口返回true；否则返回false
--dir为中断时，cb为中断引脚的回调函数，有中断产生时，如果配置了cb，会调用cb，如果产生中断的电平和valid的值相同，则cb(true)，否则cb(false)



--如下配置含义和PIN8相似
PIN6 = {pin=pio.P0_3}
PIN7 = {pin=pio.P0_2}


--配置GPIO8、GPIO9、GPIO10、GPIO11、GPIO12、GPIO13的高电平电压为2.8V
pmd.ldoset(5,pmd.LDO_VMMC)
pins.reg(PIN6,PIN7)
