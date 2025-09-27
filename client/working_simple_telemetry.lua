-- Working Simple Fisch Telemetry Script
-- Uses proven methods from fishis_complete_inventory.lua

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Read external config from getgenv (executor pattern)
local GEN = (typeof(getgenv) == "function" and getgenv()) or nil
local CFG = (GEN and (GEN.Fishis_Telemetry or GEN.Telemetry_Settings or GEN.SHOP888 or GEN.SHOP888_Settings or GEN.Hermanos_Settings)) or {}

local TELEMETRY_URLS = {
    "http://127.0.0.1:3010/telemetry",
    "http://localhost:3010/telemetry",
    "https://twist-curtis-passport-packaging.trycloudflare.com/telemetry",
    "http://103.58.149.243:3010/telemetry",
    -- If localhost is blocked, set your LAN IP below, e.g. "http://192.168.1.10:3010/telemetry"
}
do
    local apiBase = CFG.apiBase or CFG.API_BASE or CFG.ApiBase
    if typeof(apiBase) == "string" and apiBase ~= "" then
        local base = apiBase
        if string.sub(base, -1) == "/" then base = string.sub(base, 1, -2) end
        -- Prepend provided apiBase while preserving fallbacks
        local defaults = TELEMETRY_URLS
        TELEMETRY_URLS = { base .. "/telemetry" }
        for i = 1, #defaults do TELEMETRY_URLS[#TELEMETRY_URLS + 1] = defaults[i] end
    end
end
local plr = Players.LocalPlayer

-- Logging toggle (can be overridden by CFG.debug)
local LOG = (typeof(CFG.debug) == "boolean" and CFG.debug) or false
local function log(...) if LOG then print(...) end end
local function warnlog(...) if LOG then warn(...) end end

-- Show notification (only when LOG is true)
if LOG then
    StarterGui:SetCore("SendNotification", {
        Title = "🎣 Fisch Telemetry",
        Text = "Script started! Collecting data...",
        Duration = 3
    })
end

-- Always show a short inject toast (3s) to confirm the script is running
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "✅ Telemetry Injected",
        Text = "ฉีดสคริปต์สำเร็จ",
        Duration = 3
    })
end)

-- Global inventory data
local inventory = {
    player = { name = plr.Name, id = plr.UserId, displayName = plr.DisplayName },
    level = 0,
    coin = 0,
    equippedRod = "",
    location = "",
    rods = {},
    baits = {},
    time = os.date("%Y-%m-%d %H:%M:%S"),
    attributes = {}
}

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

local function sendTelemetry(data)
    -- try multiple URLs until one works
    for _, url in ipairs(TELEMETRY_URLS) do
        local ok, res = sendJson(url, data)
        if ok then
            log("✅ Telemetry sent successfully ->", url)
            return true
        end
    end
    warnlog("❌ Failed to send telemetry to all URLs")
    return false
end

-- Helper function to parse coin values with M/K suffixes
local function parseCoinValue(text)
    if not text then return 0 end
    
    -- Handle formats like "2.29M", "1.5K", "127", "1,234"
    local number, suffix = string.match(text, "([%d%.,%s]+)([MKmk]?)")
    if not number then return 0 end
    
    -- Clean the number part
    number = number:gsub(",", ""):gsub("%s", "")
    local value = tonumber(number) or 0
    
    -- Apply suffix multiplier
    if suffix then
        suffix = string.upper(suffix)
        if suffix == "M" then
            value = value * 1000000
        elseif suffix == "K" then
            value = value * 1000
        end
    end
    
    return math.floor(value)
end

-- Find player level using multiple methods
local function findLevel()
    -- Method 1: Try XP GUI (most reliable)
    local pg = plr:FindFirstChild("PlayerGui")
    if pg then
        local xpGui = pg:FindFirstChild("XP")
        if xpGui then
            local frame = xpGui:FindFirstChild("Frame")
            if frame then
                local levelCount = frame:FindFirstChild("LevelCount")
                if levelCount and levelCount:IsA("TextLabel") then
                    local text = levelCount.Text
                    local levelNum = text:match("Lvl (%d+)")
                    if levelNum then
                        inventory.level = tonumber(levelNum)
                        return
                    end
                end
            end
        end
    end
    
    -- Method 2: Try leaderstats
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("ValueBase") then
                local name = stat.Name:lower()
                if name:match("level") or name:match("lvl") then
                    inventory.level = stat.Value
                    return
                end
            end
        end
    end
    
    -- Method 3: Try player attributes
    for k, v in pairs(plr:GetAttributes()) do
        if string.find(string.lower(k), "level") then
            inventory.level = v
            return
        end
    end
end

