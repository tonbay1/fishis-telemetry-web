-- Test: Owned Rods Probe (no UI required)
-- Scans Replion-owned data and Backpack/Character tools to list rods you actually own.
-- Prints both an aggregated list (Name × Count) and instance list (Name — short UDID)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
if not plr then
    warn("❌ No LocalPlayer")
    return
end

-- ===== DEBUG =====
local DEBUG = true
local function dprint(...)
    if DEBUG then
        print("[RODS-DBG]", ...)
    end
end

-- ===== UTIL =====
local function isGuidLike(s)
    return typeof(s) == "string" and s:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function normalizeKey(s)
    return tostring(s):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- ===== CATALOG (optional, improves naming/type) =====
local itemsCatalog = {}
local idToNameIndex = {}
local nameToTypeIndex = {}

local function indexCatalog(tbl)
    if typeof(tbl) ~= "table" then return end
    if tbl.Name then
        local name = tbl.Name
        local candidates = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key }
        for _, cid in ipairs(candidates) do
            if cid ~= nil then idToNameIndex[tostring(cid)] = name end
        end
        local t = tbl.Type or tbl.Category or tbl.kind or tbl.ItemType or tbl.itemType
        if typeof(t) == "string" then
            nameToTypeIndex[normalizeKey(name)] = t:lower()
        end
    end
    for k, v in pairs(tbl) do
        if typeof(k) == "string" and typeof(v) == "table" and v.Name and isGuidLike(k) then
            idToNameIndex[k] = v.Name
            nameToTypeIndex[normalizeKey(v.Name)] = (v.Type or v.Category or v.ItemType or ""):lower()
        end
        indexCatalog(v)
    end
end

-- Try to locate Items/ItemData module deeply
local candidates = {"Items","ItemData","ItemDatabase","ItemCatalog","Catalog","Database"}
local itemsModule = ReplicatedStorage:FindFirstChild("Items")
if not itemsModule then
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            for _, nm in ipairs(candidates) do
                if string.lower(desc.Name) == string.lower(nm) then
                    itemsModule = desc
                    break
                end
            end
        end
        if itemsModule then break end
    end
end
if itemsModule and itemsModule:IsA("ModuleScript") then
    local ok, items = pcall(require, itemsModule)
    if ok and typeof(items) == "table" then
        itemsCatalog = items
        indexCatalog(itemsCatalog)
        dprint("Items catalog indexed from", itemsModule:GetFullName(), "ids=", (function() local c=0 for _ in pairs(idToNameIndex) do c+=1 end return c end)())
    else
        dprint("Failed to require items module:", itemsModule:GetFullName())
    end
else
    dprint("Items module not found in ReplicatedStorage descendants")
end

local function getItemNameById(id)
    if not id then return nil end
    local byIdx = idToNameIndex[tostring(id)]
    if byIdx then return byIdx end
    -- shallow fallback
    local keyNum = tonumber(id)
    if itemsCatalog then
        local byKey = itemsCatalog[id] or (keyNum and itemsCatalog[keyNum])
        if byKey and typeof(byKey) == "table" and byKey.Name then return byKey.Name end
    end
    return nil
end

local function isRodName(name)
    if not name or name == "" then return false end
    local n = normalizeKey(name)
    if n:find("rod") then return true end
    local t = nameToTypeIndex[n]
    return t == "rod"
end

-- ===== REPLION ACCESS =====
local function getReplionClient()
    local parents = {
        ReplicatedStorage:FindFirstChild("Packages"),
        ReplicatedStorage:FindFirstChild("Shared"),
        ReplicatedStorage:FindFirstChild("Modules"),
        ReplicatedStorage
    }
    for _, parent in ipairs(parents) do
        if parent then
            local replion = parent:FindFirstChild("Replion")
            if replion and replion:IsA("ModuleScript") then
                local ok, M = pcall(require, replion)
                if ok and M and M.Client then
                    return M.Client
                end
            end
        end
    end
    return nil
end

local function extractUDID(entry)
    -- Strict: only accept from known fields, do NOT traverse random nested keys
    local candidates = { entry.UDID, entry.Udid, entry.Uuid, entry.UUID, entry.Uid, entry.UID, entry.InstanceId, entry.InstanceID }
    for _, v in ipairs(candidates) do if isGuidLike(v) then return v end end
    -- Also consider GUID-like Guid/GUID fields if present (some games use these)
    if isGuidLike(entry.Guid) then return entry.Guid end
    if isGuidLike(entry.GUID) then return entry.GUID end
    return nil
end

-- ===== MAIN PROBE =====
local rodsDetailed = {}
local ownedUDIDs = {}
local addedNames = {}

local function addOwnedRod(name, udid, src)
    if not name or not isRodName(name) then return end
    if udid then
        if ownedUDIDs[udid] then return end
        ownedUDIDs[udid] = true
    end
    table.insert(rodsDetailed, { name = name, udid = udid, src = src })
    addedNames[normalizeKey(name)] = true
    dprint("ADD", name, "udid=", udid and (udid:sub(1,8).."..") or "nil", "src=", src)
