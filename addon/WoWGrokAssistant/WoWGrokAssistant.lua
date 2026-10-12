-- WoWGrokAssistant
-- Early skeleton for retail 12.1
-- Architecture inspired by wow-ai and WowGrok

local addonName, addonTable = ...
local frame = CreateFrame("Frame")

WoWGrokAssistantDB = WoWGrokAssistantDB or {}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[WoWGrok]|r " .. tostring(msg))
end

SLASH_WOWGROK1 = "/grok"
SLASH_WOWGROK2 = "/wowgrok"
SlashCmdList["WOWGROK"] = function(msg)
    msg = msg and strtrim(msg) or ""
    if msg == "" then
        Print("WoW Grok Assistant skeleton loaded. Bridge integration coming soon.")
        Print("Target: retail 12.1 (Interface 120100)")
    else
        Print("Message queued (not yet implemented): " .. msg)
        -- TODO: encode to pixel strip and wait for bridge ACK
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Print("Loaded. Type /grok for status.")
    end
end)
