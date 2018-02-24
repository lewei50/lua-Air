module(...,package.seeall)

--[[
功能需求：
串口LCD屏幕的显示控制
]]

local LCD_UART_ID = 1
local currentPage = 0
local pageLock = false
local testDot = false
local bEnableRefresh = true
local dName = ""
local wifiState=4

function getCurrentPage()
	return currentPage
end

function disableRefresh()
	bEnableRefresh = false
end

function enableRefresh()
	bEnableRefresh = true
end

--帧头类型以及帧尾
local CMD_SCANNER,CMD_GPIO,CMD_PORT,FRM_TAIL = 1,2,3,string.char(0xC0)
--串口读到的数据缓冲区
local rdbuf = ""

--[[
函数名：print
功能  ：打印接口，此文件中的所有打印都会加上test前缀
参数  ：无
返回值：无
]]
local function print(...)
	--_G.print("[LCD]",...)
end

function showPage(pid)
     if(currentPage ~= pid) then
          write("page "..pid)
          write("page "..pid)
          currentPage= pid
     end
end

function refreshPage()
	print("refresh page")
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
	showPage(pg)
	setPic("wifiState",wifiState)
	for k,v in pairs(Sensors.data()) do
	    print(k,v,Sensors.units()[k])
	    if(k=="Hum")then setText("hum",v..Sensors.units()[k]) end
	    if(k=="Temp")then setText("temp",v..Sensors.units()[k]) end
	    if(k=="pm25")then setText("pm25",v..Sensors.units()[k]) end
	    if(k=="aqi")then setText("aqi",v..Sensors.units()[k]) end
	    if(k=="HCHO")then setText("HCHO",v..Sensors.units()[k]) end
	    if(k=="CO2")then setText("CO2",v..Sensors.units()[k]) end
	end
end

--[[
函数名：read
功能  ：读取串口接收到的数据
参数  ：无
返回值：无
]]
local function read()
	
end

--[[
函数名：write
功能  ：通过串口发送数据
参数  ：
		s：要发送的数据
返回值：无
]]
function write(s)
	if(bEnableRefresh == true) then
		print("write",s)
		uart.write(LCD_UART_ID,s..string.char(255)..string.char(255)..string.char(255))
	end
end

function setPage(id)
	if(pageLock == false)then
		write("page "..id)
		write("page "..id)
		currentPage = id
	end
end

function lockPage(state)
	pageLock = state
end

function setInfo(cnt)
	write("info.txt=\""..cnt.."\"")
end

function displayTestDot()
	if(testDot == false) then
		setInfo(".")
		testDot = true
	else
		setInfo("")
		testDot = false
	end
end

function setText(textName,txt)
     write(textName..".txt=\""..txt.."\"")
end

function setNumber(numName,num)
     write(numName..".val="..num)
end

function setPic(numName,num)
     write(numName..".pic="..num)
end



function drawRec(startPos,endPos,size,bFill)
     startPosX = 45--37
     startPosY = 41--33
     if(bFill==0) then
     write("fill "..startPos*size+startPosX..","..endPos*size+startPosY..","..size..","..size..",WHITE"..string.char(255)..string.char(255)..string.char(255))
     end
end

function qrCodeDisp(qrCode,qrLength)
	lockPage(true)
	setPage(2)
	write("fill 33,29,170,170,BLACK"..string.char(255)..string.char(255)..string.char(255))
	local h2b = {
	    ["0"] = 0,
	    ["1"] = 1,
	    ["2"] = 2,
	    ["3"] = 3,
	    ["4"] = 4,
	    ["5"] = 5,
	    ["6"] = 6,
	    ["7"] = 7,
	    ["8"] = 8,
	    ["9"] = 9,
	    ["A"] = 10,
	    ["B"] = 11,
	    ["C"] = 12,
	    ["D"] = 13,
	    ["E"] = 14,
	    ["F"] = 15
	}
	print(string.len(qrCode))
	if(qrLength == 841)then
		row = 29
	end
	count = 1
	currentRow = 0
	currentCol = 0
	for currentBlock = 1,string.len(qrCode),1 do
		currentChar = string.sub(qrCode,currentBlock,currentBlock)
		--print(currentBlock,currentChar,h2b[string.upper(currentChar)])
		--output = ""
		currentNum = h2b[string.upper(currentChar)]
		bitMask = 8
		repeat
			--bit.band(currentNum,bitMask)/bitMask is what we needed
			--output = output .. bit.band(currentNum,bitMask)/bitMask
			currentColor = bit.band(currentNum,bitMask)/bitMask
			drawRec(currentCol,currentRow,5,currentColor)
			count = count + 1
			currentRow = currentRow + 1
			if(currentRow == row) then
				currentRow = 0
				currentCol = currentCol + 1
			end
			bitMask = bitMask/2
			if(count > qrLength) then
				break
			end
		until bitMask < 1
		--print(output)
	end
end


--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("test")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("test")后，在不需要串口时调用pm.sleep("test")
--pm.wake("test")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
--sys.reguart(LCD_UART_ID,read)
--配置并且打开串口

--uart.setup(LCD_UART_ID,9600,8,uart.PAR_NONE,uart.STOP_1)
