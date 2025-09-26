-- Auto Introspect + Send to Discord (Single File)
-- สแกนหาแหล่งข้อมูลในเกม (player stats, tools, modules, remotes, attributes)
-- แล้วสรุปผลเป็น Embed ส่งไปยัง Discord Webhook อัตโนมัติ

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local GAME_NAME = "FishIs"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj" -- ปรับเป็นของคุณได้

-- ===== KEYWORDS (ใช้กรองชื่อที่น่าจะเกี่ยวข้อง) =====
local KEYWORDS = {
    "Fish", "Fishing", "Rod", "Bait", "Inventory", "Bag", "Catch", "Sell", "Catalog", "Shop", "Item",
    "Replica", "ReplicaService", "Replion", "Data", "Config", "Stats", "Knit"
}

local function matchesKeyword(name)
    name = string.lower(name or "")
    for _, k in ipairs(KEYWORDS) do
        if string.find(name, string.lower(k)) then return true end
    end
    return false
end

-- ===== LOGGING / UTILS =====
local logs, MAX_LOG_LINES = {}, 500
local function addLog(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
    local line = table.concat(parts, ' ')
    print(line)
    if #logs < MAX_LOG_LINES then table.insert(logs, line) end
end

local function fullName(obj)
    if not obj then return "nil" end
    local ok, name = pcall(function() return obj:GetFullName() end)
    return ok and name or obj.Name
end

local function safeJSON(val)
    local ok, res = pcall(function() return HttpService:JSONEncode(val) end)
    return ok and res or tostring(val)
end

local function joinAndTrim(items, sep, maxLen)
    sep = sep or "\n"; maxLen = maxLen or 900
    local str = table.concat(items, sep)
    if #str > maxLen then str = string.sub(str, 1, maxLen - 3) .. "..." end
    return str
end

-- ===== EXECUTOR HTTP (fallback to HttpService) =====
local function findHttpRequest()
    if typeof(syn) == "table" and typeof(syn.request) == "function" then return syn.request, "syn.request" end
    if typeof(http) == "table" and typeof(http.request) == "function" then return http.request, "http.request" end
    if typeof(request) == "function" then return request, "request" end
    if typeof(http_request) == "function" then return http_request, "http_request" end
    return nil, nil
end

local httpRequest, httpSource = findHttpRequest()
addLog("HTTP source:", httpSource or "(HttpService fallback)")

local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)

    if httpRequest then
        local ok, res = pcall(function()
            return httpRequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        if not ok then
            addLog("❌ Executor HTTP error:", tostring(res))
            return false
        end
        local code = (typeof(res) == "table" and res.StatusCode) or nil
        addLog("📡 Executor HTTP Status:", code or "<unknown>")
        return (code == 200 or code == 204 or code == nil)
    else
        local ok, res = pcall(function()
            return HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        if not ok then addLog("❌ HttpService PostAsync error:", tostring(res)) end
        return ok
    end
end

-- ===== INTROSPECTION =====
local results = {
    player = {},
    leaderstats = {},
    backpack = {},
    valuesAttrs = {},
    modules = {},
    moduleSummaries = {},
    remotes = {},
    knit = {},
}

local plr = Players.LocalPlayer
addLog("Player:", plr and plr.Name or "<none>")

-- Player info
if plr then
    results.player.name = plr.Name
    results.player.id = plr.UserId
    results.player.displayName = plr.DisplayName
end

-- 1) Leaderstats & common direct stats
local function scanPlayerValues(p)
    addLog("\n=== Player Values ===")
    if not p then addLog("(no player)"); return end

    local leaderstats = p:FindFirstChild("leaderstats")
    if leaderstats then
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("ValueBase") then
                local ok, val = pcall(function() return child.Value end)
                local line = string.format("leaderstats.%s = %s", child.Name, ok and tostring(val) or "<err>")
                table.insert(results.leaderstats, line)
                addLog("[Value]", fullName(child), "=", ok and tostring(val) or "<error>")
            end
        end
    else
        addLog("leaderstats: <none>")
    end

    local common = {"Money", "Cash", "Level", "Lvl", "XP", "Coins", "Gems"}
    for _, name in ipairs(common) do
        local v = p:FindFirstChild(name)
        if v and v:IsA("ValueBase") then
            local ok, val = pcall(function() return v.Value end)
            local line = string.format("%s = %s", name, ok and tostring(val) or "<err>")
            table.insert(results.leaderstats, line)
            addLog("[Direct Stat]", name, "=", ok and tostring(val) or "<error>")
        end
    end

    local attrs = p:GetAttributes()
    if next(attrs) then
        for k, v in pairs(attrs) do
            local line = string.format("attr %s = %s", k, safeJSON(v))
            table.insert(results.valuesAttrs, line)
            addLog("[Attr] Player:", k, "=", safeJSON(v))
        end
    end
end

-- 2) Backpack / Equipped tools
local function scanTools(p)
    addLog("\n=== Tools ===")
    if not p then return end
    local bp = p:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(results.backpack, "BP:" .. tool.Name)
                addLog("[Backpack]", tool.Name)
            end
        end
    end
    if p.Character then
        for _, tool in ipairs(p.Character:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(results.backpack, "EQ:" .. tool.Name)
                addLog("[Equipped]", tool.Name)
            end
        end
    end
end

-- 3) Values / Attributes across ReplicatedStorage (filtered by keywords)
local function scanValuesAttributes(root)
    addLog("\n=== Replicated Values/Attributes (filtered) ===")
    local count = 0
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("ValueBase") and matchesKeyword(inst.Name) then
            local ok, val = pcall(function() return inst.Value end)
            local line = string.format("%s = %s", fullName(inst), ok and tostring(val) or "<err>")
            table.insert(results.valuesAttrs, line)
            count += 1
        end
        local attrs = inst:GetAttributes()
        if next(attrs) and matchesKeyword(inst.Name) then
            local line = string.format("attrs %s = %s", fullName(inst), safeJSON(attrs))
            table.insert(results.valuesAttrs, line)
            count += 1
        end
    end
    if count == 0 then addLog("(no matching)") end
