-- Advanced Telemetry Script - เก็บข้อมูลครบถ้วน
-- รวบรวมข้อมูลทุกส่วนที่สำคัญจากเกม FishIs

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local INGEST_URL = "http://localhost:3001/ingest"
local GAME_NAME = "FishIs"

-- ===== UTILITY FUNCTIONS =====
local function safeGet(obj, path)
    local current = obj
    for _, key in ipairs(path) do
        if current and current:FindFirstChild(key) then
            current = current[key]
        else
            return nil
        end
    end
    return current
end

local function safeRequire(moduleScript)
    local success, result = pcall(require, moduleScript)
    return success and result or nil
end

local function getValueSafe(obj)
    if obj and obj.Value ~= nil then
        return obj.Value
    end
    return nil
end

-- ===== PLAYER DATA =====
local function getPlayerData(player)
    local data = {
        name = player.Name,
        userId = player.UserId,
        displayName = player.DisplayName,
        accountAge = player.AccountAge,
        membershipType = tostring(player.MembershipType),
        joinTime = tick(),
    }
    
    -- leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        data.stats = {}
        for _, stat in ipairs(leaderstats:GetChildren()) do
            data.stats[stat.Name] = getValueSafe(stat)
        end
    end
    
    -- Player values (เงิน, เลเวล, XP, etc.)
    local commonStats = {"Money", "Cash", "Level", "Lvl", "XP", "Experience", "Coins"}
    for _, statName in ipairs(commonStats) do
        local stat = player:FindFirstChild(statName)
        if stat then
            data[statName:lower()] = getValueSafe(stat)
        end
    end
    
    return data
end

