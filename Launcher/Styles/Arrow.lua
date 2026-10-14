local _, ns = ...

-- The compass arrow style: the minimap's own north compass arrow, turned west, in the place of
-- the west arrow (taken off the compass, see Compass) or just outside it, with a + beside it. The
-- menu slides and fades in to the left, and the arrow rides out to its far end, just left of it.
-- Without room on the left (the minimap at the screen's left edge), all of it is mirrored to the
-- east: the arrow turned east, at the east arrow, and the menu opening to the right.
--
-- What a style has (the Launcher calls these):
--   Show(), Hide()          make and show its frames, or hide them
--   Refresh()               place them, and the menu (Menu.Place), from the settings
--   OnProgress(progress)    follow the menu opening (0) to open (1)
--   SetHovered(isHovered)   light up while the mouse is over it
--   isMovable               whether it can be dragged (then OnDragStart(), OnDragStop() and
--                           isDragging; see Launcher.SetupMover); alwaysOpen for a style without
--                           a launcher (see AlwaysOpen.lua)
local Theme = ns.Theme
local Style = {}
ns.Styles.arrow = Style

-- The minimap's west compass arrow, as shares of the minimap's half width (measured in game): how
-- far its tip reaches, and half its height; and the ring's outer edge.
local COMPASS_TIP_SHARE = 1.08
local COMPASS_HALF_HEIGHT_SHARE = 0.11
local RING_OUTER_SHARE = 1.03
-- The arrow is the compass's own north arrow turned west (see Compass.GetNorthArrowArt), just the
-- part outside the ring (the ring behind its base would go along when it moves), this much bigger,
-- growing out from the ring's edge: in place, its base is on the ring's edge. Its tip is this share
-- of the whole art's width in from its left end.
local ART_SCALE = 1.25
local ART_TIP_INSET = 0.12
-- Mirrored to the east, everything moves this much further left (set by eye in game): the east
-- side of Blizzard's compass art isn't quite the west side mirrored.
local EAST_NUDGE = 4
-- Without a compass, Satellite's own arrow texture: its size in compass arrow half heights, and
-- how far its shape reaches left and right of its center, as shares of its size (see
-- tools/generate_textures.py).
local OWN_SCALE = 3.2
local OWN_LEFT_SHARE, OWN_RIGHT_SHARE = 0.34, 0.23
-- Space between the open menu's left end and the right end of the arrow's shape.
local MENU_GAP = 4
-- The + left of the tip: its font size, and how far down it's moved to sit level with the tip (the
-- font draws it a little above the middle of its line).
local PLUS_SIZE = 28
local PLUS_DROP = 2.5
-- The smallest area the arrow takes clicks in, however small it's drawn.
local MIN_HIT_SIZE = 26

local frame, arrow
-- Where the arrow is, worked out on the west side: its center while closed, and its tip and right
-- end from its center; where the menu's right end is. And whether it's all mirrored to the east
-- (see Refresh).
local closedX, tipOffset, rightOffset, menuRight = 0, 0, 0, 0
local isEast = false
-- How far right of the minimap's middle the compass ring's middle is (see Compass.GetRingOffset).
local ringOffset = 0

local function Create()
    -- On the minimap, so it moves, scales and hides with it.
    frame = CreateFrame("Frame", "SatelliteArrowLauncher", Minimap)
    frame:SetSize(1, 1)
    frame:SetPoint("CENTER", Minimap, "CENTER")
    arrow = CreateFrame("Button", nil, frame)
    arrow.shadow = Theme.AddTexture(arrow, Theme.ARROW_SHADOW, "ARTWORK", 0, Theme.OUTLINE)
    arrow.art = Theme.AddTexture(arrow, Theme.ARROW, "ARTWORK", 1, Theme.GOLD)
    -- The same art again, added on top while hovered, to light it up.
    arrow.glow = Theme.AddTexture(arrow, Theme.ARROW, "ARTWORK", 2, Theme.GOLD)
    arrow.glow:SetBlendMode("ADD")
    arrow.glow:SetAlpha(0.45)
    arrow.glow:Hide()
    -- A + left of the tip, to show the arrow opens something; hidden while the menu is open.
    arrow.plus = arrow:CreateFontString(nil, "OVERLAY")
    arrow.plus:SetFont(STANDARD_TEXT_FONT, PLUS_SIZE, "OUTLINE")
    arrow.plus:SetText("+")
    arrow.plus:SetTextColor(Theme.GOLD:GetRGB())
    arrow.pop = Theme.CreatePop(arrow)
    ns.Launcher.SetupOpener(arrow)
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

