-- Deep Inventory Scan to Discord - รวบรวมผลลัพธ์ทั้งหมดส่งไป Discord
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

-- ===== EXECUTOR HTTP =====
local function findHttpRequest()
    if typeof(syn) == "table" and typeof(syn.request) == "function" then return syn.request, "syn.request" end
    if typeof(http) == "table" and typeof(http.request) == "function" then return http.request, "http.request" end
    if typeof(request) == "function" then return request, "request" end
    if typeof(http_request) == "function" then return http_request, "http_request" end
    return nil, nil
end
local httpRequest, httpSource = findHttpRequest()

local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)
    if httpRequest then
        local ok, res = pcall(function()
            return httpRequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        if not ok then warn("❌ Executor HTTP error:", res); return false end
        local code = (typeof(res) == "table" and res.StatusCode) or nil
        return (code == 200 or code == 204 or code == nil)
    else
        local ok, err = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        if not ok then warn("❌ HttpService PostAsync error:", err) end
        return ok
    end
end

local plr = Players.LocalPlayer
if not plr then
    warn("❌ No LocalPlayer found")
    return
end

-- ===== DATA COLLECTION =====
local scanResults = {
    player = { name = plr.Name, id = plr.UserId },
    time = os.date("%Y-%m-%d %H:%M:%S"),
    playerStructure = {},
    replicatedStorage = {},
    playerScripts = {},
    playerGui = {},
    inventoryModules = {},
    inventoryRemotes = {},
    summary = {}
}

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
                if count > 8 then parts[#parts+1] = "..."; break end
                parts[#parts+1] = tostring(k) .. ":" .. serialize(v, depth + 1)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        elseif t == "Instance" then
            return obj.ClassName .. ":" .. obj.Name
        else
            local str = tostring(obj)
            if #str > 100 then str = str:sub(1, 97) .. "..." end
            return str
        end
    end
    return serialize(val, 0)
end

local function isInventoryRelated(name)
    name = string.lower(name)
    local keywords = {"rod", "bait", "fish", "item", "inventory", "bag", "equipment", "gear", "tool", "weapon"}
    for _, keyword in ipairs(keywords) do
        if string.find(name, keyword) then return true end
    end
    return false
end

local function scanInstance(inst, path, results, depth)
    if not inst or depth > 3 then return end
    
    local name = string.lower(inst.Name)
    local className = inst.ClassName
    local children = inst:GetChildren()
    
    local isInteresting = isInventoryRelated(name) or 
                         string.find(name, string.lower(plr.Name)) or 
                         string.find(name, tostring(plr.UserId)) or
                         (className == "Folder" and #children > 0) or
                         className == "ModuleScript"
    
    if isInteresting then
        local entry = {
            path = path,
            className = className,
            childCount = #children,
            attributes = {},
            values = {},
            moduleData = nil
        }
        
        -- Attributes
        local attrs = inst:GetAttributes()
        if next(attrs) then
            entry.attributes = attrs
        end
        
        -- ValueBase objects
        for _, child in ipairs(children) do
            if child:IsA("ValueBase") then
                local ok, val = pcall(function() return child.Value end)
                if ok then
                    entry.values[child.Name] = val
                end
            end
        end
        
        -- ModuleScript data
        if className == "ModuleScript" then
            local ok, data = pcall(require, inst)
            if ok and typeof(data) == "table" then
                entry.moduleData = safeJSON(data, 1)
            end
        end
        
        table.insert(results, entry)
        
        -- Recurse into interesting children
        for _, child in ipairs(children) do
            scanInstance(child, path .. "." .. child.Name, results, depth + 1)
        end
    end
end

-- ===== SCAN EXECUTION =====
print("🔍 Deep scanning and collecting data...")

-- Scan Player
scanInstance(plr, "Players." .. plr.Name, scanResults.playerStructure, 0)

-- Scan ReplicatedStorage
for _, child in ipairs(ReplicatedStorage:GetChildren()) do
    scanInstance(child, "ReplicatedStorage." .. child.Name, scanResults.replicatedStorage, 0)
end

-- Scan PlayerScripts
local ps = plr:FindFirstChild("PlayerScripts")
if ps then
    scanInstance(ps, "PlayerScripts", scanResults.playerScripts, 0)
end

-- Scan PlayerGui for inventory-related GUIs
local pg = plr:FindFirstChild("PlayerGui")
if pg then
    for _, gui in ipairs(pg:GetChildren()) do
        if isInventoryRelated(gui.Name) then
            scanInstance(gui, "PlayerGui." .. gui.Name, scanResults.playerGui, 0)
        end
    end
end

-- Find inventory-related ModuleScripts
for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
    if inst:IsA("ModuleScript") then
        local ok, data = pcall(require, inst)
        if ok and typeof(data) == "table" then
            local hasInventoryData = false
            local sampleData = {}
            local keyCount = 0
            
            for k, v in pairs(data) do
                keyCount += 1
                if keyCount <= 3 then
                    sampleData[k] = safeJSON(v, 1)
                end
                
                if typeof(v) == "table" then
                    for subK, subV in pairs(v) do
                        local subKeyLower = string.lower(tostring(subK))
                        if string.find(subKeyLower, "id") or string.find(subKeyLower, "uuid") or
                           string.find(subKeyLower, "name") or string.find(subKeyLower, "rarity") then
                            hasInventoryData = true
                            break
                        end
                    end
                end
                
                if isInventoryRelated(tostring(k)) then
                    hasInventoryData = true
                end
                
                if hasInventoryData then break end
            end
            
            if hasInventoryData then
                table.insert(scanResults.inventoryModules, {
                    path = inst:GetFullName(),
                    keyCount = keyCount,
                    sampleData = sampleData
                })
            end
        end
    end
end

-- Find inventory-related RemoteEvents
for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
    if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
        if isInventoryRelated(inst.Name) then
            table.insert(scanResults.inventoryRemotes, {
                path = inst:GetFullName(),
                className = inst.ClassName
            })
        end
    end
end

-- ===== BUILD DISCORD EMBEDS =====
local function buildSummaryEmbed()
    local fields = {}
    table.insert(fields, { name = "👤 Player", value = string.format("%s (%s)", scanResults.player.name, scanResults.player.id), inline = true })
    table.insert(fields, { name = "⏰ Time", value = scanResults.time, inline = true })
    table.insert(fields, { name = "📊 Results", value = string.format("Player: %d\nReplicatedStorage: %d\nPlayerScripts: %d\nModules: %d\nRemotes: %d", 
        #scanResults.playerStructure, #scanResults.replicatedStorage, #scanResults.playerScripts, 
        #scanResults.inventoryModules, #scanResults.inventoryRemotes), inline = false })
    
    return {
        title = "🔍 Deep Inventory Scan Results",
        description = "Complete scan of potential inventory locations",
        color = 3447003,
        fields = fields,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
end

local function buildDetailEmbed(title, data, color)
    if #data == 0 then return nil end
    
    local description = ""
    for i, entry in ipairs(data) do
        if i > 15 then description = description .. "\n... and " .. (#data - 15) .. " more"; break end
        
        local line = "**" .. entry.path .. "**"
        if entry.className then line = line .. " (" .. entry.className .. ")" end
        if entry.childCount then line = line .. " - " .. entry.childCount .. " children" end
        if entry.keyCount then line = line .. " - " .. entry.keyCount .. " keys" end
        
        if entry.attributes and next(entry.attributes) then
            line = line .. "\n  🏷️ " .. safeJSON(entry.attributes, 1)
        end
        if entry.values and next(entry.values) then
            line = line .. "\n  📄 " .. safeJSON(entry.values, 1)
        end
        if entry.moduleData then
            line = line .. "\n  📦 " .. entry.moduleData
        end
        if entry.sampleData and next(entry.sampleData) then
            line = line .. "\n  🎯 " .. safeJSON(entry.sampleData, 1)
        end
        
        description = description .. line .. "\n\n"
        
        if #description > 1800 then
            description = description .. "... (truncated)"
            break
        end
    end
    
    return {
        title = title,
        description = description,
        color = color,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
end

-- ===== SEND TO DISCORD =====
local embeds = {}

-- Summary embed
table.insert(embeds, buildSummaryEmbed())

-- Detail embeds
local playerEmbed = buildDetailEmbed("👤 Player Structure", scanResults.playerStructure, 16776960)
if playerEmbed then table.insert(embeds, playerEmbed) end

local rsEmbed = buildDetailEmbed("🗄️ ReplicatedStorage", scanResults.replicatedStorage, 65280)
if rsEmbed then table.insert(embeds, rsEmbed) end

local psEmbed = buildDetailEmbed("📜 PlayerScripts", scanResults.playerScripts, 16711680)
if psEmbed then table.insert(embeds, psEmbed) end

local moduleEmbed = buildDetailEmbed("📦 Inventory Modules", scanResults.inventoryModules, 16753920)
if moduleEmbed then table.insert(embeds, moduleEmbed) end

local remoteEmbed = buildDetailEmbed("🛰️ Inventory Remotes", scanResults.inventoryRemotes, 8388736)
if remoteEmbed then table.insert(embeds, remoteEmbed) end

-- Send embeds (Discord has a limit of 10 embeds per message)
local function sendEmbedBatch(embedBatch, batchNum)
    local payload = {
        content = string.format("📋 Deep Inventory Scan Results (Batch %d) - %s", batchNum, scanResults.player.name),
        embeds = embedBatch
    }
    return sendWebhook(payload)
end

-- Split embeds into batches of 10
local batchSize = 10
local batchNum = 1
local currentBatch = {}

for i, embed in ipairs(embeds) do
    table.insert(currentBatch, embed)
    
    if #currentBatch >= batchSize or i == #embeds then
        if sendEmbedBatch(currentBatch, batchNum) then
            print(string.format("✅ Sent batch %d (%d embeds)", batchNum, #currentBatch))
        else
            warn(string.format("❌ Failed to send batch %d", batchNum))
        end
        
        currentBatch = {}
        batchNum = batchNum + 1
        
        -- Small delay between batches to avoid rate limiting
        if i < #embeds then
            task.wait(1)
        end
    end
end

print("🎉 Deep scan complete! Check Discord for detailed results.")
print("📝 Look for paths that contain your rods/baits data and share them with me.")
