-- Scan PlayerGui for Inventory Data
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

local plr = Players.LocalPlayer
if not plr then
    warn("❌ No LocalPlayer")
    return
end

local pg = plr:WaitForChild("PlayerGui")

-- ===== HTTP FUNCTION =====
local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)
    if typeof(request) == "function" then
        local ok = pcall(function()
            request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        return ok
    elseif typeof(http) == "table" and typeof(http.request) == "function" then
        local ok = pcall(function()
            http.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        return ok
    else
        local ok = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        return ok
    end
end

print("🔍 Scanning PlayerGui for inventory data...")

-- ===== SCAN FUNCTIONS =====
local results = {}

local function addResult(category, path, info)
    table.insert(results, string.format("[%s] %s - %s", category, path, info))
    print(string.format("[%s] %s - %s", category, path, info))
end

local function scanGuiElement(element, path, depth)
    if not element or depth > 4 then return end
    
    local name = string.lower(element.Name)
    local className = element.ClassName
    
    -- Check if this GUI element is inventory-related
    local isInventoryRelated = false
    local keywords = {"inventory", "bag", "rod", "bait", "item", "equipment", "gear", "tool", "weapon", "fish", "shop", "store"}
    for _, keyword in ipairs(keywords) do
        if string.find(name, keyword) then
            isInventoryRelated = true
            break
        end
    end
    
    -- Also check for common GUI patterns
    if className == "Frame" or className == "ScrollingFrame" or className == "Folder" then
        local children = element:GetChildren()
        if #children > 5 then -- Likely a container with items
            isInventoryRelated = true
        end
    end
    
    if isInventoryRelated then
        addResult("GUI", path, string.format("%s (%d children)", className, #element:GetChildren()))
        
        -- Check attributes
        local attrs = element:GetAttributes()
        if next(attrs) then
            addResult("GUI", path .. " [attrs]", HttpService:JSONEncode(attrs))
        end
        
        -- Look for TextLabels that might contain item names/data
        for _, child in ipairs(element:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                local text = child.Text
                if text and #text > 0 then
                    -- Check if text looks like item data
                    if string.find(text, "Rod") or string.find(text, "Bait") or 
                       string.find(text, "ID:") or string.find(text, "UUID:") or
                       string.find(text, "Level") or string.find(text, "Rarity") then
                        addResult("GUI_TEXT", path .. "." .. child.Name, string.format("'%s'", text))
                    end
                end
            elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                -- Check if image has inventory-related attributes
                local childAttrs = child:GetAttributes()
                if next(childAttrs) then
                    addResult("GUI_IMAGE", path .. "." .. child.Name, HttpService:JSONEncode(childAttrs))
                end
            end
        end
        
        -- Recursively scan children
        for _, child in ipairs(element:GetChildren()) do
            scanGuiElement(child, path .. "." .. child.Name, depth + 1)
        end
    end
end

-- ===== SCAN PLAYERGUI =====
print("Scanning all ScreenGuis in PlayerGui...")

for _, screenGui in ipairs(pg:GetChildren()) do
    if screenGui:IsA("ScreenGui") then
        print("🔍 Scanning ScreenGui:", screenGui.Name)
        scanGuiElement(screenGui, "PlayerGui." .. screenGui.Name, 0)
    end
end

-- ===== LOOK FOR SPECIFIC PATTERNS =====
print("\n🎯 Looking for specific inventory patterns...")

-- Look for common inventory GUI names
local commonInventoryNames = {
    "Inventory", "InventoryGui", "Bag", "BagGui", "Items", "ItemsGui",
    "Equipment", "EquipmentGui", "Rods", "RodsGui", "Baits", "BaitsGui",
    "Shop", "ShopGui", "Store", "StoreGui", "MainGui", "HUD"
}

for _, guiName in ipairs(commonInventoryNames) do
    local gui = pg:FindFirstChild(guiName)
    if gui then
        addResult("FOUND_GUI", "PlayerGui." .. guiName, gui.ClassName)
        
        -- Deep scan this GUI
        scanGuiElement(gui, "PlayerGui." .. guiName, 0)
    end
end

-- ===== LOOK FOR DATA IN GUI OBJECTS =====
print("\n🔍 Looking for data stored in GUI objects...")

local function findDataInGui(element, path)
    -- Check for ModuleScripts in GUI
    for _, child in ipairs(element:GetDescendants()) do
        if child:IsA("ModuleScript") then
            local ok, data = pcall(require, child)
            if ok and typeof(data) == "table" then
                local keyCount = 0
                for k, v in pairs(data) do keyCount = keyCount + 1 end
                addResult("GUI_MODULE", child:GetFullName(), string.format("table with %d keys", keyCount))
            end
        elseif child:IsA("LocalScript") then
            addResult("GUI_SCRIPT", child:GetFullName(), "LocalScript (may contain inventory logic)")
        end
    end
end

for _, screenGui in ipairs(pg:GetChildren()) do
    if screenGui:IsA("ScreenGui") then
        findDataInGui(screenGui, "PlayerGui." .. screenGui.Name)
    end
end

-- ===== SEND RESULTS TO DISCORD =====
print(string.format("\n📊 Found %d results, sending to Discord...", #results))

if #results == 0 then
    local embed = {
        title = "🔍 PlayerGui Inventory Scan",
        description = "❌ No inventory-related GUI elements found",
        color = 16711680,
        fields = {
            { name = "Player", value = plr.Name, inline = true },
            { name = "Time", value = os.date("%H:%M:%S"), inline = true },
            { name = "Suggestion", value = "Try opening inventory/bag in game first", inline = false },
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook({ content = "🔍 PlayerGui Scan Results", embeds = { embed } })
else
    -- Split results into chunks
    local function chunkResults(list, chunkSize)
        local chunks = {}
        for i = 1, #list, chunkSize do
            local chunk = {}
            for j = i, math.min(i + chunkSize - 1, #list) do
                table.insert(chunk, list[j])
            end
            table.insert(chunks, chunk)
        end
        return chunks
    end
    
    local chunks = chunkResults(results, 20)
    
    for i, chunk in ipairs(chunks) do
        local description = table.concat(chunk, "\n")
        if #description > 1900 then
            description = description:sub(1, 1900) .. "...\n(truncated)"
        end
        
        local embed = {
            title = string.format("🔍 PlayerGui Inventory Scan (Part %d/%d)", i, #chunks),
            description = "```\n" .. description .. "\n```",
            color = 3447003,
            fields = {
                { name = "Player", value = plr.Name, inline = true },
                { name = "Total Results", value = tostring(#results), inline = true },
                { name = "Part", value = string.format("%d/%d", i, #chunks), inline = true },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
        
        local payload = {
            content = "🔍 PlayerGui Scan Results",
            embeds = { embed }
        }
        
        if sendWebhook(payload) then
            print(string.format("✅ Sent part %d/%d", i, #chunks))
        else
            warn(string.format("❌ Failed to send part %d", i))
        end
        
        if i < #chunks then
            task.wait(2)
        end
    end
end

print("🎉 PlayerGui scan complete!")
print("💡 Tips:")
print("- If no results found, try opening inventory/bag in game first")
print("- Look for GUI elements that contain TextLabels with rod/bait names")
print("- Check for ModuleScripts in GUI that might contain inventory data")
