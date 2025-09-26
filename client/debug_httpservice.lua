-- Debug HttpService และหาวิธีการส่งข้อมูลทางเลือก
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

print("🔍 === HttpService Debug Test ===")

-- ตรวจสอบ HttpService
local function checkHttpService()
    print("📡 Checking HttpService status...")
    
    -- ตรวจสอบว่า HttpService เปิดใช้งานไหม
    local httpEnabled = HttpService.HttpEnabled
    print("HttpEnabled:", httpEnabled)
    
    if not httpEnabled then
        print("❌ HttpService is DISABLED!")
        print("💡 Solutions:")
        print("   1. Enable HttpService in game settings")
        print("   2. Use alternative methods (Discord webhooks, etc.)")
        return false
    end
    
    return true
end

-- ทดสอบการส่งข้อมูลไปเซิร์ฟเวอร์
local function testLocalServer()
    print("🌐 Testing local server connection...")
    
    local testData = {
        game = "FishIs",
        events = {
            {
                ts = os.time(),
                kind = "debug_test",
                player = Players.LocalPlayer and Players.LocalPlayer.Name or "Unknown",
                userId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0,
                level = 1,
                money = 0,
                rods = {},
                baits = {},
                source = "debug_script",
                debug = {
                    httpEnabled = HttpService.HttpEnabled,
                    timestamp = tick(),
                    platform = "Roblox"
                }
            }
        }
    }
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            "http://localhost:3001/ingest",
            HttpService:JSONEncode(testData),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        print("✅ Local server test SUCCESS!")
        print("📊 Response:", result)
        return true
    else
        print("❌ Local server test FAILED!")
        print("🔥 Error:", result)
        return false
    end
end

-- ทดสอบ Discord Webhook (ทางเลือก)
local function testDiscordWebhook()
    print("💬 Testing Discord webhook alternative...")
    
    -- ตัวอย่าง Discord webhook URL (ต้องแทนที่ด้วย URL จริง)
    local webhookUrl = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL_HERE"
    
    local discordData = {
        content = "🎮 FishIs Telemetry Test",
        embeds = {
            {
                title = "Game Data",
                description = "Test telemetry from FishIs",
                color = 3447003,
                fields = {
                    {
                        name = "Player",
                        value = Players.LocalPlayer and Players.LocalPlayer.Name or "Unknown",
                        inline = true
                    },
                    {
                        name = "Timestamp",
                        value = tostring(os.time()),
                        inline = true
                    }
                }
            }
        }
    }
    
    if webhookUrl:find("YOUR_WEBHOOK_URL_HERE") then
        print("⚠️ Discord webhook URL not configured")
        print("💡 To use Discord webhook:")
        print("   1. Create Discord webhook in your server")
        print("   2. Replace YOUR_WEBHOOK_URL_HERE with real URL")
        return false
    end
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            webhookUrl,
            HttpService:JSONEncode(discordData),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        print("✅ Discord webhook test SUCCESS!")
        return true
    else
        print("❌ Discord webhook test FAILED!")
        print("🔥 Error:", result)
        return false
    end
end

-- ทดสอบ Google Analytics (ทางเลือก)
local function testGoogleAnalytics()
    print("📊 Testing Google Analytics alternative...")
    
    -- Google Analytics Measurement Protocol
    local gaUrl = "https://www.google-analytics.com/collect"
    local trackingId = "UA-XXXXXXXX-X" -- ต้องแทนที่ด้วย Tracking ID จริง
    
    if trackingId:find("XXXXXXXX") then
        print("⚠️ Google Analytics not configured")
        print("💡 To use Google Analytics:")
        print("   1. Create GA property")
        print("   2. Replace UA-XXXXXXXX-X with real tracking ID")
        return false
    end
    
    local gaData = string.format(
        "v=1&tid=%s&cid=%s&t=event&ec=Game&ea=Telemetry&el=Test&ev=1",
        trackingId,
        tostring(Players.LocalPlayer and Players.LocalPlayer.UserId or 12345)
    )
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            gaUrl,
            gaData,
            Enum.HttpContentType.ApplicationUrlEncoded
        )
    end)
    
    if success then
        print("✅ Google Analytics test SUCCESS!")
        return true
    else
        print("❌ Google Analytics test FAILED!")
        print("🔥 Error:", result)
        return false
    end
