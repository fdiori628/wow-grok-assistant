-- WoWGrokAssistant
-- Phase 2+3 + enhancements

local addonName, addonTable = ...
local frame = CreateFrame("Frame")

WoWGrokAssistantDB = WoWGrokAssistantDB or {}
WoWGrokAssistantDB.notes = WoWGrokAssistantDB.notes or {}
WoWGrokAssistantDB.history = WoWGrokAssistantDB.history or {}
local nextId = (WoWGrokAssistantDB.nextId or 1)
local pendingId = nil
local nextSlot = 1
local NUM_SLOTS = 20
local MAX_HISTORY = 20
local MAX_NOTES = 10
local pollTimer = nil
local chatFrame = nil
local messageText = ""
local scrollChild = nil
local statusText = nil

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[WoWGrok]|r " .. tostring(msg))
end

local function GetTimestamp()
    return date("%H:%M")
end

local function GetCharKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or ""
    return name .. "-" .. realm
end

local function RebuildMessageText()
    messageText = ""
    for _, entry in ipairs(WoWGrokAssistantDB.history) do
        local prefix
        if entry.role == "user" then
            prefix = "|cFF88CCFF[You " .. (entry.ts or "") .. "]|r "
        elseif entry.role == "grok" then
            prefix = "|cFF00AAFF[Grok " .. (entry.ts or "") .. "]|r "
        else
            prefix = "|cFFAAAAAA[System]|r "
        end
        messageText = messageText .. prefix .. (entry.text or "") .. "\n\n"
    end
    if scrollChild then
        scrollChild:SetText(messageText)
    end
end

local function AddMessage(role, text)
    local ts = GetTimestamp()
    local entry = { role = role, text = text, ts = ts }
    tinsert(WoWGrokAssistantDB.history, entry)
    while #WoWGrokAssistantDB.history > MAX_HISTORY do
        tremove(WoWGrokAssistantDB.history, 1)
    end

    local prefix
    if role == "user" then
        prefix = "|cFF88CCFF[You " .. ts .. "]|r "
    elseif role == "grok" then
        prefix = "|cFF00AAFF[Grok " .. ts .. "]|r "
    else
        prefix = "|cFFAAAAAA[System]|r "
    end
    local line = prefix .. text .. "\n\n"
    messageText = messageText .. line
    if scrollChild then
        scrollChild:SetText(messageText)
        local sf = scrollChild:GetParent()
        if sf then
            C_Timer.After(0.05, function()
                if sf.ScrollToBottom then sf:ScrollToBottom() end
            end)
        end
    end
    if role ~= "system" then
        Print(prefix .. text)
    end
end

local function SetStatus(text)
    if statusText then
        statusText:SetText(text or "")
    end
end

local CELL = 4
local CELLS_PER_ROW = 200
local MAX_ROWS = 48

local stripFrame = nil
local cellTextures = {}

local function GetPixelPerfectScale()
    local _, physicalHeight = GetPhysicalScreenSize()
    if not physicalHeight or physicalHeight <= 0 then
        physicalHeight = 1080
    end
    local uiScale = UIParent:GetEffectiveScale() or 1
    return (768 / physicalHeight) / uiScale
end

local function EnsureStrip()
    if stripFrame then
        stripFrame:SetScale(GetPixelPerfectScale())
        return
    end
    stripFrame = CreateFrame("Frame", nil, UIParent)
    stripFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    stripFrame:SetSize(CELLS_PER_ROW * CELL, MAX_ROWS * CELL)
    stripFrame:SetFrameStrata("TOOLTIP")
    stripFrame:SetFrameLevel(1000)
    stripFrame:SetScale(GetPixelPerfectScale())

    for i = 1, CELLS_PER_ROW * MAX_ROWS do
        local t = stripFrame:CreateTexture(nil, "OVERLAY")
        local col = (i - 1) % CELLS_PER_ROW
        local row = math.floor((i - 1) / CELLS_PER_ROW)
        t:SetSize(CELL, CELL)
        t:SetPoint("TOPLEFT", stripFrame, "TOPLEFT", col * CELL, -row * CELL)
        t:SetColorTexture(0, 0, 0, 1)
        t:Hide()
        cellTextures[i] = t
    end
    stripFrame:Hide()
