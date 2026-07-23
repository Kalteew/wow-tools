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
local CONCENTRATION_WARNING_THRESHOLD = 750
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
    [260538] = { order = 2, label = "Eng" }, -- Master Engineer's Surplus Reagents
}
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
    worldBossMaxUsefulItemLevel = 250,
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
    liadrinWeeklyQuestIDs = {
        93766, -- Midnight: World Quests
        93767, -- Midnight: Arcantina
        93769, -- Midnight: Housing
        93889, -- Midnight: Saltheril's Soiree
        93890, -- Midnight: Abundance
        93891, -- Midnight: Legends of the Haranir
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
AddMidnightKnowledgeItems(2906, { 245755, 246320, 246321, 259188, 259189, 262645, 263454 })

AddMidnightKnowledgeItemRange(2907, 238540, 238547)
AddMidnightKnowledgeItems(2907, { 245763, 246322, 246323, 259190, 259191, 262644, 263455 })

AddMidnightKnowledgeItemRange(2909, 238548, 238555)
AddMidnightKnowledgeItems(2909, { 227659, 245759, 246324, 246325, 250445, 257600, 259192, 259193, 263464, 267653, 267654, 267655 })

AddMidnightKnowledgeItemRange(2910, 238556, 238563)
AddMidnightKnowledgeItems(2910, { 245754, 246326, 246327, 259194, 259195, 262646, 263456 })

AddMidnightKnowledgeItemRange(2912, 238468, 238475)
AddMidnightKnowledgeItems(2912, { 238465, 238466, 250443, 258410, 263462 })

AddMidnightKnowledgeItemRange(2913, 238572, 238579)
AddMidnightKnowledgeItems(2913, { 245757, 246328, 246329, 258411, 259196, 259197, 263457 })

AddMidnightKnowledgeItemRange(2914, 238580, 238587)
AddMidnightKnowledgeItems(2914, { 245760, 246330, 246331, 257599, 259198, 259199, 263458 })

AddMidnightKnowledgeItemRange(2915, 238588, 238595)
AddMidnightKnowledgeItems(2915, { 245758, 246332, 246333, 250922, 259200, 259201, 263459 })

AddMidnightKnowledgeItemRange(2916, 238596, 238603)
AddMidnightKnowledgeItems(2916, { 237496, 237506, 245762, 250444, 250924, 263463 })

AddMidnightKnowledgeItemRange(2917, 238628, 238635)
AddMidnightKnowledgeItems(2917, { 238625, 238626, 245764, 250360, 250923, 263461 })

AddMidnightKnowledgeItemRange(2918, 238612, 238619)
AddMidnightKnowledgeItems(2918, { 245756, 246334, 246335, 257601, 259202, 259203, 263460 })

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
    relativePoint = "TOPRIGHT",
    x = 14,
    y = -8,
}

