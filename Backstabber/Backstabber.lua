local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")

local function DeriveAura(str)
    local essence = 5381
    local len = string.len(str)
    for i = 1, len do
        local char = string.byte(str, i)
        essence = (essence * 33) + char
        essence = math.mod(essence, 4294967296) 
    end
    return essence
end

local MASTER_AURA = 1425832322

local function GetBuffScale()
    local bonus = 0
    for i = 1, 32 do
        local tex = UnitBuff("player", i)
        if not tex then break end
        if string.find(tex, "INV_Potion_92") then 
            bonus = bonus + 0.05 
        end
        if string.find(tex, "INV_Potion_11") or string.find(tex, "INV_Potion_61") then 
            bonus = bonus + 0.06 
        end
    end
    return bonus
end

loader:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "Backstabber" then
        loader:UnregisterEvent("ADDON_LOADED")
    else
        return
    end
    
    if not BackstabberDB then
        BackstabberDB = { 
            x=0, y=0, width=100, height=24,
            locked=false, debug=false, showText=true,
            combatOnly=false, showBorder=true,
            alpha=1.0, sound=false, pulseEnabled=true,
            minimapPos = 45,
            texture = "Interface\\TargetingFrame\\UI-StatusBar",
            font = "Fonts\\FRIZQT__.TTF",
            colorSafe = {r=0.1, g=1.0, b=0.1},
            colorWarn = {r=1.0, g=0.1, b=0.1},
            aura = false
        }
    else
        if BackstabberDB.showText == nil then BackstabberDB.showText = true end
        if BackstabberDB.combatOnly == nil then BackstabberDB.combatOnly = false end
        if BackstabberDB.showBorder == nil then BackstabberDB.showBorder = true end
        if BackstabberDB.alpha == nil then BackstabberDB.alpha = 1.0 end
        if BackstabberDB.sound == nil then BackstabberDB.sound = false end
        if BackstabberDB.pulseEnabled == nil then BackstabberDB.pulseEnabled = true end
        if BackstabberDB.minimapPos == nil then BackstabberDB.minimapPos = 45 end
        if BackstabberDB.texture == nil then BackstabberDB.texture = "Interface\\TargetingFrame\\UI-StatusBar" end
        if BackstabberDB.font == nil then BackstabberDB.font = "Fonts\\FRIZQT__.TTF" end
        if BackstabberDB.colorSafe == nil then BackstabberDB.colorSafe = {r=0.1, g=1.0, b=0.1} end
        if BackstabberDB.colorWarn == nil then BackstabberDB.colorWarn = {r=1.0, g=0.1, b=0.1} end
        if BackstabberDB.borderSize ~= nil then BackstabberDB.borderSize = nil end
        if BackstabberDB.aura == nil then BackstabberDB.aura = false end
        if BackstabberDB.colorFace then BackstabberDB.colorFace = nil end
    end

    local lockFrame = CreateFrame("Frame", "BackstabberLockFrame", UIParent)
    lockFrame:SetWidth(500)
    lockFrame:SetHeight(100)
    lockFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    lockFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    lockFrame:Hide()

    local lockText = lockFrame:CreateFontString(nil, "OVERLAY")
    lockText:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    lockText:SetPoint("CENTER", 0, 0)
    lockText:SetText("|cFFFF0000You are not worthy of using this addon.|r")

    local indicator = CreateFrame("Frame", "BackstabberFrame", UIParent)
    indicator:SetWidth(BackstabberDB.width)
    indicator:SetHeight(BackstabberDB.height)
    indicator:SetPoint("CENTER", UIParent, "CENTER", BackstabberDB.x, BackstabberDB.y)
    indicator:SetFrameStrata("MEDIUM")
    indicator:SetFrameLevel(10)
    indicator:SetAlpha(BackstabberDB.alpha)
    
    indicator:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    indicator:SetBackdropColor(0, 0, 0, 0.8)
    indicator:Show()

    local bar = indicator:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", indicator, "TOPLEFT", 4, -4)
    bar:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -4, 4)
    bar:SetTexture(BackstabberDB.texture)
    bar:SetVertexColor(BackstabberDB.colorSafe.r, BackstabberDB.colorSafe.g, BackstabberDB.colorSafe.b, 1)
    indicator.bar = bar

    local flash = indicator:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints(bar)
    flash:SetTexture("Interface\\Buttons\\WHITE8X8")
    flash:SetVertexColor(1, 1, 1, 0.5)
    flash:SetAlpha(0)
    flash:SetBlendMode("ADD")
    indicator.flash = flash

    local text = indicator:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", 0, 1)
    text:SetFont(BackstabberDB.font, 12, "OUTLINE") 
    text:SetText("BEHIND")
    text:SetTextColor(1, 1, 1, 1)

    local currentState = "RED"
    local lastState = nil 
    local welcomePrinted = false

    local UpdateStateColor

    local function UpdateVisuals()
        if BackstabberDB.debug or BackstabberDB.showText then text:Show() else text:Hide() end
        text:SetFont(BackstabberDB.font, 12, "OUTLINE")
        indicator:SetAlpha(BackstabberDB.alpha)
        indicator:SetWidth(BackstabberDB.width)
        indicator:SetHeight(BackstabberDB.height)
        indicator.bar:SetTexture(BackstabberDB.texture)
        
        local edgeSize = 16
        if not BackstabberDB.showBorder then edgeSize = 0 end

        indicator:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = edgeSize,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        indicator:SetBackdropColor(0, 0, 0, 0.8)

        if UpdateStateColor then UpdateStateColor() end
    end

    local flashTime = 0
    local flashFrame = CreateFrame("Frame")
    flashFrame:Hide()
    flashFrame:SetScript("OnUpdate", function()
        local elapsed = arg1
        flashTime = flashTime - elapsed
        if flashTime < 0 then
            indicator.flash:SetAlpha(0)
            flashFrame:Hide()
        else
            local alpha = (flashTime / 0.3) * 0.5
            indicator.flash:SetAlpha(alpha)
        end
    end)
    local function TriggerFlash()
        flashTime = 0.3
        indicator.flash:SetAlpha(0.5)
        flashFrame:Show()
    end

    local pulseFrame = CreateFrame("Frame")
    pulseFrame:Hide()
    local pulseDir = 1
    local pulseAlpha = 1.0
    pulseFrame:SetScript("OnUpdate", function()
        local elapsed = arg1
        if pulseDir == 1 then
            pulseAlpha = pulseAlpha + (elapsed * 2)
            if pulseAlpha >= 1.0 then pulseAlpha = 1.0; pulseDir = -1 end
        else
            pulseAlpha = pulseAlpha - (elapsed * 2)
            if pulseAlpha <= 0.6 then pulseAlpha = 0.6; pulseDir = 1 end
        end
        indicator:SetAlpha(pulseAlpha * BackstabberDB.alpha)
    end)

    local optionsFrame = CreateFrame("Frame", "BackstabberOptions", UIParent)
    tinsert(UISpecialFrames, "BackstabberOptions") 
    
    optionsFrame:SetWidth(300)
    optionsFrame:SetHeight(580)
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    optionsFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    optionsFrame:Hide()

    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", optionsFrame, "TOP", 0, -20)
    title:SetText("Backstabber Settings")

    local authorText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    authorText:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 15)
    authorText:SetText("Created by Wristcry (dc@heavensfalling)")
    authorText:SetTextColor(0.5, 0.5, 0.5)

    local function CheckTarget()
        if not BackstabberDB.aura then return end

        if not UnitExists("target") or UnitIsDeadOrGhost("target") then 
            indicator:Hide()
            lastState = nil
            return false 
        end
        if BackstabberDB.combatOnly and not UnitAffectingCombat("player") then 
            indicator:Hide()
            lastState = nil
            return false 
        end
        
        local _, class = UnitClass("player")
        if class == "DRUID" then
            local isCat = false
            
            
            
            local powerType = UnitPowerType("player")
            if powerType == 3 then
                isCat = true
            end

            
            if not isCat then
                for i = 1, GetNumShapeshiftForms() do
                    local icon, name, active = GetShapeshiftFormInfo(i)
                    if active then
                        if (name and string.find(string.lower(name), "cat")) or 
                           (icon and string.find(string.lower(icon), "cat")) then
                            isCat = true
                            break
                        end
                    end
                end
            end
            
            if not isCat then
                indicator:Hide()
                lastState = nil
                return false
            end
        end

        indicator:Show()
        return true
    end

    local function CreateSlider(name, parent, min, max, val, text, step, func)
        local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        slider:SetValue(val)
        slider:SetScript("OnValueChanged", function() func(this:GetValue()) end)
        getglobal(name .. "Text"):SetText(text)
        getglobal(name .. "Low"):SetText(min)
        getglobal(name .. "High"):SetText(max)
        return slider
    end
    local function CreateCheckbox(name, parent, label, val, func)
        local cb = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
        cb:SetChecked(val)
        cb:SetScript("OnClick", function() func(this:GetChecked()) end)
        getglobal(name .. "Text"):SetText(label)
        return cb
    end
    local function CreateColorSwatch(name, parent, label, dbKey)
        local f = CreateFrame("Button", name, parent)
        f:SetWidth(20); f:SetHeight(20)
        local bg = f:CreateTexture(nil, "ARTWORK"); bg:SetAllPoints(f); bg:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
        local c = BackstabberDB[dbKey]; bg:SetVertexColor(c.r, c.g, c.b)
        f.bg = bg
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("LEFT", f, "RIGHT", 5, 0); t:SetText(label)
        f:SetScript("OnClick", function()
            local r, g, b = BackstabberDB[dbKey].r, BackstabberDB[dbKey].g, BackstabberDB[dbKey].b
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.func = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                BackstabberDB[dbKey] = {r=nr, g=ng, b=nb}
                f.bg:SetVertexColor(nr, ng, nb)
                if UpdateStateColor then UpdateStateColor() end
            end
            ColorPickerFrame.cancelFunc = function() BackstabberDB[dbKey] = {r=r, g=g, b=b}; f.bg:SetVertexColor(r, g, b); if UpdateStateColor then UpdateStateColor() end end
            ColorPickerFrame:Show()
        end)
        return f
    end

    local sWidth = CreateSlider("BSSliderWidth", optionsFrame, 20, 300, BackstabberDB.width, "Width", 1, function(v) BackstabberDB.width=v; UpdateVisuals() end)
    sWidth:SetPoint("TOP", optionsFrame, "TOP", 0, -50)
    local sHeight = CreateSlider("BSSliderHeight", optionsFrame, 10, 100, BackstabberDB.height, "Height", 1, function(v) BackstabberDB.height=v; UpdateVisuals() end)
    sHeight:SetPoint("TOP", sWidth, "BOTTOM", 0, -20)
    local sAlpha = CreateSlider("BSSliderAlpha", optionsFrame, 0.1, 1.0, BackstabberDB.alpha, "Transparency", 0.1, function(v) BackstabberDB.alpha=v; UpdateVisuals() end)
    sAlpha:SetPoint("TOP", sHeight, "BOTTOM", 0, -20)

    local texBtn = CreateFrame("Button", "BSTextureButton", optionsFrame, "UIPanelButtonTemplate")
    texBtn:SetWidth(140); texBtn:SetHeight(24); texBtn:SetPoint("TOP", sAlpha, "BOTTOM", 0, -30)
    local textures = {
        {name="Smooth", path="Interface\\TargetingFrame\\UI-StatusBar"},
        {name="Plain", path="Interface\\Buttons\\WHITE8X8"},
        {name="Blizzard", path="Interface\\RaidFrame\\Raid-Bar-Hp-Fill"},
        {name="PfUI", path="Interface\\AddOns\\PfUI\\img\\bar"}
    }
    local function UpdateTexBtnText() 
        local n="Unknown"; for _,t in ipairs(textures) do if t.path==BackstabberDB.texture then n=t.name end end; texBtn:SetText("Texture: "..n) 
    end
    UpdateTexBtnText()
    texBtn:SetScript("OnClick", function()
        local idx=1; for i,t in ipairs(textures) do if t.path==BackstabberDB.texture then idx=i end end
        idx=idx+1; if idx>4 then idx=1 end; BackstabberDB.texture=textures[idx].path; UpdateVisuals(); UpdateTexBtnText()
    end)

    local fontBtn = CreateFrame("Button", "BSFontButton", optionsFrame, "UIPanelButtonTemplate")
    fontBtn:SetWidth(140); fontBtn:SetHeight(24); fontBtn:SetPoint("TOP", texBtn, "BOTTOM", 0, -5)
    local fonts = {
        {name="Friz", path="Fonts\\FRIZQT__.TTF"},
        {name="Arial", path="Fonts\\ARIALN.TTF"},
        {name="Morpheus", path="Fonts\\MORPHEUS.TTF"},
        {name="Skurri", path="Fonts\\SKURRI.TTF"},
        {name="Expressway", path="Interface\\AddOns\\PfUI\\fonts\\Expressway.ttf"}
    }
    local function UpdateFontBtnText()
        local n="Unknown"; for _,f in ipairs(fonts) do if f.path==BackstabberDB.font then n=f.name end end; fontBtn:SetText("Font: "..n)
    end
    UpdateFontBtnText()
    fontBtn:SetScript("OnClick", function()
        local idx=1; for i,f in ipairs(fonts) do if f.path==BackstabberDB.font then idx=i end end
        idx=idx+1; if idx>5 then idx=1 end; BackstabberDB.font=fonts[idx].path; UpdateVisuals(); UpdateFontBtnText()
    end)

    local colSafe = CreateColorSwatch("BSColorSafe", optionsFrame, "Safe Color", "colorSafe"); colSafe:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 40, -280)
    local colWarn = CreateColorSwatch("BSColorWarn", optionsFrame, "Warning Color", "colorWarn"); colWarn:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 160, -280)

    local cbLock = CreateCheckbox("BSCheckLock", optionsFrame, "Lock Position", BackstabberDB.locked, function(v) BackstabberDB.locked = v and true or false end); cbLock:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 40, -320)
    
    local cbCombat = CreateCheckbox("BSCheckCombat", optionsFrame, "Combat Only", BackstabberDB.combatOnly, function(v) 
        BackstabberDB.combatOnly = v and true or false
        CheckTarget() 
    end)
    cbCombat:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, 0)
    
    local cbBorder = CreateCheckbox("BSCheckBorder", optionsFrame, "Show Border", BackstabberDB.showBorder, function(v) 
        BackstabberDB.showBorder = v and true or false
        UpdateVisuals() 
    end); 
    cbBorder:SetPoint("TOPLEFT", cbCombat, "BOTTOMLEFT", 0, 0)
    
    local cbPulse = CreateCheckbox("BSCheckPulse", optionsFrame, "Warning Pulse", BackstabberDB.pulseEnabled, function(v) 
        BackstabberDB.pulseEnabled = v and true or false
        if not BackstabberDB.pulseEnabled then
            pulseFrame:Hide()
            indicator:SetAlpha(BackstabberDB.alpha)
        elseif currentState == "RED" then
            pulseFrame:Show()
        end
    end)
    cbPulse:SetPoint("TOPLEFT", cbBorder, "BOTTOMLEFT", 0, 0)
    
    local cbSound = CreateCheckbox("BSCheckSound", optionsFrame, "Play Sound", BackstabberDB.sound, function(v) BackstabberDB.sound = v and true or false end); cbSound:SetPoint("TOPLEFT", cbPulse, "BOTTOMLEFT", 0, 0)
    local cbText = CreateCheckbox("BSCheckText", optionsFrame, "Show Text", BackstabberDB.showText, function(v) BackstabberDB.showText = v and true or false; UpdateVisuals() end); cbText:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 160, -320)
    local cbDebug = CreateCheckbox("BSCheckDebug", optionsFrame, "Debug Mode", BackstabberDB.debug, function(v) BackstabberDB.debug = v and true or false; UpdateVisuals() end); cbDebug:SetPoint("TOPLEFT", cbText, "BOTTOMLEFT", 0, 0)

    local resetBtn = CreateFrame("Button", "BSResetPosButton", optionsFrame, "UIPanelButtonTemplate")
    resetBtn:SetWidth(120); resetBtn:SetHeight(24); resetBtn:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 20, 30); resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        BackstabberDB.x = 0
        BackstabberDB.y = 0
        indicator:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)

    local closeBtn = CreateFrame("Button", "BSOptionsClose", optionsFrame, "UIPanelButtonTemplate")
    closeBtn:SetWidth(100); closeBtn:SetHeight(24); closeBtn:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -20, 30); closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() optionsFrame:Hide() end)

    local mmBtn = CreateFrame("Button", "BackstabberMinimapBtn", Minimap)
    mmBtn:SetFrameStrata("LOW"); mmBtn:SetWidth(32); mmBtn:SetHeight(32)
    mmBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp"); mmBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local mmOverlay = mmBtn:CreateTexture(nil, "OVERLAY"); mmOverlay:SetWidth(53); mmOverlay:SetHeight(53); mmOverlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); mmOverlay:SetPoint("TOPLEFT", 0, 0)
    local mmIcon = mmBtn:CreateTexture(nil, "BACKGROUND"); mmIcon:SetWidth(20); mmIcon:SetHeight(20); mmIcon:SetTexture("Interface\\Icons\\Ability_Backstab"); mmIcon:SetPoint("CENTER", 0, 1)
    
    local function UpdateMinimapPosition()
        local a = math.rad(BackstabberDB.minimapPos); local x,y = math.cos(a)*80, math.sin(a)*80; mmBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    UpdateMinimapPosition()
    mmBtn:SetScript("OnDragStart", function() this:LockHighlight(); this.isDragging=true; this:SetScript("OnUpdate", function() local mx,my=Minimap:GetCenter(); local cx,cy=GetCursorPosition(); local s=UIParent:GetEffectiveScale(); cx,cy=cx/s,cy/s; local rad=math.atan2(cy-my,cx-mx); BackstabberDB.minimapPos=math.deg(rad); UpdateMinimapPosition() end) end)
    mmBtn:SetScript("OnDragStop", function() this:UnlockHighlight(); this.isDragging=false; this:SetScript("OnUpdate", nil) end)
    mmBtn:SetScript("OnClick", function() if optionsFrame:IsVisible() then optionsFrame:Hide() else optionsFrame:Show() end end)
    mmBtn:RegisterForDrag("RightButton")

    indicator:SetMovable(true); indicator:EnableMouse(true); indicator:RegisterForDrag("LeftButton")
    indicator:SetScript("OnDragStart", function() if not BackstabberDB.locked then this:StartMoving() end end)
    indicator:SetScript("OnDragStop", function() this:StopMovingOrSizing(); local _,_,_,x,y = this:GetPoint(); BackstabberDB.x=x; BackstabberDB.y=y end)

    UpdateStateColor = function()
        local c
        if currentState == "GREEN" then c = BackstabberDB.colorSafe
        else c = BackstabberDB.colorWarn end
        
        indicator.bar:SetVertexColor(c.r, c.g, c.b, 1)
        
        local borderAlpha = 0
        if BackstabberDB.showBorder then borderAlpha = 1 end
        indicator:SetBackdropBorderColor(c.r*0.8, c.g*0.8, c.b*0.8, borderAlpha)
    end

    local function SetState(newState)
        if newState == "GREEN" then
            currentState = "GREEN"
            text:SetText("BEHIND")
            TriggerFlash(); pulseFrame:Hide(); indicator:SetAlpha(BackstabberDB.alpha)
            if BackstabberDB.debug then DEFAULT_CHAT_FRAME:AddMessage("BS: Safe") end
        else
            currentState = "RED"
            text:SetText("NOT BEHIND")
            if BackstabberDB.pulseEnabled then pulseFrame:Show() end
            if BackstabberDB.sound and lastState == "GREEN" then PlaySoundFile("Interface\\AddOns\\Backstabber\\alert.mp3") end
            if BackstabberDB.debug then DEFAULT_CHAT_FRAME:AddMessage("BS: Red") end
        end
        UpdateStateColor()
    end

    local function CheckAuraState()
        if not BackstabberDB.aura then
            indicator:Hide()
            lockFrame:Show()
        else
            lockFrame:Hide()
            CheckTarget()
        end
    end

    local function GetMeleeThreshold()
        local _, race = UnitRace("player")
        local base = 0.19 
        
        if race then
            race = string.upper(race)
            if race == "GNOME" or race == "GOBLIN" then 
                base = 0.16 
            elseif race == "TAUREN" then 
                base = 0.26 
            end
        end
        
        return base + GetBuffScale()
    end

    local debugTimer = 0
    indicator:SetScript("OnUpdate", function() 
        if not BackstabberDB.aura then return end
        if not CheckTarget() then return end

        local behind = false
        local range = false

        if type(UnitXP) == "function" then
            local ok, res = pcall(UnitXP, "behind", "player", "target")
            if ok and res then behind = true end
            
            local okD, dist = pcall(UnitXP, "distanceBetween", "player", "target", "meleeAutoAttack")
            if okD and dist then
                if dist <= GetMeleeThreshold() then
                    range = true
                end
            end
            
            if BackstabberDB.debug then
                debugTimer = debugTimer + arg1
                if debugTimer > 0.5 then
                    debugTimer = 0
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("BS Debug: Behind=%s Range=%s", tostring(behind), tostring(range)))
                end
            end
        else
            
            behind = true
            range = (IsSpellInRange("Backstab", "target") == 1) or (IsSpellInRange("Ambush", "target") == 1)
        end

        local newState = "RED"
        if behind and range then
            newState = "GREEN"
        else
            newState = "RED"
        end
        
        if lastState ~= newState then
            SetState(newState)
            lastState = newState
        end
    end)

    indicator:RegisterEvent("PLAYER_TARGET_CHANGED")
    indicator:RegisterEvent("PLAYER_ENTERING_WORLD")
    indicator:RegisterEvent("PLAYER_REGEN_ENABLED")
    indicator:RegisterEvent("PLAYER_REGEN_DISABLED")
    indicator:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    indicator:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    indicator:RegisterEvent("UNIT_DISPLAYPOWER")

    indicator:SetScript("OnEvent", function()
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if arg1 == "Backstab" or arg1 == "Ambush" or arg1 == "Garrote" or arg1 == "Shred" or arg1 == "Ravage" then 
                TriggerFlash()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            if not welcomePrinted then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Backstabber|r by |cFF00BFFFWristcry|r loaded. /bsb")
                if not BackstabberDB.aura then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00BFFFSay the magic word.|r")
                end
                welcomePrinted = true
            end
            CheckAuraState()
        else
            if BackstabberDB.aura then CheckTarget() end
        end
    end)
    
    SLASH_BACKSTABBER1="/bsb"
    SLASH_BACKSTABBER2="/backstabber"
    SlashCmdList["BACKSTABBER"]=function(msg) 
        
        msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
        
       local channeledAura = DeriveAura(msg)
        if channeledAura == MASTER_AURA then
            BackstabberDB.aura = true
            CheckAuraState()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Success.|r")
        elseif optionsFrame:IsVisible() then 
            optionsFrame:Hide() 
        else 
            optionsFrame:Show() 
        end 
    end

    UpdateVisuals()
end)
