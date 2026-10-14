local addonName, ns = ...

-- Collects the entries of Blizzard's addon compartment (the menu under the minimap's addon
-- count). Addons get an entry with ## AddonCompartmentFunc in their TOC, which Blizzard adds when
-- the player enters the world, or by calling AddonCompartmentFrame:RegisterAddon. Entries are
-- plain tables (text, icon, func, funcOnEnter, funcOnLeave); see Blizzard_Minimap's
-- AddonCompartment.lua.
local Compartment = {}
ns.Compartment = Compartment

local LDB = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

-- Keys of the entries collected the last time, to remove the ones that are gone.
local collected = {}

-- The compartment shows each addon's title, which may have colours or icons in it; the label
-- doesn't.
local function PlainText(text)
    return strtrim(C_StringUtil.StripHyperlinks(text or ""))
end

-- TOC entries are known only by their text, the addon's title: [title] = the addon's folder name.
-- TOC files don't change while the game runs, so this is read once.
local tocAddons
local function GetTocAddons()
    if not tocAddons then
        tocAddons = {}
        for index = 1, C_AddOns.GetNumAddOns() do
            if C_AddOns.GetAddOnMetadata(index, "AddonCompartmentFunc") then
                local name, title = C_AddOns.GetAddOnInfo(index)
                tocAddons[title] = name
            end
        end
    end
    return tocAddons
end

-- LibDBIcon adds an entry for buttons whose addon asks for it (showInCompartment). Those are
-- already collected from LibDataBroker: [entry] = true.
local function GetLibDBIconEntries()
    local entries = {}
    for _, button in pairs(LibDBIcon.objects) do
        if button.compartmentData then
            entries[button.compartmentData] = true
        end
    end
    return entries
end

-- A name to compare: lower case, letters and digits only ("Foo Bar" and "FooBar" are the same).
local function Simplify(text)
    return (PlainText(text):lower():gsub("[^%w]", ""))
end

-- The addon folder an icon is in (Interface\AddOns\<folder>\...), simplified, or nil: the icon
-- tells which addon it belongs to.
local function GetIconFolder(icon)
    local folder = type(icon) == "string" and icon:match("[Aa][Dd][Dd][Oo][Nn][Ss][\\/]([^\\/]+)")
    return folder and Simplify(folder)
end

-- What tells the LibDataBroker objects' addons apart, simplified: their names and labels, and the
-- folders of their icons: [text] = true. Many addons have both an object and a compartment entry
-- (e.g. Rematch); the object's button is kept, as it has a tooltip, and the entry is left out.
local function GetBrokerNames()
    local names = {}
    for name, dataObject in LDB:DataObjectIterator() do
        names[Simplify(name)] = true
        if type(dataObject.label) == "string" then
            names[Simplify(dataObject.label)] = true
        end
        local folder = GetIconFolder(dataObject.icon)
        if folder then
            names[folder] = true
        end
    end
    names[""] = nil
    return names
end

-- Brings Satellite's buttons in line with the compartment's entries. Runs after every change:
-- RegisterAddon and Blizzard's own TOC entries end with UpdateDisplay, and so does removing an
-- entry (as LibDBIcon does it).
local function Sync()
    local tocAddons = GetTocAddons()
    local libDBIconEntries = GetLibDBIconEntries()
    local brokerNames = GetBrokerNames()
    local seen = {}
    for _, entry in ipairs(AddonCompartmentFrame.registeredAddons) do
        local tocAddon = tocAddons[entry.text]
        local label = PlainText(entry.text)
        -- The same addon if its title, its folder or its icon's folder matches an object's.
        local inBroker = brokerNames[Simplify(label)]
            or (tocAddon and brokerNames[Simplify(tocAddon)])
            or brokerNames[GetIconFolder(entry.icon) or ""]
        if not libDBIconEntries[entry] and not inBroker and tocAddon ~= addonName then
            local key = "comp:" .. (tocAddon or label)
            -- Two entries with the same text keep apart.
            local base, number = key, 1
            while seen[key] do
                number = number + 1
                key = base .. "#" .. number
            end
            seen[key] = true
            ns.Buttons.Add({
                key = key,
                source = "comp",
                name = tocAddon or label,
                label = label ~= "" and label or key,
                entry = entry,
            })
        end
    end
    for key in pairs(collected) do
        if not seen[key] then
            ns.Buttons.Remove(key)
        end
    end
    collected = seen
end

local isReady = false
local isSyncPending = false

-- Syncs once at the end of the frame, however many changes came in it (at login, one per addon).
local function RequestSync()
    if isSyncPending then
        return
    end
    isSyncPending = true
    C_Timer.After(0, function()
        isSyncPending = false
        Sync()
    end)
end

-- Checks the entries again, e.g. after a new LibDataBroker object (see Broker), which may now
-- replace an entry.
function Compartment.Refresh()
    if isReady then
        RequestSync()
    end
end

-- Called once ns.db is loaded. The compartment comes with Blizzard_Minimap.
function Compartment:Setup()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Minimap", function()
        if not AddonCompartmentFrame then
            return
        end
        isReady = true
        hooksecurefunc(AddonCompartmentFrame, "UpdateDisplay", RequestSync)
        Sync()
    end)
end
