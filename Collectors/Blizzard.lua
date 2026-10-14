local _, ns = ...

-- Blizzard's expansion button on the minimap (the landing page: Legion's order hall, the covenant
-- sanctum, the Dragon Isles summary, the Omnium Folio...), collected like an addon's button. It's
-- only there while Blizzard shows it (once the expansion's landing page is unlocked); its title,
-- description and art change with the expansion and the player's progress.
local Blizzard = {}
ns.Blizzard = Blizzard

local KEY = "blizzard:expansion"

-- Its own minimap button, moved into a hidden frame while the menu shows it (as Broker does with
-- LibDBIcon's buttons), and its own parent, to put it back.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local originalParent
-- Its strata and frame level where Blizzard put it, before it was moved (see GetMinimapLayer).
local originalStrata, originalLevel

-- Whether Blizzard has the button out: its own shown state, whatever its parent (hidden by
-- Satellite or not).
local function IsAvailable(frame)
    return frame:IsShown()
end

-- Adds the button, or takes it out when Blizzard hides it; then hides or shows the original.
local function Update()
    local frame = ExpansionLandingPageMinimapButton
    if not frame then
        return
    end
    if IsAvailable(frame) then
        -- Its art can change with nothing else (e.g. another covenant): drawn again either way.
        ns.LauncherButton.RefreshIcon(KEY)
        ns.Buttons.Add({
            key = KEY,
            source = "blizzard",
            name = "ExpansionLandingPage",
            label = frame.title or ns.L["Expansion landing page"],
            description = frame.description,
            frame = frame,
        })
        ns.Alert.Check(KEY)
    else
        ns.Buttons.Remove(KEY)
    end
    Blizzard.UpdateMinimapButton()
end

-- Hides or shows the original on the minimap, as the settings say. Unlike the addons' buttons, it
-- comes back when the player takes it out of the menu: it has no other place to be opened from.
function Blizzard.UpdateMinimapButton()
    local frame = ExpansionLandingPageMinimapButton
    local button = ns.Buttons.Get(KEY)
    if not frame then
        return
    end
    local hide = ns.db.hideMinimapButtons and button ~= nil and ns.Buttons.IsInLauncher(button)
        and not ns.Buttons.IsHidden(KEY)
    if hide and not originalParent then
        originalParent = frame:GetParent()
        originalStrata, originalLevel = frame:GetFrameStrata(), frame:GetFrameLevel()
        frame:SetParent(hiddenParent)
    elseif not hide and originalParent then
        frame:SetParent(originalParent)
        frame:SetFrameStrata(originalStrata)
        frame:SetFrameLevel(originalLevel)
        originalParent = nil
    end
end

-- The strata and frame level of the expansion button on the minimap (where it was, while it's
-- hidden), for launchers on the minimap to sit over it; nil without one.
function Blizzard.GetMinimapLayer()
    local frame = ExpansionLandingPageMinimapButton
    if originalParent then
        return originalStrata, originalLevel
    elseif frame then
        return frame:GetFrameStrata(), frame:GetFrameLevel()
    end
end

-- The art Blizzard shows on the button now (an atlas, or a texture).
function Blizzard.GetIcon(button)
    local texture = button.frame:GetNormalTexture()
    if not texture then
        return nil
    end
    return texture:GetAtlas() or texture:GetTexture()
end

-- Opens or closes the landing page, as a click on the original does.
function Blizzard.Click(button)
    button.frame:ToggleLandingPage()
end

-- Called once ns.db is loaded; the button comes with Blizzard_Minimap.
function Blizzard:Setup()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Minimap", function()
        local frame = ExpansionLandingPageMinimapButton
        if not frame then
            return
        end
        -- Blizzard shows, hides and changes it as the player's progress changes.
        hooksecurefunc(frame, "Show", Update)
        hooksecurefunc(frame, "Hide", Update)
        hooksecurefunc(frame, "SetShown", Update)
        if frame.UpdateIcon then
            hooksecurefunc(frame, "UpdateIcon", Update)
        end
        Update()
    end)
    ns.Buttons.OnChanged(Blizzard.UpdateMinimapButton)
end
