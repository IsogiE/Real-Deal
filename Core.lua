local ADDON, ns = ...

local CreateFrame, C_Timer = CreateFrame, C_Timer
local issecretvalue = _G.issecretvalue

local L = {
    LootCoin = "Loot Coin",
    LootCoinDesc = "Shows a reminder after a boss that can drop a Tarnished Undermine Real dies",
    LootCoinText = "LOOT COIN",
    LootCoinDuration = "Hide after",
    LootCoinReminder = "Reminder",
    LootCoinToday = "Today",
    LootCoinLooted = "%d / %d coins looted",
    LootCoinResetsIn = "Resets in %s",
    ShowReminder = "Show reminder",
    Unlock = "Preview and move",
    TextAppearance = "Text Appearance",
    Font = "Font",
    FontSize = "Font size",
    Outline = "Outline",
    None = "None",
    ThickOutline = "Thick Outline",
    TextColor = "Text Color",
    ResetPosition = "Reset position",
    ForeverOnly = "Real Deal only works on the Forever client.",
    MinimapIcon = "Minimap icon",
    MinimapHint = "Click to open"
}
ns.L = L

local Mod = {sources = {}}
ns.Mod = Mod

local NPC_ID_FIELD = 6
local COIN_CURRENCY_ID, COIN_ITEM_ID = 3469, 226404
local DEFAULT_FONT = "Friz Quadrata TT"
local BUILTIN_FONTS = {
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Skurri"] = "Fonts\\SKURRI.TTF"
}
local ANCHOR_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true
}
local OUTLINES = {[""] = true, OUTLINE = true, THICKOUTLINE = true}

local function isSecret(value)
    return issecretvalue and issecretvalue(value) or false
end
ns.IsSecret = isSecret

local function publicNumber(value)
    if isSecret(value) then return end
    local number = tonumber(value)
    if number and number == number and math.abs(number) < math.huge then return number end
end

local function isForeverClient()
    local version = GetBuildInfo and GetBuildInfo()
    local major, minor
    if type(version) == "string" and not isSecret(version) then
        major, minor = version:match("^(%d+)%.(%d+)")
    end
    major, minor = tonumber(major), tonumber(minor)
    return major == 1 and minor ~= nil and minor >= 60
end

local function sharedMedia()
    local LibStub = _G.LibStub
    return LibStub and LibStub("LibSharedMedia-3.0", true) or nil
end

function Mod:Print(text)
    print("|cff1784d1Real Deal|r: " .. text)
end

