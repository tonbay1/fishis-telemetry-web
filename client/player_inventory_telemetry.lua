-- Player Inventory Telemetry - แสดงของที่ผู้เล่นมีจริงๆ (รอด, เหยื่อ, เงิน, เลเวล)
-- ไม่ใช่ catalog ทั้งหมดของเกม แต่เป็น inventory ส่วนตัวของผู้เล่น

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local GAME_NAME = "FishIs"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

-- ===== EXECUTOR HTTP =====
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

-- ===== PLAYER INVENTORY SCAN =====
local function scanPlayerInventory()
    local plr = Players.LocalPlayer
    if not plr then return { error = "No LocalPlayer" } end

    local inventory = {
        player = { name = plr.Name, id = plr.UserId, displayName = plr.DisplayName },
        time = os.date("%Y-%m-%d %H:%M:%S"),
        money = 0,
        level = 0,
        rods = {},
        baits = {},
        other_items = {},
        leaderstats = {},
        attributes = {},
    }

    -- Leaderstats (Money, Level, Caught, etc.)
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("ValueBase") then
                local ok, val = pcall(function() return v.Value end)
                if ok then
                    inventory.leaderstats[v.Name] = val
                    -- Extract common values
                    if string.find(string.lower(v.Name), "money") or string.find(string.lower(v.Name), "cash") then
                        inventory.money = val
                    elseif string.find(string.lower(v.Name), "level") or string.find(string.lower(v.Name), "lvl") then
                        inventory.level = val
                    end
                end
            end
        end
    end

    -- Player attributes
    for k, v in pairs(plr:GetAttributes()) do
        inventory.attributes[k] = v
    end

    -- Try to find player data in common locations
    local function searchForInventoryData(root, rootName)
        print("🔍 Searching", rootName, "for inventory data...")
        
        -- Look for player-specific folders/data
        local function checkInstance(inst, path)
            if not inst then return end
            
            -- Check if this looks like inventory data
            local name = string.lower(inst.Name)
            if string.find(name, "inventory") or string.find(name, "bag") or 
               string.find(name, "rod") or string.find(name, "bait") or
               string.find(name, "item") then
                print("📦 Found potential inventory:", path .. inst.Name)
                
                -- Try to read as folder with children
                if inst:IsA("Folder") then
                    for _, child in ipairs(inst:GetChildren()) do
                        if child:IsA("ValueBase") then
                            local ok, val = pcall(function() return child.Value end)
                            if ok then
                                print("  📄", child.Name, "=", val)
                            end
                        elseif child:IsA("Folder") then
                            print("  📁", child.Name, "(", #child:GetChildren(), "children )")
                        end
                    end
                end
                
                -- Try to read attributes
                local attrs = inst:GetAttributes()
                if next(attrs) then
                    print("  🏷️ Attributes:", HttpService:JSONEncode(attrs))
                end
            end
        end
        
        -- Search player-specific paths
        if rootName == "Player" then
            checkInstance(root:FindFirstChild("Inventory"), "")
            checkInstance(root:FindFirstChild("Bag"), "")
            checkInstance(root:FindFirstChild("Items"), "")
            checkInstance(root:FindFirstChild("Rods"), "")
            checkInstance(root:FindFirstChild("Baits"), "")
            checkInstance(root:FindFirstChild("Data"), "")
            
            -- Check all children for inventory-like names
            for _, child in ipairs(root:GetChildren()) do
                checkInstance(child, "")
            end
        else
            -- Search descendants for player-specific data
            for _, inst in ipairs(root:GetDescendants()) do
                local name = string.lower(inst.Name)
                if string.find(name, plr.Name:lower()) or 
                   string.find(name, tostring(plr.UserId)) then
                    print("📍 Found player-specific:", inst:GetFullName())
                    checkInstance(inst, "")
                end
            end
        end
    end

    -- Search common locations for inventory data
    searchForInventoryData(plr, "Player")
    searchForInventoryData(ReplicatedStorage, "ReplicatedStorage")
    
    -- Check PlayerScripts for client-side data
    local ps = plr:FindFirstChild("PlayerScripts")
    if ps then
        searchForInventoryData(ps, "PlayerScripts")
    end

    return inventory
end

-- ===== REMOTE SPY FOR INVENTORY UPDATES =====
local function spyInventoryRemotes()
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
                    }
                end
            end
        end
        return nil
    end

    local net = findNetFolders()
    if not net or not net.RE then
        print("⚠️ Net RE folder not found for inventory spy")
        return
    end

    -- Hook inventory-related remotes
    local inventoryRemotes = {
        "EquipItem", "UnequipItem", "EquipRodSkin", "UnequipRodSkin", "EquipBait",
        "FishCaught", "ObtainedNewFishNotification", "ItemObtained"
    }

    local hooked = 0
    for _, name in ipairs(inventoryRemotes) do
        local re = net.RE:FindFirstChild(name)
        if re and re:IsA("RemoteEvent") then
            hooked += 1
            re.OnClientEvent:Connect(function(...)
                local args = {...}
                print("📡 Inventory Event:", name, HttpService:JSONEncode(args))
                
                -- Send inventory update to Discord
                local embed = {
                    title = "🎒 Inventory Event: " .. name,
                    description = "```json\n" .. HttpService:JSONEncode(args) .. "\n```",
                    color = 3447003,
                    fields = {
                        { name = "Player", value = Players.LocalPlayer.Name, inline = true },
                        { name = "Time", value = os.date("%H:%M:%S"), inline = true },
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                }
                sendWebhook({ content = "🔄 Inventory updated", embeds = { embed } })
            end)
        end
    end
    print("🔗 Hooked inventory remotes:", hooked)
end

-- ===== MAIN =====
print("🎒 Player Inventory Telemetry starting...")

local inventory = scanPlayerInventory()

-- Build Discord embed
local fields = {}
table.insert(fields, { name = "👤 Player", value = string.format("%s (%s)", inventory.player.name, inventory.player.id), inline = true })
table.insert(fields, { name = "⏰ Time", value = inventory.time, inline = true })

-- Money & Level
if inventory.money > 0 then
    table.insert(fields, { name = "💰 Money", value = tostring(inventory.money), inline = true })
end
if inventory.level > 0 then
    table.insert(fields, { name = "🏆 Level", value = tostring(inventory.level), inline = true })
end

-- Leaderstats
if next(inventory.leaderstats) then
    local parts = {}
    for k, v in pairs(inventory.leaderstats) do
        table.insert(parts, string.format("%s: %s", k, tostring(v)))
    end
    table.sort(parts)
    table.insert(fields, { name = "📊 Stats", value = table.concat(parts, "\n"), inline = false })
end

-- Attributes
if next(inventory.attributes) then
    local parts = {}
    for k, v in pairs(inventory.attributes) do
        table.insert(parts, string.format("%s: %s", k, HttpService:JSONEncode(v)))
    end
    table.sort(parts)
    table.insert(fields, { name = "🏷️ Attributes", value = table.concat(parts, "\n"), inline = false })
end

-- Rods (if found)
if #inventory.rods > 0 then
    table.insert(fields, { name = "🎣 Rods", value = table.concat(inventory.rods, "\n"), inline = false })
else
    table.insert(fields, { name = "🎣 Rods", value = "❌ No rod inventory found\n(Check F9 console for search results)", inline = false })
end

-- Baits (if found)
if #inventory.baits > 0 then
    table.insert(fields, { name = "🪱 Baits", value = table.concat(inventory.baits, "\n"), inline = false })
else
    table.insert(fields, { name = "🪱 Baits", value = "❌ No bait inventory found\n(Check F9 console for search results)", inline = false })
end

local embed = {
    title = "🎒 Player Inventory",
    description = "Personal inventory and stats",
    color = 16776960,
    fields = fields,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
}

local payload = {
    content = string.format("📊 %s inventory scan via %s", GAME_NAME, httpSource or "HttpService"),
    embeds = { embed }
}

if sendWebhook(payload) then
    print("✅ Inventory sent to Discord")
else
    warn("❌ Failed to send inventory")
end

-- Start inventory remote spy
spyInventoryRemotes()

print("🟢 Inventory telemetry active. Check F9 console for search results.")
print("🔍 If rods/baits not found, the script will show search paths in console.")

-- UI Toast
pcall(function()
    local plr = Players.LocalPlayer; if not plr then return end
    local pg = plr:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui"); sg.Name = "InventoryTelemetry"; sg.Parent = pg
    local fr = Instance.new("Frame"); fr.Size = UDim2.new(0, 400, 0, 100); fr.Position = UDim2.new(1, -420, 0, 20)
    fr.BackgroundColor3 = Color3.fromRGB(255, 165, 0); fr.BackgroundTransparency = 0.15; fr.BorderSizePixel = 0; fr.Parent = sg
    local ui = Instance.new("UICorner"); ui.CornerRadius = UDim.new(0, 10); ui.Parent = fr
    local lb = Instance.new("TextLabel"); lb.Size = UDim2.new(1,-16,1,-16); lb.Position = UDim2.fromOffset(8,8); lb.BackgroundTransparency = 1
    lb.Text = "🎒 Player Inventory Scan\nCheck Discord + F9 console"; lb.TextColor3 = Color3.new(0,0,0); lb.TextWrapped = true; lb.TextScaled = true; lb.Font = Enum.Font.SourceSansBold; lb.Parent = fr
    task.delay(8, function() sg:Destroy() end)
end)
