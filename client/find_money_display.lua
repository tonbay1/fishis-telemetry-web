-- Find Money Display - ค้นหา TextLabel ที่แสดงเงินจริง (2.29M)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local plr = Players.LocalPlayer
if not plr then
    warn("❌ No LocalPlayer")
    return
end

print("🔍 Searching for money display...")

-- Helper function to check if text looks like money
local function looksLikeMoney(text)
    if not text or #text == 0 then return false end
    
    -- Check for patterns like "2.29M", "1.5K", "1,234", etc.
    if string.match(text, "%d+%.%d+[MK]") then return true end -- 2.29M, 1.5K
    if string.match(text, "%d+[MK]") then return true end -- 2M, 5K
    if string.match(text, "%d+,%d+") then return true end -- 1,234
    if string.match(text, "^%d+$") and tonumber(text) and tonumber(text) > 1000 then return true end -- Large numbers
    
    return false
end

-- Search all GUI for money displays
local function searchForMoneyDisplay()
    local pg = plr:WaitForChild("PlayerGui")
    local moneyDisplays = {}
    
    local function scanElement(element, path, depth)
        if not element or depth > 6 then return end
        
        -- Check TextLabels for money-like text
        if element:IsA("TextLabel") then
            local text = element.Text
            if looksLikeMoney(text) then
                table.insert(moneyDisplays, {
                    path = path,
                    text = text,
                    element = element
                })
                print("💰 Found money display:", path, "=", text)
            end
        end
        
        -- Also check TextButtons
        if element:IsA("TextButton") then
            local text = element.Text
            if looksLikeMoney(text) then
                table.insert(moneyDisplays, {
                    path = path,
                    text = text,
                    element = element
                })
                print("💰 Found money display (button):", path, "=", text)
            end
        end
        
        -- Recursively scan children
        for _, child in ipairs(element:GetChildren()) do
            scanElement(child, path .. "." .. child.Name, depth + 1)
        end
    end
    
    -- Scan all ScreenGuis
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            scanElement(gui, "PlayerGui." .. gui.Name, 0)
        end
    end
    
    return moneyDisplays
end

-- Search for money displays
local moneyDisplays = searchForMoneyDisplay()

print(string.format("\n📊 Found %d money displays:", #moneyDisplays))

if #moneyDisplays == 0 then
    print("❌ No money displays found!")
    print("💡 Try:")
    print("  - Opening different GUI windows in game")
    print("  - Looking at the top/corner of screen where money is usually shown")
else
    -- Show all found displays
    for i, display in ipairs(moneyDisplays) do
        print(string.format("%d. %s = '%s'", i, display.path, display.text))
        
        -- Try to get more info about this element
        local element = display.element
        local attrs = element:GetAttributes()
        if next(attrs) then
            print("   Attributes:", HttpService:JSONEncode(attrs))
        end
        
        -- Check parent for context
        local parent = element.Parent
        if parent then
            print("   Parent:", parent.Name, "(" .. parent.ClassName .. ")")
        end
    end
    
    -- Try to find the main money display (usually the largest value)
    local maxValue = 0
    local mainDisplay = nil
    
    for _, display in ipairs(moneyDisplays) do
        local text = display.text
        local value = 0
        
        -- Parse value
        local number, suffix = string.match(text, "([%d%.,%s]+)([MKmk]?)")
        if number then
            number = number:gsub(",", ""):gsub("%s", "")
            value = tonumber(number) or 0
            
            if suffix then
                suffix = string.upper(suffix)
                if suffix == "M" then
                    value = value * 1000000
                elseif suffix == "K" then
                    value = value * 1000
                end
            end
        end
        
        if value > maxValue then
            maxValue = value
            mainDisplay = display
        end
    end
    
    if mainDisplay then
        print(string.format("\n🎯 Main money display: %s = '%s' (%s coins)", 
            mainDisplay.path, mainDisplay.text, tostring(maxValue)))
    end
end

print("\n💡 Use this information to update the inventory script with the correct path!")
