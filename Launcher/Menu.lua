local _, ns = ...

-- The menu every launcher style opens: a rounded panel with the buttons in rows, sliding out to
-- the left, right, up or down from where the style puts it: a short way from the launcher's side
-- as it fades in.
local Menu = {}
ns.Menu = Menu

local Theme = ns.Theme

-- In pixels: padding inside the border and space between buttons. Rows of buttons (the menu
-- grows sideways, and only gets more rows when it has many buttons); it's never smaller than
-- MIN_COLUMNS by MIN_ROWS buttons, so even with one button it's easy to hit. Buttons fill it from
-- the top left.
local PADDING = 10
local BUTTON_SPACING = 6
local MIN_COLUMNS, MIN_ROWS = 4, 2
local function RowsFor(count)
    return count <= 6 and 1 or count <= 16 and 2 or 3
end
-- With names (ns.db.menuLabels): each name's width beside its button, the space between columns,
-- and the most buttons in a column; the buttons then go down the columns, like a list. With names
-- only, a row's height, the space between rows, and the most rows in a column.
local LABEL_WIDTH, LABEL_GAP = 110, 6
local NAMED_COLUMN_SPACING = 14
local MAX_NAMED_ROWS = 8
local NAME_ROW_HEIGHT, NAME_ROW_SPACING = 20, 2
local MAX_NAME_ROWS = 12

local OPEN_TIME, CLOSE_TIME = 0.28, 0.2
-- How far it slides while it fades in.
local SLIDE_DISTANCE = 14
-- Seconds between one column of buttons appearing and the next.
local STAGGER = 0.03

local holder, panel
-- The shown buttons' frames, in order (see LauncherButton).
local shownFrames = {}

local isOpen = false
-- Whether the launcher is hovered (the menu lights up with it).
local isHovered = false
-- Open all the time (the Always open style): no animation, and it can't be closed.
local isAlwaysOpen = false
-- 0 = closed, 1 = open; animated in between.
local progress = 0
local animation -- { from, to, elapsed, duration } of the last animation (the table is reused)
-- "LEFT", "RIGHT", "UP" or "DOWN": the way it slides out.
local direction = "LEFT"
local onProgress -- function(progress), to move the launcher along
local frameLevel = 1
-- isByColumn: the buttons go down each column before the next (with names, or a set number per
-- column), instead of along each row.
local layout = {
    columns = 1, rows = 1, size = 0, cell = 0, cellX = 0, width = 0, height = 0, isByColumn = false,
}

local function EaseOut(x)
    return 1 - (1 - x) ^ 3
end

-- Size ----------------------------------------------------------------------------------------

-- Fits the menu to count buttons. With a number of buttons per column set (ns.db.menuRows), that
-- many down each column, and as many columns as needed. Otherwise rows from RowsFor, as many
-- columns as needed, and at least MIN_COLUMNS by MIN_ROWS; with names, columns of up to
-- MAX_NAMED_ROWS (MAX_NAME_ROWS with names only).
local function UpdateSize(count)
    local labels = ns.db.menuLabels
    local isNameOnly = labels == "names"
    local size = isNameOnly and NAME_ROW_HEIGHT or ns.db.launcher.buttonSize
    local spacingY = isNameOnly and NAME_ROW_SPACING or BUTTON_SPACING
    local cell = size + spacingY
    local item, spacingX
    if labels == "both" then
        item, spacingX = size + LABEL_GAP + LABEL_WIDTH, NAMED_COLUMN_SPACING
    elseif isNameOnly then
        item, spacingX = LABEL_WIDTH, NAMED_COLUMN_SPACING
    else
        item, spacingX = size, BUTTON_SPACING
    end
    local rows, minColumns, minRows
    local perColumn = ns.db.menuRows
    if perColumn > 0 then
        rows, minColumns, minRows = math.max(1, math.min(count, perColumn)), 1, 1
    elseif labels ~= "icons" then
        rows = math.max(1, math.min(count, isNameOnly and MAX_NAME_ROWS or MAX_NAMED_ROWS))
        minColumns, minRows = 1, MIN_ROWS
    else
        rows, minColumns, minRows = RowsFor(count), MIN_COLUMNS, MIN_ROWS
    end
    local columns = math.max(1, math.ceil(count / rows))
    layout.isByColumn = perColumn > 0 or labels ~= "icons"
    layout.size = size
    layout.columns, layout.cell, layout.cellX = columns, cell, item + spacingX
    layout.height = math.max(minRows, rows) * cell - spacingY + 2 * PADDING
    layout.width = math.max(minColumns, columns) * layout.cellX - spacingX + 2 * PADDING
    layout.rows = layout.isByColumn and rows or math.ceil(count / columns)
    panel:SetSize(layout.width, layout.height)
end

local function IsVertical()
    return direction == "UP" or direction == "DOWN"
end

-- "LEFT", "RIGHT", "UP" or "DOWN": the way it opens.
function Menu.GetDirection()
    return direction
