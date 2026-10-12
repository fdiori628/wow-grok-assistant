-- WoWGrokAssistant
-- Phase 1: pixel strip encoding for outbound messages

local addonName, addonTable = ...
local frame = CreateFrame("Frame")

WoWGrokAssistantDB = WoWGrokAssistantDB or {}
local nextId = (WoWGrokAssistantDB.nextId or 1)

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[WoWGrok]|r " .. tostring(msg))
end

-- Pixel strip constants (must match bridge/capture.ps1)
local CELL = 4
local CELLS_PER_ROW = 200
local MAX_ROWS = 48

local stripFrame = nil
local cellTextures = {}

local function EnsureStrip()
    if stripFrame then return end
    stripFrame = CreateFrame("Frame", nil, UIParent)
    stripFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    stripFrame:SetSize(CELLS_PER_ROW * CELL, MAX_ROWS * CELL)
    stripFrame:SetFrameStrata("TOOLTIP")
    stripFrame:SetFrameLevel(1000)
    -- Approximate scale so one UI unit ~ one physical pixel
    local scale = 1 / (UIParent:GetEffectiveScale() or 1)
    stripFrame:SetScale(scale)

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
    local n = #cells
    for i = 1, #cellTextures do
        local t = cellTextures[i]
        if i <= n then
            local r, g, b = WoWGrok_Codec.CellColor(cells[i])
            t:SetColorTexture(r, g, b, 1)
            t:Show()
        else
            t:Hide()
        end
    end
    stripFrame:Show()
    Print("Pixel strip drawn (" .. n .. " cells). Keep windowed or borderless mode.")
end

local function HideStrip()
    if stripFrame then
        stripFrame:Hide()
    end
end

SLASH_WOWGROK1 = "/grok"
SLASH_WOWGROK2 = "/wowgrok"
SlashCmdList["WOWGROK"] = function(msg)
    msg = msg and strtrim(msg) or ""
    if msg == "" or msg == "hide" then
        HideStrip()
        Print("Strip hidden. Type /grok <text> to send a message.")
        return
    end
    if msg == "status" then
        Print("Next message id: " .. nextId)
        return
    end

    local cells, err = WoWGrok_Codec.Encode(nextId, msg)
    if not cells then
        Print("Encode failed: " .. tostring(err))
        return
    end
    DrawStrip(cells)
    Print("Sent id=" .. nextId .. ". Bridge should decode this if capture is running.")
    nextId = nextId + 1
    WoWGrokAssistantDB.nextId = nextId
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Print("Loaded. Type /grok <message> to draw the pixel strip.")
        Print("Requires windowed/borderless mode + running bridge capture.")
    end
end)
