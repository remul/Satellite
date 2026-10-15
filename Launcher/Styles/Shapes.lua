local _, ns = ...

-- The circle and square styles: a button you can drag anywhere, by default beside the minimap's
-- top left, that looks like the minimap button: the logo and a gold chevron
-- (see StackButton). The menu slides out toward the middle of the screen.
--
-- Dragged against an edge of the screen, the circle and square dock there: they keep their size
-- and look, with part of them past the edge, cut off by it, and the menu opens away from the edge.
local Theme = ns.Theme

-- The buttons' width and height: the square is wider than tall.
local SIZES = { circle = { 50, 50 }, square = { 56, 42 } }
-- How much of the shape goes past the edge while docked, as a share of its depth (its size across
-- the edge).
local DOCKED_OVERHANG_SHARE = 1 / 2
-- The default place: beside the minimap, this many degrees round from east (counterclockwise),
-- clear of the minimap's border.
local DEFAULT_DEGREES = 150
local DEFAULT_DISTANCE_SHARE = 1.12
-- Space between the button (or its chevron) and the menu.
local MENU_GAP = 4
-- How close to an edge (in interface units) the cursor docks the button there, wherever it was
-- grabbed.
local CURSOR_SNAP_DISTANCE = 2

-- The size of key's button, from the launcher size setting.
local function GetSize(key)
    local scale = ns.Launcher.GetScale()
    return SIZES[key][1] * scale, SIZES[key][2] * scale
end

-- Docked on an edge (vertical: the left or right one): the size of the part on the screen and of
-- the whole shape, and how much of the shape goes past the edge.
local function GetDock(key, vertical)
    local width, height = GetSize(key)
    local overhang = (vertical and width or height) * DOCKED_OVERHANG_SHARE
    return {
        width = vertical and width - overhang or width, height = vertical and height or height - overhang,
        shapeWidth = width, shapeHeight = height, overhang = overhang,
    }
end

-- For each edge: the way out of the screen, and the way in (as a point of the button, and the way
-- the menu opens).
local EDGES = {
    LEFT = { x = -1, y = 0, point = "RIGHT", direction = "RIGHT" },
    RIGHT = { x = 1, y = 0, point = "LEFT", direction = "LEFT" },
    TOP = { x = 0, y = 1, point = "BOTTOM", direction = "DOWN" },
    BOTTOM = { x = 0, y = -1, point = "TOP", direction = "UP" },
}
-- For each way the menu opens: the point of the button it starts from, and one step that way.
local WAYS = {
    LEFT = { point = "LEFT", x = -1, y = 0 },
    RIGHT = { point = "RIGHT", x = 1, y = 0 },
    UP = { point = "TOP", x = 0, y = 1 },
    DOWN = { point = "BOTTOM", x = 0, y = -1 },
}

local function IsVertical(edge)
    return edge == "LEFT" or edge == "RIGHT"
end

-- Draws the shape on frame: its fill and border, which light up.
local DRAWERS = {
    circle = function(frame)
        frame.fill, frame.border = Theme.AddRoundBox(frame)
    end,
    square = function(frame)
        frame.fill, frame.border = Theme.AddBox(frame, Theme.BAR_FILL, Theme.BAR_BORDER, Theme.BAR_RADIUS)
    end,
}

