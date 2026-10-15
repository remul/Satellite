local _, ns = ...

-- Brings the minimap buttons that addons make by hand (found by Scan) into the menu. Unlike a
-- LibDataBroker object, such a button is only a frame: its clicks, tooltip and menus live in the
-- addon's own scripts. So the frame itself goes into the menu, invisible, over the menu's button
-- for it (see LauncherButton), which shows its icon in the menu's look; the addon's frame takes
-- the mouse, so it works as it did on the minimap. While Satellite has it, the frame's methods
-- that would move it back (SetPoint, SetParent...) do nothing for the addon; letting it go puts
-- back everything as it was. Protected frames are never moved.
local Handmade = {}
ns.Handmade = Handmade

local LDB = LibStub("LibDataBroker-1.1")

-- What the addon can't do with its frame while Satellite has it: move it (back to the minimap,
-- or along its ring when dragged), put it in another layer, or show it.
local LOCKED_METHODS = {
    "SetParent", "ClearAllPoints", "SetPoint", "SetAllPoints", "StartMoving",
    "SetFrameStrata", "SetFrameLevel", "SetAlpha",
}
local function DoNothing() end

-- Blizzard's minimap button art around an addon's icon (as LibDBIcon draws it), not the icon.
local FRAME_ART_IDS = {
    [136430] = true, -- Interface\Minimap\MiniMap-TrackingBorder
    [136467] = true, -- Interface\Minimap\UI-Minimap-Background
    [136477] = true, -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight
}
local FRAME_ART_PATHS = { "minimap%-trackingborder", "ui%-minimap%-background", "ui%-minimap%-zoombutton%-highlight" }
-- Hand-made buttons that stay on the minimap until the player ticks them (see IsHiddenByDefault):
-- [frame name] = true.
local STAY_ON_MINIMAP = {
    -- Plumber's expansion summary button: Plumber has a LibDBIcon button for it too, and swaps
    -- between the two with its own setting.
    PlumberLandingPageMinimapButton = true,
}
-- Where to look for the icon first: textures on these layers, in this order.
local LAYER_ORDER = { ARTWORK = 1, BORDER = 2, OVERLAY = 3, BACKGROUND = 4 }

-- While no menu button holds a frame (the menu hasn't been opened yet), it waits in here.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- [frame] = what Satellite changed on it, to put back: { methods, own, parent, points, strata,
-- level, alpha, insets }, its button's key, and the menu button it's over now (menuButton).
local taken = {}
-- [frame] = the texture that shows its icon (false: none found).
local iconTextures = {}

-- Icons ------------------------------------------------------------------------------------------

local function IsFrameArt(texture)
    local file = texture:GetTexture()
    if type(file) == "number" then
        return FRAME_ART_IDS[file] == true
    elseif type(file) == "string" then
        file = file:lower()
        for _, pattern in ipairs(FRAME_ART_PATHS) do
            if file:find(pattern) then
                return true
            end
        end
        return false
    end
    -- Without a file it shows nothing (or an atlas, checked by the caller).
    return texture:GetAtlas() == nil
end

-- The texture that shows the addon's icon on frame, or nil: the first one on the frame (or one
-- level down) that isn't Blizzard's border, background or highlight, on the ARTWORK layer first.
local function FindIconTexture(frame)
    local skip = {}
    if frame:IsObjectType("Button") then
        for _, texture in ipairs({ frame:GetHighlightTexture(), frame:GetPushedTexture() }) do
            skip[texture] = true
        end
    end
    local best, bestRank
    local function Check(owner, depth)
        for _, region in ipairs({ owner:GetRegions() }) do
            if region:GetObjectType() == "Texture" and not skip[region] and not IsFrameArt(region) then
                local rank = (LAYER_ORDER[region:GetDrawLayer()] or 9) + depth * 10
                if not bestRank or rank < bestRank then
                    best, bestRank = region, rank
                end
            end
        end
    end
    Check(frame, 0)
    for _, child in ipairs({ frame:GetChildren() }) do
        Check(child, 1)
    end
    return best
end

local function GetIconTexture(frame)
    if iconTextures[frame] == nil then
        iconTextures[frame] = FindIconTexture(frame) or false
    end
    return iconTextures[frame] or nil
end

