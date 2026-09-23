-- Ouvre la carte en repliant les panneaux qui occupent normalement l'ecran.

local function CollapseObjectiveTracker()
    local tracker = _G.ObjectiveTrackerFrame
    local header = tracker and tracker.Header
    local button = header and header.MinimizeButton

    if button and not tracker:IsCollapsed() then
        button:Click()
    end
end

local function HidePartySync()
    local frame = _G.PartySyncFrame
    if frame and frame:IsShown() then
        frame:Hide()
    end
end

local function CloseMapSidePanel()
    local map = _G.WorldMapFrame
    local toggle = map and map.SidePanelToggle
    local button = toggle and toggle.CloseButton

    if button and button:IsShown() then
        button:Click()
    end
end

local function ScheduleMapCleanup()
    CollapseObjectiveTracker()
    HidePartySync()
    CloseMapSidePanel()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            CollapseObjectiveTracker()
            HidePartySync()
            CloseMapSidePanel()
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