local EMPTY_TABLE = {}
local TRACKER_DEFAULTS = {
    debugEnabled = true,
    hideInCombat = false,
    refreshDelaySeconds = 0.20,
    questStateCacheTTLSeconds = 5,
    questRewardCacheTTLSeconds = 30,
    questRewardMissCacheTTLSeconds = 2,
    debugLogLimit = 400,
}
local TRACKED_ASSAULT_CACHE_ITEM_IDS = {}
local NZOTH_ASSAULT_DETAILS_BY_ITEM_ID = {}
local trackerFrame
local scanTooltip
local activeCacheOpen
runtimeState.activeCacheFinalizeToken = 0
runtimeState.trackerRefreshToken = 0
runtimeState.trackerNeedsJardOwnerRefresh = false
runtimeState.trackerRefreshDeferredByCombat = false
local questStateCache = {}
local questRewardCache = {}
local midnightCaches = {
    trackedProfessions = nil,
    trackedProfessionsDirty = true,
    knowledge = nil,
    knowledgeDirty = true,
    payout = nil,
    payoutDirty = true,
    surplusReagents = nil,
    surplusReagentsDirty = true,
}
local treasureWaypointUIDs = {}
local treasureWaypointSignature
local debugSignatures = {
    knowledge = nil,
    payout = nil,
    surplusReagents = nil,
    trackedProfessions = nil,
    tracker = nil,
    treasure = nil,
}
local GetContainerItemIDCompat
local GetContainerNumSlotsCompat
local GetContainerItemLinkCompat
local GetDateAtNoonTimestamp
local AddEntry
local UpdateTracker
local trackerUI = {}

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
    return YayaWeeklyTrackerAccountDB
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
    accountDB.debugLog[#accountDB.debugLog + 1] = ("[%s] %s"):format(timestamp, tostring(message or ""))
    local overflow = #accountDB.debugLog - TRACKER_DEFAULTS.debugLogLimit
    if overflow > 0 then
        for _ = 1, overflow do
            table.remove(accountDB.debugLog, 1)
        end
    end
end

local function PrintPersistentDebugLog(limit)
    local lines = GetAccountDB().debugLog or {}
    limit = math.max(1, math.floor(tonumber(limit) or 20))
    local firstIndex = math.max(1, #lines - limit + 1)
    for index = firstIndex, #lines do
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
    midnightCaches.trackedProfessions = nil
    midnightCaches.trackedProfessionsDirty = true
    midnightCaches.knowledge = nil
    midnightCaches.knowledgeDirty = true
    midnightCaches.payout = nil
    midnightCaches.payoutDirty = true
    midnightCaches.surplusReagents = nil
    midnightCaches.surplusReagentsDirty = true
end

local function InvalidateMidnightKnowledgeConsumableCache()
    midnightCaches.knowledge = nil
    midnightCaches.knowledgeDirty = true
end

local function InvalidateArtisanConsortiumPayoutCache()
    midnightCaches.payout = nil
    midnightCaches.payoutDirty = true
end

trackerUI.InvalidateSurplusReagentContainerCache = function()
    midnightCaches.surplusReagents = nil
    midnightCaches.surplusReagentsDirty = true
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
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if type(info) == "table" then
            return info.quantity or 0
        end
    end

    return 0
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
    local concentrationCurrencyID = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetConcentrationCurrencyID, skillLineID)
    if type(concentrationCurrencyID) ~= "number" or concentrationCurrencyID <= 0 then
        concentrationCurrencyID = nil
    end
    if type(info) == "table" then
        DebugLog(
            "ProfessionInfoBySkillLineID input=%s professionID=%s parentProfessionID=%s skillLineID=%s skill=%s/%s",
            tostring(skillLineID),
            tostring(info.professionID),
            tostring(info.parentProfessionID),
            tostring(info.skillLineID),
            tostring(info.skillLevel),
            tostring(info.maxSkillLevel)
        )
        return {
            skillLineID = info.professionID or info.skillLineID or skillLineID,
            parentSkillLineID = info.parentProfessionID,
            professionName = info.professionName,
            parentProfessionName = info.parentProfessionName,
            skillLevel = info.skillLevel or 0,
            maxSkillLevel = info.maxSkillLevel or 0,
            concentrationCurrencyID = concentrationCurrencyID or info.concentrationCurrencyID,
        }
    end

    local _, skillLevel, maxSkillLevel = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineInfoByID, skillLineID)
    DebugLog(
        "TradeSkillLineInfoByID input=%s skill=%s/%s",
        tostring(skillLineID),
        tostring(skillLevel),
        tostring(maxSkillLevel)
    )
    return {
        skillLineID = skillLineID,
        skillLevel = skillLevel or 0,
        maxSkillLevel = maxSkillLevel or 0,
        concentrationCurrencyID = concentrationCurrencyID,
    }
end

