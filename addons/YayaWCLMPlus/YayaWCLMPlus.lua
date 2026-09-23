local ADDON_NAME = ...
local API = {}
local state = { text = nil, color = { 0.20, 0.80, 0.45 } }
local debugEnabled = false

local function debug(...)
    if debugEnabled then
        print("|cff66ccffYayaWCLMPlus:|r", ...)
    end
end

local indicator = CreateFrame("Frame", "YayaWCLMPlusIndicator", UIParent)
indicator:SetSize(8, 8)
indicator:SetFrameStrata("LOW")
indicator:Hide()

local dot = indicator:CreateTexture(nil, "ARTWORK")
dot:SetAllPoints()
dot:SetColorTexture(0.20, 0.80, 0.45, 0.9)

local function anchorIndicator()
    indicator:ClearAllPoints()
    local viewer = _G.LFGListApplicationViewer
    if viewer and viewer:IsShown() then
        indicator:SetPoint("TOPRIGHT", viewer, "TOPRIGHT", -6, -6)
    else
        indicator:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -24)
    end
end

function API:SetState(text, color)
    if type(text) ~= "string" or text == "" then
        return self:ClearState()
    end
    state.text = text
    if type(color) == "table" then
        state.color[1] = tonumber(color[1]) or state.color[1]
        state.color[2] = tonumber(color[2]) or state.color[2]
        state.color[3] = tonumber(color[3]) or state.color[3]
    end
    dot:SetColorTexture(state.color[1], state.color[2], state.color[3], 0.9)
    indicator:SetAlpha(0.85)
    anchorIndicator()
    indicator:Show()
    debug("state set", state.text)
end

function API:ClearState()
    state.text = nil
    indicator:Hide()
    debug("state cleared")
end

function API:GetState()
    return state.text
end

_G.YayaWCLMPlusAPI = API

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LFG_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        YayaWCLMPlusDB = YayaWCLMPlusDB or {}
        debugEnabled = YayaWCLMPlusDB.debug == true
    end
    if state.text then
        anchorIndicator()
    end
end)

SLASH_YAYAWCLMPLUS1 = "/wclm"
SlashCmdList.YAYAWCLMPLUS = function(message)
    if message and message:lower() == "debug" then
        debugEnabled = not debugEnabled
        YayaWCLMPlusDB = YayaWCLMPlusDB or {}
        YayaWCLMPlusDB.debug = debugEnabled
        print("YayaWCLMPlus debug: " .. (debugEnabled and "ON" or "OFF"))
    else
        print("YayaWCLMPlus: /wclm debug")
    end
end
