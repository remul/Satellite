local _, ns = ...

-- Takes the west arrow off the minimap's compass, so the launcher's arrow can sit in its place.
-- Blizzard draws the ring and all four compass arrows as one texture (MinimapCompassTexture), so
-- it can't be hidden on its own: the texture is redrawn from pieces of itself, leaving out the
-- square with the west arrow, and that square is filled with plain ring from right beside it: its
-- upper half from just above, its lower half from just below, each turned a little to fit. The
-- ring's shading changes slowly around it, so copies from close by match their neighbours.
--
-- Only on a round minimap that doesn't rotate: a rotating compass turns with the map, and a square
-- minimap has no whole ring. Otherwise the original stays.
local Compass = {}
ns.Compass = Compass

-- Measures as shares of the minimap's half width: the radius the ring is copied around (the
-- ring is about there; it only has to lie inside the square), and the square's size, which has to
-- hold the west arrow (it reaches 1.08 out and 0.11 up and down).
local RING_SHARE = 1.0
local SQUARE_SHARE = 0.3
-- How far round the halves are copied from, in degrees: just clear of the west arrow (it spans
-- about 6.3 degrees each way), so the copies come from as close by as possible.
local COPY_DEGREES = 9
-- The north arrow's art, as shares of the minimap's half width (measured in game): from a little
-- inside the ring's outer edge (its base overlaps the ring, so the bit of ring behind the base
-- comes along) to past its tip, and this far either side of the middle. RING_PIVOT is about the
-- ring's outer edge: drawn bigger, the arrow grows out from there, so the ring behind its base
-- stays on the ring.
local NORTH_INNER_SHARE, NORTH_OUTER_SHARE = 0.94, 1.2
local NORTH_HALF_WIDTH_SHARE = 0.21
local RING_PIVOT_SHARE = 0.99

local holder -- frame for the pieces, over the compass
-- The compass's own colour and alpha, read just before it's hidden: hiding it (SetAlpha) changes
-- what GetVertexColor returns, so reading them later would copy the hidden state onto the pieces.
local originalColor, originalAlpha
local pieces = {}
local isReplaced = false

-- The compass texture's file and its corner coordinates within it (it's an atlas).
local function GetSource(compass)
    local atlas = compass:GetAtlas()
    local info = atlas and C_Texture.GetAtlasInfo(atlas)
    if info then
        return info.file or info.filename, info.leftTexCoord, info.rightTexCoord, info.topTexCoord,
            info.bottomTexCoord
    end
    local file = compass:GetTexture()
    if not file then
        return nil
    end
    local left, top, _, bottom, right = compass:GetTexCoord()
    return file, left, right, top, bottom
end

local function GetPiece(index)
    local piece = pieces[index]
    if not piece then
        piece = holder:CreateTexture()
        pieces[index] = piece
    end
    return piece
end

-- Where things are on the compass texture, in its own units from its top left (y going down):
-- the file, U(x) and V(y) for its texture coordinates, the minimap's center and half width, and
-- the scale from the minimap's units to the compass's. Nil before the compass has its size.
local function Measure(compass)
    local file, left, right, top, bottom = GetSource(compass)
    local width, height = compass:GetSize()
    local minimapX, minimapY = Minimap:GetCenter()
    local compassLeft, compassTop = compass:GetLeft(), compass:GetTop()
    if not file or not minimapX or not compassLeft or width == 0 or height == 0 then
        return nil
    end
    local scale = Minimap:GetEffectiveScale() / compass:GetEffectiveScale()
    return {
        file = file,
        scale = scale,
        centerX = minimapX * scale - compassLeft,
        centerY = compassTop - minimapY * scale,
        half = Minimap:GetWidth() / 2 * scale,
        U = function(x)
            return left + (right - left) * x / width
        end,
        V = function(y)
            return top + (bottom - top) * y / height
        end,
    }
end

