-- scan_enchant_only.lua
-- Purpose: Scan ONLY Enchant Stone (+ Super Enchant Stone) from the player's Inventory UI (Items tab)
-- and send to local telemetry server as a minimal payload. Designed to avoid double counting.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer
if not plr then return end

pcall(function()
    StarterGui:SetCore("SendNotification", { Title = "🔍 Enchant Scanner", Text = "Scanning Enchant from Items tab...", Duration = 3 })
end)

-- Settings
local DEBUG = false
local SCAN_INTERVAL = 10 -- seconds

local TELEMETRY_URLS = {
    "http://127.0.0.1:3001/telemetry",
    "http://localhost:3001/telemetry",
}

local function dprint(...)
    if DEBUG then print("[ENCHANT]", ...) end
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
    warn("[ENCHANT] failed to send to all URLs")
    return false
end

-- Utils ------------------------------------------------------------------------
local function normalize(s)
    s = tostring(s or "")
    s = s:gsub("%s+", " ")
    return string.lower(s)
end

local function getFullNameSafe(inst)
    local ok, res = pcall(function() return inst:GetFullName() end)
    return ok and res or tostring(inst)
end

local numberPatterns = {
    "x%s*([%d,]+)",      -- x 12 / x 1,234
    "([%d,]+)%s*x",      -- 12x / 1,234 x
    "%(([%d,]+)%)",      -- (12)
    "Qty%s*([%d,]+)",    -- Qty 12
    "Quantity%s*([%d,]+)",
}

local function parseFirstNumber(text)
    local t = tostring(text or "")
    for _, pat in ipairs(numberPatterns) do
        local n = t:match(pat)
        if n then
            n = n:gsub(",", "")
            local v = tonumber(n)
            if v and v >= 0 then return v end
        end
    end
    return nil
end

local function isShopPath(pathLower)
    -- Exclude shop/store/cost UI
    if pathLower:find("shop") or pathLower:find("store") then return true end
    if pathLower:find("gacha") or pathLower:find("banner") then return true end
    if pathLower:find("buy") or pathLower:find("cost") or pathLower:find("price") then return true end
    if pathLower:find("coin") or pathLower:find("coins") then return true end
    if pathLower:find("exclusive") then return true end
    return false
end

local function isInventoryItemsPath(pathLower)
    -- Require we're inside Inventory/Items UI to avoid grabbing numbers from HUD
    if not pathLower:find("playergui") then return false end
    if not (pathLower:find("inventory") or pathLower:find("backpack")) then return false end
    if not pathLower:find("item") then return false end
    return true
end

local TARGETS = {
    ["enchant stone"] = "Enchant Stone",
    ["super enchant stone"] = "Super Enchant Stone",
}

local function scanGUI()
    local result = { ["Enchant Stone"] = 0, ["Super Enchant Stone"] = 0 }
    local details = {}

    local pg = plr:FindFirstChild("PlayerGui")
    if not pg then return result, details end

    for _, ui in ipairs(pg:GetDescendants()) do
        if ui:IsA("TextLabel") or ui:IsA("TextButton") then
            local text = tostring(ui.Text or "")
            if text ~= "" then
                local lower = normalize(text)
                local nameKey = nil
                for k in pairs(TARGETS) do
                    if lower:find(k, 1, true) then nameKey = k; break end
                end
                if nameKey then
                    -- Found a name match; confirm path is not shop
                    local fullPath = getFullNameSafe(ui)
                    local pl = normalize(fullPath)
                    if isInventoryItemsPath(pl) and not isShopPath(pl) then
                        -- Try to get a count from siblings/parent
                        local parent = ui.Parent
                        local count = 0
                        -- 1) Parse number in the same label
                        count = parseFirstNumber(text) or 0
                        -- 2) Search siblings for numeric labels (strict patterns only)
                        if parent then
                            for _, sib in ipairs(parent:GetChildren()) do
                                if sib ~= ui and (sib:IsA("TextLabel") or sib:IsA("TextButton")) then
                                    local c = parseFirstNumber(sib.Text)
                                    if c and c > count then count = c end
                                end
                            end
                        end
                        local properName = TARGETS[nameKey]
                        if count > 0 then
                            -- pick the maximum we see to avoid duplicates
                            if count > (result[properName] or 0) then
                                result[properName] = count
                            end
                            table.insert(details, { name = properName, count = count, src = "GUI:"..fullPath })
                            dprint("FOUND", properName, count, fullPath)
                        else
                            -- If listed without an obvious count, assume presence = 1 (conservative)
                            if (result[properName] or 0) == 0 then
                                result[properName] = 1
                                table.insert(details, { name = properName, count = 1, src = "GUI:"..fullPath })
                                dprint("ASSUME 1", properName, fullPath)
                            end
                        end
                    end
                end
            end
        end
    end

    return result, details
end

local function runOnceAndSend()
    local counts, details = scanGUI()
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

    -- Hygiene: if materials still empty, omit fields
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
