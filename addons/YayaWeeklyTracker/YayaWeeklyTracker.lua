local addonName = ...

local JARD_SPELL_ID = 139176
local NZOTH_UNLOCK_QUEST_ID = 56542
local VICTORY_IN_OUR_NAME_QUEST_ID = 63622
local CONTAINING_THE_HELSWORN_QUEST_ID = 64273
local CONTAINING_THE_HELSWORN_LABEL = "Containing the Helsworn"
local NYALOTHA_MAP_ID = 10522
local GOLD_2000_REWARD_COPPER = 2000 * 10000
local LEGENDARY_CLOAK_ITEM_ID = 169223
local CURRENCY_WAR_RESOURCES = 1560
local CURRENCY_CORRUPTED_MEMENTOS = 1719
local CURRENCY_COALESCING_VISIONS = 1755
local UNLOCK_WORLD_QUESTS_ALLIANCE_QUEST_IDS = {
    51918,
    52450,
}
local UNLOCK_WORLD_QUESTS_HORDE_QUEST_IDS = {
    51916,
    52451,
}
local NAZJATAR_INTRO_QUEST_IDS = {
    54972, -- The Wolf's Offensive
    55053, -- The Warchief's Order
    56031, -- A Way Home (Alliance)
    56030, -- A Way Home (Horde)
}
local NAZJATAR_INTRO_COMPLETION_QUEST_IDS = {
    56031,
    56030,
}
local HARNESSING_THE_POWER_QUEST_ID = 57010
local AN_UNWELCOME_ADVISOR_QUEST_ID = 58496
local RETURN_OF_THE_WARRIOR_KING_QUEST_ID = 58498
local RETURN_OF_THE_BLACK_PRINCE_QUEST_ID = 58582
local WHERE_THE_HEART_IS_QUEST_ID = 58502
local NETWORK_DIAGNOSTICS_QUEST_ID = 58506
local A_TITANIC_PROBLEM_QUEST_ID = 56374
local THE_HALLS_OF_ORIGINATION_QUEST_ID = 56209
local TO_RAMKAHEN_QUEST_ID = 56375
local THE_ULDUM_ACCORD_QUEST_ID = 56472
local SURFACING_THREATS_QUEST_ID = 56376
local CURIOUS_CORRUPTION_QUEST_ID = 58991
local FORGING_ONWARD_QUEST_ID = 56377
local ITS_NEVER_EASY_QUEST_ID = 56536
local THE_MYSTERIOUS_SIGIL_QUEST_ID = 56537
local CLANS_OF_THE_MOGU_QUEST_ID = 56538
local FINDING_THE_RAJANI_QUEST_ID = 56539
local TIME_LOST_WARRIORS_QUEST_ID = 56771
local MARK_OF_THE_CONQUERORS_QUEST_ID = 58422
local PROOF_OF_TENACITY_QUEST_ID = 56540
local THE_ENGINE_OF_NALAKSHA_QUEST_ID = 56541
local MAGNIS_FINDINGS_QUEST_ID = 58737
local POWER_PROTOCOL_INITIATION_QUEST_ID = 57220
local RE_ORIGINATION_QUEST_ID = 57221
local INVESTIGATING_THE_HALLS_QUEST_ID = 57222
local BEGINNING_THE_DESCENT_QUEST_ID = 57290
local REMNANTS_OF_A_SHATTERED_WORLD_QUEST_ID = 57378
local DEEPER_INTO_THE_DARKNESS_QUEST_ID = 57362
local OPENING_THE_GATEWAY_QUEST_ID = 58634
local DESCENDING_INTO_MADNESS_QUEST_ID = 57373
local INTO_THE_DARKEST_DEPTHS_QUEST_ID = 57374
local WHISPERS_IN_THE_DARK_QUEST_ID = 58615
local INTO_DREAMS_QUEST_ID = 58631
local CORRUPTORS_END_QUEST_ID = 58632
local ACCESSING_THE_ARCHIVES_QUEST_ID = 57524
local CHASING_MADNESS_QUEST_ID = 57405
local LEGION_ARCHAEOLOGY_GOLD_LABEL = "Archeo Legion 5000g dispo"
local LEGION_ARCHAEOLOGY_GOLD_ROTATION_DAYS = 13 * 14
local LEGION_ARCHAEOLOGY_GOLD_WINDOW_DAYS = 14
local MOXIE_WARNING_THRESHOLD = 600
local MIDNIGHT_UNALLOYED_ABUNDANCE_CURRENCY_ID = 3377
local MIDNIGHT_KNOWLEDGE_BOOK_MOXIE_COST = 75
local MIDNIGHT_KNOWLEDGE_BOOK_ABUNDANCE_COST = 1600
local MIDNIGHT_RECIPE_MOXIE_COST = 150
local LEGION_ARCHAEOLOGY_GOLD_EU_START_DATE = {
    year = 2025,
    month = 4,
    day = 2,
}
local LEGION_ARCHAEOLOGY_GOLD_QUEST_IDS = {
    41174, -- Worth Its Weight
    41175, -- Fit for an Elven Queen
    41176, -- Sifting Through the Rubble
}

local MIDNIGHT_PROFESSION_CONFIGS = {
    [2906] = {
        order = 1,
        label = "Alch",
        weeklyLootQuestIDs = { 93528, 93529 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93690 },
        treatiseMinSkill = 25,
        darkmoonQuestID = 29506,
        treasureQuestIDs = { 89115, 89117, 89114, 89116, 89113, 89112, 89111, 89118 },
    },
    [2907] = {
        order = 2,
        label = "BS",
        weeklyLootQuestIDs = { 93530, 93531 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93691 },
        treatiseMinSkill = 25,
        darkmoonQuestID = 29508,
        treasureQuestIDs = { 89183, 89184, 89177, 89180, 89178, 89179, 89182, 89181 },
    },
    [2909] = {
        order = 3,
        label = "Ench",
        weeklyLootQuestIDs = { 93532, 93533 },
        weeklyDisenchantQuestIDs = { 95048, 95049, 95050, 95051, 95052, 95053 },
        trainerMinSkill = 25,
        trainerWeeklyQuestIDs = { 93697, 93698, 93699 },
        treatiseMinSkill = 25,
        darkmoonQuestID = 29510,
        treasureQuestIDs = { 89107, 89106, 89104, 89102, 89100, 89105, 89103, 89101 },
    },
    [2910] = {
        order = 4,
        label = "Eng",
        weeklyLootQuestIDs = { 93534, 93535 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93692 },
        treatiseMinSkill = 25,
        darkmoonQuestID = 29511,
        treasureQuestIDs = { 89139, 89133, 89135, 89138, 89140, 89136, 89137, 89134 },
    },
    [2912] = {
        order = 5,
        label = "Herb",
        gathering = true,
        weeklyKnowledgeCap = 6,
        weeklyLootQuestIDs = { 81425, 81426, 81427, 81428, 81429, 81430 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93700, 93702, 93703, 93704 },
        darkmoonQuestID = 29514,
        treasureQuestIDs = { 89160, 89158, 89161, 89157, 89162, 89159, 89155, 89156 },
    },
    [2913] = {
        order = 6,
        label = "Insc",
        weeklyLootQuestIDs = { 93536, 93537 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93693 },
        treatiseMinSkill = 25,
        darkmoonQuestID = 29515,
        treasureQuestIDs = { 89073, 89074, 89069, 89068, 89070, 89071, 89067, 89072 },
    },
    [2914] = {
        order = 7,
        label = "JC",
        weeklyLootQuestIDs = { 93538, 93539 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93694 },
        treatiseMinSkill = 25,
        darkmoonQuestID = 29516,
        treasureQuestIDs = { 89122, 89127, 89125, 89129, 89123, 89128, 89126, 89124 },
    },
    [2915] = {
        order = 8,
        label = "LW",
        weeklyLootQuestIDs = { 93540, 93541 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93695 },
        treatiseMinSkill = 25,
        darkmoonQuestID = 29517,
        treasureQuestIDs = { 89096, 89092, 89089, 89095, 89090, 89091, 89094, 89093 },
    },
    [2916] = {
        order = 9,
        label = "Mine",
        gathering = true,
        weeklyKnowledgeCap = 6,
        weeklyLootQuestIDs = { 88673, 88674, 88675, 88676, 88677, 88678 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93705, 93706, 93707, 93708, 93709 },
        darkmoonQuestID = 29518,
        treasureQuestIDs = { 89147, 89145, 89151, 89149, 89150, 89148, 89146, 89144 },
    },
    [2917] = {
        order = 10,
        label = "Skin",
        gathering = true,
        weeklyKnowledgeCap = 6,
        weeklyLootQuestIDs = { 88534, 88549, 88537, 88536, 88530, 88529 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93710, 93711, 93712, 93713, 93714 },
        darkmoonQuestID = 29519,
        treasureQuestIDs = { 89171, 89173, 89170, 89172, 89167, 89168, 89166, 89169 },
    },
    [2918] = {
        order = 11,
        label = "Tail",
        weeklyLootQuestIDs = { 93542, 93543 },
        trainerMinSkill = 1,
        trainerWeeklyQuestIDs = { 93696 },
        treatiseMinSkill = 25,
        darkmoonQuestID = 29520,
        treasureQuestIDs = { 89079, 89084, 89085, 89080, 89078, 89081, 89082, 89083 },
    },
}

local MIDNIGHT_MOXIE_CURRENCY_IDS = {
    [2906] = 3256, -- Alchemy
    [2907] = 3257, -- Blacksmithing
    [2909] = 3258, -- Enchanting
    [2910] = 3259, -- Engineering
    [2912] = 3260, -- Herbalism
    [2913] = 3261, -- Inscription
    [2914] = 3262, -- Jewelcrafting
    [2915] = 3263, -- Leatherworking
    [2916] = 3264, -- Mining
    [2917] = 3265, -- Skinning
    [2918] = 3266, -- Tailoring
}

local MIDNIGHT_KNOWLEDGE_BOOKS_BY_SKILL_LINE_ID = {
    [2906] = {
        { label = "Voidstorm", questID = 93794, itemID = 262645, mapID = 2405, x = 52.6, y = 72.9 },
        { label = "Coiled Isle", questID = 96459, itemID = 274500, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2907] = {
        { label = "Voidstorm", questID = 93795, itemID = 262644, mapID = 2405, x = 52.6, y = 72.9 },
        { label = "Coiled Isle", questID = 96511, itemID = 274515, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2909] = {
        { label = "Silvermoon", questID = 92374, itemID = 257600, mapID = 2395, x = 43.4, y = 47.4 },
        { label = "Abundance", questID = 92186, itemID = 250445, abundance = true, mapID = 2395, x = 56.78, y = 65.79 },
        { label = "Coiled Isle", questID = 96512, itemID = 274511, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2910] = {
        { label = "Voidstorm", questID = 93796, itemID = 262646, mapID = 2405, x = 52.6, y = 72.9 },
        { label = "Coiled Isle", questID = 96513, itemID = 274516, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2912] = {
        { label = "Harandar", questID = 93411, itemID = 258410, mapID = 2413, x = 51.0, y = 50.8 },
        { label = "Abundance", questID = 92174, itemID = 250443, abundance = true, mapID = 2413, x = 66.14, y = 61.69 },
        { label = "Coiled Isle", questID = 96514, itemID = 274513, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2913] = {
        { label = "Harandar", questID = 93412, itemID = 258411, mapID = 2413, x = 51.0, y = 50.8 },
        { label = "Coiled Isle", questID = 96515, itemID = 274514, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2914] = {
        { label = "Silvermoon", questID = 93222, itemID = 257599, mapID = 2395, x = 43.4, y = 47.4 },
        { label = "Coiled Isle", questID = 96516, itemID = 274510, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2915] = {
        { label = "Zul'Aman", questID = 92371, itemID = 250922, mapID = 2437, x = 45.8, y = 65.8 },
        { label = "Coiled Isle", questID = 96517, itemID = 274507, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2916] = {
        { label = "Zul'Aman", questID = 92372, itemID = 250924, mapID = 2437, x = 45.8, y = 65.8 },
        { label = "Abundance", questID = 92187, itemID = 250444, abundance = true, mapID = 2405, x = 38.82, y = 53.31 },
        { label = "Coiled Isle", questID = 96518, itemID = 274509, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2917] = {
        { label = "Zul'Aman", questID = 92373, itemID = 250923, mapID = 2437, x = 45.8, y = 65.8 },
        { label = "Abundance", questID = 92188, itemID = 250360, abundance = true, mapID = 2437, x = 31.62, y = 26.14 },
        { label = "Coiled Isle", questID = 96519, itemID = 274508, mapID = 2512, x = 58.8, y = 46.0 },
    },
    [2918] = {
        { label = "Silvermoon", questID = 93201, itemID = 257601, mapID = 2395, x = 43.4, y = 47.4 },
        { label = "Coiled Isle", questID = 96520, itemID = 274512, mapID = 2512, x = 58.8, y = 46.0 },
    },
}

local MIDNIGHT_RECIPE_TRACKING_BY_SKILL_LINE_ID = {
    [2906] = {
        {
            label = "Potion of Recklessness",
            optionKey = "trackRecipePotionRecklessness",
            spellID = 1230859,
            itemID = 259459,
            moxieCost = 150,
            mapID = 2405,
            x = 52.6,
            y = 72.9,
        },
        {
            -- Achetee a l'hotel des ventes : aucun vendeur a pointer, donc ni waypoint ni cout Moxie/Marl.
            label = "Vicious Thalassian Flask of Honor",
            optionKey = "trackRecipeViciousThalassianFlaskHonor",
            spellID = 1230883,
            itemID = 257417,
            auctionHouse = true,
        },
        {
            label = "Concentrated Silvermoon Health Potion",
            optionKey = "trackRecipeConcentratedSilvermoonHealthPotion",
            spellID = 1289744,
            itemID = 271885,
            moxieCost = 150,
            mapID = 2512,
            x = 58.8,
            y = 46.0,
        },
    },
    [2909] = {
        {
            label = "Enchant Tool - Haranir Multicrafting",
            optionKey = "trackRecipeHaranirMulticrafting",
            spellID = 1236078,
            itemID = 256749,
            moxieCost = 150,
            mapID = 2413,
            x = 51.0,
            y = 50.8,
        },
        {
            label = "Gleeful Glamour - Haranir",
            optionKey = "trackRecipeHaranirGlamour",
            spellID = 1236464,
            itemID = 256743,
            moxieCost = 150,
            mapID = 2413,
            x = 51.0,
            y = 50.8,
        },
    },
}

local MIDNIGHT_KNOWLEDGE_ITEM_SKILL_LINE_IDS = {}
local MIDNIGHT_TREATISES_BY_SKILL_LINE_ID = {
    [2906] = { itemID = 245755, weeklyQuestID = 95127 },
    [2907] = { itemID = 245763, weeklyQuestID = 95128 },
    [2909] = { itemID = 245759, weeklyQuestID = 95129 },
    [2910] = { itemID = 245809, weeklyQuestID = 95138 },
    [2912] = { itemID = 245761, weeklyQuestID = 95130 },
    [2913] = { itemID = 245757, weeklyQuestID = 95131 },
    [2914] = { itemID = 245760, weeklyQuestID = 95133 },
    [2915] = { itemID = 245758, weeklyQuestID = 95134 },
    [2916] = { itemID = 245762, weeklyQuestID = 95135 },
    [2917] = { itemID = 245828, weeklyQuestID = 95136 },
    [2918] = { itemID = 245756, weeklyQuestID = 95137 },
}
runtimeState = runtimeState or {}
runtimeState.minimumMidnightProfessionLevel = 80
runtimeState.minimumMidnightAbundanceLevel = 90
runtimeState.midnightEnchantingCatchUpCurrencyID = 3198
runtimeState.unspentKnowledgeWarningThreshold = 5
runtimeState.currencyQuantities = {}
runtimeState.midnightSeasonalResourceTracking = {
    sparksOfTides = {
        currencyID = 3509,
        itemID = 274476,
        optionKey = "trackSparksOfTides",
        label = "Sparks of Tides",
        acquiredField = "quantity",
        minimumLevel = 90,
        minimumItemLevel = 270,
    },
}
runtimeState.midnightShardOfDundunCurrencyID = 3376
runtimeState.midnightShardOfDundunCap = 8
runtimeState.baseProfessionToMidnightSkillLineID = {
    [171] = 2906, -- Alchemy
    [164] = 2907, -- Blacksmithing
    [333] = 2909, -- Enchanting
    [202] = 2910, -- Engineering
    [182] = 2912, -- Herbalism
    [773] = 2913, -- Inscription
    [755] = 2914, -- Jewelcrafting
    [165] = 2915, -- Leatherworking
    [186] = 2916, -- Mining
    [393] = 2917, -- Skinning
    [197] = 2918, -- Tailoring
}
local ARTISAN_CONSORTIUM_PAYOUT_ITEM_IDS = {
    [227713] = true,
    [246585] = true,
}
runtimeState.surplusReagentContainers = {
    [260534] = { order = 1, label = "Alch" }, -- Master Alchemist's Surplus Reagents
    [260536] = { order = 2, label = "BS" }, -- Master Smith's Surplus Reagents
    [260537] = { order = 3, label = "Ench" }, -- Master Enchanter's Surplus Reagents
    [260538] = { order = 4, label = "Eng" }, -- Master Engineer's Surplus Reagents
    [260539] = { order = 5, label = "Herb" }, -- Master Herbalist's Surplus Reagents
    [260540] = { order = 6, label = "Insc" }, -- Master Scribe's Surplus Reagents
    [260541] = { order = 7, label = "JC" }, -- Master Jewelcrafter's Surplus Reagents
    [260542] = { order = 8, label = "LW" }, -- Master Leatherworker's Surplus Reagents
    [260543] = { order = 9, label = "Mine" }, -- Master Miner's Surplus Reagents
    [260544] = { order = 10, label = "Skin" }, -- Master Skinner's Surplus Reagents
    [260545] = { order = 11, label = "Tail" }, -- Master Tailor's Surplus Reagents
}
runtimeState.mergeableFinishingReagents = {
    [247725] = { outputItemID = 247726, order = 1, label = "Resourceful" }, -- Resourceful Rebar -> Resourceful Routing
    [247719] = { outputItemID = 247724, order = 2, label = "Multicraft" }, -- Multicraft Matrix -> Multicraft Manifold
    [260630] = { outputItemID = 247788, order = 3, label = "Ingenuity" }, -- Ingenious Identifier -> Ingenious Identity
}
runtimeState.containerWhitelist = {
    [235052] = true, -- Weathered Mysterious Satchel, uncommon
    [235911] = true, -- Weathered Mysterious Satchel, rare
    [236944] = true, -- Weathered Mysterious Satchel, epic
    [235054] = true, -- Pristine Mysterious Satchel, epic
    [241131] = true, -- Amani Lapis Prism
    [241132] = true, -- Amani Lapis Prism
    [241133] = true, -- Tenebrous Amethyst Prism
    [241134] = true, -- Tenebrous Amethyst Prism
    [241135] = true, -- Sanguine Garnet Prism
    [241136] = true, -- Sanguine Garnet Prism
    [241137] = true, -- Harandar Peridot Prism
    [241138] = true, -- Harandar Peridot Prism
    [263934] = true, -- Chest of Gold
    [263466] = true, -- Overflowing Abundant Satchel
    [263467] = true, -- Avid Learner's Supply Pack, Season 1
    [268487] = true, -- Avid Learner's Supply Pack, pre-season
    [269703] = true, -- Avid Learner's Supply Pack
    [254677] = true, -- Chest
    [250755] = true, -- Pouch of Mystic Grindings
    [245650] = true, -- Bouquet of Herbs rank 1
    [245651] = true, -- Bouquet of Herbs rank 2
    [275899] = true, -- Venom-Soaked Satchel
    [275911] = true, -- Venom-Covered Chest
    [277137] = true, -- Wriggling Venom-Soaked Satchel
    [279287] = true, -- Corroded Pouch
    [279288] = true, -- Corroded Satchel
    [279345] = true, -- Venom-Drenched Sack
    [279527] = true, -- Apex Cache, Midnight Season 2
    [280458] = true, -- Delver's Corroded Pouch of Undercoin
    [257023] = true, -- Preyseeker's Adventurer Chest
    [257026] = true, -- Preyseeker's Veteran Chest
    [262346] = true, -- Preyseeker's Champion Chest
    [268545] = true, -- Aspiring Preyseeker's Chest
    [275726] = true, -- Preyhunter's Champion Chest
    [275822] = true, -- Preyhunter's Veteran Chest
    [275918] = true, -- Preyhunter's Adventurer Chest
    [276104] = true, -- Aspiring Preyhunter's Chest
    [279574] = true, -- Preyhunter's Hero Chest
    [250116] = true, -- Cache of Quel'Thalas Treasures
    [250117] = true, -- Cache of Quel'Thalas Treasures, Heroic
    [250750] = true, -- Pouch of Sprouted Clippings
    [250753] = true, -- Bag of Cracked Orebits
    [250754] = true, -- Bag of Wild Skinnings
    [250975] = true, -- Hellcaller Chest
    [251286] = true, -- Bundle of Petrified Roots
    [251287] = true, -- Generous Bundle of Petrified Roots
    [251322] = true, -- Thalassian Leatherworker's Duffel
    [251326] = true, -- Thalassian Enchanter's Purse
    [251327] = true, -- Thalassian Tailor's Tote Bag
    [251821] = true, -- Cache of Infinite Power
    [251970] = true, -- Overflowing Amani Trove
    [254323] = true, -- Worldsoul Satchel
    [254324] = true, -- Worldsoul Satchel
    [254325] = true, -- Worldsoul Satchel, level 80
    [255428] = true, -- Tolbani's Medicine Satchel
    [255666] = true, -- Huge Bag of Midnight General Goods
    [255678] = true, -- Huge Bag of Midnight Herbs
    [255679] = true, -- Huge Bag of Midnight Minerals
    [255682] = true, -- Huge Bag of Midnight Skins
    [255683] = true, -- Huge Bag of Midnight Jewelcrafting Goods
    [255684] = true, -- Huge Bag of Midnight Leatherworking Goods
    [255686] = true, -- Huge Bag of Midnight Alchemy Goods
    [255687] = true, -- Huge Bag of Midnight Optional Goods
    [255689] = true, -- Huge Bag of Midnight Engineering Goods
    [255690] = true, -- Huge Bag of Midnight Enchanting Goods
    [255691] = true, -- Huge Bag of Midnight Tailoring Goods
    [255703] = true, -- Huge Bag of Midnight Blacksmithing Goods
    [255704] = true, -- Huge Bag of Midnight Inscription Goods
    [256055] = true, -- Overflowing Hara'ti Trove
    [256763] = true, -- Cache from the Infinite's Armory
    [258279] = true, -- [DNT] Big Pouch of Supplies
    [258534] = true, -- Illustrious Contender's Strongbox
    [258620] = true, -- Field Medic's Hazard Payout
    [259086] = true, -- Void-Touched Satchel of Cooperation
    [259334] = true, -- Overflowing Singularity Trove
    [260193] = true, -- Fabled Veteran's Cache
    [260940] = true, -- Victorious Stormarion Pinnacle Cache
    [260979] = true, -- Victorious Stormarion Cache
    [262349] = true, -- Satchel of Compensation
    [262432] = true, -- Weathered Lockbox
    [262596] = true, -- Preyseeker's Satchel of Voidlight Marl
    [262622] = true, -- Preyseeker's Satchel of Coffer Key Shards
    [262623] = true, -- Preyseeker's Satchel of Adventurer Dawncrests
    [262624] = true, -- Preyseeker's Satchel of Anguish
    [262626] = true, -- Preyseeker's Box of Anguish
    [262627] = true, -- Preyseeker's Box of Coffer Key Shards
    [262629] = true, -- Preyseeker's Box of Veteran Dawncrests
    [262630] = true, -- Preyseeker's Box of Voidlight Marl
    [262631] = true, -- Preyseeker's Cache of Anguish
    [262632] = true, -- Preyseeker's Cache of Coffer Key Shards
    [262633] = true, -- Preyseeker's Cache of Champion Dawncrests
    [262634] = true, -- Preyseeker's Cache of Voidlight Marl
    [262635] = true, -- Cache of Delver's Spoils
    [262658] = true, -- Nebulous Voidcache: Midnight Falls
    [262928] = true, -- Preyseeker's Adventurer Sack
    [262936] = true, -- Preyseeker's Veteran Sack
    [262938] = true, -- Preyseeker's Champion Sack
    [263179] = true, -- Delver's Cosmetic Surprise Bag
    [263400] = true, -- Cache of Delver's Spoils
    [263433] = true, -- Overflowing Silvermoon Trove
    [263465] = true, -- Surplus Bag of Party Favors
    [263928] = true, -- Cache of Void-Touched Armaments, Champion
    [263929] = true, -- Cache of Void-Touched Armaments, Heroic
    [264274] = true, -- Fabled Adventurer's Cache
    [264314] = true, -- Cache of Void-Touched Headgear
    [264315] = true, -- Cache of Void-Touched Shoulderwear
    [264316] = true, -- Cache of Void-Touched Cloaks
    [264317] = true, -- Cache of Void-Touched Chestpieces
    [264318] = true, -- Cache of Void-Touched Bracers
    [264319] = true, -- Cache of Void-Touched Gloves
    [264320] = true, -- Cache of Void-Touched Belts
    [264321] = true, -- Cache of Void-Touched Legwear
    [264322] = true, -- Cache of Void-Touched Boots
    [264323] = true, -- Cache of Void-Touched Weapons
    [264470] = true, -- Ash-Tied Offering
    [264587] = true, -- Ani's Trinket Bag
    [264652] = true, -- Delver's Pouch of Voidlight Marl
    [264675] = true, -- Cache from the Infinite's Armory
    [264914] = true, -- Ranger's Cache
    [265790] = true, -- Cache of Mistcrests
    [265995] = true, -- Quel'Thalas Adventurer's Cache
    [267299] = true, -- Slayer's Duellum Trove
    [267488] = true, -- Nebulous Voidcache: Crown of the Cosmos
    [268297] = true, -- Rattling Bag o' Gold
    [268458] = true, -- Nebulous Voidcache: Belo'ren, Child of Al'ar
    [268459] = true, -- Nebulous Voidcache: Imperator Averzian
    [268460] = true, -- Nebulous Voidcache: Vorasius
    [268461] = true, -- Nebulous Voidcache: Fallen-King Salhadaar
    [268462] = true, -- Nebulous Voidcache: Vaelgor & Ezzorak
    [268463] = true, -- Nebulous Voidcache: Lightblinded Vanguard
    [268464] = true, -- Nebulous Voidcache: Chimaerus the Undreamt God
    [268465] = true, -- Nebulous Voidcache: Algeth'ar Academy
    [268466] = true, -- Nebulous Voidcache: Magisters' Terrace
    [268467] = true, -- Nebulous Voidcache: Nexus-Point Xenas
    [268468] = true, -- Nebulous Voidcache: Pit of Saron
    [268469] = true, -- Nebulous Voidcache: Seat of the Triumvirate
    [268470] = true, -- Nebulous Voidcache: Skyreach
    [268471] = true, -- Nebulous Voidcache: Windrunner Spire
    [268473] = true, -- Nebulous Voidcache: Maisara Caverns
    [268485] = true, -- Victorious Stormarion Pinnacle Cache
    [268488] = true, -- Overflowing Abundant Satchel
    [268489] = true, -- Surplus Bag of Party Favors
    [268490] = true, -- Apex Cache
    [268969] = true, -- Nebulous Voidcache: Delver's Trove
    [269005] = true, -- Preyseeker's Glinting Coin Pouch
    [269006] = true, -- Preyseeker's Gleaming Coin Pouch
    [269007] = true, -- Preyseeker's Glittering Coin Pouch
    [269234] = true, -- Overflowing Ritual Site Cache
    [269701] = true, -- Surplus Bag of Party Favors
    [269702] = true, -- Overflowing Abundant Satchel
    [269704] = true, -- Victorious Stormarion Cache
    [269768] = true, -- Nebulous Voidcache: Prey
    [270244] = true, -- Field Pouch
    [270247] = true, -- Field Satchel
    [270932] = true, -- Wriggling Field Pouch
    [270933] = true, -- Bulging Field Pouch
    [270934] = true, -- Recruit's Field Pouch
    [270987] = true, -- Recruit's Field Satchel
    [271221] = true, -- Wriggling Recruit's Field Pouch
    [271222] = true, -- Bulging Recruit's Field Pouch
    [272125] = true, -- Recruit's Cache
    [273152] = true, -- Delve Gearbox, item level 220
    [273153] = true, -- Delve Gearbox, item level 230
    [273154] = true, -- Delve Gearbox, item level 243
    [273155] = true, -- Delve Gearbox, item level 259
    [273156] = true, -- Delve Gearbox, item level 263
    [274372] = true, -- Big ol' Bag of Polished Pet Charms
    [274421] = true, -- Crate of Community Coupons
    [274465] = true, -- Agitated Crate of Zandalari Fury
    [274578] = true, -- Offering of Unalloyed Abundance
    [274708] = true, -- Nebulous Voidcache: Nymrissa Wavecaller
    [274713] = true, -- Cache of Amani Treasures, Heroic
    [274714] = true, -- Cache of Amani Treasures
    [275228] = true, -- Nebulous Voidcache: Rotmire
    [275690] = true, -- Riftstalker's Cache
    [275691] = true, -- Riftstalker's Overflowing Cache
    [275728] = true, -- Preyhunter's Champion Sack
    [275917] = true, -- Preyhunter's Veteran Sack
    [275919] = true, -- Preyhunter's Adventurer Sack
    [275986] = true, -- Delver's Cosmetic Surprise Bag
    [276378] = true, -- Cache of Void-Touched Armaments: Boots
    [276379] = true, -- Cache of Void-Touched Armaments: Legs
    [276380] = true, -- Cache of Void-Touched Armaments: Belts
    [276381] = true, -- Cache of Void-Touched Armaments: Gloves
    [276382] = true, -- Cache of Void-Touched Armaments: Bracers
    [276383] = true, -- Cache of Void-Touched Armaments: Chest
    [276384] = true, -- Cache of Void-Touched Armaments: Cloak
    [276385] = true, -- Cache of Void-Touched Armaments: Shoulder
    [276386] = true, -- Cache of Void-Touched Armaments: Head
    [276624] = true, -- Overflowing Hash'ura Trove
    [277124] = true, -- Warbound Cache of Void-Touched Armaments
    [277125] = true, -- Cache of Void-Touched Armaments: Weapons
    [277126] = true, -- Cache of Void-Touched Armaments: Necklaces
    [277127] = true, -- Cache of Void-Touched Armaments: Rings
    [277157] = true, -- Barnacle-Encrusted Chest
    [277937] = true, -- Balanced Offering
    [277938] = true, -- Virulent Offering
    [277940] = true, -- Fragile Offering
    [278004] = true, -- Warbound Cache of Void-Touched Armaments: Boots
    [278005] = true, -- Warbound Cache of Void-Touched Armaments: Legs
    [278006] = true, -- Warbound Cache of Void-Touched Armaments: Belts
    [278007] = true, -- Warbound Cache of Void-Touched Armaments: Gloves
    [278008] = true, -- Warbound Cache of Void-Touched Armaments: Bracers
    [278009] = true, -- Warbound Cache of Void-Touched Armaments: Chest
    [278010] = true, -- Warbound Cache of Void-Touched Armaments: Cloak
    [278011] = true, -- Warbound Cache of Void-Touched Armaments: Shoulder
    [278012] = true, -- Warbound Cache of Void-Touched Armaments: Head
    [278013] = true, -- Warbound Cache of Void-Touched Armaments: Weapons
    [278014] = true, -- Warbound Cache of Void-Touched Armaments: Necklaces
    [278015] = true, -- Warbound Cache of Void-Touched Armaments: Rings
    [278021] = true, -- Bulging Elven Field Pouch
    [278022] = true, -- Bulging Amani Field Pouch
    [278024] = true, -- Bulging Naga Field Pouch
    [278025] = true, -- Bulging Twilight Field Pouch
    [278026] = true, -- Bulging Ethereal Pack
    [278027] = true, -- Bulging Winter Pack
    [278283] = true, -- Nebulous Voidcache: Entombed Sentinels
    [278284] = true, -- Nebulous Voidcache: Ula'tek
    [278285] = true, -- Nebulous Voidcache: Soulcoiler Nek'zali
    [278286] = true, -- Nebulous Voidcache: Tortollan Explorers
    [278287] = true, -- Nebulous Voidcache: Vashnik
    [278288] = true, -- Nebulous Voidcache: Sszorak
    [278289] = true, -- Nebulous Voidcache: The Twin Fangs
    [278290] = true, -- Nebulous Voidcache: The Coiled Altar
    [279092] = true, -- Anguish-Touched Pouch
    [279284] = true, -- Nebulous Voidcache: Delver's Trove
    [279520] = true, -- Fabled Veteran's Cache
    [279522] = true, -- Surplus Bag of Party Favors
    [279523] = true, -- Overflowing Abundant Satchel
    [279525] = true, -- Avid Learner's Supply Pack
    [279526] = true, -- Victorious Stormarion Pinnacle Cache
    [279610] = true, -- Dawncrest Pack
    [279611] = true, -- Dawncrest Pack
    [279612] = true, -- Dawncrest Satchel
    [279613] = true, -- Dawncrest Satchel
    [279614] = true, -- Dawncrest Pouch
    [279615] = true, -- Dawncrest Pouch
    [279616] = true, -- Mistcrest Pack
    [279617] = true, -- Mistcrest Satchel
    [279618] = true, -- Nebulous Voidcache: dungeon reward
    [279619] = true, -- Nebulous Voidcache: dungeon reward
    [279620] = true, -- Nebulous Voidcache: dungeon reward
    [279621] = true, -- Nebulous Voidcache: dungeon reward
    [279622] = true, -- Nebulous Voidcache: dungeon reward
    [279623] = true, -- Nebulous Voidcache: Murder Row
    [279624] = true, -- Nebulous Voidcache: dungeon reward
    [279625] = true, -- Nebulous Voidcache: dungeon reward
    [280131] = true, -- Nebulous Voidcache: Prey
    [280732] = true, -- Warbound Mistcrest Pack
    [280734] = true, -- Warbound Mistcrest Satchel
    [280737] = true, -- Warbound Mistcrest Pouch
    [280781] = true, -- Cache of Void-Touched Armaments
    [280782] = true, -- Cache of Void-Touched Armaments
    [280783] = true, -- Cache of Void-Touched Armaments
    [280784] = true, -- Cache of Void-Touched Armaments
    [280785] = true, -- Cache of Void-Touched Armaments
    [280786] = true, -- Cache of Void-Touched Armaments
    [280787] = true, -- Cache of Void-Touched Armaments
    [280788] = true, -- Cache of Void-Touched Armaments
    [280789] = true, -- Cache of Void-Touched Armaments
    [280790] = true, -- Cache of Void-Touched Armaments
    [280791] = true, -- Cache of Void-Touched Armaments
    [280792] = true, -- Cache of Void-Touched Armaments
    [280793] = true, -- Cache of Void-Touched Armaments
    [281223] = true, -- Satchel of Corrosive Coins
    [281405] = true, -- Cache of Void-Touched Armaments
    [281406] = true, -- Cache of Void-Touched Armaments
    [281407] = true, -- Cache of Void-Touched Armaments
    [281408] = true, -- Cache of Void-Touched Armaments
    [281409] = true, -- Cache of Void-Touched Armaments
    [281410] = true, -- Cache of Void-Touched Armaments
    [281411] = true, -- Cache of Void-Touched Armaments
    [281412] = true, -- Cache of Void-Touched Armaments
    [281413] = true, -- Cache of Void-Touched Armaments
    [281414] = true, -- Cache of Void-Touched Armaments
    [281415] = true, -- Cache of Void-Touched Armaments
    [281416] = true, -- Cache of Void-Touched Armaments
    [281417] = true, -- Cache of Void-Touched Armaments
    [281418] = true, -- Cache of Void-Touched Armaments: Legs
    [281419] = true, -- Cache of Void-Touched Armaments
    [281420] = true, -- Cache of Void-Touched Armaments
    [281421] = true, -- Cache of Void-Touched Armaments
    [281422] = true, -- Cache of Void-Touched Armaments
    [281423] = true, -- Cache of Void-Touched Armaments
    [281424] = true, -- Cache of Void-Touched Armaments
    [281425] = true, -- Cache of Void-Touched Armaments
    [281426] = true, -- Cache of Void-Touched Armaments
    [281427] = true, -- Cache of Void-Touched Armaments
    [281428] = true, -- Cache of Void-Touched Armaments
    [281429] = true, -- Cache of Void-Touched Armaments
    [282183] = true, -- Fabled Coiled Isle Veteran's Cache
}
_G.YayaWeeklyTrackerAutoOpen = _G.YayaWeeklyTrackerAutoOpen or {}
_G.YayaWeeklyTrackerAutoOpen.GetAutoOpenContainerItemIDs = function()
    local itemIDs = {}
    for itemID in pairs(runtimeState.containerWhitelist or {}) do
        itemIDs[itemID] = true
    end
    for itemID in pairs(ARTISAN_CONSORTIUM_PAYOUT_ITEM_IDS or {}) do
        itemIDs[itemID] = true
    end
    for itemID in pairs(runtimeState.surplusReagentContainers or {}) do
        itemIDs[itemID] = true
    end
    return itemIDs
end
runtimeState.midnightEnchantingWeeklyReagents = {
    [93697] = { itemID = 243599, itemName = "Eversinging Dust", quantity = 20 },
    [93698] = { itemID = 243602, itemName = "Radiant Shard", quantity = 10 },
    [93699] = { itemID = 243605, itemName = "Dawn Crystal", quantity = 1 },
}
runtimeState.generalWeeklyQuests = {
    abundanceQuestIDs = { 89507 }, -- Abundant Offerings
    midnightWorldBossQuestIDs = {
        92560, -- Lu'ashal
        92123, -- Cragpine
        92034, -- Thorm'belan
        92636, -- Predaxas
    },
    midnightShowdownWorldBosses = {
        {
            name = "Imperator Pertinax",
            questIDs = { 96473, 96295 }, -- normal / Heroic, Val
        },
        {
            name = "Nexus-Captain Leth'ir",
            questIDs = { 96472, 96709 }, -- normal / Heroic, Naigtal
        },
    },
    worldBossMaxUsefulItemLevel = 250,
    liadrinWorldBossQuestID = 93913, -- Midnight: World Boss
    runestoneQuestIDs = {
        90573, -- Fortify the Runestones: Magisters
        90574, -- Fortify the Runestones: Blood Knights
        90575, -- Fortify the Runestones: Farstriders
        90576, -- Fortify the Runestones: Shades of the Row
    },
    halduronWorldQuestID = 95468, -- Hope in the Darkest Corners
    neighborhoodWeeklyQuestIDs = {
        95413, -- Community Engagement
        95416, -- Going Postal
        95438, -- Lost Animals
        95440, -- Housewarming
    },
    neighborhoodWeeklyActiveQuestIDs = {
        95413, -- Community Engagement
        95416, -- Going Postal
        95438, -- Lost Animals
        95439, -- Lost Animals breadcrumb
        95440, -- Housewarming
        95482, -- Lost Animals breadcrumb
    },
    liadrinWrapperQuestID = 93744, -- Unity Against the Void
    haranirLegendsQuestIDs = {
        89268, -- Lost Legends (selection)
        92716, 92719, 92720, 92721, 92722, 92723, 92724, 92725, -- The Story of...
    },
    researchConsoleQuestID = 94790, -- Research Console: Exploring the Void
    liadrinWeeklyQuestIDs = {
        93766, -- Midnight: World Quests
        93767, -- Midnight: Arcantina
        93769, -- Midnight: Housing
        93889, -- Midnight: Saltheril's Soiree
        93890, -- Midnight: Abundance
        93892, -- Midnight: Stormarion Assault
        93909, -- Midnight: Delves
        93910, -- Midnight: Prey
        93911, -- Midnight: Dungeons
        93912, -- Midnight: Raid
        93913, -- Midnight: World Boss
        94457, -- Midnight: Battlegrounds
        95842, -- Midnight: Void Assaults
        95843, -- Midnight: Ritual Sites
    },
}

local function AddMidnightKnowledgeItems(skillLineID, itemIDs)
    for _, itemID in ipairs(itemIDs or EMPTY_TABLE) do
        MIDNIGHT_KNOWLEDGE_ITEM_SKILL_LINE_IDS[itemID] = skillLineID
    end
end

local function AddMidnightKnowledgeItemRange(skillLineID, firstItemID, lastItemID)
    for itemID = firstItemID, lastItemID do
        MIDNIGHT_KNOWLEDGE_ITEM_SKILL_LINE_IDS[itemID] = skillLineID
    end
end

AddMidnightKnowledgeItemRange(2906, 238532, 238539)
AddMidnightKnowledgeItems(2906, { 245755, 246320, 246321, 259188, 259189, 262645, 263454, 274500 })

AddMidnightKnowledgeItemRange(2907, 238540, 238547)
AddMidnightKnowledgeItems(2907, { 245763, 246322, 246323, 259190, 259191, 262644, 263455, 274515 })

AddMidnightKnowledgeItemRange(2909, 238548, 238555)
AddMidnightKnowledgeItems(2909, { 227659, 245759, 246324, 246325, 250445, 257600, 259192, 259193, 263464, 267653, 267654, 267655, 274511 })

AddMidnightKnowledgeItemRange(2910, 238556, 238563)
AddMidnightKnowledgeItems(2910, { 245754, 246326, 246327, 259194, 259195, 262646, 263456, 274516 })

AddMidnightKnowledgeItemRange(2912, 238468, 238475)
AddMidnightKnowledgeItems(2912, { 238465, 238466, 250443, 258410, 263462, 274513 })

AddMidnightKnowledgeItemRange(2913, 238572, 238579)
AddMidnightKnowledgeItems(2913, { 245757, 246328, 246329, 258411, 259196, 259197, 263457, 274514 })

AddMidnightKnowledgeItemRange(2914, 238580, 238587)
AddMidnightKnowledgeItems(2914, { 245760, 246330, 246331, 257599, 259198, 259199, 263458, 274510 })

AddMidnightKnowledgeItemRange(2915, 238588, 238595)
AddMidnightKnowledgeItems(2915, { 245758, 246332, 246333, 250922, 259200, 259201, 263459, 274507 })

AddMidnightKnowledgeItemRange(2916, 238596, 238603)
AddMidnightKnowledgeItems(2916, { 237496, 237506, 245762, 250444, 250924, 263463, 274509 })

AddMidnightKnowledgeItemRange(2917, 238628, 238635)
AddMidnightKnowledgeItems(2917, { 238625, 238626, 245764, 250360, 250923, 263461, 274508 })

AddMidnightKnowledgeItemRange(2918, 238612, 238619)
AddMidnightKnowledgeItems(2918, { 245756, 246334, 246335, 257601, 259202, 259203, 263460, 274512 })

for skillLineID, treatiseInfo in pairs(MIDNIGHT_TREATISES_BY_SKILL_LINE_ID) do
    MIDNIGHT_KNOWLEDGE_ITEM_SKILL_LINE_IDS[treatiseInfo.itemID] = skillLineID
end

local MIDNIGHT_TREASURE_WAYPOINTS_BY_QUEST_ID = {
    [89115] = { mapID = 2393, x = 0.4910, y = 0.7560, title = "Freshly Plucked Peacebloom" },
    [89117] = { mapID = 2393, x = 0.4780, y = 0.5160, title = "Pristine Potion" },
    [89114] = { mapID = 2437, x = 0.4040, y = 0.5100, title = "Vial of Zul'Aman Oddities" },
    [89116] = { mapID = 2536, x = 0.4910, y = 0.2310, title = "Measured Ladle" },
    [89113] = { mapID = 2413, x = 0.3470, y = 0.2470, title = "Vial of Rootlands Oddities" },
    [89112] = { mapID = 2444, x = 0.4180, y = 0.4050, title = "Vial of Voidstorm Oddities" },
    [89111] = { mapID = 2393, x = 0.4512, y = 0.4477, title = "Vial of Eversong Oddities" },
    [89118] = { mapID = 2405, x = 0.3280, y = 0.4330, title = "Failed Experiment" },
    [89183] = { mapID = 2393, x = 0.4930, y = 0.6130, title = "Sin'dorei Master's Forgemace" },
    [89184] = { mapID = 2393, x = 0.4850, y = 0.7480, title = "Silvermoon Blacksmith's Hammer" },
    [89177] = { mapID = 2393, x = 0.2690, y = 0.6030, title = "Deconstructed Forge Techniques" },
    [89180] = { mapID = 2395, x = 0.5680, y = 0.4070, title = "Metalworking Cheat Sheet" },
    [89178] = { mapID = 2395, x = 0.4830, y = 0.7570, title = "Silvermoon Smithing Kit" },
    [89179] = { mapID = 2536, x = 0.3320, y = 0.6580, title = "Carefully Racked Spear" },
    [89182] = { mapID = 2413, x = 0.6630, y = 0.5080, title = "Rutaani Floratender's Sword" },
    [89181] = { mapID = 2444, x = 0.3060, y = 0.6890, title = "Voidstorm Defense Spear" },
    [89107] = { mapID = 2395, x = 0.6340, y = 0.3260, title = "Sin'dorei Enchanting Rod" },
    [89106] = { mapID = 2437, x = 0.4040, y = 0.5120, title = "Loa-Blessed Dust" },
    [89104] = { mapID = 2413, x = 0.3770, y = 0.6530, title = "Entropic Shard" },
    [89102] = { mapID = 2405, x = 0.3550, y = 0.5880, title = "Pure Void Crystal" },
    [89100] = { mapID = 2536, x = 0.4910, y = 0.2270, title = "Enchanted Amani Mask" },
    [89105] = { mapID = 2413, x = 0.6580, y = 0.5020, title = "Primal Essence Orb" },
    [89103] = { mapID = 2395, x = 0.6080, y = 0.5310, title = "Everblazing Sunmote" },
    [89101] = { mapID = 2395, x = 0.4020, y = 0.6123, title = "Enchanted Sunfire Silk" },
    [89139] = { mapID = 2393, x = 0.5120, y = 0.5710, title = "What To Do When Nothing Works" },
    [89133] = { mapID = 2393, x = 0.5140, y = 0.7460, title = "One Engineer's Junk" },
    [89135] = { mapID = 2395, x = 0.3950, y = 0.4580, title = "Manual of Mistakes and Mishaps" },
    [89138] = { mapID = 2536, x = 0.6510, y = 0.3450, title = "Offline Helper Bot" },
    [89140] = { mapID = 2437, x = 0.3420, y = 0.8790, title = "Handy Wrench" },
    [89136] = { mapID = 2413, x = 0.6790, y = 0.4980, title = "Expeditious Pylon" },
    [89137] = { mapID = 2444, x = 0.5400, y = 0.5100, title = "Ethereal Stormwrench" },
    [89134] = { mapID = 2444, x = 0.2900, y = 0.3920, title = "Miniaturized Transport Skiff" },
    [89160] = { mapID = 2393, x = 0.4900, y = 0.7580, title = "Simple Leaf Pruners" },
    [89158] = { mapID = 2395, x = 0.6420, y = 0.3040, title = "A Spade" },
    [89161] = { mapID = 2437, x = 0.4180, y = 0.4590, title = "Sweeping Harvester's Scythe" },
    [89157] = { mapID = 2413, x = 0.7610, y = 0.5110, title = "Harvester's Sickle" },
    [89162] = { mapID = 2413, x = 0.3810, y = 0.6690, title = "Bloomed Bud" },
    [89159] = { mapID = 2413, x = 0.3660, y = 0.2500, title = "Lightbloom Root" },
    [89155] = { mapID = 2413, x = 0.5110, y = 0.5570, title = "Planting Shovel" },
    [89156] = { mapID = 2405, x = 0.3460, y = 0.5700, title = "Peculiar Lotus" },
    [89073] = { mapID = 2393, x = 0.4770, y = 0.5030, title = "Songwriter's Pen" },
    [89074] = { mapID = 2395, x = 0.4040, y = 0.6130, title = "Songwriter's Quill" },
    [89069] = { mapID = 2395, x = 0.4830, y = 0.7560, title = "Spare Ink" },
    [89068] = { mapID = 2437, x = 0.4050, y = 0.4940, title = "Leather-Bound Techniques" },
    [89070] = { mapID = 2413, x = 0.5270, y = 0.5000, title = "Leftover Sanguithorn Pigment" },
    [89071] = { mapID = 2413, x = 0.5240, y = 0.5260, title = "Intrepid Explorer's Marker" },
    [89067] = { mapID = 2444, x = 0.6070, y = 0.8410, title = "Void-Touched Quill" },
    [89072] = { mapID = 2395, x = 0.3930, y = 0.4540, title = "Half-Baked Techniques" },
    [89122] = { mapID = 2393, x = 0.5060, y = 0.5650, title = "Sin'dorei Masterwork Chisel" },
    [89127] = { mapID = 2393, x = 0.5550, y = 0.4800, title = "Vintage Soul Gem" },
    [89125] = { mapID = 2395, x = 0.5670, y = 0.4090, title = "Poorly Rounded Vial" },
    [89129] = { mapID = 2395, x = 0.3970, y = 0.3880, title = "Sin'dorei Gem Faceters" },
    [89123] = { mapID = 2444, x = 0.3060, y = 0.6900, title = "Speculative Voidstorm Crystal" },
    [89128] = { mapID = 2444, x = 0.5420, y = 0.5120, title = "Ethereal Gem Pliers" },
    [89126] = { mapID = 2444, x = 0.6290, y = 0.5350, title = "Shattered Glass" },
    [89124] = { mapID = 2393, x = 0.2861, y = 0.4647, title = "Dual-Function Magnifiers" },
    [89096] = { mapID = 2393, x = 0.4480, y = 0.5620, title = "Artisan's Considered Order" },
    [89092] = { mapID = 2536, x = 0.4520, y = 0.4530, title = "Bundle of Tanner's Trinkets" },
    [89089] = { mapID = 2437, x = 0.3310, y = 0.7890, title = "Amani Leatherworker's Tool" },
    [89095] = { mapID = 2413, x = 0.3610, y = 0.2520, title = "Haranir Leatherworking Knife" },
    [89090] = { mapID = 2405, x = 0.3480, y = 0.5690, title = "Ethereal Leatherworking Knife" },
    [89091] = { mapID = 2437, x = 0.3080, y = 0.8410, title = "Prestigiously Racked Hide" },
    [89094] = { mapID = 2413, x = 0.5180, y = 0.5130, title = "Haranir Leatherworking Mallet" },
    [89093] = { mapID = 2444, x = 0.5380, y = 0.5160, title = "Pattern: Beyond The Void" },
    [89147] = { mapID = 2395, x = 0.3800, y = 0.4530, title = "Solid Ore Punchers" },
    [89145] = { mapID = 2437, x = 0.4190, y = 0.4630, title = "Spelunker's Lucky Charm" },
    [89151] = { mapID = 2413, x = 0.3880, y = 0.6590, title = "Spare Expedition Torch" },
    [89149] = { mapID = 2536, x = 0.3360, y = 0.6600, title = "Amani Expert's Chisel" },
    [89150] = { mapID = 2444, x = 0.3423, y = 0.7605, title = "Star Metal Deposit" },
    [89148] = { mapID = 2444, x = 0.2873, y = 0.3856, title = "Glimmering Void Pearl" },
    [89146] = { mapID = 2444, x = 0.5424, y = 0.5159, title = "Lost Voidstorm Satchel" },
    [89144] = { mapID = 2444, x = 0.3000, y = 0.6900, title = "Miner's Guide to Voidstorm" },
    [89171] = { mapID = 2393, x = 0.4320, y = 0.5570, title = "Sin'dorei Tanning Oil" },
    [89173] = { mapID = 2395, x = 0.4850, y = 0.7620, title = "Thalassian Skinning Knife" },
    [89170] = { mapID = 2437, x = 0.4040, y = 0.3600, title = "Amani Tanning Oil" },
    [89172] = { mapID = 2437, x = 0.3310, y = 0.7900, title = "Amani Skinning Knife" },
    [89167] = { mapID = 2536, x = 0.4500, y = 0.4470, title = "Cadre Skinning Knife" },
    [89168] = { mapID = 2413, x = 0.6950, y = 0.4920, title = "Primal Hide" },
    [89166] = { mapID = 2413, x = 0.7600, y = 0.5100, title = "Lightbloom Afflicted Hide" },
    [89169] = { mapID = 2444, x = 0.4550, y = 0.4240, title = "Voidstorm Leather Sample" },
    [89079] = { mapID = 2393, x = 0.3580, y = 0.6120, title = "A Really Nice Curtain" },
    [89084] = { mapID = 2393, x = 0.3170, y = 0.6820, title = "Particularly Enchanting Tablecloth" },
    [89085] = { mapID = 2437, x = 0.4040, y = 0.4940, title = "Artisan's Cover Comb" },
    [89080] = { mapID = 2395, x = 0.4630, y = 0.3480, title = "Sin'dorei Outfitter's Ruler" },
    [89078] = { mapID = 2413, x = 0.7050, y = 0.5080, title = "A Child's Stuffy" },
    [89081] = { mapID = 2413, x = 0.6980, y = 0.5100, title = "Wooden Weaving Sword" },
    [89082] = { mapID = 2444, x = 0.6190, y = 0.8370, title = "Book of Sin'dorei Stitches" },
    [89083] = { mapID = 2444, x = 0.6140, y = 0.8500, title = "Satin Throw Pillow" },
}

local REPLENISH_THE_RESERVOIR_QUEST_IDS = {
    61981, -- Venthyr
    61982, -- Kyrian
    61983, -- Necrolord
    61984, -- Night Fae
}

local NZOTH_MAJOR_ASSAULTS = {
    57157, -- Uldum
    56064, -- Vale of Eternal Blossoms
}

local NZOTH_ASSAULT_DETAILS = {
    [57157] = {
        zoneSlug = "uldum",
        zoneLabel = "Uldum",
        assaultSlug = "black_empire",
        assaultLabel = "The Black Empire",
        kind = "major",
        cacheItemID = 173372,
        cacheLabel = "Cache of the Black Empire",
    },
    [56064] = {
        zoneSlug = "vale",
        zoneLabel = "Vale of Eternal Blossoms",
        assaultSlug = "black_empire",
        assaultLabel = "The Black Empire",
        kind = "major",
        cacheItemID = 173372,
        cacheLabel = "Cache of the Black Empire",
    },
    [55350] = {
        zoneSlug = "uldum",
        zoneLabel = "Uldum",
        assaultSlug = "amathet",
        assaultLabel = "Amathet Advance",
        kind = "minor",
        cacheItemID = 174961,
        cacheLabel = "Cache of the Amathet",
    },
    [56308] = {
        zoneSlug = "uldum",
        zoneLabel = "Uldum",
        assaultSlug = "aqir",
        assaultLabel = "Aqir Unearthed",
        kind = "minor",
        cacheItemID = 174960,
        cacheLabel = "Cache of the Aqir Swarm",
    },
    [57008] = {
        zoneSlug = "vale",
        zoneLabel = "Vale of Eternal Blossoms",
        assaultSlug = "mogu",
        assaultLabel = "The Warring Clans",
        kind = "minor",
        cacheItemID = 174958,
        cacheLabel = "Cache of the Fallen Mogu",
    },
    [57728] = {
        zoneSlug = "vale",
        zoneLabel = "Vale of Eternal Blossoms",
        assaultSlug = "mantid",
        assaultLabel = "The Endless Swarm",
        kind = "minor",
        cacheItemID = 174959,
        cacheLabel = "Cache of the Mantid Swarm",
    },
}

local NZOTH_MINOR_ASSAULTS = {
    55350, -- Amathet Advance
    56308, -- Aqir Unearthed
    57008, -- The Warring Clans
    57728, -- The Endless Swarm
}

local NYALOTHA_WING_ACHIEVEMENTS = {
    {
        achievementID = 14193,
        label = "Vision of Destiny",
        bosses = 3,
    },
    {
        achievementID = 14194,
        label = "Halls of Devotion",
        bosses = 4,
    },
    {
        achievementID = 14195,
        label = "Gift of Flesh",
        bosses = 3,
    },
    {
        achievementID = 14196,
        label = "The Waking Dream",
        bosses = 2,
        nzothCriterionIndex = 2,
    },
}

local VISIONS_OF_NZOTH_OPTIONAL_STEPS = {
    {
        key = "corruptors_end",
        label = "Ny'alotha, the Waking City: The Corruptor's End",
        activeQuestIDs = { CORRUPTORS_END_QUEST_ID },
        completedQuestIDs = { CORRUPTORS_END_QUEST_ID },
    },
    {
        key = "accessing_the_archives",
        label = "Accessing the Archives",
        activeQuestIDs = { ACCESSING_THE_ARCHIVES_QUEST_ID },
        completedQuestIDs = { ACCESSING_THE_ARCHIVES_QUEST_ID },
    },
    {
        key = "remnants_of_a_shattered_world",
        label = "Remnants of a Shattered World",
        activeQuestIDs = { REMNANTS_OF_A_SHATTERED_WORLD_QUEST_ID },
        activeTitles = { "Remnants of a Shattered World" },
    },
}

local LEGENDARY_CLOAK_MAX_RANK = 15
local LEGENDARY_CLOAK_UPGRADE_STEPS = {
    {
        questID = BEGINNING_THE_DESCENT_QUEST_ID,
        rank = 1,
        label = "Beginning the Descent",
    },
    {
        questID = REMNANTS_OF_A_SHATTERED_WORLD_QUEST_ID,
        rank = 2,
        label = "Remnants of a Shattered World",
        activeTitles = { "Remnants of a Shattered World" },
    },
    {
        questID = 57391,
        rank = 3,
        label = "Reconstructing \"The Curse of Stone\" (1)",
    },
    {
        questID = 57392,
        rank = 4,
        label = "Reconstructing \"The Curse of Stone\" (2)",
    },
    {
        questID = 57402,
        rank = 5,
        label = "Reconstructing \"The Curse of Stone\" (3)",
    },
    {
        questID = 57393,
        rank = 6,
        label = "Stepping Through the Darkness",
    },
    {
        questID = 57394,
        rank = 7,
        label = "Reconstructing \"Fear and Flesh\" (1)",
    },
    {
        questID = 57395,
        rank = 8,
        label = "Reconstructing \"Fear and Flesh\" (2)",
    },
    {
        questID = 57396,
        rank = 9,
        label = "Reconstructing \"Fear and Flesh\" (3)",
    },
    {
        questID = 57403,
        rank = 10,
        label = "Reconstructing \"Fear and Flesh\" (4)",
    },
    {
        questID = 57397,
        rank = 11,
        label = "Reconstructing \"Fear and Flesh\" (5)",
    },
    {
        questID = 57398,
        rank = 12,
        label = "Walking in the Darkness",
    },
    {
        questID = 57399,
        rank = 13,
        label = "Reconstructing \"The Final Truth\" (1)",
    },
    {
        questID = 57400,
        rank = 14,
        label = "Reconstructing \"The Final Truth\" (2)",
    },
    {
        questID = 57401,
        rank = 15,
        label = "Reconstructing \"The Final Truth\" (3)",
    },
}

local DEFAULT_POSITION = {
    point = "TOPLEFT",
    relativePoint = "TOPLEFT",
    x = 14,
    y = -8,
}

local EMPTY_TABLE = {}
local TRACKER_DEFAULTS = {
    debugEnabled = true,
    hideInCombat = false,
    trackAbundance = true,
    trackSoiree = true,
    trackNeighborhood = true,
    trackLiadrin = true,
    trackWorldBossGold = true,
    trackWorldBossItemLevel = true,
    trackMidnightShowdownWorldBoss = true,
    trackTreatises = true,
    trackProfessionWeeklies = true,
    trackProfessionDarkmoon = true,
    trackProfessionLoots = true,
    trackProfessionDisenchants = true,
    -- Heritees : `trackProfessionGear` les a absorbees. Elles restent
    -- declarees pour que la migration ait une valeur a lire et qu'un retour a
    -- une version precedente retrouve son reglage.
    trackProfessionTools = true,
    trackProfessionToolEnchants = true,
    trackProfessionGear = true,
    trackSparksOfTides = true,
    autoBuyAbundanceEnchantingBags = false,
    autoBuyAbundanceFusedVitality = false,
    autoOpenContainers = false,
    trackRecipePotionRecklessness = true,
    trackRecipeViciousThalassianFlaskHonor = true,
    trackRecipeConcentratedSilvermoonHealthPotion = true,
    trackRecipeHaranirMulticrafting = true,
    trackRecipeHaranirGlamour = true,
    trackHaranirLegends = true,
    trackResearchingVoidstorm = true,
    refreshDelaySeconds = 0.20,
    questStateCacheTTLSeconds = 5,
    questRewardCacheTTLSeconds = 30,
    questRewardMissCacheTTLSeconds = 2,
    debugLogLimit = 400,
}
runtimeState.trackingOptions = {
    { category = "Quetes generales", key = "trackAbundance", label = "Abondance" },
    { category = "Quetes generales", key = "trackSoiree", label = "Soiree" },
    { category = "Quetes generales", key = "trackNeighborhood", label = "Neighborhood" },
    { category = "Quetes generales", key = "trackLiadrin", label = "Liadrin" },
    { category = "Quetes generales", key = "trackWorldBossGold", label = "World boss si gold" },
    { category = "Quetes generales", key = "trackWorldBossItemLevel", label = "World boss si ilvl" },
    { category = "Quetes generales", key = "trackMidnightShowdownWorldBoss", label = "World boss Val/Naigtal" },
    { category = "Ressources Midnight", key = "trackSparksOfTides", label = "Sparks of Tides" },
    { category = "Metiers Midnight", key = "trackTreatises", label = "Traites (inscription)" },
    { category = "Metiers Midnight", key = "trackProfessionWeeklies", label = "Weeklies metiers (trainer)" },
    { category = "Metiers Midnight", key = "trackProfessionDarkmoon", label = "DMF metiers" },
    { category = "Metiers Midnight", key = "trackProfessionLoots", label = "Loots metiers" },
    { category = "Metiers Midnight", key = "trackProfessionDisenchants", label = "Dez Enchantement" },
    { category = "Metiers Midnight", key = "trackProfessionGear", label = "Equipement de metier : outils, accessoires, enchantements" },
    { category = "Marchand Abondance", key = "autoBuyAbundanceEnchantingBags", label = "Acheter automatiquement les sacs de matériaux d'enchantement" },
    { category = "Marchand Abondance", key = "autoBuyAbundanceFusedVitality", label = "Acheter automatiquement les Fused Vitality" },
    { category = "Conteneurs", key = "autoOpenContainers", label = "Proposer l'ouverture securisee des conteneurs YWT" },
    { category = "Recettes Midnight", key = "trackRecipePotionRecklessness", label = "Potion of Recklessness" },
    { category = "Recettes Midnight", key = "trackRecipeViciousThalassianFlaskHonor", label = "Vicious Thalassian Flask of Honor" },
    { category = "Recettes Midnight", key = "trackRecipeConcentratedSilvermoonHealthPotion", label = "Concentrated Silvermoon Health Potion" },
    { category = "Recettes Midnight", key = "trackRecipeHaranirMulticrafting", label = "Enchant Tool - Haranir Multicrafting" },
    { category = "Recettes Midnight", key = "trackRecipeHaranirGlamour", label = "Gleeful Glamour - Haranir" },
    { category = "Quetes Midnight", key = "trackHaranirLegends", label = "Lost Legends" },
    { category = "Quetes Midnight", key = "trackResearchingVoidstorm", label = "Research Console: Exploring the Void" },
}
local TRACKED_ASSAULT_CACHE_ITEM_IDS = {}
local NZOTH_ASSAULT_DETAILS_BY_ITEM_ID = {}
local trackerFrame
local scanTooltip
local activeCacheOpen
runtimeState.activeCacheFinalizeToken = 0
runtimeState.trackerRefreshToken = 0
runtimeState.midnightRecipeStatePending = false
runtimeState.midnightVoidlightMarlCurrencyID = 3316
runtimeState.midnightRecipeVoidlightMarlCost = 1500
runtimeState.midnightRecipeTransferDataPending = false
runtimeState.midnightRecipeTransferMenuPending = false
runtimeState.midnightRecipeTransferRequestToken = 0
runtimeState.midnightRecipeTransferPendingAt = nil
runtimeState.midnightRecipeTransferStartingQuantity = nil
runtimeState.midnightRecipeTransferRequestedQuantity = nil
runtimeState.midnightRecipeTransferRecoveryAvailable = false
runtimeState.midnightRecipeTransferTimeoutSeconds = 20
runtimeState.trackerNeedsJardOwnerRefresh = false
runtimeState.trackerRefreshDeferredByCombat = false
runtimeState.tradeSkillBootstrapAttempted = false
runtimeState.tradeSkillBootstrapPending = false
runtimeState.tradeSkillBootstrapArmed = false
runtimeState.tradeSkillBootstrapProfessionID = nil
runtimeState.itemDataLoadPending = {}
runtimeState.itemDataLoadRetryAt = {}
runtimeState.itemDataLoadCooldownSeconds = 5
-- Les globals de stat exposes par le client sont ITEM_MOD_<STAT>_SHORT : les
-- variantes ITEM_MOD_<STAT>_RATING* n'existent pas, donc la detection reposait
-- en pratique sur les seuls alias. Or les libelles localises sont des faux amis
-- entre langues : en francais Resourcefulness s'affiche "Ingeniosite" et
-- Ingenuity "Inventivite", donc l'alias "ingeniosite" attache a Ingenuity
-- classait tout outil RF comme outil Ingenuity.
runtimeState.professionToolEnchantments = {
    statOrder = { "perception", "resourcefulness", "finesse", "multicrafting", "ingenuity", "deftness" },
    byStat = {
        perception = {
            label = "Perception",
            shortLabel = "Perception",
            itemID = 243965,
            enchantID = 7975,
            statKeys = { "ITEM_MOD_PERCEPTION_SHORT" },
            tooltipAliases = { "perception" },
        },
        resourcefulness = {
            label = "Resourcefulness",
            shortLabel = "RF",
            itemID = 243967,
            enchantID = 7977,
            statKeys = { "ITEM_MOD_RESOURCEFULNESS_SHORT", "PROFESSIONS_OUTPUT_RESOURCEFULNESS_TITLE" },
            tooltipAliases = { "resourcefulness", "ingéniosité" },
        },
        finesse = {
            label = "Finesse",
            shortLabel = "Finesse",
            itemID = 243993,
            enchantID = 8003,
            statKeys = { "ITEM_MOD_FINESSE_SHORT" },
            tooltipAliases = { "finesse" },
        },
        multicrafting = {
            label = "Multicrafting",
            shortLabel = "MC",
            itemID = 243995,
            enchantID = 8005,
            statKeys = { "ITEM_MOD_MULTICRAFT_SHORT", "PROFESSIONS_OUTPUT_MULTICRAFT_TITLE" },
            tooltipAliases = { "multicrafting", "multicraft", "fabrication multiple" },
        },
        ingenuity = {
            label = "Ingenuity",
            shortLabel = "Ingenuity",
            itemID = 244025,
            enchantID = 8035,
            statKeys = { "ITEM_MOD_INGENUITY_SHORT", "PROFESSIONS_OUTPUT_INGENUITY_TITLE" },
            tooltipAliases = { "ingenuity", "inventivité" },
        },
        deftness = {
            label = "Deftness",
            shortLabel = "Deftness",
            itemID = 244023,
            enchantID = 8033,
            statKeys = {
                "ITEM_MOD_DEFTNESS_SHORT",
                "ITEM_MOD_CRAFTING_SPEED_SHORT",
            },
            tooltipAliases = {
                "deftness",
                "adresse",
                "crafting speed",
                "vitesse d’artisanat",
                "vitesse d'artisanat",
            },
        },
    },
}
-- Equipement de metier : l'outil plus ses accessoires. La stat d'un outil est
-- tiree au hasard sur l'exemplaire, mais les accessoires portent des stats
-- fixes : leur conformite ne depend donc que de la rarete et du niveau d'objet.
-- Le seuil est strict (`> minimumItemLevel`), soit du bleu au-dessus de 232.
runtimeState.professionGear = {
    minimumQuality = 3,
    -- Seuil inclusif : un objet est conforme a partir de ce niveau. Les objets
    -- de metier rares plafonnent a 232 (rang de craft maximal), donc exiger
    -- strictement plus de 232 imposerait de l'epique et rendrait le rappel
    -- impossible a satisfaire en bleu. Reglable par `/ywt stuff ilvl <n>`.
    minimumItemLevel = 232,
    -- L'alchimie profite du Multicraft sur ses consommables et YayaQueue equipe
    -- l'outil correspondant juste avant ces crafts : il faut donc en posseder un
    -- exemplaire, en plus de l'outil Resourcefulness porte par defaut. Possession
    -- et non port : l'echange sort l'outil porte vers les sacs, donc un outil
    -- Multicrafting deja equipe se prete au meme va-et-vient qu'un outil garde
    -- en sac. Exiger le sac reclamait un second exemplaire des que le premier
    -- etait porte.
    multicraftToolSkillLineIDs = { [2906] = true },
    -- Rang rare (bleu) de l'equipement de metier Midnight : l'outil, puis les
    -- deux accessoires. Ces itemIDs ne sont que des CANDIDATS : chacun est
    -- valide en jeu (emplacement d'equipement et ligne de metier) avant d'etre
    -- propose, pour qu'une donnee fausse n'ajoute jamais un objet inadapte a la
    -- file. Le rang de craft d'un objet ne change pas son itemID, seulement ses
    -- bonusId : un achat ne peut donc pas viser un ilvl precis.
    rareCandidatesBySkillLineID = {
        [2906] = { tool = 245778, gear = { 239635, 244626 } },
        [2907] = { tool = 238018, gear = { 237952, 244628 } },
        [2909] = { tool = 244176, gear = { 239637, 240960 } },
        [2910] = { tool = 244718, gear = { 244624, 244710 } },
        [2912] = { tool = 238014, gear = { 239639, 244621 } },
        [2913] = { tool = 245776, gear = { 240957, 240958 } },
        [2914] = { tool = 244714, gear = { 240959, 244630 } },
        [2915] = { tool = 238017, gear = { 237951, 244625 } },
        [2916] = { tool = 238015, gear = { 244716, 244720 } },
        [2917] = { tool = 238016, gear = { 244622, 244623 } },
        [2918] = { tool = 244708, gear = { 237950, 239640 } },
    },
}
runtimeState.abundanceEnchantingBagItemID = 250755
runtimeState.abundanceFusedVitalityItemID = 245345
runtimeState.abundancePurchaseTargets = {
    { itemID = 250755, optionKey = "autoBuyAbundanceEnchantingBags", requiresEnchanting = true, priority = 1 },
    { itemID = 245345, optionKey = "autoBuyAbundanceFusedVitality", priority = 2 },
}
runtimeState.abundanceEnchantingPurchaseGeneration = 0
runtimeState.abundanceEnchantingPurchaseScheduled = false
runtimeState.abundanceEnchantingPurchaseAttempted = false
runtimeState.abundanceEnchantingPurchasePending = nil
runtimeState.abundanceEnchantingPurchaseRetryCount = 0
runtimeState.abundanceEnchantingPurchaseStalledCount = 0
runtimeState.abundancePurchaseSkippedItems = {}
runtimeState.abundanceEnchantingPurchaseRetryLimit = 20
runtimeState.abundanceEnchantingPurchaseDelaySeconds = 0.15
runtimeState.bagScanRetryLimit = 12
runtimeState.bagScanRetryDelaySeconds = 0.25
runtimeState.bagScanRetryCount = {}
runtimeState.bagScanRetryQueued = {}
runtimeState.bagScanRetryToken = {}
runtimeState.itemActionRefreshPending = false
runtimeState.itemActionForceBagRefresh = false
runtimeState.toolEnchantApplicationPending = {}
local questStateCache = {}
local questRewardCache = {}
local midnightCaches = {
    trackedProfessions = nil,
    trackedProfessionsDirty = true,
    knowledge = nil,
    knowledgeDirty = true,
    recipeItems = nil,
    recipeItemsDirty = true,
    payout = nil,
    payoutDirty = true,
    surplusReagents = nil,
    surplusReagentsDirty = true,
    finishingReagentMerges = nil,
    finishingReagentMergesDirty = true,
    -- L'instantane lui-meme vit dans le SavedVariable ; ce drapeau ne dit que
    -- s'il faut le reecrire au prochain passage banque ouverte.
    warbankInventoryDirty = true,
    toolEnchants = nil,
    toolEnchantsDirty = true,
}
local treasureWaypointUIDs = {}
local treasureWaypointSignature
local knowledgeBookWaypointUIDs = {}
local knowledgeBookWaypointSignature
local debugSignatures = {
    knowledge = nil,
    recipeItems = nil,
    payout = nil,
    surplusReagents = nil,
    finishingReagentMerges = nil,
    trackedProfessions = nil,
    tracker = nil,
    treasure = nil,
    midnightTreatises = nil,
    warbankInventory = nil,
    toolEnchants = nil,
    professionSupplyPlan = nil,
}
local GetContainerItemIDCompat
local GetContainerNumSlotsCompat
local GetContainerItemLinkCompat
local GetDateAtNoonTimestamp
local AddEntry
local UpdateTracker
local ScheduleTrackerRefresh
local trackerUI = {}

trackerUI.IsContainerOpeningBlocked = function()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance or (type(instanceType) == "string" and instanceType ~= "none") then
            return true
        end
    end
    if GetInstanceInfo then
        local _, instanceType = GetInstanceInfo()
        if type(instanceType) == "string" and instanceType ~= "none" then
            return true
        end
    end
    return false
end

trackerUI.RegisterContainerActionButton = function(button)
    if not button or button.ywtContainerVisibilityParent then
        return
    end
    local visibilityParent = trackerFrame and trackerFrame.containerActionVisibilityFrame
    if visibilityParent and type(button.SetParent) == "function" then
        button:SetParent(visibilityParent)
        button.ywtContainerVisibilityParent = true
    end
end

trackerUI.HideContainerActionButtons = function()
    if not trackerFrame then
        return
    end
    -- Ces boutons heritent de SecureActionButtonTemplate : Hide est protege.
    -- L'appelant est PLAYER_REGEN_DISABLED, donc le lockdown est deja actif et
    -- les appels echouaient en silence, laissant IsShown() a true alors que le
    -- state driver [combat] hide du parent avait bien masque le bouton. On
    -- laisse donc le state driver faire seul le travail en combat.
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if trackerFrame.payoutButton then
        trackerFrame.payoutButton:Hide()
    end
    if trackerFrame.autoOpenButton then
        trackerFrame.autoOpenButton:Hide()
    end
    for _, button in ipairs(trackerFrame.surplusReagentButtons or EMPTY_TABLE) do
        button:Hide()
    end
end

trackerUI.LockItemActionButton = function(button)
    if not button then
        return false
    end
    if button.itemActionLocked then
        return false
    end

    button.itemActionLocked = true
    if button.SetEnabled then
        button:SetEnabled(false)
    end
    return true
end

trackerUI.UnlockItemActionButtons = function()
    local frame = trackerFrame
    if not frame then
        return
    end

    local function Unlock(button)
        if button and button.itemActionLocked then
            -- BAG_UPDATE_DELAYED arrive environ 0,3 s apres la consommation,
            -- bien avant la fin d'un cooldown de 5 s : deverrouiller ici
            -- reactivait le bouton trop tot.
            if trackerUI.GetItemActionCooldownRemaining(trackerUI.GetButtonItemTarget(button)) > 0 then
                -- Deverrouillage differe : c'est ApplyItemActionCooldownGate qui
                -- rendra la main a la fin du cooldown.
                button.itemActionCooldownLocked = true
                return
            end
            button.itemActionLocked = false
            button.itemActionCooldownLocked = nil
            if button.SetEnabled then
                button:SetEnabled(true)
            end
        end
    end

    Unlock(frame.recipeButton)
    Unlock(frame.knowledgeButton)
    Unlock(frame.payoutButton)
    -- Le bouton d'approvisionnement se verrouille le temps d'un transfert :
    -- sans ce deverrouillage il resterait grise a vie.
    Unlock(frame.professionSupplyButton)
    for _, button in ipairs(frame.surplusReagentButtons or EMPTY_TABLE) do
        Unlock(button)
    end
    for _, button in ipairs(frame.finishingReagentMergeButtons or EMPTY_TABLE) do
        Unlock(button)
    end
    for _, button in ipairs(frame.toolEnchantApplyButtons or EMPTY_TABLE) do
        Unlock(button)
    end
end

trackerUI.RequestItemActionRefresh = function()
    runtimeState.itemActionForceBagRefresh = true
    ScheduleTrackerRefresh(0, false)
end

for _, details in pairs(NZOTH_ASSAULT_DETAILS) do
    TRACKED_ASSAULT_CACHE_ITEM_IDS[details.cacheItemID] = true

    if not NZOTH_ASSAULT_DETAILS_BY_ITEM_ID[details.cacheItemID] then
        NZOTH_ASSAULT_DETAILS_BY_ITEM_ID[details.cacheItemID] = details
    elseif NZOTH_ASSAULT_DETAILS_BY_ITEM_ID[details.cacheItemID].zoneSlug ~= details.zoneSlug then
        NZOTH_ASSAULT_DETAILS_BY_ITEM_ID[details.cacheItemID] = false
    end
end

-- Propage jusqu'a CINQ valeurs de retour. Deux consequences a garder en tete :
-- lire au-dela de la cinquieme rend toujours nil, et imbriquer un SafeCall dans
-- une fonction qui interprete son deuxieme argument passe les retours suivants
-- en prime. `tonumber(SafeCall(GetDetailedItemLevelInfo, link))` prenait ainsi
-- le booleen d'apercu pour une base numerique et levait. Affecter d'abord dans
-- une variable pour ne retenir que la premiere valeur.
local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result1, result2, result3, result4, result5 = pcall(func, ...)
    if not ok then
        return nil
    end

    return result1, result2, result3, result4, result5
end

local function HasSavedPosition(db)
    return db and db.point and db.relativePoint and db.x and db.y
end

local function GetAccountDB()
    YayaWeeklyTrackerAccountDB = YayaWeeklyTrackerAccountDB or {}
    if YayaWeeklyTrackerAccountDB.hideInCombat == nil then
        YayaWeeklyTrackerAccountDB.hideInCombat = TRACKER_DEFAULTS.hideInCombat
    end
    if YayaWeeklyTrackerAccountDB.trackProfessionLoots == nil then
        if YayaWeeklyTrackerAccountDB.trackProfessionWeeklies == false then
            YayaWeeklyTrackerAccountDB.trackProfessionLoots = false
        else
            YayaWeeklyTrackerAccountDB.trackProfessionLoots = TRACKER_DEFAULTS.trackProfessionLoots
        end
    end
    if YayaWeeklyTrackerAccountDB.trackProfessionDisenchants == nil then
        if YayaWeeklyTrackerAccountDB.trackProfessionWeeklies == false then
            YayaWeeklyTrackerAccountDB.trackProfessionDisenchants = false
        else
            YayaWeeklyTrackerAccountDB.trackProfessionDisenchants = TRACKER_DEFAULTS.trackProfessionDisenchants
        end
    end
    if YayaWeeklyTrackerAccountDB.trackProfessionDarkmoon == nil then
        if YayaWeeklyTrackerAccountDB.trackProfessionWeeklies == false then
            YayaWeeklyTrackerAccountDB.trackProfessionDarkmoon = false
        else
            YayaWeeklyTrackerAccountDB.trackProfessionDarkmoon = TRACKER_DEFAULTS.trackProfessionDarkmoon
        end
    end
    if YayaWeeklyTrackerAccountDB.trackMidnightRecipes == false then
        for _, key in ipairs({
            "trackRecipePotionRecklessness",
            "trackRecipeViciousThalassianFlaskHonor",
            "trackRecipeConcentratedSilvermoonHealthPotion",
            "trackRecipeHaranirMulticrafting",
            "trackRecipeHaranirGlamour",
        }) do
            if YayaWeeklyTrackerAccountDB[key] == nil then
                YayaWeeklyTrackerAccountDB[key] = false
            end
        end
    end
    -- `trackProfessionGear` a absorbe `trackProfessionTools` et
    -- `trackProfessionToolEnchants`, qui decoupaient la meme regle en trois.
    -- La valeur retenue est le OU des trois : personne ne perd un rappel qu'il
    -- avait active. Les anciennes cles ne sont pas effacees -- un retour a une
    -- version precedente les relirait.
    if YayaWeeklyTrackerAccountDB.trackProfessionGearMerged == nil then
        YayaWeeklyTrackerAccountDB.trackProfessionGearMerged = true
        local merged = YayaWeeklyTrackerAccountDB.trackProfessionGear ~= false
            or YayaWeeklyTrackerAccountDB.trackProfessionTools ~= false
            or YayaWeeklyTrackerAccountDB.trackProfessionToolEnchants ~= false
        YayaWeeklyTrackerAccountDB.trackProfessionGear = merged
    end
    for _, option in ipairs(runtimeState.trackingOptions) do
        if YayaWeeklyTrackerAccountDB[option.key] == nil then
            YayaWeeklyTrackerAccountDB[option.key] = TRACKER_DEFAULTS[option.key]
        end
    end
    return YayaWeeklyTrackerAccountDB
end

local function GetCharacterDB()
    YayaWeeklyTrackerDB = YayaWeeklyTrackerDB or {}
    return YayaWeeklyTrackerDB
end

local function IsDebugEnabled()
    local db = YayaWeeklyTrackerAccountDB
    if type(db) ~= "table" or db.debugEnabled == nil then
        return TRACKER_DEFAULTS.debugEnabled
    end

    return db.debugEnabled and true or false
end

local function SetDebugEnabled(enabled)
    GetAccountDB().debugEnabled = enabled and true or false
end

local function AppendPersistentDebugLog(message)
    local accountDB = GetAccountDB()
    accountDB.debugLog = accountDB.debugLog or {}

    local timestamp = date and date("%H:%M:%S") or tostring(math.floor(GetTime and GetTime() or 0))
    local entry = ("[%s] %s"):format(timestamp, tostring(message or ""))
    -- Tampon circulaire : la purge precedente appelait table.remove(t, 1), qui
    -- recopie tout le journal a chaque ligne au-dela de la limite de 400.
    YayaCore.RingBuffer.Push(accountDB.debugLog, entry, TRACKER_DEFAULTS.debugLogLimit)
end

local function PrintPersistentDebugLog(limit)
    local lines = YayaCore.RingBuffer.Read(
        GetAccountDB().debugLog or {},
        math.max(1, math.floor(tonumber(limit) or 20))
    )
    for index = 1, #lines do
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(YayaCore.UI.HEX.accent .. "YWT|r: " .. lines[index])
        elseif print then
            print("YWT: " .. lines[index])
        end
    end
end

local function ClearPersistentDebugLog()
    GetAccountDB().debugLog = {}
end

-- Journalise une erreur fatale sans dependre du mode debug, et l'imprime une
-- seule fois par message distinct. La ligne affichee dans la frame est tronquee
-- par sa largeur : le chat et le journal persistant en gardent le texte entier,
-- lisible apres coup avec `/ywt log`.
runtimeState.lastFatalDiagnostic = nil
runtimeState.LogFatalDiagnostic = function(message)
    local text = tostring(message or "erreur inconnue")
    -- Un rafraichissement echoue se repete plusieurs fois par seconde : sans
    -- cette garde, le journal se remplirait du meme message et ecraserait
    -- l'historique utile.
    if runtimeState.lastFatalDiagnostic == text then
        return
    end
    runtimeState.lastFatalDiagnostic = text
    AppendPersistentDebugLog("YWT FATAL " .. text)

    local line = "YWT: erreur, texte complet ci-dessous et dans /ywt log"
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(YayaCore.UI.HEX.danger .. line .. "|r")
        DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif print then
        print(line)
        print(text)
    end
end

local function DebugLog(message, ...)
    if not IsDebugEnabled() then
        return
    end

    local text = tostring(message or "")
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        text = ok and formatted or text
    end

    AppendPersistentDebugLog("YWT DEBUG " .. text)

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(YayaCore.UI.HEX.accent .. "YWT DEBUG|r " .. text)
        return
    end

    if print then
        print("YWT DEBUG " .. text)
    end
end

-- Ces quatre valeurs sont des champs de trackerUI, pas des locaux de chunk :
-- Lua 5.1 plafonne un chunk a 200 variables locales et ce fichier est a 198.
-- Quatre locaux de plus et le fichier ne compile plus du tout, donc l'addon
-- entier ne s'execute pas : ni section, ni boutons, ni ouverture de conteneur.
trackerUI.itemActionCooldownButtonFields = {
    "recipeButton",
    "knowledgeButton",
    "payoutButton",
}
trackerUI.itemActionCooldownButtonLists = {
    "surplusReagentButtons",
    "finishingReagentMergeButtons",
    "toolEnchantApplyButtons",
}

trackerUI.GetButtonItemTarget = function(button)
    if not button then
        return nil
    end
    -- itemID d'abord : C_Item.GetItemCooldown l'accepte directement, alors qu'un
    -- nom depend d'un cache d'objet chaud et reste ambigu entre deux homonymes.
    return button.itemID
        or button.itemLink
        or button.itemName
        or nil
end

-- IsUsableItem ne rend compte que du niveau, de la classe et de la spe : elle
-- ignore totalement les cooldowns. Entre deux traites, le second bouton restait
-- donc actif, l'action securisee partait, le serveur la rejetait en silence, la
-- pile ne bougeait pas et le bouton paraissait casse. On lit le cooldown reel.
trackerUI.GetItemActionCooldownRemaining = function(itemTarget)
    if not itemTarget then
        return 0
    end
    local getCooldown = C_Item and C_Item.GetItemCooldown
    if type(getCooldown) ~= "function" then
        return 0
    end
    local ok, startTime, duration, enabled = pcall(getCooldown, itemTarget)
    if not ok or enabled == false then
        return 0
    end
    startTime = tonumber(startTime) or 0
    duration = tonumber(duration) or 0
    if startTime <= 0 or duration <= 0 then
        return 0
    end
    return math.max(0, startTime + duration - (GetTime and GetTime() or 0))
end

trackerUI.StripItemActionCountdown = function(button)
    if type(button.GetText) ~= "function" or type(button.SetText) ~= "function" then
        return
    end
    -- gsub renvoie deux valeurs : on isole la chaine avant de la passer a SetText.
    local baseText = (button:GetText() or ""):gsub("%s*%(%d+s%)$", "")
    button:SetText(baseText)
end

trackerUI.ApplyItemActionCooldownGate = function(button)
    if not button then
        return 0
    end

    local remaining = trackerUI.GetItemActionCooldownRemaining(trackerUI.GetButtonItemTarget(button))
    if remaining <= 0 then
        -- C'est ici que le verrou est rendu, pas dans UnlockItemActionButtons :
        -- cette derniere ne tourne que sur BAG_UPDATE_DELAYED, occasion deja
        -- consommee pendant le cooldown. Sans cette branche le bouton restait
        -- desactive pour toujours apres un traite.
        if button.itemActionCooldownLocked then
            button.itemActionCooldownLocked = nil
            button.itemActionLocked = false
            if button.SetEnabled then
                button:SetEnabled(true)
            end
            trackerUI.StripItemActionCountdown(button)
            DebugLog(
                "ItemActionCooldown release button=%s item=%s",
                tostring(button:GetName() or "?"),
                tostring(trackerUI.GetButtonItemTarget(button) or "none")
            )
        end
        return 0
    end

    -- Le cooldown court toujours : on le renvoie meme si le bouton est masque,
    -- pour que le rafraichissement reste programme et que la liberation arrive.
    if not button.itemActionCooldownLocked then
        DebugLog(
            "ItemActionCooldown hold button=%s item=%s remaining=%.2f",
            tostring(button:GetName() or "?"),
            tostring(trackerUI.GetButtonItemTarget(button) or "none"),
            remaining
        )
    end
    button.itemActionCooldownLocked = true
    if type(button.IsShown) ~= "function" or not button:IsShown() then
        return remaining
    end

    if button.SetEnabled then
        button:SetEnabled(false)
    end
    if type(button.GetText) == "function" and type(button.SetText) == "function" then
        local baseText = (button:GetText() or ""):gsub("%s*%(%d+s%)$", "")
        button:SetText(("%s (%ds)"):format(baseText, math.ceil(remaining)))
    end
    return remaining
end

-- Applique le gate a tous les boutons d'objet du tracker, puis reprogramme un
-- rafraichissement a la fin du cooldown le plus long pour que le compte a
-- rebours affiche reste juste et que le bouton se reactive tout seul.
trackerUI.ApplyItemActionCooldownGates = function()
    local frame = trackerFrame
    if not frame then
        return
    end

    local longest = 0
    for _, field in ipairs(trackerUI.itemActionCooldownButtonFields) do
        longest = math.max(longest, trackerUI.ApplyItemActionCooldownGate(frame[field]))
    end
    for _, listField in ipairs(trackerUI.itemActionCooldownButtonLists) do
        for _, button in ipairs(frame[listField] or EMPTY_TABLE) do
            longest = math.max(longest, trackerUI.ApplyItemActionCooldownGate(button))
        end
    end

    if longest > 0 then
        ScheduleTrackerRefresh(math.min(longest + 0.05, 1.0), false)
    end
end


_G.YayaWeeklyTrackerAutoOpen = _G.YayaWeeklyTrackerAutoOpen or {}
_G.YayaWeeklyTrackerAutoOpen.DebugLog = function(message, ...)
    DebugLog("AutoOpen " .. tostring(message or ""), ...)
end

trackerUI.ResetBagScanRetry = function(cacheKey)
    runtimeState.bagScanRetryCount = runtimeState.bagScanRetryCount or {}
    runtimeState.bagScanRetryQueued = runtimeState.bagScanRetryQueued or {}
    runtimeState.bagScanRetryToken = runtimeState.bagScanRetryToken or {}
    runtimeState.bagScanRetryCount[cacheKey] = 0
    runtimeState.bagScanRetryQueued[cacheKey] = nil
    runtimeState.bagScanRetryToken[cacheKey] = (runtimeState.bagScanRetryToken[cacheKey] or 0) + 1
end

trackerUI.UsePreviousBagCacheOnTransientEmpty = function(cacheKey, previousCount, currentCount, previousState)
    runtimeState.bagScanRetryCount = runtimeState.bagScanRetryCount or {}

    if runtimeState.itemActionForceBagRefresh
        and (cacheKey == "recipeItems"
            or cacheKey == "payout"
            or cacheKey == "surplusReagents"
            or cacheKey == "finishingReagentMerges")
    then
        trackerUI.ResetBagScanRetry(cacheKey)
        return false
    end

    -- A partial result is authoritative: only protect a completely empty scan.
    if currentCount ~= 0 or previousCount <= 0 then
        trackerUI.ResetBagScanRetry(cacheKey)
        return false
    end

    if cacheKey ~= "trackedProfessions" and type(previousState) == "table" then
        local itemIDs = {}
        if type(previousState.countsByItemID) == "table" then
            for itemID in pairs(previousState.countsByItemID) do
                itemIDs[tonumber(itemID) or itemID] = true
            end
        elseif previousState.itemID then
            itemIDs[tonumber(previousState.itemID) or previousState.itemID] = true
        else
            for _, state in ipairs(previousState) do
                if type(state) == "table" and state.itemID then
                    itemIDs[tonumber(state.itemID) or state.itemID] = true
                end
            end
        end

        local checkedItemCount = 0
        local hasOwnedItem = false
        for itemID in pairs(itemIDs) do
            checkedItemCount = checkedItemCount + 1
            local owned = C_Item and SafeCall(C_Item.GetItemCount, itemID, false, false, false, false)
                or SafeCall(GetItemCount, itemID)
            if (tonumber(owned) or 0) > 0 then
                hasOwnedItem = true
                break
            end
        end
        if checkedItemCount == 0 or not hasOwnedItem then
            trackerUI.ResetBagScanRetry(cacheKey)
            return false
        end
    end

    if not (C_Timer and C_Timer.After) then
        trackerUI.ResetBagScanRetry(cacheKey)
        return false
    end

    local retryCount = (runtimeState.bagScanRetryCount[cacheKey] or 0) + 1
    local retryLimit = runtimeState.bagScanRetryLimit or 12
    if retryCount > retryLimit then
        trackerUI.ResetBagScanRetry(cacheKey)
        DebugLog(
            "Bag scan empty accepted cache=%s after=%d retries",
            tostring(cacheKey),
            retryLimit
        )
        return false
    end

    runtimeState.bagScanRetryCount[cacheKey] = retryCount
    runtimeState.bagScanRetryQueued = runtimeState.bagScanRetryQueued or {}
    runtimeState.bagScanRetryToken = runtimeState.bagScanRetryToken or {}
    if not runtimeState.bagScanRetryQueued[cacheKey] then
        runtimeState.bagScanRetryQueued[cacheKey] = true
        runtimeState.bagScanRetryToken[cacheKey] = (runtimeState.bagScanRetryToken[cacheKey] or 0) + 1
        local retryToken = runtimeState.bagScanRetryToken[cacheKey]
        C_Timer.After(runtimeState.bagScanRetryDelaySeconds or 0.25, function()
            if runtimeState.bagScanRetryToken[cacheKey] ~= retryToken then
                return
            end
            runtimeState.bagScanRetryQueued[cacheKey] = nil
            if cacheKey == "trackedProfessions" then
                midnightCaches.trackedProfessionsDirty = true
            elseif cacheKey == "knowledge" then
                midnightCaches.knowledgeDirty = true
            elseif cacheKey == "recipeItems" then
                midnightCaches.recipeItemsDirty = true
            elseif cacheKey == "payout" then
                midnightCaches.payoutDirty = true
            elseif cacheKey == "surplusReagents" then
                midnightCaches.surplusReagentsDirty = true
            elseif cacheKey == "finishingReagentMerges" then
                midnightCaches.finishingReagentMergesDirty = true
            end

            if ScheduleTrackerRefresh then
                ScheduleTrackerRefresh(0, false)
            elseif UpdateTracker then
                UpdateTracker()
            end
        end)
    end

    if retryCount == 1 or retryCount == retryLimit then
        DebugLog(
            "Bag scan transient empty cache=%s previous=%d retry=%d",
            tostring(cacheKey),
            previousCount,
            retryCount
        )
    end
    return true
end

local function DebugSafeCall(label, func, ...)
    if type(func) ~= "function" then
        DebugLog("%s: fonction absente", tostring(label))
        return nil
    end

    local ok, result1, result2, result3, result4, result5 = pcall(func, ...)
    if not ok then
        DebugLog("%s: %s", tostring(label), tostring(result1))
        return nil
    end

    return result1, result2, result3, result4, result5
end

local function GetPlayerKey()
    local name = UnitName and UnitName("player")
    if not name or name == "" then
        return
    end

    local realm = GetRealmName and GetRealmName() or ""
    return realm ~= "" and (realm .. "." .. name) or name
end

local function GetNow()
    return time and time() or 0
end

local function GetCachedBoolean(cache, key)
    local entry = cache[key]
    local now = GetNow()
    if entry and entry.expiresAt and entry.expiresAt > now then
        return entry.value
    end
end

local function SetCachedBoolean(cache, key, value, ttlSeconds)
    cache[key] = {
        value = value and true or false,
        expiresAt = GetNow() + ttlSeconds,
    }
    return value
end

local function InvalidateQuestCaches()
    wipe(questStateCache)
    wipe(questRewardCache)
end

local function InvalidateTrackedMidnightProfessions()
    midnightCaches.trackedProfessionsDirty = true
end

local function InvalidateMidnightKnowledgeConsumableCache()
    midnightCaches.knowledgeDirty = true
end

trackerUI.InvalidateMidnightRecipeItemCache = function()
    midnightCaches.recipeItemsDirty = true
end

local function InvalidateArtisanConsortiumPayoutCache()
    midnightCaches.payoutDirty = true
end

trackerUI.InvalidateSurplusReagentContainerCache = function()
    midnightCaches.surplusReagentsDirty = true
end

trackerUI.InvalidateFinishingReagentMergeCache = function()
    midnightCaches.finishingReagentMergesDirty = true
end

local function GetLocalizedMapName(mapID, fallback)
    if C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then
            return mapInfo.name
        end
    end

    return fallback
end

local function GetCurrencyQuantity(currencyID)
    local eventQuantity = runtimeState.currencyQuantities[currencyID]
    if type(eventQuantity) == "number" then
        return eventQuantity
    end

    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if type(info) == "table" then
            return info.quantity or 0
        end
    end

    return 0
end

trackerUI.GetMidnightSeasonalResourceStatus = function(resource)
    if type(resource) ~= "table" or type(resource.currencyID) ~= "number" then
        return
    end

    local info = SafeCall(
        C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,
        resource.currencyID
    )
    if type(info) ~= "table" then
        return
    end

    local maximum = tonumber(info.maxQuantity) or 0
    if maximum <= 0 then
        return
    end

    local acquired = tonumber(info[resource.acquiredField or "quantity"])
    if acquired == nil then
        acquired = tonumber(info.quantity) or 0
    end

    local available
    if resource.itemID then
        available = SafeCall(
            C_Item and C_Item.GetItemCount,
            resource.itemID,
            true,
            false,
            true,
            true
        )
        if type(available) ~= "number" then
            available = SafeCall(GetItemCount, resource.itemID, true)
        end
    else
        available = tonumber(info[resource.availableField or "quantity"]) or 0
    end

    return {
        acquired = math.max(0, math.min(acquired, maximum)),
        maximum = maximum,
        available = math.max(0, tonumber(available) or 0),
    }
end

trackerUI.FormatMidnightSeasonalResourceCount = function(acquired, maximum)
    local progress = maximum > 0 and math.max(0, math.min(acquired / maximum, 1)) or 0
    local red, green, blue
    if progress <= 0.5 then
        local phase = progress * 2
        red = 1
        green = 0.20 + (0.65 - 0.20) * phase
        blue = 0.20 + (0.10 - 0.20) * phase
    else
        local phase = (progress - 0.5) * 2
        red = 1.0 + (0.30 - 1.0) * phase
        green = 0.65 + (1.0 - 0.65) * phase
        blue = 0.10 + (0.40 - 0.10) * phase
    end

    return ("|cff%02x%02x%02x%d/%d|r"):format(
        math.floor(red * 255 + 0.5),
        math.floor(green * 255 + 0.5),
        math.floor(blue * 255 + 0.5),
        acquired,
        maximum
    )
end

local function IsItemCurrentlyUsable(itemLink, itemName, itemID)
    if not IsUsableItem then
        return true
    end

    local itemTarget = itemLink or itemName or (itemID and ("item:" .. tostring(itemID))) or nil
    if not itemTarget then
        return false
    end

    local isUsable = IsUsableItem(itemTarget)
    return isUsable and true or false
end

local function BuildCurrencySnapshot()
    return {
        money = GetMoney and GetMoney() or 0,
        warResources = GetCurrencyQuantity(CURRENCY_WAR_RESOURCES),
        corruptedMementos = GetCurrencyQuantity(CURRENCY_CORRUPTED_MEMENTOS),
        coalescingVisions = GetCurrencyQuantity(CURRENCY_COALESCING_VISIONS),
    }
end

local function BuildCurrencyDelta(before, after)
    before = before or EMPTY_TABLE
    after = after or EMPTY_TABLE

    return {
        money = (after.money or 0) - (before.money or 0),
        warResources = (after.warResources or 0) - (before.warResources or 0),
        corruptedMementos = (after.corruptedMementos or 0) - (before.corruptedMementos or 0),
        coalescingVisions = (after.coalescingVisions or 0) - (before.coalescingVisions or 0),
    }
end

local function GetNzothCacheHistory()
    local accountDB = GetAccountDB()
    accountDB.nzothCacheHistory = accountDB.nzothCacheHistory or {}
    return accountDB.nzothCacheHistory
end

local function GetNextNzothCacheHistoryID()
    local accountDB = GetAccountDB()
    accountDB.nzothCacheHistoryNextID = accountDB.nzothCacheHistoryNextID or 1

    local historyID = accountDB.nzothCacheHistoryNextID
    accountDB.nzothCacheHistoryNextID = historyID + 1
    return historyID
end

local function GetPendingNzothCacheQueue()
    local playerKey = GetPlayerKey()
    if not playerKey then
        return
    end

    local accountDB = GetAccountDB()
    accountDB.pendingNzothCaches = accountDB.pendingNzothCaches or {}
    accountDB.pendingNzothCaches[playerKey] = accountDB.pendingNzothCaches[playerKey] or {}
    return accountDB.pendingNzothCaches[playerKey]
end

local function QueuePendingNzothCache(questID)
    local details = NZOTH_ASSAULT_DETAILS[questID]
    if not details then
        return
    end

    local queue = GetPendingNzothCacheQueue()
    if not queue then
        return
    end

    queue[#queue + 1] = {
        questID = questID,
        questTitle = nil,
        source = details.zoneSlug,
        sourceLabel = details.zoneLabel,
        zone = details.zoneSlug,
        zoneLabel = details.zoneLabel,
        assault = details.assaultSlug,
        assaultLabel = details.assaultLabel,
        kind = details.kind,
        cacheItemID = details.cacheItemID,
        cacheLabel = details.cacheLabel,
        turnedInAt = GetNow(),
    }
end

local function PopPendingNzothCache(cacheItemID)
    local queue = GetPendingNzothCacheQueue()
    if not queue or #queue == 0 then
        return
    end

    if cacheItemID then
        for index, entry in ipairs(queue) do
            if entry.cacheItemID == cacheItemID then
                return table.remove(queue, index)
            end
        end

        return
    end

    return table.remove(queue, 1)
end

local function MigrateLegacyPosition()
    if HasSavedPosition(YayaWeeklyTrackerAccountDB) then
        return
    end

    if not HasSavedPosition(YayaWeeklyTrackerDB) then
        return
    end

    local accountDB = GetAccountDB()
    accountDB.point = YayaWeeklyTrackerDB.point
    accountDB.relativePoint = YayaWeeklyTrackerDB.relativePoint
    accountDB.x = YayaWeeklyTrackerDB.x
    accountDB.y = YayaWeeklyTrackerDB.y
end

local function IsQuestDone(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID)
    end

    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID)
    end

    return false
end

local function HasJardRecipe()
    return IsPlayerSpell and IsPlayerSpell(JARD_SPELL_ID)
end

local function UpdateJardOwners()
    local playerKey = GetPlayerKey()
    if not playerKey then
        return
    end

    local accountDB = GetAccountDB()
    accountDB.jardOwners = accountDB.jardOwners or {}

    if not HasJardRecipe() then
        if accountDB.jardOwners[playerKey] then
            accountDB.jardOwners[playerKey] = nil
        end
        return
    end

    local name = UnitName("player")
    local realm = GetRealmName()
    local _, classFile = UnitClass("player")
    local existing = accountDB.jardOwners[playerKey]
    if existing
        and existing.name == name
        and existing.realm == realm
        and existing.class == classFile then
        return
    end

    accountDB.jardOwners[playerKey] = {
        name = name,
        realm = realm,
        class = classFile,
        updatedAt = GetNow(),
    }
end

local function IsAnyQuestDone(questIDs)
    for _, questID in ipairs(questIDs) do
        if IsQuestDone(questID) then
            return true
        end
    end

    return false
end

trackerUI.IsAnyQuestDoneOnAccount = function(questIDs)
    for _, questID in ipairs(questIDs) do
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount
            and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID) then
            return true
        end

        if IsQuestDone(questID) then
            return true
        end
    end

    return false
end

local function HasRenown80Covenant()
    if not (C_Covenants and C_Covenants.GetActiveCovenantID) then
        return false
    end

    local covenantID = C_Covenants.GetActiveCovenantID()
    if not covenantID or covenantID == 0 then
        return false
    end

    if not (C_CovenantSanctumUI and C_CovenantSanctumUI.GetRenownLevel) then
        return false
    end

    return (C_CovenantSanctumUI.GetRenownLevel() or 0) >= 80
end

local function GetQuestTitle(questID)
    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local title = C_TaskQuest.GetQuestInfoByQuestID(questID)
        if title and title ~= "" then
            return title
        end
    end

    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title and title ~= "" then
            return title
        end
    end
end

local function GetQuestMapID(questID)
    if GetQuestUiMapID then
        local mapID = GetQuestUiMapID(questID)
        if mapID and mapID > 0 then
            return mapID
        end
    end

    if C_TaskQuest and C_TaskQuest.GetQuestZoneID then
        local mapID = C_TaskQuest.GetQuestZoneID(questID)
        if mapID and mapID > 0 then
            return mapID
        end
    end
end

local function IsQuestActiveOnMap(questID, activeByQuestID)
    if activeByQuestID and activeByQuestID[questID] then
        return true
    end

    local cached = GetCachedBoolean(questStateCache, questID)
    if cached ~= nil then
        return cached
    end

    if C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then
        return SetCachedBoolean(questStateCache, questID, true, TRACKER_DEFAULTS.questStateCacheTTLSeconds)
    end

    local mapID = GetQuestMapID(questID)
    if not mapID then
        return SetCachedBoolean(questStateCache, questID, false, TRACKER_DEFAULTS.questStateCacheTTLSeconds)
    end

    if C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
        local tasks = C_TaskQuest.GetQuestsOnMap(mapID) or EMPTY_TABLE
        for _, info in ipairs(tasks) do
            if info.questID == questID then
                return SetCachedBoolean(questStateCache, questID, true, TRACKER_DEFAULTS.questStateCacheTTLSeconds)
            end
        end
    end

    if C_AreaPoiInfo and C_AreaPoiInfo.GetEventsForMap and C_AreaPoiInfo.GetAreaPOIInfo then
        local title = GetQuestTitle(questID)
        if not title then
            return SetCachedBoolean(questStateCache, questID, false, TRACKER_DEFAULTS.questStateCacheTTLSeconds)
        end

        local events = C_AreaPoiInfo.GetEventsForMap(mapID) or EMPTY_TABLE
        for _, poiID in ipairs(events) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
            if info and info.name == title then
                return SetCachedBoolean(questStateCache, questID, true, TRACKER_DEFAULTS.questStateCacheTTLSeconds)
            end
        end
    end

    return SetCachedBoolean(questStateCache, questID, false, TRACKER_DEFAULTS.questStateCacheTTLSeconds)
end

local function FindActiveQuest(candidates, activeByQuestID)
    for _, questID in ipairs(candidates) do
        if IsQuestActiveOnMap(questID, activeByQuestID) then
            return questID
        end
    end
end

local function IsLegionArchaeologyGoldRotationActive()
    if not (time and date) then
        return false
    end

    local anchorTimestamp = GetDateAtNoonTimestamp(LEGION_ARCHAEOLOGY_GOLD_EU_START_DATE)
    local now = GetNow()
    local todayParts = date("*t", now)
    local todayTimestamp = todayParts and GetDateAtNoonTimestamp(todayParts)
    if not anchorTimestamp or not todayTimestamp then
        return false
    end

    local diffDays = math.floor((todayTimestamp - anchorTimestamp) / 86400)
    local cycleDay = diffDays % LEGION_ARCHAEOLOGY_GOLD_ROTATION_DAYS
    if cycleDay < 0 then
        cycleDay = cycleDay + LEGION_ARCHAEOLOGY_GOLD_ROTATION_DAYS
    end

    return cycleDay < LEGION_ARCHAEOLOGY_GOLD_WINDOW_DAYS
end

local function IsLegionArchaeologyGoldQuestAvailable(activeByQuestID)
    return FindActiveQuest(LEGION_ARCHAEOLOGY_GOLD_QUEST_IDS, activeByQuestID) ~= nil
        or IsLegionArchaeologyGoldRotationActive()
end

local function RequestQuestRewardData(questID)
    if questID and C_TaskQuest and C_TaskQuest.RequestPreloadRewardData then
        C_TaskQuest.RequestPreloadRewardData(questID)
    end
end

local function GetQuestRewardMoney(questID)
    if GetQuestLogRewardMoney then
        return GetQuestLogRewardMoney(questID) or 0
    end

    return 0
end

local function GetQuestRewardCount(getter, questID)
    if getter then
        return getter(questID) or 0
    end

    return 0
end

local function HasFlatGoldQuestReward(questID)
    local cached = GetCachedBoolean(questRewardCache, questID)
    if cached ~= nil then
        return cached
    end

    local money = GetQuestRewardMoney(questID)
    if money <= 0 then
        RequestQuestRewardData(questID)
        return SetCachedBoolean(questRewardCache, questID, false, TRACKER_DEFAULTS.questRewardMissCacheTTLSeconds)
    end

    return SetCachedBoolean(
        questRewardCache,
        questID,
        GetQuestRewardCount(GetNumQuestLogRewards, questID) <= 0
        and GetQuestRewardCount(GetNumQuestLogChoiceRewards, questID) <= 0
        and GetQuestRewardCount(GetNumQuestLogRewardCurrencies, questID) <= 0,
        TRACKER_DEFAULTS.questRewardCacheTTLSeconds
    )
end

local function GetRemainingSpellCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            if duration.HasSecretValues and duration:HasSecretValues() then
                return 1
            end

            local remaining = duration.GetRemainingDuration and duration:GetRemainingDuration()
            if remaining and (not issecretvalue or not issecretvalue(remaining)) and remaining > 1.5 then
                return remaining
            end

            return 0
        end
    end

    if GetSpellCooldown then
        local startTime, duration = GetSpellCooldown(spellID)
        if startTime and duration
            and (not issecretvalue or not issecretvalue(startTime))
            and (not issecretvalue or not issecretvalue(duration))
            and duration > 0 then
            local remaining = (startTime + duration) - GetTime()
            if remaining > 1.5 then
                return remaining
            end
        end
    end

    return 0
end

local function GetQuestLogSnapshot()
    local quests = {}

    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        for index = 1, numEntries do
            local info = C_QuestLog.GetInfo(index)
            if info and not info.isHeader and info.questID and info.questID > 0 then
                quests[#quests + 1] = {
                    questID = info.questID,
                    title = info.title,
                    isComplete = info.isComplete and true or false,
                    frequency = info.frequency,
                }
            end
        end

        return quests
    end

    if GetNumQuestLogEntries and GetQuestLogTitle then
        local numEntries = GetNumQuestLogEntries()
        for index = 1, numEntries do
            local title, _, _, isHeader, _, isComplete, frequency, questID = GetQuestLogTitle(index)
            if not isHeader and questID and questID > 0 then
                quests[#quests + 1] = {
                    questID = questID,
                    title = title,
                    isComplete = isComplete and true or false,
                    frequency = frequency,
                }
            end
        end
    end

    return quests
end

local function NormalizeText(text)
    if not text or text == "" then
        return
    end

    return text:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

GetDateAtNoonTimestamp = function(parts)
    if not (time and parts) then
        return
    end

    return time({
        year = parts.year,
        month = parts.month,
        day = parts.day,
        hour = 12,
        min = 0,
        sec = 0,
    })
end

local function BuildQuestLogLookups(questLog)
    local byQuestID = {}
    local byTitle = {}

    for _, entry in ipairs(questLog or EMPTY_TABLE) do
        if entry.questID then
            byQuestID[entry.questID] = entry
        end

        local normalizedTitle = NormalizeText(entry.title)
        if normalizedTitle then
            byTitle[normalizedTitle] = entry
        end
    end

    return byQuestID, byTitle
end

local function GetServerNow()
    if GetServerTime and (not issecretvalue or not issecretvalue(GetServerTime())) then
        local serverNow = GetServerTime()
        if serverNow and serverNow > 0 then
            return serverNow
        end
    end

    return GetNow()
end

local function IsDarkmoonFaireActive()
    if not date then
        return false
    end

    local today = date("*t", GetServerNow())
    if not today then
        return false
    end

    local firstDay = date("*t", GetDateAtNoonTimestamp({
        year = today.year,
        month = today.month,
        day = 1,
    }))
    if not firstDay or not firstDay.wday then
        return false
    end

    local firstSundayDay = 1 + ((8 - firstDay.wday) % 7)
    return today.day >= firstSundayDay and today.day < (firstSundayDay + 7)
end

local function GetProfessionSkillLineInfo(skillLineID)
    local info = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
    if type(info) == "table" then
        return {
            skillLineID = info.professionID or info.skillLineID or skillLineID,
            parentSkillLineID = info.parentProfessionID,
            professionName = info.professionName,
            parentProfessionName = info.parentProfessionName,
            skillLevel = info.skillLevel or 0,
            maxSkillLevel = info.maxSkillLevel or 0,
        }
    end

    local _, skillLevel, maxSkillLevel = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineInfoByID, skillLineID)
    return {
        skillLineID = skillLineID,
        skillLevel = skillLevel or 0,
        maxSkillLevel = maxSkillLevel or 0,
    }
end

local function GetTrackedMidnightProfessions()
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    if playerLevel < runtimeState.minimumMidnightProfessionLevel then
        return EMPTY_TABLE
    end

    if not midnightCaches.trackedProfessionsDirty and midnightCaches.trackedProfessions then
        return midnightCaches.trackedProfessions
    end

    local previous = midnightCaches.trackedProfessions
    local rows = {}
    local rowBySkillLineID = {}
    local seenSkillLineIDs = {}
    local learnedParentSkillLineIDs = {}
    local fallbackCount = 0
    local tradeSkillCount = 0

    local function ResolveConfigSkillLineID(info, fallbackSkillLineID)
        local directSkillLineID = info and info.skillLineID or fallbackSkillLineID
        if MIDNIGHT_PROFESSION_CONFIGS[directSkillLineID] then
            return directSkillLineID
        end

        local parentSkillLineID = info and info.parentSkillLineID or nil
        if parentSkillLineID and runtimeState.baseProfessionToMidnightSkillLineID[parentSkillLineID] then
            return runtimeState.baseProfessionToMidnightSkillLineID[parentSkillLineID]
        end

        local professionName = info and info.professionName or nil
        local parentProfessionName = info and info.parentProfessionName or nil
        if type(professionName) == "string" and professionName:find("^Midnight ") then
            for candidateSkillLineID, config in pairs(MIDNIGHT_PROFESSION_CONFIGS) do
                if professionName == ("Midnight " .. (parentProfessionName or "")) then
                    if config and config.label and parentProfessionName then
                        return candidateSkillLineID
                    end
                end
            end
        end
    end

    local function AddTrackedProfession(skillLineID, skillLevel, maxSkillLevel)
        local existingRow = rowBySkillLineID[skillLineID]
        if existingRow then
            if MIDNIGHT_MOXIE_CURRENCY_IDS[skillLineID] and not existingRow.moxieCurrencyID then
                existingRow.moxieCurrencyID = MIDNIGHT_MOXIE_CURRENCY_IDS[skillLineID]
            end
            return
        end

        if seenSkillLineIDs[skillLineID] then
            return
        end

        local config = MIDNIGHT_PROFESSION_CONFIGS[skillLineID]
        if not config or (skillLevel or 0) <= 0 then
            return
        end

        seenSkillLineIDs[skillLineID] = true
        local row = {
            config = config,
            skillLineID = skillLineID,
            skillLevel = skillLevel or 0,
            maxSkillLevel = maxSkillLevel or 0,
            moxieCurrencyID = MIDNIGHT_MOXIE_CURRENCY_IDS[skillLineID],
        }
        rows[#rows + 1] = row
        rowBySkillLineID[skillLineID] = row
    end

    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetAllProfessionTradeSkillLines) == "function" then
        local skillLineIDs = SafeCall(C_TradeSkillUI.GetAllProfessionTradeSkillLines) or EMPTY_TABLE
        tradeSkillCount = #skillLineIDs
        for _, skillLineID in ipairs(skillLineIDs) do
            local info = GetProfessionSkillLineInfo(skillLineID)
            if info then
                local resolvedSkillLineID = ResolveConfigSkillLineID(info, skillLineID)
                if resolvedSkillLineID then
                    AddTrackedProfession(
                        resolvedSkillLineID,
                        info.skillLevel,
                        info.maxSkillLevel
                    )
                end
            end
        end
    end

    if GetProfessions and GetProfessionInfo then
        local professionIndices = { GetProfessions() }
        for _, professionIndex in ipairs(professionIndices) do
            if professionIndex then
                local _, _, skillLevel, maxSkillLevel, _, _, skillLineID = GetProfessionInfo(professionIndex)
                if skillLineID then
                    fallbackCount = fallbackCount + 1
                    learnedParentSkillLineIDs[skillLineID] = true
                    AddTrackedProfession(skillLineID, skillLevel, maxSkillLevel)
                end
            end
        end
    end

    for skillLineID in pairs(MIDNIGHT_PROFESSION_CONFIGS) do
        local info = GetProfessionSkillLineInfo(skillLineID)
        if info and (info.skillLevel or 0) > 0 then
            local resolvedSkillLineID = ResolveConfigSkillLineID(info, skillLineID) or skillLineID
            AddTrackedProfession(
                resolvedSkillLineID,
                info.skillLevel,
                info.maxSkillLevel
            )
        elseif info and info.parentSkillLineID and learnedParentSkillLineIDs[info.parentSkillLineID] and (info.maxSkillLevel or 0) > 0 then
            AddTrackedProfession(
                skillLineID,
                info.skillLevel,
                info.maxSkillLevel
            )
        end
    end

    table.sort(rows, function(a, b)
        return (a.config.order or 999) < (b.config.order or 999)
    end)

    if previous and trackerUI.UsePreviousBagCacheOnTransientEmpty(
        "trackedProfessions",
        #previous,
        #rows
    ) then
        midnightCaches.trackedProfessions = previous
        midnightCaches.trackedProfessionsDirty = false
        return previous
    end

    if previous then
        local previousSkillLineIDs = {}
        local trackedProfessionSetChanged = #previous ~= #rows
        for _, row in ipairs(previous) do
            previousSkillLineIDs[row.skillLineID] = true
        end
        if not trackedProfessionSetChanged then
            for _, row in ipairs(rows) do
                if not previousSkillLineIDs[row.skillLineID] then
                    trackedProfessionSetChanged = true
                    break
                end
            end
        end
        if trackedProfessionSetChanged then
            midnightCaches.knowledgeDirty = true
            midnightCaches.recipeItemsDirty = true
        end
    end

    local debugParts = {}
    for _, row in ipairs(rows) do
        debugParts[#debugParts + 1] = ("%s(%d/%d id=%d)"):format(
            row.config.label or tostring(row.skillLineID),
            row.skillLevel or 0,
            row.maxSkillLevel or 0,
            row.skillLineID or 0
        )
    end
    local debugSummary = #debugParts > 0 and table.concat(debugParts, ", ") or "none"
    local debugSignature = ("%s|api=%d|fallback=%d"):format(debugSummary, tradeSkillCount, fallbackCount)
    if debugSignature ~= debugSignatures.trackedProfessions then
        debugSignatures.trackedProfessions = debugSignature
        DebugLog("Midnight professions = %s | api=%d fallback=%d", debugSummary, tradeSkillCount, fallbackCount)
    end

    midnightCaches.trackedProfessions = rows
    midnightCaches.trackedProfessionsDirty = false
    return rows
end

local function HasLearnedMidnightBaseProfession()
    if not GetProfessions or not GetProfessionInfo then
        return false
    end

    local professionIndices = { GetProfessions() }
    for _, professionIndex in ipairs(professionIndices) do
        if professionIndex then
            local _, _, skillLevel, _, _, _, skillLineID = GetProfessionInfo(professionIndex)
            if skillLineID and (skillLevel or 0) > 0 and runtimeState.baseProfessionToMidnightSkillLineID[skillLineID] then
                return true
            end
        end
    end

    return false
end

local function CountRemainingTrackedQuests(questIDs)
    local total = 0
    local completed = 0

    for _, questID in ipairs(questIDs or EMPTY_TABLE) do
        total = total + 1
        if IsQuestDone(questID) then
            completed = completed + 1
        end
    end

    return math.max(total - completed, 0), total
end

trackerUI.GetMidnightEnchantingCatchUpStatus = function(row, remainingWeeklyLoots, remainingDisenchants)
    if not row or row.skillLineID ~= 2909 then
        return nil
    end

    local config = row.config or EMPTY_TABLE
    local hasTrainerWeeklyCompleted = IsAnyQuestDone(config.trainerWeeklyQuestIDs or EMPTY_TABLE)
    if (remainingWeeklyLoots or 0) > 0
        or (remainingDisenchants or 0) > 0
        or not hasTrainerWeeklyCompleted then
        return { active = false }
    end

    local info = SafeCall(
        C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,
        runtimeState.midnightEnchantingCatchUpCurrencyID
    )
    if type(info) ~= "table" then
        return nil
    end

    local maximum = tonumber(info.maxQuantity) or 0
    local earned = tonumber(info.quantity)
    if earned == nil then
        earned = tonumber(info.totalEarned)
    end
    if maximum <= 0 or earned == nil then
        return nil
    end

    local remaining = math.max(maximum - earned, 0)
    if remaining <= 0 then
        return nil
    end

    return {
        active = true,
        remaining = remaining,
        total = maximum,
    }
end

local function GetContainerItemCountCompat(bagID, slotIndex)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bagID, slotIndex)
        if info and info.stackCount then
            return info.stackCount
        end
    end

    if GetContainerItemInfo then
        local _, itemCount = GetContainerItemInfo(bagID, slotIndex)
        if itemCount then
            return itemCount
        end
    end

    return 1
end

-- ---------------------------------------------------------------- Warbank
--
-- Inventaire de la banque de compte : seule source du verdict « present en
-- Warbank » pour tout ce que le tracker sait reclamer. Deux oracles, qui ne
-- repondent pas a la meme question.
--
-- Le CLIENT sait compter. `C_Item.GetItemCount` inclut la banque de compte par
-- son cinquieme argument, banque fermee comprise, donc il donne le *combien*
-- sans rien persister ni dependre d'un addon tiers. Mais il ne rend qu'un total
-- par itemID : la statistique et le rang d'un outil ne s'y lisent pas.
--
-- L'INSTANTANE persistant donne ce *quoi*. Il est ecrit a chaque scan banque
-- ouverte et survit au `/reload`, donc il repond encore a l'hotel des ventes,
-- loin de la banque -- c'est tout l'interet.
--
-- L'egalite des deux tranche la fraicheur : un instantane qui ne compte pas
-- autant d'exemplaires que le client est perime, et ne vaut alors rien. Ce test
-- vaut mieux qu'un horodatage, car il detecte immediatement qu'un autre
-- personnage a vide la banque.
trackerUI.warbank = {}

-- Les itemIDs suivis viennent des tables que l'addon tient deja : enchantements
-- d'outil, candidats rares d'equipement de metier, traites. Aucune liste
-- nouvelle a maintenir, donc aucune a oublier de mettre a jour.
trackerUI.warbank.GetTrackedItemIDs = function()
    if runtimeState.warbankTrackedItemIDs then
        return runtimeState.warbankTrackedItemIDs
    end

    local tracked = {}
    for _, statInfo in pairs(runtimeState.professionToolEnchantments.byStat) do
        if statInfo.itemID then
            tracked[statInfo.itemID] = true
        end
    end
    for _, candidates in pairs(runtimeState.professionGear.rareCandidatesBySkillLineID) do
        if candidates.tool then
            tracked[candidates.tool] = true
        end
        for _, itemID in ipairs(candidates.gear or EMPTY_TABLE) do
            tracked[itemID] = true
        end
    end
    for _, treatise in pairs(MIDNIGHT_TREATISES_BY_SKILL_LINE_ID) do
        if treatise.itemID then
            tracked[treatise.itemID] = true
        end
    end

    runtimeState.warbankTrackedItemIDs = tracked
    return tracked
end

trackerUI.warbank.GetSnapshot = function()
    local accountDB = GetAccountDB()
    local snapshot = accountDB.warbankSnapshot
    if type(snapshot) ~= "table" or snapshot.version ~= 1 then
        snapshot = { version = 1, scannedAt = 0, tabs = {}, itemsByID = {} }
        accountDB.warbankSnapshot = snapshot
    end
    if type(snapshot.tabs) ~= "table" then
        snapshot.tabs = {}
    end
    if type(snapshot.itemsByID) ~= "table" then
        snapshot.itemsByID = {}
    end
    return snapshot
end

-- Difference brute entre « sacs + banque de compte » et « sacs seuls ». Rend
-- nil si le client ne sait pas repondre : inconnu n'est pas zero.
trackerUI.warbank.GetClientCount = function(itemID)
    if not C_Item or type(C_Item.GetItemCount) ~= "function" then
        return nil
    end
    local withAccount = tonumber(SafeCall(C_Item.GetItemCount, itemID, false, false, false, true))
    local withoutAccount = tonumber(SafeCall(C_Item.GetItemCount, itemID, false, false, false, false))
    if not withAccount or not withoutAccount then
        return nil
    end
    return math.max(withAccount - withoutAccount, 0)
end

-- Le compte vivant, banque fermee comprise. L'oracle du client est prefere,
-- mais il n'est retenu que s'il a fait ses preuves une fois banque ouverte :
-- un client qui ignorerait le cinquieme argument rendrait un zero indiscernable
-- d'une banque reellement vide, et ferait racheter tout ce qui y dort.
trackerUI.warbank.GetLiveCount = function(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    if GetAccountDB().warbankClientCountUsable ~= false then
        local clientCount = trackerUI.warbank.GetClientCount(itemID)
        if clientCount then
            return clientCount
        end
    end
    return trackerUI.GetToolEnchantWarbankQuantity(itemID)
end

-- Ce qui vient d'etre sorti mais que le client n'a pas encore repercute.
--
-- Un transfert n'est pas instantane, et surtout les onglets de la banque de
-- compte se rafraichissent sur `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED`, qui
-- arrive APRES le `BAG_UPDATE_DELAYED` qui deverrouille le bouton. Entre les
-- deux, un scan revoit l'objet encore en banque et le repropose : le bouton
-- se rearme et sort un deuxieme, puis un troisieme exemplaire.
--
-- On ne peut donc pas s'en remettre au moment ou les conteneurs se mettent a
-- jour. Ce que l'on sait de source sure, c'est ce que l'on vient de retirer :
-- tant que le compte vivant n'a pas baisse d'autant, l'objet reste en transit
-- et le plan n'a le droit de rien decider a son sujet.
runtimeState.warbankPullsInFlight = {}
runtimeState.warbankPullGraceSeconds = 10

trackerUI.warbank.NotePull = function(itemID, quantity, liveBefore)
    itemID = tonumber(itemID)
    if not itemID or not liveBefore then
        return
    end
    local pending = runtimeState.warbankPullsInFlight[itemID]
    local now = type(GetTime) == "function" and GetTime() or 0
    runtimeState.warbankPullsInFlight[itemID] = {
        quantity = (pending and pending.quantity or 0) + math.max(quantity or 1, 1),
        -- Le point de reference reste celui du PREMIER retrait encore en
        -- transit : deux retraits consecutifs se cumulent, et le client doit
        -- avoir baisse de leur somme pour qu'on les considere digeres.
        liveBefore = pending and pending.liveBefore or liveBefore,
        expiresAt = now + runtimeState.warbankPullGraceSeconds,
    }
end

-- Rend ce qui reste en transit, et oublie l'entree des que le client a
-- rattrape -- ou apres une grace, si le transfert n'a finalement pas eu lieu.
trackerUI.warbank.ConsumeInFlight = function(itemID, live)
    local pending = runtimeState.warbankPullsInFlight[itemID]
    if not pending then
        return 0
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    if now >= (pending.expiresAt or 0) then
        runtimeState.warbankPullsInFlight[itemID] = nil
        return 0
    end
    if live and live <= (pending.liveBefore or 0) - pending.quantity then
        runtimeState.warbankPullsInFlight[itemID] = nil
        return 0
    end
    return pending.quantity
end

-- Verdict d'un exemplaire de la Warbank face a une variante. Rend true, false
-- ou nil, exactement comme `state.DoesLinkMatchVariant` de YayaQueue : nil veut
-- dire « pas encore jugeable », jamais « non conforme ».
trackerUI.warbank.MatchVariant = function(instance, variant)
    if type(instance) ~= "table" or type(variant) ~= "table" then
        return nil
    end
    if instance.unresolved == true or type(instance.link) ~= "string" then
        return nil
    end

    if variant.statKey then
        if instance.statKey == nil then
            -- Tooltip lu sans y trouver de statistique : l'exemplaire n'en
            -- porte pas, il ne peut donc pas satisfaire la variante. Tooltip
            -- pas encore lu : on ne tranche pas.
            if instance.statResolved ~= true then
                return nil
            end
            return false
        end
        if instance.statKey ~= variant.statKey then
            return false
        end
    end

    if variant.minItemLevel then
        local itemLevel = tonumber(instance.itemLevel)
        if not itemLevel then
            return nil
        end
        if itemLevel < variant.minItemLevel then
            return false
        end
    end

    return true
end

-- Ce que la Warbank offre pour un besoin donne.
--
--   1. compte indisponible          -> known = false
--   2. compte nul                   -> known = true, absent CERTAIN, sans
--                                      instantane et meme sur une installation
--                                      neuve
--   3. besoin sans variante         -> la quantite suffit a decider
--   4. rien dans l'instantane       -> il y a quelque chose, on ignore quoi
--   5. instantane et compte discordent -> instantane perime
--   6. sinon, verdict par exemplaire
--
-- L'indecis ne vaut ni « absent » ni « present » : il ne propose aucune
-- recuperation et il interdit l'achat.
trackerUI.warbank.Resolve = function(itemID, variant)
    local result = { count = 0, matched = 0, undecided = 0, known = false, slots = {} }
    itemID = tonumber(itemID)
    if not itemID then
        return result
    end

    local live = trackerUI.warbank.GetLiveCount(itemID)
    if live == nil then
        return result
    end
    result.count = live

    -- Un retrait deja parti interdit toute decision sur cet objet : ni un
    -- deuxieme retrait, ni un achat pour le remplacer. `known` reste faux, ce
    -- qui range l'entree dans les bloques du plan, avec sa raison.
    local inFlight = trackerUI.warbank.ConsumeInFlight(itemID, live)
    if inFlight > 0 then
        result.inFlight = inFlight
        return result
    end

    if live <= 0 then
        result.known = true
        return result
    end

    local entry = trackerUI.warbank.GetSnapshot().itemsByID[itemID]
    local instances = entry and entry.instances or nil
    local snapshotTotal = 0
    for _, instance in ipairs(instances or EMPTY_TABLE) do
        snapshotTotal = snapshotTotal + math.max(tonumber(instance.stackCount) or 1, 1)
    end

    if type(variant) ~= "table" then
        -- Une marchandise n'a pas d'identite a verifier : son compte tranche.
        -- Les emplacements connus servent au transfert, et celui-ci revalide
        -- toujours sa source, donc un instantane en retard ne fait pas de mal.
        result.known = true
        result.matched = live
        result.slots = instances or {}
        return result
    end

    if not instances or #instances == 0 then
        return result
    end
    if snapshotTotal ~= live then
        return result
    end

    for _, instance in ipairs(instances) do
        local verdict = trackerUI.warbank.MatchVariant(instance, variant)
        if verdict == true then
            result.matched = result.matched + 1
            result.slots[#result.slots + 1] = instance
        elseif verdict == nil then
            result.undecided = result.undecided + 1
        end
    end
    result.known = true
    return result
end

-- Lecture d'un emplacement de la Warbank. Un equipement de metier porte son
-- identite complete, lue exactement comme un outil possede : la statistique au
-- tooltip du lien unique (jamais `C_Item.GetItemStats`, qui decrit l'item de
-- base) et le rang par le PREMIER des trois retours de
-- `GetDetailedItemLevelInfo`. Une marchandise n'a besoin que de sa pile.
trackerUI.warbank.ReadSlot = function(bagID, slotIndex, itemID)
    local instance = {
        bagID = bagID,
        slotIndex = slotIndex,
        stackCount = math.max(GetContainerItemCountCompat(bagID, slotIndex), 1),
    }

    local equipLoc
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        equipLoc = select(4, SafeCall(C_Item.GetItemInfoInstant, itemID))
    end
    local isGear = equipLoc == "INVTYPE_PROFESSION_TOOL" or equipLoc == "INVTYPE_PROFESSION_GEAR"

    local link = GetContainerItemLinkCompat(bagID, slotIndex)
    if type(link) == "string" and link:find("item:", 1, true) then
        instance.link = link
    end
    if not isGear then
        return instance
    end

    if not instance.link then
        instance.unresolved = true
        trackerUI.RequestToolItemData(itemID)
        return instance
    end

    local statKey, statsPending = trackerUI.GetToolEnchantStat(instance.link)
    if statKey then
        instance.statKey = statKey
        instance.statResolved = true
    elseif statsPending then
        instance.unresolved = true
    else
        instance.statResolved = true
    end

    local detailedItemLevel
    if type(GetDetailedItemLevelInfo) == "function" then
        detailedItemLevel = SafeCall(GetDetailedItemLevelInfo, instance.link)
    end
    instance.itemLevel = tonumber(detailedItemLevel)
    if not instance.itemLevel then
        instance.unresolved = true
    end

    return instance
end

-- Ecriture de l'instantane, banque ouverte seulement, et FUSIONNELLE par
-- onglet : un onglet dont le client ne rend aucun emplacement n'est pas lu, et
-- son contenu precedent est conserve. Sans cela, un scan pendant le chargement
-- de la banque effacerait un onglet reellement plein.
trackerUI.warbank.Scan = function()
    if not trackerUI.IsAccountBankOpen() then
        return false
    end

    local tracked = trackerUI.warbank.GetTrackedItemIDs()
    local snapshot = trackerUI.warbank.GetSnapshot()
    local scannedTabs = {}
    local scanned = {}
    local scannedSum = 0

    for _, bagID in ipairs(trackerUI.GetAccountBankBagIDs()) do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        if slotCount > 0 then
            scannedTabs[bagID] = slotCount
            for slotIndex = 1, slotCount do
                local itemID = GetContainerItemIDCompat(bagID, slotIndex)
                if itemID and tracked[itemID] then
                    local instance = trackerUI.warbank.ReadSlot(bagID, slotIndex, itemID)
                    scanned[itemID] = scanned[itemID] or {}
                    scanned[itemID][#scanned[itemID] + 1] = instance
                    scannedSum = scannedSum + instance.stackCount
                end
            end
        end
    end

    if next(scannedTabs) == nil then
        return false
    end

    local merged = {}
    for itemID, entry in pairs(snapshot.itemsByID) do
        for _, instance in ipairs(entry.instances or EMPTY_TABLE) do
            if not scannedTabs[instance.bagID] then
                merged[itemID] = merged[itemID] or {}
                merged[itemID][#merged[itemID] + 1] = instance
            end
        end
    end
    for itemID, instances in pairs(scanned) do
        merged[itemID] = merged[itemID] or {}
        for _, instance in ipairs(instances) do
            merged[itemID][#merged[itemID] + 1] = instance
        end
    end

    local itemsByID = {}
    for itemID, instances in pairs(merged) do
        local total = 0
        for _, instance in ipairs(instances) do
            total = total + math.max(tonumber(instance.stackCount) or 1, 1)
        end
        if total > 0 then
            itemsByID[itemID] = { total = total, instances = instances }
        end
    end
    snapshot.itemsByID = itemsByID
    for bagID, slotCount in pairs(scannedTabs) do
        snapshot.tabs[bagID] = { slots = slotCount }
    end
    snapshot.scannedAt = type(GetServerTime) == "function" and (SafeCall(GetServerTime) or 0) or 0

    trackerUI.warbank.CalibrateClientOracle(scanned, scannedSum)
    trackerUI.warbank.LogSnapshot(snapshot)
    return true
end

-- La banque ouverte est le seul moment ou l'on connait la verite : c'est donc
-- la qu'on verifie l'oracle du client. S'il rend zero alors que le scan voit
-- des objets, c'est que le cinquieme argument de `GetItemCount` ne repond pas
-- sur ce client, et le repli TSM prend la main -- definitivement, jusqu'a ce
-- qu'un scan le contredise.
trackerUI.warbank.CalibrateClientOracle = function(scanned, scannedSum)
    if (scannedSum or 0) <= 0 then
        return
    end

    local clientSum = 0
    local answered = false
    for itemID in pairs(scanned) do
        local clientCount = trackerUI.warbank.GetClientCount(itemID)
        if clientCount then
            answered = true
            clientSum = clientSum + clientCount
        end
    end
    if not answered then
        return
    end

    local accountDB = GetAccountDB()
    local usable = clientSum > 0
    if accountDB.warbankClientCountUsable ~= usable then
        accountDB.warbankClientCountUsable = usable
        DebugLog("Warbank client oracle = %s (scan=%d client=%d)",
            tostring(usable), scannedSum, clientSum)
    end
end

trackerUI.warbank.LogSnapshot = function(snapshot)
    local parts = {}
    local unresolved = 0
    local tabCount = 0
    for itemID, entry in pairs(snapshot.itemsByID) do
        parts[#parts + 1] = ("%dx%d"):format(itemID, entry.total or 0)
        for _, instance in ipairs(entry.instances or EMPTY_TABLE) do
            if instance.unresolved == true then
                unresolved = unresolved + 1
            end
        end
    end
    for _ in pairs(snapshot.tabs) do
        tabCount = tabCount + 1
    end
    table.sort(parts)

    local signature = ("oracle=%s tabs=%d unresolved=%d :: %s"):format(
        GetAccountDB().warbankClientCountUsable == false and "tsm" or "client",
        tabCount,
        unresolved,
        #parts > 0 and table.concat(parts, ",") or "none")
    if signature ~= debugSignatures.warbankInventory then
        debugSignatures.warbankInventory = signature
        DebugLog("Warbank inventory = %s", signature)
    end
end

-- Point d'entree du cycle de rafraichissement : ne rescanne que si un
-- evenement a peri l'instantane et que la banque est ouverte.
trackerUI.warbank.Refresh = function()
    if not midnightCaches.warbankInventoryDirty then
        return false
    end
    if not trackerUI.IsAccountBankOpen() then
        return false
    end
    midnightCaches.warbankInventoryDirty = false
    return trackerUI.warbank.Scan()
end

-- API publique de l'inventaire Warbank. YayaQueue s'en sert pour ne pas
-- racheter un exemplaire conforme qui dort en banque : lui ne compte que les
-- sacs et les emplacements equipes, et n'a aucun moyen de lire la banque de
-- compte fermee.
_G.YayaWeeklyTrackerAPI = _G.YayaWeeklyTrackerAPI or {}
_G.YayaWeeklyTrackerAPI.ResolveWarbankItem = function(itemID, variant)
    return trackerUI.warbank.Resolve(itemID, variant)
end

local function FindMidnightKnowledgeConsumableInBags(trackedRows)
    if not midnightCaches.knowledgeDirty and midnightCaches.knowledge then
        return midnightCaches.knowledge
    end

    local previous = midnightCaches.knowledge
    trackedRows = trackedRows or GetTrackedMidnightProfessions()

    local trackedSkillLineIDs = {}
    for _, row in ipairs(trackedRows) do
        trackedSkillLineIDs[row.skillLineID] = true
    end

    if not next(trackedSkillLineIDs) then
        if previous and trackerUI.UsePreviousBagCacheOnTransientEmpty(
            "knowledge",
            previous.totalCount or 0,
            0,
            previous
        ) then
            midnightCaches.knowledge = previous
            midnightCaches.knowledgeDirty = false
            return previous
        end

        midnightCaches.knowledge = {
            totalCount = 0,
        }
        midnightCaches.knowledgeDirty = false
        return midnightCaches.knowledge
    end

    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)
    -- Les traites partagent un long cooldown que les autres objets de connaissance
    -- n'ont pas. Prendre le premier objet trouve dans l'ordre des sacs enchainait
    -- donc parfois deux traites, et le second partait dans le vide. On retient un
    -- candidat par categorie pour intercaler les autres objets KP entre les deux
    -- traites : le cooldown s'ecoule pendant ce temps.
    local firstReadyTreatise
    local firstTreatise
    local firstOtherItem
    local totalCount = 0
    local countsByItemID = {}

    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            local skillLineID = itemID and MIDNIGHT_KNOWLEDGE_ITEM_SKILL_LINE_IDS[itemID] or nil
            if skillLineID and trackedSkillLineIDs[skillLineID] then
                local treatiseInfo = MIDNIGHT_TREATISES_BY_SKILL_LINE_ID[skillLineID]
                local isTreatise = treatiseInfo ~= nil and treatiseInfo.itemID == itemID
                local isCompletedTreatise = isTreatise and IsQuestDone(treatiseInfo.weeklyQuestID)
                if not isCompletedTreatise then
                    local stackCount = math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
                    countsByItemID[itemID] = (countsByItemID[itemID] or 0) + stackCount
                    local itemLink = GetContainerItemLinkCompat(bagID, slotIndex)
                    local itemName = GetItemInfo and GetItemInfo(itemID) or nil
                    if IsItemCurrentlyUsable(itemLink, itemName, itemID) then
                        totalCount = totalCount + stackCount
                        local candidate = {
                            bagID = bagID,
                            itemID = itemID,
                            itemLink = itemLink,
                            itemName = itemName,
                            slotIndex = slotIndex,
                        }
                        if not isTreatise then
                            firstOtherItem = firstOtherItem or candidate
                        else
                            firstTreatise = firstTreatise or candidate
                            if trackerUI.GetItemActionCooldownRemaining(itemID) <= 0 then
                                firstReadyTreatise = firstReadyTreatise or candidate
                            end
                        end
                    end
                end
            end
        end
    end

    -- Ordre voulu : un traite des qu'il est pret, sinon les autres objets KP tant
    -- qu'il en reste, sinon le traite encore en cooldown (le gate du bouton se
    -- charge alors d'afficher l'attente). Avec deux traites cela donne
    -- traite -> autres KP -> traite ; avec un seul, il part en premier comme avant.
    local firstMatch = firstReadyTreatise or firstOtherItem or firstTreatise

    local result = {
        totalCount = totalCount,
        countsByItemID = countsByItemID,
        bagID = firstMatch and firstMatch.bagID or nil,
        itemID = firstMatch and firstMatch.itemID or nil,
        itemLink = firstMatch and firstMatch.itemLink or nil,
        itemName = firstMatch and firstMatch.itemName or nil,
        slotIndex = firstMatch and firstMatch.slotIndex or nil,
    }
    if previous and trackerUI.UsePreviousBagCacheOnTransientEmpty(
        "knowledge",
        previous.totalCount or 0,
        result.totalCount or 0,
        previous
    ) then
        midnightCaches.knowledge = previous
        midnightCaches.knowledgeDirty = false
        return previous
    end

    local debugSignature = ("%d:%s"):format(result.totalCount or 0, tostring(result.itemID or "none"))
    if debugSignature ~= debugSignatures.knowledge then
        debugSignatures.knowledge = debugSignature
        DebugLog("KP items = count:%d first:%s", result.totalCount or 0, tostring(result.itemID or "none"))
    end

    midnightCaches.knowledge = result
    midnightCaches.knowledgeDirty = false
    return result
end

local function FindArtisanConsortiumPayoutInBags()
    if not midnightCaches.payoutDirty and midnightCaches.payout then
        return midnightCaches.payout
    end

    local previous = midnightCaches.payout
    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)
    local matches = {}
    local totalCount = 0

    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            local isPayout = itemID and ARTISAN_CONSORTIUM_PAYOUT_ITEM_IDS[itemID]
            local isWhitelistedContainer = itemID and runtimeState.containerWhitelist[itemID]
            if isPayout or isWhitelistedContainer then
                totalCount = totalCount + math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
                matches[#matches + 1] = {
                    bagID = bagID,
                    itemID = itemID,
                    itemLink = GetContainerItemLinkCompat(bagID, slotIndex),
                    itemName = GetItemInfo and GetItemInfo(itemID) or nil,
                    slotIndex = slotIndex,
                    targetKey = tostring(bagID) .. ":" .. tostring(slotIndex),
                    isPayout = isPayout == true,
                }
            end
        end
    end

    runtimeState.attemptedPayoutTargetKeys = runtimeState.attemptedPayoutTargetKeys or {}
    local startIndex = 1
    for index, match in ipairs(matches) do
        if match.targetKey == runtimeState.lastPayoutTargetKey then
            startIndex = (index % #matches) + 1
            break
        end
    end

    local selectedMatch
    for offset = 0, #matches - 1 do
        local match = matches[((startIndex + offset - 1) % #matches) + 1]
        if not runtimeState.attemptedPayoutTargetKeys[match.targetKey] then
            selectedMatch = match
            break
        end
    end

    local result = {
        totalCount = totalCount,
        bagID = selectedMatch and selectedMatch.bagID or nil,
        itemID = selectedMatch and selectedMatch.itemID or nil,
        itemLink = selectedMatch and selectedMatch.itemLink or nil,
        itemName = selectedMatch and selectedMatch.itemName or nil,
        slotIndex = selectedMatch and selectedMatch.slotIndex or nil,
        targetKey = selectedMatch and selectedMatch.targetKey or nil,
        isPayout = selectedMatch and selectedMatch.isPayout or false,
    }
    if previous and trackerUI.UsePreviousBagCacheOnTransientEmpty(
        "payout",
        previous.totalCount or 0,
        result.totalCount or 0,
        previous
    ) then
        midnightCaches.payout = previous
        midnightCaches.payoutDirty = false
        return previous
    end

    local debugSignature = ("%d:%s:%s"):format(
        result.totalCount or 0,
        tostring(result.itemID or "none"),
        tostring(result.targetKey or "none")
    )
    if debugSignature ~= debugSignatures.payout then
        debugSignatures.payout = debugSignature
        DebugLog(
            "Payout items = count:%d selected:%s target:%s",
            result.totalCount or 0,
            tostring(result.itemID or "none"),
            tostring(result.targetKey or "none")
        )
    end

    midnightCaches.payout = result
    midnightCaches.payoutDirty = false
    return result
end

-- Tout ce qui decrit le contenu de la banque de compte se perime d'un seul
-- geste : un site oublie ferait vivre le plan un rafraichissement de retard
-- sur l'instantane, et proposerait de recuperer un emplacement deja vide.
trackerUI.InvalidateWarbankCaches = function()
    midnightCaches.warbankInventoryDirty = true
end

trackerUI.InstallWarbankRefreshHooks = function()
    if type(hooksecurefunc) ~= "function" then
        return
    end

    runtimeState.warbankRefreshHooks = runtimeState.warbankRefreshHooks or {}
    local hooks = runtimeState.warbankRefreshHooks
    local function RefreshWarbankButtons(source)
        DebugLog("Warbank selection changed via %s", tostring(source))
        trackerUI.InvalidateWarbankCaches()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0.05, false)
    end

    if not hooks.bankType then
        if type(Addon_SetBankType) == "function" then
            hooksecurefunc("Addon_SetBankType", function()
                RefreshWarbankButtons("Addon_SetBankType")
            end)
            hooks.bankType = true
        else
            -- `BankPanel` peut ne pas etre une frame selon l'UI installee :
            -- l'indexer sans verifier son type leve une erreur au lieu de
            -- simplement renoncer au hook.
            local bankPanel = (_G.BankFrame and _G.BankFrame.BankPanel) or _G.BankPanel
            if type(bankPanel) == "table" and type(bankPanel.SetBankType) == "function" then
                hooksecurefunc(bankPanel, "SetBankType", function()
                    RefreshWarbankButtons("BankPanel.SetBankType")
                end)
                hooks.bankType = true
            end
        end
    end

    if not hooks.elvUI then
        local elvUI = _G.ElvUI
        local engine = type(elvUI) == "table" and elvUI[1] or nil
        local bags = engine and type(engine.GetModule) == "function"
            and SafeCall(engine.GetModule, engine, "Bags") or nil
        if bags and type(bags.SelectBankTab) == "function" then
            hooksecurefunc(bags, "SelectBankTab", function()
                RefreshWarbankButtons("ElvUI.SelectBankTab")
            end)
            hooks.elvUI = true
        elseif bags and type(bags.ShowBankTab) == "function" then
            hooksecurefunc(bags, "ShowBankTab", function()
                RefreshWarbankButtons("ElvUI.ShowBankTab")
            end)
            hooks.elvUI = true
        end
    end
end

trackerUI.IsAccountBankOpen = function()
    local accountBankType = Enum and Enum.BankType and Enum.BankType.Account
    if accountBankType == nil then
        return false
    end

    local bankFrame = _G.BankFrame or BankFrame
    local isBankShown = bankFrame
        and type(bankFrame.IsShown) == "function"
        and bankFrame:IsShown()
    local bags
    local elvUI = _G.ElvUI
    if type(elvUI) == "table" then
        local engine = elvUI[1]
        bags = engine and type(engine.GetModule) == "function"
            and SafeCall(engine.GetModule, engine, "Bags")
        local elvBankFrame = bags and bags.BankFrame or nil
        local elvBankShown = elvBankFrame
            and type(elvBankFrame.IsShown) == "function"
            and elvBankFrame:IsShown()
        if not isBankShown and elvBankShown then
            bankFrame = elvBankFrame
            isBankShown = true
        end
    end
    if not isBankShown then
        return false
    end

    local activeBankType
    if type(bankFrame.GetActiveBankType) == "function" then
        activeBankType = SafeCall(bankFrame.GetActiveBankType, bankFrame)
    end
    local bankPanel = _G.BankPanel or bankFrame.BankPanel
    if activeBankType == nil
        and type(bankPanel) == "table"
        and type(bankPanel.GetActiveBankType) == "function" then
        activeBankType = SafeCall(bankPanel.GetActiveBankType, bankPanel)
    end
    if activeBankType == nil and type(Addon_GetBankType) == "function" then
        activeBankType = SafeCall(Addon_GetBankType)
    end
    if activeBankType ~= nil then
        return activeBankType == accountBankType
    end

    local accountTabID = bags and bags.WarbandIndexs and bags.WarbandIndexs[1]
    return accountTabID ~= nil and bags.BankTab == accountTabID
end

trackerUI.GetAccountBankBagIDs = function()
    local bagIDs = {}
    local seenBagIDs = {}
    local function AddBagID(bagID)
        bagID = tonumber(bagID)
        if bagID and not seenBagIDs[bagID] then
            seenBagIDs[bagID] = true
            bagIDs[#bagIDs + 1] = bagID
        end
    end

    local accountBankType = Enum and Enum.BankType and Enum.BankType.Account
    if accountBankType ~= nil and C_Bank and type(C_Bank.FetchPurchasedBankTabIDs) == "function" then
        local purchased = SafeCall(C_Bank.FetchPurchasedBankTabIDs, accountBankType)
        if type(purchased) == "table" then
            for key, value in pairs(purchased) do
                local bagID = tonumber(value)
                if not bagID and (value == true or type(value) == "table") then
                    bagID = tonumber(key)
                end
                AddBagID(bagID)
            end
        end
    end

    local bagIndex = Enum and Enum.BagIndex or {}
    local first = tonumber(bagIndex.AccountBankTab_1)
    local last = tonumber(bagIndex.AccountBankTab_5)
    if first and last then
        for bagID = first, last do
            AddBagID(bagID)
        end
    end

    table.sort(bagIDs)
    return bagIDs
end

-- Les traites hebdomadaires encore a obtenir. La Warbank n'est pas consultee
-- ici : le plan d'approvisionnement s'en charge, ce qui permet de savoir qu'un
-- traite y dort meme banque fermee -- ce que l'ancien scan, court-circuite des
-- que la banque etait fermee, ne pouvait pas dire.
trackerUI.GetMissingMidnightTreatises = function(trackedRows)
    if GetAccountDB().trackTreatises == false then
        return EMPTY_TABLE
    end

    trackedRows = trackedRows or GetTrackedMidnightProfessions()
    local missing = {}
    for _, row in ipairs(trackedRows) do
        local config = MIDNIGHT_PROFESSION_CONFIGS[row.skillLineID]
        local treatiseInfo = MIDNIGHT_TREATISES_BY_SKILL_LINE_ID[row.skillLineID]
        if config and treatiseInfo
            and row.skillLevel >= (config.treatiseMinSkill or math.huge)
            and not IsQuestDone(treatiseInfo.weeklyQuestID)
            and trackerUI.GetOwnedItemCount(treatiseInfo.itemID) <= 0 then
            missing[#missing + 1] = {
                skillLineID = row.skillLineID,
                label = config.label or tostring(row.skillLineID),
                itemID = treatiseInfo.itemID,
            }
        end
    end

    local debugParts = {}
    for _, entry in ipairs(missing) do
        debugParts[#debugParts + 1] = ("%s:%d"):format(entry.label or "?", entry.itemID or 0)
    end
    local debugSignature = table.concat(debugParts, ",")
    if debugSignature ~= debugSignatures.midnightTreatises then
        debugSignatures.midnightTreatises = debugSignature
        DebugLog("Midnight treatises = %s", debugSignature ~= "" and debugSignature or "none")
    end

    return missing
end

trackerUI.FindSurplusReagentContainersInBags = function()
    if not midnightCaches.surplusReagentsDirty and midnightCaches.surplusReagents then
        return midnightCaches.surplusReagents
    end

    local previous = midnightCaches.surplusReagents
    local byItemID = {}
    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)

    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            local config = itemID and runtimeState.surplusReagentContainers[itemID] or nil
            if config then
                local state = byItemID[itemID]
                if not state then
                    state = {
                        itemID = itemID,
                        itemLink = GetContainerItemLinkCompat(bagID, slotIndex),
                        itemName = GetItemInfo and GetItemInfo(itemID) or nil,
                        label = config.label,
                        order = config.order,
                        totalCount = 0,
                    }
                    byItemID[itemID] = state
                end
                state.totalCount = state.totalCount + math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
            end
        end
    end

    local results = {}
    for _, state in pairs(byItemID) do
        results[#results + 1] = state
    end
    table.sort(results, function(left, right)
        return (left.order or 99) < (right.order or 99)
    end)

    if previous and trackerUI.UsePreviousBagCacheOnTransientEmpty(
        "surplusReagents",
        #previous,
        #results,
        previous
    ) then
        midnightCaches.surplusReagents = previous
        midnightCaches.surplusReagentsDirty = false
        return previous
    end

    local debugParts = {}
    for _, state in ipairs(results) do
        debugParts[#debugParts + 1] = ("%s:%d"):format(tostring(state.itemID), state.totalCount or 0)
    end
    local debugSignature = table.concat(debugParts, ",")
    if debugSignature ~= debugSignatures.surplusReagents then
        debugSignatures.surplusReagents = debugSignature
        DebugLog("Surplus reagent containers = %s", debugSignature ~= "" and debugSignature or "none")
    end

    midnightCaches.surplusReagents = results
    midnightCaches.surplusReagentsDirty = false
    return results
end

trackerUI.FindMergeableFinishingReagentsInBags = function()
    if not midnightCaches.finishingReagentMergesDirty and midnightCaches.finishingReagentMerges then
        return midnightCaches.finishingReagentMerges
    end

    local previous = midnightCaches.finishingReagentMerges
    local byItemID = {}
    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)

    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            local config = itemID and runtimeState.mergeableFinishingReagents[itemID] or nil
            if config then
                local state = byItemID[itemID]
                if not state then
                    state = {
                        itemID = itemID,
                        outputItemID = config.outputItemID,
                        itemLink = GetContainerItemLinkCompat(bagID, slotIndex),
                        itemName = GetItemInfo and GetItemInfo(itemID) or nil,
                        label = config.label,
                        order = config.order,
                        totalCount = 0,
                    }
                    byItemID[itemID] = state
                end
                state.totalCount = state.totalCount + math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
            end
        end
    end

    local results = {}
    for _, state in pairs(byItemID) do
        if state.totalCount >= 5 then
            state.mergeCount = math.floor(state.totalCount / 5)
            results[#results + 1] = state
        end
    end
    table.sort(results, function(left, right)
        return (left.order or 99) < (right.order or 99)
    end)

    if previous and trackerUI.UsePreviousBagCacheOnTransientEmpty(
        "finishingReagentMerges",
        #previous,
        #results,
        previous
    ) then
        midnightCaches.finishingReagentMerges = previous
        midnightCaches.finishingReagentMergesDirty = false
        return previous
    end

    midnightCaches.finishingReagentMerges = results
    midnightCaches.finishingReagentMergesDirty = false
    return results
end

trackerUI.UpdateMidnightKnowledgeButton = function(state)
    local button = trackerFrame and trackerFrame.knowledgeButton or nil
    if not button then
        return false
    end

    if state and state.itemID then
        if not button.itemActionLocked then
            button:SetEnabled(true)
        end
        button:SetText(("Utiliser KP x%d"):format(state.totalCount or 1))
        button.bagID = state.bagID
        button.slotIndex = state.slotIndex
        button.itemID = state.itemID
        button.itemLink = state.itemLink
        button.itemName = state.itemName
        if not (InCombatLockdown and InCombatLockdown()) then
            -- Dispatch par itemID comme UpdateMidnightRecipeButton : un nom depend
            -- d'un cache d'objet chaud et reste ambigu entre deux homonymes.
            button:SetAttribute("type", "item")
            button:SetAttribute("item", "item:" .. tostring(state.itemID))
        end
        DebugLog(
            "KnowledgeButton ready itemID=%s bag=%s slot=%s link=%s name=%s item=%s",
            tostring(button.itemID or "none"),
            tostring(button.bagID or "none"),
            tostring(button.slotIndex or "none"),
            tostring(button.itemLink or "none"),
            tostring(button.itemName or "none"),
            tostring(button:GetAttribute("item") or "none")
        )
        button:Show()
        return true
    end

    button.bagID = nil
    button.slotIndex = nil
    button.itemID = nil
    button.itemLink = nil
    button.itemName = nil
    if not (InCombatLockdown and InCombatLockdown()) then
        button:SetAttribute("type", nil)
        button:SetAttribute("item", nil)
    end
    button:Hide()
    return false
end

trackerUI.UpdateMidnightRecipeButton = function(state)
    local button = trackerFrame and trackerFrame.recipeButton or nil
    if not button then
        return false
    end

    if state and state.itemID then
        if not button.itemActionLocked then
            button:SetEnabled(true)
        end
        button:SetText(("Utiliser recette x%d"):format(state.totalCount or 1))
        button.bagID = state.bagID
        button.slotIndex = state.slotIndex
        button.itemID = state.itemID
        button.itemLink = state.itemLink
        button.itemName = state.itemName
        if not (InCombatLockdown and InCombatLockdown()) then
            button:SetAttribute("type", "item")
            button:SetAttribute("item", "item:" .. tostring(state.itemID))
        end
        DebugLog(
            "RecipeButton ready itemID=%s bag=%s slot=%s link=%s name=%s item=%s",
            tostring(button.itemID or "none"),
            tostring(button.bagID or "none"),
            tostring(button.slotIndex or "none"),
            tostring(button.itemLink or "none"),
            tostring(button.itemName or "none"),
            tostring(button:GetAttribute("item") or "none")
        )
        button:Show()
        return true
    end

    button.bagID = nil
    button.slotIndex = nil
    button.itemID = nil
    button.itemLink = nil
    button.itemName = nil
    if not (InCombatLockdown and InCombatLockdown()) then
        button:SetAttribute("type", nil)
        button:SetAttribute("item", nil)
    end
    button:Hide()
    return false
end

trackerUI.GetMidnightRecipeTransferStatus = function(trackedRows)
    local result = {
        requiredQuantity = 0,
        currentQuantity = 0,
        neededQuantity = 0,
        availableQuantity = 0,
        transferQuantity = 0,
        sourceGUID = nil,
        sourceName = nil,
        dataReady = false,
        transferInProgress = false,
        transferFailureReason = nil,
        transferRecoveryAvailable = runtimeState.midnightRecipeTransferRecoveryAvailable == true,
        canTransfer = false,
    }

    for _, row in ipairs(trackedRows or GetTrackedMidnightProfessions()) do
        local recipeStatus = trackerUI.GetMidnightRecipeStatus(row)
        result.requiredQuantity = result.requiredQuantity + (recipeStatus.requiredVoidlightMarl or 0)
    end

    if result.requiredQuantity <= 0 then
        return result
    end

    local currencyID = runtimeState.midnightVoidlightMarlCurrencyID
    result.currentQuantity = GetCurrencyQuantity(currencyID)
    result.neededQuantity = math.max(result.requiredQuantity - result.currentQuantity, 0)
    if result.neededQuantity <= 0 then
        return result
    end

    if not (C_CurrencyInfo and type(C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters) == "function") then
        return result
    end

    local accountCurrencyDataReady = SafeCall(
        C_CurrencyInfo.IsAccountCharacterCurrencyDataReady
    )
    local accountCharacters = SafeCall(
        C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters,
        currencyID
    )
    if type(accountCharacters) ~= "table"
        or accountCurrencyDataReady == false
        or (accountCurrencyDataReady ~= true and next(accountCharacters) == nil) then
        return result
    end

    result.dataReady = true
    local playerGUID = UnitGUID and UnitGUID("player") or nil
    local bestSource
    for _, characterData in pairs(accountCharacters) do
        local quantity = math.max(tonumber(characterData and characterData.quantity) or 0, 0)
        local characterGUID = characterData and characterData.characterGUID or nil
        if quantity > 0 and characterGUID and characterGUID ~= playerGUID then
            result.availableQuantity = result.availableQuantity + quantity
            if not bestSource or quantity > bestSource.quantity then
                bestSource = {
                    guid = characterGUID,
                    name = characterData.fullCharacterName or characterData.characterName,
                    quantity = quantity,
                }
            end
        end
    end

    result.sourceGUID = bestSource and bestSource.guid or nil
    result.sourceName = bestSource and bestSource.name or nil
    result.transferQuantity = bestSource and math.min(result.neededQuantity, bestSource.quantity) or 0
    if bestSource and type(C_CurrencyInfo.GetMaxTransferableAmountFromQuantity) == "function" then
        local maxTransferQuantity = SafeCall(
            C_CurrencyInfo.GetMaxTransferableAmountFromQuantity,
            currencyID,
            bestSource.quantity
        )
        if type(maxTransferQuantity) == "number" then
            result.transferQuantity = math.min(result.transferQuantity, math.max(maxTransferQuantity, 0))
        end
    end
    result.transferInProgress = runtimeState.midnightRecipeTransferDataPending
        or (SafeCall(C_CurrencyInfo.IsCurrencyTransferInProgress) == true
            and not result.transferRecoveryAvailable)
    result.canTransfer = result.transferQuantity > 0 and not result.transferInProgress
    if result.canTransfer and type(C_CurrencyInfo.CanTransferCurrency) == "function" then
        local canTransfer, failureReason = SafeCall(C_CurrencyInfo.CanTransferCurrency, currencyID)
        result.transferFailureReason = failureReason
        if canTransfer == false then
            result.canTransfer = false
        end
    end
    return result
end

trackerUI.ClearMidnightRecipeTransferPending = function(reason)
    runtimeState.midnightRecipeTransferDataPending = false
    runtimeState.midnightRecipeTransferPendingAt = nil
    runtimeState.midnightRecipeTransferStartingQuantity = nil
    runtimeState.midnightRecipeTransferRequestedQuantity = nil
    runtimeState.midnightRecipeTransferRequestToken = (runtimeState.midnightRecipeTransferRequestToken or 0) + 1
    runtimeState.midnightRecipeTransferRecoveryAvailable = false
    if reason then
        DebugLog("Marl transfer state cleared: %s", tostring(reason))
    end
    ScheduleTrackerRefresh(0.05, false)
end

trackerUI.StartMidnightRecipeTransferWatchdog = function(requestedQuantity)
    runtimeState.midnightRecipeTransferDataPending = true
    runtimeState.midnightRecipeTransferPendingAt = GetTime and GetTime() or 0
    runtimeState.midnightRecipeTransferStartingQuantity = GetCurrencyQuantity(
        runtimeState.midnightVoidlightMarlCurrencyID
    )
    runtimeState.midnightRecipeTransferRequestedQuantity = requestedQuantity
    runtimeState.midnightRecipeTransferRecoveryAvailable = false
    runtimeState.midnightRecipeTransferRequestToken = (runtimeState.midnightRecipeTransferRequestToken or 0) + 1
    local requestToken = runtimeState.midnightRecipeTransferRequestToken
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(runtimeState.midnightRecipeTransferTimeoutSeconds or 20, function()
            if runtimeState.midnightRecipeTransferRequestToken ~= requestToken
                or not runtimeState.midnightRecipeTransferDataPending then
                return
            end

            local currentQuantity = GetCurrencyQuantity(runtimeState.midnightVoidlightMarlCurrencyID)
            local startingQuantity = runtimeState.midnightRecipeTransferStartingQuantity or 0
            local requestedAmount = runtimeState.midnightRecipeTransferRequestedQuantity or 0
            if requestedAmount > 0 and currentQuantity >= startingQuantity + requestedAmount then
                trackerUI.ClearMidnightRecipeTransferPending("quantity updated")
                return
            end

            runtimeState.midnightRecipeTransferDataPending = false
            runtimeState.midnightRecipeTransferPendingAt = nil
            runtimeState.midnightRecipeTransferRecoveryAvailable = true
            DebugLog(
                "Marl transfer watchdog timeout current=%d start=%d requested=%d apiInProgress=%s",
                currentQuantity,
                startingQuantity,
                requestedAmount,
                tostring(SafeCall(C_CurrencyInfo.IsCurrencyTransferInProgress) == true)
            )
            ScheduleTrackerRefresh(0.05, false)
        end)
    end
end

trackerUI.RecoverMidnightRecipeTransfer = function()
    runtimeState.midnightRecipeTransferRequestToken = (runtimeState.midnightRecipeTransferRequestToken or 0) + 1
    runtimeState.midnightRecipeTransferDataPending = false
    runtimeState.midnightRecipeTransferPendingAt = nil
    runtimeState.midnightRecipeTransferRecoveryAvailable = false
    if CurrencyTransferMenu and type(HideUIPanel) == "function" then
        pcall(HideUIPanel, CurrencyTransferMenu)
    end
    if CurrencyTransferLog and type(HideUIPanel) == "function" then
        pcall(HideUIPanel, CurrencyTransferLog)
    end
    if C_CurrencyInfo and type(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters) == "function" then
        pcall(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters)
    end
    DebugLog("Marl transfer interface reset")
    trackerUI.OpenMidnightRecipeCurrencyTransfer()
end

trackerUI.OpenMidnightRecipeTransferMenu = function()
    local currencyID = runtimeState.midnightVoidlightMarlCurrencyID
    if not (CurrencyTransferMenu
        and type(CurrencyTransferMenu.TriggerEvent) == "function"
        and CurrencyTransferMenuMixin
        and CurrencyTransferMenuMixin.Event
        and CurrencyTransferMenuMixin.Event.CurrencyTransferRequested) then
        return false
    end
    if SafeCall(C_CurrencyInfo.IsAccountCharacterCurrencyDataReady) ~= true then
        return false
    end

    local ok, err = pcall(
        CurrencyTransferMenu.TriggerEvent,
        CurrencyTransferMenu,
        CurrencyTransferMenuMixin.Event.CurrencyTransferRequested,
        currencyID
    )
    if not ok then
        DebugLog("Marl transfer menu failed: %s", tostring(err))
        return false
    end
    return true
end

trackerUI.OpenMidnightRecipeCurrencyTransfer = function()
    local transferableFilter = Enum
        and Enum.CurrencyFilterType
        and Enum.CurrencyFilterType.DiscoveredAndAllAccountTransferable
    if transferableFilter and C_CurrencyInfo and type(C_CurrencyInfo.SetCurrencyFilter) == "function" then
        pcall(C_CurrencyInfo.SetCurrencyFilter, transferableFilter)
    end

    local tokenFrameShown = TokenFrame and type(TokenFrame.IsShown) == "function" and TokenFrame:IsShown()
    if not tokenFrameShown then
        if CharacterFrame and type(CharacterFrame.ToggleTokenFrame) == "function" then
            pcall(CharacterFrame.ToggleTokenFrame, CharacterFrame)
        elseif type(ToggleCharacter) == "function" then
            pcall(ToggleCharacter, "TokenFrame")
        end
    end
    if C_CurrencyInfo and type(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters) == "function" then
        pcall(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters)
    end
    trackerUI.OpenMidnightRecipeTransferMenu()
    ScheduleTrackerRefresh(0.05, false)
end

trackerUI.ResetMidnightRecipeTransferAction = function(button)
    if not button then
        return
    end

    button.midnightRecipeTransferActionArmed = false
    button.midnightRecipeTransferActionQuantity = nil
    if not (InCombatLockdown and InCombatLockdown()) then
        button:SetAttribute("type", nil)
        button:SetAttribute("clickbutton", nil)
    end
end

trackerUI.IsMidnightRecipeNativeTransferAmountReady = function(state)
    if not state or not state.sourceGUID or state.transferQuantity <= 0 then
        return false
    end

    local menu = CurrencyTransferMenu
    local content = menu and menu.Content or nil
    local amountSelector = content and content.AmountSelector or nil
    local amountInput = amountSelector and amountSelector.InputBox or nil
    local confirmButton = content and content.ConfirmButton or nil
    if not (menu and type(menu.IsShown) == "function" and menu:IsShown()
        and type(menu.GetCurrencyID) == "function"
        and menu:GetCurrencyID() == runtimeState.midnightVoidlightMarlCurrencyID
        and type(menu.GetSourceCharacterData) == "function"
        and type(menu.GetRequestedCurrencyTransferAmount) == "function"
        and amountInput and confirmButton) then
        return false
    end

    local source = menu:GetSourceCharacterData()
    local nativeAmount = menu:GetRequestedCurrencyTransferAmount()
    return source and source.characterGUID == state.sourceGUID
        and nativeAmount == state.transferQuantity
        and (type(confirmButton.IsEnabled) ~= "function" or confirmButton:IsEnabled())
end

trackerUI.UpdateMidnightRecipeTransferButton = function(trackedRows)
    local button = trackerFrame and trackerFrame.recipeMarlButton or nil
    if not button then
        return false
    end

    if runtimeState.midnightRecipeTransferFeatureEnabled ~= true then
        trackerUI.ResetMidnightRecipeTransferAction(button)
        button:Hide()
        return false
    end

    local state = trackerUI.GetMidnightRecipeTransferStatus(trackedRows)
    if state.requiredQuantity <= 0 or state.neededQuantity <= 0 then
        button:SetEnabled(true)
        button.requiredQuantity = nil
        button.currentQuantity = nil
        button.availableQuantity = nil
        button.sourceGUID = nil
        button.transferQuantity = nil
        button.transferRecoveryAvailable = nil
        button:Hide()
        return false
    end

    button.requiredQuantity = state.requiredQuantity
    button.currentQuantity = state.currentQuantity
    button.availableQuantity = state.availableQuantity
    button.sourceGUID = state.sourceGUID
    button.sourceName = state.sourceName
    button.transferQuantity = state.transferQuantity
    button.transferRecoveryAvailable = state.transferRecoveryAvailable

    if state.transferRecoveryAvailable then
        button:SetText("Réinitialiser transfert")
        button:SetEnabled(true)
    elseif state.transferInProgress then
        button:SetText("Transfert en cours")
        button:SetEnabled(false)
    elseif not state.dataReady then
        button:SetText("Ouvrir interface marls")
        button:SetEnabled(type(ToggleCharacter) == "function")
    elseif state.canTransfer then
        if trackerUI.IsMidnightRecipeNativeTransferAmountReady(state) then
            button:SetText("Confirmer transfert")
        else
            button:SetText(("Definir qte x%d"):format(state.transferQuantity))
        end
        button:SetEnabled(true)
    elseif state.sourceGUID then
        button:SetText("Transfert indisponible")
        button:SetEnabled(false)
    else
        button:SetText("Aucun marl disponible")
        button:SetEnabled(false)
    end

    button:Show()
    return true
end

trackerUI.UpdateArtisanConsortiumPayoutButton = function(state)
    local button = trackerFrame and trackerFrame.payoutButton or nil
    if not button then
        return false
    end

    if trackerUI.IsContainerOpeningBlocked()
        or GetAccountDB().autoOpenContainers == true then
        state = nil
    end

    if state and state.itemID then
        if not button.itemActionLocked then
            button:SetEnabled(true)
        end
        local label = state.isPayout and "Ouvrir payout" or "Ouvrir coffre"
        button:SetText(("%s x%d"):format(label, state.totalCount or 1))
        button.bagID = state.bagID
        button.slotIndex = state.slotIndex
        button.payoutTargetKey = state.targetKey
        button.isPayout = state.isPayout
        button.itemID = state.itemID
        button.itemLink = state.itemLink
        button.itemName = state.itemName
        if not (InCombatLockdown and InCombatLockdown()) then
            button:SetAttribute("type", "item")
            button:SetAttribute("item", "item:" .. tostring(state.itemID))
            button:SetAttribute("bag", nil)
            button:SetAttribute("slot", nil)
        end
        button:Show()
        return true
    end

    button.bagID = nil
    button.slotIndex = nil
    button.payoutTargetKey = nil
    button.isPayout = nil
    button.itemID = nil
    button.itemLink = nil
    button.itemName = nil
    if not (InCombatLockdown and InCombatLockdown()) then
        button:SetAttribute("type", nil)
        button:SetAttribute("item", nil)
        button:SetAttribute("bag", nil)
        button:SetAttribute("slot", nil)
    end
    button:Hide()
    return false
end

trackerUI.UpdateSurplusReagentButtons = function(states)
    local buttons = trackerFrame and trackerFrame.surplusReagentButtons or EMPTY_TABLE
    local visibleCount = 0
    local autoOpenContainers = GetAccountDB().autoOpenContainers == true
    local containerOpeningBlocked = trackerUI.IsContainerOpeningBlocked()

    for index, button in ipairs(buttons) do
        local state = states and states[index] or nil
        if state and state.itemID and not autoOpenContainers and not containerOpeningBlocked then
            if not button.itemActionLocked then
                button:SetEnabled(true)
            end
            button:SetText(("Ouvrir surplus %s x%d"):format(state.label or "", state.totalCount or 1))
            button.itemID = state.itemID
            button.itemLink = state.itemLink
            button.itemName = state.itemName
            if not (InCombatLockdown and InCombatLockdown()) then
                button:SetAttribute("type", "item")
                button:SetAttribute("item", "item:" .. tostring(state.itemID))
            end
            button:Show()
            visibleCount = visibleCount + 1
        else
            button.itemID = nil
            button.itemLink = nil
            button.itemName = nil
            if not (InCombatLockdown and InCombatLockdown()) then
                button:SetAttribute("type", nil)
                button:SetAttribute("item", nil)
            end
            button:Hide()
        end
    end

    return visibleCount
end

trackerUI.UpdateFinishingReagentMergeButtons = function(states)
    local buttons = trackerFrame and trackerFrame.finishingReagentMergeButtons or EMPTY_TABLE
    local visibleCount = 0

    for index, button in ipairs(buttons) do
        local state = states and states[index] or nil
        if state and state.itemID and state.mergeCount and state.mergeCount > 0 then
            if not button.itemActionLocked then
                button:SetEnabled(true)
            end
            button:SetText(("Fusionner %s x%d"):format(state.label or "item", state.mergeCount))
            button.itemID = state.itemID
            button.outputItemID = state.outputItemID
            button.itemLink = state.itemLink
            button.itemName = state.itemName
            button.mergeCount = state.mergeCount
            if not (InCombatLockdown and InCombatLockdown()) then
                button:SetAttribute("type", "item")
                button:SetAttribute("item", "item:" .. tostring(state.itemID))
            end
            button:Show()
            visibleCount = visibleCount + 1
        else
            button.itemID = nil
            button.outputItemID = nil
            button.itemLink = nil
            button.itemName = nil
            button.mergeCount = nil
            if not (InCombatLockdown and InCombatLockdown()) then
                button:SetAttribute("type", nil)
                button:SetAttribute("item", nil)
            end
            button:Hide()
        end
    end

    return visibleCount
end

trackerUI.GetOwnedItemCount = function(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return 0
    end

    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID, false, false, false, false) or 0
    end

    if GetItemCount then
        return GetItemCount(itemID) or 0
    end

    return 0
end

trackerUI.InvalidateToolEnchantCache = function()
    midnightCaches.toolEnchantsDirty = true
end

trackerUI.GetProfessionIDForSkillLine = function(skillLineID)
    local info = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
    if type(info) == "table" then
        return tonumber(info.profession or info.professionID)
    end

    if GetProfessions and GetProfessionInfo then
        for _, professionIndex in ipairs({ GetProfessions() }) do
            if professionIndex then
                local _, _, _, _, _, _, baseSkillLineID = SafeCall(GetProfessionInfo, professionIndex)
                local mappedSkillLineID = runtimeState.baseProfessionToMidnightSkillLineID[baseSkillLineID]
                if mappedSkillLineID == skillLineID
                    and C_TradeSkillUI
                    and type(C_TradeSkillUI.GetProfessionSkillLineID) == "function" then
                    return tonumber(SafeCall(C_TradeSkillUI.GetProfessionSkillLineID, baseSkillLineID))
                end
            end
        end
    end
end

trackerUI.GetToolEnchantStat = function(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    -- The profession tool stat is rolled per item. It is present in the tooltip
    -- of the unique item link. GetItemStats() can describe the base item and
    -- must not override the random stat of the owned tool.
    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
        local tooltipData = SafeCall(C_TooltipInfo.GetHyperlink, itemLink)
        if type(tooltipData) == "table" and type(tooltipData.lines) == "table" then
            local function Normalize(text)
                if type(text) ~= "string" then
                    return ""
                end
                text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                text = text:gsub("%s+", " ")
                return string.lower(text)
            end

            for _, line in ipairs(tooltipData.lines) do
                local text = Normalize(line.leftText) .. " " .. Normalize(line.rightText)
                -- Retenir le libelle le plus long qui matche la ligne, jamais le
                -- premier de statOrder : un libelle d'une autre langue peut etre
                -- le faux ami d'une stat testee plus tot.
                local bestStatKey, bestLength = nil, 0
                local function Consider(statKey, needle)
                    if needle ~= "" and #needle > bestLength and text:find(needle, 1, true) then
                        bestStatKey, bestLength = statKey, #needle
                    end
                end
                for _, statKey in ipairs(runtimeState.professionToolEnchantments.statOrder) do
                    local statInfo = runtimeState.professionToolEnchantments.byStat[statKey]
                    for _, key in ipairs(statInfo.statKeys or EMPTY_TABLE) do
                        Consider(statKey, Normalize(_G[key]))
                    end
                    for _, alias in ipairs(statInfo.tooltipAliases or EMPTY_TABLE) do
                        Consider(statKey, Normalize(alias))
                    end
                end
                if bestStatKey then
                    return bestStatKey
                end
            end
            return nil, false
        end
        return nil, true
    end

    return nil, false
end

trackerUI.GetToolEnchantID = function(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end

    local payload = itemLink:match("|Hitem:([^|]+)|h") or itemLink:match("item:([^|]+)")
    if not payload then
        return nil
    end

    local _, enchantID = strsplit(":", payload)
    return tonumber(enchantID) or 0
end

trackerUI.RequestToolItemData = function(itemID)
    if not itemID or not C_Item or type(C_Item.RequestLoadItemDataByID) ~= "function" then
        return false
    end

    local now = GetTime and GetTime() or 0
    local retryAt = runtimeState.itemDataLoadRetryAt[itemID] or 0
    if runtimeState.itemDataLoadPending[itemID] or now < retryAt then
        return true
    end
    runtimeState.itemDataLoadPending[itemID] = true
    runtimeState.itemDataLoadRetryAt[itemID] = now + runtimeState.itemDataLoadCooldownSeconds
    SafeCall(C_Item.RequestLoadItemDataByID, itemID)
    return true
end

-- Un emplacement de metier est conforme s'il porte un objet au moins rare dont
-- le niveau d'objet depasse le seuil. Ne jamais conclure sur un objet dont la
-- rarete ou le niveau ne sont pas encore charges : ce serait signaler un
-- equipement non conforme alors que seule la donnee manque.
trackerUI.GetProfessionGearMinimumItemLevel = function()
    local configured = tonumber(GetAccountDB().professionGearMinimumItemLevel)
    if configured and configured > 0 then
        return configured
    end
    return runtimeState.professionGear.minimumItemLevel
end

trackerUI.EvaluateProfessionGearSlot = function(slotID, isToolSlot)
    local slotState = { slotID = slotID, isToolSlot = isToolSlot == true }
    if type(GetInventoryItemLink) ~= "function" then
        slotState.pending = true
        return slotState
    end

    local itemLink = SafeCall(GetInventoryItemLink, "player", slotID)
    if type(itemLink) ~= "string" or itemLink == "" then
        -- Un slot sans lien est reellement vide : le client rend le lien d'un
        -- objet equipe meme quand ses donnees ne sont pas encore chargees.
        slotState.empty = true
        return slotState
    end
    slotState.itemLink = itemLink
    slotState.itemID = type(GetInventoryItemID) == "function"
        and tonumber(SafeCall(GetInventoryItemID, "player", slotID))
        or nil

    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        slotState.equipLoc = select(4, SafeCall(C_Item.GetItemInfoInstant, itemLink))
    elseif type(GetItemInfoInstant) == "function" then
        slotState.equipLoc = select(4, SafeCall(GetItemInfoInstant, itemLink))
    end
    slotState.isTool = slotState.equipLoc == "INVTYPE_PROFESSION_TOOL"

    -- SafeCall ne propage que cinq valeurs de retour : lire la rarete en
    -- troisieme position est sur, mais le niveau d'objet doit venir de
    -- GetDetailedItemLevelInfo, qui tient compte des ameliorations.
    local itemName, _, quality = SafeCall(GetItemInfo, itemLink)
    -- GetDetailedItemLevelInfo rend trois valeurs : niveau effectif, apercu
    -- (booleen) et niveau de base. Les passer telles quelles a tonumber ferait
    -- du booleen sa base numerique et leverait. Une affectation simple ne
    -- retient que la premiere.
    local detailedItemLevel
    if type(GetDetailedItemLevelInfo) == "function" then
        detailedItemLevel = SafeCall(GetDetailedItemLevelInfo, itemLink)
    end
    local itemLevel = tonumber(detailedItemLevel)
    slotState.itemName = itemName
    quality = tonumber(quality)
    if not quality or not itemLevel then
        if slotState.itemID then
            trackerUI.RequestToolItemData(slotState.itemID)
        end
        slotState.pending = true
        return slotState
    end

    slotState.quality = quality
    slotState.itemLevel = itemLevel
    local minimumItemLevel = trackerUI.GetProfessionGearMinimumItemLevel()
    slotState.lowQuality = quality < runtimeState.professionGear.minimumQuality
    slotState.lowItemLevel = itemLevel < minimumItemLevel
    slotState.ok = not slotState.lowQuality and not slotState.lowItemLevel
    return slotState
end

-- GetProfessionSlots peut indexer a partir de 0 ou de 1 selon les versions du
-- client : balayer les deux conventions plutot que d'en supposer une.
-- Libelle lisible d'un emplacement fautif pour l'infobulle. Sur un slot vide la
-- nature de l'objet attendu est inconnue : se rabattre sur la position, l'outil
-- etant toujours le premier emplacement rendu par GetProfessionSlots.
trackerUI.DescribeProfessionGearSlot = function(slotState)
    local slotLabel = (slotState.isTool or slotState.isToolSlot) and "Outil" or "Accessoire"
    if slotState.empty then
        if slotState.isToolSlot or slotState.isTool then
            return ("%s : aucun outil conforme possede"):format(slotLabel)
        end
        return ("%s : vide"):format(slotLabel)
    end
    local itemLabel = slotState.itemName or ("item:" .. tostring(slotState.itemID or "?"))
    local reasons = {}
    if slotState.lowQuality then
        reasons[#reasons + 1] = "rarete sous rare"
    end
    if slotState.lowItemLevel then
        reasons[#reasons + 1] = ("ilvl %s < %d"):format(
            tostring(slotState.itemLevel or "?"),
            trackerUI.GetProfessionGearMinimumItemLevel())
    end
    if #reasons == 0 then
        return ("%s : %s"):format(slotLabel, itemLabel)
    end
    return ("%s : %s (%s)"):format(slotLabel, itemLabel, table.concat(reasons, ", "))
end

trackerUI.CollectProfessionGearSlots = function(profession, slots, toolSlot)
    local gear = profession.gear
    local seen = {}
    for index = 0, 10 do
        local slotID = tonumber(slots[index])
        if slotID and not seen[slotID] then
            seen[slotID] = true
            local slotState = trackerUI.EvaluateProfessionGearSlot(slotID, slotID == toolSlot)
            gear.slots[#gear.slots + 1] = slotState
        end
    end
end

-- Le verdict d'un emplacement n'est arrete qu'ici, une fois les sacs scannes.
-- L'emplacement d'outil est juge sur la POSSESSION d'au moins un outil conforme,
-- pas sur l'outil porte : YayaQueue echange l'outil Multicraft et l'outil
-- Resourcefulness selon la recette, donc ce qui est porte a un instant donne ne
-- dit rien, et un verdict sur le port ferait clignoter le rappel au rythme des
-- echanges. Les accessoires, eux, ne tournent pas : leur emplacement se juge
-- bien sur ce qu'il porte.
trackerUI.SummarizeProfessionGear = function(profession)
    local gear = profession.gear
    gear.emptyCount, gear.lowQualityCount = 0, 0
    gear.lowItemLevelCount, gear.nonCompliantCount = 0, 0

    local hasCompliantTool, toolComplianceUnknown = false, false
    -- La statistique compte autant que le rang : un outil ilvl 232 qui ne porte
    -- pas Resourcefulness ne satisfait pas l'exigence, et c'est cette variante
    -- manquante que l'achat doit viser. `pendingStats` retient les exemplaires
    -- dont le niveau d'objet n'est pas encore lisible : inconnu n'est pas absent,
    -- sinon un rappel apparait le temps d'un chargement et la file achete un
    -- doublon.
    local compliantStats, pendingStats = {}, {}
    for _, tool in ipairs(profession.tools) do
        if tool.compliant == true then
            hasCompliantTool = true
            if tool.statKey then
                compliantStats[tool.statKey] = true
            end
        elseif tool.compliant == nil then
            toolComplianceUnknown = true
            if tool.statKey then
                pendingStats[tool.statKey] = true
            end
        end
    end
    gear.hasCompliantTool = hasCompliantTool
    gear.toolComplianceUnknown = toolComplianceUnknown
    gear.compliantToolStats = compliantStats
    gear.pendingToolStats = pendingStats

    for _, slotState in ipairs(gear.slots) do
        -- La nature de l'emplacement decide, jamais l'objet qui s'y trouve :
        -- `isToolSlot` vient de la position rendue par GetProfessionSlots.
        if slotState.isToolSlot then
            if hasCompliantTool then
                slotState.compliant = true
                slotState.satisfiedByOwnedTool = slotState.ok ~= true
            elseif toolComplianceUnknown or slotState.pending then
                slotState.compliant = nil
            else
                slotState.compliant = false
            end
        elseif slotState.pending then
            slotState.compliant = nil
        else
            slotState.compliant = slotState.ok == true
        end

        if slotState.compliant == nil then
            gear.pending = true
        elseif slotState.compliant == false then
            gear.nonCompliantCount = gear.nonCompliantCount + 1
            if slotState.empty then
                gear.emptyCount = gear.emptyCount + 1
            else
                if slotState.lowQuality then
                    gear.lowQualityCount = gear.lowQualityCount + 1
                end
                if slotState.lowItemLevel then
                    gear.lowItemLevelCount = gear.lowItemLevelCount + 1
                end
            end
        end
    end
end

-- Ce qui manque a un metier cote outil, statistique comprise. Un seul endroit
-- en decide : le plan d'achat, les rappels et le besoin d'enchantement en
-- decoulent. Deux calculs separes divergeaient, et la file achetait alors un
-- outil sans son enchantement, ou l'inverse.
trackerUI.GetProfessionToolNeeds = function(profession, config)
    local needs = {}
    if not profession or profession.toolScanPending then
        return needs, true
    end

    local gear = profession.gear or EMPTY_TABLE
    local compliant = gear.compliantToolStats or EMPTY_TABLE
    local pendingStats = gear.pendingToolStats or EMPTY_TABLE

    -- « Possede mais sous le seuil » n'est pas « absent » : le rappel doit dire
    -- lequel des deux manque, sinon il passe pour faux devant un outil qu'on a
    -- sous les yeux. La nuance est portee par le besoin lui-meme, pour que les
    -- jetons de ligne n'aient rien a recalculer.
    local function OwnsStat(statKey)
        for _, tool in ipairs(profession.tools or EMPTY_TABLE) do
            if tool.statKey == statKey then
                return true
            end
        end
        return false
    end
    local function StatNeed(statKey, reason)
        local statInfo = runtimeState.professionToolEnchantments.byStat[statKey]
        return {
            statKey = statKey,
            reason = reason,
            shortLabel = statInfo and statInfo.shortLabel or statKey,
            ownedUnderRank = OwnsStat(statKey),
        }
    end

    if config and config.gathering == true then
        -- Resourcefulness n'economise que des reactifs de craft : un outil de
        -- recolte se juge sur son seul rang, et sa statistique n'est pas ciblee.
        if gear.hasCompliantTool == false and gear.toolComplianceUnknown ~= true then
            needs[#needs + 1] = {
                reason = "outil",
                shortLabel = "outil",
                ownedUnderRank = #(profession.tools or EMPTY_TABLE) > 0,
            }
        end
    elseif compliant.resourcefulness ~= true and pendingStats.resourcefulness ~= true then
        needs[#needs + 1] = StatNeed("resourcefulness", "outil Resourcefulness")
    end

    -- Meme regle que l'emplacement d'outil : la possession decide, jamais le
    -- port. YayaQueue equipe l'outil Multicrafting depuis les sacs, mais
    -- l'echange y renvoie l'outil qui sort, donc un exemplaire deja equipe est
    -- exactement ce qu'il faut -- il est meme deja en place. Juger sur le sac
    -- faisait reclamer un second outil des que le premier etait porte.
    if profession.requiresMulticraftTool
        and compliant.multicrafting ~= true
        and pendingStats.multicrafting ~= true then
        needs[#needs + 1] = StatNeed("multicrafting", "outil Multicrafting")
    end

    return needs, false
end

trackerUI.GetToolItemDetails = function(itemID, itemLink, source, bagID, slotIndex)
    local function ReturnPending()
        trackerUI.RequestToolItemData(itemID)
        return nil, true, true
    end

    local equipLoc
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        equipLoc = select(4, SafeCall(C_Item.GetItemInfoInstant, itemLink or itemID))
    end
    if not equipLoc and type(GetItemInfoInstant) == "function" then
        equipLoc = select(4, SafeCall(GetItemInfoInstant, itemLink or itemID))
    end
    if not equipLoc and type(GetItemInfo) == "function" then
        equipLoc = select(9, SafeCall(GetItemInfo, itemLink or itemID))
    end
    if not equipLoc then
        return ReturnPending()
    end
    if equipLoc ~= "INVTYPE_PROFESSION_TOOL" then
        return nil, false, false
    end

    local quality = type(GetItemInfo) == "function" and select(3, SafeCall(GetItemInfo, itemLink or itemID)) or nil
    if not quality and C_Item and type(C_Item.GetItemQualityByID) == "function" then
        quality = SafeCall(C_Item.GetItemQualityByID, itemID)
    end
    if not quality then
        return ReturnPending()
    end
    if tonumber(quality) < 3 then
        return nil, false, false
    end

    -- Le lien de l'objet n'est PAS exige ici. Un outil qui vient d'etre achete
    -- n'est pas encore lie, et c'est exactement l'exemplaire qu'il ne faut pas
    -- racheter : l'ignorer faisait commander un doublon dans la foulee de la
    -- livraison. YayaQueue, lui, garde son filtre soulbound pour l'echange
    -- d'outil avant craft -- il n'equipe que ce qui appartient deja au
    -- personnage. Ce que le tracker compte, c'est la possession.
    --
    -- Restent la rarete, l'emplacement d'equipement et la ligne de metier pour
    -- borner ce qui est retenu : un objet du bon itemID garde pour la revente
    -- compterait, mais il lui faudrait aussi la bonne statistique et le bon
    -- rang pour satisfaire une variante.

    -- Never replace a missing unique link with GetItemInfo(itemID): the tool's
    -- profession stat is randomized on the owned item, not on the base item.
    if type(itemLink) ~= "string" or not itemLink:find("item:", 1, true) then
        return ReturnPending()
    end

    local enchantID = trackerUI.GetToolEnchantID(itemLink)
    if enchantID == nil then
        return ReturnPending()
    end

    local statKey, statsPending = trackerUI.GetToolEnchantStat(itemLink)
    if not statKey then
        if statsPending then
            return ReturnPending()
        end
        return nil, false, true
    end

    local statInfo = runtimeState.professionToolEnchantments.byStat[statKey]
    -- Tout outil retenu ici est deja rare ou mieux : le filtre de rarete est
    -- applique plus haut. Reste le niveau d'objet, lu sur le lien unique pour
    -- tenir compte du rang de craft. `compliant` vaut nil quand ce niveau n'est
    -- pas lisible : inconnu n'est pas non conforme.
    -- Meme piege que dans EvaluateProfessionGearSlot : ne retenir que la
    -- premiere des trois valeurs rendues par GetDetailedItemLevelInfo.
    local detailedItemLevel
    if type(GetDetailedItemLevelInfo) == "function" then
        detailedItemLevel = SafeCall(GetDetailedItemLevelInfo, itemLink)
    end
    local itemLevel = tonumber(detailedItemLevel)
    local compliant = nil
    if itemLevel then
        compliant = itemLevel >= trackerUI.GetProfessionGearMinimumItemLevel()
    end
    return {
        itemID = itemID,
        itemLink = itemLink,
        statKey = statKey,
        statInfo = statInfo,
        enchantID = enchantID,
        missingEnchant = enchantID == 0,
        source = source,
        bagID = bagID,
        slotIndex = slotIndex,
        quality = tonumber(quality),
        itemLevel = itemLevel,
        compliant = compliant,
    }, false, true
end

trackerUI.GetToolEnchantWarbankQuantity = function(itemID)
    if type(TSM_API) ~= "table"
        or type(TSM_API.GetWarbankQuantity) ~= "function"
        or type(TSM_API.ToItemString) ~= "function" then
        return nil
    end

    local okString, itemString = pcall(TSM_API.ToItemString, "i:" .. tostring(itemID))
    if not okString or type(itemString) ~= "string" or itemString == "" then
        return nil
    end

    local okQuantity, quantity = pcall(TSM_API.GetWarbankQuantity, itemString)
    if okQuantity and type(quantity) == "number" then
        return math.max(0, quantity)
    end
end

-- Les enchantements reclames par les outils possedes, arretes APRES les
-- besoins d'outil parce qu'ils en dependent.
--
-- Une statistique encore ouverte dans `toolNeeds` signifie qu'aucun exemplaire
-- conforme n'est possede : ceux qu'on a sont sous le seuil et partent des que
-- le remplacant arrive. Les enchanter reviendrait a jeter un parchemin, et
-- leur besoin est de toute facon deja porte par le futur outil, que le plan
-- commande avec son enchantement. Compter les deux faisait acheter deux
-- parchemins pour un seul outil final, et proposer de poser le premier sur
-- l'outil qu'on remplace.
trackerUI.CollectProfessionEnchantNeeds = function(profession, skillLineID, result)
    local replacedStats = {}
    for _, need in ipairs(profession.toolNeeds or EMPTY_TABLE) do
        if need.statKey then
            replacedStats[need.statKey] = true
        end
    end

    local skipped = 0
    for _, details in ipairs(profession.tools) do
        local statInfo = details.statInfo
        local wrongEnchant = not statInfo or details.enchantID ~= statInfo.enchantID
        if wrongEnchant and replacedStats[details.statKey] then
            skipped = skipped + 1
        elseif wrongEnchant then
            local requiredItemID = statInfo and statInfo.itemID or nil

            if details.missingEnchant then
                local key = requiredItemID or details.itemID
                local entry = profession.missingEnchantTools[key]
                if not entry then
                    entry = {
                        itemID = details.itemID,
                        requiredItemID = requiredItemID,
                        label = statInfo and statInfo.shortLabel or nil,
                        statLabel = statInfo and statInfo.label or nil,
                        quantity = 0,
                    }
                    profession.missingEnchantTools[key] = entry
                end
                entry.quantity = entry.quantity + 1
            elseif requiredItemID then
                profession.missingByItemID[requiredItemID] =
                    (profession.missingByItemID[requiredItemID] or 0) + 1
                local entry = profession.missingTools[requiredItemID]
                if not entry then
                    entry = {
                        itemID = requiredItemID,
                        label = statInfo.shortLabel,
                        statLabel = statInfo.label,
                        quantity = 0,
                    }
                    profession.missingTools[requiredItemID] = entry
                end
                entry.quantity = entry.quantity + 1
            end

            if requiredItemID then
                result.requiredByItemID[requiredItemID] =
                    (result.requiredByItemID[requiredItemID] or 0) + 1
            end

            -- Un outil de rechange garde en sac s'enchante comme l'outil
            -- equipe : le bouton securise cible alors la paire
            -- target-bag/target-slot au lieu du seul slot d'inventaire. La
            -- cible doit rester adressable.
            local targetAddressable =
                (details.source == "equipment" and details.slotIndex ~= nil)
                or (details.source == "bag" and details.bagID ~= nil and details.slotIndex ~= nil)
            if targetAddressable and statInfo then
                local action = {
                    skillLineID = skillLineID,
                    enchantItemID = statInfo.itemID,
                    expectedEnchantID = statInfo.enchantID,
                    enchantLink = statInfo.itemLink,
                    toolItemID = details.itemID,
                    toolLink = details.itemLink,
                    toolName = type(GetItemInfo) == "function"
                        and SafeCall(GetItemInfo, details.itemLink or details.itemID)
                        or nil,
                    source = details.source,
                    toolBag = details.source == "bag" and details.bagID or nil,
                    toolSlot = details.slotIndex,
                    statKey = details.statKey,
                    statLabel = statInfo.label,
                    professionLabel = profession.label,
                }
                profession.applyEnchants[#profession.applyEnchants + 1] = action
                result.applyEnchants[#result.applyEnchants + 1] = action
            end
        end
    end

    return skipped
end

trackerUI.FindToolEnchantState = function(trackedRows)
    if not midnightCaches.toolEnchantsDirty and midnightCaches.toolEnchants then
        return midnightCaches.toolEnchants
    end

    trackedRows = trackedRows or GetTrackedMidnightProfessions()
    local previous = midnightCaches.toolEnchants
    local result = {
        bySkillLineID = {},
        -- Les enchantements reclames par les outils DEJA POSSEDES. Ceux des
        -- outils encore a acheter n'entrent pas ici : ils naissent du besoin
        -- d'outil, et c'est le plan d'approvisionnement qui les emet, juste
        -- apres l'outil qui les porte.
        requiredByItemID = {},
        applyEnchants = {},
        pending = false,
        debugItems = {},
    }
    local trackedSkillLineIDs = {}
    for _, row in ipairs(trackedRows) do
        trackedSkillLineIDs[row.skillLineID] = true
        result.bySkillLineID[row.skillLineID] = {
            missingTools = {},
            missingEnchantTools = {},
            missingByItemID = {},
            tools = {},
            applyEnchants = {},
            hasEquippedTool = false,
            equippedToolPending = false,
            hasResourcefulnessTool = false,
            hasMulticraftTool = false,
            requiresMulticraftTool =
                runtimeState.professionGear.multicraftToolSkillLineIDs[row.skillLineID] == true,
            toolScanPending = false,
            professionID = nil,
            toolSlot = nil,
            gear = {
                slots = {},
                emptyCount = 0,
                lowQualityCount = 0,
                lowItemLevelCount = 0,
                -- Un emplacement peut cumuler rarete et niveau insuffisants :
                -- compter les emplacements fautifs, pas les motifs, sinon le
                -- total depasse le nombre reel d'emplacements. Les compteurs
                -- sont arretes par SummarizeProfessionGear, une fois les sacs
                -- scannes, car l'emplacement d'outil se juge sur la possession.
                nonCompliantCount = 0,
                hasCompliantTool = false,
                toolComplianceUnknown = false,
                compliantToolStats = {},
                pendingToolStats = {},
                pending = false,
                slotsKnown = false,
            },
            toolNeeds = {},
        }
    end

    local seenLocations = {}
    local function AddTool(source, skillLineID, itemID, itemLink, bagID, slotIndex)
        if not skillLineID or not trackedSkillLineIDs[skillLineID] or not itemID then
            return
        end
        local locationKey = source .. ":" .. tostring(bagID or slotIndex) .. ":" .. tostring(slotIndex or "")
        if seenLocations[locationKey] then
            return
        end
        seenLocations[locationKey] = true

        local details, pending, eligible = trackerUI.GetToolItemDetails(itemID, itemLink, source, bagID, slotIndex)
        if pending then
            result.pending = true
        end
        if details then
            result.debugItems[#result.debugItems + 1] = ("item=%s source=%s enchant=%s state=%s"):format(
                tostring(itemID),
                tostring(source),
                tostring(details.enchantID),
                details.missingEnchant
                    and ("missing:" .. tostring(details.statKey or "unknown"))
                    or tostring(details.statKey or "unknown")
            )
        else
            result.debugItems[#result.debugItems + 1] = ("item=%s source=%s details=nil pending=%s eligible=%s"):format(
                tostring(itemID),
                tostring(source),
                tostring(pending),
                tostring(eligible)
            )
        end
        if not details then
            return nil, pending, eligible
        end

        local profession = result.bySkillLineID[skillLineID]
        -- Le scan se contente de recenser. Les enchantements sont comptes plus
        -- tard, par trackerUI.CollectProfessionEnchantNeeds, quand les besoins
        -- d'outil sont connus : eux seuls disent quels exemplaires sont
        -- sortants, et un outil sortant ne s'enchante pas.
        profession.tools[#profession.tools + 1] = details
        return details, pending, eligible
    end

    for _, row in ipairs(trackedRows) do
        local profession = result.bySkillLineID[row.skillLineID]
        profession.label = row.config and row.config.label or nil
        local professionID = trackerUI.GetProfessionIDForSkillLine(row.skillLineID)
        profession.professionID = professionID
        if not professionID
            or not C_TradeSkillUI
            or type(C_TradeSkillUI.GetProfessionSlots) ~= "function" then
            profession.equippedToolPending = true
        else
            local slots = SafeCall(C_TradeSkillUI.GetProfessionSlots, professionID)
            if type(slots) ~= "table" then
                profession.equippedToolPending = true
            else
                local toolSlot = slots[1] or slots[0]
                profession.toolSlot = toolSlot
                if toolSlot and type(GetInventoryItemLink) == "function" then
                    local itemLink = SafeCall(GetInventoryItemLink, "player", toolSlot)
                    local itemID = type(GetInventoryItemID) == "function"
                        and tonumber(SafeCall(GetInventoryItemID, "player", toolSlot))
                        or nil
                    local _, pending, eligible = AddTool("equipment", row.skillLineID, itemID, itemLink, nil, toolSlot)
                    if eligible then
                        profession.hasEquippedTool = true
                    end
                    if pending then
                        profession.equippedToolPending = true
                    end
                elseif toolSlot then
                    profession.equippedToolPending = true
                end
                profession.gear.slotsKnown = true
                trackerUI.CollectProfessionGearSlots(profession, slots, toolSlot)
            end
        end
        if not profession.gear.slotsKnown then
            profession.gear.pending = true
        end
    end

    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)
    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            if itemID then
                local itemLink = GetContainerItemLinkCompat(bagID, slotIndex)
                if not itemLink and C_Item and type(C_Item.GetItemInfoInstant) == "function"
                    and select(4, SafeCall(C_Item.GetItemInfoInstant, itemID)) == "INVTYPE_PROFESSION_TOOL" then
                    result.pending = trackerUI.RequestToolItemData(itemID) or result.pending
                end
                local skillLineID = (itemLink or itemID)
                    and C_TradeSkillUI
                    and type(C_TradeSkillUI.GetSkillLineForGear) == "function"
                    and tonumber(SafeCall(C_TradeSkillUI.GetSkillLineForGear, itemLink or itemID))
                    or nil
                skillLineID = trackedSkillLineIDs[skillLineID] and skillLineID
                    or runtimeState.baseProfessionToMidnightSkillLineID[skillLineID]
                AddTool("bag", skillLineID, itemID, itemLink, bagID, slotIndex)
            end
        end
    end

    local debugParts = {}
    for _, row in ipairs(trackedRows) do
        local profession = result.bySkillLineID[row.skillLineID]
        -- Presence d'un outil Resourcefulness, equipe ou en sac : la stat est
        -- celle lue au tooltip de chaque exemplaire, jamais un enchantement.
        -- Possession, jamais port : dans un flux multi-outil l'exemplaire porte
        -- change au fil des recettes, un outil garde en sac compte donc autant.
        for _, tool in ipairs(profession.tools) do
            if tool.statKey == "resourcefulness" then
                profession.hasResourcefulnessTool = true
            elseif tool.statKey == "multicrafting" then
                profession.hasMulticraftTool = true
            end
        end
        -- Un scan incomplet ne doit pas declarer un outil absent : sans cache
        -- precedent, FindToolEnchantState renvoie un resultat encore partiel.
        profession.toolScanPending = result.pending == true
            or profession.equippedToolPending == true
        trackerUI.SummarizeProfessionGear(profession)
        profession.toolNeeds = trackerUI.GetProfessionToolNeeds(profession, row.config)
        -- Les enchantements viennent apres, et pas avant : ils dependent de ce
        -- que les besoins d'outil declarent sortant.
        local skippedEnchants =
            trackerUI.CollectProfessionEnchantNeeds(profession, row.skillLineID, result)
        local unenchantedCount = 0
        local wrongEnchantCount = 0
        for _, tool in pairs(profession.missingEnchantTools) do
            unenchantedCount = unenchantedCount + (tool.quantity or 0)
        end
        for _, tool in pairs(profession.missingTools) do
            wrongEnchantCount = wrongEnchantCount + (tool.quantity or 0)
        end
        -- L'enchantement part avec l'outil : un outil achete nu resterait a
        -- enchanter, et son rappel n'apparaitrait qu'au scan suivant, une fois
        -- l'achat fait. Le plan d'approvisionnement emet donc l'enchantement
        -- juste apres l'outil qu'il commande, et le scanner ne connait que les
        -- enchantements des outils deja possedes.
        local gear = profession.gear
        local needParts = {}
        for _, need in ipairs(profession.toolNeeds) do
            needParts[#needParts + 1] = need.statKey or "any"
        end
        debugParts[#debugParts + 1] = ("gear[%d] slots=%d empty=%d lowQ=%d lowIlvl=%d bad=%d pending=%s tool=%s rfOwned=%s rfOk=%s mcOwned=%s mcOk=%s needs=%s"):format(
            row.skillLineID,
            #gear.slots,
            gear.emptyCount,
            gear.lowQualityCount,
            gear.lowItemLevelCount,
            gear.nonCompliantCount,
            tostring(gear.pending),
            tostring(gear.hasCompliantTool),
            tostring(profession.hasResourcefulnessTool),
            tostring(gear.compliantToolStats.resourcefulness == true),
            tostring(profession.hasMulticraftTool),
            tostring(gear.compliantToolStats.multicrafting == true),
            #needParts > 0 and table.concat(needParts, "+") or "none")
        debugParts[#debugParts + 1] = ("id=%d prof=%s slot=%s tools=%d unench=%d wrong=%d skipped=%d apply=%d equipped=%s rf=%s pending=%s"):format(
            row.skillLineID,
            tostring(profession.professionID),
            tostring(profession.toolSlot),
            #profession.tools,
            unenchantedCount,
            wrongEnchantCount,
            skippedEnchants,
            #profession.applyEnchants,
            tostring(profession.hasEquippedTool),
            tostring(profession.hasResourcefulnessTool),
            tostring(profession.toolScanPending)
        )
    end
    local debugSummary = #debugParts > 0 and table.concat(debugParts, " | ") or "none"
    local debugItems = #result.debugItems > 0 and " items=" .. table.concat(result.debugItems, ",") or ""
    local requiredParts = {}
    for itemID, quantity in pairs(result.requiredByItemID) do
        requiredParts[#requiredParts + 1] = tostring(itemID) .. "x" .. tostring(quantity)
    end
    table.sort(requiredParts)
    local requiredSummary = #requiredParts > 0 and table.concat(requiredParts, ",") or "none"
    local debugSignature = debugSummary
        .. "|need=" .. requiredSummary
        .. "|scanPending=" .. tostring(result.pending)
        .. debugItems
    if debugSignature ~= debugSignatures.toolEnchants then
        debugSignatures.toolEnchants = debugSignature
        DebugLog("Tool enchant scan = %s", debugSignature)
    end

    if result.pending and previous then
        midnightCaches.toolEnchants = previous
        midnightCaches.toolEnchantsDirty = false
        return previous
    end

    -- L'outil equipe passe avant les outils de rechange : le pool de boutons
    -- est borne, et c'est lui qui doit rester visible quand il y a trop
    -- d'actions a afficher.
    table.sort(result.applyEnchants, function(left, right)
        local leftRank = left.source == "equipment" and 0 or 1
        local rightRank = right.source == "equipment" and 0 or 1
        if leftRank ~= rightRank then
            return leftRank < rightRank
        end
        if (left.toolBag or -1) ~= (right.toolBag or -1) then
            return (left.toolBag or -1) < (right.toolBag or -1)
        end
        if (left.toolSlot or 0) ~= (right.toolSlot or 0) then
            return (left.toolSlot or 0) < (right.toolSlot or 0)
        end
        return (left.skillLineID or 0) < (right.skillLineID or 0)
    end)
    midnightCaches.toolEnchants = result
    midnightCaches.toolEnchantsDirty = false
    return result
end

trackerUI.MarkToolEnchantApplicationPending = function(action)
    if not action or not action.skillLineID or not action.toolSlot or not action.enchantItemID then
        return
    end

    -- Deux outils de rechange peuvent partager un meme slotIndex dans deux
    -- sacs differents : la source et le sac font partie de l'identite de la
    -- cible, sinon une confirmation validerait la mauvaise application.
    local key = table.concat({
        tostring(action.skillLineID),
        tostring(action.source or "equipment"),
        tostring(action.toolBag or "-"),
        tostring(action.toolSlot),
    }, ":")
    runtimeState.toolEnchantApplicationPending[key] = {
        skillLineID = action.skillLineID,
        source = action.source or "equipment",
        toolBag = action.toolBag,
        toolSlot = action.toolSlot,
        enchantItemID = action.enchantItemID,
        expectedEnchantID = action.expectedEnchantID,
        expiresAt = (GetTime and GetTime() or 0) + 30,
    }
end

trackerUI.ConfirmToolEnchantApplications = function(state)
    local pendingApplications = runtimeState.toolEnchantApplicationPending or EMPTY_TABLE
    local now = GetTime and GetTime() or 0
    for key, action in pairs(pendingApplications) do
        if action.expiresAt and now > action.expiresAt then
            pendingApplications[key] = nil
        else
            local profession = state and state.bySkillLineID[action.skillLineID]
            local confirmed = false
            local expectedSource = action.source or "equipment"
            for _, tool in ipairs(profession and profession.tools or EMPTY_TABLE) do
                if tool.source == expectedSource
                    and tool.bagID == action.toolBag
                    and tool.slotIndex == action.toolSlot
                    and tool.enchantID == action.expectedEnchantID then
                    confirmed = true
                    break
                end
            end
            if confirmed then
                local removedQuantity = 0
                if YayaQueueAPI and type(YayaQueueAPI.RemoveItem) == "function" then
                    local ok
                    ok, removedQuantity = YayaQueueAPI.RemoveItem(action.enchantItemID, 1)
                    if not ok then
                        removedQuantity = 0
                    end
                end
                if removedQuantity > 0 then
                    print(("YWT: Retire 1x enchantement %s de YayaQueue (outil enchante)"):format(
                        action.enchantItemID
                    ))
                end
                DebugLog(
                    "Tool enchant applied skillLine=%s source=%s bag=%s slot=%s item=%s removed=%s",
                    tostring(action.skillLineID),
                    tostring(action.source or "equipment"),
                    tostring(action.toolBag),
                    tostring(action.toolSlot),
                    tostring(action.enchantItemID),
                    tostring(removedQuantity)
                )
                pendingApplications[key] = nil
            end
        end
    end
end

trackerUI.GetProfessionToolEnchantStatus = function(row)
    local state = trackerUI.FindToolEnchantState()
    return state.bySkillLineID[row and row.skillLineID] or { missingTools = {} }
end

-- Les sacs portes par le personnage, et EUX SEULS. Les conteneurs de banque
-- repondent a `GetContainerNumSlots` des que la banque est ouverte -- c'est-a-
-- dire exactement quand on transfere -- donc une borne calculee sur
-- `NUM_TOTAL_EQUIPPED_BAG_SLOTS` laissait le balayage entrer dans la Warbank et
-- y designer une destination. Le sac de reactifs est a part : il n'accepte que
-- des reactifs, et un outil depose la est refuse sans erreur Lua.
trackerUI.GetPlayerBagIDs = function()
    local bagIndex = Enum and Enum.BagIndex or EMPTY_TABLE
    local backpack = tonumber(bagIndex.Backpack) or 0
    local lastBag = tonumber(NUM_BAG_SLOTS) or 4
    local bagIDs = { backpack }
    for bagID = backpack + 1, backpack + lastBag do
        bagIDs[#bagIDs + 1] = bagID
    end
    return bagIDs, tonumber(bagIndex.ReagentBag)
end

-- Emplacement de sac capable d'accueillir `quantity` exemplaires : une pile
-- entamee du meme objet d'abord, un emplacement vide sinon.
--
-- La taille de pile inconnue vaut UN, jamais 200 : un outil de metier ne
-- s'empile pas, et le prendre pour empilable faisait designer comme
-- destination l'emplacement d'un exemplaire deja possede. Le jeu executait
-- alors un echange a deux sens -- l'objet du sac partait vers la Warbank -- et
-- le refusait s'il etait soulbound, ce qui est le cas de tout outil deja
-- equipe une fois.
trackerUI.FindBagDestination = function(itemID, quantity)
    if not C_Container or type(C_Container.GetContainerItemInfo) ~= "function" then
        return nil, nil
    end

    local maxStack = 1
    if type(GetItemInfo) == "function" then
        local stackSize = select(8, SafeCall(GetItemInfo, itemID))
        maxStack = math.max(1, tonumber(stackSize) or 1)
    end
    local isReagent = false
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        -- classID 7 = Reagent, le seul contenu accepte par le sac de reactifs.
        isReagent = select(6, SafeCall(C_Item.GetItemInfoInstant, itemID)) == 7
    end

    local bagIDs, reagentBagID = trackerUI.GetPlayerBagIDs()
    if isReagent and reagentBagID then
        bagIDs[#bagIDs + 1] = reagentBagID
    end

    local emptyBag, emptySlot
    for _, bagID in ipairs(bagIDs) do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local info = SafeCall(C_Container.GetContainerItemInfo, bagID, slotIndex)
            if not info then
                if not emptyBag then
                    emptyBag, emptySlot = bagID, slotIndex
                end
            elseif maxStack > 1
                and tonumber(info.itemID) == itemID
                and (tonumber(info.stackCount) or 0) + quantity <= maxStack then
                return bagID, slotIndex
            end
        end
    end
    return emptyBag, emptySlot
end

-- Le geste unique : sortir de la Warbank exactement `request.quantity`
-- exemplaires de l'emplacement designe, et les deposer dans les sacs.
--
-- Un transfert par appel, jamais plus. Le compteur du bouton annonce le reste
-- a faire, pas ce que le clic va faire, et son infobulle doit le dire.
--
-- Les deux implementations qu'elle remplace divergeaient sur cinq points ; on
-- garde a chaque fois la version la plus sure.
trackerUI.PullFromWarbank = function(request, button)
    if type(request) ~= "table"
        or not request.itemID
        or not request.bagID
        or not request.slotIndex then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    -- Le verrou est verifie ici, pas seulement porte par l'etat du widget :
    -- un clic peut arriver autrement que par la souris, et le plan lu deux
    -- fois avant BAG_UPDATE_DELAYED sortirait deux fois le meme objet.
    if button and button.itemActionLocked then
        return false
    end
    if not C_Container
        or type(C_Container.GetContainerItemInfo) ~= "function"
        or type(C_Container.PickupContainerItem) ~= "function" then
        print("YWT: transfert Warbank indisponible")
        return false
    end

    -- Un curseur deja charge transforme le transfert en echange silencieux :
    -- le premier Pickup deposerait ce qu'il porte a la place de l'objet vise.
    if type(GetCursorInfo) == "function" and select(1, GetCursorInfo()) then
        print("YWT: libère d'abord le curseur")
        return false
    end

    -- La source est revalidee : entre le scan et le clic, l'emplacement a pu
    -- changer d'objet, se vider ou se verrouiller.
    local sourceInfo = SafeCall(C_Container.GetContainerItemInfo, request.bagID, request.slotIndex)
    local stackCount = tonumber(sourceInfo and sourceInfo.stackCount) or 0
    if not sourceInfo or tonumber(sourceInfo.itemID) ~= request.itemID or stackCount <= 0 then
        trackerUI.InvalidateWarbankCaches()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0, false)
        return false
    end
    if sourceInfo.isLocked then
        return false
    end

    -- La destination est relue juste avant le split, pas au moment du plan :
    -- un sac a pu se remplir depuis, et l'objet resterait sur le curseur.
    local amount = math.max(math.min(tonumber(request.quantity) or 1, stackCount), 1)
    local destinationBag, destinationSlot = trackerUI.FindBagDestination(request.itemID, amount)
    if not destinationBag or not destinationSlot then
        print("YWT: aucun emplacement disponible dans les sacs")
        return false
    end

    local ok
    if amount < stackCount then
        if type(C_Container.SplitContainerItem) ~= "function" then
            print("YWT: le split de stack n'est pas disponible")
            return false
        end
        ok = pcall(C_Container.SplitContainerItem, request.bagID, request.slotIndex, amount)
    else
        ok = pcall(C_Container.PickupContainerItem, request.bagID, request.slotIndex)
    end
    if not ok then
        print("YWT: transfert Warbank indisponible")
        return false
    end

    -- Releve avant le mouvement : c'est la reference qui dira plus tard si le
    -- client a repercute le retrait.
    local liveBefore = trackerUI.warbank.GetLiveCount(request.itemID)

    DebugLog("Warbank pull item=%d x%d from=%s:%s to=%s:%s live=%s",
        request.itemID, amount,
        tostring(request.bagID), tostring(request.slotIndex),
        tostring(destinationBag), tostring(destinationSlot),
        tostring(liveBefore))

    local placed = pcall(C_Container.PickupContainerItem, destinationBag, destinationSlot)
    -- `pcall` ne dit rien du verdict du jeu : un depot refuse n'est pas une
    -- erreur Lua, seulement un message a l'ecran. Le curseur, lui, ne ment
    -- pas -- s'il porte encore quelque chose, le transfert a echoue.
    local cursorStillLoaded = type(GetCursorInfo) == "function"
        and select(1, GetCursorInfo()) ~= nil
    if not placed or cursorStillLoaded then
        -- Split puis Pickup ne forment pas un geste atomique : entre les deux,
        -- l'objet est sur le curseur. L'y laisser bloquerait tous les clics
        -- suivants, y compris ceux du joueur.
        if type(ClearCursor) == "function" then
            pcall(ClearCursor)
        end
        print("YWT: dépôt refusé par le jeu, curseur libéré")
        DebugLog("Warbank pull refused item=%d to=%s:%s",
            request.itemID, tostring(destinationBag), tostring(destinationSlot))
        trackerUI.InvalidateWarbankCaches()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0, false)
        return false
    end

    -- Le retrait est note comme en transit AVANT tout rafraichissement : le
    -- verrou du bouton ne tient que jusqu'a BAG_UPDATE_DELAYED, alors que les
    -- onglets de la banque de compte, eux, se mettent a jour plus tard. Sans
    -- cette note, le premier scan intercalaire revoit l'objet en banque et le
    -- repropose aussitot.
    trackerUI.warbank.NotePull(request.itemID, amount, liveBefore)

    -- Verrou anti-multiclic : deux clics avant BAG_UPDATE_DELAYED relisaient le
    -- meme plan et sortaient deux fois l'objet.
    trackerUI.LockItemActionButton(button)
    trackerUI.InvalidateWarbankCaches()
    trackerUI.InvalidateToolEnchantCache()
    trackerUI.RequestItemActionRefresh()
    return true
end

-- Un candidat n'est propose que si le client confirme son emplacement
-- d'equipement et sa ligne de metier. Retourne nil quand la donnee de l'objet
-- n'est pas encore chargee : indecis n'est pas invalide.
trackerUI.IsProfessionGearCandidateValid = function(itemID, skillLineID, wantTool)
    local equipLoc
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        equipLoc = select(4, SafeCall(C_Item.GetItemInfoInstant, itemID))
    end
    if not equipLoc and type(GetItemInfoInstant) == "function" then
        equipLoc = select(4, SafeCall(GetItemInfoInstant, itemID))
    end
    if not equipLoc then
        trackerUI.RequestToolItemData(itemID)
        return nil
    end
    if equipLoc ~= (wantTool and "INVTYPE_PROFESSION_TOOL" or "INVTYPE_PROFESSION_GEAR") then
        return false
    end

    if not C_TradeSkillUI or type(C_TradeSkillUI.GetSkillLineForGear) ~= "function" then
        return nil
    end
    local gearSkillLineID = tonumber(SafeCall(C_TradeSkillUI.GetSkillLineForGear, itemID))
    if not gearSkillLineID then
        return nil
    end
    if gearSkillLineID == skillLineID
        or runtimeState.baseProfessionToMidnightSkillLineID[gearSkillLineID] == skillLineID then
        return true
    end
    return false
end

-- Variante d'achat d'un objet d'equipement de metier : le rang minimal, et pour
-- un outil la statistique exigee. YayaQueue s'en sert pour ecarter les annonces
-- non conformes au lieu de prendre la moins chere. La statistique voyage par sa
-- cle interne, jamais par son libelle : YayaQueue la relit au tooltip de chaque
-- annonce, dans la langue du client, comme le tracker le fait des outils
-- possedes. Le bonusId de statistique n'existe que sur un exemplaire craft avec
-- une Missive, il ne peut donc pas servir de critere.
trackerUI.BuildProfessionGearVariant = function(statKey)
    local variant = { minItemLevel = trackerUI.GetProfessionGearMinimumItemLevel() }
    if not statKey then
        return variant
    end

    local statInfo = runtimeState.professionToolEnchantments.byStat[statKey]
    if not statInfo then
        return nil
    end
    variant.statKey = statKey
    variant.statLabel = statInfo.label
    return variant
end

-- Plan d'approvisionnement : tout ce qui manque a l'equipement de metier, et
-- pour chaque manque, ce que la Warbank peut fournir avant l'hotel des ventes.
--
-- Une seule arithmetique, appliquee a TOUT besoin -- outil, accessoire,
-- enchantement, traite :
--
--   pull = min(besoin - possede, exemplaires conformes en Warbank)
--   buy  = besoin - possede - pull - deja en file, mais SEULEMENT si la
--          Warbank a rendu un verdict net ; sinon l'entree est bloquee.
--
-- Bloquer plutot que decider est le point important : un exemplaire dont on ne
-- sait pas s'il convient ne doit ni etre propose a la recuperation, ni etre
-- rachete. C'est l'indecis de trackerUI.warbank.Resolve, propage jusqu'ici.
--
-- Le stock possede n'est pas deduit d'un besoin a variante : c'est la variante
-- qui dit ce qui manque, et deux exemplaires du meme itemID peuvent differer
-- par leur rang comme par leur statistique.
trackerUI.BuildProfessionSupplyPlan = function(trackedRows)
    trackedRows = trackedRows or GetTrackedMidnightProfessions()
    local state = trackerUI.FindToolEnchantState(trackedRows)
    local plan = {
        entries = {},
        pullQuantity = 0,
        buyQuantity = 0,
        gearQuantity = 0,
        enchantQuantity = 0,
        pending = false,
        blocked = {},
        invalidCandidates = {},
        unknownStats = {},
    }

    local function ItemName(itemID)
        return SafeCall(GetItemInfo, itemID) or ("item:" .. tostring(itemID))
    end

    local function Add(itemID, need, variant, options)
        options = options or EMPTY_TABLE
        if not itemID or need <= 0 then
            return false
        end
        if options.wantTool ~= nil then
            local valid = trackerUI.IsProfessionGearCandidateValid(
                itemID, options.skillLineID, options.wantTool)
            if valid == nil then
                plan.pending = true
                return false
            end
            if valid == false then
                plan.invalidCandidates[#plan.invalidCandidates + 1] = itemID
                return false
            end
        end

        local owned = variant and 0 or trackerUI.GetOwnedItemCount(itemID)
        local missing = math.max(need - owned, 0)
        if missing <= 0 then
            return false
        end

        -- La quantite deja en file se compte PAR VARIANTE : l'outil
        -- Resourcefulness et l'outil Multicrafting d'un metier partagent leur
        -- itemID, et un compte global ferait passer le second pour demande.
        local queued = 0
        if YayaQueueAPI and type(YayaQueueAPI.GetDirectItemQuantity) == "function" then
            queued = tonumber(YayaQueueAPI.GetDirectItemQuantity(itemID, variant)) or 0
        end

        local warbank = trackerUI.warbank.Resolve(itemID, variant)
        local pull = math.max(math.min(missing, warbank.matched), 0)
        local buy = 0
        if options.pullOnly then
            buy = 0
        elseif warbank.known and warbank.undecided == 0 then
            buy = math.max(missing - pull - queued, 0)
        else
            plan.blocked[#plan.blocked + 1] = {
                itemID = itemID,
                itemName = ItemName(itemID),
                reason = (warbank.inFlight or 0) > 0
                        and "transfert Warbank en cours"
                    or warbank.undecided > 0
                        and "variante indeterminee en Warbank"
                    or "stock Warbank inconnu",
            }
        end

        if pull <= 0 and buy <= 0 then
            return false
        end

        plan.entries[#plan.entries + 1] = {
            itemID = itemID,
            itemName = ItemName(itemID),
            variant = variant,
            need = missing,
            owned = owned,
            queued = queued,
            warbank = warbank,
            pull = pull,
            buy = buy,
            reason = options.reason,
            pullOnly = options.pullOnly == true,
            skillLineID = options.skillLineID,
            professionLabel = options.professionLabel,
        }
        plan.pullQuantity = plan.pullQuantity + pull
        plan.buyQuantity = plan.buyQuantity + buy
        if variant then
            plan.gearQuantity = plan.gearQuantity + buy
        else
            plan.enchantQuantity = plan.enchantQuantity + buy
        end
        return true
    end

    -- Les enchantements se cumulent AVANT d'etre proposes. Deux besoins du
    -- meme parchemin -- un outil possede a re-enchanter, un outil encore a
    -- acheter -- se partagent le meme stock : les traiter separement ferait
    -- deduire deux fois le meme exemplaire en sac, et n'en acheterait aucun.
    local enchantNeeds = {}
    local enchantReason = {}

    for itemID, quantity in pairs(state.requiredByItemID or EMPTY_TABLE) do
        enchantNeeds[itemID] = (enchantNeeds[itemID] or 0) + quantity
        enchantReason[itemID] = "enchantement d'un outil possede"
    end

    for _, row in ipairs(trackedRows) do
        local profession = state.bySkillLineID[row.skillLineID]
        local gear = profession and profession.gear or nil
        local candidates = runtimeState.professionGear.rareCandidatesBySkillLineID[row.skillLineID]
        if gear and candidates then
            local professionLabel = profession.label or tostring(row.skillLineID)
            -- Les outils suivent `toolNeeds`, seul juge de ce qui manque : un
            -- outil conforme mais sans la bonne statistique laisse le besoin
            -- ouvert, alors que l'emplacement, lui, est satisfait.
            for _, need in ipairs(profession.toolNeeds or EMPTY_TABLE) do
                local variant = trackerUI.BuildProfessionGearVariant(need.statKey)
                if not variant then
                    plan.unknownStats[#plan.unknownStats + 1] = need.statKey or "?"
                elseif candidates.tool then
                    Add(candidates.tool, 1, variant, {
                        wantTool = true,
                        skillLineID = row.skillLineID,
                        professionLabel = professionLabel,
                        reason = need.reason,
                    })
                    -- L'enchantement part avec l'outil : un outil obtenu nu
                    -- resterait a enchanter, et son rappel n'apparaitrait qu'au
                    -- scan suivant. Un outil de recolte, demande sans
                    -- statistique, n'en reclame aucun : la stat de l'exemplaire
                    -- obtenu n'est pas connue d'avance.
                    local needStatInfo = need.statKey
                        and runtimeState.professionToolEnchantments.byStat[need.statKey]
                        or nil
                    if needStatInfo then
                        enchantNeeds[needStatInfo.itemID] =
                            (enchantNeeds[needStatInfo.itemID] or 0) + 1
                        enchantReason[needStatInfo.itemID] =
                            enchantReason[needStatInfo.itemID]
                            or "enchantement de l'outil achete"
                    end
                end
            end

            if gear.pending then
                plan.pending = true
            else
                local missingGearSlots = 0
                for _, slotState in ipairs(gear.slots) do
                    if slotState.compliant == false and not slotState.isToolSlot then
                        missingGearSlots = missingGearSlots + 1
                    end
                end
                -- Les deux emplacements d'accessoire acceptent n'importe quel
                -- accessoire du metier : proposer autant de candidats distincts
                -- qu'il y a d'emplacements a completer. Leurs statistiques sont
                -- fixes, seul le rang est exige.
                local added = 0
                for _, itemID in ipairs(candidates.gear or EMPTY_TABLE) do
                    if added >= missingGearSlots then
                        break
                    end
                    if Add(itemID, 1, trackerUI.BuildProfessionGearVariant(nil), {
                        wantTool = false,
                        skillLineID = row.skillLineID,
                        professionLabel = professionLabel,
                        reason = "accessoire",
                    }) then
                        added = added + 1
                    end
                end
            end
        end
    end

    for itemID, quantity in pairs(enchantNeeds) do
        Add(itemID, quantity, nil, { reason = enchantReason[itemID] })
    end

    -- Les traites ne se recuperent que depuis la Warbank : aucun candidat
    -- d'achat n'est tenu pour eux, et un traite absent de la banque n'est pas
    -- commande a l'hotel des ventes.
    for _, treatise in ipairs(trackerUI.GetMissingMidnightTreatises(trackedRows)) do
        Add(treatise.itemID, 1, nil, {
            pullOnly = true,
            skillLineID = treatise.skillLineID,
            professionLabel = treatise.label,
            reason = "traite " .. tostring(treatise.label or ""),
        })
    end

    -- Le plan est journalise : c'est la seule facon de savoir en jeu pourquoi
    -- un objet est propose, ou ne l'est pas, sans deviner. La signature evite
    -- de reecrire la meme ligne a chaque rafraichissement.
    local planParts = {}
    for _, entry in ipairs(plan.entries) do
        planParts[#planParts + 1] = ("%dx%d/%s%s"):format(
            entry.buy > 0 and entry.buy or entry.pull,
            entry.itemID,
            entry.variant
                and (tostring(entry.variant.statKey or "rank")
                    .. ":" .. tostring(entry.variant.minItemLevel or 0))
                or (entry.pullOnly and "traite" or "enchant"),
            entry.pull > 0 and ("+wb" .. entry.pull) or "")
    end
    table.sort(planParts)
    local planSignature = ("gear=%d ench=%d pull=%d blocked=%d pending=%s invalid=%d unknownStats=%d :: %s"):format(
        plan.gearQuantity,
        plan.enchantQuantity,
        plan.pullQuantity,
        #plan.blocked,
        tostring(plan.pending),
        #plan.invalidCandidates,
        #plan.unknownStats,
        #planParts > 0 and table.concat(planParts, ",") or "none")
    if planSignature ~= debugSignatures.professionSupplyPlan then
        debugSignatures.professionSupplyPlan = planSignature
        DebugLog("Profession supply plan = %s", planSignature)
    end

    return plan
end

-- Le prochain objet que la Warbank peut rendre, avec son emplacement. Un seul
-- par appel : le bouton sort les objets un a un.
trackerUI.FindNextSupplyPull = function(plan)
    for _, entry in ipairs(plan and plan.entries or EMPTY_TABLE) do
        if entry.pull > 0 then
            for _, slot in ipairs(entry.warbank and entry.warbank.slots or EMPTY_TABLE) do
                if slot.bagID and slot.slotIndex and (slot.stackCount or 0) > 0 then
                    return {
                        itemID = entry.itemID,
                        bagID = slot.bagID,
                        slotIndex = slot.slotIndex,
                        quantity = math.min(entry.pull, slot.stackCount or 1),
                        label = entry.itemName,
                    }
                end
            end
        end
    end
    return nil
end

trackerUI.QueueProfessionSupplyPurchases = function(plan)
    if not YayaQueueAPI or type(YayaQueueAPI.AddItem) ~= "function" then
        print("YWT: YayaQueue n'est pas disponible")
        return false
    end

    plan = plan or trackerUI.BuildProfessionSupplyPlan()
    local queuedQuantity = 0
    for _, entry in ipairs(plan.entries) do
        if entry.buy > 0 then
            YayaQueueAPI.AddItem(entry.itemID, entry.buy, entry.itemName, entry.variant)
            queuedQuantity = queuedQuantity + entry.buy
        end
    end
    if queuedQuantity > 0 then
        if type(YayaQueueAPI.Refresh) == "function" then
            YayaQueueAPI.Refresh()
        end
        print(("YWT: %d equipement(s) et %d enchantement(s) ajoute(s) a YayaQueue"):format(
            plan.gearQuantity, plan.enchantQuantity))
    end
    trackerUI.InvalidateToolEnchantCache()
    ScheduleTrackerRefresh(0.05, false)
    return queuedQuantity > 0
end

-- Un seul bouton, et son libelle annonce ce que le PROCHAIN clic va faire :
-- sortir un objet de la Warbank tant qu'il y en a et qu'elle est ouverte,
-- mettre en file l'achat du reste sinon. C'est « si present en Warbank, sinon
-- l'hotel des ventes » ramene a un seul geste, que l'autoclicker peut marteler
-- jusqu'a extinction.
trackerUI.UpdateProfessionSupplyButton = function(plan)
    local button = trackerFrame and trackerFrame.professionSupplyButton
    if not button then
        return false
    end
    if not plan or (#plan.entries == 0 and #plan.blocked == 0) then
        button.supplyPlan = nil
        button.supplyPull = nil
        button:Hide()
        return false
    end

    -- La recuperation n'est proposee que banque ouverte : les emplacements de
    -- l'instantane ne sont adressables que la. Le plan, lui, sait deja que
    -- l'objet y dort, et c'est ce qui empeche de le racheter entre-temps.
    local pullRequest = trackerUI.IsAccountBankOpen()
        and trackerUI.FindNextSupplyPull(plan)
        or nil
    local queueAvailable = YayaQueueAPI and type(YayaQueueAPI.AddItem) == "function"
    local enabled

    if pullRequest then
        button:SetText(("Récupérer WB x%d"):format(plan.pullQuantity))
        enabled = true
    elseif plan.buyQuantity > 0 then
        -- Les enchantements comptent a part : sans cette distinction, un `x4`
        -- sur trois emplacements fautifs passait pour une erreur de comptage.
        if plan.gearQuantity <= 0 then
            button:SetText(("Acheter ench YQ x%d"):format(plan.enchantQuantity))
        elseif plan.enchantQuantity > 0 then
            button:SetText(("Acheter stuff YQ x%d +%de"):format(
                plan.gearQuantity, plan.enchantQuantity))
        else
            button:SetText(("Acheter stuff YQ x%d"):format(plan.gearQuantity))
        end
        enabled = queueAvailable == true
    elseif plan.pullQuantity > 0 then
        button:SetText(("Récupérer WB x%d"):format(plan.pullQuantity))
        enabled = false
    else
        button:SetText(("Approvisionner x%d"):format(#plan.blocked))
        enabled = false
    end

    button.supplyPlan = plan
    button.supplyPull = pullRequest
    if not button.itemActionLocked then
        button:SetEnabled(enabled == true)
    end
    button:Show()
    return true
end

trackerUI.UpdateToolEnchantApplyButtons = function(state)
    local buttons = trackerFrame and trackerFrame.toolEnchantApplyButtons or EMPTY_TABLE
    local actions = state and state.applyEnchants or EMPTY_TABLE
    local visibleCount = 0

    local function HideButton(button)
        button.actionState = nil
        button.itemID = nil
        button.itemLink = nil
        button.toolLink = nil
        if not (InCombatLockdown and InCombatLockdown()) then
            button:SetAttribute("type", nil)
            button:SetAttribute("item", nil)
            button:SetAttribute("target-bag", nil)
            button:SetAttribute("target-slot", nil)
        end
        button:Hide()
    end

    for _, action in ipairs(actions) do
        local hasItem = action
            and action.enchantItemID
            and trackerUI.GetOwnedItemCount(action.enchantItemID) > 0
        if hasItem and action.toolSlot then
            local button = buttons[visibleCount + 1]
            if not button then
                break
            end
            visibleCount = visibleCount + 1
            if not button.itemActionLocked then
                button:SetEnabled(true)
            end
            button:SetText(("Appliquer %s%s"):format(
                action.statLabel or "l'enchantement",
                action.source == "bag" and " (sac)" or ""
            ))
            button.actionState = action
            button.itemID = action.enchantItemID
            button.itemLink = action.enchantLink
            button.toolLink = action.toolLink
            if not (InCombatLockdown and InCombatLockdown()) then
                button:SetAttribute("type", "item")
                button:SetAttribute("item", "item:" .. tostring(action.enchantItemID))
                -- target-bag nil pour l'outil equipe : target-slot est alors
                -- lu comme un slot d'inventaire, sinon comme un slot de
                -- conteneur.
                button:SetAttribute("target-bag", action.toolBag)
                button:SetAttribute("target-slot", action.toolSlot)
            end
            button:Show()
        end
    end

    for index = visibleCount + 1, #buttons do
        HideButton(buttons[index])
    end

    return visibleCount
end

trackerUI.HasEnchantingProfession = function(trackedRows)
    trackedRows = trackedRows or GetTrackedMidnightProfessions()
    for _, row in ipairs(trackedRows) do
        if row.skillLineID == 2909 and (row.skillLevel or 0) > 0 then
            return true
        end
    end
    return false
end

trackerUI.FindAbundancePurchaseMerchantIndices = function()
    local merchantCount = 0
    if type(GetMerchantNumItems) == "function" then
        merchantCount = tonumber(SafeCall(GetMerchantNumItems)) or 0
    elseif C_MerchantFrame and type(C_MerchantFrame.GetNumItems) == "function" then
        merchantCount = tonumber(SafeCall(C_MerchantFrame.GetNumItems)) or 0
    end

    local itemIndices = {}
    for index = 1, merchantCount do
        local itemInfo = C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function"
            and SafeCall(C_MerchantFrame.GetItemInfo, index)
            or nil
        local itemID = type(GetMerchantItemID) == "function"
            and SafeCall(GetMerchantItemID, index)
            or nil
        if not itemID and type(itemInfo) == "table" then
            itemID = itemInfo.itemID
        end
        if not itemID and type(GetMerchantItemLink) == "function"
            and C_Item and type(C_Item.GetItemInfoInstant) == "function" then
            local itemLink = SafeCall(GetMerchantItemLink, index)
            itemID = itemLink and SafeCall(C_Item.GetItemInfoInstant, itemLink) or nil
        end
        if itemID == runtimeState.abundanceEnchantingBagItemID
            or itemID == runtimeState.abundanceFusedVitalityItemID then
            itemIndices[itemID] = index
        end
    end
    return itemIndices
end

trackerUI.FindAbundancePurchaseTarget = function(itemIndices, trackedRows)
    local accountDB = GetAccountDB()
    local skippedItems = runtimeState.abundancePurchaseSkippedItems or EMPTY_TABLE
    local selectedTarget
    local selectedPriority
    for _, target in ipairs(runtimeState.abundancePurchaseTargets or EMPTY_TABLE) do
        local targetPriority = target.priority or 999
        if accountDB[target.optionKey] == true
            and not skippedItems[target.itemID]
            and itemIndices[target.itemID]
            and (not target.requiresEnchanting or trackerUI.HasEnchantingProfession(trackedRows))
            and (not selectedTarget or targetPriority < selectedPriority)
        then
            selectedTarget = target
            selectedPriority = targetPriority
        end
    end
    return selectedTarget
end

trackerUI.ScheduleAbundanceEnchantingBagPurchase = function(delaySeconds)
    local accountDB = GetAccountDB()
    if (accountDB.autoBuyAbundanceEnchantingBags ~= true
            and accountDB.autoBuyAbundanceFusedVitality ~= true)
        or runtimeState.abundanceEnchantingPurchaseAttempted
        or runtimeState.abundanceEnchantingPurchaseScheduled
        or not C_Timer
        or type(C_Timer.After) ~= "function"
    then
        return
    end

    runtimeState.abundanceEnchantingPurchaseScheduled = true
    local generation = runtimeState.abundanceEnchantingPurchaseGeneration
    C_Timer.After(delaySeconds or runtimeState.abundanceEnchantingPurchaseDelaySeconds, function()
        runtimeState.abundanceEnchantingPurchaseScheduled = false
        if generation ~= runtimeState.abundanceEnchantingPurchaseGeneration
            or runtimeState.abundanceEnchantingPurchaseAttempted
            or not MerchantFrame
            or type(MerchantFrame.IsShown) ~= "function"
            or not MerchantFrame:IsShown()
        then
            return
        end
        trackerUI.TryBuyAbundanceEnchantingBags()
    end)
end

trackerUI.TryBuyAbundanceEnchantingBags = function()
    if runtimeState.abundanceEnchantingPurchaseAttempted
        or not MerchantFrame
        or type(MerchantFrame.IsShown) ~= "function"
        or not MerchantFrame:IsShown()
    then
        return
    end

    local pending = runtimeState.abundanceEnchantingPurchasePending
    if pending then
        local currentOwned = trackerUI.GetOwnedItemCount(pending.itemID)
        local currentCurrency = GetCurrencyQuantity(MIDNIGHT_UNALLOYED_ABUNDANCE_CURRENCY_ID)
        local progressed = currentOwned > (pending.ownedBefore or 0)
            or currentCurrency < (pending.currencyBefore or currentCurrency)
        runtimeState.abundanceEnchantingPurchasePending = nil
        if progressed then
            runtimeState.abundanceEnchantingPurchaseStalledCount = 0
        else
            runtimeState.abundanceEnchantingPurchaseStalledCount = (runtimeState.abundanceEnchantingPurchaseStalledCount or 0) + 1
            if runtimeState.abundanceEnchantingPurchaseStalledCount >= 3 then
                runtimeState.abundancePurchaseSkippedItems[pending.itemID] = true
                runtimeState.abundanceEnchantingPurchaseStalledCount = 0
                DebugLog("Abundance purchase target stopped: no progress (item=%s)", tostring(pending.itemID))
            else
                trackerUI.ScheduleAbundanceEnchantingBagPurchase()
                return
            end
        end
    end

    local merchantIndices = trackerUI.FindAbundancePurchaseMerchantIndices()
    local target = trackerUI.FindAbundancePurchaseTarget(
        merchantIndices,
        GetTrackedMidnightProfessions()
    )
    if not target then
        local hasMerchantTarget = next(merchantIndices) ~= nil
        runtimeState.abundanceEnchantingPurchaseRetryCount = (runtimeState.abundanceEnchantingPurchaseRetryCount or 0) + 1
        if not hasMerchantTarget
            and runtimeState.abundanceEnchantingPurchaseRetryCount < (runtimeState.abundanceEnchantingPurchaseRetryLimit or 20)
        then
            trackerUI.ScheduleAbundanceEnchantingBagPurchase()
        else
            runtimeState.abundanceEnchantingPurchaseAttempted = true
            DebugLog("Abundance purchase stopped: no eligible target")
        end
        return
    end

    local itemInfo = C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function"
        and SafeCall(C_MerchantFrame.GetItemInfo, merchantIndices[target.itemID])
        or nil
    if type(itemInfo) == "table" then
        if itemInfo.numAvailable and itemInfo.numAvailable == 0 then
            runtimeState.abundancePurchaseSkippedItems[target.itemID] = true
            trackerUI.ScheduleAbundanceEnchantingBagPurchase(0)
            return
        end
        if itemInfo.isPurchasable == false or itemInfo.isUsable == false then
            runtimeState.abundancePurchaseSkippedItems[target.itemID] = true
            trackerUI.ScheduleAbundanceEnchantingBagPurchase(0)
            return
        end
    end

    if type(CanAffordMerchantItem) == "function"
        and SafeCall(CanAffordMerchantItem, merchantIndices[target.itemID]) == false
    then
        runtimeState.abundancePurchaseSkippedItems[target.itemID] = true
        trackerUI.ScheduleAbundanceEnchantingBagPurchase(0)
        return
    end

    local ownedBefore = trackerUI.GetOwnedItemCount(target.itemID)
    local currencyBefore = GetCurrencyQuantity(MIDNIGHT_UNALLOYED_ABUNDANCE_CURRENCY_ID)
    local ok, err
    if type(BuyMerchantItem) ~= "function" then
        ok, err = false, "BuyMerchantItem unavailable"
    else
        ok, err = pcall(BuyMerchantItem, merchantIndices[target.itemID], 1)
    end
    if not ok then
        runtimeState.abundanceEnchantingPurchaseAttempted = true
        DebugLog("Abundance enchanting bag purchase failed: %s", tostring(err))
        return
    end

    runtimeState.abundanceEnchantingPurchasePending = {
        itemID = target.itemID,
        ownedBefore = ownedBefore,
        currencyBefore = currencyBefore,
    }
    runtimeState.abundanceEnchantingPurchaseRetryCount = 0
    trackerUI.ScheduleAbundanceEnchantingBagPurchase()
end

trackerUI.FindActiveMidnightEnchantingWeekly = function(trackedRows)
    trackedRows = trackedRows or GetTrackedMidnightProfessions()
    local hasEnchanting = false
    for _, row in ipairs(trackedRows) do
        if row.skillLineID == 2909 then
            hasEnchanting = true
            break
        end
    end
    if not hasEnchanting then
        return
    end

    local questLog = GetQuestLogSnapshot()
    local activeByQuestID = BuildQuestLogLookups(questLog)
    for questID, reagentInfo in pairs(runtimeState.midnightEnchantingWeeklyReagents or EMPTY_TABLE) do
        if activeByQuestID[questID] and not IsQuestDone(questID) then
            local owned = trackerUI.GetOwnedItemCount(reagentInfo.itemID)
            return {
                questID = questID,
                questTitle = GetQuestTitle(questID) or activeByQuestID[questID].title,
                itemID = reagentInfo.itemID,
                itemName = reagentInfo.itemName,
                needed = reagentInfo.quantity,
                owned = owned,
                missing = math.max(0, reagentInfo.quantity - owned),
            }
        end
    end
end

trackerUI.EnsureEnchantingWeeklyQueueItem = function(trackedRows)
    if GetAccountDB().trackProfessionWeeklies == false
        or not (YayaQueueAPI and type(YayaQueueAPI.AddItem) == "function") then
        return false
    end

    local weekly = trackerUI.FindActiveMidnightEnchantingWeekly(trackedRows)
    if not (weekly and weekly.missing > 0) then
        return false
    end

    local characterDB = GetCharacterDB()
    characterDB.autoQueuedEnchantingWeeklies = characterDB.autoQueuedEnchantingWeeklies or {}
    local queuedByQuest = characterDB.autoQueuedEnchantingWeeklies
    if queuedByQuest[weekly.questID] ~= nil then
        return false
    end

    local existingQuantity
    if type(YayaQueueAPI.GetDirectItemQuantity) == "function" then
        existingQuantity = YayaQueueAPI.GetDirectItemQuantity(weekly.itemID)
    end
    if existingQuantity and existingQuantity >= weekly.needed then
        queuedByQuest[weekly.questID] = 0
        return false
    end

    local ok = YayaQueueAPI.AddItem(weekly.itemID, weekly.needed, weekly.itemName)
    if ok then
        queuedByQuest[weekly.questID] = weekly.needed
        print(("YWT: Ajoute automatiquement +%dx %s a YayaQueue (%d manquants pour la weekly)"):format(
            weekly.needed,
            weekly.itemName or ("item:" .. tostring(weekly.itemID)),
            weekly.missing
        ))
    end
    return false
end

trackerUI.ClearMidnightTreasureWaypoints = function()
    if not (TomTom and type(TomTom.RemoveWaypoint) == "function") then
        wipe(treasureWaypointUIDs)
        treasureWaypointSignature = nil
        return
    end

    for _, uid in ipairs(treasureWaypointUIDs) do
        TomTom:RemoveWaypoint(uid)
    end

    wipe(treasureWaypointUIDs)
    treasureWaypointSignature = nil
end

trackerUI.ClearMidnightKnowledgeBookWaypoints = function()
    if TomTom and type(TomTom.RemoveWaypoint) == "function" then
        for _, uid in ipairs(knowledgeBookWaypointUIDs) do
            TomTom:RemoveWaypoint(uid)
        end
    end
    wipe(knowledgeBookWaypointUIDs)
    knowledgeBookWaypointSignature = nil
end

trackerUI.GetRecipeKnownFromTooltip = function(itemID)
    if not itemID or not C_TooltipInfo then
        return nil
    end

    local tooltipData
    if type(C_TooltipInfo.GetItemByID) == "function" then
        tooltipData = SafeCall(C_TooltipInfo.GetItemByID, itemID)
    elseif type(C_TooltipInfo.GetHyperlink) == "function" then
        tooltipData = SafeCall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
    end

    if type(tooltipData) ~= "table" or type(tooltipData.lines) ~= "table" or #tooltipData.lines == 0 then
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
            local now = GetTime and GetTime() or 0
            local retryAt = runtimeState.itemDataLoadRetryAt[itemID] or 0
            if not runtimeState.itemDataLoadPending[itemID] and now >= retryAt then
                runtimeState.itemDataLoadPending[itemID] = true
                runtimeState.itemDataLoadRetryAt[itemID] = now + runtimeState.itemDataLoadCooldownSeconds
                DebugLog("Request item data item=%s", tostring(itemID))
                SafeCall(C_Item.RequestLoadItemDataByID, itemID)
            end
        end
        return nil
    end

    local lineTypes = Enum and Enum.TooltipDataLineType
    local requirementTypes = Enum and Enum.TooltipDataUsageRequirementType
    local usageRequirement = lineTypes and lineTypes.UsageRequirement

    for _, line in ipairs(tooltipData.lines) do
        if type(line) == "table"
            and usageRequirement
            and requirementTypes
            and line.type == usageRequirement
            and line.usable ~= true
            and line.requirementType == requirementTypes.NotAlreadyKnown then
            -- The NotAlreadyKnown requirement is failing: this recipe is known.
            return true
        end

        local text = type(line) == "table" and line.leftText or nil
        if type(text) == "string"
            and ITEM_SPELL_KNOWN
            and text:find(ITEM_SPELL_KNOWN, 1, true) then
            return true
        end
    end

    -- Item data is loaded and no "already known" marker was found.
    return false
end

local function IsMidnightRecipeKnown(recipe)
    if not recipe then
        return true
    end

    local characterDB = GetCharacterDB()
    characterDB.knownMidnightRecipes = characterDB.knownMidnightRecipes or {}
    if characterDB.knownMidnightRecipes[recipe.itemID] == true then
        return true
    end

    local tooltipKnown = trackerUI.GetRecipeKnownFromTooltip(recipe.itemID)
    if tooltipKnown == true then
        characterDB.knownMidnightRecipes[recipe.itemID] = true
        midnightCaches.recipeItemsDirty = true
        return tooltipKnown
    elseif tooltipKnown == false then
        return false
    end

    if C_TradeSkillUI and recipe.spellID and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
        local recipeInfo = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipe.spellID)
        if type(recipeInfo) == "table" and recipeInfo.learned == true then
            characterDB.knownMidnightRecipes[recipe.itemID] = true
            midnightCaches.recipeItemsDirty = true
            return true
        end
    end

    if recipe.spellID
        and C_SpellBook
        and C_SpellBook.IsSpellInSpellBook
        and Enum
        and Enum.SpellBookSpellBank
        and Enum.SpellBookSpellBank.Player then
        local known = SafeCall(
            C_SpellBook.IsSpellInSpellBook,
            recipe.spellID,
            Enum.SpellBookSpellBank.Player,
            false
        )
        if known == true then
            characterDB.knownMidnightRecipes[recipe.itemID] = true
            midnightCaches.recipeItemsDirty = true
            return true
        end
    end

    if C_TradeSkillUI and recipe.itemID and type(C_TradeSkillUI.GetRecipeInfoForItemID) == "function" then
        local recipeInfo = SafeCall(C_TradeSkillUI.GetRecipeInfoForItemID, recipe.itemID)
        if type(recipeInfo) == "table" and recipeInfo.learned == true then
            characterDB.knownMidnightRecipes[recipe.itemID] = true
            midnightCaches.recipeItemsDirty = true
            return true
        end
    end

    -- Sans tooltip charge, les "false" des API metier sont ambigus.
    return nil
end

trackerUI.FindMidnightRecipeInBags = function(trackedRows)
    if not midnightCaches.recipeItemsDirty and midnightCaches.recipeItems then
        return midnightCaches.recipeItems
    end

    local previous = midnightCaches.recipeItems
    trackedRows = trackedRows or GetTrackedMidnightProfessions()
    local trackedRecipesByItemID = {}
    for _, row in ipairs(trackedRows or EMPTY_TABLE) do
        local recipes = MIDNIGHT_RECIPE_TRACKING_BY_SKILL_LINE_ID[row.skillLineID]
        for _, recipe in ipairs(recipes or EMPTY_TABLE) do
            if GetAccountDB()[recipe.optionKey] ~= false then
                local known = IsMidnightRecipeKnown(recipe)
                if known == nil then
                    runtimeState.midnightRecipeStatePending = true
                elseif not known then
                    trackedRecipesByItemID[recipe.itemID] = recipe
                end
            end
        end
    end

    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)
    local firstMatch
    local totalCount = 0
    local countsByItemID = {}
    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            if itemID and trackedRecipesByItemID[itemID] then
                local count = math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
                countsByItemID[itemID] = (countsByItemID[itemID] or 0) + count
                totalCount = totalCount + count
                if not firstMatch then
                    firstMatch = {
                        bagID = bagID,
                        itemID = itemID,
                        itemLink = GetContainerItemLinkCompat(bagID, slotIndex),
                        itemName = GetItemInfo and GetItemInfo(itemID) or nil,
                        slotIndex = slotIndex,
                    }
                end
            end
        end
    end

    local result = {
        totalCount = totalCount,
        countsByItemID = countsByItemID,
        bagID = firstMatch and firstMatch.bagID or nil,
        itemID = firstMatch and firstMatch.itemID or nil,
        itemLink = firstMatch and firstMatch.itemLink or nil,
        itemName = firstMatch and firstMatch.itemName or nil,
        slotIndex = firstMatch and firstMatch.slotIndex or nil,
    }
    if previous and trackerUI.UsePreviousBagCacheOnTransientEmpty(
        "recipeItems",
        previous.totalCount or 0,
        result.totalCount or 0,
        previous
    ) then
        midnightCaches.recipeItems = previous
        midnightCaches.recipeItemsDirty = false
        return previous
    end

    local debugSignature = ("%d:%s"):format(result.totalCount or 0, tostring(result.itemID or "none"))
    if debugSignature ~= debugSignatures.recipeItems then
        debugSignatures.recipeItems = debugSignature
        DebugLog("Recipe items = count:%d first:%s", result.totalCount or 0, tostring(result.itemID or "none"))
    end

    midnightCaches.recipeItems = result
    midnightCaches.recipeItemsDirty = false
    return result
end

trackerUI.GetMidnightRecipeStatus = function(row)
    local result = {
        missingRecipes = {},
        requiredMoxie = 0,
        currentMoxie = 0,
        requiredVoidlightMarl = 0,
        currentVoidlightMarl = 0,
    }
    local recipes = row and row.skillLineID and MIDNIGHT_RECIPE_TRACKING_BY_SKILL_LINE_ID[row.skillLineID]
    if not recipes then
        return result
    end

    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local recipeItems = trackerUI.FindMidnightRecipeInBags()
    for _, recipe in ipairs(recipes) do
        local requiresAbundance = recipe.abundance == true
            or (tonumber(recipe.abundanceCost) or 0) > 0
        if GetAccountDB()[recipe.optionKey] ~= false
            and (not requiresAbundance or playerLevel >= runtimeState.minimumMidnightAbundanceLevel) then
            local known = IsMidnightRecipeKnown(recipe)
            if known == nil then
                runtimeState.midnightRecipeStatePending = true
            elseif not known and (recipeItems.countsByItemID[recipe.itemID] or 0) == 0 then
                result.missingRecipes[#result.missingRecipes + 1] = recipe
                -- Une recette achetee a l'hotel des ventes ne coute aucune monnaie de metier.
                if not recipe.auctionHouse then
                    result.requiredMoxie = result.requiredMoxie + (recipe.moxieCost or MIDNIGHT_RECIPE_MOXIE_COST)
                    result.requiredVoidlightMarl = result.requiredVoidlightMarl
                        + (recipe.voidlightMarlCost or runtimeState.midnightRecipeVoidlightMarlCost)
                end
            end
        end
    end
    if result.requiredMoxie > 0 then
        result.currentMoxie = GetCurrencyQuantity(row.moxieCurrencyID or MIDNIGHT_MOXIE_CURRENCY_IDS[row.skillLineID])
    end
    if result.requiredVoidlightMarl > 0 then
        result.currentVoidlightMarl = GetCurrencyQuantity(runtimeState.midnightVoidlightMarlCurrencyID)
    end
    return result
end

trackerUI.BuildMidnightKnowledgeBookWaypointPlan = function(trackedRows)
    local plan = {}
    local seen = {}
    local signatureParts = {}

    for _, row in ipairs(trackedRows or GetTrackedMidnightProfessions()) do
        local bookStatus = trackerUI.GetMidnightKnowledgeBookStatus(row)
        for _, book in ipairs(bookStatus.missingBooks) do
            local key = ("%s:%s:%s:%s"):format(book.mapID, book.x, book.y, book.label)
            if not seen[key] then
                seen[key] = true
                plan[#plan + 1] = {
                    mapID = book.mapID,
                    x = book.x / 100,
                    y = book.y / 100,
                    title = ("YWT livre KP - %s"):format(book.label),
                }
            end
            signatureParts[#signatureParts + 1] = tostring(row.skillLineID) .. ":" .. tostring(book.questID)
        end
        local recipeStatus = trackerUI.GetMidnightRecipeStatus(row)
        -- Budget cumule : ne pointer un vendeur que si la Moxie restante paie encore la recette.
        local affordableMoxie = recipeStatus.currentMoxie or 0
        for _, recipe in ipairs(recipeStatus.missingRecipes) do
            local moxieCost = recipe.moxieCost or MIDNIGHT_RECIPE_MOXIE_COST
            if not recipe.auctionHouse and recipe.mapID and affordableMoxie >= moxieCost then
                affordableMoxie = affordableMoxie - moxieCost
                local key = ("%s:%s:%s:%s"):format(recipe.mapID, recipe.x, recipe.y, recipe.label)
                if not seen[key] then
                    seen[key] = true
                    plan[#plan + 1] = {
                        mapID = recipe.mapID,
                        x = recipe.x / 100,
                        y = recipe.y / 100,
                        title = ("YWT recette - %s"):format(recipe.label),
                    }
                end
                signatureParts[#signatureParts + 1] = tostring(row.skillLineID) .. ":recipe:" .. tostring(recipe.itemID)
            end
        end
    end

    table.sort(signatureParts)
    return plan, table.concat(signatureParts, ",")
end

trackerUI.SyncMidnightKnowledgeBookWaypoints = function(trackedRows)
    if not (TomTom and type(TomTom.AddWaypoint) == "function" and type(TomTom.RemoveWaypoint) == "function") then
        if #knowledgeBookWaypointUIDs > 0 then
            trackerUI.ClearMidnightKnowledgeBookWaypoints()
        end
        return
    end

    local plan, signature = trackerUI.BuildMidnightKnowledgeBookWaypointPlan(trackedRows)
    if signature == knowledgeBookWaypointSignature then
        return
    end

    trackerUI.ClearMidnightKnowledgeBookWaypoints()
    for _, waypoint in ipairs(plan) do
        local uid = TomTom:AddWaypoint(waypoint.mapID, waypoint.x, waypoint.y, {
            title = waypoint.title,
            from = addonName,
            persistent = false,
            crazy = false,
            silent = true,
        })
        if uid then
            knowledgeBookWaypointUIDs[#knowledgeBookWaypointUIDs + 1] = uid
        end
    end
    knowledgeBookWaypointSignature = signature
end

trackerUI.BuildMidnightTreasureWaypointPlan = function(trackedRows)
    local plan = {}
    local signatureParts = {}

    for _, row in ipairs(trackedRows or GetTrackedMidnightProfessions()) do
        for _, questID in ipairs(row.config.treasureQuestIDs or EMPTY_TABLE) do
            if not IsQuestDone(questID) then
                local waypoint = MIDNIGHT_TREASURE_WAYPOINTS_BY_QUEST_ID[questID]
                if waypoint then
                    plan[#plan + 1] = {
                        mapID = waypoint.mapID,
                        x = waypoint.x,
                        y = waypoint.y,
                        title = ("%s - %s"):format(row.config.label, waypoint.title),
                    }
                    signatureParts[#signatureParts + 1] = tostring(questID)
                end
            end
        end
    end

    return plan, table.concat(signatureParts, ",")
end

trackerUI.SyncMidnightTreasureWaypoints = function()
    if not (TomTom and type(TomTom.AddWaypoint) == "function" and type(TomTom.RemoveWaypoint) == "function") then
        if #treasureWaypointUIDs > 0 then
            trackerUI.ClearMidnightTreasureWaypoints()
        end
        trackerUI.ClearMidnightKnowledgeBookWaypoints()
        return
    end

    local trackedRows = GetTrackedMidnightProfessions()
    trackerUI.SyncMidnightKnowledgeBookWaypoints(trackedRows)
    local plan, signature = trackerUI.BuildMidnightTreasureWaypointPlan(trackedRows)
    if signature == treasureWaypointSignature then
        return
    end

    trackerUI.ClearMidnightTreasureWaypoints()
    if #plan == 0 then
        return
    end

    for _, waypoint in ipairs(plan) do
        local uid = TomTom:AddWaypoint(waypoint.mapID, waypoint.x, waypoint.y, {
            title = waypoint.title,
            from = addonName,
            persistent = false,
            crazy = false,
            silent = true,
        })
        if uid then
            treasureWaypointUIDs[#treasureWaypointUIDs + 1] = uid
        end
    end

    treasureWaypointSignature = signature
end

trackerUI.RetriggerMidnightTreasureWaypoints = function()
    trackerUI.ClearMidnightTreasureWaypoints()
    trackerUI.ClearMidnightKnowledgeBookWaypoints()
    trackerUI.SyncMidnightTreasureWaypoints()
end

trackerUI.UpdateMidnightTreasureButton = function(trackedRows)
    local button = trackerFrame and trackerFrame.treasureButton or nil
    if not button then
        return false
    end

    if not (TomTom and type(TomTom.AddWaypoint) == "function" and type(TomTom.RemoveWaypoint) == "function") then
        button.missingCount = nil
        button:Hide()
        return false
    end

    local plan = trackerUI.BuildMidnightTreasureWaypointPlan(trackedRows)
    local missingCount = #plan
    if missingCount > 0 then
        button.missingCount = missingCount
        button:SetText(("TomTom tresors x%d"):format(missingCount))
        if debugSignatures.treasure ~= tostring(missingCount) then
            debugSignatures.treasure = tostring(missingCount)
            DebugLog("TomTom treasures missing = %d", missingCount)
        end
        button:Show()
        return true
    end

    if debugSignatures.treasure ~= "0" then
        debugSignatures.treasure = "0"
        DebugLog("TomTom treasures missing = 0")
    end
    button.missingCount = nil
    button:Hide()
    return false
end

trackerUI.BuildMidnightProfessionTokens = function(row)
    local config = row and row.config or nil
    if not config then
        -- Deux valeurs, sinon l'appelant recoit nil pour oneTimeTokens et leve
        -- sur sa longueur des qu'une ligne arrive sans config.
        return EMPTY_TABLE, EMPTY_TABLE
    end

    local tokens = {}
    local oneTimeTokens = {}

    -- Un jeton porte desormais deux ecritures : short pour la ligne, ou la
    -- place se compte en pixels, full pour l'infobulle, ou les noms entiers
    -- tiennent. tone remplace le balisage inline, qui se refermait mal : en
    -- WoW |r retablit la couleur par defaut au lieu de depiler, donc un jeton
    -- colore effacait la couleur de tous les suivants.
    local function Push(list, short, full, tone, line)
        list[#list + 1] = {
            short = short,
            full = full or short,
            tone = tone,
            line = line ~= false,
        }
    end

    -- Espace qui ne casse pas la ligne : si une mesure devait etre prise en
    -- defaut, la coupure tomberait quand meme entre deux jetons et non au
    -- milieu de l'un d'eux.
    local NB = YayaCore.UI.TEXT.nbsp
    local accountDB = GetAccountDB()
    local trackProfessionWeeklies = accountDB.trackProfessionWeeklies ~= false
    local trackProfessionLoots = accountDB.trackProfessionLoots ~= false
    local trackProfessionDisenchants = accountDB.trackProfessionDisenchants ~= false
    local trackProfessionGear = accountDB.trackProfessionGear ~= false
    local remainingTreasures, totalTreasures = CountRemainingTrackedQuests(config.treasureQuestIDs)
    if remainingTreasures > 0 then
        Push(oneTimeTokens,
            ("T%d/%d"):format(remainingTreasures, totalTreasures),
            ("Tresors : %d/%d restants"):format(remainingTreasures, totalTreasures),
            "category")
    end

    local remainingWeeklyLoots, totalWeeklyLoots = CountRemainingTrackedQuests(config.weeklyLootQuestIDs)
    if trackProfessionLoots and remainingWeeklyLoots > 0 then
        Push(tokens,
            ("loot%s%d/%d"):format(NB, remainingWeeklyLoots, totalWeeklyLoots),
            ("Loots hebdomadaires : %d/%d restants"):format(remainingWeeklyLoots, totalWeeklyLoots),
            "success")
    elseif trackProfessionLoots and totalWeeklyLoots <= 0 and (config.weeklyKnowledgeCap or 0) > 0 then
        Push(tokens,
            ("loot%s%d/%d"):format(NB, config.weeklyKnowledgeCap, config.weeklyKnowledgeCap),
            ("Loots hebdomadaires : %d/%d restants"):format(
                config.weeklyKnowledgeCap, config.weeklyKnowledgeCap),
            "success")
    end

    local remainingDisenchants, totalDisenchants = CountRemainingTrackedQuests(config.weeklyDisenchantQuestIDs)
    if trackProfessionDisenchants and remainingDisenchants > 0 then
        Push(tokens,
            ("dez%s%d/%d"):format(NB, remainingDisenchants, totalDisenchants),
            ("Desenchantements hebdomadaires : %d/%d restants"):format(
                remainingDisenchants, totalDisenchants),
            "success")
    end

    local hasTrainerWeeklyUnlocked = row.skillLevel >= (config.trainerMinSkill or math.huge)
    local hasTrainerWeeklyCompleted = IsAnyQuestDone(config.trainerWeeklyQuestIDs or EMPTY_TABLE)
    if trackProfessionWeeklies
        and hasTrainerWeeklyUnlocked
        and (not config.trainerWeeklyQuestIDs or not hasTrainerWeeklyCompleted) then
        Push(tokens, "hebdo", "Quete hebdomadaire de maitre disponible", "success")
    end

    if trackProfessionDisenchants and row.skillLineID == 2909 then
        local catchUp = trackerUI.GetMidnightEnchantingCatchUpStatus(
            row,
            remainingWeeklyLoots,
            remainingDisenchants
        )
        if catchUp then
            if catchUp.active then
                Push(tokens,
                    ("catchup%s%d"):format(NB, catchUp.remaining),
                    ("Rattrapage Enchantement : %d restants"):format(catchUp.remaining),
                    "success")
            else
                -- Rien a faire : le rappel n'a sa place qu'en infobulle.
                Push(tokens, "catchup", "Rattrapage Enchantement inactif", "muted", false)
            end
        end
    end

    local hasTreatiseUnlocked = row.skillLevel >= (config.treatiseMinSkill or math.huge)
    local treatiseTrackingEnabled = accountDB.trackTreatises ~= false
    local treatiseInfo = MIDNIGHT_TREATISES_BY_SKILL_LINE_ID[row.skillLineID]
    local hasTreatiseCompleted = treatiseInfo and IsQuestDone(treatiseInfo.weeklyQuestID) or false
    if treatiseTrackingEnabled and hasTreatiseUnlocked and not hasTreatiseCompleted then
        Push(tokens, "traite", "Traite hebdomadaire non consomme", "success")
    end

    if accountDB.trackProfessionDarkmoon ~= false
        and IsDarkmoonFaireActive()
        and config.darkmoonQuestID
        and not IsQuestDone(config.darkmoonQuestID) then
        Push(tokens, "DMF", "Foire de Sombrelune : quete de metier disponible", "success")
    end

    local knowledgeInfo = SafeCall(
        C_ProfSpecs and C_ProfSpecs.GetCurrencyInfoForSkillLine,
        row.skillLineID
    )
    local unspentKnowledge = type(knowledgeInfo) == "table" and knowledgeInfo.numAvailable or 0
    if type(unspentKnowledge) == "number"
        and unspentKnowledge > runtimeState.unspentKnowledgeWarningThreshold then
        Push(tokens,
            ("KP%s%d"):format(NB, unspentKnowledge),
            ("%d points de connaissance a depenser"):format(unspentKnowledge),
            "danger")
    end

    -- Un nom de livre ou de recette Midnight fait couramment plus de trente
    -- caracteres, pour cent-soixante-seize pixels utiles : la ligne ne porte
    -- donc plus qu'un compteur, et les noms entiers passent en infobulle.
    local bookStatus = trackerUI.GetMidnightKnowledgeBookStatus(row)
    local bookNames = {}
    for _, book in ipairs(bookStatus.missingBooks) do
        bookNames[#bookNames + 1] = book.label
    end
    if #bookNames > 0 then
        table.sort(bookNames)
        Push(oneTimeTokens,
            ("+10KP%sx%d"):format(NB, #bookNames),
            ("Livres +10 KP : %s"):format(table.concat(bookNames, ", ")),
            "category")
    end

    local recipeStatus = trackerUI.GetMidnightRecipeStatus(row)
    local vendorRecipes, auctionRecipes = {}, {}
    for _, recipe in ipairs(recipeStatus.missingRecipes) do
        local bucket = recipe.auctionHouse and auctionRecipes or vendorRecipes
        bucket[#bucket + 1] = recipe.label
    end
    if #vendorRecipes > 0 then
        table.sort(vendorRecipes)
        Push(oneTimeTokens,
            ("rec%sx%d"):format(NB, #vendorRecipes),
            ("Recettes chez le PNJ : %s"):format(table.concat(vendorRecipes, ", ")),
            "category")
    end
    if #auctionRecipes > 0 then
        table.sort(auctionRecipes)
        Push(oneTimeTokens,
            ("recHV%sx%d"):format(NB, #auctionRecipes),
            ("Recettes a l'hotel des ventes : %s"):format(table.concat(auctionRecipes, ", ")),
            "category")
    end

    -- Deux jetons, et rien de recalcule. `stuff` compte le materiel qui
    -- manque -- outils et accessoires confondus -- et `ench` les
    -- enchantements a poser. Les quatre anciens jetons decoupaient la meme
    -- regle en morceaux, sous deux options differentes : `outil RF` et `MC KO`
    -- etaient litteralement le meme calcul, et couper l'option des outils ne
    -- faisait que deplacer le rappel dans le compteur `stuff`, qui juge le
    -- meme emplacement.
    local toolStatus = trackProfessionGear
        and trackerUI.GetProfessionToolEnchantStatus(row)
        or EMPTY_TABLE

    if trackProfessionGear then
        local gear = toolStatus.gear or EMPTY_TABLE
        local details = {}
        local missingCount = 0

        -- Les outils viennent de `toolNeeds`, seule source du manque, et
        -- portent deja la nuance « possede mais sous le seuil ».
        if not toolStatus.toolScanPending then
            for _, need in ipairs(toolStatus.toolNeeds or EMPTY_TABLE) do
                missingCount = missingCount + 1
                details[#details + 1] = need.ownedUnderRank
                    and ("%s : possede mais sous le seuil de %d d'ilvl"):format(
                        need.reason or need.shortLabel or "outil",
                        trackerUI.GetProfessionGearMinimumItemLevel())
                    or ("%s : aucun exemplaire possede"):format(
                        need.reason or need.shortLabel or "outil")
            end
        end

        -- Les accessoires viennent des emplacements. L'emplacement d'outil est
        -- ecarte : il est deja compte par `toolNeeds`, et le compter deux fois
        -- ferait dire au jeton plus que ce que le bouton propose. Un scan
        -- incomplet ne declare rien.
        if not gear.pending then
            for _, slotState in ipairs(gear.slots or EMPTY_TABLE) do
                if slotState.compliant == false and not slotState.isToolSlot then
                    missingCount = missingCount + 1
                    details[#details + 1] = trackerUI.DescribeProfessionGearSlot(slotState)
                end
            end
        end

        if missingCount > 0 then
            Push(oneTimeTokens,
                ("stuff%sx%d"):format(NB, missingCount),
                ("Equipement de metier a completer (rare+ et ilvl >= %d) :\n%s"):format(
                    trackerUI.GetProfessionGearMinimumItemLevel(),
                    table.concat(details, "\n")),
                "warning")
        end

        -- pairs sur une table hachee : l'ordre change d'un rafraichissement a
        -- l'autre. On trie donc avant de composer, sinon l'infobulle danse.
        local enchantDetails = {}
        local enchantCount = 0
        for _, tool in pairs(toolStatus.missingEnchantTools or EMPTY_TABLE) do
            enchantCount = enchantCount + (tool.quantity or 0)
            enchantDetails[#enchantDetails + 1] = ("%s x%d : aucun enchantement"):format(
                tool.label or "?", tool.quantity or 0)
        end
        for _, tool in pairs(toolStatus.missingTools or EMPTY_TABLE) do
            enchantCount = enchantCount + (tool.quantity or 0)
            enchantDetails[#enchantDetails + 1] = ("%s x%d : mauvais enchantement"):format(
                tool.label or "?", tool.quantity or 0)
        end
        if enchantCount > 0 then
            table.sort(enchantDetails)
            Push(oneTimeTokens,
                ("ench%sx%d"):format(NB, enchantCount),
                ("Enchantements d'outil a poser :\n%s"):format(
                    table.concat(enchantDetails, "\n")),
                "warning")
        end
    end

    -- Les jetons sont traces : sans cela ils ne sont verifiables qu'a l'oeil,
    -- en jeu, alors qu'ils derivent maintenant des memes sources que le plan
    -- d'approvisionnement. Un jeton sans ligne de plan devient un ecart
    -- visible plutot qu'un doute.
    local tokenParts = {}
    for _, token in ipairs(oneTimeTokens) do
        tokenParts[#tokenParts + 1] = (tostring(token.short or "?"):gsub(NB, " "))
    end
    local tokenSignature = #tokenParts > 0 and table.concat(tokenParts, ",") or "none"
    local tokenKey = "professionTokens" .. tostring(row.skillLineID)
    if tokenSignature ~= debugSignatures[tokenKey] then
        debugSignatures[tokenKey] = tokenSignature
        DebugLog("Profession tokens[%s] = %s", tostring(row.skillLineID), tokenSignature)
    end

    return tokens, oneTimeTokens
end

trackerUI.GetMidnightKnowledgeBookStatus = function(row)
    local result = {
        missingBooks = {},
        requiredMoxie = 0,
        requiredAbundance = 0,
        currentMoxie = 0,
        currentAbundance = 0,
    }
    local books = row and row.skillLineID and MIDNIGHT_KNOWLEDGE_BOOKS_BY_SKILL_LINE_ID[row.skillLineID]
    if not books or (row.skillLevel or 0) < 25 then
        return result
    end

    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local knowledgeItems = FindMidnightKnowledgeConsumableInBags()
    for _, book in ipairs(books) do
        local itemCount = book.itemID
            and knowledgeItems.countsByItemID
            and knowledgeItems.countsByItemID[book.itemID]
            or 0
        if (not book.abundance or playerLevel >= runtimeState.minimumMidnightAbundanceLevel)
            and not IsQuestDone(book.questID)
            and itemCount == 0 then
            result.missingBooks[#result.missingBooks + 1] = book
            if book.abundance then
                result.requiredAbundance = result.requiredAbundance + MIDNIGHT_KNOWLEDGE_BOOK_ABUNDANCE_COST
            else
                result.requiredMoxie = result.requiredMoxie + MIDNIGHT_KNOWLEDGE_BOOK_MOXIE_COST
            end
        end
    end

    if result.requiredMoxie > 0 then
        result.currentMoxie = GetCurrencyQuantity(row.moxieCurrencyID or MIDNIGHT_MOXIE_CURRENCY_IDS[row.skillLineID])
    end
    if result.requiredAbundance > 0 then
        result.currentAbundance = GetCurrencyQuantity(MIDNIGHT_UNALLOYED_ABUNDANCE_CURRENCY_ID)
    end
    return result
end

trackerUI.GetMidnightProfessionWarningTokens = function(row)
    local currencyID = row and row.moxieCurrencyID or nil
    if not currencyID and row and row.skillLineID then
        currencyID = MIDNIGHT_MOXIE_CURRENCY_IDS[row.skillLineID]
        row.moxieCurrencyID = currencyID
    end
    if not currencyID then
        return
    end

    local currentMoxie = GetCurrencyQuantity(currencyID)
    local bookStatus = trackerUI.GetMidnightKnowledgeBookStatus(row)
    local recipeStatus = trackerUI.GetMidnightRecipeStatus(row)
    local warnings = {}
    local NB = YayaCore.UI.TEXT.nbsp
    local function Push(short, full, tone)
        warnings[#warnings + 1] = { short = short, full = full, tone = tone, line = true }
    end

    local requiredMoxie = bookStatus.requiredMoxie + recipeStatus.requiredMoxie
    if requiredMoxie > 0 and currentMoxie < requiredMoxie then
        Push(("moxie%s%d/%d"):format(NB, currentMoxie, requiredMoxie),
            ("Moxie : %d requis, %d possedes"):format(requiredMoxie, currentMoxie),
            "critical")
    elseif currentMoxie > MOXIE_WARNING_THRESHOLD then
        Push(("moxie%s%d"):format(NB, currentMoxie),
            ("Moxie : %d, au-dessus du seuil de %d"):format(currentMoxie, MOXIE_WARNING_THRESHOLD),
            "warning")
    end
    if bookStatus.requiredAbundance > 0 and bookStatus.currentAbundance < bookStatus.requiredAbundance then
        Push(("abond%s%d/%d"):format(NB, bookStatus.currentAbundance, bookStatus.requiredAbundance),
            ("Abondance non alliee : %d/%d"):format(
                bookStatus.currentAbundance, bookStatus.requiredAbundance),
            "critical")
    end
    if recipeStatus.requiredVoidlightMarl > 0
        and recipeStatus.currentVoidlightMarl < recipeStatus.requiredVoidlightMarl then
        Push(("marls%s%d/%d"):format(NB, recipeStatus.currentVoidlightMarl,
                recipeStatus.requiredVoidlightMarl),
            ("Voidlight Marl : %d/%d"):format(
                recipeStatus.currentVoidlightMarl, recipeStatus.requiredVoidlightMarl),
            "critical")
    end
    if #warnings > 0 then
        return warnings
    end
end

trackerUI.NotifyContainerOpening = function(button, _, down)
    if down or not button or not button.itemID then
        return
    end
    if trackerUI.IsContainerOpeningBlocked() then
        DebugLog("Container opening blocked itemID=%s", tostring(button.itemID))
        return
    end
    if YayaContainerValuesAPI and type(YayaContainerValuesAPI.BeginOpening) == "function" then
        YayaContainerValuesAPI.BeginOpening(button.itemID)
    end
end

--- Prepare une entree a partir de descripteurs de jetons.
--
-- La ligne ne recoit que les ecritures courtes, colorees jeton par jeton ;
-- l'infobulle recoit le detail complet, y compris les jetons que la ligne ne
-- porte pas. Le decoupage en lignes revient a la mise en page, qui seule
-- connait la largeur reelle.
trackerUI.BuildProfessionEntry = function(label, descriptors)
    local shorts, details = {}, {}
    for _, token in ipairs(descriptors) do
        if token.line then
            shorts[#shorts + 1] = YayaCore.UI.Colorize(token.tone, token.short)
        end
        details[#details + 1] = token.full
    end
    if #shorts == 0 then
        return nil
    end
    return {
        tokens = shorts,
        prefix = label .. ":",
        tooltipTitle = label,
        tooltipBody = table.concat(details, "\n"),
    }
end

trackerUI.AddMidnightProfessionEntries = function(entries, trackedRows, oneTimeEntries)
    local oneTimeRows = {}
    for _, row in ipairs(trackedRows or GetTrackedMidnightProfessions()) do
        local tokens, oneTimeTokens = trackerUI.BuildMidnightProfessionTokens(row)
        local warnings = trackerUI.GetMidnightProfessionWarningTokens(row)
        local weekly = trackerUI.BuildProfessionEntry(row.config.label, tokens)
        if weekly then
            AddEntry(entries, row.config.label, "todo", weekly)
        end
        if #oneTimeTokens > 0 or warnings then
            oneTimeRows[#oneTimeRows + 1] = { row = row, tokens = oneTimeTokens }
        end
    end

    if #oneTimeRows > 0 then
        for _, state in ipairs(oneTimeRows) do
            local descriptors = {}
            for _, token in ipairs(state.tokens) do
                descriptors[#descriptors + 1] = token
            end
            for _, token in ipairs(trackerUI.GetMidnightProfessionWarningTokens(state.row)
                or EMPTY_TABLE) do
                descriptors[#descriptors + 1] = token
            end
            local entry = trackerUI.BuildProfessionEntry(state.row.config.label, descriptors)
            if entry then
                AddEntry(oneTimeEntries or entries, state.row.config.label, "todo", entry)
            end
        end
    end
end

local function FindActiveQuestInLog(candidates, activeByQuestID)
    for _, questID in ipairs(candidates) do
        if activeByQuestID[questID] then
            return questID, activeByQuestID[questID]
        end
    end
end

local function FindQuestLogIndexByQuestID(questID)
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        for index = 1, numEntries do
            local info = C_QuestLog.GetInfo(index)
            if info and not info.isHeader and info.questID == questID then
                return index
            end
        end
    end

    if GetNumQuestLogEntries and GetQuestLogTitle then
        local numEntries = GetNumQuestLogEntries()
        for index = 1, numEntries do
            local _, _, _, isHeader, _, _, _, candidateQuestID = GetQuestLogTitle(index)
            if not isHeader and candidateQuestID == questID then
                return index
            end
        end
    end
end

local function ExtractProgressText(text)
    if type(text) ~= "string" or text == "" then
        return
    end

    local current, total = text:match("(%d+)%s*/%s*(%d+)")
    if current and total then
        return current .. "/" .. total
    end
end

local function GetQuestObjectiveProgressText(questID)
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local objectives = C_QuestLog.GetQuestObjectives(questID) or EMPTY_TABLE
        for _, objective in ipairs(objectives) do
            local progressText = ExtractProgressText(objective and objective.text)
            if progressText then
                return progressText
            end
        end
    end

    local questLogIndex = FindQuestLogIndexByQuestID(questID)
    if questLogIndex and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        local objectiveCount = GetNumQuestLeaderBoards(questLogIndex) or 0
        for objectiveIndex = 1, objectiveCount do
            local objectiveText = GetQuestLogLeaderBoard(objectiveIndex, questLogIndex)
            local progressText = ExtractProgressText(objectiveText)
            if progressText then
                return progressText
            end
        end
    end
end

local function AddReplenishTheReservoirEntry(entries, activeByQuestID)
    -- Hidden on request: keep detection code intact, but do not expose this line in the tracker UI.
    return
end

local function GetVisionsOfNzothQuestlineSteps()
    local steps = {
        {
            key = "unlock_world_quests",
            label = "Uniting Kul Tiras / Uniting Zandalar",
            activeQuestIDs = { 51918, 52450, 51916, 52451 },
            completedQuestIDs = { 51918, 52450, 51916, 52451 },
        },
        {
            key = "nazjatar_intro",
            label = "Nazjatar intro",
            activeQuestIDs = NAZJATAR_INTRO_QUEST_IDS,
            completedQuestIDs = NAZJATAR_INTRO_COMPLETION_QUEST_IDS,
            activeTitles = {
                "The Wolf's Offensive",
                "The Warchief's Order",
                "A Way Home",
            },
        },
        {
            key = "harnessing_the_power",
            label = "Harnessing the Power",
            activeQuestIDs = { HARNESSING_THE_POWER_QUEST_ID },
            completedQuestIDs = { HARNESSING_THE_POWER_QUEST_ID },
        },
    }

    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if faction == "Alliance" then
        steps[#steps + 1] = {
            key = "an_unwelcome_advisor",
            label = "An Unwelcome Advisor",
            activeQuestIDs = { AN_UNWELCOME_ADVISOR_QUEST_ID },
            completedQuestIDs = { AN_UNWELCOME_ADVISOR_QUEST_ID },
        }
        steps[#steps + 1] = {
            key = "return_of_the_warrior_king",
            label = "Return of the Warrior King",
            activeQuestIDs = { RETURN_OF_THE_WARRIOR_KING_QUEST_ID },
            completedQuestIDs = { RETURN_OF_THE_WARRIOR_KING_QUEST_ID },
        }
    else
        steps[#steps + 1] = {
            key = "return_of_the_black_prince",
            label = "Return of the Black Prince",
            activeQuestIDs = { RETURN_OF_THE_BLACK_PRINCE_QUEST_ID },
            completedQuestIDs = { RETURN_OF_THE_BLACK_PRINCE_QUEST_ID },
        }
    end

    local sharedSteps = {
        {
            key = "where_the_heart_is",
            label = "Where the Heart Is",
            activeQuestIDs = { WHERE_THE_HEART_IS_QUEST_ID },
            completedQuestIDs = { WHERE_THE_HEART_IS_QUEST_ID },
        },
        {
            key = "network_diagnostics",
            label = "Network Diagnostics",
            activeQuestIDs = { NETWORK_DIAGNOSTICS_QUEST_ID },
            completedQuestIDs = { NETWORK_DIAGNOSTICS_QUEST_ID },
        },
        {
            key = "a_titanic_problem",
            label = "A Titanic Problem",
            activeQuestIDs = { A_TITANIC_PROBLEM_QUEST_ID },
            completedQuestIDs = { A_TITANIC_PROBLEM_QUEST_ID },
        },
        {
            key = "the_halls_of_origination",
            label = "The Halls of Origination",
            activeQuestIDs = { THE_HALLS_OF_ORIGINATION_QUEST_ID },
            completedQuestIDs = { THE_HALLS_OF_ORIGINATION_QUEST_ID },
        },
        {
            key = "to_ramkahen",
            label = "To Ramkahen",
            activeQuestIDs = { TO_RAMKAHEN_QUEST_ID },
            completedQuestIDs = { TO_RAMKAHEN_QUEST_ID },
        },
        {
            key = "the_uldum_accord",
            label = "The Uldum Accord",
            activeQuestIDs = { THE_ULDUM_ACCORD_QUEST_ID },
            completedQuestIDs = { THE_ULDUM_ACCORD_QUEST_ID },
        },
        {
            key = "surfacing_threats",
            label = "Surfacing Threats",
            activeQuestIDs = { SURFACING_THREATS_QUEST_ID },
            completedQuestIDs = { SURFACING_THREATS_QUEST_ID },
        },
        {
            key = "curious_corruption",
            label = "Curious Corruption",
            activeQuestIDs = { CURIOUS_CORRUPTION_QUEST_ID },
            completedQuestIDs = { CURIOUS_CORRUPTION_QUEST_ID },
        },
        {
            key = "forging_onward",
            label = "Forging Onward",
            activeQuestIDs = { FORGING_ONWARD_QUEST_ID },
            completedQuestIDs = { FORGING_ONWARD_QUEST_ID },
        },
        {
            key = "its_never_easy",
            label = "It's Never Easy",
            activeQuestIDs = { ITS_NEVER_EASY_QUEST_ID },
            completedQuestIDs = { ITS_NEVER_EASY_QUEST_ID },
        },
        {
            key = "the_mysterious_sigil",
            label = "The Mysterious Sigil",
            activeQuestIDs = { THE_MYSTERIOUS_SIGIL_QUEST_ID },
            completedQuestIDs = { THE_MYSTERIOUS_SIGIL_QUEST_ID },
        },
        {
            key = "clans_of_the_mogu",
            label = "Clans of the Mogu",
            activeQuestIDs = { CLANS_OF_THE_MOGU_QUEST_ID },
            completedQuestIDs = { CLANS_OF_THE_MOGU_QUEST_ID },
        },
        {
            key = "finding_the_rajani",
            label = "Finding the Rajani",
            activeQuestIDs = { FINDING_THE_RAJANI_QUEST_ID },
            completedQuestIDs = { FINDING_THE_RAJANI_QUEST_ID },
        },
        {
            key = "time_lost_warriors",
            label = "Time-Lost Warriors",
            activeQuestIDs = { TIME_LOST_WARRIORS_QUEST_ID },
            completedQuestIDs = { TIME_LOST_WARRIORS_QUEST_ID },
        },
        {
            key = "proof_of_tenacity",
            label = "Mark of the Conquerors / Proof of Tenacity",
            activeQuestIDs = { MARK_OF_THE_CONQUERORS_QUEST_ID, PROOF_OF_TENACITY_QUEST_ID },
            completedQuestIDs = { PROOF_OF_TENACITY_QUEST_ID },
            activeTitles = {
                "Mark of the Conquerors",
                "Proof of Tenacity",
            },
        },
        {
            key = "the_engine_of_nalaksha",
            label = "The Engine of Nalak'sha",
            activeQuestIDs = { THE_ENGINE_OF_NALAKSHA_QUEST_ID },
            completedQuestIDs = { THE_ENGINE_OF_NALAKSHA_QUEST_ID },
        },
        {
            key = "restored_hope",
            label = "Restored Hope",
            activeQuestIDs = { NZOTH_UNLOCK_QUEST_ID },
            completedQuestIDs = { NZOTH_UNLOCK_QUEST_ID },
        },
        {
            key = "magnis_findings",
            label = "Magni's Findings",
            activeQuestIDs = { MAGNIS_FINDINGS_QUEST_ID },
            completedQuestIDs = { MAGNIS_FINDINGS_QUEST_ID },
        },
        {
            key = "power_protocol_initiation",
            label = "Power Protocol Initiation",
            activeQuestIDs = { POWER_PROTOCOL_INITIATION_QUEST_ID },
            completedQuestIDs = { POWER_PROTOCOL_INITIATION_QUEST_ID },
        },
        {
            key = "re_origination",
            label = "Re-Origination",
            activeQuestIDs = { RE_ORIGINATION_QUEST_ID },
            completedQuestIDs = { RE_ORIGINATION_QUEST_ID },
        },
        {
            key = "investigating_the_halls",
            label = "Investigating the Halls",
            activeQuestIDs = { INVESTIGATING_THE_HALLS_QUEST_ID },
            completedQuestIDs = { INVESTIGATING_THE_HALLS_QUEST_ID },
        },
        {
            key = "beginning_the_descent",
            label = "Beginning the Descent",
            activeQuestIDs = { BEGINNING_THE_DESCENT_QUEST_ID },
            completedQuestIDs = { BEGINNING_THE_DESCENT_QUEST_ID },
        },
        {
            key = "deeper_into_the_darkness",
            label = "Deeper Into the Darkness",
            activeQuestIDs = { DEEPER_INTO_THE_DARKNESS_QUEST_ID },
            completedQuestIDs = { DEEPER_INTO_THE_DARKNESS_QUEST_ID },
        },
        {
            key = "opening_the_gateway",
            label = "Opening the Gateway",
            activeQuestIDs = { OPENING_THE_GATEWAY_QUEST_ID },
            completedQuestIDs = { OPENING_THE_GATEWAY_QUEST_ID },
        },
        {
            key = "descending_into_madness",
            label = "Descending Into Madness",
            activeQuestIDs = { DESCENDING_INTO_MADNESS_QUEST_ID },
            completedQuestIDs = { DESCENDING_INTO_MADNESS_QUEST_ID },
        },
        {
            key = "into_the_darkest_depths",
            label = "Into the Darkest Depths",
            activeQuestIDs = { INTO_THE_DARKEST_DEPTHS_QUEST_ID },
            completedQuestIDs = { INTO_THE_DARKEST_DEPTHS_QUEST_ID },
        },
        {
            key = "whispers_in_the_dark",
            label = "Whispers in the Dark",
            activeQuestIDs = { WHISPERS_IN_THE_DARK_QUEST_ID },
            completedQuestIDs = { WHISPERS_IN_THE_DARK_QUEST_ID },
        },
        {
            key = "into_dreams",
            label = "Into Dreams",
            activeQuestIDs = { INTO_DREAMS_QUEST_ID },
            completedQuestIDs = { INTO_DREAMS_QUEST_ID },
        },
    }

    for _, step in ipairs(sharedSteps) do
        steps[#steps + 1] = step
    end

    return steps
end

local function IsQuestlineStepComplete(step)
    local questIDs = step and step.completedQuestIDs or nil
    if not questIDs or #questIDs == 0 then
        return false
    end

    for _, questID in ipairs(questIDs) do
        if IsQuestDone(questID) then
            return true
        end
    end

    return false
end

local function FindActiveQuestlineStep(step, activeByQuestID, activeByTitle)
    local questIDs = step and step.activeQuestIDs or nil
    if questIDs then
        for _, questID in ipairs(questIDs) do
            local entry = activeByQuestID[questID]
            if entry then
                return entry
            end
        end
    end

    local titles = step and step.activeTitles or nil
    if titles then
        for _, title in ipairs(titles) do
            local entry = activeByTitle[NormalizeText(title)]
            if entry then
                return entry
            end
        end
    end
end

local function BuildQuestlineStepSnapshot(step, index, activeEntry)
    if not step then
        return nil
    end

    return {
        index = index,
        key = step.key,
        label = step.label,
        questID = activeEntry and activeEntry.questID or nil,
        questTitle = activeEntry and activeEntry.title or nil,
        isComplete = IsQuestlineStepComplete(step),
    }
end

local function BuildVisionsOfNzothQuestlineSnapshot(questLog)
    local requiredSteps = GetVisionsOfNzothQuestlineSteps()
    local activeByQuestID, activeByTitle = BuildQuestLogLookups(questLog)
    local currentStep
    local currentStepType = nil

    for index, step in ipairs(requiredSteps) do
        local activeEntry = FindActiveQuestlineStep(step, activeByQuestID, activeByTitle)
        if activeEntry then
            currentStep = BuildQuestlineStepSnapshot(step, index, activeEntry)
            currentStepType = "main"
            break
        end
    end

    if not currentStep then
        for index, step in ipairs(VISIONS_OF_NZOTH_OPTIONAL_STEPS) do
            local activeEntry = FindActiveQuestlineStep(step, activeByQuestID, activeByTitle)
            if activeEntry then
                currentStep = BuildQuestlineStepSnapshot(step, index, activeEntry)
                currentStepType = "optional"
                break
            end
        end
    end

    local completedRequiredSteps = 0
    local lastCompletedStep
    local nextRequiredStep

    for index, step in ipairs(requiredSteps) do
        if IsQuestlineStepComplete(step) then
            completedRequiredSteps = completedRequiredSteps + 1
            lastCompletedStep = BuildQuestlineStepSnapshot(step, index)
        elseif not nextRequiredStep then
            nextRequiredStep = BuildQuestlineStepSnapshot(step, index)
        end
    end

    return {
        requiredStepCount = #requiredSteps,
        completedRequiredSteps = completedRequiredSteps,
        mainChainComplete = IsQuestDone(INTO_DREAMS_QUEST_ID),
        cloakQuestDone = IsQuestDone(BEGINNING_THE_DESCENT_QUEST_ID),
        accessToArchivesDone = IsQuestDone(ACCESSING_THE_ARCHIVES_QUEST_ID),
        corruptorsEndDone = IsQuestDone(CORRUPTORS_END_QUEST_ID),
        currentStepType = currentStepType,
        currentStep = currentStep,
        lastCompletedStep = lastCompletedStep,
        nextRequiredStep = nextRequiredStep,
    }
end

local function BuildQuestProgressSnapshot(questLog)
    local majorQuestID = FindActiveQuest(NZOTH_MAJOR_ASSAULTS)
    local minorQuestID = FindActiveQuest(NZOTH_MINOR_ASSAULTS)

    return {
        nzothUnlocked = IsQuestDone(NZOTH_UNLOCK_QUEST_ID),
        activeMajorAssaultQuestID = majorQuestID,
        activeMajorAssaultQuestTitle = majorQuestID and GetQuestTitle(majorQuestID) or nil,
        activeMinorAssaultQuestID = minorQuestID,
        activeMinorAssaultQuestTitle = minorQuestID and GetQuestTitle(minorQuestID) or nil,
        victoryInOurNameDone = IsQuestDone(VICTORY_IN_OUR_NAME_QUEST_ID),
        containingTheHelswornDone = IsQuestDone(CONTAINING_THE_HELSWORN_QUEST_ID),
        questline = BuildVisionsOfNzothQuestlineSnapshot(questLog or EMPTY_TABLE),
    }
end

local function GetScanTooltip()
    if scanTooltip then
        return scanTooltip
    end

    scanTooltip = CreateFrame("GameTooltip", addonName .. "ScanTooltip", UIParent, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    return scanTooltip
end

local function ParseCloakRank(text)
    if not text or text == "" then
        return
    end

    local rank = text:match("^Rank%s+(%d+)$")
    if rank then
        return tonumber(rank), text
    end

    rank = text:match("^Rang%s+(%d+)$")
    if rank then
        return tonumber(rank), text
    end
end

GetContainerNumSlotsCompat = function(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID)
    end

    if GetContainerNumSlots then
        return GetContainerNumSlots(bagID)
    end

    return 0
end

GetContainerItemLinkCompat = function(bagID, slotIndex)
    if C_Container and C_Container.GetContainerItemLink then
        local link = SafeCall(C_Container.GetContainerItemLink, bagID, slotIndex)
        if link then
            return link
        end
    end

    if C_Container and C_Container.GetContainerItemInfo then
        local info = SafeCall(C_Container.GetContainerItemInfo, bagID, slotIndex)
        if info and info.hyperlink then
            return info.hyperlink
        end
    end

    if GetContainerItemLink then
        return SafeCall(GetContainerItemLink, bagID, slotIndex)
    end
end

local function GetTooltipRank(getter)
    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    getter(tooltip)

    for lineIndex = 2, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. lineIndex]
        local text = line and line:GetText()
        local parsedRank, parsedText = ParseCloakRank(text)
        if parsedRank then
            return parsedRank, parsedText
        end
    end
end

local function GetLegendaryCloakRankProgress(questLog)
    local activeByQuestID, activeByTitle = BuildQuestLogLookups(questLog or EMPTY_TABLE)
    local currentRank
    local activeStep
    local activeQuestEntry
    local lastCompletedStep

    for _, step in ipairs(LEGENDARY_CLOAK_UPGRADE_STEPS) do
        if IsQuestDone(step.questID) then
            currentRank = step.rank
            lastCompletedStep = step
        elseif not activeStep then
            local entry = activeByQuestID[step.questID]

            if not entry and step.activeTitles then
                for _, title in ipairs(step.activeTitles) do
                    entry = activeByTitle[NormalizeText(title)]
                    if entry then
                        break
                    end
                end
            end

            if entry then
                activeStep = step
                activeQuestEntry = entry
            end
        end
    end

    local hasRank15PlusProgress = IsQuestDone(CHASING_MADNESS_QUEST_ID) or activeByQuestID[CHASING_MADNESS_QUEST_ID] ~= nil
    if hasRank15PlusProgress then
        currentRank = math.max(currentRank or 0, LEGENDARY_CLOAK_MAX_RANK)
    end

    if activeStep then
        currentRank = math.max(currentRank or 0, activeStep.rank - 1)
    end

    if currentRank and currentRank > LEGENDARY_CLOAK_MAX_RANK then
        currentRank = LEGENDARY_CLOAK_MAX_RANK
    end

    return {
        rank = currentRank,
        maxRank = LEGENDARY_CLOAK_MAX_RANK,
        atMaxRank = (currentRank or 0) >= LEGENDARY_CLOAK_MAX_RANK,
        lastCompletedStep = lastCompletedStep,
        activeStep = activeStep,
        activeQuestEntry = activeQuestEntry,
        hasRank15PlusProgress = hasRank15PlusProgress,
    }
end

local function GetCloakSnapshot()
    local itemLink = GetInventoryItemLink and GetInventoryItemLink("player", INVSLOT_BACK) or nil
    if not itemLink then
        return {}
    end

    local itemID = GetInventoryItemID and GetInventoryItemID("player", INVSLOT_BACK) or nil
    local itemName = GetItemInfo and GetItemInfo(itemLink) or nil
    local itemLevel = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(itemLink) or nil
    local rank, rankText = GetTooltipRank(function(tooltip)
        tooltip:SetInventoryItem("player", INVSLOT_BACK)
    end)

    return {
        itemID = itemID,
        itemLink = itemLink,
        itemName = itemName,
        itemLevel = itemLevel,
        rank = rank,
        rankText = rankText,
    }
end

local function GetLegendaryCloakSnapshot(questLog)
    local rankProgress = GetLegendaryCloakRankProgress(questLog)
    local snapshot = {
        obtained = IsQuestDone(BEGINNING_THE_DESCENT_QUEST_ID),
        rank = rankProgress.rank,
        rankText = nil,
        rankSource = rankProgress.rank and "quest_history" or nil,
        maxRank = rankProgress.maxRank,
        atMaxRank = rankProgress.atMaxRank,
    }

    if GetItemCount and (GetItemCount(LEGENDARY_CLOAK_ITEM_ID, true) or 0) > 0 then
        snapshot.obtained = true
    end

    if not snapshot.obtained then
        snapshot.rank = nil
        snapshot.rankSource = nil
        snapshot.atMaxRank = false
    elseif not snapshot.rank then
        snapshot.rank = 1
        snapshot.rankSource = "item_presence"
    end

    if snapshot.obtained and rankProgress.lastCompletedStep then
        snapshot.lastUpgradeQuestID = rankProgress.lastCompletedStep.questID
        snapshot.lastUpgradeQuestLabel = rankProgress.lastCompletedStep.label
    end

    if snapshot.obtained and rankProgress.activeStep then
        snapshot.activeUpgradeQuestID = rankProgress.activeStep.questID
        snapshot.activeUpgradeQuestLabel = rankProgress.activeStep.label
        snapshot.nextRank = rankProgress.activeStep.rank
        snapshot.activeUpgradeQuestTitle = rankProgress.activeQuestEntry and rankProgress.activeQuestEntry.title or nil
    end

    if snapshot.obtained and rankProgress.hasRank15PlusProgress then
        snapshot.rank15PlusProgress = true
        snapshot.rank15PlusQuestID = CHASING_MADNESS_QUEST_ID
    end

    local equippedItemID = GetInventoryItemID and GetInventoryItemID("player", INVSLOT_BACK) or nil
    if equippedItemID == LEGENDARY_CLOAK_ITEM_ID then
        local itemLink = GetInventoryItemLink("player", INVSLOT_BACK)
        snapshot.itemID = LEGENDARY_CLOAK_ITEM_ID
        snapshot.itemLink = itemLink
        snapshot.itemName = itemLink and GetItemInfo and GetItemInfo(itemLink) or nil
        snapshot.itemLevel = itemLink and GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(itemLink) or nil
        snapshot.isEquipped = true
        snapshot.tooltipRank, snapshot.rankText = GetTooltipRank(function(tooltip)
            tooltip:SetInventoryItem("player", INVSLOT_BACK)
        end)
        if snapshot.tooltipRank and not snapshot.rank then
            snapshot.rank = snapshot.tooltipRank
            snapshot.rankSource = "tooltip"
        end
        return snapshot
    end

    for bagID = 0, NUM_BAG_SLOTS do
        local numSlots = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, numSlots do
            if GetContainerItemIDCompat(bagID, slotIndex) == LEGENDARY_CLOAK_ITEM_ID then
                local itemLink = GetContainerItemLinkCompat(bagID, slotIndex)
                snapshot.itemID = LEGENDARY_CLOAK_ITEM_ID
                snapshot.itemLink = itemLink
                snapshot.itemName = itemLink and GetItemInfo and GetItemInfo(itemLink) or nil
                snapshot.itemLevel = itemLink and GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(itemLink) or nil
                snapshot.bagID = bagID
                snapshot.slotIndex = slotIndex
                snapshot.tooltipRank, snapshot.rankText = GetTooltipRank(function(tooltip)
                    tooltip:SetBagItem(bagID, slotIndex)
                end)
                if snapshot.tooltipRank and not snapshot.rank then
                    snapshot.rank = snapshot.tooltipRank
                    snapshot.rankSource = "tooltip"
                end
                return snapshot
            end
        end
    end

    return snapshot
end

local function GetHeartOfAzerothSnapshot()
    local itemLink = GetInventoryItemLink and GetInventoryItemLink("player", INVSLOT_NECK) or nil
    if not itemLink then
        return {}
    end

    local itemID = GetInventoryItemID and GetInventoryItemID("player", INVSLOT_NECK) or nil
    local itemName = GetItemInfo and GetItemInfo(itemLink) or nil
    local itemLevel = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(itemLink) or nil
    local level

    if C_AzeriteItem and C_AzeriteItem.FindActiveAzeriteItem and C_AzeriteItem.GetPowerLevel then
        local itemLocation = C_AzeriteItem.FindActiveAzeriteItem()
        if itemLocation then
            level = C_AzeriteItem.GetPowerLevel(itemLocation)
        end
    end

    return {
        itemID = itemID,
        itemLink = itemLink,
        itemName = itemName,
        itemLevel = itemLevel,
        level = level,
    }
end

local function BuildNyalothaProgressSnapshot()
    local progress = {
        source = "achievement_criteria",
        wings = {},
        totalBosses = 0,
        killedBosses = 0,
        nzothKilled = false,
        hasAccountWideAchievements = false,
    }

    if not (GetAchievementInfo and GetAchievementCriteriaInfo) then
        return progress
    end

    for _, wing in ipairs(NYALOTHA_WING_ACHIEVEMENTS) do
        local _, achievementName, _, achievementComplete, month, day, year, _, flags, _, _, _, wasEarnedByMe = GetAchievementInfo(wing.achievementID)
        local isAccountWide = false
        if bit and bit.band and ACHIEVEMENT_FLAGS_ACCOUNT then
            isAccountWide = bit.band(flags or 0, ACHIEVEMENT_FLAGS_ACCOUNT) == ACHIEVEMENT_FLAGS_ACCOUNT
        end

        if isAccountWide then
            progress.hasAccountWideAchievements = true
        end

        local wingSnapshot = {
            achievementID = wing.achievementID,
            name = achievementName or wing.label,
            completed = achievementComplete and true or false,
            wasEarnedByMe = wasEarnedByMe and true or false,
            isAccountWide = isAccountWide,
            completedDate = (achievementComplete and month and day and year) and ("%02d/%02d/%04d"):format(day, month, year) or nil,
            bosses = {},
        }

        for criteriaIndex = 1, wing.bosses do
            local criteriaLabel, _, isKilled = GetAchievementCriteriaInfo(wing.achievementID, criteriaIndex)
            wingSnapshot.bosses[#wingSnapshot.bosses + 1] = {
                index = criteriaIndex,
                label = criteriaLabel,
                isKilled = isKilled and true or false,
            }

            progress.totalBosses = progress.totalBosses + 1
            if isKilled then
                progress.killedBosses = progress.killedBosses + 1
            end

            if wing.nzothCriterionIndex == criteriaIndex then
                progress.nzothKilled = isKilled and true or false
            end
        end

        progress.wings[#progress.wings + 1] = wingSnapshot
    end

    return progress
end

local function BuildRaidBossSnapshot(instanceIndex)
    local bosses = {}
    if not GetSavedInstanceEncounterInfo then
        return bosses
    end

    local encounterIndex = 1
    while true do
        local bossName, _, isKilled = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
        if not bossName then
            break
        end

        bosses[#bosses + 1] = {
            name = bossName,
            isKilled = isKilled and true or false,
        }
        encounterIndex = encounterIndex + 1
    end

    return bosses
end

local function IsNyalothaSavedInstance(name)
    if not name or name == "" then
        return false
    end

    local localizedName = GetLocalizedMapName(NYALOTHA_MAP_ID, "Ny'alotha, the Waking City")
    return name == localizedName or name == "Ny'alotha, the Waking City"
end

local function GetNyalothaRaidSnapshot()
    local raid = {
        mapID = NYALOTHA_MAP_ID,
        name = GetLocalizedMapName(NYALOTHA_MAP_ID, "Ny'alotha, the Waking City"),
        lockouts = {},
        progress = BuildNyalothaProgressSnapshot(),
    }

    if not (GetNumSavedInstances and GetSavedInstanceInfo) then
        return raid
    end

    local numInstances = GetNumSavedInstances()
    for instanceIndex = 1, numInstances do
        local name, _, reset, difficultyID, locked, extended, _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(instanceIndex)
        if isRaid and IsNyalothaSavedInstance(name) then
            raid.lockouts[#raid.lockouts + 1] = {
                difficultyID = difficultyID,
                difficultyName = difficultyName,
                locked = locked and true or false,
                extended = extended and true or false,
                reset = reset,
                maxPlayers = maxPlayers,
                encounterProgress = encounterProgress,
                numEncounters = numEncounters,
                bosses = BuildRaidBossSnapshot(instanceIndex),
            }
        end
    end

    return raid
end

local function GetPlayerSnapshot()
    local _, classFile = UnitClass("player")
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil

    return {
        key = GetPlayerKey(),
        name = UnitName("player"),
        realm = GetRealmName(),
        class = classFile,
        level = UnitLevel and UnitLevel("player") or nil,
        faction = faction,
    }
end

local function GetLocationSnapshot()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil

    return {
        mapID = mapID,
        zone = GetZoneText and GetZoneText() or nil,
        subZone = GetSubZoneText and GetSubZoneText() or nil,
    }
end

local function BuildFallbackCacheSource(cacheItemID)
    local details = cacheItemID and NZOTH_ASSAULT_DETAILS_BY_ITEM_ID[cacheItemID] or nil
    local activeQuestID

    if cacheItemID == 173372 then
        activeQuestID = FindActiveQuest(NZOTH_MAJOR_ASSAULTS)
        details = activeQuestID and NZOTH_ASSAULT_DETAILS[activeQuestID] or nil
    elseif not details and cacheItemID then
        for questID, candidate in pairs(NZOTH_ASSAULT_DETAILS) do
            if candidate.cacheItemID == cacheItemID then
                activeQuestID = questID
                details = candidate
                break
            end
        end
    elseif not details then
        activeQuestID = FindActiveQuest(NZOTH_MAJOR_ASSAULTS)
        details = activeQuestID and NZOTH_ASSAULT_DETAILS[activeQuestID] or nil
    end

    return {
        questID = activeQuestID,
        questTitle = activeQuestID and GetQuestTitle(activeQuestID) or nil,
        source = details and details.zoneSlug or "unknown",
        sourceLabel = details and details.zoneLabel or "Unknown",
        zone = details and details.zoneSlug or "unknown",
        zoneLabel = details and details.zoneLabel or "Unknown",
        assault = details and details.assaultSlug or "unknown",
        assaultLabel = details and details.assaultLabel or "Unknown",
        kind = details and details.kind or "unknown",
        cacheItemID = details and details.cacheItemID or cacheItemID,
        cacheLabel = details and details.cacheLabel or nil,
        turnedInAt = nil,
    }
end

local function SaveNzothCacheRecord(record)
    local history = GetNzothCacheHistory()
    record.id = GetNextNzothCacheHistoryID()
    history[#history + 1] = record
end

local function FinalizeActiveCacheOpen()
    if not activeCacheOpen then
        return
    end

    local record = activeCacheOpen
    activeCacheOpen = nil

    record.after = {
        currencies = BuildCurrencySnapshot(),
    }
    record.delta = BuildCurrencyDelta(record.before and record.before.currencies, record.after.currencies)
    record.reward = {
        gold = record.delta.money,
        warResources = record.delta.warResources,
        corruptedMementos = record.delta.corruptedMementos,
        coalescingVisions = record.delta.coalescingVisions,
        got2000Gold = record.delta.money >= GOLD_2000_REWARD_COPPER,
    }

    SaveNzothCacheRecord(record)
end

local function ScheduleFinalizeActiveCacheOpen(delaySeconds)
    if not activeCacheOpen then
        return
    end

    if not (C_Timer and C_Timer.After) then
        FinalizeActiveCacheOpen()
        return
    end

    runtimeState.activeCacheFinalizeToken = runtimeState.activeCacheFinalizeToken + 1
    local token = runtimeState.activeCacheFinalizeToken
    C_Timer.After(delaySeconds or 0.4, function()
        if activeCacheOpen and runtimeState.activeCacheFinalizeToken == token then
            FinalizeActiveCacheOpen()
        end
    end)
end

local function RefreshTrackerNow()
    if not trackerFrame then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        runtimeState.trackerRefreshDeferredByCombat = true
        return
    end

    InvalidateQuestCaches()
    runtimeState.midnightRecipeStatePending = false

    if runtimeState.trackerNeedsJardOwnerRefresh then
        runtimeState.trackerNeedsJardOwnerRefresh = false
        UpdateJardOwners()
    end

    UpdateTracker()
    runtimeState.itemActionForceBagRefresh = false
    if runtimeState.itemActionRefreshPending then
        runtimeState.itemActionRefreshPending = false
        trackerUI.UnlockItemActionButtons()
    end
    -- Apres UpdateTracker et le deverrouillage, sinon le gate serait annule.
    trackerUI.ApplyItemActionCooldownGates()
    trackerUI.SyncMidnightTreasureWaypoints()
    if runtimeState.midnightRecipeStatePending and C_Timer and C_Timer.After then
        ScheduleTrackerRefresh(10, false)
    end
end

ScheduleTrackerRefresh = function(delaySeconds, refreshJardOwners)
    if not trackerFrame then
        return
    end

    if refreshJardOwners then
        runtimeState.trackerNeedsJardOwnerRefresh = true
    end

    if not (C_Timer and C_Timer.After) then
        RefreshTrackerNow()
        return
    end

    runtimeState.trackerRefreshToken = runtimeState.trackerRefreshToken + 1
    local token = runtimeState.trackerRefreshToken
    local effectiveDelay = delaySeconds or TRACKER_DEFAULTS.refreshDelaySeconds
    if effectiveDelay > 0 then
        effectiveDelay = math.max(effectiveDelay, TRACKER_DEFAULTS.refreshDelaySeconds)
    end

    C_Timer.After(effectiveDelay, function()
        if trackerFrame and runtimeState.trackerRefreshToken == token then
            RefreshTrackerNow()
        end
    end)
end

_G.YayaWeeklyTrackerAutoOpen = _G.YayaWeeklyTrackerAutoOpen or {}
_G.YayaWeeklyTrackerAutoOpen.GetActionButton = function()
    return trackerFrame and trackerFrame.autoOpenButton or nil
end
_G.YayaWeeklyTrackerAutoOpen.RequestTrackerRefresh = function()
    ScheduleTrackerRefresh(0, false)
end

trackerUI.FinishTradeSkillBootstrap = function()
    if not runtimeState.tradeSkillBootstrapPending then
        return
    end

    runtimeState.tradeSkillBootstrapPending = false
    if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.CloseTradeSkill) == "function" then
        pcall(C_TradeSkillUI.CloseTradeSkill)
    end
    InvalidateTrackedMidnightProfessions()
    DebugLog("TradeSkill bootstrap ferme")
    ScheduleTrackerRefresh(0.05, true)
end

trackerUI.ArmTradeSkillBootstrap = function(frame)
    local trackedRows = GetTrackedMidnightProfessions()
    if trackedRows and #trackedRows > 0 then
        if runtimeState.tradeSkillBootstrapArmed then
            frame:SetScript("OnKeyDown", nil)
            runtimeState.tradeSkillBootstrapArmed = false
        end
        return false
    end

    if runtimeState.tradeSkillBootstrapAttempted
        or runtimeState.tradeSkillBootstrapPending
        or runtimeState.tradeSkillBootstrapArmed
        or _G.ForceLoadTradeSkillData
        or (UnitLevel and UnitLevel("player") or 0) < runtimeState.minimumMidnightProfessionLevel
        or not GetProfessions
        or not GetProfessionInfo
        or type(C_TradeSkillUI) ~= "table"
        or type(C_TradeSkillUI.OpenTradeSkill) ~= "function" then
        return false
    end

    local professionIndices = { GetProfessions() }
    for _, professionIndex in ipairs(professionIndices) do
        if professionIndex then
            local _, _, skillLevel, _, _, _, professionID = GetProfessionInfo(professionIndex)
            if professionID
                and runtimeState.baseProfessionToMidnightSkillLineID[professionID]
                and (skillLevel or 0) > 0 then
                runtimeState.tradeSkillBootstrapArmed = true
                runtimeState.tradeSkillBootstrapProfessionID = professionID
                frame:SetPropagateKeyboardInput(true)
                frame:SetScript("OnKeyDown", function(self)
                    if InCombatLockdown and InCombatLockdown() then
                        return
                    end

                    self:SetScript("OnKeyDown", nil)
                    runtimeState.tradeSkillBootstrapArmed = false
                    runtimeState.tradeSkillBootstrapAttempted = true
                    runtimeState.tradeSkillBootstrapPending = true
                    local ok, err = pcall(
                        C_TradeSkillUI.OpenTradeSkill,
                        runtimeState.tradeSkillBootstrapProfessionID
                    )
                    if not ok then
                        runtimeState.tradeSkillBootstrapPending = false
                        DebugLog(
                            "TradeSkill bootstrap echec id=%s: %s",
                            tostring(runtimeState.tradeSkillBootstrapProfessionID),
                            tostring(err)
                        )
                        return
                    end

                    DebugLog(
                        "TradeSkill bootstrap ouvre id=%s",
                        tostring(runtimeState.tradeSkillBootstrapProfessionID)
                    )
                    if C_Timer and C_Timer.After then
                        C_Timer.After(2, trackerUI.FinishTradeSkillBootstrap)
                    end
                end)
                DebugLog("TradeSkill bootstrap arme id=%s", tostring(professionID))
                return true
            end
        end
    end

    return false
end

local function IsUnsafeChatMessage(value)
    return type(value) ~= "string" or (issecretvalue and issecretvalue(value))
end

local function CaptureActiveCacheMessage(event, message)
    if not activeCacheOpen or IsUnsafeChatMessage(message) or message == "" then
        return
    end

    activeCacheOpen.lootMessages = activeCacheOpen.lootMessages or {}
    activeCacheOpen.lootMessages[#activeCacheOpen.lootMessages + 1] = {
        event = event,
        message = message,
    }
end

local function StartNzothCacheTracking(cacheItemID)
    if activeCacheOpen then
        FinalizeActiveCacheOpen()
    end

    local pending = PopPendingNzothCache(cacheItemID) or BuildFallbackCacheSource(cacheItemID)
    pending.questTitle = pending.questTitle or (pending.questID and GetQuestTitle(pending.questID) or nil)
    local questLog = GetQuestLogSnapshot()

    activeCacheOpen = {
        cacheItemID = cacheItemID,
        openedAt = GetNow(),
        openedDate = date and date("%Y-%m-%d %H:%M:%S") or nil,
        player = GetPlayerSnapshot(),
        location = GetLocationSnapshot(),
        source = pending,
        cloak = GetCloakSnapshot(),
        legendaryCloak = GetLegendaryCloakSnapshot(questLog),
        heartOfAzeroth = GetHeartOfAzerothSnapshot(),
        questProgress = BuildQuestProgressSnapshot(questLog),
        questLog = questLog,
        raid = GetNyalothaRaidSnapshot(),
        before = {
            currencies = BuildCurrencySnapshot(),
        },
    }

    ScheduleFinalizeActiveCacheOpen(1)
end

GetContainerItemIDCompat = function(bagID, slotIndex)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = SafeCall(C_Container.GetContainerItemInfo, bagID, slotIndex)
        if info and info.itemID then
            return tonumber(info.itemID) or info.itemID
        end

        local link = info and info.hyperlink or nil
        if not link and C_Container.GetContainerItemLink then
            link = SafeCall(C_Container.GetContainerItemLink, bagID, slotIndex)
        end
        if link then
            if C_Item and C_Item.GetItemInfoInstant then
                local itemID = SafeCall(C_Item.GetItemInfoInstant, link)
                if itemID then
                    return tonumber(itemID) or itemID
                end
            end
            if GetItemInfoInstant then
                local itemID = SafeCall(GetItemInfoInstant, link)
                if itemID then
                    return tonumber(itemID) or itemID
                end
            end
        end
    end

    if GetContainerItemLink then
        local link = SafeCall(GetContainerItemLink, bagID, slotIndex)
        if link then
            if C_Item and C_Item.GetItemInfoInstant then
                local itemID = SafeCall(C_Item.GetItemInfoInstant, link)
                if itemID then
                    return tonumber(itemID) or itemID
                end
            end
            if GetItemInfoInstant then
                local itemID = SafeCall(GetItemInfoInstant, link)
                if itemID then
                    return tonumber(itemID) or itemID
                end
            end
        end
    end
end

local function OnContainerItemUsed(bagID, slotIndex)
    local itemID = GetContainerItemIDCompat(bagID, slotIndex)
    if TRACKED_ASSAULT_CACHE_ITEM_IDS[itemID] then
        StartNzothCacheTracking(itemID)
    end
end

local function HookCacheItemUse()
    if not hooksecurefunc then
        return
    end

    if C_Container and C_Container.UseContainerItem then
        hooksecurefunc(C_Container, "UseContainerItem", OnContainerItemUsed)
        return
    end

    if UseContainerItem then
        hooksecurefunc("UseContainerItem", OnContainerItemUsed)
    end
end

AddEntry = function(entries, label, state, options)
    if not state then
        return
    end

    local entry = {
        label = label,
        state = state,
    }
    if options then
        for key, value in pairs(options) do
            entry[key] = value
        end
    end

    entries[#entries + 1] = entry
end

trackerUI.FindActiveMidnightShowdownWorldBoss = function(activeByQuestID)
    local bosses = runtimeState.generalWeeklyQuests.midnightShowdownWorldBosses
    local completedQuestID
    local completedBossName

    for _, boss in ipairs(bosses or EMPTY_TABLE) do
        for _, questID in ipairs(boss.questIDs or EMPTY_TABLE) do
            if IsQuestActiveOnMap(questID, activeByQuestID) then
                if not IsQuestDone(questID) then
                    return questID, boss.name
                end
                completedQuestID = completedQuestID or questID
                completedBossName = completedBossName or boss.name
            end
        end
    end

    return completedQuestID, completedBossName
end

trackerUI.AddMidnightSeasonalResourceEntry = function(entries, resource, accountDB)
    if type(resource) ~= "table"
        or type(accountDB) ~= "table"
        or accountDB[resource.optionKey] == false then
        return
    end

    local minimumLevel = tonumber(resource.minimumLevel)
    if minimumLevel and (UnitLevel and UnitLevel("player") or 0) < minimumLevel then
        return
    end

    local minimumItemLevel = tonumber(resource.minimumItemLevel)
    if minimumItemLevel then
        local averageItemLevel, equippedItemLevel
        if GetAverageItemLevel then
            averageItemLevel, equippedItemLevel = GetAverageItemLevel()
        end
        equippedItemLevel = tonumber(equippedItemLevel)
        if not equippedItemLevel or equippedItemLevel <= 0 then
            equippedItemLevel = tonumber(averageItemLevel) or 0
        end
        if equippedItemLevel < minimumItemLevel then
            return
        end
    end

    local status = trackerUI.GetMidnightSeasonalResourceStatus(resource)
    if not status then
        return
    end

    if status.acquired < status.maximum then
        AddEntry(entries, resource.label, "todo", {
            displayText = ("%s: %s"):format(
                resource.label,
                trackerUI.FormatMidnightSeasonalResourceCount(status.acquired, status.maximum)
            ),
        })
    elseif status.available > 0 then
        AddEntry(entries, resource.label, "todo", {
            displayText = ("%s: %s"):format(
                resource.label,
                trackerUI.FormatMidnightSeasonalResourceCount(status.maximum, status.maximum)
            ),
        })
    end
end

trackerUI.AddGeneralWeeklyEntries = function(entries, activeByQuestID)
    local level = UnitLevel and UnitLevel("player") or 0
    local config = runtimeState.generalWeeklyQuests
    local accountDB = GetAccountDB()

    local seasonalResources = runtimeState.midnightSeasonalResourceTracking
    trackerUI.AddMidnightSeasonalResourceEntry(
        entries,
        seasonalResources and seasonalResources.sparksOfTides,
        accountDB
    )

    if accountDB.trackAbundance ~= false
        and level >= runtimeState.minimumMidnightProfessionLevel
        and not IsAnyQuestDone(config.abundanceQuestIDs) then
        AddEntry(entries, "Abondance", "todo")
    end

    local shardQuantity = GetCurrencyQuantity(runtimeState.midnightShardOfDundunCurrencyID)
    if level >= runtimeState.minimumMidnightAbundanceLevel
        and shardQuantity >= runtimeState.midnightShardOfDundunCap then
        AddEntry(entries, "Shard of Dundun", "todo", {
            displayText = ("Shard of Dundun: |cffff6666%d/%d a depenser|r"):format(
                shardQuantity,
                runtimeState.midnightShardOfDundunCap
            ),
        })
    end

    if accountDB.trackHaranirLegends ~= false
        and level >= 80
        and not IsAnyQuestDone(config.haranirLegendsQuestIDs) then
        AddEntry(entries, "Lost Legends", "todo")
    end

    if accountDB.trackResearchingVoidstorm ~= false
        and level >= 80
        and IsQuestActiveOnMap(config.researchConsoleQuestID, activeByQuestID)
        and not IsQuestDone(config.researchConsoleQuestID) then
        AddEntry(entries, "Research Console: Exploring the Void", "todo")
    end

    if level < 90 then
        return
    end

    if accountDB.trackMidnightShowdownWorldBoss ~= false then
        local showdownQuestID, showdownBossName = trackerUI.FindActiveMidnightShowdownWorldBoss(activeByQuestID)
        if showdownQuestID and not IsQuestDone(showdownQuestID) then
            AddEntry(entries, showdownBossName or GetQuestTitle(showdownQuestID) or "World boss Val/Naigtal", "todo")
        end
    end

    local activeLiadrinQuestID = FindActiveQuest(config.liadrinWeeklyQuestIDs, activeByQuestID)
    local worldBossQuestID = FindActiveQuest(config.midnightWorldBossQuestIDs, activeByQuestID)
    if worldBossQuestID and not IsQuestDone(worldBossQuestID) then
        local rewardMoney = GetQuestRewardMoney(worldBossQuestID)
        local averageItemLevel, equippedItemLevel = 0, 0
        if GetAverageItemLevel then
            averageItemLevel, equippedItemLevel = GetAverageItemLevel()
        end
        equippedItemLevel = equippedItemLevel or averageItemLevel or 0

        if rewardMoney <= 0 then
            RequestQuestRewardData(worldBossQuestID)
        end

        local isLiadrinWorldBossTracked = accountDB.trackLiadrin ~= false
            and activeLiadrinQuestID == config.liadrinWorldBossQuestID
        local shouldTrackForGold = accountDB.trackWorldBossGold ~= false and rewardMoney > 0
        local shouldTrackForItemLevel = accountDB.trackWorldBossItemLevel ~= false
            and equippedItemLevel > 0
            and equippedItemLevel < config.worldBossMaxUsefulItemLevel

        if isLiadrinWorldBossTracked or shouldTrackForGold or shouldTrackForItemLevel then
            if rewardMoney > 0 then
                local gold = math.floor((rewardMoney / 10000) + 0.5)
                AddEntry(entries, (GetQuestTitle(worldBossQuestID) or "World boss Midnight") .. " " .. gold .. "g", "todo")
            else
                AddEntry(entries, GetQuestTitle(worldBossQuestID) or "World boss Midnight", "todo")
            end
        end
    end

    if accountDB.trackSoiree ~= false and not IsAnyQuestDone(config.runestoneQuestIDs) then
        AddEntry(entries, "Defense des runestones", "todo")
    end

    if IsQuestActiveOnMap(config.halduronWorldQuestID, activeByQuestID)
        and not IsQuestDone(config.halduronWorldQuestID) then
        AddEntry(entries, "Halduron: World Quests", "todo")
    end

    if accountDB.trackNeighborhood ~= false
        and not trackerUI.IsAnyQuestDoneOnAccount(config.neighborhoodWeeklyQuestIDs) then
        local activeNeighborhoodQuestID = FindActiveQuest(config.neighborhoodWeeklyActiveQuestIDs, activeByQuestID)
        local label = "Weekly Neighborhood"
        if activeNeighborhoodQuestID then
            local activeQuest = activeByQuestID and activeByQuestID[activeNeighborhoodQuestID]
            label = "Neighborhood: " .. ((activeQuest and activeQuest.title) or GetQuestTitle(activeNeighborhoodQuestID) or "weekly")
        end
        AddEntry(entries, label, "todo")
    end

    local isLiadrinWeeklyActive = activeLiadrinQuestID
        or IsQuestActiveOnMap(config.liadrinWrapperQuestID, activeByQuestID)
    if accountDB.trackLiadrin ~= false
        and isLiadrinWeeklyActive
        and not IsQuestDone(config.liadrinWrapperQuestID)
        and not IsAnyQuestDone(config.liadrinWeeklyQuestIDs) then
        local label = "Weekly Liadrin"
        if activeLiadrinQuestID then
            local activeQuest = activeByQuestID and activeByQuestID[activeLiadrinQuestID]
            label = "Liadrin: " .. ((activeQuest and activeQuest.title) or GetQuestTitle(activeLiadrinQuestID) or "weekly")
        end
        AddEntry(entries, label, "todo")
    end
end

trackerUI.BuildEntries = function(trackedRows)
    local entries = {}
    local questLog = GetQuestLogSnapshot()
    local activeByQuestID = BuildQuestLogLookups(questLog)

    if IsLegionArchaeologyGoldQuestAvailable(activeByQuestID) then
        AddEntry(entries, LEGION_ARCHAEOLOGY_GOLD_LABEL, "todo", {
            prominent = true,
            displayText = LEGION_ARCHAEOLOGY_GOLD_LABEL,
        })
    end

    -- Ligne hebdo masquee pour le moment.
    -- local majorQuestID = FindActiveQuest(NZOTH_MAJOR_ASSAULTS)
    -- if not IsQuestDone(NZOTH_UNLOCK_QUEST_ID) then
    --     AddEntry(entries, "Visions N'Zoth (hebdo)", "locked")
    -- elseif majorQuestID and not IsQuestDone(majorQuestID) then
    --     AddEntry(entries, "Visions N'Zoth (hebdo)", "todo")
    -- end

    -- Ligne bi-hebdo masquee pour le moment.
    -- local minorQuestID = FindActiveQuest(NZOTH_MINOR_ASSAULTS)
    -- if not IsQuestDone(NZOTH_UNLOCK_QUEST_ID) then
    --     AddEntry(entries, "Visions N'Zoth (bi-hebdo)", "locked")
    -- elseif minorQuestID and not IsQuestDone(minorQuestID) then
    --     AddEntry(entries, "Visions N'Zoth (bi-hebdo)", "todo")
    -- end

    local weeklyEntries = {}
    local oneTimeEntries = {}

    AddReplenishTheReservoirEntry(weeklyEntries, activeByQuestID)

    if HasJardRecipe() and GetRemainingSpellCooldown(JARD_SPELL_ID) <= 0 then
        AddEntry(weeklyEntries, "Jard", "todo")
    end

    if IsQuestActiveOnMap(CONTAINING_THE_HELSWORN_QUEST_ID, activeByQuestID)
        and HasFlatGoldQuestReward(CONTAINING_THE_HELSWORN_QUEST_ID) then
        if not IsQuestDone(VICTORY_IN_OUR_NAME_QUEST_ID) then
            AddEntry(weeklyEntries, CONTAINING_THE_HELSWORN_LABEL, "locked")
        elseif not IsQuestDone(CONTAINING_THE_HELSWORN_QUEST_ID) then
            AddEntry(weeklyEntries, CONTAINING_THE_HELSWORN_LABEL, "todo")
        end
    end

    if SafeCall(C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards) == true then
        AddEntry(weeklyEntries, "Great Vault", "todo", {
            displayText = "Great Vault: |cffff6666a ouvrir|r",
        })
    end

    trackerUI.AddGeneralWeeklyEntries(weeklyEntries, activeByQuestID)

    trackerUI.AddMidnightProfessionEntries(weeklyEntries, trackedRows, oneTimeEntries)

    if #weeklyEntries > 0 then
        for _, entry in ipairs(weeklyEntries) do
            entries[#entries + 1] = entry
        end
    end

    if #oneTimeEntries > 0 then
        AddEntry(entries, "One time", "todo", {
            prominent = true,
            displayText = "|cffd6b36aOne time|r",
            satisfied = true,
        })
        for _, entry in ipairs(oneTimeEntries) do
            entries[#entries + 1] = entry
        end
    end

    local level = UnitLevel and UnitLevel("player") or 0
    if level >= runtimeState.minimumMidnightProfessionLevel and trackedRows and #trackedRows == 0 then
        local displayText = "Midnight: |cffff6666aucun metier detecte|r"
        if HasLearnedMidnightBaseProfession() then
            displayText = "Midnight: |cffffcc66ouvre les metiers pour charger les infos manquantes|r"
        end

        AddEntry(entries, "Midnight", "locked", {
            displayText = displayText,
        })
    end

    return entries
end

trackerUI.EnsureTrackerLine = function(index)
    if trackerFrame.lines[index] then
        return trackerFrame.lines[index]
    end

    -- Une entree etait un simple FontString large de 178 px : ni fond, ni
    -- survol, ni infobulle, ni garde de debordement, et le libelle colle a son
    -- statut dans une seule chaine alignee a gauche.
    local row = YayaCore.UI.CreateRow(trackerFrame, {
        height = YayaCore.UI.SIZE.rowHCompact,
        labelFont = YayaCore.UI.FONT.body,
        valueFont = YayaCore.UI.FONT.body,
        tooltipAnchor = "ANCHOR_LEFT",
    })
    trackerFrame.lines[index] = row
    return row
end

--- Largeur utile du libelle d'une ligne du tracker.
--
-- La largeur vient des ancres que YayaFrame pose sur la section : elle n'est
-- pas resolue au tout premier passage, ou trackerFrame vaut encore 1x1. Le
-- repli donne alors la meme valeur qu'en regime permanent, donc le premier
-- rendu n'est pas faux.
trackerUI.GetTrackerLabelWidth = function()
    local width = YayaCore.UI.ResolveWidth(trackerFrame, YayaCore.UI.SIZE.contentW)
    return math.max(40, math.floor(width - YayaCore.UI.PAD.md * 2 - YayaCore.UI.PAD.sm))
end

--- Peint une entree sur sa ligne et rend la hauteur a reserver, en entier.
--
-- CRITIQUE AUTOCLICKER. Cette valeur est posee sur la ligne ET donnee a la
-- pile : les deux ne peuvent donc pas diverger, et le bord bas de la frame ne
-- bouge pas d'un pixel quand une ligne grandit. Un depassement visuel residuel
-- est absorbe par le clipping deja actif sur la ligne.
trackerUI.ApplyEntry = function(row, entry, index)
    row.Reset()
    row.SetStripe(index)

    local font = entry.prominent and YayaCore.UI.FONT.header or YayaCore.UI.FONT.body
    YayaCore.UI.SetFont(row.label, font)
    row.label:SetTextColor(YayaCore.UI.Unpack(
        entry.prominent and YayaCore.UI.COLOR.category or YayaCore.UI.COLOR.text))

    local height = YayaCore.UI.SIZE.rowHCompact
    if entry.prominent then
        height = height + YayaCore.UI.PAD.sm
    end

    -- Resume de metier : plusieurs jetons pour une ligne de 176 px utiles. Le
    -- texte est decoupe ici, ou la largeur est connue, et le detail complet
    -- part en infobulle.
    if entry.tokens then
        local width = trackerUI.GetTrackerLabelWidth()
        row.SetLabelWrap(YayaCore.UI.TEXT.maxLines, width)
        local composed, lines, hidden = YayaCore.UI.PackLines(entry.tokens, {
            width = width,
            maxLines = YayaCore.UI.TEXT.maxLines,
            prefix = entry.prefix,
            font = font,
        })
        local textHeight = YayaCore.UI.FitLabel(
            row.label, composed, lines, YayaCore.UI.TEXT.maxLines)
        row.value:SetText("")
        row.hiddenTokenCount = hidden
        row.SetTooltip(entry.tooltipTitle, entry.tooltipBody)
        return math.max(height, textHeight + YayaCore.UI.PAD.sm)
    end

    row.SetLabelWrap(1)

    -- Les entrees a texte compose gardent leur balisage : elles portent deja
    -- leurs propres couleurs et compteurs.
    if entry.displayText then
        row.label:SetText(entry.displayText)
        row.value:SetText("")
        row.SetTruncatedTooltip(YayaCore.UI.StripMarkup(entry.displayText))
        return height
    end

    row.label:SetText(entry.label or "")
    if entry.state == "todo" then
        row.value:SetText("a faire")
        row.SetTone("success")
    else
        row.value:SetText("a debloquer")
        row.SetTone("warning")
    end
    if entry.tooltipTitle then
        row.SetTooltip(entry.tooltipTitle, entry.tooltipBody)
    else
        row.SetTruncatedTooltip(YayaCore.UI.StripMarkup(entry.label))
    end
    return height
end

-- Les boutons d'action, par champ et par reservoir. Declares en champs de table
-- plutot qu'en locals : le chunk est a deux variables de la limite des 200 que
-- Lua 5.1 autorise, et la depasser empeche l'addon entier de charger.
trackerUI.actionButtonFields = {
    "payoutButton",
    "knowledgeButton",
    "recipeButton",
    "recipeMarlButton",
    "treasureButton",
    "professionSupplyButton",
    "autoOpenButton",
}

trackerUI.actionButtonPools = {
    "surplusReagentButtons",
    "finishingReagentMergeButtons",
    "toolEnchantApplyButtons",
}

--- Masque tout le contenu de la section, pour le repli.
trackerUI.HideAllWidgets = function()
    -- Les boutons sont securises : les masquer en combat est interdit. Les
    -- lignes ne le sont pas, donc elles disparaissent quand meme.
    local locked = InCombatLockdown and InCombatLockdown()
    for _, field in ipairs(locked and {} or trackerUI.actionButtonFields) do
        local button = trackerFrame[field]
        if button then
            button:Hide()
        end
    end
    for _, field in ipairs(locked and {} or trackerUI.actionButtonPools) do
        for _, button in ipairs(trackerFrame[field] or {}) do
            button:Hide()
        end
    end
    for _, row in ipairs(trackerFrame.lines or {}) do
        row.Reset()
        row:Hide()
    end
end

trackerUI.SavePosition = function()
    if YayaFrameAPI and type(YayaFrameAPI.SavePosition) == "function" then
        YayaFrameAPI:SavePosition()
    end
end

trackerUI.ApplyPosition = function()
    if YayaFrameAPI and type(YayaFrameAPI.ApplyPosition) == "function" then
        YayaFrameAPI:ApplyPosition()
    end
end

trackerUI.ResetPosition = function()
    if YayaFrameAPI and type(YayaFrameAPI.ResetPosition) == "function" then
        YayaFrameAPI:ResetPosition()
    end
end

trackerUI.ApplyCombatVisibility = function()
    if not YayaFrameAPI or type(YayaFrameAPI.SetHideInCombat) ~= "function" then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        runtimeState.combatVisibilityUpdateDeferred = true
        return
    end

    runtimeState.combatVisibilityUpdateDeferred = false
    YayaFrameAPI:SetHideInCombat(GetAccountDB().hideInCombat == true)
end

trackerUI.RegisterOptions = function()
    if runtimeState.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = "Yaya Weekly Tracker"

    local scrollFrame = CreateFrame(
        "ScrollFrame",
        addonName .. "OptionsScrollFrame",
        panel,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)
    local scrollChild = CreateFrame("Frame", addonName .. "OptionsScrollChild", scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.optionsScrollFrame = scrollFrame
    panel.optionsScrollChild = scrollChild

    -- L'empilement remplace la chaine d'ancres ou chaque controle nommait son
    -- predecesseur : la hauteur du contenu devient une somme, connue tout de
    -- suite, au lieu d'une mesure GetTop/GetBottom indisponible avant le
    -- premier rendu et qui retombait sur un repli de six cents pixels.
    local stack = YayaCore.UI.StackLayout(scrollChild, {
        left = YayaCore.UI.PAD.xl,
        top = YayaCore.UI.PAD.xl,
    })

    local title = scrollChild:CreateFontString(nil, "ARTWORK", YayaCore.UI.FONT.heading)
    title:SetText(panel.name)
    stack.Add(title, 0, { height = YayaCore.UI.SIZE.headerH, stretch = false })

    local description = scrollChild:CreateFontString(nil, "ARTWORK", YayaCore.UI.FONT.body)
    description:SetText("Reglages partages par tout le compte.")
    stack.Add(description, YayaCore.UI.PAD.sm,
        { height = YayaCore.UI.SIZE.rowHCompact, stretch = false })

    local function AddSection(titleText)
        local section = scrollChild:CreateFontString(nil, "ARTWORK", YayaCore.UI.FONT.header)
        section:SetText(titleText)
        section:SetTextColor(YayaCore.UI.Unpack(YayaCore.UI.COLOR.category))
        YayaCore.UI.BoundLabel(section, "LEFT")
        stack.Add(section, YayaCore.UI.PAD.lg,
            { height = YayaCore.UI.SIZE.rowHCompact, stretch = false })

        local divider = YayaCore.UI.CreateDivider(scrollChild)
        divider:SetPoint("LEFT", section, "RIGHT", YayaCore.UI.PAD.md, 0)
        divider:SetPoint("RIGHT", scrollChild, "RIGHT", -YayaCore.UI.PAD.xl, 0)
        return section
    end

    AddSection("Affichage")

    local checkbox = YayaCore.UI.CreateCheckbox(scrollChild,
        "Cacher integralement la frame en combat", {
            name = addonName .. "HideInCombatCheckbox",
            onClick = function(checked)
                GetAccountDB().hideInCombat = checked
                trackerUI.ApplyCombatVisibility()
            end,
        })
    stack.Add(checkbox, YayaCore.UI.PAD.sm,
        { height = YayaCore.UI.SIZE.headerH, stretch = false })

    panel.trackingCheckboxes = {}
    local previousCategory
    for index, option in ipairs(runtimeState.trackingOptions) do
        if option.category ~= previousCategory then
            previousCategory = option.category
            AddSection(option.category)
        end

        local trackingCheckbox = YayaCore.UI.CreateCheckbox(scrollChild, option.label, {
            name = addonName .. "TrackingCheckbox" .. index,
            onClick = function(checked, self)
                GetAccountDB()[self.optionKey] = checked
                if self.optionKey == "autoOpenContainers"
                    and _G.YayaWeeklyTrackerAutoOpen
                    and type(_G.YayaWeeklyTrackerAutoOpen.Refresh) == "function"
                then
                    _G.YayaWeeklyTrackerAutoOpen.Refresh()
                end
                ScheduleTrackerRefresh(0, false)
            end,
        })
        trackingCheckbox.optionKey = option.key
        stack.Add(trackingCheckbox, YayaCore.UI.PAD.sm,
            { height = YayaCore.UI.SIZE.headerH, stretch = false })
        panel.trackingCheckboxes[index] = trackingCheckbox
    end

    local contentHeight = stack.Finish(YayaCore.UI.PAD.xl)

    local function UpdateScrollChildSize()
        local width = scrollFrame:GetWidth() or 0
        if width > 0 then
            scrollChild:SetWidth(width)
        end
        scrollChild:SetHeight(contentHeight)
    end
    scrollFrame:SetScript("OnSizeChanged", UpdateScrollChildSize)

    panel:SetScript("OnShow", function()
        UpdateScrollChildSize()
        local accountDB = GetAccountDB()
        checkbox:SetChecked(accountDB.hideInCombat)
        for _, trackingCheckbox in ipairs(panel.trackingCheckboxes) do
            trackingCheckbox:SetChecked(accountDB[trackingCheckbox.optionKey] ~= false)
        end
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        runtimeState.optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(runtimeState.optionsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    runtimeState.optionsPanel = panel
end

runtimeState.ensureVisibleDefaultPosition = function()
    if not trackerFrame or not trackerFrame.GetCenter then
        return
    end

    local centerX, centerY = trackerFrame:GetCenter()
    local screenWidth = UIParent and UIParent:GetWidth() or 0
    local screenHeight = UIParent and UIParent:GetHeight() or 0
    DebugLog(
        "EnsureVisible center=%s,%s screen=%s,%s",
        tostring(centerX),
        tostring(centerY),
        tostring(screenWidth),
        tostring(screenHeight)
    )
    if centerX and centerY and centerX > 0 and centerY > 0 and centerX < screenWidth and centerY < screenHeight then
        return
    end

    DebugLog("EnsureVisible reset position triggered")
    trackerUI.ResetPosition()
end

runtimeState.showTrackerDiagnostic = function(message)
    DebugLog("ShowTrackerDiagnostic %s", tostring(message))
    runtimeState.ensureVisibleDefaultPosition()
    trackerFrame:Show()
    trackerUI.HideAllWidgets()

    -- Le titre vit desormais dans le bandeau de section tenu par YayaFrame :
    -- la section n'a plus a le redessiner.
    local row = trackerUI.EnsureTrackerLine(1)
    YayaCore.UI.SetFont(row.label, YayaCore.UI.FONT.body)
    row.label:SetTextColor(YayaCore.UI.Unpack(YayaCore.UI.COLOR.danger))
    row.label:SetText(message or "YWT: erreur")
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", trackerFrame, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", trackerFrame, "TOPRIGHT", 0, 0)
    row:Show()

    trackerFrame:SetHeight(YayaCore.UI.SIZE.rowHCompact + YayaCore.UI.PAD.xs)
    if YayaFrameAPI and type(YayaFrameAPI.Refresh) == "function" then
        YayaFrameAPI:Refresh()
    end
end

UpdateTracker = function()
    if InCombatLockdown and InCombatLockdown() then
        runtimeState.trackerRefreshDeferredByCombat = true
        return
    end

    local ok, err = pcall(function()
        runtimeState.ensureVisibleDefaultPosition()

        local trackedRows = GetTrackedMidnightProfessions()
        local entries = trackerUI.BuildEntries(trackedRows)
        local knowledgeItemState = DebugSafeCall("FindMidnightKnowledgeConsumableInBags", FindMidnightKnowledgeConsumableInBags, trackedRows)
        local recipeItemState = DebugSafeCall("FindMidnightRecipeInBags", trackerUI.FindMidnightRecipeInBags, trackedRows)
        local payoutItemState = DebugSafeCall("FindArtisanConsortiumPayoutInBags", FindArtisanConsortiumPayoutInBags)
        local surplusReagentStates = DebugSafeCall("FindSurplusReagentContainersInBags", trackerUI.FindSurplusReagentContainersInBags)
        local finishingReagentMergeStates = DebugSafeCall("FindMergeableFinishingReagentsInBags", trackerUI.FindMergeableFinishingReagentsInBags)
        local hasKnowledgeButton = DebugSafeCall("UpdateMidnightKnowledgeButton", trackerUI.UpdateMidnightKnowledgeButton, knowledgeItemState) or false
        local hasRecipeButton = DebugSafeCall("UpdateMidnightRecipeButton", trackerUI.UpdateMidnightRecipeButton, recipeItemState) or false
        local hasRecipeMarlButton = DebugSafeCall("UpdateMidnightRecipeTransferButton", trackerUI.UpdateMidnightRecipeTransferButton, trackedRows) or false
        local hasPayoutButton = DebugSafeCall("UpdateArtisanConsortiumPayoutButton", trackerUI.UpdateArtisanConsortiumPayoutButton, payoutItemState) or false
        local surplusButtonCount = DebugSafeCall("UpdateSurplusReagentButtons", trackerUI.UpdateSurplusReagentButtons, surplusReagentStates) or 0
        local finishingReagentMergeButtonCount = DebugSafeCall("UpdateFinishingReagentMergeButtons", trackerUI.UpdateFinishingReagentMergeButtons, finishingReagentMergeStates) or 0
        DebugSafeCall("EnsureEnchantingWeeklyQueueItem", trackerUI.EnsureEnchantingWeeklyQueueItem, trackedRows)
        local hasTreasureButton = DebugSafeCall("UpdateMidnightTreasureButton", trackerUI.UpdateMidnightTreasureButton, trackedRows) or false
        local accountDB = GetAccountDB()
        -- L'instantane de la Warbank se rafraichit AVANT le scan d'outils et
        -- le plan qui en decoule : sinon la premiere passe apres l'ouverture de
        -- la banque bati son plan sur l'instantane precedent.
        DebugSafeCall("WarbankRefresh", trackerUI.warbank.Refresh)
        local trackProfessionGear = accountDB.trackProfessionGear ~= false
        local toolEnchantState
        if trackProfessionGear then
            toolEnchantState = DebugSafeCall("FindToolEnchantState", trackerUI.FindToolEnchantState, trackedRows)
        end
        if toolEnchantState then
            DebugSafeCall(
                "ConfirmToolEnchantApplications",
                trackerUI.ConfirmToolEnchantApplications,
                toolEnchantState
            )
        end
        local toolEnchantApplyButtonCount = DebugSafeCall(
            "UpdateToolEnchantApplyButtons",
            trackerUI.UpdateToolEnchantApplyButtons,
            toolEnchantState
        ) or 0
        local hasSupplyButton = DebugSafeCall(
            "UpdateProfessionSupplyButton",
            trackerUI.UpdateProfessionSupplyButton,
            trackProfessionGear
                and DebugSafeCall(
                    "BuildProfessionSupplyPlan",
                    trackerUI.BuildProfessionSupplyPlan,
                    trackedRows)
                or nil
        ) or false
        local autoOpenApi = _G.YayaWeeklyTrackerAutoOpen
        local autoOpenButton = autoOpenApi
            and type(autoOpenApi.GetActionButton) == "function"
            and autoOpenApi.GetActionButton()
            or nil
        -- La visibilite est deduite de l'etat du module, pas de IsShown().
        -- Lire IsShown() creait une dependance circulaire : le module montrait le
        -- bouton, demandait un rafraichissement, et cette passe decouvrait un
        -- bouton visible mais sans ancrage. Chaque bascule masquait aussi toute
        -- la section, d'ou le bouton qui apparaissait, disparaissait, puis
        -- sautait d'un cran.
        local autoOpenCandidate = nil
        if autoOpenApi and type(autoOpenApi.GetPendingCandidate) == "function" then
            local ok, candidate = pcall(autoOpenApi.GetPendingCandidate)
            autoOpenCandidate = ok and candidate or nil
        end
        local hasAutoOpenButton = (autoOpenButton ~= nil and autoOpenCandidate ~= nil) or false
        if autoOpenButton and not hasAutoOpenButton
            and not (InCombatLockdown and InCombatLockdown()) then
            autoOpenButton:Hide()
        end
        local trackerDebugSignature = ("%d|kp=%s|recipe=%s|marl=%s|po=%s|sr=%d|fm=%d|tt=%s|tea=%d|sup=%s|ao=%s"):format(#entries, tostring(hasKnowledgeButton), tostring(hasRecipeButton), tostring(hasRecipeMarlButton), tostring(hasPayoutButton), surplusButtonCount, finishingReagentMergeButtonCount, tostring(hasTreasureButton), toolEnchantApplyButtonCount, tostring(hasSupplyButton), tostring(hasAutoOpenButton))
        if trackerDebugSignature ~= debugSignatures.tracker then
            debugSignatures.tracker = trackerDebugSignature
            DebugLog("UpdateTracker entries=%d kpButton=%s recipeButton=%s marlButton=%s payoutButton=%s surplusButtons=%d mergeButtons=%d treasureButton=%s toolApply=%d supplyButton=%s autoOpen=%s", #entries, tostring(hasKnowledgeButton), tostring(hasRecipeButton), tostring(hasRecipeMarlButton), tostring(hasPayoutButton), surplusButtonCount, finishingReagentMergeButtonCount, tostring(hasTreasureButton), toolEnchantApplyButtonCount, tostring(hasSupplyButton), tostring(hasAutoOpenButton))
        end
        local hasUsefulEntry = false
        for _, entry in ipairs(entries) do
            if not entry.satisfied then
                hasUsefulEntry = true
                break
            end
        end
        if not hasUsefulEntry and not hasKnowledgeButton and not hasRecipeButton and not hasRecipeMarlButton and not hasPayoutButton and surplusButtonCount == 0 and finishingReagentMergeButtonCount == 0 and not hasTreasureButton and toolEnchantApplyButtonCount == 0 and not hasSupplyButton and not hasAutoOpenButton then
            DebugLog("UpdateTracker hide frame: all professions complete and no other actions")
            trackerFrame:Hide()
            if YayaFrameAPI and type(YayaFrameAPI.Refresh) == "function" then
                YayaFrameAPI:Refresh()
            end
            return
        end

        DebugLog("UpdateTracker show frame with %d entries", #entries)
        trackerFrame:Show()

        if trackerUI.collapsed then
            trackerUI.HideAllWidgets()
            trackerFrame:SetHeight(1)
            if YayaFrameAPI and type(YayaFrameAPI.Refresh) == "function" then
                YayaFrameAPI:Refresh()
            end
            DebugLog("UpdateTracker collapsed")
            return
        end

        -- Les widgets visibles sont collectes dans l'ordre d'affichage, puis
        -- empiles en une passe. Chaque bouton devait auparavant connaitre tous
        -- ses predecesseurs possibles : deux cents lignes de if/elseif ou
        -- l'ajout d'un bouton obligeait a reprendre tous les suivants.
        local stack = YayaCore.UI.StackLayout(trackerFrame)

        for index = 1, math.max(#entries, #trackerFrame.lines) do
            local row = trackerUI.EnsureTrackerLine(index)
            local entry = entries[index]
            if entry then
                -- Une seule source de verite pour la hauteur : la ligne et la
                -- pile recoivent le meme entier, donc elles ne peuvent pas
                -- diverger et deplacer les boutons.
                local rowHeight = trackerUI.ApplyEntry(row, entry, index)
                row:SetHeight(rowHeight)
                row:Show()
                stack.Add(row, 0, { height = rowHeight })
            else
                row.Reset()
                row:Hide()
            end
        end

        local actions = {}
        local function AddAction(button)
            if button then
                actions[#actions + 1] = button
            end
        end

        AddAction(hasPayoutButton and trackerFrame.payoutButton)
        AddAction(hasKnowledgeButton and trackerFrame.knowledgeButton)
        AddAction(hasRecipeButton and trackerFrame.recipeButton)
        AddAction(hasRecipeMarlButton and trackerFrame.recipeMarlButton)
        for index = 1, surplusButtonCount do
            AddAction(trackerFrame.surplusReagentButtons[index])
        end
        for index = 1, finishingReagentMergeButtonCount do
            AddAction(trackerFrame.finishingReagentMergeButtons[index])
        end
        AddAction(hasTreasureButton and trackerFrame.treasureButton)
        AddAction(hasSupplyButton and trackerFrame.professionSupplyButton)
        for index = 1, toolEnchantApplyButtonCount do
            AddAction(trackerFrame.toolEnchantApplyButtons[index])
        end
        AddAction(hasAutoOpenButton and autoOpenButton)
        trackerFrame.bindingActions = actions

        -- CRITIQUE AUTOCLICKER. La pile est packee depuis le bas, a pas
        -- constant : la frame est ancree BOTTOMLEFT et grandit vers le haut,
        -- donc le dernier bouton reste toujours a UI.ACTION.bottomMargin du bord
        -- inferieur. Un bouton qui disparait laisse sa place au suivant, au meme
        -- pixel, la ou pointe l'autoclicker. UI.ACTION est partage avec le
        -- panneau de YayaQueue pour que les deux frames alignent leurs slots.
        for index, button in ipairs(actions) do
            button:SetHeight(YayaCore.UI.ACTION.height)
            stack.Add(
                button,
                index == 1 and YayaCore.UI.PAD.xs or YayaCore.UI.ACTION.gap,
                { height = YayaCore.UI.ACTION.height }
            )
        end

        if hasAutoOpenButton and autoOpenButton
            and not (InCombatLockdown and InCombatLockdown()) then
            -- Ancre pose, on peut afficher : le bouton n'apparait jamais sans
            -- position. Le state driver [combat] hide reste maitre en combat.
            autoOpenButton:Show()
        end

        local height = stack.Finish(YayaCore.UI.ACTION.bottomMargin)
        trackerFrame:SetHeight(height)
        if YayaFrameAPI and type(YayaFrameAPI.Refresh) == "function" then
            YayaFrameAPI:Refresh()
        end
        DebugLog("UpdateTracker final height=%d", height)
    end)

    if not ok then
        DebugLog("UpdateTracker fatal: %s", tostring(err))
        runtimeState.LogFatalDiagnostic(err)
        runtimeState.showTrackerDiagnostic(
            ("YWT: %serreur, voir le chat ou /ywt log|r"):format(YayaCore.UI.HEX.danger))
    end
end

trackerUI.CreateTrackerFrame = function()
    if not YayaFrameAPI or type(YayaFrameAPI.GetFrame) ~= "function" then
        return
    end

    trackerFrame = CreateFrame("Frame", addonName .. "Frame", YayaFrameAPI:GetFrame())
    trackerFrame.bindingActions = {}
    YayaCore.ActionBinding.RegisterProvider("weekly", function()
        return nil, trackerFrame.bindingActions
    end)
    DebugLog("CreateTrackerFrame %s", tostring(addonName .. "Frame"))
    trackerFrame:SetFrameStrata("MEDIUM")
    -- Pas de largeur imposee : YayaFrame etire chaque section entre ses
    -- gouttieres. Le contenu tenait dans 184 px a gauche d'un conteneur de
    -- 200, donc la marge droite valait 16 px et la gauche 6.
    trackerFrame:SetSize(1, 1)
    trackerFrame:SetClampedToScreen(true)

    trackerFrame.containerActionVisibilityFrame = CreateFrame(
        "Frame",
        addonName .. "ContainerActionVisibilityFrame",
        trackerFrame
    )
    trackerFrame.containerActionVisibilityFrame:SetAllPoints(trackerFrame)
    if type(RegisterStateDriver) == "function" then
        RegisterStateDriver(trackerFrame.containerActionVisibilityFrame, "visibility", "[combat] hide; show")
    end

    -- Ni fond ni titre ici : le conteneur porte le fond, et le bandeau de
    -- section porte le titre. La section repeignait le meme noir a 55 % que
    -- YayaFrame, ce qui portait l'opacite reelle a environ 80 %.

    trackerFrame.knowledgeButton = CreateFrame("Button", addonName .. "KnowledgeButton", trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    trackerFrame.knowledgeButton:SetSize(178, YayaCore.UI.ACTION.height)
    trackerFrame.knowledgeButton:RegisterForClicks("AnyUp")
    trackerFrame.knowledgeButton:SetAttribute("useOnKeyDown", false)
    trackerFrame.knowledgeButton:SetText("Utiliser KP")
    trackerFrame.knowledgeButton:Hide()
    trackerFrame.knowledgeButton:HookScript("PreClick", function(self, _, down)
        if down then
            return
        end
        DebugLog(
            "KnowledgeButton click itemID=%s bag=%s slot=%s link=%s name=%s item=%s",
            tostring(self.itemID or "none"),
            tostring(self.bagID or "none"),
            tostring(self.slotIndex or "none"),
            tostring(self.itemLink or "none"),
            tostring(self.itemName or "none"),
            tostring(self:GetAttribute("item") or "none")
        )
    end)
    trackerFrame.knowledgeButton:SetScript("PostClick", function(self, _, down)
        if down then
            return
        end
        trackerUI.LockItemActionButton(self)
        InvalidateMidnightKnowledgeConsumableCache()
        trackerUI.RequestItemActionRefresh()
    end)
    trackerFrame.knowledgeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Utilise le prochain consommable de connaissance Midnight.")
        GameTooltip:AddLine("Le bouton ne prend que les items du ou des metiers Midnight du personnage.", 1, 1, 1, true)
        if self.itemLink then
            GameTooltip:AddLine(self.itemLink, 0.5, 0.8, 1, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.knowledgeButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.recipeButton = CreateFrame("Button", addonName .. "RecipeButton", trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    trackerFrame.recipeButton:SetSize(178, YayaCore.UI.ACTION.height)
    trackerFrame.recipeButton:RegisterForClicks("AnyUp")
    trackerFrame.recipeButton:SetAttribute("useOnKeyDown", false)
    trackerFrame.recipeButton:SetText("Utiliser recette")
    trackerFrame.recipeButton:Hide()
    trackerFrame.recipeButton:SetScript("PostClick", function(self, _, down)
        if down then
            return
        end
        trackerUI.LockItemActionButton(self)
        trackerUI.InvalidateMidnightRecipeItemCache()
        trackerUI.RequestItemActionRefresh()
    end)
    trackerFrame.recipeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Consomme la prochaine recette Midnight suivie présente dans les sacs.")
        if self.itemLink then
            GameTooltip:AddLine(self.itemLink, 0.5, 0.8, 1, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.recipeButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.recipeMarlButton = CreateFrame("Button", addonName .. "RecipeMarlButton", trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    trackerFrame.recipeMarlButton:SetSize(178, YayaCore.UI.ACTION.height)
    trackerFrame.recipeMarlButton:RegisterForClicks("AnyUp")
    trackerFrame.recipeMarlButton:SetAttribute("useOnKeyDown", false)
    trackerFrame.recipeMarlButton:SetText("Ouvrir interface marls")
    trackerFrame.recipeMarlButton:Hide()
    trackerFrame.recipeMarlButton:SetScript("PreClick", function(self, _, down)
        trackerUI.ResetMidnightRecipeTransferAction(self)
        if down then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        local tokenFrameShown = TokenFrame and type(TokenFrame.IsShown) == "function" and TokenFrame:IsShown()
        if runtimeState.midnightRecipeTransferRecoveryAvailable then
            trackerUI.RecoverMidnightRecipeTransfer()
            return
        end

        local transferMenuShown = CurrencyTransferMenu
            and type(CurrencyTransferMenu.IsShown) == "function"
            and CurrencyTransferMenu:IsShown()
            and type(CurrencyTransferMenu.GetCurrencyID) == "function"
            and CurrencyTransferMenu:GetCurrencyID() == runtimeState.midnightVoidlightMarlCurrencyID
        if not transferMenuShown then
            runtimeState.midnightRecipeTransferMenuPending = true
            if not tokenFrameShown then
                trackerUI.OpenMidnightRecipeCurrencyTransfer()
            else
                if C_CurrencyInfo and type(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters) == "function" then
                    pcall(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters)
                end
                if trackerUI.OpenMidnightRecipeTransferMenu() then
                    runtimeState.midnightRecipeTransferMenuPending = false
                end
                ScheduleTrackerRefresh(0.05, false)
            end
            return
        end

        runtimeState.midnightRecipeTransferMenuPending = false
        local state = trackerUI.GetMidnightRecipeTransferStatus(GetTrackedMidnightProfessions())
        if state.canTransfer and state.sourceGUID and state.transferQuantity > 0 then
            local menuContent = CurrencyTransferMenu and CurrencyTransferMenu.Content or nil
            local amountSelector = menuContent and menuContent.AmountSelector or nil
            local amountInput = amountSelector and amountSelector.InputBox or nil
            local confirmButton = menuContent and menuContent.ConfirmButton or nil
            local nativeSource = type(CurrencyTransferMenu.GetSourceCharacterData) == "function"
                and CurrencyTransferMenu:GetSourceCharacterData()
                or nil
            if not (nativeSource and nativeSource.characterGUID == state.sourceGUID
                and amountInput and type(amountInput.SetNumber) == "function"
                and type(amountInput.ValidateAndSetValue) == "function" and confirmButton) then
                DebugLog("Marl transfer native menu not ready source=%s input=%s confirm=%s", tostring(nativeSource and nativeSource.characterGUID == state.sourceGUID), tostring(amountInput ~= nil), tostring(confirmButton ~= nil))
                return
            end

            local nativeAmount = type(CurrencyTransferMenu.GetRequestedCurrencyTransferAmount) == "function"
                and CurrencyTransferMenu:GetRequestedCurrencyTransferAmount()
                or 0
            if nativeAmount ~= state.transferQuantity then
                amountInput:SetNumber(state.transferQuantity)
                amountInput:ValidateAndSetValue()
                DebugLog("Marl transfer amount set requested=%d native=%d", state.transferQuantity, nativeAmount)
                ScheduleTrackerRefresh(0.05, false)
                return
            end
            if type(confirmButton.IsEnabled) == "function" and not confirmButton:IsEnabled() then
                DebugLog("Marl transfer native confirm disabled amount=%d", state.transferQuantity)
                return
            end

            self:SetAttribute("type", "click")
            self:SetAttribute("clickbutton", confirmButton)
            self.midnightRecipeTransferActionArmed = true
            self.midnightRecipeTransferActionQuantity = state.transferQuantity
            trackerUI.StartMidnightRecipeTransferWatchdog(state.transferQuantity)
            self:SetEnabled(false)
            ScheduleTrackerRefresh(0, false)
        elseif state.transferFailureReason then
            DebugLog("Marl transfer unavailable reason=%s", tostring(state.transferFailureReason))
        end
    end)
    trackerFrame.recipeMarlButton:SetScript("PostClick", function(self, _, down)
        if down then
            return
        end
        if self.midnightRecipeTransferActionArmed then
            self.midnightRecipeTransferActionArmed = false
            self.midnightRecipeTransferActionQuantity = nil
            ScheduleTrackerRefresh(0.05, false)
        end
    end)
    trackerFrame.recipeMarlButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Transfere les Voidlight Marls des autres personnages pour acheter les recettes suivies.")
        if self.requiredQuantity then
            GameTooltip:AddLine(("Manque actuel : %d / %d"):format(
                math.max(self.currentQuantity or 0, 0),
                self.requiredQuantity
            ), 1, 1, 1, true)
        end
        if self.availableQuantity then
            GameTooltip:AddLine(("Disponible sur les autres personnages : %d"):format(self.availableQuantity), 0.7, 0.85, 1, true)
        end
        if self.sourceGUID and self.transferQuantity then
            GameTooltip:AddLine(("Prochaine source : %s (%d)"):format(
                self.sourceName or "personnage",
                self.transferQuantity
            ), 0.7, 1, 0.7, true)
        elseif self.transferRecoveryAvailable then
            GameTooltip:AddLine("Le transfert semble bloqué. Clique pour réinitialiser l'interface.", 1, 0.7, 0.2, true)
        elseif not self:IsEnabled() then
            GameTooltip:AddLine("Plus assez de marls disponibles sur les autres personnages.", 1, 0.4, 0.4, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.recipeMarlButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.payoutButton = CreateFrame("Button", addonName .. "PayoutButton", trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    trackerFrame.payoutButton:SetSize(178, YayaCore.UI.ACTION.height)
    trackerFrame.payoutButton:RegisterForClicks("AnyUp")
    trackerFrame.payoutButton:SetAttribute("useOnKeyDown", false)
    trackerFrame.payoutButton:SetText("Ouvrir payout")
    trackerFrame.payoutButton:Hide()
    trackerUI.RegisterContainerActionButton(trackerFrame.payoutButton)
    trackerFrame.payoutButton:HookScript("PreClick", trackerUI.NotifyContainerOpening)
    trackerFrame.payoutButton:HookScript("PostClick", function(self, _, down)
        if down then
            return
        end

        trackerUI.LockItemActionButton(self)

        if InCombatLockdown and InCombatLockdown() then
            runtimeState.trackerRefreshDeferredByCombat = true
            return
        end

        runtimeState.lastPayoutTargetKey = self.payoutTargetKey
        runtimeState.attemptedPayoutTargetKeys = runtimeState.attemptedPayoutTargetKeys or {}
        if self.payoutTargetKey then
            runtimeState.attemptedPayoutTargetKeys[self.payoutTargetKey] = true
        end
        InvalidateArtisanConsortiumPayoutCache()
        trackerUI.RequestItemActionRefresh()
        trackerUI.UpdateArtisanConsortiumPayoutButton(FindArtisanConsortiumPayoutInBags())
    end)
    trackerFrame.payoutButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ouvre le prochain payout ou coffre de la whitelist disponible.")
        if self.itemLink then
            GameTooltip:AddLine(self.itemLink, 0.5, 0.8, 1, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.payoutButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.autoOpenButton = CreateFrame("Button", addonName .. "AutoOpenButton", trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    trackerFrame.autoOpenButton:SetSize(178, YayaCore.UI.ACTION.height)
    trackerFrame.autoOpenButton:RegisterForClicks("AnyUp")
    trackerFrame.autoOpenButton:SetAttribute("useOnKeyDown", false)
    trackerFrame.autoOpenButton:SetText("Ouvrir conteneur")
    trackerFrame.autoOpenButton:SetPoint("TOPLEFT", 6, -22)
    trackerFrame.autoOpenButton:Hide()
    trackerUI.RegisterContainerActionButton(trackerFrame.autoOpenButton)
    trackerFrame.autoOpenButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ouvre le prochain conteneur suivi.")
        if self.itemLink then
            GameTooltip:AddLine(self.itemLink, 0.5, 0.8, 1, true)
        end
        GameTooltip:AddLine("Apparait apres plusieurs echecs automatiques.", 1, 0.8, 0.2, true)
        GameTooltip:Show()
    end)
    trackerFrame.autoOpenButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.surplusReagentButtons = {}
    for index = 1, 11 do
        local button = CreateFrame("Button", addonName .. "SurplusReagentButton" .. index, trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
        button:SetSize(178, YayaCore.UI.ACTION.height)
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetText("Ouvrir surplus")
        button:Hide()
        trackerUI.RegisterContainerActionButton(button)
        button:HookScript("PreClick", trackerUI.NotifyContainerOpening)
        button:HookScript("PostClick", function(self, _, down)
            if down then
                return
            end
            trackerUI.LockItemActionButton(self)
            trackerUI.InvalidateSurplusReagentContainerCache()
            trackerUI.RequestItemActionRefresh()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Ouvre ce type de conteneur de composants en surplus.")
            if self.itemLink then
                GameTooltip:AddLine(self.itemLink, 0.5, 0.8, 1, true)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        trackerFrame.surplusReagentButtons[index] = button
    end

    trackerFrame.finishingReagentMergeButtons = {}
    for index = 1, 3 do
        local button = CreateFrame("Button", addonName .. "FinishingReagentMergeButton" .. index, trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
        button:SetSize(178, YayaCore.UI.ACTION.height)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetAttribute("useOnKeyDown", false)
        button:SetText("Fusionner")
        button:Hide()
        button:HookScript("PostClick", function(self, _, down)
            if down then
                return
            end
            trackerUI.LockItemActionButton(self)
            trackerUI.InvalidateFinishingReagentMergeCache()
            trackerUI.RequestItemActionRefresh()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Fusionne 5 exemplaires de rang 1 en 1 exemplaire de rang 2.")
            if self.itemLink then
                GameTooltip:AddLine(self.itemLink, 0.5, 0.8, 1, true)
            end
            if self.mergeCount then
                GameTooltip:AddLine(("Fusions possibles : %d"):format(self.mergeCount), 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        trackerFrame.finishingReagentMergeButtons[index] = button
    end

    trackerFrame.treasureButton = CreateFrame("Button", addonName .. "TreasureButton", trackerFrame, "UIPanelButtonTemplate")
    trackerFrame.treasureButton:SetSize(178, YayaCore.UI.ACTION.height)
    trackerFrame.treasureButton:RegisterForClicks("AnyUp")
    trackerFrame.treasureButton:SetText("TomTom tresors")
    trackerFrame.treasureButton:Hide()
    trackerFrame.treasureButton:SetScript("OnClick", function()
        trackerUI.RetriggerMidnightTreasureWaypoints()
        ScheduleTrackerRefresh(0.05, false)
    end)
    trackerFrame.treasureButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Regenere tous les waypoints TomTom des tresors Midnight manquants.")
        if self.missingCount then
            GameTooltip:AddLine(("Tresors encore manquants : %d"):format(self.missingCount), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.treasureButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.professionSupplyButton = CreateFrame("Button", addonName .. "ProfessionSupplyButton", trackerFrame, "UIPanelButtonTemplate")
    trackerFrame.professionSupplyButton:SetSize(178, YayaCore.UI.ACTION.height)
    trackerFrame.professionSupplyButton:RegisterForClicks("AnyUp", "AnyDown")
    trackerFrame.professionSupplyButton:SetText("Approvisionner")
    trackerFrame.professionSupplyButton:Hide()
    trackerFrame.professionSupplyButton:SetScript("OnClick", function(self, _, down)
        if down then
            return
        end
        -- La Warbank d'abord, l'hotel des ventes ensuite : c'est la regle du
        -- plan, et le libelle du bouton l'a deja annoncee.
        if self.supplyPull then
            trackerUI.PullFromWarbank(self.supplyPull, self)
        else
            trackerUI.QueueProfessionSupplyPurchases(self.supplyPlan)
        end
    end)
    trackerFrame.professionSupplyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Complete l'equipement de metier : Warbank d'abord, hotel des ventes ensuite.")
        local plan = self.supplyPlan

        local function DescribeVariant(variant)
            if not variant then
                return nil
            end
            if variant.statLabel then
                return ("%s, ilvl >= %d"):format(variant.statLabel, variant.minItemLevel or 0)
            end
            return ("ilvl >= %d"):format(variant.minItemLevel or 0)
        end

        local function AddEntryLine(entry, quantity, colorR, colorG, colorB)
            GameTooltip:AddLine(
                ("%sx %s (%s%s)"):format(
                    tostring(quantity),
                    entry.itemName or ("item:" .. tostring(entry.itemID)),
                    entry.professionLabel and (entry.professionLabel .. " ") or "",
                    entry.reason or "?"),
                colorR, colorG, colorB, true)
            local variantLabel = DescribeVariant(entry.variant)
            if variantLabel then
                GameTooltip:AddLine(("    variante exigee : %s"):format(variantLabel), 0.5, 0.8, 1, true)
            end
        end

        if plan and plan.pullQuantity > 0 then
            GameTooltip:AddLine("A recuperer depuis la Warbank :", 0.6, 1, 0.6, true)
            for _, entry in ipairs(plan.entries) do
                if entry.pull > 0 then
                    AddEntryLine(entry, entry.pull, 0.7, 0.9, 0.7)
                end
            end
            if not trackerUI.IsAccountBankOpen() then
                GameTooltip:AddLine(
                    "Ouvre la Warbank pour les sortir ; en attendant, ils ne sont pas rachetes.",
                    1, 0.8, 0.4, true)
            else
                GameTooltip:AddLine("Un clic sort un seul objet : reclique jusqu'a extinction.",
                    0.7, 0.7, 0.7, true)
            end
        end

        if plan and plan.buyQuantity > 0 then
            GameTooltip:AddLine("A acheter a l'hotel des ventes :", 1, 0.9, 0.6, true)
            for _, entry in ipairs(plan.entries) do
                if entry.buy > 0 then
                    AddEntryLine(entry, entry.buy, 0.7, 0.7, 0.7)
                end
            end
            -- La file ecarte les annonces non conformes : ce que le bouton
            -- promet est ce qui sera achete, ou rien. Sans ce rappel, le
            -- silence passerait pour une panne.
            GameTooltip:AddLine(
                ("YayaQueue n'achete qu'une annonce conforme (rang ilvl >= %d, statistique exigee pour un outil)."):format(
                    trackerUI.GetProfessionGearMinimumItemLevel()),
                0.7, 1, 0.7, true)
        end

        for _, blocked in ipairs(plan and plan.blocked or EMPTY_TABLE) do
            GameTooltip:AddLine(
                ("%s : %s, ni recupere ni achete."):format(
                    blocked.itemName or ("item:" .. tostring(blocked.itemID)),
                    blocked.reason or "verdict Warbank inconnu"),
                1, 0.6, 0.2, true)
        end
        for _, statKey in ipairs(plan and plan.unknownStats or EMPTY_TABLE) do
            GameTooltip:AddLine(
                ("Statistique %s non ciblable : aucun bonusId connu, rien n'est propose."):format(statKey),
                1, 0.4, 0.4, true)
        end
        if plan and plan.pending then
            GameTooltip:AddLine("Scan encore incomplet : le plan peut evoluer.", 1, 0.6, 0.2, true)
        end
        if not self:IsEnabled() then
            GameTooltip:AddLine("Rien d'actionnable pour l'instant.", 1, 0.6, 0.2, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.professionSupplyButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.toolEnchantApplyButtons = {}
    -- Les outils de rechange en sac ont chacun leur bouton : 11 ne couvrait
    -- que les metiers, pas les exemplaires supplementaires.
    for index = 1, 20 do
        local button = CreateFrame("Button", addonName .. "ToolEnchantApplyButton" .. index, trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
        button:SetSize(178, YayaCore.UI.ACTION.height)
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetText("Appliquer enchantement")
        button:Hide()
        button:HookScript("PostClick", function(self, _, down)
            if down then
                return
            end
            trackerUI.MarkToolEnchantApplicationPending(self.actionState)
            trackerUI.LockItemActionButton(self)
            trackerUI.InvalidateToolEnchantCache()
            trackerUI.RequestItemActionRefresh()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local action = self.actionState
            GameTooltip:SetText("Applique l'enchantement sur l'outil correspondant, équipé ou en sac.")
            if action and action.statLabel then
                GameTooltip:AddLine(("Stat : %s"):format(action.statLabel), 1, 1, 1, true)
            end
            if action and action.toolLink then
                GameTooltip:AddLine(("Cible : %s"):format(action.toolLink), 0.5, 0.8, 1, true)
            end
            GameTooltip:AddLine("L'enchantement doit être présent dans les sacs.", 1, 0.8, 0.2, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        trackerFrame.toolEnchantApplyButtons[index] = button
    end

    trackerFrame.lines = {}
    for index = 1, 6 do
        trackerUI.EnsureTrackerLine(index)
    end

    YayaFrameAPI:AttachSection(addonName, trackerFrame, 20)
    YayaFrameAPI:SetSectionTitle(addonName, "Hebdo")
    YayaFrameAPI:SetSectionCollapseHandler(addonName, function(collapsed)
        trackerUI.collapsed = collapsed
        UpdateTracker()
    end)
    trackerUI.collapsed = YayaFrameAPI:IsSectionCollapsed(addonName) == true

    trackerUI.ApplyCombatVisibility()
    DebugLog("CreateTrackerFrame done")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "ZONE_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_UPDATE")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
eventFrame:RegisterEvent("AREA_POIS_UPDATED")
eventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_CURRENCY")
eventFrame:RegisterEvent("CHAT_MSG_MONEY")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
eventFrame:RegisterEvent("ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
eventFrame:RegisterEvent("CURRENCY_TRANSFER_INITIATED")
eventFrame:RegisterEvent("CURRENCY_TRANSFER_SUCCESS")
eventFrame:RegisterEvent("CURRENCY_TRANSFER_FAILED")
eventFrame:RegisterEvent("CURRENCY_TRANSFER_LOG_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event ~= "ITEM_DATA_LOAD_RESULT" and event ~= "CHAT_MSG_CURRENCY" then
        DebugLog("Event %s", tostring(event))
    end
    if event == "TRADE_SKILL_SHOW" and runtimeState.tradeSkillBootstrapPending then
        if C_Timer and C_Timer.After then
            C_Timer.After(0, trackerUI.FinishTradeSkillBootstrap)
        else
            trackerUI.FinishTradeSkillBootstrap()
        end
    end

    if event == "PLAYER_LOGIN" then
        MigrateLegacyPosition()
        trackerUI.CreateTrackerFrame()
        trackerUI.RegisterOptions()
        HookCacheItemUse()
        trackerUI.ArmTradeSkillBootstrap(eventFrame)
        trackerUI.InstallWarbankRefreshHooks()

        SLASH_YAYAWEEKLYTRACKER1 = "/ywt"
        SlashCmdList.YAYAWEEKLYTRACKER = function(message)
            local command = strtrim((message or ""):lower())
            if command == "reset" then
                trackerUI.ResetPosition()
            elseif command == "debug" then
                SetDebugEnabled(not IsDebugEnabled())
                DebugLog("Debug %s", IsDebugEnabled() and "active" or "desactive")
            elseif command == "debug on" then
                SetDebugEnabled(true)
                DebugLog("Debug active")
            elseif command == "debug off" then
                SetDebugEnabled(false)
            elseif command == "debug now" then
                InvalidateTrackedMidnightProfessions()
                InvalidateMidnightKnowledgeConsumableCache()
                trackerUI.InvalidateMidnightRecipeItemCache()
                InvalidateArtisanConsortiumPayoutCache()
                trackerUI.InvalidateSurplusReagentContainerCache()
                trackerUI.InvalidateFinishingReagentMergeCache()
                trackerUI.InvalidateWarbankCaches()
                trackerUI.InvalidateToolEnchantCache()
                debugSignatures.knowledge = nil
                debugSignatures.payout = nil
                debugSignatures.surplusReagents = nil
                debugSignatures.trackedProfessions = nil
                debugSignatures.tracker = nil
                debugSignatures.treasure = nil
                debugSignatures.midnightTreatises = nil
                debugSignatures.warbankInventory = nil
                debugSignatures.professionSupplyPlan = nil
                debugSignatures.toolEnchants = nil
                DebugLog("Forced debug refresh")
            elseif command == "log" then
                PrintPersistentDebugLog(20)
            elseif command:match("^log%s+%d+$") then
                PrintPersistentDebugLog(command:match("^log%s+(%d+)$"))
            elseif command == "log clear" then
                ClearPersistentDebugLog()
                print("YWT: Log vide")
            elseif command:match("^stuff%s+ilvl%s+%d+$") then
                local value = tonumber(command:match("^stuff%s+ilvl%s+(%d+)$"))
                GetAccountDB().professionGearMinimumItemLevel = value
                trackerUI.InvalidateToolEnchantCache()
                ScheduleTrackerRefresh(0, false)
                print(("YWT: Equipement de metier conforme a partir de l'ilvl %d"):format(value))
            elseif command == "stuff ilvl" then
                print(("YWT: Equipement de metier conforme a partir de l'ilvl %d (defaut %d)"):format(
                    trackerUI.GetProfessionGearMinimumItemLevel(),
                    runtimeState.professionGear.minimumItemLevel))
            elseif command == "stuff ilvl reset" then
                GetAccountDB().professionGearMinimumItemLevel = nil
                trackerUI.InvalidateToolEnchantCache()
                ScheduleTrackerRefresh(0, false)
                print(("YWT: Seuil d'ilvl de l'equipement de metier remis a %d"):format(
                    runtimeState.professionGear.minimumItemLevel))
            elseif command == "stuff" then
                local accountDB = GetAccountDB()
                local isEnabled = accountDB.trackProfessionGear ~= false
                accountDB.trackProfessionGear = not isEnabled
                trackerUI.InvalidateToolEnchantCache()
                ScheduleTrackerRefresh(0, false)
                print(("YWT: Equipement de metier %s"):format(
                    accountDB.trackProfessionGear and "active" or "desactive"))
            elseif command == "stuff on" then
                GetAccountDB().trackProfessionGear = true
                trackerUI.InvalidateToolEnchantCache()
                ScheduleTrackerRefresh(0, false)
                print("YWT: Equipement de metier active")
            elseif command == "stuff off" then
                GetAccountDB().trackProfessionGear = false
                trackerUI.InvalidateToolEnchantCache()
                ScheduleTrackerRefresh(0, false)
                print("YWT: Equipement de metier desactive")
            elseif command == "traites" then
                local accountDB = GetAccountDB()
                local isEnabled = accountDB.trackTreatises ~= false
                accountDB.trackTreatises = not isEnabled
                print(("YWT: Tracker les traites (inscription) %s"):format(accountDB.trackTreatises and "active" or "desactive"))
            elseif command == "traites on" then
                GetAccountDB().trackTreatises = true
                print("YWT: Tracker les traites (inscription) active")
            elseif command == "traites off" then
                GetAccountDB().trackTreatises = false
                print("YWT: Tracker les traites (inscription) desactive")
            elseif command == "autoopen reset" or command == "autoopen reset all" then
                local api = _G.YayaWeeklyTrackerAutoOpen
                if api and type(api.ResetContainerCaches) == "function" then
                    local includeForbidden = command == "autoopen reset all"
                    api.ResetContainerCaches(includeForbidden)
                    print(("YWT: verdicts d'auto-ouverture purges%s"):format(
                        includeForbidden and " (y compris les conteneurs interdits par Blizzard)" or ""
                    ))
                else
                    print("YWT: module d'auto-ouverture indisponible")
                end
            elseif command == "autoopen" then
                local api = _G.YayaWeeklyTrackerAutoOpen
                local forbidden, failed, successful = 0, 0, 0
                if api then
                    if type(api.GetForbiddenContainers) == "function" then
                        for _ in pairs(api.GetForbiddenContainers() or EMPTY_TABLE) do
                            forbidden = forbidden + 1
                        end
                    end
                    if type(api.GetFailedContainers) == "function" then
                        for _ in pairs(api.GetFailedContainers() or EMPTY_TABLE) do
                            failed = failed + 1
                        end
                    end
                    if type(api.GetSuccessfulContainers) == "function" then
                        for _ in pairs(api.GetSuccessfulContainers() or EMPTY_TABLE) do
                            successful = successful + 1
                        end
                    end
                end
                print(("YWT autoopen: %d interdits (manuel uniquement), %d refus transitoires, %d succes"):format(
                    forbidden,
                    failed,
                    successful
                ))
            end
            ScheduleTrackerRefresh(0, false)
        end
        DebugLog("Debug actif. Commandes: /ywt debug, /ywt debug on, /ywt debug off, /ywt traites, /ywt autoopen, /ywt autoopen reset")
        ScheduleTrackerRefresh(0, true)
    elseif event == "MERCHANT_SHOW" then
        runtimeState.abundanceEnchantingPurchaseGeneration = (runtimeState.abundanceEnchantingPurchaseGeneration or 0) + 1
        runtimeState.abundanceEnchantingPurchaseScheduled = false
        runtimeState.abundanceEnchantingPurchaseAttempted = false
        runtimeState.abundanceEnchantingPurchasePending = nil
        runtimeState.abundanceEnchantingPurchaseRetryCount = 0
        runtimeState.abundanceEnchantingPurchaseStalledCount = 0
        runtimeState.abundancePurchaseSkippedItems = {}
        trackerUI.ScheduleAbundanceEnchantingBagPurchase(0.05)
    elseif event == "MERCHANT_UPDATE" then
        trackerUI.ScheduleAbundanceEnchantingBagPurchase()
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        local reagentInfo = runtimeState.midnightEnchantingWeeklyReagents[questID]
        if reagentInfo and YayaQueueAPI and type(YayaQueueAPI.RemoveItem) == "function" then
            local characterDB = GetCharacterDB()
            characterDB.autoQueuedEnchantingWeeklies = characterDB.autoQueuedEnchantingWeeklies or {}
            local queuedQuantity = characterDB.autoQueuedEnchantingWeeklies[questID]
            local removeQuantity = queuedQuantity == nil and reagentInfo.quantity or queuedQuantity
            local ok, removedQuantity = false, 0
            if removeQuantity > 0 then
                ok, removedQuantity = YayaQueueAPI.RemoveItem(reagentInfo.itemID, removeQuantity)
            end
            characterDB.autoQueuedEnchantingWeeklies[questID] = nil
            if ok and removedQuantity and removedQuantity > 0 then
                print(("YWT: Retire %dx %s de YayaQueue (weekly rendue)"):format(
                    removedQuantity,
                    reagentInfo.itemName or ("item:" .. tostring(reagentInfo.itemID))
                ))
            end
        end
        QueuePendingNzothCache(questID)
        trackerUI.InvalidateWarbankCaches()
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "BAG_UPDATE_DELAYED" then
        runtimeState.itemActionRefreshPending = true
        runtimeState.itemActionForceBagRefresh = true
        runtimeState.attemptedPayoutTargetKeys = runtimeState.attemptedPayoutTargetKeys or {}
        wipe(runtimeState.attemptedPayoutTargetKeys)
        InvalidateMidnightKnowledgeConsumableCache()
        trackerUI.InvalidateMidnightRecipeItemCache()
        InvalidateArtisanConsortiumPayoutCache()
        trackerUI.InvalidateSurplusReagentContainerCache()
        trackerUI.InvalidateFinishingReagentMergeCache()
        trackerUI.InvalidateWarbankCaches()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0, false)
        if runtimeState.abundanceEnchantingPurchasePending then
            trackerUI.ScheduleAbundanceEnchantingBagPurchase(0)
        end
        if activeCacheOpen then
            ScheduleFinalizeActiveCacheOpen(0.35)
        end
    elseif event == "BANKFRAME_OPENED" then
        trackerUI.InstallWarbankRefreshHooks()
        trackerUI.InvalidateWarbankCaches()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0.05, false)
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.75, function()
                trackerUI.InvalidateWarbankCaches()
                trackerUI.InvalidateToolEnchantCache()
                ScheduleTrackerRefresh(0, false)
            end)
        end
    elseif event == "BANKFRAME_CLOSED" then
        trackerUI.InvalidateWarbankCaches()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0, false)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
        or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if Enum and Enum.PlayerInteractionType
            and interactionType == Enum.PlayerInteractionType.AccountBanker then
            trackerUI.InvalidateWarbankCaches()
            trackerUI.InvalidateToolEnchantCache()
            ScheduleTrackerRefresh(event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and 0.05 or 0, false)
        end
    elseif event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        trackerUI.InvalidateWarbankCaches()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "SPELLS_CHANGED"
        or event == "SKILL_LINES_CHANGED"
        or event == "TRADE_SKILL_SHOW"
        or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        InvalidateTrackedMidnightProfessions()
        trackerUI.InvalidateWarbankCaches()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0.05, true)
        trackerUI.ArmTradeSkillBootstrap(eventFrame)
    elseif event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" then
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "PLAYER_LEVEL_UP" then
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0, false)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        local rawItemID, success = ...
        local itemID = tonumber(rawItemID)
        local wasPending = itemID and runtimeState.itemDataLoadPending[itemID] == true
        if itemID then
            runtimeState.itemDataLoadPending[itemID] = nil
            if wasPending then
                runtimeState.itemDataLoadRetryAt[itemID] = (GetTime and GetTime() or 0)
                    + (success == false and runtimeState.itemDataLoadCooldownSeconds or 10)
            end
        end
        if wasPending then
            DebugLog(
                "ITEM_DATA_LOAD_RESULT item=%s success=%s pending=%s",
                tostring(itemID or rawItemID or "none"),
                tostring(success),
                tostring(wasPending == true)
            )
        end
        if wasPending then
            trackerUI.InvalidateMidnightRecipeItemCache()
            trackerUI.InvalidateToolEnchantCache()
            ScheduleTrackerRefresh(0.05, false)
        end
    elseif event == "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED" then
        if runtimeState.midnightRecipeTransferMenuPending
            and trackerUI.OpenMidnightRecipeTransferMenu() then
            runtimeState.midnightRecipeTransferMenuPending = false
        end
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "CURRENCY_TRANSFER_INITIATED" then
        if not runtimeState.midnightRecipeTransferDataPending then
            trackerUI.StartMidnightRecipeTransferWatchdog(nil)
        end
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "CURRENCY_TRANSFER_SUCCESS" then
        trackerUI.ClearMidnightRecipeTransferPending("success event")
        if C_CurrencyInfo and type(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters) == "function" then
            pcall(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters)
        end
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "CURRENCY_TRANSFER_FAILED" then
        local failureReason = ...
        DebugLog("Marl transfer failed reason=%s", tostring(failureReason))
        trackerUI.ClearMidnightRecipeTransferPending("failure event")
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "CURRENCY_TRANSFER_LOG_UPDATE" then
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "QUEST_LOG_UPDATE"
        or event == "SPELL_UPDATE_COOLDOWN"
        or event == "AREA_POIS_UPDATED"
        or event == "QUEST_DATA_LOAD_RESULT"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS"
        or event == "COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED"
        or event == "WEEKLY_REWARDS_UPDATE" then
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "PLAYER_REGEN_DISABLED" then
        trackerUI.HideContainerActionButtons()
        runtimeState.trackerRefreshDeferredByCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        if runtimeState.combatVisibilityUpdateDeferred then
            trackerUI.ApplyCombatVisibility()
        end
        if runtimeState.trackerRefreshDeferredByCombat then
            runtimeState.trackerRefreshDeferredByCombat = false
            ScheduleTrackerRefresh(0, false)
        end
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        local currencyID, quantity = ...
        local previousQuantity = type(currencyID) == "number"
            and runtimeState.currencyQuantities[currencyID]
            or nil
        if type(currencyID) == "number" and type(quantity) == "number" then
            runtimeState.currencyQuantities[currencyID] = quantity
            if currencyID == runtimeState.midnightVoidlightMarlCurrencyID
                and runtimeState.midnightRecipeTransferDataPending
                and type(previousQuantity) == "number"
                and quantity > previousQuantity then
                trackerUI.ClearMidnightRecipeTransferPending("currency display update")
            end
        end
        ScheduleTrackerRefresh(0.05, false)
        trackerUI.ScheduleAbundanceEnchantingBagPurchase(0)
        if activeCacheOpen then
            ScheduleFinalizeActiveCacheOpen(0.35)
        end
    elseif activeCacheOpen and event == "PLAYER_MONEY" then
        ScheduleFinalizeActiveCacheOpen(0.35)
    elseif activeCacheOpen and (event == "CHAT_MSG_CURRENCY" or event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_LOOT") then
        local message = ...
        CaptureActiveCacheMessage(event, message)
        ScheduleFinalizeActiveCacheOpen(0.35)
    end
end)

