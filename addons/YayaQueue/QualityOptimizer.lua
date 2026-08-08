local _, ns = ...

local Optimizer = {}
ns.QualityOptimizer = Optimizer

local function StableValue(value)
    if type(value) == "number" then
        return string.format("n:%020.0f", value)
    end
    return type(value) .. ":" .. tostring(value)
end

local function IsFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function IsBetter(candidate, current)
    if not current then return true end
    if candidate.cost ~= current.cost then
        return candidate.cost < current.cost
    end
    if candidate.estimated ~= current.estimated then
        return candidate.estimated ~= true
    end
    return candidate.signature < current.signature
end

local function GetOptionCost(option, quantity)
    quantity = math.max(0, math.floor(tonumber(quantity) or 0))
    if quantity <= 0 then
        return 0, false
    end

    if type(option.costForQuantity) == "function" then
        local ok, cost, estimated = pcall(option.costForQuantity, quantity)
        if ok and IsFiniteNumber(cost) and cost >= 0 then
            return cost, estimated == true
        end
        return nil, false
    end

    local price = tonumber(option.price)
    if not IsFiniteNumber(price) or price < 0 then
        return nil, false
    end
    return price * quantity, option.estimated == true
end

local function OptionSignature(option)
    return string.format(
        "%02d:%s",
        tonumber(option.quality) or 0,
        StableValue(option.itemID)
    )
end

local function AllocationSignature(allocations)
    local parts = {}
    for index, allocation in ipairs(allocations) do
        parts[index] = string.format(
            "%02d:%s:%010d",
            tonumber(allocation.quality) or 0,
            StableValue(allocation.itemID),
            tonumber(allocation.quantity) or 0
        )
    end
    return table.concat(parts, ",")
end

local function ConsolidateOptions(slot, tierCount)
    local byQuality = {}
    for _, rawOption in ipairs(slot.options or {}) do
        local quality = tonumber(rawOption.quality)
        local price = tonumber(rawOption.price)
        if quality then quality = math.floor(quality) end
        if quality and quality >= 1 and quality <= tierCount
            and rawOption.itemID ~= nil
            and IsFiniteNumber(price)
            and price >= 0 then
            local option = {
                itemID = rawOption.itemID,
                quality = quality,
                price = price,
                estimated = rawOption.estimated == true,
                costForQuantity = rawOption.costForQuantity,
            }
            option.signature = OptionSignature(option)
            local current = byQuality[quality]
            if not current
                or option.price < current.price
                or (
                    option.price == current.price
                    and option.estimated ~= current.estimated
                    and option.estimated ~= true
                )
                or (
                    option.price == current.price
                    and option.estimated == current.estimated
                    and option.signature < current.signature
                ) then
                byQuality[quality] = option
            end
        end
    end
    return byQuality
end

local function GetCompletionBonus(completionBonuses, quality)
    local rawBonus = completionBonuses and completionBonuses[quality]
    local bonus = tonumber(rawBonus)
    if IsFiniteNumber(bonus) then return bonus end
    return 0
end

