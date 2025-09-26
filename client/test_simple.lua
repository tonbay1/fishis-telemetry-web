-- Simple test version with debug messages
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local INGEST_URL = "http://localhost:3001/ingest"

-- Test function
local function testConnection()
    print("🔍 Testing telemetry connection...")
    
    local player = Players.LocalPlayer
    if not player then
        print("❌ No LocalPlayer found")
        return
    end
    
    print("✅ Player found:", player.Name)
    
    -- Create simple test data
    local testData = {
        game = "FishIs",
        events = {
            {
                ts = os.time(),
                kind = "test_connection",
                player = player.Name,
                userId = player.UserId,
                level = 1,
                money = 0,
                rods = {},
                baits = {},
                source = "test_script"
            }
        }
    }
    
    print("📤 Sending test data to:", INGEST_URL)
    
    -- Try to send
    local success, result = pcall(function()
        return HttpService:PostAsync(
            INGEST_URL, 
            HttpService:JSONEncode(testData), 
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        print("✅ SUCCESS! Data sent successfully")
        print("📊 Server response:", result)
    else
        print("❌ FAILED to send data")
        print("🔥 Error:", result)
    end
end

-- Show UI notification
local function showNotification()
    local player = Players.LocalPlayer
    if not player then return end
    
    local pg = player:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "TelemetryTest"
    screen.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(0.5, -150, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screen
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "🧪 Testing Telemetry...\nCheck Developer Console (F9)"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.Parent = frame
    
    -- Auto remove after 5 seconds
    game:GetService("Debris"):AddItem(screen, 5)
end

-- Run test
showNotification()
wait(1)
testConnection()