end

local function runReplion()
    local Client = getReplionClient()
    if not Client then
        dprint("Replion client not found")
        return
    end
    local replicons = { "Data", "Inventory", "PlayerData", "Profile", "SaveData", "PlayerProfile" }
    -- Owned/inventory leaning keys plus rod-specific keys; catalogs will be filtered by path checker below
    local probeKeys = {
        "OwnedItems","OwnedRods","Inventory","InventoryItems","Backpack","Storage","Locker","Bag","Equipped",
        "Rods","FishingRods","RodInventory","RodBag",
        "LockerItems","StorageItems","BagItems","VaultItems","BankItems","WarehouseItems","StashItems"
    }
    dprint("Replicons:", table.concat(replicons, ","))
    dprint("ProbeKeys:", table.concat(probeKeys, ","))

    local visited = setmetatable({}, {__mode = "k"})
    local maxVisited, visitedCount = 10000, 0

    local function isCatalogPath(path)
        local p = string.lower(path or "")
        if p:find("catalog") or p:find("shop") or p:find("market") then return true end
        if p:find("pages") then return true end
        if p:find("content") and not (p:find("inventory") or p:find("backpack") or p:find("owned") or p:find("bag") or p:find("locker") or p:find("storage")) then
            return true
        end
        return false
    end

    local function pathIsOwned(path)
        local p = string.lower(path or "")
        if p:find("owned") or p:find("inventory") or p:find("backpack") or p:find("storage") or p:find("locker") or p:find("bag") or p:find("equip") or p:find("equipment") then
            return true
        end
        if p:find("vault") or p:find("bank") or p:find("warehouse") or p:find("stash") or p:find("depot") then
            return true
        end
        -- Accept rod-specific paths if not obviously catalog-ish
        if (p:find("rod")) and not isCatalogPath(p) then return true end
        return false
    end

    local function handle(entry, path)
        if visitedCount > maxVisited then return end
        -- Skip primitive at top-level; we'll handle id maps inside tables below
        if typeof(entry) == "string" or typeof(entry) == "number" then return end
        if typeof(entry) ~= "table" then return end
        if visited[entry] then return end
        visited[entry] = true
        visitedCount += 1

        -- Skip catalog-like paths entirely
        if isCatalogPath(path) then dprint("SKIP catalog path:", path); return end

        local entryName = entry.Name or entry.ItemName or entry.DisplayName
        local entryType = entry.Type or entry.Category or entry.ItemType
        local udid = extractUDID(entry)
        -- Owned if entry flags or has UDID, or the path suggests owned/inventory
        local ownedByEntry = (entry.Owned == true or entry.IsOwned == true or entry.Owns == true or entry.Equipped == true or entry.equipped == true or (udid ~= nil))
        local ownedByPath = pathIsOwned(path)
        local owned = ownedByEntry or ownedByPath
        if owned and entryName and isRodName(entryName) then
            addOwnedRod(entryName, udid, path)
        elseif (entry.Id or entry.ID) and owned then
            local name = getItemNameById(entry.Id or entry.ID)
            if name and isRodName(name) then addOwnedRod(name, udid or tostring(entry.Id or entry.ID), path..":idmap") end
        end

        -- If this is a map of id -> boolean/number, treat truthy/positive as owned
        if ownedByPath then
            local seen = 0
            for k, v in pairs(entry) do
                if typeof(k) == "string" or typeof(k) == "number" then
                    local truthy = (typeof(v) == "boolean" and v == true) or (typeof(v) == "number" and v > 0)
                    if truthy then
                        local name = getItemNameById(k)
                        if name and isRodName(name) then
                            addOwnedRod(name, tostring(k), path..":kv")
                            seen += 1
                            if seen > 50 then break end
                        else
                            dprint("Unknown ID in owned map:", tostring(k), "at", path)
                        end
                    end
                end
            end
            -- Also handle arrays of IDs under owned paths
            local arrSeen = 0
            for i, v in ipairs(entry) do
                if typeof(v) == "string" or typeof(v) == "number" then
                    local name = getItemNameById(v)
                    if name and isRodName(name) then
                        addOwnedRod(name, tostring(v), path..":arr")
                        arrSeen += 1
                        if arrSeen > 100 then break end
                    else
                        dprint("Unknown array ID:", tostring(v), "at", path)
                    end
                elseif typeof(v) == "table" then
                    local raw = v.Id or v.ID or v.ItemId or v.ItemID
                    if raw ~= nil then
                        local name = getItemNameById(raw)
                        if name and isRodName(name) then
                            addOwnedRod(name, tostring(raw), path..":arrobj")
                            arrSeen += 1
                            if arrSeen > 100 then break end
                        end
                    end
                end
            end
        end
        local i = 0
        for k, v in pairs(entry) do
            i += 1
            if i > 800 then break end
            local childPath = tostring(path)..">"..tostring(k)
            handle(v, childPath)
        end
    end

    for _, r in ipairs(replicons) do
        local rep = Client:WaitReplion(r, 2)
        if rep then
            dprint("Replion found:", r)
            for _, key in ipairs(probeKeys) do
                local ok, value = pcall(function() return rep:GetExpect(key) end)
                if ok and value ~= nil then
                    dprint("Probe hit:", r.."."..key, "type=", typeof(value))
                    handle(value, r..":"..key)
                else
                    dprint("Probe miss:", r.."."..key)
                end
            end
        end
    end
