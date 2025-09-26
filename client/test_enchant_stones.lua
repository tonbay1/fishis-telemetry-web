-- test_enchant_stones.lua
-- Standalone tester to compare Enchant Stone counts from Replion vs GUI and print chosen values

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
if not plr then
    warn("[EnchantTest] No LocalPlayer")
    return
end

local DEBUG = true
local FORCE_GUI = false -- set true to ignore Replion and take GUI values as truth (for testing)

local function dprint(...)
    if DEBUG then print("[EnchantTest]", ...) end
end

local function normalizeKey(s)
    return tostring(s):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function extractQtyFields(t)
    return tonumber(t.Count) or tonumber(t.count) or tonumber(t.Amount) or tonumber(t.amount)
        or tonumber(t.Quantity) or tonumber(t.quantity) or tonumber(t.Qty) or tonumber(t.qty)
        or tonumber(t.Stack) or tonumber(t.stack)
end

local function textToNumber(s)
    if not s or s == "" then return nil end
    return tonumber(s:match("x%s*(%d+)%s*$")) or tonumber(s:match("(%d+)%s*$")) or tonumber(s:match("(%d+)"))
end

local result = {
    replion = { ES = nil, SES = nil },
    gui     = { ES = nil, SES = nil },
    chosen  = { ES = nil, SES = nil },
}

local function setMax(target, key, val)
    if not val or val <= 0 then return end
    local cur = target[key]
    target[key] = cur and math.max(cur, val) or val
end

-- Scan Replion for materials
local function scanReplion()
    local parents = {
        ReplicatedStorage:FindFirstChild("Packages"),
        ReplicatedStorage:FindFirstChild("Shared"),
        ReplicatedStorage:FindFirstChild("Modules")
    }

    local repliconNames = {"Data", "Inventory", "PlayerData", "Profile", "SaveData"}
    local probeKeys = {
        "Materials","Material","Currencies","Currency","Stones","Gems","Shards","Resources","InventoryMaterials","InventoryResource",
        "OwnedItems","Inventory","Backpack","Storage","Bag","Locker"
    }

    local visited = setmetatable({}, {__mode = "k"})
    local maxVisited = 4000
    local visitedCount = 0

    local function harvest(entry)
        if visitedCount > maxVisited then return end
        local t = typeof(entry)
        if t == "table" then
            if visited[entry] then return end
            visited[entry] = true
            visitedCount += 1

            -- name + qty style
            local name = entry.Name or entry.ItemName or entry.DisplayName
            local qty = extractQtyFields(entry)
            if name and qty and qty > 0 then
                local n = normalizeKey(name)
                if (n:find("super") and (n:find("enchant stone") or n:find("enchantstone"))) then
                    setMax(result.replion, "SES", qty)
                elseif (n:find("enchant stone") or n:find("enchantstone")) then
                    setMax(result.replion, "ES", qty)
                end
            end

            -- map style name -> count
            local added = 0
            for k, v in pairs(entry) do
                if typeof(k) == "string" and typeof(v) == "number" and v > 0 then
                    local nk = normalizeKey(k)
                    if (nk:find("super") and (nk:find("enchant stone") or nk:find("enchantstone"))) then
                        setMax(result.replion, "SES", v)
                        added += 1
                    elseif (nk:find("enchant stone") or nk:find("enchantstone")) then
                        setMax(result.replion, "ES", v)
                        added += 1
                    end
                    if added > 50 then break end
                end
            end

            -- recurse
            local cnt = 0
            for k, v in pairs(entry) do
                harvest(v)
                cnt += 1
                if cnt > 800 then break end
            end
        end
    end

    for _, parent in ipairs(parents) do
        if parent then
            local replion = parent:FindFirstChild("Replion")
            if replion then
                local ok, Client = pcall(require, replion)
                if ok and Client and Client.Client and Client.Client.WaitReplion then
                    for _, rname in ipairs(repliconNames) do
                        local replicon = Client.Client:WaitReplion(rname, 2)
                        if replicon then
                            dprint("Replion found:", rname)
                            for _, key in ipairs(probeKeys) do
                                local okGet, value = pcall(function() return replicon:GetExpect(key) end)
                                if okGet and value ~= nil then
                                    dprint("Probe hit:", rname .. "." .. key, "type=", typeof(value))
                                    harvest(value)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Scan GUI for visible counts
local function scanGUI()
    local pg = plr:WaitForChild("PlayerGui")

    local function parseContainer(container)
        if not container then return end
        for _, d in ipairs(container:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = d.Text or ""
                if #t > 0 then
                    local tl = t:lower()
                    local num = textToNumber(t)
                    if num and num > 0 then
                        if (tl:find("super") and (tl:find("enchant stone") or tl:find("enchantstone"))) then
                            setMax(result.gui, "SES", num)
                        elseif (tl:find("enchant stone") or tl:find("enchantstone")) then
                            setMax(result.gui, "ES", num)
                        end
                    end
                end
            end
        end
    end

    -- Backpack.Display
    local backpack = pg:FindFirstChild("Backpack")
    if backpack then parseContainer(backpack:FindFirstChild("Display")) end

    -- Exclusive Store tiles
    local store = pg:FindFirstChild("Exclusive Store")
    if store then
        local ok = pcall(function()
            parseContainer(store.Main.Content.Items.Stone["Enchant Stone"])
        end)
        if not ok then dprint("Exclusive Store Enchant Stone tile not accessible") end
        local ok2 = pcall(function()
            parseContainer(store.Main.Content.Items.Stone["Super Enchant Stone"])
        end)
        if not ok2 then dprint("Exclusive Store Super Enchant Stone tile not accessible") end
    end

    -- Roll Enchant
    parseContainer(pg:FindFirstChild("Roll Enchant"))
end

-- MAIN
scanReplion()
scanGUI()

if FORCE_GUI then
    result.chosen.ES  = result.gui.ES or result.replion.ES
    result.chosen.SES = result.gui.SES or result.replion.SES
else
    -- Prefer Replion if present
    result.chosen.ES  = result.replion.ES or result.gui.ES
    result.chosen.SES = result.replion.SES or result.gui.SES
end

print("[EnchantTest] ========= SUMMARY =========")
print(string.format("[EnchantTest] Enchant Stone       | Replion=%s | GUI=%s | Chosen=%s",
    tostring(result.replion.ES), tostring(result.gui.ES), tostring(result.chosen.ES)))
print(string.format("[EnchantTest] Super Enchant Stone | Replion=%s | GUI=%s | Chosen=%s",
    tostring(result.replion.SES), tostring(result.gui.SES), tostring(result.chosen.SES)))
print("[EnchantTest] ==================================")

-- Guidance
if result.replion.ES and result.gui.ES and result.replion.ES ~= result.gui.ES then
    dprint("Mismatch detected for Enchant Stone: Replion vs GUI. Replion may lag a bit after usage.")
end
if result.replion.SES and result.gui.SES and result.replion.SES ~= result.gui.SES then
    dprint("Mismatch detected for Super Enchant Stone: Replion vs GUI.")
end

return result
