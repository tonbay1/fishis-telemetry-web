-- Scan Knit/KnitClient Services and common data containers
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local function log(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
    print(table.concat(parts, ' '))
end

local function tryRequire(mod)
    local ok, res = pcall(require, mod)
    if ok then
        local t = typeof(res)
        log("  ✅ require ->", t)
        return res
    else
        log("  ❌ require error:", res)
    end
end

print("\n🔎=== SCAN KNIT SERVICES ===")

-- Try common entry points
local KnitFolder = ReplicatedStorage:FindFirstChild("Knit") or ReplicatedStorage:FindFirstChild("KnitClient")
if KnitFolder and KnitFolder:IsA("Folder") then
    log("Found Knit folder:", KnitFolder:GetFullName())

    -- Services folder pattern
    local servicesFolder = KnitFolder:FindFirstChild("Services")
    if servicesFolder and servicesFolder:IsA("Folder") then
        local services = servicesFolder:GetChildren()
        log("Services count:", #services)
        for _, s in ipairs(services) do
            if s:IsA("ModuleScript") then
                log("  • Service module:", s.Name)
            end
        end
    else
        log("Services folder not found under Knit. Will scan descendants for Service modules...")
        local count = 0
        for _, d in ipairs(KnitFolder:GetDescendants()) do
            if d:IsA("ModuleScript") and (string.find(string.lower(d.Name), "service") or string.find(string.lower(d.Name), "controller")) then
                count += 1
                log("  • Candidate:", d:GetFullName())
            end
        end
        if count == 0 then log("  (no service/controller modules found)") end
    end

    -- Try require main Knit module if present
    local KnitMain = KnitFolder:FindFirstChild("Knit") or KnitFolder:FindFirstChild("KnitClient")
    if KnitMain and KnitMain:IsA("ModuleScript") then
        log("Trying to require:", KnitMain:GetFullName())
        local K = tryRequire(KnitMain)
        if typeof(K) == "table" then
            -- Heuristics: print keys
            local keys = {}
            local n = 0
            for k, v in pairs(K) do
                n += 1
                table.insert(keys, tostring(k))
            end
            log("Knit keys:", n, table.concat(keys, ", "))
            if typeof(K.GetService) == "function" then
                log("Knit has GetService() – you can try K.GetService('SomeService') from console once you know the name.")
            end
        end
    end
else
    log("Knit/KnitClient folder not found in ReplicatedStorage")
end

print("✅ Done. Now check output and note service or controller names. Then we can hook the right data.")
