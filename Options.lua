local _, ns = ...
local Mod, L = ns.Mod, ns.L

local WHITE = "Interface\\Buttons\\WHITE8x8"
local BACKDROP = {bgFile = WHITE, edgeFile = WHITE, edgeSize = 1}
local ACCENT = {0.09, 0.52, 0.82}
local GOLD = {1, 0.82, 0}
local DONE_COLOR = {0.25, 1, 0.25}
local CHECK_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"

local WIN_W, WIN_H, PAD, TITLE_H, TOP = 940, 600, 12, 30, 62
local SETTINGS_W, PANEL_GAP, SCROLLBAR_W = 250, 12, 8
local LIST_W = WIN_W - PAD * 2 - SETTINGS_W - PANEL_GAP
local COLUMNS, CARD_GAP, CARD_PAD, HEADER_H, BAR_H, ROW_H, ICON_SIZE = 3, 10, 10, 20, 3, 18, 14
local FONT_SIZE = 12
local POPUP_ROWS, POPUP_ROW_H = 12, 18

local OUTLINE_ITEMS = {
    {value = "", label = L.None},
    {value = "OUTLINE", label = L.Outline},
    {value = "THICKOUTLINE", label = L.ThickOutline}
}

local window, popup

local function skin(frame, alpha)
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0.06, 0.06, 0.06, alpha or 0.92)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function newText(parent, size, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
    local path, _, flags = text:GetFont()
    if path then text:SetFont(path, size or FONT_SIZE, flags or "") end
    return text
end

local function formatReset(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if hours > 0 then return ("%dh %dm"):format(hours, minutes) end
    return ("%dm"):format(math.max(1, minutes))
end

local function secondsUntilReset()
    local seconds = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset()
    if seconds == nil or ns.IsSecret(seconds) then return end
    return tonumber(seconds)
end

-- Today's coins ---------------------------------------------------------------

local function createCard(parent, source)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    skin(card, 0.6)

    local header = CreateFrame("Frame", nil, card)
    header:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -CARD_PAD)
    header:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CARD_PAD, -CARD_PAD)
    header:SetHeight(HEADER_H - 4)

    card.count = newText(header, FONT_SIZE + 1)
    card.count:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    card.count:SetJustifyH("RIGHT")

    card.title = newText(header, FONT_SIZE + 1)
    card.title:SetPoint("LEFT", header, "LEFT", 0, 0)
    card.title:SetPoint("RIGHT", card.count, "LEFT", -8, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    card.title:SetTextColor(unpack(GOLD))
    card.title:SetText(source.name)

    card.barBG = card:CreateTexture(nil, "ARTWORK")
    card.barBG:SetTexture(WHITE)
    card.barBG:SetVertexColor(1, 1, 1, 0.08)
    card.barBG:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -(CARD_PAD + HEADER_H))
    card.barBG:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CARD_PAD, -(CARD_PAD + HEADER_H))
    card.barBG:SetHeight(BAR_H)

    card.bar = card:CreateTexture(nil, "OVERLAY")
    card.bar:SetTexture(WHITE)
    card.bar:SetPoint("TOPLEFT", card.barBG, "TOPLEFT")
    card.bar:SetHeight(BAR_H)

    card.rows = {}
    for index, boss in ipairs(source.bosses) do
        local row = CreateFrame("Frame", nil, card)
        row.icon = row:CreateTexture(nil, "OVERLAY")
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(ROW_H - ICON_SIZE) / 2)
        row.name = newText(row)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("TOP")
        row.name:SetWordWrap(true)
        row.name:SetText(boss.name)
        card.rows[index] = row
    end
    return card
end

local function layoutCard(card, width)
    card:SetWidth(width)
    local textWidth = math.max(20, width - CARD_PAD * 2 - ICON_SIZE - 6)
    local y = CARD_PAD + HEADER_H + BAR_H + 6
    for _, row in ipairs(card.rows) do
        row.name:SetWidth(textWidth)
        local textHeight = row.name:GetStringHeight() or 0
        local height = math.max(ROW_H, math.ceil(textHeight) + (ROW_H - FONT_SIZE))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -y)
        row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CARD_PAD, -y)
        row:SetHeight(height)
        y = y + height
    end
    card.height = y + CARD_PAD - 2
    card:SetHeight(card.height)
    return card.height
