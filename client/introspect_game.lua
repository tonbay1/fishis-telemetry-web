-- Introspect Game - ค้นหาว่าข้อมูลผู้เล่น/ไอเท็มถูกจำลอง (replicate) มาที่ Client ตรงไหน
-- ใช้สคริปต์นี้เพื่อสแกนหา leaderstats, Backpack/Character Tools, Attributes, ModuleScripts, และ RemoteEvents ที่เกี่ยวข้องกับ Fish/Rod/Bait/Inventory

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer

local KEYWORDS = {
    "Fish", "Fishing", "Rod", "Bait", "Inventory", "Bag", "Catch", "Sell", "Catalog", "Shop", "Item",
    "Replica", "ReplicaService", "Replion", "Data", "Config", "Stats", "Knit"
}

local MAX_LOG_LINES = 400
local logs = {}

local function addLog(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[i] = tostring(v)
    end
    local line = table.concat(parts, " ")
    print(line)
    if #logs < MAX_LOG_LINES then
        table.insert(logs, line)
    end
end

local function fullName(obj)
    if not obj then return "nil" end
    local ok, name = pcall(function() return obj:GetFullName() end)
    return ok and name or obj.Name
end

local function matchesKeyword(name)
    name = string.lower(name or "")
    for _, k in ipairs(KEYWORDS) do
        if string.find(name, string.lower(k)) then
            return true
        end
    end
    return false
end

-- 1) Leaderstats & common value containers on Player
local function scanPlayerValues(p)
    addLog("\n=== Player Values ===")
    if not p then addLog("(no player)"); return end

    local function dumpValueFolder(folder)
        for _, child in ipairs(folder:GetDescendants()) do
            if child:IsA("ValueBase") then
                local ok, val = pcall(function() return child.Value end)
                addLog("[Value]", fullName(child), "=", ok and tostring(val) or "<error>")
            end
        end
    end

    local leaderstats = p:FindFirstChild("leaderstats")
    if leaderstats then
        addLog("leaderstats found ->", fullName(leaderstats))
        dumpValueFolder(leaderstats)
    else
        addLog("leaderstats: <none>")
    end

    -- Common direct stats (Money, Cash, Level, XP, etc.)
    local common = {"Money", "Cash", "Level", "Lvl", "XP", "Coins", "Gems"}
    for _, name in ipairs(common) do
        local v = p:FindFirstChild(name)
        if v and v:IsA("ValueBase") then
            local ok, val = pcall(function() return v.Value end)
            addLog("[Direct Stat]", name, "=", ok and tostring(val) or "<error>")
        end
    end

    -- Attributes on Player
    local attrs = p:GetAttributes()
    if next(attrs) then
        addLog("Attributes on Player:")
        for k, v in pairs(attrs) do
            addLog("  -", k, "=", HttpService:JSONEncode(v))
        end
    end
end

-- 2) Backpack and Character tools
local function scanTools(p)
    addLog("\n=== Tools (Backpack/Character) ===")
    if not p then return end

    local backpack = p:FindFirstChild("Backpack")
    if backpack then
        local count = 0
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                count += 1
                addLog("[Backpack]", tool.Name, "| attrs:", HttpService:JSONEncode(tool:GetAttributes()))
            end
        end
        if count == 0 then addLog("Backpack: no tools") end
    else
        addLog("Backpack: <none>")
    end

    if p.Character then
        local count = 0
        for _, tool in ipairs(p.Character:GetChildren()) do
            if tool:IsA("Tool") then
                count += 1
                addLog("[Equipped]", tool.Name, "| attrs:", HttpService:JSONEncode(tool:GetAttributes()))
            end
        end
        if count == 0 then addLog("Character: no equipped tools") end
    else
        addLog("Character: <none>")
    end
end

-- 3) Attributes + ValueBases across key containers
local function scanAttributesAndValues(root, title)
    addLog("\n===", title, "===")
    local found = 0
    for _, inst in ipairs(root:GetDescendants()) do
        -- Value objects
        if inst:IsA("ValueBase") and (matchesKeyword(inst.Name) or inst.Parent == root) then
            local ok, val = pcall(function() return inst.Value end)
            addLog("[ValueBase]", fullName(inst), "=", ok and tostring(val) or "<error>")
            found += 1
        end
        -- Attributes on interesting instances
        local attrs = inst:GetAttributes()
        if next(attrs) and matchesKeyword(inst.Name) then
            local ok, json = pcall(HttpService.JSONEncode, HttpService, attrs)
            addLog("[Attrs]", fullName(inst), ok and json or "<attrs error>")
            found += 1
        end
    end
    if found == 0 then addLog("(no matching values/attributes found)") end
end

