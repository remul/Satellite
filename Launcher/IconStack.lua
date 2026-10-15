local _, ns = ...

-- What the minimap button, circle and square show: Satellite's logo (the default), whose buttons
-- go round its orbit while it's hovered or open; the guild Prisma's, for its members; or the
-- player's class, spec or hero talent image. Spread (hovered or open), the logos grow a little.
local IconStack = {}
ns.IconStack = IconStack

local Theme = ns.Theme

-- The logos (ns.db.discSymbols): Satellite's symbol from its emblem (see tools/render_logos.sh),
-- in the border colour, whose buttons (orbiter) go round its orbit; and the guild Prisma's (its
-- crystal on its own, in its own colours), offered only to the guild's members. Each with its
-- texture, its part of the texture (left, right, top, bottom; the texture is square) and its
-- height as a share of the button's (its smaller side), so it stays inside any launcher's border
-- even grown; LOGO_GROWTH is how much bigger it gets spread.
local PRISMA_GUILD = "Prisma"
local LOGOS = {
    satellite = {
        texture = ns.MEDIA .. "SatelliteLogo", orbiter = ns.MEDIA .. "SatelliteLogoButtons",
        coords = { 0, 1, 0, 1 }, share = 0.7, isTinted = true,
    },
    prisma = { texture = ns.MEDIA .. "Prisma", coords = { 40 / 256, 216 / 256, 8 / 256, 252 / 256 }, share = 0.75 },
}
local LOGO_GROWTH = 0.075
-- The player's own images from the game, cut round (isMasked) with a dark outline (isRound): as big
-- as fits inside the launcher's border (fillsBorder), with IMAGE_OUTLINE and IMAGE_GAP around
-- them, not growing; and how much of each side is cut off, so their own edges and rims go: the
-- spec's square icon, and the class's icon and the hero talent tree's emblem, round with a rim.
-- IMAGE_BORDER is how far the border reaches in from the edge: the square's (see Theme.AddBox),
-- a pixel more than the round ones' (Theme.ROUND_BORDER).
local IMAGE_BORDER, IMAGE_OUTLINE, IMAGE_GAP = 3.5, 1.5, 0.5
-- The images' colour settings (ns.db.imageColors): grey, and tinted from grey; "full" is their
-- own colours.
local IMAGE_TINTS = {
    gray = CreateColor(1, 1, 1, 1),
    gold = CreateColor(1, 0.84, 0.5, 1),
    silver = CreateColor(0.86, 0.88, 0.93, 1),
    bronze = CreateColor(0.95, 0.7, 0.48, 1),
}
-- How they come alive while hovered or open (ns.db.imageAnimation): "glow" (a light of the image
-- over it, this bright at most), "turn" (a little, this far, against the clock, and stays there)
-- or "none".
local GLOW_ALPHA = 0.45
local TURN_ANGLE = math.rad(20)
local SPEC_IMAGE = { trim = 0.07 }
local EMBLEM_IMAGE = { trim = 0.12 }
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- Whether the player's character is in the guild Prisma (not known for a moment after login).
function IconStack.IsInPrisma()
    return GetGuildInfo("player") == PRISMA_GUILD
end

-- An image from texture's part (left, right, top, bottom), sized and trimmed as kind says. aspect
-- is how many times wider a step in the texture's coordinates is across than down (its texture
-- isn't always square), to turn it without stretching it (1 if nil).
local function MakeImage(texture, left, right, top, bottom, kind, aspect)
    local trimX, trimY = (right - left) * kind.trim, (bottom - top) * kind.trim
    return {
        texture = texture, coords = { left + trimX, right - trimX, top + trimY, bottom - trimY },
        aspect = aspect or 1, fillsBorder = true, isRound = true, isMasked = true, isSquare = true,
    }
end

