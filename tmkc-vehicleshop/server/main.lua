TMKC = nil

TriggerEvent('TMKC:GetObject', function(obj) TMKC = obj end)

local NumberCharset = {}
local Charset = {}

for i = 48,  57 do table.insert(NumberCharset, string.char(i)) end

for i = 65,  90 do table.insert(Charset, string.char(i)) end
for i = 97, 122 do table.insert(Charset, string.char(i)) end

-- code

RegisterNetEvent('tmkc-vehicleshop:server:buyVehicle')
AddEventHandler('tmkc-vehicleshop:server:buyVehicle', function(vehicleData, garage)
    local src = source
    local pData = TMKC.Functions.GetPlayer(src)
    local cid = pData.PlayerData.citizenid
    local vData = TMKC.Shared.Vehicles[vehicleData["model"]]
    local balance = pData.PlayerData.money["bank"]
    
    if (balance - vData["price"]) >= 0 then
        local plate = GeneratePlate()
        TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `garage`) VALUES ('"..pData.PlayerData.steam.."', '"..cid.."', '"..vData["model"].."', '"..GetHashKey(vData["model"]).."', '{}', '"..plate.."', '"..garage.."')")
        TriggerClientEvent("TMKC:Notify", src, "Successful! Your vehicle was delivered to "..QB.GarageLabel[garage], "success", 5000)
        pData.Functions.RemoveMoney('bank', vData["price"], "vehicle-bought-in-shop")
        TriggerEvent("tmkc-log:server:sendLog", cid, "vehiclebought", {model=vData["model"], name=vData["name"], from="garage", location=QB.GarageLabel[garage], moneyType="bank", price=vData["price"], plate=plate})
        TriggerEvent("tmkc-log:server:CreateLog", "vehicleshop", "Vehicle Purchased (garage)", "green", "**"..GetPlayerName(src) .. "** has bought " .. vData["name"] .. " one for $" .. vData["price"])
    else
		TriggerClientEvent("TMKC:Notify", src, "You don't have enough money, you are missing $"..format_thousand(vData["price"] - balance), "error", 5000)
    end
end)

RegisterNetEvent('tmkc-vehicleshop:server:buyShowroomVehicle')
AddEventHandler('tmkc-vehicleshop:server:buyShowroomVehicle', function(vehicle, class)
    local src = source
    local pData = TMKC.Functions.GetPlayer(src)
    local cid = pData.PlayerData.citizenid
    local balance = pData.PlayerData.money["bank"]
    local vehiclePrice = TMKC.Shared.Vehicles[vehicle]["price"]
    local plate = GeneratePlate()

    if (balance - vehiclePrice) >= 0 then
        TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `state`) VALUES ('"..pData.PlayerData.steam.."', '"..cid.."', '"..vehicle.."', '"..GetHashKey(vehicle).."', '{}', '"..plate.."', 0)")
        TriggerClientEvent("TMKC:Notify", src, "Successful! Your vehicle is waiting for you outside.", "success", 5000)
        TriggerClientEvent('tmkc-vehicleshop:client:buyShowroomVehicle', src, vehicle, plate)
        pData.Functions.RemoveMoney('bank', vehiclePrice, "vehicle-bought-in-showroom")
        TriggerEvent("tmkc-log:server:sendLog", cid, "vehiclebought", {model=vehicle, name=TMKC.Shared.Vehicles[vehicle]["name"], from="showroom", moneyType="bank", price=TMKC.Shared.Vehicles[vehicle]["price"], plate=plate})
        TriggerEvent("tmkc-log:server:CreateLog", "vehicleshop", "Vehicle bought (showroom)", "green", "**"..GetPlayerName(src) .. "** has bought " .. TMKC.Shared.Vehicles[vehicle]["name"] .. " one for $" .. TMKC.Shared.Vehicles[vehicle]["price"])
    else
        TriggerClientEvent("TMKC:Notify", src, "You don't have enough money, you are missing $"..format_thousand(vehiclePrice - balance), "error", 5000)
    end
