
local ESX = exports["es_extended"]:getSharedObject()
local PlayerData = {}
local vuilniswagen = nil
local isInDienst = false
local currentLevel = 1
local currentXP = 0
local currentRoute = {}
local currentContainerIndex = 1
local containerBlip = nil
local truckBlip = nil
local activeContainerLocaties = {}
local dumpsterProps = {}
local holdingTrashBag = false
local trashBagProp = nil
local containerTargets = {}
local truckTargetId = nil
local depositMarker = nil
local routeCompleted = false
local depositPaid = false
local truckInitialHealth = 1000.0
local truckCurrentHealth = 1000.0
local bagsCollected = 0
local pendingPayment = 0
local isDumping = false

CreateThread(function()
    while ESX.GetPlayerData().job == nil do
        Wait(100)
    end
    
    PlayerData = ESX.GetPlayerData()
    
    lib.callback('7-vuilnisman:getPlayerLevel', false, function(level, xp)
        currentLevel = level
        currentXP = xp
    end)
    
    if Config.UseBlips then
        local blip = AddBlipForCoord(Config.Startpunt.coords)
        SetBlipSprite(blip, Config.Startpunt.blip.sprite)
        SetBlipColour(blip, Config.Startpunt.blip.color)
        SetBlipScale(blip, Config.Startpunt.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Startpunt.blip.label)
        EndTextCommandSetBlipName(blip)
    end
    
    if Config.UseBlips then
        local depositBlip = AddBlipForCoord(Config.VoertuigVerwijder.coords)
        SetBlipSprite(depositBlip, 318)
        SetBlipColour(depositBlip, 1)
        SetBlipScale(depositBlip, 0.8)
        SetBlipAsShortRange(depositBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Text.deposit_point)
        EndTextCommandSetBlipName(depositBlip)
    end

    
    CreateVuilnismanPed()
    
    CreateDumpMarker()
    
    CreateDepositMarker()
end)

CreateThread(function()
    while true do
        Wait(1000)
        if isInDienst and holdingTrashBag and DoesEntityExist(vuilniswagen) then
            if not truckTargetId or not exports.ox_target:zoneExists(truckTargetId) then
                AddTargetToTruckBack()
            end
        end
        Wait(4000)
    end
end)

function CreateVuilnismanPed()
    local pedModel = `s_m_y_dockwork_01`
    lib.requestModel(pedModel, 5000)
    
    if not HasModelLoaded(pedModel) then
        return
    end
    
    local ped = CreatePed(4, pedModel, Config.Startpunt.coords.x, Config.Startpunt.coords.y, Config.Startpunt.coords.z - 1.0, 270.0, false, true)
    
    SetEntityHeading(ped, 270.0)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'vuilnisman_start',
            icon = 'fas fa-trash',
            label = 'Praat met Vuilnisman',
            onSelect = function()
                OpenVuilnismanMenu()
            end,
            distance = 2.0
        },
        {
            name = 'vuilnisman_sell_bags',
            icon = 'fas fa-dollar-sign',
            label = 'Lever vuilniszakken in',
            onSelect = function()
                SellTrashBags()
            end,
            distance = 2.0,
            canInteract = function()
                return isInDienst and bagsCollected > 0
            end
        }
    })
end

function SellTrashBags()
    if bagsCollected <= 0 then
        Notificatie('Je hebt geen vuilniszakken om in te leveren', 'error')
        return
    end
    
    local success = lib.progressBar({
        duration = 3000,
        label = 'Vuilniszakken inleveren...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        },
    })
    
    if success then
        local totalPayment = pendingPayment
        
        TriggerServerEvent('7-vuilnisman:dumpTrashBags', bagsCollected, totalPayment)
        
        Notificatie(string.format('Je hebt %d vuilniszakken ingeleverd en €%d verdiend!', bagsCollected, totalPayment), 'success')
        
        bagsCollected = 0
        pendingPayment = 0
        
        if containerBlip then
            SetBlipRoute(containerBlip, true)
        end
        
        SetDumpBlipActive(false)
    end