-- An image from an atlas: its texture file and part, which can be trimmed (SetAtlas can't); or
-- nil if the game doesn't have it.
local function MakeAtlasImage(atlas, kind)
    local info = atlas and C_Texture.GetAtlasInfo(atlas)
    local file = info and (info.file or info.filename)
    if not file then
        return nil
    end
    local left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    -- The whole texture's width and height in pixels, from the part's.
    local aspect = (info.width / (right - left)) / (info.height / (bottom - top))
    return MakeImage(file, left, right, top, bottom, kind, aspect)
end

local function GetClassImage()
    local _, classFile = UnitClass("player")
    return MakeAtlasImage(GetClassAtlas(classFile), EMBLEM_IMAGE)
end

-- The spec's icon (a file), or nil without a spec (a new character).
local function GetSpecIcon()
    local index = C_SpecializationInfo.GetSpecialization()
    return index and select(4, C_SpecializationInfo.GetSpecializationInfo(index))
end

-- The spec's icon; without a spec, the class's.
local function GetSpecImage()
    local icon = GetSpecIcon()
    if not icon then
        return GetClassImage()
    end
    return MakeImage(icon, 0, 1, 0, 1, SPEC_IMAGE)
end

-- The active hero talent tree's emblem (an atlas), or nil below the level for one.
local function GetHeroAtlas()
    local subTreeID = C_ClassTalents.GetActiveHeroTalentSpec()
    local configID = C_ClassTalents.GetActiveConfigID()
    local info = subTreeID and configID and C_Traits.GetSubTreeInfo(configID, subTreeID)
    return info and info.iconElementID
end

-- The hero talent tree's emblem; without one, the spec's icon.
local function GetHeroImage()
    return MakeAtlasImage(GetHeroAtlas(), EMBLEM_IMAGE) or GetSpecImage()
end

local IMAGES = { classImage = GetClassImage, specImage = GetSpecImage, heroImage = GetHeroImage }

-- A small picture of a symbol for the settings' dropdown, as text markup (see GetSymbolPreview).
local PREVIEW_SIZE = 16

local function GetClassPreview()
    local _, classFile = UnitClass("player")
    return CreateAtlasMarkup(GetClassAtlas(classFile), PREVIEW_SIZE, PREVIEW_SIZE)
end

local function GetSpecPreview()
    local icon = GetSpecIcon()
    if not icon then
        return GetClassPreview()
    end
    -- Its edge cropped, as the launcher does (64 pixels, 4 off each side).
    return format("|T%s:%d:%d:0:0:64:64:4:60:4:60|t", icon, PREVIEW_SIZE, PREVIEW_SIZE)
end

local PREVIEWS = {
    -- Satellite's icon, the logo in its frame.
    satellite = function()
        return format("|T%sIcon:%d:%d|t", ns.MEDIA, PREVIEW_SIZE, PREVIEW_SIZE)
    end,
    prisma = function()
        local coords = LOGOS.prisma.coords
        local width = Round(PREVIEW_SIZE * (coords[2] - coords[1]) / (coords[4] - coords[3]))
        return format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t", LOGOS.prisma.texture, PREVIEW_SIZE, width,
            Round(coords[1] * 256), Round(coords[2] * 256), Round(coords[3] * 256), Round(coords[4] * 256))
    end,
    classImage = GetClassPreview,
    specImage = GetSpecPreview,
    -- The hero talent tree's emblem, or the spec's icon without one (as GetHeroImage).
    heroImage = function()
        local atlas = GetHeroAtlas()
        if atlas and C_Texture.GetAtlasInfo(atlas) then
            return CreateAtlasMarkup(atlas, PREVIEW_SIZE, PREVIEW_SIZE)
        end
        return GetSpecPreview()
    end,
}

-- A symbol's name ("satellite", "classImage"...) with a small picture of it before it, for the
-- settings' dropdown.
function IconStack.GetSymbolLabel(symbols, name)
    return PREVIEWS[symbols]() .. " " .. name
end

