local debugEnabled = false
local debugThread = nil
local cachedPI = nil
local cachedModel = nil
local cachedVehicleData = nil
local cachedVehicleModel = nil

local tireProfileTargets = {
    ["ClassC1"] = {minIndex = 452, maxIndex = 476, speed = "135"},
    ["ClassC2"] = {minIndex = 428, maxIndex = 451, speed = "131"},
    ["ClassC3"] = {minIndex = 404, maxIndex = 427, speed = "128"},
    ["ClassC4"] = {minIndex = 380, maxIndex = 403, speed = "124"},
    ["ClassC5"] = {minIndex = 350, maxIndex = 379, speed = "120"},

    ["ClassB1"] = {minIndex = 537, maxIndex = 551, speed = "160"},
    ["ClassB2"] = {minIndex = 523, maxIndex = 536, speed = "153"},
    ["ClassB3"] = {minIndex = 509, maxIndex = 522, speed = "148"},
    ["ClassB4"] = {minIndex = 495, maxIndex = 508, speed = "143"},
    ["ClassB5"] = {minIndex = 475, maxIndex = 494, speed = "138"},

    ["ClassA1"] = {minIndex = 592, maxIndex = 601, speed = "170"},
    ["ClassA2"] = {minIndex = 583, maxIndex = 591, speed = "168"},
    ["ClassA3"] = {minIndex = 574, maxIndex = 582, speed = "167"},
    ["ClassA4"] = {minIndex = 565, maxIndex = 573, speed = "165"},
    ["ClassA5"] = {minIndex = 550, maxIndex = 564, speed = "164"},

    ["ClassS1"] = {minIndex = 641, maxIndex = 651, speed = "185"},
    ["ClassS2"] = {minIndex = 631, maxIndex = 640, speed = "182"},
    ["ClassS3"] = {minIndex = 621, maxIndex = 630, speed = "179"},
    ["ClassS4"] = {minIndex = 611, maxIndex = 620, speed = "176"},
    ["ClassS5"] = {minIndex = 600, maxIndex = 610, speed = "174"},

    ["ClassS+1"] = {minIndex = 690, maxIndex = 701, speed = "190"},
    ["ClassS+2"] = {minIndex = 678, maxIndex = 689, speed = "190"},
    ["ClassS+3"] = {minIndex = 666, maxIndex = 677, speed = "190"},
    ["ClassS+4"] = {minIndex = 654, maxIndex = 665, speed = "190"},
    ["ClassS+5"] = {minIndex = 650, maxIndex = 653, speed = "190"},

    ["Moto1"] = {minIndex = 750, maxIndex = 800, speed = "220"},
    ["Moto2"] = {minIndex = 650, maxIndex = 750, speed = "180"},
    ["Moto3"] = {minIndex = 550, maxIndex = 650, speed = "160"},
    ["Moto4"] = {minIndex = 450, maxIndex = 550, speed = "130"},
    ["Moto5"] = {minIndex = 350, maxIndex = 450, speed = "100"},
}

function GetTireProfileReference(profile)
    local data = tireProfileTargets[profile]
    return data and string.format("Target Index: %d–%d | Target Speed: %s", data.minIndex, data.maxIndex, data.speed)
        or "[No Reference Set]"
end

function IsDynamicRunning()
    return GetResourceState("legacydmc_dynamic") == "started"
end

function DrawText3D(x, y, z, offsetY, text, color)
    local r, g, b = table.unpack(color or {220, 220, 220})
    
    SetDrawOrigin(x, y, z, 0)
    DrawRect(0.085, offsetY + 0.012, 0.19, 0.026, 0, 0, 0, 195)
    SetTextScale(0.45, 0.45)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(r, g, b, 255)
    SetTextDropshadow(2, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.0, offsetY)
    ClearDrawOrigin()
end

function RenderDebugText(x, y, z, lines)
    local offsetY = 0.02
    for _, line in ipairs(lines) do
        DrawText3D(x, y, z, offsetY, line.text, line.color)
        offsetY = offsetY - 0.026
    end
end