-- ===== INVENTORY & BACKPACK =====
local function getInventoryData(player)
    local inventory = {
        backpack = {},
        character = {},
        starterGear = {}
    }
    
    -- Backpack items
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            table.insert(inventory.backpack, {
                name = item.Name,
                className = item.ClassName,
                parent = "Backpack"
            })
        end
    end
    
    -- Character items (equipped)
    if player.Character then
        for _, item in ipairs(player.Character:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(inventory.character, {
                    name = item.Name,
                    className = item.ClassName,
                    parent = "Character"
                })
            end
        end
    end
    
    -- StarterGear
    local starterGear = player:FindFirstChild("StarterGear")
    if starterGear then
        for _, item in ipairs(starterGear:GetChildren()) do
            table.insert(inventory.starterGear, {
                name = item.Name,
                className = item.ClassName,
                parent = "StarterGear"
            })
        end
    end
    
    return inventory
end

-- ===== GAME-SPECIFIC DATA (FishIs) =====
local function getFishingData(player)
    local fishingData = {
        rods = {},
        baits = {},
        fish = {},
        achievements = {}
    }
    
    -- Rods data
    local rodsFolder = player:FindFirstChild("Rods")
    if rodsFolder then
        for _, rod in ipairs(rodsFolder:GetChildren()) do
            table.insert(fishingData.rods, {
                name = rod.Name,
                value = getValueSafe(rod)
            })
        end
    end
    
    -- Baits data  
    local baitsFolder = player:FindFirstChild("Baits")
    if baitsFolder then
        for _, bait in ipairs(baitsFolder:GetChildren()) do
            table.insert(fishingData.baits, {
                name = bait.Name,
                value = getValueSafe(bait)
            })
        end
    end
    
    -- Fish collection
    local fishFolder = player:FindFirstChild("Fish") or player:FindFirstChild("FishCollection")
    if fishFolder then
        for _, fish in ipairs(fishFolder:GetChildren()) do
            table.insert(fishingData.fish, {
                name = fish.Name,
                value = getValueSafe(fish)
            })
        end
    end
    
    return fishingData
end

-- ===== REPLICATED STORAGE DATA =====
local function getGameCatalog()
    local catalog = {
        items = {},
        baits = {},
        fish = {},
        locations = {}
    }
    
    -- Items catalog
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    if itemsFolder then
        for _, module in ipairs(itemsFolder:GetChildren()) do
            if module:IsA("ModuleScript") then
                local data = safeRequire(module)
                if data and data.Data then
                    catalog.items[module.Name] = {
                        name = data.Data.Name,
                        id = data.Data.Id,
                        tier = data.Data.Tier,
                        type = data.Data.Type,
                        price = data.Price
                    }
                end
            end
        end
    end
    
    -- Baits catalog
    local baitsFolder = ReplicatedStorage:FindFirstChild("Baits")
    if baitsFolder then
        for _, module in ipairs(baitsFolder:GetChildren()) do
            if module:IsA("ModuleScript") then
                local data = safeRequire(module)
                if data and data.Data then
                    catalog.baits[module.Name] = {
                        name = data.Data.Name,
                        id = data.Data.Id,
                        tier = data.Data.Tier
                    }
                end
            end
        end
    end
    
    return catalog
end

-- ===== WORKSPACE DATA =====
local function getWorldData()
    local worldData = {
        players = {},
        npcs = {},
        locations = {}
    }
    
    -- Other players in game
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            table.insert(worldData.players, {
                name = player.Name,
                userId = player.UserId,
                character = player.Character and player.Character.Name or nil
            })
        end
    end
    
    -- NPCs or important objects
    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, npc in ipairs(npcsFolder:GetChildren()) do
            table.insert(worldData.npcs, {
                name = npc.Name,
                position = npc:IsA("Model") and npc.PrimaryPart and npc.PrimaryPart.Position or nil
            })
        end
    end
    
    return worldData
end

-- ===== REPLION DATA (Advanced) =====
local function getReplionData()
    local replionData = {}
    
    local success, Replion = pcall(function()
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        if packages then
            return require(packages:WaitForChild("Replion"))
        end
        return nil
    end)
    
    if success and Replion then
        local dataSuccess, dataReplion = pcall(function()
            return Replion.Client:WaitReplion("Data")
        end)
        
        if dataSuccess and dataReplion then
            local keys = {"Inventory", "StarterPack", "Rods", "Baits", "Fish", "Money", "Level", "XP"}
            for _, key in ipairs(keys) do
                local value = dataReplion:Get(key)
                if value ~= nil then
                    replionData[key] = value
                end
            end
        end
    end
    
    return replionData
end

-- ===== BUILD COMPLETE SNAPSHOT =====
local function buildCompleteSnapshot()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    local snapshot = {
        timestamp = os.time(),
        tick = tick(),
        kind = "complete_telemetry",
        game = GAME_NAME,
        
        -- Player data
        player = getPlayerData(player),
        
        -- Inventory
        inventory = getInventoryData(player),
        
        -- Game-specific
        fishing = getFishingData(player),
        
        -- Game catalog
        catalog = getGameCatalog(),
        
        -- World data
        world = getWorldData(),
        
        -- Replion data
        replion = getReplionData(),
        
        -- System info
        system = {
            fps = math.floor(1/RunService.Heartbeat:Wait()),
            ping = player:GetNetworkPing() * 1000,
            platform = "Roblox"
        },
        
        source = "advanced_telemetry_script"
    }
    
    return snapshot
end

-- ===== SEND DATA =====
local function sendTelemetry(data)
    local payload = {
        game = GAME_NAME,
        events = {data}
    }
    
    local success, result = pcall(function()
        return HttpService:PostAsync(
            INGEST_URL,
            HttpService:JSONEncode(payload),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        print("✅ Telemetry sent successfully!")
        print("📊 Data size:", string.len(HttpService:JSONEncode(payload)), "bytes")
    else
        warn("❌ Failed to send telemetry:", result)
    end
    
    return success
end

-- ===== UI NOTIFICATION =====
local function showAdvancedNotification()
    local player = Players.LocalPlayer
    if not player then return end
    
    local pg = player:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "AdvancedTelemetry"
    screen.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 120)
    frame.Position = UDim2.new(0.5, -175, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screen
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.4, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔬 Advanced Telemetry Active"
    title.TextColor3 = Color3.fromRGB(100, 255, 100)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = frame
    
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, 0, 0.6, 0)
    desc.Position = UDim2.new(0, 0, 0.4, 0)
    desc.BackgroundTransparency = 1
    desc.Text = "Collecting comprehensive game data...\nCheck server dashboard for results"
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.TextScaled = true
    desc.Font = Enum.Font.SourceSans
    desc.Parent = frame
    
    -- Fade out animation
    task.delay(3, function()
        local tween = TweenService:Create(frame, TweenInfo.new(1), {BackgroundTransparency = 1})
        local tween2 = TweenService:Create(title, TweenInfo.new(1), {TextTransparency = 1})
        local tween3 = TweenService:Create(desc, TweenInfo.new(1), {TextTransparency = 1})
        tween:Play()
        tween2:Play()
        tween3:Play()
        tween.Completed:Wait()
        screen:Destroy()
    end)
end

-- ===== MAIN EXECUTION =====
print("🚀 Starting Advanced Telemetry Collection...")
showAdvancedNotification()

task.wait(1)

local snapshot = buildCompleteSnapshot()
if snapshot then
    print("📋 Snapshot created with", #HttpService:JSONEncode(snapshot), "bytes of data")
    sendTelemetry(snapshot)
else
    warn("❌ Failed to create snapshot")
end

print("✨ Advanced Telemetry completed!")