end

function CreateDepositMarker()
    depositMarker = exports.ox_target:addSphereZone({
        coords = Config.VoertuigVerwijder.coords,
        radius = Config.VoertuigVerwijder.radius,
        options = {
            {
                name = 'return_truck',
                icon = 'fas fa-truck',
                label = 'Lever vuilniswagen in',
                distance = 10.0,
                onSelect = function()
                    if routeCompleted then
                        VerwijderVuilniswagen()
                        if #currentRoute > 0 then
                            TriggerServerEvent('7-vuilnisman:routeVoltooid', currentLevel * 50)
                        end
                        GenerateRoute()
                        routeCompleted = false
                    else
                        VerwijderVuilniswagen()
                    end
                end,
                canInteract = function()
                    return isInDienst and DoesEntityExist(vuilniswagen) and IsPedInVehicle(PlayerPedId(), vuilniswagen, true)
                end
            }
        }
    })
end

function OpenVuilnismanMenu()
    if PlayerData.job.name ~= Config.JobName then
        Notificatie(Config.Text.wrong_job, 'error')
        return
    end
    
    local options = {}
    
    if not isInDienst then
        table.insert(options, {
            title = Config.Text.start_job,
            description = 'Begin met afval ophalen',
            icon = 'trash',
            onSelect = function()
                StartVuilnismanDienst()
            end
        })
    else
        if not DoesEntityExist(vuilniswagen) then
            table.insert(options, {
                title = Config.Text.get_truck,
                description = 'Haal de vuilniswagen',
                icon = 'truck',
                onSelect = function() 
                    SpawnVuilniswagen() 
                end
            })
        else
            table.insert(options, {
                title = Config.Text.return_truck,
                description = 'Lever de vuilniswagen in',
                icon = 'truck',
                onSelect = function() 
                    VerwijderVuilniswagen() 
                end
            })
        end
        
        if bagsCollected > 0 then
            table.insert(options, {
                title = 'Lever vuilniszakken in',
                description = string.format('Lever %d vuilniszakken in voor €%d', bagsCollected, pendingPayment),
                icon = 'dollar-sign',
                onSelect = function()
                    SellTrashBags()
                end
            })
        end
        
        table.insert(options, {
            title = Config.Text.stop_job,
            description = 'Stop met werken',
            icon = 'times',
            onSelect = function()
                StopVuilnismanDienst()
            end
        })
    end
    
    if Config.UseLevels then
        local levelInfo
        if currentLevel < Config.MaxLevel then
            levelInfo = string.format("Level: %d | XP: %d/%d", 
                currentLevel, 
                currentXP, 
                Config.LevelBeloningen[currentLevel].xpVoorVolgendLevel
            )
        else
            levelInfo = string.format("Level: %d (MAX)", currentLevel)
        end
        
        table.insert(options, {
            title = 'Jouw Niveau',
            description = levelInfo,
            icon = 'star',
            disabled = true
        })
    end

    lib.registerContext({
        id = 'vuilnisman_menu',
        title = Config.Text.menu_title,
        options = options
    })
    
    lib.showContext('vuilnisman_menu')
end

function StartVuilnismanDienst()
    isInDienst = true
    Notificatie(Config.Text.job_started, 'info')
    
    GenerateRoute()
end

function StopVuilnismanDienst()
    isInDienst = false
    RemoveAllContainerBlips()
    
    if DoesEntityExist(vuilniswagen) then
        if Config.UseDeposit and depositPaid then
            Notificatie('Je hebt je vuilniswagen niet ingeleverd! Je borg is verloren gegaan.', 'error')
            depositPaid = false
        end
        
        VerwijderVuilniswagen()
    end
    
    for _, prop in pairs(dumpsterProps) do
        if DoesEntityExist(prop) then
            DeleteObject(prop)
        end
    end
    
    for _, target in pairs(containerTargets) do
        exports.ox_target:removeZone(target)
    end
    
    dumpsterProps = {}
    containerTargets = {}
    
    RemoveTrashBagFromPlayer()
    
    Notificatie(Config.Text.job_ended, 'info')
