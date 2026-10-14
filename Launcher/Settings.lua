local _, ns = ...
local L = ns.L

-- The launcher's settings: a panel beside the open menu, opened by right-clicking the launcher (or
-- from Blizzard's Options). The menu stays open, so every change shows at once. Three tabs:
-- "Launcher" in two columns (the launcher's look; the menu's layout), "Buttons", a list of the
-- menu's buttons to show, hide and order, and "Behavior" (opening and closing; the launcher's
-- place, locked or free to drag).
local Settings = {}
ns.Settings = Settings

local Theme = ns.Theme

-- In interface units: a column's width, the padding, the space between the columns, between rows,
-- and between the panel and the menu.
local COLUMN_WIDTH = 230
local PADDING = 16
local COLUMN_GAP = 20
local ROW_SPACING = 10
local MENU_GAP = 8
-- The Buttons tab: its list's height, a row's height, and the sort button's width.
local LIST_HEIGHT = 300
local LIST_ROW_HEIGHT = 26
local SORT_WIDTH = 150
-- The Buttons tab's options under the list (in ns.db; also in Blizzard's Options, see
-- UI/Options.lua).
local BUTTON_OPTIONS = {
    { "hideMinimapButtons", "Hide the addons' own minimap buttons" },
    { "collectHandmadeButtons", "Collect hand-made minimap buttons" },
    { "showWithoutMinimapButton", "Show addons without a minimap button" },
    { "includeExpansionButton", "Include Blizzard's expansion button" },
}
-- The triangle texture (pointing left) turned up or down, in the eight-value form.
local POINTING_UP = { 0, 0, 1, 0, 0, 1, 1, 1 }
local POINTING_DOWN = { 1, 0, 0, 0, 1, 1, 0, 1 }

local STYLES = {
    { "satellite", "Minimap button", "A round button on the minimap's ring. Drag it around the ring." },
    { "arrow", "Compass arrow", "Replaces the minimap's west arrow, or sits beside it." },
    { "circle", "Circle", "A button you can put anywhere. Drag it against an edge of the screen to dock it there." },
    { "square", "Square", "A button you can put anywhere. Drag it against an edge of the screen to dock it there." },
    { "sideBar", "Side bar", "A bar on an edge of the screen: left, right, top or bottom. Drag it along the edge, or to another one." },
    { "alwaysOpen", "Always open", "No button: the menu stays open all the time." },
}

local function GetStyleInfo(key)
    for _, info in ipairs(STYLES) do
        if info[1] == key then
            return info
        end
    end
    return STYLES[1]
end

local panel
-- The tab shown: "launcher", "buttons" or "behavior".
local currentTab = "launcher"
-- Whether the panel stays where it is on the screen, until it's closed: once a setting changed
-- (the menu may grow or shrink with it, and the slider being dragged must stay under the mouse),
-- or once the player dragged it. Until then it follows the menu, which may still be opening.
local isFixed = false

-- Keeps the panel where it is now on the screen (see isFixed).
local function FixPlace()
    if isFixed or not panel:GetLeft() then
        return
    end
    isFixed = true
    -- Where it will be once the menu is open, if it's still opening.
    local left, top = panel:GetLeft(), panel:GetTop()
    local x, y = ns.Menu.GetDistanceToOpen()
    local scale = UIParent:GetEffectiveScale() / panel:GetEffectiveScale()
    left, top = left + x * scale, top + y * scale
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

-- Saves a change from the panel and redraws the launcher, with the panel staying put.
local function Apply(setValue, value)
    FixPlace()
    setValue(value)
    ns.Launcher.Refresh()
end

-- Controls ---------------------------------------------------------------------------------------

local function CreateRow(height)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(COLUMN_WIDTH, height)
    return row
end

local function AddLabel(row, text)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("TOPLEFT")
    row.label:SetText(text)
end