-- 4) Find ModuleScripts that look like data/catalog/inventory modules
local function scanModules()
    addLog("\n=== ModuleScripts (likely data/config/inventory) ===")

    local function scanRoot(root, rootName)
        local count = 0
        for _, inst in ipairs(root:GetDescendants()) do
            if inst:IsA("ModuleScript") and matchesKeyword(inst.Name) then
                count += 1
                addLog("[Module]", rootName .. ":", fullName(inst))
            end
        end
        if count == 0 then addLog(rootName .. ": (no matching modules)") end
    end

    scanRoot(ReplicatedStorage, "ReplicatedStorage")
    if localPlayer then
        local ps = localPlayer:FindFirstChild("PlayerScripts")
        if ps then scanRoot(ps, "PlayerScripts") else addLog("PlayerScripts: <none>") end
    end
end

-- 5) RemoteEvents/RemoteFunctions (names filtered by KEYWORDS)
local function scanRemotes()
    addLog("\n=== Remotes (names contain keywords) ===")
    local function scanRoot(root, rootName)
        local count = 0
        for _, inst in ipairs(root:GetDescendants()) do
            if (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) and matchesKeyword(inst.Name) then
                count += 1
                addLog("[Remote]", rootName .. ":", fullName(inst), "| Class:", inst.ClassName)
            end
        end
        if count == 0 then addLog(rootName .. ": (no matching remotes)") end
    end

    scanRoot(ReplicatedStorage, "ReplicatedStorage")
    if localPlayer then
        local ps = localPlayer:FindFirstChild("PlayerScripts")
        if ps then scanRoot(ps, "PlayerScripts") end
    end
end

-- 6) Dump folders likely used for items/catalog
local function scanLikelyFolders()
    addLog("\n=== Likely Folders (Items/Configs/Catalog) ===")
    local function scan(root, rootName)
        local hits = 0
        for _, inst in ipairs(root:GetDescendants()) do
            if inst:IsA("Folder") and matchesKeyword(inst.Name) then
                hits += 1
                addLog("[Folder]", rootName .. ":", fullName(inst))
            end
        end
        if hits == 0 then addLog(rootName .. ": (no matching folders)") end
    end

    scan(ReplicatedStorage, "ReplicatedStorage")
    scan(Lighting, "Lighting")
end

-- 7) Watchers for late-created data (leaderstats/backpack/remotes)
local function addWatchers()
    addLog("\n=== Watchers (late-created children) ===")
    if not localPlayer then return end

    local function onChildAdded(child)
        if child.Name == "leaderstats" or child:IsA("Folder") then
            addLog("[Player ChildAdded]", child.Name, "=> scanning values")
            task.defer(function()
                scanPlayerValues(localPlayer)
            end)
        end
    end
    localPlayer.ChildAdded:Connect(onChildAdded)

    local backpack = localPlayer:FindFirstChild("Backpack")
    if backpack then
        backpack.ChildAdded:Connect(function(ch)
            if ch:IsA("Tool") then
                addLog("[Backpack Added]", ch.Name)
            end
        end)
    end
end

-- MAIN
addLog("\n================ INTROSPECT GAME ================")
addLog("Player:", localPlayer and localPlayer.Name or "<none>")

scanPlayerValues(localPlayer)
scanTools(localPlayer)
scanAttributesAndValues(ReplicatedStorage, "ReplicatedStorage Values/Attributes (filtered)")
scanModules()
scanRemotes()
scanLikelyFolders()
addWatchers()

addLog("\nDone. Open Developer Console (F9) to view full logs.")

-- Optional: show compact UI toast soผู้ใช้รู้ว่าสคริปต์ทำงานแล้ว
local function toast(msg)
    local p = localPlayer
    if not p then return end
    local pg = p:FindFirstChild("PlayerGui") or p:WaitForChild("PlayerGui", 5)
    if not pg then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "IntrospectToast"
    sg.Parent = pg
    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(0, 380, 0, 90)
    fr.Position = UDim2.new(1, -400, 0, 20)
    fr.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    fr.BackgroundTransparency = 0.15
    fr.BorderSizePixel = 0
    fr.Parent = sg
    local ui = Instance.new("UICorner")
    ui.CornerRadius = UDim.new(0, 10)
    ui.Parent = fr
    local lb = Instance.new("TextLabel")
    lb.Size = UDim2.new(1, -16, 1, -16)
    lb.Position = UDim2.fromOffset(8, 8)
    lb.BackgroundTransparency = 1
    lb.Text = "🔎 Introspect Game: check F9 console for results"
    lb.TextColor3 = Color3.new(1,1,1)
    lb.TextWrapped = true
    lb.TextScaled = true
    lb.Font = Enum.Font.SourceSansBold
    lb.Parent = fr
    fr:TweenPosition(UDim2.new(1, -400, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.35, true)
    task.delay(6, function()
        fr:TweenPosition(UDim2.new(1, 20, 0, 20), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true)
        task.wait(0.35)
        sg:Destroy()
    end)
end

toast()
