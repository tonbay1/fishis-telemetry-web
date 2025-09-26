-- Executor Discord Telemetry - ใช้ฟังก์ชัน HTTP ของ executor แทน HttpService
-- เหตุผล: หลายเกม/สภาพแวดล้อมไม่อนุญาตให้ LocalScript ใช้ HttpService ออกอินเทอร์เน็ตได้
-- แต่ตัว executor มักมีฟังก์ชัน http_request/syn.request/request ที่ส่ง webhook ได้

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- ===== CONFIG =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1420473700507058269/jLjLrwLWMzIB4YJuTZ98qxlU1C3jZIUqVlQdz4oNLhnyAbuHCmDYsg-exQQFaJKFfelj"
local GAME_NAME = "FishIs"

-- ===== EXECUTOR HTTP DETECTION =====
local function findHttpRequest()
    -- ค้นหาฟังก์ชันของ executor ตามที่ใช้บ่อยที่สุด
    if typeof(syn) == "table" and typeof(syn.request) == "function" then
        return syn.request, "syn.request"
    end
    if typeof(http) == "table" and typeof(http.request) == "function" then
        return http.request, "http.request"
    end
    if typeof(request) == "function" then
        return request, "request"
    end
    if typeof(http_request) == "function" then
        return http_request, "http_request"
    end
    return nil, nil
end

local httpRequest, httpSource = findHttpRequest()
print("🔎 HTTP function:", httpSource or "<none> (will fallback to HttpService if possible)")

-- ===== SENDER WRAPPER =====
local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)

    if httpRequest then
        -- ใช้ฟังก์ชันของ executor
        local ok, res = pcall(function()
            return httpRequest({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body
            })
        end)

        if not ok then
            warn("❌ Executor HTTP error:", tostring(res))
            return false, tostring(res)
        end

        -- res อาจเป็น table ที่มี StatusCode, Body
        local code = (typeof(res) == "table" and res.StatusCode) or nil
        print("📡 Executor HTTP Status:", code or "<unknown>")
        if code == 200 or code == 204 then
            return true, res
        else
            -- บาง executor ไม่ใส่ StatusCode แต่จริงๆ ส่งได้ ให้ถือว่า ok ถ้าไม่มี error
            return code == nil, res
        end
    else
        -- Fallback: พยายามใช้ HttpService (มักจะถูกบล็อกบน client)
        local ok, res = pcall(function()
            return HttpService:RequestAsync({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body
            })
        end)
        if ok and typeof(res) == "table" then
            print("📡 HttpService Status:", res.StatusCode, res.StatusMessage)
            return (res.StatusCode == 200 or res.StatusCode == 204), res
        else
            warn("❌ HttpService RequestAsync failed:", tostring(res))
            return false, tostring(res)
        end
    end
end

-- ===== DATA COLLECT =====
local function collectBasic()
    local plr = Players.LocalPlayer
    if not plr then return { note = "no LocalPlayer" } end

    local data = {
        player = { name = plr.Name, id = plr.UserId, displayName = plr.DisplayName },
        game = GAME_NAME,
        ts = os.time(),
        time = os.date("%Y-%m-%d %H:%M:%S"),
    }

    -- leaderstats (ถ้ามี)
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        data.leaderstats = {}
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("ValueBase") then
                local ok, val = pcall(function() return v.Value end)
                data.leaderstats[v.Name] = ok and val or nil
            end
        end
    end

    -- Backpack items
    local bp = plr:FindFirstChild("Backpack")
    if bp then
        data.backpack = {}
        for _, it in ipairs(bp:GetChildren()) do
            table.insert(data.backpack, it.Name)
        end
    end

    return data
end

-- ===== MAIN =====
print("\n🚀 Executor Discord Telemetry starting...")
local basic = collectBasic()

-- สร้าง payload (content + embed)
local embedFields = {
    { name = "👤 Player", value = string.format("%s (%s)", basic.player and basic.player.name or "?", basic.player and basic.player.id or "?"), inline = true },
    { name = "⏰ Time", value = basic.time or "", inline = true },
}

if basic.leaderstats and next(basic.leaderstats) then
    local parts = {}
    for k, v in pairs(basic.leaderstats) do table.insert(parts, ("%s: %s"):format(k, tostring(v))) end
    table.insert(embedFields, { name = "📊 Leaderstats", value = table.concat(parts, "\n"), inline = false })
end
if basic.backpack and #basic.backpack > 0 then
    local txt = table.concat(basic.backpack, ", ")
    if #txt > 1000 then txt = txt:sub(1, 997) .. "..." end
    table.insert(embedFields, { name = "🎒 Backpack", value = txt, inline = false })
end

local payload = {
    content = "📡 Executor HTTP: " .. (httpSource or "(none)") .. " | Game: " .. GAME_NAME,
    embeds = { {
        title = "FishIs Telemetry (Executor)",
        description = "Collected via executor HTTP function",
        color = 3447003,
        fields = embedFields,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    } }
}

local ok, res = sendWebhook(payload)

if ok then
    print("✅ Webhook sent successfully via", httpSource or "HttpService")
else
    warn("❌ Failed to send webhook. Source:", httpSource or "HttpService")
    warn("   → See above logs for details")
end

-- UI toast แจ้งผล
pcall(function()
    local plr = Players.LocalPlayer; if not plr then return end
    local pg = plr:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui"); sg.Name = "ExecWebhookToast"; sg.Parent = pg
    local fr = Instance.new("Frame"); fr.Size = UDim2.new(0, 380, 0, 90); fr.Position = UDim2.new(1, -400, 0, 20)
    fr.BackgroundColor3 = ok and Color3.fromRGB(0,140,0) or Color3.fromRGB(150,0,0); fr.BackgroundTransparency = 0.15; fr.BorderSizePixel = 0; fr.Parent = sg
    local ui = Instance.new("UICorner"); ui.CornerRadius = UDim.new(0, 10); ui.Parent = fr
    local lb = Instance.new("TextLabel"); lb.Size = UDim2.new(1,-16,1,-16); lb.Position = UDim2.fromOffset(8,8); lb.BackgroundTransparency = 1
    lb.Text = ok and "✅ Sent telemetry via executor HTTP" or "❌ Failed to send telemetry"; lb.TextColor3 = Color3.new(1,1,1); lb.TextScaled = true; lb.Font = Enum.Font.SourceSansBold; lb.Parent = fr
    fr:TweenPosition(UDim2.new(1, -400, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.35, true)
    task.delay(6, function() fr:TweenPosition(UDim2.new(1, 20, 0, 20), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true); task.wait(0.35); sg:Destroy() end)
end)
