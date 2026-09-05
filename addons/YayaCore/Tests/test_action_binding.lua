-- Routing checks only; secure hardware dispatch still requires an in-game test.
YayaCore = {}
UIParent = {}
local combat = false
function InCombatLockdown() return combat end
local proxy
function CreateFrame()
    proxy = { attributes = {}, scripts = {} }
    function proxy:RegisterForClicks(...) self.clicks = {...} end
    function proxy:SetAttribute(key, value)
        assert(not combat, "protected attribute changed in combat")
        self.attributes[key] = value
    end
    function proxy:HookScript(key, fn) self.scripts[key] = fn end
    return proxy
end
function RegisterStateDriver(frame, state, condition)
    assert(state == "visibility" and condition == "[combat] hide; show")
end
dofile("ActionBinding.lua")
-- Key-up must be requested by the binding itself, not just the button.
local xmlFile = assert(io.open("Bindings.xml", "r"))
local xml = xmlFile:read("*a")
xmlFile:close()
local declaration = assert(xml:match('<Binding%s+([^>]+)>'))
assert(declaration:match('runOnUp="true"'), "binding must deliver key release")
local category = assert(declaration:match('category="([^"]+)"'))
assert(category == "Yaya", "binding category must be a literal safe label")
assert(declaration:match('description="Action suivante %(YQ / YWT%)"'),
    "binding must have a readable description without a tainted BINDING_NAME global")
assert(not declaration:match('BINDING_HEADER_'), "do not resolve the category through a tainted global")
assert(not declaration:match('header='), "do not create an untranslated legacy header row")
local binding = YayaCore.ActionBinding
local function candidate(y, scale)
    return {
        visible = true, enabled = true,
        IsVisible = function(self) return self.visible end,
        IsEnabled = function(self) return self.enabled end,
        GetBottom = function() return y end,
        GetEffectiveScale = function() return scale or 1 end,
    }
end
assert(binding.ResolveTarget() == nil)
local top, bottom = candidate(200), candidate(100)
binding.RegisterProvider("weekly", function() return nil, {top, bottom} end)
assert(binding.ResolveTarget() == bottom)
bottom.enabled = false
assert(binding.ResolveTarget() == top)
bottom.enabled, bottom.visible = true, false
assert(binding.ResolveTarget() == top)
top.visible = false
assert(binding.ResolveTarget() == nil)
top.visible, bottom.visible = true, true
local scaled = candidate(150, 0.5)
binding.RegisterProvider("weekly", function() return nil, {top, bottom, scaled} end)
assert(binding.ResolveTarget() == scaled)
local frame, nextButton = candidate(0), candidate(500)
binding.RegisterProvider("queue", function() return frame, {nextButton} end)
assert(binding.ResolveTarget() == nextButton)
nextButton.enabled = false
assert(binding.ResolveTarget() == nil, "disabled Next must block weekly fallback")
nextButton.enabled, nextButton.visible = true, false
assert(binding.ResolveTarget() == nil, "hidden Next in visible queue must block fallback")
frame.visible = false
assert(binding.ResolveTarget() == scaled)
assert(proxy.clicks[1] == "AnyUp" and #proxy.clicks == 1)
assert(proxy.attributes.useOnKeyDown == false)
proxy.scripts.PreClick(proxy, "LeftButton", true)
assert(proxy.attributes.clickbutton == nil)
proxy.scripts.PreClick(proxy, "LeftButton", false)
assert(proxy.attributes.clickbutton == scaled)
proxy.scripts.PostClick(proxy)
assert(proxy.attributes.clickbutton == nil, "never retain a stale target")
combat = true
proxy.scripts.PreClick(proxy, "LeftButton", false)
proxy.scripts.PostClick(proxy)
assert(proxy.attributes.clickbutton == nil)
print("ActionBinding: routing, visibility, disabled priority, scale, release and combat checks passed")
