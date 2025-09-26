-- find_stones_complete.lua
-- สแกนหาหิน Enchant Stone ทุกที่ในเกม + ModuleScript + ทุกอย่าง

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer

print("🔍 กำลังหาหิน Enchant Stone ทุกที่ในเกม (รวม ModuleScript)...")

local found = {}
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"

-- ฟังก์ชันแปลง string เป็น number อย่างปลอดภัย
local function safeNumber(str)
    if type(str) == "number" then return str end
    if type(str) ~= "string" then return 0 end
    str = str:gsub(",", "")
    local n = tonumber(str)
    return n or 0
end

-- ฟังก์ชันสรุป table แบบสั้น
local function summarizeTable(t, depth)
    depth = depth or 0
    if depth > 2 then return "..." end
    if type(t) ~= "table" then return tostring(t) end
    local out = {}
    local count = 0
    for k,v in pairs(t) do
        count = count + 1
        if count > 20 then table.insert(out, "...") break end
        if type(v) == "table" then
            table.insert(out, tostring(k).."={"..summarizeTable(v, depth+1).."}")
        else
            table.insert(out, tostring(k).."="..tostring(v))
        end
    end
    return table.concat(out, ", ")
end

-- ส่งผลลัพธ์ไป Discord
local function sendDiscordBlocks(title, lines)
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
        local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
        if ok then
            local req = (request or http_request or (syn and syn.request))
            if req then
                req({
                    Url = WEBHOOK_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = encoded,
                })
            else
                pcall(function()
                    HttpService:PostAsync(WEBHOOK_URL, encoded, Enum.HttpContentType.ApplicationJson)
                end)
            end
        end
    end
end

-- 1. สแกน Player attributes
local function scanPlayerAttributes()
    print("👤 กำลังสแกน Player attributes...")
    for name, value in pairs(plr:GetAttributes()) do
        local nameStr = tostring(name):lower()
        if (nameStr:find("enchant") and nameStr:find("stone")) or nameStr:find("material") or nameStr:find("หิน") then
            local info = string.format("🔍 Attribute: %s = %s", name, tostring(value))
            print(info)
            table.insert(found, info)
        end
    end
end

-- 2. สแกน leaderstats
local function scanLeaderstats()
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        print("📊 กำลังสแกน leaderstats...")
        for _, stat in ipairs(leaderstats:GetChildren()) do
            local name = stat.Name:lower()
            if (name:find("enchant") and name:find("stone")) or name:find("material") or name:find("stone") or name:find("หิน") then
                local value = stat.Value
                local info = string.format("📊 Leaderstat: %s = %s", stat.Name, tostring(value))
                print(info)
                table.insert(found, info)
            end
        end
    end
end

