local _, ns = ...

-- The buttons inside the launcher: one per collected button (see Buttons), drawn like a minimap
-- button, that shows the addon's icon and tooltip and passes clicks on to the addon. Frames are
-- kept per key and reused, as WoW can't delete frames.
local LauncherButton = {}
ns.LauncherButton = LauncherButton

local LDB = LibStub("LibDataBroker-1.1")

-- Blizzard's minimap button art, as LibDBIcon uses it.
local BORDER_TEXTURE = 136430 -- Interface\Minimap\MiniMap-TrackingBorder
local BACKGROUND_TEXTURE = 136467 -- Interface\Minimap\UI-Minimap-Background
local HIGHLIGHT_TEXTURE = 136477 -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight
local QUESTION_MARK = 134400
-- Sizes as a share of the button's size, from LibDBIcon's 31 pixel button.
local BORDER_SCALE, BACKGROUND_SCALE, ICON_SCALE = 50 / 31, 24 / 31, 18 / 31
-- Icons are cropped a little, as LibDBIcon does, to hide their own square edge.
local ICON_CROP = 0.05
-- Showing names only: the space before the name, and the row's colour while hovered.
local NAME_INSET = 6
local ROW_HIGHLIGHT = CreateColor(1, 0.82, 0.3, 0.12)
-- The menu's own button shapes (ns.db.buttonShape; "minimap" is Blizzard's minimap button art):
-- each one's texture (also its icon's mask), its size and its icon's as shares of the button's
-- (a circle or square fills more of it than a diamond, so they're drawn smaller to look alike),
-- and how far its outline reaches out and its fill in (its border, in the border colour, between
-- them). Diamonds have thicker edges, as their sides run slanted.
local SHAPES = {
    circle = { texture = "DISC", size = 0.88, icon = 0.55, outline = 1.5, inset = 1.5 },
    square = { texture = "BAR_FILL", size = 0.84, icon = 0.55, outline = 1.5, inset = 1.5 },
    diamond = { texture = "DIAMOND", size = 1, icon = 0.5, outline = 2, inset = 2.25 },
}
local SHAPE_HIGHLIGHT = CreateColor(1, 1, 1, 0.18)
-- The dot on a button whose icon changed (see Alert): its size and colour.
local ALERT_SIZE = 7
local ALERT_COLOR = CreateColor(0.95, 0.27, 0.2, 1)

local APPEAR_TIME = 0.22
local DISAPPEAR_TIME = 0.12

-- [key] = frame
local frames = {}

-- Shows button's icon (a collected button, see Buttons) on the texture icon.
function LauncherButton.SetIconTexture(icon, button)
    local texture, coords
    icon:SetVertexColor(1, 1, 1)
    if button.source == "ldb" then
        local dataObject = button.dataObject
        texture, coords = dataObject.icon, dataObject.iconCoords
        icon:SetVertexColor(dataObject.iconR or 1, dataObject.iconG or 1, dataObject.iconB or 1)
    elseif button.source == "comp" then
        texture = button.entry.icon
    elseif button.source == "blizzard" then
        texture = ns.Blizzard.GetIcon(button)
    elseif button.source == "frame" then
        -- The icon on the addon's own frame as it is, with its own crop and colour.
        if ns.Handmade.CopyIcon(icon, button) then
            return
        end
        texture = ns.Handmade.GetFallbackIcon(button)
    end
    if type(texture) == "string" and C_Texture.GetAtlasInfo(texture) then
        icon:SetAtlas(texture)
        return
    end
    icon:SetTexture(texture or QUESTION_MARK)
    local left, right, top, bottom = 0, 1, 0, 1
    if type(coords) == "table" then
        left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
    end
    local cropX, cropY = (right - left) * ICON_CROP, (bottom - top) * ICON_CROP
    icon:SetTexCoord(left + cropX, right - cropX, top + cropY, bottom - cropY)
end

-- Shows or hides the dot on the menu's button with key (if it has one).
function LauncherButton.SetAlerted(key, isShown)
    local self = frames[key]
    if self then
        self.alertOutline:SetShown(isShown)
        self.alertDot:SetShown(isShown)
    end
end

function LauncherButton.ClearAlerts()
    for key in pairs(frames) do
        LauncherButton.SetAlerted(key, false)
    end
end

-- What button's icon looks like now, as a string: the same string for the same look (see Alert).
function LauncherButton.GetIconLook(button)
    if button.source == "ldb" then
        local dataObject = button.dataObject
        return format("%s %s %s %s", tostring(dataObject.icon), tostring(dataObject.iconR),
            tostring(dataObject.iconG), tostring(dataObject.iconB))
    elseif button.source == "comp" then
        return tostring(button.entry.icon)
    elseif button.source == "blizzard" then
        return tostring(ns.Blizzard.GetIcon(button))
    elseif button.source == "frame" then
        return ns.Handmade.GetIconLook(button)
    end
    return ""
end

local function SetIcon(self)
    LauncherButton.SetIconTexture(self.icon, self.button)
end

-- The menu's button with key, or nil if it has none yet.
function LauncherButton.GetFrame(key)
    return frames[key]
end

-- Draws the icon again for the menu's button with key, if it has one (its art changed).
function LauncherButton.RefreshIcon(key)
    local self = frames[key]
    if self then
        SetIcon(self)
    end
end

local function ShowSimpleTooltip(self, extraLine)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, self.button.label)
    if extraLine then
        GameTooltip_AddNormalLine(GameTooltip, extraLine)
    end
    GameTooltip:Show()