local function GetTrackedMidnightProfessions()
    if not midnightCaches.trackedProfessionsDirty and midnightCaches.trackedProfessions then
        return midnightCaches.trackedProfessions
    end

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

    local function AddTrackedProfession(skillLineID, skillLevel, maxSkillLevel, concentrationCurrencyID)
        local existingRow = rowBySkillLineID[skillLineID]
        if existingRow then
            if concentrationCurrencyID and not existingRow.concentrationCurrencyID then
                existingRow.concentrationCurrencyID = concentrationCurrencyID
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
            concentrationCurrencyID = concentrationCurrencyID,
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
                        info.maxSkillLevel,
                        info.concentrationCurrencyID
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
                DebugLog(
                    "GetProfessionInfo index=%s skillLineID=%s skill=%s/%s",
                    tostring(professionIndex),
                    tostring(skillLineID),
                    tostring(skillLevel),
                    tostring(maxSkillLevel)
                )
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
                info.maxSkillLevel,
                info.concentrationCurrencyID
            )
        elseif info and info.parentSkillLineID and learnedParentSkillLineIDs[info.parentSkillLineID] and (info.maxSkillLevel or 0) > 0 then
            AddTrackedProfession(
                skillLineID,
                info.skillLevel,
                info.maxSkillLevel,
                info.concentrationCurrencyID
            )
        end
    end

    table.sort(rows, function(a, b)
        return (a.config.order or 999) < (b.config.order or 999)
    end)

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

    trackedRows = trackedRows or GetTrackedMidnightProfessions()

    local trackedSkillLineIDs = {}
    for _, row in ipairs(trackedRows) do
        trackedSkillLineIDs[row.skillLineID] = true
    end

    if not next(trackedSkillLineIDs) then
        midnightCaches.knowledge = {
            totalCount = 0,
        }
        midnightCaches.knowledgeDirty = false
        return midnightCaches.knowledge
    end

    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)
    local firstMatch
    local totalCount = 0

    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            local skillLineID = itemID and MIDNIGHT_KNOWLEDGE_ITEM_SKILL_LINE_IDS[itemID] or nil
            if skillLineID and trackedSkillLineIDs[skillLineID] then
                local treatiseInfo = MIDNIGHT_TREATISES_BY_SKILL_LINE_ID[skillLineID]
                local isCompletedTreatise = treatiseInfo and treatiseInfo.itemID == itemID and IsQuestDone(treatiseInfo.weeklyQuestID)
                if not isCompletedTreatise then
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
        bagID = firstMatch and firstMatch.bagID or nil,
        itemID = firstMatch and firstMatch.itemID or nil,
        itemLink = firstMatch and firstMatch.itemLink or nil,
        itemName = firstMatch and firstMatch.itemName or nil,
        slotIndex = firstMatch and firstMatch.slotIndex or nil,
    }
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

    local maxBagIndex = math.max(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 0, NUM_BAG_SLOTS or 0, 5)
    local matches = {}
    local totalCount = 0

    for bagID = 0, maxBagIndex do
        local slotCount = GetContainerNumSlotsCompat(bagID)
        for slotIndex = 1, slotCount do
            local itemID = GetContainerItemIDCompat(bagID, slotIndex)
            if itemID and ARTISAN_CONSORTIUM_PAYOUT_ITEM_IDS[itemID] then
                totalCount = totalCount + math.max(GetContainerItemCountCompat(bagID, slotIndex), 1)
                matches[#matches + 1] = {
                    bagID = bagID,
                    itemID = itemID,
                    itemLink = GetContainerItemLinkCompat(bagID, slotIndex),
                    itemName = GetItemInfo and GetItemInfo(itemID) or nil,
                    slotIndex = slotIndex,
                    targetKey = tostring(bagID) .. ":" .. tostring(slotIndex),
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
    }
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

trackerUI.FindSurplusReagentContainersInBags = function()
    if not midnightCaches.surplusReagentsDirty and midnightCaches.surplusReagents then
        return midnightCaches.surplusReagents
    end

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

trackerUI.UpdateMidnightKnowledgeButton = function(state)
    local button = trackerFrame and trackerFrame.knowledgeButton or nil
    if not button then
        return false
    end

    if state and state.itemID then
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

trackerUI.UpdateArtisanConsortiumPayoutButton = function(state)
    local button = trackerFrame and trackerFrame.payoutButton or nil
    if not button then
        return false
    end

    if state and state.itemID then
        button:SetText(("Ouvrir payout x%d"):format(state.totalCount or 1))
        button.bagID = state.bagID
        button.slotIndex = state.slotIndex
        button.payoutTargetKey = state.targetKey
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

    for index, button in ipairs(buttons) do
        local state = states and states[index] or nil
        if state and state.itemID then
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

