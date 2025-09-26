-- Enable HttpService and Test
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

print("🔧 Attempting to enable HttpService...")

-- Try to enable HttpService
local success, error = pcall(function()
    HttpService.HttpEnabled = true
end)

if success then
    print("✅ HttpService enabled successfully!")
    
    -- Verify it's enabled
    if HttpService.HttpEnabled then
        print("✅ HttpService is now ENABLED")
        
        -- Show success notification
        local player = Players.LocalPlayer
        if player then
            local pg = player:WaitForChild("PlayerGui")
            local screen = Instance.new("ScreenGui")
            screen.Name = "HttpServiceEnabled"
            screen.Parent = pg
            
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 300, 0, 80)
            frame.Position = UDim2.new(0.5, -150, 0, 50)
            frame.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            frame.BackgroundTransparency = 0.2
            frame.BorderSizePixel = 0
            frame.Parent = screen
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = frame
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = "✅ HttpService Enabled!\nYou can now run telemetry scripts"
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextScaled = true
            label.Font = Enum.Font.SourceSansBold
            label.Parent = frame
            
            game:GetService("Debris"):AddItem(screen, 5)
        end
        
        print("🚀 Now you can run telemetry scripts!")
        print("💡 Try running discord_webhook_telemetry.lua or simple_discord_test.lua")
        
    else
        print("❌ HttpService is still disabled after attempt")
    end
else
    print("❌ Failed to enable HttpService:", error)
    print("💡 You may need to enable it manually in game settings")
    print("💡 Or your executor may not have permission to change this setting")
    
    -- Show error notification
    local player = Players.LocalPlayer
    if player then
        local pg = player:WaitForChild("PlayerGui")
        local screen = Instance.new("ScreenGui")
        screen.Name = "HttpServiceError"
        screen.Parent = pg
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 350, 0, 100)
        frame.Position = UDim2.new(0.5, -175, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(150, 50, 0)
        frame.BackgroundTransparency = 0.2
        frame.BorderSizePixel = 0
        frame.Parent = screen
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = "❌ Cannot Enable HttpService\nCheck executor permissions\nor game settings"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextScaled = true
        label.Font = Enum.Font.SourceSansBold
        label.Parent = frame
        
        game:GetService("Debris"):AddItem(screen, 7)
    end
end

-- Final status check
print("\n📊 === FINAL STATUS ===")
print("HttpService.HttpEnabled:", HttpService.HttpEnabled)
if HttpService.HttpEnabled then
    print("🎉 Ready to send telemetry data!")
else
    print("⚠️ Still need to enable HttpService manually")
end