end

local function OnEnter(self)
    local button = self.button
    if button.source == "ldb" then
        local dataObject = button.dataObject
        if dataObject.OnTooltipShow then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            dataObject.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        elseif dataObject.OnEnter then
            dataObject.OnEnter(self)
        else
            ShowSimpleTooltip(self, dataObject.tooltiptext)
        end
    elseif button.source == "comp" and button.entry.funcOnEnter then
        button.entry.funcOnEnter(self)
    elseif button.source == "blizzard" then
        -- As Blizzard's own button shows it: the title in white, the description below.
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(button.label, 1, 1, 1)
        if button.description then
            GameTooltip:AddLine(button.description, nil, nil, nil, true)
        end
        GameTooltip:Show()
    else
        ShowSimpleTooltip(self)
    end
end

local function OnLeave(self)
    GameTooltip:Hide()
    local button = self.button
    if button.source == "ldb" and button.dataObject.OnLeave then
        button.dataObject.OnLeave(self)
    elseif button.source == "comp" and button.entry.funcOnLeave then
        button.entry.funcOnLeave(self)
    end
end

-- After a click on the menu's button (or on a hand-made button's own frame over it, see
-- Handmade): most clicks open something, so the menu closes (a setting). Not on right-click:
-- addons often open a menu there, attached to the button. Nor while the settings are open.
function LauncherButton.AfterClick(self, mouseButton)
    if mouseButton == "LeftButton" and ns.db.closeOnClick and not ns.Settings.IsShown() then
        -- Its tooltip, or the hand-made frame's over it.
        local owner = GameTooltip:GetOwner()
        if owner and (owner == self or owner:GetParent() == self) then
            GameTooltip:Hide()
        end
        ns.Menu.Close()
    end
end

-- Passes the click on as the addon's own button would: LibDataBroker's OnClick, the compartment's
-- func as Blizzard's menu calls it, or Blizzard's expansion button's. A hand-made button's own
-- frame lies over this one and takes its clicks.
local function OnClick(self, mouseButton)
    local button = self.button
    if button.source == "ldb" and button.dataObject.OnClick then
        button.dataObject.OnClick(self, mouseButton)
    elseif button.source == "comp" and button.entry.func then
        button.entry.func(button.entry, { buttonName = mouseButton }, nil)
    elseif button.source == "blizzard" then
        ns.Blizzard.Click(button)
    end
    LauncherButton.AfterClick(self, mouseButton)
end

local function CreateAppearAnimation(self)
    local group = self:CreateAnimationGroup()
    group:SetToFinalAlpha(true)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(APPEAR_TIME * 0.7)
    local scale = group:CreateAnimation("Scale")
    scale:SetScaleFrom(0.3, 0.3)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(APPEAR_TIME)
    scale:SetSmoothing("OUT")
    group.alpha, group.scale = alpha, scale
    return group
end

local function CreateDisappearAnimation(self)
    local group = self:CreateAnimationGroup()
    group:SetToFinalAlpha(true)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(DISAPPEAR_TIME)
    group:SetScript("OnFinished", function()
        self:Hide()
    end)
    return group
end

