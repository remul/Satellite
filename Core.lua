local addonName, ns = ...
local L = ns.L

ns.TITLE = "Satellite"
-- Path to the addon's own textures, e.g. ns.MEDIA .. "Icon".
ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

-- Defaults are copied into the saved variables on first load and whenever new keys are added.
local DEFAULTS = {
    debug = false,
    -- The launcher (see Launcher/Launcher.lua), in pixels: distance of its arrow from the
    -- minimap's west compass arrow (when it's beside it, not in its place), and size of the
    -- buttons in its menu; and the launcher's own size for each style, in percent of its normal
    -- size ([style] = percent; 100 while missing), so each style keeps its own.
    launcher = {
        gap = 4,
        buttonSize = 28,
        scales = {},
    },
    -- The launcher's style (see Launcher/Styles): "satellite", "arrow", "circle", "square",
    -- "sideBar" or "alwaysOpen".
    style = "satellite",
    -- Where the player dragged each style's launcher to, missing while it's in its
    -- default place: [style] = { x, y } (its center from the screen's bottom left), or { degrees }
    -- (the satellite on the ring); the circle and square share shape = { x, y } or { edge, offset }
    -- (docked on an edge).
    positions = {},
    -- The side bar's edge of the screen ("LEFT", "RIGHT", "TOP" or "BOTTOM") and place along it
    -- (from the middle); it follows the circle and square, and they follow it (see
    -- Launcher.SetShapePosition).
    sideBar = { side = "RIGHT", offset = 0 },
    -- Put the launcher's arrow in the place of the minimap's west compass arrow (see
    -- Launcher/Compass.lua), instead of beside it.
    replaceCompassArrow = true,
    -- Which way the circle's and square's menu opens while they're not docked on an edge: "AUTO"
    -- (toward the middle of the screen), "LEFT", "RIGHT", "UP" or "DOWN".
    openDirection = "AUTO",
    -- The colours of the player's class, spec or hero talent image (see IconStack): "full" (its
    -- own), "gray", or tinted "gold", "silver" or "bronze".
    imageColors = "full",
    -- How that image comes alive while the launcher is hovered (see IconStack): "glow", "turn" or
    -- "none".
    imageAnimation = "glow",
    -- The border colour of the minimap button, circle and square, and their chevron (see
    -- Theme.GetAccentColors): "gold", "silver", "bronze" or "class".
    borderColor = "gold",
    -- What's on the minimap button, circle and square (see IconStack): "satellite" (Satellite's
    -- logo), "classImage", "specImage" or "heroImage" (the player's class, spec or hero talent
    -- image), or "prisma" (the guild Prisma's logo, for its members).
    discSymbols = "satellite",
    -- How many buttons go down each column of the menu before the next column starts; 0 lets
    -- Satellite choose (rows for few buttons, more as they grow).
    menuRows = 0,
    -- Whether the launcher stays where it is; unlocked, it moves when dragged (with Shift, it
    -- always does).
    locked = true,
    -- The menu's buttons in the player's order (keys), and the ones they hid: [key] = true, or
    -- false for one hidden by default that they put in (see Buttons.IsHidden).
    buttonOrder = {},
    hiddenButtons = {},
    -- The buttons whose icon changes don't show the alert dot (see Alert): [key] = true.
    quietButtons = {},
    -- The buttons the player made favorites: shown beside the launcher, out of the menu (see
    -- Launcher/Favorites.lua): [key] = true.
    favoriteButtons = {},
    -- Where favorites show: "always" (beside the launcher), "hover" (beside it while it's
    -- hovered or the menu is open) or "menu" (first in the menu).
    showFavorites = "always",
    -- The names the player gave buttons, in place of their own (see Buttons.SetName): [key] = name.
    buttonNames = {},
    -- When each of those keys' buttons was last there: [key] = time(). Keys not seen for a while
    -- (an addon removed) are taken out of both (see Buttons.Prune).
    buttonsSeen = {},
    -- Put Blizzard's expansion button (the landing page) in the menu too (see Collectors/Blizzard.lua).
    includeExpansionButton = false,
    -- What the menu's buttons show: "icons", "both" (the addons' names beside their icons) or
    -- "names" (only the names, as a list).
    menuLabels = "icons",
    -- The shape of the menu's buttons: "minimap" (Blizzard's minimap button), "circle", "square"
    -- or "diamond" (see LauncherButton).
    buttonShape = "circle",
    -- Close the menu after a click on one of its buttons (a right-click only if it opened no
    -- dropdown, see LauncherButton.AfterClick).
    closeOnClick = true,
    -- Open the menu when the mouse rests on the launcher.
    openOnHover = false,
    -- When the menu closes by itself (see Launcher.lua): "click" (after a click anywhere else) or
    -- "leave" (a moment after the mouse left the launcher and the menu).
    closeMode = "click",
    -- A dot on the launcher when an addon changed its icon since the menu was last opened (see
    -- Launcher/Alert.lua).
    showAlerts = true,
    -- Hide the addons' own LibDBIcon minimap buttons while the launcher shows them.
    hideMinimapButtons = true,
    -- Also move the minimap buttons that addons make by hand into the menu, while their own
    -- buttons are hidden (see Collectors/Handmade.lua).
    collectHandmadeButtons = true,
    -- Also show addons without a minimap button: only in the addon compartment, or LibDataBroker
    -- objects only for broker displays (see Buttons.IsInLauncher).
    showWithoutMinimapButton = false,
}

