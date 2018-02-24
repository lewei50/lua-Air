local moduleName = "Sensors"
local M = {}
_G[moduleName] = M

local sensorValues={}
local sensorUnits={}

local function chkSensorChange(sensorName,sensorValue)
     if(sensorValues[sensorName] ~= nil and sensorValues[sensorName]==sensorValue) then
     return false
     end
     return true
end

function M.setSensorValue(sensorName,sensorValue,sensorUnit)
     sensorUnit = sensorUnit or ""
     if(chkSensorChange(sensorName,sensorValue)) then
          sensorValues[sensorName] = sensorValue
          sensorUnits[sensorName] = sensorUnit
          return true
     end
     return false
end

function M.data()
     return sensorValues
end

function M.units()
     return sensorUnits
end

function M.clear()
     sensorValues={}
end

return M