local function CreateFrameFor(parent)
    local self = CreateFrame("Button", nil, parent)
    self:RegisterForClicks("AnyUp")
    self:SetHighlightTexture(HIGHLIGHT_TEXTURE)

    self.background = self:CreateTexture(nil, "BACKGROUND")
    self.background:SetTexture(BACKGROUND_TEXTURE)
    self.background:SetPoint("CENTER")
    self.icon = self:CreateTexture(nil, "ARTWORK")
    self.icon:SetPoint("CENTER")
    -- The shapes (see SetLook): outline, border and fill under the icon, the icon cut to the
    -- shape, and the shape lit up while hovered.
    self.shapeOutline = self:CreateTexture(nil, "BACKGROUND", nil, 0)
    self.shapeBorder = self:CreateTexture(nil, "BACKGROUND", nil, 1)
    self.shapeFill = self:CreateTexture(nil, "BACKGROUND", nil, 2)
    self.shapeHighlight = self:CreateTexture(nil, "HIGHLIGHT")
    self.shapeHighlight:SetBlendMode("ADD")
    self.shapeTextures = { self.shapeOutline, self.shapeBorder, self.shapeFill, self.shapeHighlight }
    self.iconMask = self:CreateMaskTexture()
    self.iconMask:SetAllPoints(self.icon)
    self.border = self:CreateTexture(nil, "OVERLAY")
    self.border:SetTexture(BORDER_TEXTURE)
    self.border:SetPoint("TOPLEFT")
    -- The addon's name, when the menu shows names (see SetLook), and the row lit up while hovered
    -- when it shows only names.
    self.label = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.label:SetJustifyH("LEFT")
    self.label:SetWordWrap(false)
    self.label:Hide()
    self.rowHighlight = self:CreateTexture(nil, "HIGHLIGHT")
    self.rowHighlight:SetAllPoints()
    self.rowHighlight:SetColorTexture(ROW_HIGHLIGHT:GetRGBA())
    -- A dot in the corner while its icon is new since the menu was last opened (see Alert).
    self.alertOutline = self:CreateTexture(nil, "OVERLAY", nil, 6)
    self.alertOutline:SetTexture(ns.Theme.DISC)
    self.alertOutline:SetVertexColor(ns.Theme.OUTLINE:GetRGBA())
    self.alertOutline:SetSize(ALERT_SIZE + 3, ALERT_SIZE + 3)
    self.alertOutline:SetPoint("CENTER", self, "TOPRIGHT", -3, -3)
    self.alertDot = self:CreateTexture(nil, "OVERLAY", nil, 7)
    self.alertDot:SetTexture(ns.Theme.DISC)
    self.alertDot:SetVertexColor(ALERT_COLOR:GetRGBA())
    self.alertDot:SetSize(ALERT_SIZE, ALERT_SIZE)
    self.alertDot:SetPoint("CENTER", self.alertOutline)
    self.alertOutline:Hide()
    self.alertDot:Hide()

    self:SetScript("OnEnter", OnEnter)
    self:SetScript("OnLeave", OnLeave)
    self:SetScript("OnClick", OnClick)
    self.appear = CreateAppearAnimation(self)
    self.disappear = CreateDisappearAnimation(self)
    self:Hide()
    return self
end

-- The frame for button (see Buttons), made the first time.
function LauncherButton.Get(parent, button)
    local self = frames[button.key]
    if not self then
        self = CreateFrameFor(parent)
        frames[button.key] = self
    end
    self.button = button
    SetIcon(self)
    return self
end

-- Hides every frame whose button isn't in keys ([key] = true).
function LauncherButton.HideOthers(keys)
    for key, self in pairs(frames) do
        if not keys[key] then
            self.appear:Stop()
            self.disappear:Stop()
            self:Hide()
        end
    end
end

-- Blizzard's expansion button brings its own round frame: it's drawn this big, without the
-- minimap button's border and background.
local FRAMED_ART_SCALE = 1.3

-- Draws the frame for what the menu shows (mode: "icons", "both" or "names"): a minimap button
-- size wide; with "both", the addon's name beside it, width wide (cut off with "..." if it doesn't
-- fit; clicks on it count as clicks on the button); with "names", just the name, as a row width
-- wide and size high.
-- Places texture over the button, grown by grow on each side (shrunk if negative).
local function Fit(texture, grow)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", -grow, grow)
    texture:SetPoint("BOTTOMRIGHT", grow, -grow)
end

