-- Scan Owned Baits (no GUI)
-- Collects all owned baits without opening inventory UI, using replicated data (Replion/client state),
-- Player instance values/attributes, and catalogs in ReplicatedStorage. Sends to local telemetry server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer
if not plr then return end

-- Notify (3s)
pcall(function()
    StarterGui:SetCore("SendNotification", { Title = "🪱 Baits Scanner", Text = "Scanning owned baits...", Duration = 3 })
end)

-- Settings
local DEBUG = false
local ALLOW_GUI_FALLBACK = false -- keep false to avoid reading UI text

local function dprint(...)
    if DEBUG then print("[BAITS]", ...) end
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
    warn("[BAITS] failed to send to all URLs")
    return false
end

-- Utils ------------------------------------------------------------------------
local function normalizeKey(s)
    return tostring(s):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local baitTokens = {
    "bait", "worm", "ghost worm", "shrimp", "squid", "maggot", "bagel", "flakes", "minnow", "leech", "fish head"
}
local function isBaitName(name)
    if not name or name == "" then return false end
    local n = normalizeKey(name)
    for _, tk in ipairs(baitTokens) do if n:find(tk) then return true end end
    return false
end

-- Catalog index (Baits + Items fallback) ---------------------------------------
local baitIdToName, baitNameSet = {}, {}
local idToNameIndex = {} -- generic fallback (Items)

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
            local sid = k
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
        if ok and typeof(data) == "table" then indexTableAsCatalog(data, true); dprint("baits catalog indexed from", mod:GetFullName()) end
    end
    -- Also support a Folder of baits
    local folder = ReplicatedStorage:FindFirstChild("Baits")
    if folder and folder:IsA("Folder") then
        for _, inst in ipairs(folder:GetDescendants()) do
            if inst.Name and inst.Name ~= "" then baitNameSet[normalizeKey(inst.Name)] = true end
            local id = inst:GetAttribute("Id") or inst:GetAttribute("ID") or inst:GetAttribute("ItemId")
            if id ~= nil then baitIdToName[tostring(id)] = inst.Name end
        end
        dprint("baits folder indexed from", folder:GetFullName())
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
        if ok and typeof(items) == "table" then indexTableAsCatalog(items, false); dprint("items catalog indexed") end
    end
end

local function getBaitNameById(id, path)
    if not id then return nil end
    local sid = tostring(id)
    if baitIdToName[sid] then return baitIdToName[sid] end
    -- path hint: if path contains "bait" prefer bait list even without id
    if path and normalizeKey(path):find("bait") then return nil end
    return idToNameIndex[sid]
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
local baitsDetailed, nameCounts = {}, {}
local function addBait(name, count, src, id)
    if not name or name == "" then return end
    local nkey = normalizeKey(name)
    -- Must be recognized as bait by catalog or tokens
    if not baitNameSet[nkey] and not isBaitName(name) then return end
    nameCounts[name] = (nameCounts[name] or 0) + (tonumber(count) or 1)
    table.insert(baitsDetailed, { name = name, count = tonumber(count) or 1, src = src, id = id and tostring(id) or nil })
    dprint("ADD", name, "x", tonumber(count) or 1, src or "")
end

local function runReplion()
    local Client = getReplionClient()
    if not Client then dprint("no replion client"); return end
    local replicons = { "Data", "Inventory", "PlayerData", "Profile", "SaveData", "PlayerProfile" }
    local probeKeys = {
        "Baits","OwnedBaits","BaitInventory","BaitBag","Bag","Inventory","InventoryItems","Storage","Locker",
        "Consumables","Materials","Items","OwnedItems"
    }

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
        visited[entry] = true; visitedCount += 1
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
            -- maps id -> count/bool
            for k, v in pairs(entry) do
                if typeof(k) == "string" or typeof(k) == "number" then
                    local count = nil
                    if typeof(v) == "boolean" and v == true then count = 1 end
                    if typeof(v) == "number" and v > 0 then count = v end
                    if count then
                        local name = getBaitNameById(k, path)
                        if name then addBait(name, count, path..":kv", k) end
                    end
                end
            end
            -- arrays of ids/objects
            local limit = 0
            for _, v in ipairs(entry) do
                if typeof(v) == "string" or typeof(v) == "number" then
                    local name = getBaitNameById(v, path)
                    if name then addBait(name, 1, path..":arr", v) end
                elseif typeof(v) == "table" then
                    local raw = v.Id or v.ID or v.ItemId or v.ItemID
                    local count = v.Count or v.Amount or 1
                    if raw ~= nil then
                        local name = getBaitNameById(raw, path)
                        if name then addBait(name, count, path..":arrobj", raw) end
                    elseif v.Name then
                        if baitNameSet[normalizeKey(v.Name)] or isBaitName(v.Name) then addBait(v.Name, count, path..":obj") end
                    end
                end
                limit += 1; if limit > 300 then break end
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

local function collectFromPlayerInstances()
    local roots = {}
    for _, name in ipairs({"Data","Inventory","Profile","SaveData","Stats"}) do
        local node = plr:FindFirstChild(name); if node then table.insert(roots, node) end
    end
    for _, root in ipairs(roots) do
        for _, inst in ipairs(root:GetDescendants()) do
            local n = inst.Name or ""
            local ln = normalizeKey(n)
            if ln:find("bait") or ln:find("worm") or ln:find("shrimp") or ln:find("squid") or ln:find("maggot") or ln:find("minnow") or ln:find("leech") or ln:find("fish head") or ln:find("bagel") or ln:find("flakes") then
                local count = 0
                if inst:IsA("IntValue") or inst:IsA("NumberValue") then count = tonumber(inst.Value) or 0 end
                if inst:IsA("BoolValue") and inst.Value == true then count = 1 end
                if count > 0 then addBait(n, count, "PlayerData:"..root.Name) end
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
            if isBaitName(text) then addBait(text, 1, "GUI:"..element:GetFullName()) end
        end
    end
end

-- Aggregate and send ------------------------------------------------------------
local function namesFromCounts()
    local names = {}
    for name, cnt in pairs(nameCounts) do if cnt > 0 then table.insert(names, name) end end
    table.sort(names)
    return names
end

local function runOnceAndSend()
    baitsDetailed = {}; nameCounts = {}
    requireBaitsCatalog()
    requireItemsCatalog()
    runReplion()
    collectFromPlayerInstances()
    collectFromGUI()

    local names = namesFromCounts()
    local payload = {
        account = plr.Name,
        playerName = plr.Name,
        userId = plr.UserId,
        displayName = plr.DisplayName,
        baits = names,
        -- send detailed counts for debugging/analysis
        baitsDetailed = baitsDetailed,
        online = true,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        lastUpdated = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    -- hygiene: if no baits, omit field to avoid overwriting server state
    if not payload.baits or #payload.baits == 0 then payload.baits = nil end
    if not payload.baitsDetailed or #payload.baitsDetailed == 0 then payload.baitsDetailed = nil end
    sendTelemetry(payload)
end

-- Run periodically (every 10s)
spawn(function()
    while true do
        pcall(runOnceAndSend)
        wait(10)
    end
end)
