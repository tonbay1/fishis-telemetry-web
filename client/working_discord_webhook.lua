-- Working Discord Webhook - ใช้ RequestAsync
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

print("🚀 Testing Discord webhook with RequestAsync...")

-- Function to send message using RequestAsync
local function sendDiscordMessage(content, embed)
    local payload = {}
    
    if content then
        payload.content = content
    end
    
    if embed then
        payload.embeds = {embed}
    end
    
    local jsonPayload = HttpService:JSONEncode(payload)
    print("📋 Sending JSON:", jsonPayload)
    
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonPayload
        })
    end)
    
    if success then
        print("✅ HTTP Request Success!")
        print("📊 Status Code:", response.StatusCode)
        print("📊 Status Message:", response.StatusMessage)
        print("📊 Success:", response.Success)
        
        if response.Body and response.Body ~= "" then
            print("📊 Response Body:", response.Body)
        end
        
        if response.StatusCode == 200 or response.StatusCode == 204 then
            print("🎉 Message sent to Discord successfully!")
            return true
        else
            print("❌ Discord rejected the message")
            print("🔥 Status Code:", response.StatusCode)
            return false
        end
    else
        print("❌ HTTP Request Failed!")
        print("🔥 Error:", response)
        return false
    end
end

-- Test 1: Simple message
print("\n📤 Test 1: Simple message...")
local success1 = sendDiscordMessage("🎮 Hello from Roblox! Time: " .. os.date("%H:%M:%S"))

task.wait(2)

-- Test 2: Embed message
print("\n📤 Test 2: Embed message...")
local player = Players.LocalPlayer
local embed = {
    title = "🎮 FishIs Telemetry Test",
    description = "Testing Discord webhook from Roblox game",
    color = 3447003, -- Blue
    fields = {
        {
            name = "👤 Player",
            value = player and player.Name or "Unknown",
            inline = true
        },
        {
            name = "🆔 User ID", 
            value = player and tostring(player.UserId) or "0",
            inline = true
        },
        {
            name = "⏰ Time",
            value = os.date("%Y-%m-%d %H:%M:%S"),
            inline = true
        }
    },
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    footer = {
        text = "FishIs Telemetry System"
    }
}

local success2 = sendDiscordMessage(nil, embed)

task.wait(2)

-- Test 3: Combined message and embed
print("\n📤 Test 3: Combined message and embed...")
local gameEmbed = {
    title = "🎣 Game Data Collection",
    description = "Collecting telemetry data from FishIs",
    color = 65280, -- Green
    fields = {
        {
            name = "🎮 Game",
            value = "FishIs",
            inline = true
        },
        {
            name = "📊 Status",
            value = "Active",
            inline = true
        },
        {
            name = "🔧 Method",
            value = "Discord Webhook",
            inline = true
        }
    }
}

local success3 = sendDiscordMessage("📊 **Telemetry Data Collection Started**", gameEmbed)

-- Show UI notification
local function showNotification(message, color)
    local player = Players.LocalPlayer
    if not player then return end
    
    local pg = player:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "WebhookResult"
    screen.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 100)
    frame.Position = UDim2.new(0.5, -200, 0, 50)
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screen
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = frame
    
    game:GetService("Debris"):AddItem(screen, 7)
end

-- Summary
print("\n📋 === TEST RESULTS ===")
print("Simple Message:", success1 and "✅" or "❌")
print("Embed Message:", success2 and "✅" or "❌") 
print("Combined Message:", success3 and "✅" or "❌")

local successCount = (success1 and 1 or 0) + (success2 and 1 or 0) + (success3 and 1 or 0)

if successCount > 0 then
    print(string.format("🎉 %d/3 tests passed! Check your Discord channel.", successCount))
    showNotification(string.format("🎉 Discord Webhook Working!\n%d/3 tests passed", successCount), Color3.fromRGB(0, 150, 0))
else
    print("❌ All tests failed!")
    showNotification("❌ Discord Webhook Failed!\nCheck console for details", Color3.fromRGB(150, 0, 0))
end

print("✨ Test completed! Check your Discord channel for messages.")
