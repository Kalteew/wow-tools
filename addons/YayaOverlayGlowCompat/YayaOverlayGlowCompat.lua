local showGlow = _G.ActionButton_ShowOverlayGlow
local hideGlow = _G.ActionButton_HideOverlayGlow

if showGlow and hideGlow then
	return
end

local _, _, _, buildInfo = _G.GetBuildInfo()
local preferredTemplate = buildInfo and buildInfo >= 110107 and "ActionButtonSpellAlertTemplate" or "ActionBarButtonSpellActivationAlert"

local function playGlow(glow)
	if not glow then
		return
	end

	if not glow:IsShown() then
		glow:Show()
	end

	if glow.animOut and glow.animOut:IsPlaying() then
		glow.animOut:Stop()
	end

	if glow.animIn then
		if glow.animIn:IsPlaying() then
			glow.animIn:Stop()
		end
		glow.animIn:Play()
		return
	end

	if glow.ProcStartAnim and not glow.ProcStartAnim:IsPlaying() then
		glow.ProcStartAnim:Play()
	end
end

local function stopGlow(glow)
	if not glow then
		return
	end

	if glow.animOut then
		if glow.animOut:IsPlaying() then
			glow.animOut:Stop()
		end
		if glow.animIn and glow.animIn:IsPlaying() then
			glow.animIn:Stop()
		end
	elseif glow.ProcStartAnim and glow.ProcStartAnim:IsPlaying() then
		glow.ProcStartAnim:Stop()
	end

	if glow:IsShown() then
		glow:Hide()
	end
end

local function createGlow(button)
	if not button then
		return nil
	end

	local glow = button.__YayaOverlayGlowCompat
	if glow then
		return glow
	end

	local frameName
	if button.GetName then
		local buttonName = button:GetName()
		if buttonName and #buttonName <= 40 then
			frameName = buttonName .. "YayaGlowCompat"
		end
	end

	local ok, frame = _G.pcall(_G.CreateFrame, "Frame", frameName, button, preferredTemplate)
	if (not ok or not frame) and preferredTemplate ~= "ActionBarButtonSpellActivationAlert" then
		ok, frame = _G.pcall(_G.CreateFrame, "Frame", frameName, button, "ActionBarButtonSpellActivationAlert")
	end
	if (not ok or not frame) and preferredTemplate ~= "ActionButtonSpellAlertTemplate" then
		ok, frame = _G.pcall(_G.CreateFrame, "Frame", frameName, button, "ActionButtonSpellAlertTemplate")
	end
	if not ok or not frame then
		return nil
	end

	local width, height = button:GetSize()
	frame:SetSize(width * 1.4, height * 1.4)
	frame:SetPoint("TOPLEFT", button, "TOPLEFT", -width * 0.32, height * 0.36)
	frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", width * 0.32, -height * 0.36)

	if frame.outerGlow then
		frame.outerGlow:SetScale(1.2)
	end
	if frame.ProcStartAnim then
		frame.ProcStartAnim:Stop()
	end

	frame:Hide()
	button.__YayaOverlayGlowCompat = frame
	return frame
end

if not showGlow then
	function _G.ActionButton_ShowOverlayGlow(button)
		playGlow(createGlow(button))
	end
end

if not hideGlow then
	function _G.ActionButton_HideOverlayGlow(button)
		if not button then
			return
		end

		stopGlow(button.__YayaOverlayGlowCompat or button.spellGlow or button.overlay or button.SpellActivationAlert)
	end
end
