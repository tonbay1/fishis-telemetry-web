-- Remote Spy - ดักจับ RemoteEvent/RemoteFunction เพื่อหา data flow จริงในเกม
-- หมายเหตุ: สคริปต์นี้ต้องการ executor ที่รองรับ getrawmetatable / setreadonly / getnamecallmethod

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local KEYWORDS = {
    "fish", "fishing", "rod", "bait", "inventory", "bag", "catch", "sell", "catalog", "shop", "item"
}

local function matches(name)
    name = string.lower(tostring(name or ""))
    for _, k in ipairs(KEYWORDS) do
        if string.find(name, k) then return true end
    end
    return false
end

local function safeJSON(val)
    local ok, res = pcall(function() return HttpService:JSONEncode(val) end)
    if ok then return res else return tostring(val) end
end

print("\n🔎=== REMOTE SPY START ===")

-- 1) Hook __namecall to log FireServer / InvokeServer outbounds
local canHook = (typeof(getrawmetatable) == "function") and (typeof(getnamecallmethod) == "function")
if not canHook then
    warn("❌ Executor does not expose required hook functions (getrawmetatable/getnamecallmethod)")
else
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    local oldIndex = mt.__index

    if typeof(setreadonly) == "function" then setreadonly(mt, false) end

    mt.__namecall = function(self, ...)
        local method = getnamecallmethod()
        if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
            if method == "FireServer" or method == "InvokeServer" then
                local args = {...}
                local name = self.Name
                if matches(name) then
                    local preview = {}
                    for i = 1, math.min(#args, 6) do
                        local v = args[i]
                        table.insert(preview, typeof(v) == "table" and safeJSON(v) or tostring(v))
                    end
                    print(string.format("📤 [%s] %s(%s)", method, self:GetFullName(), table.concat(preview, ", ")))
                else
                    -- Uncomment to log everything
                    -- print(string.format("📤 [%s] %s", method, self:GetFullName()))
                end
            end
        end
        return oldNamecall(self, ...)
    end

    if typeof(setreadonly) == "function" then setreadonly(mt, true) end

    print("✅ Hooked __namecall for FireServer/InvokeServer")
end

-- 2) Connect OnClientEvent to log inbound events to the client
local function connectClientEvents(root)
    local count = 0
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("RemoteEvent") then
            local name = inst.Name
            if matches(name) then
                count += 1
                inst.OnClientEvent:Connect(function(...)
                    local args = {...}
                    local preview = {}
                    for i = 1, math.min(#args, 6) do
                        local v = args[i]
                        table.insert(preview, typeof(v) == "table" and safeJSON(v) or tostring(v))
                    end
                    print(string.format("📥 [OnClientEvent] %s(%s)", inst:GetFullName(), table.concat(preview, ", ")))
                end)
            end
        end
    end
    print(string.format("🔗 Connected %d client events (filtered by keywords)", count))
end

connectClientEvents(ReplicatedStorage)

-- Optional: watch for new remotes created later
ReplicatedStorage.DescendantAdded:Connect(function(inst)
    if inst:IsA("RemoteEvent") and matches(inst.Name) then
        print("➕ New RemoteEvent detected:", inst:GetFullName())
        inst.OnClientEvent:Connect(function(...)
            local args = {...}
            local preview = {}
            for i = 1, math.min(#args, 6) do
                local v = args[i]
                table.insert(preview, typeof(v) == "table" and safeJSON(v) or tostring(v))
            end
            print(string.format("📥 [OnClientEvent] %s(%s)", inst:GetFullName(), table.concat(preview, ", ")))
        end)
    end
end)

print("🟢 Remote spy is active.")
print("➡️ Now perform actions: equip rod, cast line, catch fish, sell fish.")
print("➡️ Watch F9 Console for 📤 FireServer/InvokeServer and 📥 OnClientEvent logs.")
