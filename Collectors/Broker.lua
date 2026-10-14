local _, ns = ...

-- Collects the buttons of addons that use LibDataBroker, the most common way to have a minimap
-- button (LibDBIcon draws it from the addon's data object). Satellite bundles both libraries, so
-- this works whichever addon loads first: LibStub keeps a single copy for all of them.
local Broker = {}
ns.Broker = Broker

local LDB = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

-- LibDataBroker's object types: launchers are buttons that open something; data sources show
-- text (e.g. coordinates or gold) and may also be clickable.
Broker.LAUNCHER = "launcher"
Broker.DATA_SOURCE = "data source"

-- Adds the object to Satellite's buttons (again, if it was removed).
function Broker.Collect(name, dataObject)
    ns.Buttons.Add({
        key = "ldb:" .. name,
        source = "ldb",
        name = name,
        label = dataObject.label or name,
        type = dataObject.type,
        dataObject = dataObject,
    })
end

-- LibDBIcon's minimap buttons that Satellite hides, as its menu shows them instead: they're
-- moved into a hidden frame, so they stay hidden whatever the addon does with them.
-- [button] = its own parent, to put it back.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local originalParents = {}

-- LibDBIcon's minimap button for an object name, or nil. The button's name in LibDBIcon may
-- differ from the object's (RareScanner's object is RareScannerLDB, its button
-- RareScannerMinimapIcon), so it's found by the object it draws.
local function GetMinimapButton(name)
    local dataObject = LDB:GetDataObjectByName(name)
    if not dataObject then
        return nil
    end
    local minimapButton = LibDBIcon:GetMinimapButton(name)
    if minimapButton and minimapButton.dataObject == dataObject then
        return minimapButton
    end
    for _, other in pairs(LibDBIcon.objects) do
        if other.dataObject == dataObject then
            return other
        end
    end
    return nil
end

-- Hides or shows the addon's own minimap button, as the settings say.
local function UpdateMinimapButton(minimapButton)
    local name = minimapButton.dataObject and LDB:GetNameByDataObject(minimapButton.dataObject)
    local button = name and ns.Buttons.Get("ldb:" .. name)
    local hide = ns.db.hideMinimapButtons and button ~= nil and ns.Buttons.IsInLauncher(button)
    -- Checks where it is each time: another button collector may have moved it since.
    local parent = minimapButton:GetParent()
    if hide then
        if parent ~= hiddenParent then
            originalParents[minimapButton] = parent
            minimapButton:SetParent(hiddenParent)
        end
    elseif originalParents[minimapButton] then
        -- Put back only if it's still hidden here, not taken out of another addon's bar.
        if parent == hiddenParent then
            minimapButton:SetParent(originalParents[minimapButton])
        end
        originalParents[minimapButton] = nil
    end
end

-- Hides or shows every addon's own minimap button, after the settings or buttons changed.
function Broker.UpdateMinimapButtons()
    for _, minimapButton in pairs(LibDBIcon.objects) do
        UpdateMinimapButton(minimapButton)
    end
end

-- Whether the addon shows this object as a button on the minimap (with LibDBIcon).
function Broker.HasMinimapButton(button)
    return GetMinimapButton(button.name) ~= nil
end

-- Called once ns.db is loaded.
function Broker:Setup()
    for name, dataObject in LDB:DataObjectIterator() do
        Broker.Collect(name, dataObject)
    end
    -- CallbackHandler's RegisterCallback takes the owner first; the IDE reads it as a method.
    ---@diagnostic disable-next-line: param-type-mismatch
    LDB.RegisterCallback(self, "LibDataBroker_DataObjectCreated", function(_, name, dataObject)
        Broker.Collect(name, dataObject)
        ns.Compartment.Refresh()
    end)
    -- CallbackHandler adds RegisterCallback to LibDBIcon when it loads; the IDE can't see it.
    ---@diagnostic disable-next-line: undefined-field
    LibDBIcon.RegisterCallback(self, "LibDBIcon_IconCreated", function(_, minimapButton)
        UpdateMinimapButton(minimapButton)
        -- Now that it has a minimap button, the launcher shows it.
        ns.Buttons.NotifyChanged()
    end)
    ns.Buttons.OnChanged(Broker.UpdateMinimapButtons)
end
