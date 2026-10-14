local _, ns = ...

-- A small stack of three coloured discs, overlapping, standing for the addon buttons inside: what
-- the minimap button, circle and square show. Each has a simple glyph (a dragon, a potion and a
-- sword, or the player's class and spec) instead of the addons' own icons, so the launcher stays
-- quiet; coloured, silver, gold, bronze or in the class colour. Members of the guild Prisma can
-- show its logo instead. Spread, the discs move apart and grow a
-- little (while hovered or open). Two arrangements: a "cluster" that fits in a circle (one disc
-- on top, two below), and a "row" for the square.
local IconStack = {}
ns.IconStack = IconStack

local Theme = ns.Theme

-- The discs' glyphs (see tools/render_glyphs.sh), this share of a disc's size: as set
-- (ns.db.discSymbols), a dragon, a potion and a sword, or the player's class and spec: the class's
-- glyph on the disc that stands out (CLASS_DISC), and two for the spec (by its index in the class)
-- on the others. Without a spec, the class's glyph on all three.
local GLYPH_SHARE = 0.74
local ADVENTURE_GLYPHS = { "Dragon", "Potion", "Sword" }
local CLASS_GLYPHS = {
    WARRIOR = { "Axe", { "Sword", "Banner" }, { "Fist", "Flame" }, { "Shield", "Tower" } },
    PALADIN = { "Hammer", { "Sun", "Wings" }, { "Shield", "Tower" }, { "Sword", "Crown" } },
    HUNTER = { "Bow", { "Paw", "Fang" }, { "Arrow", "Crosshair" }, { "Spear", "Bomb" } },
    ROGUE = { "Dagger", { "Drop", "Skull" }, { "Dice", "Anchor" }, { "Mask", "Moon" } },
    PRIEST = { "Cross", { "Shield", "Sun" }, { "Wings", "Candle" }, { "Eye", "Skull" } },
    DEATHKNIGHT = { "Skull", { "Drop", "Sword" }, { "Snowflake", "Sword" }, { "Bones", "Tombstone" } },
    SHAMAN = { "Lightning", { "Flame", "Mountain" }, { "Fist", "Axe" }, { "Wave", "Drop" } },
    MAGE = { "Star", { "Book", "Hourglass" }, { "Flame", "Meteor" }, { "Snowflake", "Icicle" } },
    WARLOCK = { "Flame", { "Skull", "Eye" }, { "Horns", "Fang" }, { "Meteor", "Shard" } },
    MONK = { "Balance", { "Keg", "Shield" }, { "Lotus", "Cloud" }, { "Fist", "ClawMarks" } },
    DRUID = { "Leaf", { "Moon", "Star" }, { "ClawMarks", "Fang" }, { "Paw", "Shield" }, { "Tree", "Lotus" } },
    DEMONHUNTER = { "Horns", { "Wings", "ClawMarks" }, { "Shield", "Flame" }, { "Eye", "Moon" } },
    EVOKER = { "Dragon", { "Flame", "Wings" }, { "Lotus", "Drop" }, { "Hourglass", "Mountain" } },
}
-- The disc that stands out in each arrangement (see ARRANGEMENTS): the top one, or the middle.
local CLASS_DISC = { cluster = 1, row = 2 }

-- The guild Prisma's logo (Media/Prisma.tga, its crystal on its own), in place of the discs:
-- offered only to the guild's members ("prisma" in ns.db.discSymbols). Its part of the texture
-- (left, right, top, bottom), its height as a share of the button's (its smaller side), so it
-- stays inside any launcher's border even grown, and how much bigger it gets spread.
local PRISMA_GUILD = "Prisma"
local LOGO = ns.MEDIA .. "Prisma"
local LOGO_COORDS = { 40 / 256, 216 / 256, 8 / 256, 252 / 256 }
local LOGO_SHARE = 0.75
local LOGO_GROWTH = 0.075

-- Whether the player's character is in the guild Prisma (not known for a moment after login).
function IconStack.IsInPrisma()
    return GetGuildInfo("player") == PRISMA_GUILD
end

local function ShowsLogo()
    return ns.db.discSymbols == "prisma" and IconStack.IsInPrisma()
end

-- The three discs' glyphs, for arrangement.
local function GetGlyphs(arrangement)
    local _, classFile = UnitClass("player")
    local class = CLASS_GLYPHS[classFile]
    if ns.db.discSymbols ~= "class" or not class then
        return ADVENTURE_GLYPHS
    end
    local spec = class[1 + (C_SpecializationInfo.GetSpecialization() or 0)]
    local glyphs, specGlyph = {}, 1
    for index = 1, 3 do
        if index == CLASS_DISC[arrangement] or type(spec) ~= "table" then
            glyphs[index] = class[1]
        else
            glyphs[index] = spec[specGlyph]
            specGlyph = specGlyph + 1
        end
    end
    return glyphs
end
-- The colour settings (ns.db.discColors): the three discs' colours, a little different from each
-- other so they stand apart where they overlap, and the glyphs' colour. "class" is made from the
-- player's class colour (see GetClassPalette).
local PALETTES = {
    -- Muted teal, plum and clay (not gold, which the border is), with cream glyphs.
    colored = {
        discs = { CreateColor(0.33, 0.47, 0.46, 1), CreateColor(0.42, 0.38, 0.5, 1), CreateColor(0.55, 0.41, 0.33, 1) },
        glyph = CreateColor(1, 0.95, 0.83, 1),
    },
    silver = {
        discs = { CreateColor(0.8, 0.8, 0.83, 1), CreateColor(0.68, 0.68, 0.72, 1), CreateColor(0.57, 0.57, 0.61, 1) },
        glyph = CreateColor(0.16, 0.16, 0.18, 1),
    },
    gold = {
        discs = { CreateColor(0.96, 0.78, 0.33, 1), CreateColor(0.86, 0.66, 0.24, 1), CreateColor(0.76, 0.56, 0.18, 1) },
        glyph = CreateColor(0.27, 0.17, 0.06, 1),
    },
    bronze = {
        discs = { CreateColor(0.78, 0.53, 0.33, 1), CreateColor(0.68, 0.45, 0.27, 1), CreateColor(0.58, 0.38, 0.22, 1) },
        glyph = CreateColor(1, 0.95, 0.83, 1),
    },
}

-- A disc's size, as a share of the button's (its smaller side), the same on every launcher; and
-- how much bigger it gets spread (hovered or open).
local DISC_SHARE = 0.32
local SPREAD_GROWTH = 0.15
-- For each arrangement: where the discs' middles are at rest and spread, in disc sizes from the
-- stack's middle (y up); and the order they're drawn in, back to front. Even spread and grown, a
-- cluster stays within 1.25 disc sizes of its middle, and a row within 1.33 to each side.
local ARRANGEMENTS = {
    cluster = {
        rest = { { 0, 0.4 }, { -0.45, -0.29 }, { 0.45, -0.29 } },
        spread = { { 0, 0.52 }, { -0.57, -0.36 }, { 0.57, -0.36 } },
        order = { 1, 2, 3 },
    },
    row = {
        rest = { { -0.61, 0 }, { 0, 0 }, { 0.61, 0 } },
        spread = { { -0.75, 0 }, { 0, 0 }, { 0.75, 0 } },
        -- The middle one in front.
        order = { 1, 3, 2 },
    },
}

-- Three shades of the player's (quiet) class colour, with dark glyphs on a light colour and cream
-- ones on a dark colour.
local SHADES = { 1.1, 0.92, 0.76 }
local function GetClassPalette()
    local r, g, b = Theme.GetQuietClassColor():GetRGB()
    local discs = {}
    for index, shade in ipairs(SHADES) do
        discs[index] = CreateColor(math.min(1, r * shade), math.min(1, g * shade), math.min(1, b * shade), 1)
    end
    local isLight = 0.3 * r + 0.59 * g + 0.11 * b > 0.6
    return { discs = discs, glyph = isLight and PALETTES.gold.glyph or PALETTES.colored.glyph }
end

-- A stack drawn on frame, around the middle of anchor (frame if nil); Layout gives its size.
function IconStack.Create(frame, anchor)
    local stack = {
        anchor = anchor or frame, arrangement = "cluster", size = 1, x = 0, y = 0,
        spread = 0, discs = {},
    }
    for index = 1, #ADVENTURE_GLYPHS do
        local function AddTexture(file)
            local texture = frame:CreateTexture(nil, "ARTWORK")
            texture:SetTexture(file)
            return texture
        end
        local disc = AddTexture(Theme.DISC)
        local outline = AddTexture(Theme.DISC)
        outline:SetVertexColor(Theme.OUTLINE:GetRGBA())
        outline:SetPoint("TOPLEFT", disc, "TOPLEFT", -1.5, 1.5)
        outline:SetPoint("BOTTOMRIGHT", disc, "BOTTOMRIGHT", 1.5, -1.5)
        local glyph = AddTexture(ns.MEDIA .. "Glyph" .. ADVENTURE_GLYPHS[index])
        glyph:SetPoint("CENTER", disc)
        stack.discs[index] = { disc = disc, outline = outline, glyph = glyph }
    end
    stack.logo = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    stack.logo:SetTexture(LOGO)
    stack.logo:SetTexCoord(unpack(LOGO_COORDS))
    stack.logo:Hide()
    return stack
end

local function Place(stack)
    local t = stack.spread
    if stack.logo:IsShown() then
        -- The logo grows a little, as the discs do.
        local height = stack.buttonSize * LOGO_SHARE * (1 + LOGO_GROWTH * t)
        local width = height * (LOGO_COORDS[2] - LOGO_COORDS[1]) / (LOGO_COORDS[4] - LOGO_COORDS[3])
        stack.logo:SetSize(width, height)
        stack.logo:ClearAllPoints()
        stack.logo:SetPoint("CENTER", stack.anchor, "CENTER", stack.x, stack.y)
        return
    end
    local layout = ARRANGEMENTS[stack.arrangement]
    local size = stack.size
    local discSize = size * (1 + SPREAD_GROWTH * t)
    for index, entry in ipairs(stack.discs) do
        entry.disc:SetSize(discSize, discSize)
        entry.glyph:SetSize(discSize * GLYPH_SHARE, discSize * GLYPH_SHARE)
        local rest, spread = layout.rest[index], layout.spread[index]
        local x = rest[1] + (spread[1] - rest[1]) * t
        local y = rest[2] + (spread[2] - rest[2]) * t
        entry.disc:ClearAllPoints()
        entry.disc:SetPoint("CENTER", stack.anchor, "CENTER", stack.x + x * size, stack.y + y * size)
    end
end

-- Sizes the stack for a button buttonSize across (its smaller side): arrangement ("cluster" or
-- "row"), and its middle x, y from the anchor's middle (0 if nil).
function IconStack.Layout(stack, arrangement, buttonSize, x, y)
    local discSize = buttonSize * DISC_SHARE
    stack.arrangement, stack.size, stack.x, stack.y = arrangement, discSize, x or 0, y or 0
    stack.buttonSize = buttonSize
    local showsLogo = ShowsLogo()
    stack.logo:SetShown(showsLogo)
    for _, entry in ipairs(stack.discs) do
        entry.disc:SetShown(not showsLogo)
        entry.outline:SetShown(not showsLogo)
        entry.glyph:SetShown(not showsLogo)
    end
    local layout = ARRANGEMENTS[arrangement]
    local palette = ns.db.discColors == "class" and GetClassPalette()
        or PALETTES[ns.db.discColors] or PALETTES.colored
    local glyphs = GetGlyphs(arrangement)
    for index, entry in ipairs(stack.discs) do
        entry.disc:SetVertexColor(palette.discs[index]:GetRGBA())
        entry.glyph:SetTexture(ns.MEDIA .. "Glyph" .. glyphs[index])
        entry.glyph:SetVertexColor(palette.glyph:GetRGBA())
        -- Back to front, each disc with its outline under it and its glyph over it.
        local subLevel = (layout.order[index] - 1) * 3
        entry.outline:SetDrawLayer("ARTWORK", subLevel - 1)
        entry.disc:SetDrawLayer("ARTWORK", subLevel)
        entry.glyph:SetDrawLayer("ARTWORK", subLevel + 1)
    end
    Place(stack)
end

-- From not spread (0) to spread (1).
function IconStack.SetSpread(stack, t)
    stack.spread = t
    Place(stack)
end