end

local function DrawStrip(cells)
    EnsureStrip()
    for i = 1, #cellTextures do
        local t = cellTextures[i]
        if i <= #cells then
            local r, g, b = WoWGrok_Codec.CellColor(cells[i])
            t:SetColorTexture(r, g, b, 1)
            t:Show()
        else
            t:Hide()
        end
    end
    stripFrame:Show()
end

local function HideStrip()
    if stripFrame then stripFrame:Hide() end
end

local function GetWeeklyByType(typeId, label)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return nil end
    local ok, activities = pcall(function() return C_WeeklyRewards.GetActivities(typeId) end)
    if not ok or not activities or #activities == 0 then return nil end
    local parts = {}
    for _, act in ipairs(activities) do
        local prog = ""
        if act.progress and act.threshold then
            prog = string.format("%d/%d", act.progress, act.threshold)
        end
        local rewardName = nil
        if act.rewards and #act.rewards > 0 and act.rewards[1].itemDBID and C_WeeklyRewards.GetItemHyperlink then
            local link = C_WeeklyRewards.GetItemHyperlink(act.rewards[1].itemDBID)
            if link then
                rewardName = GetItemInfo(link) or link
            end
        end
        if prog ~= "" then
            if rewardName then
                tinsert(parts, prog .. " (" .. rewardName .. ")")
            else
                tinsert(parts, prog)
            end
        end
    end
    if #parts > 0 then
        return label .. ": " .. table.concat(parts, ", ")
    end
    return nil
end

local function GetContext()
    local parts = {}
    local name = UnitName("player") or "?"
    local level = UnitLevel("player") or "?"
    local _, class = UnitClass("player")
    local zone = GetZoneText() or GetRealZoneText() or "?"
    local sub = GetSubZoneText() or ""
    tinsert(parts, string.format("Character: %s, Level %s %s", name, level, class or ""))
    tinsert(parts, string.format("Zone: %s%s", zone, sub ~= "" and (" / " .. sub) or ""))

    local specIndex = GetSpecialization()
    if specIndex then
        local _, specName = GetSpecializationInfo(specIndex)
        if specName then
            tinsert(parts, "Specialization: " .. specName)
        end
    end

    local avg, equipped = GetAverageItemLevel()
    if avg and equipped then
        tinsert(parts, string.format("Item Level: %.1f equipped / %.1f overall", equipped, avg))
    end

    local money = GetMoney()
    if money then
        local gold = math.floor(money / 10000)
        tinsert(parts, string.format("Gold: %d", gold))
    end

    local numQuests = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
    tinsert(parts, string.format("Active quests: %d", numQuests))

    local w1 = GetWeeklyByType(1, "M+")
    local w3 = GetWeeklyByType(3, "Raid")
    local w6 = GetWeeklyByType(6, "World")
    if w1 then tinsert(parts, w1) end
    if w3 then tinsert(parts, w3) end
    if w6 then tinsert(parts, w6) end

    local profs = {}
    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    local function addProf(idx)
        if idx then
            local name, _, skillLevel, maxSkill = GetProfessionInfo(idx)
            if name and skillLevel then
                tinsert(profs, string.format("%s %d/%d", name, skillLevel, maxSkill or 0))
            end
        end
    end
    addProf(prof1)
    addProf(prof2)
    addProf(archaeology)
    addProf(fishing)
    addProf(cooking)
    if #profs > 0 then
        tinsert(parts, "Professions: " .. table.concat(profs, ", "))
    end

    local gear = {}
    local slots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local itemName = GetItemInfo(link)
            if itemName then
                tinsert(gear, itemName)
            end
        end
    end
    if #gear > 0 then
        tinsert(parts, "Equipped: " .. table.concat(gear, ", "))
    end

    local key = GetCharKey()
    local notes = WoWGrokAssistantDB.notes[key]
    if notes and #notes > 0 then
        tinsert(parts, "Notes: " .. table.concat(notes, "; "))
    end

    return table.concat(parts, "\n")
