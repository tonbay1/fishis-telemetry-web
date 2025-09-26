-- Scan Owned Rods (no GUI)
-- Collects all owned rods without opening inventory UI, using replicated data (Replion/client state),
-- Backpack/Character/StarterGear tools, and player-side values/attributes. Sends to local telemetry server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer
if not plr then return end

-- Notify (3s)
pcall(function()
    StarterGui:SetCore("SendNotification", { Title = "🎣 Rods Scanner", Text = "Scanning owned rods...", Duration = 3 })
end)

-- Settings
local DEBUG = false
local ALLOW_GUI_FALLBACK = false -- keep false to avoid reading UI text

local function dprint(...)
    if DEBUG then print("[RODS]", ...) end
end

-- HTTP helpers (executor-aware) ------------------------------------------------
local TELEMETRY_URLS = {
    "http://127.0.0.1:3001/telemetry",
    "http://localhost:3001/telemetry",
}

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

local function sendTelemetry(payload)
    for _, url in ipairs(TELEMETRY_URLS) do
        local ok = sendJson(url, payload)
        if ok then dprint("sent ->", url); return true end
    end
    warn("[RODS] failed to send to all URLs")
    return false
end

-- Utils ------------------------------------------------------------------------
local function isGuidLike(s)
    return typeof(s) == "string" and s:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function normalizeKey(s)
    return tostring(s):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function isRodName(name)
    if not name or name == "" then return false end
    return normalizeKey(name):find("rod") ~= nil
end

-- Catalog index (optional mapping id->name/type) --------------------------------
local itemsCatalog, idToNameIndex, nameToTypeIndex = {}, {}, {}

local function indexCatalog(tbl)
    if typeof(tbl) ~= "table" then return end
    if tbl.Name then
        local name = tbl.Name
        local candidates = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key }
        for _, cid in ipairs(candidates) do
            if cid ~= nil then idToNameIndex[tostring(cid)] = name end
        end
        local t = tbl.Type or tbl.Category or tbl.kind or tbl.ItemType or tbl.itemType
        if typeof(t) == "string" then nameToTypeIndex[normalizeKey(name)] = t:lower() end
    end
    for k, v in pairs(tbl) do
        if typeof(k) == "string" and typeof(v) == "table" and v.Name and isGuidLike(k) then
            idToNameIndex[k] = v.Name
            nameToTypeIndex[normalizeKey(v.Name)] = (v.Type or v.Category or v.ItemType or ""):lower()
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
        if ok and typeof(items) == "table" then itemsCatalog = items; indexCatalog(itemsCatalog); dprint("catalog indexed") end
    end
end

local function getItemNameById(id)
    if not id then return nil end
    local byIdx = idToNameIndex[tostring(id)]
    if byIdx then return byIdx end
    local keyNum = tonumber(id)
    if itemsCatalog then
        local byKey = itemsCatalog[id] or (keyNum and itemsCatalog[keyNum])
        if byKey and typeof(byKey) == "table" and byKey.Name then return byKey.Name end
    end
    return nil
end

-- Replion access ----------------------------------------------------------------
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

-- Collection --------------------------------------------------------------------
local rodsDetailed, ownedUDIDs = {}, {}
local function addOwnedRod(name, udid, src)
    if not name or not isRodName(name) then return end
    if udid then
        if ownedUDIDs[udid] then return end
        ownedUDIDs[udid] = true
    end
    table.insert(rodsDetailed, { name = name, udid = udid, src = src })
    dprint("ADD", name, udid and (udid:sub(1,8).."..") or "nil", src)
end

