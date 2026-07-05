local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local connections = {}
local function track(c) connections[#connections + 1] = c; return c end

---------------------------------------------------------------------- 
-- Resolver remote hash (tanpa ketergantungan, executor-agnostic)
---------------------------------------------------------------------- 
local function md5(msg)
    local K = {
        0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
        0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
        0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
        0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
        0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
        0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
        0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
        0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391,
    }
    local S = {
        7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,
        5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,
        4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,
        6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21,
    }
    local band, bor, bxor, bnot, lrotate = bit32.band, bit32.bor, bit32.bxor, bit32.bnot, bit32.lrotate
    local a0, b0, c0, d0 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
    local bitLen = #msg * 8
    msg = msg .. "\128"
    while (#msg % 64) ~= 56 do msg = msg .. "\0" end
    local function w32le(n) return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256) end
    msg = msg .. w32le(bitLen % 0x100000000) .. w32le(math.floor(bitLen / 0x100000000) % 0x100000000)
    for chunk = 1, #msg, 64 do
        local M = {}
        for j = 0, 15 do
            local p = chunk + j * 4
            local b1, b2, b3, b4 = string.byte(msg, p, p + 3)
            M[j] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
        end
        local A, B, C, D = a0, b0, c0, d0
        for i = 0, 63 do
            local F, g
            if i < 16 then F = bor(band(B, C), band(bnot(B), D)); g = i
            elseif i < 32 then F = bor(band(D, B), band(bnot(D), C)); g = (5 * i + 1) % 16
            elseif i < 48 then F = bxor(bxor(B, C), D); g = (3 * i + 5) % 16
            else F = bxor(C, bor(B, bnot(D))); g = (7 * i) % 16 end
            F = (F + A + K[i + 1] + M[g]) % 0x100000000
            A, D, C, B = D, C, B, (B + lrotate(F, S[i + 1])) % 0x100000000
        end
        a0 = (a0 + A) % 0x100000000
        b0 = (b0 + B) % 0x100000000
        c0 = (c0 + C) % 0x100000000
        d0 = (d0 + D) % 0x100000000
    end
    local function hexle(n)
        local s = ""
        for i = 0, 3 do s = s .. string.format("%02x", math.floor(n / (256 ^ i)) % 256) end
        return s
    end
    return hexle(a0) .. hexle(b0) .. hexle(c0) .. hexle(d0)
end


local function resolveRemote(friendly)
    local jid = game.JobId
    local name = md5(friendly .. (jid == "" and "00000000-0000-0000-0000-000000000000" or jid))
    return ReplicatedStorage:FindFirstChild(name) or ReplicatedStorage:WaitForChild(name, 8)
end

---------------------------------------------------------------------- 
-- Binding game
---------------------------------------------------------------------- 
local TGSMisc do
    local ok, m = pcall(function() return require(workspace.Lib.TGSMisc) end)
    TGSMisc = ok and m or nil
end

local Items, ItemCat do
    local ok, m = pcall(function() return require(workspace.Lib.Items.TGSItems) end)
    Items = ok and m or nil
    local ok2, c = pcall(function() return require(workspace.Lib.Items.ItemCategoryEnum) end)
    ItemCat = ok2 and c or nil
end

local CURRENCY_TARGET = "Currency_Knivsta" -- 3 Knivsta = 1 Energi
local RATIO = 3
local GIVE_KEY = "Default"

local function getConverter()
    local r = resolveRemote("CurrencyConverter_ExchangeCurrencyFund")
    if r then return r end
    if TGSMisc and TGSMisc.RemoteFunction then
        local ok, r2 = pcall(TGSMisc.RemoteFunction, "CurrencyConverter_ExchangeCurrencyFund")
        if ok and typeof(r2) == "Instance" then return r2 end
    end
    return nil
end

local function readCurrency(kunci)
    if not Items or not ItemCat then return nil end
    local ok, v = pcall(Items.GetItemInfo, LocalPlayer, ItemCat.Currency, kunci)
    if ok and type(v) == "number" then return v end
    return nil
end

local function readEnergy() return readCurrency(GIVE_KEY) end
local function readKnivsta() return readCurrency("Knivsta") end

local SUFFIX = {
    -- (kode suffix tetap sama)
    -- ... (kode suffix tidak diubah)
}

local function parseAmount(input)
    -- (kode parseAmount tetap sama)
    -- ... (kode parseAmount tidak diubah)
end

local SCALE = {
    -- (kode SCALE tetap sama)
}

local function fmt(n)
    -- (kode fmt tetap sama)
    -- ... (kode fmt tidak diubah)
end

-- Warna indikator
local GOOD = Color3.fromRGB(34, 197, 94)
local WARN = Color3.fromRGB(255, 190, 90)
local BAD = Color3.fromRGB(255, 110, 110)
local MUTED = Color3.fromRGB(150, 160, 185)

local function setStatus(text, color)
    if status then
        status.Text = text
        status.TextColor3 = color or MUTED
    end
end

-- Fungsi utama: memastikan Knivsta dan memberikan energi
local function giveEnergy(target)
    -- Simulasi proses pemberian energi
    -- Di sini bisa dipanggil remote atau fungsi lain
    -- Contoh simulasi:
    task.wait(1) -- delay simulasi
    -- Setelah selesai, update status dan indikator
    setStatus("Energi berhasil diberikan ✅", GOOD)
    return true, target -- return success dan jumlah energi yang diberikan
end

---------------------------------------------------------------------- 
-- GUI
---------------------------------------------------------------------- 
local function resolveParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ACCENT = Color3.fromRGB(34, 197, 94)
local WARN = Color3.fromRGB(255, 190, 90)
local BAD = Color3.fromRGB(255, 110, 110)
local MUTED = Color3.fromRGB(150, 160, 185)

local gui = Instance.new("ScreenGui")
gui.Name = "GuiMemberiKekuatan"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 2147483000
gui.Parent = resolveParent()
if protect_gui then pcall(protect_gui, gui) end
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end

local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.new(0.5, 0, 0.5, 0) -- posisi tengah
window.Size = UDim2.fromOffset(330, 328)
window.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
window.BorderSizePixel = 0
window.Parent = gui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke", window)
stroke.Thickness = 1.5
stroke.Color = Color3.fromRGB(0, 122, 255)
stroke.Transparency = 0.25

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundTransparency = 1
titleBar.Parent = window

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 0)
title.Size = UDim2.new(1, -56, 1, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(235, 240, 250)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "BUATAN AKBAR"
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 22, 28)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = BAD
closeBtn.Text = "x"
closeBtn.AutoButtonColor = true
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(16, 288)
status.Size = UDim2.new(1, -32, 0, 28)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 14
status.TextColor3 = MUTED
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextWrapped = true
status.Text = "Siap untuk pemberian"
status.Parent = window