-- 3. สแกนทุก GUI ใน PlayerGui + ImageLabel + ValueObject + Attribute
local function scanAllGUIs()
    local pg = plr:WaitForChild("PlayerGui")
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") or gui:IsA("GuiBase2d") then
            print(string.format("📂 กำลังสแกน GUI: %s", gui.Name))
            for _, descendant in ipairs(gui:GetDescendants()) do
                -- ValueObject
                if descendant:IsA("IntValue") or descendant:IsA("NumberValue") then
                    local n = safeNumber(descendant.Value)
                    local name = descendant.Name:lower()
                    if n > 0 and (name:find("amount") or name:find("count") or name:find("quantity") or name:find("stack") or name:find("value") or name:find("stone") or name:find("enchant") or name:find("หิน")) then
                        print(string.format("🪨 พบ ValueObject %s = %d | Path: %s", descendant.Name, n, descendant:GetFullName()))
                        table.insert(found, string.format("🪨 ValueObject %s = %d | Path: %s", descendant.Name, n, descendant:GetFullName()))
                    end
                end
                -- Attribute
                if descendant.GetAttributes then
                    local attrs = descendant:GetAttributes()
                    for attr, val in pairs(attrs) do
                        local attrLow = tostring(attr):lower()
                        local num = safeNumber(val)
                        if num > 0 and (attrLow:find("amount") or attrLow:find("count") or attrLow:find("quantity") or attrLow:find("stack") or attrLow:find("value") or attrLow:find("stone") or attrLow:find("enchant") or attrLow:find("หิน")) then
                            print(string.format("🪨 พบ Attribute %s = %s (num=%d) | Path: %s", attr, tostring(val), num, descendant:GetFullName()))
                            table.insert(found, string.format("🪨 Attribute %s = %s (num=%d) | Path: %s", attr, tostring(val), num, descendant:GetFullName()))
                        end
                    end
                end
                -- TextLabel/TextButton
                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                    local text = descendant.Text or ""
                    if #text > 0 then
                        local lowerText = text:lower()
                        if (lowerText:find("enchant") and lowerText:find("stone")) or lowerText:find("enchantstone") or lowerText:find("หินมนต") then
                            local numbers = {}
                            for num in text:gmatch("%d+") do
                                local n = safeNumber(num)
                                if n > 0 and n <= 10000 then
                                    table.insert(numbers, n)
                                end
                            end
                            if #numbers > 0 then
                                local path = descendant:GetFullName()
                                local info = string.format("🪨 เจอ: '%s' | ตัวเลข: %s | ที่: %s", text, table.concat(numbers, ","), path)
                                print(info)
                                table.insert(found, info)
                            end
                        end
                    end
                end
                -- ImageLabel
                if descendant:IsA("ImageLabel") and (descendant.Name:lower():find("enchant") or descendant.Name:find("หินมนต")) then
                    print("🪨 พบ ImageLabel หินมนตร์:", descendant:GetFullName())
                    local foundCount = false
                    for _, child in ipairs(descendant:GetChildren()) do
                        if child:IsA("TextLabel") then
                            print("   จำนวน (TextLabel):", child.Text)
                            local val = safeNumber(child.Text)
                            table.insert(found, string.format("🪨 ImageLabel %s | จำนวน (TextLabel): %s (num=%d)", descendant:GetFullName(), child.Text, val))
                            foundCount = true
                        elseif child:IsA("IntValue") or child:IsA("NumberValue") then
                            print("   จำนวน (Value):", child.Value)
                            local val = safeNumber(child.Value)
                            table.insert(found, string.format("🪨 ImageLabel %s | จำนวน (Value): %s (num=%d)", descendant:GetFullName(), tostring(child.Value), val))
                            foundCount = true
                        end
                    end
                    if descendant.GetAttributes then
                        local attrs = descendant:GetAttributes()
                        for attr, val in pairs(attrs) do
                            local num = safeNumber(val)
                            print("   Attribute:", attr, val, "(num=", num, ")")
                            table.insert(found, string.format("🪨 ImageLabel %s | Attribute: %s = %s (num=%d)", descendant:GetFullName(), attr, tostring(val), num))
                            foundCount = true
                        end
                    end
                    if not foundCount then
                        table.insert(found, string.format("🪨 ImageLabel %s | ไม่พบจำนวน (ไม่มี Text/Value/Attribute)", descendant:GetFullName()))
                    end
                end
            end
        end
    end
end