-- A group's title, with a thin line under it.
local function CreateHeader(text)
    local row = CreateRow(22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("TOPLEFT")
    row.label:SetText(text)
    local line = row:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(Theme.GOLD:GetRGB())
    line:SetAlpha(0.35)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    return row
end

-- A slider with a label above it and the value on its right (shown with valueFormat: a format
-- string, "%d" if nil, or a function(value) returning the text).
local function CreateSlider(label, minValue, maxValue, getValue, setValue, valueFormat)
    local row = CreateRow(42)
    AddLabel(row, label)
    row.slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    row.slider:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.slider:SetWidth(COLUMN_WIDTH - 30)
    local formatters = {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
            MinimalSliderWithSteppersMixin.Label.Right, function(value)
                if type(valueFormat) == "function" then
                    return valueFormat(value)
                end
                return format(valueFormat or "%d", value)
            end),
    }
    function row.Update()
        row.slider:Init(getValue(), minValue, maxValue, maxValue - minValue, formatters)
    end
    row.slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = math.floor(value + 0.5)
        if value ~= getValue() then
            Apply(setValue, value)
        end
    end, row)
    return row
end

-- A checkbox, with a line of help under its label if help is given.
local function CreateCheckbox(label, getValue, setValue, help)
    local row = CreateRow(26)
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(26, 26)
    row.check:SetPoint("LEFT")
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.label:SetPoint("RIGHT")
    row.label:SetJustifyH("LEFT")
    row.label:SetText(label)
    if help then
        -- The box at the top, the label level with it, and the help under the label.
        row.check:ClearAllPoints()
        row.check:SetPoint("TOPLEFT")
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", row.check, "TOPRIGHT", 4, -6)
        row.label:SetPoint("RIGHT")
        row.help = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.help:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
        row.help:SetPoint("RIGHT")
        row.help:SetJustifyH("LEFT")
        row.help:SetText(help)
    end
    row.check:SetScript("OnClick", function(self)
        Apply(setValue, self:GetChecked())
    end)
    function row.Update()
        row.check:SetChecked(getValue())
        -- Taller when the label wraps, or with help under it.
        local height = row.label:GetStringHeight() + 8
        if row.help then
            height = 6 + row.label:GetStringHeight() + 3 + row.help:GetStringHeight() + 2
        end
        row:SetHeight(math.max(26, height))
    end
    return row
end

-- A dropdown with a label above it: options are { text, value } pairs, or a function returning
-- them (for options that come and go).
local function CreateDropdown(label, options, getValue, setValue)
    local row = CreateRow(44)
    AddLabel(row, label)
    row.dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    row.dropdown:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.dropdown:SetWidth(COLUMN_WIDTH)
    local function IsSelected(value)
        return getValue() == value
    end
    local function SetSelected(value)
        Apply(setValue, value)
    end
    row.dropdown:SetupMenu(function(_, root)
        for _, option in ipairs(type(options) == "function" and options() or options) do
            root:CreateRadio(option[1], IsSelected, SetSelected, option[2])
        end
    end)
    function row.Update()
        row.dropdown:GenerateMenu()
    end
    return row
end