end

local function updateCard(card, source, coinIcon, here)
    local got = 0
    for index, boss in ipairs(source.bosses) do
        local row = card.rows[index]
        if row then
            if boss.looted then
                got = got + 1
                row.icon:SetTexture(CHECK_ICON)
                row.icon:SetTexCoord(0, 1, 0, 1)
                row.name:SetTextColor(0.5, 0.5, 0.5)
            else
                row.icon:SetTexture(coinIcon)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.name:SetTextColor(1, 1, 1)
            end
        end
    end
    local total = #source.bosses
    local done = total > 0 and got >= total
    card.count:SetText(("%d / %d"):format(got, total))
    if done then card.count:SetTextColor(unpack(DONE_COLOR)) else card.count:SetTextColor(1, 1, 1) end

    local barWidth = (card:GetWidth() or 0) - CARD_PAD * 2
    local fraction = total > 0 and got / total or 0
    card.bar:SetWidth(math.max(0.01, barWidth * fraction))
    card.bar:SetShown(fraction > 0 and barWidth > 0)
    if done then card.bar:SetVertexColor(unpack(DONE_COLOR)) else card.bar:SetVertexColor(unpack(ACCENT)) end

    if here then
        card:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    else
        card:SetBackdropBorderColor(0, 0, 0, 1)
    end
    return got, total
end

local function createCoinList(parent)
    local list = {frame = CreateFrame("Frame", nil, parent)}
    local frame = list.frame
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -TOP)
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", PAD, PAD)
    frame:SetWidth(LIST_W)

    local header = newText(frame, FONT_SIZE + 2)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetTextColor(unpack(GOLD))
    header:SetText(L.LootCoinToday)

    local summaryIcon = frame:CreateTexture(nil, "OVERLAY")
    summaryIcon:SetSize(20, 20)
    summaryIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    summaryIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -24)
    local summary = newText(frame, FONT_SIZE + 2)
    summary:SetPoint("LEFT", summaryIcon, "RIGHT", 8, 0)
    local reset = newText(frame)
    reset:SetPoint("RIGHT", frame, "TOPRIGHT", 0, -34)
    reset:SetJustifyH("RIGHT")
    reset:SetTextColor(0.6, 0.6, 0.6)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -54)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(LIST_W - SCROLLBAR_W, 1)
    scroll:SetScrollChild(content)

    local thumb = frame:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.25)
    thumb:SetWidth(3)

    local contentHeight, offset = 1, 0
    local function applyScroll()
        local view = scroll:GetHeight() or 0
        local range = math.max(0, contentHeight - view)
        offset = math.max(0, math.min(range, offset))
        scroll:SetVerticalScroll(offset)
        if range <= 0 or view <= 0 then
            thumb:Hide()
            return
        end
        local thumbHeight = math.max(20, view * view / contentHeight)
        thumb:SetHeight(thumbHeight)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -(view - thumbHeight) * offset / range)
        thumb:Show()
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * 40
        applyScroll()
    end)

    local sources = Mod:GetCoinList()
    local cards = {}
    for index, source in ipairs(sources) do cards[index] = createCard(content, source) end

    local lastReset
    local function updateReset()
        local seconds = secondsUntilReset()
        if seconds and lastReset and seconds > lastReset + 60 then
            lastReset = seconds
            list.Refresh()
            return
        end
        lastReset = seconds
        reset:SetText(seconds and L.LootCoinResetsIn:format(formatReset(seconds)) or "")
    end
    list.UpdateReset = updateReset

    function list.Refresh()
        sources = Mod:GetCoinList()
        local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        if ns.IsSecret(instanceID) then instanceID = nil end
        local coinIcon = Mod:GetCoinIcon()
        local got, total = 0, 0
        for index, source in ipairs(sources) do
            if cards[index] then
                local cardGot, cardTotal = updateCard(cards[index], source, coinIcon, instanceID ~= nil and source.instanceID == instanceID)
                got, total = got + cardGot, total + cardTotal
            end
        end
        summaryIcon:SetTexture(coinIcon)
        summary:SetText(L.LootCoinLooted:format(got, total))
        updateReset()
    end

    function list.Layout()
        local width = LIST_W - SCROLLBAR_W
        local cardWidth = (width - CARD_GAP * (COLUMNS - 1)) / COLUMNS
        local heights = {}
        for column = 1, COLUMNS do heights[column] = 0 end
        for _, card in ipairs(cards) do
            local column = 1
            for c = 2, COLUMNS do
                if heights[c] < heights[column] then column = c end
            end
            local height = layoutCard(card, cardWidth)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", content, "TOPLEFT", (column - 1) * (cardWidth + CARD_GAP), -heights[column])
            heights[column] = heights[column] + height + CARD_GAP
        end
        local tallest = 0
        for column = 1, COLUMNS do tallest = math.max(tallest, heights[column]) end
        contentHeight = math.max(1, tallest - CARD_GAP)
        content:SetHeight(contentHeight)
        applyScroll()
        list.Refresh()
    end

    return list