local function runReplion()
    local Client = getReplionClient()
    if not Client then dprint("no replion client"); return end
    local replicons = { "Data", "Inventory", "PlayerData", "Profile", "SaveData", "PlayerProfile" }
    local probeKeys = {
        "OwnedItems","OwnedRods","Inventory","InventoryItems","Backpack","Storage","Locker","Bag","Equipped",
        "Rods","FishingRods","RodInventory","RodBag",
        "LockerItems","StorageItems","BagItems","VaultItems","BankItems","WarehouseItems","StashItems"
    }

    local visited = setmetatable({}, {__mode = "k"})
    local visitedCount, maxVisited = 0, 10000

    local function isCatalogPath(path)
        local p = string.lower(path or "")
        if p:find("catalog") or p:find("shop") or p:find("market") then return true end
        if p:find("pages") then return true end
        if p:find("content") and not (p:find("inventory") or p:find("backpack") or p:find("owned") or p:find("bag") or p:find("locker") or p:find("storage")) then return true end
        return false
    end
    local function pathIsOwned(path)
        local p = string.lower(path or "")
        if p:find("owned") or p:find("inventory") or p:find("backpack") or p:find("storage") or p:find("locker") or p:find("bag") or p:find("equip") or p:find("equipment") then
            return true
        end
        if p:find("vault") or p:find("bank") or p:find("warehouse") or p:find("stash") or p:find("depot") then return true end
        if (p:find("rod")) and not isCatalogPath(p) then return true end
        return false
    end

    local function extractUDID(entry)
        local cands = { entry.UDID, entry.Udid, entry.Uuid, entry.UUID, entry.Uid, entry.UID, entry.InstanceId, entry.InstanceID }
        for _, v in ipairs(cands) do if isGuidLike(v) then return v end end
        if isGuidLike(entry.Guid) then return entry.Guid end
        if isGuidLike(entry.GUID) then return entry.GUID end
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
        if owned and entryName and isRodName(entryName) then
            addOwnedRod(entryName, udid, path)
        elseif (entry.Id or entry.ID) and owned then
            local name = getItemNameById(entry.Id or entry.ID)
            if name and isRodName(name) then addOwnedRod(name, udid or tostring(entry.Id or entry.ID), path..":idmap") end
        end

        if ownedByPath then
            for k, v in pairs(entry) do
                if typeof(k) == "string" or typeof(k) == "number" then
                    local truthy = (typeof(v) == "boolean" and v == true) or (typeof(v) == "number" and v > 0)
                    if truthy then
                        local name = getItemNameById(k)
                        if name and isRodName(name) then addOwnedRod(name, tostring(k), path..":kv") end
                    end
                end
            end
            for i, v in ipairs(entry) do
                if typeof(v) == "string" or typeof(v) == "number" then
                    local name = getItemNameById(v)
                    if name and isRodName(name) then addOwnedRod(name, tostring(v), path..":arr") end
                elseif typeof(v) == "table" then
                    local raw = v.Id or v.ID or v.ItemId or v.ItemID
                    if raw ~= nil then
                        local name = getItemNameById(raw)
                        if name and isRodName(name) then addOwnedRod(name, tostring(raw), path..":arrobj") end
                    end
                end
            end
        end
        local i = 0
        for k, v in pairs(entry) do i += 1; if i > 800 then break end; handle(v, tostring(path)..">"..tostring(k)) end
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
    local sg = plr:FindFirstChild("StarterGear")
    scan(sg, "StarterGear")
end

local function collectFromPlayerInstances()
    local roots = {}
    for _, name in ipairs({"Data","Inventory","Profile","SaveData","Stats"}) do
        local node = plr:FindFirstChild(name); if node then table.insert(roots, node) end
    end
    for _, root in ipairs(roots) do
        for _, inst in ipairs(root:GetDescendants()) do
            local n = inst.Name or ""
            if n:lower():find("rod") then
                local ownedAttr = (inst:GetAttribute("Owned") == true) or (inst:GetAttribute("Equipped") == true)
                local typeAttr = tostring(inst:GetAttribute("Type") or inst:GetAttribute("ItemType") or inst:GetAttribute("Category") or ""):lower()
                local isRodAttr = typeAttr:find("rod") ~= nil
                local isValueOwned = false
                if inst:IsA("BoolValue") then isValueOwned = inst.Value == true end
                if inst:IsA("IntValue") or inst:IsA("NumberValue") then isValueOwned = (inst.Value or 0) > 0 end
                if ownedAttr or isRodAttr or isValueOwned then if isRodName(n) then addOwnedRod(n, nil, "PlayerData:"..root.Name) end end
            end
        end
    end
end

local function collectFromGUI()
    if not ALLOW_GUI_FALLBACK then return end
    local pg = plr:FindFirstChild("PlayerGui"); if not pg then return end
    for _, element in ipairs(pg:GetDescendants()) do
        if element:IsA("TextLabel") or element:IsA("TextButton") then
            local text = element.Text or ""
            if text:lower():find("rod") then addOwnedRod(text, nil, "GUI:"..element:GetFullName()) end
        end
    end
end

-- Aggregate and send ------------------------------------------------------------
local function aggregateDistinct()
    local counts, names = {}, {}
    for _, inst in ipairs(rodsDetailed) do
        counts[inst.name] = (counts[inst.name] or 0) + 1
    end
    for name, _ in pairs(counts) do table.insert(names, name) end
    table.sort(names)
    return names, counts
end

local function runOnceAndSend()
    rodsDetailed = {}; ownedUDIDs = {}
    requireItemsCatalog()
    runReplion()
    collectFromTools()
    collectFromPlayerInstances()
    collectFromGUI()

    local names, counts = aggregateDistinct()
    local payload = {
        account = plr.Name,
        playerName = plr.Name,
        userId = plr.UserId,
        displayName = plr.DisplayName,
        rods = names,
        rodsDetailed = rodsDetailed,
        online = true,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        lastUpdated = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    sendTelemetry(payload)
end

-- Run periodically (every 10s)
spawn(function()
    while true do
        pcall(runOnceAndSend)
        wait(10)
    end
end)