local function CreateStyle(key)
    local Style = { isMovable = true }
    -- button is what's clicked: the part of the shape on the screen; shape holds the drawing,
    -- which goes past the edge while docked. opener is the stack and chevron.
    local button, shape, opener
    local direction = "LEFT"

    local function Create()
        button = CreateFrame("Button", "SatelliteLauncher_" .. key, UIParent)
        button:SetFrameStrata(Theme.STRATA)
        button:SetFrameLevel(Theme.LEVEL)
        button:SetClampedToScreen(true)
        shape = CreateFrame("Frame", nil, button)
        DRAWERS[key](shape)
        opener = ns.StackButton.Create(button, shape, function(isLit)
            Theme.SetBoxHovered(shape.fill, shape.border, isLit)
        end)
        ns.Launcher.SetupOpener(button)
    end

    function Style:Show()
        if not button then
            Create()
        end
        button:Show()
    end

    function Style:Hide()
        if button then
            button:Hide()
        end
    end

    -- The whole shape, or docked on edge: the button is the part on the screen, and the shape
    -- goes past the edge by the overhang.
    local function Layout(edge)
        shape:ClearAllPoints()
        if not edge then
            button:SetSize(GetSize(key))
            shape:SetAllPoints(button)
        else
            local dock = GetDock(key, IsVertical(edge))
            button:SetSize(dock.width, dock.height)
            shape:SetSize(dock.shapeWidth, dock.shapeHeight)
            local out = EDGES[edge]
            shape:SetPoint(edge, button, edge, out.x * dock.overhang, out.y * dock.overhang)
        end
    end

    -- The logo, in the middle of the whole shape, also while docked (cut off by the edge then).
    local function LayoutIcons(edge)
        local size = math.min(GetSize(key))
        local x, y = 0, 0
        if edge then
            -- The shape's middle is half the overhang further out than the button's.
            local shift = GetDock(key, IsVertical(edge)).overhang / 2
            x, y = EDGES[edge].x * shift, EDGES[edge].y * shift
        end
        opener:Layout(direction, size, x, y)
    end

    -- Docked on an edge, at the place the player dragged it to, or beside the minimap; with
    -- isMoveOnly (while dragged, on the same edge), its shape is as it was. Returns the edge it's
    -- docked on.
    local function Place(isMoveOnly)
        local position = ns.Launcher.GetPosition("shape")
        local edge = position and position.edge
        if not isMoveOnly then
            Layout(edge)
        end
        button:ClearAllPoints()
        if edge then
            -- On the screen, however long the button (the place may come from the side bar).
            local vertical = IsVertical(edge)
            local dock = GetDock(key, vertical)
            local room = vertical and (UIParent:GetHeight() - dock.height) / 2 or (UIParent:GetWidth() - dock.width) / 2
            local offset = math.max(-room, math.min(room, position.offset))
            button:SetPoint(edge, UIParent, edge, vertical and 0 or offset, vertical and offset or 0)
        elseif position and position.x then
            button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", position.x, position.y)
        else
            local x, y = ns.Launcher.GetMinimapEdgePoint(DEFAULT_DEGREES, DEFAULT_DISTANCE_SHARE,
                select(1, GetSize(key)) / 2)
            button:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end
        return edge
    end

    function Style:OnProgress(progress)
        opener:SetProgress(progress)
    end

    -- A short pop of the logo, to show a new button (see Launcher.Pulse).
    function Style:Pulse()
        opener:Pulse()
    end

    -- The edge it's docked on, or nil.
    local dockedEdge

    -- The alert dot (see Alert): at the top right, on the circle's ring or in the square's corner;
    -- docked, in the corner on the screen's side.
    function Style:GetAlertPoint()
        local width, height = GetSize(key)
        local x, y = width / 2, height / 2
        if key == "circle" then
            x, y = x * 0.66, y * 0.66
        else
            x, y = x - 6, y - 6
        end
        local out = dockedEdge and EDGES[dockedEdge]
        if out and out.x ~= 0 then
            x = -out.x * x
        end
        if out and out.y ~= 0 then
            y = -out.y * y
        end
        return shape, "CENTER", x, y
    end

    -- The way the menu opens: docked, away from the edge; otherwise as set (see openDirection),
    -- or toward the middle.
    local function GetMenuDirection(edge)
        local setting = ns.db.openDirection
        if edge then
            return EDGES[edge].direction
        elseif WAYS[setting] then
            return setting
        end
        return ns.Launcher.GetDirection(button)
    end

    local function GetShapeRadius()
        return math.max(GetSize(key)) / 2
    end

    -- Docked with favorites beside it, in an orbit round the shape (see Favorites), unless it's
    -- in a corner.
    local function IsOrbiting()
        local count = ns.Favorites.GetCount()
        return dockedEdge ~= nil and count > 0 and ns.Favorites.CanOrbitDocked(count, ns.Favorites.GetSize(),
            ns.Favorites.GetGap(), dockedEdge, shape, GetShapeRadius())
    end

    function Style:Refresh()
        local edge = Place()
        dockedEdge = edge
        ns.Menu.SetFrameLevel(button:GetFrameLevel() + 1, Theme.MENU_STRATA)
        direction = GetMenuDirection(edge)
        LayoutIcons(edge)
        -- From the button's side: past the chevron; docked, past the favorites' orbit too.
        local way = WAYS[direction]
        local extent = way.x ~= 0 and button:GetWidth() / 2 or button:GetHeight() / 2
        local reach = opener:GetMenuReach() - extent + MENU_GAP
        if edge and IsOrbiting() then
            -- From the shape's middle; the button's side is half the shape's depth from it.
            local width, height = GetSize(key)
            local orbitReach = ns.Favorites.GetDockedOrbitReach(ns.Favorites.GetCount(), ns.Favorites.GetSize(),
                ns.Favorites.GetGap(), GetShapeRadius())
            reach = math.max(reach, orbitReach + MENU_GAP - (IsVertical(edge) and width or height) / 2)
        end
        ns.Menu.Place(button, button, way.point, way.x * reach, way.y * reach, direction)
    end

    function Style:SetHovered(isHovered)
        opener:SetHovered(isHovered)
    end

    -- The favorites (see Favorites): in an arc round the button, on the side away from the menu,
    -- turned toward the middle of the screen where they wouldn't fit; docked, in an orbit round the
    -- shape, or in a corner in a row along the edge.
    function Style:PlaceFavorites(points, count, size, gap)
        if IsOrbiting() then
            ns.Favorites.PlaceInDockedOrbit(points, count, size, gap, dockedEdge, button, shape, GetShapeRadius())
        elseif dockedEdge then
            local width, height = button:GetSize()
            local length = IsVertical(dockedEdge) and height or width
            ns.Favorites.PlaceAlongEdge(points, count, size, gap, dockedEdge, button, length)
        else
            local way = WAYS[direction]
            local radius = math.max(GetSize(key)) / 2 + gap + size / 2
            local degrees = math.deg(math.atan2(-way.y, -way.x))
            ns.Favorites.PlaceInArc(points, count, size, gap, button, radius, degrees)
        end
        return button, 0, 0, button
    end

    -- While dragged, the button follows the cursor; close to an edge (for the shapes
    -- that dock), it docks there, along it with the cursor.
    local grabX, grabY = 0, 0

    local function GetCursor()
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        return x / scale, y / scale
    end

    -- Docks where the shape, following the cursor, would be past the edge by half its overhang:
    -- halfway between its place against the edge and its docked place, so it moves the least
    -- either way. Or, as the cursor can't leave the screen, when the cursor reaches the edge.
    local function FollowCursor()
        local cursorX, cursorY = GetCursor()
        local x, y = cursorX + grabX, cursorY + grabY
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        local halfWidth, halfHeight = GetSize(key)
        halfWidth, halfHeight = halfWidth / 2, halfHeight / 2
        -- The saved place's table is reused while it stays the same kind (docked or not), not made
        -- anew every frame.
        local saved = ns.Launcher.GetPosition("shape")
        local position
        -- The edge nearest the shape's side, and how far the shape's side and the cursor are from it.
        local edge, along, distance = ns.Launcher.GetNearestEdge(x, y, halfWidth, halfHeight)
        local dock = GetDock(key, IsVertical(edge))
        if distance <= -dock.overhang / 2
            or ns.Launcher.GetEdgeDistance(edge, cursorX, cursorY) <= CURSOR_SNAP_DISTANCE then
            -- Along the edge as far as the corner; the menu moves onto the screen by itself (see
            -- Menu.Place).
            local room = IsVertical(edge) and (height - dock.height) / 2 or (width - dock.width) / 2
            position = saved and saved.edge and saved or {}
            position.edge, position.offset = edge, math.max(-room, math.min(room, along))
        else
            position = saved and saved.x and saved or {}
            position.x = math.max(halfWidth, math.min(width - halfWidth, x))
            position.y = math.max(halfHeight, math.min(height - halfHeight, y))
        end
        ns.Launcher.SetShapePosition(position)
        -- Only moved, every frame; drawn again only when it docks on another edge (or comes off
        -- one), or its menu would open the other way. Letting go redraws it (see
        -- Launcher.SetupMover).
        if position.edge ~= dockedEdge then
            Style:Refresh()
        else
            Place(true)
            if GetMenuDirection(position.edge) ~= direction then
                Style:Refresh()
            end
        end
    end

    function Style:OnDragStart()
        Style.isDragging = true
        local x, y = GetCursor()
        -- From the whole shape's middle (past the edge while docked), as FollowCursor places it.
        local centerX, centerY = shape:GetCenter()
        local scale = shape:GetEffectiveScale() / UIParent:GetEffectiveScale()
        grabX, grabY = centerX * scale - x, centerY * scale - y
        button:SetScript("OnUpdate", FollowCursor)
    end

    function Style:OnDragStop()
        Style.isDragging = false
        button:SetScript("OnUpdate", nil)
    end

    return Style
end

for key in pairs(DRAWERS) do
    ns.Styles[key] = CreateStyle(key)
end
