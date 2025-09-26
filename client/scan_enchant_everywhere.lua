-- scan_enchant_everywhere.lua
-- Brute force scan ALL PlayerGui for any TextLabel containing numbers that might be Enchant Stone counts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local plr = Players.LocalPlayer
if not plr then
    warn("[EnchantScan] No LocalPlayer")
    return
end

local function joinNums(nums, sep)
    if not nums or #nums == 0 then return "" end
    local parts = {}
    for i, v in ipairs(nums) do parts[i] = tostring(v) end
    return table.concat(parts, sep or ",")
end

-- Global candidate collector for this module
local candidates = {}

-- Scan containers named 'Enchant Stone' and 'Super Enchant Stone' and harvest numbers inside
local function scanNamedContainers(root)
    if not root then return end
    local function harvest(container, label)
        local function buildPath(obj)
            local path = {}
            local current = obj
            while current and current ~= game do
                table.insert(path, 1, string.format("%s[%s]", current.Name, current.ClassName))
                current = current.Parent
            end
            return table.concat(path, ".")
        end
        local best = nil
        for _, d in ipairs(container:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = d.Text or ""
                if #t > 0 then
                    local nums = {}
                    for n in t:gmatch("%d+") do table.insert(nums, tonumber(n)) end
                    if #nums > 0 then
                        best = best or {}
                        for _, v in ipairs(nums) do table.insert(best, v) end
                    end
                end
            end
        end
        local path = (getFullPath and getFullPath(container)) or buildPath(container)
        table.insert(candidates, {
            path = path,
            text = label,
            numbers = best or {},
            priority = (best and #best > 0) and "HIGH" or "NAME",
            nameHint = true
        })
        print(string.format("[EnchantScan] NAME: %s | '%s' | nums=%s", path, label, joinNums(best, ",")))
    end
    for _, d in ipairs(root:GetDescendants()) do
        local nm = d.Name and d.Name:lower() or ""
        if nm:find("enchant stone") or nm:find("enchantstone") then
            harvest(d, d.Name)
        elseif nm:find("super enchant stone") then
            harvest(d, d.Name)
        end
    end
end

-- ===== WEBHOOK CONFIG =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

local function sendWebhook(payload)
    local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then
        warn("[EnchantScan] JSON encode failed")
        return false
    end
    local req = (request or http_request or (syn and syn.request))
    if req then
        local res = req({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = encoded,
        })
        return res and (res.StatusCode == 200 or res.StatusCode == 204)
    else
        local ok2 = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, encoded, Enum.HttpContentType.ApplicationJson)
        end)
        return ok2
    end
end

local function sendDiscordTextBlocks(title, lines)
    -- Discord content limit ~2000 chars
    local blocks = {}
    local current = title .. "\n" .. "```"
    for _, line in ipairs(lines) do
        if #current + #line + 2 >= 1900 then
            table.insert(blocks, current .. "\n```")
            current = "```" .. line
        else
            current = current .. "\n" .. line
        end
    end
    table.insert(blocks, current .. "\n```")
    for _, content in ipairs(blocks) do
        local payload = { content = content }
        local ok = sendWebhook(payload)
        if not ok then warn("[EnchantScan] Failed to send a Discord block") end
    end
end

-- Scanner options
local DEBUG = true
local ONLY_VISIBLE = true
local TARGET_COUNT = 50 -- set to nil to disable target highlighting

local function dprint(...)
    if DEBUG then print("[EnchantScanDBG]", ...) end
end

local function isGuiObjectVisible(obj)
    -- Returns true if obj and all GUI ancestors are visible/enabled
    local current = obj
    while current and current ~= game do
        if current:IsA("ScreenGui") and current.Enabled == false then
            return false
        end
        if current:IsA("GuiObject") and current.Visible == false then
            return false
        end
        current = current.Parent
    end
    return true
end

local function normalizeKey(s)
    return tostring(s):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function extractNumbers(text)
    local numbers = {}
    for num in text:gmatch("%d+") do
        local n = tonumber(num)
        if n and n > 0 and n < 100000 then -- reasonable range for item counts
            table.insert(numbers, n)
        end
    end
    return numbers
end

local function getFullPath(obj)
    local path = {}
    local current = obj
    while current and current ~= game do
        table.insert(path, 1, string.format("%s[%s]", current.Name, current.ClassName))
        current = current.Parent
    end
    return table.concat(path, ".")
