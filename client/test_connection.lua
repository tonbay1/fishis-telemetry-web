-- Simple Connection Test Script
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local TELEMETRY_URL = "http://127.0.0.1:3001/telemetry"
local plr = Players.LocalPlayer

-- HTTP helpers (executor-aware)
local function getHttpRequest()
    return (typeof(syn) == "table" and syn.request)
        or (typeof(http) == "table" and http.request)
        or http_request
        or (typeof(fluxus) == "table" and fluxus.request)
        or request
end

local function sendJson(url, tbl)
    local ok, body = pcall(function() return HttpService:JSONEncode(tbl) end)
    if not ok then return false, "encode_failed" end
    local req = getHttpRequest()
    if req then
        local ok2, res = pcall(req, {Url=url, Method="POST", Headers={ ["Content-Type"] = "application/json" }, Body=body})
        if ok2 and res then
            local sc = res.StatusCode or res.status or res.Status or res.code
            return (sc == 200 or sc == 201), res
        else
            return false, res
        end
    else
        local ok3, res2 = pcall(function() return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson) end)
        return ok3, res2
    end
end

-- Show notification
StarterGui:SetCore("SendNotification", {
    Title = "🧪 Connection Test",
    Text = "Testing connection to server...",
    Duration = 3
})

-- Simple test data
local testData = {
    account = plr.Name,
    playerName = plr.Name,
    userId = plr.UserId,
    displayName = plr.DisplayName,
    testMessage = "Hello from Roblox!",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    money = 999,
    level = 123,
    location = "Test Location",
    rods = {"Test Rod 1", "Test Rod 2"},
    baits = {"Test Bait 1", "Test Bait 2"},
    materials = {},
    rodsDetailed = {},
    online = true
}

-- Send test data
local function sendTest()
    print("🧪 Sending test data to server...")
    print("   URL:", TELEMETRY_URL)
    print("   Player:", plr.Name)
    
    local success, result = sendJson(TELEMETRY_URL, testData)
    
    if success then
        print("✅ Test data sent successfully!")
        print("   Response:", result)
    else
        warn("❌ Failed to send test data:")
        warn("   Error:", result)
    end
    
    return success
end

-- Run test
print("🚀 Starting connection test...")
spawn(function()
    wait(1)
    sendTest()
    
    -- Send test every 5 seconds
    while true do
        wait(5)
        print("🔄 Sending periodic test...")
        sendTest()
    end
end)
