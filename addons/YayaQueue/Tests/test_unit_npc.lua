-- Regression test for Retail secret UnitGUID values, executed with Lua 5.1.
--
-- The client may return a secret string from UnitGUID. Passing it to strsplit
-- raises "attempt to perform string conversion on a secret string value".
-- The addon must ignore that value and keep the ordinary GUID path working.

local passed, failed = 0, 0

local function equals(name, actual, expected)
    if actual == expected then
        passed = passed + 1
        print(("  OK    %s"):format(name))
    else
        failed = failed + 1
        print(("  ECHEC %s -> attendu %s, obtenu %s"):format(
            name, tostring(expected), tostring(actual)))
    end
end

local handle = assert(io.open("YayaQueue.lua", "rb"), "YayaQueue.lua introuvable")
local source = handle:read("*a"):gsub("\r\n", "\n")
handle:close()

local body = source:match("(state%.GetUnitNPCID = function%(unit%).-\nend)\n")
assert(body, "state.GetUnitNPCID introuvable dans la source")

state = {}
function SafeCall(func, ...)
    local ok, result = pcall(func, ...)
    if ok then
        return result
    end
    return nil
end

local SECRET_GUID = "Creature-SECRET"
local currentGUID
local splitCalls = 0

function UnitGUID()
    return currentGUID
end

function issecretvalue(value)
    return value == SECRET_GUID
end

function strsplit(separator, guid)
    splitCalls = splitCalls + 1
    assert(guid ~= SECRET_GUID, "un secret GUID ne doit jamais etre decoupe")
    local result = {}
    for part in (guid .. separator):gmatch("(.-)" .. separator) do
        result[#result + 1] = part
    end
    return unpack(result)
end

assert(loadstring(body, "GetUnitNPCID"))()

currentGUID = SECRET_GUID
equals("un GUID secret est ignore", state.GetUnitNPCID("target"), nil)
equals("un GUID secret n'est jamais passe a strsplit", splitCalls, 0)

currentGUID = "Creature-0-0-0-0-123456-0"
equals("un GUID Creature conserve son NPC ID", state.GetUnitNPCID("target"), 123456)
equals("un GUID normal est decoupe une fois", splitCalls, 1)

currentGUID = "Player-0-0-0-0-123456-0"
equals("un GUID Player reste ignore", state.GetUnitNPCID("target"), nil)

print("")
print(("%d reussite(s), %d echec(s)"):format(passed, failed))
if failed > 0 then
    os.exit(1)
end
