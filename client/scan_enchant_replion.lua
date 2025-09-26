-- scan_enchant_replion.lua
-- Purpose: Read ONLY Enchant Stone (+ Super Enchant Stone) from Replion Data -> Inventory -> Items
-- and send to local telemetry server as a minimal payload, without relying on GUI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer
if not plr then return end

pcall(function()
    StarterGui:SetCore("SendNotification", { Title = "📦 Enchant Scanner (Replion)", Text = "Reading Inventory > Items...", Duration = 3 })
end)

-- Settings
local DEBUG = false
local SCAN_INTERVAL = 10 -- seconds

local TELEMETRY_URLS = {
    "http://127.0.0.1:3001/telemetry",
    "http://localhost:3001/telemetry",
}

local function dprint(...)
    if DEBUG then print("[ENCHANT-RPLN]", ...) end
end

-- HTTP helpers (executor-aware)
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
    warn("[ENCHANT-RPLN] failed to send to all URLs")
    return false
end

-- Replion Client ----------------------------------------------------------------
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

-- Build id->name map from ReplicatedStorage.Items --------------------------------
local idToName = {}
local function isEnchantName(name)
    if not name then return false end
    local n = string.lower(tostring(name))
    n = n:gsub("%s+"," ")
    return n == "enchant stone" or n == "super enchant stone"
end

local function indexTableAsCatalog(tbl)
    if typeof(tbl) ~= "table" then return end
    if tbl.Name then
        local name = tbl.Name
        local candidates = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key }
        for _, cid in ipairs(candidates) do
            if cid ~= nil then
                local sid = tostring(cid)
                if isEnchantName(name) then idToName[sid] = name end
            end
        end
    end
    for k, v in pairs(tbl) do
        if typeof(k) == "string" and typeof(v) == "table" and v.Name then
            local sid = tostring(k)
            if isEnchantName(v.Name) then idToName[sid] = v.Name end
        end
        indexTableAsCatalog(v)
    end
end

local function indexItems()
    local itemsModule = ReplicatedStorage:FindFirstChild("Items")
    if not itemsModule then
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc:IsA("ModuleScript") and string.lower(desc.Name) == "items" then
                itemsModule = desc; break
            end
        end
    end
    if itemsModule and itemsModule:IsA("ModuleScript") then
        local ok, data = pcall(require, itemsModule)
        if ok and typeof(data) == "table" then
            idToName = {}
            indexTableAsCatalog(data)
            dprint("indexed Items module for Enchant ids, entries:", (function() local c=0 for _ in pairs(idToName) do c=c+1 end return c end)())
        else
            warn("[ENCHANT-RPLN] require Items module failed")
        end
    else
        warn("[ENCHANT-RPLN] Items module not found")
    end
end

local function getNameById(id)
    if not id then return nil end
    return idToName[tostring(id)]
end

-- Scan ----------------------------------------------------------------------------
local function scanOnce()
    local counts = { ["Enchant Stone"] = 0, ["Super Enchant Stone"] = 0 }
    local details = {}

    local Client = getReplionClient()
    if not Client then dprint("no replion client"); return counts, details end
    local Data = Client:WaitReplion("Data", 2)
    if not Data then dprint("no Data replion"); return counts, details end

    local ok, inv = pcall(function() return Data:GetExpect({"Inventory"}) end)
    if not ok or inv == nil then dprint("no Inventory table"); return counts, details end

    local items = inv.Items
    if typeof(items) ~= "table" then dprint("Inventory.Items missing"); return counts, details end

    -- iterate array of item entries: expect { Id=<id>, Quantity=<n>, UUID=..., Metadata=... }
    local limit = 0
    for _, entry in ipairs(items) do
        local id = entry and (entry.Id or entry.ID or entry.ItemId or entry.ItemID)
        local qty = entry and (entry.Quantity or entry.Count or entry.Amount or 1) or 1
        local name = getNameById(id)
        if name and isEnchantName(name) then
            counts[name] = (counts[name] or 0) + (tonumber(qty) or 0)
            table.insert(details, { name = name, count = qty, src = "Replion:Data.Inventory.Items", id = tostring(id) })
            dprint("ADD", name, qty, "id=", id)
        end
        limit += 1; if limit > 2000 then break end
    end

    return counts, details
end

local function runOnceAndSend()
    indexItems()
    local counts, details = scanOnce()

    local payload = {
        account = plr.Name,
        playerName = plr.Name,
        userId = plr.UserId,
        displayName = plr.DisplayName,
        materials = {},
        materialsDetailed = details,
        online = true,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        lastUpdated = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    if (counts["Enchant Stone"] or 0) > 0 then payload.materials["Enchant Stone"] = counts["Enchant Stone"] end
    if (counts["Super Enchant Stone"] or 0) > 0 then payload.materials["Super Enchant Stone"] = counts["Super Enchant Stone"] end

    if next(payload.materials) == nil then payload.materials = nil end
    if not payload.materialsDetailed or #payload.materialsDetailed == 0 then payload.materialsDetailed = nil end

    sendTelemetry(payload)
end

spawn(function()
    while true do
        pcall(runOnceAndSend)
        task.wait(SCAN_INTERVAL)
    end
end)
