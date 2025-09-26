-- Simple Working Discord Webhook - ใช้วิธีที่ทำงานได้แน่นอน
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

print("🚀 Simple Discord Webhook Test...")

-- Simple function that definitely works
local function sendSimpleMessage(message)
    local data = {
        content = message
    }
    
    local jsonString = HttpService:JSONEncode(data)
    print("📋 JSON:", jsonString)
    
    -- Use pcall to catch any errors
    local success, result = pcall(function()
        return HttpService:PostAsync(WEBHOOK_URL, jsonString, Enum.HttpContentType.ApplicationJson)
    end)
    
    print("✅ Success:", success)
    print("📊 Result:", tostring(result))
    print("📊 Result Type:", type(result))
    
    if success then
        -- Even if result is false, the HTTP request went through
        print("🎉 HTTP request completed!")
        return true
    else
        print("❌ HTTP request failed:", result)
        return false
    end
end

-- Alternative method using different approach
local function sendAlternativeMessage(message)
    print("\n🔄 Trying alternative method...")
    
    -- Try with simpler JSON structure
    local simpleJson = string.format('{"content":"%s"}', message)
    print("📋 Simple JSON:", simpleJson)
    
    local success, result = pcall(function()
        return HttpService:PostAsync(WEBHOOK_URL, simpleJson, Enum.HttpContentType.ApplicationJson)
    end)
    
    print("✅ Alternative Success:", success)
    print("📊 Alternative Result:", tostring(result))
    
    return success
end

-- Test with current time
local currentTime = os.date("%H:%M:%S")
local testMessage = "🎮 Hello from FishIs! Time: " .. currentTime

print("📤 Testing simple message...")
local result1 = sendSimpleMessage(testMessage)

task.wait(3)

print("📤 Testing alternative method...")
local result2 = sendAlternativeMessage("🔄 Alternative test message at " .. currentTime)

-- Show notification
local function showResult(success)
    local player = Players.LocalPlayer
    if not player then return end
    
    local pg = player:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "SimpleWebhookTest"
    screen.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 120)
    frame.Position = UDim2.new(0.5, -175, 0, 50)
    frame.BackgroundColor3 = success and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 50, 0)
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
        "✅ Webhook Test Completed!\nCheck your Discord channel\nfor test messages" or
        "❌ Webhook Test Failed!\nCheck console for errors\nTry creating new webhook"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = frame
    
    game:GetService("Debris"):AddItem(screen, 8)
end

-- Final result
print("\n📋 === FINAL RESULTS ===")
print("Method 1 (JSONEncode):", result1 and "✅" or "❌")
print("Method 2 (Simple JSON):", result2 and "✅" or "❌")

local anySuccess = result1 or result2
showResult(anySuccess)

if anySuccess then
    print("🎉 At least one method worked!")
    print("💡 Check your Discord channel for test messages")
    print("💡 If you see messages, the webhook is working!")
else
    print("❌ Both methods failed")
    print("💡 Possible solutions:")
    print("   1. Create a new Discord webhook")
    print("   2. Check if Discord server is accessible")
    print("   3. Try using local server instead")
end

print("✨ Test completed!")

-- If successful, show how to use it for telemetry
if anySuccess then
    print("\n🎯 === NEXT STEPS ===")
    print("✅ Discord webhook is working!")
    print("💡 You can now modify discord_webhook_telemetry.lua")
    print("💡 Or use this simple method for basic logging")
    
    -- Example of how to send game data
    task.wait(2)
    print("\n📊 Sending example game data...")
    
    local player = Players.LocalPlayer
    if player then
        local gameData = string.format(
            "🎮 **FishIs Player Data**\\n" ..
            "👤 Player: %s\\n" ..
            "🆔 ID: %s\\n" ..
            "⏰ Time: %s",
            player.Name,
            tostring(player.UserId),
            os.date("%Y-%m-%d %H:%M:%S")
        )
        
        sendSimpleMessage(gameData)
    end
end
