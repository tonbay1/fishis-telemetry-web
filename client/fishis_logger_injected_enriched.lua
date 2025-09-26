-- fishis_logger_injected_enriched.lua
-- Minimal UI (Injected badge only) + Silent background logging
-- Enriched: read Rod/Bait catalog from ReplicatedStorage Modules, match Backpack,
-- and (optionally) pull Replion "Data" keys if present.

-- ========= CONFIG =========
local INGEST_URL        = "http://localhost:3001/ingest"  -- TODO: change to your server URL
local BATCH_SIZE        = 10          -- accumulate N events before sending
local BATCH_INTERVAL_S  = 10          -- force send every N seconds if buffer not empty
local SAMPLE_INTERVAL_S = 8           -- snapshot interval (seconds)
local GAME_NAME         = "FishIs"    -- project/game name tag
-- ==========================

-- ====== SERVICES ======
local HttpService   = game:GetService("HttpService")
local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ====== UTIL ======
local function JEncode(t) local ok,s=pcall(HttpService.JSONEncode,HttpService,t); return ok and s or "{}" end
local function safeRequire(m) local ok,mod=pcall(require,m); if ok then return mod end; return nil end

-- ====== ONE-TIME INJECTED BADGE (auto-hide) ======
do
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
    local pg = player:WaitForChild("PlayerGui")

    local screen = Instance.new("ScreenGui")
    screen.Name = "FishIsTelemetryInjected"
    screen.ResetOnSpawn = false
    screen.Parent = pg

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 240, 0, 36)
    badge.Position = UDim2.new(0, 12, 0, 12)
    badge.BackgroundColor3 = Color3.fromRGB(16,16,16)
    badge.BackgroundTransparency = 0.15
    badge.BorderSizePixel = 0
    badge.Text = "✅ Telemetry injected"
    badge.TextColor3 = Color3.fromRGB(230, 255, 230)
    badge.Font = Enum.Font.SourceSansBold
    badge.TextSize = 18
    badge.Parent = screen

    badge.BackgroundTransparency = 0.4
    badge.TextTransparency = 0.2
    local tween = TweenService:Create(badge, TweenInfo.new(0.25), {BackgroundTransparency = 0.15, TextTransparency = 0})
    tween:Play()
    task.delay(2.0, function()
        local t2 = TweenService:Create(badge, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextTransparency = 1})
        t2:Play()
        t2.Completed:Wait()
        screen:Destroy()
    end)
end

-- ===== Catalog from ReplicatedStorage (Rods/Baits) =====
local function catalogRods()
    local out = {}  -- by name
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if itemsFolder then
        for _,mod in ipairs(itemsFolder:GetChildren()) do
            if mod:IsA("ModuleScript") then
                local data = safeRequire(mod)
                if type(data) == "table" and type(data.Data)=="table" then
                    local dtype = tostring(data.Data.Type or ""):lower()
                    if dtype:find("fishing rod") or dtype:find("rod") then
                        out[data.Data.Name] = {
                            id   = data.Data.Id,
                            name = data.Data.Name,
                            tier = data.Data.Tier,
                            icon = data.Data.Icon,
                            price = data.Price,
                            stats = {
                                clickPower = data.ClickPower,
                                resilience = data.Resilience,
                                maxWeight  = data.MaxWeight,
                                windup     = tostring(data.Windup),
                            }
                        }
                    end
                end
            end
        end
    end
    return out
end

local function catalogBaits()
    local out = {}
    local baitsFolder = ReplicatedStorage:FindFirstChild("Baits")
    if baitsFolder then
        for _,mod in ipairs(baitsFolder:GetChildren()) do
            if mod:IsA("ModuleScript") then
                local data = safeRequire(mod)
                if type(data)=="table" and type(data.Data)=="table" then
                    local dtype = tostring(data.Data.Type or ""):lower()
                    if dtype:find("bait") then
                        out[data.Data.Name] = {
                            id    = data.Data.Id,
                            name  = data.Data.Name,
                            tier  = data.Data.Tier,
                            icon  = data.Data.Icon,
                            stats = data.Modifiers or {},
                        }
                    end
                end
            end
        end
    end
    return out
end

local ROD_CATALOG  = catalogRods()
local BAIT_CATALOG = catalogBaits()