end)

RegisterNetEvent('tmkc-vehicleshop:server:FinanceVehicle')
AddEventHandler('tmkc-vehicleshop:server:FinanceVehicle', function(vehicle, class)
    local src = source
    local pData = TMKC.Functions.GetPlayer(src)
    local cid = pData.PlayerData.citizenid
    local balance = pData.PlayerData.money["bank"]
    local vehicleValue = TMKC.Shared.Vehicles[vehicle]["price"]
    local financeInstallment = (TMKC.Shared.Vehicles[vehicle]["price"] * 0.15)
    local plate = GeneratePlate()

    if (balance - financeInstallment) >= 0 then
        TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `state`,`finance_owed`) VALUES ('"..pData.PlayerData.steam.."', '"..cid.."', '"..vehicle.."', '"..GetHashKey(vehicle).."', '{}', '"..plate.."', 0, '"..vehicleValue.."')")
        TriggerClientEvent("TMKC:Notify", src, "Successful! Your vehicle is waiting for you outside.", "success", 5000)
        TriggerClientEvent('tmkc-vehicleshop:client:buyShowroomVehicle', src, vehicle, plate)
        pData.Functions.RemoveMoney('bank', financeInstallment, "vehicle-financed-in-showroom")
        TriggerEvent("tmkc-log:server:sendLog", cid, "vehiclebought", {model=vehicle, name=TMKC.Shared.Vehicles[vehicle]["name"], from="showroom", moneyType="bank", price=TMKC.Shared.Vehicles[vehicle]["price"], plate=plate})
        TriggerEvent("tmkc-log:server:CreateLog", "vehicleshop", "Vehicle bought (showroom)", "green", "**"..GetPlayerName(src) .. "** has bought " .. TMKC.Shared.Vehicles[vehicle]["name"] .. " one for $" .. TMKC.Shared.Vehicles[vehicle]["price"])
    else
        TriggerClientEvent("TMKC:Notify", src, "You don't have enough money, you are missing $"..format_thousand(financeInstallment - balance), "error", 5000)
    end
end)

Citizen.CreateThread(function()
    TMKC.Functions.ExecuteSql(false, "SELECT * FROM `player_vehicles`", function(result)
        if result[1] ~= nil then
            for k, v in pairs(result) do
                Player = TMKC.Functions.GetPlayerByCitizenId(v.citizenid)
                local VehicleData = TMKC.Shared.Vehicles[v.vehicle]
                if v.finance_owed ~= nil then
                	if Player ~= nil then
	                    if v.finance_owed > 0 then
	                        installment = ( VehicleData["price"] * 0.15)
	                        balance = Player.PlayerData.money["bank"]
	                        if (balance - installment >= 0) then
	                            TMKC.Functions.ExecuteSql(false, "UPDATE `player_vehicles` SET `finance_owed` = '"..v.finance_owed.."' - '"..installment.."' WHERE `plate` = '"..v.plate.."'")
	                            Player.Functions.RemoveMoney("bank",installment,'paid-finance')
	                        else
	                            TMKC.Functions.ExecuteSql(false, "DELETE FROM `player_vehicles` WHERE `plate` = '"..v.plate.."'")
	                        end
	                    elseif v.finance_owed < 0 then
	                        TMKC.Functions.ExecuteSql(false, "UPDATE `player_vehicles` SET `finance_owed` = 0 WHERE `plate` = '"..v.plate.."'")
	                    end
	                else
	                	TMKC.Functions.ExecuteSql(false, "SELECT * FROM `players` WHERE `citizenid` = '"..v.citizenid.."'", function(result)
	                		if result[1] ~= nil then
	                			if v.finance_owed > 0 then
	                				local installment = (vehicleData["price"] * 0.15)
	                				local NewBal = json.decode(result[1].money)
	                				NewBal.bank = NewBal.bank - installment
	                				if NewBal.bank >= 0 then
	                					TMKC.Functions.ExecuteSql(false,"UPDATE `players` SET `money` = '"..json.encode(NewBal).."' WHERE `citizenid` = '"..v.citizenid.."'")
	                					TMKC.Functions.ExecuteSql(false,"UDPATE `player_vehicles` SET `finance_owed` = '"..v.finance_owed.."' - '"..installment.."' WHERE `plate` = '"..v.plate.."'")
	                				else
	                					TMKC.Functions.ExecuteSql(false,"DELETE FROM `player_vehicles` WHERE `plate` = '"..v.plate.."'")
	                				end
	                			elseif v.finance_owed < 0 then 
	                				TMKC.Functions.ExecuteSql(false,"UPDATE `player_vehicles` SET `finance_owed` = 0 WHERE `plate` = '"..v.plate.."'")
	                			end
	                		end
	                	end)
	                end
                end
            end
        end
    end)
end)


