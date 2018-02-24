module(...,package.seeall)

local sensorValues={}
local sensorUnits={}

local function chkSensorChange(sensorName,sensorValue)
     if(sensorValues[sensorName] ~= nil and sensorValues[sensorName]==sensorValue) then
     return false
     end
     return true
end

function setSensorValue(sensorName,sensorValue,sensorUnit)
     sensorUnit = sensorUnit or ""
     if(chkSensorChange(sensorName,sensorValue)) then
          sensorValues[sensorName] = sensorValue
          sensorUnits[sensorName] = sensorUnit
          return true
     end
     return false
end

function data()
     return sensorValues
end

function units()
     return sensorUnits
end

function clear()
     sensorValues={}
end
