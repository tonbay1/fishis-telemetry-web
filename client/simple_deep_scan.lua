-- Simple Deep Scan - เวอร์ชันง่ายที่รันได้แน่นอน
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
    
    -- Try executor HTTP first
    if typeof(request) == "function" then
        local ok, res = pcall(function()
            return request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        return ok
    elseif typeof(http) == "table" and typeof(http.request) == "function" then
        local ok, res = pcall(function()
            return http.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        return ok
    else
        -- Fallback to HttpService
        local ok, err = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        return ok
    end
end

-- ===== SIMPLE SCAN =====
print("🔍 Simple Deep Scan starting...")

local results = {}
local function addResult(category, path, info)
    table.insert(results, string.format("[%s] %s - %s", category, path, info))
end

-- 1. Scan Player
print("Scanning Player...")
local function scanPlayer()
    for _, child in ipairs(plr:GetChildren()) do
        local name = string.lower(child.Name)
        if string.find(name, "inventory") or string.find(name, "bag") or 
           string.find(name, "rod") or string.find(name, "bait") or
           string.find(name, "item") or string.find(name, "data") then
            
            local info = string.format("%s (%d children)", child.ClassName, #child:GetChildren())
            addResult("PLAYER", "Players." .. plr.Name .. "." .. child.Name, info)
            
            -- Check children
            for _, subchild in ipairs(child:GetChildren()) do
                if subchild:IsA("ValueBase") then
                    local ok, val = pcall(function() return subchild.Value end)
                    if ok then
                        addResult("PLAYER", "  └─ " .. subchild.Name, tostring(val))
                    end
                end
            end
        end
    end
end

-- 2. Scan ReplicatedStorage for player-specific data
print("Scanning ReplicatedStorage...")
local function scanReplicatedStorage()
    for _, child in ipairs(ReplicatedStorage:GetChildren()) do
        local name = string.lower(child.Name)
        if string.find(name, "player") or string.find(name, "data") or
           string.find(name, "inventory") or string.find(name, "item") then
            
            local info = string.format("%s (%d children)", child.ClassName, #child:GetChildren())
            addResult("REPLICATED", "ReplicatedStorage." .. child.Name, info)
            
            -- Look for player-specific folders
            for _, subchild in ipairs(child:GetChildren()) do
                local subname = string.lower(subchild.Name)
                if string.find(subname, string.lower(plr.Name)) or 
                   string.find(subname, tostring(plr.UserId)) then
                    addResult("REPLICATED", "  └─ " .. subchild.Name, subchild.ClassName)
                end
            end
        end
    end
end

-- 3. Find ModuleScripts that might contain inventory data
print("Scanning ModuleScripts...")
local function scanModules()
    local count = 0
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if inst:IsA("ModuleScript") and count < 20 then
            local name = string.lower(inst.Name)
            if string.find(name, "inventory") or string.find(name, "item") or
               string.find(name, "rod") or string.find(name, "bait") or
               string.find(name, "data") then
                
                count = count + 1
                local ok, data = pcall(require, inst)
                if ok and typeof(data) == "table" then
                    local keyCount = 0
                    for k, v in pairs(data) do keyCount = keyCount + 1 end
                    addResult("MODULE", inst:GetFullName(), string.format("table with %d keys", keyCount))
                else
                    addResult("MODULE", inst:GetFullName(), "ModuleScript")
                end
            end
        end
    end
end

-- 4. Find RemoteEvents
print("Scanning RemoteEvents...")
local function scanRemotes()
    local count = 0
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) and count < 15 then
            local name = string.lower(inst.Name)
            if string.find(name, "inventory") or string.find(name, "item") or
               string.find(name, "rod") or string.find(name, "bait") or
               string.find(name, "equip") or string.find(name, "get") then
                
                count = count + 1
                addResult("REMOTE", inst:GetFullName(), inst.ClassName)
            end
        end
    end
end

-- Run scans
scanPlayer()
scanReplicatedStorage()
scanModules()
scanRemotes()

-- ===== SEND RESULTS =====
print("Sending results to Discord...")

-- Split results into chunks for multiple embeds
local function chunkResults(list, chunkSize)
    local chunks = {}
    for i = 1, #list, chunkSize do
        local chunk = {}
        for j = i, math.min(i + chunkSize - 1, #list) do
            table.insert(chunk, list[j])
        end
        table.insert(chunks, chunk)
    end
    return chunks
end

local chunks = chunkResults(results, 20)

for i, chunk in ipairs(chunks) do
    local description = table.concat(chunk, "\n")
    if #description > 1900 then
        description = description:sub(1, 1900) .. "...\n(truncated)"
    end
    
    local embed = {
        title = string.format("🔍 Deep Scan Results (Part %d/%d)", i, #chunks),
        description = "```\n" .. description .. "\n```",
        color = 3447003,
        fields = {
            { name = "Player", value = plr.Name, inline = true },
            { name = "Total Results", value = tostring(#results), inline = true },
            { name = "Part", value = string.format("%d/%d", i, #chunks), inline = true },
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    
    local payload = {
        content = string.format("📋 Deep Scan Results - %s", plr.Name),
        embeds = { embed }
    }
    
    if sendWebhook(payload) then
        print(string.format("✅ Sent part %d/%d", i, #chunks))
    else
        warn(string.format("❌ Failed to send part %d", i))
    end
    
    -- Wait between sends
    if i < #chunks then
        task.wait(2)
    end
end

print("🎉 Scan complete! Check Discord for results.")
print("📝 Total results found:", #results)

-- Show summary in console
print("\n📊 SUMMARY:")
local categories = {}
for _, result in ipairs(results) do
    local category = result:match("%[(.-)%]")
    categories[category] = (categories[category] or 0) + 1
end
for cat, count in pairs(categories) do
    print(string.format("  %s: %d items", cat, count))
end
