local _, ns = ...

-- The buttons Satellite has collected, from every source (see Collectors). Each button is saved
-- under a key that stays the same between sessions ("ldb:BugSack"), so the order and settings
-- the player gives it can be kept by that key.
local Buttons = {}
ns.Buttons = Buttons

-- [key] = { key, source, name, label, ... }; the fields after label depend on the source. label is
-- the name the player gave it (see SetName) or ownLabel, the one its collector gave it.
local buttons = {}
-- All buttons sorted by label, made again only after a change (see GetAll).
local sorted

-- Functions to call when buttons were added or removed (see OnChanged).
local listeners = {}
local isNotifyPending = false
-- Counts the changes, at once (the listeners hear of them at the end of the frame): what's worked
-- out from the buttons can be kept until it changes (see GetChangeCount).
local changeCount = 0

function Buttons.GetChangeCount()
    return changeCount
end

-- Tells the listeners once per frame, however many buttons changed in it (at login, dozens).
-- Also for changes that decide which buttons the launcher shows (see IsInLauncher).
function Buttons.NotifyChanged()
    changeCount = changeCount + 1
    if isNotifyPending then
        return
    end
    isNotifyPending = true
    C_Timer.After(0, function()
        isNotifyPending = false
        for _, listener in ipairs(listeners) do
            listener()
        end
    end)
end

