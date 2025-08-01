local debugEnabled = false
local debugThread = nil
local cachedPI = nil
local cachedModel = nil
local cachedVehicleData = nil
local cachedVehicleModel = nil

local tireProfileTargets = {
    ["ClassC1"] = {minIndex = 412, maxIndex = 436, speed = "135"},
    ["ClassC2"] = {minIndex = 388, maxIndex = 411, speed = "131"},
    ["ClassC3"] = {minIndex = 364, maxIndex = 387, speed = "128"},
    ["ClassC4"] = {minIndex = 340, maxIndex = 363, speed = "124"},
    ["ClassC5"] = {minIndex = 310, maxIndex = 339, speed = "120"},

    ["ClassB1"] = {minIndex = 497, maxIndex = 511, speed = "160"},
    ["ClassB2"] = {minIndex = 483, maxIndex = 496, speed = "153"},
    ["ClassB3"] = {minIndex = 469, maxIndex = 482, speed = "148"},
    ["ClassB4"] = {minIndex = 455, maxIndex = 468, speed = "143"},
    ["ClassB5"] = {minIndex = 435, maxIndex = 454, speed = "138"},

    ["ClassA1"] = {minIndex = 552, maxIndex = 561, speed = "170"},
    ["ClassA2"] = {minIndex = 543, maxIndex = 551, speed = "168"},
    ["ClassA3"] = {minIndex = 534, maxIndex = 542, speed = "167"},
    ["ClassA4"] = {minIndex = 525, maxIndex = 533, speed = "165"},
    ["ClassA5"] = {minIndex = 510, maxIndex = 524, speed = "164"},

    ["ClassS1"] = {minIndex = 601, maxIndex = 611, speed = "185"},
    ["ClassS2"] = {minIndex = 591, maxIndex = 600, speed = "182"},
    ["ClassS3"] = {minIndex = 581, maxIndex = 590, speed = "179"},
    ["ClassS4"] = {minIndex = 571, maxIndex = 580, speed = "176"},
    ["ClassS5"] = {minIndex = 560, maxIndex = 570, speed = "174"},

    ["ClassS+1"] = {minIndex = 650, maxIndex = 661, speed = "198"},
    ["ClassS+2"] = {minIndex = 638, maxIndex = 649, speed = "196"},
    ["ClassS+3"] = {minIndex = 626, maxIndex = 637, speed = "194"},
    ["ClassS+4"] = {minIndex = 614, maxIndex = 625, speed = "192"},
    ["ClassS+5"] = {minIndex = 610, maxIndex = 613, speed = "190"},

    ["ClassX1"] = {minIndex = 932, maxIndex = 999, speed = "241"},
    ["ClassX2"] = {minIndex = 864, maxIndex = 931, speed = "230"},
    ["ClassX3"] = {minIndex = 796, maxIndex = 863, speed = "220"},
    ["ClassX4"] = {minIndex = 728, maxIndex = 795, speed = "210"},
    ["ClassX5"] = {minIndex = 661, maxIndex = 727, speed = "200"},

    ["Moto1"] = {minIndex = 750, maxIndex = 850, speed = "220"},
    ["Moto2"] = {minIndex = 550, maxIndex = 600, speed = "164"},
    ["Moto3"] = {minIndex = 450, maxIndex = 550, speed = "150"},
    ["Moto4"] = {minIndex = 400, maxIndex = 450, speed = "140"},
    ["Moto5"] = {minIndex = 350, maxIndex = 400, speed = "130"},
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
            return exports["legacydmc_dynamic"]:getPerformanceIndex(model, nil, nil, nil, nil, nil, nil)
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