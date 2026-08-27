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
            label = "Vicious Thalassian Flask of Honor",
            optionKey = "trackRecipeViciousThalassianFlaskHonor",
            spellID = 1230883,
            itemID = 257417,
            moxieCost = 150,
            mapID = 2395,
            x = 34.04,
            y = 81.20,
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
    trackProfessionTools = true,
    trackProfessionToolEnchants = true,
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
    { category = "Metiers Midnight", key = "trackProfessionTools", label = "Outils metiers" },
    { category = "Metiers Midnight", key = "trackProfessionToolEnchants", label = "Enchantements des outils" },
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
runtimeState.professionToolEnchantments = {
    statOrder = { "perception", "resourcefulness", "finesse", "multicrafting", "ingenuity", "deftness" },
    byStat = {
        perception = {
            label = "Perception",
            shortLabel = "Perception",
            itemID = 243965,
            enchantID = 7975,
            statKeys = { "ITEM_MOD_PERCEPTION_RATING_SHORT", "ITEM_MOD_PERCEPTION_RATING" },
            tooltipAliases = { "perception" },
        },
        resourcefulness = {
            label = "Resourcefulness",
            shortLabel = "RF",
            itemID = 243967,
            enchantID = 7977,
            statKeys = { "ITEM_MOD_RESOURCEFULNESS_RATING_SHORT", "ITEM_MOD_RESOURCEFULNESS_RATING" },
            tooltipAliases = { "resourcefulness", "débrouillardise" },
        },
        finesse = {
            label = "Finesse",
            shortLabel = "Finesse",
            itemID = 243993,
            enchantID = 8003,
            statKeys = { "ITEM_MOD_FINESSE_RATING_SHORT", "ITEM_MOD_FINESSE_RATING" },
            tooltipAliases = { "finesse" },
        },
        multicrafting = {
            label = "Multicrafting",
            shortLabel = "MC",
            itemID = 243995,
            enchantID = 8005,
            statKeys = { "ITEM_MOD_MULTICRAFT_RATING_SHORT", "ITEM_MOD_MULTICRAFT_RATING" },
            tooltipAliases = { "multicrafting", "multicraft", "fabrication multiple" },
        },
        ingenuity = {
            label = "Ingenuity",
            shortLabel = "Ingenuity",
            itemID = 244025,
            enchantID = 8035,
            statKeys = { "ITEM_MOD_INGENUITY_RATING_SHORT", "ITEM_MOD_INGENUITY_RATING" },
            tooltipAliases = { "ingenuity", "ingéniosité" },
        },
        deftness = {
            label = "Deftness",
            shortLabel = "Deftness",
            itemID = 244023,
            enchantID = 8033,
            statKeys = {
                "ITEM_MOD_DEFTNESS_RATING_SHORT",
                "ITEM_MOD_DEFTNESS_RATING",
                "ITEM_MOD_CRAFTING_SPEED_RATING_SHORT",
                "ITEM_MOD_CRAFTING_SPEED_RATING",
            },
            tooltipAliases = { "deftness", "dextérité", "crafting speed", "vitesse de fabrication" },
        },
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
    warbankTreatises = nil,
    warbankTreatisesDirty = true,
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
    warbankTreatises = nil,
    toolEnchants = nil,
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
    for _, button in ipairs(frame.surplusReagentButtons or EMPTY_TABLE) do
        Unlock(button)
    end
    for _, button in ipairs(frame.finishingReagentMergeButtons or EMPTY_TABLE) do
        Unlock(button)
    end
    for _, button in ipairs(frame.warbankTreatiseButtons or EMPTY_TABLE) do
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
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99YWT|r: " .. lines[index])
        elseif print then
            print("YWT: " .. lines[index])
        end
    end
end

local function ClearPersistentDebugLog()
    GetAccountDB().debugLog = {}
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
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99YWT DEBUG|r " .. text)
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
    "warbankTreatiseButtons",
    "toolEnchantApplyButtons",
}

trackerUI.GetButtonItemTarget = function(button)
    if not button then
        return nil
    end
    return button.itemName
        or button.itemLink
        or (button.itemID and ("item:" .. tostring(button.itemID)))
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
    local firstMatch
    local totalCount = 0
    local countsByItemID = {}

    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            local skillLineID = itemID and MIDNIGHT_KNOWLEDGE_ITEM_SKILL_LINE_IDS[itemID] or nil
            if skillLineID and trackedSkillLineIDs[skillLineID] then
                local treatiseInfo = MIDNIGHT_TREATISES_BY_SKILL_LINE_ID[skillLineID]
                local isCompletedTreatise = treatiseInfo and treatiseInfo.itemID == itemID and IsQuestDone(treatiseInfo.weeklyQuestID)
                if not isCompletedTreatise then
                    countsByItemID[itemID] = (countsByItemID[itemID] or 0) + math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
                    local itemLink = GetContainerItemLinkCompat(bagID, slotIndex)
                    local itemName = GetItemInfo and GetItemInfo(itemID) or nil
                    if IsItemCurrentlyUsable(itemLink, itemName, itemID) then
                        totalCount = totalCount + math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
                        if not firstMatch then
                            firstMatch = {
                                bagID = bagID,
                                itemID = itemID,
                                itemLink = itemLink,
                                itemName = itemName,
                                slotIndex = slotIndex,
                            }
                        end
                    end
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

trackerUI.InvalidateWarbankTreatiseCache = function()
    midnightCaches.warbankTreatisesDirty = true
end

trackerUI.InstallWarbankRefreshHooks = function()
    if type(hooksecurefunc) ~= "function" then
        return
    end

    runtimeState.warbankRefreshHooks = runtimeState.warbankRefreshHooks or {}
    local hooks = runtimeState.warbankRefreshHooks
    local function RefreshWarbankButtons(source)
        DebugLog("Warbank selection changed via %s", tostring(source))
        trackerUI.InvalidateWarbankTreatiseCache()
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
            local bankPanel = (_G.BankFrame and _G.BankFrame.BankPanel) or _G.BankPanel
            if bankPanel and type(bankPanel.SetBankType) == "function" then
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
    if activeBankType == nil and bankPanel and type(bankPanel.GetActiveBankType) == "function" then
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

trackerUI.FindMissingMidnightTreatisesInWarbank = function(trackedRows)
    if GetAccountDB().trackTreatises == false or not trackerUI.IsAccountBankOpen() then
        local closedResult = { bankOpen = false, matches = EMPTY_TABLE }
        midnightCaches.warbankTreatises = closedResult
        midnightCaches.warbankTreatisesDirty = false
        return closedResult
    end
    if not midnightCaches.warbankTreatisesDirty and midnightCaches.warbankTreatises then
        return midnightCaches.warbankTreatises
    end

    trackedRows = trackedRows or GetTrackedMidnightProfessions()
    local missingBySkillLineID = {}
    for _, row in ipairs(trackedRows) do
        local config = MIDNIGHT_PROFESSION_CONFIGS[row.skillLineID]
        local treatiseInfo = MIDNIGHT_TREATISES_BY_SKILL_LINE_ID[row.skillLineID]
        if config and treatiseInfo
            and row.skillLevel >= (config.treatiseMinSkill or math.huge)
            and not IsQuestDone(treatiseInfo.weeklyQuestID)
            and trackerUI.GetOwnedItemCount(treatiseInfo.itemID) <= 0 then
            missingBySkillLineID[row.skillLineID] = {
                label = config.label or tostring(row.skillLineID),
                itemID = treatiseInfo.itemID,
            }
        end
    end

    local matchesBySkillLineID = {}
    for _, bagID in ipairs(trackerUI.GetAccountBankBagIDs()) do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            local skillLineID = itemID and MIDNIGHT_KNOWLEDGE_ITEM_SKILL_LINE_IDS[itemID] or nil
            local missing = skillLineID and missingBySkillLineID[skillLineID] or nil
            if missing and missing.itemID == itemID and not matchesBySkillLineID[skillLineID] then
                matchesBySkillLineID[skillLineID] = {
                    skillLineID = skillLineID,
                    label = missing.label,
                    bagID = bagID,
                    slotIndex = slotIndex,
                    itemID = itemID,
                    itemLink = GetContainerItemLinkCompat(bagID, slotIndex),
                    itemName = GetItemInfo and GetItemInfo(itemID) or nil,
                    stackCount = math.max(GetContainerItemCountCompat(bagID, slotIndex), 1),
                }
            end
        end
    end

    local matches = {}
    for _, row in ipairs(trackedRows) do
        local match = matchesBySkillLineID[row.skillLineID]
        if match then
            matches[#matches + 1] = match
        end
    end

    local debugParts = {}
    for _, match in ipairs(matches) do
        debugParts[#debugParts + 1] = ("%s:%d:%d"):format(
            match.label or "?",
            match.itemID or 0,
            match.stackCount or 0
        )
    end
    local debugSignature = table.concat(debugParts, ",")
    if debugSignature ~= debugSignatures.warbankTreatises then
        debugSignatures.warbankTreatises = debugSignature
        DebugLog("Warbank treatises = %s", debugSignature ~= "" and debugSignature or "none")
    end

    local result = { bankOpen = true, matches = matches }
    midnightCaches.warbankTreatises = result
    midnightCaches.warbankTreatisesDirty = false
    return result
end

trackerUI.PullWarbankTreatise = function(button)
    if not button or not button.bagID or not button.slotIndex or not button.itemID then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if not C_Container
        or type(C_Container.GetContainerItemInfo) ~= "function"
        or type(C_Container.PickupContainerItem) ~= "function" then
        print("YWT: transfert Warbank indisponible")
        return
    end

    if type(GetCursorInfo) == "function" and select(1, GetCursorInfo()) then
        print("YWT: libère d'abord le curseur")
        return
    end

    local sourceInfo = SafeCall(C_Container.GetContainerItemInfo, button.bagID, button.slotIndex)
    local stackCount = tonumber(sourceInfo and sourceInfo.stackCount) or 0
    if not sourceInfo or tonumber(sourceInfo.itemID) ~= button.itemID or stackCount <= 0 then
        trackerUI.InvalidateWarbankTreatiseCache()
        ScheduleTrackerRefresh(0, false)
        return
    end
    if sourceInfo.isLocked then
        return
    end

    local destinationBag, destinationSlot = trackerUI.FindToolEnchantDestination(button.itemID, 1)
    if not destinationBag or not destinationSlot then
        print("YWT: aucun emplacement disponible dans les sacs")
        return
    end

    local ok
    if stackCount > 1 then
        if type(C_Container.SplitContainerItem) ~= "function" then
            print("YWT: le split de stack n'est pas disponible")
            return
        end
        ok = pcall(C_Container.SplitContainerItem, button.bagID, button.slotIndex, 1)
    else
        ok = pcall(C_Container.PickupContainerItem, button.bagID, button.slotIndex)
    end
    if not ok then
        print("YWT: transfert Warbank indisponible")
        return
    end

    local placed = pcall(C_Container.PickupContainerItem, destinationBag, destinationSlot)
    if not placed then
        print("YWT: impossible de déposer le traité dans les sacs")
        return
    end

    trackerUI.LockItemActionButton(button)
    trackerUI.InvalidateWarbankTreatiseCache()
    trackerUI.RequestItemActionRefresh()
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
            local itemTarget = state.itemName or state.itemLink or ("item:" .. tostring(state.itemID or 0))
            button:SetAttribute("type", "item")
            button:SetAttribute("item", itemTarget)
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

trackerUI.UpdateWarbankTreatiseButtons = function(state)
    local buttons = trackerFrame and trackerFrame.warbankTreatiseButtons or EMPTY_TABLE
    local matches = state and state.bankOpen and state.matches or EMPTY_TABLE
    local visibleCount = 0

    for index, button in ipairs(buttons) do
        local match = matches[index]
        if match and match.bagID and match.slotIndex then
            if not button.itemActionLocked then
                button:SetEnabled(true)
            end
            button.skillLineID = match.skillLineID
            button.itemID = match.itemID
            button.itemLink = match.itemLink
            button.itemName = match.itemName
            button.bagID = match.bagID
            button.slotIndex = match.slotIndex
            button:SetText(("Récupérer traité %s x1"):format(match.label or ""))
            button:Show()
            visibleCount = visibleCount + 1
        else
            button.skillLineID = nil
            button.itemID = nil
            button.itemLink = nil
            button.itemName = nil
            button.bagID = nil
            button.slotIndex = nil
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
                for _, statKey in ipairs(runtimeState.professionToolEnchantments.statOrder) do
                    local statInfo = runtimeState.professionToolEnchantments.byStat[statKey]
                    for _, key in ipairs(statInfo.statKeys or EMPTY_TABLE) do
                        local localizedName = Normalize(_G[key])
                        if localizedName ~= "" and text:find(localizedName, 1, true) then
                            return statKey
                        end
                    end
                    for _, alias in ipairs(statInfo.tooltipAliases or EMPTY_TABLE) do
                        if text:find(Normalize(alias), 1, true) then
                            return statKey
                        end
                    end
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

trackerUI.GetToolItemLocation = function(source, bagID, slotIndex)
    if not ItemLocation or type(C_Item) ~= "table" or type(C_Item.IsBound) ~= "function" then
        return nil, nil
    end

    local location
    if source == "bag" and type(ItemLocation.CreateFromBagAndSlot) == "function" then
        local ok, value = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, bagID, slotIndex)
        location = ok and value or nil
    elseif source == "equipment" and type(ItemLocation.CreateFromEquipmentSlot) == "function" then
        local ok, value = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slotIndex)
        location = ok and value or nil
    end
    if not location then
        return nil, nil
    end

    local bound = SafeCall(C_Item.IsBound, location)
    return location, bound
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

    local _, bound = trackerUI.GetToolItemLocation(source, bagID, slotIndex)
    if bound == nil then
        return nil, true, true
    end
    if bound ~= true then
        return nil, false, false
    end

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

