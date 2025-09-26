-- Scan Owned Materials (no GUI)
-- Collects owned/crafted materials without opening inventory UI, using replicated data (Replion/client state),
-- player-side values/attributes, and catalogs in ReplicatedStorage. Sends to local telemetry server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer
if not plr then return end

-- Notify (3s)
pcall(function()
    StarterGui:SetCore("SendNotification", { Title = "🪨 Materials Scanner", Text = "Scanning owned materials...", Duration = 3 })
end)

-- Settings
local DEBUG = false
local ALLOW_GUI_FALLBACK = false -- keep false to avoid reading UI text
-- Strict mode: only track Enchant Stone and Super Enchant Stone, and only from authoritative/kv sources
local STRICT_ENCHANT_ONLY = true
local EXACT_ENCHANT_FROM_KV_ONLY = true
local ENCHANT_WHITELIST = { ["enchant stone"] = true, ["super enchant stone"] = true }

local function dprint(...)
    if DEBUG then print("[MATS]", ...) end
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
    warn("[MATS] failed to send to all URLs")
    return false
end

-- Utils ------------------------------------------------------------------------
local function normalizeKey(s)
    return tostring(s):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Identify likely material names (tune as needed)
local materialTokens = {
    "material", "stone", "enchant", "super enchant", "gem", "ore", "bar", "pearl", "crystal", "shard", "essence", "scale", "tooth"
}
local function isMaterialName(name)
    if not name or name == "" then return false end
    local n = normalizeKey(name)
    if STRICT_ENCHANT_ONLY then
        return ENCHANT_WHITELIST[n] == true
    end
    for _, tk in ipairs(materialTokens) do if n:find(tk) then return true end end
    return false
end

-- Catalog index (Materials + Items fallback) -----------------------------------
local matIdToName, idToNameIndex = {}, {}

local function indexTableAsCatalog(tbl, preferMat)
    if typeof(tbl) ~= "table" then return end
    if tbl.Name then
        local name = tbl.Name
        local candidates = { tbl.Id, tbl.ID, tbl.ItemId, tbl.ItemID, tbl.UUID, tbl.Guid, tbl.GUID, tbl.Uid, tbl.UID, tbl.Key }
        for _, cid in ipairs(candidates) do
            if cid ~= nil then
                local sid = tostring(cid)
                if preferMat then
                    matIdToName[sid] = name
                else
                    if isMaterialName(name) then
                        idToNameIndex[sid] = name
                    end
                end
            end
        end
        if preferMat and isMaterialName(name) then idToNameIndex[normalizeKey(name)] = name end
    end
    for k, v in pairs(tbl) do
        if typeof(k) == "string" and typeof(v) == "table" and v.Name then
            local sid = tostring(k)
            if preferMat then
                matIdToName[sid] = v.Name
                if isMaterialName(v.Name) then idToNameIndex[normalizeKey(v.Name)] = v.Name end
            else
                if isMaterialName(v.Name) then
                    idToNameIndex[sid] = v.Name
                end
            end
        end
        indexTableAsCatalog(v, preferMat)
    end
end

local function requireMaterialsCatalog()
    local candidates = {"Materials","MaterialData","MaterialDatabase","MaterialCatalog","Mats","MatsData"}
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
        if ok and typeof(data) == "table" then indexTableAsCatalog(data, true); dprint("materials catalog indexed from", mod:GetFullName()) end
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

local function getMaterialNameById(id)
    if not id then return nil end
    local sid = tostring(id)
    if matIdToName[sid] then return matIdToName[sid] end
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
local nameCounts, materialsDetailed = {}, {}
local namePrio = {} -- track best source priority per material name
local authoritativeByName = {}
local adds = 0 -- how many leaf additions performed (for replicon stop logic)
local function addMaterial(name, count, src, id)
    if not name or name == "" then return end
    if not isMaterialName(name) then return end
    if authoritativeByName[name] then return end -- skip if authoritative value already set
    -- decide source priority
    local prio = 1 -- leaf/obj
    local s = tostring(src or "")
    if s:find(":kv") then prio = 3
    elseif s:find(":arrobj") or s:find(":arr") then prio = 2
    else prio = 1 end
    if STRICT_ENCHANT_ONLY and EXACT_ENCHANT_FROM_KV_ONLY then
        -- Prefer KV (maps) or PlayerData overrides; allow :arrobj/:arr (prio 2) to accumulate within the chosen dataset
        if prio < 3 then
            if prio == 2 then
                -- allow accumulation for prio 2
                -- (we already limit to a single chosen dataset per replicon, reducing double counting)
            else
                -- prio 1 (leaf/obj) is not accepted in strict mode
                return
            end
        end
    end
    local c = tonumber(count) or 0
    if c <= 0 then c = 1 end
    local existingPrio = namePrio[name]
    if not existingPrio or prio > existingPrio then
        -- upgrade to higher priority; replace count
        namePrio[name] = prio
        nameCounts[name] = c
    elseif prio == existingPrio then
        -- same priority; accumulate
        nameCounts[name] = (nameCounts[name] or 0) + c
    else
        -- lower priority than existing; ignore
    end
    table.insert(materialsDetailed, { name = name, count = c, src = src, id = id and tostring(id) or nil })
    adds = adds + 1
    dprint("ADD", name, "x", c, src or "")
