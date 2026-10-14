local addonName, ns = ...

-- Finds minimap buttons that addons make by hand, without LibDataBroker: frames on the minimap
-- that look like a button. The minimap also holds Blizzard's own frames and, with addons like
-- TomTom, HandyNotes or GatherMate, hundreds of map pins; the checks below keep those out. A
-- frame is only listed here; nothing is moved yet.
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
local function GetLabel(name)
    local _, addon = issecurevariable(name)
    if addon and addon ~= addonName then
        local _, title = C_AddOns.GetAddOnInfo(addon)
        if title then
            return strtrim(C_StringUtil.StripHyperlinks(title)), addon
        end
    end
    return name, addon
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
                    local label, addon = GetLabel(name)
                    ns.Buttons.Add({
                        key = key,
                        source = "frame",
                        name = name,
                        label = label,
                        addon = addon,
                        frame = frame,
                    })
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

-- How many frames the minimap had at the last scan; a new scan only runs when that changes.
local lastChildCount = -1

local function ScanIfChanged()
    local count = Minimap:GetNumChildren() + (MinimapBackdrop and MinimapBackdrop:GetNumChildren() or 0)
    if count ~= lastChildCount then
        lastChildCount = count
        Scan.Run()
    end
end

-- How often to look for new frames: addons that load later, or make their button late.
local CHECK_INTERVAL = 5

-- Called once ns.db is loaded. The first scan waits until every addon has had time to make its
-- button after login.
function Scan:Setup()
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", function(isInitialLogin, isReloadingUi)
        if isInitialLogin or isReloadingUi then
            C_Timer.After(2, function()
                ScanIfChanged()
                C_Timer.NewTicker(CHECK_INTERVAL, ScanIfChanged)
            end)
        end
    end)
end

-- Debug command: scans now and prints how long it took.
function Scan.PrintRun()
    local result = Scan.Run()
    ns:Print(format("Scan: %d checked, %d skipped (known), %d buttons, %.2f ms",
        result.checked, result.skipped, result.found, result.milliseconds))
end
