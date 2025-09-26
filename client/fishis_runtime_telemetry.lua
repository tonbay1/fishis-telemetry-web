-- FishIs Runtime Telemetry
-- Captures snapshot + hooks important remotes (ObtainedNewFishNotification, EquipItem, UnequipItem, EquipRodSkin, UnequipRodSkin)
-- Sends to Discord webhook using executor HTTP if available, falls back to HttpService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local GAME_NAME = "FishIs"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"
local MAX_EMBED_FIELD = 900

-- Keywords for filtering interesting names (to match introspection style)
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

local function fullName(obj)
    if not obj then return "nil" end
    local ok, nm = pcall(function() return obj:GetFullName() end)
    return ok and nm or obj.Name
end

-- ===== EXECUTOR HTTP DETECTION =====
local function findHttpRequest()
    if typeof(syn) == "table" and typeof(syn.request) == "function" then return syn.request, "syn.request" end
    if typeof(http) == "table" and typeof(http.request) == "function" then return http.request, "http.request" end
    if typeof(request) == "function" then return request, "request" end
    if typeof(http_request) == "function" then return http_request, "http_request" end
    return nil, nil
end
local httpRequest, httpSource = findHttpRequest()
print("📡 HTTP source:", httpSource or "HttpService")

local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)
    if httpRequest then
        local ok, res = pcall(function()
            return httpRequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        if not ok then warn("❌ Executor HTTP error:", res); return false end
        local code = (typeof(res) == "table" and res.StatusCode) or nil
        return (code == 200 or code == 204 or code == nil)
    else
        local ok, err = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        if not ok then warn("❌ HttpService PostAsync error:", err) end
        return ok
    end
end

local function trim(text, limit)
    limit = limit or MAX_EMBED_FIELD
    if not text then return "-" end
    if #text > limit then return text:sub(1, limit - 3) .. "..." end
    return text
end

-- ===== SNAPSHOT COLLECTION =====
local function collectPlayerSnapshot()
    local plr = Players.LocalPlayer
    local snap = {
        player = plr and { name = plr.Name, id = plr.UserId, displayName = plr.DisplayName } or { name = "<none>", id = 0 },
        ts = os.time(),
        time = os.date("%Y-%m-%d %H:%M:%S"),
        leaderstats = {},
        attrs = {},
        tools = {},
        game = GAME_NAME,
    }
    if plr then
        local ls = plr:FindFirstChild("leaderstats")
        if ls then
            for _, v in ipairs(ls:GetChildren()) do
                if v:IsA("ValueBase") then
                    local ok, val = pcall(function() return v.Value end)
                    snap.leaderstats[v.Name] = ok and val or nil
                end
            end
        end
        for k, v in pairs(plr:GetAttributes()) do
            snap.attrs[k] = v
        end
        local bp = plr:FindFirstChild("Backpack")
        if bp then
            for _, it in ipairs(bp:GetChildren()) do
                if it:IsA("Tool") then table.insert(snap.tools, it.Name) end
            end
        end
        if plr.Character then
            for _, it in ipairs(plr.Character:GetChildren()) do
                if it:IsA("Tool") then table.insert(snap.tools, "EQ:" .. it.Name) end
            end
        end
    end
    return snap
end

local function getBaitsCatalog(timeoutSeconds)
    local catalog = {}
    local baitsFolder = ReplicatedStorage:FindFirstChild("Baits")
    if not baitsFolder then
        baitsFolder = ReplicatedStorage:WaitForChild("Baits", timeoutSeconds or 5)
    end
    if not baitsFolder then return catalog end
    -- Ensure children have replicated
    local start = tick()
    local children = baitsFolder:GetChildren()
    while (#children == 0) and (tick() - start < (timeoutSeconds or 5)) do
        task.wait(0.2)
        children = baitsFolder:GetChildren()
    end
    for _, mod in ipairs(children) do
        if mod:IsA("ModuleScript") then
            local ok, data = pcall(require, mod)
            if ok and typeof(data) == "table" then
                local entry = { name = mod.Name }
                entry.Price = data.Price
                entry.Hidden = data.Hidden
                if typeof(data.Modifiers) == "table" then
                    entry.Modifiers = {}
                    for k, v in pairs(data.Modifiers) do
                        entry.Modifiers[k] = v
                    end
                end
                if typeof(data.Data) == "table" then
                    entry.Data = {}
                    for k, v in pairs(data.Data) do
                        entry.Data[k] = v
                    end
                end
                table.insert(catalog, entry)
            end
        end
    end
    table.sort(catalog, function(a, b) return (tostring(a.name) < tostring(b.name)) end)
    return catalog
end

-- Collect module list (filtered) similar to introspection
local function collectModulesFiltered()
    local list = {}
    local function collect(root)
        for _, inst in ipairs(root:GetDescendants()) do
            if inst:IsA("ModuleScript") and matchesKeyword(inst.Name) then
                table.insert(list, fullName(inst))
            end
        end
    end
    collect(ReplicatedStorage)
    local plr = Players.LocalPlayer
    if plr then
        local ps = plr:FindFirstChild("PlayerScripts")
        if ps then collect(ps) end
    end
    table.sort(list)
    -- Trim to a reasonable length to fit embed limits
    if #list > 30 then
        local trimmed = {}
        for i = 1, 30 do trimmed[i] = list[i] end
        list = trimmed
    end
    return list
end

-- Collect remotes list (filtered) similar to introspection
local function collectRemotesFiltered()
    local list = {}
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) and matchesKeyword(inst.Name) then
            table.insert(list, string.format("%s (%s)", fullName(inst), inst.ClassName))
        end
    end
    table.sort(list)
    if #list > 30 then
        local trimmed = {}
        for i = 1, 30 do trimmed[i] = list[i] end
        list = trimmed
    end
    return list
end

local function snapshotToEmbeds(snap, baits, modulesList, remotesList)
    local fields = {}
    table.insert(fields, { name = "👤 Player", value = string.format("%s (%s)", snap.player.name, tostring(snap.player.id)), inline = true })
    table.insert(fields, { name = "🎮 Game", value = GAME_NAME, inline = true })
    table.insert(fields, { name = "⏰ Time", value = snap.time, inline = true })

    if next(snap.leaderstats) then
        local parts = {}
        for k, v in pairs(snap.leaderstats) do table.insert(parts, ("%s: %s"):format(k, tostring(v))) end
        table.sort(parts)
        table.insert(fields, { name = "📊 Leaderstats", value = trim(table.concat(parts, "\n")), inline = false })
    end

    if next(snap.attrs) then
        local parts = {}
        for k, v in pairs(snap.attrs) do table.insert(parts, ("%s: %s"):format(k, HttpService:JSONEncode(v))) end
        table.sort(parts)
        table.insert(fields, { name = "🧩 Attributes", value = trim(table.concat(parts, "\n")), inline = false })
    end

    if #snap.tools > 0 then
        table.insert(fields, { name = "🎒 Tools", value = trim(table.concat(snap.tools, ", ")), inline = false })
    end

    local embeds = { {
        title = "FishIs Snapshot",
        description = "Initial client snapshot",
        color = 3447003,
        fields = fields,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    } }

    if baits and #baits > 0 then
        local lines = {}
        for i, e in ipairs(baits) do
            local price = e.Price and (" price=" .. tostring(e.Price)) or ""
            local hidden = (e.Hidden ~= nil) and (" hidden=" .. tostring(e.Hidden)) or ""
            local mods = e.Modifiers and (" mods=" .. HttpService:JSONEncode(e.Modifiers)) or ""
            table.insert(lines, string.format("%s%s%s%s", e.name, price, hidden, mods))
            if #lines >= 20 then break end -- limit output
        end
        table.insert(embeds, {
            title = "Baits Catalog (Top 20)",
            description = trim(table.concat(lines, "\n"), 1500),
            color = 65280,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })
    end

    -- Add modules/remotes like introspection
    if modulesList and #modulesList > 0 then
        table.insert(fields, { name = "📦 Modules", value = trim(table.concat(modulesList, "\n"), 900), inline = false })
    end
    if remotesList and #remotesList > 0 then
        table.insert(fields, { name = "🛰️ Remotes", value = trim(table.concat(remotesList, "\n"), 900), inline = false })
    end

    return embeds
end

-- ===== REMOTE HOOKS =====
local function findNetFolders()
    local packages = ReplicatedStorage:FindFirstChild("Packages")
    if not packages then return nil end
    local index = packages:FindFirstChild("_Index")
    if not index then return nil end
    for _, child in ipairs(index:GetChildren()) do
        if string.find(string.lower(child.Name), "sleitnick_net") then
            local netFolder = child:FindFirstChild("net")
            if netFolder then
                return {
                    RE = netFolder:FindFirstChild("RE"),
                    RF = netFolder:FindFirstChild("RF"),
                    root = netFolder,
                }
            end
        end
    end
    return nil
end

local function hookRemotes()
    local net = findNetFolders()
    if not net or not net.RE then
        warn("⚠️ Net RE folder not found")
        return
    end

    local targets = {
        "ObtainedNewFishNotification",
        "EquipItem", "UnequipItem",
        "EquipRodSkin", "UnequipRodSkin",
    }

    local hooked = 0
    for _, name in ipairs(targets) do
        local re = net.RE:FindFirstChild(name)
        if re and re:IsA("RemoteEvent") then
            hooked += 1
            re.OnClientEvent:Connect(function(...)
                local args = {...}
                local preview = {}
                for i = 1, math.min(#args, 8) do
                    local v = args[i]
                    table.insert(preview, typeof(v) == "table" and HttpService:JSONEncode(v) or tostring(v))
                end
                -- Build event embed
                local embed = {
                    title = "Event: " .. name,
                    description = (#preview > 0) and table.concat(preview, "\n") or "(no args)",
                    color = 16737792,
                    fields = {
                        { name = "Player", value = Players.LocalPlayer and Players.LocalPlayer.Name or "?", inline = true },
                        { name = "Time", value = os.date("%H:%M:%S"), inline = true },
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
                local payload = { content = "🎣 Runtime event captured", embeds = { embed } }
                sendWebhook(payload)
            end)
        end
    end
    print("🔗 Hooked RE events:", hooked)
end

-- ===== MAIN =====
print("🚀 FishIs Runtime Telemetry starting...")
local snapshot = collectPlayerSnapshot()
local baits = getBaitsCatalog(5)
local modulesList = collectModulesFiltered()
local remotesList = collectRemotesFiltered()

local payload = {
    content = string.format("📡 %s telemetry via %s", GAME_NAME, httpSource or "HttpService"),
    embeds = snapshotToEmbeds(snapshot, baits, modulesList, remotesList)
}

if sendWebhook(payload) then
    print("✅ Snapshot sent")
else
    warn("❌ Failed to send snapshot")
end

-- If baits weren't ready yet, try again shortly and send as a follow-up embed
if not baits or #baits == 0 then
    task.delay(5, function()
        local lateBaits = getBaitsCatalog(10)
        if lateBaits and #lateBaits > 0 then
            local lines = {}
            for i, e in ipairs(lateBaits) do
                local mods = e.Modifiers and (" mods=" .. HttpService:JSONEncode(e.Modifiers)) or ""
                local price = e.Price and (" price=" .. tostring(e.Price)) or ""
                local hidden = (e.Hidden ~= nil) and (" hidden=" .. tostring(e.Hidden)) or ""
                table.insert(lines, string.format("%s%s%s%s", e.name, price, hidden, mods))
                if #lines >= 20 then break end
            end
            local embed = {
                title = "Baits Catalog (Top 20)",
                description = trim(table.concat(lines, "\n"), 1500),
                color = 65280,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
            sendWebhook({ content = "⏳ Baits catalog loaded", embeds = { embed } })
        end
    end)
end

hookRemotes()
print("🟢 Waiting for events (equip, fish caught, etc.)...")

-- Optional toast
pcall(function()
    local plr = Players.LocalPlayer; if not plr then return end
    local pg = plr:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui"); sg.Name = "FishIsRuntimeTelemetry"; sg.Parent = pg
    local fr = Instance.new("Frame"); fr.Size = UDim2.new(0, 420, 0, 100); fr.Position = UDim2.new(1, -440, 0, 20)
    fr.BackgroundColor3 = Color3.fromRGB(30, 30, 50); fr.BackgroundTransparency = 0.15; fr.BorderSizePixel = 0; fr.Parent = sg
    local ui = Instance.new("UICorner"); ui.CornerRadius = UDim.new(0, 10); ui.Parent = fr
    local lb = Instance.new("TextLabel"); lb.Size = UDim2.new(1,-16,1,-16); lb.Position = UDim2.fromOffset(8,8); lb.BackgroundTransparency = 1
    lb.Text = "🟢 FishIs Runtime Telemetry\nSending snapshot + listening to events"; lb.TextColor3 = Color3.new(1,1,1); lb.TextWrapped = true; lb.TextScaled = true; lb.Font = Enum.Font.SourceSansBold; lb.Parent = fr
    task.delay(7, function() sg:Destroy() end)
end)
