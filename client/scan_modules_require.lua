-- Scan Modules and Require - ค้นหาโมดูลที่น่าจะเก็บ data/catalog/inventory แล้วลอง require เพื่อดูโครงสร้าง
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer

local KEYWORDS = {
    "Fish", "Fishing", "Rod", "Bait", "Inventory", "Bag", "Item", "Catalog", "Shop",
    "Data", "Config", "Stats", "Replica", "ReplicaService", "Replion", "Knit"
}

local MAX_KEYS = 30
local MAX_PREVIEW_LEN = 140

local function matchesKeyword(name)
    name = string.lower(name or "")
    for _, k in ipairs(KEYWORDS) do
        if string.find(name, string.lower(k)) then return true end
    end
    return false
end

local function fullName(obj)
    if not obj then return "nil" end
    local ok, name = pcall(function() return obj:GetFullName() end)
    return ok and name or obj.Name
end

local function previewValue(v)
    local t = typeof(v)
    if t == "table" then
        local count = 0
        for _ in pairs(v) do count += 1 end
        return string.format("<table keys=%d>", count)
    elseif t == "string" then
        local s = v
        if #s > MAX_PREVIEW_LEN then s = string.sub(s, 1, MAX_PREVIEW_LEN) .. "..." end
        return string.format("\"%s\"", s)
    elseif t == "Instance" then
        return "Instance(" .. v.ClassName .. ":" .. v.Name .. ")"
    else
        return tostring(v)
    end
end

local function safeJSONEncode(tbl)
    local ok, res = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then return res else return "<json error>" end
end

print("\n🔎=== SCAN MODULES & REQUIRE ===")

local candidates = {}

local function collectModules(root, rootName)
    local found = 0
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("ModuleScript") and matchesKeyword(inst.Name) then
            table.insert(candidates, {root = rootName, mod = inst})
            found += 1
        end
    end
    print(string.format("%s -> %d matching modules", rootName, found))
end

collectModules(ReplicatedStorage, "ReplicatedStorage")
if localPlayer then
    local ps = localPlayer:FindFirstChild("PlayerScripts")
    if ps then
        collectModules(ps, "PlayerScripts")
    else
        print("PlayerScripts: <none>")
    end
end

print(string.format("\n📦 Total candidates: %d", #candidates))

for i, item in ipairs(candidates) do
    local mod = item.mod
    print(string.format("\n[%d/%d] Requiring: %s", i, #candidates, fullName(mod)))
    local ok, res = pcall(require, mod)
    if not ok then
        print("  ❌ require error:", tostring(res))
    else
        local t = typeof(res)
        print("  ✅ require type:", t)
        if t == "table" then
            -- summarize top-level keys
            local keys = {}
            local keyCount = 0
            for k, v in pairs(res) do
                keyCount += 1
                if #keys < MAX_KEYS then
                    table.insert(keys, string.format("%s=%s", tostring(k), previewValue(v)))
                end
            end
            print(string.format("  📊 keys: %d (showing up to %d)", keyCount, MAX_KEYS))
            print("  → ", table.concat(keys, ", "))
        elseif t == "function" then
            print("  ℹ️ module returned a function (call site unknown)")
        else
            print("  ℹ️ value:", previewValue(res))
        end
    end
end

print('\n✅ Done. Open F9 to view results. Note modules may lazy-load; trigger UI/menus then rerun.')