end

function Menu.GetSize()
    return layout.width, layout.height
end

-- Drawing --------------------------------------------------------------------------------------

-- For each direction: the holder's point at the launcher, and the far end the panel is
-- fixed to.
local ANCHORS = {
    LEFT = { "RIGHT", "LEFT" },
    RIGHT = { "LEFT", "RIGHT" },
    UP = { "BOTTOM", "TOP" },
    DOWN = { "TOP", "BOTTOM" },
}

-- One step in each direction the menu can open.
local STEPS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

-- Shows the menu as it is at the current progress.
local function Draw()
    holder:SetSize(layout.width, layout.height)
    -- Fading in, it starts the slide distance back toward the launcher.
    local far = ANCHORS[direction][2]
    local back = SLIDE_DISTANCE * (1 - progress)
    local stepX, stepY = unpack(STEPS[direction])
    panel:ClearAllPoints()
    panel:SetPoint(far, holder, far, -stepX * back, -stepY * back)
    panel:SetAlpha(progress)
    holder:SetShown(progress > 0)
    if onProgress then
        onProgress(progress)
    end
end

local function OnUpdate(_, elapsed)
    animation.elapsed = animation.elapsed + elapsed
    local x = math.min(1, animation.elapsed / animation.duration)
    progress = animation.from + (animation.to - animation.from) * EaseOut(x)
    Draw()
    if x >= 1 then
        holder:SetScript("OnUpdate", nil)
    end
end

local function Animate(to, duration)
    animation = animation or {}
    animation.from, animation.to, animation.elapsed, animation.duration = progress, to, 0, duration
    holder:Show()
    holder:SetScript("OnUpdate", OnUpdate)
end

-- Buttons --------------------------------------------------------------------------------------

-- Gets the frames for the launcher's buttons and puts them in the panel, left to right, row by
-- row. Opening, they pop in from the launcher's side outward.
local function UpdateButtons(withAnimation)
    local buttons = ns.Buttons.GetLauncherButtons()
    UpdateSize(#buttons)
    local keys = {}
    wipe(shownFrames)
    for index, button in ipairs(buttons) do
        local column = (index - 1) % layout.columns
        local row = math.floor((index - 1) / layout.columns)
        if layout.isByColumn then
            column, row = math.floor((index - 1) / layout.rows), (index - 1) % layout.rows
        end
        local buttonFrame = ns.LauncherButton.Get(panel, button)
        ns.LauncherButton.SetLook(buttonFrame, ns.db.menuLabels, layout.size, LABEL_WIDTH)
        buttonFrame:SetFrameLevel(panel:GetFrameLevel() + 2)
        buttonFrame:ClearAllPoints()
        buttonFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING + column * layout.cellX,
            -PADDING - row * layout.cell)
        -- A hand-made button's own frame goes over it, once it's sized and in its layer.
        if button.source == "frame" then
            ns.Handmade.Attach(button, buttonFrame)
        end
        keys[button.key] = true
        shownFrames[index] = buttonFrame
        if isOpen then
            if withAnimation then
                -- Columns (or rows, sliding up or down) nearest the launcher first.
                local fromLauncher = direction == "LEFT" and layout.columns - 1 - column
                    or direction == "RIGHT" and column
                    or direction == "UP" and layout.rows - 1 - row
                    or row
                ns.LauncherButton.Appear(buttonFrame, 0.04 + fromLauncher * STAGGER)
            else
                ns.LauncherButton.ShowNow(buttonFrame)
            end
        end
    end
    ns.LauncherButton.HideOthers(keys)
end

-- Placing --------------------------------------------------------------------------------------

-- Space kept between the menu and the screen's edges.
local SCREEN_MARGIN = 4

-- How far to move the menu so it stays on the screen: x, y in the holder's units, for an anchor at
-- relativeTo's relativePoint moved by x, y. Across the way it opens (it's centred on its launcher
-- that way), e.g. beside a launcher near the screen's top; and the way it opens too, e.g. near the
-- screen's left edge.
local POINT_SHARES = { LEFT = 0, RIGHT = 1, BOTTOM = 0, TOP = 1 }
local function GetScreenShift(relativeTo, relativePoint, x, y)
    local left, bottom, width, height = relativeTo:GetRect()
    if not left then
        return 0, 0
    end
    local uiScale = UIParent:GetEffectiveScale()
    local toScreen = relativeTo:GetEffectiveScale() / uiScale
    local holderToScreen = holder:GetEffectiveScale() / uiScale
    -- The anchor on the screen, and the menu's size there.
    local shareX = POINT_SHARES[relativePoint:match("LEFT") or relativePoint:match("RIGHT") or ""] or 0.5
    local shareY = POINT_SHARES[relativePoint:match("BOTTOM") or relativePoint:match("TOP") or ""] or 0.5
    local anchorX = (left + width * shareX) * toScreen + x * holderToScreen
    local anchorY = (bottom + height * shareY) * toScreen + y * holderToScreen
    local menuWidth, menuHeight = layout.width * holderToScreen, layout.height * holderToScreen
    -- The menu's low and high ends on each axis.
    local lowX, lowY = anchorX - menuWidth / 2, anchorY - menuHeight / 2
    if direction == "LEFT" then
        lowX = anchorX - menuWidth
    elseif direction == "RIGHT" then
        lowX = anchorX
    elseif direction == "UP" then
        lowY = anchorY
    else
        lowY = anchorY - menuHeight
    end
    local function Shift(low, length, screenLength)
        if low < SCREEN_MARGIN then
            return SCREEN_MARGIN - low
        elseif low + length > screenLength - SCREEN_MARGIN then
            return screenLength - SCREEN_MARGIN - low - length
        end
        return 0
    end
    local shiftX = Shift(lowX, menuWidth, UIParent:GetWidth())
    local shiftY = Shift(lowY, menuHeight, UIParent:GetHeight())
    return shiftX / holderToScreen, shiftY / holderToScreen