-- The style dropdown, with a line under it saying what the chosen style is.
local function CreateStyleRow()
    local options = {}
    for _, info in ipairs(STYLES) do
        options[#options + 1] = { L[info[2]], info[1] }
    end
    local row = CreateDropdown(L["Style"], options, function()
        return ns.db.style
    end, function(value)
        ns.db.style = value
    end)
    row.help = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.help:SetPoint("TOPLEFT", row.dropdown, "BOTTOMLEFT", 0, -6)
    row.help:SetPoint("RIGHT")
    row.help:SetJustifyH("LEFT")
    function row.Update()
        row.dropdown:GenerateMenu()
        row.help:SetText(L[GetStyleInfo(ns.db.style)[3]])
        row:SetHeight(44 + row.help:GetStringHeight() + 6)
    end
    return row
end

local function CreateButton(text, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(COLUMN_WIDTH, 24)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

-- The Buttons tab --------------------------------------------------------------------------------
-- Blizzard's scroll list with its drag behaviour: drag a row by its grip (or
-- anywhere on it) to a new place, with a line showing where it goes, or use its arrows.

local function GetListWidth()
    return 2 * COLUMN_WIDTH + COLUMN_GAP
end

-- A small gold triangle button, pointing up or down, for moving a button in the list.
local function CreateArrowButton(parent, coords, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(18, 18)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(Theme.TRIANGLE)
    button.icon:SetSize(11, 7)
    button.icon:SetPoint("CENTER")
    ---@diagnostic disable-next-line: redundant-parameter
    button.icon:SetTexCoord(unpack(coords))
    button.icon:SetVertexColor(Theme.GOLD:GetRGBA())
    button:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(Theme.GOLD_HOVER:GetRGBA())
    end)
    button:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(Theme.GOLD:GetRGBA())
    end)
    button:SetScript("OnClick", onClick)
    return button
end

local function SetArrowEnabled(button, isEnabled)
    button:SetEnabled(isEnabled)
    button:SetAlpha(isEnabled and 1 or 0.25)
end

-- A drag grip (two columns of three dots), to show that a row can be dragged.
local GRIP_DOT, GRIP_GAP = 2, 2
local function CreateDragGrip(parent)
    local grip = CreateFrame("Frame", nil, parent)
    grip:SetSize(2 * GRIP_DOT + GRIP_GAP, 3 * GRIP_DOT + 2 * GRIP_GAP)
    for column = 0, 1 do
        for row = 0, 2 do
            local dot = grip:CreateTexture(nil, "ARTWORK")
            dot:SetColorTexture(Theme.SILVER.r, Theme.SILVER.g, Theme.SILVER.b, 0.8)
            dot:SetSize(GRIP_DOT, GRIP_DOT)
            dot:SetPoint("TOPLEFT", column * (GRIP_DOT + GRIP_GAP), -row * (GRIP_DOT + GRIP_GAP))
        end
    end
    return grip
end

-- A row of the list (template: SatelliteButtonListRowTemplate, see UI/Templates.xml): the grip, a
-- checkbox (shown in the menu or not), the icon and name, and the arrows.
local RowMixin = {}
_G.SatelliteButtonListRowMixin = RowMixin

function RowMixin:OnLoad()
    self.stripe = self:CreateTexture(nil, "BACKGROUND")
    self.stripe:SetAllPoints()
    self.stripe:SetColorTexture(1, 1, 1, 0.04)
    self.highlight = self:CreateTexture(nil, "BACKGROUND", nil, 1)
    self.highlight:SetAllPoints()
    self.highlight:SetColorTexture(1, 0.82, 0.3, 0.08)
    self.highlight:Hide()
    self.grip = CreateDragGrip(self)
    self.grip:SetPoint("LEFT", 6, 0)
    self.check = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
    self.check:SetSize(24, 24)
    self.check:SetPoint("LEFT", self.grip, "RIGHT", 6, 0)
    self.check:SetScript("OnClick", function(check)
        FixPlace()
        ns.Buttons.SetHidden(self.key, not check:GetChecked())
    end)
    self.icon = self:CreateTexture(nil, "ARTWORK")
    self.icon:SetSize(18, 18)
    self.icon:SetPoint("LEFT", self.check, "RIGHT", 4, 0)
    self.down = CreateArrowButton(self, POINTING_DOWN, function()
        FixPlace()
        ns.Buttons.Move(self.key, 1)
    end)
    self.down:SetPoint("RIGHT", -2, 0)
    self.up = CreateArrowButton(self, POINTING_UP, function()
        FixPlace()
        ns.Buttons.Move(self.key, -1)
    end)
    self.up:SetPoint("RIGHT", self.down, "LEFT", -2, 0)
    self.name = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.name:SetPoint("LEFT", self.icon, "RIGHT", 6, 0)
    self.name:SetPoint("RIGHT", self.up, "LEFT", -6, 0)
    self.name:SetJustifyH("LEFT")
    self.name:SetWordWrap(false)
    -- Lights up while hovered, also over its checkbox and arrows.
    local function UpdateHighlight()
        self.highlight:SetShown(self:IsMouseOver())
    end
    self:SetScript("OnEnter", UpdateHighlight)
    self:SetScript("OnLeave", UpdateHighlight)
    for _, child in ipairs({ self.check, self.up, self.down }) do
        child:HookScript("OnEnter", UpdateHighlight)
        child:HookScript("OnLeave", UpdateHighlight)
    end
