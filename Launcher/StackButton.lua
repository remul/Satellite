local _, ns = ...

-- What the minimap button, circle and square launchers share inside their own shapes: the stack
-- of coloured discs (see IconStack) and a gold chevron beside the button, on the side the menu
-- opens, pointing that way. Hovered, the discs spread and the chevron nudges out; open, the discs
-- stay spread and the chevron points back.
local StackButton = {}
ns.StackButton = StackButton

local Theme = ns.Theme

-- The chevron (pointing left or right; swapped pointing up or down): its width and height, the
-- space between it and the button, and how much further out it moves while hovered.
local CHEVRON_WIDTH, CHEVRON_HEIGHT, CHEVRON_GAP, CHEVRON_NUDGE = 7, 12, 3, 2
-- Seconds to go from not hovered to hovered.
local HOVER_TIME = 0.15

-- For each way: one step out of the button, and the triangle texture's coordinates (it points
-- left) to point that way, in the eight-value form (upper left, lower left, upper right, lower
-- right).
local WAYS = {
    LEFT = { x = -1, y = 0, coords = { 0, 0, 0, 1, 1, 0, 1, 1 } },
    RIGHT = { x = 1, y = 0, coords = { 1, 0, 1, 1, 0, 0, 0, 1 } },
    UP = { x = 0, y = 1, coords = { 0, 0, 1, 0, 0, 1, 1, 1 } },
    DOWN = { x = 0, y = -1, coords = { 1, 0, 0, 0, 1, 1, 0, 1 } },
}
local OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", UP = "DOWN", DOWN = "UP" }

local Methods = {}
local Meta = { __index = Methods }

-- On button (what's clicked, which the stack and chevron are placed around), drawn on drawOn
-- (button if nil). onLit(isLit) is called as it lights up and back, for the style's own border.
function StackButton.Create(button, drawOn, onLit)
    drawOn = drawOn or button
    local self = setmetatable({
        button = button, onLit = onLit, direction = "LEFT", hover = 0, hoverTarget = 0, progress = 0,
    }, Meta)
    self.chevronShadow = drawOn:CreateTexture(nil, "OVERLAY", nil, 0)
    self.chevronShadow:SetTexture(Theme.TRIANGLE)
    self.chevronShadow:SetVertexColor(Theme.OUTLINE:GetRGBA())
    self.chevron = drawOn:CreateTexture(nil, "OVERLAY", nil, 1)
    self.chevron:SetTexture(Theme.TRIANGLE)
    self.chevrons = { self.chevronShadow, self.chevron }
    self.stack = ns.IconStack.Create(drawOn, button)
    self.color, self.hoverColor = Theme.GetAccentColors()
    self.animator = CreateFrame("Frame", nil, button)
    self.animator:Hide()
    self.animator:SetScript("OnUpdate", function(_, elapsed)
        local step = elapsed / HOVER_TIME
        local target = self.hoverTarget
        self.hover = target > self.hover and math.min(target, self.hover + step) or math.max(target, self.hover - step)
        self:Draw()
        if self.hover == target then
            self.animator:Hide()
        end
    end)
    return self
end

-- How far the button reaches from its middle toward the menu.
local function GetExtent(self)
    local way = WAYS[self.direction]
    return way.x ~= 0 and self.button:GetWidth() / 2 or self.button:GetHeight() / 2
end

-- Runs every frame while it's animating: colours only change when it lights up or goes back.
function Methods:Draw()
    ns.IconStack.SetSpread(self.stack, math.max(self.hover, self.progress))
    local isLit = self.hover > 0.5
    if isLit ~= self.isLit then
        self.isLit = isLit
        self.chevron:SetVertexColor((isLit and self.hoverColor or self.color):GetRGBA())
        if self.onLit then
            self.onLit(isLit)
        end
    end
    local scale = ns.Launcher.GetScale()
    local way = WAYS[self.direction]
    local distance = GetExtent(self) + (CHEVRON_GAP + CHEVRON_WIDTH / 2 + CHEVRON_NUDGE * self.hover) * scale
    local pointing = self.progress < 0.5 and self.direction or OPPOSITE[self.direction]
    local sideways = way.x ~= 0
    local width = (sideways and CHEVRON_WIDTH or CHEVRON_HEIGHT) * scale
    local height = (sideways and CHEVRON_HEIGHT or CHEVRON_WIDTH) * scale
    self.chevron:SetSize(width, height)
    self.chevronShadow:SetSize(width + 2.5, height + 2.5)
    for _, texture in ipairs(self.chevrons) do
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", self.button, "CENTER", way.x * distance, way.y * distance)
        ---@diagnostic disable-next-line: redundant-parameter
        texture:SetTexCoord(unpack(WAYS[pointing].coords))
    end
end

-- After the button's size or place changed: the menu opens toward direction ("LEFT", "RIGHT",
-- "UP" or "DOWN"), and the stack's arrangement, the button's size and the stack's place (see
-- IconStack.Layout).
function Methods:Layout(direction, arrangement, buttonSize, x, y)
    self.direction = direction
    -- The border colour may have changed: the next Draw colours everything again.
    self.color, self.hoverColor = Theme.GetAccentColors()
    self.isLit = nil
    ns.IconStack.Layout(self.stack, arrangement, buttonSize, x, y)
    self:Draw()
end

-- How far from the button's middle the menu has to start, to clear the chevron.
function Methods:GetMenuReach()
    return GetExtent(self) + (CHEVRON_GAP + CHEVRON_WIDTH + CHEVRON_NUDGE) * ns.Launcher.GetScale()
end

function Methods:SetProgress(progress)
    self.progress = progress
    self:Draw()
end

function Methods:SetHovered(isHovered)
    self.hoverTarget = isHovered and 1 or 0
    self.animator:Show()
end