-- Calls listener() after buttons were added, replaced or removed.
function Buttons.OnChanged(listener)
    listeners[#listeners + 1] = listener
end

-- Whether two buttons have the same fields (collectors make a new table each time they look).
local function IsSame(a, b)
    for field, value in pairs(a) do
        if b[field] ~= value then
            return false
        end
    end
    for field in pairs(b) do
        if a[field] == nil then
            return false
        end
    end
    return true
end

-- Sets button's label from its own and the name the player gave it, and what it's sorted by.
local function ApplyName(button)
    button.label = ns.db.buttonNames[button.key] or button.ownLabel
    button.sortKey = button.label:lower()
end

-- Adds button, or replaces the one with the same key. Returns true if it's new. Nothing changes
-- (and no one is told) if the same button is already there.
function Buttons.Add(button)
    local old = buttons[button.key]
    button.ownLabel = button.label
    ApplyName(button)
    if old and IsSame(old, button) then
        return false
    end
    buttons[button.key] = button
    sorted = nil
    if not old then
        ns:Debug("Found", button.key)
    end
    Buttons.NotifyChanged()
    return old == nil
end

function Buttons.Remove(key)
    if buttons[key] then
        buttons[key] = nil
        sorted = nil
        ns:Debug("Removed", key)
        Buttons.NotifyChanged()
    end
end

function Buttons.Get(key)
    return buttons[key]
end

-- A collector found a new name for button (see Handmade): its own label, kept behind the
-- player's.
function Buttons.SetOwnLabel(button, label)
    if label ~= button.ownLabel then
        button.ownLabel = label
        ApplyName(button)
        sorted = nil
    end
end

-- The player's name for the button with key; nil, empty or its own name gives it back its own.
function Buttons.SetName(key, name)
    name = name and strtrim(name) or ""
    local button = buttons[key]
    if name == "" or (button and name == button.ownLabel) then
        name = nil
    end
    ns.db.buttonNames[key] = name
    if button then
        ApplyName(button)
        sorted = nil
    end
    Buttons.NotifyChanged()
end

local function CompareButtons(a, b)
    if a.sortKey ~= b.sortKey then
        return a.sortKey < b.sortKey
    end
    return a.key < b.key
end

-- All buttons, sorted by label. The list is shared; callers don't change it.
function Buttons.GetAll()
    if not sorted then
        sorted = {}
        for _, button in pairs(buttons) do
            sorted[#sorted + 1] = button
        end
        table.sort(sorted, CompareButtons)
    end
    return sorted
end

-- Whether the launcher shows button: every addon with a minimap button (LibDBIcon draws it for
-- LibDataBroker objects of any type; BugSack's is a data source). Addons without one (only in the
-- addon compartment, or only for broker displays like Titan Panel) when the player wants them.
-- Hand-made buttons found by the minimap scan as Handmade says.
function Buttons.IsInLauncher(button)
    if button.source == "frame" then
        return ns.Handmade.IsCollected(button)
    end
    -- Blizzard's expansion button (collected only while it's on the minimap) when the player wants it.
    if button.source == "blizzard" then
        return ns.db.includeExpansionButton
    end
    if button.source == "ldb" and ns.Broker.HasMinimapButton(button) then
        return true
    end
    return ns.db.showWithoutMinimapButton
end

-- The player's order and hidden buttons --------------------------------------------------------
-- ns.db.buttonOrder lists keys in the player's order; buttons not in it come after, by name.
-- ns.db.hiddenButtons: [key] = true for the buttons the player took out of the menu (false for
-- one hidden by default that they put in, see IsHidden).

-- The buttons that can be in the menu, hidden ones too, in the player's order.
function Buttons.GetCandidates()
    local orderIndex = {}
    for index, key in ipairs(ns.db.buttonOrder) do
        orderIndex[key] = index
    end
    local list, nameIndex = {}, {}
    for _, button in ipairs(Buttons.GetAll()) do
        if Buttons.IsInLauncher(button) then
            list[#list + 1] = button
            nameIndex[button] = #list
        end
    end
    table.sort(list, function(a, b)
        local orderA, orderB = orderIndex[a.key], orderIndex[b.key]
        if orderA and orderB then
            return orderA < orderB
        elseif orderA or orderB then
            return orderA ~= nil
        end
        return nameIndex[a] < nameIndex[b]
    end)
    return list
end

-- The buttons the menu shows, in order.
function Buttons.GetLauncherButtons()
    local list = {}
    for _, button in ipairs(Buttons.GetCandidates()) do
        if not Buttons.IsHidden(button.key) then
            list[#list + 1] = button
        end
    end
    return list
end

-- Favorites -------------------------------------------------------------------------------------
-- ns.db.favoriteButtons: [key] = true for the buttons the player made favorites (see Favorites).

-- At most this many, so they fit along the minimap's ring.
Buttons.MAX_FAVORITES = 4

function Buttons.IsFavorite(key)
    return ns.db.favoriteButtons[key] == true
end

-- The favorites the menu has, in the player's order: at most MAX_FAVORITES (a saved favorite of an
-- addon that's off doesn't count; when it's back, one too many stays in the menu). From
-- launcherButtons, if given (Buttons.GetLauncherButtons, already made).
function Buttons.GetFavorites(launcherButtons)
    local list = {}
    for _, button in ipairs(launcherButtons or Buttons.GetLauncherButtons()) do
        if Buttons.IsFavorite(button.key) and #list < Buttons.MAX_FAVORITES then
            list[#list + 1] = button
        end
    end
    return list
end

function Buttons.SetFavorite(key, isFavorite)
    ns.db.favoriteButtons[key] = isFavorite or nil
    -- Its icon as it is now is its normal, wherever it shows (see Alert).
    ns.Alert.Forget(key)
    Buttons.NotifyChanged()
end

-- Buttons out of the menu until the player ticks them: [key] = true.
local OUT_OF_MENU = {
    -- Plumber's expansion summary: its own button stays on the minimap (see Handmade), as
    -- Blizzard's expansion button does (see Collectors/Blizzard.lua).
    ["ldb:PlumberLandingButton"] = true,
}

-- Whether the button with key is hidden without the player saying (see also
-- Handmade.IsHiddenByDefault).
local function IsHiddenByDefault(key)
    local button = buttons[key]
    if OUT_OF_MENU[key] then
        return true
    end
    return button ~= nil and button.source == "frame" and ns.Handmade.IsHiddenByDefault(button)
end

-- Whether the player took the button out of the menu (a hand-made one is back on the minimap
-- then). ns.db.hiddenButtons has true for hidden, or false for shown when it's hidden by default.
function Buttons.IsHidden(key)
    local isHidden = ns.db.hiddenButtons[key]
    if isHidden == nil then
        return IsHiddenByDefault(key)
    end
    return isHidden
end

-- Buttons without the alert dot until the player turns it on: boss mods change their icon with
-- the instance and their modules (BigWigs's button also shows LittleWigs and TinyWigs).
local QUIET_BY_DEFAULT = {
    ["ldb:BigWigs"] = true,
    ["ldb:DBM"] = true,
}

-- Whether the button with key shows no alert dot when its icon changes (see Alert).
-- ns.db.quietButtons has true for quiet, or false for alerting when it's quiet by default.
function Buttons.IsQuiet(key)
    local isQuiet = ns.db.quietButtons[key]
    if isQuiet == nil then
        return QUIET_BY_DEFAULT[key] == true
    end
    return isQuiet
end

function Buttons.SetQuiet(key, isQuiet)
    if isQuiet == (QUIET_BY_DEFAULT[key] == true) then
        ns.db.quietButtons[key] = nil
    else
        ns.db.quietButtons[key] = isQuiet
    end
    ns.Alert.Forget(key)
end

function Buttons.SetHidden(key, isHidden)
    if isHidden == IsHiddenByDefault(key) then
        ns.db.hiddenButtons[key] = nil
    else
        ns.db.hiddenButtons[key] = isHidden
    end
    Buttons.NotifyChanged()
end

-- Saves keys as the order. Keys of buttons that aren't there now (an addon turned off) keep their
-- place at the end.
function Buttons.SetOrder(keys)
    local order, isListed = {}, {}
    for _, key in ipairs(keys) do
        order[#order + 1] = key
        isListed[key] = true
    end
    for _, oldKey in ipairs(ns.db.buttonOrder) do
        if not isListed[oldKey] then
            order[#order + 1] = oldKey
        end
    end
    ns.db.buttonOrder = order
    Buttons.NotifyChanged()
end

-- Moves the button with key step places (-1 up, 1 down) among the candidates.
function Buttons.Move(key, step)
    local keys = {}
    local from
    for index, button in ipairs(Buttons.GetCandidates()) do
        keys[index] = button.key
        if button.key == key then
            from = index
        end
    end
    local to = from and from + step
    if not to or to < 1 or to > #keys then
        return
    end
    keys[from], keys[to] = keys[to], keys[from]
    Buttons.SetOrder(keys)
end

-- Saved keys of removed addons ------------------------------------------------------------------
-- The order, hidden buttons, names and favorites are kept by key, also while an addon is turned
-- off or not loaded yet (it may come back). Keys whose button hasn't been there for PRUNE_DAYS are
-- taken out.

-- Checked this long after login, once addons have made their buttons.
local PRUNE_DELAY = 20
local PRUNE_DAYS = 30

function Buttons.Prune()
    local now = time()
    local seen = ns.db.buttonsSeen
    for key in pairs(buttons) do
        seen[key] = now
    end
    local isSaved = {}
    for _, key in ipairs(ns.db.buttonOrder) do
        isSaved[key] = true
    end
    for key in pairs(ns.db.hiddenButtons) do
        isSaved[key] = true
    end
    for key in pairs(ns.db.quietButtons) do
        isSaved[key] = true
    end
    for key in pairs(ns.db.buttonNames) do
        isSaved[key] = true
    end
    for key in pairs(ns.db.favoriteButtons) do
        isSaved[key] = true
    end
    local isGone = {}
    for key in pairs(isSaved) do
        -- Saved before Satellite kept track: counted from now.
        seen[key] = seen[key] or now
        if now - seen[key] > PRUNE_DAYS * 24 * 60 * 60 then
            isGone[key] = true
        end
    end
    for key in pairs(seen) do
        if isGone[key] or not isSaved[key] then
            seen[key] = nil
        end
    end
    if not next(isGone) then
        return
    end
    local order = {}
    for _, key in ipairs(ns.db.buttonOrder) do
        if not isGone[key] then
            order[#order + 1] = key
        end
    end
    ns.db.buttonOrder = order
    for key in pairs(isGone) do
        ns.db.hiddenButtons[key] = nil
        ns.db.quietButtons[key] = nil
        ns.db.buttonNames[key] = nil
        ns.db.favoriteButtons[key] = nil
        ns:Debug("Pruned", key)
    end
end

-- Called once ns.db is loaded.
function Buttons:Setup()
    ns:RegisterEvent("PLAYER_LOGIN", function()
        C_Timer.After(PRUNE_DELAY, Buttons.Prune)
    end)
end

-- Back to sorting by name.
function Buttons.ResetOrder()
    wipe(ns.db.buttonOrder)
    Buttons.NotifyChanged()
end
