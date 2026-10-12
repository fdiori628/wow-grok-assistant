-- WoWGrokAssistant
-- Phase 2: Grok CLI + basic character context

local addonName, addonTable = ...
local frame = CreateFrame("Frame")

WoWGrokAssistantDB = WoWGrokAssistantDB or {}
local nextId = (WoWGrokAssistantDB.nextId or 1)
local pendingId = nil
local nextSlot = 1
local NUM_SLOTS = 20
local pollTimer = nil

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[WoWGrok]|r " .. tostring(msg))
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

-- Basic character context (safe APIs for retail 12.1)
local function GetContext()
    local parts = {}
    local name = UnitName("player") or "?"
    local level = UnitLevel("player") or "?"
    local _, class = UnitClass("player")
    local zone = GetZoneText() or GetRealZoneText() or "?"
    local sub = GetSubZoneText() or ""
    tinsert(parts, string.format("Character: %s, Level %s %s", name, level, class or ""))
    tinsert(parts, string.format("Zone: %s%s", zone, sub ~= "" and (" / " .. sub) or ""))

    -- Quest count
    local numQuests = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
    tinsert(parts, string.format("Active quests: %d", numQuests))

    -- Simple gear summary (item links for main slots)
    local gear = {}
    local slots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17} -- head to offhand roughly
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            tinsert(gear, link)
        end
    end
    if #gear > 0 then
        tinsert(parts, "Equipped: " .. table.concat(gear, " "))
    end

    return table.concat(parts, "\n")
end

local function ProcessSlotData()
    local data = WoWGrok_SlotData
    if type(data) ~= "table" or type(data.replies) ~= "table" then return end
    for _, reply in ipairs(data.replies) do
        if reply.id == pendingId and reply.status == "done" then
            Print("Reply id=" .. reply.id .. ": " .. (reply.text or ""))
            pendingId = nil
            HideStrip()
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

SLASH_WOWGROK1 = "/grok"
SLASH_WOWGROK2 = "/wowgrok"
SlashCmdList["WOWGROK"] = function(msg)
    msg = msg and strtrim(msg) or ""
    if msg == "" or msg == "hide" then
        HideStrip()
        pendingId = nil
        Print("Strip hidden.")
        return
    end
    if msg == "status" then
        Print("Next id: " .. nextId .. " pending: " .. tostring(pendingId))
        return
    end
    if msg == "context" then
        Print(GetContext())
        return
    end

    local context = GetContext()
    local fullText = "You are an in-game assistant for World of Warcraft (retail).\n" ..
                     "Current player context:\n" .. context .. "\n\n" ..
                     "Player question: " .. msg .. "\n\n" ..
                     "Answer concisely and helpfully. Focus on WoW advice."

    local cells, err = WoWGrok_Codec.Encode(nextId, fullText)
    if not cells then
        Print("Encode failed: " .. tostring(err))
        return
    end
    pendingId = nextId
    DrawStrip(cells)
    Print("Sent id=" .. nextId .. ". Waiting for Grok reply...")
    StartPolling()
    nextId = nextId + 1
    WoWGrokAssistantDB.nextId = nextId
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Print("Loaded (Phase 2: Grok). Type /grok <message> or /grok context")
    elseif stripFrame then
        stripFrame:SetScale(GetPixelPerfectScale())
    end
end)
