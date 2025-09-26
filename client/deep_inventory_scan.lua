-- Deep Inventory Scan - ค้นหา inventory ทุกมุมทุกซอก
-- สำหรับหาตำแหน่งจริงของ rods, baits, items ที่ผู้เล่นมี

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local plr = Players.LocalPlayer
if not plr then
    warn("❌ No LocalPlayer found")
    return
end

print("🔍 === DEEP INVENTORY SCAN ===")
print("Player:", plr.Name, "ID:", plr.UserId)

-- ===== HELPER FUNCTIONS =====
local function safeJSON(val, maxDepth)
    maxDepth = maxDepth or 2
    local function serialize(obj, depth)
        if depth > maxDepth then return "<deep>" end
        local t = typeof(obj)
        if t == "table" then
            local parts = {}
            local count = 0
            for k, v in pairs(obj) do
                count += 1
                if count > 10 then parts[#parts+1] = "..."; break end
                parts[#parts+1] = tostring(k) .. ":" .. serialize(v, depth + 1)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        elseif t == "Instance" then
            return obj.ClassName .. ":" .. obj.Name
        else
            return tostring(obj)
        end
    end
    return serialize(val, 0)
end

local function scanInstance(inst, path, depth)
    if not inst or depth > 4 then return end
    
    local name = string.lower(inst.Name)
    local className = inst.ClassName
    
    -- Check if this looks like inventory/item data
    local isInteresting = false
    local keywords = {"rod", "bait", "fish", "item", "inventory", "bag", "equipment", "gear", "tool"}
    for _, keyword in ipairs(keywords) do
        if string.find(name, keyword) then
            isInteresting = true
            break
        end
    end
    
    -- Also check if it contains player-specific data
    if string.find(name, string.lower(plr.Name)) or string.find(name, tostring(plr.UserId)) then
        isInteresting = true
    end
    
    -- Check if it's a data structure (Folder, Configuration, etc.)
    if className == "Folder" or className == "Configuration" or className == "ModuleScript" then
        local children = inst:GetChildren()
        if #children > 0 then
            isInteresting = true
        end
    end
    
    if isInteresting then
        print(string.format("%s📁 %s (%s) - %d children", string.rep("  ", depth), path, className, #inst:GetChildren()))
        
        -- Check attributes
        local attrs = inst:GetAttributes()
        if next(attrs) then
            print(string.format("%s  🏷️ Attributes: %s", string.rep("  ", depth), safeJSON(attrs)))
        end
        
        -- Check ValueBase objects
        for _, child in ipairs(inst:GetChildren()) do
            if child:IsA("ValueBase") then
                local ok, val = pcall(function() return child.Value end)
                if ok then
                    print(string.format("%s  📄 %s = %s", string.rep("  ", depth), child.Name, safeJSON(val)))
                end
            end
        end
        
        -- Check if it's a ModuleScript - try to require it
        if className == "ModuleScript" then
            local ok, data = pcall(require, inst)
            if ok and typeof(data) == "table" then
                print(string.format("%s  📦 Module data: %s", string.rep("  ", depth), safeJSON(data, 1)))
            end
        end
        
        -- Recursively scan interesting children
        for _, child in ipairs(inst:GetChildren()) do
            scanInstance(child, path .. "." .. child.Name, depth + 1)
        end
    end
end

-- ===== SCAN LOCATIONS =====
print("\n🔍 Scanning Player...")
scanInstance(plr, "Players." .. plr.Name, 0)

print("\n🔍 Scanning ReplicatedStorage...")
-- Look for player-specific data in ReplicatedStorage
for _, child in ipairs(ReplicatedStorage:GetChildren()) do
    scanInstance(child, "ReplicatedStorage." .. child.Name, 0)
end

print("\n🔍 Scanning PlayerScripts...")
local ps = plr:FindFirstChild("PlayerScripts")
if ps then
    scanInstance(ps, "PlayerScripts", 0)
else
    print("❌ No PlayerScripts found")
end

print("\n🔍 Scanning PlayerGui...")
local pg = plr:FindFirstChild("PlayerGui")
if pg then
    for _, gui in ipairs(pg:GetChildren()) do
        -- Look for inventory-related GUIs
        local name = string.lower(gui.Name)
        if string.find(name, "inventory") or string.find(name, "bag") or 
           string.find(name, "rod") or string.find(name, "bait") or
           string.find(name, "item") then
            scanInstance(gui, "PlayerGui." .. gui.Name, 0)
        end
    end
end

-- ===== ADVANCED SEARCH =====
print("\n🔍 Advanced Search - Looking for data tables...")

-- Try to find any tables that contain rod/bait-like data
local function searchForInventoryTables(root, rootName)
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("ModuleScript") then
            local ok, data = pcall(require, inst)
            if ok and typeof(data) == "table" then
                -- Check if this table contains inventory-like data
                local hasInventoryData = false
                local sampleKeys = {}
                local keyCount = 0
                
                for k, v in pairs(data) do
                    keyCount += 1
                    if keyCount <= 5 then
                        table.insert(sampleKeys, tostring(k))
                    end
                    
                    -- Check if value looks like item data
                    if typeof(v) == "table" then
                        for subK, subV in pairs(v) do
                            local subKeyLower = string.lower(tostring(subK))
                            if string.find(subKeyLower, "id") or string.find(subKeyLower, "uuid") or
                               string.find(subKeyLower, "name") or string.find(subKeyLower, "type") or
                               string.find(subKeyLower, "rarity") or string.find(subKeyLower, "level") then
                                hasInventoryData = true
                                break
                            end
                        end
                    end
                    
                    -- Check key names
                    local keyLower = string.lower(tostring(k))
                    if string.find(keyLower, "rod") or string.find(keyLower, "bait") or
                       string.find(keyLower, "item") or string.find(keyLower, "inventory") or
                       string.find(keyLower, "equipment") then
                        hasInventoryData = true
                    end
                    
                    if hasInventoryData then break end
                end
                
                if hasInventoryData then
                    print(string.format("🎯 Potential inventory data: %s", inst:GetFullName()))
                    print(string.format("   Keys (%d): %s", keyCount, table.concat(sampleKeys, ", ")))
                    print(string.format("   Sample: %s", safeJSON(data, 1)))
                end
            end
        end
    end
end

searchForInventoryTables(ReplicatedStorage, "ReplicatedStorage")
if ps then
    searchForInventoryTables(ps, "PlayerScripts")
end

-- ===== REMOTE EVENTS SCAN =====
print("\n🔍 Scanning RemoteEvents for inventory-related names...")
local function scanRemotes(root)
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
            local name = string.lower(inst.Name)
            local keywords = {"inventory", "item", "rod", "bait", "equip", "unequip", "obtain", "get", "set"}
            for _, keyword in ipairs(keywords) do
                if string.find(name, keyword) then
                    print(string.format("🛰️ %s: %s", inst.ClassName, inst:GetFullName()))
                    break
                end
            end
        end
    end
end

scanRemotes(ReplicatedStorage)

print("\n✅ Deep scan complete!")
print("📋 Summary:")
print("- Check the paths above that look like inventory data")
print("- Look for ModuleScripts that contain player items")
print("- Try interacting with inventory/rods/baits in game, then run again")
print("- If you see promising paths, copy them and we can create a targeted scanner")