end

local scanned = 0

local function scanElement(element, depth)
    if not element or depth > 12 then return end
    scanned = scanned + 1
    
    if element:IsA("TextLabel") or element:IsA("TextButton") then
        local text = element.Text or ""
        if #text > 0 then
            local lowerText = text:lower()
            local numbers = extractNumbers(text)
            local visibleOk = true
            if ONLY_VISIBLE and element:IsA("GuiObject") then
                visibleOk = isGuiObjectVisible(element)
            end
            local nameLower = (element.Name or ""):lower()
            local parentLower = (element.Parent and element.Parent.Name or ""):lower()
            local hasNameHint = (nameLower:find("count") or nameLower:find("qty") or nameLower:find("amount") or nameLower:find("counter")
                or parentLower:find("count") or parentLower:find("qty") or parentLower:find("amount") or parentLower:find("counter"))
            local isTarget = false
            if TARGET_COUNT and #numbers > 0 then
                for _, n in ipairs(numbers) do if n == TARGET_COUNT then isTarget = true break end end
            end
            
            -- Ignore obvious non-item counts like weights
            if lowerText:find("kg") or lowerText:find("weight") or lowerText:find("lbs") or lowerText:find("lb ") then
                -- skip adding candidate
            -- Look for enchant-related text with numbers
            elseif visibleOk and #numbers > 0 and (lowerText:find("enchant") or lowerText:find("stone")) then
                local path = getFullPath(element)
                table.insert(candidates, {
                    path = path,
                    text = text,
                    numbers = numbers,
                    priority = isTarget and "TARGET" or "HIGH", -- contains enchant/stone keywords
                    nameHint = hasNameHint and true or false
                })
                local tag = isTarget and "TARGET" or "HIGH"
                local hint = hasNameHint and " (name-hint)" or ""
                print(string.format("[EnchantScan] %s: %s%s | Text: '%s' | Numbers: %s", 
                    tag, path, hint, text, joinNums(numbers, ", ")))
            
            -- Look for any text with numbers in reasonable range (50-ish)
            elseif visibleOk and #numbers > 0 then
                for _, num in ipairs(numbers) do
                    if num >= 10 and num <= 200 then -- likely item count range
                        local path = getFullPath(element)
                        table.insert(candidates, {
                            path = path,
                            text = text,
                            numbers = {num},
                            priority = (TARGET_COUNT and num == TARGET_COUNT) and "TARGET" or "MEDIUM",
                            nameHint = hasNameHint and true or false
                        })
                        local tag = (TARGET_COUNT and num == TARGET_COUNT) and "TARGET" or "MEDIUM"
                        local hint = hasNameHint and " (name-hint)" or ""
                        print(string.format("[EnchantScan] %s: %s%s | Text: '%s' | Number: %s", 
                            tag, path, hint, text, tostring(num)))
                        break
                    end
                end
            end
        end
    end
    
    -- Recurse through children
    for _, child in ipairs(element:GetChildren()) do
        scanElement(child, depth + 1)
    end
end

-- Scan specific areas first
local function scanSpecificAreas()
    local pg = plr:WaitForChild("PlayerGui")
    
    print("[EnchantScan] === SCANNING SPECIFIC AREAS ===")
    
    -- Backpack
    local backpack = pg:FindFirstChild("Backpack")
    if backpack then
        print("[EnchantScan] Scanning Backpack...")
        scanElement(backpack, 0)
    end
    
    -- Inventory
    local inventory = pg:FindFirstChild("Inventory")
    if inventory then
        print("[EnchantScan] Scanning Inventory...")
        scanElement(inventory, 0)
    end
    
    -- Exclusive Store
    local store = pg:FindFirstChild("Exclusive Store")
    if store then
        print("[EnchantScan] Scanning Exclusive Store...")
        scanElement(store, 0)
    end
    
    -- Roll Enchant
    local roll = pg:FindFirstChild("Roll Enchant")
    if roll then
        print("[EnchantScan] Scanning Roll Enchant...")
        scanElement(roll, 0)
    end
    
    -- Panel
    local panel = pg:FindFirstChild("Panel")
    if panel then
        print("[EnchantScan] Scanning Panel...")
        scanElement(panel, 0)
    end
