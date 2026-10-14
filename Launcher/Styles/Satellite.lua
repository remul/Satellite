local _, ns = ...

-- The minimap button style (the default): a round button on the minimap's ring, where Blizzard
-- puts its own buttons (like the expansion button), with a stack of coloured discs and a gold
-- chevron (see StackButton). Click it and the menu slides out beside it, away from the minimap;
-- drag it around the ring (when unlocked, or with Shift).
local Theme = ns.Theme
local Style = { isMovable = true }
ns.Styles.satellite = Style

local SIZE = 40
-- The default place, in degrees round from east (counterclockwise): the ring's top left, clear
-- of Blizzard's buttons. Its center sits this far from the minimap's center, as a share of the
-- minimap's half width: on the ring.
local DEFAULT_DEGREES = 140
local RING_SHARE = 1.02
-- Space between the chevron and the menu.
local MENU_GAP = 4

-- frame holds the menu; button is over it.
local frame, button, opener

local function GetSize()
    return SIZE * ns.Launcher.GetScale()
end

local function Create()
    -- On the minimap, so it moves, scales and hides with it.
    frame = CreateFrame("Frame", "SatelliteLauncher_satellite", Minimap)
    frame:SetSize(1, 1)
    frame:SetPoint("CENTER", Minimap, "CENTER")
    button = CreateFrame("Button", nil, frame)
    local _, ring = Theme.AddRoundBox(button)
    opener = ns.StackButton.Create(button, nil, function(isLit)
        local color, hoverColor = Theme.GetAccentColors()
        ring:SetVertexColor((isLit and hoverColor or color):GetRGBA())
    end)
    ns.Launcher.SetupOpener(button)
end

function Style:Show()
    if not frame then
        Create()
    end
    frame:Show()
end

function Style:Hide()
    if frame then
        frame:Hide()
    end
end

local function GetDegrees()
    local position = ns.Launcher.GetPosition("satellite")
    return position and position.degrees or DEFAULT_DEGREES
end

-- Over the expansion button's strata and level, so it's never hidden behind Blizzard's buttons;
-- the menu just below it.
local function UpdateFrameLevels()
    local strata, level = ns.Blizzard.GetMinimapLayer()
    if strata then
        frame:SetFrameStrata(strata)
        frame:SetFrameLevel(level + 1)
    end
    ns.Menu.SetFrameLevel(frame:GetFrameLevel() + 1)
    button:SetFrameLevel(frame:GetFrameLevel() + 6)
end

-- The menu opens away from the minimap, unless there's no room for it on that side of the screen.
local function GetMenuDirection()
    local outward = math.cos(math.rad(GetDegrees())) <= 0 and "LEFT" or "RIGHT"
    local x = button:GetCenter()
    if not x then
        return outward
    end
    local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
    x = x * scale
    local need = opener:GetMenuReach() + MENU_GAP + ns.Menu.GetSize()
    if outward == "LEFT" and x - need < 0 then
        return "RIGHT"
    elseif outward == "RIGHT" and x + need > UIParent:GetWidth() then
        return "LEFT"
    end
    return outward
end

function Style:Refresh()
    local radians = math.rad(GetDegrees())
    local distance = Minimap:GetWidth() / 2 * RING_SHARE
    local size = GetSize()
    button:SetSize(size, size)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * distance, math.sin(radians) * distance)
    UpdateFrameLevels()
    local direction = GetMenuDirection()
    opener:Layout(direction, "cluster", size)
    local reach = opener:GetMenuReach() + MENU_GAP
    ns.Menu.Place(frame, button, "CENTER", direction == "LEFT" and -reach or reach, 0, direction)
end

function Style:OnProgress(progress)
    opener:SetProgress(progress)
end

function Style:SetHovered(isHovered)
    opener:SetHovered(isHovered)
end


-- While dragged, it goes round the ring after the cursor.
local function FollowCursor()
    local scale = Minimap:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    local degrees = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
    ns.db.positions.satellite = { degrees = degrees }
    Style:Refresh()
end

function Style:OnDragStart()
    Style.isDragging = true
    button:SetScript("OnUpdate", FollowCursor)
end

function Style:OnDragStop()
    Style.isDragging = false
    button:SetScript("OnUpdate", nil)
end
