$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot "addons\YayaQueue\YayaQueue.lua"
$source = Get-Content -LiteralPath $sourcePath -Raw
$dumpBuilderBlock = [regex]::Match(
    $source,
    "(?s)local function IsRequiredRecipeReagentSlot.*?(?=local function GetConcentrationDumpState)"
).Value
if (-not $dumpBuilderBlock) {
    throw "Dump Concentration builder block not found"
}

$harness = @"
local function SafeCall(func, ...)
    local ok, result = pcall(func, ...)
    return ok and result or nil
end
local function NormalizeCraftingReagents(reagents)
    local normalized = {}
    for _, reagent in ipairs(reagents or {}) do
        normalized[#normalized + 1] = reagent
    end
    return normalized
end
local function GetRecipeSlotReagent(slot)
    return slot and slot.reagents and slot.reagents[1] or nil
end
local function AddEnchantingVellumReagent(reagents)
    return reagents
end
Enum = {
    CraftingReagentType = { Basic = 1 },
}

$dumpBuilderBlock

local recipeID = 1230859 -- Potion of Recklessness
local schematic = {
    recipeID = recipeID,
    reagentSlotSchematics = {
        { required = true, reagentType = 1, dataSlotIndex = 1, quantityRequired = 5, reagents = { { itemID = 240991 } } },
        { required = true, reagentType = 1, dataSlotIndex = 2, quantityRequired = 8, reagents = { { itemID = 236761 } } },
        { required = true, reagentType = 1, dataSlotIndex = 3, quantityRequired = 4, reagents = { { itemID = 236774 } } },
        { required = true, reagentType = 2, dataSlotIndex = 4, quantityRequired = 2, reagents = { { itemID = 236950 } } },
    },
}
local transactionSnapshot = {
    { dataSlotIndex = 1, reagent = { itemID = 240991 }, quantity = 5 },
    { dataSlotIndex = 2, reagent = { itemID = 236761 }, quantity = 8 },
    { dataSlotIndex = 3, reagent = { itemID = 236774 }, quantity = 4 },
    -- Blizzard omits Mote of Primal Energy here.
}
local form = {
    reagentSlots = {
        Required = {
            {
                Button = {
                    GetItemID = function()
                        return 236950
                    end,
                },
            },
        },
    },
}

local complete = BuildCompleteCraftingReagents(form, schematic, transactionSnapshot)
local demand = BuildCompleteRecipeReagents(schematic, complete, {})
local quantities = {}
for _, reagent in ipairs(demand) do
    quantities[reagent.itemID] = reagent.quantity
end
assert(quantities[236950] == 2, "Potion of Recklessness must include two Motes per craft")
assert(quantities[236950] * 7 == 14, "seven concentration crafts must demand fourteen Motes")
print("Potion of Recklessness Dump Concentration fixture: ok")
"@

$harnessPath = Join-Path ([IO.Path]::GetTempPath()) ("yayaqueue-dump-concentration-" + [guid]::NewGuid().ToString("N") + ".lua")
try {
    Set-Content -LiteralPath $harnessPath -Value $harness -Encoding utf8
    & npx.cmd --yes --package=fengari-node-cli fengari $harnessPath
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Remove-Item -LiteralPath $harnessPath -Force -ErrorAction SilentlyContinue
}
