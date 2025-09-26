-- Minimal FishIs Telemetry - ง่ายที่สุด ทำงานได้แน่นอน
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ===== CONFIG =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

print("🎮 === MINIMAL FISHIS TELEMETRY ===")
print("⏰ Starting at:", os.time())

-- Function to collect basic data
local function collectBasicData()
    local player = Players.LocalPlayer
    if not player then
        print("❌ No player found")
        return nil
    end

    local data = {
        player_name = player.Name,
        player_id = player.UserId,
        game_name = "FishIs",
        timestamp = os.time(),
        current_time = os.date("%Y-%m-%d %H:%M:%S")
    }

    print("✅ Player found:", player.Name)

    -- Try to get leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        data.leaderstats = {}
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat.Value then
                data.leaderstats[stat.Name] = stat.Value
            end
        end
        print("✅ Leaderstats found:", #data.leaderstats, "stats")
    end

    -- Try to get common stats
    local commonStats = {"Money", "Cash", "Level", "Lvl", "XP"}
    data.common_stats = {}
    for _, statName in ipairs(commonStats) do
        local stat = player:FindFirstChild(statName)
        if stat and stat.Value then
            data.common_stats[statName] = stat.Value
        end
    end

    -- Try to get backpack
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        data.backpack_items = {}
        for _, item in ipairs(backpack:GetChildren()) do
            table.insert(data.backpack_items, item.Name)
        end
        print("✅ Backpack found:", #data.backpack_items, "items")
    end

    return data
end

-- Function to send data to Discord
local function sendToDiscord(data)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then
        print("❌ No webhook URL configured")
        return false
    end

    -- Create simple message
    local message = string.format(
        "🎮 **FishIs Telemetry**\\n" ..
        "👤 Player: %s (ID: %s)\\n" ..
        "⏰ Time: %s\\n" ..
        "🎯 Data collected successfully!",
        data.player_name,
        tostring(data.player_id),
        data.current_time
    )

    -- Create embed
    local embed = {
        title = "🎣 FishIs Game Data",
        description = "Player telemetry data",
        color = 65280,
        fields = {
            {
                name = "👤 Player",
                value = string.format("**%s**", data.player_name),
                inline = true
            },
            {
                name = "🆔 User ID",
                value = tostring(data.player_id),
                inline = true
            },
            {
                name = "⏰ Timestamp",
                value = data.current_time,
                inline = true
            }
        }
    }

    -- Add leaderstats
    if data.leaderstats then
        local statsText = ""
        for statName, value in pairs(data.leaderstats) do
            statsText = statsText .. string.format("**%s**: %s\\n", statName, tostring(value))
        end
        table.insert(embed.fields, {
            name = "📊 Leaderstats",
            value = statsText,
            inline = false
        })
    end

    -- Add common stats
    if data.common_stats then
        local statsText = ""
        for statName, value in pairs(data.common_stats) do
            statsText = statsText .. string.format("**%s**: %s\\n", statName, tostring(value))
        end
        table.insert(embed.fields, {
            name = "📈 Common Stats",
            value = statsText,
            inline = false
        })
    end

    -- Add backpack
    if data.backpack_items and #data.backpack_items > 0 then
        local itemsText = table.concat(data.backpack_items, ", ")
        if #itemsText > 1000 then
            itemsText = string.sub(itemsText, 1, 997) .. "..."
        end
        table.insert(embed.fields, {
            name = "🎒 Backpack Items",
            value = itemsText,
            inline = false
        })
    end

    -- Create payload
    local payload = {
        content = message,
        embeds = {embed}
    }

    -- Send to Discord
    local success, result = pcall(function()
        return HttpService:PostAsync(
            WEBHOOK_URL,
            HttpService:JSONEncode(payload),
            Enum.HttpContentType.ApplicationJson
        )
    end)

    if success then
        print("✅ Data sent to Discord successfully!")
        return true
    else
        print("❌ Failed to send data:", result)
        return false
    end
end

-- ===== MAIN EXECUTION =====
print("🔍 Checking HttpService...")
if not HttpService.HttpEnabled then
    print("❌ HttpService is disabled!")
    print("💡 Enable it with: game:GetService('HttpService').HttpEnabled = true")
else
    print("✅ HttpService is enabled")
end

print("🔍 Collecting game data...")
local gameData = collectBasicData()

if gameData then
    print("📊 Data collected:")
    for key, value in pairs(gameData) do
        if type(value) == "table" then
            print("  " .. key .. ":", #value, "items")
        else
            print("  " .. key .. ":", tostring(value))
        end
    end

    print("📤 Sending to Discord...")
    local sendSuccess = sendToDiscord(gameData)

    if sendSuccess then
        print("🎉 SUCCESS! Check your Discord channel for the message!")
    else
        print("❌ Failed to send to Discord")
    end
else
    print("❌ No game data collected")
end

print("✨ Script completed!")