-- Find player money using multiple methods
local function findMoney()
    -- Method 1: Precise Events HUD path
    local playerGui = plr:FindFirstChild("PlayerGui")
    if playerGui then
        local events = playerGui:FindFirstChild("Events")
        if events then
            local frame = events:FindFirstChild("Frame")
            if frame then
                local cc = frame:FindFirstChild("CurrencyCounter")
                if cc and cc:FindFirstChild("Counter") and cc.Counter:IsA("TextLabel") then
                    local text = cc.Counter.Text
                    local coinValue = parseCoinValue(text)
                    if coinValue > 0 then
                        inventory.coin = coinValue
                        return
                    end
                end
            end
        end

        -- Method 2: Shop currency counters (visible when shop UIs are open)
        local shops = {"Boat Shop", "Rod Shop", "Bait Shop"}
        for _, shopName in ipairs(shops) do
            local shop = playerGui:FindFirstChild(shopName)
            if shop then
                local main = shop:FindFirstChild("Main")
                local content = main and main:FindFirstChild("Content")
                local top = content and content:FindFirstChild("Top")
                local ccf = top and top:FindFirstChild("CurrencyCounterFrame")
                local cf = ccf and ccf:FindFirstChild("CurrencyFrame")
                local counter = cf and cf:FindFirstChild("Counter")
                if counter and counter:IsA("TextLabel") then
                    local coinValue = parseCoinValue(counter.Text)
                    if coinValue > 0 then
                        inventory.coin = coinValue
                        return
                    end
                end
            end
        end
    end

    -- Method 3: leaderstats fallback
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("ValueBase") then
                local name = stat.Name:lower()
                if name:match("money") or name:match("coin") or name:match("cash") then
                    inventory.coin = stat.Value
                    return
                end
            end
        end
    end

    -- Method 4: attributes fallback
    for k, v in pairs(plr:GetAttributes()) do
        if string.find(string.lower(k), "money") or string.find(string.lower(k), "coin") then
            inventory.coin = v
            return
        end
    end

    -- Method 5: generic GUI search as last resort
    if playerGui then
        for _, descendant in pairs(playerGui:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text then
                local text = descendant.Text
                if text:find("$") or text:match("[%d,%.]+[MKmk]?") then
                    local coinValue = parseCoinValue(text)
                    if coinValue > 0 then
                        inventory.coin = coinValue
                        return
                    end
                end
            end
        end
    end
end

-- Find location
local function findLocation()
    -- Method 1: Attribute (most reliable)
    local attr = plr:GetAttribute("LocationName")
    if attr and tostring(attr) ~= "" then
        inventory.location = tostring(attr)
        return
    end

    -- Method 2: Events HUD label
    local playerGui = plr:FindFirstChild("PlayerGui")
    if playerGui then
        local events = playerGui:FindFirstChild("Events")
        local frame = events and events:FindFirstChild("Frame")
        local loc = frame and frame:FindFirstChild("Location")
        local label = loc and loc:FindFirstChild("Label")
        if label and label:IsA("TextLabel") and label.Text and label.Text ~= "" then
            inventory.location = label.Text
            return
        end
    end

    -- Method 3: generic search fallback
    if playerGui then
        for _, descendant in pairs(playerGui:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text then
                if descendant.Name:lower():find("location") then
                    inventory.location = descendant.Text
                    return
                end
            end
        end
    end
end

-- Find inventory items using working method
local function findInventoryItems()
    inventory.rods = {}
    inventory.baits = {}
    
    local playerGui = plr:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    -- Look for inventory GUI
    local inventoryGui = playerGui:FindFirstChild("inventory")
    if not inventoryGui then return end
    
    -- Search through inventory items
    local function searchInventory(parent, depth)
        if depth > 8 then return end
        
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("Frame") or child:IsA("ScrollingFrame") then
                -- Look for item containers
                for _, item in pairs(child:GetChildren()) do
                    if item:IsA("Frame") then
                        -- Find item name
                        local itemName = nil
                        for _, label in pairs(item:GetDescendants()) do
                            if label:IsA("TextLabel") and label.Text and label.Text ~= "" then
                                itemName = label.Text
                                break
                            end
                        end
                        
                        if itemName then
                            -- Classify items
                            if itemName:find("Rod") then
                                -- Avoid duplicates
                                local found = false
                                for _, existing in pairs(inventory.rods) do
                                    if existing == itemName then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(inventory.rods, itemName)
                                end
                            elseif itemName:find("Worm") or itemName:find("Shrimp") or itemName:find("Squid") or 
                                   itemName:find("Fish Head") or itemName:find("Maggot") or itemName:find("Bagel") or
                                   itemName:find("Flakes") or itemName:find("Minnow") or itemName:find("Leech") then
                                -- Avoid duplicates
                                local found = false
                                for _, existing in pairs(inventory.baits) do
                                    if existing == itemName then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(inventory.baits, itemName)
                                end
                            end
                        end
                    end
                end
                
                -- Recursive search
                searchInventory(child, depth + 1)
            end
        end
    end
    
    searchInventory(inventoryGui, 0)
end

-- Find equipped rod
local function findEquippedRod()
    local playerGui = plr:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    -- Look in HUD for equipped item
    local hud = playerGui:FindFirstChild("hud")
    if hud then
        for _, descendant in pairs(hud:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Text and descendant.Text:find("Rod") then
                inventory.equippedRod = descendant.Text
                return
            end
        end
    end
    
    -- Look for equipped item indicators
    for _, descendant in pairs(playerGui:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text and descendant.Text:find("Rod") then
            if descendant.Name:lower():find("equip") or 
               descendant.Parent.Name:lower():find("equip") then
                inventory.equippedRod = descendant.Text
                return
            end
        end
    end
end

-- Main scan function
-- No-GUI rods collection helpers
local function addRodUnique(name)
    if not name or name == "" then return end
    if not string.find(string.lower(name), "rod") then return end
    for _, r in ipairs(inventory.rods) do
        if r == name then return end
    end
    table.insert(inventory.rods, name)
end

-- No-GUI baits collection helpers (names only)
local function addBaitUnique(name)
    if not name or name == "" then return end
    local lname = string.lower(name)
    -- quick bait heuristics
    if not (lname:find("bait") or lname:find("worm") or lname:find("shrimp") or lname:find("squid") or lname:find("maggot") or lname:find("bagel") or lname:find("flakes") or lname:find("minnow") or lname:find("leech") or lname:find("fish head")) then
        return
    end
    for _, b in ipairs(inventory.baits) do
        if b == name then return end
    end
    table.insert(inventory.baits, name)
end

local function scanTools(container)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") or child:IsA("Model") then
            local n = child.Name or ""
            if n:find("Rod") then addRodUnique(n) end
        end
    end
end

local function findRodsEverywhere()
    -- Merge sources without relying on inventory GUI
    pcall(function() scanTools(plr:FindFirstChild("Backpack")) end)
    pcall(function() scanTools(plr.Character) end)
    pcall(function() scanTools(plr:FindFirstChild("StarterGear")) end)

    -- Player attributes that imply ownership
    for k, v in pairs(plr:GetAttributes()) do
        local lk = string.lower(k)
        if lk:find("rod") then
            local truthy = (type(v) == "boolean" and v) or (type(v) == "number" and v > 0) or (type(v) == "string" and v ~= "")
            if truthy then addRodUnique(k) end
        end
    end

    -- Values under player (BoolValue/NumberValue/StringValue)
    for _, d in ipairs(plr:GetDescendants()) do
        local nm = (d.Name or ""):lower()
        if nm:find("rod") then
            if d:IsA("BoolValue") and d.Value == true then
                addRodUnique(d.Name)
            elseif (d:IsA("IntValue") or d:IsA("NumberValue")) and (d.Value or 0) > 0 then
                addRodUnique(d.Name)
            elseif d:IsA("StringValue") and d.Value and d.Value ~= "" and string.lower(d.Value):find("rod") then
                addRodUnique(d.Value)
            end
        end
    end
end

-- Replion + Items catalog based rods scanning (no GUI)
local function runReplionRods()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local itemsCatalog, idToNameIndex = {}, {}

    local function indexCatalog(tbl)
        if typeof(tbl) ~= "table" then return end
        if tbl.Name then
            local name = tbl.Name
            local cands = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key }
            for _, cid in ipairs(cands) do if cid ~= nil then idToNameIndex[tostring(cid)] = name end end
        end
        for k, v in pairs(tbl) do
            if typeof(k) == "string" and typeof(v) == "table" and v.Name then
                idToNameIndex[k] = v.Name
            end
            indexCatalog(v)
        end
    end

    local function requireItemsCatalog()
        local candidates = {"Items","ItemData","ItemDatabase","ItemCatalog","Catalog","Database"}
        local itemsModule = ReplicatedStorage:FindFirstChild("Items")
        if not itemsModule then
            for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
                if desc:IsA("ModuleScript") then
                    for _, nm in ipairs(candidates) do
                        if string.lower(desc.Name) == string.lower(nm) then itemsModule = desc; break end
                    end
                end
                if itemsModule then break end
            end
        end
        if itemsModule and itemsModule:IsA("ModuleScript") then
            local ok, items = pcall(require, itemsModule)
            if ok and typeof(items) == "table" then itemsCatalog = items; indexCatalog(itemsCatalog) end
        end
    end

    local function getItemNameById(id)
        if not id then return nil end
        return idToNameIndex[tostring(id)]
    end

    local function getReplionClient()
        local parents = { ReplicatedStorage:FindFirstChild("Packages"), ReplicatedStorage:FindFirstChild("Shared"), ReplicatedStorage:FindFirstChild("Modules"), ReplicatedStorage }
        for _, parent in ipairs(parents) do
            if parent then
                local replion = parent:FindFirstChild("Replion")
                if replion and replion:IsA("ModuleScript") then
                    local ok, M = pcall(require, replion)
                    if ok and M and M.Client then return M.Client end
                end
            end
        end
        return nil
    end

    requireItemsCatalog()
    local rodsDetailed, namesSet = {}, {}
    local function add(name, udid, src)
        if not name or name == "" then return end
        if not string.find(string.lower(name), "rod") then return end
        if udid then udid = tostring(udid) end
        table.insert(rodsDetailed, { name = name, udid = udid, src = src })
        namesSet[string.lower(name)] = name
    end

    local Client = getReplionClient()
    if not Client then return {}, {} end
    local replicons = { "Data", "Inventory", "PlayerData", "Profile", "SaveData", "PlayerProfile" }
    local probeKeys = {
        "OwnedItems","OwnedRods","Inventory","InventoryItems","Backpack","Storage","Locker","Bag","Equipped",
        "Rods","FishingRods","RodInventory","RodBag",
        "LockerItems","StorageItems","BagItems","VaultItems","BankItems","WarehouseItems","StashItems"
    }

    local visited = setmetatable({}, {__mode = "k"})
    local visitedCount, maxVisited = 0, 8000

    local function isCatalogPath(path)
        local p = string.lower(path or "")
        if p:find("catalog") or p:find("shop") or p:find("market") then return true end
        if p:find("pages") then return true end
        if p:find("content") and not (p:find("inventory") or p:find("owned") or p:find("backpack") or p:find("storage") or p:find("locker") or p:find("bag")) then return true end
        return false
    end
    local function pathIsOwned(path)
        local p = string.lower(path or "")
        if p:find("owned") or p:find("inventory") or p:find("backpack") or p:find("storage") or p:find("locker") or p:find("bag") or p:find("equip") or p:find("equipment") then return true end
        if p:find("vault") or p:find("bank") or p:find("warehouse") or p:find("stash") or p:find("depot") then return true end
        if p:find("rod") and not isCatalogPath(p) then return true end
        return false
    end

    local function extractUDID(entry)
        local c = { entry and (entry.UDID or entry.Udid or entry.Uuid or entry.UUID or entry.Uid or entry.UID or entry.InstanceId or entry.InstanceID) }
        for _, v in ipairs(c) do if typeof(v) == "string" then return v end end
        return nil
    end

    local function handle(entry, path)
        if typeof(entry) ~= "table" then return end
        if visited[entry] then return end
        visited[entry] = true; visitedCount += 1
        if visitedCount > maxVisited then return end
        if isCatalogPath(path) then return end

        local entryName = entry.Name or entry.ItemName or entry.DisplayName
        local udid = extractUDID(entry)
        local ownedByEntry = (entry.Owned == true or entry.IsOwned == true or entry.Owns == true or entry.Equipped == true or entry.equipped == true or (udid ~= nil))
        local ownedByPath = pathIsOwned(path)
        local owned = ownedByEntry or ownedByPath
        if owned and entryName and string.find(string.lower(entryName), "rod") then
            add(entryName, udid, path)
        end

        if owned then
            -- numeric/string ID maps
            for k, v in pairs(entry) do
                if typeof(k) == "string" or typeof(k) == "number" then
                    local truthy = (typeof(v) == "boolean" and v == true) or (typeof(v) == "number" and v > 0)
                    if truthy then
                        local name = getItemNameById(k)
                        if name and string.find(string.lower(name), "rod") then add(name, tostring(k), path..":kv") end
                    end
                end
            end
            -- arrays of IDs / objects with Id
            local limit = 0
            for _, v in ipairs(entry) do
                if typeof(v) == "string" or typeof(v) == "number" then
                    local name = getItemNameById(v)
                    if name and string.find(string.lower(name), "rod") then add(name, tostring(v), path..":arr") end
                elseif typeof(v) == "table" then
                    local raw = v.Id or v.ID or v.ItemId or v.ItemID
                    if raw ~= nil then
                        local name = getItemNameById(raw)
                        if name and string.find(string.lower(name), "rod") then add(name, tostring(raw), path..":arrobj") end
                    end
                end
                limit = limit + 1; if limit > 300 then break end
            end
        end

        local i = 0
        for k, v in pairs(entry) do i = i + 1; if i > 600 then break end; handle(v, tostring(path)..">"..tostring(k)) end
    end

    for _, r in ipairs(replicons) do
        local rep = Client:WaitReplion(r, 2)
        if rep then
            for _, key in ipairs(probeKeys) do
                local ok, value = pcall(function() return rep:GetExpect(key) end)
                if ok and value ~= nil then handle(value, r..":"..key) end
            end
        end
    end

    local names = {}
    for k, v in pairs(namesSet) do table.insert(names, v) end
    table.sort(names)
    return names, rodsDetailed
end

-- Replion + Catalog based baits scanning (no GUI)
local function runReplionBaits()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local function normalizeKey(s)
        return tostring(s):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    end

    local baitTokens = { "bait","worm","ghost worm","shrimp","squid","maggot","bagel","flakes","minnow","leech","fish head" }
    local function isBaitName(name)
        local n = normalizeKey(name)
        for _, tk in ipairs(baitTokens) do if n:find(tk) then return true end end
        return false
    end

    local baitIdToName, baitNameSet, idToNameIndex = {}, {}, {}

    local function indexTableAsCatalog(tbl, preferBait)
        if typeof(tbl) ~= "table" then return end
        if tbl.Name then
            local name = tbl.Name
            local candidates = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key }
            for _, cid in ipairs(candidates) do
                if cid ~= nil then
                    local sid = tostring(cid)
                    if preferBait then baitIdToName[sid] = name else idToNameIndex[sid] = name end
                end
            end
            if preferBait then baitNameSet[normalizeKey(name)] = true end
        end
        for k, v in pairs(tbl) do
            if typeof(k) == "string" and typeof(v) == "table" and v.Name then
                local sid = tostring(k)
                if preferBait then baitIdToName[sid] = v.Name else idToNameIndex[sid] = v.Name end
                if preferBait then baitNameSet[normalizeKey(v.Name)] = true end
            end
            indexTableAsCatalog(v, preferBait)
        end
    end

    local function requireBaitsCatalog()
        local candidates = {"Baits","BaitData","BaitDatabase","BaitCatalog","BaitsCatalog","BaitsData","BaitsDB"}
        local mod
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc:IsA("ModuleScript") then
                for _, nm in ipairs(candidates) do
                    if string.lower(desc.Name) == string.lower(nm) then mod = desc; break end
                end
            end
            if mod then break end
        end
        if mod then
            local ok, data = pcall(require, mod)
            if ok and typeof(data) == "table" then indexTableAsCatalog(data, true) end
        end
        local folder = ReplicatedStorage:FindFirstChild("Baits")
        if folder and folder:IsA("Folder") then
            for _, inst in ipairs(folder:GetDescendants()) do
                if inst.Name and inst.Name ~= "" then baitNameSet[normalizeKey(inst.Name)] = true end
                local id = inst:GetAttribute("Id") or inst:GetAttribute("ID") or inst:GetAttribute("ItemId")
                if id ~= nil then baitIdToName[tostring(id)] = inst.Name end
            end
        end
    end

    local function requireItemsCatalog()
        local candidates = {"Items","ItemData","ItemDatabase","ItemCatalog","Catalog","Database"}
        local itemsModule = ReplicatedStorage:FindFirstChild("Items")
        if not itemsModule then
            for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
                if desc:IsA("ModuleScript") then
                    for _, nm in ipairs(candidates) do
                        if string.lower(desc.Name) == string.lower(nm) then itemsModule = desc; break end
                    end
                end
                if itemsModule then break end
            end
        end
        if itemsModule and itemsModule:IsA("ModuleScript") then
            local ok, items = pcall(require, itemsModule)
            if ok and typeof(items) == "table" then indexTableAsCatalog(items, false) end
        end
    end

    local function getBaitNameById(id)
        if not id then return nil end
        local sid = tostring(id)
        if baitIdToName[sid] then return baitIdToName[sid] end
        return idToNameIndex[sid]
    end

    local function getReplionClient()
        local parents = { ReplicatedStorage:FindFirstChild("Packages"), ReplicatedStorage:FindFirstChild("Shared"), ReplicatedStorage:FindFirstChild("Modules"), ReplicatedStorage }
        for _, parent in ipairs(parents) do
            if parent then
                local replion = parent:FindFirstChild("Replion")
                if replion and replion:IsA("ModuleScript") then
                    local ok, M = pcall(require, replion)
                    if ok and M and M.Client then return M.Client end
                end
            end
        end
        return nil
    end

    requireBaitsCatalog()
    requireItemsCatalog()

    local nameCounts, baitsDetailed = {}, {}
    local function addBait(name, count, src, id)
        if not name or name == "" then return end
        local nkey = normalizeKey(name)
        if not baitNameSet[nkey] and not isBaitName(name) then return end
        nameCounts[name] = (nameCounts[name] or 0) + (tonumber(count) or 1)
        table.insert(baitsDetailed, { name = name, count = tonumber(count) or 1, src = src, id = id and tostring(id) or nil })
    end

    local Client = getReplionClient()
    if Client then
        local replicons = { "Data", "Inventory", "PlayerData", "Profile", "SaveData", "PlayerProfile" }
        local probeKeys = { "Baits","OwnedBaits","BaitInventory","BaitBag","Bag","Inventory","InventoryItems","Storage","Locker","Consumables","Materials","Items","OwnedItems" }

        local visited = setmetatable({}, {__mode = "k"})
        local visitedCount, maxVisited = 0, 10000
        local function isCatalogPath(path)
            local p = normalizeKey(path or "")
            if p:find("catalog") or p:find("shop") or p:find("market") then return true end
            if p:find("pages") then return true end
            if p:find("content") and not (p:find("inventory") or p:find("owned") or p:find("bag") or p:find("storage") or p:find("locker")) then return true end
            return false
        end
        local function pathIsOwned(path)
            local p = normalizeKey(path or "")
            if p:find("bait") or p:find("owned") or p:find("inventory") or p:find("bag") or p:find("storage") or p:find("locker") then return true end
            if p:find("consumable") or p:find("material") then return true end
            return false
        end
        local function handle(entry, path)
            if typeof(entry) ~= "table" then return end
            if visited[entry] then return end
            visited[entry] = true; visitedCount = visitedCount + 1
            if visitedCount > maxVisited then return end
            if isCatalogPath(path) then return end
            local entryName = entry.Name or entry.ItemName or entry.DisplayName
            local ownedByEntry = (entry.Owned == true or entry.IsOwned == true)
            local ownedByPath = pathIsOwned(path)
            local owned = ownedByEntry or ownedByPath
            if owned and entryName then
                if baitNameSet[normalizeKey(entryName)] or isBaitName(entryName) then addBait(entryName, entry.Count or entry.Amount or 1, path) end
            end
            if owned then
                for k, v in pairs(entry) do
                    if typeof(k) == "string" or typeof(k) == "number" then
                        local count
                        if typeof(v) == "boolean" and v == true then count = 1 end
                        if typeof(v) == "number" and v > 0 then count = v end
                        if count then
                            local name = getBaitNameById(k)
                            if name then addBait(name, count, path..":kv", k) end
                        end
                    end
                end
                local limit = 0
                for _, v in ipairs(entry) do
                    if typeof(v) == "string" or typeof(v) == "number" then
                        local name = getBaitNameById(v)
                        if name then addBait(name, 1, path..":arr", v) end
                    elseif typeof(v) == "table" then
                        local raw = v.Id or v.ID or v.ItemId or v.ItemID
                        local count = v.Count or v.Amount or 1
                        if raw ~= nil then
                            local name = getBaitNameById(raw)
                            if name then addBait(name, count, path..":arrobj", raw) end
                        elseif v.Name then
                            if baitNameSet[normalizeKey(v.Name)] or isBaitName(v.Name) then addBait(v.Name, count, path..":obj") end
                        end
                    end
                    limit = limit + 1; if limit > 300 then break end
                end
            end
            local i = 0
            for k, v in pairs(entry) do i = i + 1; if i > 800 then break end; handle(v, tostring(path)..">"..tostring(k)) end
        end
        for _, r in ipairs(replicons) do
            local rep = Client:WaitReplion(r, 2)
            if rep then
                for _, key in ipairs(probeKeys) do
                    local ok, value = pcall(function() return rep:GetExpect(key) end)
                    if ok and value ~= nil then handle(value, r..":"..key) end
                end
            end
        end
    end

    local names = {}
    for name, cnt in pairs(nameCounts) do if cnt and cnt > 0 then table.insert(names, name) end end
    table.sort(names)
    return names, baitsDetailed
end

local function addBaitUnique(name)
    if not name or name == "" then return end
    if not inventory.baits then inventory.baits = {} end
    if not table.find(inventory.baits, name) then table.insert(inventory.baits, name) end
end

-- Enchant-only scanner (Replion Inventory.Items)
local function scanEnchantOnlyReplion()
    local function isEnchantName(name)
        if not name then return false end
        local n = string.lower(tostring(name)):gsub("%s+"," ")
        return n == "enchant stone" or n == "super enchant stone"
    end

    -- Build id -> name for Enchant items only from ReplicatedStorage.Items
    local idToName = {}
    local function indexTableAsCatalog(tbl)
        if typeof(tbl) ~= "table" then return end
        if tbl.Name then
            local name = tbl.Name
            local cands = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key }
            for _, cid in ipairs(cands) do
                if cid ~= nil and isEnchantName(name) then idToName[tostring(cid)] = name end
            end
        end
        for k, v in pairs(tbl) do
            if typeof(k) == "string" and typeof(v) == "table" and v.Name and isEnchantName(v.Name) then
                idToName[tostring(k)] = v.Name
            end
            indexTableAsCatalog(v)
        end
    end

    local function indexItems()
        local itemsModule = ReplicatedStorage:FindFirstChild("Items")
        if not itemsModule then
            for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
                if desc:IsA("ModuleScript") and string.lower(desc.Name) == "items" then itemsModule = desc; break end
            end
        end
        if itemsModule and itemsModule:IsA("ModuleScript") then
            local ok, data = pcall(require, itemsModule)
            if ok and typeof(data) == "table" then idToName = {}; indexTableAsCatalog(data) end
        end
    end

    local function getReplionClient()
        local parents = { ReplicatedStorage:FindFirstChild("Packages"), ReplicatedStorage:FindFirstChild("Shared"), ReplicatedStorage:FindFirstChild("Modules"), ReplicatedStorage }
        for _, parent in ipairs(parents) do
            if parent then
                local replion = parent:FindFirstChild("Replion")
                if replion and replion:IsA("ModuleScript") then
                    local ok, M = pcall(require, replion)
                    if ok and M and M.Client then return M.Client end
                end
            end
        end
        return nil
    end

    indexItems()
    local counts = { ["Enchant Stone"] = 0, ["Super Enchant Stone"] = 0 }
    local details = {}
    local Client = getReplionClient()
    if not Client then return counts, details end
    local Data = Client:WaitReplion("Data", 2)
    if not Data then return counts, details end
    local ok, inv = pcall(function() return Data:GetExpect({"Inventory"}) end)
    if not ok or inv == nil then return counts, details end
    local items = inv.Items
    if typeof(items) ~= "table" then return counts, details end
    local limit = 0
    for _, entry in ipairs(items) do
        local id = entry and (entry.Id or entry.ID or entry.ItemId or entry.ItemID)
        local qty = entry and (entry.Quantity or entry.Count or entry.Amount or 1) or 1
        local name = id and idToName[tostring(id)] or nil
        if name and isEnchantName(name) then
            local q = tonumber(qty) or 0
            counts[name] = (counts[name] or 0) + q
            table.insert(details, { name = name, count = q, src = "Replion:Data.Inventory.Items", id = id and tostring(id) or nil })
        end
        limit = limit + 1; if limit > 2000 then break end
    end
    return counts, details
end

-- Equipped rod scanner via Replion
local function getEquippedRodNameReplion()
    local function indexItems()
        local idToName = {}
        local function isRodName(n)
            n = string.lower(tostring(n or ""))
            return n:find("rod") ~= nil
        end
        local function walk(tbl)
            if typeof(tbl) ~= "table" then return end
            if tbl.Name and isRodName(tbl.Name) then
                local cands = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.Key }
                for _, cid in ipairs(cands) do if cid ~= nil then idToName[tostring(cid)] = tbl.Name end end
            end
            for k, v in pairs(tbl) do
                if typeof(k) == "string" and typeof(v) == "table" and v.Name and isRodName(v.Name) then idToName[tostring(k)] = v.Name end
                walk(v)
            end
        end
        local mod = ReplicatedStorage:FindFirstChild("Items")
        if not mod then
            for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
                if d:IsA("ModuleScript") and string.lower(d.Name) == "items" then mod = d; break end
            end
        end
        if mod and mod:IsA("ModuleScript") then
            local ok, data = pcall(require, mod)
            if ok and typeof(data) == "table" then walk(data) end
        end
        return idToName
    end

    local function getReplionClient()
        local parents = { ReplicatedStorage:FindFirstChild("Packages"), ReplicatedStorage:FindFirstChild("Shared"), ReplicatedStorage:FindFirstChild("Modules"), ReplicatedStorage }
        for _, parent in ipairs(parents) do
            if parent then
                local replion = parent:FindFirstChild("Replion")
                if replion and replion:IsA("ModuleScript") then
                    local ok, M = pcall(require, replion)
                    if ok and M and M.Client then return M.Client end
                end
            end
        end
        return nil
    end

    local Client = getReplionClient(); if not Client then return nil end
    local Data = Client:WaitReplion("Data", 2); if not Data then return nil end
    local okE, equipped = pcall(function() return Data:GetExpect("EquippedItems") end)
    if not okE or typeof(equipped) ~= "table" or #equipped == 0 then return nil end
    local okI, inv = pcall(function() return Data:GetExpect({"Inventory"}) end)
    if not okI or typeof(inv) ~= "table" then return nil end
    local rods = inv["Fishing Rods"] or inv.Rods or inv.FishingRods
    if typeof(rods) ~= "table" then return nil end
    local map = {}
    for _, entry in ipairs(rods) do
        if typeof(entry) == "table" and entry.UUID then map[tostring(entry.UUID)] = entry end
    end
    local idToName = indexItems()
    for _, uuid in ipairs(equipped) do
        local e = map[tostring(uuid)]
        if e and e.Id then
            local name = idToName[tostring(e.Id)]
            if name and string.lower(name):find("rod") then return name end
        end
    end
    return nil