end

-- Puts the menu's launcher-side end at (relativeTo, relativePoint, x, y), sliding out toward
-- newDirection ("LEFT", "RIGHT", "UP" or "DOWN"), moved as far as it takes to stay on the screen
-- (see GetScreenShift); it moves and hides with parent. The holder is where the menu is once open;
-- the panel slides into it (see Draw).
function Menu.Place(parent, relativeTo, relativePoint, x, y, newDirection)
    direction = newDirection
    holder:SetParent(parent)
    -- A new parent can change the frame level; keep the style's.
    Menu.SetFrameLevel(frameLevel)
    holder:ClearAllPoints()
    local near = ANCHORS[direction][1]
    local shiftX, shiftY = GetScreenShift(relativeTo, relativePoint, x, y)
    holder:SetPoint(near, relativeTo, relativePoint, x + shiftX, y + shiftY)
    Draw()
end

-- How far the menu still moves until it's open (x, y in UIParent's units): the rest of the slide.
-- 0, 0 once it's open.
function Menu.GetDistanceToOpen()
    local stepX, stepY = unpack(STEPS[direction])
    local rest = SLIDE_DISTANCE * (1 - progress)
    rest = rest * holder:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return stepX * rest, stepY * rest
end

-- The menu's frame level; its buttons go 3 above.
function Menu.SetFrameLevel(level)
    frameLevel = level
    holder:SetFrameLevel(level)
    panel:SetFrameLevel(level + 1)
end

-- Opening and closing --------------------------------------------------------------------------

function Menu.IsOpen()
    return isOpen
end

function Menu.Open()
    isOpen = true
    UpdateButtons(true)
    ns.Alert.OnMenuOpened()
    Animate(1, OPEN_TIME)
end

function Menu.Close()
    if isAlwaysOpen then
        return
    end
    isOpen = false
    ns.Settings.Hide()
    for _, buttonFrame in ipairs(shownFrames) do
        ns.LauncherButton.Disappear(buttonFrame)
    end
    ns.Alert.OnMenuClosed()
    Animate(0, CLOSE_TIME)
end

function Menu.Toggle()
    if isOpen then
        Menu.Close()
    else
        Menu.Open()
    end
end

-- Starts over for a style: closed, or open for good; callback(progress) moves its launcher.
function Menu.Reset(alwaysOpen, callback)
    isAlwaysOpen = alwaysOpen
    isOpen = alwaysOpen
    progress = alwaysOpen and 1 or 0
    animation = nil
    holder:SetScript("OnUpdate", nil)
    onProgress = callback
end

-- Sizes the menu for the buttons it shows, without placing them (for the style to place it).
function Menu.Measure()
    UpdateSize(#ns.Buttons.GetLauncherButtons())
end

-- Redraws after the buttons or settings changed (the border colour too).
function Menu.Refresh()
    UpdateButtons(false)
    Theme.SetBoxHovered(panel.fill, panel.border, isHovered)
    Draw()
end

-- Lights up while the launcher is hovered; its border is in the launcher's border colour.
function Menu.SetHovered(hovered)
    isHovered = hovered
    Theme.SetBoxHovered(panel.fill, panel.border, isHovered)
end

-- The panel, e.g. to drag the Always open style by.
function Menu.GetPanel()
    return panel
end

-- The panel takes the mouse, so clicks on its background don't reach the game world behind it.
-- A right-click there opens the settings, as on the launcher (the Always open style has none).
function Menu.Setup()
    holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()
    panel = CreateFrame("Frame", nil, holder)
    panel:EnableMouse(true)
    panel.fill, panel.border = Theme.AddBox(panel, Theme.PANEL_FILL, Theme.PANEL_BORDER, Theme.PANEL_RADIUS)
    panel:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "RightButton" and self:IsMouseOver() then
            ns.Settings.Toggle()
        end
    end)
end
