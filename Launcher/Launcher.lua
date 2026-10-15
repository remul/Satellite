local _, ns = ...

-- The launcher: what opens the menu with the buttons (see Menu), in one of several styles (see
-- Launcher/Styles): a button on the minimap's ring, the compass arrow, a circle or square you can
-- put anywhere, a bar on the edge of the screen, or no launcher at all with the menu always open.
-- This picks the style and gives every style the same clicks, tooltip and dragging: right-click
-- for the settings (see Settings); drag to move when unlocked, or with Shift.
local Launcher = {}
ns.Launcher = Launcher

-- The styles, by key (each file in Launcher/Styles adds its own): see Styles/Arrow.lua for what a
-- style has.
ns.Styles = ns.Styles or {}
Launcher.DEFAULT_STYLE = "satellite"

local isReady = false
local current -- the style shown now

function Launcher.GetStyle()
    return ns.Styles[ns.db.style] or ns.Styles[Launcher.DEFAULT_STYLE]
end

-- Redraws after the style, the settings, the minimap's size or the buttons changed.
function Launcher.Refresh()
    if not isReady then
        return
    end
    local style = Launcher.GetStyle()
    if style ~= current then
        if current then
            current:Hide()
        end
        current = style
        ns.Menu.Reset(style.alwaysOpen, function(progress)
            style:OnProgress(progress)
        end)
    end
    ns.Compass.Update()
    style:Show()
    -- The style places the menu from its size, so that's measured first.
    ns.Menu.Measure()
    style:Refresh()
    ns.Menu.Refresh()
    -- A new style starts with the menu closed; with the settings open, it opens again, so the
    -- changes show.
    if ns.Settings.IsShown() and not ns.Menu.IsOpen() then
        ns.Menu.Open()
    end
    ns.Alert.Update()
    ns.Settings.Update()
end

-- Hovering (settings): the menu opens after the mouse rests on the launcher this long, and closes
-- this long after it left the launcher and the menu.
local HOVER_OPEN_DELAY, LEAVE_CLOSE_DELAY = 0.2, 0.6
-- A click this soon after the menu opened on hover doesn't close it again.
local HOVER_CLICK_GRACE = 1
-- The frames that open the menu (see SetupOpener), when it opened on hover, and how long the
-- mouse has rested on them or been away.
local openers = {}
local hoverOpenTime, hoverTime, awayTime = 0, 0, 0
local watcher = CreateFrame("Frame")
watcher:Hide()