-- ===== read leaderstats / values =====
local function readStat(player, names)
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _,n in ipairs(names) do
            local v = ls:FindFirstChild(n)
            if v and v.Value ~= nil then return v.Value end
        end
    end
    for _,n in ipairs(names) do
        local v = player:FindFirstChild(n)
        if v and v.Value ~= nil then return v.Value end
    end
    return 0
end

-- ===== Backpack → owned (match catalogue) =====
local function listBackpackItems(player)
    local items = {}
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _,child in ipairs(bp:GetChildren()) do
            local name = child.Name
            local meta = ROD_CATALOG[name]
            table.insert(items, meta and {name=name, id=meta.id, tier=meta.tier} or {name=name})
        end
    end
    return items
end

local function listBaitsOwned(player)
    local owned = {}
    local baitFolder = player:FindFirstChild("Baits")
    if baitFolder then
        for _,c in ipairs(baitFolder:GetChildren()) do
            local name = c.Name
            local meta = BAIT_CATALOG[name]
            table.insert(owned, meta and {name=name, id=meta.id, tier=meta.tier} or {name=name})
        end
    end
    return owned
end

-- ===== (Optional) Replion Data =====
local function readReplionData()
    local ok, Replion = pcall(function()
        local pkgs = ReplicatedStorage:FindFirstChild("Packages")
        if not pkgs then return nil end
        return require(pkgs:WaitForChild("Replion"))
    end)
    if not ok or not Replion then return {} end
    local data = {}
    local ok2, repl = pcall(function() return Replion.Client:WaitReplion("Data") end)
    if ok2 and repl then
        for _,key in ipairs({"Inventory","StarterPack","StarterPackTimer","Rods","Baits"}) do
            local v = repl:Get(key)
            if v ~= nil then data[key] = v end
        end
    end
    return data
end

-- ===== Build snapshot =====
local function buildSnapshot(player)
    local snap = {
        ts       = os.time(),
        kind     = "fish_snapshot",
        game     = GAME_NAME,
        player   = player.Name,
        userId   = player.UserId,
        level    = readStat(player, {"Level","Lvl"}),
        money    = readStat(player, {"Money","Cash"}),
        rods     = listBackpackItems(player),   -- [{name,id?,tier?}, ...]
        baits    = listBaitsOwned(player),      -- [{name,id?,tier?}, ...]
        catalog  = { rods = ROD_CATALOG, baits = BAIT_CATALOG },
        replion  = readReplionData(),
        source   = "executor_fishis_silent"
    }
    return snap
end

-- ===== BATCH & SEND (silent) =====
local buffer, lastSend = {}, os.time()

local function sendBatch()
    if #buffer == 0 then return end
    local payload = { game = GAME_NAME, events = buffer }
    local body = JEncode(payload)
    local ok, err = pcall(function()
        HttpService:PostAsync(INGEST_URL, body, Enum.HttpContentType.ApplicationJson)
    end)
    if ok then
        buffer = {}
        lastSend = os.time()
    else
        warn("[telemetry] send failed: ", err) -- silent warning
    end
end

local function enqueue(snap)
    table.insert(buffer, snap)
    if #buffer >= BATCH_SIZE then sendBatch() end
end

task.spawn(function()
    while true do
        if #buffer > 0 and (os.time() - lastSend) >= BATCH_INTERVAL_S then
            sendBatch()
        end
        task.wait(1)
    end
end)

-- triggers
Players.PlayerAdded:Connect(function(pl)
    task.delay(2, function() enqueue(buildSnapshot(pl)) end)
end)

task.spawn(function()
    while true do
        local lp = Players.LocalPlayer
        if lp then enqueue(buildSnapshot(lp)) end
        task.wait(SAMPLE_INTERVAL_S)
    end
end)

local function hookBackpack(plr)
    local bp = plr:FindFirstChild("Backpack")
    if not bp then return end
    bp.ChildAdded:Connect(function() enqueue(buildSnapshot(plr)) end)
    bp.ChildRemoved:Connect(function() enqueue(buildSnapshot(plr)) end)
end
for _,pl in ipairs(Players:GetPlayers()) do hookBackpack(pl) end
Players.PlayerAdded:Connect(hookBackpack)
-- end of file