end

function GenerateRoute()
    local routeSize = math.min(5 + currentLevel, 10)
    
    currentRoute = {}
    activeContainerLocaties = {}
    currentContainerIndex = 1
    RemoveAllContainerBlips()
    
    local allLocations = {}
    for i = 1, #Config.ContainerLocaties do
        table.insert(allLocations, i)
    end
    
    for i = 1, routeSize do
        if #allLocations == 0 then break end
        local randomIndex = math.random(1, #allLocations)
        local locationIndex = allLocations[randomIndex]
        
        table.insert(currentRoute, locationIndex)
        table.insert(activeContainerLocaties, Config.ContainerLocaties[locationIndex])
        
        table.remove(allLocations, randomIndex)
    end
    
    SpawnDumpsters()
    
    UpdateContainerBlip()
end

function SpawnDumpsters()
    for _, target in pairs(containerTargets) do
        exports.ox_target:removeZone(target)
    end
    
    for _, prop in pairs(dumpsterProps) do
        if DoesEntityExist(prop) then
            DeleteObject(prop)
        end
    end
    
    dumpsterProps = {}
    containerTargets = {}
    
    local dumpsterHash = GetHashKey(Config.DumpsterProp)
    
    lib.requestModel(dumpsterHash, 5000)
    
    for i, containerData in ipairs(activeContainerLocaties) do
        local coords = containerData.coords
        
        local dumpster = CreateObject(dumpsterHash, coords.x, coords.y, coords.z - 1.0, false, false, false)
        SetEntityHeading(dumpster, math.random(0, 359))
        PlaceObjectOnGroundProperly(dumpster)
        FreezeEntityPosition(dumpster, true)
        SetEntityAsMissionEntity(dumpster, true, true)
        
        dumpsterProps[i] = dumpster
        
        local targetId = exports.ox_target:addSphereZone({
            coords = coords,
            radius = 2.0,
            options = {
                {
                    name = 'collect_trash_' .. i,
                    icon = 'fas fa-trash',
                    label = Config.Text.collect_container,
                    distance = 3.0,
                    onSelect = function()
                        PickupTrashBag(i)
                    end,
                    canInteract = function()
                        if not isInDienst or not DoesEntityExist(vuilniswagen) or holdingTrashBag then
                            return false
                        end
                        
                        local playerPos = GetEntityCoords(PlayerPedId())
                        local truckPos = GetEntityCoords(vuilniswagen)
                        
                        if #(playerPos - truckPos) > 50.0 then
                            return false
                        end
                        
                        return i == currentContainerIndex
                    end
                }
            }
        })
        
        table.insert(containerTargets, targetId)
    end
    
    if DoesEntityExist(vuilniswagen) then
        AddTargetToTruckBack()
    end
end

function PickupTrashBag(containerIndex)
    if holdingTrashBag then
        Notificatie(Config.Text.holding_trash, 'error')
        return
    end
    
    local playerPos = GetEntityCoords(PlayerPedId())
    local truckPos = GetEntityCoords(vuilniswagen)
    
    if #(playerPos - truckPos) > 50.0 then
        Notificatie(Config.Text.truck_too_far, 'error')
        return
    end
    
    if containerIndex ~= currentContainerIndex then
        Notificatie('Volg de route in de juiste volgorde', 'error')
        return
    end
    
    local success = lib.progressBar({
        duration = Config.TrashPickupDuration,
        label = Config.Text.progress_collecting,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        },
    })
    
    if success then
        CreateTrashBagProp()
        holdingTrashBag = true
        
        local currentIndex = currentContainerIndex
        
        if dumpsterProps[currentIndex] and DoesEntityExist(dumpsterProps[currentIndex]) then
            DeleteObject(dumpsterProps[currentIndex])
            dumpsterProps[currentIndex] = nil
        end
        
        if containerTargets[currentIndex] then
            exports.ox_target:removeZone(containerTargets[currentIndex])
            containerTargets[currentIndex] = nil
        end
        
        AddTargetToTruckBack()
    end