-- Shows the icon of button's frame on the texture icon; false if it has none (then its addon's
-- TOC icon, see GetFallbackIcon).
function Handmade.CopyIcon(icon, button)
    local source = GetIconTexture(button.frame)
    if not source then
        return false
    end
    local atlas = source:GetAtlas()
    if atlas then
        icon:SetAtlas(atlas)
    else
        icon:SetTexture(source:GetTexture())
        icon:SetTexCoord(source:GetTexCoord())
    end
    icon:SetVertexColor(source:GetVertexColor())
    return true
end

-- The icon in the addon's TOC (## IconTexture), or nil.
function Handmade.GetFallbackIcon(button)
    return button.addon and C_AddOns.GetAddOnMetadata(button.addon, "IconTexture")
end

-- What button's icon looks like now, as a string (see LauncherButton.GetIconLook).
function Handmade.GetIconLook(button)
    local source = GetIconTexture(button.frame)
    if not source then
        return ""
    end
    local r, g, b = source:GetVertexColor()
    return format("%s %.2f %.2f %.2f", tostring(source:GetAtlas() or source:GetTexture()), r, g, b)
end

-- Taking and letting go --------------------------------------------------------------------------

-- Puts the taken frame over menuButton, covering it (and its name, where clicks on it count), and
-- above it to take the mouse; without one, in the hidden frame.
local function Place(frame, state, menuButton)
    local methods = state.methods
    state.menuButton = menuButton
    methods.ClearAllPoints(frame)
    if not menuButton then
        methods.SetParent(frame, hiddenParent)
        methods.SetPoint(frame, "CENTER")
        return
    end
    methods.SetParent(frame, menuButton)
    methods.SetPoint(frame, "TOPLEFT", menuButton)
    methods.SetPoint(frame, "BOTTOMRIGHT", menuButton)
    methods.SetFrameStrata(frame, menuButton:GetFrameStrata())
    methods.SetFrameLevel(frame, menuButton:GetFrameLevel() + 5)
    frame:SetHitRectInsets(menuButton:GetHitRectInsets())
end

local function Take(button)
    local frame = button.frame
    -- The widget's own methods, which Satellite still uses while the addon's do nothing.
    local methods = getmetatable(frame).__index
    local state = {
        key = button.key,
        methods = methods,
        own = {},
        parent = frame:GetParent(),
        points = {},
        strata = frame:GetFrameStrata(),
        level = frame:GetFrameLevel(),
        alpha = frame:GetAlpha(),
        insets = { frame:GetHitRectInsets() },
    }
    for index = 1, frame:GetNumPoints() do
        state.points[index] = { frame:GetPoint(index) }
    end
    for _, name in ipairs(LOCKED_METHODS) do
        -- The addon may have set its own on the frame.
        state.own[name] = rawget(frame, name)
        frame[name] = DoNothing
    end
    taken[frame] = state
    methods.SetAlpha(frame, 0)
    Place(frame, state, ns.LauncherButton.GetFrame(button.key))
    ns:Debug("Took", button.key)
end

local function Release(frame)
    local state = taken[frame]
    taken[frame] = nil
    if state.menuButton then
        state.menuButton:UnlockHighlight()
    end
    for _, name in ipairs(LOCKED_METHODS) do
        frame[name] = state.own[name]
    end
    local methods = state.methods
    methods.SetParent(frame, state.parent)
    methods.ClearAllPoints(frame)
    for _, point in ipairs(state.points) do
        methods.SetPoint(frame, unpack(point))
    end
    methods.SetFrameStrata(frame, state.strata)
    methods.SetFrameLevel(frame, state.level)
    methods.SetAlpha(frame, state.alpha)
    frame:SetHitRectInsets(unpack(state.insets))
    ns:Debug("Let go of", frame:GetName())
end

-- Puts button's frame over its menu button (see Menu), if Satellite has it.
function Handmade.Attach(button, menuButton)
    local state = taken[button.frame]
    if state then
        Place(button.frame, state, menuButton)
    end
end

-- The addon's LibDBIcon button (shown or not), from the same addon folder as its icon, by its
-- object's name and the object; or nil. That one is in the menu already.
local function GetBrokerTwin(button)
    if not button.addon then
        return nil
    end
    local addon = ns.Compartment.Simplify(button.addon)
    for name, dataObject in LDB:DataObjectIterator() do
        if ns.Compartment.GetIconFolder(dataObject.icon) == addon
            and ns.Broker.GetMinimapButton(dataObject) then
            return name, dataObject
        end
    end
    return nil
end