-- Saved settings that Satellite no longer uses go: keys that aren't in DEFAULTS, and places of
-- launchers that don't keep their own (the circle and square share "shape").
local POSITION_KEYS = { satellite = true, shape = true, alwaysOpen = true }

local function RemoveUnused(db)
    for key in pairs(db) do
        if DEFAULTS[key] == nil then
            db[key] = nil
        end
    end
    for key in pairs(db.positions) do
        if not POSITION_KEYS[key] then
            db.positions[key] = nil
        end
    end
end

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = type(value) == "table" and CopyTable(value) or value
        elseif type(value) == "table" and type(target[key]) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
end

function ns:Print(...)
    print("|cff33ff99" .. ns.TITLE .. "|r:", ...)
end

function ns:Debug(...)
    if self.db and self.db.debug then
        self:Print("|cff888888[debug]|r", ...)
    end
end

-- Event dispatch: ns:RegisterEvent("EVENT_NAME", callback) calls callback(...) when it fires.
-- Without a callback, ns:EVENT_NAME(...) is called. An event can have several callbacks.
local frame = CreateFrame("Frame")
-- [event] = { { key = callback or METHOD, run = function(...) } }. Lists are replaced, not changed
-- in place, so a callback can unregister itself while the event is being dispatched.
local callbacks = {}
local METHOD = {} -- key for the ns:EVENT_NAME handler

frame:SetScript("OnEvent", function(_, event, ...)
    local list = callbacks[event]
    if list then
        for _, entry in ipairs(list) do
            entry.run(...)
        end
    end
end)

local function AddCallback(event, callback)
    local list = CopyTable(callbacks[event] or {}, true)
    tinsert(list, {
        key = callback or METHOD,
        run = callback or function(...)
            -- Calls the ns:EVENT_NAME handler; the IDE can't tell which method that is.
            ---@diagnostic disable-next-line: param-type-mismatch
            ns[event](ns, ...)
        end,
    })
    callbacks[event] = list
end

function ns:RegisterEvent(event, callback)
    AddCallback(event, callback)
    frame:RegisterEvent(event)
end

