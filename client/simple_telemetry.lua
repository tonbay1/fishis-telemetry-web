-- Simple Fisch Telemetry Script
-- Sends only essential player data to web dashboard

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local TELEMETRY_URL = "http://127.0.0.1:3001/telemetry"
local plr = Players.LocalPlayer

-- Show notification
StarterGui:SetCore("SendNotification", {
    Title = "🎣 Fisch Telemetry",
    Text = "Script started! Collecting data...",
    Duration = 3
})

-- Global inventory data
local inventory = {
    player = { name = plr.Name, id = plr.UserId, displayName = plr.DisplayName },
    level = 0,
    coin = 0,
    equippedRod = "",
    location = "",
    rods = {},
    baits = {},
    time = os.date("%Y-%m-%d %H:%M:%S")
}

-- Send telemetry to server
local function sendTelemetry(data)
    local success, result = pcall(function()
        local jsonData = HttpService:JSONEncode(data)
        return HttpService:PostAsync(TELEMETRY_URL, jsonData, Enum.HttpContentType.ApplicationJson)
    end)
    
    if success then
        print("✅ Telemetry sent successfully!")
        print("   Player:", data.account or "Unknown")
        print("   Money:", data.money or 0)
        print("   Level:", data.level or 0)
        print("   Baits:", #(data.baits or {}))
    else
        warn("❌ Failed to send telemetry:", result)
    end
    
    return success
end

-- Helper function to parse coin values with M/K suffixes
local function parseCoinValue(text)
    if not text then return 0 end
    
    -- Handle formats like "2.29M", "1.5K", "1,234", "1234"
    local number, suffix = string.match(text, "([%d%.,%s]+)([MKmk]?)")
    if not number then return 0 end
    
    -- Clean the number part
    number = number:gsub(",", ""):gsub("%s", "")
    local value = tonumber(number) or 0
    
    -- Apply suffix multiplier
    if suffix then
        suffix = string.upper(suffix)
        if suffix == "M" then
            value = value * 1000000
        elseif suffix == "K" then
            value = value * 1000
        end
    end
    
    return math.floor(value)
end

-- Find player data using proven methods
local function findPlayerData()
    -- Get leaderstats first
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("ValueBase") then
                local ok, val = pcall(function() return v.Value end)
                if ok then
                    if string.find(string.lower(v.Name), "level") or string.find(string.lower(v.Name), "lvl") then
                        inventory.level = val
                    elseif string.find(string.lower(v.Name), "money") or string.find(string.lower(v.Name), "coin") then
                        inventory.coin = val
                    end
                end
            end
        end
    end
    
    -- Get player attributes
    for k, v in pairs(plr:GetAttributes()) do
        if string.find(string.lower(k), "level") then
            inventory.level = v
        elseif string.find(string.lower(k), "money") or string.find(string.lower(k), "coin") then
            inventory.coin = v
        elseif string.find(string.lower(k), "location") then
            inventory.location = tostring(v)
        end
    end
    
    -- Search GUI for additional data
    local playerGui = plr:FindFirstChild("PlayerGui")
    if playerGui then
        for _, descendant in pairs(playerGui:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text then
                local text = descendant.Text
                
                -- Look for money with $ or coin indicators
                if (text:find("$") or text:find("C") or descendant.Name:lower():find("money") or descendant.Name:lower():find("coin")) and text:match("[%d%.,%s]+[MKmk]?") then
                    local coinValue = parseCoinValue(text)
                    if coinValue > 0 then
                        inventory.coin = coinValue
                    end
                end
                
                -- Look for level
                if (text:match("Level (%d+)") or (descendant.Name:lower():find("level") and text:match("^%d+$"))) then
                    local levelNum = text:match("(%d+)")
                    if levelNum then
                        inventory.level = tonumber(levelNum)
                    end
                end
            end
        end
    end
end

-- Find inventory items using comprehensive search
local function findInventoryItems()
    inventory.rods = {}
    inventory.baits = {}
    
    local playerGui = plr:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    -- Search all GUI elements for items
    for _, descendant in pairs(playerGui:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text and descendant.Text ~= "" then
            local itemName = descendant.Text
            
            -- Check for rods
            if itemName:find("Rod") and not itemName:find("Equipped") then
                -- Avoid duplicates
                local found = false
                for _, existing in pairs(inventory.rods) do
                    if existing == itemName then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(inventory.rods, itemName)
                end
            end
            
            -- Check for baits (common bait names)
            local baitNames = {"Worm", "Shrimp", "Squid", "Fish Head", "Maggot", "Bagel", "Flakes", "Minnow", "Leech", "Coral", "Seaweed"}
            for _, baitType in pairs(baitNames) do
                if itemName:find(baitType) then
                    -- Avoid duplicates
                    local found = false
                    for _, existing in pairs(inventory.baits) do
                        if existing == itemName then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(inventory.baits, itemName)
                    end
                    break
                end
            end
        end
    end
end

-- Find equipped rod using comprehensive search
local function findEquippedRod()
    local playerGui = plr:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    -- Search all GUI elements for equipped rod
    for _, descendant in pairs(playerGui:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text and descendant.Text:find("Rod") then
            -- Look for indicators that this is the equipped rod
            if descendant.Name:lower():find("equip") or 
               descendant.Parent.Name:lower():find("equip") or
               descendant.Parent.Parent.Name:lower():find("equip") then
                inventory.equippedRod = descendant.Text
                break
            end
        end
    end
    
    -- If no equipped rod found, try to find it in HUD area
    if inventory.equippedRod == "" then
        for _, descendant in pairs(playerGui:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text and descendant.Text:find("Rod") then
                -- Check if it's in a likely HUD location
                if descendant.Parent.Name:lower():find("hud") or 
                   descendant.Parent.Name:lower():find("tool") or
                   descendant.Parent.Name:lower():find("item") then
                    inventory.equippedRod = descendant.Text
                    break
                end
            end
        end
    end
end

-- Main scan function
local function scanAndSend()
    print("🔍 Scanning player data...")
    
    -- Reset data
    inventory.rods = {}
    inventory.baits = {}
    inventory.time = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Collect data
    findPlayerData()
    findInventoryItems()
    findEquippedRod()
    
    print("   Found", #inventory.rods, "rods and", #inventory.baits, "baits")
    
    -- Prepare telemetry
    local telemetry = {
        account = inventory.player.name,
        playerName = inventory.player.name,
        userId = inventory.player.id,
        displayName = inventory.player.displayName,
        money = inventory.coin,
        coins = inventory.coin,
        level = inventory.level,
        equippedRod = inventory.equippedRod,
        location = inventory.location,
        rods = inventory.rods,
        baits = inventory.baits,
        materials = {},
        rodsDetailed = {},
        online = true,
        time = inventory.time,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        lastUpdated = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    -- Send to server
    sendTelemetry(telemetry)
end

-- Auto-send loop (every 5 seconds)
spawn(function()
    while true do
        pcall(scanAndSend)
        wait(5)
    end
end)