end

-- Settings widgets --------------------------------------------------------------

local function getPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", nil, window, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    skin(popup, 1)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup.rows, popup.items, popup.offset = {}, {}, 0
    for index = 1, POPUP_ROWS do
        local row = CreateFrame("Button", nil, popup)
        row:SetHeight(POPUP_ROW_H)
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", 1, -1 - (index - 1) * POPUP_ROW_H)
        row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -1 - (index - 1) * POPUP_ROW_H)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.35)
        row.text = newText(row)
        row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self)
            local onPick = popup.onPick
            popup:Hide()
            if onPick then onPick(self.value) end
        end)
        popup.rows[index] = row
    end
    function popup.Update()
        local items = popup.items
        popup.offset = math.max(0, math.min(math.max(0, #items - POPUP_ROWS), popup.offset))
        for index, row in ipairs(popup.rows) do
            local item = items[index + popup.offset]
            if item then
                row.value = item.value
                row.text:SetText(item.label)
                if item.value == popup.current then
                    row.text:SetTextColor(unpack(GOLD))
                else
                    row.text:SetTextColor(1, 1, 1)
                end
                row:Show()
            else
                row:Hide()
            end
        end
        popup:SetHeight(math.min(#items, POPUP_ROWS) * POPUP_ROW_H + 2)
    end
    popup:SetScript("OnMouseWheel", function(_, delta)
        popup.offset = popup.offset - delta
        popup.Update()
    end)
    popup:SetScript("OnHide", function() popup.owner = nil end)
    popup:Hide()
    return popup
end

local function label(parent, text)
    local fs = newText(parent)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    fs:SetTextColor(0.8, 0.8, 0.8)
    fs:SetText(text)
    return fs
end

local function makeHeader(parent, text)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(22)
    local fs = newText(holder, FONT_SIZE + 2)
    fs:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    fs:SetTextColor(unpack(GOLD))
    fs:SetText(text)
    local line = holder:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.12)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    return holder
end

local function makeCheckbox(parent, text, get, set)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(18)
    local box = CreateFrame("Frame", nil, button, "BackdropTemplate")
    box:SetSize(14, 14)
    box:SetPoint("LEFT", button, "LEFT", 0, 0)
    skin(box, 1)
    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    check:SetColorTexture(unpack(ACCENT))
    local fs = newText(button)
    fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
    fs:SetText(text)
    function button.Refresh() check:SetShown(get() == true) end
    button:SetScript("OnClick", function()
        set(not get())
        button.Refresh()
    end)
    return button
end

local function makeSlider(parent, text, minValue, maxValue, suffix, get, set)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(36)
    label(holder, text)
    local value = newText(holder)
    value:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    local slider = CreateFrame("Slider", nil, holder, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(10)
    slider:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 2)
    slider:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 2)
    skin(slider, 1)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(unpack(ACCENT))
    thumb:SetSize(8, 14)
    slider:SetThumbTexture(thumb)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    local last
    function holder.Refresh()
        last = get()
        value:SetText(last .. (suffix or ""))
        slider:SetValue(last)
    end
    slider:SetScript("OnValueChanged", function(_, raw)
        local rounded = math.floor(raw + 0.5)
        if rounded == last then return end
        last = rounded
        value:SetText(rounded .. (suffix or ""))
        set(rounded)
    end)
    return holder
end

local function makeDropdown(parent, text, getItems, get, set)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(40)
    label(holder, text)
    local button = CreateFrame("Button", nil, holder, "BackdropTemplate")
    button:SetHeight(22)
    button:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    button:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    skin(button, 1)
    local current = newText(button)
    current:SetPoint("LEFT", button, "LEFT", 6, 0)
    current:SetPoint("RIGHT", button, "RIGHT", -18, 0)
    current:SetJustifyH("LEFT")
    current:SetWordWrap(false)
    local arrow = newText(button)
    arrow:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.6, 0.6, 0.6)
    function holder.Refresh()
        local selected = get()
        local shown = selected
        for _, item in ipairs(getItems()) do
            if item.value == selected then shown = item.label end
        end
        current:SetText(shown)
    end
    button:SetScript("OnClick", function()
        local list = getPopup()
        if list:IsShown() and list.owner == holder then
            list:Hide()
            return
        end
        list.items = getItems()
        list.current = get()
        list.offset = 0
        for index, item in ipairs(list.items) do
            if item.value == list.current then list.offset = index - 1 end
        end
        list.onPick = function(picked)
            set(picked)
            holder.Refresh()
        end
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -1)
        list:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -1)
        list.Update()
        list:Show()
        list.owner = holder
    end)
    return holder
