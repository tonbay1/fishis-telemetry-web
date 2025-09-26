-- Find Money Data - ค้นหาข้อมูลเงินด้วยคำหลายๆ แบบ
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
    else
        local ok = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        return ok
    end
end

print("💰 Finding Money Data...")

-- ===== MONEY KEYWORDS =====
local moneyKeywords = {
    "money", "cash", "coin", "coins", "currency", "buck", "bucks", 
    "credit", "credits", "dollar", "dollars", "gold", "silver",
    "gem", "gems", "point", "points", "balance", "wallet",
    "fund", "funds", "wealth", "treasure", "reward", "rewards"
}

local function isMoney(name)
    name = string.lower(name)
    for _, keyword in ipairs(moneyKeywords) do
        if string.find(name, keyword) then
            return true
        end
    end
    return false
end

-- ===== SEARCH FUNCTIONS =====
local results = {}

local function addResult(category, path, name, value, info)
    local result = {
        category = category,
        path = path,
        name = name,
        value = value,
        info = info or ""
    }
    table.insert(results, result)
    print(string.format("[%s] %s.%s = %s %s", category, path, name, tostring(value), info))
end

-- 1. Search in Player leaderstats and direct children
local function searchPlayer()
    print("🔍 Searching Player...")
    
    -- Leaderstats
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("ValueBase") then
                local ok, val = pcall(function() return v.Value end)
                if ok then
                    if isMoney(v.Name) then
                        addResult("LEADERSTATS", "leaderstats", v.Name, val, "💰 MONEY CANDIDATE")
                    else
                        addResult("LEADERSTATS", "leaderstats", v.Name, val)
                    end
                end
            end
        end
    end
    
    -- Direct player children
    for _, child in ipairs(plr:GetChildren()) do
        if child:IsA("ValueBase") then
            local ok, val = pcall(function() return child.Value end)
            if ok then
                if isMoney(child.Name) then
                    addResult("PLAYER", "Player", child.Name, val, "💰 MONEY CANDIDATE")
                else
                    addResult("PLAYER", "Player", child.Name, val)
                end
            end
        end
    end
    
    -- Player attributes
    local attrs = plr:GetAttributes()
    for k, v in pairs(attrs) do
        if isMoney(k) then
            addResult("PLAYER_ATTR", "Player", k, v, "💰 MONEY CANDIDATE")
        else
            addResult("PLAYER_ATTR", "Player", k, v)
        end
    end
end

-- 2. Search in PlayerGui for money displays
local function searchPlayerGui()
    print("🔍 Searching PlayerGui...")
    
    local pg = plr:WaitForChild("PlayerGui")
    
    local function scanGuiForMoney(element, path, depth)
        if not element or depth > 4 then return end
        
        -- Check TextLabels for money values
        if element:IsA("TextLabel") or element:IsA("TextButton") then
            local text = element.Text
            if text and #text > 0 then
                -- Look for number patterns that might be money
                local numbers = string.match(text, "%d+[%d,%.]*")
                if numbers then
                    local name = element.Name
                    if isMoney(name) or isMoney(text) then
                        addResult("GUI_TEXT", path, name, text, "💰 MONEY CANDIDATE")
                    elseif tonumber(numbers:gsub(",", "")) and tonumber(numbers:gsub(",", "")) > 1000 then
                        -- Large numbers might be money
                        addResult("GUI_TEXT", path, name, text, "💰 POSSIBLE MONEY")
                    end
                end
            end
        end
        
        -- Check element name and attributes
        if isMoney(element.Name) then
            local attrs = element:GetAttributes()
            if next(attrs) then
                for k, v in pairs(attrs) do
                    addResult("GUI_ATTR", path, element.Name .. "." .. k, v, "💰 MONEY CANDIDATE")
                end
            end
        end
        
        -- Recursively scan children
        for _, child in ipairs(element:GetChildren()) do
            scanGuiForMoney(child, path .. "." .. child.Name, depth + 1)
        end
    end
    
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            scanGuiForMoney(gui, "PlayerGui." .. gui.Name, 0)
        end
    end
end

