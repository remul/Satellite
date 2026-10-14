local _, ns = ...

-- The circle and square styles: a button you can drag anywhere, by default beside the minimap's
-- top left, that looks like the minimap button: a stack of coloured discs and a gold chevron
-- (see StackButton). The menu slides out toward the middle of the screen.
--
-- Dragged against an edge of the screen, the circle and square dock there: they keep their size
-- and look, with part of them past the edge, cut off by it, and the menu opens away from the edge.
local Theme = ns.Theme

-- The buttons' width and height: the square is wider than tall, to fit its row of discs.
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
-- How close to an edge (in interface units) the button has to be dragged to dock there.
local SNAP_DISTANCE = 16

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
        button:SetFrameLevel(10)
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

    -- The discs, in the middle of the whole shape, also while docked (cut off by the edge then).
    local function LayoutIcons(edge)
        local arrangement = key == "square" and "row" or "cluster"
        local size = math.min(GetSize(key))
        local x, y = 0, 0
        if edge then
            -- The shape's middle is half the overhang further out than the button's.
            local shift = GetDock(key, IsVertical(edge)).overhang / 2
            x, y = EDGES[edge].x * shift, EDGES[edge].y * shift
        end
        opener:Layout(direction, arrangement, size, x, y)
    end

    -- Docked on an edge, at the place the player dragged it to, or beside the minimap. Returns
    -- the edge it's docked on.
    local function Place()
        local position = ns.Launcher.GetPosition(key)
        local edge = position and position.edge
        Layout(edge)
        button:ClearAllPoints()
        if edge then
            local vertical = IsVertical(edge)
            button:SetPoint(edge, UIParent, edge, vertical and 0 or position.offset, vertical and position.offset or 0)
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

    -- A short bounce of the discs, to show a new button (see Launcher.Pulse).
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

    function Style:Refresh()
        local edge = Place()
        dockedEdge = edge
        ns.Menu.SetFrameLevel(button:GetFrameLevel() + 1)
        -- Docked: away from the edge; otherwise as set (see openDirection), or toward the middle.
        local setting = ns.db.openDirection
        if edge then
            direction = EDGES[edge].direction
        elseif WAYS[setting] then
            direction = setting
        else
            direction = ns.Launcher.GetDirection(button)
        end
        LayoutIcons(edge)
        -- From the button's side: past the chevron.
        local way = WAYS[direction]
        local extent = way.x ~= 0 and button:GetWidth() / 2 or button:GetHeight() / 2
        local reach = opener:GetMenuReach() - extent + MENU_GAP
        ns.Menu.Place(button, button, way.point, way.x * reach, way.y * reach, direction)
    end

    function Style:SetHovered(isHovered)
        opener:SetHovered(isHovered)
    end

    -- While dragged, the button follows the cursor; close to an edge (for the shapes
    -- that dock), it docks there, along it with the cursor, keeping the menu on the screen.
    local grabX, grabY = 0, 0

    local function GetCursor()
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        return x / scale, y / scale
    end

    local function FollowCursor()
        local x, y = GetCursor()
        x, y = x + grabX, y + grabY
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        local halfWidth, halfHeight = GetSize(key)
        halfWidth, halfHeight = halfWidth / 2, halfHeight / 2
        local position
        local distances = {
            LEFT = x - halfWidth, RIGHT = width - x - halfWidth, BOTTOM = y - halfHeight, TOP = height - y - halfHeight,
        }
        local edge = "LEFT"
        for candidate, distance in pairs(distances) do
            if distance < distances[edge] then
                edge = candidate
            end
        end
        if distances[edge] < SNAP_DISTANCE then
            local menuWidth, menuHeight = ns.Menu.GetSize()
            local dock = GetDock(key, IsVertical(edge))
            local along, room
            if IsVertical(edge) then
                along, room = y - height / 2, (height - math.max(dock.height, menuHeight)) / 2
            else
                along, room = x - width / 2, (width - math.max(dock.width, menuWidth)) / 2
            end
            position = { edge = edge, offset = math.max(-room, math.min(room, along)) }
        end
        position = position or {
            x = math.max(halfWidth, math.min(width - halfWidth, x)),
            y = math.max(halfHeight, math.min(height - halfHeight, y)),
        }
        ns.db.positions[key] = position
        Style:Refresh()
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