end

function CreateTrashBagProp()
    local bagHash = GetHashKey(Config.TrashBagProp)
    
    lib.requestModel(bagHash, 5000)
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    trashBagProp = CreateObject(bagHash, coords.x, coords.y, coords.z - 1.0, true, true, true)
    
    AttachEntityToEntity(
        trashBagProp,
        playerPed,
        GetPedBoneIndex(playerPed, 57005),
        0.12, 0.0, 0.0,
        25.0, 270.0, 180.0,
        true, true, false, true, 1, true
    )
    
    local animDict = "missfbi4prepp1"
    local animName = "_idle_garbage_man"
    
    lib.requestAnimDict(animDict, 1000)
    
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
end

function RemoveTrashBagFromPlayer()
    ClearPedTasks(PlayerPedId())
    
    if trashBagProp and DoesEntityExist(trashBagProp) then
        DeleteObject(trashBagProp)
        trashBagProp = nil
    end
    
    holdingTrashBag = false
end

function PlaceTrashBagInTruck()
    if not holdingTrashBag then
        Notificatie(Config.Text.need_trash_bag, 'error')
        return
    end
    
    local success = lib.progressBar({
        duration = Config.TrashDropDuration,
        label = Config.Text.progress_dropping,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        }
    })
    
    if success then
        RemoveTrashBagFromPlayer()
        
        bagsCollected = bagsCollected + 1
        
        local betaling = Config.LevelBeloningen[currentLevel].baseLoon
        pendingPayment = pendingPayment + betaling
        
        local xp = Config.LevelBeloningen[currentLevel].xpPerContainer
        TriggerServerEvent('7-vuilnisman:addXP', xp)
        
        Notificatie(string.format(Config.Text.container_collected, xp), 'success')
        
        if bagsCollected >= Config.MaxBagsBeforeDump then
            Notificatie(Config.Text.dump_required, 'info')
            SetDumpBlipActive(true)
        else
            currentContainerIndex = currentContainerIndex + 1
            
            if currentContainerIndex > #currentRoute then
                Notificatie(Config.Text.collected_all, 'success')
                routeCompleted = true
                SetDepositBlipRoute()
                RemoveAllContainerBlips()
            else
                UpdateContainerBlip()
                
                if not containerTargets[currentContainerIndex] then
                    SpawnDumpsters()
                end
            end
        end
    end
end

function SetDumpBlipActive(active)
    if dumpBlip then
        SetBlipRoute(dumpBlip, active)
        SetBlipRouteColour(dumpBlip, 1)
    end
    
    if containerBlip and active then
        SetBlipRoute(containerBlip, false)
    elseif containerBlip and not active then
        SetBlipRoute(containerBlip, true)
    end
end

function StopVuilnismanDienst()
    isInDienst = false
    RemoveAllContainerBlips()
    SetDumpBlipActive(false)
    
    if DoesEntityExist(vuilniswagen) then
        if Config.UseDeposit and depositPaid then
            Notificatie('Je hebt je vuilniswagen niet ingeleverd! Je borg is verloren gegaan.', 'error')
            depositPaid = false
        end
        
        VerwijderVuilniswagen()
    end
    
    for _, prop in pairs(dumpsterProps) do
        if DoesEntityExist(prop) then
            DeleteObject(prop)
        end
    end
    
    for _, target in pairs(containerTargets) do
        exports.ox_target:removeZone(target)
    end
    
    dumpsterProps = {}
    containerTargets = {}
    
    bagsCollected = 0
    pendingPayment = 0
    
    RemoveTrashBagFromPlayer()
    
    Notificatie(Config.Text.job_ended, 'info')
end

