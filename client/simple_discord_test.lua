-- Simple Discord Webhook Test
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

print("🧪 Testing Discord webhook...")

-- Test 1: Simple message
local function testSimpleMessage()
    print("📤 Test 1: Sending simple message...")
    
    local data = {
        content = "🎮 Hello from Roblox! Test message at " .. os.date("%H:%M:%S")
    }
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            WEBHOOK_URL,
            HttpService:JSONEncode(data),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        print("✅ Simple message sent successfully!")
        print("📊 Response:", result)
        return true
    else
        print("❌ Simple message failed!")
        print("🔥 Error:", result)
        return false
    end
end

-- Test 2: Embed message
local function testEmbedMessage()
    print("📤 Test 2: Sending embed message...")
    
    local player = Players.LocalPlayer
    local embed = {
        title = "🎮 Roblox Game Test",
        description = "Testing Discord webhook from Roblox",
        color = 3447003,
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
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    local data = {
        embeds = {embed}
    }
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            WEBHOOK_URL,
            HttpService:JSONEncode(data),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        print("✅ Embed message sent successfully!")
        print("📊 Response:", result)
        return true
    else
        print("❌ Embed message failed!")
        print("🔥 Error:", result)
        return false
    end
end

-- Test 3: Check HttpService status
local function checkHttpService()
    print("🔍 Checking HttpService status...")
    
    local httpEnabled = HttpService.HttpEnabled
    print("HttpEnabled:", httpEnabled)
    
    if not httpEnabled then
        print("❌ HttpService is DISABLED!")
        print("💡 Enable it with: game:GetService('HttpService').HttpEnabled = true")
        return false
    else
        print("✅ HttpService is enabled")
        return true
    end
end

-- Show UI notification
local function showNotification(message, color)
    local player = Players.LocalPlayer
    if not player then return end
    
    local pg = player:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "DiscordTest"
    screen.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 80)
    frame.Position = UDim2.new(0.5, -175, 0, 50)
    frame.BackgroundColor3 = color or Color3.fromRGB(50, 50, 50)
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
    
    -- Auto remove after 5 seconds
    game:GetService("Debris"):AddItem(screen, 5)
end

-- Main execution
print("🚀 Starting Discord webhook tests...")
showNotification("🧪 Testing Discord Webhook...", Color3.fromRGB(100, 100, 200))

task.wait(1)

-- Run tests
local results = {}
results.httpService = checkHttpService()

if results.httpService then
    task.wait(1)
    results.simpleMessage = testSimpleMessage()
    
    task.wait(2)
    results.embedMessage = testEmbedMessage()
else
    print("❌ Cannot run tests - HttpService disabled")
    showNotification("❌ HttpService Disabled!", Color3.fromRGB(200, 50, 50))
end

-- Summary
print("\n📋 === TEST RESULTS ===")
print("HttpService:", results.httpService and "✅" or "❌")
print("Simple Message:", results.simpleMessage and "✅" or "❌")
print("Embed Message:", results.embedMessage and "✅" or "❌")

if results.simpleMessage or results.embedMessage then
    print("✅ Discord webhook is working!")
    showNotification("✅ Discord Webhook Working!", Color3.fromRGB(50, 200, 50))
else
    print("❌ Discord webhook failed!")
    showNotification("❌ Discord Webhook Failed!", Color3.fromRGB(200, 50, 50))
end

print("✨ Tests completed! Check your Discord channel for messages.")