trackerUI.GetToolEnchantBankStock = function(requiredItemIDs)
    local stock = {}
    local slots = {}
    local knownByItemID = {}
    local bankOpen = trackerUI.IsAccountBankOpen()
    local bankKnown = false
    local bankBagIDs = bankOpen and trackerUI.GetAccountBankBagIDs() or EMPTY_TABLE
    if bankOpen then
        bankKnown = #bankBagIDs > 0
        for _, bagID in ipairs(bankBagIDs) do
            local slotCount = GetContainerNumSlotsCompat(bagID)
            for slotIndex = 1, slotCount do
                local itemID = GetContainerItemIDCompat(bagID, slotIndex)
                if itemID and requiredItemIDs[itemID] then
                    local stackCount = math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
                    stock[itemID] = (stock[itemID] or 0) + stackCount
                    slots[itemID] = slots[itemID] or {}
                    slots[itemID][#slots[itemID] + 1] = {
                        bagID = bagID,
                        slotIndex = slotIndex,
                        stackCount = stackCount,
                    }
                end
            end
        end
        for itemID in pairs(requiredItemIDs) do
            knownByItemID[itemID] = bankKnown
        end
    end

    for itemID in pairs(requiredItemIDs) do
        local tsmQuantity = trackerUI.GetToolEnchantWarbankQuantity(itemID)
        if not bankOpen and tsmQuantity ~= nil then
            stock[itemID] = tsmQuantity
            knownByItemID[itemID] = true
        end
    end

    bankKnown = next(requiredItemIDs) == nil
    for itemID in pairs(requiredItemIDs) do
        if knownByItemID[itemID] ~= true then
            bankKnown = false
            break
        end
        bankKnown = true
    end

    return {
        bankOpen = bankOpen,
        bankKnown = bankKnown,
        knownByItemID = knownByItemID,
        stock = stock,
        slots = slots,
    }