end

local function collectFromTools()
    local function scan(container, where)
        if not container then return end
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Tool") or obj:IsA("Model") then
                local n = obj.Name or ""
                if n:find("Rod") then addOwnedRod(n, nil, "Tool:"..where) end
            end
        end
    end
    scan(plr:FindFirstChild("Backpack"), "Backpack")
    scan(plr.Character, "Character")
end

local function collectFromStarterGear()
    local sg = plr:FindFirstChild("StarterGear")
    if not sg then return end
    dprint("Scanning StarterGear for rods...")
    for _, obj in ipairs(sg:GetChildren()) do
        if obj:IsA("Tool") or obj:IsA("Model") then
            local n = obj.Name or ""
            if n:find("Rod") then addOwnedRod(n, nil, "StarterGear") end
        end
    end
end

local function collectFromPlayerDataInstances()
    dprint("Scanning Player instance data for rods...")
    local roots = {}
    for _, name in ipairs({"Data","Inventory","Profile","SaveData","Stats"}) do
        local node = plr:FindFirstChild(name)
        if node then table.insert(roots, node) end
    end
    local scanned = 0
    for _, root in ipairs(roots) do
        for _, inst in ipairs(root:GetDescendants()) do
            scanned += 1
            if scanned > 5000 then break end
            local n = inst.Name or ""
            if n:lower():find("rod") then
                -- Check attributes/values that imply ownership
                local ownedAttr = (inst:GetAttribute("Owned") == true) or (inst:GetAttribute("Equipped") == true)
                local typeAttr = tostring(inst:GetAttribute("Type") or inst:GetAttribute("ItemType") or inst:GetAttribute("Category") or ""):lower()
                local isRodAttr = typeAttr:find("rod") ~= nil
                local isValueOwned = false
                if inst:IsA("BoolValue") then isValueOwned = inst.Value == true end
                if inst:IsA("IntValue") or inst:IsA("NumberValue") then isValueOwned = (inst.Value or 0) > 0 end
                if ownedAttr or isRodAttr or isValueOwned then
                    if isRodName(n) then
                        addOwnedRod(n, nil, "PlayerData:"..root.Name)
                    end
                end
            end
        end
    end
end

local function collectFromGUI()
    dprint("Fallback: scanning GUI for rods (deepest scan, all matches)...")
    local pg = plr:WaitForChild("PlayerGui")
    local found = 0
    for _, element in ipairs(pg:GetDescendants()) do
        if element:IsA("TextLabel") or element:IsA("TextButton") then
            local text = element.Text or ""
            if text:lower():find("rod") then
                addOwnedRod(text, nil, "GUI:"..element:GetFullName())
                found = found + 1
                dprint("GUI ROD MATCH:", text, "at", element:GetFullName())
            end
        end
    end
    dprint("Total rods found in GUI:", found)
end

-- Run
print("🚀 Testing Owned Rods (no UI)...")
runReplion()
collectFromTools()
collectFromStarterGear()
collectFromPlayerDataInstances()

-- If Replion found nothing, try GUI as fallback
if #rodsDetailed == 0 then
    dprint("No rods from Replion/Tools, trying GUI fallback...")
    collectFromGUI()
end

-- Aggregate
local counts = {}
for _, inst in ipairs(rodsDetailed) do
    counts[inst.name] = (counts[inst.name] or 0) + 1
end

-- Print summary
local distinct, total = 0, #rodsDetailed
for _ in pairs(counts) do distinct += 1 end
print(string.format("✅ Owned rod instances: %d | distinct names: %d", total, distinct))

local listNames = {}
for name, cnt in pairs(counts) do table.insert(listNames, string.format("%s × %d", name, cnt)) end
table.sort(listNames)
print("🎣 Rods (name × count):\n" .. table.concat(listNames, "\n"))

local lines = {}
for i, inst in ipairs(rodsDetailed) do
    local short = inst.udid and (tostring(inst.udid):sub(1,8).."..") or "nil"
    table.insert(lines, string.format("%s — %s (%s)", inst.name, short, inst.src or ""))
    if i >= 20 then break end
end
if #lines > 0 then
    print("🆔 Rod instances (first 20):\n" .. table.concat(lines, "\n"))
end

print("ℹ️ NOTE: This probe does not open any UI. It relies on Replion-owned data and current Backpack/Character tools.")
