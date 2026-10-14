local _, ns = ...

-- The menu every launcher style opens: a rounded panel with the buttons in rows, sliding out to
-- the left, right, up or down from where the style puts it: a short way from the launcher's side
-- as it fades in, or (for the compass arrow, which rides along in front of it) uncovered from that
-- spot by a clipping frame that grows from there.
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
-- With names (a setting): each name's width beside its button, the space between columns, and
-- the most buttons in a column; the buttons then go down the columns, like a list.
local LABEL_WIDTH, LABEL_GAP = 110, 6
local NAMED_COLUMN_SPACING = 14
local MAX_NAMED_ROWS = 8

local OPEN_TIME, CLOSE_TIME = 0.28, 0.2
-- How far it slides while it fades in (when not uncovered).
local SLIDE_DISTANCE = 14
-- Seconds between one column of buttons appearing and the next.
local STAGGER = 0.03

local clip, panel
-- The shown buttons' frames, in order (see LauncherButton).
local shownFrames = {}

local isOpen = false
-- Open all the time (the Always open style): no animation, and it can't be closed.
local isAlwaysOpen = false
-- 0 = closed, 1 = open; animated in between.
local progress = 0
local animation -- { from, to, elapsed, duration } of the last animation (the table is reused)
-- "LEFT", "RIGHT", "UP" or "DOWN": the way it slides out; and whether it's uncovered by the
-- clipping frame (see Place) instead of fading in.
local direction = "LEFT"
local isUncovered = false
local onProgress -- function(progress), to move the launcher along
local frameLevel = 1
-- isByColumn: the buttons go down each column before the next (with names, or a set number per
-- column), instead of along each row.
local layout = { columns = 1, rows = 1, cell = 0, cellX = 0, width = 0, height = 0, isByColumn = false }

local function EaseOut(x)
    return 1 - (1 - x) ^ 3
end

-- Size ----------------------------------------------------------------------------------------

-- Fits the menu to count buttons. With a number of buttons per column set (ns.db.menuRows), that
-- many down each column, and as many columns as needed. Otherwise rows from RowsFor, as many
-- columns as needed, and at least MIN_COLUMNS by MIN_ROWS; with names, columns of up to
-- MAX_NAMED_ROWS.
local function UpdateSize(count)
    local size = ns.db.launcher.buttonSize
    local cell = size + BUTTON_SPACING
    local item, spacingX
    if ns.db.showNames then
        item, spacingX = size + LABEL_GAP + LABEL_WIDTH, NAMED_COLUMN_SPACING
    else
        item, spacingX = size, BUTTON_SPACING
    end
    local rows, minColumns, minRows
    local perColumn = ns.db.menuRows
    if perColumn > 0 then
        rows, minColumns, minRows = math.max(1, math.min(count, perColumn)), 1, 1
    elseif ns.db.showNames then
        rows, minColumns, minRows = math.max(1, math.min(count, MAX_NAMED_ROWS)), 1, MIN_ROWS
    else
        rows, minColumns, minRows = RowsFor(count), MIN_COLUMNS, MIN_ROWS
    end
    local columns = math.max(1, math.ceil(count / rows))
    layout.isByColumn = perColumn > 0 or ns.db.showNames
    layout.columns, layout.cell, layout.cellX = columns, cell, item + spacingX
    layout.height = math.max(minRows, rows) * cell - BUTTON_SPACING + 2 * PADDING
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

-- For each direction: the clipping frame's point at the launcher, and the far end the panel is
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
    local share = isUncovered and progress or 1
    if IsVertical() then
        clip:SetSize(layout.width, math.max(0.1, layout.height * share))
    else
        clip:SetSize(math.max(0.1, layout.width * share), layout.height)
    end
    -- Fading in, it starts the slide distance back toward the launcher.
    local far = ANCHORS[direction][2]
    local back = isUncovered and 0 or SLIDE_DISTANCE * (1 - progress)
    local stepX, stepY = unpack(STEPS[direction])
    panel:ClearAllPoints()
    panel:SetPoint(far, clip, far, -stepX * back, -stepY * back)
    panel:SetAlpha(isUncovered and 1 or progress)
    clip:SetShown(progress > 0)
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
        clip:SetScript("OnUpdate", nil)
    end
end

local function Animate(to, duration)
    animation = animation or {}
    animation.from, animation.to, animation.elapsed, animation.duration = progress, to, 0, duration
    clip:Show()
    clip:SetScript("OnUpdate", OnUpdate)
end

-- Buttons --------------------------------------------------------------------------------------