-- 4. สแกน ReplicatedStorage, Backpack, Player, DataModel
local function scanAllServices()
    local Services = {
        game:GetService("ReplicatedStorage"),
        game:GetService("Players"):FindFirstChild(game.Players.LocalPlayer.Name),
        game:GetService("Players"):FindFirstChild(game.Players.LocalPlayer.Name) and game:GetService("Players"):FindFirstChild(game.Players.LocalPlayer.Name):FindFirstChild("Backpack"),
        game
    }
    for _, service in ipairs(Services) do
        if service then
            print("\n===== สแกน: " .. service:GetFullName() .. " =====")
            for _, descendant in ipairs(service:GetDescendants()) do
                -- ValueObject
                if descendant:IsA("IntValue") or descendant:IsA("NumberValue") then
                    local n = safeNumber(descendant.Value)
                    local name = descendant.Name:lower()
                    if n > 0 and (name:find("amount") or name:find("count") or name:find("quantity") or name:find("stack") or name:find("value") or name:find("stone") or name:find("enchant") or name:find("หิน")) then
                        print(string.format("🪨 [Service] ValueObject %s = %d | Path: %s", descendant.Name, n, descendant:GetFullName()))
                        table.insert(found, string.format("🪨 [Service] ValueObject %s = %d | Path: %s", descendant.Name, n, descendant:GetFullName()))
                    end
                end
                -- Attribute
                if descendant.GetAttributes then
                    local attrs = descendant:GetAttributes()
                    for attr, val in pairs(attrs) do
                        local attrLow = tostring(attr):lower()
                        local num = safeNumber(val)
                        if num > 0 and (attrLow:find("amount") or attrLow:find("count") or attrLow:find("quantity") or attrLow:find("stack") or attrLow:find("value") or attrLow:find("stone") or attrLow:find("enchant") or attrLow:find("หิน")) then
                            print(string.format("🪨 [Service] Attribute %s = %s (num=%d) | Path: %s", attr, tostring(val), num, descendant:GetFullName()))
                            table.insert(found, string.format("🪨 [Service] Attribute %s = %s (num=%d) | Path: %s", attr, tostring(val), num, descendant:GetFullName()))
                        end
                    end
                end
            end
        end
    end
end

-- 5. สแกนและ require ทุก ModuleScript
local function scanAndRequireModuleScripts()
    print("\n===== สแกนและ require ModuleScript =====")
    local locations = {
        game:GetService("ReplicatedStorage"),
        game:GetService("Players"):FindFirstChild(game.Players.LocalPlayer.Name),
        game:GetService("Players"):FindFirstChild(game.Players.LocalPlayer.Name) and game:GetService("Players"):FindFirstChild(game.Players.LocalPlayer.Name):FindFirstChild("PlayerGui"),
    }
    local moduleResults = {}
    for _, parent in ipairs(locations) do
        if parent then
            for _, descendant in ipairs(parent:GetDescendants()) do
                if descendant:IsA("ModuleScript") then
                    local ok, data = pcall(require, descendant)
                    local header = string.format("📦 ModuleScript: %s", descendant:GetFullName())
                    if ok then
                        local summary = summarizeTable(data)
                        table.insert(moduleResults, header.."\n"..summary)
                        print("[ModuleScript] ", header, summary)
                    else
                        table.insert(moduleResults, header.."\n[require ERROR] "..tostring(data))
                        print("[ModuleScript ERROR] ", header, data)
                    end
                end
            end
        end
    end
    -- ส่งไป Discord (แบ่ง block ถ้ายาว)
    if #moduleResults > 0 then
        sendDiscordBlocks("📦 ผลการ require ModuleScript ทั้งหมด:", moduleResults)
    else
        sendDiscordBlocks("📦 ผลการ require ModuleScript ทั้งหมด:", {"ไม่พบ ModuleScript หรือ require ไม่สำเร็จ"})
    end
end

-- เริ่มสแกน
scanPlayerAttributes()
scanLeaderstats()
scanAllGUIs()
scanAllServices()
scanAndRequireModuleScripts()

print("\n" .. string.rep("=", 50))
print("📋 สรุปผลการค้นหา:")

if #found > 0 then
    for i, info in ipairs(found) do
        print(string.format("%d. %s", i, info))
    end
    sendDiscordBlocks("📋 ผลการค้นหาหิน/Value ทั้งหมด:", found)
else
    print("❌ ไม่เจอหิน Enchant Stone เลย")
    print("💡 ลองเปิด Backpack/Inventory ในเกมก่อน แล้วรันสคริปต์ใหม่")
    sendDiscordBlocks("📋 ผลการค้นหาหิน/Value ทั้งหมด:", {"❌ ไม่เจอหิน Enchant Stone เลย"})
end
print(string.rep("=", 50))

return found
