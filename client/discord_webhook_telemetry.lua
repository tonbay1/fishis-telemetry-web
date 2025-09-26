-- Discord Webhook Telemetry - ทางเลือกสำหรับการส่งข้อมูล
-- ใช้ Discord webhook แทน local server

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ===== CONFIG =====
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"
local GAME_NAME = "FishIs"

-- ===== UTILITY FUNCTIONS =====
local function safeRequire(moduleScript)
    local success, result = pcall(require, moduleScript)
    return success and result or nil
end

local function getValueSafe(obj)
    if obj and obj.Value ~= nil then
        return obj.Value
    end
    return nil
end

-- ===== COLLECT GAME DATA =====
local function collectGameData()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    -- Basic player data
    local playerData = {
        name = player.Name,
        userId = player.UserId,
        displayName = player.DisplayName
    }
    
    -- Stats
    local stats = {}
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            stats[stat.Name] = getValueSafe(stat)
        end
    end
    
    -- Common stats
    local commonStats = {"Money", "Cash", "Level", "Lvl", "XP"}
    for _, statName in ipairs(commonStats) do
        local stat = player:FindFirstChild(statName)
        if stat then
            stats[statName:lower()] = getValueSafe(stat)
        end
    end
    
    -- Inventory
    local inventory = {}
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            table.insert(inventory, item.Name)
        end
    end
    
    -- Fishing specific
    local fishingData = {}
    local rodsFolder = player:FindFirstChild("Rods")
    if rodsFolder then
        fishingData.rods = {}
        for _, rod in ipairs(rodsFolder:GetChildren()) do
            fishingData.rods[rod.Name] = getValueSafe(rod)
        end
    end
    
    local baitsFolder = player:FindFirstChild("Baits")
    if baitsFolder then
        fishingData.baits = {}
        for _, bait in ipairs(baitsFolder:GetChildren()) do
            fishingData.baits[bait.Name] = getValueSafe(bait)
        end
    end
    
    return {
        player = playerData,
        stats = stats,
        inventory = inventory,
        fishing = fishingData,
        timestamp = os.time(),
        tick = tick()
    }
end