-- 3. Search in ReplicatedStorage for player data
local function searchReplicatedStorage()
    print("🔍 Searching ReplicatedStorage...")
    
    local function searchInstance(inst, path, depth)
        if not inst or depth > 3 then return end
        
        local name = string.lower(inst.Name)
        
        -- Check if this instance is related to player data or money
        if string.find(name, string.lower(plr.Name)) or 
           string.find(name, tostring(plr.UserId)) or
           string.find(name, "player") or
           string.find(name, "data") or
           isMoney(inst.Name) then
            
            -- Check ValueBase objects
            for _, child in ipairs(inst:GetChildren()) do
                if child:IsA("ValueBase") then
                    local ok, val = pcall(function() return child.Value end)
                    if ok then
                        if isMoney(child.Name) then
                            addResult("REPLICATED", path, child.Name, val, "💰 MONEY CANDIDATE")
                        else
                            addResult("REPLICATED", path, child.Name, val)
                        end
                    end
                end
            end
            
            -- Check attributes
            local attrs = inst:GetAttributes()
            for k, v in pairs(attrs) do
                if isMoney(k) then
                    addResult("REPLICATED_ATTR", path, k, v, "💰 MONEY CANDIDATE")
                else
                    addResult("REPLICATED_ATTR", path, k, v)
                end
            end
            
            -- Continue searching children
            for _, child in ipairs(inst:GetChildren()) do
                searchInstance(child, path .. "." .. child.Name, depth + 1)
            end
        end
    end
    
    for _, child in ipairs(ReplicatedStorage:GetChildren()) do
        searchInstance(child, "ReplicatedStorage." .. child.Name, 0)
    end
end

-- ===== RUN SEARCHES =====
searchPlayer()
searchPlayerGui()
searchReplicatedStorage()

-- ===== ANALYZE RESULTS =====
print(string.format("\n📊 Found %d results", #results))

-- Separate money candidates from other results
local moneyCandidates = {}
local otherResults = {}

for _, result in ipairs(results) do
    if string.find(result.info, "MONEY") then
        table.insert(moneyCandidates, result)
    else
        table.insert(otherResults, result)
    end
end

-- ===== SEND TO DISCORD =====
local function buildEmbed(title, resultsList, color)
    if #resultsList == 0 then return nil end
    
    local description = ""
    for i, result in ipairs(resultsList) do
        if i > 20 then
            description = description .. string.format("\n... and %d more", #resultsList - 20)
            break
        end
        
        local line = string.format("**[%s]** %s.%s = `%s`", 
            result.category, result.path, result.name, tostring(result.value))
        if result.info and #result.info > 0 then
            line = line .. " " .. result.info
        end
        description = description .. line .. "\n"
    end
    
    return {
        title = title,
        description = description,
        color = color,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
end

local embeds = {}

-- Money candidates embed
local moneyEmbed = buildEmbed("💰 Money Candidates", moneyCandidates, 16776960)
if moneyEmbed then
    table.insert(embeds, moneyEmbed)
end

-- Other results embed (top 15)
if #otherResults > 0 then
    local topOthers = {}
    for i = 1, math.min(15, #otherResults) do
        table.insert(topOthers, otherResults[i])
    end
    local otherEmbed = buildEmbed("📊 Other Data Found", topOthers, 3447003)
    if otherEmbed then
        table.insert(embeds, otherEmbed)
    end
end

-- Summary embed
local summaryEmbed = {
    title = "🔍 Money Search Results",
    description = string.format("Searched for money-related data in FishIs game"),
    color = 65280,
    fields = {
        { name = "👤 Player", value = plr.Name, inline = true },
        { name = "⏰ Time", value = os.date("%H:%M:%S"), inline = true },
        { name = "📊 Results", value = string.format("Money candidates: %d\nOther data: %d\nTotal: %d", 
            #moneyCandidates, #otherResults, #results), inline = false },
    },
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
}
table.insert(embeds, 1, summaryEmbed) -- Add at beginning

-- Send embeds
for i, embed in ipairs(embeds) do
    local payload = {
        content = string.format("💰 Money Search Results (Part %d/%d)", i, #embeds),
        embeds = { embed }
    }
    
    if sendWebhook(payload) then
        print(string.format("✅ Sent part %d/%d", i, #embeds))
    else
        warn(string.format("❌ Failed to send part %d", i))
    end
    
    if i < #embeds then
        task.wait(2)
    end
end

print("🎉 Money search complete!")
if #moneyCandidates > 0 then
    print("💰 Found potential money data! Check Discord for details.")
else
    print("❌ No obvious money data found. Money might be stored with a different name.")
    print("💡 Try looking in Dex Explorer for:")
    print("  - Large number values (>1000)")
    print("  - Values that change when you buy/sell items")
    print("  - leaderstats with numeric values")
end
