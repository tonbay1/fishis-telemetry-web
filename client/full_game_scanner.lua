-- Full Game Scanner - Scans EVERYTHING in the game
-- Sends all data to server for analysis

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local TELEMETRY_URLS = {
    "http://127.0.0.1:3001/telemetry",
    "http://localhost:3001/telemetry",
    -- If localhost is blocked, set your LAN IP below, e.g. "http://192.168.1.10:3001/telemetry"
}
local plr = Players.LocalPlayer

-- Show notification
StarterGui:SetCore("SendNotification", {
    Title = "🔍 Full Game Scanner",
    Text = "Scanning EVERYTHING in the game...",
    Duration = 3
})

-- Executor-aware HTTP helpers
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
        local ok2, res = pcall(req, { Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
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

local function sendData(data)
    for _, url in ipairs(TELEMETRY_URLS) do
        local ok, res = sendJson(url, data)
        if ok then
            print("✅ Data sent successfully ->", url)
            return true
        end
    end
    warn("❌ Failed to send data to all URLs")
    return false
end

-- Scan function to get all possible data
local function scanEverything()
    print("🔍 Starting comprehensive scan...")
    
    local scanData = {
        account = plr.Name,
        playerName = plr.Name,
        userId = plr.UserId,
        displayName = plr.DisplayName,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        
        -- Player data containers
        leaderstats = {},
        attributes = {},
        playerGui = {},
        allTextLabels = {},
        allFrames = {},
        allValues = {},
        
        -- Specific searches
        moneyRelated = {},
        levelRelated = {},
        locationRelated = {},
        rodRelated = {},
        baitRelated = {},
        inventoryRelated = {}
    }
    
    print("📊 Scanning leaderstats...")
    -- Scan leaderstats
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("ValueBase") then
                local ok, val = pcall(function() return stat.Value end)
                if ok then
                    scanData.leaderstats[stat.Name] = {
                        name = stat.Name,
                        value = val,
                        className = stat.ClassName
                    }
                    print("   📈", stat.Name .. ":", val, "(" .. stat.ClassName .. ")")
                end
            end
        end
    else
        print("   ❌ No leaderstats found")
    end
    
    print("🎯 Scanning player attributes...")
    -- Scan player attributes
    for k, v in pairs(plr:GetAttributes()) do
        scanData.attributes[k] = v
        print("   🔧", k .. ":", v)
    end
    
    print("🖥️ Scanning PlayerGui...")
    -- Scan PlayerGui
    local playerGui = plr:FindFirstChild("PlayerGui")
    if playerGui then
        -- Get all GUI children
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                scanData.playerGui[gui.Name] = {
                    name = gui.Name,
                    className = gui.ClassName,
                    children = {}
                }
                
                -- Get immediate children
                for _, child in pairs(gui:GetChildren()) do
                    table.insert(scanData.playerGui[gui.Name].children, {
                        name = child.Name,
                        className = child.ClassName
                    })
                end
                
                print("   📱", gui.Name, "(" .. #gui:GetChildren() .. " children)")
            end
        end
        
        print("🔤 Scanning all TextLabels...")
        -- Scan ALL TextLabels
        local textLabelCount = 0
        for _, descendant in pairs(playerGui:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text and descendant.Text ~= "" then
                textLabelCount = textLabelCount + 1
                local text = descendant.Text
                local path = descendant:GetFullName()
                
                table.insert(scanData.allTextLabels, {
                    text = text,
                    name = descendant.Name,
                    path = path,
                    parent = descendant.Parent.Name
                })
                
                -- Categorize by content
                local lowerText = text:lower()
                local lowerName = descendant.Name:lower()
                local lowerParent = descendant.Parent.Name:lower()
                
                -- Money related
                if text:match("%d") and (text:find("$") or lowerName:find("money") or lowerName:find("coin") or lowerName:find("cash") or lowerParent:find("money") or lowerParent:find("coin")) then
                    table.insert(scanData.moneyRelated, {
                        text = text,
                        name = descendant.Name,
                        parent = descendant.Parent.Name,
                        path = path
                    })
                end
                
                -- Level related
                if (text:match("level") or text:match("lvl") or text:match("^%d+$")) and (lowerName:find("level") or lowerName:find("lvl") or lowerParent:find("level") or lowerParent:find("lvl") or text:match("Level") or text:match("Lvl")) then
                    table.insert(scanData.levelRelated, {
                        text = text,
                        name = descendant.Name,
                        parent = descendant.Parent.Name,
                        path = path
                    })
                end
                
                -- Location related
                if lowerName:find("location") or lowerParent:find("location") or (text:len() > 5 and text:len() < 30 and not text:match("%d") and text:match("^[%a%s]+$")) then
                    table.insert(scanData.locationRelated, {
                        text = text,
                        name = descendant.Name,
                        parent = descendant.Parent.Name,
                        path = path
                    })
                end
                
                -- Rod related
                if text:find("Rod") then
                    table.insert(scanData.rodRelated, {
                        text = text,
                        name = descendant.Name,
                        parent = descendant.Parent.Name,
                        path = path
                    })
                end
                
                -- Bait related
                if text:find("Worm") or text:find("Shrimp") or text:find("Squid") or text:find("Fish Head") or text:find("Maggot") or text:find("Bagel") or text:find("Flakes") or text:find("Minnow") then
                    table.insert(scanData.baitRelated, {
                        text = text,
                        name = descendant.Name,
                        parent = descendant.Parent.Name,
                        path = path
                    })
                end
                
                -- Inventory related
                if lowerName:find("inventory") or lowerParent:find("inventory") or lowerName:find("item") or lowerParent:find("item") then
                    table.insert(scanData.inventoryRelated, {
                        text = text,
                        name = descendant.Name,
                        parent = descendant.Parent.Name,
                        path = path
                    })
                end
            end
        end
        print("   📝 Found", textLabelCount, "TextLabels")
        
        print("📦 Scanning all Frames...")
        -- Scan ALL Frames
        local frameCount = 0
        for _, descendant in pairs(playerGui:GetDescendants()) do
            if descendant:IsA("Frame") or descendant:IsA("ScrollingFrame") then
                frameCount = frameCount + 1
                local path = descendant:GetFullName()
                
                table.insert(scanData.allFrames, {
                    name = descendant.Name,
                    className = descendant.ClassName,
                    path = path,
                    parent = descendant.Parent.Name,
                    childCount = #descendant:GetChildren()
                })
            end
        end
        print("   🖼️ Found", frameCount, "Frames")
        
        print("🔢 Scanning all ValueBase objects...")
        -- Scan ALL ValueBase objects
        local valueCount = 0
        for _, descendant in pairs(playerGui:GetDescendants()) do
            if descendant:IsA("ValueBase") then
                valueCount = valueCount + 1
                local ok, val = pcall(function() return descendant.Value end)
                if ok then
                    table.insert(scanData.allValues, {
                        name = descendant.Name,
                        value = val,
                        className = descendant.ClassName,
                        path = descendant:GetFullName(),
                        parent = descendant.Parent.Name
                    })
                end
            end
        end
        print("   💎 Found", valueCount, "ValueBase objects")
    end
    
    -- Add summary counts
    scanData.summary = {
        leaderstatsCount = #scanData.leaderstats,
        attributesCount = 0,
        textLabelsCount = #scanData.allTextLabels,
        framesCount = #scanData.allFrames,
        valuesCount = #scanData.allValues,
        moneyRelatedCount = #scanData.moneyRelated,
        levelRelatedCount = #scanData.levelRelated,
        locationRelatedCount = #scanData.locationRelated,
        rodRelatedCount = #scanData.rodRelated,
        baitRelatedCount = #scanData.baitRelated,
        inventoryRelatedCount = #scanData.inventoryRelated
    }
    
    for _ in pairs(scanData.attributes) do
        scanData.summary.attributesCount = scanData.summary.attributesCount + 1
    end
    
    print("📊 Scan Summary:")
    print("   Leaderstats:", scanData.summary.leaderstatsCount)
    print("   Attributes:", scanData.summary.attributesCount)
    print("   TextLabels:", scanData.summary.textLabelsCount)
    print("   Frames:", scanData.summary.framesCount)
    print("   Values:", scanData.summary.valuesCount)
    print("   Money-related:", scanData.summary.moneyRelatedCount)
    print("   Level-related:", scanData.summary.levelRelatedCount)
    print("   Location-related:", scanData.summary.locationRelatedCount)
    print("   Rod-related:", scanData.summary.rodRelatedCount)
    print("   Bait-related:", scanData.summary.baitRelatedCount)
    print("   Inventory-related:", scanData.summary.inventoryRelatedCount)
    
    -- Send all data to server
    sendData(scanData)
end

-- Run scan immediately and then every 10 seconds
print("🚀 Starting full game scan...")

-- First scan immediately
spawn(function()
    wait(1) -- Short wait for game to load
    print("🔍 Running first scan...")
    local success, err = pcall(scanEverything)
    if not success then
        warn("❌ First scan failed:", err)
    end
end)

-- Then scan every 10 seconds
spawn(function()
    wait(5) -- Wait a bit before starting loop
    while true do
        print("🔄 Running periodic scan...")
        local success, err = pcall(scanEverything)
        if not success then
            warn("❌ Periodic scan failed:", err)
        end
        wait(10)
    end
end)
