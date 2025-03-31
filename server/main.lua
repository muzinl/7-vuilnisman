local ESX = exports["es_extended"]:getSharedObject()

function GetPlayerLevelData(identifier)
    local result = MySQL.Sync.fetchAll('SELECT * FROM vuilnisman_levels WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })
    
    if result[1] then
        return result[1]
    else
        MySQL.Sync.execute('INSERT INTO vuilnisman_levels (identifier, level, xp) VALUES (@identifier, 1, 0)', {
            ['@identifier'] = identifier
        })
        
        return {level = 1, xp = 0}
    end
end


function UpdatePlayerLevelData(identifier, level, xp)
    MySQL.Async.execute('UPDATE vuilnisman_levels SET level = @level, xp = @xp WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
        ['@level'] = level,
        ['@xp'] = xp
    })
end


lib.callback.register('7-vuilnisman:checkDeposit', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        return false
    end
    
    return xPlayer.getMoney() >= Config.DepositAmount
end)


lib.callback.register('7-vuilnisman:getPlayerLevel', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        return 1, 0
    end
    
    local levelData = GetPlayerLevelData(xPlayer.identifier)
    return levelData.level, levelData.xp
end)

RegisterNetEvent('7-vuilnisman:routeVoltooid')
AddEventHandler('7-vuilnisman:routeVoltooid', function(bonus)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    if xPlayer.job.name ~= Config.JobName then
        -- Potentiële cheater
        return
    end

    local levelData = GetPlayerLevelData(xPlayer.identifier)
    local routeBonus = math.floor(bonus * (1 + (levelData.level * 0.1)))
    
    xPlayer.addMoney(routeBonus)

    TriggerClientEvent('7-vuilnisman:notification', src, string.format('Route bonus: €%s', routeBonus), 'success')
    
    local xpBonus = math.floor(bonus / 5)
    AddXP(xPlayer, xpBonus)
end)

function AddXP(xPlayer, xpAmount)
    if not Config.UseLevels then return end
    
    local identifier = xPlayer.identifier
    local levelData = GetPlayerLevelData(identifier)
    local currentLevel = levelData.level
    local currentXP = levelData.xp
    
    if currentLevel >= Config.MaxLevel then
        TriggerClientEvent('7-vuilnisman:notification', xPlayer.source, Config.Text.max_level, 'info')
        return
    end
    
    local newXP = currentXP + xpAmount
    local newLevel = currentLevel
    local leveledUp = false
    
    while newLevel < Config.MaxLevel do
        local xpForNextLevel = Config.LevelBeloningen[newLevel].xpVoorVolgendLevel
        
        if newXP >= xpForNextLevel then
            newXP = newXP - xpForNextLevel
            newLevel = newLevel + 1
            leveledUp = true
        else
            break
        end
    end

    UpdatePlayerLevelData(identifier, newLevel, newXP)

    if leveledUp then
        TriggerClientEvent('7-vuilnisman:levelUp', xPlayer.source, newLevel)
    else
        local xpForNextLevel = Config.LevelBeloningen[newLevel].xpVoorVolgendLevel
        TriggerClientEvent('7-vuilnisman:xpUpdate', xPlayer.source, xpAmount, newXP, xpForNextLevel, newLevel + 1)
    end
    
    return newLevel, newXP
end

RegisterNetEvent('7-vuilnisman:claimLevelUpReward')
AddEventHandler('7-vuilnisman:claimLevelUpReward', function(level)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    local levelData = GetPlayerLevelData(xPlayer.identifier)
    
    if levelData.level ~= level then
        -- cheater
        return
    end
    
    local reward = level * 1000
    
    xPlayer.addMoney(reward)
    
    TriggerClientEvent('7-vuilnisman:notification', src, string.format('Level %s beloning: €%s', level, reward), 'success')
end)

ESX.RegisterCommand('vuilnismansetlevel', 'admin', function(xPlayer, args, showError)
    local targetPlayer = args.playerId
    local newLevel = args.level
    
    if newLevel < 1 or newLevel > Config.MaxLevel then
        return showError('Level moet tussen 1 en ' .. Config.MaxLevel .. ' zijn')
    end
    
    local xTarget = ESX.GetPlayerFromId(targetPlayer)
    
    if not xTarget then
        return showError('Speler niet gevonden')
    end
    
    UpdatePlayerLevelData(xTarget.identifier, newLevel, 0)
    
    xPlayer.showNotification(string.format('Je hebt %s\'s level aangepast naar %s', xTarget.getName(), newLevel))
    xTarget.showNotification(string.format('Je vuilnisman level is aangepast naar %s', newLevel))
    
    TriggerClientEvent('7-vuilnisman:syncLevel', xTarget.source, newLevel, 0)
    
end, true, {help = 'Zet vuilnisman level van een speler', validate = true, arguments = {
    {name = 'playerId', help = 'Speler ID', type = 'player'},
    {name = 'level', help = 'Nieuw level (1-' .. Config.MaxLevel .. ')', type = 'number'}
}})

lib.callback.register('7-vuilnisman:getConfig', function(source)
    return Config
end)


RegisterNetEvent('7-vuilnisman:logActivity')
AddEventHandler('7-vuilnisman:logActivity', function(activityType)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
end)

RegisterNetEvent('7-vuilnisman:payDeposit')
AddEventHandler('7-vuilnisman:payDeposit', function(amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then
        return
    end
    
    if xPlayer.getMoney() < amount then
        TriggerClientEvent('7-vuilnisman:notification', src, string.format(Config.Text.not_enough_money, amount), 'error')
        return
    end
    

    xPlayer.removeMoney(amount)
    
    TriggerClientEvent('7-vuilnisman:notification', src, string.format(Config.Text.deposit_paid, amount), 'info')
end)


RegisterNetEvent('7-vuilnisman:returnDeposit')
AddEventHandler('7-vuilnisman:returnDeposit', function(returnAmount, deductionAmount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then
        return
    end
    
    xPlayer.addMoney(returnAmount)
    
    if deductionAmount > 0 then
        TriggerClientEvent('7-vuilnisman:notification', src, string.format(Config.Text.deposit_partially_returned, returnAmount, deductionAmount), 'info')
    else
        TriggerClientEvent('7-vuilnisman:notification', src, string.format(Config.Text.deposit_returned, returnAmount), 'success')
    end
end)

RegisterNetEvent('7-vuilnisman:dumpTrashBags')
AddEventHandler('7-vuilnisman:dumpTrashBags', function(bagCount, totalPayment)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    if xPlayer.job.name ~= Config.JobName then
    -- cheater
        return
    end
    
    xPlayer.addMoney(totalPayment)
    
end)


RegisterNetEvent('7-vuilnisman:addXP')
AddEventHandler('7-vuilnisman:addXP', function(xpAmount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    

    if xPlayer.job.name ~= Config.JobName then
        -- cheater
        return
    end
    
    AddXP(xPlayer, xpAmount)
end)