function GetCachedPI(veh)
    if not IsDynamicRunning() then return nil end
    local model = GetEntityModel(veh)
    if cachedModel ~= model or not cachedPI then
        cachedModel = model
        local success, result = pcall(function()
            return exports["legacydmc_dynamic"]:getPerformanceIndex(model)
        end)
        cachedPI = (success and result and result.PI) and result or nil
    end
    return cachedPI
end

function GetCachedVehicleData(veh)
    if not IsDynamicRunning() then return nil end
    local model = GetEntityModel(veh)
    if cachedVehicleModel ~= model or not cachedVehicleData then
        cachedVehicleModel = model
        local success, result = pcall(function()
            return exports["legacydmc_dynamic"]:getVehicleData(model)
        end)
        cachedVehicleData = success and result or nil
    end
    return cachedVehicleData
end

function ResetCache()
    cachedPI, cachedModel, cachedVehicleData, cachedVehicleModel = nil, nil, nil, nil
end

RegisterCommand("dyndebug", function()
    debugEnabled = not debugEnabled
    local status = debugEnabled and "^2ENABLED" or "^1DISABLED"
    TriggerEvent('chat:addMessage', {color = {255, 255, 0}, args = {"[DYNAMIC_DEBUG]", "Debug mode "..status}})
    ResetCache()

    if debugEnabled then
        debugThread = CreateThread(function()
            while debugEnabled do
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)

                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                    local coords = GetEntityCoords(veh)
                    local x, y, z = coords.x, coords.y, coords.z
                    local piData = GetCachedPI(veh)
                    local vehicleData = GetCachedVehicleData(veh)
                    local tireProfile = (vehicleData and vehicleData.tyre and vehicleData.tyre.tyreCompound) or "[Unknown]"
                    local profileData = tireProfileTargets[tireProfile]
                    local piInRange = profileData and piData and (piData.PI >= profileData.minIndex and piData.PI <= profileData.maxIndex) or false
                    local piColor = piInRange and {0, 255, 0} or nil
                    local telemetry = {}
                    local currentRPM = 0

                    if IsDynamicRunning() then
                        local success, result = pcall(function()
                            return exports["legacydmc_dynamic"]:getTelemetryData()
                        end)
                        if success and result then
                            telemetry = result
                            currentRPM = telemetry.engineRpm or 0
                        end
                    end

                    local lines = {}

                    if not piData or not vehicleData then
                        lines = {
                            {text = "[Waiting on legacydmc_dynamic...]"},
                        }
                    else
                        lines = {
                            {text = ""},
                            {text = string.format("Handling: %.2f", piData.handlingScore / 100)},
                            {text = string.format("Top Speed: %.2f", piData.estimatedTopSpeedScore / 100)},
                            {text = string.format("Braking: %.2f", piData.brakingScore / 100)},
                            {text = string.format("Acceleration: %.2f", piData.accScore / 100)},
                            {text = string.format("Performance Index: %d", piData.PI), color = piColor},
                            {text = "-------------------------------------------"},
                            {text = GetTireProfileReference(tireProfile)},
                            {text = "-------------------------------------------"},
                            {text = string.format("Speed: %.1f km/h", GetEntitySpeed(veh) * 3.6)},
                            {text = "Gear: " .. GetVehicleCurrentGear(veh)},
                            {text = string.format("RPM: %.0f", currentRPM)},
                            {text = "-------------------------------------------"},
                            {text = string.format("Tire Profile: %s", tireProfile)},
                            {text = "Vehicle Name: " .. GetDisplayNameFromVehicleModel(GetEntityModel(veh))},
                            {text = ""}
                        }
                    end
                    RenderDebugText(x, y, z, lines)
                else
                    ResetCache()
                end
                Wait(0)
            end
        end)
    else
        debugThread = nil
    end
end, false)

AddEventHandler('onClientResourceStart', function(res) if res == "legacydmc_dynamic" then ResetCache() end end)
AddEventHandler('onClientResourceStop', function(res) if res == "legacydmc_dynamic" then ResetCache() end end)