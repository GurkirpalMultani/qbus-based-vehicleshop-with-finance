TMKC = nil
TriggerEvent('TMKC:GetObject', function(obj) TMKC = obj end)

-- Code

TMKC.Functions.CreateCallback('tmkc-occasions:server:getVehicles', function(source, cb)
    TMKC.Functions.ExecuteSql(false, 'SELECT * FROM `occasion_vehicles`', function(result)
        if result[1] ~= nil then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

TMKC.Functions.CreateCallback("tmkc-occasions:server:checkVehicleOwner", function(source, cb, plate)
    local src = source
    local pData = TMKC.Functions.GetPlayer(src)

    exports['ghmattimysql']:execute('SELECT * FROM player_vehicles WHERE plate = @plate AND citizenid = @citizenid', {['@plate'] = plate, ['@citizenid'] = pData.PlayerData.citizenid}, function(result)
        if result[1] ~= nil then
            if result[1].finance_owed ~= nil then
                if result[1].finance_owed == 0 then
                    cb(true)
                else
                    cb(false)
                end
            else
                cb(true)
            end
        else
            cb(false)
        end
    end)
end)

TMKC.Functions.CreateCallback("tmkc-garage:server:checkVehicleOwner", function(source, cb, plate)
    local src = source
    local pData = TMKC.Functions.GetPlayer(src)

    exports['ghmattimysql']:execute('SELECT * FROM player_vehicles WHERE plate = @plate AND citizenid = @citizenid', {['@plate'] = plate, ['@citizenid'] = pData.PlayerData.citizenid}, function(result)
        if result[1] ~= nil then
            cb(true)
        else
            cb(false)
        end
    end)
end)

TMKC.Functions.CreateCallback("tmkc-occasions:server:getSellerInformation", function(source, cb, citizenid)
    local src = source

    exports['ghmattimysql']:execute('SELECT * FROM players WHERE citizenid = @citizenid', {['@citizenid'] = citizenid}, function(result)
        if result[1] ~= nil then
            cb(result[1])
        else
            cb(nil)
        end
    end)
end)

RegisterServerEvent('tmkc-occasions:server:ReturnVehicle')
AddEventHandler('tmkc-occasions:server:ReturnVehicle', function(vehicleData)
    local src = source
    local Player = TMKC.Functions.GetPlayer(src)
    TMKC.Functions.ExecuteSql(false, "SELECT * FROM `occasion_vehicles` WHERE `plate` = '"..vehicleData['plate'].."' AND `occasionid` = '"..vehicleData["oid"].."'", function(result)
        if result[1] ~= nil then 
            if result[1].seller == Player.PlayerData.citizenid then
                TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `state`) VALUES ('"..Player.PlayerData.steam.."', '"..Player.PlayerData.citizenid.."', '"..vehicleData["model"].."', '"..GetHashKey(vehicleData["model"]).."', '"..vehicleData["mods"].."', '"..vehicleData["plate"].."', '0')")
                TMKC.Functions.ExecuteSql(false, "DELETE FROM `occasion_vehicles` WHERE `occasionid` = '"..vehicleData["oid"].."' and `plate` = '"..vehicleData['plate'].."'")
                TriggerClientEvent("tmkc-occasions:client:ReturnOwnedVehicle", src, result[1])
                TriggerClientEvent('tmkc-occasion:client:refreshVehicles', -1)
            else
                TriggerClientEvent('TMKC:Notify', src, 'This is not your vehicle...', 'error', 3500)
            end
        else
            TriggerClientEvent('TMKC:Notify', src, 'Vehicle does not exist...', 'error', 3500)
        end
    end)
end)

RegisterServerEvent('tmkc-occasions:server:sellVehicle')
AddEventHandler('tmkc-occasions:server:sellVehicle', function(vehiclePrice, vehicleData)
    local src = source
    local Player = TMKC.Functions.GetPlayer(src)
    TMKC.Functions.ExecuteSql(true, "DELETE FROM `player_vehicles` WHERE `plate` = '"..vehicleData.plate.."' AND `vehicle` = '"..vehicleData.model.."'")
    TMKC.Functions.ExecuteSql(true, "INSERT INTO `occasion_vehicles` (`seller`, `price`, `description`, `plate`, `model`, `mods`, `occasionid`) VALUES ('"..Player.PlayerData.citizenid.."', '"..vehiclePrice.."', '"..escapeSqli(vehicleData.desc).."', '"..vehicleData.plate.."', '"..vehicleData.model.."', '"..json.encode(vehicleData.mods).."', '"..generateOID().."')")
    
    TriggerEvent("tmkc-log:server:sendLog", Player.PlayerData.citizenid, "vehiclesold", {model=vehicleData.model, vehiclePrice=vehiclePrice})
    TriggerEvent("tmkc-log:server:CreateLog", "vehicleshop", "Vehicle for sale", "red", "**"..GetPlayerName(src) .. "** bought a " .. vehicleData.model .. " for "..vehiclePrice)

    TriggerClientEvent('tmkc-occasion:client:refreshVehicles', -1)
end)

RegisterServerEvent('tmkc-occasions:server:buyVehicle')
AddEventHandler('tmkc-occasions:server:buyVehicle', function(vehicleData)
    local src = source
    local Player = TMKC.Functions.GetPlayer(src)

    TMKC.Functions.ExecuteSql(false, "SELECT * FROM `occasion_vehicles` WHERE `plate` = '"..vehicleData['plate'].."' AND `occasionid` = '"..vehicleData["oid"].."'", function(result)
        if result[1] ~= nil and next(result[1]) ~= nil then
            if Player.PlayerData.money.cash >= result[1].price then
                local SellerCitizenId = result[1].seller
                local SellerData = TMKC.Functions.GetPlayerByCitizenId(SellerCitizenId)
                -- New price calculation minus tax
                local NewPrice = math.ceil((result[1].price / 100) * 77)

                Player.Functions.RemoveMoney('cash', result[1].price)

                -- Insert vehicle for buyer
                TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `state`) VALUES ('"..Player.PlayerData.steam.."', '"..Player.PlayerData.citizenid.."', '"..result[1].model.."', '"..GetHashKey(result[1].model).."', '"..result[1].mods.."', '"..result[1].plate.."', '0')")
                
                -- Handle money transfer
                if SellerData ~= nil then
                    -- Add money for online
                    SellerData.Functions.AddMoney('bank', NewPrice)
                else
                    -- Add money for offline
                    TMKC.Functions.ExecuteSql(true, "SELECT * FROM `players` WHERE `citizenid` = '"..SellerCitizenId.."'", function(BuyerData)
                        if BuyerData[1] ~= nil then
                            local BuyerMoney = json.decode(BuyerData[1].money)
                            BuyerMoney.bank = BuyerMoney.bank + NewPrice
                            TMKC.Functions.ExecuteSql(false, "UPDATE `players` SET `money` = '"..json.encode(BuyerMoney).."' WHERE `citizenid` = '"..SellerCitizenId.."'")
                        end
                    end)
                end

                TriggerEvent("tmkc-log:server:sendLog", Player.PlayerData.citizenid, "vehiclebought", {model = result[1].model, from = SellerCitizenId, moneyType = "cash", vehiclePrice = result[1].price, plate = result[1].plate})
                TriggerEvent("tmkc-log:server:CreateLog", "vehicleshop", "Occasion sold", "green", "**"..GetPlayerName(src) .. "** sold an occasion for "..result[1].price .. " (" .. result[1].plate .. ") to **"..SellerCitizenId.."**")
                TriggerClientEvent('tmkc-occasion:client:refreshVehicles', -1)
            
                -- Delete vehicle from Occasion
                TMKC.Functions.ExecuteSql(false, "DELETE FROM `occasion_vehicles` WHERE `plate` = '"..result[1].plate.."' and `occasionid` = '"..result[1].occasionid.."'")

                -- Send selling mail to seller
                TriggerEvent('tmkc-phone:server:sendNewMailToOffline', SellerCitizenId, {
                    sender = "Mosleys Occasions",
                    subject = "U heeft een voertuig verkocht!",
                    message = ""..TMKC.Shared.Vehicles[result[1].model].name.." is sold for $"..result[1].price..",-!"
                })
            elseif Player.PlayerData.money.bank >= result[1].price then
                local SellerCitizenId = result[1].seller
                local SellerData = TMKC.Functions.GetPlayerByCitizenId(SellerCitizenId)
                -- New price calculation minus tax
                local NewPrice = math.ceil((result[1].price / 100) * 77)

                Player.Functions.RemoveMoney('bank', result[1].price)

                -- Insert vehicle for buyer
                TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `state`) VALUES ('"..Player.PlayerData.steam.."', '"..Player.PlayerData.citizenid.."', '"..result[1].model.."', '"..GetHashKey(result[1].model).."', '"..result[1].mods.."', '"..result[1].plate.."', '0')")
                
                -- Handle money transfer
                if SellerData ~= nil then
                    -- Add money for online
                    SellerData.Functions.AddMoney('bank', NewPrice)
                else
                    -- Add money for offline
                    TMKC.Functions.ExecuteSql(true, "SELECT * FROM `players` WHERE `citizenid` = '"..SellerCitizenId.."'", function(BuyerData)
                        if BuyerData[1] ~= nil then
                            local BuyerMoney = json.decode(BuyerData[1].money)
                            BuyerMoney.bank = BuyerMoney.bank + NewPrice
                            TMKC.Functions.ExecuteSql(false, "UPDATE `players` SET `money` = '"..json.encode(BuyerMoney).."' WHERE `citizenid` = '"..SellerCitizenId.."'")
                        end
                    end)
                end

                TriggerEvent("tmkc-log:server:sendLog", Player.PlayerData.citizenid, "vehiclebought", {model = result[1].model, from = SellerCitizenId, moneyType = "cash", vehiclePrice = result[1].price, plate = result[1].plate})
                TriggerEvent("tmkc-log:server:CreateLog", "vehicleshop", "Occasion bought", "green", "**"..GetPlayerName(src) .. "** bought an occasions for "..result[1].price .. " (" .. result[1].plate .. ") from **"..SellerCitizenId.."**")
                TriggerClientEvent('tmkc-occasion:client:refreshVehicles', -1)
            
                -- Delete vehicle from Occasion
                TMKC.Functions.ExecuteSql(false, "DELETE FROM `occasion_vehicles` WHERE `plate` = '"..result[1].plate.."' and `occasionid` = '"..result[1].occasionid.."'")

                -- Send selling mail to seller
                TriggerEvent('tmkc-phone:server:sendNewMailToOffline', SellerCitizenId, {
                    sender = "Mosleys Occasions",
                    subject = "You have sold a vehicle!",
                    message = "Je "..TMKC.Shared.Vehicles[result[1].model].name.." is sold for $"..result[1].price..",-!"
                })
            else
                TriggerClientEvent('TMKC:Notify', src, 'You don\'t have enough money...', 'error', 3500)
            end
        end
    end)
end)

function generateOID()
    local num = math.random(1, 10)..math.random(111, 999)

    return "OC"..num
end

function round(number)
    return number - (number % 1)
end

function escapeSqli(str)
    local replacements = { ['"'] = '\\"', ["'"] = "\\'" }
    return str:gsub( "['\"]", replacements ) -- or string.gsub( source, "['\"]", replacements )
end