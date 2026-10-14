local addonName, ns = ...

-- Finds minimap buttons that addons make by hand, without LibDataBroker: frames on the minimap
-- that look like a button (Handmade brings them into the menu). The minimap also holds
-- Blizzard's own frames and, with addons like TomTom, HandyNotes or GatherMate, hundreds of map
-- pins; the checks below keep those out, and frames that can never be a button are skipped at
-- once next time. It runs a few times after login and after an addon loads later on (see Setup),
-- and when asked (/satellite list and /satellite scan).
local Scan = {}
ns.Scan = Scan

local LibDBIcon = LibStub("LibDBIcon-1.0")

-- Buttons are about 31 pixels square; map pins are smaller.
local MIN_SIZE, MAX_SIZE = 24, 48
-- Width and height may differ this much (as a ratio) and still be a button.
local MAX_ASPECT = 1.35
-- Satellite's own test buttons (see Debug/Test.lua) are found like any addon's.
local TEST_PATTERN = "^SatelliteTest"

-- Frames that are never a button, so later scans skip them at once: [frame] = reason. Frames
-- that may still turn into one (too small or hidden for now) are checked again each time.
local rejected = setmetatable({}, { __mode = "k" })

-- HereBeDragons keeps the pins of every addon that uses it (TomTom, HandyNotes, GatherMate...).
local function IsMapPin(frame)
    local HBDPins = LibStub("HereBeDragons-Pins-2.0", true)
    return HBDPins ~= nil and type(HBDPins.minimapPins) == "table" and HBDPins.minimapPins[frame] ~= nil
end

local function IsLibDBIconButton(frame)
    for _, button in pairs(LibDBIcon.objects) do
        if button == frame then
            return true
        end
    end
    return false
end

-- Why frame can never be a hand-made button, or nil. Its global name tells who made it: names
-- that Blizzard set are secure; others name the addon that set them.
local function GetPermanentReason(frame, name)
    if not name then
        return "unnamed"
    end
    local isSecure, addon = issecurevariable(name)
    if isSecure then
        return "blizzard"
    end
    if addon == addonName and not name:find(TEST_PATTERN) then
        return "satellite"
    end
    if IsMapPin(frame) then
        return "pin"
    end
    if IsLibDBIconButton(frame) then
        return "libdbicon"
    end
    if frame:IsProtected() then
        return "protected"
    end
    return nil
end

-- Whether frame looks like a button right now: shown, button-sized and clickable.
local function LooksLikeButton(frame)
    if not frame:IsShown() or not frame:IsMouseEnabled() then
        return false
    end
    local width, height = frame:GetSize()
    if width < MIN_SIZE or height < MIN_SIZE or width > MAX_SIZE or height > MAX_SIZE then
        return false
    end
    return math.max(width, height) / math.min(width, height) <= MAX_ASPECT
end

-- The addon's title (without colours) for its button's label, or the frame's name.
local function GetLabel(name, addon)
    if addon then
        local _, title = C_AddOns.GetAddOnInfo(addon)
        if title then
            return strtrim(C_StringUtil.StripHyperlinks(title))
        end
    end
    return name
end

local stats = { checked = 0, skipped = 0, found = 0, milliseconds = 0 }

local function GetChildren(parent)
    return { parent:GetChildren() }
end

local function ScanChildren(parent)
    -- A minimap with thousands of pins has more children than fit in one table constructor.
    local ok, children = pcall(GetChildren, parent)
    if not ok then
        ns:Debug("Too many frames on", parent:GetName(), "to scan:", parent:GetNumChildren())
        return
    end
    for _, frame in ipairs(children) do
        if rejected[frame] then
            stats.skipped = stats.skipped + 1
        else
            stats.checked = stats.checked + 1
            local name = frame:GetName()
            local reason = GetPermanentReason(frame, name)
            if reason then
                rejected[frame] = reason
            elseif LooksLikeButton(frame) then
                local key = "frame:" .. name
                if not ns.Buttons.Get(key) then
                    -- The addon that made it (it set the frame's global name).
                    local _, addon = issecurevariable(name)
                    if addon == addonName then
                        addon = nil
                    end
                    local button = {
                        key = key,
                        source = "frame",
                        name = name,
                        label = GetLabel(name, addon),
                        addon = addon,
                        frame = frame,
                    }
                    ns.Handmade.Watch(button)
                    ns.Buttons.Add(button)
                end
                stats.found = stats.found + 1
            end
        end
    end
end

-- Checks the minimap's frames for buttons. Returns what it did (see stats).
function Scan.Run()
    stats.checked, stats.skipped, stats.found = 0, 0, 0
    local start = debugprofilestop()
    ScanChildren(Minimap)
    if MinimapBackdrop then
        ScanChildren(MinimapBackdrop)
    end
    stats.milliseconds = debugprofilestop() - start
    if ns.db.debug then
        ns:Debug(format("Scan: %d checked, %d skipped, %d buttons, %.2f ms",
            stats.checked, stats.skipped, stats.found, stats.milliseconds))
    end
    return stats
end

-- Debug command: scans now and prints how long it took.
function Scan.PrintRun()
    local result = Scan.Run()
    ns:Print(format("Scan: %d checked, %d skipped (known), %d buttons, %.2f ms",
        result.checked, result.skipped, result.found, result.milliseconds))
end

-- Addons make their buttons as they load, some only once the player is in the world: the minimap
-- is looked at this many seconds after login, and this long after an addon loads later on.
local LOGIN_SCANS = { 1, 4, 12 }
local LOAD_DELAY = 2
local isScanPending = false

local function RequestScan()
    if isScanPending then
        return
    end
    isScanPending = true
    C_Timer.After(LOAD_DELAY, function()
        isScanPending = false
        Scan.Run()
    end)
end

-- Called once ns.db is loaded.
function Scan:Setup()
    ns:RegisterEvent("PLAYER_LOGIN", function()
        for _, delay in ipairs(LOGIN_SCANS) do
            C_Timer.After(delay, Scan.Run)
        end
        ns:RegisterEvent("ADDON_LOADED", RequestScan)
    end)
end
