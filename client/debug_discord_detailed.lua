-- Detailed Discord Webhook Debug
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

print("🔍 === DETAILED DISCORD DEBUG ===")

-- Test 1: Minimal JSON
local function testMinimal()
    print("\n📤 Test 1: Minimal JSON...")
    
    local data = {
        content = "Hello from Roblox!"
    }
    
    local jsonString = HttpService:JSONEncode(data)
    print("📋 JSON String:", jsonString)
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            WEBHOOK_URL,
            jsonString,
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    print("✅ Success:", success)
    print("📊 Result:", tostring(result))
    print("📊 Result Type:", type(result))
    
    if not success then
        print("🔥 Error Details:", result)
    end
    
    return success
end

-- Test 2: Different content type
local function testDifferentContentType()
    print("\n📤 Test 2: Different Content Type...")
    
    local data = {
        content = "Test with different content type"
    }
    
    local jsonString = HttpService:JSONEncode(data)
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            WEBHOOK_URL,
            jsonString,
            Enum.HttpContentType.TextPlain
        )
    end)
    
    print("✅ Success:", success)
    print("📊 Result:", tostring(result))
    
    return success
end

-- Test 3: Manual headers
local function testManualHeaders()
    print("\n📤 Test 3: Manual Headers...")
    
    local data = {
        content = "Test with manual headers"
    }
    
    local jsonString = HttpService:JSONEncode(data)
    
    local headers = {
        ["Content-Type"] = "application/json"
    }
    
    local success, result = pcall(function()
        return HttpService:RequestAsync({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = headers,
            Body = jsonString
        })
    end)
    
    print("✅ Success:", success)
    if success then
        print("📊 Status Code:", result.StatusCode)
        print("📊 Status Message:", result.StatusMessage)
        print("📊 Body:", result.Body)
        print("📊 Headers:", HttpService:JSONEncode(result.Headers or {}))
    else
        print("🔥 Error:", result)
    end
    
    return success and result.Success
end

-- Test 4: Check webhook validity
local function testWebhookInfo()
    print("\n📤 Test 4: Check Webhook Info...")
    
    local success, result = pcall(function()
        return HttpService:RequestAsync({
            Url = WEBHOOK_URL,
            Method = "GET"
        })
    end)
    
    print("✅ Success:", success)
    if success then
        print("📊 Status Code:", result.StatusCode)
        print("📊 Webhook Info:", result.Body)
    else
        print("🔥 Error:", result)
    end
    
    return success
end

-- Test 5: Simple string content
local function testSimpleString()
    print("\n📤 Test 5: Simple String Content...")
    
    local simpleJson = '{"content":"Simple string test"}'
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            WEBHOOK_URL,
            simpleJson,
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    print("✅ Success:", success)
    print("📊 Result:", tostring(result))
    
    return success
end

-- Show notification
local function showResult(testName, success)
    local player = Players.LocalPlayer
    if not player then return end
    
    local pg = player:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "DebugResult"
    screen.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(1, -320, 0, 20)
    frame.BackgroundColor3 = success and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screen
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s %s", success and "✅" or "❌", testName)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = frame
    
    game:GetService("Debris"):AddItem(screen, 3)
end

-- Run all tests
print("🚀 Starting detailed Discord webhook tests...")

local results = {}

task.wait(1)
results.minimal = testMinimal()
showResult("Minimal Test", results.minimal)

task.wait(2)
results.differentContentType = testDifferentContentType()
showResult("Content Type Test", results.differentContentType)

task.wait(2)
results.manualHeaders = testManualHeaders()
showResult("Manual Headers Test", results.manualHeaders)

task.wait(2)
results.webhookInfo = testWebhookInfo()
showResult("Webhook Info Test", results.webhookInfo)

task.wait(2)
results.simpleString = testSimpleString()
showResult("Simple String Test", results.simpleString)

-- Summary
print("\n📋 === FINAL RESULTS ===")
for testName, result in pairs(results) do
    print(string.format("%s: %s", testName, result and "✅" or "❌"))
end

local successCount = 0
for _, result in pairs(results) do
    if result then successCount = successCount + 1 end
end

print(string.format("\n🎯 Success Rate: %d/%d tests passed", successCount, 5))

if successCount > 0 then
    print("✅ At least one method works! Check your Discord channel.")
else
    print("❌ All tests failed. There might be an issue with the webhook URL or Discord API.")
end
