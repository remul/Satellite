local _, ns = ...

-- The side bar style, like Blizzard's side panels: a dark bar with cut corners on an edge of the
-- screen (left, right, top or bottom), with a tab inside it along its inner edge and a gold
-- triangle on the tab. The menu
-- slides out from the tab toward the middle of the screen; the triangle points the way it opens,
-- and back once it's open. Drag it along its edge or to another one (when unlocked, or with
-- Shift).
local Theme = ns.Theme
local Style = { isMovable = true }
ns.Styles.sideBar = Style

local RAIL_FILL, RAIL_BORDER = ns.MEDIA .. "RailFill", ns.MEDIA .. "RailBorder"
local TAB_FILL, TAB_BORDER = ns.MEDIA .. "TabFill", ns.MEDIA .. "TabBorder"
-- The textures' slice margins: their cut corners and border (see tools/generate_textures.py).
local RAIL_MARGIN, TAB_MARGIN = 8, 5

-- Colours of Blizzard's side panels (measured in game): a dark fill, a little lighter at the top
-- of the bar, grey borders, and a gold triangle shaded lighter at the top.
local FILL = CreateColor(0.1, 0.1, 0.1, 1)
local RAIL_FILL_TOP, RAIL_FILL_BOTTOM = CreateColor(0.2, 0.2, 0.2, 1), CreateColor(0.09, 0.09, 0.09, 1)
local BORDER_COLOR = CreateColor(0.55, 0.55, 0.57, 1)
local BORDER_HOVER = CreateColor(0.8, 0.8, 0.84, 1)
local TRIANGLE_TOP, TRIANGLE_BOTTOM = CreateColor(1, 0.86, 0.36, 1), CreateColor(0.85, 0.6, 0.12, 1)
local TRIANGLE_HOVER = CreateColor(1, 0.92, 0.6, 1)

-- In interface units, for a bar on the left or right (swapped on the top or bottom): the bar's
-- thickness, the tab's thickness and length, and the triangle's width and height (pointing left
-- or right), measured from Blizzard's. The bar is as long as the menu is high (on every edge, so
-- it's the same bar on the top as on a side); at least a little longer than the tab.
local RAIL_THICKNESS, MIN_RAIL_LENGTH = 16, 60
local TAB_THICKNESS, TAB_LENGTH = 15, 33
local TRIANGLE_WIDTH, TRIANGLE_HEIGHT = 6, 11
-- Space between the bar and the menu.
local MENU_GAP = 3

-- For each edge: the way in (toward the middle of the screen) as a point of the bar, and the way
-- the menu opens.
local INWARD = {
    LEFT = { point = "RIGHT", direction = "RIGHT" },
    RIGHT = { point = "LEFT", direction = "LEFT" },
    TOP = { point = "BOTTOM", direction = "DOWN" },
    BOTTOM = { point = "TOP", direction = "UP" },
}

-- The triangle texture points left; these coordinates turn it to point each way (the
-- eight-value form: upper left, lower left, upper right, lower right).
local POINTING = {
    LEFT = { 0, 0, 0, 1, 1, 0, 1, 1 },
    RIGHT = { 1, 0, 1, 1, 0, 0, 0, 1 },
    UP = { 0, 0, 1, 0, 0, 1, 1, 1 },
    DOWN = { 1, 0, 0, 0, 1, 1, 0, 1 },
}
local OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", UP = "DOWN", DOWN = "UP" }

local bar, tab
local railLength = MIN_RAIL_LENGTH
local direction = "LEFT"

local function IsVertical(side)
    return side == "LEFT" or side == "RIGHT"
end

-- A box in the side panels' style: fill, dark outline, and border; returns the fill and border.
local function AddBox(frame, fillFile, borderFile, margin)
    local fill = Theme.AddSlicedTexture(frame, fillFile, margin, "BACKGROUND", 0, FILL)
    Theme.AddSlicedTexture(frame, borderFile, margin, "BORDER", 0, Theme.OUTLINE, 1)
    return fill, Theme.AddSlicedTexture(frame, borderFile, margin, "BORDER", 1, BORDER_COLOR)