-- Draws the arrow with the compass's own north arrow, or Satellite's texture without one (turned
-- east, if it's mirrored), and sizes and places it: its base on the ring where the west arrow was,
-- or beside the west arrow. Sets closedX, tipOffset and rightOffset, on the west side.
local function Layout(half)
    local isInPlace = ns.Compass.IsReplaced()
    local compassTip = -half * COMPASS_TIP_SHARE
    local art = ns.Compass.GetNorthArrowArt()
    local width, height, tipX
    if art then
        local scale = ART_SCALE * ns.Launcher.GetScale()
        width, height = (art.pivot - art.x0) * scale, (art.y1 - art.y0) * scale
        local rightX
        if isInPlace then
            rightX = art.pivot
        else
            -- Its right end at the compass arrow's tip, less the distance setting.
            rightX = compassTip - ns.db.launcher.gap
        end
        closedX = rightX - width / 2
        tipX = rightX - width + (art.x1 - art.x0) * scale * ART_TIP_INSET
        for _, texture in ipairs({ arrow.art, arrow.glow }) do
            texture:SetTexture(art.file)
            ---@diagnostic disable-next-line: redundant-parameter
            texture:SetTexCoord(unpack(isEast and art.eastCoords or art.outerCoords))
            texture:SetVertexColor(unpack(art.color))
        end
        arrow.art:SetBlendMode(MinimapCompassTexture:GetBlendMode())
        arrow.shadow:Hide()
    else
        local size = half * COMPASS_HALF_HEIGHT_SHARE * OWN_SCALE * ns.Launcher.GetScale()
        width, height = size, size
        if isInPlace then
            tipX = compassTip
        else
            tipX = compassTip - ns.db.launcher.gap - size * (OWN_LEFT_SHARE + OWN_RIGHT_SHARE)
        end
        closedX = tipX + size * OWN_LEFT_SHARE
        arrow.shadow:Show()
        -- The texture points left: mirrored, it points right.
        local left, right = isEast and 1 or 0, isEast and 0 or 1
        arrow.shadow:SetTexCoord(left, right, 0, 1)
        for _, texture in ipairs({ arrow.art, arrow.glow }) do
            texture:SetTexture(Theme.ARROW)
            texture:SetTexCoord(left, right, 0, 1)
            texture:SetVertexColor(Theme.GOLD:GetRGBA())
        end
        arrow.art:SetBlendMode("BLEND")
    end
    tipOffset, rightOffset = tipX - closedX, width / 2
    arrow:SetSize(width, height)
    local growX, growY = math.max(0, (MIN_HIT_SIZE - width) / 2), math.max(0, (MIN_HIT_SIZE - height) / 2)
    arrow:SetHitRectInsets(-growX, -growX, -growY, -growY)
end

-- In the strata of Blizzard's expansion button on the minimap (e.g. the Omnium Folio), below it,
-- so it draws over the menu; the arrow over the minimap's compass, as the compass arrow it
-- replaces was.
local function UpdateFrameLevels()
    local strata, buttonLevel = ns.Blizzard.GetMinimapLayer()
    if strata then
        frame:SetFrameStrata(strata)
        frame:SetFrameLevel(math.max(1, buttonLevel - 6))
    end
    local level = frame:GetFrameLevel()
    ns.Menu.SetFrameLevel(level + 1)
    arrow:SetFrameLevel(math.max(level + 5, ns.Compass.GetFrameLevel() + 1))
end

-- On the west side, or mirrored to the east: 1 or -1, for distances worked out on the west.
local function GetMirror()
    return isEast and -1 or 1
end

-- A place worked out on the west side (x from the minimap's middle), on the side it's on now:
-- mirrored around the compass ring's middle.
local function ToSide(x)
    return isEast and 2 * ringOffset - x - EAST_NUDGE or x
end

function Style:Refresh()
    local half = Minimap:GetWidth() / 2
    Layout(half)
    -- The menu comes out from under the arrow, but outside the minimap's ring.
    menuRight = math.min(closedX + rightOffset, -half * RING_OUTER_SHARE - 2)
    -- Room on the screen for the open menu and the arrow beside it on the west? If not, on the
    -- east, when there's room there.
    local reach = ns.Menu.GetSize() + MENU_GAP + 2 * rightOffset - menuRight
    local x = frame:GetCenter()
    local toScreen = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local east = x ~= nil and (x - reach) * toScreen < 0
        and (x + reach) * toScreen <= UIParent:GetWidth()
    ns.Compass.SetSide(east and 1 or -1)
    ringOffset = ns.Compass.GetRingOffset()
    if east ~= isEast then
        isEast = east
        ns:Debug(format("Arrow on the %s side; compass ring %.1f off the minimap's middle",
            east and "east" or "west", ringOffset))
        Layout(half)
    end
    local mirror = GetMirror()
    arrow.plus:ClearAllPoints()
    arrow.plus:SetPoint(isEast and "LEFT" or "RIGHT", arrow, "CENTER", mirror * (tipOffset - 1),
        -PLUS_DROP)
    UpdateFrameLevels()
    ns.Menu.Place(frame, frame, "CENTER", ToSide(menuRight), 0, isEast and "RIGHT" or "LEFT")
end

-- The arrow rides along with the menu, just outside it; the + fades.
function Style:OnProgress(progress)
    local width = ns.Menu.GetSize()
    local openX = menuRight - width - rightOffset - MENU_GAP
    local x = closedX + (openX - closedX) * progress
    arrow:SetPoint("CENTER", frame, "CENTER", ToSide(x), 0)
    arrow.plus:SetAlpha(1 - math.min(1, progress * 3))
end

-- A short pop of the arrow, to show a new button (see Launcher.Pulse).
function Style:Pulse()
    arrow.pop:Play()
end

-- The alert dot (see Alert): above the arrow.
function Style:GetAlertPoint()
    return arrow, "TOP", 0, 0
end

function Style:SetHovered(isHovered)
    arrow.glow:SetShown(isHovered)
    arrow.plus:SetTextColor((isHovered and Theme.GOLD_HOVER or Theme.GOLD):GetRGB())
end