function SetDepositBlipRoute()
    if containerBlip then
        RemoveBlip(containerBlip)
    end
    
    containerBlip = AddBlipForCoord(Config.VoertuigVerwijder.coords)
    SetBlipSprite(containerBlip, 318)
    SetBlipColour(containerBlip, 1)
    SetBlipScale(containerBlip, 0.8)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Text.deposit_point)
    EndTextCommandSetBlipName(containerBlip)
    
    SetBlipRoute(containerBlip, true)
    SetBlipRouteColour(containerBlip, 1)
end

function AddTargetToTruckBack()
    if not DoesEntityExist(vuilniswagen) then return end
    
    if truckTargetId then
        exports.ox_target:removeZone(truckTargetId)
        truckTargetId = nil
    end
    
    local offset = GetOffsetFromEntityInWorldCoords(vuilniswagen, 0.0, -3.5, 1.0)
    
    truckTargetId = exports.ox_target:addSphereZone({
        coords = offset,
        radius = 5.0,
        options = {
            {
                name = 'place_trash_in_truck',
                icon = 'fas fa-trash',
                label = Config.Text.place_in_truck,
                distance = 6.0,
                onSelect = function()
                    PlaceTrashBagInTruck()
                end,
                canInteract = function()
                    return isInDienst and holdingTrashBag
                end
            }
        }
    })
    
end

function UpdateContainerBlip()
    if containerBlip then
        RemoveBlip(containerBlip)
    end
    
    if currentContainerIndex <= #activeContainerLocaties then
        local containerData = activeContainerLocaties[currentContainerIndex]
        containerBlip = AddBlipForCoord(containerData.coords)
        
        SetBlipSprite(containerBlip, 318)
        SetBlipColour(containerBlip, 2)
        SetBlipScale(containerBlip, 0.8)
        SetBlipAsShortRange(containerBlip, false)
        
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Text.container_blip)
        EndTextCommandSetBlipName(containerBlip)
        
        SetBlipRoute(containerBlip, true)
        SetBlipRouteColour(containerBlip, 2)
    end
end

function RemoveAllContainerBlips()
    if containerBlip then
        RemoveBlip(containerBlip)
        containerBlip = nil
    end
end

function SpawnVuilniswagen()
    if DoesEntityExist(vuilniswagen) then
        Notificatie('Je hebt al een vuilniswagen', 'error')
        return
    end
    
    if Config.UseDeposit then
        lib.callback('7-vuilnisman:checkDeposit', false, function(canPay)
            if canPay then
                TriggerServerEvent('7-vuilnisman:payDeposit', Config.DepositAmount)
                depositPaid = true
                
                DoSpawnVuilniswagen()
            else
                
                Notificatie(string.format(Config.Text.not_enough_money, Config.DepositAmount), 'error')
            end
        end)
    else
        DoSpawnVuilniswagen()
    end
end

function DoSpawnVuilniswagen()
    local model = GetHashKey(Config.Voertuig)
    lib.requestModel(model, 5000)
    
    if not HasModelLoaded(model) then
        Notificatie('Voertuig model kan niet geladen worden', 'error')
        return
    end
    
    local coords = Config.VoertuigSpawn.coords
    local heading = coords.w
    
    local spawnRadius = Config.VoertuigSpawn.spawnRadius
    local isClear = IsSpawnPointClear(vec3(coords.x, coords.y, coords.z), spawnRadius)
    
    if not isClear then
        Notificatie('Spawnpunt is geblokkeerd', 'error')
        return
    end
    
    vuilniswagen = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
    
    SetVehicleOnGroundProperly(vuilniswagen)
    SetEntityAsMissionEntity(vuilniswagen, true, true)
    SetVehicleHasBeenOwnedByPlayer(vuilniswagen, true)
    SetVehicleDirtLevel(vuilniswagen, 0.0)
    
    truckInitialHealth = GetEntityHealth(vuilniswagen)
    truckCurrentHealth = truckInitialHealth
    
    if Config.UseBlips then
        truckBlip = AddBlipForEntity(vuilniswagen)
        SetBlipSprite(truckBlip, 318)
        SetBlipColour(truckBlip, 43)
        SetBlipAsShortRange(truckBlip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Text.truck_blip)
        EndTextCommandSetBlipName(truckBlip)
    end
    
    Notificatie(Config.Text.truck_spawned, 'success')
    
    AddTargetToTruckBack()
    
    if #currentRoute == 0 then
        GenerateRoute()
    else
        SpawnDumpsters()
    end
    
    if Config.UseDeposit and Config.DepositFeeOnDamage then
        CreateThread(function()
            while DoesEntityExist(vuilniswagen) do
                truckCurrentHealth = GetEntityHealth(vuilniswagen)
                Wait(1000)
            end
        end)
    end
