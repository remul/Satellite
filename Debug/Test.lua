local _, ns = ...

-- Test buttons and map pins (/satellite test), to try Satellite without installing many addons.
-- They copy what real addons do, so every collector and filter has something to find:
-- - launchers: LibDataBroker launchers of every kind, most with a LibDBIcon minimap button;
-- - data sources: LibDataBroker objects with text that changes every second;
-- - compartment: entries in Blizzard's addon compartment;
-- - buttons: hand-made minimap buttons, as older addons create them;
-- - pins: many small map pins on the minimap, as TomTom or HandyNotes add them.
-- A developer tool, so its messages aren't translated.
local Test = {}
ns.Test = Test

local LDB = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

local PREFIX = "SatelliteTest"
local ICONS = {
    "Interface\\Icons\\INV_Misc_Bag_08",
    "Interface\\Icons\\INV_Misc_Gear_01",
    "Interface\\Icons\\INV_Misc_Map_01",
    "Interface\\Icons\\Spell_Nature_Lightning",
    "Interface\\Icons\\INV_Misc_Book_09",
    "Interface\\Icons\\Achievement_General",
    "Interface\\Icons\\INV_Misc_QuestionMark",
}
-- A round mask for the pins (the one Blizzard uses for portraits).
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local DEFAULT_COUNTS = { launchers = 6, data = 3, compartment = 3, buttons = 4, pins = 1000 }

-- How many of each kind are shown now.
local counts = { launchers = 0, data = 0, compartment = 0, buttons = 0, pins = 0 }