-- ===== SEND TO DISCORD ===== (Updated working version)
local function sendToDiscord(data)
    if DISCORD_WEBHOOK_URL:find("YOUR_WEBHOOK_URL_HERE") then
        warn("❌ Discord webhook URL not configured!")
        warn("💡 Please replace YOUR_WEBHOOK_URL_HERE with your actual webhook URL")
        return false
    end
    
    -- Create Discord embed
    local embed = {
        title = "🎮 " .. GAME_NAME .. " Telemetry",
        description = "Player data collected from game",
        color = 3447003, -- Blue color
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        fields = {}
    }
    
    -- Add player info
    table.insert(embed.fields, {
        name = "👤 Player",
        value = string.format("%s (%s)", data.player.name, tostring(data.player.userId)),
        inline = true
    })
    
    -- Add stats
    if data.stats and next(data.stats) then
        local statsText = ""
        for statName, value in pairs(data.stats) do
            statsText = statsText .. string.format("%s: %s\n", statName, tostring(value))
        end
        if statsText ~= "" then
            table.insert(embed.fields, {
                name = "📊 Stats",
                value = statsText,
                inline = true
            })
        end
    end
    
    -- Add inventory
    if data.inventory and #data.inventory > 0 then
        local inventoryText = table.concat(data.inventory, ", ")
        if #inventoryText > 1024 then
            inventoryText = string.sub(inventoryText, 1, 1020) .. "..."
        end
        table.insert(embed.fields, {
            name = "🎒 Inventory (" .. #data.inventory .. " items)",
            value = inventoryText,
            inline = false
        })
    end
    
    -- Add fishing data
    if data.fishing then
        if data.fishing.rods and next(data.fishing.rods) then
            local rodsText = ""
            for rodName, count in pairs(data.fishing.rods) do
                rodsText = rodsText .. string.format("%s: %s\n", rodName, tostring(count))
            end
            if rodsText ~= "" then
                table.insert(embed.fields, {
                    name = "🎣 Rods",
                    value = rodsText,
                    inline = true
                })
            end
        end
        
        if data.fishing.baits and next(data.fishing.baits) then
            local baitsText = ""
            for baitName, count in pairs(data.fishing.baits) do
                baitsText = baitsText .. string.format("%s: %s\n", baitName, tostring(count))
            end
            if baitsText ~= "" then
                table.insert(embed.fields, {
                    name = "🪱 Baits",
                    value = baitsText,
                    inline = true
                })
            end
        end
    end
    
    -- Add timestamp
    table.insert(embed.fields, {
        name = "⏰ Timestamp",
        value = os.date("%Y-%m-%d %H:%M:%S", data.timestamp),
        inline = true
    })
    
    -- Create Discord payload
    local discordPayload = {
        embeds = {embed}
    }
    
    -- Send to Discord using working method
    local success, result = pcall(function()
        return HttpService:PostAsync(
            DISCORD_WEBHOOK_URL,
            HttpService:JSONEncode(discordPayload),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    -- Don't worry about result value, just check if HTTP request succeeded
    if success then
        print("✅ Telemetry data sent to Discord!")
        print("📊 HTTP request completed successfully")
        return true
    else
        warn("❌ Failed to send to Discord:", result)
        return false
    end
end

-- ===== ALTERNATIVE: PASTEBIN =====
local function sendToPastebin(data)
    local PASTEBIN_API_KEY = "YOUR_PASTEBIN_API_KEY" -- Replace with your API key
    
    if PASTEBIN_API_KEY:find("YOUR_PASTEBIN_API_KEY") then
        warn("⚠️ Pastebin API key not configured")
        return false
    end
    
    local logText = string.format(
        "=== FishIs Telemetry Log ===\n" ..
        "Timestamp: %s\n" ..
        "Player: %s (%s)\n" ..
        "Stats: %s\n" ..
        "Inventory: %s\n" ..
        "Fishing Data: %s\n" ..
        "========================\n",
        os.date("%Y-%m-%d %H:%M:%S", data.timestamp),
        data.player.name,
        tostring(data.player.userId),
        HttpService:JSONEncode(data.stats or {}),
        table.concat(data.inventory or {}, ", "),
        HttpService:JSONEncode(data.fishing or {})
    )
    
    local pastebinData = string.format(
        "api_dev_key=%s&api_option=paste&api_paste_code=%s&api_paste_name=FishIs_Telemetry_%s&api_paste_expire_date=1D",
        PASTEBIN_API_KEY,
        HttpService:UrlEncode(logText),
        tostring(data.timestamp)
    )
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            "https://pastebin.com/api/api_post.php",
            pastebinData,
            Enum.HttpContentType.ApplicationUrlEncoded
        )
    end)
    
    if success then
        print("✅ Data sent to Pastebin:", result)
        return true
    else
        warn("❌ Failed to send to Pastebin:", result)
        return false
    end
end

-- ===== UI NOTIFICATION =====
local function showNotification(success, method)
    local player = Players.LocalPlayer
    if not player then return end
    
    local pg = player:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "TelemetryNotification"
    screen.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(1, -320, 0, 20)
    frame.BackgroundColor3 = success and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(100, 0, 0)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screen
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = success and 
        string.format("✅ Telemetry sent via %s", method) or 
        string.format("❌ Failed to send telemetry")
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = frame
    
    -- Slide in animation
    frame:TweenPosition(UDim2.new(1, -320, 0, 20), "Out", "Quad", 0.5)
    
    -- Auto remove after 5 seconds
    task.delay(5, function()
        frame:TweenPosition(UDim2.new(1, 0, 0, 20), "In", "Quad", 0.5)
        task.wait(0.5)
        screen:Destroy()
    end)
end

-- ===== MAIN EXECUTION =====
print("🚀 Starting Discord Webhook Telemetry...")

-- Collect data
local gameData = collectGameData()
if not gameData then
    warn("❌ Failed to collect game data")
    return
end

print("📊 Game data collected:", HttpService:JSONEncode(gameData))

-- Try to send data
local success = false
local method = ""

-- Try Discord first
if sendToDiscord(gameData) then
    success = true
    method = "Discord"
else
    -- Try Pastebin as fallback
    if sendToPastebin(gameData) then
        success = true
        method = "Pastebin"
    end
end

-- Show notification
showNotification(success, method)

if success then
    print("✅ Telemetry sent successfully via", method)
else
    warn("❌ All telemetry methods failed")
    warn("💡 Please configure Discord webhook or Pastebin API key")
end
