-- One hardware key release delegates to one existing action button.
local Binding = { providers = {} }
YayaCore.ActionBinding = Binding

function Binding.RegisterProvider(name, provider)
    Binding.providers[name] = provider
end

local function Available(button)
    return button and button:IsVisible() and button:IsEnabled()
end

function Binding.ResolveTarget()
    local queue = Binding.providers.queue
    if queue then
        local frame, buttons = queue()
        -- A visible queue owns the shortcut even while Next is disabled.
        if frame and frame:IsVisible() then
            local button = buttons and buttons[1]
            return Available(button) and button or nil
        end
    end
    local weekly = Binding.providers.weekly
    if not weekly then return nil end
    local _, buttons = weekly()
    local target, lowest
    for _, button in ipairs(buttons or {}) do
        if Available(button) then
            local bottom = button:GetBottom()
            if bottom then
                bottom = bottom * button:GetEffectiveScale()
                if not lowest or bottom <= lowest then
                    target, lowest = button, bottom
                end
            end
        end
    end
    return target
end

local button = CreateFrame("Button", "YayaNextActionButton", UIParent,
    "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp")
button:SetAttribute("useOnKeyDown", false)
button:SetAttribute("type", "click")
-- A secure state driver prevents a stale target from being used in combat.
RegisterStateDriver(button, "visibility", "[combat] hide; show")
button:HookScript("PreClick", function(self, _, down)
    if down or InCombatLockdown() then return end
    self:SetAttribute("clickbutton", Binding.ResolveTarget())
end)
button:HookScript("PostClick", function(self)
    if not InCombatLockdown() then
        self:SetAttribute("clickbutton", nil)
    end
end)