-- Builds the pieces.
local function Build(compass)
    local m = Measure(compass)
    if not m then
        return false
    end
    local file, U, V = m.file, m.U, m.V
    local width, height = compass:GetSize()
    local centerX, centerY, half = m.centerX, m.centerY, m.half
    local radius, size = half * RING_SHARE, half * SQUARE_SHARE
    local layer, subLevel = compass:GetDrawLayer()
    local r, g, b, a = unpack(originalColor)
    local function Place(piece, x0, y0, x1, y1)
        piece:SetTexture(file)
        piece:SetDrawLayer(layer, subLevel)
        piece:SetVertexColor(r, g, b, a)
        piece:SetBlendMode(compass:GetBlendMode())
        piece:ClearAllPoints()
        piece:SetPoint("TOPLEFT", holder, "TOPLEFT", x0, -y0)
        piece:SetSize(x1 - x0, y1 - y0)
        piece:Show()
    end

    -- The square with the west arrow.
    local squareLeft, squareRight = centerX - radius - size / 2, centerX - radius + size / 2
    local squareTop, squareBottom = centerY - size / 2, centerY + size / 2

    -- Everything else: right of the square, and above and below it.
    local regions = {
        { squareRight, 0, width, height },
        { 0, 0, squareRight, squareTop },
        { 0, squareBottom, squareRight, height },
    }
    for index, region in ipairs(regions) do
        local piece = GetPiece(index)
        local x0, y0, x1, y1 = unpack(region)
        Place(piece, x0, y0, x1, y1)
        piece:SetTexCoord(U(x0), U(x1), V(y0), V(y1))
    end

    -- The square, in two halves: each corner of a half, turned around the minimap's center by
    -- COPY_DEGREES (the upper half clockwise, up the ring; the lower one the other way), lands on
    -- the spot to copy.
    local h = size / 2
    local function FillHalf(piece, upper)
        local turn = math.rad(upper and -COPY_DEGREES or COPY_DEGREES)
        local cos, sin = math.cos(turn), math.sin(turn)
        local function Source(dx, dy)
            -- (dx, dy): the corner from the square's center, y going up.
            local x, y = -radius + dx, dy
            return U(centerX + x * cos - y * sin), V(centerY - (x * sin + y * cos))
        end
        local topY, bottomY = upper and h or 0, upper and 0 or -h
        Place(piece, squareLeft, centerY - topY, squareRight, centerY - bottomY)
        local ulX, ulY = Source(-h, topY)
        local llX, llY = Source(-h, bottomY)
        local urX, urY = Source(h, topY)
        local lrX, lrY = Source(h, bottomY)
        -- The eight-value form: upper left, lower left, upper right, lower right corners.
        ---@diagnostic disable-next-line: redundant-parameter
        piece:SetTexCoord(ulX, ulY, llX, llY, urX, urY, lrX, lrY)
    end
    FillHalf(GetPiece(#regions + 1), true)
    FillHalf(GetPiece(#regions + 2), false)
    return true
end

-- Not on a minimap that isn't round all the way: its compass isn't a whole ring to redraw.
local function CanReplace()
    return ns.db.style == "arrow" and ns.db.replaceCompassArrow and MinimapCompassTexture ~= nil
        and not GetCVarBool("rotateMinimap") and ns.Launcher.IsMinimapRound()
end

-- The compass's own north arrow, turned to point west, to draw as the launcher's arrow: its file,
-- the texture coordinates of the part outside the ring (the eight-value form, turning it), and
-- where it would be pointing west in the minimap's units around its center: { file, outerCoords,
-- x0, x1, y0, y1, pivot, color } (pivot: the ring's outer edge, see RING_PIVOT_SHARE). Nil
-- without a compass.
function Compass.GetNorthArrowArt()
    local compass = MinimapCompassTexture
    local m = compass and Measure(compass)
    if not m then
        return nil
    end
    -- On the compass, in its units from its top left (y going down), kept on the texture.
    local half = m.half
    local left, right = m.centerX - half * NORTH_HALF_WIDTH_SHARE, m.centerX + half * NORTH_HALF_WIDTH_SHARE
    local top = math.max(0, m.centerY - half * NORTH_OUTER_SHARE)
    local bottom = m.centerY - half * NORTH_INNER_SHARE
    local uLeft, uRight, vTop = m.U(left), m.U(right), m.V(top)
    local vPivot = m.V(m.centerY - half * RING_PIVOT_SHARE)
    local depth, width = (bottom - top) / m.scale, (right - left) / m.scale
    local inner = half / m.scale * NORTH_INNER_SHARE
    local pivot = -half / m.scale * RING_PIVOT_SHARE
    return {
        file = m.file,
        -- Turned a quarter counterclockwise: the tip (the top) to the left.
        outerCoords = { uRight, vTop, uLeft, vTop, uRight, vPivot, uLeft, vPivot },
        x0 = -inner - depth, x1 = -inner, y0 = -width / 2, y1 = width / 2, pivot = pivot,
        -- While the compass is hidden, the colour it had.
        color = isReplaced and originalColor or { compass:GetVertexColor() },
    }
end

-- The frame level of the compass's pieces (or 0), for the launcher's arrow to go over them.
function Compass.GetFrameLevel()
    return holder and holder:GetFrameLevel() or 0
end

-- Whether the west arrow is taken off now (the launcher's arrow then sits in its place).
function Compass.IsReplaced()
    return isReplaced
end

-- Takes the west arrow off or puts it back, as the settings say. Called again when the minimap's
-- size changes.
function Compass.Update()
    local compass = MinimapCompassTexture
    if not compass or not holder then
        return
    end
    local wasReplaced, canReplace = isReplaced, CanReplace()
    if canReplace and not wasReplaced then
        originalColor = { compass:GetVertexColor() }
        originalAlpha = compass:GetAlpha()
    end
    isReplaced = canReplace and Build(compass)
    holder:SetShown(isReplaced and compass:IsShown())
    -- Its alpha only changes when it's taken off or put back, so other addons (minimap skins)
    -- can set it otherwise.
    if isReplaced then
        compass:SetAlpha(0)
    elseif wasReplaced then
        compass:SetAlpha(originalAlpha)
    end
end

-- Called once ns.db is loaded; the pieces are made at login, once the minimap has its size.
function Compass:Setup()
    local compass = MinimapCompassTexture
    if not compass then
        return
    end
    holder = CreateFrame("Frame", nil, compass:GetParent())
    holder:SetAllPoints(compass)
    holder:Hide()
    -- Blizzard hides the compass in some places (e.g. inside player housing); the pieces follow.
    local function FollowShown()
        holder:SetShown(isReplaced and compass:IsShown())
    end
    hooksecurefunc(compass, "Show", FollowShown)
    hooksecurefunc(compass, "Hide", FollowShown)
    hooksecurefunc(compass, "SetShown", FollowShown)
    ns:RegisterEvent("CVAR_UPDATE", function(name)
        if name == "rotateMinimap" then
            ns.Launcher.Refresh()
        end
    end)
end