end

local function SendMessage(msg)
    if not msg or msg == "" then return end
    AddMessage("user", msg)
    SetStatus("Sending...")

    local context = GetContext()
    local fullText = "You are an in-game assistant for World of Warcraft (retail 12.1).\n" ..
                     "Current player context:\n" .. context .. "\n\n" ..
                     "Player question: " .. msg .. "\n\n" ..
                     "Answer concisely and helpfully. Focus on WoW advice. Use the context when relevant."

    local cells, err = WoWGrok_Codec.Encode(nextId, fullText)
    if not cells then
        AddMessage("system", "Message too long for pixel strip. Try a shorter question or clear notes.")
        SetStatus("Too long")
        return
    end
    pendingId = nextId
    DrawStrip(cells)
    AddMessage("system", "Waiting for Grok...")
    SetStatus("Waiting for Grok...")
    StartPolling()
    nextId = nextId + 1
    WoWGrokAssistantDB.nextId = nextId
end

local function ProcessSlotData()
    local data = WoWGrok_SlotData
    if type(data) ~= "table" or type(data.replies) ~= "table" then return end
    for _, reply in ipairs(data.replies) do
        if reply.id == pendingId and reply.status == "done" then
            AddMessage("grok", reply.text or "")
            pendingId = nil
            HideStrip()
            SetStatus("Ready")
            if pollTimer then
                pollTimer:Cancel()
                pollTimer = nil
            end
            return true
        end
    end
    return false
end

local function PollSlot()
    if not pendingId then return end
    local name = string.format("WoWGrok_S%03d", nextSlot)
    nextSlot = nextSlot % NUM_SLOTS + 1
    local ok, reason = C_AddOns and C_AddOns.LoadAddOn(name)
    if ok then
        ProcessSlotData()
    elseif reason then
        Print("Slot load failed: " .. tostring(reason))
    end
end

local function StartPolling()
    if pollTimer then pollTimer:Cancel() end
    local delays = {1, 2, 3, 5, 8, 12, 20}
    local idx = 1
    local function scheduleNext()
        if not pendingId or idx > #delays then return end
        pollTimer = C_Timer.NewTimer(delays[idx], function()
            PollSlot()
            idx = idx + 1
            scheduleNext()
        end)
    end
    scheduleNext()
end

local function CreateChatUI()
    if chatFrame then return end

    chatFrame = CreateFrame("Frame", "WoWGrokChatFrame", UIParent, "BackdropTemplate")
    chatFrame:SetSize(480, 380)
    chatFrame:SetPoint("CENTER")
    chatFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    chatFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
    chatFrame:SetMovable(true)
    chatFrame:EnableMouse(true)
    chatFrame:RegisterForDrag("LeftButton")
    chatFrame:SetScript("OnDragStart", chatFrame.StartMoving)
    chatFrame:SetScript("OnDragStop", chatFrame.StopMovingOrSizing)
    chatFrame:SetClampedToScreen(true)
    chatFrame:Hide()

    local title = chatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cFF00AAFFWoW Grok Assistant|r")

    local closeBtn = CreateFrame("Button", nil, chatFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() chatFrame:Hide() end)

    local clearBtn = CreateFrame("Button", nil, chatFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("TOPLEFT", 12, -10)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        WoWGrokAssistantDB.history = {}
        messageText = ""
        if scrollChild then scrollChild:SetText("") end
        SetStatus("Ready")
    end)

    statusText = chatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPRIGHT", -40, -12)
    statusText:SetText("Ready")
    statusText:SetTextColor(0.6, 0.8, 1)

    local scroll = CreateFrame("ScrollFrame", nil, chatFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -42)
    scroll:SetPoint("BOTTOMRIGHT", -32, 58)

    scrollChild = CreateFrame("EditBox", nil, scroll)
    scrollChild:SetMultiLine(true)
    scrollChild:SetFontObject(ChatFontNormal)
    scrollChild:SetWidth(400)
    scrollChild:SetAutoFocus(false)
    scrollChild:EnableMouse(false)
    scrollChild:SetText("")
    scroll:SetScrollChild(scrollChild)

    local input = CreateFrame("EditBox", nil, chatFrame, "InputBoxTemplate")
    input:SetSize(380, 22)
    input:SetPoint("BOTTOMLEFT", 20, 18)
    input:SetAutoFocus(false)
    input:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            SendMessage(text)
            self:SetText("")
            self:ClearFocus()
        end
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    chatFrame.input = input
    RebuildMessageText()