-- The logo or image shown: Satellite's logo, unless the player chose another (Prisma's, while
-- they're in the guild).
local function GetLogo()
    local symbols = ns.db.discSymbols
    if symbols == "prisma" and IconStack.IsInPrisma() then
        return LOGOS.prisma
    end
    -- An image the game doesn't have shows Satellite's logo.
    return IMAGES[symbols] and IMAGES[symbols]() or LOGOS.satellite
end

-- Whether one of the player's images shows, in its colours (ns.db.imageColors).
function IconStack.ShowsImage()
    return GetLogo().fillsBorder == true
end

-- What the launcher shows, to tell when it changed (e.g. another hero talent tree, which may be
-- on the same texture as the last).
function IconStack.GetSymbolKey()
    local logo = GetLogo()
    return format("%s %.4f %.4f", tostring(logo.texture), logo.coords[1], logo.coords[3])
end

-- Shows texture's part coords (left, right, top, bottom) turned by angle (radians) round its
-- middle: the part's corners turn in the texture instead (SetRotation would show the rest of the
-- texture the part is cut from). Its corners show a little of what's around it, which the round
-- cut hides.
local function SetTurnedCoords(texture, coords, aspect, angle)
    local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
    local centerX, centerY = (left + right) / 2, (top + bottom) / 2
    local halfX, halfY = (right - left) / 2 * aspect, (bottom - top) / 2
    local cos, sin = math.cos(angle), math.sin(angle)
    local function Corner(signX, signY)
        local x, y = signX * halfX, signY * halfY
        return centerX + (x * cos - y * sin) / aspect, centerY + x * sin + y * cos
    end
    local upperLeftX, upperLeftY = Corner(-1, -1)
    local lowerLeftX, lowerLeftY = Corner(-1, 1)
    local upperRightX, upperRightY = Corner(1, -1)
    local lowerRightX, lowerRightY = Corner(1, 1)
    ---@diagnostic disable-next-line: redundant-parameter
    texture:SetTexCoord(upperLeftX, upperLeftY, lowerLeftX, lowerLeftY, upperRightX, upperRightY, lowerRightX, lowerRightY)
end

-- Moving textures (the logo grows, its buttons turn) aren't snapped to whole pixels: snapped,
-- each steps on its own, and an outline anchored around a texture flickers between one pixel and
-- two.
local function KeepOffPixelGrid(texture)
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
end

-- A stack drawn on frame, around the middle of anchor (frame if nil); Layout gives its size.
function IconStack.Create(frame, anchor)
    local stack = { anchor = anchor or frame, x = 0, y = 0, spread = 0, angle = 0, isMasked = false }
    stack.logo = frame:CreateTexture(nil, "ARTWORK", nil, 6)
    KeepOffPixelGrid(stack.logo)
    -- Round images: a dark ring around them, and the square ones cut round.
    stack.logoOutline = frame:CreateTexture(nil, "ARTWORK", nil, 5)
    stack.logoOutline:SetTexture(Theme.DISC)
    stack.logoOutline:SetVertexColor(Theme.OUTLINE:GetRGBA())
    stack.logoOutline:SetPoint("TOPLEFT", stack.logo, "TOPLEFT", -IMAGE_OUTLINE, IMAGE_OUTLINE)
    stack.logoOutline:SetPoint("BOTTOMRIGHT", stack.logo, "BOTTOMRIGHT", IMAGE_OUTLINE, -IMAGE_OUTLINE)
    KeepOffPixelGrid(stack.logoOutline)
    stack.logoOutline:Hide()
    stack.logoMask = frame:CreateMaskTexture()
    stack.logoMask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    stack.logoMask:SetAllPoints(stack.logo)
    -- The image's glow: itself again, added on top as light.
    stack.logoGlow = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    stack.logoGlow:SetAllPoints(stack.logo)
    stack.logoGlow:SetBlendMode("ADD")
    stack.logoGlow:AddMaskTexture(stack.logoMask)
    KeepOffPixelGrid(stack.logoGlow)
    stack.logoGlow:Hide()
    stack.orbiter = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    stack.orbiter:SetAllPoints(stack.logo)
    KeepOffPixelGrid(stack.orbiter)
    stack.orbiter:Hide()
    return stack