end

local function runReplion()
    local Client = getReplionClient()
    if not Client then dprint("no replion client"); return end
    -- Prefer Inventory first to avoid duplicates across replicons
    local replicons = { "Inventory", "Data", "PlayerData", "Profile", "SaveData", "PlayerProfile" }
    local probeKeys = {
        "Materials","OwnedMaterials","Items","OwnedItems","Inventory","InventoryItems","Bag","Storage","Locker",
        "Resources","Ingredients","Craft","Crafting","Stones","Gems"
    }

    local visited = setmetatable({}, {__mode = "k"})
    local visitedCount, maxVisited = 0, 10000

    local function isCatalogPath(path)
        local p = normalizeKey(path or "")
        if p:find("catalog") or p:find("shop") or p:find("market") then return true end
        if p:find("pages") then return true end
        if p:find("content") and not (p:find("inventory") or p:find("owned") or p:find("bag") or p:find("storage") or p:find("locker") or p:find("materials") or p:find("resource") or p:find("ingredient")) then return true end
        return false
    end
    local function pathIsOwned(path)
        local p = normalizeKey(path or "")
        -- Explicitly exclude any Baits subtree from materials ownership detection
        if p:find("bait") then return false end
        if p:find("material") or p:find("materials") then return true end
        if p:find("owned") or p:find("inventory") or p:find("bag") or p:find("storage") or p:find("locker") then return true end
        if p:find("consumable") or p:find("resource") or p:find("ingredient") or p:find("craft") then return true end
        if p:find("stone") or p:find("enchant") or p:find("gem") or p:find("ore") or p:find("bar") then return true end
        return false
    end

    local function handle(entry, path)
        if typeof(entry) ~= "table" then return end
        if visited[entry] then return end
        visited[entry] = true; visitedCount += 1
        if visitedCount > maxVisited then return end
        if isCatalogPath(path) then return end

        -- Skip any subtree under Baits to avoid id collisions (e.g., id 10 in Baits)
        local pnow = normalizeKey(path or "")
        if pnow:find("bait") then return end
        -- In strict enchant mode, accept materials-like branches and Inventory>Items (UI Items tab data)
        local allowed = true
        if STRICT_ENCHANT_ONLY then
            allowed = (
                pnow:find("materials") or pnow:find("ownedmaterials") or pnow:find("stones") or pnow:find("resources")
                or (pnow:find("inventory") and pnow:find("items"))
            ) and true or false
        end
        -- Avoid extremely deep category trees
        local _, depth = (path or ""):gsub(">", "")
        if depth and depth > 6 then return end
        local entryName = entry.Name or entry.ItemName or entry.DisplayName
        local ownedByEntry = (entry.Owned == true or entry.IsOwned == true)
        local ownedByPath = pathIsOwned(path)
        local owned = ownedByEntry or ownedByPath
        if owned and entryName and isMaterialName(entryName) then
            -- Treat material leaf as terminal to avoid double counting its internal keys
            if allowed then
                addMaterial(entryName, entry.Count or entry.Amount or 1, path)
                return
            end
        end

        if owned then
            -- maps id -> count/bool
            for k, v in pairs(entry) do
                if typeof(k) == "string" or typeof(k) == "number" then
                    local count = nil
                    if typeof(v) == "boolean" and v == true then count = 1 end
                    if typeof(v) == "number" and v > 0 then count = v end
                    if count then
                        local name = getMaterialNameById(k)
                        if name and isMaterialName(name) and allowed then addMaterial(name, count, path..":kv", k) end
                    end
                end
            end
            -- arrays of ids/objects
            local limit = 0
            for _, v in ipairs(entry) do
                if typeof(v) == "string" or typeof(v) == "number" then
                    if pnow:find("bait") then -- safety guard
                        -- do not interpret bait ids as materials
                    else
                        local name = getMaterialNameById(v)
                        if name and isMaterialName(name) and allowed then addMaterial(name, 1, path..":arr", v) end
                    end
                elseif typeof(v) == "table" then
                    local raw = v.Id or v.ID or v.ItemId or v.ItemID
                    -- Use Quantity when present (Inventory>Items objects)
                    local count = v.Quantity or v.Count or v.Amount or 1
                    if raw ~= nil then
                        if not pnow:find("bait") then
                            local name = getMaterialNameById(raw)
                            if name and isMaterialName(name) and allowed then
                                addMaterial(name, count, path..":arrobj", raw)
                                visited[v] = true -- prevent re-processing this table in the later pairs() traversal
                            end
                        end
                    elseif v.Name and isMaterialName(v.Name) then
                        if allowed then
                            addMaterial(v.Name, count, path..":obj")
                            visited[v] = true -- prevent re-processing this table in the later pairs() traversal
                        end
                    end
                end
                limit += 1; if limit > 300 then break end
            end
        end

        local i = 0
        for k, v in pairs(entry) do i += 1; if i > 800 then break end; handle(v, tostring(path)..">"..tostring(k)) end
    end

    local stop = false
    for _, r in ipairs(replicons) do
        local rep = Client:WaitReplion(r, 2)
        if rep then
            local primaryKeys = { "OwnedMaterials","Materials","Inventory","InventoryItems","OwnedItems","Items","Bag","Storage","Locker","Resources","Ingredients","Craft","Crafting","Stones","Gems" }
            local chosenKey, chosenVal
            for _, key in ipairs(primaryKeys) do
                local ok, value = pcall(function() return rep:GetExpect(key) end)
                if ok and value ~= nil then chosenKey = key; chosenVal = value; break end
            end
            if chosenVal ~= nil then
                handle(chosenVal, r..":"..chosenKey)
                stop = true -- prefer single primary dataset per replicon
            else
                -- Fallback: scan probeKeys to get at least one dataset
                for _, key in ipairs(probeKeys) do
                    local ok, value = pcall(function() return rep:GetExpect(key) end)
                    if ok and value ~= nil then handle(value, r..":"..key); stop = true; break end
                end
            end
        end
        if stop then break end
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
            if ln:find("stone") or ln:find("enchant") or ln:find("material") or ln:find("gem") or ln:find("ore") or ln:find("bar") then
                local count = 0
                if inst:IsA("IntValue") or inst:IsA("NumberValue") then count = tonumber(inst.Value) or 0 end
                if inst:IsA("BoolValue") and inst.Value == true then count = 1 end
                if count > 0 then
                    -- treat PlayerData values as authoritative for this name
                    nameCounts[n] = count
                    namePrio[n] = 100
                    authoritativeByName[n] = true
                    table.insert(materialsDetailed, { name = n, count = count, src = "PlayerData:"..root.Name, id = nil })
                    dprint("AUTHORITATIVE", n, "=", count, "from", root.Name)
                end
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
            if isMaterialName(text) then addMaterial(text, 1, "GUI:"..element:GetFullName()) end
        end
    end
end

-- Aggregate and send ------------------------------------------------------------
local function runOnceAndSend()
    nameCounts = {}; materialsDetailed = {}; authoritativeByName = {}; namePrio = {}; adds = 0
    requireMaterialsCatalog()
    requireItemsCatalog()
    runReplion()
    collectFromPlayerInstances()
    collectFromGUI()

    local payload = {
        account = plr.Name,
        playerName = plr.Name,
        userId = plr.UserId,
        displayName = plr.DisplayName,
        -- materials as a mapping { name: count }
        materials = nameCounts,
        materialsDetailed = materialsDetailed,
        online = true,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        lastUpdated = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    -- hygiene: omit empty so we don't overwrite server state
    if not payload.materials or (type(payload.materials) == "table" and next(payload.materials) == nil) then payload.materials = nil end
    if not payload.materialsDetailed or #payload.materialsDetailed == 0 then payload.materialsDetailed = nil end
    sendTelemetry(payload)
end

-- Run periodically (every 10s)
spawn(function()
    while true do
        pcall(runOnceAndSend)
        wait(10)
    end
end)