end

-- 4) Modules + try require to preview structure
local MAX_MODULE_REQUIRE = 10
local MAX_KEYS_PREVIEW = 20
local function scanAndRequireModules()
    addLog("\n=== ModuleScripts (filtered) ===")
    local cands = {}
    local function collect(root, rootName)
        for _, inst in ipairs(root:GetDescendants()) do
            if inst:IsA("ModuleScript") and matchesKeyword(inst.Name) then
                table.insert(cands, {root = rootName, mod = inst})
                table.insert(results.modules, string.format("%s:%s", rootName, fullName(inst)))
            end
        end
    end
    collect(ReplicatedStorage, "ReplicatedStorage")
    local ps = plr and plr:FindFirstChild("PlayerScripts")
    if ps then collect(ps, "PlayerScripts") end

    addLog("Modules found:", #cands)
    local limit = math.min(#cands, MAX_MODULE_REQUIRE)
    for i = 1, limit do
        local mod = cands[i].mod
        addLog(string.format("[require %d/%d]", i, limit), fullName(mod))
        local ok, res = pcall(require, mod)
        if ok then
            local t = typeof(res)
            if t == "table" then
                local keys, kcount = {}, 0
                for k, v in pairs(res) do
                    kcount += 1
                    if #keys < MAX_KEYS_PREVIEW then
                        table.insert(keys, string.format("%s=%s", tostring(k), (typeof(v) == "table" and "<table>" or tostring(v))))
                    end
                end
                local line = string.format("%s keys=%d → %s", mod.Name, kcount, table.concat(keys, ", "))
                table.insert(results.moduleSummaries, line)
                addLog("  keys:", kcount)
            else
                table.insert(results.moduleSummaries, string.format("%s => %s", mod.Name, t))
            end
        else
            table.insert(results.moduleSummaries, string.format("%s (require error)", mod.Name))
            addLog("  ❌ require error")
        end
    end
end

-- 5) Remotes (names filtered)
local function scanRemotes()
    addLog("\n=== Remotes (filtered) ===")
    local count = 0
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) and matchesKeyword(inst.Name) then
            count += 1
            local line = string.format("%s (%s)", fullName(inst), inst.ClassName)
            table.insert(results.remotes, line)
        end
    end
    addLog("Remotes found:", count)
end

-- 6) Knit / KnitClient services/controllers quick scan
local function scanKnit()
    local kfold = ReplicatedStorage:FindFirstChild("Knit") or ReplicatedStorage:FindFirstChild("KnitClient")
    if not kfold then addLog("Knit: <none>"); return end
    table.insert(results.knit, "Folder: " .. fullName(kfold))

    local function addIfModule(d)
        if d:IsA("ModuleScript") and (string.find(string.lower(d.Name), "service") or string.find(string.lower(d.Name), "controller")) then
            table.insert(results.knit, fullName(d))
        end
    end

    for _, d in ipairs(kfold:GetDescendants()) do addIfModule(d) end
