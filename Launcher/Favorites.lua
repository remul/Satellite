local _, ns = ...

-- Favorites: up to four buttons the player picks (a star in the Buttons list, see Settings) that
-- show beside the launcher, out of the menu, for quick access, like satellites around it. Each
-- style says where they go (Style:PlaceFavorites, below): along the minimap's ring above and below
-- the minimap button or the compass arrow, in an arc round the circle and square (in an orbit
-- round them while docked), in a row along the side bar. The Always open style has no launcher to
-- put them beside: there they're first in the menu.
--
-- Shown always, or only while the launcher is hovered or the menu is open (ns.db.showFavorites):
-- then they fly out from the launcher, and back a moment after the mouse left.
--
-- What a style has for them:
--   PlaceFavorites(points, count, size, gap)
--       fills points with count places { x1, y1, x2, y2, ... } (the favorites' middles, from the
--       middle of a frame), and returns that frame, the place they fly out from (x, y, from the
--       same middle), and the frame whose layer they take (the launcher's button)
local Favorites = {}
ns.Favorites = Favorites

-- A favorite's size at the launcher's normal size, and the space between them and the launcher.
local SIZE = 30
local GAP = 4
-- Shown on hover: how long they take to fly out and back, and how long after the mouse left the
-- launcher and them they go.
local REVEAL_TIME, HIDE_TIME = 0.2, 0.15
local LEAVE_DELAY = 0.6
-- Space between a favorite and the screen's edge, in a row along it.
local EDGE_MARGIN = 2

local holder, animator
-- The buttons shown beside the launcher, in order, and [key] = true for them; and the menu's
-- buttons (see Update).
local outside, isOutside = {}, {}
local menuButtons = {}
-- The places the style gave them, the frame they're from, and the place they fly out from.
local points = {}
local relativeTo
local originX, originY = 0, 0
-- 0 = in the launcher, 1 = out; animated in between on hover.
local reveal = 1
local isLauncherHovered = false
local awayTime = 0

function Favorites.GetSize()
    return SIZE * ns.Launcher.GetScale()
end

function Favorites.GetGap()
    return GAP * ns.Launcher.GetScale()
end

-- Whether favorites show beside the launcher: not when the player wants them in the menu, nor for
-- a style without a launcher.
function Favorites.IsActive()
    return ns.db.showFavorites ~= "menu" and ns.Launcher.GetStyle().PlaceFavorites ~= nil
end

-- Whether the button with key shows beside the launcher (as of the last Update).
function Favorites.IsShownOutside(key)
    return isOutside[key] == true
end

-- How many show beside the launcher (as of the last Update).
function Favorites.GetCount()
    return #outside
end

-- Works out which buttons show beside the launcher, and which in the menu: without the ones
-- beside the launcher; with favorites first, where they have no other place (the Always open
-- style). Called before the style and the menu are placed (see Launcher.Refresh), which make room
-- for them; the lists are kept until the next time.
function Favorites.Update()
    wipe(outside)
    wipe(isOutside)
    wipe(menuButtons)
    local buttons = ns.Buttons.GetLauncherButtons()
    local favorites = ns.db.showFavorites ~= "menu" and ns.Buttons.GetFavorites(buttons)
    if favorites and Favorites.IsActive() then
        for index, button in ipairs(favorites) do
            outside[index] = button
            isOutside[button.key] = true
        end
    elseif favorites then
        for _, button in ipairs(favorites) do
            menuButtons[#menuButtons + 1] = button
            isOutside[button.key] = true
        end
    end
    for _, button in ipairs(buttons) do
        if not isOutside[button.key] then
            menuButtons[#menuButtons + 1] = button
        end
    end
    -- Only the ones beside the launcher count from here on.
    if #outside == 0 then
        wipe(isOutside)
    end
end

-- The buttons the menu shows, in order (as of the last Update; the list is shared, callers don't
-- change it).
function Favorites.GetMenuButtons()
    return menuButtons
end

-- Places -----------------------------------------------------------------------------------------
-- Shared by the styles.

-- How many degrees apart two places on the minimap's ring are, distance apart (their middles), at
-- share of the minimap's half size from its middle.
function Favorites.GetRingStep(distance, share)
    local radius = Minimap:GetWidth() / 2 * share
    return math.deg(2 * math.asin(math.min(1, distance / (2 * radius))))
end

-- Free on the screen, the circle and square have their favorites in an arc round their middle:
-- on the side away from the menu, slid round as far as it takes to stay on the screen and clear
-- of the open menu (near the screen's edge, round the launcher's other sides). Where the arc
-- doesn't fit, on a wider orbit; and where that doesn't either, in a row along the nearest edge.
local MAX_ORBITS = 3
-- [degree + 1] = whether a favorite fits there on the orbit being tried (reused); and each whole
-- degree's cosine and sine, worked out once.
local isFree = {}
local COS, SIN = {}, {}
for degree = 0, 359 do
    COS[degree + 1], SIN[degree + 1] = math.cos(math.rad(degree)), math.sin(math.rad(degree))
end

local function FillArc(target, count, radius, step, first)
    for index = 1, count do
        local radians = math.rad(first + (index - 1) * step)
        target[2 * index - 1], target[2 * index] = radius * math.cos(radians), radius * math.sin(radians)
    end
end

-- The longest run of free degrees round the orbit: its first degree and its length (360 when all
-- of it is free).
local function FindLongestRun()
    local bestStart, bestLength = 0, 0
    -- Starting only where a run starts (the degree before isn't free), going round once.
    for start = 0, 359 do
        if isFree[start + 1] and not isFree[(start - 1) % 360 + 1] then
            local length = 0
            while length < 360 and isFree[(start + length) % 360 + 1] do
                length = length + 1
            end
            if length > bestLength then
                bestStart, bestLength = start, length
            end
        end
    end
    if bestLength == 0 and isFree[1] then
        return 0, 360
    end
    return bestStart, bestLength
end

function Favorites.PlaceInArc(target, count, size, gap, frame, radius, degrees)
    local centerX, centerY = frame:GetCenter()
    if not centerX then
        return
    end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    centerX, centerY = centerX * scale, centerY * scale
    local half = size / 2
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    -- The open menu, with a gap round it.
    local menuLeft, menuBottom, menuWidth, menuHeight = ns.Menu.GetOpenRect()
    for orbit = 0, MAX_ORBITS - 1 do
        local orbitRadius = radius + orbit * (size + gap)
        local step = math.deg(2 * math.asin(math.min(1, (size + gap) / (2 * orbitRadius))))
        local span = (count - 1) * step
        for degree = 1, 360 do
            local x = centerX + orbitRadius * COS[degree]
            local y = centerY + orbitRadius * SIN[degree]
            local free = x - half >= 0 and x + half <= width and y - half >= 0 and y + half <= height
            if free and menuLeft then
                free = x + half + gap <= menuLeft or x - half - gap >= menuLeft + menuWidth
                    or y + half + gap <= menuBottom or y - half - gap >= menuBottom + menuHeight
            end
            isFree[degree] = free
        end
        local runStart, runLength = FindLongestRun()
        -- The run's degrees are runStart to runStart + runLength - 1; the arc fits when it spans
        -- no more.
        if runLength == 360 then
            FillArc(target, count, orbitRadius, step, degrees - span / 2)
            return
        elseif runLength - 1 >= span then
            -- Centred on degrees (taken round to the run's side), or as near as the run allows.
            local middle = runStart + (runLength - 1) / 2
            local wanted = degrees - span / 2
            wanted = wanted + 360 * math.floor((middle - wanted - span / 2) / 360 + 0.5)
            local first = math.max(runStart, math.min(runStart + runLength - 1 - span, wanted))
            FillArc(target, count, orbitRadius, step, first)
            return
        end
    end
    local edge = ns.Launcher.GetNearestEdge(centerX, centerY)
    local frameWidth, frameHeight = frame:GetSize()
    Favorites.PlaceAlongEdge(target, count, size, gap, edge, frame,
        (edge == "LEFT" or edge == "RIGHT") and frameHeight or frameWidth)
end

-- For each edge of the screen: one step in from it.
local INWARD = {
    LEFT = { x = 1, y = 0 }, RIGHT = { x = -1, y = 0 }, BOTTOM = { x = 0, y = 1 }, TOP = { x = 0, y = -1 },
}

-- The open menu, seen from edge (see Menu.GetOpenRect): how far its near side is from the edge,
-- and where it starts and ends along the edge, from along (the frame's middle). nil without one.
local function GetMenuSpan(edge, along)
    local left, bottom, width, height = ns.Menu.GetOpenRect()
    if not left then
        return nil
    end
    local near
    if edge == "LEFT" then
        near = left
    elseif edge == "RIGHT" then
        near = UIParent:GetWidth() - left - width
    elseif edge == "BOTTOM" then
        near = bottom
    else
        near = UIParent:GetHeight() - bottom - height
    end
    if edge == "LEFT" or edge == "RIGHT" then
        return near, bottom - along, bottom + height - along
    end
    return near, left - along, left + width - along
end

-- A row of count places along edge, against it, on both sides of frame (length long along the
-- edge): one side and then the other, outward; all on one side where the other has no room (in
-- a corner). Where the open menu comes so close to the edge that they'd be under it (the side
-- bar's), they start past its ends.
function Favorites.PlaceAlongEdge(target, count, size, gap, edge, frame, length)
    local centerX, centerY = frame:GetCenter()
    if not centerX then
        return
    end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    centerX, centerY = centerX * scale, centerY * scale
    local isVertical = edge == "LEFT" or edge == "RIGHT"
    local along = isVertical and centerY or centerX
    local screenLength = isVertical and UIParent:GetHeight() or UIParent:GetWidth()
    local cell = size + gap
    -- Each side's first place (up or right, down or left), from the frame's middle.
    local firstUp = length / 2 + gap + size / 2
    local firstDown = firstUp
    local menuNear, menuLow, menuHigh = GetMenuSpan(edge, along)
    -- (Half a pixel of leeway: the side bar's menu opens just clear, see GetRowDepth.)
    if menuNear and menuNear - gap < size + EDGE_MARGIN - 0.5 then
        firstUp = math.max(firstUp, menuHigh + gap + size / 2)
        firstDown = math.max(firstDown, -menuLow + gap + size / 2)
    end
    -- How many fit on each side, on the screen, and how many are there.
    local roomUp = math.floor((screenLength - along - firstUp - size / 2) / cell) + 1
    local roomDown = math.floor((along - firstDown - size / 2) / cell) + 1
    local usedUp, usedDown = 0, 0
    local inward = INWARD[edge]
    -- Across the edge: the places' middles this far in from it.
    local across = size / 2 + EDGE_MARGIN - ns.Launcher.GetEdgeDistance(edge, centerX, centerY)
    for index = 1, count do
        -- One side and then the other; the other where one is full.
        local isUp = index % 2 == 1
        if isUp and usedUp >= roomUp and usedDown < roomDown then
            isUp = false
        elseif not isUp and usedDown >= roomDown and usedUp < roomUp then
            isUp = true
        end
        local offset
        if isUp then
            usedUp = usedUp + 1
            offset = firstUp + (usedUp - 1) * cell
        else
            usedDown = usedDown + 1
            offset = -(firstDown + (usedDown - 1) * cell)
        end
        local x = isVertical and inward.x * across or offset
        local y = isVertical and offset or inward.y * across
        target[2 * index - 1], target[2 * index] = x, y
    end
end

-- Docked on an edge, the circle and square have their favorites in an orbit round their shape's
-- middle (on the edge, or past it): two on each side, one against the edge and one further in,
-- closer to the button. With one or two, only those against the edge, out of the menu's way; with
-- more, the menu opens past the orbit (see GetDockedOrbitReach). The orbit's radius, and the
-- angles (radians, from the edge) of the places against the edge and further in. The orbit is
-- this share of a favorite's size further out than touching the shape: room for the two further
-- in to stay either side of the chevron between them.
local ORBIT_SPACE_SHARE = 0.25

local function GetDockedOrbit(size, gap, shapeRadius)
    local radius = shapeRadius + gap + size / 2 + size * ORBIT_SPACE_SHARE
    local outer = math.asin(math.min(1, (size / 2 + EDGE_MARGIN) / radius))
    local inner = outer + 2 * math.asin(math.min(1, (size + gap) / (2 * radius)))
    return radius, outer, inner
end

-- The places in the orbit, in order along the edge: { side, inner } (side 1: up or right).
local ORBIT_SLOTS = {
    [1] = { { 1, false } },
    [2] = { { -1, false }, { 1, false } },
    [3] = { { -1, false }, { 1, true }, { 1, false } },
    [4] = { { -1, false }, { -1, true }, { 1, true }, { 1, false } },
}

-- The shape's middle in UIParent's units, and its place along edge.
local function GetShapeMiddle(shape, edge)
    local x, y = shape:GetCenter()
    if not x then
        return nil
    end
    local scale = shape:GetEffectiveScale() / UIParent:GetEffectiveScale()
    x, y = x * scale, y * scale
    return x, y, (edge == "LEFT" or edge == "RIGHT") and y or x
end

-- Whether the orbit fits on the screen on both sides of shape (not in a corner).
function Favorites.CanOrbitDocked(count, size, gap, edge, shape, shapeRadius)
    if not ORBIT_SLOTS[count] then
        return false
    end
    local _, _, along = GetShapeMiddle(shape, edge)
    if not along then
        return false
    end
    local radius, outer = GetDockedOrbit(size, gap, shapeRadius)
    local reach = radius * math.cos(outer) + size / 2
    local screenLength = (edge == "LEFT" or edge == "RIGHT") and UIParent:GetHeight() or UIParent:GetWidth()
    return along - reach >= 0 and along + reach <= screenLength
end

-- How far in from the shape's middle the orbit reaches (the far side of the places further in),
-- for the menu to open past it; 0 with only the places against the edge.
function Favorites.GetDockedOrbitReach(count, size, gap, shapeRadius)
    if count <= 2 then
        return 0
    end
    local radius, _, inner = GetDockedOrbit(size, gap, shapeRadius)
    return radius * math.sin(inner) + size / 2
end

-- The orbit's places (see CanOrbitDocked first), from frame's middle.
function Favorites.PlaceInDockedOrbit(target, count, size, gap, edge, frame, shape, shapeRadius)
    local shapeX, shapeY = GetShapeMiddle(shape, edge)
    local frameX, frameY = frame:GetCenter()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local offsetX, offsetY = shapeX - frameX * scale, shapeY - frameY * scale
    local isVertical = edge == "LEFT" or edge == "RIGHT"
    local inward = INWARD[edge]
    local radius, outer, inner = GetDockedOrbit(size, gap, shapeRadius)
    for index, slot in ipairs(ORBIT_SLOTS[count]) do
        local angle = slot[2] and inner or outer
        local along, across = slot[1] * radius * math.cos(angle), radius * math.sin(angle)
        target[2 * index - 1] = offsetX + (isVertical and inward.x * across or along)
        target[2 * index] = offsetY + (isVertical and along or inward.y * across)
    end
end

-- How long a row along an edge has to be for count favorites on both sides of something length
-- long (see PlaceAlongEdge).
function Favorites.GetRowLength(count, length)
    return length + 2 * math.ceil(count / 2) * (Favorites.GetSize() + Favorites.GetGap())
end

-- How far in from the screen's edge a row along it reaches (see PlaceAlongEdge), and a gap past
-- that: for a menu to open clear of it.
function Favorites.GetRowDepth()
    return Favorites.GetSize() + EDGE_MARGIN + Favorites.GetGap()
end

-- Drawing ----------------------------------------------------------------------------------------

local function EaseOut(x)
    return 1 - (1 - x) ^ 3
end

-- Puts each favorite at its place, as far out as they've flown.
local function Draw()
    local out = EaseOut(reveal)
    for index, button in ipairs(outside) do
        local frame = ns.LauncherButton.GetFrame(button.key)
        local x, y = points[2 * index - 1] or 0, points[2 * index] or 0
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", relativeTo, "CENTER", originX + (x - originX) * out,
            originY + (y - originY) * out)
    end
    holder:SetAlpha(reveal)
    holder:SetShown(reveal > 0)
end

-- Asks the style for the places, and moves the favorites there.
local function Place()
    if #outside == 0 or not holder then
        return
    end
    local style = ns.Launcher.GetStyle()
    local frame
    relativeTo, originX, originY, frame = style:PlaceFavorites(points, #outside, Favorites.GetSize(),
        Favorites.GetGap())
    if holder:GetParent() ~= relativeTo then
        holder:SetParent(relativeTo)
    end
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel(frame:GetFrameLevel())
    Draw()
end

function Favorites.IsMouseOver()
    if not holder or not holder:IsVisible() then
        return false
    end
    for _, button in ipairs(outside) do
        local frame = ns.LauncherButton.GetFrame(button.key)
        if frame and frame:IsMouseOver() then
            return true
        end
    end
    return false
end

-- Whether they're out now: not while the launcher is dragged; otherwise always, or on hover while
-- the launcher or they are hovered, or the menu or the settings are open.
local function ShouldShow()
    if ns.Launcher.GetStyle().isDragging then
        return false
    elseif ns.db.showFavorites ~= "hover" then
        return true
    end
    return isLauncherHovered or ns.Menu.IsOpen() or ns.Settings.IsShown() or Favorites.IsMouseOver()
end

-- Hidden while the launcher is dragged (they'd jump round it as it moves); once it's let go, they
-- fly out where it is (see Refresh).
local isHiddenForDrag = false

function Favorites.HideForDrag()
    if not holder then
        return
    end
    isHiddenForDrag = true
    reveal = 0
    holder:Hide()
    animator:Hide()
end

-- Runs while they fly, and while they're out on hover (to see the mouse leave).
local function OnUpdate(self, elapsed)
    local target = ShouldShow() and 1 or 0
    if target == 0 and reveal > 0 then
        awayTime = awayTime + elapsed
        if awayTime < LEAVE_DELAY then
            return
        end
    else
        awayTime = 0
    end
    if reveal ~= target then
        local step = elapsed / (target > reveal and REVEAL_TIME or HIDE_TIME)
        reveal = target > reveal and math.min(target, reveal + step) or math.max(target, reveal - step)
        Draw()
    end
    if reveal == target and (target == 0 or ns.db.showFavorites ~= "hover") then
        self:Hide()
    end
end

-- Looks again whether they should be out (the launcher was hovered, the menu opened...).
function Favorites.Wake()
    if animator and #outside > 0 then
        animator:Show()
    end
end

-- Called as the mouse comes onto the launcher and leaves it (see Launcher.SetupOpener).
function Favorites.SetLauncherHovered(isHovered)
    isLauncherHovered = isHovered
    Favorites.Wake()
end

-- Draws the favorites beside the launcher, after the style placed it (see Launcher.Refresh).
function Favorites.Refresh()
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(1, 1)
        animator = CreateFrame("Frame")
        animator:Hide()
        animator:SetScript("OnUpdate", OnUpdate)
    end
    ns.LauncherButton.HideOthers(isOutside, holder)
    if #outside == 0 then
        holder:Hide()
        animator:Hide()
        return
    end
    if isHiddenForDrag and not ns.Launcher.GetStyle().isDragging then
        isHiddenForDrag = false
        reveal = 0
    else
        reveal = ShouldShow() and 1 or 0
    end
    local size = Favorites.GetSize()
    for _, button in ipairs(outside) do
        local frame = ns.LauncherButton.Get(holder, button)
        frame.isFavorite = true
        ns.LauncherButton.SetLook(frame, "icons", size, 0)
        ns.LauncherButton.SetAlerted(button.key, ns.db.showAlerts and ns.Alert.IsChanged(button.key))
        ns.LauncherButton.ShowNow(frame)
    end
    Place()
    -- In the layer the holder took from the launcher (see Place), over it; a hand-made button's own
    -- frame goes over its favorite, once that's sized and in its layer.
    for _, button in ipairs(outside) do
        local frame = ns.LauncherButton.GetFrame(button.key)
        frame:SetFrameStrata(holder:GetFrameStrata())
        frame:SetFrameLevel(holder:GetFrameLevel() + 1)
        if button.source == "frame" then
            ns.Handmade.Attach(button, frame)
        end
    end
    Favorites.Wake()
end
