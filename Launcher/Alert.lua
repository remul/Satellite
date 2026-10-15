local _, ns = ...

-- A small dot on the launcher when an addon changed its icon since the menu was last opened, as
-- addons do to show something new (BugSack's bug turns red). Opening the menu clears it; the
-- buttons that changed show the same dot until the menu closes. An icon that changes back (the
-- errors read) clears it too. Each style says where its dot goes (Style:GetAlertPoint); the
-- Always open style has none, its menu shows everything already.
--
-- Some addons use their icon to show a state that follows the zone (BigWigs lights up in an
-- instance): changes just after a loading screen or a zone change are taken as the new normal.
-- The player can also turn the dot off for single buttons (Buttons.SetQuiet); boss mods have it
-- off until turned on.
--
-- Favorites beside the launcher (see Favorites) show their own dot, until they're clicked; and not
-- the launcher's, as they can be seen already (unless they only show on mouseover).
local Alert = {}
ns.Alert = Alert

local Theme = ns.Theme

-- Addons set their icons as they load, so changes count from this many seconds after login; and
-- after a loading screen or a zone change, from this many seconds after.
local START_DELAY = 5
local ZONE_DELAY = 5
-- The dot's size (without its outline) and colour; it pulses gently.
local DOT_SIZE = 8
local DOT_COLOR = CreateColor(0.95, 0.27, 0.2, 1)
Alert.DOT_COLOR = DOT_COLOR
local PULSE_ALPHA, PULSE_TIME = 0.55, 0.8

-- [key] = what its icon looked like when the menu was last opened (see LauncherButton.GetIconLook),
-- and [key] = true for the buttons whose icon differs now.
local seen, changed = {}, {}
local isWatching = false
-- Until when (GetTime()) icon changes are the new normal, after zoning.
local quietUntil = 0
local dot

local function IsWatched(button)
    return ns.Buttons.IsInLauncher(button) and not ns.Buttons.IsHidden(button.key)
        and not ns.Buttons.IsQuiet(button.key)
end

local function CreateDot()
    dot = CreateFrame("Frame", nil, UIParent)
    Theme.AddTexture(dot, Theme.DISC, "ARTWORK", 0, Theme.OUTLINE, 1.5)
    Theme.AddTexture(dot, Theme.DISC, "ARTWORK", 1, DOT_COLOR)
    local pulse = dot:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(PULSE_ALPHA)
    alpha:SetDuration(PULSE_TIME)
    alpha:SetSmoothing("IN_OUT")
    dot:SetScript("OnShow", function()
        pulse:Play()
    end)
    dot:SetScript("OnHide", function()
        pulse:Stop()
    end)
    dot:Hide()
end

-- Whether the button with key changed its icon since it was last seen.
function Alert.IsChanged(key)
    return changed[key] == true
end

-- Whether a button whose change the launcher's dot shows changed its icon: one in the menu, or
-- a favorite that only shows on mouseover (the others show their own).
local function HasLauncherChanges()
    if ns.db.showFavorites == "hover" then
        return next(changed) ~= nil
    end
    for key in pairs(changed) do
        if not ns.Favorites.IsShownOutside(key) then
            return true
        end
    end
    return false
end

-- Shows or hides the dot on the launcher, where the current style puts it.
function Alert.Update()
    local style = ns.Launcher.GetStyle()
    local frame, point, x, y
    if ns.db.showAlerts and HasLauncherChanges() and not ns.Menu.IsOpen() and style.GetAlertPoint then
        frame, point, x, y = style:GetAlertPoint()
    end
    if not frame then
        if dot then
            dot:Hide()
        end
        return
    end
    if not dot then
        CreateDot()
    end
    local size = DOT_SIZE * ns.Launcher.GetScale()
    dot:SetParent(frame)
    dot:SetSize(size, size)
    dot:SetFrameLevel(frame:GetFrameLevel() + 10)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", frame, point, x, y)
    dot:Show()
end

-- Remembers every button's icon as it is now; with menuOnly, the menu's, not the favorites'
-- beside the launcher (theirs stay until they're clicked).
local function Remember(menuOnly)
    for _, button in ipairs(ns.Buttons.GetLauncherButtons()) do
        if not menuOnly or not ns.Favorites.IsShownOutside(button.key) then
            seen[button.key] = ns.LauncherButton.GetIconLook(button)
            changed[button.key] = nil
        end
    end
end

-- Called when the button with key may have changed its icon.
function Alert.Check(key)
    if not isWatching then
        return
    end
    local button = ns.Buttons.Get(key)
    if not button or not IsWatched(button) then
        changed[key] = nil
    elseif seen[key] == nil or GetTime() < quietUntil then
        -- New since the menu was opened, or just after zoning: what it shows now is its normal.
        seen[key] = ns.LauncherButton.GetIconLook(button)
        changed[key] = nil
    else
        changed[key] = ns.LauncherButton.GetIconLook(button) ~= seen[key] or nil
    end
    if ns.Favorites.IsShownOutside(key) then
        ns.LauncherButton.SetAlerted(key, ns.db.showAlerts and changed[key] == true)
    end
    Alert.Update()
end

-- Takes the button's icon as it is now as its normal (e.g. its dot was just turned back on).
function Alert.Forget(key)
    seen[key], changed[key] = nil, nil
    Alert.Check(key)
end

-- The menu opened: the buttons that changed show their dot, and the launcher's goes.
function Alert.OnMenuOpened()
    for key in pairs(changed) do
        if not ns.Favorites.IsShownOutside(key) then
            ns.LauncherButton.SetAlerted(key, ns.db.showAlerts)
        end
    end
    if isWatching then
        -- Favorites on mouseover show with the menu: seen now too (their own dot stays until
        -- they're clicked).
        Remember(ns.db.showFavorites ~= "hover")
    end
    Alert.Update()
end

function Alert.OnMenuClosed()
    ns.LauncherButton.ClearAlerts()
    Alert.Update()
end

-- Called at login.
function Alert.Start()
    C_Timer.After(START_DELAY, function()
        Remember()
        isWatching = true
    end)
    local function OnZoneChanged()
        quietUntil = GetTime() + ZONE_DELAY
    end
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", OnZoneChanged)
    ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChanged)
end
