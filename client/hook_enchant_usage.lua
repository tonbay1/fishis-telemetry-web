-- hook_enchant_usage.lua
-- Purpose: Hook __namecall to detect remote calls related to using Enchant Stones (or consuming items)
-- and send a minimal usage telemetry event. This is for debugging/telemetry only; does not modify behavior.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer
if not plr then return end

pcall(function()
    StarterGui:SetCore("SendNotification", { Title = "🪄 Hook Enchant Usage", Text = "Monitoring Remote calls...", Duration = 3 })
end)

-- Settings ----------------------------------------------------------------------
local DEBUG = false
local SEND_INTERVAL_SEC = 0.2 -- rate limit
local KEYWORDS = { "enchant", "consume", "use", "item", "inventory" }
local NAME_WHITELIST = { ["enchant stone"] = true, ["super enchant stone"] = true }

-- Defer network out of __namecall by using a queue
local usageQueue = {}

local TELEMETRY_URLS = {
    "http://127.0.0.1:3001/telemetry",
    "http://localhost:3001/telemetry",
}

local function dprint(...)
    if DEBUG then print("[HOOK-ENCH]", ...) end
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
    warn("[HOOK-ENCH] failed to send to all URLs")
    return false
end

-- Items id -> name map (only Enchant names) -------------------------------------
local idToName = {}
local function isEnchantName(name)
    if not name then return false end
    local n = string.lower(tostring(name)):gsub("%s+"," ")
    return NAME_WHITELIST[n] == true
end

local function indexTableAsCatalog(tbl)
    if typeof(tbl) ~= "table" then return end
    if tbl.Name then
        local name = tbl.Name
        local candidates = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key }
        for _, cid in ipairs(candidates) do
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
    idToName = {}
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
        if ok and typeof(data) == "table" then indexTableAsCatalog(data); dprint("indexed items ->", (function() local c=0 for _ in pairs(idToName) do c=c+1 end return c end)()) end
    end
end

indexItems()

-- Utilities ---------------------------------------------------------------------
local function now()
    return os.clock()
end

local function summarizeSimple(v)
    local tv = typeof(v)
    if tv == "number" or tv == "string" or tv == "boolean" then return v end
    if tv == "Instance" then return (v.ClassName .. ":" .. (v.Name or "?")) end
    if tv == "table" then return "<table>" end
    return tv
end

local function extractIdNameCountFromArgs(args)
    local foundName, foundCount
    -- try to find tables with Id/ItemId/UUID/Quantity
    for _, a in ipairs(args) do
        if typeof(a) == "table" then
            local id = a.Id or a.ID or a.ItemId or a.ItemID
            local qty = a.Quantity or a.Count or a.Amount
            if id ~= nil then
                local nm = idToName[tostring(id)]
                if nm and isEnchantName(nm) then foundName = nm; foundCount = tonumber(qty) end
            end
            -- also check if name provided directly
            local nm2 = a.Name or a.ItemName or a.DisplayName
            if nm2 and isEnchantName(nm2) then foundName = nm2; foundCount = tonumber(qty) end
        elseif typeof(a) == "number" or typeof(a) == "string" then
            local nm = idToName[tostring(a)]
            if nm and isEnchantName(nm) then foundName = nm end
        end
    end
    return foundName, foundCount
end

-- Hook __namecall ----------------------------------------------------------------
local lastSend = 0
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod and getnamecallmethod() or nil
    local args = { ... }
    local okToInspect = not checkcaller or not checkcaller()
    local shouldQueue = false
    local queuedUsage = nil
    if okToInspect and (method == "FireServer" or method == "InvokeServer") then
        if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
            local rname = string.lower(self.Name or "")
            local hit = false
            for _, k in ipairs(KEYWORDS) do if rname:find(k, 1, true) then hit = true; break end end
            if hit then
                local ename, count = extractIdNameCountFromArgs(args)
                if ename then
                    local t = now()
                    if (t - lastSend) >= SEND_INTERVAL_SEC then
                        lastSend = t
                        queuedUsage = { name = ename, delta = -1, remote = self.Name, count = count or 1, args = {} }
                        for i = 1, math.min(#args, 5) do queuedUsage.args[i] = summarizeSimple(args[i]) end
                        shouldQueue = true
                    end
                else
                    dprint("REMOTE", self.Name, method, "args:", table.create and #args or "?")
                end
            end
        end
    end
    -- Always call original to avoid interfering with gameplay
    local ret = oldNamecall(self, ...)
    if shouldQueue and queuedUsage then
        task.defer(function()
            table.insert(usageQueue, queuedUsage)
        end)
        dprint("USAGE", queuedUsage.name, "delta", queuedUsage.delta, "remote", queuedUsage.remote, "count", queuedUsage.count)
    end
    return ret
end)

-- Flush queue in background to keep hook light-weight
spawn(function()
    while true do
        local usage = table.remove(usageQueue, 1)
        if usage then
            local payload = {
                account = plr.Name,
                playerName = plr.Name,
                userId = plr.UserId,
                displayName = plr.DisplayName,
                materialsUsage = { usage },
                online = true,
                time = os.date("%Y-%m-%d %H:%M:%S"),
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                lastUpdated = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
            sendTelemetry(payload)
        end
        task.wait(0.1)
    end
end)