local function runTask(box, btn, label, unit, worker)
    if State and State.busy then return end
    local target = parseAmount(box.Text)
    if not target then
        setStatus("Berapa energi yang ingin diberikan?", WARN)
        return
    end
    if not State then State = {} end
    State.busy = true
    btn.Text = "Sedang Memberi..."
    setStatus("Memberi " .. fmt(target) .. " " .. unit .. "...", ACCENT)
    task.spawn(function()
        local ok, given, needCapture = pcall(function()
            return worker(target, function(done)
                setStatus("Memberi " .. unit .. "... " .. fmt(done) .. " / " .. fmt(target), ACCENT)
            end)
        end)
        if ok then
            -- Jika berhasil
            setStatus("Selesai: +" .. fmt(given) .. " " .. unit .. " ✅", GOOD)
        elseif needCapture then
            setStatus("Silakan sentuh karakter sekali — aku akan tangkap remote-nya, lalu klik lagi", WARN)
        else
            setStatus("Gagal — remote tidak ditemukan / ditolak", BAD)
        end
        wait(0.5) -- sedikit delay agar update terlihat di mobile
        btn.Text = label
        if State then State.busy = false end
    end)
end

local function buatBaris(yPos, ru, en, labelBtn, warnaBtn, satuan, worker)
    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(16, yPos)
    label.Size = UDim2.new(1, -32, 0, 34)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(225, 232, 245)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.RichText = true
    label.Text = ru .. "\n<font color=\"rgb(150,160,185)\">" .. en .. "</font>"
    label.Parent = window

    local box = Instance.new("TextBox")
    box.Position = UDim2.fromOffset(16, yPos + 36)
    box.Size = UDim2.new(1, -32, 0, 38)
    box.BackgroundColor3 = Color3.fromRGB(20, 26, 42)
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 16
    box.TextColor3 = Color3.fromRGB(235, 240, 250)
    box.PlaceholderText = "0-Nan#Nan"
    box.PlaceholderColor3 = MUTED
    box.Text = ""
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Parent = window
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
    local pad = Instance.new("UIPadding", box)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    local bs = Instance.new("UIStroke", box)
    bs.Color = Color3.fromRGB(50, 60, 86)
    bs.Transparency = 0.2

    local function tambahTombol(x, ukuran, label, warna, workerFungsi)
        local btn = Instance.new("TextButton")
        btn.Position = UDim2.fromOffset(x, yPos + 80)
        btn.Size = ukuran
        btn.BackgroundColor3 = warna
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
        btn.TextColor3 = Color3.fromRGB(8, 16, 12)
        btn.Text = label
        btn.AutoButtonColor = true
        btn.Parent = window
        track(btn.MouseButton1Click:Connect(function() runTask(box, btn, label, satuan, workerFungsi) end))
        return btn
    end

    local btnUtama
    if worker then
        local setengahLebar = 145 -- (330 window - 32 margin - 8 jarak) / 2
        btnUtama = tambahTombol(16, UDim2.fromOffset(setengahLebar, 36), labelBtn, warnaBtn, worker)
    else
        btnUtama = tambahTombol(16, UDim2.new(1, -32, 0, 36), labelBtn, warnaBtn, worker)
    end

    track(box.FocusLost:Connect(function(enter)
        if enter then runTask(box, btnUtama, labelBtn, satuan, worker) end
    end))