end

local function ToggleChat()
    CreateChatUI()
    if chatFrame:IsShown() then
        chatFrame:Hide()
    else
        chatFrame:Show()
        chatFrame.input:SetFocus()
    end
end

SLASH_WOWGROK1 = "/grok"
SLASH_WOWGROK2 = "/wowgrok"
SlashCmdList["WOWGROK"] = function(msg)
    msg = msg and strtrim(msg) or ""
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""

    if msg == "" or cmd == "toggle" then
        ToggleChat()
        return
    end
    if cmd == "hide" then
        HideStrip()
        if chatFrame then chatFrame:Hide() end
        pendingId = nil
        return
    end
    if cmd == "status" then
        Print("Next id: " .. nextId .. " pending: " .. tostring(pendingId))
        return
    end
    if cmd == "debug" then
        local scale = GetPixelPerfectScale()
        local hist = #WoWGrokAssistantDB.history
        Print(string.format("scale=%.4f nextId=%d pending=%s nextSlot=%d history=%d", scale, nextId, tostring(pendingId), nextSlot, hist))
        return
    end
    if cmd == "context" then
        AddMessage("system", GetContext())
        return
    end
    if cmd == "clear" then
        WoWGrokAssistantDB.history = {}
        messageText = ""
        if scrollChild then scrollChild:SetText("") end
        SetStatus("Ready")
        return
    end

    if cmd == "weekly" then
        SendMessage("Summarize my current weekly progress (M+, Raid, World) including any reward items, and suggest the highest priority activities I should do this week.")
        return
    end
    if cmd == "gear" then
        SendMessage("Based on my current equipped gear and item level, suggest the most impactful upgrades I should pursue next (dungeons, raids, crafts, vault, etc.).")
        return
    end
    if cmd == "map" then
        local zone = GetZoneText() or GetRealZoneText() or "unknown zone"
        SendMessage("I am currently in " .. zone .. ". Suggest useful activities, routes, or nearby objectives I should consider (dungeons, rares, world quests, etc.). Keep it practical.")
        return
    end
    if cmd == "profession" or cmd == "prof" then
        SendMessage("Based on my professions and skill levels, suggest what I should prioritize this week (knowledge points, crafts, gathering routes, or specialization choices).")
        return
    end
    if cmd == "note" then
        local key = GetCharKey()
        WoWGrokAssistantDB.notes[key] = WoWGrokAssistantDB.notes[key] or {}
        local sub, text = rest:match("^(%S+)%s*(.*)$")
        sub = sub and sub:lower() or "list"
        if sub == "add" and text ~= "" then
            if #WoWGrokAssistantDB.notes[key] >= MAX_NOTES then
                AddMessage("system", "Note limit reached (" .. MAX_NOTES .. "). Clear some first.")
            else
                tinsert(WoWGrokAssistantDB.notes[key], text)
                AddMessage("system", "Note added: " .. text)
            end
        elseif sub == "list" then
            local notes = WoWGrokAssistantDB.notes[key]
            if #notes == 0 then
                AddMessage("system", "No notes for this character.")
            else
                AddMessage("system", "Notes:\n" .. table.concat(notes, "\n"))
            end
        elseif sub == "clear" then
            WoWGrokAssistantDB.notes[key] = {}
            AddMessage("system", "Notes cleared.")
        else
            AddMessage("system", "Usage: /grok note add <text> | list | clear")
        end
        return
    end

    SendMessage(msg)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Print("Loaded. Type /grok to open the chat window.")
        Print("Commands: /grok weekly | gear | map | profession | note | debug | clear")
        CreateChatUI()
    elseif stripFrame then
        stripFrame:SetScale(GetPixelPerfectScale())
    end
end)