end

-- ทดสอบ Pastebin (ทางเลือก)
local function testPastebin()
    print("📝 Testing Pastebin alternative...")
    
    local pastebinUrl = "https://pastebin.com/api/api_post.php"
    local apiKey = "YOUR_PASTEBIN_API_KEY" -- ต้องแทนที่ด้วย API key จริง
    
    if apiKey:find("YOUR_PASTEBIN_API_KEY") then
        print("⚠️ Pastebin API key not configured")
        print("💡 To use Pastebin:")
        print("   1. Get API key from pastebin.com")
        print("   2. Replace YOUR_PASTEBIN_API_KEY with real key")
        return false
    end
    
    local logData = string.format(
        "[%s] Player: %s, UserId: %s, Test: Success",
        os.date("%Y-%m-%d %H:%M:%S"),
        Players.LocalPlayer and Players.LocalPlayer.Name or "Unknown",
        tostring(Players.LocalPlayer and Players.LocalPlayer.UserId or 0)
    )
    
    local pastebinData = string.format(
        "api_dev_key=%s&api_option=paste&api_paste_code=%s&api_paste_name=FishIs_Telemetry_%s",
        apiKey,
        HttpService:UrlEncode(logData),
        tostring(os.time())
    )
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            pastebinUrl,
            pastebinData,
            Enum.HttpContentType.ApplicationUrlEncoded
        )
    end)
    
    if success then
        print("✅ Pastebin test SUCCESS!")
        print("📄 Paste URL:", result)
        return true
    else
        print("❌ Pastebin test FAILED!")
        print("🔥 Error:", result)
        return false
    end
end

-- แสดง UI notification
local function showDebugUI()
    local player = Players.LocalPlayer
    if not player then return end
    
    local pg = player:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "HttpServiceDebug"
    screen.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 200)
    frame.Position = UDim2.new(0.5, -200, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = screen
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.3, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔍 HttpService Debug"
    title.TextColor3 = Color3.fromRGB(255, 255, 100)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = frame
    
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0.7, 0)
    status.Position = UDim2.new(0, 0, 0.3, 0)
    status.BackgroundTransparency = 1
    status.Text = "Running tests...\nCheck Developer Console (F9) for details"
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextScaled = true
    status.Font = Enum.Font.SourceSans
    status.Parent = frame
    
    -- Auto close after 10 seconds
    task.delay(10, function()
        if screen and screen.Parent then
            screen:Destroy()
        end
    end)
    
    return status
end

-- === MAIN EXECUTION ===
local statusLabel = showDebugUI()

print("🚀 Starting HttpService debug tests...")

-- รอ 1 วินาที
task.wait(1)

-- ทดสอบทีละขั้นตอน
local results = {
    httpService = checkHttpService(),
    localServer = false,
    discordWebhook = false,
    googleAnalytics = false,
    pastebin = false
}

if results.httpService then
    results.localServer = testLocalServer()
    task.wait(1)
    results.discordWebhook = testDiscordWebhook()
    task.wait(1)
    results.googleAnalytics = testGoogleAnalytics()
    task.wait(1)
    results.pastebin = testPastebin()
end

-- สรุปผลลัพธ์
print("\n📋 === TEST RESULTS SUMMARY ===")
print("HttpService Enabled:", results.httpService and "✅" or "❌")
print("Local Server:", results.localServer and "✅" or "❌")
print("Discord Webhook:", results.discordWebhook and "✅" or "❌")
print("Google Analytics:", results.googleAnalytics and "✅" or "❌")
print("Pastebin:", results.pastebin and "✅" or "❌")

-- อัพเดท UI
if statusLabel then
    local summary = string.format(
        "HttpService: %s\nLocal Server: %s\nSee console for details",
        results.httpService and "✅ Enabled" or "❌ Disabled",
        results.localServer and "✅ Working" or "❌ Failed"
    )
    statusLabel.Text = summary
end

print("✨ Debug tests completed!")
print("💡 If local server failed, try alternative methods above")