end

local function Place(stack)
    local logo = stack.logoInfo
    -- The logo grows a little; an image fills the border and stays.
    local coords = logo.coords
    local height
    if logo.fillsBorder then
        height = stack.buttonSize - 2 * (IMAGE_BORDER + IMAGE_OUTLINE + IMAGE_GAP)
    else
        height = stack.buttonSize * logo.share * (1 + LOGO_GROWTH * stack.spread)
    end
    local width = logo.isSquare and height or height * (coords[2] - coords[1]) / (coords[4] - coords[3])
    stack.logo:SetSize(width, height)
    stack.logo:ClearAllPoints()
    stack.logo:SetPoint("CENTER", stack.anchor, "CENTER", stack.x, stack.y)
    -- Its buttons go round its orbit, square round the middle.
    if logo.orbiter then
        stack.orbiter:SetRotation(stack.angle)
    end
    if logo.fillsBorder then
        -- An image turns a little, against the clock (its part turning the other way in the
        -- texture, whose coordinates run down), or glows, as set; with the hover, not the orbit.
        local animation = ns.db.imageAnimation
        local angle = animation == "turn" and TURN_ANGLE * stack.spread or 0
        SetTurnedCoords(stack.logo, coords, logo.aspect, angle)
        if animation == "glow" then
            stack.logoGlow:SetAlpha(GLOW_ALPHA * stack.spread)
        end
    end
end

-- Sizes the stack for a button buttonSize across (its smaller side), with its middle x, y from the
-- anchor's middle (0 if nil).
function IconStack.Layout(stack, buttonSize, x, y)
    stack.buttonSize, stack.x, stack.y = buttonSize, x or 0, y or 0
    -- Found once here, not each frame of the animation (see Place).
    local logo = GetLogo()
    stack.logoInfo = logo
    stack.orbiter:SetShown(logo.orbiter ~= nil)
    local glows = logo.fillsBorder == true and ns.db.imageAnimation == "glow"
    stack.logoGlow:SetShown(glows)
    if glows then
        stack.logoGlow:SetTexture(logo.texture)
        stack.logoGlow:SetTexCoord(unpack(logo.coords))
    end
    stack.logoOutline:SetShown(logo.isRound == true)
    local isMasked = logo.isMasked == true
    if isMasked ~= stack.isMasked then
        stack.isMasked = isMasked
        if isMasked then
            stack.logo:AddMaskTexture(stack.logoMask)
        else
            stack.logo:RemoveMaskTexture(stack.logoMask)
        end
    end
    stack.logo:SetTexture(logo.texture)
    stack.logo:SetTexCoord(unpack(logo.coords))
    local color = logo.isTinted and Theme.GetAccentColors() or WHITE_FONT_COLOR
    -- An image in grey, tinted or not, as set.
    local tint = logo.fillsBorder and IMAGE_TINTS[ns.db.imageColors] or nil
    stack.logo:SetDesaturated(tint ~= nil)
    stack.logoGlow:SetDesaturated(tint ~= nil)
    color = tint or color
    stack.logo:SetVertexColor(color:GetRGB())
    stack.logoGlow:SetVertexColor(color:GetRGB())
    if logo.orbiter then
        stack.orbiter:SetTexture(logo.orbiter)
        stack.orbiter:SetVertexColor(color:GetRGB())
    end
    Place(stack)
end

-- From not spread (0) to spread (1), and turned by angle (radians, counterclockwise; 0 if nil)
-- while it orbits.
function IconStack.SetSpread(stack, t, angle)
    stack.spread, stack.angle = t, angle or 0
    Place(stack)
end
