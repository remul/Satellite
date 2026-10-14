local _, ns = ...

-- The always open style: no launcher, just the menu, open all the time, like a drawer that can't
-- be closed. By default it sits left of the minimap; drag the menu to move it (when unlocked, or
-- with Shift).
local Style = { alwaysOpen = true, isMovable = true }
ns.Styles.alwaysOpen = Style

-- Space between the menu and the minimap's border, by default.
local MINIMAP_GAP = 12

-- A frame the size of a point, where the menu's right end is; dragging moves it.
local holder

function Style:Show()
    if not holder then
        holder = CreateFrame("Frame", "SatelliteMenuHolder", UIParent)
        holder:SetSize(1, 1)
        holder:SetFrameStrata(ns.Theme.STRATA)
        holder:SetFrameLevel(10)
        holder:SetMovable(true)
        holder:SetClampedToScreen(true)
        ns.Launcher.SetupMover(ns.Menu.GetPanel(), Style)
    end
    holder:Show()
end

function Style:Hide()
    if holder then
        holder:Hide()
    end
end

function Style:Refresh()
    holder:ClearAllPoints()
    local position = ns.Launcher.GetPosition("alwaysOpen")
    if position then
        holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", position.x, position.y)
    else
        holder:SetPoint("CENTER", Minimap, "LEFT", -MINIMAP_GAP, 0)
    end
    -- While dragged, the whole menu stays on the screen: it's left of the holder, centred on it.
    local width, height = ns.Menu.GetSize()
    holder:SetClampRectInsets(-width, 0, height / 2, -height / 2)
    ns.Menu.SetFrameLevel(holder:GetFrameLevel() + 1)
    ns.Menu.Place(holder, holder, "CENTER", 0, 0, "LEFT")
end

function Style:OnProgress()
end

function Style:SetHovered()
end

-- Dragging the menu moves the holder, and the menu with it.
function Style:OnDragStart()
    Style.isDragging = true
    holder:StartMoving()
end

function Style:OnDragStop()
    Style.isDragging = false
    holder:StopMovingOrSizing()
    -- Satellite keeps the place (see Launcher.SavePosition), not the game's layout file.
    holder:SetUserPlaced(false)
    ns.Launcher.SavePosition("alwaysOpen", holder)
end