local function Icon(i)
    return ICONS[(i - 1) % #ICONS + 1]
end

local function OnClickPrint(name)
    return function(_, mouseButton)
        ns:Print(format("Test click: %s (%s)", name, tostring(mouseButton)))
    end
end

-- A point on a circle around the minimap's center: angle in degrees, radius as a share of the
-- minimap's half width (1 = its edge).
local function MinimapOffset(angle, radius)
    local half = Minimap:GetWidth() / 2
    return math.cos(math.rad(angle)) * half * radius, math.sin(math.rad(angle)) * half * radius
end

-- LibDataBroker launchers ----------------------------------------------------------------------

-- One kind per launcher, in turn, so a handful covers everything addons do with their objects.
local LAUNCHER_KINDS = {
    "tooltip",    -- OnTooltipShow, the usual way
    "enter",      -- OnEnter/OnLeave instead of OnTooltipShow
    "coords",     -- iconCoords and a tinted icon (iconR/G/B)
    "nolabel",    -- no label: only the object's name
    "long",       -- a very long label
    "brokeronly", -- no minimap button: only for broker displays (e.g. Titan Panel)
}

-- Settings LibDBIcon keeps per button, normally saved by the addon: [name] = { minimapPos }.
local iconSettings = {}
local launcherNames = {}

local function LauncherName(i)
    return PREFIX .. "Launcher" .. i
end

local function CreateLauncher(i)
    local name = LauncherName(i)
    local kind = LAUNCHER_KINDS[(i - 1) % #LAUNCHER_KINDS + 1]
    local object = {
        type = "launcher",
        icon = Icon(i),
        label = format("Test %s %d", kind, i),
        OnClick = OnClickPrint(name),
    }
    if kind == "enter" then
        object.OnEnter = function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
            GameTooltip:AddLine(name)
            GameTooltip:AddLine("Tooltip from OnEnter", 1, 1, 1)
            GameTooltip:Show()
        end
        object.OnLeave = GameTooltip_Hide
    else
        object.OnTooltipShow = function(tooltip)
            tooltip:AddLine(name)
            tooltip:AddLine(format("Kind: %s", kind), 1, 1, 1)
        end
    end
    if kind == "coords" then
        object.iconCoords = { 0.1, 0.9, 0.1, 0.9 }
        object.iconR, object.iconG, object.iconB = 0.4, 0.8, 1
    elseif kind == "nolabel" then
        object.label = nil
    elseif kind == "long" then
        object.label = format("Test launcher with a really quite long name %d", i)
    end
    LDB:NewDataObject(name, object)
    if kind ~= "brokeronly" then
        iconSettings[name] = { minimapPos = (i * 37) % 360 }
        LibDBIcon:Register(name, LDB:GetDataObjectByName(name), iconSettings[name])
    end
    launcherNames[i] = name
end

-- LibDataBroker can't remove objects, so hidden ones stay in it until /reload; Satellite's list
-- drops them, and their minimap buttons are hidden.
local function SetLaunchers(n)
    for i = 1, math.max(n, counts.launchers) do
        local name = LauncherName(i)
        if i <= n then
            if not launcherNames[i] then
                CreateLauncher(i)
            else
                ns.Broker.Collect(name, LDB:GetDataObjectByName(name))
                LibDBIcon:Show(name)
            end
        elseif launcherNames[i] then
            ns.Buttons.Remove("ldb:" .. name)
            LibDBIcon:Hide(name)
        end
    end
    counts.launchers = n
end

-- LibDataBroker data sources -------------------------------------------------------------------

local dataNames = {}
local dataTicker

local function DataName(i)
    return PREFIX .. "Data" .. i
end

local function CreateDataSource(i)
    local name = DataName(i)
    local object = {
        type = "data source",
        label = format("Test data %d", i),
        text = "0",
        OnClick = OnClickPrint(name),
    }
    -- Every other one has no icon, as many text-only data sources.
    if i % 2 == 1 then
        object.icon = Icon(i + 3)
    end
    LDB:NewDataObject(name, object)
    dataNames[i] = name
end

-- Changes each shown data source's text every second, as clocks or gold counters do.
local function TickData()
    for i = 1, counts.data do
        local object = LDB:GetDataObjectByName(DataName(i))
        object.text = format("%d", (tonumber(object.text) or 0) + i)
    end
end

local function SetDataSources(n)
    for i = 1, math.max(n, counts.data) do
        local name = DataName(i)
        if i <= n then
            if not dataNames[i] then
                CreateDataSource(i)
            else
                ns.Broker.Collect(name, LDB:GetDataObjectByName(name))
            end
        elseif dataNames[i] then
            ns.Buttons.Remove("ldb:" .. name)
        end
    end
    counts.data = n
    if n > 0 and not dataTicker then
        dataTicker = C_Timer.NewTicker(1, TickData)
    elseif n == 0 and dataTicker then
        dataTicker:Cancel()
        dataTicker = nil
    end
end

-- Addon compartment ----------------------------------------------------------------------------

local compartmentEntries = {}

local function CreateCompartmentEntry(i)
    local name = PREFIX .. "Compartment" .. i
    return {
        text = format("Test compartment %d", i),
        icon = Icon(i + 1),
        notCheckable = true,
        registerForAnyClick = true,
        func = function(_, menuInputData)
            OnClickPrint(name)(nil, menuInputData and menuInputData.buttonName)
        end,
        funcOnEnter = function(button)
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:AddLine(name)
            GameTooltip:Show()
        end,
        funcOnLeave = GameTooltip_Hide,
    }
end

-- The compartment has no way to remove an entry, so this takes it out of its list, as LibDBIcon
-- does.
local function RemoveCompartmentEntry(entry)
    local registered = AddonCompartmentFrame.registeredAddons
    for index = #registered, 1, -1 do
        if registered[index] == entry then
            table.remove(registered, index)
        end
    end
end

local function SetCompartment(n)
    if not AddonCompartmentFrame then
        ns:Print("The addon compartment isn't available.")
        return
    end
    for i = 1, math.max(n, counts.compartment) do
        local isShown = i <= counts.compartment
        if i <= n and not isShown then
            compartmentEntries[i] = compartmentEntries[i] or CreateCompartmentEntry(i)
            AddonCompartmentFrame:RegisterAddon(compartmentEntries[i])
        elseif i > n and isShown then
            RemoveCompartmentEntry(compartmentEntries[i])
        end
    end
    AddonCompartmentFrame:UpdateDisplay()
    counts.compartment = n
end

-- Hand-made minimap buttons --------------------------------------------------------------------

-- One kind per button, in turn.
local HANDMADE_KINDS = {
    "plain",    -- on the minimap, like a LibDBIcon button
    "backdrop", -- parented to MinimapBackdrop instead of Minimap
    "stubborn", -- puts itself back every 2 seconds, as some addons do
    "unnamed",  -- no global name
}

local handmade = {}
local stubbornTicker

-- Built like a LibDBIcon button: tracking border, round background and icon.
local function CreateHandmadeButton(i)
    local kind = HANDMADE_KINDS[(i - 1) % #HANDMADE_KINDS + 1]
    local name = kind ~= "unnamed" and (PREFIX .. "MinimapButton" .. i) or nil
    local button = CreateFrame("Button", name, kind == "backdrop" and MinimapBackdrop or Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(Icon(i + 2))
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")

    local label = name or format("unnamed test button %d", i)
    button:SetScript("OnClick", OnClickPrint(label))
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(label)
        GameTooltip:AddLine(format("Kind: %s", kind), 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    button.kind = kind
    -- Placed on the minimap's edge, apart from the LibDBIcon test buttons.
    button.offsetX, button.offsetY = MinimapOffset(200 + i * 23, 1.08)
    return button
end

local function PlaceHandmade(button)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", button.offsetX, button.offsetY)
end

local function PlaceStubbornButtons()
    for i = 1, counts.buttons do
        if handmade[i].kind == "stubborn" then
            PlaceHandmade(handmade[i])
        end
    end
end

local function SetHandmadeButtons(n)
    for i = 1, math.max(n, counts.buttons) do
        if i <= n then
            handmade[i] = handmade[i] or CreateHandmadeButton(i)
            PlaceHandmade(handmade[i])
            handmade[i]:Show()
        elseif handmade[i] then
            handmade[i]:Hide()
            if handmade[i]:GetName() then
                ns.Buttons.Remove("frame:" .. handmade[i]:GetName())
            end
        end
    end
    counts.buttons = n
    if n > 0 and not stubbornTicker then
        stubbornTicker = C_Timer.NewTicker(2, PlaceStubbornButtons)
    elseif n == 0 and stubbornTicker then
        stubbornTicker:Cancel()
        stubbornTicker = nil
    end
end

-- Map pins -------------------------------------------------------------------------------------

local PIN_COLORS = {
    { 1, 0.82, 0 }, { 0.2, 1, 0.3 }, { 0.3, 0.7, 1 }, { 1, 0.3, 0.3 }, { 0.9, 0.5, 1 },
}

local pins = {}
local pinTicker

-- Most pins are small unnamed frames, as HereBeDragons creates them; every fifth one has a global
-- name (and is a bit bigger), to test that the minimap scan skips small named frames too.
local function CreatePin(i)
    local named = i % 5 == 0
    local pin = CreateFrame(named and "Button" or "Frame", named and (PREFIX .. "Pin" .. i) or nil, Minimap)
    pin:SetSize(named and 16 or 12, named and 16 or 12)
    local texture = pin:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    local color = PIN_COLORS[(i - 1) % #PIN_COLORS + 1]
    texture:SetColorTexture(color[1], color[2], color[3])
    local mask = pin:CreateMaskTexture()
    mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
    mask:SetAllPoints()
    texture:AddMaskTexture(mask)
    return pin
end

-- A random spot inside the minimap.
local function PlacePin(pin)
    local x, y = MinimapOffset(math.random() * 360, math.sqrt(math.random()) * 0.92)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Moves every shown pin, as pins move while the player walks; the heaviest case for the scan.
local function MovePins()
    for i = 1, counts.pins do
        PlacePin(pins[i])
    end
end

local function SetPins(n, moving)
    for i = 1, math.max(n, counts.pins) do
        if i <= n then
            pins[i] = pins[i] or CreatePin(i)
            PlacePin(pins[i])
            pins[i]:Show()
        elseif pins[i] then
            pins[i]:Hide()
        end
    end
    counts.pins = n
    if pinTicker then
        pinTicker:Cancel()
        pinTicker = nil
    end
    if moving and n > 0 then
        pinTicker = C_Timer.NewTicker(0.1, MovePins)
    end
end

-- Commands -------------------------------------------------------------------------------------

local SETTERS = {
    launchers = SetLaunchers,
    data = SetDataSources,
    compartment = SetCompartment,
    buttons = SetHandmadeButtons,
    pins = SetPins,
}
local ORDER = { "launchers", "data", "compartment", "buttons", "pins" }

local function PrintStatus()
    local parts = {}
    for _, kind in ipairs(ORDER) do
        parts[#parts + 1] = format("%s %d", kind, counts[kind])
    end
    ns:Print("Test: " .. table.concat(parts, ", ") .. (pinTicker and " (pins moving)" or ""))
end

local function PrintHelp()
    ns:Print("Test commands:")
    print("  /satellite test all - one of each kind and 1000 pins")
    print("  /satellite test launchers [n] - LibDataBroker launchers (default 6)")
    print("  /satellite test data [n] - LibDataBroker data sources (default 3)")
    print("  /satellite test compartment [n] - addon compartment entries (default 3)")
    print("  /satellite test buttons [n] - hand-made minimap buttons (default 4)")
    print("  /satellite test pins [n] [moving] - map pins on the minimap (default 1000)")
    print("  /satellite test clear - remove everything")
    PrintStatus()
end

-- msg: the text after "/satellite test".
function Test.Command(msg)
    local kind, number, option = strsplit(" ", strtrim(msg or ""):lower())
    if kind == "all" then
        for _, name in ipairs(ORDER) do
            SETTERS[name](DEFAULT_COUNTS[name])
        end
    elseif kind == "clear" then
        for _, name in ipairs(ORDER) do
            SETTERS[name](0)
        end
    elseif SETTERS[kind] then
        local n = tonumber(number) or DEFAULT_COUNTS[kind]
        SETTERS[kind](math.max(0, math.floor(n)), option == "moving" or number == "moving")
    else
        PrintHelp()
        return
    end
    PrintStatus()
end