end

-- Scan everything if specific areas don't yield results
local function scanEverything()
    local pg = plr:WaitForChild("PlayerGui")
    
    print("[EnchantScan] === SCANNING ALL PlayerGui ===")
    
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") or gui:IsA("GuiBase2d") then
            print(string.format("[EnchantScan] Scanning GUI: %s", gui.Name))
            scanElement(gui, 0)
        end
    end
    -- After generic scan, attempt name-based container scan too
    scanNamedContainers(pg)
end

-- Also check ReplicatedStorage for item definitions
local function checkReplicatedStorage()
    print("[EnchantScan] === CHECKING ReplicatedStorage ===")
    
    local items = ReplicatedStorage:FindFirstChild("Items")
    if items then
        local enchantStone = items:FindFirstChild("Enchant Stone")
        if enchantStone then
            print("[EnchantScan] Found ReplicatedStorage.Items['Enchant Stone']")
            if enchantStone:IsA("ModuleScript") then
                local ok, data = pcall(require, enchantStone)
                if ok then
                    print("[EnchantScan] Enchant Stone data:", game:GetService("HttpService"):JSONEncode(data))
                end
            end
        end
        
        local superEnchantStone = items:FindFirstChild("Super Enchant Stone")
        if superEnchantStone then
            print("[EnchantScan] Found ReplicatedStorage.Items['Super Enchant Stone']")
        end
    end
end

-- MAIN EXECUTION
print("[EnchantScan] Starting comprehensive Enchant Stone scan...")

checkReplicatedStorage()
scanSpecificAreas()

print(string.format("[EnchantScan] Scanned %d elements in specific areas", scanned))

if #candidates == 0 then
    print("[EnchantScan] No candidates found in specific areas, scanning everything...")
    scanned = 0
    scanEverything()
    print(string.format("[EnchantScan] Scanned %d total elements", scanned))
end

print("[EnchantScan] === SUMMARY ===")
print(string.format("[EnchantScan] Found %d candidates total", #candidates))

-- Group by priority
local highPriority = {}
local mediumPriority = {}

for _, candidate in ipairs(candidates) do
    if candidate.priority == "HIGH" then
        table.insert(highPriority, candidate)
    else
        table.insert(mediumPriority, candidate)
    end
end

if #highPriority > 0 then
    print("[EnchantScan] HIGH PRIORITY (contains 'enchant' or 'stone'):")
    for _, c in ipairs(highPriority) do
        print(string.format("  %s | '%s'", c.path, c.text))
    end
end

if #mediumPriority > 0 and #mediumPriority <= 20 then
    print("[EnchantScan] MEDIUM PRIORITY (numbers 10-200):")
    for _, c in ipairs(mediumPriority) do
        print(string.format("  %s | '%s'", c.path, c.text))
    end
elseif #mediumPriority > 20 then
    print(string.format("[EnchantScan] MEDIUM PRIORITY: %d candidates (too many to list)", #mediumPriority))
end

print("[EnchantScan] === END ===")

-- ===== SEND TO DISCORD =====
local outLines = {}
table.insert(outLines, string.format("Found %d candidates total", #candidates))

if #highPriority > 0 then
    table.insert(outLines, "\nHIGH/TARGET PRIORITY:")
    for _, c in ipairs(highPriority) do
        local nums = ""; if c.numbers and #c.numbers > 0 then nums = table.concat(c.numbers, ",") end
        local tag = c.priority or "HIGH"
        local hint = c.nameHint and " (name-hint)" or ""
        table.insert(outLines, string.format("[%s]%s %s | '%s' | nums=%s", tag, hint, c.path, c.text, nums))
    end
end

if #mediumPriority > 0 then
    table.insert(outLines, "\nMEDIUM PRIORITY:")
    for _, c in ipairs(mediumPriority) do
        local nums = ""; if c.numbers and #c.numbers > 0 then nums = table.concat(c.numbers, ",") end
        local tag = c.priority or "MEDIUM"
        local hint = c.nameHint and " (name-hint)" or ""
        table.insert(outLines, string.format("[%s]%s %s | '%s' | nums=%s", tag, hint, c.path, c.text, nums))
    end
end

sendDiscordTextBlocks("🔎 EnchantScan results", outLines)

return candidates