end

-- Run scans
scanPlayerValues(plr)
scanTools(plr)
scanValuesAttributes(ReplicatedStorage)
scanAndRequireModules()
scanRemotes()
scanKnit()

-- ===== BUILD DISCORD PAYLOAD =====
local function listOrDash(t)
    if not t or (#t == 0) then return "-" end
    return table.concat(t, "\n")
end

local embedFields = {}

-- Player
local playerLine = plr and string.format("%s (%s)", plr.Name, tostring(plr.UserId)) or "<none>"
 table.insert(embedFields, { name = "👤 Player", value = playerLine, inline = true })
 table.insert(embedFields, { name = "🎮 Game", value = GAME_NAME, inline = true })
 table.insert(embedFields, { name = "⏰ Time", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true })

-- Leaderstats
if #results.leaderstats > 0 then
    table.insert(embedFields, { name = "📊 Leaderstats", value = joinAndTrim(results.leaderstats, "\n", 900), inline = false })
end

-- Backpack
if #results.backpack > 0 then
    table.insert(embedFields, { name = "🎒 Tools", value = joinAndTrim(results.backpack, ", ", 900), inline = false })
end

-- Modules
if #results.modules > 0 then
    table.insert(embedFields, { name = "📦 Modules", value = joinAndTrim(results.modules, "\n", 900), inline = false })
end

-- Remotes
if #results.remotes > 0 then
    table.insert(embedFields, { name = "🛰️ Remotes", value = joinAndTrim(results.remotes, "\n", 900), inline = false })
end

-- Values / Attrs
if #results.valuesAttrs > 0 then
    table.insert(embedFields, { name = "🧩 Values/Attrs", value = joinAndTrim(results.valuesAttrs, "\n", 900), inline = false })
end

-- Knit
if #results.knit > 0 then
    table.insert(embedFields, { name = "🧵 Knit", value = joinAndTrim(results.knit, "\n", 900), inline = false })
end

-- Second embed for module require previews
local embeds = { {
    title = "FishIs Introspection Summary",
    description = "Auto-collected info from client",
    color = 3447003,
    fields = embedFields,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
} }

if #results.moduleSummaries > 0 then
    table.insert(embeds, {
        title = "Module Require Preview",
        description = joinAndTrim(results.moduleSummaries, "\n", 1500),
        color = 16776960,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
end

-- Include compact logs in content (trimmed)
local content = "``" .. "`\n" .. joinAndTrim(logs, "\n", 1200) .. "\n" .. "``" .. "`"

local payload = { content = content, embeds = embeds }

-- ===== SEND =====
addLog("\n📤 Sending introspection result to Discord...")
local ok = sendWebhook(payload)
if ok then
    addLog("✅ Sent to Discord successfully!")
else
    addLog("❌ Failed to send to Discord")
end

-- ===== UI TOAST =====
pcall(function()
    local p = Players.LocalPlayer; if not p then return end
    local pg = p:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui"); sg.Name = "AutoIntrospectToast"; sg.Parent = pg
    local fr = Instance.new("Frame"); fr.Size = UDim2.new(0, 380, 0, 90); fr.Position = UDim2.new(1, -400, 0, 20)
    fr.BackgroundColor3 = ok and Color3.fromRGB(0,140,0) or Color3.fromRGB(150,0,0); fr.BackgroundTransparency = 0.15; fr.BorderSizePixel = 0; fr.Parent = sg
    local ui = Instance.new("UICorner"); ui.CornerRadius = UDim.new(0, 10); ui.Parent = fr
    local lb = Instance.new("TextLabel"); lb.Size = UDim2.new(1,-16,1,-16); lb.Position = UDim2.fromOffset(8,8); lb.BackgroundTransparency = 1
    lb.Text = ok and "✅ Introspection sent to Discord" or "❌ Failed sending to Discord – check F9"
    lb.TextColor3 = Color3.new(1,1,1); lb.TextScaled = true; lb.Font = Enum.Font.SourceSansBold; lb.Parent = fr
    fr:TweenPosition(UDim2.new(1, -400, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.35, true)
    task.delay(6, function() fr:TweenPosition(UDim2.new(1, 20, 0, 20), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true); task.wait(0.35); sg:Destroy() end)
end)
