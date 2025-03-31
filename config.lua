Config = {}

-- Algemene instellingen
Config.JobName = 'vuilnisman'
Config.LevelXPMultiplier = 1.25  -- XP multiplier per level (maakt het moeilijker om hogere levels te bereiken)
Config.UseBlips = true
Config.UseLevels = true
Config.MaxLevel = 10

-- UI Instellingen
Config.NotificationType = 'ox_lib'  -- 'esx' of 'ox_lib'

-- Voertuig instellingen
Config.Voertuig = 'trash2'  -- Updated vehicle model to trash2
Config.VoertuigSpawn = {
    coords = vec4(-366.7759, -1558.7223, 25.3583, 17.7156), -- Updated vehicle spawn coordinates
    spawnRadius = 5.0
}

Config.VoertuigVerwijder = {
    coords = vec3(-335.80, -1564.80, 24.23),
    radius = 5.0
}

--Afval stortplaats Instellingen
Config.MaxBagsBeforeDump = 20  -- Number of trash bags before requiring a dump
Config.BagsCollected = 0       -- Initialize counter

-- Borg instellingen
Config.UseDeposit = true  -- Borg systeem aan/uit
Config.DepositAmount = 1000  -- Bedrag van de borg
Config.DepositFeeOnDamage = true  -- Hef een bedrag op beschadiging van de truck
Config.DamageFeePct = 25  -- Percentage van de borg dat ingehouden wordt bij schade (25%)

-- Startlocatie
Config.Startpunt = {
    coords = vec3(-349.80, -1569.80, 25.23),
    blip = {
        sprite = 318,
        color = 43,
        scale = 0.8,
        label = "Vuilnisdienst"
    }
}

-- Props en animaties
Config.DumpsterProp = 'm23_2_prop_m32_dumpster_01a'  -- Dumpster model
Config.TrashBagProp = 'prop_cs_rub_binbag_01'  -- Trash bag model
Config.TrashPickupDuration = 3000  -- Milliseconden voor het oprapen van een vuilniszak
Config.TrashDropDuration = 2000    -- Milliseconden voor het plaatsen van een vuilniszak

-- Level beloningen
Config.LevelBeloningen = {
    [1] = {
        baseLoon = 250,    -- Basis loon per container
        xpPerContainer = 10, -- XP per container
        xpVoorVolgendLevel = 100 -- XP nodig voor level 2
    },
    [2] = {
        baseLoon = 300,
        xpPerContainer = 15,
        xpVoorVolgendLevel = 250
    },
    [3] = {
        baseLoon = 350,
        xpPerContainer = 20,
        xpVoorVolgendLevel = 500
    },
    [4] = {
        baseLoon = 400,
        xpPerContainer = 25,
        xpVoorVolgendLevel = 1000
    },
    [5] = {
        baseLoon = 450,
        xpPerContainer = 30,
        xpVoorVolgendLevel = 2000
    },
    [6] = {
        baseLoon = 500,
        xpPerContainer = 35,
        xpVoorVolgendLevel = 4000
    },
    [7] = {
        baseLoon = 550,
        xpPerContainer = 40,
        xpVoorVolgendLevel = 8000
    },
    [8] = {
        baseLoon = 600,
        xpPerContainer = 45,
        xpVoorVolgendLevel = 16000
    },
    [9] = {
        baseLoon = 650,
        xpPerContainer = 50,
        xpVoorVolgendLevel = 32000
    },
    [10] = {
        baseLoon = 750,
        xpPerContainer = 60,
        xpVoorVolgendLevel = nil -- Max level
    }
}

-- Locaties waar containers opgehaald kunnen worden
Config.ContainerLocaties = {
    -- Richman gebied
    {coords = vec3(-123.7841, -1772.1863, 29.8223)},
    {coords = vec3(-15.5088, -1821.1632, 25.7816)},
    {coords = vec3(177.4054, -1830.1359, 28.1234)}
}

-- Localizatie
Config.Text = {
    menu_title = "Vuilnisman Job",
    start_job = "Start werkdag",
    stop_job = "Stop werkdag",
    get_truck = "Haal vuilniswagen",
    return_truck = "Lever vuilniswagen in",
    progress_collecting = "Vuilniszak oprapen...",
    progress_dropping = "Vuilniszak in container plaatsen...",
    truck_blip = "Vuilniswagen",
    container_blip = "Afvalcontainer",
    deposit_point = "Stortplaats",
    collect_container = "Doorzoek de vuilnisbak",
    place_in_truck = "Zet de vuilniszak vrachtwagen",
    job_started = "Je hebt je dienst gestart. Haal een vuilniswagen op!",
    job_ended = "Je hebt je dienst beëindigd",
    truck_spawned = "Vuilniswagen is afgeleverd",
    truck_returned = "Vuilniswagen is ingeleverd",
    truck_needed = "Je hebt een vuilniswagen nodig",
    level_up = "Je bent nu level %s!",
    xp_gained = "+%s XP | %s/%s XP naar Level %s",
    payment_received = "Je hebt €%s ontvangen",
    max_level = "Je bent al op het maximale level!",
    container_collected = "Vuilniszak geplaatst! +%s XP",
    holding_trash = "Je hebt al een vuilniszak vast",
    collected_all = "Je hebt alle containers verzameld! Ga terug naar de stortplaats",
    not_in_truck = "Je moet in de vuilniswagen zitten",
    truck_too_far = "De vuilniswagen is te ver weg",
    wrong_job = "Je werkt niet als vuilnisman",
    need_trash_bag = "Je moet eerst een vuilniszak oppakken",
    truck_damaged = "Je voertuig is beschadigd. %d%% van je borg wordt ingehouden.",
    deposit_paid = "Je hebt €%d borg betaald.",
    not_enough_money = "Je hebt niet genoeg geld. Je hebt €%d nodig.",
    deposit_returned = "Je borg van €%d is terugbetaald.",
    deposit_partially_returned = "€%d van je borg is terugbetaald. €%d is ingehouden vanwege schade.",
    dump_required = "Je vuilniswagen zit vol! Ga naar de stortplaats om te legen.",
    dump_bags = "Afval storten",
    dumping_progress = "Vuilnis wordt gestort...",
    bags_dumped = "Je hebt %d zakken afval gestort en €%d ontvangen.",
    no_bags_to_dump = "Je hebt geen vuilniszakken om te dumpen"
}