end

local function Create()
    bar = CreateFrame("Button", "SatelliteSideBar", UIParent)
    bar:SetFrameStrata(Theme.STRATA)
    bar:SetFrameLevel(Theme.LEVEL)
    local railFill
    railFill, bar.border = AddBox(bar, RAIL_FILL, RAIL_BORDER, RAIL_MARGIN)
    railFill:SetGradient("VERTICAL", RAIL_FILL_BOTTOM, RAIL_FILL_TOP)
    tab = CreateFrame("Button", nil, bar)
    tab:SetFrameLevel(bar:GetFrameLevel() + 2)
    tab.border = select(2, AddBox(tab, TAB_FILL, TAB_BORDER, TAB_MARGIN))
    local function AddTriangle(subLevel, color)
        local texture = tab:CreateTexture(nil, "ARTWORK", nil, subLevel)
        texture:SetTexture(Theme.TRIANGLE)
        texture:SetVertexColor(color:GetRGBA())
        texture:SetPoint("CENTER")
        return texture
    end
    tab.shadow = AddTriangle(0, Theme.OUTLINE)
    tab.triangle = AddTriangle(1, TRIANGLE_TOP)
    tab.pop = Theme.CreatePop(tab)
    ns.Launcher.SetupOpener(bar)
    ns.Launcher.SetupOpener(tab)
end

function Style:Show()
    if not bar then
        Create()
    end
    bar:Show()
end

function Style:Hide()
    if bar then
        bar:Hide()
    end
end

-- Gold, lighter at the top; brighter while hovered.
local isHovered = false
local function UpdateTriangleColor()
    if isHovered then
        tab.triangle:SetGradient("VERTICAL", TRIANGLE_HOVER, TRIANGLE_HOVER)
    else
        tab.triangle:SetGradient("VERTICAL", TRIANGLE_BOTTOM, TRIANGLE_TOP)
    end
end

-- Points the triangle (and its outline) toward pointing ("LEFT", "RIGHT", "UP" or "DOWN").
local function PointTriangle(pointing)
    local sideways = pointing == "LEFT" or pointing == "RIGHT"
    local scale = ns.Launcher.GetScale()
    local width = (sideways and TRIANGLE_WIDTH or TRIANGLE_HEIGHT) * scale
    local height = (sideways and TRIANGLE_HEIGHT or TRIANGLE_WIDTH) * scale
    tab.triangle:SetSize(width, height)
    tab.shadow:SetSize(width + 2, height + 2)
    for _, texture in ipairs({ tab.triangle, tab.shadow }) do
        ---@diagnostic disable-next-line: redundant-parameter
        texture:SetTexCoord(unpack(POINTING[pointing]))
    end
    UpdateTriangleColor()
end

-- On its edge, at its place along it; the tab inside it, along its inner edge.
local function Place()
    local side, offset = ns.db.sideBar.side, ns.db.sideBar.offset
    local vertical = IsVertical(side)
    local inward = INWARD[side].point
    local _, menuHeight = ns.Menu.GetSize()
    local scale = ns.Launcher.GetScale()
    local thickness, tabThickness, tabLength = RAIL_THICKNESS * scale, TAB_THICKNESS * scale, TAB_LENGTH * scale
    -- Long enough for the favorites beside the tab too (see PlaceFavorites).
    railLength = math.max(MIN_RAIL_LENGTH * scale, menuHeight,
        ns.Favorites.GetRowLength(ns.Favorites.GetCount(), tabLength))
    bar:SetSize(vertical and thickness or railLength, vertical and railLength or thickness)
    tab:SetSize(vertical and tabThickness or tabLength, vertical and tabLength or tabThickness)
    -- On the screen, however long the rail (the place may come from the circle or square).
    local room = ((vertical and UIParent:GetHeight() or UIParent:GetWidth()) - railLength) / 2
    offset = math.max(-room, math.min(room, offset))
    bar:ClearAllPoints()
    bar:SetPoint(side, UIParent, side, vertical and 0 or offset, vertical and offset or 0)

    tab:ClearAllPoints()
    tab:SetPoint(inward, bar, inward)