end


function VerwijderVuilniswagen()
    if DoesEntityExist(vuilniswagen) then
        local vehicleCoords = GetEntityCoords(vuilniswagen)
        local depositPoint = Config.VoertuigVerwijder.coords
        
        if #(vehicleCoords - depositPoint) <= Config.VoertuigVerwijder.radius then
            if Config.UseDeposit and depositPaid then
                if Config.DepositFeeOnDamage then
                    local damagePercent = (1 - (truckCurrentHealth / truckInitialHealth)) * 100
                    
                    if damagePercent > 5 then
                        local deduction = math.floor(Config.DepositAmount * (Config.DamageFeePct / 100))
                        local returnAmount = Config.DepositAmount - deduction
                        
                        Notificatie(string.format(Config.Text.truck_damaged, Config.DamageFeePct), 'warn')
                        
                        TriggerServerEvent('7-vuilnisman:returnDeposit', returnAmount, deduction)
                    else
                        TriggerServerEvent('7-vuilnisman:returnDeposit', Config.DepositAmount, 0)
                    end
                else
                    TriggerServerEvent('7-vuilnisman:returnDeposit', Config.DepositAmount, 0)
                end
                
                depositPaid = false
            end
            
            if truckTargetId then
                exports.ox_target:removeZone(truckTargetId)
                truckTargetId = nil
            end
            
            DeleteVehicle(vuilniswagen)
            vuilniswagen = nil
            
            if truckBlip then
                RemoveBlip(truckBlip)
                truckBlip = nil
            end
            
            RemoveTrashBagFromPlayer()
            
            Notificatie(Config.Text.truck_returned, 'success')
        else
            Notificatie('Ga naar het inleverpunt om de vuilniswagen in te leveren', 'error')
        end
    else
        Notificatie('Je hebt geen vuilniswagen', 'error')
    end
end


function IsSpawnPointClear(coords, radius)
    local vehicles = GetGamePool('CVehicle')
    
    for i = 1, #vehicles do
        local vehicleCoords = GetEntityCoords(vehicles[i])
        local distance = #(vehicleCoords - coords)
        
        if distance < radius then
            return false
        end
    end
    
    return true
end

RegisterNetEvent('7-vuilnisman:levelUp')
AddEventHandler('7-vuilnisman:levelUp', function(newLevel)
    currentLevel = newLevel
    Notificatie(string.format(Config.Text.level_up, newLevel), 'success')
end)

RegisterNetEvent('7-vuilnisman:updateXP')
AddEventHandler('7-vuilnisman:updateXP', function(xp, xpForNext, nextLevel)
    currentXP = xp
    
    if nextLevel then
        Notificatie(string.format(Config.Text.xp_gained, xp, currentXP, xpForNext, nextLevel), 'info')
    else
        Notificatie(Config.Text.max_level, 'info')
    end
end)

function Notificatie(msg, type)
    if msg == nil then
        msg = "Error: Missing notification text"
    end
    
    if Config.NotificationType == 'ox_lib' then
        lib.notify({
            title = 'Vuilnisdienst',
            description = msg,
            type = type
        })
    elseif Config.NotificationType == 'esx' then
        ESX.ShowNotification(msg)
    end
end

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
    
    if PlayerData.job.name ~= Config.JobName and isInDienst then
        StopVuilnismanDienst()
    end
end)