-- Whether the mouse is where frame takes clicks: its hit area, grown or shrunk from its edges
-- (the compass arrow's is grown; see Arrow.lua).
local function IsMouseOverHitArea(frame)
    local left, right, top, bottom = frame:GetHitRectInsets()
    return frame:IsMouseOver(-top, bottom, left, -right)
end

local function IsMouseOverLauncher()
    if ns.Menu.IsOpen() and ns.Menu.GetPanel():IsMouseOver() then
        return true
    end
    for _, opener in ipairs(openers) do
        if opener:IsVisible() and IsMouseOverHitArea(opener) then
            return true
        end
    end
    return false
end

-- An addon's dropdown, opened from one of the menu's buttons, needs the menu to stay (also see
-- LauncherButton.AfterClick).
local function IsAddonMenuOpen()
    local manager = Menu and Menu.GetManager and Menu.GetManager()
    if manager and manager:IsAnyMenuOpen() then
        return true
    end
    return DropDownList1 ~= nil and DropDownList1:IsShown()
end
Launcher.IsAddonMenuOpen = IsAddonMenuOpen

-- Runs while the mouse is over the launcher, or the menu is open and closes when it leaves.
watcher:SetScript("OnUpdate", function(self, elapsed)
    local isOver = IsMouseOverLauncher()
    if not ns.Menu.IsOpen() then
        awayTime = 0
        if ns.db.openOnHover and isOver and not current.alwaysOpen and not current.isDragging then
            hoverTime = hoverTime + elapsed
            if hoverTime >= HOVER_OPEN_DELAY then
                hoverTime, hoverOpenTime = 0, GetTime()
                ns.Menu.Open()
            end
        else
            hoverTime = 0
        end
        if not isOver then
            self:Hide()
        end
        return
    end
    hoverTime = 0
    if ns.db.closeMode ~= "leave" or current.alwaysOpen then
        if not isOver then
            self:Hide()
        end
        return
    end
    if isOver or ns.Settings.IsShown() or current.isDragging or IsAddonMenuOpen() then
        awayTime = 0
        return
    end
    awayTime = awayTime + elapsed
    if awayTime >= LEAVE_CLOSE_DELAY then
        awayTime = 0
        ns.Menu.Close()
        self:Hide()
    end
end)

-- A click anywhere else closes the menu (unless it closes when the mouse leaves): not on the
-- launcher or the menu (a hand-made button's own frame is in it), nor while the settings or an
-- addon's dropdown are open (clicks in those belong to them).
local function OnGlobalMouseDown()
    if ns.db.closeMode ~= "click" or not ns.Menu.IsOpen() or current.alwaysOpen then
        return
    end
    if IsMouseOverLauncher() or ns.Settings.IsShown() or IsAddonMenuOpen() then
        return
    end
    ns.Menu.Close()
end

function Launcher.Toggle()
    if current.alwaysOpen then
        return
    end
    -- Opened on hover a moment ago: the click that usually follows keeps it open.
    if ns.Menu.IsOpen() and ns.db.openOnHover and GetTime() - hoverOpenTime < HOVER_CLICK_GRACE then
        return
    end
    ns.Menu.Toggle()
    watcher:Show()
end

-- Shared behaviour -------------------------------------------------------------------------------

-- Whether the current style's launcher moves when dragged: when it's unlocked, or with Shift.
local function CanMove()
    return current.isMovable and (not ns.db.locked or IsShiftKeyDown())
end

-- Space between the launcher and its tooltip.
local TOOLTIP_GAP = 10

-- Beside one of owner's corners, toward the middle of the screen (so it isn't pushed back over
-- the launcher at an edge), with some space between.
local function AnchorTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    local x, y = owner:GetCenter()
    if not x then
        GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
        return
    end
    local scale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local isLeft = x * scale > UIParent:GetWidth() / 2
    local isAbove = y * scale < UIParent:GetHeight() / 2
    local vertical = isAbove and "BOTTOM" or "TOP"
    local horizontal = isLeft and "RIGHT" or "LEFT"
    local ownerPoint = (isAbove and "TOP" or "BOTTOM") .. (isLeft and "LEFT" or "RIGHT")
    GameTooltip:SetPoint(vertical .. horizontal, owner, ownerPoint,
        isLeft and -TOOLTIP_GAP or TOOLTIP_GAP, isAbove and TOOLTIP_GAP or -TOOLTIP_GAP)
end

-- Only while the menu is closed: open, the tooltip would cover it, and the menu shows what it is.
local function ShowTooltip(owner)
    if ns.Menu.IsOpen() then
        if GameTooltip:IsOwned(owner) then
            GameTooltip:Hide()
        end
        return
    end
    local L = ns.L
    AnchorTooltip(owner)
    GameTooltip_SetTitle(GameTooltip, ns.TITLE)
    GameTooltip_AddNormalLine(GameTooltip, L["Click to show your addon buttons."])
    GameTooltip_AddInstructionLine(GameTooltip, L["Right-click for settings."])
    if current.isMovable then
        GameTooltip_AddInstructionLine(GameTooltip, ns.db.locked and L["Shift-drag to move."] or L["Drag to move."])
    end
    GameTooltip:Show()
end

-- When a drag last ended: the click that ends a drag doesn't open or close the menu.
local lastDragTime = 0

-- Makes frame move the current style's launcher when dragged (see CanMove); with onlyStyle, only
-- while that style is the current one (the menu's panel, for the Always open style).
function Launcher.SetupMover(frame, onlyStyle)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if (not onlyStyle or current == onlyStyle) and CanMove() then
            GameTooltip:Hide()
            -- The menu would be in the way while it moves along. The settings stay where they
            -- are, and the menu opens again where it's let go (see Launcher.Refresh).
            ns.Settings.Detach()
            if ns.Menu.IsOpen() then
                ns.Menu.Close(true)
            end
            current:OnDragStart()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if current.isDragging then
            current:OnDragStop()
            lastDragTime = GetTime()
            ns.Settings.Attach()
            Launcher.Refresh()
        end
    end)
end

-- Makes button open and close the menu (and the settings, with a right-click), light up with it
-- while hovered, and move the launcher when dragged.
function Launcher.SetupOpener(button)
    button:RegisterForClicks("AnyUp")
    Launcher.SetupMover(button)
    openers[#openers + 1] = button
    button:SetScript("OnEnter", function(self)
        watcher:Show()
        current:SetHovered(true)
        ns.Menu.SetHovered(true)
        ShowTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        current:SetHovered(false)
        ns.Menu.SetHovered(false)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if GetTime() - lastDragTime < 0.2 then
            return
        end
        if mouseButton == "RightButton" then
            ns.Settings.Toggle()
        else
            Launcher.Toggle()
        end
        if self:IsMouseOver() then
            ShowTooltip(self)
        end
    end)
end

-- New buttons ----------------------------------------------------------------------------------
-- The launcher pulses when an addon adds a button while the game runs (an addon loaded later):
-- not while addons are still loading after login, while the menu is open (the button shows), or
-- while the settings are open (they add and take out buttons themselves).
local PULSE_START_DELAY = 5
local knownButtons = {}
local isPulseReady = false

-- The menu's buttons now, [key] = true.
local function RememberButtons()
    wipe(knownButtons)
    for _, button in ipairs(ns.Buttons.GetLauncherButtons()) do
        knownButtons[button.key] = true
    end
end

local function PulseForNewButtons()
    if not isPulseReady then
        return
    end
    local isNew = false
    for _, button in ipairs(ns.Buttons.GetLauncherButtons()) do
        isNew = isNew or not knownButtons[button.key]
    end
    RememberButtons()
    if isNew and not ns.Menu.IsOpen() and not ns.Settings.IsShown() and current.Pulse then
        current:Pulse()
    end
end

-- The minimap's shape, which minimap addons (ElvUI, SexyMap...) set with the global
-- GetMinimapShape, as LibDBIcon reads it: for each quarter (bottom right, bottom left, top right,
-- top left), whether it's round. Without it, the minimap is round.
local SHAPES = {
    ROUND = { true, true, true, true },
    SQUARE = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function GetShape()
    ---@diagnostic disable-next-line: undefined-global
    local shape = GetMinimapShape and GetMinimapShape()
    return SHAPES[shape] or SHAPES.ROUND
end

-- Whether the minimap is round all the way (its compass is then whole).
function Launcher.IsMinimapRound()
    return GetShape() == SHAPES.ROUND
end

-- A point degrees round from east (counterclockwise) on the minimap's edge, from its middle: on
-- its ring, or on its side where that quarter is square. share moves it out (1 is on the edge,
-- as a share of the minimap's half size), and extra further out, in its units.
function Launcher.GetMinimapEdgePoint(degrees, share, extra)
    local radians = math.rad(degrees)
    local x, y = math.cos(radians), math.sin(radians)
    local quarter = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    local width = Minimap:GetWidth() / 2 * share + (extra or 0)
    local height = Minimap:GetHeight() / 2 * share + (extra or 0)
    if not GetShape()[quarter] then
        -- Out to the square's side: the larger of x and y reaches it.
        local reach = math.max(math.abs(x), math.abs(y))
        x, y = x / reach, y / reach
    end
    return x * width, y * height
end

-- The current style's size setting, in percent of its normal size; each style has its own.
function Launcher.GetScalePercent()
    return ns.db.launcher.scales[ns.db.style] or 100
end

function Launcher.SetScalePercent(percent)
    ns.db.launcher.scales[ns.db.style] = percent ~= 100 and percent or nil
end

-- The current style's size setting, as a factor (1 is its normal size); the style multiplies its
-- sizes with it.
function Launcher.GetScale()
    return Launcher.GetScalePercent() / 100
end

-- Saved places --------------------------------------------------------------------------------

-- Where the player dragged a style's launcher to: its center, from the screen's bottom left
-- (in UIParent's units), or nil while it's in its default place.
function Launcher.GetPosition(key)
    return ns.db.positions[key]
end

function Launcher.SavePosition(key, frame)
    local x, y = frame:GetCenter()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ns.db.positions[key] = { x = x * scale, y = y * scale }
end

-- Whether the circle and square are docked on an edge of the screen.
function Launcher.IsShapeDocked()
    local position = ns.db.positions.shape
    return position ~= nil and position.edge ~= nil
end

-- How far x, y (in UIParent's units) is from an edge of the screen.
function Launcher.GetEdgeDistance(edge, x, y)
    if edge == "LEFT" then
        return x
    elseif edge == "RIGHT" then
        return UIParent:GetWidth() - x
    elseif edge == "BOTTOM" then
        return y
    end
    return UIParent:GetHeight() - y
end

local EDGES = { "LEFT", "RIGHT", "BOTTOM", "TOP" }

-- The edge of the screen nearest to x, y (in UIParent's units; the first of them in a corner),
-- its distance, less halfWidth or halfHeight (a frame's, with x, y its middle; 0 if nil), and how
-- far along the edge x, y is from its middle: the circle and square dock there, and the side bar
-- sits there. Runs every frame of a drag, so it makes no tables.
function Launcher.GetNearestEdge(x, y, halfWidth, halfHeight)
    local nearest, nearestDistance
    for _, edge in ipairs(EDGES) do
        local isVertical = edge == "LEFT" or edge == "RIGHT"
        local distance = Launcher.GetEdgeDistance(edge, x, y) - ((isVertical and halfWidth or halfHeight) or 0)
        if not nearestDistance or distance < nearestDistance then
            nearest, nearestDistance = edge, distance
        end
    end
    local isVertical = nearest == "LEFT" or nearest == "RIGHT"
    local along = isVertical and y - UIParent:GetHeight() / 2 or x - UIParent:GetWidth() / 2
    return nearest, along, nearestDistance
end

-- The circle, square and side bar share their place, so switching between them keeps the
-- launcher where it is: the circle's and square's (see Shapes) in ns.db.positions.shape, which
-- the side bar's (ns.db.sideBar) follows, and the other way round.
function Launcher.SetShapePosition(position)
    ns.db.positions.shape = position
    if position.edge then
        ns.db.sideBar.side, ns.db.sideBar.offset = position.edge, position.offset
    else
        ns.db.sideBar.side, ns.db.sideBar.offset = Launcher.GetNearestEdge(position.x, position.y)
    end
end

-- Called every frame of a drag: the shape's place is changed in place while it's docked already.
function Launcher.SetSideBarPosition(side, offset)
    ns.db.sideBar.side, ns.db.sideBar.offset = side, offset
    local shape = ns.db.positions.shape
    if shape and shape.edge then
        shape.edge, shape.offset = side, offset
    else
        ns.db.positions.shape = { edge = side, offset = offset }
    end
end

-- Puts every launcher back in its default place.
function Launcher.ResetPositions()
    wipe(ns.db.positions)
    ns.db.sideBar.side, ns.db.sideBar.offset = "RIGHT", 0
    Launcher.Refresh()
end

-- Which way the menu opens from frame: toward the middle of the screen.
function Launcher.GetDirection(frame)
    local x = frame:GetCenter()
    if not x then
        return "LEFT"
    end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * scale > UIParent:GetWidth() / 2 and "LEFT" or "RIGHT"
end

-- Called once ns.db is loaded; the frames are made at login, once the minimap has its size.
function Launcher:Setup()
    ns:RegisterEvent("PLAYER_LOGIN", function()
        ns.Menu.Setup()
        ns.Compass:Setup()
        ns.LauncherButton.Setup()
        isReady = true
        Launcher.Refresh()
        ns.Alert.Start()

        ns.Buttons.OnChanged(Launcher.Refresh)
        ns.Buttons.OnChanged(PulseForNewButtons)
        C_Timer.After(PULSE_START_DELAY, function()
            RememberButtons()
            isPulseReady = true
        end)
        -- The guild is known a moment after login, and can change: the Prisma logo (see IconStack)
        -- shows or goes. The roster updates often; only a change of guild redraws.
        local wasInPrisma = ns.IconStack.IsInPrisma()
        local function OnGuildChanged()
            local isInPrisma = ns.IconStack.IsInPrisma()
            if isInPrisma ~= wasInPrisma then
                wasInPrisma = isInPrisma
                Launcher.Refresh()
            end
        end
        ns:RegisterEvent("PLAYER_GUILD_UPDATE", OnGuildChanged)
        ns:RegisterEvent("GUILD_ROSTER_UPDATE", OnGuildChanged)
        -- The class symbols and images change with the spec, and the hero talent image with the
        -- talents (see IconStack); talents change often, the image seldom.
        ns:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", Launcher.Refresh)
        local symbolKey = ns.IconStack.GetSymbolKey()
        ns:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
            local key = ns.IconStack.GetSymbolKey()
            if key ~= symbolKey then
                symbolKey = key
                Launcher.Refresh()
            end
        end)
        ns:RegisterEvent("GLOBAL_MOUSE_DOWN", OnGlobalMouseDown)
        Minimap:HookScript("OnSizeChanged", Launcher.Refresh)
        -- Where things fit on the screen changes with the UI scale, the window's size, and the
        -- minimap moved in Edit Mode.
        ns:RegisterEvent("UI_SCALE_CHANGED", Launcher.Refresh)
        ns:RegisterEvent("DISPLAY_SIZE_CHANGED", Launcher.Refresh)
        EventRegistry:RegisterCallback("EditMode.Exit", Launcher.Refresh, Launcher)
    end)
end