end

-- data: { button, index, count }.
function RowMixin:Init(data)
    local button = data.button
    self.key = button.key
    local isShown = not ns.Buttons.IsHidden(button.key)
    self.stripe:SetShown(data.index % 2 == 0)
    self.check:SetChecked(isShown)
    ns.LauncherButton.SetIconTexture(self.icon, button)
    self.icon:SetDesaturated(not isShown)
    self.name:SetText(button.label)
    self.name:SetFontObject(isShown and "GameFontHighlight" or "GameFontDisable")
    SetArrowEnabled(self.up, data.index > 1)
    SetArrowEnabled(self.down, data.index < data.count)
end

local function CreateButtonsPage()
    local page = CreateFrame("Frame", nil, panel)
    -- The hint, the list, and the options and sort button under it (its height is set below).
    page:SetWidth(GetListWidth())
    page.hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.hint:SetPoint("TOPLEFT")
    page.hint:SetWidth(GetListWidth())
    page.hint:SetJustifyH("LEFT")
    page.hint:SetText(L["Untick a button to take it out of the menu; a hand-made one goes back to the minimap. Drag a row, or use its arrows, to change the order."])

    -- The list, with a thin scroll bar on its right.
    page.scrollBox = CreateFrame("Frame", nil, page, "WowScrollBoxList")
    page.scrollBox:SetPoint("TOPLEFT", page.hint, "BOTTOMLEFT", 0, -6)
    page.scrollBox:SetSize(GetListWidth() - 16, LIST_HEIGHT)
    page.scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
    page.scrollBar:SetPoint("TOPLEFT", page.scrollBox, "TOPRIGHT", 6, 0)
    page.scrollBar:SetPoint("BOTTOMLEFT", page.scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(LIST_ROW_HEIGHT)
    view:SetElementInitializer("SatelliteButtonListRowTemplate", function(row, data)
        row:Init(data)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(page.scrollBox, page.scrollBar, view)

    -- Dropping a row saves the list's new order.
    local dragBehavior = ScrollUtil.InitDefaultLinearDragBehavior(page.scrollBox)
    dragBehavior:SetReorderable(true)
    dragBehavior:SetPostDrop(function(contextData)
        local keys = {}
        for _, data in contextData.dataProvider:Enumerate() do
            keys[#keys + 1] = data.button.key
        end
        FixPlace()
        ns.Buttons.SetOrder(keys)
    end)
    -- A list that changed during a drag (see UpdateButtonsPage) is filled again once it ends,
    -- also when the drag was let go of outside the list.
    dragBehavior:SetNotifyDragStart(function(_, isDragging)
        if not isDragging and page.isStale then
            page.isStale = false
            C_Timer.After(0, Settings.Update)
        end
    end)
    page.dragBehavior = dragBehavior

    -- Under the list: which buttons it has (also in Blizzard's Options), and the sort button on
    -- the right.
    page.sort = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    page.sort:SetSize(SORT_WIDTH, 24)
    page.sort:SetPoint("TOPRIGHT", page.scrollBar, "BOTTOMRIGHT", 0, -10)
    page.sort:SetText(L["Sort by name"])
    page.sort:SetScript("OnClick", function()
        FixPlace()
        ns.Buttons.ResetOrder()
    end)
    -- Each under the one before, or under its label when that wraps (in longer languages).
    page.options = {}
    local optionsHeight = 0
    for index, option in ipairs(BUTTON_OPTIONS) do
        local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", page.scrollBox, "BOTTOMLEFT", 0, -10 - optionsHeight)
        check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        check.label:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -5)
        check.label:SetWidth(GetListWidth() - SORT_WIDTH - COLUMN_GAP - 28)
        check.label:SetJustifyH("LEFT")
        check.label:SetText(L[option[2]])
        optionsHeight = optionsHeight + math.max(24, check.label:GetStringHeight() + 10) + 2
        check.key = option[1]
        check:SetScript("OnClick", function(self)
            FixPlace()
            ns.db[self.key] = self:GetChecked()
            -- The addons' own minimap buttons follow (Broker and Blizzard listen for changes).
            ns.Buttons.NotifyChanged()
        end)
        page.options[index] = check
    end
    page:SetHeight(page.hint:GetStringHeight() + 6 + LIST_HEIGHT + 10 + optionsHeight)
    page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    page.empty:SetPoint("TOP", page.scrollBox, "TOP", 0, -20)
    page.empty:SetText(L["No buttons found yet."])
    return page
end

-- Fills the list with the buttons, in the menu's order, keeping where it's scrolled to.
local function UpdateButtonsPage(page)
    -- Not while a row is being dragged: the list would change under it.
    if page.dragBehavior:GetDragging() then
        page.isStale = true
        return
    end
    local buttons = ns.Buttons.GetCandidates()
    local entries = {}
    for index, button in ipairs(buttons) do
        entries[index] = { button = button, index = index, count = #buttons }
    end
    page.scrollBox:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.RetainScrollPosition)
    for _, check in ipairs(page.options) do
        check:SetChecked(ns.db[check.key])
    end
    page.empty:SetShown(#buttons == 0)
end

-- The tabs, at the top right beside the title.
local function CreateTab(text, key)
    local tab = CreateFrame("Button", nil, panel)
    tab.key = key
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.text:SetPoint("CENTER")
    tab.text:SetText(text)
    tab:SetSize(tab.text:GetStringWidth() + 20, 24)
    tab.line = tab:CreateTexture(nil, "ARTWORK")
    tab.line:SetColorTexture(Theme.GOLD:GetRGB())
    tab.line:SetHeight(2)
    tab.line:SetPoint("BOTTOMLEFT", 6, 0)
    tab.line:SetPoint("BOTTOMRIGHT", -6, 0)
    tab:SetScript("OnClick", function()
        currentTab = key
        Settings.Update()
    end)
    return tab
end

local function UpdateTabs()
    for _, tab in ipairs(panel.tabs) do
        local isCurrent = tab.key == currentTab
        tab.line:SetShown(isCurrent)
        tab.text:SetFontObject(isCurrent and "GameFontHighlight" or "GameFontDisable")
    end
end

-- The panel -------------------------------------------------------------------------------------

local function CreatePanel()
    panel = CreateFrame("Frame", "SatelliteSettings", UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:SetWidth(2 * COLUMN_WIDTH + COLUMN_GAP + 2 * PADDING)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Satellite places it again next time, not the game's layout file.
        self:SetUserPlaced(false)
        isFixed = true
    end)
    panel:SetScript("OnHide", function()
        isFixed = false
    end)
    -- Escape closes it, like Blizzard's windows.
    tinsert(UISpecialFrames, panel:GetName())
    Theme.AddBox(panel, Theme.PANEL_FILL, Theme.PANEL_BORDER, Theme.PANEL_RADIUS)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    panel.title:SetPoint("TOPLEFT", PADDING, -PADDING)
    panel.title:SetText(ns.TITLE)
    panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.close:SetPoint("TOPRIGHT", -4, -4)
    panel.tabs = {
        CreateTab(L["Launcher"], "launcher"),
        CreateTab(L["Buttons"], "buttons"),
        CreateTab(L["Behavior"], "behavior"),
    }
    panel.tabs[3]:SetPoint("RIGHT", panel.close, "LEFT", -6, 0)
    panel.tabs[2]:SetPoint("RIGHT", panel.tabs[3], "LEFT", -4, 0)
    panel.tabs[1]:SetPoint("RIGHT", panel.tabs[2], "LEFT", -4, 0)
    panel.buttonsPage = CreateButtonsPage()

    panel.rows = {
        lookHeader = CreateHeader(L["Look"]),
        style = CreateStyleRow(),
        scale = CreateSlider(L["Launcher size"], 50, 200, function()
            return ns.Launcher.GetScalePercent()
        end, function(value)
            ns.Launcher.SetScalePercent(value)
        end, "%d%%"),
        borderColor = CreateDropdown(L["Border color"], {
            { L["Gold"], "gold" },
            { L["Silver"], "silver" },
            { L["Bronze"], "bronze" },
            { L["Class color"], "class" },
        }, function()
            return ns.db.borderColor
        end, function(value)
            ns.db.borderColor = value
        end),
        -- Prisma's logo, only for the guild's members (see IconStack).
        discSymbols = CreateDropdown(L["Symbols"], function()
            local options = { { L["Dragon, potion, sword"], "adventure" }, { L["Your class and spec"], "class" } }
            if ns.IconStack.IsInPrisma() then
                options[#options + 1] = { "Prisma", "prisma" }
            end
            return options
        end, function()
            -- Prisma's logo after leaving the guild shows the default symbols (see IconStack).
            if ns.db.discSymbols == "prisma" and not ns.IconStack.IsInPrisma() then
                return "adventure"
            end
            return ns.db.discSymbols
        end, function(value)
            ns.db.discSymbols = value
        end),
        discColors = CreateDropdown(L["Symbol colors"], {
            { L["Colored"], "colored" },
            { L["Silver"], "silver" },
            { L["Gold"], "gold" },
            { L["Bronze"], "bronze" },
            { L["Class color"], "class" },
        }, function()
            return ns.db.discColors
        end, function(value)
            ns.db.discColors = value
        end),
        replaceCompassArrow = CreateCheckbox(L["Replace the minimap's west arrow"], function()
            return ns.db.replaceCompassArrow
        end, function(value)
            ns.db.replaceCompassArrow = value
        end),
        gap = CreateSlider(L["Distance from the minimap"], 0, 40, function()
            return ns.db.launcher.gap
        end, function(value)
            ns.db.launcher.gap = value
        end),

        menuHeader = CreateHeader(L["Menu"]),
        buttonSize = CreateSlider(L["Button size"], 20, 40, function()
            return ns.db.launcher.buttonSize
        end, function(value)
            ns.db.launcher.buttonSize = value
        end),
        buttonShape = CreateDropdown(L["Button shape"], {
            { L["Circle"], "circle" },
            { L["Minimap button"], "minimap" },
            { L["Square"], "square" },
            { L["Diamond"], "diamond" },
        }, function()
            return ns.db.buttonShape
        end, function(value)
            ns.db.buttonShape = value
        end),
        menuRows = CreateSlider(L["Buttons per column"], 0, 12, function()
            return ns.db.menuRows
        end, function(value)
            ns.db.menuRows = value
        end, function(value)
            return value == 0 and L["Auto"] or format("%d", value)
        end),
        menuLabels = CreateDropdown(L["Show"], {
            { L["Icons"], "icons" },
            { L["Icons and names"], "both" },
            { L["Names only"], "names" },
        }, function()
            return ns.db.menuLabels
        end, function(value)
            ns.db.menuLabels = value
        end),
        alertsHeader = CreateHeader(L["Alerts"]),
        showAlerts = CreateCheckbox(L["Show a dot when an addon's icon changes"], function()
            return ns.db.showAlerts
        end, function(value)
            ns.db.showAlerts = value
        end),
        openingHeader = CreateHeader(L["Opening and closing"]),
        openOnHover = CreateCheckbox(L["Open on mouseover"], function()
            return ns.db.openOnHover
        end, function(value)
            ns.db.openOnHover = value
        end),
        closeOnLeave = CreateCheckbox(L["Close when the mouse leaves"], function()
            return ns.db.closeOnLeave
        end, function(value)
            ns.db.closeOnLeave = value
        end),
        closeOnClick = CreateCheckbox(L["Close after clicking a button"], function()
            return ns.db.closeOnClick
        end, function(value)
            ns.db.closeOnClick = value
        end),
        openDirection = CreateDropdown(L["Opens toward"], {
            { L["The middle of the screen"], "AUTO" },
            { L["Left"], "LEFT" },
            { L["Right"], "RIGHT" },
            { L["Up"], "UP" },
            { L["Down"], "DOWN" },
        }, function()
            return ns.db.openDirection
        end, function(value)
            ns.db.openDirection = value
        end),

        positionHeader = CreateHeader(L["Position"]),
        locked = CreateCheckbox(L["Lock position"], function()
            return ns.db.locked
        end, function(value)
            ns.db.locked = value
        end, L["Shift-drag still moves it."]),
        reset = CreateButton(L["Reset position"], function()
            FixPlace()
            ns.Launcher.ResetPositions()
        end),
    }
    panel:Hide()
end

-- Beside the menu, on its far side from the launcher (or for a menu opening up or down, on the
-- side with more room), until it stays put (see isFixed).
local function PlacePanel()
    if isFixed then
        return
    end
    local menu = ns.Menu.GetPanel()
    local direction = ns.Menu.GetDirection()
    if direction == "UP" or direction == "DOWN" then
        local x = menu:GetCenter()
        direction = (x and x * menu:GetEffectiveScale() / UIParent:GetEffectiveScale() > UIParent:GetWidth() / 2)
            and "LEFT" or "RIGHT"
    end
    panel:ClearAllPoints()
    if direction == "LEFT" then
        panel:SetPoint("TOPRIGHT", menu, "TOPLEFT", -MENU_GAP, 0)
    else
        panel:SetPoint("TOPLEFT", menu, "TOPRIGHT", MENU_GAP, 0)
    end
end

-- The top of the tabs' content, below the title.
local function GetContentTop()
    return PADDING + panel.title:GetStringHeight() + ROW_SPACING + 4
end

-- Lays out one column of rows ({ row, isShown } pairs) from the top; returns its height.
local function LayoutColumn(entries, left)
    local y = GetContentTop()
    for _, entry in ipairs(entries) do
        local row, isShown = entry[1], entry[2]
        row:SetShown(isShown)
        if isShown then
            if row.Update then
                row.Update()
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -y)
            y = y + row:GetHeight() + ROW_SPACING
        end
    end
    return y
end

-- The rows of a tab ("launcher" or "behavior") that apply to the current style, in columns of
-- { row, isShown } pairs.
local function GetColumns(tab)
    local rows = panel.rows
    local style = ns.db.style
    local launcher = ns.Launcher.GetStyle()
    local columns
    if tab == "behavior" then
        -- The Always open style's menu doesn't open or close.
        local canClose = not launcher.alwaysOpen
        -- Docked on an edge, the circle and square open away from it.
        local hasDirection = (style == "circle" or style == "square") and not ns.Launcher.IsDocked(style)
        columns = {
            {
                { rows.openingHeader, canClose or hasDirection },
                { rows.openOnHover, canClose },
                { rows.closeOnClick, canClose },
                { rows.closeOnLeave, canClose },
                { rows.openDirection, hasDirection },
            },
            {
                -- A dot needs a launcher to sit on.
                { rows.alertsHeader, canClose },
                { rows.showAlerts, canClose },
                { rows.positionHeader, launcher.isMovable },
                { rows.locked, launcher.isMovable },
                { rows.reset, launcher.isMovable },
            },
        }
    else
        local isArrow = style == "arrow"
        local hasDiscs = style == "satellite" or style == "circle" or style == "square"
        columns = {
            {
                { rows.lookHeader, true },
                { rows.style, true },
                { rows.scale, not launcher.alwaysOpen },
                -- The menu's border too, so for every style.
                { rows.borderColor, true },
                { rows.discSymbols, hasDiscs },
                -- Prisma's logo has its own colours.
                { rows.discColors, hasDiscs and not (ns.db.discSymbols == "prisma" and ns.IconStack.IsInPrisma()) },
                -- A minimap that isn't round has no whole compass to take the arrow from.
                { rows.replaceCompassArrow, isArrow and ns.Launcher.IsMinimapRound() },
                { rows.gap, isArrow and not ns.Compass.IsReplaced() },
            },
            {
                { rows.menuHeader, true },
                -- Names only have no buttons to size.
                { rows.buttonSize, ns.db.menuLabels ~= "names" },
                { rows.buttonShape, ns.db.menuLabels ~= "names" },
                { rows.menuRows, true },
                { rows.menuLabels, true },
            },
        }
    end
    return columns
end

-- How tall the panel is with a tab's columns.
local function MeasureColumns(columns)
    local height = GetContentTop()
    for _, column in ipairs(columns) do
        local y = GetContentTop()
        for _, entry in ipairs(column) do
            local row, isShown = entry[1], entry[2]
            if isShown then
                if row.Update then
                    row.Update()
                end
                y = y + row:GetHeight() + ROW_SPACING
            end
        end
        height = math.max(height, y)
    end
    return height - ROW_SPACING + PADDING
end

-- Shows the current tab: the rows that apply to the current style, or the list of buttons. The
-- panel is as tall as its tallest tab, so it doesn't move when switching tabs (near the screen's
-- edge it's kept on the screen, which would move it with every change of height).
local function UpdatePanel()
    UpdateTabs()
    local page = panel.buttonsPage
    page:SetShown(currentTab == "buttons")
    for _, row in pairs(panel.rows) do
        row:Hide()
    end
    panel:SetHeight(math.max(GetContentTop() + page:GetHeight() + PADDING,
        MeasureColumns(GetColumns("launcher")), MeasureColumns(GetColumns("behavior"))))
    if currentTab == "buttons" then
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", PADDING, -GetContentTop())
        UpdateButtonsPage(page)
        PlacePanel()
        return
    end
    -- Columns with nothing to show for this style are left out; the others move left.
    local left = PADDING
    for _, column in ipairs(GetColumns(currentTab)) do
        local hasRows = false
        for _, entry in ipairs(column) do
            hasRows = hasRows or entry[2]
        end
        if hasRows then
            LayoutColumn(column, left)
            left = left + COLUMN_WIDTH + COLUMN_GAP
        end
    end
    PlacePanel()
end

-- Opening and closing ---------------------------------------------------------------------------

function Settings.IsShown()
    return panel ~= nil and panel:IsShown()
end

-- Opens the menu too, so changes show on it.
function Settings.Show()
    if not panel then
        CreatePanel()
    end
    if not ns.Menu.IsOpen() then
        ns.Menu.Open()
    end
    panel:Show()
    UpdatePanel()
end

function Settings.Hide()
    if panel then
        panel:Hide()
    end
end

function Settings.Toggle()
    if Settings.IsShown() then
        Settings.Hide()
    else
        Settings.Show()
    end
end

-- Keeps the panel in step after the launcher changed (style, size, place).
function Settings.Update()
    if Settings.IsShown() then
        UpdatePanel()
    end
end
