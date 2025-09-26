-- FishIs Level & XP Finder
-- Searches for player level and XP data using Replion system and GUI elements

local plr = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🎮 === FishIs Level & XP Finder ===")

-- Try to find Replion Client
local function findReplionData()
    print("🔍 Searching for Replion data...")
    
    -- Look for Replion in common locations
    local replionPaths = {
        ReplicatedStorage:FindFirstChild("Packages"),
        ReplicatedStorage:FindFirstChild("Shared"),
        ReplicatedStorage:FindFirstChild("Modules")
    }
    
    for _, parent in ipairs(replionPaths) do
        if parent then
            local replion = parent:FindFirstChild("Replion")
            if replion then
                print("📦 Found Replion at:", replion:GetFullName())
                
                local ok, Client = pcall(require, replion)
                if ok and Client and Client.Client then
                    print("✅ Successfully loaded Replion Client")
                    
                    -- Try to get Data replion
                    local dataReplion = Client.Client:WaitReplion("Data", 5)
                    if dataReplion then
                        print("🎯 Found Data replion!")
                        
                        -- Get Level
                        local level = dataReplion:GetExpect("Level")
                        if level then
                            print("📊 Level:", level)
                        end
                        
                        -- Get XP
                        local xp = dataReplion:GetExpect("XP")
                        if xp then
                            print("⭐ XP:", xp)
                        end
                        
                        -- Get all data keys
                        print("🔑 Available data keys:")
                        local data = dataReplion:GetData()
                        if data then
                            for k, v in pairs(data) do
                                print("  -", k .. ":", typeof(v), "=", tostring(v))
                            end
                        end
                        
                        return {level = level, xp = xp, replion = dataReplion}
                    else
                        print("❌ Could not find Data replion")
                    end
                else
                    print("❌ Failed to load Replion Client")
                end
            end
        end
    end
    
    return nil
end

-- Try to find level from PlayerGui
local function findLevelFromGUI()
    print("🖥️ Searching for level in PlayerGui...")
    
    local pg = plr:WaitForChild("PlayerGui")
    
    -- Look for XP GUI
    local xpGui = pg:FindFirstChild("XP")
    if xpGui then
        print("🎯 Found XP GUI:", xpGui:GetFullName())
        
        local frame = xpGui:FindFirstChild("Frame")
        if frame then
            local levelCount = frame:FindFirstChild("LevelCount")
            if levelCount and levelCount:IsA("TextLabel") then
                print("📊 Level display text:", levelCount.Text)
                
                -- Extract level number from "Lvl 123" format
                local levelNum = levelCount.Text:match("Lvl (%d+)")
                if levelNum then
                    print("📊 Extracted Level:", tonumber(levelNum))
                    return tonumber(levelNum)
                end
            end
        end
    end
    
    -- Search all TextLabels for level-like text
    local function searchForLevel(parent, depth)
        if depth > 3 then return end
        
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("TextLabel") then
                local text = child.Text
                if text:match("Lvl %d+") or text:match("Level %d+") or text:match("LV %d+") then
                    print("🎯 Found level text:", child:GetFullName(), "=", text)
                    local num = text:match("(%d+)")
                    if num then
                        return tonumber(num)
                    end
                end
            elseif child:IsA("GuiObject") then
                local result = searchForLevel(child, depth + 1)
                if result then return result end
            end
        end
    end
    
    return searchForLevel(pg, 0)
end

-- Try to find leaderstats
local function findLeaderstats()
    print("📈 Searching for leaderstats...")
    
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        print("🎯 Found leaderstats:", leaderstats:GetFullName())
        
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("ValueBase") then
                print("📊", stat.Name .. ":", stat.Value)
                
                if stat.Name:lower():match("level") or stat.Name:lower():match("lvl") then
                    return stat.Value
                end
            end
        end
    end
    
    return nil
end

-- Main execution
print("🚀 Starting level/XP search...")

-- Try Replion first (most reliable)
local replionData = findReplionData()

-- Try GUI method
local guiLevel = findLevelFromGUI()

-- Try leaderstats
local leaderstatsLevel = findLeaderstats()

-- Summary
print("\n📋 === SUMMARY ===")
if replionData then
    print("✅ Replion Data - Level:", replionData.level, "XP:", replionData.xp)
end
if guiLevel then
    print("✅ GUI Level:", guiLevel)
end
if leaderstatsLevel then
    print("✅ Leaderstats Level:", leaderstatsLevel)
end

-- Recommend best source
if replionData and replionData.level then
    print("🎯 RECOMMENDED: Use Replion system for most accurate data")
    print("   Code: Client:WaitReplion('Data'):GetExpect('Level')")
elseif guiLevel then
    print("🎯 RECOMMENDED: Use PlayerGui.XP.Frame.LevelCount")
elseif leaderstatsLevel then
    print("🎯 RECOMMENDED: Use leaderstats")
else
    print("❌ No level data found!")
end

print("✅ Level/XP search complete!")
