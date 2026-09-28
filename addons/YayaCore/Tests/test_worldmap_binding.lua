-- Le nettoyage de la carte ne doit jamais cliquer un bouton Blizzard depuis
-- un hook addon : ce chemin propage le taint dans l'ObjectiveTracker.

local objectiveTracker = {
    shown = true,
    hidden = false,
    IsShown = function(self) return self.shown end,
    Hide = function(self) self.shown, self.hidden = false, true end,
}
local partySync = {
    shown = true,
    hidden = false,
    IsShown = function(self) return self.shown end,
    Hide = function(self) self.shown, self.hidden = false, true end,
}
local timers = {}
local hooks = {}
local toggles = 0
local combat = false

_G.ObjectiveTrackerFrame = objectiveTracker
_G.PartySyncFrame = partySync
_G.WorldMapFrame = nil
_G.C_Timer = {
    After = function(_, callback) timers[#timers + 1] = callback end,
}

function InCombatLockdown() return combat end
function ToggleQuestLog() toggles = toggles + 1 end
function QuestMapFrame_Open() end
function hooksecurefunc(name, callback) hooks[name] = callback end

local bindingFrame = {}
function bindingFrame:RegisterEvent() end
function bindingFrame:UnregisterEvent() end
function bindingFrame:SetScript() end
function CreateFrame() return bindingFrame end

dofile("WorldMapBinding.lua")

YayaToggleWorldMap()
assert(toggles == 1, "the binding still opens the quest map")
assert(objectiveTracker.hidden, "the objective tracker is hidden with native Hide")
assert(partySync.hidden, "party sync is hidden")
for _, callback in ipairs(timers) do callback() end
assert(objectiveTracker.hidden and partySync.hidden, "the deferred cleanup stays safe")
assert(hooks.ToggleQuestLog and hooks.QuestMapFrame_Open, "Blizzard entry points stay hooked")

combat = true
objectiveTracker.shown, objectiveTracker.hidden = true, false
YayaToggleWorldMap()
assert(not objectiveTracker.hidden, "combat skips protected tracker changes")
print("WorldMapBinding: no Blizzard click, native hide and combat guard passed")
