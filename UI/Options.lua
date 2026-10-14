local _, ns = ...
local L = ns.L

-- Satellite's category in Blizzard's Options (AddOns tab), with the account's settings in ns.db,
-- grouped under section headers.
local Options = {}
ns.Options = Options

local category, layout

local function Register(key, varType, label, default)
    return Settings.RegisterAddOnSetting(category, "Satellite_" .. key, key, ns.db, varType, label, default)
end

local function AddCheckbox(key, label, tooltip, default, onChanged)
    local setting = Register(key, Settings.VarType.Boolean, label, default or false)
    Settings.CreateCheckbox(category, setting, tooltip)
    if onChanged then
        setting:SetValueChangedCallback(onChanged)
    end
end

local function AddSection(name)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name))
end

-- Called once ns.db is loaded.
function Options:Setup()
    category, layout = Settings.RegisterVerticalLayoutCategory(ns.TITLE)

    -- The addons' own minimap buttons follow (Broker and Blizzard listen for changes).
    local function OnButtonsChanged()
        ns.Buttons.NotifyChanged()
    end
    AddSection(L["Buttons"])
    AddCheckbox("hideMinimapButtons", L["Hide the addons' own minimap buttons"],
        L["Satellite shows these buttons in its menu, so the minimap stays clear."], true, OnButtonsChanged)
    AddCheckbox("showWithoutMinimapButton", L["Show addons without a minimap button"],
        L["Addons that are only in the addon compartment, or only show in broker displays, appear in the menu too."],
        false, OnButtonsChanged)
    AddCheckbox("includeExpansionButton", L["Include Blizzard's expansion button"],
        L["The landing page's button (order hall, covenant sanctum, Omnium Folio...) goes in the menu too."],
        false, OnButtonsChanged)

    -- The launcher's look and place have their own panel beside the menu (see Launcher/Settings.lua).
    AddSection(L["Launcher"])
    layout:AddInitializer(CreateSettingsButtonInitializer(L["Launcher settings"], L["Open"], function()
        -- Hiding Blizzard's panel from here in combat can block its own changes; Satellite's
        -- panel shows over it anyway.
        if not InCombatLockdown() then
            HideUIPanel(SettingsPanel)
        end
        ns.Settings.Show()
    end, L["Or right-click the launcher."], true))

    AddSection(L["Development"])
    AddCheckbox("debug", L["Debug messages in chat"], L["Shows details in chat, for troubleshooting."])

    Settings.RegisterAddOnCategory(category)
end

-- Blizzard's Options can't be opened in combat: the launcher's own settings open instead.
function Options:Open()
    if InCombatLockdown() then
        ns.Settings.Show()
        return
    end
    Settings.OpenToCategory(category:GetID())
end