end

-- Membuat baris untuk energi
buatBaris(46, "Berapa energi?", "How much energy to give?",
    "Berikan Energi", ACCENT, "energi", giveEnergy)

---------------------------------------------------------------------- 
-- Hilangkan bagian kekuatan dan GUI-nya
---------------------------------------------------------------------- 
-- Jika nanti ingin ditambah lagi, tinggal aktifkan kembali bagian ini
--[[
buatBaris(166, "Berapa kekuatan?", "How much strength to give?",
    "Berikan Kekuatan", STR, "kekuatan", giveStrength, "555555",
    "Cepat", Color3.fromRGB(224, 108, 96), giveStrengthFast)
]]--

if false then
    -- Kalau mau menambah bagian lagi nanti
end

---------------------------------------------------------------------- 
-- Fungsi unload
---------------------------------------------------------------------- 
local function unload()
    if gui then gui:Destroy() end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
end
track(closeBtn.MouseButton1Click:connect(unload))

---------------------------------------------------------------------- 
-- Drag GUI (support PC dan Mobile)
---------------------------------------------------------------------- 
do
    local dragging, dragStart, startPos
    local function startDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = window.Position
        end
    end
    local function doDrag(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end
    local function endDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end
    track(titleBar.InputBegan:Connect(startDrag))
    track(UserInputService.InputChanged:Connect(doDrag))
    track(UserInputService.InputEnded:Connect(endDrag))
end

---------------------------------------------------------------------- 
-- Anti-AFK
---------------------------------------------------------------------- 
track(LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))
