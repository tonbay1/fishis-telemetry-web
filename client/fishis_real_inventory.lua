-- FishIs Real Inventory - อ่านข้อมูล inventory จริงของผู้เล่นจาก ReplicatedStorage.Items
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

print("🎒 FishIs Real Inventory starting...")

-- ===== LOAD ITEMS CATALOG =====
local itemsCatalog = {}
local baitsCatalog = {}

-- Load Items catalog
local itemsModule = ReplicatedStorage:FindFirstChild("Items")
if itemsModule and itemsModule:IsA("ModuleScript") then
    local ok, items = pcall(require, itemsModule)
    if ok and typeof(items) == "table" then
        itemsCatalog = items
        print("✅ Loaded Items catalog:", #itemsCatalog, "items")
    else
        warn("❌ Failed to require Items module")
    end
else
    warn("❌ Items module not found")
end

-- Load Baits catalog
local baitsModule = ReplicatedStorage:FindFirstChild("Baits")
if baitsModule and baitsModule:IsA("ModuleScript") then
    local ok, baits = pcall(require, baitsModule)
    if ok and typeof(baits) == "table" then
        baitsCatalog = baits
        print("✅ Loaded Baits catalog:", #baitsCatalog, "baits")
    else
        warn("❌ Failed to require Baits module")
    end
else
    warn("❌ Baits module not found")
end

-- ===== FIND PLAYER INVENTORY DATA =====
local function findPlayerInventory()
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
    
    -- Search for player inventory in common locations
    local searchPaths = {
        plr,
        ReplicatedStorage:FindFirstChild("PlayerData"),
        ReplicatedStorage:FindFirstChild("Data"),
        ReplicatedStorage:FindFirstChild("Players"),
    }
    
    for _, root in ipairs(searchPaths) do
        if root then
            -- Look for player-specific data
            local function searchInInstance(inst, depth)
                if not inst or depth > 3 then return end
                
                local name = string.lower(inst.Name)
                if string.find(name, string.lower(plr.Name)) or 
                   string.find(name, tostring(plr.UserId)) or
                   string.find(name, "inventory") or
                   string.find(name, "items") or
                   string.find(name, "rods") or
                   string.find(name, "baits") then
                    
                    print("🔍 Checking:", inst:GetFullName())
                    
                    -- Check if this contains inventory data
                    for _, child in ipairs(inst:GetChildren()) do
                        if child:IsA("ValueBase") then
                            local ok, val = pcall(function() return child.Value end)
                            if ok then
                                print("  📄", child.Name, "=", val)
                                
                                -- Try to parse as item data
                                if typeof(val) == "string" and (string.find(val, "Rod") or string.find(val, "Bait")) then
                                    if string.find(val, "Rod") then
                                        table.insert(inventory.rods, val)
                                    elseif string.find(val, "Bait") then
                                        table.insert(inventory.baits, val)
                                    end
                                end
                            end
                        elseif child:IsA("Folder") then
                            searchInInstance(child, depth + 1)
                        end
                    end
                    
                    -- Check attributes
                    local attrs = inst:GetAttributes()
                    if next(attrs) then
                        print("  🏷️ Attributes:", HttpService:JSONEncode(attrs))
                        for k, v in pairs(attrs) do
                            if string.find(string.lower(k), "rod") or string.find(string.lower(k), "bait") or string.find(string.lower(k), "item") then
                                if typeof(v) == "string" then
                                    if string.find(v, "Rod") then
                                        table.insert(inventory.rods, v)
                                    elseif string.find(v, "Bait") then
                                        table.insert(inventory.baits, v)
                                    end
                                elseif typeof(v) == "table" then
                                    for _, item in ipairs(v) do
                                        if typeof(item) == "string" then
                                            if string.find(item, "Rod") then
                                                table.insert(inventory.rods, item)
                                            elseif string.find(item, "Bait") then
                                                table.insert(inventory.baits, item)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Continue searching children
                for _, child in ipairs(inst:GetChildren()) do
                    searchInInstance(child, depth + 1)
                end
            end
            
            searchInInstance(root, 0)
        end
    end
    
    return inventory
end

-- ===== HOOK INVENTORY EVENTS =====
local function hookInventoryEvents()
    local function findNetFolder()
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        if not packages then return nil end
        local index = packages:FindFirstChild("_Index")
        if not index then return nil end
        for _, child in ipairs(index:GetChildren()) do
            if string.find(string.lower(child.Name), "sleitnick_net") then
                local netFolder = child:FindFirstChild("net")
                if netFolder then
                    return netFolder:FindFirstChild("RE")
                end
            end
        end
        return nil
    end
    
    local reFolder = findNetFolder()
    if not reFolder then
        print("⚠️ RemoteEvents folder not found")
        return
    end
    
    local inventoryEvents = {
        "EquipItem", "UnequipItem", "EquipBait", "EquipRodSkin", "UnequipRodSkin",
        "FavoriteItem", "BaitSpawned"
    }
    
    local hooked = 0
    for _, eventName in ipairs(inventoryEvents) do
        local re = reFolder:FindFirstChild(eventName)
        if re and re:IsA("RemoteEvent") then
            hooked = hooked + 1
            re.OnClientEvent:Connect(function(...)
                local args = {...}
                print("📡 Event:", eventName, HttpService:JSONEncode(args))
                
                -- Send to Discord
                local embed = {
                    title = "🎒 Inventory Event: " .. eventName,
                    description = "```json\n" .. HttpService:JSONEncode(args) .. "\n```",
                    color = 16776960,
                    fields = {
                        { name = "Player", value = plr.Name, inline = true },
                        { name = "Time", value = os.date("%H:%M:%S"), inline = true },
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
                sendWebhook({ content = "🔄 Inventory Event", embeds = { embed } })
            end)
        end
    end
    print("🔗 Hooked inventory events:", hooked)
end

-- ===== MAIN EXECUTION =====
local inventory = findPlayerInventory()

-- Build Discord embed
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
    local rodLines = {}
    for i, rod in ipairs(inventory.rods) do
        -- Try to get rod details from catalog
        local rodData = itemsCatalog[rod]
        if rodData and typeof(rodData) == "table" then
            local id = rodData.ID or i
            local uuid = rodData.UUID or "unknown"
            table.insert(rodLines, string.format("%s | ID: %s | UUID: %s", rod, tostring(id), tostring(uuid)))
        else
            table.insert(rodLines, string.format("%s | ID: %s | UUID: unknown", rod, tostring(i)))
        end
    end
    table.insert(fields, { name = "🎣 Rods", value = table.concat(rodLines, "\n"), inline = false })
else
    table.insert(fields, { name = "🎣 Rods", value = "❌ No rods found in inventory\n(Check F9 console for search details)", inline = false })
end

-- Baits
if #inventory.baits > 0 then
    local baitLines = {}
    for i, bait in ipairs(inventory.baits) do
        -- Try to get bait details from catalog
        local baitData = baitsCatalog[bait]
        if baitData and typeof(baitData) == "table" then
            local id = baitData.ID or i
            local uuid = baitData.UUID or "unknown"
            table.insert(baitLines, string.format("%s | ID: %s | UUID: %s", bait, tostring(id), tostring(uuid)))
        else
            table.insert(baitLines, string.format("%s | ID: %s | UUID: unknown", bait, tostring(i)))
        end
    end
    table.insert(fields, { name = "🪱 Baits", value = table.concat(baitLines, "\n"), inline = false })
else
    table.insert(fields, { name = "🪱 Baits", value = "❌ No baits found in inventory\n(Check F9 console for search details)", inline = false })
end

local embed = {
    title = "🎒 Player Info",
    description = "Here are your stats, rods and baits!",
    color = 16776960,
    fields = fields,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
}

local payload = {
    content = "📊 FishIs inventory scan via " .. (httpRequest and "executor" or "HttpService"),
    embeds = { embed }
}

if sendWebhook(payload) then
    print("✅ Inventory sent to Discord")
else
    warn("❌ Failed to send inventory")
end

-- Hook events for real-time updates
hookInventoryEvents()

print("🟢 Real inventory telemetry active!")
print("📝 If rods/baits not found, check F9 console for search paths.")