-- Removes the callback given to RegisterEvent (without one: the ns:EVENT_NAME handler). Other
-- callbacks for the event keep running.
function ns:UnregisterEvent(event, callback)
    local key = callback or METHOD
    local list = {}
    for _, entry in ipairs(callbacks[event] or {}) do
        if entry.key ~= key then
            list[#list + 1] = entry
        end
    end
    if #list > 0 then
        callbacks[event] = list
    else
        callbacks[event] = nil
        frame:UnregisterEvent(event)
    end
end

-- Prints the buttons Satellite found, to check what it collects.
function ns.PrintButtons()
    -- Looks for hand-made minimap buttons now, to list the newest.
    ns.Scan.Run()
    local list = ns.Buttons.GetAll()
    if #list == 0 then
        ns:Print(L["No buttons found yet."])
        return
    end
    ns:Print(format(L["Buttons found: %d"], #list))
    local Broker = ns.Broker
    for _, button in ipairs(list) do
        local kind
        if button.source == "comp" then
            kind = L["Addon compartment"]
        elseif button.source == "frame" then
            kind = L["Minimap button"] .. " (" .. button.name .. ")"
        elseif button.source == "blizzard" then
            kind = L["Blizzard"]
        elseif button.type == Broker.LAUNCHER then
            kind = L["Launcher"]
        elseif button.type == Broker.DATA_SOURCE then
            kind = L["Data source"]
        else
            kind = L["Other"]
        end
        local line = "  " .. button.label .. " - " .. kind
        if button.source == "ldb" and Broker.HasMinimapButton(button) then
            line = line .. ", " .. L["has a minimap button"]
        end
        print(line)
    end
end

-- The settings are shared by all characters (SatelliteDB), or a character has its own
-- (SatelliteCharacterDB.settings, while SatelliteCharacterDB.isOwn). Switching reloads the
-- interface: Blizzard's Options hold on to the table they were set up with (see UI/Options.lua).
function ns.HasCharacterSettings()
    return SatelliteCharacterDB.isOwn == true
end

-- Turning them on starts from a copy of the shared ones (or the character's from before); off,
-- the character's are kept, for next time.
function ns.SetCharacterSettings(isOwn)
    SatelliteCharacterDB.isOwn = isOwn or nil
    if isOwn and not SatelliteCharacterDB.settings then
        SatelliteCharacterDB.settings = CopyTable(SatelliteDB)
    end
    ReloadUI()
end

StaticPopupDialogs.SATELLITE_CHARACTER_SETTINGS = {
    text = L["Reload the interface to switch Satellite's settings?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, isOwn)
        ns.SetCharacterSettings(isOwn)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Puts every setting back to its default, also the buttons' order and the hidden ones: the
-- character's own, or the shared ones. The settings stay the same table (Blizzard's Options read
-- from it, see UI/Options.lua).
function ns.ResetSettings()
    wipe(ns.db)
    ApplyDefaults(ns.db, DEFAULTS)
    ns.Buttons.NotifyChanged()
    ns.Launcher.Refresh()
    ns:Print(L["All settings are back to their defaults."])
end

StaticPopupDialogs.SATELLITE_RESET_SETTINGS = {
    text = L["Reset all of Satellite's settings? The order of your buttons and the hidden ones are reset too."],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        ns.ResetSettings()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Lifecycle
function ns:ADDON_LOADED(loadedName)
    if loadedName ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")

    SatelliteDB = SatelliteDB or {}
    SatelliteCharacterDB = SatelliteCharacterDB or {}
    local db = SatelliteDB
    if SatelliteCharacterDB.isOwn then
        SatelliteCharacterDB.settings = SatelliteCharacterDB.settings or CopyTable(SatelliteDB)
        db = SatelliteCharacterDB.settings
    end
    ApplyDefaults(db, DEFAULTS)
    RemoveUnused(db)
    self.db = db
    ns.Options:Setup()
    ns.Broker:Setup()
    ns.Compartment:Setup()
    ns.Blizzard:Setup()
    ns.Scan:Setup()
    ns.Handmade:Setup()
    ns.Buttons:Setup()
    ns.Launcher:Setup()
end

ns:RegisterEvent("ADDON_LOADED")

-- Global so the TOC's AddonCompartmentFunc can find it.
_G.Satellite_OnAddonCompartmentClick = function()
    ns.Options:Open()
end

-- Slash commands
SLASH_SATELLITE1 = "/satellite"

SlashCmdList.SATELLITE = function(msg)
    local cmd, rest = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")

    if cmd == "" then
        ns.Options:Open()
    elseif cmd == "list" then
        ns.PrintButtons()
    elseif cmd == "reset" then
        ns.Launcher.ResetPositions()
    elseif cmd == "scan" then
        ns.Scan.PrintRun()
    elseif cmd == "test" and ns.Test then
        -- Only in development copies: the release packager leaves Debug/Test.lua out (see the TOC).
        ns.Test.Command(rest)
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns:Print(L["Debug"], ns.db.debug and L["enabled"] or L["disabled"])
    else
        ns:Print(L["Commands:"])
        print(L["  /satellite - open the settings"])
        print(L["  /satellite list - list the buttons Satellite found"])
        print(L["  /satellite reset - put the launcher back in its place"])
        print(L["  /satellite debug - toggle debug output"])
        if ns.db.debug then
            print(L["  /satellite scan - scan the minimap now"])
            if ns.Test then
                print(L["  /satellite test - test buttons and map pins"])
            end
        end
    end
end