end

local function openColorPicker(color, onChange)
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = a
        if ColorPickerFrame.GetColorAlpha then
            na = ColorPickerFrame:GetColorAlpha()
        elseif OpacitySliderFrame then
            na = 1 - (OpacitySliderFrame:GetValue() or 0)
        end
        onChange(nr, ng, nb, na)
    end
    local function cancel() onChange(r, g, b, a) end
    if type(ColorPickerFrame.SetupColorPickerAndShow) == "function" then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, opacity = a, hasOpacity = true,
            swatchFunc = apply, opacityFunc = apply, cancelFunc = cancel
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - a
        ColorPickerFrame.previousValues = {r = r, g = g, b = b, opacity = 1 - a}
        ColorPickerFrame.func = apply
        ColorPickerFrame.opacityFunc = apply
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end
end

local function makeColorSwatch(parent, text, get, set)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(20)
    local box = CreateFrame("Frame", nil, button, "BackdropTemplate")
    box:SetSize(18, 18)
    box:SetPoint("LEFT", button, "LEFT", 0, 0)
    skin(box, 1)
    local fs = newText(button)
    fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
    fs:SetText(text)
    function button.Refresh()
        local color = get()
        box:SetBackdropColor(color[1] or 1, color[2] or 1, color[3] or 1, 1)
    end
    button:SetScript("OnClick", function()
        openColorPicker(get(), function(r, g, b, a)
            set({r, g, b, a})
            button.Refresh()
        end)
    end)
    return button
end