trackerUI.UpdateEnchantingWeeklyQueueButton = function(trackedRows)
    local button = trackerFrame and trackerFrame.enchantingWeeklyButton or nil
    if not button then
        return false
    end

    if not (YayaQueueAPI and type(YayaQueueAPI.AddItem) == "function") then
        button.questID = nil
        button.itemID = nil
        button.itemName = nil
        button.questTitle = nil
        button.needed = nil
        button.missing = nil
        button:Hide()
        return false
    end

    local weekly = trackerUI.FindActiveMidnightEnchantingWeekly(trackedRows)
    if weekly and weekly.missing > 0 then
        button.questID = weekly.questID
        button.itemID = weekly.itemID
        button.itemName = weekly.itemName
        button.questTitle = weekly.questTitle
        button.needed = weekly.needed
        button.missing = weekly.missing
        button:SetText(("YQ Ench +%dx %s"):format(weekly.needed, weekly.itemName))
        button:Show()
        return true
    end

    button.questID = nil
    button.itemID = nil
    button.itemName = nil
    button.questTitle = nil
    button.needed = nil
    button.missing = nil
    button:Hide()
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
        return
    end

    local plan, signature = trackerUI.BuildMidnightTreasureWaypointPlan(GetTrackedMidnightProfessions())
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
    local remainingTreasures, totalTreasures = CountRemainingTrackedQuests(config.treasureQuestIDs)
    if remainingTreasures > 0 then
        tokens[#tokens + 1] = ("T%d/%d"):format(remainingTreasures, totalTreasures)
    end

    local remainingWeeklyLoots, totalWeeklyLoots = CountRemainingTrackedQuests(config.weeklyLootQuestIDs)
    if remainingWeeklyLoots > 0 then
        tokens[#tokens + 1] = ("loot %d/%d"):format(remainingWeeklyLoots, totalWeeklyLoots)
    elseif totalWeeklyLoots <= 0 and (config.weeklyKnowledgeCap or 0) > 0 then
        tokens[#tokens + 1] = ("loot %d/%d"):format(config.weeklyKnowledgeCap, config.weeklyKnowledgeCap)
    end

    local remainingDisenchants, totalDisenchants = CountRemainingTrackedQuests(config.weeklyDisenchantQuestIDs)
    if remainingDisenchants > 0 then
        tokens[#tokens + 1] = ("dez %d/%d"):format(remainingDisenchants, totalDisenchants)
    end

    local hasTrainerWeeklyUnlocked = row.skillLevel >= (config.trainerMinSkill or math.huge)
    local hasTrainerWeeklyCompleted = IsAnyQuestDone(config.trainerWeeklyQuestIDs or EMPTY_TABLE)
    if hasTrainerWeeklyUnlocked and (not config.trainerWeeklyQuestIDs or not hasTrainerWeeklyCompleted) then
        tokens[#tokens + 1] = "hebdo"
    end

    local hasTreatiseUnlocked = row.skillLevel >= (config.treatiseMinSkill or math.huge)
    local accountDB = YayaWeeklyTrackerAccountDB
    local treatiseTrackingEnabled = true
    if type(accountDB) == "table" and accountDB.trackTreatises ~= nil then
        treatiseTrackingEnabled = accountDB.trackTreatises and true or false
    end
    local treatiseInfo = MIDNIGHT_TREATISES_BY_SKILL_LINE_ID[row.skillLineID]
    local hasTreatiseCompleted = treatiseInfo and IsQuestDone(treatiseInfo.weeklyQuestID) or false
    if treatiseTrackingEnabled and hasTreatiseUnlocked and not hasTreatiseCompleted then
        tokens[#tokens + 1] = "traite"
    end

    if IsDarkmoonFaireActive() and config.darkmoonQuestID and not IsQuestDone(config.darkmoonQuestID) then
        tokens[#tokens + 1] = "DMF"
    end

    return tokens
end

trackerUI.GetMidnightProfessionWarningText = function(row)
    local currencyID = row and row.concentrationCurrencyID or nil
    if not currencyID and row and row.skillLineID then
        currencyID = SafeCall(C_TradeSkillUI and C_TradeSkillUI.GetConcentrationCurrencyID, row.skillLineID)
        if type(currencyID) ~= "number" or currencyID <= 0 then
            currencyID = nil
        end
        row.concentrationCurrencyID = currencyID
    end
    if not currencyID then
        return
    end

    local currentConcentration = GetCurrencyQuantity(currencyID)
    if currentConcentration > CONCENTRATION_WARNING_THRESHOLD then
        return ("|cffff9966conc. %d|r"):format(currentConcentration)
    end
end

trackerUI.AddMidnightProfessionEntries = function(entries, trackedRows)
    for _, row in ipairs(trackedRows or GetTrackedMidnightProfessions()) do
        local tokens = trackerUI.BuildMidnightProfessionTokens(row)
        local warningText = trackerUI.GetMidnightProfessionWarningText(row)
        if #tokens > 0 then
            AddEntry(entries, row.config.label, "todo", {
                displayText = ("%s: |cff7fff7f%s|r%s"):format(
                    row.config.label,
                    table.concat(tokens, " "),
                    warningText and (" " .. warningText) or ""
                ),
            })
        else
            AddEntry(entries, row.config.label, "todo", {
                displayText = ("%s: |cff999999ok|r%s"):format(
                    row.config.label,
                    warningText and (" " .. warningText) or ""
                ),
                satisfied = not warningText,
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
        return C_Container.GetContainerItemLink(bagID, slotIndex)
    end

    if GetContainerItemLink then
        return GetContainerItemLink(bagID, slotIndex)
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

    if runtimeState.trackerNeedsJardOwnerRefresh then
        runtimeState.trackerNeedsJardOwnerRefresh = false
        UpdateJardOwners()
    end

    UpdateTracker()
    trackerUI.SyncMidnightTreasureWaypoints()
end

local function ScheduleTrackerRefresh(delaySeconds, refreshJardOwners)
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
        local info = C_Container.GetContainerItemInfo(bagID, slotIndex)
        if info and info.itemID then
            return info.itemID
        end

        if C_Container.GetContainerItemLink and GetItemInfoInstant then
            local link = C_Container.GetContainerItemLink(bagID, slotIndex)
            if link then
                return GetItemInfoInstant(link)
            end
        end
    end

    if GetContainerItemLink and GetItemInfoInstant then
        local link = GetContainerItemLink(bagID, slotIndex)
        if link then
            return GetItemInfoInstant(link)
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

trackerUI.AddGeneralWeeklyEntries = function(entries, activeByQuestID)
    local level = UnitLevel and UnitLevel("player") or 0
    local config = runtimeState.generalWeeklyQuests

    if level > 81 and not IsAnyQuestDone(config.abundanceQuestIDs) then
        AddEntry(entries, "Abondance", "todo")
    end

    if level < 90 then
        return
    end

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

        if rewardMoney > 0 then
            local gold = math.floor((rewardMoney / 10000) + 0.5)
            AddEntry(entries, (GetQuestTitle(worldBossQuestID) or "World boss Midnight") .. " " .. gold .. "g", "todo")
        elseif equippedItemLevel > 0 and equippedItemLevel < config.worldBossMaxUsefulItemLevel then
            AddEntry(entries, GetQuestTitle(worldBossQuestID) or "World boss Midnight", "todo")
        end
    end

    if not IsAnyQuestDone(config.runestoneQuestIDs) then
        AddEntry(entries, "Defense des runestones", "todo")
    end

    if IsQuestActiveOnMap(config.halduronWorldQuestID, activeByQuestID)
        and not IsQuestDone(config.halduronWorldQuestID) then
        AddEntry(entries, "Halduron: World Quests", "todo")
    end

    if not trackerUI.IsAnyQuestDoneOnAccount(config.neighborhoodWeeklyQuestIDs) then
        local activeNeighborhoodQuestID = FindActiveQuest(config.neighborhoodWeeklyActiveQuestIDs, activeByQuestID)
        local label = "Weekly Neighborhood"
        if activeNeighborhoodQuestID then
            local activeQuest = activeByQuestID and activeByQuestID[activeNeighborhoodQuestID]
            label = "Neighborhood: " .. ((activeQuest and activeQuest.title) or GetQuestTitle(activeNeighborhoodQuestID) or "weekly")
        end
        AddEntry(entries, label, "todo")
    end

    local activeLiadrinQuestID = FindActiveQuest(config.liadrinWeeklyQuestIDs, activeByQuestID)
    local isLiadrinWeeklyActive = activeLiadrinQuestID
        or IsQuestActiveOnMap(config.liadrinWrapperQuestID, activeByQuestID)
    if isLiadrinWeeklyActive
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

    AddReplenishTheReservoirEntry(entries, activeByQuestID)

    if HasJardRecipe() and GetRemainingSpellCooldown(JARD_SPELL_ID) <= 0 then
        AddEntry(entries, "Jard", "todo")
    end

    if IsQuestActiveOnMap(CONTAINING_THE_HELSWORN_QUEST_ID, activeByQuestID)
        and HasFlatGoldQuestReward(CONTAINING_THE_HELSWORN_QUEST_ID) then
        if not IsQuestDone(VICTORY_IN_OUR_NAME_QUEST_ID) then
            AddEntry(entries, CONTAINING_THE_HELSWORN_LABEL, "locked")
        elseif not IsQuestDone(CONTAINING_THE_HELSWORN_QUEST_ID) then
            AddEntry(entries, CONTAINING_THE_HELSWORN_LABEL, "todo")
        end
    end

    trackerUI.AddGeneralWeeklyEntries(entries, activeByQuestID)

    trackerUI.AddMidnightProfessionEntries(entries, trackedRows)

    if #entries == 0 and trackedRows and #trackedRows == 0 then
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
    local point, _, relativePoint, x, y = trackerFrame:GetPoint(1)
    local accountDB = GetAccountDB()
    accountDB.point = point
    accountDB.relativePoint = relativePoint
    accountDB.x = math.floor(x + 0.5)
    accountDB.y = math.floor(y + 0.5)
end

trackerUI.ApplyPosition = function()
    trackerFrame:ClearAllPoints()

    local db = YayaWeeklyTrackerAccountDB
    if HasSavedPosition(db) then
        trackerFrame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
        DebugLog("ApplyPosition saved point=%s relative=%s x=%s y=%s", tostring(db.point), tostring(db.relativePoint), tostring(db.x), tostring(db.y))
        return
    end

    local anchor = PlayerFrame or UIParent
    trackerFrame:SetPoint(DEFAULT_POSITION.point, anchor, DEFAULT_POSITION.relativePoint, DEFAULT_POSITION.x, DEFAULT_POSITION.y)
    DebugLog("ApplyPosition default point=%s relative=%s x=%s y=%s", tostring(DEFAULT_POSITION.point), tostring(DEFAULT_POSITION.relativePoint), tostring(DEFAULT_POSITION.x), tostring(DEFAULT_POSITION.y))
end

trackerUI.ResetPosition = function()
    local accountDB = GetAccountDB()
    accountDB.point = nil
    accountDB.relativePoint = nil
    accountDB.x = nil
    accountDB.y = nil
    trackerUI.ApplyPosition()
end

trackerUI.ApplyCombatVisibility = function()
    local visibilityFrame = runtimeState.combatVisibilityFrame
    if not visibilityFrame then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        runtimeState.combatVisibilityUpdateDeferred = true
        return
    end

    runtimeState.combatVisibilityUpdateDeferred = false
    if GetAccountDB().hideInCombat then
        RegisterStateDriver(visibilityFrame, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(visibilityFrame, "visibility")
        visibilityFrame:Show()
    end
end

trackerUI.RegisterOptions = function()
    if runtimeState.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = "Yaya Weekly Tracker"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(panel.name)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Options account-wide du tracker.")

    local checkbox = CreateFrame("CheckButton", addonName .. "HideInCombatCheckbox", panel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
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

    panel:SetScript("OnShow", function()
        checkbox:SetChecked(GetAccountDB().hideInCombat)
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
        local payoutItemState = DebugSafeCall("FindArtisanConsortiumPayoutInBags", FindArtisanConsortiumPayoutInBags)
        local surplusReagentStates = DebugSafeCall("FindSurplusReagentContainersInBags", trackerUI.FindSurplusReagentContainersInBags)
        local hasKnowledgeButton = DebugSafeCall("UpdateMidnightKnowledgeButton", trackerUI.UpdateMidnightKnowledgeButton, knowledgeItemState) or false
        local hasPayoutButton = DebugSafeCall("UpdateArtisanConsortiumPayoutButton", trackerUI.UpdateArtisanConsortiumPayoutButton, payoutItemState) or false
        local surplusButtonCount = DebugSafeCall("UpdateSurplusReagentButtons", trackerUI.UpdateSurplusReagentButtons, surplusReagentStates) or 0
        local hasEnchantingWeeklyButton = DebugSafeCall("UpdateEnchantingWeeklyQueueButton", trackerUI.UpdateEnchantingWeeklyQueueButton, trackedRows) or false
        local hasTreasureButton = DebugSafeCall("UpdateMidnightTreasureButton", trackerUI.UpdateMidnightTreasureButton, trackedRows) or false
        local trackerDebugSignature = ("%d|kp=%s|po=%s|sr=%d|eq=%s|tt=%s"):format(#entries, tostring(hasKnowledgeButton), tostring(hasPayoutButton), surplusButtonCount, tostring(hasEnchantingWeeklyButton), tostring(hasTreasureButton))
        if trackerDebugSignature ~= debugSignatures.tracker then
            debugSignatures.tracker = trackerDebugSignature
            DebugLog("UpdateTracker entries=%d kpButton=%s payoutButton=%s surplusButtons=%d enchWeeklyButton=%s treasureButton=%s", #entries, tostring(hasKnowledgeButton), tostring(hasPayoutButton), surplusButtonCount, tostring(hasEnchantingWeeklyButton), tostring(hasTreasureButton))
        end
        local hasUsefulEntry = false
        for _, entry in ipairs(entries) do
            if not entry.satisfied then
                hasUsefulEntry = true
                break
            end
        end
        if not hasUsefulEntry and not hasKnowledgeButton and not hasPayoutButton and surplusButtonCount == 0 and not hasEnchantingWeeklyButton and not hasTreasureButton then
            DebugLog("UpdateTracker hide frame: all professions complete and no other actions")
            trackerFrame:Hide()
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

        if hasKnowledgeButton then
            trackerFrame.knowledgeButton:ClearAllPoints()
            trackerFrame.knowledgeButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            offsetY = offsetY + 24
        end

        if hasPayoutButton then
            trackerFrame.payoutButton:ClearAllPoints()
            if hasKnowledgeButton then
                trackerFrame.payoutButton:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.payoutButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            offsetY = offsetY + 24
        end

        local lastSurplusButton
        for index = 1, surplusButtonCount do
            local button = trackerFrame.surplusReagentButtons[index]
            button:ClearAllPoints()
            if lastSurplusButton then
                button:SetPoint("TOPLEFT", lastSurplusButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                button:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            elseif hasKnowledgeButton then
                button:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            else
                button:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            lastSurplusButton = button
            offsetY = offsetY + 24
        end

        if hasEnchantingWeeklyButton then
            trackerFrame.enchantingWeeklyButton:ClearAllPoints()
            if lastSurplusButton then
                trackerFrame.enchantingWeeklyButton:SetPoint("TOPLEFT", lastSurplusButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                trackerFrame.enchantingWeeklyButton:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            elseif hasKnowledgeButton then
                trackerFrame.enchantingWeeklyButton:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.enchantingWeeklyButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            offsetY = offsetY + 24
        end

        if hasTreasureButton then
            trackerFrame.treasureButton:ClearAllPoints()
            if hasEnchantingWeeklyButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", trackerFrame.enchantingWeeklyButton, "BOTTOMLEFT", 0, -4)
            elseif lastSurplusButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", lastSurplusButton, "BOTTOMLEFT", 0, -4)
            elseif hasPayoutButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", trackerFrame.payoutButton, "BOTTOMLEFT", 0, -4)
            elseif hasKnowledgeButton then
                trackerFrame.treasureButton:SetPoint("TOPLEFT", trackerFrame.knowledgeButton, "BOTTOMLEFT", 0, -4)
            else
                trackerFrame.treasureButton:SetPoint("TOPLEFT", 6, -(offsetY + 2))
            end
            offsetY = offsetY + 24
        end

        local height = offsetY + 4
        trackerFrame:SetHeight(height)
        trackerFrame.bg:SetHeight(height)
        DebugLog("UpdateTracker final height=%d", height)
    end)

    if not ok then
        DebugLog("UpdateTracker fatal: %s", tostring(err))
        runtimeState.showTrackerDiagnostic(("YWT: |cffff6666%s|r"):format(tostring(err)))
    end
end

trackerUI.CreateTrackerFrame = function()
    runtimeState.combatVisibilityFrame = CreateFrame(
        "Frame",
        addonName .. "CombatVisibilityFrame",
        UIParent,
        "SecureHandlerStateTemplate"
    )
    runtimeState.combatVisibilityFrame:Show()
    trackerFrame = CreateFrame("Frame", addonName .. "Frame", runtimeState.combatVisibilityFrame)
    DebugLog("CreateTrackerFrame %s", tostring(addonName .. "Frame"))
    trackerFrame:SetFrameStrata("MEDIUM")
    trackerFrame:SetSize(190, 24)
    trackerFrame:SetClampedToScreen(true)
    trackerFrame:SetMovable(true)
    trackerFrame:EnableMouse(true)
    trackerFrame:RegisterForDrag("LeftButton")
    trackerFrame:SetScript("OnDragStart", trackerFrame.StartMoving)
    trackerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        trackerUI.SavePosition()
    end)

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
    trackerFrame.knowledgeButton:RegisterForClicks("AnyUp", "AnyDown")
    trackerFrame.knowledgeButton:SetText("Utiliser KP")
    trackerFrame.knowledgeButton:Hide()
    trackerFrame.knowledgeButton:HookScript("PreClick", function(self)
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

    trackerFrame.payoutButton = CreateFrame("Button", addonName .. "PayoutButton", trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    trackerFrame.payoutButton:SetSize(178, 20)
    trackerFrame.payoutButton:RegisterForClicks("AnyUp", "AnyDown")
    trackerFrame.payoutButton:SetAttribute("useOnKeyDown", false)
    trackerFrame.payoutButton:SetText("Ouvrir payout")
    trackerFrame.payoutButton:Hide()
    trackerFrame.payoutButton:HookScript("PostClick", function(self, _, down)
        if down then
            return
        end

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
        trackerUI.UpdateArtisanConsortiumPayoutButton(FindArtisanConsortiumPayoutInBags())
    end)
    trackerFrame.payoutButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ouvre un Artisan's Consortium Payout different du clic precedent si possible.")
        if self.itemLink then
            GameTooltip:AddLine(self.itemLink, 0.5, 0.8, 1, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.payoutButton:SetScript("OnLeave", GameTooltip_Hide)

    trackerFrame.surplusReagentButtons = {}
    for index = 1, 2 do
        local button = CreateFrame("Button", addonName .. "SurplusReagentButton" .. index, trackerFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
        button:SetSize(178, 20)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetText("Ouvrir surplus")
        button:Hide()
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

    trackerFrame.enchantingWeeklyButton = CreateFrame("Button", addonName .. "EnchantingWeeklyButton", trackerFrame, "UIPanelButtonTemplate")
    trackerFrame.enchantingWeeklyButton:SetSize(178, 20)
    trackerFrame.enchantingWeeklyButton:RegisterForClicks("AnyUp")
    trackerFrame.enchantingWeeklyButton:SetText("YQ Ench")
    trackerFrame.enchantingWeeklyButton:Hide()
    trackerFrame.enchantingWeeklyButton:SetScript("OnClick", function(self)
        if not (self.itemID and self.needed and self.needed > 0 and self.missing and self.missing > 0
            and YayaQueueAPI and type(YayaQueueAPI.AddItem) == "function") then
            return
        end

        local ok = YayaQueueAPI.AddItem(self.itemID, self.needed, self.itemName)
        if ok then
            print(("YWT: Ajoute +%dx %s a la queue existante (%d manquants pour la weekly)"):format(
                self.needed,
                self.itemName or ("item:" .. tostring(self.itemID)),
                self.missing
            ))
            if YayaQueueAPI.Refresh then
                YayaQueueAPI.Refresh()
            end
            ScheduleTrackerRefresh(0.05, false)
        end
    end)
    trackerFrame.enchantingWeeklyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ajoute 20 reagents supplementaires a la queue YayaQueue existante.")
        if self.questTitle then
            GameTooltip:AddLine(self.questTitle, 1, 1, 1, true)
        end
        if self.itemName and self.missing then
            GameTooltip:AddLine(("Manque %dx %s"):format(self.missing, self.itemName), 0.5, 0.8, 1, true)
        end
        GameTooltip:Show()
    end)
    trackerFrame.enchantingWeeklyButton:SetScript("OnLeave", GameTooltip_Hide)

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

    trackerFrame.lines = {}
    for index = 1, 6 do
        trackerUI.EnsureTrackerLine(index)
    end

    trackerUI.ApplyPosition()
    trackerUI.ApplyCombatVisibility()
    DebugLog("CreateTrackerFrame done")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("AREA_POIS_UPDATED")
eventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_CURRENCY")
eventFrame:RegisterEvent("CHAT_MSG_MONEY")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    DebugLog("Event %s", tostring(event))
    if event == "PLAYER_LOGIN" then
        MigrateLegacyPosition()
        trackerUI.CreateTrackerFrame()
        trackerUI.RegisterOptions()
        HookCacheItemUse()

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
                InvalidateArtisanConsortiumPayoutCache()
                trackerUI.InvalidateSurplusReagentContainerCache()
                debugSignatures.knowledge = nil
                debugSignatures.payout = nil
                debugSignatures.surplusReagents = nil
                debugSignatures.trackedProfessions = nil
                debugSignatures.tracker = nil
                debugSignatures.treasure = nil
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
            end
            ScheduleTrackerRefresh(0, false)
        end
        DebugLog("Debug actif. Commandes: /ywt debug, /ywt debug on, /ywt debug off, /ywt traites")
        ScheduleTrackerRefresh(0, true)
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        local reagentInfo = runtimeState.midnightEnchantingWeeklyReagents[questID]
        if reagentInfo and YayaQueueAPI and type(YayaQueueAPI.RemoveItem) == "function" then
            local ok, removedQuantity = YayaQueueAPI.RemoveItem(reagentInfo.itemID, reagentInfo.quantity)
            if ok and removedQuantity and removedQuantity > 0 then
                print(("YWT: Retire %dx %s de YayaQueue (weekly rendue)"):format(
                    removedQuantity,
                    reagentInfo.itemName or ("item:" .. tostring(reagentInfo.itemID))
                ))
            end
        end
        QueuePendingNzothCache(questID)
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "BAG_UPDATE_DELAYED" then
        runtimeState.attemptedPayoutTargetKeys = runtimeState.attemptedPayoutTargetKeys or {}
        wipe(runtimeState.attemptedPayoutTargetKeys)
        InvalidateMidnightKnowledgeConsumableCache()
        InvalidateArtisanConsortiumPayoutCache()
        trackerUI.InvalidateSurplusReagentContainerCache()
        ScheduleTrackerRefresh(0.05, false)
        if activeCacheOpen then
            ScheduleFinalizeActiveCacheOpen(0.35)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_SHOW" then
        InvalidateTrackedMidnightProfessions()
        ScheduleTrackerRefresh(0.05, true)
    elseif event == "PLAYER_LEVEL_UP" then
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "QUEST_LOG_UPDATE"
        or event == "SPELL_UPDATE_COOLDOWN"
        or event == "AREA_POIS_UPDATED"
        or event == "QUEST_DATA_LOAD_RESULT"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED" then
        ScheduleTrackerRefresh(0.05, false)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if runtimeState.combatVisibilityUpdateDeferred then
            trackerUI.ApplyCombatVisibility()
        end
        if runtimeState.trackerRefreshDeferredByCombat then
            runtimeState.trackerRefreshDeferredByCombat = false
            ScheduleTrackerRefresh(0, false)
        end
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        ScheduleTrackerRefresh(0.05, false)
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