function Mod:FontList()
    local seen, out = {}, {}
    for name in pairs(BUILTIN_FONTS) do
        seen[name] = true
        out[#out + 1] = name
    end
    local media = sharedMedia()
    if media then
        for _, name in ipairs(media:List("font")) do
            if not seen[name] then
                seen[name] = true
                out[#out + 1] = name
            end
        end
    end
    table.sort(out)
    return out
end

local function fontPath(name)
    local media = sharedMedia()
    local path = media and media:Fetch("font", name, true)
    return path or BUILTIN_FONTS[name] or STANDARD_TEXT_FONT
end

local lookups
local function getLookups()
    if lookups then return lookups end
    lookups = {instances = {}, byEncounter = {}, byNPC = {}}
    for _, source in ipairs(Mod.sources) do
        if source.enabled ~= false and source.instanceID then
            lookups.instances[source.instanceID] = true
            for _, boss in ipairs(source.bosses or {}) do
                if boss.coin ~= false then
                    lookups.byEncounter[boss.encounter] = boss
                    if boss.npc then lookups.byNPC[boss.npc] = boss end
                end
            end
        end
    end
    return lookups
end

local function currentInstanceID()
    return publicNumber((select(8, GetInstanceInfo())))
end

local function npcIDFromGUID(guid)
    if type(guid) ~= "string" or isSecret(guid) then return end
    return tonumber((select(NPC_ID_FIELD, strsplit("-", guid))))
end

function Mod:GetDaily(key)
    local char = self.char
    if not char then return {} end
    char[key] = type(char[key]) == "table" and char[key] or {}
    local records, now = char[key], time()
    for encounterID, expires in pairs(records) do
        if type(expires) ~= "number" or expires <= now then records[encounterID] = nil end
    end
    return records
end

local function nextDailyReset()
    local untilReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset
        and publicNumber(C_DateAndTime.GetSecondsUntilDailyReset())
    return time() + (untilReset or 86400)
end

function Mod:CountKill(encounterID)
    local kills = self:GetDaily("lootCoinKills")
    if kills[encounterID] then return false end
    kills[encounterID] = nextDailyReset()
    return true
end

function Mod:MarkLooted(encounterID)
    self:GetDaily("lootCoinLooted")[encounterID] = nextDailyReset()
    if ns.OnCoinsUpdated then ns.OnCoinsUpdated() end
end

function Mod:IsLootedToday(encounterID)
    return self:GetDaily("lootCoinLooted")[encounterID] ~= nil
end

function Mod:GetCoinList()
    local looted, out = self:GetDaily("lootCoinLooted"), {}
    for _, source in ipairs(self.sources) do
        if source.enabled ~= false then
            local bosses = {}
            for _, boss in ipairs(source.bosses or {}) do
                if boss.coin ~= false then
                    bosses[#bosses + 1] = {name = boss.name, looted = looted[boss.encounter] ~= nil}
                end
            end
            out[#out + 1] = {name = source.name, instanceID = source.instanceID, bosses = bosses}
        end
    end
    return out
end

function Mod:GetCoinIcon()
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(COIN_CURRENCY_ID)
    local icon = info and publicNumber(info.iconFileID)
    if not icon and C_Item and C_Item.GetItemIconByID then icon = publicNumber(C_Item.GetItemIconByID(COIN_ITEM_ID)) end
    return icon or "Interface\\Icons\\INV_Misc_Coin_01"
end

local function isCoinSlot(slot)
    local currencyID = publicNumber((select(4, GetLootSlotInfo(slot))))
    if currencyID == COIN_CURRENCY_ID then return true end
    local link = GetLootSlotLink(slot)
    if type(link) ~= "string" or isSecret(link) then return false end
    return link:find("currency:" .. COIN_CURRENCY_ID .. "[:|]") ~= nil
        or link:find("item:" .. COIN_ITEM_ID .. "[:|]") ~= nil
end

function Mod:IsEnabled()
    return self.active == true and self.db.enabled ~= false
end

function Mod:EnsureSettings()
    local db = self.db
    if db.enabled == nil then db.enabled = true end
    db.enabled = db.enabled == true
    db.font = type(db.font) == "table" and db.font or {}
    local font = db.font
    font.name = type(font.name) == "string" and font.name or DEFAULT_FONT
    font.size = math.max(8, math.min(100, publicNumber(font.size) or 48))
    font.outline = OUTLINES[font.outline] and font.outline or "OUTLINE"
    font.color = type(font.color) == "table" and font.color or {1, 0.82, 0, 1}
    db.duration = math.max(3, math.min(60, publicNumber(db.duration) or 10))
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    db.minimap.hide = db.minimap.hide == true
    self:GetPosition()
end

function Mod:GetPosition()
    self.db.position = type(self.db.position) == "table" and self.db.position or {}
    local position = self.db.position
    position.point = ANCHOR_POINTS[position.point] and position.point or "CENTER"
    position.x = publicNumber(position.x) or 0
    position.y = publicNumber(position.y) or 200
    return position
end

function Mod:EnsureDisplay()
    if self.frame then return end
    local frame = CreateFrame("Frame", "RealDealReminderFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        if Mod.editMode and not InCombatLockdown() then f:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        Mod:SavePosition()
    end)
    frame.mover = frame:CreateTexture(nil, "BACKGROUND")
    frame.mover:SetAllPoints(frame)
    frame.mover:SetColorTexture(0.09, 0.52, 0.82, 0.3)
    frame.mover:Hide()
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text:SetJustifyH("CENTER")
    frame:Hide()
    self.frame = frame
    self:ApplyFont()
    self:ApplyPosition()
end

function Mod:ApplyFont()
    local frame = self.frame
    if not frame then return end
    local font = self.db.font
    frame.text:SetFont(fontPath(font.name), font.size, font.outline)
    if not frame.text:GetFont() then frame.text:SetFont(STANDARD_TEXT_FONT, font.size, font.outline) end
    local color = font.color
    frame.text:SetTextColor(color[1] or 1, color[2] or 0.82, color[3] or 0, color[4] or 1)
    frame.text:SetText(L.LootCoinText)
    local width = publicNumber(frame.text:GetStringWidth()) or 0
    frame:SetSize(math.max(120, width + 24), font.size + 16)
end

function Mod:ApplyPosition()
    local frame = self.frame
    if not frame then return end
    local position = self:GetPosition()
    frame:ClearAllPoints()
    frame:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

function Mod:SavePosition(position)
    if not position then
        local frame = self.frame
        local x, y = frame and frame:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if not (x and y and parentX and parentY) then return end
        position = {point = "CENTER", x = x - parentX, y = y - parentY}
    end
    self.db.position = {point = position.point, x = position.x, y = position.y}
    self:ApplyPosition()
end

function Mod:ResetPosition()
    self:SavePosition({point = "CENTER", x = 0, y = 200})
end

function Mod:Refresh()
    self:EnsureSettings()
    if not self.frame then return end
    self:ApplyFont()
    self:ApplyPosition()
    self:RefreshDisplay()
end

function Mod:SetEditMode(enabled)
    self.editMode = enabled == true and self.active == true and not InCombatLockdown()
    if self.editMode then self:EnsureDisplay() end
    self:RefreshDisplay()
end

function Mod:SetPreviewMode(enabled)
    self.previewMode = enabled == true and self.active == true and not InCombatLockdown()
    if self.previewMode then self:EnsureDisplay() end
    self:RefreshDisplay()
end

function Mod:RefreshDisplay()
    local frame = self.frame
    if not frame then return end
    frame:EnableMouse(self.editMode == true)
    frame.mover:SetShown(self.editMode == true)
    if self.pending or self.editMode or self.previewMode then
        frame:Show()
    else
        frame:Hide()
    end
end

function Mod:Clear()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self.pending = nil
    self:RefreshDisplay()
end

local function coinCount()
    local total = 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(COIN_CURRENCY_ID)
        if info then
            local quantity = publicNumber(info.quantity)
            if not quantity then return end
            total = total + quantity
        end
    end
    if C_Item and C_Item.GetItemCount then
        total = total + (publicNumber(C_Item.GetItemCount(COIN_ITEM_ID)) or 0)
    end
    return total
end

function Mod:CoinLooted()
    local awaiting = self.awaiting
    self.awaiting = nil
    self:MarkLooted(awaiting.encounterID)
    if self.pending and self.pending.encounterID == awaiting.encounterID then self:Clear() end
end

function Mod:OnCurrencyUpdate(_, currencyType, _, quantityChange)
    if not self.awaiting then return end
    if publicNumber(currencyType) == COIN_CURRENCY_ID and (publicNumber(quantityChange) or 0) > 0 then
        return self:CoinLooted()
    end
    self:CheckCoinCount()
end

function Mod:CheckCoinCount()
    local awaiting = self.awaiting
    if not awaiting then return end
    local count = coinCount()
    if not count then return end
    if not awaiting.coins then
        awaiting.coins = count
    elseif count > awaiting.coins then
        self:CoinLooted()
    end
end

-- The coin is still tracked for the daily page when the reminder text is switched off.
function Mod:Remind(encounterID, npcID)
    self:Clear()
    self.awaiting = {encounterID = encounterID, coins = coinCount() or self.preFightCoins}
    if self.db.enabled == false then return end
    self:EnsureDisplay()
    self.pending = {encounterID = encounterID, npcID = npcID}
    self.hideTimer = C_Timer.NewTimer(self.db.duration, function()
        self.hideTimer = nil
        self:Clear()
    end)
    self:RefreshDisplay()
end

function Mod:OnEncounterEnd(_, encounterID, _, _, _, success)
    encounterID, success = publicNumber(encounterID), publicNumber(success)
    if success ~= 1 or not encounterID then return end
    local known = getLookups()
    local boss = known.byEncounter[encounterID]
    if not boss or not known.instances[currentInstanceID()] then return end
    if not self:CountKill(encounterID) then return end
    self:Remind(encounterID, boss.npc)
end

function Mod:OnLootOpened()
    local pending, known = self.pending, getLookups()
    local opensPending = false
    self.coinSlots = {}
    for slot = 1, (publicNumber(GetNumLootItems()) or 0) do
        local npcID = npcIDFromGUID(GetLootSourceInfo(slot))
        if pending and pending.npcID and npcID == pending.npcID then opensPending = true end
        if isCoinSlot(slot) then
            local boss = npcID and known.byNPC[npcID]
            self.coinSlots[slot] = boss and boss.encounter or nil
        end
    end
    if opensPending then self:Clear() end
end

function Mod:OnLootSlotCleared(_, slot)
    slot = publicNumber(slot)
    local encounterID = slot and self.coinSlots and self.coinSlots[slot]
    if not encounterID then return end
    self.coinSlots[slot] = nil
    if self.awaiting and self.awaiting.encounterID == encounterID then self.awaiting = nil end
    self:MarkLooted(encounterID)
    if self.pending and self.pending.encounterID == encounterID then self:Clear() end
end

function Mod:OnLootClosed()
    self.coinSlots = nil
end

function Mod:OnEnteringWorld()
    if not IsInInstance() then
        self.awaiting = nil
        self:Clear()
    end
end

function Mod:NotePreFightCoins()
    self.preFightCoins = coinCount() or self.preFightCoins
end

function Mod:OnCombatStart()
    self:NotePreFightCoins()
    self.editMode, self.previewMode = false, false
    self:RefreshDisplay()
    if ns.OnModesCleared then ns.OnModesCleared() end
end

local EVENTS = {
    ENCOUNTER_END = "OnEncounterEnd",
    LOOT_OPENED = "OnLootOpened",
    LOOT_SLOT_CLEARED = "OnLootSlotCleared",
    LOOT_CLOSED = "OnLootClosed",
    PLAYER_ENTERING_WORLD = "OnEnteringWorld",
    PLAYER_REGEN_DISABLED = "OnCombatStart",
    ENCOUNTER_START = "NotePreFightCoins",
    PLAYER_REGEN_ENABLED = "CheckCoinCount",
    CURRENCY_DISPLAY_UPDATE = "OnCurrencyUpdate",
    BAG_UPDATE_DELAYED = "CheckCoinCount"
}

local listener = CreateFrame("Frame")
listener:RegisterEvent("ADDON_LOADED")
listener:RegisterEvent("PLAYER_LOGIN")
listener:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        RealDealDB = type(RealDealDB) == "table" and RealDealDB or {}
        RealDealCharDB = type(RealDealCharDB) == "table" and RealDealCharDB or {}
        Mod.db, Mod.char = RealDealDB, RealDealCharDB
        Mod.editMode, Mod.previewMode = false, false
        Mod:EnsureSettings()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not Mod.db or not isForeverClient() then
            Mod.idleReason = L.ForeverOnly
            return
        end
        Mod.active = true
        Mod:EnsureDisplay()
        Mod:Refresh()
        Mod:SetupMinimapIcon()
        for name in pairs(EVENTS) do self:RegisterEvent(name) end
    else
        local handler = EVENTS[event]
        if handler then Mod[handler](Mod, event, ...) end
    end
end)

function Mod:SetupMinimapIcon()
    local LibStub = _G.LibStub
    local broker = LibStub and LibStub("LibDataBroker-1.1", true)
    local icons = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (broker and icons) or self.minimapIcons then return end
    local object = broker:NewDataObject("RealDeal", {
        type = "launcher",
        text = "Real Deal",
        icon = self:GetCoinIcon(),
        OnClick = function()
            if ns.ToggleOptions then ns.ToggleOptions() end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cff1784d1Real|r Deal")
            tooltip:AddLine(L.MinimapHint, 1, 1, 1)
        end
    })
    if not object then return end
    icons:Register("RealDeal", object, self.db.minimap)
    self.minimapIcons = icons
end

function Mod:SetMinimapIconShown(shown)
    self.db.minimap.hide = not shown
    local icons = self.minimapIcons
    if not icons then return end
    if shown then icons:Show("RealDeal") else icons:Hide("RealDeal") end
end

local function open()
    if not Mod.active then
        Mod:Print(Mod.idleReason or L.ForeverOnly)
        return
    end
    if ns.ToggleOptions then ns.ToggleOptions() end
end

SLASH_REALDEAL1 = "/realdeal"
SLASH_REALDEAL2 = "/lootcoin"
SlashCmdList.REALDEAL = open

function RealDeal_OnAddonCompartmentClick()
    open()
end
