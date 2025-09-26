-- FishIs Complete Inventory - อ่านข้อมูลครบถ้วน รวม coins จาก PlayerGui
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"
-- Send telemetry to your local/remote web dashboard
-- Change this if your Node server runs elsewhere
local TELEMETRY_URL = "http://127.0.0.1:3001/telemetry"

local plr = Players.LocalPlayer
if not plr then
    warn("❌ No LocalPlayer")
    return
end

-- Send telemetry data to the web dashboard (Node server)
local function sendTelemetryToServer(payload)
    local body = HttpService:JSONEncode(payload)
    local headers = { ["Content-Type"] = "application/json" }
    if typeof(request) == "function" then
        local ok = pcall(function()
            request({ Url = TELEMETRY_URL, Method = "POST", Headers = headers, Body = body })
        end)
        return ok
    elseif typeof(http) == "table" and typeof(http.request) == "function" then
        local ok = pcall(function()
            http.request({ Url = TELEMETRY_URL, Method = "POST", Headers = headers, Body = body })
        end)
        return ok
    else
        local ok = pcall(function()
            HttpService:PostAsync(TELEMETRY_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        return ok
    end
end

-- Materials field will be added later when building the Discord embed

-- ===== DEBUG SWITCH =====
local DEBUG = true
local function dprint(...)
    if DEBUG then
        print("[DBG]", ...)
    end
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

dprint("🎒 FishIs Complete Inventory starting...")

-- ===== LOAD CATALOGS =====
local itemsCatalog = {}
local baitsCatalog = {}
local guidNameIndexBoot = {}
local idToNameIndex = {}
local nameToTypeIndex = {}
local nameToIdsIndex = {}

-- Load Items catalog
local itemsModule = ReplicatedStorage:FindFirstChild("Items")
if itemsModule and itemsModule:IsA("ModuleScript") then
    local ok, items = pcall(require, itemsModule)
    if ok and typeof(items) == "table" then
        itemsCatalog = items
        dprint("✅ Loaded Items catalog")
    end
end

-- Load Baits catalog  
local baitsModule = ReplicatedStorage:FindFirstChild("Baits")
if baitsModule and baitsModule:IsA("ModuleScript") then
    local ok, baits = pcall(require, baitsModule)
    if ok and typeof(baits) == "table" then
        baitsCatalog = baits
        dprint("✅ Loaded Baits catalog")
    end
end

-- Build reverse indices from Items catalog to map IDs/GUIDs -> Names
local function indexCatalog(tbl)
    if typeof(tbl) ~= "table" then return end
    -- If table itself looks like an item
    if tbl.Name then
        local candidates = {
            tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key
        }
        for _, cid in ipairs(candidates) do
            if cid ~= nil then
                local key = tostring(cid)
                idToNameIndex[key] = tbl.Name
                if typeof(cid) == "string" and key:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
                    guidNameIndexBoot[key] = tbl.Name
                end
                local nlower = (tbl.Name):lower()
                nameToIdsIndex[nlower] = nameToIdsIndex[nlower] or {}
                nameToIdsIndex[nlower][key] = true
            end
        end
        -- record type/category for name classification
        local t = tbl.Type or tbl.Category or tbl.kind or tbl.ItemType or tbl.itemType
        if typeof(t) == "string" then
            nameToTypeIndex[(tbl.Name):lower()] = t:lower()
        end
    end
    for k, v in pairs(tbl) do
        -- If key itself is a GUID and value has a Name
        if typeof(k) == "string" and typeof(v) == "table" and v.Name and k:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
            guidNameIndexBoot[k] = v.Name
            idToNameIndex[k] = v.Name
            local nlower = (v.Name):lower()
            nameToIdsIndex[nlower] = nameToIdsIndex[nlower] or {}
            nameToIdsIndex[nlower][k] = true
        end
        indexCatalog(v)
    end
end

indexCatalog(itemsCatalog)

-- ===== COLLECT PLAYER DATA =====
local inventory = {
    player = { name = plr.Name, id = plr.UserId, displayName = plr.DisplayName },
    time = os.date("%Y-%m-%d %H:%M:%S"),
    coin = 0,
    level = nil,  -- Changed from 0 to nil so it can be properly set
    stats = {},
    attributes = {},
    rods = {},
    baits = {},
    items = {},
    materials = {},
    enchants = {},
    rodsDetailed = {}
}

-- Get leaderstats
local ls = plr:FindFirstChild("leaderstats")
if ls then
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("ValueBase") then
            local ok, val = pcall(function() return v.Value end)
            if ok then
                inventory.stats[v.Name] = val
                if string.find(string.lower(v.Name), "level") or string.find(string.lower(v.Name), "lvl") then
                    inventory.level = val
                end
            end
        end
    end
end

-- Get player attributes
for k, v in pairs(plr:GetAttributes()) do
    inventory.attributes[k] = v
end

-- Helper function to parse coin values with M/K suffixes
local function parseCoinValue(text)
    if not text then return 0 end
    
    -- Handle formats like "2.29M", "1.5K", "1,234", "1234"
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

-- ===== FIND LEVEL & XP =====
local function findLevelAndXP()
    dprint("🎮 Searching for level and XP...")
    
    -- Try Replion system first (most accurate) - Fixed version
    local function tryReplion()
        dprint("🔍 Searching for Replion data...")
        
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
                    dprint("📦 Found Replion at:", replion:GetFullName())
                    
                    local ok, Client = pcall(require, replion)
                    if ok and Client and Client.Client then
                        dprint("✅ Successfully loaded Replion Client")
                        
                        -- Try to get Data replion
                        local dataReplion = Client.Client:WaitReplion("Data", 5)
                        if dataReplion then
                            dprint("🎯 Found Data replion!")
                            
                            -- Get Level
                            local level = dataReplion:GetExpect("Level")
                            if level then
                                inventory.level = level
                                dprint("📊 Level:", level)
                            end
                            
                            -- Skip XP (not needed)
                            
                            -- Successfully found Level from Replion
                            
                            return {level = level, replion = dataReplion}
                        else
                            dprint("❌ Could not find Data replion")
                        end
                    else
                        dprint("❌ Failed to load Replion Client")
                    end
                end
            end
        end
        
        return nil
    end
    
    -- Try GUI method as fallback
    local function tryGUI()
        local pg = plr:WaitForChild("PlayerGui")
        local xpGui = pg:FindFirstChild("XP")
        if xpGui then
            local frame = xpGui:FindFirstChild("Frame")
            if frame then
                local levelCount = frame:FindFirstChild("LevelCount")
                if levelCount and levelCount:IsA("TextLabel") then
                    local text = levelCount.Text
                    print("📊 Level display text:", text)
                    
                    local levelNum = text:match("Lvl (%d+)")
                    if levelNum then
                        inventory.level = tonumber(levelNum)
                        print("📊 Level from GUI:", inventory.level)
                        return true
                    end
                end
            end
        end
        return false
    end
    
    -- Try leaderstats as last resort
    local function tryLeaderstats()
        local leaderstats = plr:FindFirstChild("leaderstats")
        if leaderstats then
            print("🎯 Found leaderstats:", leaderstats:GetFullName())
            for _, stat in ipairs(leaderstats:GetChildren()) do
                if stat:IsA("ValueBase") then
                    local name = stat.Name:lower()
                    local value = stat.Value
                    print("📊", stat.Name .. ":", value)
                    
                    if name:match("level") or name:match("lvl") then
                        inventory.level = value
                        return true
                    end
                end
            end
        end
        return false
    end
    
    -- Try methods in order of reliability
    local replionData = tryReplion()
    if not replionData then
        if not tryGUI() then
            tryLeaderstats()
        end
    end
    
    -- Try player attributes for additional stats
    local attrs = plr:GetAttributes()
    for k, v in pairs(attrs) do
        local name = k:lower()
        if typeof(v) == "number" and v > 0 then
            print("📊 Player attribute", k .. ":", v)
            if name:match("level") or name:match("lvl") and not inventory.level then
                inventory.level = v
            elseif name:match("money") or name:match("coin") or name:match("cash") and not inventory.coin then
                inventory.coin = v
            end
        end
    end
end

-- ===== FIND COINS =====
local function findCoins()
    dprint("💰 Searching for coins...")
    
    local pg = plr:WaitForChild("PlayerGui")
    
    -- Try multiple known money display locations
    local moneyPaths = {
        {"Boat Shop", "Main", "Content", "Top", "CurrencyCounterFrame", "CurrencyFrame", "Counter"},
        {"Rod Shop", "Main", "Content", "Top", "CurrencyCounterFrame", "CurrencyFrame", "Counter"},
        {"Bait Shop", "Main", "Content", "Top", "CurrencyCounterFrame", "CurrencyFrame", "Counter"},
        {"Events", "Frame", "CurrencyCounter", "Counter"},
        {"!!! Starter Pack", "Center", "StarterPack", "RewardsList", "Coins"}
    }
    
    for _, path in ipairs(moneyPaths) do
        local current = pg
        local pathStr = "PlayerGui"
        
        -- Navigate through the path
        for i, segment in ipairs(path) do
            current = current:FindFirstChild(segment)
            pathStr = pathStr .. "." .. segment
            if not current then break end
        end
        
        if current then
            dprint("🎯 Found money element:", pathStr)
            
            -- Check attributes FIRST (most reliable)
            local attrs = current:GetAttributes()
            for k, v in pairs(attrs) do
                if typeof(v) == "number" and v > 0 then
                    inventory.coin = v
                    dprint("💰 Coins from attribute", k .. ":", inventory.coin)
                    return
                elseif typeof(v) == "string" then
                    local parsed = parseCoinValue(v)
                    if parsed > 0 then
                        inventory.coin = parsed
                        dprint("💰 Coins from string attribute", k .. ":", v, "=", inventory.coin)
                        return
                    end
                end
            end
            
            -- Check if it's a TextLabel with money value
            if current:IsA("TextLabel") then
                local text = current.Text
                local parsed = parseCoinValue(text)
                if parsed > 0 then
                    inventory.coin = parsed
                    dprint("💰 Coins from TextLabel:", text, "=", inventory.coin)
                    return
                end
            end
            
            -- Check ValueBase children
            for _, child in ipairs(current:GetChildren()) do
                if child:IsA("ValueBase") then
                    local ok, val = pcall(function() return child.Value end)
                    if ok and typeof(val) == "number" and val > 0 then
                        inventory.coin = val
                        dprint("💰 Coins from ValueBase:", inventory.coin)
                        return
                    end
                end
            end
            
            -- Check children TextLabels
            for _, child in ipairs(current:GetChildren()) do
                if child:IsA("TextLabel") then
                    local text = child.Text
                    local parsed = parseCoinValue(text)
                    if parsed > 0 then
                        inventory.coin = parsed
                        dprint("💰 Coins from child TextLabel:", text, "=", inventory.coin)
                        return
                    end
                end
            end
        end
    end
    
    -- Fallback: search all GUI for "coins" or large numbers
    local function searchGuiForCoins(element, path, depth)
        if not element or depth > 4 then return end
        
        local name = string.lower(element.Name)
        if string.find(name, "coin") then
            print("🔍 Found coins-related element:", element:GetFullName())
            
            if element:IsA("TextLabel") then
                local text = element.Text
                local coinValue = string.match(text, "%d+[%d,]*")
                if coinValue then
                    local cleanValue = coinValue:gsub(",", "")
                    local num = tonumber(cleanValue)
                    if num and num > inventory.coin then
                        inventory.coin = num
                        print("💰 Coins from GUI search:", inventory.coin)
                    end
                end
            end
        end
        
        for _, child in ipairs(element:GetChildren()) do
            searchGuiForCoins(child, path .. "." .. child.Name, depth + 1)
        end
    end
    
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            searchGuiForCoins(gui, "PlayerGui." .. gui.Name, 0)
        end
    end
end

findCoins()

-- ===== FIND INVENTORY ITEMS =====
local function findInventoryItems()
    dprint("🎒 Searching for inventory items (rods & baits)...")
    local pg = plr:WaitForChild("PlayerGui")
    local rodSet = {}
    local baitSet = {}
    local enchantSet = {}
    local guidNameIndex = {}
    local ownedIds = {}
    local ownedNames = {}
    local dbg = {ownedAdds = 0, guiAdds = 0, guiSkips = 0}

    local function normalizeKey(s)
        return tostring(s):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    end

    local function addUnique(list, set, value, tag)
        if not value or value == "" then return end
        local key = normalizeKey(value)
        if not set[key] then
            set[key] = true
            table.insert(list, value)
            if tag then dprint(tag, value) end
        end
    end

    -- Ignore generic UI texts like 'Rods' or 'Notification'
    local function shouldIgnoreRodText(txt)
        if not txt then return true end
        local s = normalizeKey(txt)
        if s == "" then return true end
        -- GUID-like strings (8-4-4-4-12 hex)
        if s:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then return true end
        -- Ignore very short or numeric-only strings
        if #s < 3 then return true end
        if tonumber(s) ~= nil then return true end
        -- Exact tab/header words
        if s == "rod" or s == "rods" then return true end
        -- Any kind of notification label
        if s:find("notification") or s:find("notif") or s:find("notify") then return true end
        -- Common UI noise words
        if s:find("equipped") or s == "equip" then return true end
        if s == "close" or s == "back" or s == "page" or s == "pages" or s == "tab" then return true end
        return false
    end

    local function isRodName(name)
        if not name or name == "" then return false end
        local n = normalizeKey(name)
        if n:find("rod") then return true end
        local t = nameToTypeIndex[n]
        if t and t == "rod" then return true end
        return false
    end

    local function safeAddRodName(name, tag)
        if shouldIgnoreRodText(name) then return end
        if not isRodName(name) then return end
        addUnique(inventory.rods, rodSet, name, tag)
    end

    local function safeAddEnchant(name)
        if not name or name == "" then return end
        local s = normalizeKey(name)
        if s:find("enchant") or s:find("luck") or s:find("speed") or s:find("power") then
            addUnique(inventory.enchants, enchantSet, name)
        end
    end

    local function addMaterialQuantity(name, qty)
        if not name or not qty or qty <= 0 then return end
        local n = normalizeKey(name)
        -- Track ONLY Enchant Stone variants (avoid counting 'Enchanted Angelfish' etc.)
        if (n:find("super") and (n:find("enchant stone") or n:find("enchantstone"))) then
            local cur = inventory.materials["Super Enchant Stone"] or 0
            inventory.materials["Super Enchant Stone"] = cur + qty
        elseif (n:find("enchant stone") or n:find("enchantstone")) then
            local cur = inventory.materials["Enchant Stone"] or 0
            inventory.materials["Enchant Stone"] = cur + qty
        end
    end

    local function extractUDID(entry)
        local function isGuidLike(s)
            if typeof(s) ~= "string" then return false end
            return s:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
        end
        local candidates = {
            entry.UDID, entry.Udid, entry.Uuid, entry.UUID, entry.Guid, entry.GUID,
            entry.Uid, entry.UID, entry.InstanceId, entry.InstanceID, entry.HandleId, entry.HandleID,
            entry.Key
        }
        for _, v in ipairs(candidates) do
            if isGuidLike(v) then return v end
        end
        -- try nested GUID-like strings
        for k, v in pairs(entry) do
            if isGuidLike(v) then return v end
        end
        return nil
    end

    local ownedUDIDs = {}
    local function addOwnedRod(name, udid, tag)
        if not name then return end
        if not isRodName(name) then return end
        if udid then
            if ownedUDIDs[udid] then return end
            ownedUDIDs[udid] = true
        end
        table.insert(inventory.rodsDetailed, { name = name, udid = udid })
        safeAddRodName(name, tag)
        dbg.ownedAdds += 1
        dprint("ADD ROD:", name, "udid=", udid and (udid:sub(1,8).."..") or "nil", "src=", tag)
    end

    local function isRodItemData(data)
        if typeof(data) ~= "table" then return false end
        local t = (data.Type or data.Category or data.kind or data.ItemType or data.itemType)
        if typeof(t) == "string" then
            return t:lower():find("rod") ~= nil
        end
        return false
    end

    local function getItemNameById(id)
        if not id then return nil end
        local keyNum = tonumber(id)
        local candidates = {}
        -- Use prebuilt indices first
        local byIdx = idToNameIndex[tostring(id)]
        if byIdx then return byIdx end
        -- Prefer GUID mapping if available
        -- Prefer GUID mapping if available
        if typeof(id) == "string" and guidNameIndex[id] then
            return guidNameIndex[id]
        end
        if typeof(id) == "string" and guidNameIndexBoot[id] then
            return guidNameIndexBoot[id]
        end
        -- itemsCatalog may be keyed numerically or by string keys; search both
        if itemsCatalog then
            local byKey = itemsCatalog[id] or (keyNum and itemsCatalog[keyNum]) or nil
            if byKey and typeof(byKey) == "table" and byKey.Name then
                return byKey.Name
            end
            for k, v in pairs(itemsCatalog) do
                if typeof(v) == "table" then
                    if v.Id == id or v.ID == id or v.ItemId == id or v.ItemID == id or v.Id == keyNum then
                        return v.Name or tostring(id)
                    end
                    if isRodItemData(v) and v.Name then
                        table.insert(candidates, v.Name)
                    end
                end
            end
        end
        return nil
    end

    -- 0) Specific Inventory GUI path (per user):
    --    PlayerGui.Inventory.Main.Content.Pages.Rods
    --    PlayerGui.Inventory.Main.Top
    local function collectFromSpecifiedInventoryGUI()
        local inv = pg:FindFirstChild("Inventory")
        if not inv then return end
        local main = inv:FindFirstChild("Main")
        if not main then return end

        -- Read Main.Top for equipped/selected rod name if present
        local top = main:FindFirstChild("Top")
        if top then
            for _, d in ipairs(top:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local t = d.Text
                    if t and #t > 0 then
                        -- Heuristic: look for 'Equipped' or explicit rod-looking names
                        local equipped = t:match("[Ee]quipped[:%-]?%s*(.+)")
                        if equipped and #equipped > 0 and not equipped:find("Shop") then
                            -- Save equipped rod separately; do not add to rods list to avoid duplicates
                            inventory.equippedRod = equipped:gsub("^%s+", ""):gsub("%s+$", "")
                            dprint("🎣 Equipped Rod:", inventory.equippedRod)
                        end
                    end
                end
            end
        end

        -- Also try Backpack.Display.* as a source for the equipped rod
        local backpack = pg:FindFirstChild("Backpack")
        if backpack then
            local display = backpack:FindFirstChild("Display")
            if display then
                -- Try text-based detection like "Rod: NAME" or "Equipped: NAME"
                for _, d in ipairs(display:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        local t = d.Text
                        if t and #t > 0 then
                            local m = t:match("[Rr]od[:%-]?%s*(.+)") or t:match("[Ee]quipped[:%-]?%s*(.+)")
                            if m and m ~= "" then
                                local name = m:gsub("^%s+", ""):gsub("%s+$", "")
                                if isRodName(name) or name:lower():find("rod") then
                                    if not inventory.equippedRod or inventory.equippedRod == "" then
                                        inventory.equippedRod = name
                                        dprint("🎯 Equipped Rod (Backpack.Display Text):", name)
                                    end
                                end
                            elseif isRodName(t) and (not inventory.equippedRod or inventory.equippedRod == "") then
                                inventory.equippedRod = t
                                dprint("🎯 Equipped Rod (Backpack.Display Label):", t)
                            end
                            -- Try to parse stone counts only from labels explicitly mentioning Enchant Stone
                            local tl = t:lower()
                            if (tl:find("super") and (tl:find("enchant stone") or tl:find("enchantstone"))) then
                                local num = tonumber(t:match("x%s*(%d+)%s*$")) or tonumber(t:match("(%d+)%s*$")) or tonumber(t:match("(%d+)") )
                                if num and num > 0 then
                                    local cur = inventory.materials["Super Enchant Stone"] or 0
                                    if num > cur then
                                        inventory.materials["Super Enchant Stone"] = num
                                        dprint("🪨 Super Enchant Stone (GUI parsed):", num)
                                    end
                                end
                            elseif (tl:find("enchant stone") or tl:find("enchantstone")) then
                                local num = tonumber(t:match("x%s*(%d+)%s*$")) or tonumber(t:match("(%d+)%s*$")) or tonumber(t:match("(%d+)") )
                                if num and num > 0 then
                                    local cur = inventory.materials["Enchant Stone"] or 0
                                    if num > cur then
                                        inventory.materials["Enchant Stone"] = num
                                        dprint("🪨 Enchant Stone (GUI parsed):", num)
                                    end
                                end
                            end
                        end
                    end
                end

                -- Look for a selected/Equipped item under Display.Rods
                local rodsFolder = display:FindFirstChild("Rods")
                if rodsFolder and (not inventory.equippedRod or inventory.equippedRod == "") then
                    local found = false
                    for _, item in ipairs(rodsFolder:GetDescendants()) do
                        if item:IsA("TextLabel") or item:IsA("TextButton") then
                            local txt = item.Text
                            if txt and isRodName(txt) then
                                local selected = item:GetAttribute("Equipped") == true or item:GetAttribute("Selected") == true or item:GetAttribute("IsSelected") == true
                                if not selected then
                                    local sel = item:FindFirstChild("Equipped") or item:FindFirstChild("Selected") or item:FindFirstChild("Check") or item:FindFirstChild("Checkmark")
                                    if sel and sel.Visible == true then selected = true end
                                end
                                if selected then
                                    inventory.equippedRod = txt
                                    dprint("🎯 Equipped Rod (Backpack.Display.Rods):", txt)
                                    found = true
                                    break
                                end
                            end
                        end
                    end
                    if not found then
                        local candidate = nil
                        for _, item in ipairs(rodsFolder:GetDescendants()) do
                            if item:IsA("TextLabel") or item:IsA("TextButton") then
                                local txt = item.Text
                                if txt and isRodName(txt) then
                                    if candidate and candidate ~= txt then candidate = nil; break end
                                    candidate = txt
                                end
                            end
                        end
                        if candidate and (not inventory.equippedRod or inventory.equippedRod == "") then
                            inventory.equippedRod = candidate
                            dprint("🎯 Equipped Rod (Backpack.Display.Rods single):", candidate)
                        end
                    end
                end
            end
        end

        -- Read Main.Content.Pages.Rods for all owned rods
        local content = main:FindFirstChild("Content")
        if not content then return end
        local pages = content:FindFirstChild("Pages")
        if not pages then return end
        local rodsPage = pages:FindFirstChild("Rods")
        if not rodsPage then return end

        dprint("📦 Found Inventory Rods container:", rodsPage:GetFullName())

        local function scanRods(element, depth)
            if not element or depth > 6 then return end
            local n = element.Name and element.Name:lower() or ""
            if n:find("notification") or n:find("notif") then return end
            -- Attribute-based match
            local atype = element:GetAttribute("Type") or element:GetAttribute("ItemType")
            local aname = element:GetAttribute("Name") or element:GetAttribute("DisplayName") or element:GetAttribute("ItemName")
            local idAttr = element:GetAttribute("Id") or element:GetAttribute("ID") or element:GetAttribute("ItemId") or element:GetAttribute("ItemID")
            if typeof(atype) == "string" and atype:lower():find("rod") then
                if aname and aname ~= "" then
                    safeAddRodName(tostring(aname), "🎣 Rod (Inv Attr):")
                end
                if idAttr then
                    local nm = getItemNameById(idAttr)
                    if nm then safeAddRodName(nm, "🎣 Rod (Inv Attr ID->Catalog):") end
                end
            end

            -- Child labels commonly named Name/ItemName/Title/DisplayName
            if element:IsA("TextLabel") then
                local lower = element.Name:lower()
                if lower == "name" or lower == "itemname" or lower == "title" or lower == "displayname" then
                    local txt = element.Text
                    if txt and #txt > 0 then
                        safeAddRodName(txt, "🎣 Rod (Inv GUI):")
                    end
                end
            end

            for _, ch in ipairs(element:GetChildren()) do
                scanRods(ch, depth + 1)
            end
        end

        -- Direct child frames pass
        for _, item in ipairs(rodsPage:GetChildren()) do
            if item:IsA("Frame") or item:IsA("ImageButton") or item:IsA("TextButton") then
                local nameLabel = item:FindFirstChild("Name") or item:FindFirstChild("ItemName") or item:FindFirstChild("Title") or item:FindFirstChild("DisplayName")
                if nameLabel and nameLabel:IsA("TextLabel") then
                    local txt = nameLabel.Text
                    if txt and txt ~= "" then
                        safeAddRodName(txt, "🎣 Rod (Inv Name):")
                    end
                end
                local idLabel = item:FindFirstChild("ID") or item:FindFirstChild("Id") or item:FindFirstChild("ItemId")
                if idLabel and idLabel:IsA("TextLabel") then
                    local id = idLabel.Text and idLabel.Text:match("(%d+)")
                    if id then
                        local nm = getItemNameById(id)
                        if nm then safeAddRodName(nm, "🎣 Rod (Inv ID->Catalog):") end
                    end
                end
            end
        end

        -- Deep scan under rodsPage
        scanRods(rodsPage, 0)

        dprint(string.format("✅ Inventory Rods via specified path. Total: %d", #inventory.rods))
    end

    -- Run specified path collector first as requested
    collectFromSpecifiedInventoryGUI()

    -- 1) GUI scan (improved, less strict)
    local searchGuis = {"Backpack", "Inventory", "InventoryGui", "Bag", "BagGui", "Items", "MainGui"}
    local function extractFromGUI(element, depth)
        if not element or depth > 8 then return end
        local n = element.Name and element.Name:lower() or ""
        if n:find("notification") or n:find("notif") then return end
        if element:IsA("TextLabel") or element:IsA("TextButton") then
            local text = element.Text
            if text and #text > 0 then
                -- Basic heuristic: contains 'Rod' but avoid shop headers
                if text:find("Rod") and not text:find("Shop") then
                    local key = normalizeKey(text)
                    if ownedNames[key] or (nameToIdsIndex[key] and (function()
                        for idk,_ in pairs(nameToIdsIndex[key]) do if ownedIds[idk] then return true end end
                        return false
                    end)()) or (inventory.equippedRod and normalizeKey(inventory.equippedRod)==key) then
                        safeAddRodName(text, "🎣 Rod (GUI):")
                        dbg.guiAdds += 1
                        dprint("GUI ADD Rod:", text)
                    else
                        dbg.guiSkips += 1
                        dprint("GUI SKIP Rod (not owned):", text)
                    end
                elseif text:find("Bait") and not text:find("Shop") then
                    addUnique(inventory.baits, baitSet, text, "🪱 Bait (GUI):")
                end
                -- Parse "ID:123" to map to catalog
                local id = text:match("ID:?%s*(%d+)")
                if id then
                    local name = getItemNameById(id)
                    if name then safeAddRodName(name, "🎣 Rod (ID->Catalog):") end
                end
            end
        end
        -- Attribute-based hints (only accept if owned)
        local attrType = element:GetAttribute("Type") or element:GetAttribute("ItemType")
        if typeof(attrType) == "string" and attrType:lower():find("rod") then
            local label = element:GetAttribute("DisplayName") or element.Name
            local n = tostring(label)
            local key = normalizeKey(n)
            if ownedNames[key] or (inventory.equippedRod and normalizeKey(inventory.equippedRod) == key) then
                safeAddRodName(n, "🎣 Rod (Attr GUI):")
            end
        end
        for _, child in ipairs(element:GetChildren()) do
            extractFromGUI(child, depth + 1)
        end
    end
    -- Aggregate owned rod instances into name × count summary
    if #inventory.rodsDetailed > 0 then
        local counts = {}
        for _, inst in ipairs(inventory.rodsDetailed) do
            counts[inst.name] = (counts[inst.name] or 0) + 1
        end
        inventory.rods = {}
        for name, cnt in pairs(counts) do
            table.insert(inventory.rods, string.format("%s × %d", name, cnt))
        end
        table.sort(inventory.rods)
        dprint(string.format("Owned instances=%d, distinct rods=%d, guiAdds=%d, guiSkips=%d", #inventory.rodsDetailed, #inventory.rods, dbg.guiAdds, dbg.guiSkips))
    end

    -- Only fallback to generic GUI scan if we still have nothing from Replion/spec path
    if #inventory.rodsDetailed == 0 and #inventory.rods == 0 then
        for _, guiName in ipairs(searchGuis) do
            local gui = pg:FindFirstChild(guiName)
            if gui then
                dprint("🔍 Scanning GUI:", guiName)
                extractFromGUI(gui, 0)
            end
        end
    end

    -- 2) Player Backpack/Character tools
    local function collectFromTools(container, where)
        if not container then return end
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Tool") or obj:IsA("Model") then
                local n = obj.Name or ""
                if n:find("Rod") then
                    safeAddRodName(n, "🎣 Rod ("..where.."):")
                    -- If rod is in Character, it is likely the currently equipped rod
                    if where == "Character" and (not inventory.equippedRod or inventory.equippedRod == "") then
                        inventory.equippedRod = n
                        dprint("🎯 Equipped Rod (Character):", n)
                    end
                end
            end
        end
    end
    collectFromTools(plr:FindFirstChild("Backpack"), "Backpack")
    collectFromTools(plr.Character, "Character")

    -- 2.5) Collect enchants and materials from actual player inventory (not shop)
    local function collectUIEnchantInfo()
        -- Panel -> Tags.Enchant (for enchant names)
        local panel = pg:FindFirstChild("Panel")
        if panel then
            local ok = pcall(function()
                local tags = panel.Frame.Content.Right.Items.Scrolling.Tile.Inner.Tags.Enchant
                if tags then
                    for _, d in ipairs(tags:GetDescendants()) do
                        if d:IsA("TextLabel") then
                            local t = d.Text
                            if t and #t > 0 then safeAddEnchant(t) end
                        end
                    end
                end
            end)
            if not ok then dprint("Panel enchant tags path not available yet") end
        end

        -- Backpack inventory for materials (actual owned items)
        local backpack = pg:FindFirstChild("Backpack")
        if backpack then
            dprint("🎒 Scanning Backpack for materials...")
            local function scanBackpackForMaterials(container)
                if not container then return end
                for _, d in ipairs(container:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        local t = d.Text or ""
                        if #t > 0 then
                            local tl = t:lower()
                            -- Look for enchant stone quantities in actual inventory
                            if (tl:find("enchant stone") or tl:find("enchantstone")) and not tl:find("buy") and not tl:find("shop") and not tl:find("cost") then
                                local num = tonumber(t:match("x%s*(%d+)")) or tonumber(t:match("(%d+)%s*x")) or tonumber(t:match("(%d+)"))
                                if num and num > 0 then
                                    local cur = inventory.materials["Enchant Stone"] or 0
                                    if num > cur then
                                        inventory.materials["Enchant Stone"] = num
                                        dprint("🪨 Enchant Stone (Backpack inventory):", num, "from text:", t)
                                    end
                                end
                            elseif (tl:find("super") and (tl:find("enchant stone") or tl:find("enchantstone"))) and not tl:find("buy") and not tl:find("shop") and not tl:find("cost") then
                                local num = tonumber(t:match("x%s*(%d+)")) or tonumber(t:match("(%d+)%s*x")) or tonumber(t:match("(%d+)"))
                                if num and num > 0 then
                                    local cur = inventory.materials["Super Enchant Stone"] or 0
                                    if num > cur then
                                        inventory.materials["Super Enchant Stone"] = num
                                        dprint("🪨 Super Enchant Stone (Backpack inventory):", num, "from text:", t)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- Scan common backpack paths
            scanBackpackForMaterials(backpack:FindFirstChild("Display"))
            scanBackpackForMaterials(backpack:FindFirstChild("Frame"))
            scanBackpackForMaterials(backpack:FindFirstChild("Main"))
            scanBackpackForMaterials(backpack) -- scan root too
        end

        -- Inventory GUI (if different from Backpack)
        local inventory_gui = pg:FindFirstChild("Inventory")
        if inventory_gui then
            dprint("📦 Scanning Inventory GUI for materials...")
            for _, d in ipairs(inventory_gui:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local t = d.Text or ""
                    if #t > 0 then
                        local tl = t:lower()
                        if (tl:find("enchant stone") or tl:find("enchantstone")) and not tl:find("buy") and not tl:find("shop") and not tl:find("cost") then
                            local num = tonumber(t:match("x%s*(%d+)")) or tonumber(t:match("(%d+)%s*x")) or tonumber(t:match("(%d+)"))
                            if num and num > 0 then
                                local cur = inventory.materials["Enchant Stone"] or 0
                                if num > cur then
                                    inventory.materials["Enchant Stone"] = num
                                    dprint("🪨 Enchant Stone (Inventory GUI):", num, "from text:", t)
                                end
                            end
                        elseif (tl:find("super") and (tl:find("enchant stone") or tl:find("enchantstone"))) and not tl:find("buy") and not tl:find("shop") and not tl:find("cost") then
                            local num = tonumber(t:match("x%s*(%d+)")) or tonumber(t:match("(%d+)%s*x")) or tonumber(t:match("(%d+)"))
                            if num and num > 0 then
                                local cur = inventory.materials["Super Enchant Stone"] or 0
                                if num > cur then
                                    inventory.materials["Super Enchant Stone"] = num
                                    dprint("🪨 Super Enchant Stone (Inventory GUI):", num, "from text:", t)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Materials/Items GUI (if exists)
        local materials_gui = pg:FindFirstChild("Materials") or pg:FindFirstChild("Items")
        if materials_gui then
            dprint("🧱 Scanning Materials GUI for stones...")
            for _, d in ipairs(materials_gui:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local t = d.Text or ""
                    if #t > 0 then
                        local tl = t:lower()
                        if (tl:find("enchant stone") or tl:find("enchantstone")) and not tl:find("buy") and not tl:find("shop") and not tl:find("cost") then
                            local num = tonumber(t:match("x%s*(%d+)")) or tonumber(t:match("(%d+)%s*x")) or tonumber(t:match("(%d+)"))
                            if num and num > 0 then
                                local cur = inventory.materials["Enchant Stone"] or 0
                                if num > cur then
                                    inventory.materials["Enchant Stone"] = num
                                    dprint("🪨 Enchant Stone (Materials GUI):", num, "from text:", t)
                                end
                            end
                        elseif (tl:find("super") and (tl:find("enchant stone") or tl:find("enchantstone"))) and not tl:find("buy") and not tl:find("shop") and not tl:find("cost") then
                            local num = tonumber(t:match("x%s*(%d+)")) or tonumber(t:match("(%d+)%s*x")) or tonumber(t:match("(%d+)"))
                            if num and num > 0 then
                                local cur = inventory.materials["Super Enchant Stone"] or 0
                                if num > cur then
                                    inventory.materials["Super Enchant Stone"] = num
                                    dprint("🪨 Super Enchant Stone (Materials GUI):", num, "from text:", t)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 3) Replion Data (if available) - enhanced to work without opening GUI
    local function collectFromReplion()
        local parents = {
            ReplicatedStorage:FindFirstChild("Packages"),
            ReplicatedStorage:FindFirstChild("Shared"),
            ReplicatedStorage:FindFirstChild("Modules")
        }

        -- Try multiple replicons, not only "Data"
        local repliconNames = {"Data", "Inventory", "PlayerData", "Profile", "SaveData"}

        -- Known key names to probe inside the replicon (owned/inventory only)
        local probeKeys = {
            "OwnedItems","OwnedRods","Inventory","InventoryItems","Backpack","Storage","Locker","Bag",
            "Equipment","Equipments","Tools","ToolInventory","Equipped",
            -- Materials-related
            "Materials","Material","Currencies","Currency","Stones","Gems","Shards","Resources","InventoryMaterials","InventoryResource"
        }

        dprint("Replion scan replicons:", table.concat(repliconNames, ","))
        dprint("Replion scan probeKeys:", table.concat(probeKeys, ","))

        local visitedTables = setmetatable({}, {__mode = "k"})
        local maxVisited = 3000
        local visitedCount = 0

        local function handleEntry(entry, tag, owned)
            if visitedCount > maxVisited then return end
            if typeof(entry) == "string" or typeof(entry) == "number" then
                if not owned then return end
                local name = getItemNameById(entry)
                if name then safeAddRodName(name, tag or "🎣 Rod (Replion ID):") end
            elseif typeof(entry) == "table" then
                if visitedTables[entry] then return end
                visitedTables[entry] = true
                visitedCount += 1
                local entryName = entry.Name or entry.ItemName or entry.DisplayName
                local entryType = entry.Type or entry.Category or entry.ItemType
                -- materials quantity if present
                local qty = tonumber(entry.Count) or tonumber(entry.count) or tonumber(entry.Amount) or tonumber(entry.amount)
                    or tonumber(entry.Quantity) or tonumber(entry.quantity) or tonumber(entry.Qty) or tonumber(entry.qty) or tonumber(entry.Stack) or tonumber(entry.stack)
                local ud = extractUDID(entry)
                local ownedMark = owned or entry.Owned == true or entry.IsOwned == true or entry.Owns == true or entry.Equipped == true or entry.equipped == true or (ud ~= nil)
                -- If this table looks like a map of material name -> count under an owned path, collect Enchant totals
                if ownedMark then
                    local addedMat = 0
                    for mk, mv in pairs(entry) do
                        if typeof(mk) == "string" and typeof(mv) == "number" and mv > 0 then
                            local nk = normalizeKey(mk)
                            if (nk:find("super") and (nk:find("enchant stone") or nk:find("enchantstone"))) or (nk:find("enchant stone") or nk:find("enchantstone")) then
                                addMaterialQuantity(mk, mv)
                                addedMat += 1
                                if addedMat > 50 then break end
                            end
                        end
                    end
                end
                -- Detect equipped rod from Replion flags
                if (entry.Equipped == true or entry.equipped == true) and entryName then
                    local isRod = false
                    if isRodItemData(entry) then
                        isRod = true
                    elseif typeof(entryType) == "string" and entryType:lower() == "rod" then
                        isRod = true
                    end
                    if isRod and (not inventory.equippedRod or inventory.equippedRod == "") then
                        inventory.equippedRod = entryName
                        dprint("🎯 Equipped Rod (Replion):", entryName)
                    end
                end
                if entryName and qty and qty > 0 then
                    addMaterialQuantity(entryName, qty)
                end
                if ownedMark then
                    if isRodItemData(entry) and entryName then
                        ownedNames[normalizeKey(entryName)] = true
                        addOwnedRod(entryName, ud, "🎣 Rod (Replion Data):")
                    elseif entryName and (typeof(entryType)=="string" and entryType:lower()=="rod") then
                        ownedNames[normalizeKey(entryName)] = true
                        addOwnedRod(entryName, ud, "🎣 Rod (Replion Data):")
                    end
                elseif entry.Id or entry.ID then
                    local rawId = entry.Id or entry.ID
                    -- if this id looks like a GUID and we have a Name, index it
                    if typeof(rawId) == "string" and entryName and rawId:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
                        guidNameIndex[rawId] = entryName
                    end
                    local name = getItemNameById(rawId)
                    if name and ownedMark then
                        if qty and qty > 0 then addMaterialQuantity(name, qty) end
                        ownedIds[tostring(rawId)] = true
                        ownedNames[normalizeKey(name)] = true
                        addOwnedRod(name, tostring(rawId), "🎣 Rod (Replion ID->Catalog):")
                    end
                else
                    if entryName then
                        dprint("Skip non-owned entry:", entryName, "path=", tag)
                    end
                end
                -- Recurse
                local count = 0
                for k, v in pairs(entry) do
                    handleEntry(v, tag, ownedMark)
                    count += 1
                    if visitedCount > maxVisited or count > 500 then break end
                end
            end
        end

        for _, parent in ipairs(parents) do
            if parent then
                local replion = parent:FindFirstChild("Replion")
                if replion then
                    local ok, Client = pcall(require, replion)
                    if ok and Client and Client.Client then
                        for _, rname in ipairs(repliconNames) do
                            local replicon = Client.Client:WaitReplion(rname, 2)
                            if replicon then
                                dprint("Replion found:", rname)
                                for _, key in ipairs(probeKeys) do
                                    local okGet, value = pcall(function() return replicon:GetExpect(key) end)
                                    if okGet and value then
                                        local kl = string.lower(key)
                                        local ownedKey = false
                                        if kl:find("owned") or kl:find("owneditems") or kl:find("ownedrods") or kl:find("inventory") or kl:find("backpack") or kl:find("storage") or kl:find("locker") or kl:find("bag") then
                                            ownedKey = true
                                        end
                                        if not ownedKey then
                                            if kl:find("material") or kl:find("materials") or kl:find("currency") or kl:find("currencies") or kl:find("stone") or kl:find("stones") or kl:find("gem") or kl:find("gems") or kl:find("shard") or kl:find("shards") or kl:find("resource") or kl:find("resources") then
                                                ownedKey = true
                                            end
                                        end
                                        dprint("Probe hit:", rname .. "." .. key, "type=", typeof(value), "ownedCtx=", ownedKey)
                                        if typeof(value) == "table" then
                                            handleEntry(value, "🎣 Rod (Replion "..rname..":"..key.."):", ownedKey)
                                        else
                                            handleEntry(value, "🎣 Rod (Replion "..rname..":"..key.."):", ownedKey)
                                        end
                                    else
                                        dprint("Probe miss:", rname .. "." .. key)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    collectFromReplion()
    collectUIEnchantInfo()

    dprint(string.format("✅ Rods found: %d | Baits found: %d", #inventory.rods, #inventory.baits))
end

-- Removed duplicate main execution

-- ===== BUILD DISCORD EMBED =====
local fields = {}

-- Player info
table.insert(fields, { name = "👤 Player", value = string.format("%s (%s)", inventory.player.name, inventory.player.id), inline = true })
table.insert(fields, { name = "⏰ Time", value = inventory.time, inline = true })

-- Money and Level
if inventory.coin > 0 then
    table.insert(fields, { name = "💰 Money", value = string.format("%s", tostring(inventory.coin)), inline = true })
else
    table.insert(fields, { name = "💰 Money", value = "0 (or not found)", inline = true })
end

-- Debug Level
if inventory.level and typeof(inventory.level) == "number" and inventory.level > 0 then
    table.insert(fields, { name = "🏆 Level", value = string.format("Lvl: %s", tostring(inventory.level)), inline = true })
else
    -- Removed 'DEBUG (post)' level prints
end

-- Equipped Rod (if detected from Inventory.Main.Top)
if inventory.equippedRod and inventory.equippedRod ~= "" then
    table.insert(fields, { name = "🎯 Equipped Rod", value = tostring(inventory.equippedRod), inline = true })
end

-- XP removed as requested

-- Stats
if next(inventory.stats) then
    local statLines = {}
    for k, v in pairs(inventory.stats) do
        table.insert(statLines, string.format("%s: %s", k, tostring(v)))
    end
    table.sort(statLines)
    table.insert(fields, { name = "📊 Stats", value = table.concat(statLines, "\n"), inline = false })
end

-- Location (from Attributes)
local loc = inventory.attributes and inventory.attributes["LocationName"]
if loc and tostring(loc) ~= "" then
    table.insert(fields, { name = "📍 Location", value = tostring(loc), inline = true })
end

-- Materials (show Enchant Stone only for now)
do
    local lines = {}
    local es = inventory.materials and inventory.materials["Enchant Stone"] or 0
    local ses = inventory.materials and inventory.materials["Super Enchant Stone"] or 0
    if es and es > 0 then table.insert(lines, string.format("Enchant Stone × %d", es)) end
    if ses and ses > 0 then table.insert(lines, string.format("Super Enchant Stone × %d", ses)) end
    if #lines > 0 then
        table.insert(fields, { name = "🪨 Materials", value = table.concat(lines, "\n"), inline = true })
    end
end

-- Rods
if #inventory.rods > 0 then
    table.sort(inventory.rods)
    local maxShow = 30
    local show = {}
    for i = 1, math.min(#inventory.rods, maxShow) do
        table.insert(show, inventory.rods[i])
    end
    local rodText = table.concat(show, "\n")
    if #inventory.rods > maxShow then
        rodText = rodText .. string.format("\n… and %d more", #inventory.rods - maxShow)
    end
    if #rodText > 1000 then rodText = rodText:sub(1, 997) .. "..." end
    table.insert(fields, { name = "🎣 Rods", value = rodText, inline = false })
else
    table.insert(fields, { name = "🎣 Rods", value = "❌ No rods found\n(Try opening inventory in game)", inline = false })
end

-- Rods (IDs)
if inventory.rodsDetailed and #inventory.rodsDetailed > 0 then
    local maxIds = 10
    local lines = {}
    local shown = 0
    for _, inst in ipairs(inventory.rodsDetailed) do
        if inst.udid and inst.name then
            local short = tostring(inst.udid)
            if #short > 10 then short = short:sub(1, 8) .. ".." end
            table.insert(lines, string.format("%s — %s", inst.name, short))
            shown = shown + 1
            if shown >= maxIds then break end
        end
    end
    if #lines > 0 then
        table.insert(fields, { name = "🆔 Rods (IDs)", value = table.concat(lines, "\n"), inline = false })
    end
end

-- Discord embed will be sent after main execution

-- ===== MAIN EXECUTION =====
dprint("🚀 Starting complete inventory scan...")

local function scanAndSend()
    -- Reset inventory for fresh scan
    inventory.coin = 0
    inventory.level = 0
    inventory.rods = {}
    inventory.baits = {}
    inventory.materials = {}
    inventory.rodsDetailed = {}
    inventory.equippedRod = ""
    
    -- Find player data
    findLevelAndXP()
    findCoins()
    findInventoryItems()
    
    -- Update inventory.baits from baitSet for web telemetry
    inventory.baits = {}
    dprint("🔍 DEBUG: baitSet exists:", baitSet ~= nil)
    if baitSet then
        local count = 0
        for baitName, _ in pairs(baitSet) do
            count = count + 1
            table.insert(inventory.baits, baitName)
            dprint("🔍 DEBUG: Adding bait:", baitName)
        end
        dprint("🔍 DEBUG: baitSet had", count, "items")
    else
        dprint("🔍 DEBUG: baitSet is nil, checking global baits...")
        -- Try to find baits from Discord fields that were just created
        for _, field in ipairs(fields or {}) do
            if field.name and field.name:find("Baits") and field.value and not field.value:find("No baits") then
                -- Parse baits from Discord field value
                for line in field.value:gmatch("[^\n]+") do
                    if line and #line > 0 and not line:find("Try opening") then
                        table.insert(inventory.baits, line)
                        dprint("🔍 DEBUG: Extracted bait from Discord:", line)
                    end
                end
                break
            end
        end
    end
    dprint("🔍 DEBUG: Final inventory.baits count:", #inventory.baits)
    
    -- Create Discord baits field
    if #inventory.baits > 0 then
        local baitText = table.concat(inventory.baits, "\n")
        if #baitText > 1000 then baitText = baitText:sub(1, 997) .. "..." end
        table.insert(fields, { name = "🪱 Baits", value = baitText, inline = false })
        dprint("🔍 DEBUG: Added Discord baits field with", #inventory.baits, "baits")
    else
        table.insert(fields, { name = "🪱 Baits", value = "❌ No baits found\n(Try opening inventory in game)", inline = false })
        dprint("🔍 DEBUG: Added Discord 'no baits' field")
    end

dprint("🎉 Complete inventory scan finished!")
dprint("📊 Summary:")
dprint("  💰 Coins:", inventory.coin)
dprint("  🏆 Level:", inventory.level)
-- XP removed
dprint("  📊 Stats:", next(inventory.stats) and "found" or "none")
dprint("  🎣 Rods:", #inventory.rods)
dprint("  🪱 Baits:", #inventory.baits)

dprint("Coins:", inventory.coin)

dprint("✅ Complete inventory scan finished successfully! Level:", inventory.level, "| Coins:", inventory.coin)

-- ===== REBUILD FIELDS AFTER SCAN =====
fields = {}

-- Player info
table.insert(fields, { name = "👤 Player", value = string.format("%s (%s)", inventory.player.name, inventory.player.id), inline = true })
table.insert(fields, { name = "⏰ Time", value = inventory.time, inline = true })

-- Money and Level
if inventory.coin > 0 then
    table.insert(fields, { name = "💰 Money", value = string.format("%s", tostring(inventory.coin)), inline = true })
else
    table.insert(fields, { name = "💰 Money", value = "0 (or not found)", inline = true })
end

-- Debug Level (post)
dprint("🔍 DEBUG (post) - inventory.level:", inventory.level, "type:", typeof(inventory.level))
if inventory.level and typeof(inventory.level) == "number" and inventory.level > 0 then
    table.insert(fields, { name = "🏆 Level", value = string.format("Lvl: %s", tostring(inventory.level)), inline = true })
    dprint("✅ Added Level to Discord embed (post):", inventory.level)
else
    dprint("❌ Level not added to embed (post) - value:", inventory.level, "type:", typeof(inventory.level))
end

-- Equipped Rod (post)
if inventory.equippedRod and inventory.equippedRod ~= "" then
    table.insert(fields, { name = "🎯 Equipped Rod", value = tostring(inventory.equippedRod), inline = true })
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

-- Location (from Attributes)
do
    local loc = inventory.attributes and inventory.attributes["LocationName"]
    if loc and tostring(loc) ~= "" then
        table.insert(fields, { name = "📍 Location", value = tostring(loc), inline = true })
    end
end

-- Materials (show both Enchant Stone and Super Enchant Stone)
do
    local lines = {}
    local es = inventory.materials and inventory.materials["Enchant Stone"] or 0
    local ses = inventory.materials and inventory.materials["Super Enchant Stone"] or 0
    if es and es > 0 then table.insert(lines, string.format("Enchant Stone × %d", es)) end
    if ses and ses > 0 then table.insert(lines, string.format("Super Enchant Stone × %d", ses)) end
    if #lines > 0 then
        table.insert(fields, { name = "🪨 Materials", value = table.concat(lines, "\n"), inline = true })
    end
end

-- Enchants
if inventory.enchants and #inventory.enchants > 0 then
    local list = {}
    for _, e in ipairs(inventory.enchants) do table.insert(list, e) end
    table.sort(list)
    local text = table.concat(list, ", ")
    if #text > 1000 then text = text:sub(1, 997).."..." end
    table.insert(fields, { name = "🔮 Enchants", value = text, inline = false })
end

-- Rods
if #inventory.rods > 0 then
    table.sort(inventory.rods)
    local maxShow = 30
    local show = {}
    for i = 1, math.min(#inventory.rods, maxShow) do
        table.insert(show, inventory.rods[i])
    end
    local rodText = table.concat(show, "\n")
    if #inventory.rods > maxShow then
        rodText = rodText .. string.format("\n… and %d more", #inventory.rods - maxShow)
    end
    if #rodText > 1000 then rodText = rodText:sub(1, 997) .. "..." end
    table.insert(fields, { name = "🎣 Rods", value = rodText, inline = false })
else
    table.insert(fields, { name = "🎣 Rods", value = "❌ No rods found\n(Try opening inventory in game)", inline = false })
end

-- Rods (IDs)
if inventory.rodsDetailed and #inventory.rodsDetailed > 0 then
    local maxIds = 10
    local lines = {}
    local shown = 0
    for _, inst in ipairs(inventory.rodsDetailed) do
        if inst.udid and inst.name then
            local short = tostring(inst.udid)
            if #short > 10 then short = short:sub(1, 8) .. ".." end
            table.insert(lines, string.format("%s — %s", inst.name, short))
            shown = shown + 1
            if shown >= maxIds then break end
        end
    end
    if #lines > 0 then
        table.insert(fields, { name = "🆔 Rods (IDs)", value = table.concat(lines, "\n"), inline = false })
    end
end

-- Baits
if #inventory.baits > 0 then
    local baitText = table.concat(inventory.baits, "\n")
    if #baitText > 1000 then baitText = baitText:sub(1, 997) .. "..." end
    table.insert(fields, { name = "🪱 Baits", value = baitText, inline = false })
else
    table.insert(fields, { name = "🪱 Baits", value = "❌ No baits found\n(Try opening inventory in game)", inline = false })
end

-- ===== SEND TO DISCORD =====
local embed = {
    title = "🎒 Player Info",
    description = "Here are your stats, rods and baits!",
    color = 16776960,
    fields = fields,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
}

local payload = {
    content = "📊 FishIs complete inventory scan",
    embeds = { embed }
}

    if sendWebhook(payload) then
        print("✅ Complete inventory sent to Discord")
    else
        warn("❌ Failed to send inventory")
    end

    -- ===== SEND TO WEB DASHBOARD =====
    local loc = inventory.attributes and inventory.attributes["LocationName"]
    local telemetry = {
        account = inventory.player and inventory.player.name or tostring(plr.Name),
        playerName = inventory.player and inventory.player.name or nil,
        userId = inventory.player and inventory.player.id or nil,
        displayName = inventory.player and inventory.player.displayName or nil,
        money = inventory.coin or 0,
        coins = inventory.coin or 0,
        level = inventory.level or 0,
        equippedRod = inventory.equippedRod or "",
        location = loc and tostring(loc) or "",
        rods = inventory.rods or {},
        baits = inventory.baits or {},
        materials = inventory.materials or {},
        rodsDetailed = inventory.rodsDetailed or {},
        online = true,
        time = inventory.time,
    }
    print("🔍 DEBUG: Sending to web - baits count:", #(telemetry.baits or {}))
    if telemetry.baits and #telemetry.baits > 0 then
        print("🔍 DEBUG: Sending baits:", table.concat(telemetry.baits, ", "))
    end
    if sendTelemetryToServer(telemetry) then
        print("✅ Telemetry sent to web dashboard")
    else
        warn("❌ Failed to send telemetry to web dashboard")
    end

end

-- ===== AUTO-SEND LOOP =====
print("🔄 Starting auto-send loop (every 5 seconds)...")
while true do
    local success = pcall(scanAndSend)
    if not success then
        warn("❌ Error in scan cycle, continuing...")
    end
    wait(5)
end