local function makeButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetHeight(22)
    skin(button, 1)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.3)
    local fs = newText(button)
    fs:SetPoint("CENTER", button, "CENTER", 0, 0)
    fs:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function createSettingsPanel(parent)
    local panel = {frame = CreateFrame("Frame", nil, parent, "BackdropTemplate"), widgets = {}}
    local frame = panel.frame
    skin(frame, 0.6)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -TOP)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PAD, PAD)
    frame:SetWidth(SETTINGS_W)

    local y = 10
    local function add(widget, gap)
        widget:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -y)
        widget:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -y)
        y = y + widget:GetHeight() + (gap or 8)
        if widget.Refresh then panel.widgets[#panel.widgets + 1] = widget end
        return widget
    end

    local function refresh() Mod:Refresh() end

    add(makeHeader(frame, L.LootCoinReminder))
    add(makeCheckbox(frame, L.ShowReminder,
        function() return Mod.db.enabled end,
        function(value)
            Mod.db.enabled = value
            if not value then Mod:Clear() end
        end), 4)
    add(makeCheckbox(frame, L.Unlock,
        function() return Mod.editMode end,
        function(value) Mod:SetEditMode(value) end))
    add(makeSlider(frame, L.LootCoinDuration, 3, 60, "s",
        function() return Mod.db.duration or 10 end,
        function(value) Mod.db.duration = value end), 14)

    add(makeHeader(frame, L.TextAppearance))
    add(makeDropdown(frame, L.Font,
        function()
            local items = {}
            for index, name in ipairs(Mod:FontList()) do items[index] = {value = name, label = name} end
            return items
        end,
        function() return Mod.db.font.name end,
        function(value)
            Mod.db.font.name = value
            refresh()
        end))
    add(makeSlider(frame, L.FontSize, 8, 100, "",
        function() return Mod.db.font.size or 48 end,
        function(value)
            Mod.db.font.size = value
            refresh()
        end))
    add(makeDropdown(frame, L.Outline,
        function() return OUTLINE_ITEMS end,
        function() return Mod.db.font.outline or "" end,
        function(value)
            Mod.db.font.outline = value or ""
            refresh()
        end))
    add(makeColorSwatch(frame, L.TextColor,
        function() return Mod.db.font.color or {1, 0.82, 0, 1} end,
        function(value)
            Mod.db.font.color = value
            refresh()
        end), 14)
    add(makeButton(frame, L.ResetPosition, function() Mod:ResetPosition() end), 14)
    add(makeCheckbox(frame, L.MinimapIcon,
        function() return not Mod.db.minimap.hide end,
        function(value) Mod:SetMinimapIconShown(value) end))

    function panel.Refresh()
        Mod:EnsureSettings()
        for _, widget in ipairs(panel.widgets) do widget.Refresh() end
    end

    return panel
end

-- Window ---------------------------------------------------------------------------

local function buildWindow()
    window = CreateFrame("Frame", "RealDealWindow", UIParent, "BackdropTemplate")
    window:SetSize(WIN_W, WIN_H)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:SetFrameStrata("HIGH")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    skin(window)
    window:Hide()
    tinsert(UISpecialFrames, "RealDealWindow")

    local titleBar = CreateFrame("Frame", nil, window)
    titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(TITLE_H)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() window:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)

    local icon = titleBar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("LEFT", titleBar, "LEFT", PAD, 0)
    local title = newText(titleBar, FONT_SIZE + 3)
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("|cff1784d1Real|r Deal")

    local close = makeButton(titleBar, "x", function() window:Hide() end)
    close:SetSize(20, 20)
    close:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

    local desc = newText(window)
    desc:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -(TITLE_H + 6))
    desc:SetTextColor(0.7, 0.7, 0.7)
    desc:SetText(L.LootCoinDesc)

    local list = createCoinList(window)
    local settings = createSettingsPanel(window)

    local function refresh()
        icon:SetTexture(Mod:GetCoinIcon())
        list.Refresh()
        settings.Refresh()
    end

    window:SetScript("OnShow", function()
        list.Layout()
        refresh()
    end)
    window:SetScript("OnHide", function()
        if popup then popup:Hide() end
        Mod:SetEditMode(false)
        Mod:SetPreviewMode(false)
    end)
    local elapsed = 0
    window:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        list.UpdateReset()
    end)

    ns.OnCoinsUpdated = function()
        if window:IsShown() then list.Refresh() end
    end
    ns.OnModesCleared = function()
        if window:IsShown() then settings.Refresh() end
    end
end

function ns.ToggleOptions()
    if not window then buildWindow() end
    window:SetShown(not window:IsShown())
end
