local _, ns = ...

-- The look every launcher style shares: the minimap's border (a silver ring with a dark outline,
-- and gold compass arrows), with dark leather inside. Textures are white and tinted (see
-- tools/generate_textures.py).
local Theme = {}
ns.Theme = Theme

Theme.ARROW = ns.MEDIA .. "Arrow"
Theme.ARROW_SHADOW = ns.MEDIA .. "ArrowShadow"
Theme.PANEL_FILL = ns.MEDIA .. "PanelFill"
Theme.PANEL_BORDER = ns.MEDIA .. "PanelBorder"
Theme.BAR_FILL = ns.MEDIA .. "BarFill"
Theme.BAR_BORDER = ns.MEDIA .. "BarBorder"
Theme.DISC = ns.MEDIA .. "Disc"
Theme.DIAMOND = ns.MEDIA .. "Diamond"
Theme.TRIANGLE = ns.MEDIA .. "Triangle"
-- Corner radius of the panel and bar textures, their slice margins.
Theme.PANEL_RADIUS = 16
Theme.BAR_RADIUS = 6

Theme.OUTLINE = CreateColor(0.05, 0.05, 0.05, 1)
Theme.SILVER = CreateColor(0.62, 0.62, 0.64, 1)
Theme.GOLD = CreateColor(0.95, 0.76, 0.3, 1)
Theme.FILL = CreateColor(0.15, 0.105, 0.06, 0.95)
-- The strata of the launchers you can put anywhere (and so their menu): over the action bars and
-- unit frames, under dialogs and tooltips.
Theme.STRATA = "HIGH"

-- While hovered, things light up.
Theme.SILVER_HOVER = CreateColor(0.9, 0.9, 0.94, 1)
Theme.GOLD_HOVER = CreateColor(1, 0.88, 0.5, 1)
Theme.FILL_HOVER = CreateColor(0.21, 0.15, 0.09, 0.95)

-- A texture filling frame (grown by grow pixels on each side), tinted color.
function Theme.AddTexture(frame, file, layer, subLevel, color, grow)
    local texture = frame:CreateTexture(nil, layer, nil, subLevel)
    texture:SetTexture(file)
    texture:SetVertexColor(color:GetRGBA())
    grow = grow or 0
    texture:SetPoint("TOPLEFT", -grow, grow)
    texture:SetPoint("BOTTOMRIGHT", grow, -grow)
    return texture
end

-- The same, drawn as slices with margin, so rounded corners keep their size at any size.
function Theme.AddSlicedTexture(frame, file, margin, layer, subLevel, color, grow)
    local texture = Theme.AddTexture(frame, file, layer, subLevel, color, grow)
    texture:SetTextureSliceMargins(margin, margin, margin, margin)
    texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    return texture
end

-- A rounded box in the theme on frame: dark fill, dark outline and silver border. Returns the
-- fill and the border, to light them up.
function Theme.AddBox(frame, fillFile, borderFile, margin)
    local fill = Theme.AddSlicedTexture(frame, fillFile, margin, "BACKGROUND", 0, Theme.FILL)
    Theme.AddSlicedTexture(frame, borderFile, margin, "BORDER", 0, Theme.OUTLINE)
    local border = Theme.AddSlicedTexture(frame, borderFile, margin, "BORDER", 1, Theme.SILVER, -1.5)
    return fill, border
end

-- The border colour setting (ns.db.borderColor) of the minimap button, circle and square, which
-- their chevron takes too: gold, silver, bronze, or the player's class colour, made quieter than
-- the game's own (less bright and less saturated, so it sits with the minimap's colours).
local ACCENTS = {
    gold = Theme.GOLD,
    silver = Theme.SILVER,
    bronze = CreateColor(0.72, 0.48, 0.3, 1),
}
local QUIET_CLASS_COLORS = {
    WARRIOR = CreateColor(0.7, 0.57, 0.43, 1),
    PALADIN = CreateColor(0.82, 0.55, 0.66, 1),
    HUNTER = CreateColor(0.6, 0.72, 0.45, 1),
    ROGUE = CreateColor(0.86, 0.82, 0.48, 1),
    PRIEST = CreateColor(0.85, 0.85, 0.82, 1),
    DEATHKNIGHT = CreateColor(0.66, 0.25, 0.3, 1),
    SHAMAN = CreateColor(0.25, 0.48, 0.75, 1),
    MAGE = CreateColor(0.4, 0.7, 0.8, 1),
    WARLOCK = CreateColor(0.53, 0.53, 0.8, 1),
    MONK = CreateColor(0.3, 0.78, 0.6, 1),
    DRUID = CreateColor(0.85, 0.52, 0.22, 1),
    DEMONHUNTER = CreateColor(0.58, 0.33, 0.7, 1),
    EVOKER = CreateColor(0.3, 0.56, 0.5, 1),
}
-- How much lighter (toward white) the colour gets while hovered.
local ACCENT_HOVER_SHARE = 0.4

-- The player's class colour, the quieter version.
function Theme.GetQuietClassColor()
    local _, classFile = UnitClass("player")
    return QUIET_CLASS_COLORS[classFile] or Theme.GOLD
end

-- The border colour, and the same lighter, for while it's hovered.
function Theme.GetAccentColors()
    local color = ACCENTS[ns.db.borderColor] or Theme.GOLD
    if ns.db.borderColor == "class" then
        color = Theme.GetQuietClassColor()
    end
    local r, g, b = color:GetRGB()
    local function Lighter(value)
        return value + (1 - value) * ACCENT_HOVER_SHARE
    end
    return color, CreateColor(Lighter(r), Lighter(g), Lighter(b), 1)
end

-- A round button on frame, with a dark outline and a gold border that keeps its thickness at any
-- size (a gold disc with a smaller fill disc over it). Returns the fill and the border.
Theme.ROUND_BORDER = 2.5
function Theme.AddRoundBox(frame)
    Theme.AddTexture(frame, Theme.DISC, "BACKGROUND", 0, Theme.OUTLINE, 1.5)
    local border = Theme.AddTexture(frame, Theme.DISC, "BACKGROUND", 1, Theme.GOLD)
    local fill = Theme.AddTexture(frame, Theme.DISC, "BACKGROUND", 2, Theme.FILL, -Theme.ROUND_BORDER)
    return fill, border
end

-- A short pop on frame (it grows a little and settles), to show something new: an animation group
-- to Play.
function Theme.CreatePop(frame)
    local group = frame:CreateAnimationGroup()
    local grow = group:CreateAnimation("Scale")
    grow:SetScaleTo(1.25, 1.25)
    grow:SetDuration(0.12)
    grow:SetSmoothing("OUT")
    grow:SetOrder(1)
    local settle = group:CreateAnimation("Scale")
    settle:SetScaleTo(0.8, 0.8)
    settle:SetDuration(0.2)
    settle:SetSmoothing("IN_OUT")
    settle:SetOrder(2)
    return group
end

-- Colours a box (the menu, the circle and square) for hovered or not: its border in the border
-- colour (see GetAccentColors).
function Theme.SetBoxHovered(fill, border, isHovered)
    local color, hoverColor = Theme.GetAccentColors()
    fill:SetVertexColor((isHovered and Theme.FILL_HOVER or Theme.FILL):GetRGBA())
    border:SetVertexColor((isHovered and hoverColor or color):GetRGBA())
end

