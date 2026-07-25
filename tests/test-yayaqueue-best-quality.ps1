$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot "addons\YayaQueue\YayaQueue.lua"
$source = Get-Content -LiteralPath $sourcePath -Raw

$builderBlock = [regex]::Match(
    $source,
    "(?s)local function GetRecipeReagentQuality.*?(?=local function GetRecipeContextFromSchematicForm)"
).Value
if (-not $builderBlock) {
    throw "Best-quality builder block not found"
}
$allocationBlock = [regex]::Match(
    $source,
    "(?s)local function ApplyQueuedSlotAllocations.*?(?=local function ApplyQueuedRecipeConfigNow)"
).Value
if (-not $allocationBlock) {
    throw "Queued allocation block not found"
}

$requiredWiring = @(
    "GetRecipeSlotReagent(slot, useBestQualityReagents)",
    "ShouldUseBestQualityReagents(form)",
    "useBestQualityReagents = context.useBestQualityReagents == true and true or nil",
    "pending.useBestQualityReagents"
)
foreach ($needle in $requiredWiring) {
    if (-not $source.Contains($needle)) {
        throw "Missing best-quality queue wiring: $needle"
    }
}

$harness = @"
local function SafeCall(func, ...)
    local ok, result = pcall(func, ...)
    return ok and result or nil
end

local qualities = {
    [101] = 1,
    [102] = 3,
    [103] = 2,
}
C_TradeSkillUI = {
    GetItemReagentQualityByItemInfo = function(itemID)
        return qualities[itemID]
    end,
}
Professions = {
    ShouldAllocateBestQualityReagents = function()
        return false
    end,
}
Enum = {
    CraftingReagentType = { Basic = 1 },
    TradeskillSlotDataType = { Reagent = 1, ModifiedReagent = 2 },
}
local function WarmItemData() end
local function AddEnchantingVellumReagent(reagents)
    return reagents
end

$builderBlock

local qualitySlot = {
    reagents = {
        { itemID = 101 },
        { itemID = 102 },
        { itemID = 103 },
    },
}
assert(GetRecipeSlotReagent(qualitySlot, false).itemID == 101, "unchecked must preserve the first reagent")
assert(GetRecipeSlotReagent(qualitySlot, true).itemID == 102, "checked must select the highest quality")

local plainSlot = {
    reagents = {
        { itemID = 201 },
    },
}
assert(GetRecipeSlotReagent(plainSlot, true).itemID == 201, "a slot without quality variants must stay unchanged")

local schematic = {
    name = "Quality fixture",
    outputItemID = 999,
    quantityMin = 1,
    reagentSlotSchematics = {
        {
            required = true,
            reagentType = Enum.CraftingReagentType.Basic,
            dataSlotType = Enum.TradeskillSlotDataType.Reagent,
            quantityRequired = 4,
            reagents = qualitySlot.reagents,
        },
        {
            required = true,
            reagentType = Enum.CraftingReagentType.Basic,
            dataSlotType = Enum.TradeskillSlotDataType.Reagent,
            quantityRequired = 2,
            reagents = plainSlot.reagents,
        },
    },
}
local unchecked = BuildRecipeContext(123, { name = "Quality fixture" }, schematic, nil, false, false)
assert(unchecked.reagents[1].itemID == 101, "unchecked demand must remain unchanged")
assert(unchecked.reagents[2].itemID == 201, "plain reagent must remain present")
assert(unchecked.useBestQualityReagents == nil, "unchecked entries must keep the legacy shape")

local checked = BuildRecipeContext(123, { name = "Quality fixture" }, schematic, nil, false, true)
assert(checked.reagents[1].itemID == 102, "checked demand must use the highest-quality itemID")
assert(checked.reagents[1].quantity == 4, "quality selection must preserve quantity")
assert(checked.reagents[2].itemID == 201, "checked demand must preserve a no-variant reagent")
assert(checked.useBestQualityReagents == true, "checked state must be propagated")

local form = {
    AllocateBestQualityCheckbox = {
        GetChecked = function()
            return true
        end,
    },
}
assert(ShouldUseBestQualityReagents(form) == true, "the visible checkbox must drive queue capture")

$allocationBlock

local allocatedBest
Professions.AllocateAllBasicReagents = function(_, useBest)
    allocatedBest = useBest
end
local transaction = {
    SetManuallyAllocated = function(_, manuallyAllocated)
        assert(manuallyAllocated == false, "automatic allocation must stay enabled")
    end,
}
local runtimeForm = {}
assert(ApplyQueuedSlotAllocations(transaction, runtimeForm, {}, {}, true) == true)
assert(allocatedBest == true, "queued checked state must reach Blizzard allocation")

allocatedBest = nil
assert(ApplyQueuedSlotAllocations(transaction, runtimeForm, {}, {}, nil) == true)
assert(allocatedBest == false, "legacy unchecked path must retain the current preference")

print("YayaQueue best-quality fixtures: ok")
"@

$harnessPath = Join-Path ([IO.Path]::GetTempPath()) ("yayaqueue-best-quality-" + [guid]::NewGuid().ToString("N") + ".lua")
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
