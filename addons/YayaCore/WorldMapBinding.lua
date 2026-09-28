-- Ouvre la carte en masquant les panneaux qui occupent normalement l'ecran.

local function HideObjectiveTracker()
    local tracker = _G.ObjectiveTrackerFrame

    -- Ne pas cliquer le bouton Blizzard depuis un hook addon : le chemin
    -- SetCollapsed -> Update lit ensuite des auras secretes dans
    -- Blizzard_MawBuffs et herite du taint YayaCore. Hide() ne force pas ce
    -- recalcul; en combat, on laisse aussi le client gerer l'etat protege.
    if tracker and not InCombatLockdown() and tracker:IsShown() then
        tracker:Hide()
    end
end

local function HidePartySync()
    local frame = _G.PartySyncFrame
    if frame and frame:IsShown() then
        frame:Hide()
    end
end

local function ScheduleMapCleanup()
    HideObjectiveTracker()
    HidePartySync()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            HideObjectiveTracker()
            HidePartySync()
        end)
    end
end

function YayaToggleWorldMap()
    if type(ToggleQuestLog) == "function" then
        ToggleQuestLog()
    end
    ScheduleMapCleanup()
end

if type(hooksecurefunc) == "function" then
    if type(ToggleQuestLog) == "function" then
        hooksecurefunc("ToggleQuestLog", ScheduleMapCleanup)
    end
    if type(QuestMapFrame_Open) == "function" then
        hooksecurefunc("QuestMapFrame_Open", ScheduleMapCleanup)
    end
end

local bindingFrame = CreateFrame("Frame")
bindingFrame:RegisterEvent("PLAYER_LOGIN")
bindingFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    -- L ouvre normalement le journal des quetes. Cette action le remplace
    -- volontairement, comme demande pour la touche de jeu de l'utilisateur.
    if type(SetBinding) == "function" then
        -- L ouvre le journal de quetes, qui affiche la carte en mode compact.
        SetBinding("L", "TOGGLEQUESTLOG")
        if type(SaveBindings) == "function" and type(GetCurrentBindingSet) == "function" then
            SaveBindings(GetCurrentBindingSet())
        end
    end
end)