end

-- Which way the triangle points now, so it's only redrawn when that changes (see OnProgress).
local pointedAt

function Style:Refresh()
    -- Sizes may have changed: the triangle is drawn again.
    pointedAt = nil
    Place()
    local inward = INWARD[ns.db.sideBar.side]
    direction = inward.direction
    -- With favorites beside the tab, the menu opens past them.
    local gap = MENU_GAP
    if ns.Favorites.GetCount() > 0 then
        gap = math.max(gap, ns.Favorites.GetRowDepth() - RAIL_THICKNESS * ns.Launcher.GetScale())
    end
    local x = direction == "LEFT" and -gap or direction == "RIGHT" and gap or 0
    local y = direction == "DOWN" and -gap or direction == "UP" and gap or 0
    ns.Menu.SetFrameLevel(bar:GetFrameLevel() + 4, Theme.MENU_STRATA)
    ns.Menu.Place(bar, tab, inward.point, x, y, direction)
end

-- The triangle points the way the menu opens, and back once it's open.
function Style:OnProgress(progress)
    local pointing = progress >= 0.5 and OPPOSITE[direction] or direction
    if pointing ~= pointedAt then
        pointedAt = pointing
        PointTriangle(pointing)
    end
end

-- A short pop of the tab, to show a new button (see Launcher.Pulse).
function Style:Pulse()
    tab.pop:Play()
end

-- The favorites (see Favorites): in a straight row along the bar on both sides of the tab, against
-- the edge of the screen, reaching in past the bar; the menu opens past them (see Refresh).
function Style:PlaceFavorites(points, count, size, gap)
    local side = ns.db.sideBar.side
    local width, height = tab:GetSize()
    ns.Favorites.PlaceAlongEdge(points, count, size, gap, side, tab, IsVertical(side) and height or width)
    return tab, 0, 0, tab
end

-- The alert dot (see Alert): on the tab's corner toward the middle of the screen and up (or
-- right, on the top and bottom edges).
local ALERT_CORNERS = { LEFT = "TOPRIGHT", RIGHT = "TOPLEFT", TOP = "BOTTOMRIGHT", BOTTOM = "TOPRIGHT" }
function Style:GetAlertPoint()
    return tab, ALERT_CORNERS[ns.db.sideBar.side], 0, 0
end

function Style:SetHovered(hovered)
    isHovered = hovered
    bar.border:SetVertexColor((hovered and BORDER_HOVER or BORDER_COLOR):GetRGBA())
    tab.border:SetVertexColor((hovered and BORDER_HOVER or BORDER_COLOR):GetRGBA())
    UpdateTriangleColor()
end

-- While dragged, the bar goes to the edge nearest the cursor, and along it with the
-- cursor.
local function FollowCursor()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    local side, along = ns.Launcher.GetNearestEdge(x, y)
    local room = ((IsVertical(side) and UIParent:GetHeight() or UIParent:GetWidth()) - railLength) / 2
    local isNewSide = side ~= ns.db.sideBar.side
    ns.Launcher.SetSideBarPosition(side, math.max(-room, math.min(room, along)))
    -- On another edge, the menu opens another way too.
    if isNewSide then
        Style:Refresh()
    else
        Place()
    end
end

function Style:OnDragStart()
    Style.isDragging = true
    bar:SetScript("OnUpdate", FollowCursor)
end

function Style:OnDragStop()
    Style.isDragging = false
    bar:SetScript("OnUpdate", nil)
end
