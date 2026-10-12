-- WoWGrokAssistant
-- Phase 2+: Enhanced UI + richer character context

local addonName, addonTable = ...
local frame = CreateFrame("Frame")

WoWGrokAssistantDB = WoWGrokAssistantDB or {}
local nextId = (WoWGrokAssistantDB.nextId or 1)
local pendingId = nil
local nextSlot = 1
local NUM_SLOTS = 20
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

local function AddMessage(role, text)
    local prefix
    if role == "user" then
        prefix = "|cFF88CCFF[You " .. GetTimestamp() .. "]|r "
    elseif role == "grok" then
        prefix = "|cFF00AAFF[Grok " .. GetTimestamp() .. "]|r "
    else
        prefix = "|cFFAAAAAA[System]|r "
    end
    local line = prefix .. text .. "\n\n"
    messageText = messageText .. line
    if scrollChild then
        scrollChild:SetText(messageText)
        local sf = scrollChild:GetParent()
        if sf then
            -- Force scroll to bottom
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

local function GetContext()
    local parts = {}
    local name = UnitName("player") or "?"
    local level = UnitLevel("player") or "?"
    local _, class = UnitClass("player")
    local zone = GetZoneText() or GetRealZoneText() or "?"
    local sub = GetSubZoneText() or ""
    tinsert(parts, string.format("Character: %s, Level %s %s", name, level, class or ""))
    tinsert(parts, string.format("Zone: %s%s", zone, sub ~= "" and (" / " .. sub) or ""))

    -- Item level
    local avg, equipped = GetAverageItemLevel()
    if avg and equipped then
        tinsert(parts, string.format("Item Level: %.1f equipped / %.1f overall", equipped, avg))
    end

    -- Quests
    local numQuests = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
    tinsert(parts, string.format("Active quests: %d", numQuests))

    -- Weekly rewards (vault / activities)
    if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
        local ok, activities = pcall(C_WeeklyRewards.GetActivities)
        if ok and activities and #activities > 0 then
            local weekly = {}
            for _, act in ipairs(activities) do
                if act.progress and act.threshold then
                    tinsert(weekly, string.format("%d/%d", act.progress, act.threshold))
                end
            end
            if #weekly > 0 then
                tinsert(parts, "Weekly progress: " .. table.concat(weekly, ", "))
            end
        end
    end

    -- Gear summary (names only to keep payload smaller)
    local gear = {}
    local slots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local name = GetItemInfo(link)
            if name then
                tinsert(gear, name)
            end
        end
    end
    if #gear > 0 then
        tinsert(parts, "Equipped: " .. table.concat(gear, ", "))
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
        AddMessage("system", "Encode failed: " .. tostring(err))
        SetStatus("Error")
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
    local ok = C_AddOns and C_AddOns.LoadAddOn(name)
    if ok then
        ProcessSlotData()
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
    chatFrame:SetSize(460, 360)
    chatFrame:SetPoint("CENTER")
    chatFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    chatFrame:SetBackdropColor(0, 0, 0, 0.85)
    chatFrame:SetMovable(true)
    chatFrame:EnableMouse(true)
    chatFrame:RegisterForDrag("LeftButton")
    chatFrame:SetScript("OnDragStart", chatFrame.StartMoving)
    chatFrame:SetScript("OnDragStop", chatFrame.StopMovingOrSizing)
    chatFrame:SetClampedToScreen(true)
    chatFrame:Hide()

    local title = chatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("WoW Grok Assistant")

    local closeBtn = CreateFrame("Button", nil, chatFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() chatFrame:Hide() end)

    local clearBtn = CreateFrame("Button", nil, chatFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("TOPLEFT", 12, -10)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        messageText = ""
        if scrollChild then scrollChild:SetText("") end
        SetStatus("Ready")
    end)

    statusText = chatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPRIGHT", -40, -12)
    statusText:SetText("Ready")
    statusText:SetTextColor(0.7, 0.7, 0.7)

    local scroll = CreateFrame("ScrollFrame", nil, chatFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -40)
    scroll:SetPoint("BOTTOMRIGHT", -32, 55)

    scrollChild = CreateFrame("EditBox", nil, scroll)
    scrollChild:SetMultiLine(true)
    scrollChild:SetFontObject(ChatFontNormal)
    scrollChild:SetWidth(380)
    scrollChild:SetAutoFocus(false)
    scrollChild:EnableMouse(false)
    scrollChild:SetText("")
    scroll:SetScrollChild(scrollChild)

    local input = CreateFrame("EditBox", nil, chatFrame, "InputBoxTemplate")
    input:SetSize(360, 22)
    input:SetPoint("BOTTOMLEFT", 20, 16)
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
    if msg == "" or msg == "toggle" then
        ToggleChat()
        return
    end
    if msg == "hide" then
        HideStrip()
        if chatFrame then chatFrame:Hide() end
        pendingId = nil
        return
    end
    if msg == "status" then
        Print("Next id: " .. nextId .. " pending: " .. tostring(pendingId))
        return
    end
    if msg == "context" then
        AddMessage("system", GetContext())
        return
    end
    if msg == "clear" then
        messageText = ""
        if scrollChild then scrollChild:SetText("") end
        SetStatus("Ready")
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
        CreateChatUI()
    elseif stripFrame then
        stripFrame:SetScale(GetPixelPerfectScale())
    end
end)