function format_thousand(v)
    local s = string.format("%d", math.floor(v))
    local pos = string.len(s) % 3
    if pos == 0 then pos = 3 end
    return string.sub(s, 1, pos)
            .. string.gsub(string.sub(s, pos + 1), "(...)", ",%1")
end

function GeneratePlate()
    local plate = tostring(GetRandomNumber(1)) .. GetRandomLetter(2) .. tostring(GetRandomNumber(3)) .. GetRandomLetter(2)
    TMKC.Functions.ExecuteSql(true, "SELECT * FROM `player_vehicles` WHERE `plate` = '"..plate.."'", function(result)
        while (result[1] ~= nil) do
            plate = tostring(GetRandomNumber(1)) .. GetRandomLetter(2) .. tostring(GetRandomNumber(3)) .. GetRandomLetter(2)
        end
        return plate
    end)
    return plate:upper()
end

function GetRandomNumber(length)
	Citizen.Wait(1)
	math.randomseed(GetGameTimer())
	if length > 0 then
		return GetRandomNumber(length - 1) .. NumberCharset[math.random(1, #NumberCharset)]
	else
		return ''
	end
end

function GetRandomLetter(length)
	Citizen.Wait(1)
	math.randomseed(GetGameTimer())
	if length > 0 then
		return GetRandomLetter(length - 1) .. Charset[math.random(1, #Charset)]
	else
		return ''
	end
end

RegisterServerEvent('tmkc-vehicleshop:server:setShowroomCarInUse')
AddEventHandler('tmkc-vehicleshop:server:setShowroomCarInUse', function(showroomVehicle, bool)
    QB.ShowroomVehicles[showroomVehicle].inUse = bool
    TriggerClientEvent('tmkc-vehicleshop:client:setShowroomCarInUse', -1, showroomVehicle, bool)
end)

RegisterServerEvent('tmkc-vehicleshop:server:setShowroomVehicle')
AddEventHandler('tmkc-vehicleshop:server:setShowroomVehicle', function(vData, k)
    QB.ShowroomVehicles[k].chosenVehicle = vData
    TriggerClientEvent('tmkc-vehicleshop:client:setShowroomVehicle', -1, vData, k)
end)

RegisterServerEvent('tmkc-vehicleshop:server:SetCustomShowroomVeh')
AddEventHandler('tmkc-vehicleshop:server:SetCustomShowroomVeh', function(vData, k)
    QB.ShowroomVehicles[k].vehicle = vData
    TriggerClientEvent('tmkc-vehicleshop:client:SetCustomShowroomVeh', -1, vData, k)
end)

TMKC.Commands.Add("sellv", "Sell ​​vehicle from Custom Car Dealer", {}, false, function(source, args)
    local Player = TMKC.Functions.GetPlayer(source)
    local TargetId = args[1]

    if Player.PlayerData.job.name == "cardealer" then
        if TargetId ~= nil then
            TriggerClientEvent('tmkc-vehicleshop:client:SellCustomVehicle', source, TargetId)
        else
            TriggerClientEvent('TMKC:Notify', source, 'You must provide a Player ID!', 'error')
        end
    else
        TriggerClientEvent('TMKC:Notify', source, 'You are not a Vehicle Dealer', 'error')
    end
end)

TMKC.Commands.Add("testdrive", "Test Drive the car", {}, false, function(source, args)
    local Player = TMKC.Functions.GetPlayer(source)
    local TargetId = args[1]

    if Player.PlayerData.job.name == "cardealer" then
        TriggerClientEvent('tmkc-vehicleshop:client:DoTestrit', source, GeneratePlate())
    else
        TriggerClientEvent('TMKC:Notify', source, 'You are not a Vehicle Dealer', 'error')
    end
end)

TMKC.Commands.Add("financev", "Sell ​​vehicle from Custom Car Dealer", {}, false, function(source, args)
    local Player = TMKC.Functions.GetPlayer(source)
    local TargetId = args[1]

    if Player.PlayerData.job.name == "cardealer" then
        if TargetId ~= nil then
            TriggerClientEvent('tmkc-vehicleshop:client:FinanceCustomVehicle', source, TargetId)
        else
            TriggerClientEvent('TMKC:Notify', source, 'You must provide a Player ID!', 'error')
        end
    else
        TriggerClientEvent('TMKC:Notify', source, 'You are not a Vehicle Dealer', 'error')
    end
end)

RegisterServerEvent('tmkc-vehicleshop:server:SellCustomVehicle')
AddEventHandler('tmkc-vehicleshop:server:SellCustomVehicle', function(TargetId, ShowroomSlot)
    TriggerClientEvent('tmkc-vehicleshop:client:SetVehicleBuying', TargetId, ShowroomSlot)
end)

RegisterServerEvent('tmkc-vehicleshop:server:FinanceCustomVehicle')
AddEventHandler('tmkc-vehicleshop:server:FinanceCustomVehicle', function(TargetId, ShowroomSlot)
    TriggerClientEvent('tmkc-vehicleshop:client:SetVehicleFinance', TargetId, ShowroomSlot)
end)

RegisterServerEvent('tmkc-vehicleshop:server:ConfirmVehicle')
AddEventHandler('tmkc-vehicleshop:server:ConfirmVehicle', function(ShowroomVehicle)
    local src = source
    local Player = TMKC.Functions.GetPlayer(src)
    local VehPrice = TMKC.Shared.Vehicles[ShowroomVehicle.vehicle].price
    local plate = GeneratePlate()

    if Player.PlayerData.money.cash >= VehPrice then
        Player.Functions.RemoveMoney('cash', VehPrice)
        TriggerEvent("tmkc-moneysafe:server:Depositcardealer",VehPrice*0.2)
        TriggerClientEvent('tmkc-vehicleshop:client:ConfirmVehicle', src, ShowroomVehicle, plate)
        TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `state`) VALUES ('"..Player.PlayerData.steam.."', '"..Player.PlayerData.citizenid.."', '"..ShowroomVehicle.vehicle.."', '"..GetHashKey(ShowroomVehicle.vehicle).."', '{}', '"..plate.."', 0)")
    elseif Player.PlayerData.money.bank >= VehPrice then
        Player.Functions.RemoveMoney('bank', VehPrice)
        TriggerEvent("tmkc-moneysafe:server:Depositcardealer",VehPrice*0.2)
        TriggerClientEvent('tmkc-vehicleshop:client:ConfirmVehicle', src, ShowroomVehicle, plate)
        TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `state`) VALUES ('"..Player.PlayerData.steam.."', '"..Player.PlayerData.citizenid.."', '"..ShowroomVehicle.vehicle.."', '"..GetHashKey(ShowroomVehicle.vehicle).."', '{}', '"..plate.."', 0)")
    else
        if Player.PlayerData.money.cash > Player.PlayerData.money.bank then
            TriggerClientEvent('TMKC:Notify', src, 'You don\'t have enough money ... You are missing ('..(Player.PlayerData.money.cash - VehPrice)..',-)')
        else
            TriggerClientEvent('TMKC:Notify', src, 'You don\'t have enough money ... You are missing ('..(Player.PlayerData.money.bank - VehPrice)..',-)')
        end
    end
end)

RegisterNetEvent('tmkc-vehicleshop:server:ConfirmVehicleFinance')
AddEventHandler('tmkc-vehicleshop:server:ConfirmVehicleFinance', function(vehicle, class)
    local src = source
    local pData = TMKC.Functions.GetPlayer(src)
    local cid = pData.PlayerData.citizenid
    local balance = pData.PlayerData.money["bank"]
    local vehicleValue = TMKC.Shared.Vehicles[ShowroomVehicle.vehicle].price
    local financeInstallment = (vehicleValue * 0.15)
    local plate = GeneratePlate()

    if (balance - financeInstallment) >= 0 then
        TMKC.Functions.ExecuteSql(false, "INSERT INTO `player_vehicles` (`steam`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `state`,`finance_owed`) VALUES ('"..pData.PlayerData.steam.."', '"..cid.."', '"..ShowroomVehicle.vehicle.."', '"..GetHashKey(ShowroomVehicle.vehicle).."', '{}', '"..plate.."', 0, '"..vehicleValue.."')")
        TriggerClientEvent("TMKC:Notify", src, "Successful! Your vehicle is waiting for you outside.", "success", 5000)
        TriggerClientEvent('tmkc-vehicleshop:client:ConfirmVehicle', src, ShowroomVehicle, plate)
        pData.Functions.RemoveMoney('bank', financeInstallment, "vehicle-financed-in-showroom")
        TriggerEvent("tmkc-log:server:sendLog", cid, "vehiclebought", {model=vehicle, name=TMKC.Shared.Vehicles[ShowroomVehicle.vehicle]["name"], from="showroom", moneyType="bank", price=TMKC.Shared.Vehicles[ShowroomVehicle.vehicle]["price"], plate=plate})
        TriggerEvent("tmkc-log:server:CreateLog", "vehicleshop", "Vehicle bought (showroom)", "green", "**"..GetPlayerName(src) .. "** has bought " .. TMKC.Shared.Vehicles[ShowroomVehicle.vehicle]["name"] .. " one for $" .. TMKC.Shared.Vehicles[ShowroomVehicle.vehicle]["price"])
    else
        TriggerClientEvent("TMKC:Notify", src, "You don't have enough money, you are missing $"..format_thousand(financeInstallment - balance), "error", 5000)
    end
end)

TMKC.Functions.CreateCallback('tmkc-vehicleshop:server:SellVehicle', function(source, cb, vehicle, plate)
    local VehicleData = TMKC.Shared.VehicleModels[vehicle]
    local src = source
    local Player = TMKC.Functions.GetPlayer(src)

    TMKC.Functions.ExecuteSql(false, "SELECT * FROM `player_vehicles` WHERE `citizenid` = '"..Player.PlayerData.citizenid.."' AND `plate` = '"..plate.."'", function(result)
        if result[1] ~= nil then
            if result[1].finance_owed <= 0 then
                Player.Functions.AddMoney('bank', math.ceil(VehicleData["price"] / 100 * 60))
                TMKC.Functions.ExecuteSql(false, "DELETE FROM `player_vehicles` WHERE `citizenid` = '"..Player.PlayerData.citizenid.."' AND `plate` = '"..plate.."'")
                cb(true)
            else
                TriggerClientEvent("TMKC:Notify",src ,"This vehicle is on finance, it cannot be sold untill all payments are made", "error")
                cb(false)
            end
        else
            cb(false)
        end
    end)
end)