end

-- Main scan function
local function scanAndSend()
    log("🔍 Scanning player data...")
    
    -- Reset data
    inventory.rods = {}
    inventory.baits = {}
    inventory.time = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Collect data using proven methods
    findLevel()
    findMoney()
    findLocation()
    findInventoryItems()
    findRodsEverywhere()
    local rodsDetailedOut = {}
    local rNames, rDetailed = runReplionRods()
    for _, n in ipairs(rNames) do addRodUnique(n) end
    if rDetailed and #rDetailed > 0 then rodsDetailedOut = rDetailed end
    local baitsDetailedOut = {}
    local bNames, bDetailed = runReplionBaits()
    for _, n in ipairs(bNames) do addBaitUnique(n) end
    if bDetailed and #bDetailed > 0 then baitsDetailedOut = bDetailed end
    -- Prefer Replion-equipped rod; fallback to GUI if not found
    local eq = getEquippedRodNameReplion()
    if eq and eq ~= "" then
        inventory.equippedRod = eq
    else
        findEquippedRod()
    end
    -- Enchant-only counts via Replion (Inventory.Items)
    local enchantCounts, enchantDetails = scanEnchantOnlyReplion()
    -- sanitize: keep only >0 to avoid Super: 0 and Materials: 2 (zero entries)
    local materials = {}
    local materialsDetailed = {}
    for k, v in pairs(enchantCounts) do
        local n = tonumber(v) or 0
        if n > 0 then materials[k] = n end
    end
    for _, d in ipairs(enchantDetails) do
        local n = tonumber(d.count) or 0
        if n > 0 then table.insert(materialsDetailed, d) end
    end
    
    log("   Level:", inventory.level)
    log("   Money:", inventory.coin)
    log("   Location:", inventory.location)
    log("   Equipped Rod:", inventory.equippedRod)
    log("   Found", #inventory.rods, "rods and", #inventory.baits, "baits")
    
    -- Prepare telemetry
    local telemetry = {
        account = (typeof(CFG.account) == "string" and CFG.account ~= "" and CFG.account) or inventory.player.name,
        playerName = inventory.player.name,
        userId = inventory.player.id,
        displayName = inventory.player.displayName,
        money = inventory.coin,
        coins = inventory.coin,
        level = inventory.level,
        equippedRod = inventory.equippedRod,
        location = inventory.location,
        rods = inventory.rods,
        baits = inventory.baits,
        materials = materials,
        materialsDetailed = materialsDetailed,
        rodsDetailed = rodsDetailedOut,
        baitsDetailed = baitsDetailedOut,
        online = true,
        time = inventory.time,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        lastUpdated = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    -- Add machine name to telemetry
    telemetry.machine = CFG.machineName or CFG.machine or CFG.PC or CFG.pc or "Unknown-PC"
    
    -- Add optional attributes from CFG (e.g., key/PC labels)
    local attrs = {}
    if CFG.key then attrs.key = tostring(CFG.key) end
    if CFG.PC or CFG.pc then attrs.pc = tostring(CFG.PC or CFG.pc) end
    if CFG.machineName or CFG.machine then attrs.machine = tostring(CFG.machineName or CFG.machine) end
    if next(attrs) ~= nil then telemetry.attributes = attrs end

    -- Omit fields that are empty/unknown to avoid overwriting good data on the server
    if not telemetry.rods or #telemetry.rods == 0 then telemetry.rods = nil end
    if not telemetry.baits or #telemetry.baits == 0 then telemetry.baits = nil end
    if not telemetry.rodsDetailed or #telemetry.rodsDetailed == 0 then telemetry.rodsDetailed = nil end
    if not telemetry.baitsDetailed or #telemetry.baitsDetailed == 0 then telemetry.baitsDetailed = nil end
    if not telemetry.materials or (type(telemetry.materials) == "table" and next(telemetry.materials) == nil) then telemetry.materials = nil end
    if not telemetry.materialsDetailed or #telemetry.materialsDetailed == 0 then telemetry.materialsDetailed = nil end
    if not telemetry.equippedRod or telemetry.equippedRod == "" or telemetry.equippedRod == "None" then telemetry.equippedRod = nil end
    if not telemetry.location or telemetry.location == "" or telemetry.location == "Unknown" then telemetry.location = nil end
    
    -- Send to server
    sendTelemetry(telemetry)
end

-- Auto-send loop (every 5 seconds)
spawn(function()
    while true do
        pcall(scanAndSend)
        wait(5)
    end
end)