local function BuildChoice(counts, optionsByQuality, required, weightPerPoint, completionBonuses)
    local allocations = {}
    local cost = 0
    local estimated = false
    local qualityPoints = 0
    local uniformQuality

    for quality = 1, #counts do
        local quantity = counts[quality] or 0
        if quantity > 0 then
            local option = optionsByQuality[quality]
            allocations[#allocations + 1] = {
                itemID = option.itemID,
                quality = quality,
                quantity = quantity,
                price = nil,
                estimated = false,
            }
            local optionCost, optionEstimated = GetOptionCost(option, quantity)
            if optionCost == nil then
                return nil
            end
            allocations[#allocations].price = optionCost / quantity
            allocations[#allocations].estimated = optionEstimated
            cost = cost + optionCost
            qualityPoints = qualityPoints + (quality - 1) * quantity
            if quantity == required then uniformQuality = quality end
            if optionEstimated then estimated = true end
        end
    end

    local completionBonus = 0
    if uniformQuality then
        completionBonus = GetCompletionBonus(completionBonuses, uniformQuality)
    end

    local choice = {
        weight = qualityPoints * weightPerPoint + completionBonus,
        qualityPoints = qualityPoints,
        completionBonus = completionBonus,
        cost = cost,
        estimated = estimated,
        allocations = allocations,
        uniformQuality = uniformQuality,
    }
    choice.signature = AllocationSignature(allocations)
    return choice
end

local function AddBestChoice(bestByWeight, choice)
    if not choice then return end
    local current = bestByWeight[choice.weight]
    if IsBetter(choice, current) then
        bestByWeight[choice.weight] = choice
    end
end

local function IsShiftedUniform(counts, required, completionBonuses)
    for quality = 1, #counts do
        if counts[quality] == required then
            return GetCompletionBonus(completionBonuses, quality) ~= 0
        end
    end
    return false
end

local function AddThreeTierPoint(
    bestByWeight,
    qualityPoints,
    required,
    weightPerPoint,
    optionsByQuality,
    completionBonuses,
    priceDelta,
    hasNonlinearCost
)
    local minimumThree = math.max(0, qualityPoints - required)
    local maximumThree = math.floor(qualityPoints / 2)
    local candidates = {}

    if hasNonlinearCost then
        for qualityThree = minimumThree, maximumThree do
            candidates[#candidates + 1] = qualityThree
        end
    elseif priceDelta > 0 then
        candidates[1] = minimumThree
        candidates[2] = minimumThree + 1
    elseif priceDelta < 0 then
        candidates[1] = maximumThree
        candidates[2] = maximumThree - 1
    else
        candidates[1] = minimumThree
        candidates[2] = minimumThree + 1
        candidates[3] = maximumThree - 1
        candidates[4] = maximumThree
    end

    local seen = {}
    for _, qualityThree in ipairs(candidates) do
        if qualityThree >= minimumThree and qualityThree <= maximumThree and not seen[qualityThree] then
            seen[qualityThree] = true
            local qualityTwo = qualityPoints - 2 * qualityThree
            local counts = {
                required - qualityTwo - qualityThree,
                qualityTwo,
                qualityThree,
            }
            if not IsShiftedUniform(counts, required, completionBonuses) then
                AddBestChoice(bestByWeight, BuildChoice(
                    counts,
                    optionsByQuality,
                    required,
                    weightPerPoint,
                    completionBonuses
                ))
                if not hasNonlinearCost and priceDelta ~= 0 then return end
            end
        end
    end
end

function Optimizer.BuildSlotChoices(slot)
    if type(slot) ~= "table" then
        return nil, "slot must be a table"
    end

    local required = tonumber(slot.required)
    local tierCount = tonumber(slot.tierCount)
    local weightPerPoint = tonumber(slot.weightPerPoint)
    if required then required = math.floor(required) end
    if tierCount then tierCount = math.floor(tierCount) end
    if not required or required < 1 then
        return nil, "slot.required must be a positive integer"
    end
    if tierCount ~= 2 and tierCount ~= 3 then
        return nil, "slot.tierCount must be 2 or 3"
    end
    if not IsFiniteNumber(weightPerPoint) then
        return nil, "slot.weightPerPoint must be a finite number"
    end

    local optionsByQuality = ConsolidateOptions(slot, tierCount)
    for quality = 1, tierCount do
        if not optionsByQuality[quality] then
            return nil, "missing priced option for quality " .. tostring(quality)
        end
    end

    local hasNonlinearCost = false
    for quality = 1, tierCount do
        if type(optionsByQuality[quality].costForQuantity) == "function" then
            hasNonlinearCost = true
            break
        end
    end

    local bestByWeight = {}
    if tierCount == 2 then
        for qualityTwo = 0, required do
            AddBestChoice(bestByWeight, BuildChoice(
                { required - qualityTwo, qualityTwo },
                optionsByQuality,
                required,
                weightPerPoint,
                slot.completionBonusByQuality
            ))
        end
    else
        local priceDelta = optionsByQuality[1].price
            - 2 * optionsByQuality[2].price
            + optionsByQuality[3].price
        for qualityPoints = 0, 2 * required do
            AddThreeTierPoint(
                bestByWeight,
                qualityPoints,
                required,
                weightPerPoint,
                optionsByQuality,
                slot.completionBonusByQuality,
                priceDelta,
                hasNonlinearCost
            )
        end
        for quality = 1, 3 do
            local counts = { 0, 0, 0 }
            counts[quality] = required
            AddBestChoice(bestByWeight, BuildChoice(
                counts,
                optionsByQuality,
                required,
                weightPerPoint,
                slot.completionBonusByQuality
            ))
        end
    end

    local choices = {}
    for _, choice in pairs(bestByWeight) do
        choices[#choices + 1] = choice
    end
    table.sort(choices, function(left, right)
        if left.weight ~= right.weight then return left.weight < right.weight end
        if left.cost ~= right.cost then return left.cost < right.cost end
        if left.estimated ~= right.estimated then return left.estimated ~= true end
        return left.signature < right.signature
    end)

    choices.required = required
    choices.tierCount = tierCount
    choices.weightPerPoint = weightPerPoint
    choices.optionsByQuality = optionsByQuality
    return choices
end

local function ChoiceList(group)
    if type(group) ~= "table" then return nil end
    if type(group.choices) == "table" then return group.choices end
    return group
end

local function ChoiceSignature(choice)
    if type(choice.signature) == "string" then return choice.signature end
    if type(choice.allocations) == "table" then
        return AllocationSignature(choice.allocations)
    end
    return string.format(
        "%s:%s:%s",
        StableValue(choice.weight),
        StableValue(choice.cost),
        tostring(choice.estimated == true)
    )
end

local function SortedStates(statesByWeight)
    local states = {}
    for _, state in pairs(statesByWeight) do
        states[#states + 1] = state
    end
    table.sort(states, function(left, right)
        if left.weight ~= right.weight then return left.weight < right.weight end
        if left.cost ~= right.cost then return left.cost < right.cost end
        if left.estimated ~= right.estimated then return left.estimated ~= true end
        return left.signature < right.signature
    end)
    return states
end

function Optimizer.CombineGroups(groups, yieldWork)
    if type(groups) ~= "table" then
        return nil, "groups must be a table"
    end
    if yieldWork ~= nil and type(yieldWork) ~= "function" then
        return nil, "yieldWork must be a function"
    end

    local root = {
        weight = 0,
        cost = 0,
        estimated = false,
        signature = "",
        previous = nil,
        choice = nil,
        groupIndex = 0,
    }
    local states = { root }
    local statesByWeight = { [0] = root }
    local transitions = 0

    for groupIndex, group in ipairs(groups) do
        local choices = ChoiceList(group)
        if not choices or #choices == 0 then
            return nil, "group " .. tostring(groupIndex) .. " has no choices"
        end

        local nextByWeight = {}
        for _, previous in ipairs(states) do
            for _, choice in ipairs(choices) do
                local choiceWeight = tonumber(choice.weight)
                local choiceCost = tonumber(choice.cost)
                if not IsFiniteNumber(choiceWeight) or not IsFiniteNumber(choiceCost) then
                    return nil, "group " .. tostring(groupIndex) .. " contains an invalid choice"
                end
                local choiceSignature = ChoiceSignature(choice)
                local signature
                if previous.signature == "" then
                    signature = choiceSignature
                else
                    signature = previous.signature .. "|" .. choiceSignature
                end
                local candidate = {
                    weight = previous.weight + choiceWeight,
                    cost = previous.cost + choiceCost,
                    estimated = previous.estimated or choice.estimated == true,
                    signature = signature,
                    previous = previous,
                    choice = choice,
                    groupIndex = groupIndex,
                }
                if IsBetter(candidate, nextByWeight[candidate.weight]) then
                    nextByWeight[candidate.weight] = candidate
                end

                transitions = transitions + 1
                if yieldWork and transitions % 256 == 0 then yieldWork() end
            end
        end
        statesByWeight = nextByWeight
        states = SortedStates(statesByWeight)
    end

    local result = {
        states = states,
        statesByWeight = statesByWeight,
        groupCount = #groups,
        transitionCount = transitions,
    }
    if #states > 0 then
        result.minWeight = states[1].weight
        result.maxWeight = states[#states].weight
    end
    return result
end

function Optimizer.GetStatesInRange(result, minWeight, maxWeight)
    if type(result) ~= "table" then return {} end
    local minimum = tonumber(minWeight) or -math.huge
    local maximum = tonumber(maxWeight) or math.huge
    local source = result.states
    if type(source) ~= "table" and type(result.statesByWeight) == "table" then
        source = SortedStates(result.statesByWeight)
    end
    if type(source) ~= "table" then return {} end

    local states = {}
    for _, state in ipairs(source) do
        if state.weight >= minimum and state.weight <= maximum then
            states[#states + 1] = state
        end
    end
    table.sort(states, function(left, right)
        if left.weight ~= right.weight then return left.weight < right.weight end
        if left.cost ~= right.cost then return left.cost < right.cost end
        if left.estimated ~= right.estimated then return left.estimated ~= true end
        return left.signature < right.signature
    end)
    return states
end

function Optimizer.BuildAllocations(state)
    local path = {}
    local cursor = state
    while type(cursor) == "table" and cursor.choice do
        path[#path + 1] = cursor.choice
        cursor = cursor.previous
    end

    local allocations = {}
    for pathIndex = #path, 1, -1 do
        local choice = path[pathIndex]
        for _, allocation in ipairs(choice.allocations or {}) do
            allocations[#allocations + 1] = {
                itemID = allocation.itemID,
                quality = allocation.quality,
                quantity = allocation.quantity,
                price = allocation.price,
                estimated = allocation.estimated == true,
            }
        end
    end
    return allocations
end

local function Assert(condition, message)
    if not condition then error(message or "assertion failed", 2) end
end

local function FindChoice(choices, weight)
    for _, choice in ipairs(choices or {}) do
        if choice.weight == weight then return choice end
    end
end

local function AllocationQuantity(allocations, quality)
    local quantity = 0
    for _, allocation in ipairs(allocations or {}) do
        if allocation.quality == quality then
            quantity = quantity + allocation.quantity
        end
    end
    return quantity
end

local function AssertGroupsMatchBruteForce(groups)
    local expected = {}
    local function Visit(groupIndex, weight, cost, estimated, signatures)
        if groupIndex > #groups then
            local candidate = {
                weight = weight,
                cost = cost,
                estimated = estimated,
                signature = table.concat(signatures, "|"),
            }
            if IsBetter(candidate, expected[weight]) then expected[weight] = candidate end
            return
        end
        for _, choice in ipairs(ChoiceList(groups[groupIndex])) do
            signatures[#signatures + 1] = ChoiceSignature(choice)
            Visit(
                groupIndex + 1,
                weight + choice.weight,
                cost + choice.cost,
                estimated or choice.estimated == true,
                signatures
            )
            signatures[#signatures] = nil
        end
    end
    Visit(1, 0, 0, false, {})

    local result, message = Optimizer.CombineGroups(groups)
    Assert(result ~= nil, message)
    local actualCount = 0
    for weight, wanted in pairs(expected) do
        actualCount = actualCount + 1
        local actual = result.statesByWeight[weight]
        Assert(actual ~= nil, "missing DP weight " .. tostring(weight))
        Assert(actual.cost == wanted.cost, "wrong DP cost at weight " .. tostring(weight))
        Assert(actual.estimated == wanted.estimated, "wrong estimated tie at weight " .. tostring(weight))
        Assert(actual.signature == wanted.signature, "wrong deterministic tie at weight " .. tostring(weight))
    end
    Assert(#result.states == actualCount, "DP returned unexpected states")
end

local function AssertThreeTierChoicesMatchBruteForce(slot, choices)
    local expected = {}
    local options = choices.optionsByQuality
    for qualityThree = 0, slot.required do
        for qualityTwo = 0, slot.required - qualityThree do
            local choice = BuildChoice(
                {
                    slot.required - qualityTwo - qualityThree,
                    qualityTwo,
                    qualityThree,
                },
                options,
                slot.required,
                slot.weightPerPoint,
                slot.completionBonusByQuality
            )
            if IsBetter(choice, expected[choice.weight]) then expected[choice.weight] = choice end
        end
    end
    local count = 0
    for weight, wanted in pairs(expected) do
        count = count + 1
        local actual = FindChoice(choices, weight)
        Assert(actual ~= nil, "missing three-tier weight " .. tostring(weight))
        Assert(actual.cost == wanted.cost, "wrong three-tier cost at weight " .. tostring(weight))
        Assert(actual.estimated == wanted.estimated, "wrong three-tier estimated flag")
        Assert(actual.signature == wanted.signature, "wrong three-tier deterministic tie")
    end
    Assert(#choices == count, "three-tier choices returned unexpected states")
end

function Optimizer.RunSelfTests()
    local tests = {
        {
            name = "small brute force and multiple slots",
            run = function()
                local first = assert(Optimizer.BuildSlotChoices({
                    required = 3,
                    tierCount = 2,
                    weightPerPoint = 2,
                    options = {
                        { itemID = 101, quality = 1, price = 7 },
                        { itemID = 102, quality = 2, price = 11 },
                    },
                }))
                local second = assert(Optimizer.BuildSlotChoices({
                    required = 2,
                    tierCount = 3,
                    weightPerPoint = 1,
                    options = {
                        { itemID = 201, quality = 1, price = 8 },
                        { itemID = 202, quality = 2, price = 9, estimated = true },
                        { itemID = 203, quality = 3, price = 13 },
                    },
                }))
                AssertGroupsMatchBruteForce({ first, second })
            end,
        },
        {
            name = "41/59 split",
            run = function()
                local choices = assert(Optimizer.BuildSlotChoices({
                    required = 100,
                    tierCount = 2,
                    weightPerPoint = 1,
                    options = {
                        { itemID = 301, quality = 1, price = 3 },
                        { itemID = 302, quality = 2, price = 5 },
                    },
                }))
                local result = assert(Optimizer.CombineGroups({ choices }))
                local states = Optimizer.GetStatesInRange(result, 59, 59)
                Assert(#states == 1, "41/59 state not found")
                local allocations = Optimizer.BuildAllocations(states[1])
                Assert(AllocationQuantity(allocations, 1) == 41, "expected 41 rank-one reagents")
                Assert(AllocationQuantity(allocations, 2) == 59, "expected 59 rank-two reagents")
            end,
        },
        {
            name = "three exact ranks",
            run = function()
                local slot = {
                    required = 4,
                    tierCount = 3,
                    weightPerPoint = 2,
                    options = {
                        { itemID = 401, quality = 1, price = 9 },
                        { itemID = 402, quality = 2, price = 7, estimated = true },
                        { itemID = 403, quality = 3, price = 5 },
                    },
                }
                local choices = assert(Optimizer.BuildSlotChoices(slot))
                AssertThreeTierChoicesMatchBruteForce(slot, choices)

                local priceSets = {
                    { 9, 7, 5 },
                    { 4, 9, 11 },
                    { 12, 8, 10 },
                }
                local bonusSets = {
                    {},
                    { [1] = 2 },
                    { [2] = 3 },
                    { [3] = 4 },
                    { [1] = 1, [2] = 2, [3] = 3 },
                }
                for required = 1, 5 do
                    for _, prices in ipairs(priceSets) do
                        for estimatedMask = 0, 7 do
                            for _, bonuses in ipairs(bonusSets) do
                                local bruteSlot = {
                                    required = required,
                                    tierCount = 3,
                                    weightPerPoint = 2,
                                    completionBonusByQuality = bonuses,
                                    options = {},
                                }
                                for quality = 1, 3 do
                                    bruteSlot.options[quality] = {
                                        itemID = 410 + quality,
                                        quality = quality,
                                        price = prices[quality],
                                        estimated = math.floor(estimatedMask / (2 ^ (quality - 1))) % 2 == 1,
                                    }
                                end
                                local bruteChoices = assert(Optimizer.BuildSlotChoices(bruteSlot))
                                AssertThreeTierChoicesMatchBruteForce(bruteSlot, bruteChoices)
                            end
                        end
                    end
                end
            end,
        },
        {
            name = "higher rank can be cheaper",
            run = function()
                local choices = assert(Optimizer.BuildSlotChoices({
                    required = 5,
                    tierCount = 2,
                    weightPerPoint = 1,
                    options = {
                        { itemID = 501, quality = 1, price = 10 },
                        { itemID = 502, quality = 2, price = 4 },
                    },
                }))
                local low = FindChoice(choices, 0)
                local high = FindChoice(choices, 5)
                Assert(low and high, "missing uniform choices")
                Assert(high.cost == 20, "wrong all-rank-two cost")
                Assert(high.cost < low.cost, "cheaper higher rank was not preserved")
            end,
        },
        {
            name = "quantity-aware option cost",
            run = function()
                local choices = assert(Optimizer.BuildSlotChoices({
                    required = 5,
                    tierCount = 2,
                    weightPerPoint = 1,
                    options = {
                        {
                            itemID = 511,
                            quality = 1,
                            price = 3,
                            costForQuantity = function(quantity)
                                return math.min(quantity, 2) * 3
                                    + math.max(0, quantity - 2) * 10
                            end,
                        },
                        { itemID = 512, quality = 2, price = 4 },
                    },
                }))
                Assert(FindChoice(choices, 0).cost == 36, "smart quantity was not capped")
                Assert(FindChoice(choices, 5).cost == 20, "fixed unit price was not preserved")

                local threeTier = assert(Optimizer.BuildSlotChoices({
                    required = 4,
                    tierCount = 3,
                    weightPerPoint = 1,
                    options = {
                        {
                            itemID = 521,
                            quality = 1,
                            price = 1,
                            costForQuantity = function(quantity) return quantity end,
                        },
                        { itemID = 522, quality = 2, price = 10 },
                        {
                            itemID = 523,
                            quality = 3,
                            price = 1,
                            costForQuantity = function(quantity)
                                return quantity == 1 and 1 or quantity > 1 and 100 or 0
                            end,
                        },
                    },
                }))
                local interior = FindChoice(threeTier, 4)
                Assert(interior and interior.cost == 22, "nonlinear three-tier split was not optimized")
                Assert(AllocationQuantity(interior.allocations, 1) == 1, "nonlinear split lost rank one")
                Assert(AllocationQuantity(interior.allocations, 2) == 2, "nonlinear split lost rank two")
                Assert(AllocationQuantity(interior.allocations, 3) == 1, "nonlinear split lost rank three")
            end,
        },
        {
            name = "duplicate rank consolidation",
            run = function()
                local choices = assert(Optimizer.BuildSlotChoices({
                    required = 1,
                    tierCount = 2,
                    weightPerPoint = 1,
                    options = {
                        { itemID = 612, quality = 1, price = 8 },
                        { itemID = 611, quality = 1, price = 8 },
                        { itemID = 610, quality = 1, price = 8, estimated = true },
                        { itemID = 602, quality = 2, price = 12 },
                    },
                }))
                local allocations = FindChoice(choices, 0).allocations
                Assert(allocations[1].itemID == 611, "duplicate rank tie was not deterministic")
            end,
        },
        {
            name = "full-rank completion bonus",
            run = function()
                local choices = assert(Optimizer.BuildSlotChoices({
                    required = 4,
                    tierCount = 2,
                    weightPerPoint = 1,
                    completionBonusByQuality = { [2] = 3 },
                    options = {
                        { itemID = 701, quality = 1, price = 1 },
                        { itemID = 702, quality = 2, price = 2 },
                    },
                }))
                Assert(FindChoice(choices, 4) == nil, "all-rank-two bonus was not applied discretely")
                local result = assert(Optimizer.CombineGroups({ choices }))
                local states = Optimizer.GetStatesInRange(result, 7, 7)
                Assert(#states == 1, "completion-bonus target is unreachable")
                local allocations = Optimizer.BuildAllocations(states[1])
                Assert(AllocationQuantity(allocations, 1) == 0, "completion target used rank one")
                Assert(AllocationQuantity(allocations, 2) == 4, "completion target did not use full rank two")
                Assert(states[1].cost == 8, "completion target did not keep the optimal cost")
            end,
        },
        {
            name = "DP estimated and signature ties",
            run = function()
                local result = assert(Optimizer.CombineGroups({
                    {
                        {
                            weight = 1,
                            cost = 10,
                            estimated = true,
                            signature = "a",
                            allocations = {},
                        },
                        {
                            weight = 1,
                            cost = 10,
                            estimated = false,
                            signature = "z",
                            allocations = {},
                        },
                        {
                            weight = 1,
                            cost = 10,
                            estimated = false,
                            signature = "y",
                            allocations = {},
                        },
                    },
                }))
                local state = result.statesByWeight[1]
                Assert(state and state.estimated == false, "DP preferred an estimated tie")
                Assert(state.signature == "y", "DP signature tie is not deterministic")
            end,
        },
    }

    for _, test in ipairs(tests) do
        local ok, message = pcall(test.run)
        if not ok then
            return false, test.name .. ": " .. tostring(message)
        end
    end
    return true, tostring(#tests) .. " tests passed"
end
