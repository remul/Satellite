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

local function SetIcon(self)
    LauncherButton.SetIconTexture(self.icon, self.button)
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

-- Passes the click on as the addon's own button would: LibDataBroker's OnClick, the compartment's
-- func as Blizzard's menu calls it, or Blizzard's expansion button's.
local function OnClick(self, mouseButton)
    local button = self.button
    if button.source == "ldb" and button.dataObject.OnClick then
        button.dataObject.OnClick(self, mouseButton)
    elseif button.source == "comp" and button.entry.func then
        button.entry.func(button.entry, { buttonName = mouseButton }, nil)
    elseif button.source == "blizzard" then
        ns.Blizzard.Click(button)
    end
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
    self.border = self:CreateTexture(nil, "OVERLAY")
    self.border:SetTexture(BORDER_TEXTURE)
    self.border:SetPoint("TOPLEFT")
    -- The addon's name to the right, when the menu shows names (see SetLabel).
    self.label = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.label:SetPoint("LEFT", self, "RIGHT", 6, 0)
    self.label:SetJustifyH("LEFT")
    self.label:SetWordWrap(false)
    self.label:Hide()

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

function LauncherButton.SetSize(self, size)
    self:SetSize(size, size)
    local hasOwnFrame = self.button.source == "blizzard"
    self.border:SetShown(not hasOwnFrame)
    self.background:SetShown(not hasOwnFrame)
    self.border:SetSize(size * BORDER_SCALE, size * BORDER_SCALE)
    self.background:SetSize(size * BACKGROUND_SCALE, size * BACKGROUND_SCALE)
    local iconSize = size * (hasOwnFrame and FRAMED_ART_SCALE or ICON_SCALE)
    self.icon:SetSize(iconSize, iconSize)
end

-- Shows the addon's name to the right of the button, width wide (it's cut off with "..." if it
-- doesn't fit), or hides it; clicks on the name count as clicks on the button.
function LauncherButton.SetLabel(self, isShown, width)
    self.label:SetShown(isShown)
    self.label:SetText(self.button.label)
    self.label:SetWidth(width)
    self:SetHitRectInsets(0, isShown and -(width + 6) or 0, 0, 0)
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
local ICON_ATTRIBUTES = { icon = true, iconCoords = true, iconR = true, iconG = true, iconB = true }

function LauncherButton.Setup()
    -- CallbackHandler's RegisterCallback takes the owner first; the IDE reads it as a method.
    ---@diagnostic disable-next-line: param-type-mismatch
    -- Data sources change their text often (some every frame), so other attributes return early.
    LDB.RegisterCallback(LauncherButton, "LibDataBroker_AttributeChanged", function(_, name, key)
        if not ICON_ATTRIBUTES[key] then
            return
        end
        local self = frames["ldb:" .. name]
        if self then
            SetIcon(self)
        end
    end)
end
