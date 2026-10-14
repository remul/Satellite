local _, ns = ...

-- A small dot on the launcher when an addon changed its icon since the menu was last opened, as
-- addons do to show something new (BugSack's bug turns red). Opening the menu clears it; the
-- buttons that changed show the same dot until the menu closes. An icon that changes back (the
-- errors read) clears it too. Each style says where its dot goes (Style:GetAlertPoint); the
-- Always open style has none, its menu shows everything already.
local Alert = {}
ns.Alert = Alert

local Theme = ns.Theme

-- Addons set their icons as they load, so changes count from this many seconds after login.
local START_DELAY = 5
-- The dot's size (without its outline) and colour; it pulses gently.
local DOT_SIZE = 8
local DOT_COLOR = CreateColor(0.95, 0.27, 0.2, 1)
local PULSE_ALPHA, PULSE_TIME = 0.55, 0.8

-- [key] = what its icon looked like when the menu was last opened (see LauncherButton.GetIconLook),
-- and [key] = true for the buttons whose icon differs now.
local seen, changed = {}, {}
local isWatching = false
local dot

local function IsWatched(button)
    return ns.Buttons.IsInLauncher(button) and not ns.Buttons.IsHidden(button.key)
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

-- Shows or hides the dot on the launcher, where the current style puts it.
function Alert.Update()
    local style = ns.Launcher.GetStyle()
    local frame, point, x, y
    if ns.db.showAlerts and next(changed) and not ns.Menu.IsOpen() and style.GetAlertPoint then
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

-- Remembers every button's icon as it is now.
local function Remember()
    wipe(seen)
    wipe(changed)
    for _, button in ipairs(ns.Buttons.GetLauncherButtons()) do
        seen[button.key] = ns.LauncherButton.GetIconLook(button)
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
    elseif seen[key] == nil then
        -- New since the menu was opened: what it shows now is what it started with.
        seen[key] = ns.LauncherButton.GetIconLook(button)
    else
        changed[key] = ns.LauncherButton.GetIconLook(button) ~= seen[key] or nil
    end
    Alert.Update()
end

-- The menu opened: the buttons that changed show their dot, and the launcher's goes.
function Alert.OnMenuOpened()
    for key in pairs(changed) do
        ns.LauncherButton.SetAlerted(key, ns.db.showAlerts)
    end
    if isWatching then
        Remember()
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
end