end

trackerUI.FindToolEnchantState = function(trackedRows)
    if not midnightCaches.toolEnchantsDirty and midnightCaches.toolEnchants then
        return midnightCaches.toolEnchants
    end

    trackedRows = trackedRows or GetTrackedMidnightProfessions()
    local previous = midnightCaches.toolEnchants
    local result = {
        bySkillLineID = {},
        requiredByItemID = {},
        pullPlan = {},
        buyPlan = {},
        applyEnchants = {},
        pullQuantity = 0,
        buyQuantity = 0,
        pending = false,
        bankOpen = false,
        bankKnown = false,
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
            professionID = nil,
            toolSlot = nil,
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
        profession.tools[#profession.tools + 1] = details
        if source == "equipment"
            and details.statInfo
            and details.enchantID ~= details.statInfo.enchantID
            and slotIndex then
            local toolName = type(GetItemInfo) == "function"
                and SafeCall(GetItemInfo, itemLink or itemID)
                or nil
            local action = {
                skillLineID = skillLineID,
                enchantItemID = details.statInfo.itemID,
                expectedEnchantID = details.statInfo.enchantID,
                enchantLink = details.statInfo.itemLink,
                toolItemID = details.itemID,
                toolLink = details.itemLink,
                toolName = toolName,
                toolSlot = slotIndex,
                statKey = details.statKey,
                statLabel = details.statInfo.label,
                professionLabel = profession.label,
            }
            profession.applyEnchants[#profession.applyEnchants + 1] = action
            result.applyEnchants[#result.applyEnchants + 1] = action
        end
        local function AddRequiredEnchant(includeWrongEnchantWarning)
            if not details.statInfo then
                return
            end
            local requiredItemID = details.statInfo.itemID
            if includeWrongEnchantWarning then
                profession.missingByItemID[requiredItemID] = (profession.missingByItemID[requiredItemID] or 0) + 1
                profession.missingTools[requiredItemID] = profession.missingTools[requiredItemID] or {
                    itemID = requiredItemID,
                    label = details.statInfo.shortLabel,
                    statLabel = details.statInfo.label,
                    quantity = 0,
                }
                profession.missingTools[requiredItemID].quantity = profession.missingTools[requiredItemID].quantity + 1
            end
            result.requiredByItemID[requiredItemID] = (result.requiredByItemID[requiredItemID] or 0) + 1
        end
        if details.missingEnchant then
            local missingEnchantKey = details.statInfo and details.statInfo.itemID or details.itemID
            profession.missingEnchantTools[missingEnchantKey] = profession.missingEnchantTools[missingEnchantKey] or {
                itemID = details.itemID,
                requiredItemID = details.statInfo and details.statInfo.itemID or nil,
                label = details.statInfo and details.statInfo.shortLabel or nil,
                statLabel = details.statInfo and details.statInfo.label or nil,
                quantity = 0,
            }
            profession.missingEnchantTools[missingEnchantKey].quantity = profession.missingEnchantTools[missingEnchantKey].quantity + 1
            AddRequiredEnchant(false)
            return details, pending, eligible
        end
        if details.enchantID == details.statInfo.enchantID then
            return details, pending, eligible
        end

        AddRequiredEnchant(true)
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
            end
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
        local unenchantedCount = 0
        local wrongEnchantCount = 0
        for _, tool in pairs(profession.missingEnchantTools) do
            unenchantedCount = unenchantedCount + (tool.quantity or 0)
        end
        for _, tool in pairs(profession.missingTools) do
            wrongEnchantCount = wrongEnchantCount + (tool.quantity or 0)
        end
        debugParts[#debugParts + 1] = ("id=%d prof=%s slot=%s tools=%d unench=%d wrong=%d apply=%d equipped=%s pending=%s"):format(
            row.skillLineID,
            tostring(profession.professionID),
            tostring(profession.toolSlot),
            #profession.tools,
            unenchantedCount,
            wrongEnchantCount,
            #profession.applyEnchants,
            tostring(profession.hasEquippedTool),
            tostring(profession.equippedToolPending)
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

    local bankState = trackerUI.GetToolEnchantBankStock(result.requiredByItemID)
    result.bankOpen = bankState.bankOpen
    result.bankKnown = bankState.bankKnown
    for itemID, requiredQuantity in pairs(result.requiredByItemID) do
        local bankItemKnown = bankState.knownByItemID[itemID] == true
        local bagQuantity = trackerUI.GetOwnedItemCount(itemID)
        local bankQuantity = bankState.stock[itemID] or 0
        local pullQuantity = bankItemKnown
            and math.max(math.min(requiredQuantity - bagQuantity, bankQuantity), 0)
            or 0
        local buyDeficit = bankItemKnown
            and math.max(requiredQuantity - bagQuantity - bankQuantity, 0)
            or 0
        local directQuantity = 0
        if YayaQueueAPI and type(YayaQueueAPI.GetDirectItemQuantity) == "function" then
            directQuantity = tonumber(YayaQueueAPI.GetDirectItemQuantity(itemID)) or 0
        end
        local buyQuantity = math.max(buyDeficit - directQuantity, 0)
        local itemName = type(GetItemInfo) == "function" and SafeCall(GetItemInfo, itemID) or nil
        if pullQuantity > 0 then
            result.pullPlan[#result.pullPlan + 1] = {
                itemID = itemID,
                quantity = pullQuantity,
                slots = bankState.slots[itemID] or EMPTY_TABLE,
            }
            result.pullQuantity = result.pullQuantity + pullQuantity
        end
        if buyQuantity > 0 then
            result.buyPlan[#result.buyPlan + 1] = {
                itemID = itemID,
                quantity = buyQuantity,
                itemName = itemName or ("item:" .. tostring(itemID)),
            }
            result.buyQuantity = result.buyQuantity + buyQuantity
        end
    end

    table.sort(result.pullPlan, function(left, right) return left.itemID < right.itemID end)
    table.sort(result.buyPlan, function(left, right) return left.itemID < right.itemID end)
    table.sort(result.applyEnchants, function(left, right)
        return (left.toolSlot or 0) < (right.toolSlot or 0)
    end)
    midnightCaches.toolEnchants = result
    midnightCaches.toolEnchantsDirty = false
    return result
end

trackerUI.MarkToolEnchantApplicationPending = function(action)
    if not action or not action.skillLineID or not action.toolSlot or not action.enchantItemID then
        return
    end

    local key = tostring(action.skillLineID) .. ":" .. tostring(action.toolSlot)
    runtimeState.toolEnchantApplicationPending[key] = {
        skillLineID = action.skillLineID,
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
            for _, tool in ipairs(profession and profession.tools or EMPTY_TABLE) do
                if tool.source == "equipment"
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
                    "Tool enchant applied skillLine=%s slot=%s item=%s removed=%s",
                    tostring(action.skillLineID),
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

trackerUI.FindToolEnchantDestination = function(itemID, quantity)
    if not C_Container or type(C_Container.GetContainerItemInfo) ~= "function" then
        return nil, nil
    end

    local maxStack = type(GetItemInfo) == "function" and select(8, SafeCall(GetItemInfo, itemID)) or 200
    maxStack = math.max(1, tonumber(maxStack) or 200)
    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)
    local emptyBag, emptySlot
    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local info = SafeCall(C_Container.GetContainerItemInfo, bagID, slotIndex)
            if not info then
                emptyBag = emptyBag or bagID
                emptySlot = emptySlot or slotIndex
            elseif tonumber(info.itemID) == itemID
                and (tonumber(info.stackCount) or 0) + quantity <= maxStack then
                return bagID, slotIndex
            end
        end
    end
    return emptyBag, emptySlot
end

trackerUI.PullToolEnchantItems = function()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local state = trackerUI.FindToolEnchantState(GetTrackedMidnightProfessions())
    if not state.bankOpen or not state.bankKnown or #state.pullPlan == 0 then
        print("YWT: ouvre la Warbank pour récupérer les enchantements disponibles")
        return
    end

    local selectedPlan
    local selectedSlot
    for _, plan in ipairs(state.pullPlan) do
        for _, slot in ipairs(plan.slots or EMPTY_TABLE) do
            if (slot.stackCount or 0) > 0 then
                selectedPlan = plan
                selectedSlot = slot
                break
            end
        end
        if selectedPlan then
            break
        end
    end
    if not selectedPlan or not selectedSlot then
        print("YWT: aucun stack d'enchantement disponible dans la Warbank")
        return
    end

    local amount = math.min(selectedPlan.quantity, selectedSlot.stackCount or 1)
    local destinationBag, destinationSlot = trackerUI.FindToolEnchantDestination(selectedPlan.itemID, amount)
    if not destinationBag or not destinationSlot then
        print("YWT: aucun emplacement disponible dans les sacs")
        return
    end

    local info = C_Container and type(C_Container.GetContainerItemInfo) == "function"
        and SafeCall(C_Container.GetContainerItemInfo, selectedSlot.bagID, selectedSlot.slotIndex)
        or nil
    if info and info.isLocked then
        return
    end

    local ok = false
    if amount < (selectedSlot.stackCount or 1)
        and C_Container
        and type(C_Container.SplitContainerItem) == "function" then
        ok = pcall(C_Container.SplitContainerItem, selectedSlot.bagID, selectedSlot.slotIndex, amount)
    elseif C_Container and type(C_Container.PickupContainerItem) == "function" then
        ok = pcall(C_Container.PickupContainerItem, selectedSlot.bagID, selectedSlot.slotIndex)
    end
    if not ok then
        print("YWT: transfert Warbank indisponible")
        return
    end
    if C_Container and type(C_Container.PickupContainerItem) == "function" then
        pcall(C_Container.PickupContainerItem, destinationBag, destinationSlot)
    end
    trackerUI.InvalidateToolEnchantCache()
    ScheduleTrackerRefresh(0.15, false)
end

trackerUI.QueueToolEnchantPurchases = function()
    if not YayaQueueAPI or type(YayaQueueAPI.AddItem) ~= "function" then
        print("YWT: YayaQueue n'est pas disponible")
        return
    end

    local state = trackerUI.FindToolEnchantState(GetTrackedMidnightProfessions())
    local queuedQuantity = 0
    for _, plan in ipairs(state.buyPlan or EMPTY_TABLE) do
        if plan.quantity > 0 then
            YayaQueueAPI.AddItem(plan.itemID, plan.quantity, plan.itemName)
            queuedQuantity = queuedQuantity + plan.quantity
        end
    end
    if queuedQuantity > 0 and type(YayaQueueAPI.Refresh) == "function" then
        YayaQueueAPI.Refresh()
        print(("YWT: %d enchantement(s) ajouté(s) à YayaQueue"):format(queuedQuantity))
    end
    trackerUI.InvalidateToolEnchantCache()
    ScheduleTrackerRefresh(0.05, false)
end

trackerUI.UpdateToolEnchantButtons = function(state)
    local pullButton = trackerFrame and trackerFrame.toolEnchantPullButton
    local buyButton = trackerFrame and trackerFrame.toolEnchantBuyButton
    if not pullButton or not buyButton then
        return false, false
    end

    local hasPull = state and (state.pullQuantity or 0) > 0
    local hasBuy = state and (state.buyQuantity or 0) > 0
    if hasPull then
        local canPull = state.bankOpen and state.bankKnown and #state.pullPlan > 0
        pullButton:SetText(("Pull enchants Warbank x%d"):format(state.pullQuantity))
        pullButton:SetEnabled(canPull)
        pullButton.pullState = state
        pullButton:Show()
    else
        pullButton.pullState = nil
        pullButton:Hide()
    end

    if hasBuy then
        local queueAvailable = YayaQueueAPI and type(YayaQueueAPI.AddItem) == "function"
        buyButton:SetText(("Acheter enchants YQ x%d"):format(state.buyQuantity))
        buyButton:SetEnabled(queueAvailable == true)
        buyButton.buyState = state
        buyButton:Show()
    else
        buyButton.buyState = nil
        buyButton:Hide()
    end
    return hasPull, hasBuy
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
            button:SetText(("Appliquer %s"):format(action.statLabel or "l'enchantement"))
            button.actionState = action
            button.itemID = action.enchantItemID
            button.itemLink = action.enchantLink
            button.toolLink = action.toolLink
            if not (InCombatLockdown and InCombatLockdown()) then
                button:SetAttribute("type", "item")
                button:SetAttribute("item", "item:" .. tostring(action.enchantItemID))
                button:SetAttribute("target-bag", nil)
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
                result.requiredMoxie = result.requiredMoxie + (recipe.moxieCost or MIDNIGHT_RECIPE_MOXIE_COST)
                result.requiredVoidlightMarl = result.requiredVoidlightMarl
                    + (recipe.voidlightMarlCost or runtimeState.midnightRecipeVoidlightMarlCost)
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
        for _, recipe in ipairs(recipeStatus.missingRecipes) do
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
        return EMPTY_TABLE
    end

    local tokens = {}
    local oneTimeTokens = {}
    local accountDB = GetAccountDB()
    local trackProfessionWeeklies = accountDB.trackProfessionWeeklies ~= false
    local trackProfessionLoots = accountDB.trackProfessionLoots ~= false
    local trackProfessionDisenchants = accountDB.trackProfessionDisenchants ~= false
    local trackProfessionTools = accountDB.trackProfessionTools ~= false
    local trackProfessionToolEnchants = accountDB.trackProfessionToolEnchants ~= false
    local remainingTreasures, totalTreasures = CountRemainingTrackedQuests(config.treasureQuestIDs)
    if remainingTreasures > 0 then
        oneTimeTokens[#oneTimeTokens + 1] = ("T%d/%d"):format(remainingTreasures, totalTreasures)
    end

    local remainingWeeklyLoots, totalWeeklyLoots = CountRemainingTrackedQuests(config.weeklyLootQuestIDs)
    if trackProfessionLoots and remainingWeeklyLoots > 0 then
        tokens[#tokens + 1] = ("loot %d/%d"):format(remainingWeeklyLoots, totalWeeklyLoots)
    elseif trackProfessionLoots and totalWeeklyLoots <= 0 and (config.weeklyKnowledgeCap or 0) > 0 then
        tokens[#tokens + 1] = ("loot %d/%d"):format(config.weeklyKnowledgeCap, config.weeklyKnowledgeCap)
    end

    local remainingDisenchants, totalDisenchants = CountRemainingTrackedQuests(config.weeklyDisenchantQuestIDs)
    if trackProfessionDisenchants and remainingDisenchants > 0 then
        tokens[#tokens + 1] = ("dez %d/%d"):format(remainingDisenchants, totalDisenchants)
    end

    local hasTrainerWeeklyUnlocked = row.skillLevel >= (config.trainerMinSkill or math.huge)
    local hasTrainerWeeklyCompleted = IsAnyQuestDone(config.trainerWeeklyQuestIDs or EMPTY_TABLE)
    if trackProfessionWeeklies
        and hasTrainerWeeklyUnlocked
        and (not config.trainerWeeklyQuestIDs or not hasTrainerWeeklyCompleted) then
        tokens[#tokens + 1] = "hebdo"
    end

    local hasTreatiseUnlocked = row.skillLevel >= (config.treatiseMinSkill or math.huge)
    local treatiseTrackingEnabled = accountDB.trackTreatises ~= false
    local treatiseInfo = MIDNIGHT_TREATISES_BY_SKILL_LINE_ID[row.skillLineID]
    local hasTreatiseCompleted = treatiseInfo and IsQuestDone(treatiseInfo.weeklyQuestID) or false
    if treatiseTrackingEnabled and hasTreatiseUnlocked and not hasTreatiseCompleted then
        tokens[#tokens + 1] = "traite"
    end

    if accountDB.trackProfessionDarkmoon ~= false
        and IsDarkmoonFaireActive()
        and config.darkmoonQuestID
        and not IsQuestDone(config.darkmoonQuestID) then
        tokens[#tokens + 1] = "DMF"
    end

    local knowledgeInfo = SafeCall(
        C_ProfSpecs and C_ProfSpecs.GetCurrencyInfoForSkillLine,
        row.skillLineID
    )
    local unspentKnowledge = type(knowledgeInfo) == "table" and knowledgeInfo.numAvailable or 0
    if type(unspentKnowledge) == "number"
        and unspentKnowledge > runtimeState.unspentKnowledgeWarningThreshold then
        tokens[#tokens + 1] = ("|cffff6666KP %d a placer|r"):format(unspentKnowledge)
    end

    local bookStatus = trackerUI.GetMidnightKnowledgeBookStatus(row)
    for _, book in ipairs(bookStatus.missingBooks) do
        oneTimeTokens[#oneTimeTokens + 1] = ("+10KP (%s)"):format(book.label)
    end

    local recipeStatus = trackerUI.GetMidnightRecipeStatus(row)
    for _, recipe in ipairs(recipeStatus.missingRecipes) do
        oneTimeTokens[#oneTimeTokens + 1] = ("recette (%s)"):format(recipe.label)
    end

    local toolStatus = (trackProfessionTools or trackProfessionToolEnchants)
        and trackerUI.GetProfessionToolEnchantStatus(row)
        or EMPTY_TABLE
    if trackProfessionTools
        and toolStatus.hasEquippedTool == false
        and not toolStatus.equippedToolPending then
        oneTimeTokens[#oneTimeTokens + 1] = "outil non equipe"
    end
    if trackProfessionToolEnchants then
        for _, tool in pairs(toolStatus.missingTools or EMPTY_TABLE) do
            oneTimeTokens[#oneTimeTokens + 1] = ("outil %s x%d"):format(tool.label or "?", tool.quantity or 0)
        end
        for _, tool in pairs(toolStatus.missingEnchantTools or EMPTY_TABLE) do
            oneTimeTokens[#oneTimeTokens + 1] = ("outil sans enchant %s x%d"):format(
                tool.label or "?",
                tool.quantity or 0
            )
        end
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

trackerUI.GetMidnightProfessionWarningText = function(row)
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
    local warningParts = {}
    local requiredMoxie = bookStatus.requiredMoxie + recipeStatus.requiredMoxie
    if requiredMoxie > 0 and currentMoxie < requiredMoxie then
        local moxieText = ("moxie %d/%d"):format(currentMoxie, requiredMoxie)
        warningParts[#warningParts + 1] = "|cffff3333" .. moxieText .. "|r"
    elseif currentMoxie > MOXIE_WARNING_THRESHOLD then
        warningParts[#warningParts + 1] = ("|cffff9966moxie %d|r"):format(currentMoxie)
    end
    if bookStatus.requiredAbundance > 0 and bookStatus.currentAbundance < bookStatus.requiredAbundance then
        local abundanceText = ("abondance %d/%d"):format(
            bookStatus.currentAbundance,
            bookStatus.requiredAbundance
        )
        warningParts[#warningParts + 1] = "|cffff3333" .. abundanceText .. "|r"
    end
    if recipeStatus.requiredVoidlightMarl > 0
        and recipeStatus.currentVoidlightMarl < recipeStatus.requiredVoidlightMarl then
        local marlText = ("marls %d/%d"):format(
            recipeStatus.currentVoidlightMarl,
            recipeStatus.requiredVoidlightMarl
        )
        warningParts[#warningParts + 1] = "|cffff3333" .. marlText .. "|r"
    end
    if #warningParts > 0 then
        return table.concat(warningParts, " ")
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

trackerUI.AddMidnightProfessionEntries = function(entries, trackedRows, oneTimeEntries)
    local oneTimeRows = {}
    for _, row in ipairs(trackedRows or GetTrackedMidnightProfessions()) do
        local tokens, oneTimeTokens = trackerUI.BuildMidnightProfessionTokens(row)
        local warningText = trackerUI.GetMidnightProfessionWarningText(row)
        if #tokens > 0 then
            AddEntry(entries, row.config.label, "todo", {
                displayText = ("%s: |cff7fff7f%s|r%s"):format(
                    row.config.label,
                    table.concat(tokens, " "),
                    ""
                ),
            })
        end
        if #oneTimeTokens > 0 or warningText then
            oneTimeRows[#oneTimeRows + 1] = { row = row, tokens = oneTimeTokens }
        end
    end

    if #oneTimeRows > 0 then
        for _, state in ipairs(oneTimeRows) do
            local warningText = trackerUI.GetMidnightProfessionWarningText(state.row)
            local displayText = table.concat(state.tokens, " ")
            if displayText ~= "" then
                displayText = "|cffd6b36a" .. displayText .. "|r"
            end
            if warningText then
                displayText = displayText .. (displayText ~= "" and " " or "") .. warningText
            end
            AddEntry(oneTimeEntries or entries, state.row.config.label, "todo", {
                displayText = ("%s: %s"):format(state.row.config.label, displayText),
            })
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

trackerUI.FormatEntry = function(entry)
    if entry.displayText then
        return entry.displayText
    end

    if entry.state == "todo" then
        return ("%s: |cff7fff7fa faire|r"):format(entry.label)
    end

    return ("%s: |cffffcc66a debloquer|r"):format(entry.label)
end

trackerUI.EnsureTrackerLine = function(index)
    if trackerFrame.lines[index] then
        return trackerFrame.lines[index]
    end

    local line = trackerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetWidth(178)
    line:SetJustifyH("LEFT")
    trackerFrame.lines[index] = line
    return line
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

    local title = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(panel.name)

    local description = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Reglages partages par tout le compte.")

    local function AddSection(titleText, anchor)
        local section = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        section:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
        section:SetText("|cffffd100" .. titleText .. "|r")

        local divider = scrollChild:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(0.45, 0.34, 0.12, 0.65)
        divider:SetPoint("LEFT", section, "RIGHT", 8, 0)
        divider:SetPoint("RIGHT", scrollChild, "RIGHT", -18, 0)
        divider:SetHeight(1)
        return section
    end

    local checkbox = CreateFrame("CheckButton", addonName .. "HideInCombatCheckbox", scrollChild, "UICheckButtonTemplate")
    local displaySection = AddSection("Affichage", description)
    checkbox:SetPoint("TOPLEFT", displaySection, "BOTTOMLEFT", 0, -8)
    local checkboxLabel = checkbox.Text or checkbox.text
    if not checkboxLabel then
        checkboxLabel = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkboxLabel:SetPoint("LEFT", checkbox, "RIGHT", 2, 1)
        checkbox.Text = checkboxLabel
    end
    checkboxLabel:SetText("Cacher integralement la frame en combat")
    checkbox:SetScript("OnClick", function(self)
        GetAccountDB().hideInCombat = self:GetChecked() and true or false
        trackerUI.ApplyCombatVisibility()
    end)

    panel.trackingCheckboxes = {}
    local previousCheckbox = checkbox
    local previousCategory
    for index, option in ipairs(runtimeState.trackingOptions) do
        if option.category ~= previousCategory then
            previousCategory = option.category
            local section = AddSection(option.category, previousCheckbox)
            previousCheckbox = section
        end

        local trackingCheckbox = CreateFrame(
            "CheckButton",
            addonName .. "TrackingCheckbox" .. index,
            scrollChild,
            "UICheckButtonTemplate"
        )
        trackingCheckbox:SetPoint("TOPLEFT", previousCheckbox, "BOTTOMLEFT", 0, -6)
        trackingCheckbox.optionKey = option.key
        local trackingLabel = trackingCheckbox.Text or trackingCheckbox.text
        if not trackingLabel then
            trackingLabel = trackingCheckbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            trackingLabel:SetPoint("LEFT", trackingCheckbox, "RIGHT", 2, 1)
            trackingCheckbox.Text = trackingLabel
        end
        trackingLabel:SetText(option.label)
        trackingCheckbox:SetScript("OnClick", function(self)
            GetAccountDB()[self.optionKey] = self:GetChecked() and true or false
            if self.optionKey == "autoOpenContainers"
                and _G.YayaWeeklyTrackerAutoOpen
                and type(_G.YayaWeeklyTrackerAutoOpen.Refresh) == "function"
            then
                _G.YayaWeeklyTrackerAutoOpen.Refresh()
            end
            ScheduleTrackerRefresh(0, false)
        end)
        panel.trackingCheckboxes[index] = trackingCheckbox
        previousCheckbox = trackingCheckbox
    end

    local function UpdateScrollChildSize()
        local width = scrollFrame:GetWidth() or 0
        if width > 0 then
            scrollChild:SetWidth(width)
        end

        local contentTop = scrollChild:GetTop()
        local lastBottom = previousCheckbox:GetBottom()
        if contentTop and lastBottom then
            scrollChild:SetHeight(math.max(1, contentTop - lastBottom + 18))
        else
            scrollChild:SetHeight(600)
        end
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
    trackerFrame.title:SetText("Hebdo")
    trackerFrame:SetHeight(38)
    trackerFrame.bg:SetHeight(38)

    local line = trackerUI.EnsureTrackerLine(1)
    line:SetFontObject(GameFontHighlightSmall)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", 6, -20)
    line:SetText(message or "YWT: erreur")
    line:Show()

    for index = 2, #trackerFrame.lines do
        local extraLine = trackerFrame.lines[index]
        if extraLine then
            extraLine:SetText("")
            extraLine:Hide()
        end
    end
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
        local warbankTreatiseState = DebugSafeCall("FindMissingMidnightTreatisesInWarbank", trackerUI.FindMissingMidnightTreatisesInWarbank, trackedRows)
        local hasKnowledgeButton = DebugSafeCall("UpdateMidnightKnowledgeButton", trackerUI.UpdateMidnightKnowledgeButton, knowledgeItemState) or false
        local hasRecipeButton = DebugSafeCall("UpdateMidnightRecipeButton", trackerUI.UpdateMidnightRecipeButton, recipeItemState) or false
        local hasRecipeMarlButton = DebugSafeCall("UpdateMidnightRecipeTransferButton", trackerUI.UpdateMidnightRecipeTransferButton, trackedRows) or false
        local hasPayoutButton = DebugSafeCall("UpdateArtisanConsortiumPayoutButton", trackerUI.UpdateArtisanConsortiumPayoutButton, payoutItemState) or false
        local surplusButtonCount = DebugSafeCall("UpdateSurplusReagentButtons", trackerUI.UpdateSurplusReagentButtons, surplusReagentStates) or 0
        local finishingReagentMergeButtonCount = DebugSafeCall("UpdateFinishingReagentMergeButtons", trackerUI.UpdateFinishingReagentMergeButtons, finishingReagentMergeStates) or 0
        local warbankTreatiseButtonCount = DebugSafeCall("UpdateWarbankTreatiseButtons", trackerUI.UpdateWarbankTreatiseButtons, warbankTreatiseState) or 0
        DebugSafeCall("EnsureEnchantingWeeklyQueueItem", trackerUI.EnsureEnchantingWeeklyQueueItem, trackedRows)
        local hasTreasureButton = DebugSafeCall("UpdateMidnightTreasureButton", trackerUI.UpdateMidnightTreasureButton, trackedRows) or false
        local accountDB = GetAccountDB()
        local trackProfessionTools = accountDB.trackProfessionTools ~= false
        local trackProfessionToolEnchants = accountDB.trackProfessionToolEnchants ~= false
        local toolEnchantState
        if trackProfessionTools or trackProfessionToolEnchants then
            toolEnchantState = DebugSafeCall("FindToolEnchantState", trackerUI.FindToolEnchantState, trackedRows)
        end
        if trackProfessionToolEnchants and toolEnchantState then
            DebugSafeCall(
                "ConfirmToolEnchantApplications",
                trackerUI.ConfirmToolEnchantApplications,
                toolEnchantState
            )
        end
        local hasToolEnchantPullButton, hasToolEnchantBuyButton = DebugSafeCall(
            "UpdateToolEnchantButtons",
            trackerUI.UpdateToolEnchantButtons,
            trackProfessionToolEnchants and toolEnchantState or nil
        )
        hasToolEnchantPullButton = hasToolEnchantPullButton or false
        hasToolEnchantBuyButton = hasToolEnchantBuyButton or false
        local toolEnchantApplyButtonCount = DebugSafeCall(
            "UpdateToolEnchantApplyButtons",
            trackerUI.UpdateToolEnchantApplyButtons,
            trackProfessionToolEnchants and toolEnchantState or nil
        ) or 0
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
        local trackerDebugSignature = ("%d|kp=%s|recipe=%s|marl=%s|po=%s|sr=%d|fm=%d|wb=%d|tt=%s|tep=%s|teb=%s|tea=%d|ao=%s"):format(#entries, tostring(hasKnowledgeButton), tostring(hasRecipeButton), tostring(hasRecipeMarlButton), tostring(hasPayoutButton), surplusButtonCount, finishingReagentMergeButtonCount, warbankTreatiseButtonCount, tostring(hasTreasureButton), tostring(hasToolEnchantPullButton), tostring(hasToolEnchantBuyButton), toolEnchantApplyButtonCount, tostring(hasAutoOpenButton))
        if trackerDebugSignature ~= debugSignatures.tracker then
            debugSignatures.tracker = trackerDebugSignature
            DebugLog("UpdateTracker entries=%d kpButton=%s recipeButton=%s marlButton=%s payoutButton=%s surplusButtons=%d mergeButtons=%d warbankTreatiseButtons=%d treasureButton=%s toolPull=%s toolBuy=%s toolApply=%d autoOpen=%s", #entries, tostring(hasKnowledgeButton), tostring(hasRecipeButton), tostring(hasRecipeMarlButton), tostring(hasPayoutButton), surplusButtonCount, finishingReagentMergeButtonCount, warbankTreatiseButtonCount, tostring(hasTreasureButton), tostring(hasToolEnchantPullButton), tostring(hasToolEnchantBuyButton), toolEnchantApplyButtonCount, tostring(hasAutoOpenButton))
        end
        local hasUsefulEntry = false
        for _, entry in ipairs(entries) do
            if not entry.satisfied then
                hasUsefulEntry = true
                break
            end
        end
        if not hasUsefulEntry and not hasKnowledgeButton and not hasRecipeButton and not hasRecipeMarlButton and not hasPayoutButton and surplusButtonCount == 0 and finishingReagentMergeButtonCount == 0 and warbankTreatiseButtonCount == 0 and not hasTreasureButton and not hasToolEnchantPullButton and not hasToolEnchantBuyButton and toolEnchantApplyButtonCount == 0 and not hasAutoOpenButton then
            DebugLog("UpdateTracker hide frame: all professions complete and no other actions")
            trackerFrame:Hide()
            if YayaFrameAPI and type(YayaFrameAPI.Refresh) == "function" then
                YayaFrameAPI:Refresh()
            end
            return
        end

        DebugLog("UpdateTracker show frame with %d entries", #entries)
        trackerFrame:Show()

        local offsetY = 20
        local lineCount = math.max(#entries, #trackerFrame.lines)
        for index = 1, lineCount do
            local line = trackerUI.EnsureTrackerLine(index)
            local entry = entries[index]
            if entry then
                line:SetFontObject(entry.prominent and GameFontHighlight or GameFontHighlightSmall)
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", 6, -offsetY)
                line:SetText(trackerUI.FormatEntry(entry))
                line:Show()
                local minimumLineHeight = entry.prominent and 18 or 14
                local renderedLineHeight = line.GetStringHeight and line:GetStringHeight() or minimumLineHeight
                offsetY = offsetY + math.max(minimumLineHeight, math.ceil(renderedLineHeight) + 2)
            else
                line:SetText("")
                line:Hide()
            end
        end

        if hasPayoutButton then
            trackerFrame.payoutButton:ClearAllPoints()
            trackerFrame.payoutButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            offsetY = offsetY + 24
        end

        if hasKnowledgeButton then
            trackerFrame.knowledgeButton:ClearAllPoints()
            if hasPayoutButton then
                trackerFrame.knowledgeButton:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.knowledgeButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            offsetY = offsetY + 24
        end

        if hasRecipeButton then
            trackerFrame.recipeButton:ClearAllPoints()
            if hasKnowledgeButton then
                trackerFrame.recipeButton:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                trackerFrame.recipeButton:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.recipeButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            offsetY = offsetY + 24
        end

        if hasRecipeMarlButton then
            trackerFrame.recipeMarlButton:ClearAllPoints()
            if hasRecipeButton then
                trackerFrame.recipeMarlButton:SetPoint("TOPLEFT", trackerFrame.recipeButton, "BOTTOMLEFT", 0, -4)
            elseif hasKnowledgeButton then
                trackerFrame.recipeMarlButton:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                trackerFrame.recipeMarlButton:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.recipeMarlButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            offsetY = offsetY + 24
        end

        local lastSurplusButton
        for index = 1, surplusButtonCount do
            local button = trackerFrame.surplusReagentButtons[index]
            button:ClearAllPoints()
            if lastSurplusButton then
                button:SetPoint("TOPLEFT", lastSurplusButton, "BOTTOMLEFT", 0, -4)
            elseif hasRecipeMarlButton then
                button:SetPoint("TOPLEFT", trackerFrame.recipeMarlButton, "BOTTOMLEFT", 0, -4)
            elseif hasRecipeButton then
                button:SetPoint("TOPLEFT", trackerFrame.recipeButton, "BOTTOMLEFT", 0, -4)
            elseif hasKnowledgeButton then
                button:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                button:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            else
                button:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            lastSurplusButton = button
            offsetY = offsetY + 24
        end

        local lastFinishingReagentMergeButton
        for index = 1, finishingReagentMergeButtonCount do
            local button = trackerFrame.finishingReagentMergeButtons[index]
            button:ClearAllPoints()
            if lastFinishingReagentMergeButton then
                button:SetPoint("TOPLEFT", lastFinishingReagentMergeButton, "BOTTOMLEFT", 0, -4)
            elseif lastSurplusButton then
                button:SetPoint("TOPLEFT", lastSurplusButton, "BOTTOMLEFT", 0, -4)
            elseif hasRecipeMarlButton then
                button:SetPoint("TOPLEFT", trackerFrame.recipeMarlButton, "BOTTOMLEFT", 0, -4)
            elseif hasRecipeButton then
                button:SetPoint("TOPLEFT", trackerFrame.recipeButton, "BOTTOMLEFT", 0, -4)
            elseif hasKnowledgeButton then
                button:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                button:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            else
                button:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            lastFinishingReagentMergeButton = button
            offsetY = offsetY + 24
        end

        local lastWarbankTreatiseButton
        for index = 1, warbankTreatiseButtonCount do
            local button = trackerFrame.warbankTreatiseButtons[index]
            button:ClearAllPoints()
            if lastWarbankTreatiseButton then
                button:SetPoint("TOPLEFT", lastWarbankTreatiseButton, "BOTTOMLEFT", 0, -4)
            elseif lastFinishingReagentMergeButton then
                button:SetPoint("TOPLEFT", lastFinishingReagentMergeButton, "BOTTOMLEFT", 0, -4)
            elseif lastSurplusButton then
                button:SetPoint("TOPLEFT", lastSurplusButton, "BOTTOMLEFT", 0, -4)
            elseif hasRecipeMarlButton then
                button:SetPoint("TOPLEFT", trackerFrame.recipeMarlButton, "BOTTOMLEFT", 0, -4)
            elseif hasRecipeButton then
                button:SetPoint("TOPLEFT", trackerFrame.recipeButton, "BOTTOMLEFT", 0, -4)
            elseif hasKnowledgeButton then
                button:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                button:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            else
                button:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            lastWarbankTreatiseButton = button
            offsetY = offsetY + 24
        end

        if hasTreasureButton then
            trackerFrame.treasureButton:ClearAllPoints()
            if lastWarbankTreatiseButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", lastWarbankTreatiseButton, "BOTTOMLEFT", 0, -4)
            elseif lastFinishingReagentMergeButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", lastFinishingReagentMergeButton, "BOTTOMLEFT", 0, -4)
            elseif lastSurplusButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", lastSurplusButton, "BOTTOMLEFT", 0, -4)
            elseif hasRecipeMarlButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", trackerFrame.recipeMarlButton, "BOTTOMLEFT", 0, -4)
            elseif hasRecipeButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", trackerFrame.recipeButton, "BOTTOMLEFT", 0, -4)
            elseif hasKnowledgeButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.treasureButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            offsetY = offsetY + 24
        end

        local lastActionButton
        if hasTreasureButton then
            lastActionButton = trackerFrame.treasureButton
        elseif lastWarbankTreatiseButton then
            lastActionButton = lastWarbankTreatiseButton
        elseif lastFinishingReagentMergeButton then
            lastActionButton = lastFinishingReagentMergeButton
        elseif lastSurplusButton then
            lastActionButton = lastSurplusButton
        elseif hasRecipeMarlButton then
            lastActionButton = trackerFrame.recipeMarlButton
        elseif hasRecipeButton then
            lastActionButton = trackerFrame.recipeButton
        elseif hasKnowledgeButton then
            lastActionButton = trackerFrame.knowledgeButton
        elseif hasPayoutButton then
            lastActionButton = trackerFrame.payoutButton
        end

        if hasToolEnchantPullButton then
            trackerFrame.toolEnchantPullButton:ClearAllPoints()
            if lastActionButton then
                trackerFrame.toolEnchantPullButton:SetPoint("TOPLEFT", lastActionButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.toolEnchantPullButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            lastActionButton = trackerFrame.toolEnchantPullButton
            offsetY = offsetY + 24
        end

        if hasToolEnchantBuyButton then
            trackerFrame.toolEnchantBuyButton:ClearAllPoints()
            if lastActionButton then
                trackerFrame.toolEnchantBuyButton:SetPoint("TOPLEFT", lastActionButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.toolEnchantBuyButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            lastActionButton = trackerFrame.toolEnchantBuyButton
            offsetY = offsetY + 24
        end

        local lastToolEnchantApplyButton
        for index = 1, toolEnchantApplyButtonCount do
            local button = trackerFrame.toolEnchantApplyButtons[index]
            button:ClearAllPoints()
            if lastToolEnchantApplyButton then
                button:SetPoint("TOPLEFT", lastToolEnchantApplyButton, "BOTTOMLEFT", 0, -4)
            elseif lastActionButton then
                button:SetPoint("TOPLEFT", lastActionButton, "BOTTOMLEFT", 0, -4)
            else
                button:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            lastToolEnchantApplyButton = button
            offsetY = offsetY + 24
        end

        if hasAutoOpenButton then
            autoOpenButton:ClearAllPoints()
            if lastToolEnchantApplyButton then
                autoOpenButton:SetPoint("TOPLEFT", lastToolEnchantApplyButton, "BOTTOMLEFT", 0, -4)
            elseif lastActionButton then
                autoOpenButton:SetPoint("TOPLEFT", lastActionButton, "BOTTOMLEFT", 0, -4)
            else
                autoOpenButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            -- Ancre pose, on peut afficher : le bouton n'apparait jamais sans
            -- position. Le state driver [combat] hide reste maitre en combat.
            if not (InCombatLockdown and InCombatLockdown()) then
                autoOpenButton:Show()
            end
            offsetY = offsetY + 24
        end

        local height = offsetY + 4
        trackerFrame:SetHeight(height)
        trackerFrame.bg:SetHeight(height)
        if YayaFrameAPI and type(YayaFrameAPI.Refresh) == "function" then
            YayaFrameAPI:Refresh()
        end
        DebugLog("UpdateTracker final height=%d", height)
    end)

    if not ok then
        DebugLog("UpdateTracker fatal: %s", tostring(err))
        runtimeState.showTrackerDiagnostic(("YWT: |cffff6666%s|r"):format(tostring(err)))
    end
end

trackerUI.CreateTrackerFrame = function()
    if not YayaFrameAPI or type(YayaFrameAPI.GetFrame) ~= "function" then
        return
    end

    trackerFrame = CreateFrame("Frame", addonName .. "Frame", YayaFrameAPI:GetFrame())
    DebugLog("CreateTrackerFrame %s", tostring(addonName .. "Frame"))
    trackerFrame:SetFrameStrata("MEDIUM")
    trackerFrame:SetSize(190, 24)
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

    trackerFrame.bg = trackerFrame:CreateTexture(nil, "BACKGROUND")
    trackerFrame.bg:SetPoint("TOPLEFT")
    trackerFrame.bg:SetPoint("TOPRIGHT")
    trackerFrame.bg:SetHeight(24)
    trackerFrame.bg:SetColorTexture(0, 0, 0, 0.55)

    trackerFrame.title = trackerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trackerFrame.title:SetPoint("TOPLEFT", 6, -5)
    trackerFrame.title:SetText("Hebdo")

    trackerFrame.knowledgeButton = CreateFrame("Button", addonName .. "KnowledgeButton", trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    trackerFrame.knowledgeButton:SetSize(178, 20)
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
    trackerFrame.recipeButton:SetSize(178, 20)
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
    trackerFrame.recipeMarlButton:SetSize(178, 20)
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
    trackerFrame.payoutButton:SetSize(178, 20)
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
    trackerFrame.autoOpenButton:SetSize(178, 20)
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
        button:SetSize(178, 20)
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
        button:SetSize(178, 20)
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

    trackerFrame.warbankTreatiseButtons = {}
    for index = 1, 11 do
        local button = CreateFrame("Button", addonName .. "WarbankTreatiseButton" .. index, trackerFrame, "UIPanelButtonTemplate")
        button:SetSize(178, 20)
        button:RegisterForClicks("AnyUp")
        button:SetText("Récupérer traité")
        button:Hide()
        button:SetScript("OnClick", function(self, _, down)
            if down then
                return
            end
            trackerUI.PullWarbankTreatise(self)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Récupère un seul traité depuis la Warbank.")
            if self.itemLink then
                GameTooltip:AddLine(self.itemLink, 0.5, 0.8, 1, true)
            end
            GameTooltip:AddLine("Le reste du stack reste dans la Warbank.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        trackerFrame.warbankTreatiseButtons[index] = button
    end

    trackerFrame.treasureButton = CreateFrame("Button", addonName .. "TreasureButton", trackerFrame, "UIPanelButtonTemplate")
    trackerFrame.treasureButton:SetSize(178, 20)
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

    trackerFrame.toolEnchantPullButton = CreateFrame("Button", addonName .. "ToolEnchantPullButton", trackerFrame, "UIPanelButtonTemplate")
    trackerFrame.toolEnchantPullButton:SetSize(178, 20)
    trackerFrame.toolEnchantPullButton:RegisterForClicks("AnyUp", "AnyDown")
    trackerFrame.toolEnchantPullButton:SetText("Pull enchants Warbank")
    trackerFrame.toolEnchantPullButton:Hide()
    trackerFrame.toolEnchantPullButton:SetScript("OnClick", function(_, _, down)
        if down then
            return
        end
        trackerUI.PullToolEnchantItems()
    end)
    trackerFrame.toolEnchantPullButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Récupère uniquement la quantité nécessaire depuis la Warbank.")
        local state = self.pullState
        if state and state.pullQuantity then
            GameTooltip:AddLine(("À récupérer : %d"):format(state.pullQuantity), 1, 1, 1, true)
        end
        if not self:IsEnabled() then
            GameTooltip:AddLine("Ouvre la Warbank et attends le chargement de son contenu.", 1, 0.6, 0.2, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.toolEnchantPullButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.toolEnchantBuyButton = CreateFrame("Button", addonName .. "ToolEnchantBuyButton", trackerFrame, "UIPanelButtonTemplate")
    trackerFrame.toolEnchantBuyButton:SetSize(178, 20)
    trackerFrame.toolEnchantBuyButton:RegisterForClicks("AnyUp", "AnyDown")
    trackerFrame.toolEnchantBuyButton:SetText("Acheter enchants YQ")
    trackerFrame.toolEnchantBuyButton:Hide()
    trackerFrame.toolEnchantBuyButton:SetScript("OnClick", function(_, _, down)
        if down then
            return
        end
        trackerUI.QueueToolEnchantPurchases()
    end)
    trackerFrame.toolEnchantBuyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajoute les déficits d'enchantements à la queue YayaQueue.")
        local state = self.buyState
        if state and state.buyQuantity then
            GameTooltip:AddLine(("À acheter : %d"):format(state.buyQuantity), 1, 1, 1, true)
        end
        if not self:IsEnabled() then
            GameTooltip:AddLine("YayaQueue n'est pas disponible.", 1, 0.4, 0.4, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.toolEnchantBuyButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.toolEnchantApplyButtons = {}
    for index = 1, 11 do
        local button = CreateFrame("Button", addonName .. "ToolEnchantApplyButton" .. index, trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
        button:SetSize(178, 20)
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
            GameTooltip:SetText("Applique l'enchantement sur l'outil équipé correspondant.")
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
                trackerUI.InvalidateWarbankTreatiseCache()
                trackerUI.InvalidateToolEnchantCache()
                debugSignatures.knowledge = nil
                debugSignatures.payout = nil
                debugSignatures.surplusReagents = nil
                debugSignatures.trackedProfessions = nil
                debugSignatures.tracker = nil
                debugSignatures.treasure = nil
                debugSignatures.warbankTreatises = nil
                debugSignatures.toolEnchants = nil
                DebugLog("Forced debug refresh")
            elseif command == "log" then
                PrintPersistentDebugLog(20)
            elseif command:match("^log%s+%d+$") then
                PrintPersistentDebugLog(command:match("^log%s+(%d+)$"))
            elseif command == "log clear" then
                ClearPersistentDebugLog()
                print("YWT: Log vide")
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
        trackerUI.InvalidateWarbankTreatiseCache()
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
        trackerUI.InvalidateWarbankTreatiseCache()
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
        trackerUI.InvalidateWarbankTreatiseCache()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0.05, false)
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.75, function()
                trackerUI.InvalidateWarbankTreatiseCache()
                trackerUI.InvalidateToolEnchantCache()
                ScheduleTrackerRefresh(0, false)
            end)
        end
    elseif event == "BANKFRAME_CLOSED" then
        trackerUI.InvalidateWarbankTreatiseCache()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0, false)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
        or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if Enum and Enum.PlayerInteractionType
            and interactionType == Enum.PlayerInteractionType.AccountBanker then
            trackerUI.InvalidateWarbankTreatiseCache()
            trackerUI.InvalidateToolEnchantCache()
            ScheduleTrackerRefresh(event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and 0.05 or 0, false)
        end
    elseif event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        trackerUI.InvalidateWarbankTreatiseCache()
        trackerUI.InvalidateToolEnchantCache()
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "SPELLS_CHANGED"
        or event == "SKILL_LINES_CHANGED"
        or event == "TRADE_SKILL_SHOW"
        or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        InvalidateTrackedMidnightProfessions()
        trackerUI.InvalidateWarbankTreatiseCache()
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

