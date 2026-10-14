local _, ns = ...

-- The launcher: what opens the menu with the buttons (see Menu), in one of several styles (see
-- Launcher/Styles): a button on the minimap's ring, the compass arrow, a circle or square you can
-- put anywhere, a bar on the edge of the screen, or no launcher at all with the menu always open.
-- This picks the style and gives every style the same clicks, tooltip and dragging: right-click
-- for the settings (see Settings); drag to move when unlocked, or with Shift.
local Launcher = {}
ns.Launcher = Launcher

-- The styles, by key (each file in Launcher/Styles adds its own): see Styles/Arrow.lua for what a
-- style has.
ns.Styles = ns.Styles or {}
Launcher.DEFAULT_STYLE = "satellite"

local isReady = false
local current -- the style shown now

function Launcher.GetStyle()
    return ns.Styles[ns.db.style] or ns.Styles[Launcher.DEFAULT_STYLE]
end

-- Redraws after the style, the settings, the minimap's size or the buttons changed.
function Launcher.Refresh()
    if not isReady then
        return
    end
    local style = Launcher.GetStyle()
    if style ~= current then
        if current then
            current:Hide()
        end
        current = style
        ns.Menu.Reset(style.alwaysOpen, function(progress)
            style:OnProgress(progress)
        end)
    end
    ns.Compass.Update()
    style:Show()
    -- The style places the menu from its size, so that's measured first.
    ns.Menu.Measure()
    style:Refresh()
    ns.Menu.Refresh()
    -- A new style starts with the menu closed; with the settings open, it opens again, so the
    -- changes show.
    if ns.Settings.IsShown() and not ns.Menu.IsOpen() then
        ns.Menu.Open()
    end
    ns.Settings.Update()
end

function Launcher.Toggle()
    if not current.alwaysOpen then
        ns.Menu.Toggle()
    end
end

-- Shared behaviour -------------------------------------------------------------------------------

-- Whether the current style's launcher moves when dragged: when it's unlocked, or with Shift.
local function CanMove()
    return current.isMovable and (not ns.db.locked or IsShiftKeyDown())
end

-- Only while the menu is closed: open, the tooltip would cover it, and the menu shows what it is.
local function ShowTooltip(owner)
    if ns.Menu.IsOpen() then
        if GameTooltip:IsOwned(owner) then
            GameTooltip:Hide()
        end
        return
    end
    local L = ns.L
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip_SetTitle(GameTooltip, ns.TITLE)
    GameTooltip_AddNormalLine(GameTooltip, L["Click to show your addon buttons."])
    GameTooltip_AddInstructionLine(GameTooltip, L["Right-click for settings."])
    if current.isMovable then
        GameTooltip_AddInstructionLine(GameTooltip, ns.db.locked and L["Shift-drag to move."] or L["Drag to move."])
    end
    GameTooltip:Show()
end

-- When a drag last ended: the click that ends a drag doesn't open or close the menu.
local lastDragTime = 0

-- Makes frame move the current style's launcher when dragged (see CanMove); with onlyStyle, only
-- while that style is the current one (the menu's panel, for the Always open style).
function Launcher.SetupMover(frame, onlyStyle)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if (not onlyStyle or current == onlyStyle) and CanMove() then
            GameTooltip:Hide()
            current:OnDragStart()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if current.isDragging then
            current:OnDragStop()
            lastDragTime = GetTime()
            Launcher.Refresh()
        end
    end)
end

-- Makes button open and close the menu (and the settings, with a right-click), light up with it
-- while hovered, and move the launcher when dragged.
function Launcher.SetupOpener(button)
    button:RegisterForClicks("AnyUp")
    Launcher.SetupMover(button)
    button:SetScript("OnEnter", function(self)
        current:SetHovered(true)
        ns.Menu.SetHovered(true)
        ShowTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        current:SetHovered(false)
        ns.Menu.SetHovered(false)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if GetTime() - lastDragTime < 0.2 then
            return
        end
        if mouseButton == "RightButton" then
            ns.Settings.Toggle()
        else
            Launcher.Toggle()
        end
        if self:IsMouseOver() then
            ShowTooltip(self)
        end
    end)
end


-- The launcher's size setting, as a factor (1 is its normal size); each style multiplies its
-- sizes with it.
function Launcher.GetScale()
    return ns.db.launcher.scale / 100
end

-- Saved places --------------------------------------------------------------------------------

-- Where the player dragged a style's launcher to: its center, from the screen's bottom left
-- (in UIParent's units), or nil while it's in its default place.
function Launcher.GetPosition(key)
    return ns.db.positions[key]
end

function Launcher.SavePosition(key, frame)
    local x, y = frame:GetCenter()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ns.db.positions[key] = { x = x * scale, y = y * scale }
end

-- Whether a style's launcher is docked on an edge of the screen (the circle and square).
function Launcher.IsDocked(key)
    local position = ns.db.positions[key]
    return position ~= nil and position.edge ~= nil
end

-- Puts every launcher back in its default place.
function Launcher.ResetPositions()
    wipe(ns.db.positions)
    ns.db.sideBar.side, ns.db.sideBar.offset = "RIGHT", 0
    Launcher.Refresh()
end

-- Which way the menu opens from frame: toward the middle of the screen.
function Launcher.GetDirection(frame)
    local x = frame:GetCenter()
    if not x then
        return "LEFT"
    end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * scale > UIParent:GetWidth() / 2 and "LEFT" or "RIGHT"
end

-- Called once ns.db is loaded; the frames are made at login, once the minimap has its size.
function Launcher:Setup()
    ns:RegisterEvent("PLAYER_LOGIN", function()
        ns.Menu.Setup()
        ns.Compass:Setup()
        ns.LauncherButton.Setup()
        isReady = true
        Launcher.Refresh()

        ns.Buttons.OnChanged(Launcher.Refresh)
        -- The guild is known a moment after login, and can change: the Prisma logo (see IconStack)
        -- shows or goes. The roster updates often; only a change of guild redraws.
        local wasInPrisma = ns.IconStack.IsInPrisma()
        local function OnGuildChanged()
            local isInPrisma = ns.IconStack.IsInPrisma()
            if isInPrisma ~= wasInPrisma then
                wasInPrisma = isInPrisma
                Launcher.Refresh()
            end
        end
        ns:RegisterEvent("PLAYER_GUILD_UPDATE", OnGuildChanged)
        ns:RegisterEvent("GUILD_ROSTER_UPDATE", OnGuildChanged)
        Minimap:HookScript("OnSizeChanged", Launcher.Refresh)
        -- The expansion button shows once the expansion's features are unlocked.
        if ExpansionLandingPageMinimapButton then
            ExpansionLandingPageMinimapButton:HookScript("OnShow", Launcher.Refresh)
        end
    end)
end
