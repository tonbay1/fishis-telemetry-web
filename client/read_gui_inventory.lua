-- Read GUI Inventory - อ่านข้อมูลจาก PlayerGui.Backpack และ PlayerGui.Inventory
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

local plr = Players.LocalPlayer
if not plr then
    warn("❌ No LocalPlayer")
    return
end

-- ===== HTTP FUNCTION =====
local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)
    if typeof(request) == "function" then
        local ok = pcall(function()
            request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        return ok
    elseif typeof(http) == "table" and typeof(http.request) == "function" then
        local ok = pcall(function()
            http.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        return ok
    else
        local ok = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        return ok
    end
end

print("🎒 Reading GUI Inventory...")

-- ===== READ INVENTORY DATA =====
local inventory = {
    rods = {},
    baits = {},
    items = {},
    money = 0,
    level = 0,
    stats = {}
}

-- Get basic stats from leaderstats
local ls = plr:FindFirstChild("leaderstats")
if ls then
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("ValueBase") then
            local ok, val = pcall(function() return v.Value end)
            if ok then
                inventory.stats[v.Name] = val
                if string.find(string.lower(v.Name), "money") or string.find(string.lower(v.Name), "cash") then
                    inventory.money = val
                elseif string.find(string.lower(v.Name), "level") or string.find(string.lower(v.Name), "lvl") then
                    inventory.level = val
                end
            end
        end
    end
end

-- ===== SCAN GUI INVENTORY =====
local function scanGuiForItems(gui, guiName)
    if not gui then
        print("❌", guiName, "not found")
        return
    end
    
    print("🔍 Scanning", guiName, "...")
    
    local function extractItemData(element, path, depth)
        if not element or depth > 5 then return end
        
        local name = element.Name
        local className = element.ClassName
        
        -- Look for TextLabels that contain item information
        if className == "TextLabel" or className == "TextButton" then
            local text = element.Text
            if text and #text > 0 then
                -- Check if this looks like rod/bait data
                if string.find(text, "Rod") and (string.find(text, "ID:") or string.find(text, "|")) then
                    table.insert(inventory.rods, text)
                    print("🎣 Found rod:", text)
                elseif string.find(text, "Bait") and (string.find(text, "ID:") or string.find(text, "|")) then
                    table.insert(inventory.baits, text)
                    print("🪱 Found bait:", text)
                elseif string.find(text, "ID:") or string.find(text, "UUID:") then
                    table.insert(inventory.items, text)
                    print("📦 Found item:", text)
                end
            end
        end
        
        -- Check attributes for item data
        local attrs = element:GetAttributes()
        if next(attrs) then
            for k, v in pairs(attrs) do
                if typeof(v) == "string" then
                    if string.find(v, "Rod") and (string.find(v, "ID") or string.find(v, "UUID")) then
                        table.insert(inventory.rods, v)
                        print("🎣 Found rod (attr):", v)
                    elseif string.find(v, "Bait") and (string.find(v, "ID") or string.find(v, "UUID")) then
                        table.insert(inventory.baits, v)
                        print("🪱 Found bait (attr):", v)
                    end
                elseif typeof(v) == "table" then
                    local jsonStr = HttpService:JSONEncode(v)
                    if string.find(jsonStr, "Rod") or string.find(jsonStr, "Bait") then
                        print("📊 Found item data (attr):", k, "=", jsonStr)
                    end
                end
            end
        end
        
        -- Check for ModuleScripts that might contain inventory data
        if className == "ModuleScript" then
            local ok, data = pcall(require, element)
            if ok and typeof(data) == "table" then
                print("📦 Found ModuleScript:", path)
                
                -- Check if this contains inventory data
                for k, v in pairs(data) do
                    if typeof(v) == "table" then
                        local jsonStr = HttpService:JSONEncode(v)
                        if string.find(jsonStr, "Rod") or string.find(jsonStr, "Bait") or string.find(jsonStr, "ID") then
                            print("  📄", k, "=", jsonStr)
                        end
                    elseif typeof(v) == "string" and (string.find(v, "Rod") or string.find(v, "Bait")) then
                        print("  📄", k, "=", v)
                        if string.find(v, "Rod") then
                            table.insert(inventory.rods, v)
                        elseif string.find(v, "Bait") then
                            table.insert(inventory.baits, v)
                        end
                    end
                end
            end
        end
        
        -- Recursively scan children
        for _, child in ipairs(element:GetChildren()) do
            extractItemData(child, path .. "." .. child.Name, depth + 1)
        end
    end
    
    extractItemData(gui, guiName, 0)
end

-- ===== SCAN SPECIFIC GUI LOCATIONS =====
local pg = plr:WaitForChild("PlayerGui")

-- Scan Backpack GUI
local backpackGui = pg:FindFirstChild("Backpack")
scanGuiForItems(backpackGui, "PlayerGui.Backpack")

-- Scan Inventory GUI
local inventoryGui = pg:FindFirstChild("Inventory")
scanGuiForItems(inventoryGui, "PlayerGui.Inventory")

-- Also scan other common inventory GUI names
local otherGuis = {"InventoryGui", "Bag", "BagGui", "Items", "ItemsGui", "MainGui", "HUD"}
for _, guiName in ipairs(otherGuis) do
    local gui = pg:FindFirstChild(guiName)
    if gui then
        scanGuiForItems(gui, "PlayerGui." .. guiName)
    end
end

-- ===== BUILD DISCORD EMBED =====
local fields = {}
table.insert(fields, { name = "👤 Player", value = string.format("%s (%s)", plr.Name, plr.UserId), inline = true })
table.insert(fields, { name = "⏰ Time", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true })

-- Money & Level
if inventory.money > 0 then
    table.insert(fields, { name = "💰 Money", value = string.format("%s", tostring(inventory.money)), inline = true })
end
if inventory.level > 0 then
    table.insert(fields, { name = "🏆 Level", value = string.format("Lvl: %s", tostring(inventory.level)), inline = true })
end

-- Stats
if next(inventory.stats) then
    local statLines = {}
    for k, v in pairs(inventory.stats) do
        table.insert(statLines, string.format("%s: %s", k, tostring(v)))
    end
    table.sort(statLines)
    table.insert(fields, { name = "📊 Stats", value = table.concat(statLines, "\n"), inline = false })
end

-- Rods
if #inventory.rods > 0 then
    local rodText = table.concat(inventory.rods, "\n")
    if #rodText > 1000 then
        rodText = rodText:sub(1, 997) .. "..."
    end
    table.insert(fields, { name = "🎣 Rods", value = rodText, inline = false })
else
    table.insert(fields, { name = "🎣 Rods", value = "❌ No rods found in GUI\n(Try opening inventory in game first)", inline = false })
end

-- Baits
if #inventory.baits > 0 then
    local baitText = table.concat(inventory.baits, "\n")
    if #baitText > 1000 then
        baitText = baitText:sub(1, 997) .. "..."
    end
    table.insert(fields, { name = "🪱 Baits", value = baitText, inline = false })
else
    table.insert(fields, { name = "🪱 Baits", value = "❌ No baits found in GUI\n(Try opening inventory in game first)", inline = false })
end

-- Other items
if #inventory.items > 0 then
    local itemText = table.concat(inventory.items, "\n")
    if #itemText > 1000 then
        itemText = itemText:sub(1, 997) .. "..."
    end
    table.insert(fields, { name = "📦 Other Items", value = itemText, inline = false })
end

local embed = {
    title = "🎒 Player Info",
    description = "Here are your stats, rods and baits!",
    color = 16776960,
    fields = fields,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
}

local payload = {
    content = "📊 FishIs GUI inventory scan",
    embeds = { embed }
}

if sendWebhook(payload) then
    print("✅ GUI inventory sent to Discord")
else
    warn("❌ Failed to send GUI inventory")
end

print("🎉 GUI inventory scan complete!")
print("📊 Summary:")
print("  🎣 Rods found:", #inventory.rods)
print("  🪱 Baits found:", #inventory.baits)
print("  📦 Other items found:", #inventory.items)

if #inventory.rods == 0 and #inventory.baits == 0 then
    print("💡 Tips:")
    print("- Open inventory/backpack in game first")
    print("- Make sure you have rods/baits in your inventory")
    print("- Try equipping a rod or using a bait")
end