-- Draws the button in one of the menu's own shapes (see SHAPES), or not (nil: Blizzard's art).
local function SetShape(self, shape, size)
    local info = SHAPES[shape]
    for _, texture in ipairs(self.shapeTextures) do
        texture:SetShown(info ~= nil)
    end
    if not info then
        if self.isMasked then
            self.icon:RemoveMaskTexture(self.iconMask)
            self.isMasked = false
        end
        return
    end
    local Theme = ns.Theme
    local file = Theme[info.texture]
    local color = Theme.GetAccentColors()
    -- How far in from the button's edge the shape is drawn.
    local margin = size * (1 - info.size) / 2
    self.shapeOutline:SetTexture(file)
    self.shapeOutline:SetVertexColor(Theme.OUTLINE:GetRGBA())
    Fit(self.shapeOutline, info.outline - margin)
    self.shapeBorder:SetTexture(file)
    self.shapeBorder:SetVertexColor(color:GetRGBA())
    Fit(self.shapeBorder, -margin)
    self.shapeFill:SetTexture(file)
    self.shapeFill:SetVertexColor(Theme.FILL:GetRGBA())
    Fit(self.shapeFill, -info.inset - margin)
    self.shapeHighlight:SetTexture(file)
    self.shapeHighlight:SetVertexColor(SHAPE_HIGHLIGHT:GetRGBA())
    Fit(self.shapeHighlight, -info.inset - margin)
    self.iconMask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not self.isMasked then
        self.icon:AddMaskTexture(self.iconMask)
        self.isMasked = true
    end
    self.icon:SetSize(size * info.icon, size * info.icon)
end

function LauncherButton.SetLook(self, mode, size, width)
    local isNameOnly = mode == "names"
    local hasOwnFrame = self.button.source == "blizzard"
    -- Blizzard's expansion button has its own frame in its art, so it keeps it in every shape.
    local shape = not isNameOnly and not hasOwnFrame and ns.db.buttonShape
    local isShaped = SHAPES[shape] ~= nil
    SetShape(self, isShaped and shape or nil, size)
    self.border:SetShown(not hasOwnFrame and not isNameOnly and not isShaped)
    self.background:SetShown(not hasOwnFrame and not isNameOnly and not isShaped)
    self.icon:SetShown(not isNameOnly)
    self:GetHighlightTexture():SetAlpha((isNameOnly or isShaped) and 0 or 1)
    self.rowHighlight:SetShown(isNameOnly)
    self.label:SetShown(mode ~= "icons")
    self.label:SetText(self.button.label)
    self.label:ClearAllPoints()
    if isNameOnly then
        self:SetSize(width, size)
        self.label:SetPoint("LEFT", NAME_INSET, 0)
        self.label:SetWidth(width - 2 * NAME_INSET)
        self:SetHitRectInsets(0, 0, 0, 0)
        return
    end
    self:SetSize(size, size)
    if not isShaped then
        self.border:SetSize(size * BORDER_SCALE, size * BORDER_SCALE)
        self.background:SetSize(size * BACKGROUND_SCALE, size * BACKGROUND_SCALE)
        local iconSize = size * (hasOwnFrame and FRAMED_ART_SCALE or ICON_SCALE)
        self.icon:SetSize(iconSize, iconSize)
    end
    self.label:SetPoint("LEFT", self, "RIGHT", 6, 0)
    self.label:SetWidth(width)
    self:SetHitRectInsets(0, mode == "both" and -(width + 6) or 0, 0, 0)
end

-- Shows the frame with its pop-in animation, after delay seconds.
function LauncherButton.Appear(self, delay)
    self.disappear:Stop()
    self:SetAlpha(0)
    self:Show()
    self.appear.alpha:SetStartDelay(delay)
    self.appear.scale:SetStartDelay(delay)
    self.appear:Play()
end

function LauncherButton.Disappear(self)
    self.appear:Stop()
    if self:IsShown() then
        self.disappear:Play()
    end
end

-- Shown at once, without animation (e.g. when buttons change while the launcher is open).
function LauncherButton.ShowNow(self)
    self.appear:Stop()
    self.disappear:Stop()
    self:SetAlpha(1)
    self:Show()
end

-- Addons change their icon as things happen (e.g. BugSack when there's a new error).
local ICON_ATTRIBUTES = { "icon", "iconCoords", "iconR", "iconG", "iconB" }

function LauncherButton.Setup()
    local function OnIconChanged(_, name)
        local self = frames["ldb:" .. name]
        if self then
            SetIcon(self)
        end
        ns.Alert.Check("ldb:" .. name)
    end
    -- Only these attributes: data sources change their text often, some every frame.
    for _, key in ipairs(ICON_ATTRIBUTES) do
        -- CallbackHandler's RegisterCallback takes the owner first; the IDE reads it as a method.
        ---@diagnostic disable-next-line: param-type-mismatch
        LDB.RegisterCallback(LauncherButton, "LibDataBroker_AttributeChanged__" .. key, OnIconChanged)
    end
end