-- Gets the frames for the launcher's buttons and puts them in the panel, left to right, row by
-- row. Opening, they pop in from the launcher's side outward.
local function UpdateButtons(withAnimation)
    local buttons = ns.Buttons.GetLauncherButtons()
    UpdateSize(#buttons)
    local size = ns.db.launcher.buttonSize
    local keys = {}
    wipe(shownFrames)
    for index, button in ipairs(buttons) do
        local column = (index - 1) % layout.columns
        local row = math.floor((index - 1) / layout.columns)
        if layout.isByColumn then
            column, row = math.floor((index - 1) / layout.rows), (index - 1) % layout.rows
        end
        local buttonFrame = ns.LauncherButton.Get(panel, button)
        ns.LauncherButton.SetSize(buttonFrame, size)
        ns.LauncherButton.SetLabel(buttonFrame, ns.db.showNames, LABEL_WIDTH)
        buttonFrame:SetFrameLevel(panel:GetFrameLevel() + 2)
        buttonFrame:ClearAllPoints()
        buttonFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING + column * layout.cellX,
            -PADDING - row * layout.cell)
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

-- The menu is centred on its launcher across the way it opens (up and down for a menu opening to
-- the side). How far to move it that way so it stays on the screen, e.g. beside a launcher near
-- the screen's top: x, y in the clipping frame's units, for an anchor at relativeTo's middle
-- moved by x, y.
local function GetScreenShift(relativeTo, x, y)
    local centerX, centerY = relativeTo:GetCenter()
    if not centerX then
        return 0, 0
    end
    local uiScale = UIParent:GetEffectiveScale()
    local toScreen = relativeTo:GetEffectiveScale() / uiScale
    local clipToScreen = clip:GetEffectiveScale() / uiScale
    local function Shift(middle, length, screenLength)
        local low, high = middle - length / 2, middle + length / 2
        if low < SCREEN_MARGIN then
            return SCREEN_MARGIN - low
        elseif high > screenLength - SCREEN_MARGIN then
            return screenLength - SCREEN_MARGIN - high
        end
        return 0
    end
    if IsVertical() then
        local middle = centerX * toScreen + x * clipToScreen
        return Shift(middle, layout.width * clipToScreen, UIParent:GetWidth()) / clipToScreen, 0
    end
    local middle = centerY * toScreen + y * clipToScreen
    return 0, Shift(middle, layout.height * clipToScreen, UIParent:GetHeight()) / clipToScreen
end

-- Puts the menu's launcher-side end at (relativeTo, relativePoint, x, y), sliding out toward
-- newDirection ("LEFT", "RIGHT", "UP" or "DOWN"), moved along that end as far as it takes to stay
-- on the screen; it moves and hides with parent. The panel is fixed to the clipping frame's far
-- end (see Draw). uncover: uncovered by the clipping frame growing from that end, instead of
-- fading in.
function Menu.Place(parent, relativeTo, relativePoint, x, y, newDirection, uncover)
    direction = newDirection
    isUncovered = uncover or false
    clip:SetClipsChildren(isUncovered)
    clip:SetParent(parent)
    -- A new parent can change the frame level; keep the style's.
    Menu.SetFrameLevel(frameLevel)
    clip:ClearAllPoints()
    local near = ANCHORS[direction][1]
    local shiftX, shiftY = GetScreenShift(relativeTo, x, y)
    clip:SetPoint(near, relativeTo, relativePoint, x + shiftX, y + shiftY)
    Draw()
end

-- The menu's frame level; its buttons go 3 above.
function Menu.SetFrameLevel(level)
    frameLevel = level
    clip:SetFrameLevel(level)
    panel:SetFrameLevel(level + 1)
end

-- Opening and closing --------------------------------------------------------------------------

function Menu.IsOpen()
    return isOpen
end

function Menu.Open()
    isOpen = true
    UpdateButtons(true)
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
    clip:SetScript("OnUpdate", nil)
    onProgress = callback
end

-- Sizes the menu for the buttons it shows, without placing them (for the style to place it).
function Menu.Measure()
    UpdateSize(#ns.Buttons.GetLauncherButtons())
end

-- Redraws after the buttons or settings changed.
function Menu.Refresh()
    UpdateButtons(false)
    Draw()
end

function Menu.SetHovered(isHovered)
    Theme.SetBoxHovered(panel.fill, panel.border, isHovered)
end

-- The panel, e.g. to drag the Always open style by.
function Menu.GetPanel()
    return panel
end

-- The panel takes the mouse, so clicks on its background don't reach the game world behind it.
function Menu.Setup()
    clip = CreateFrame("Frame", nil, UIParent)
    clip:SetClipsChildren(true)
    clip:Hide()
    panel = CreateFrame("Frame", nil, clip)
    panel:EnableMouse(true)
    panel.fill, panel.border = Theme.AddBox(panel, Theme.PANEL_FILL, Theme.PANEL_BORDER, Theme.PANEL_RADIUS)
end