-- The addon's title, and with a LibDBIcon button too, what that one is called, to tell them
-- apart and show they're the same: "Plumber (Expansion Summary)".
local function UpdateLabel(button)
    local name, dataObject = GetBrokerTwin(button)
    local twinLabel = name and ns.Broker.GetLabel(name, dataObject)
    if twinLabel and twinLabel ~= button.title then
        button.label = format("%s (%s)", button.title, twinLabel)
    else
        button.label = button.title
    end
end

-- Whether button's frame can go in the menu (see Buttons.IsInLauncher): while the player wants
-- hand-made buttons and the addons' own buttons hidden, and while its addon shows it. It's listed
-- in the settings then; unticked there (see Buttons.IsHidden), it stays on the minimap.
function Handmade.IsCollected(button)
    local frame = button.frame
    return ns.db.collectHandmadeButtons and ns.db.hideMinimapButtons and frame:IsShown()
        and not frame:IsProtected()
end

-- Whether button stays on the minimap until the player ticks it: when its addon also has a
-- LibDBIcon button (in the menu already), or swaps its own for one (see STAY_ON_MINIMAP).
function Handmade.IsHiddenByDefault(button)
    return STAY_ON_MINIMAP[button.name] == true or GetBrokerTwin(button) ~= nil
end

-- Takes the frames that go in the menu, and lets go of the others (also of those whose button
-- is gone, or that the player unticked: those go back on the minimap).
function Handmade.Update()
    for frame, state in pairs(taken) do
        if not ns.Buttons.Get(state.key) then
            Release(frame)
        end
    end
    for _, button in ipairs(ns.Buttons.GetAll()) do
        if button.source == "frame" then
            UpdateLabel(button)
            local isIn = ns.Buttons.IsInLauncher(button) and not ns.Buttons.IsHidden(button.key)
            if isIn and not taken[button.frame] then
                Take(button)
            elseif not isIn and taken[button.frame] then
                Release(button.frame)
            end
        end
    end
end

-- Watching ---------------------------------------------------------------------------------------

-- Starts following button's frame, found by Scan: the menu button lights up while it's hovered
-- and closes the menu after a click (as its own buttons do); the menu follows when the addon
-- shows or hides it, or changes its icon. Hooks can't be taken off, so this is done once per frame
-- and does nothing while Satellite doesn't have it.
function Handmade.Watch(button)
    local frame, key = button.frame, button.key
    frame:HookScript("OnEnter", function()
        local state = taken[frame]
        if state and state.menuButton then
            state.menuButton:LockHighlight()
        end
    end)
    frame:HookScript("OnLeave", function()
        local state = taken[frame]
        if state and state.menuButton then
            state.menuButton:UnlockHighlight()
        end
    end)
    frame:HookScript(frame:IsObjectType("Button") and "OnClick" or "OnMouseUp", function(_, mouseButton)
        local state = taken[frame]
        if state and state.menuButton then
            ns.LauncherButton.AfterClick(state.menuButton, mouseButton)
        end
    end)
    -- Its own shown state: OnShow and OnHide would also fire when Satellite moves it. Some addons
    -- show their button again and again, or set its icon every frame: only changes count.
    local wasShown = frame:IsShown()
    local function OnShownChanged()
        if frame:IsShown() ~= wasShown then
            wasShown = frame:IsShown()
            ns.Buttons.NotifyChanged()
        end
    end
    hooksecurefunc(frame, "Show", OnShownChanged)
    hooksecurefunc(frame, "Hide", OnShownChanged)
    hooksecurefunc(frame, "SetShown", OnShownChanged)
    local icon = GetIconTexture(frame)
    if icon then
        local look = Handmade.GetIconLook(button)
        local function OnIconChanged()
            local newLook = Handmade.GetIconLook(button)
            if newLook ~= look then
                look = newLook
                ns.LauncherButton.RefreshIcon(key)
                ns.Alert.Check(key)
            end
        end
        hooksecurefunc(icon, "SetTexture", OnIconChanged)
        hooksecurefunc(icon, "SetAtlas", OnIconChanged)
        hooksecurefunc(icon, "SetVertexColor", OnIconChanged)
    end
end

-- Called once ns.db is loaded. Everything goes back before logging out, for addons that save
-- where their button is then.
function Handmade:Setup()
    ns.Buttons.OnChanged(Handmade.Update)
    ns:RegisterEvent("PLAYER_LOGOUT", function()
        for frame in pairs(taken) do
            Release(frame)
        end
    end)
end
