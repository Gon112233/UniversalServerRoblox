--[[
    UNIVERSAL HUB  (Server Joiner + Hop + NPC + Island + Heavy Fishing Suite)
    Giao diện đồng bộ theo Universal Server Joiner.
    Tab Farm / Filter / Quest chỉ hoạt động trong game Heavy Fishing.
    Phím tắt: RightShift / RightCtrl / Insert = ẩn/hiện cửa sổ.
]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local genv = (getgenv and getgenv()) or _G

-- Runner ID: các vòng lặp của bản chạy cũ sẽ tự dừng khi chạy lại script
local RUNNER_ID = math.random(100000, 999999)
genv._ACTIVE_FARM_RUNNER = RUNNER_ID
local function isActive()
    return genv._ACTIVE_FARM_RUNNER == RUNNER_ID
end

----------------------------------------------------------------
-- GUI parent + dọn GUI cũ
----------------------------------------------------------------
local guiParent
do
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then guiParent = h end
    end
    if not guiParent then
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then guiParent = cg end
    end
    guiParent = guiParent or player:WaitForChild("PlayerGui")

    local candidates = { guiParent, player:FindFirstChild("PlayerGui") }
    pcall(function() table.insert(candidates, game:GetService("CoreGui")) end)
    for _, parent in ipairs(candidates) do
        local old = parent and parent:FindFirstChild("UniversalHub")
        if old then old:Destroy() end
        old = parent and parent:FindFirstChild("UniversalServerJoiner")
        if old then old:Destroy() end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "UniversalHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = guiParent

----------------------------------------------------------------
-- Theme
----------------------------------------------------------------
local C = {
    bg = Color3.fromRGB(20, 21, 25),
    header = Color3.fromRGB(28, 30, 36),
    panel = Color3.fromRGB(34, 36, 43),
    item = Color3.fromRGB(42, 45, 54),
    itemHover = Color3.fromRGB(52, 56, 68),
    selected = Color3.fromRGB(48, 88, 138),
    text = Color3.fromRGB(236, 238, 242),
    muted = Color3.fromRGB(150, 155, 168),
    accent = Color3.fromRGB(64, 132, 214),
    danger = Color3.fromRGB(190, 70, 70),
    ok = Color3.fromRGB(90, 190, 120),
    warn = Color3.fromRGB(230, 180, 80),
    border = Color3.fromRGB(52, 55, 64),
}

local CATEGORY_COLORS = {
    Boss = Color3.fromRGB(205, 85, 85),
    Shop = Color3.fromRGB(95, 185, 120),
    Quest = Color3.fromRGB(225, 180, 75),
    Function = Color3.fromRGB(110, 150, 215),
}

local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

----------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------
local function create(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local function corner(obj, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, obj)
end

local function stroke(obj, color)
    create("UIStroke", {
        Color = color or C.border,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

local function label(parent, text, pos, size, textSize, color, bold)
    return create("TextLabel", {
        Position = pos,
        Size = size,
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = color or C.text,
        TextSize = textSize or 13,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end

local function button(parent, text, pos, size, color)
    local base = color or C.item
    local obj = create("TextButton", {
        Position = pos,
        Size = size,
        BackgroundColor3 = base,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = C.text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
    }, parent)
    corner(obj, 6)

    obj:SetAttribute("BaseColor", base)
    obj.MouseEnter:Connect(function()
        local b = obj:GetAttribute("BaseColor")
        obj.BackgroundColor3 = b:Lerp(Color3.new(1, 1, 1), 0.12)
    end)
    obj.MouseLeave:Connect(function()
        obj.BackgroundColor3 = obj:GetAttribute("BaseColor")
    end)
    return obj
end

local function setButtonColor(obj, color)
    obj:SetAttribute("BaseColor", color)
    obj.BackgroundColor3 = color
end

local function textBox(parent, placeholder, pos, size)
    local box = create("TextBox", {
        Position = pos,
        Size = size,
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = C.muted,
        TextColor3 = C.text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
    corner(box, 6)
    stroke(box)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, box)
    return box
end

-- Trang cuộn (dùng cho các tab dạng danh sách thẻ)
local function scrollPage(page)
    local sf = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.muted,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, page)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sf)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 10),
    }, sf)
    return sf
end

local function sectionLabel(parent, text)
    return label(parent, text, UDim2.new(), UDim2.new(1, 0, 0, 16), 11, C.muted, true)
end

-- Công tắc bật/tắt; trả về hàm đặt trạng thái
local function switchControl(parent, pos, default, cb)
    local sw = create("TextButton", {
        Position = pos,
        Size = UDim2.fromOffset(44, 22),
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, parent)
    corner(sw, 11)
    local dot = create("Frame", {
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, sw)
    corner(dot, 8)

    local state = default and true or false
    local function render(animate)
        local bg = state and C.ok or C.item
        local dp = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        if animate then
            local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(sw, info, { BackgroundColor3 = bg }):Play()
            TweenService:Create(dot, info, { Position = dp }):Play()
        else
            sw.BackgroundColor3 = bg
            dot.Position = dp
        end
    end
    render(false)

    sw.MouseButton1Click:Connect(function()
        state = not state
        render(true)
        if cb then cb(state) end
    end)

    return function(v)
        state = v and true or false
        render(true)
    end
end

local function toggleCard(parent, title, subtitle, default, cb)
    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, parent)
    corner(card, 8)
    stroke(card)
    label(card, title, UDim2.fromOffset(12, 7), UDim2.new(1, -80, 0, 20), 13, C.text, true)
    label(card, subtitle or "", UDim2.fromOffset(12, 28), UDim2.new(1, -80, 0, 18), 11, C.muted)
    local set = switchControl(card, UDim2.new(1, -56, 0.5, -11), default, cb)
    return card, set
end

local function infoCard(parent, height, color)
    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 34),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, parent)
    corner(card, 8)
    stroke(card)
    local lbl = label(card, "", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 12, color or C.text)
    lbl.TextWrapped = true
    lbl.TextTruncate = Enum.TextTruncate.None
    return lbl
end

local function actionButton(parent, text, color, cb)
    local b = button(parent, text, UDim2.new(), UDim2.new(1, 0, 0, 38), color or C.accent)
    b.TextSize = 13
    b.MouseButton1Click:Connect(cb)
    return b
end

----------------------------------------------------------------
-- Main window
----------------------------------------------------------------
local WIDTH, HEIGHT = 560, 540
local TITLE_H, TAB_H, STATUS_H = 40, 38, 32

local frame = create("Frame", {
    Size = UDim2.fromOffset(WIDTH, HEIGHT),
    Position = UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = true,
}, gui)
corner(frame, 10)
stroke(frame)

-- Tự co giãn cho màn hình nhỏ (mobile)
local uiScale = create("UIScale", {}, frame)
local function updateScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    uiScale.Scale = math.clamp(math.min(vp.X / (WIDTH + 20), vp.Y / (HEIGHT + 20)), 0.5, 1)
end
updateScale()
if Workspace.CurrentCamera then
    connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
end

local titleBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, TITLE_H),
    BackgroundColor3 = C.header,
    BorderSizePixel = 0,
    Active = true,
}, frame)

label(titleBar, "Universal Hub  |  Server • NPC • Island • Fishing", UDim2.fromOffset(14, 0),
    UDim2.new(1, -110, 1, 0), 14, C.text, true)

local minimize = button(titleBar, "–",
    UDim2.new(1, -72, 0, 6), UDim2.fromOffset(28, 28), C.item)
local close = button(titleBar, "×",
    UDim2.new(1, -38, 0, 6), UDim2.fromOffset(28, 28), C.danger)

-- Tabs
local tabBar = create("Frame", {
    Position = UDim2.fromOffset(0, TITLE_H),
    Size = UDim2.new(1, 0, 0, TAB_H),
    BackgroundColor3 = C.header,
    BorderSizePixel = 0,
}, frame)

local tabButtons = {}
local pages = {}
local activeTab = "Server"

local function selectTab(name)
    activeTab = name
    for tabName, b in pairs(tabButtons) do
        local active = tabName == name
        setButtonColor(b, active and C.accent or C.header)
        b.TextColor3 = active and C.text or C.muted
    end
    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end
end

local tabNames = { "Server", "Hop", "NPC", "Island", "Farm", "Filter", "Quest" }
local tabTitles = {
    Server = "🌐 Server",
    Hop = "🔀 Hop",
    NPC = "👤 NPC",
    Island = "🏝 Island",
    Farm = "🎣 Farm",
    Filter = "🐟 Filter",
    Quest = "🎯 Quest",
}
for i, name in ipairs(tabNames) do
    local b = button(tabBar, tabTitles[name],
        UDim2.new((i - 1) / #tabNames, 3, 0, 4),
        UDim2.new(1 / #tabNames, -6, 1, -8), C.header)
    b.TextSize = 11
    tabButtons[name] = b
    b.MouseButton1Click:Connect(function()
        selectTab(name)
    end)
end

local pageArea = create("Frame", {
    Position = UDim2.fromOffset(0, TITLE_H + TAB_H),
    Size = UDim2.new(1, 0, 1, -(TITLE_H + TAB_H + STATUS_H)),
    BackgroundTransparency = 1,
}, frame)

for _, name in ipairs(tabNames) do
    pages[name] = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    }, pageArea)
end

-- Status bar (shared)
local statusBar = create("Frame", {
    Position = UDim2.new(0, 0, 1, -STATUS_H),
    Size = UDim2.new(1, 0, 0, STATUS_H),
    BackgroundColor3 = C.header,
    BorderSizePixel = 0,
}, frame)

local statusDot = create("Frame", {
    Position = UDim2.fromOffset(12, 11),
    Size = UDim2.fromOffset(10, 10),
    BackgroundColor3 = C.muted,
    BorderSizePixel = 0,
}, statusBar)
corner(statusDot, 5)

local statusText = label(statusBar, "Ready.", UDim2.fromOffset(30, 0),
    UDim2.new(1, -40, 1, 0), 12, C.muted)

local function setStatus(text, kind)
    statusText.Text = text
    local color = C.muted
    if kind == "ok" then
        color = C.ok
    elseif kind == "warn" then
        color = C.warn
    elseif kind == "error" then
        color = C.danger
    elseif kind == "info" then
        color = C.accent
    end
    statusDot.BackgroundColor3 = color
    statusText.TextColor3 = kind and color or C.muted
end

local function getPlayerRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

----------------------------------------------------------------
-- FISHING ENGINE (từ Heavy Fishing Suite)
----------------------------------------------------------------
local function detectFishingGame()
    local ev = ReplicatedStorage:FindFirstChild("Events")
    return ev ~= nil and ev:FindFirstChild("Fishing") ~= nil
end
local isFishingGame = detectFishingGame()

local Config = {
    AutoFish = false,
    AutoSkill = false,
    AutoSell = false,
    AutoBait = false,
    AntiAFK = false,
    BoostFps = false,
    SelectedBait = "Basic Bait",
    BaitBuyAmount = 20,
    BaitThreshold = 2,
    TicketQuestEnabled = false,
    TicketDifficulty = "Easy",
    SkipFilterEnabled = false,
    CustomFishTable = {},
}

local SkipStats = { Count = 0, LastFish = "Chưa có", LastTime = 0 }

local SECRET_RODS = {
    ["Blazeshark Rod"] = Vector3.new(-6, 54, 10),
    ["Lifebloom Rod"] = Vector3.new(-116, 78, -1533),
    ["Anchorbound Rod"] = Vector3.new(-1206, 53, 1646),
    ["Kraken Rod"] = Vector3.new(1546, 73, 1488),
    ["Demonic Rod"] = Vector3.new(1184, 86, -1244),
    ["Legacy Rod"] = Vector3.new(-2768, 12, -1511),
    ["Ascendant Bamboo Rod"] = Vector3.new(-1361, 144, 32),
}

local KEY_SPOTS = {
    ["Nana Bán Cá (Spawn)"] = Vector3.new(-205, 8, 108),
    ["Ticket Quest Giver"] = Vector3.new(-147, 7, 91),
    ["Đảo Băng"] = Vector3.new(-76, 8, -1476),
    ["Đảo San Hô"] = Vector3.new(1569, 27, 76),
    ["Đảo Núi Lửa"] = Vector3.new(1411, 63, -1572),
}

local Farm = {}

function Farm.events()
    return ReplicatedStorage:FindFirstChild("Events")
end

function Farm.playerData()
    local data = ReplicatedStorage:FindFirstChild("Data")
    return data and data:FindFirstChild(tostring(player.UserId))
end

function Farm.invCount()
    local pData = Farm.playerData()
    if not pData then return 0, 50 end
    local inv = pData:FindFirstChild("Inventory")
    local limit = pData:FindFirstChild("InventoryLimit")
    return inv and #inv:GetChildren() or 0, limit and limit.Value or 50
end

function Farm.baitCount(baitName)
    local pData = Farm.playerData()
    if not pData then return 0 end
    local bf = pData:FindFirstChild("Bait")
    local b = bf and bf:FindFirstChild(baitName)
    return b and b.Value or 0
end

function Farm.checkBait()
    if not Config.AutoBait then return end
    local E = Farm.events()
    if not E then return end
    if Farm.baitCount(Config.SelectedBait) <= Config.BaitThreshold then
        if E:FindFirstChild("BuyBait") then
            E.BuyBait:FireServer(Config.SelectedBait, Config.BaitBuyAmount)
            task.wait(0.3)
        end
    end
    local pData = Farm.playerData()
    local equipped = pData and pData:FindFirstChild("EquippedBait")
    if equipped and equipped.Value ~= Config.SelectedBait and E:FindFirstChild("EquipBait") then
        E.EquipBait:InvokeServer(Config.SelectedBait)
    end
end

local lastSellTime = 0

function Farm.checkSell(force)
    if not Config.AutoSell then return end
    local E = Farm.events()
    if not E then return end
    local now = os.clock()
    local count, limit = Farm.invCount()
    
    -- Bán khi: gọi cưỡng chế (force), túi đầy (>= limit - 2), hoặc mỗi 30s (nếu có ít nhất 1 cá)
    if force or count >= (limit - 2) or (count > 0 and now - lastSellTime >= 30) then
        if E:FindFirstChild("SellFish") then
            E.SellFish:FireServer()
            lastSellTime = now
        end
    end
end

local isHandlingTicketQuest = false

local function teleportFacingNPC()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local npcFolder = Workspace:FindFirstChild("NPC")
    local fn = npcFolder and npcFolder:FindFirstChild("Function")
    local giver = fn and fn:FindFirstChild("Ticket Quest Giver")
    local targetRoot = giver and (giver:FindFirstChild("HumanoidRootPart") or giver:FindFirstChildWhichIsA("BasePart"))

    if hrp and targetRoot then
        -- Đứng đối diện trước mặt NPC 3.5 studs, nhìn thẳng vào NPC
        local npcPos = targetRoot.Position
        local look = targetRoot.CFrame.LookVector
        local standPos = npcPos + Vector3.new(look.X * 3.5, 0.5, look.Z * 3.5)
        hrp.CFrame = CFrame.new(standPos, Vector3.new(npcPos.X, standPos.Y, npcPos.Z))
        return true
    elseif hrp then
        hrp.CFrame = CFrame.new(KEY_SPOTS["Ticket Quest Giver"] + Vector3.new(0, 3, 0))
        return true
    end
    return false
end

function Farm.activeQuest()
    local pData = Farm.playerData()
    local quest = pData and pData:FindFirstChild("Quest")
    local main = quest and quest:FindFirstChild("Main")
    if not main then return nil end
    if main:FindFirstChild("Easy Ticket Quest") then
        return "Easy Ticket Quest", main["Easy Ticket Quest"]
    elseif main:FindFirstChild("Hard Ticket Quest") then
        return "Hard Ticket Quest", main["Hard Ticket Quest"]
    end
    return nil
end

function Farm.questCooldown()
    local pData = Farm.playerData()
    local cd = pData and pData:FindFirstChild("TicketQuestCooldown")
    if not cd then return 0 end
    return math.max(0, math.floor((cd.Value or 0) - Workspace:GetServerTimeNow()))
end

-- Trả về tên quest, tiến độ, mục tiêu
function Farm.questProgress(defaultTarget)
    local qName, qFolder = Farm.activeQuest()
    if not qName or not qFolder then return nil end
    local prog = qFolder:FindFirstChild("1") and qFolder["1"].Value or 0
    local target = defaultTarget or 0
    local obj = qFolder:FindFirstChild("Objective")
    local objStr = obj and obj:FindFirstChild("1") and obj["1"].Value or ""
    local parts = string.split(tostring(objStr), ",")
    if parts and parts[2] then target = tonumber(parts[2]) or target end
    return qName, prog, target
end

local function clickButton(btn)
    if not btn then return false end
    if getconnections then
        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
            if c.Fire then c:Fire() elseif c.fire then c:fire() end
        end
    end
    pcall(function()
        if firesignal then firesignal(btn.MouseButton1Click) end
    end)
    return true
end

function Farm.interactWithNPC(diff)
    local npcFolder = Workspace:FindFirstChild("NPC")
    local fn = npcFolder and npcFolder:FindFirstChild("Function")
    local giver = fn and fn:FindFirstChild("Ticket Quest Giver")
    if not giver then return false end

    local prompt = giver:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt or not fireproximityprompt then return false end

    local mainGui = player.PlayerGui:FindFirstChild("MainGui")
    local menu = mainGui and mainGui:FindFirstChild("Menu")
    local dialogue = menu and menu:FindFirstChild("Dialogue")

    -- Thử kích hoạt prompt
    fireproximityprompt(prompt)

    -- Chờ Dialogue mở ra (tối đa 2.5s)
    local opened = false
    for _ = 1, 10 do
        task.wait(0.25)
        if dialogue and dialogue.Visible then
            opened = true
            break
        end
        fireproximityprompt(prompt)
    end

    if not opened or not dialogue then return false end

    local btnFrame = dialogue:FindFirstChild("ButtonFrame")
    if not btnFrame then return false end

    -- Bước 1: Nhấn nút Quest (thường là Button 1)
    local btn1 = btnFrame:FindFirstChild("1")
    if btn1 and btn1.Visible then
        clickButton(btn1)
        task.wait(0.6)
    end

    -- Bước 2: Kiểm tra tiếp hội thoại
    -- Nếu xuất hiện nút chọn độ khó hoặc nút Leave
    local targetBtn = (diff == "Hard") and btnFrame:FindFirstChild("2") or btnFrame:FindFirstChild("1")
    if targetBtn and targetBtn.Visible then
        clickButton(targetBtn)
        task.wait(0.5)
    end

    -- Nếu còn nút Leave (đóng hội thoại)
    local leaveBtn = btnFrame:FindFirstChild("1")
    if leaveBtn and leaveBtn.Visible then
        clickButton(leaveBtn)
        task.wait(0.3)
    end

    return true
end

function Farm.claimQuest()
    local E = Farm.events()
    local qName, prog, target = Farm.questProgress(0)
    if not E or not qName then return false end
    if target > 0 and prog >= target and E:FindFirstChild("ClaimQuest") then
        E.ClaimQuest:FireServer(qName)
        task.wait(0.5)
        return true
    end
    return false
end

function Farm.processTicketQuestCycle()
    if not Config.TicketQuestEnabled or isHandlingTicketQuest or not Farm.events() then return end

    local qName, prog, target = Farm.questProgress(0)
    local isCompleted = (qName ~= nil and target > 0 and prog >= target)
    local cooldown = Farm.questCooldown()
    local shouldTakeNew = (not qName and cooldown <= 0)

    if isCompleted or shouldTakeNew then
        isHandlingTicketQuest = true

        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            isHandlingTicketQuest = false
            return
        end

        local savedSpot = hrp.CFrame
        setStatus("Ticket Quest: Đang bay về trước mặt NPC...", "info")

        task.wait(0.4)
        teleportFacingNPC()
        task.wait(0.8)

        -- 1. Nhận thưởng nếu đã xong
        if isCompleted and qName then
            Farm.claimQuest()
            setStatus("Ticket Quest: Đã gửi nhận thưởng vé quay!", "ok")
            task.wait(0.8)
        end

        -- 2. Tương tác trực tiếp với NPC (nói chuyện & nhận quest / hoàn thành hội thoại)
        setStatus("Ticket Quest: Đang tương tác trò chuyện với NPC...", "info")
        Farm.interactWithNPC(Config.TicketDifficulty)
        task.wait(1)

        -- 3. Teleport trở lại vị trí ban đầu
        local curChar = player.Character
        local curHrp = curChar and curChar:FindFirstChild("HumanoidRootPart")
        if curHrp then
            curHrp.CFrame = savedSpot
        end
        setStatus("Ticket Quest: Đã trở lại vị trí câu ban đầu.", "ok")
        task.wait(0.8)

        isHandlingTicketQuest = false
    end
end

function Farm.ensureRod()
    local E = Farm.events()
    local char = player.Character
    if E and char and char:GetAttribute("Type") ~= "Fishing Rod" and E:FindFirstChild("ToggleHotbar") then
        E.ToggleHotbar:InvokeServer("1")
        task.wait(0.3)
    end
end

function Farm.redeemCodes()
    local E = Farm.events()
    local pData = Farm.playerData()
    local folder = pData and pData:FindFirstChild("Code")
    if not E or not folder or not E:FindFirstChild("RedeemCode") then return 0 end
    local count = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c.Value == false then
            E.RedeemCode:FireServer(c.Name)
            count = count + 1
            task.wait(0.3)
        end
    end
    return count
end

-- Anti-AFK
local afkConn = nil
local function updateAntiAFK()
    if Config.AntiAFK then
        if not afkConn then
            afkConn = connect(player.Idled, function()
                if Config.AntiAFK then
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end
            end)
        end
    elseif afkConn then
        afkConn:Disconnect()
        afkConn = nil
    end
end
updateAntiAFK()

-- =========================================================
-- FPS BOOST ENGINE (Tối ưu hóa đồ họa, tắt hiệu ứng & giảm lag)
-- =========================================================
local SavedFpsProperties = setmetatable({}, { __mode = "k" })
local FpsDescendantConn = nil

local function setAndSaveProperty(inst, prop, newVal)
    local saved = SavedFpsProperties[inst]
    if not saved then
        saved = {}
        SavedFpsProperties[inst] = saved
    end
    if saved[prop] == nil then
        local ok, curVal = pcall(function() return inst[prop] end)
        if not ok then return end
        saved[prop] = curVal
    end
    pcall(function() inst[prop] = newVal end)
end

local function optimizeInstanceForFps(inst)
    if inst:IsA("BasePart") then
        setAndSaveProperty(inst, "CastShadow", false)
        setAndSaveProperty(inst, "Reflectance", 0)
    elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Smoke") or inst:IsA("Sparkles") or inst:IsA("Fire") then
        setAndSaveProperty(inst, "Enabled", false)
    elseif inst:IsA("Decal") or inst:IsA("Texture") then
        setAndSaveProperty(inst, "Transparency", 1)
    elseif inst:IsA("PostEffect") then
        setAndSaveProperty(inst, "Enabled", false)
    elseif inst:IsA("Atmosphere") then
        setAndSaveProperty(inst, "Density", 0)
    end
end

local function restoreFpsProperties()
    if FpsDescendantConn then
        FpsDescendantConn:Disconnect()
        FpsDescendantConn = nil
    end
    for inst, props in pairs(SavedFpsProperties) do
        for prop, val in pairs(props) do
            pcall(function() inst[prop] = val end)
        end
    end
    table.clear(SavedFpsProperties)
end

local function toggleBoostFps(enabled)
    restoreFpsProperties()
    if not enabled then return end

    pcall(function()
        local renderSettings = settings().Rendering
        setAndSaveProperty(renderSettings, "QualityLevel", Enum.QualityLevel.Level01)
    end)
    setAndSaveProperty(Lighting, "GlobalShadows", false)
    setAndSaveProperty(Lighting, "EnvironmentDiffuseScale", 0)
    setAndSaveProperty(Lighting, "EnvironmentSpecularScale", 0)

    local terrain = Workspace.Terrain
    if terrain then
        setAndSaveProperty(terrain, "Decoration", false)
        setAndSaveProperty(terrain, "WaterWaveSize", 0)
        setAndSaveProperty(terrain, "WaterWaveSpeed", 0)
        setAndSaveProperty(terrain, "WaterReflectance", 0)
    end

    for _, desc in ipairs(Workspace:GetDescendants()) do
        optimizeInstanceForFps(desc)
    end
    for _, desc in ipairs(Lighting:GetDescendants()) do
        optimizeInstanceForFps(desc)
    end
    FpsDescendantConn = connect(game.DescendantAdded, optimizeInstanceForFps)
end

-- RenderStepped: perfect catch + lọc cá + auto skill
connect(RunService.RenderStepped, function()
    if not isActive() then return end
    if not Config.AutoFish and not Config.AutoSkill then return end
    if isHandlingTicketQuest then return end

    local pGui = player:FindFirstChild("PlayerGui")
    local mainGui = pGui and pGui:FindFirstChild("MainGui")
    local fishingFrame = mainGui and mainGui:FindFirstChild("Fishing")

    if fishingFrame and fishingFrame.Visible then
        local E = Farm.events()
        local barFrame = fishingFrame:FindFirstChild("BarFrame")
        local bar = barFrame and barFrame:FindFirstChild("Bar")
        local progBar = fishingFrame:FindFirstChild("ProgressionBar")
        local fishNameLabel = progBar and progBar:FindFirstChild("FishName")
        local fishName = fishNameLabel and fishNameLabel.Text or ""

        local shouldSkip = false
        if Config.SkipFilterEnabled and fishName ~= "" and fishName ~= "Fish" then
            if Config.CustomFishTable[fishName] ~= true then
                shouldSkip = true
            end
        end

        if shouldSkip then
            if bar then bar.Position = UDim2.new(1.2, 0, 0.5, 0) end
            if os.clock() - SkipStats.LastTime > 1.2 then
                SkipStats.Count = SkipStats.Count + 1
                SkipStats.LastFish = fishName
                SkipStats.LastTime = os.clock()
            end
        else
            if Config.AutoFish and bar then
                bar.Position = UDim2.new(0.5, 0, 0.5, 0)
            end
            if E and E:FindFirstChild("UpdateFishProgression") then
                E.UpdateFishProgression:FireServer()
            end
        end
    end
end)

-- Auto Skill theo thứ tự: Z -> X -> C -> V
local skillKeys = { "Z", "X", "C", "V" }
task.spawn(function()
    while isActive() and gui.Parent do
        task.wait(0.12)
        if Config.AutoSkill and not isHandlingTicketQuest then
            local pGui = player:FindFirstChild("PlayerGui")
            local mainGui = pGui and pGui:FindFirstChild("MainGui")
            local fishingFrame = mainGui and mainGui:FindFirstChild("Fishing")
            if fishingFrame and fishingFrame.Visible then
                local E = Farm.events()
                if E and E:FindFirstChild("UseSkill") then
                    for _, key in ipairs(skillKeys) do
                        if not Config.AutoSkill or not fishingFrame.Visible then break end
                        E.UseSkill:FireServer(key)
                        task.wait(0.18) -- Giãn cách nhịp giữa các skill Z -> X -> C -> V
                    end
                end
            end
        end
    end
end)

-- Vòng lặp câu cá chính
task.spawn(function()
    while isActive() and gui.Parent do
        task.wait(0.4)
        if Config.AutoFish and not isHandlingTicketQuest then
            local E = Farm.events()
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local pGui = player:FindFirstChild("PlayerGui")
            local mainGui = pGui and pGui:FindFirstChild("MainGui")
            local fishingFrame = mainGui and mainGui:FindFirstChild("Fishing")
            local inMinigame = fishingFrame and fishingFrame.Visible
            if E and E:FindFirstChild("Fishing") and not inMinigame and char and hrp then
                local count, limit = Farm.invCount()
                if count >= (limit - 1) then
                    Farm.checkSell(true)
                    task.wait(1)
                else
                    Farm.checkBait()
                    Farm.checkSell(false)
                    Farm.ensureRod()
                    local isFishing = char:GetAttribute("Fishing")
                    local isCoolingDown = char:GetAttribute("CDForTheNextThrow")
                    if not isFishing and not isCoolingDown then
                        E.Fishing:FireServer(hrp.CFrame)
                        task.wait(1.5)
                    end
                end
            end
        end
    end
end)

-- Vòng lặp Ticket Quest
task.spawn(function()
    while isActive() and gui.Parent do
        task.wait(3)
        if Config.TicketQuestEnabled and Farm.events() then
            Farm.processTicketQuestCycle()
        end
    end
end)

----------------------------------------------------------------
-- SERVER PAGE
----------------------------------------------------------------
do
    local serverPage = pages.Server

    label(serverPage, "JOIN SERVER BY JOBID", UDim2.fromOffset(14, 12),
        UDim2.new(1, -28, 0, 16), 11, C.muted, true)

    local jobInput = textBox(serverPage, "Paste server JobId here...",
        UDim2.fromOffset(14, 34), UDim2.new(1, -28, 0, 38))

    local joinButton = button(serverPage, "JOIN SERVER",
        UDim2.fromOffset(14, 80), UDim2.new(1, -28, 0, 40), C.accent)
    joinButton.TextSize = 14

    label(serverPage, "CURRENT SERVER", UDim2.fromOffset(14, 138),
        UDim2.new(1, -28, 0, 16), 11, C.muted, true)

    local infoFrame = create("Frame", {
        Position = UDim2.fromOffset(14, 160),
        Size = UDim2.new(1, -28, 0, 96),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, serverPage)
    corner(infoFrame, 8)
    stroke(infoFrame)

    local function infoRow(y, title)
        label(infoFrame, title, UDim2.fromOffset(12, y), UDim2.fromOffset(70, 20), 12, C.muted)
        return label(infoFrame, "-", UDim2.fromOffset(84, y),
            UDim2.new(1, -96, 0, 20), 12, C.text)
    end

    local placeValue = infoRow(8, "PlaceId")
    local jobValue = infoRow(36, "JobId")
    local playersValue = infoRow(64, "Players")

    local function refreshServerInfo()
        placeValue.Text = tostring(game.PlaceId)
        jobValue.Text = game.JobId ~= "" and game.JobId or "(Studio / none)"
        playersValue.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
    end
    refreshServerInfo()
    connect(Players.PlayerAdded, refreshServerInfo)
    connect(Players.PlayerRemoving, function()
        task.defer(refreshServerInfo)
    end)

    local copyButton = button(serverPage, "Copy JobId",
        UDim2.fromOffset(14, 268), UDim2.new(0.5, -18, 0, 36), C.item)
    local rejoinButton = button(serverPage, "Rejoin",
        UDim2.new(0.5, 4, 0, 268), UDim2.new(0.5, -18, 0, 36), C.item)

    label(serverPage, "Tip: press Enter in the box to join quickly.",
        UDim2.fromOffset(14, 316), UDim2.new(1, -28, 0, 18), 11, C.muted)

    local function joinServer()
        local jobId = jobInput.Text:match("^%s*(.-)%s*$")

        if jobId == "" then
            setStatus("Please enter a JobId first.", "warn")
            return
        end
        if jobId == game.JobId then
            setStatus("You are already in this server.", "warn")
            return
        end

        setStatus("Requesting teleport to server...", "info")

        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
        end)

        if not ok then
            setStatus("Error: " .. tostring(err), "error")
        end
    end

    joinButton.MouseButton1Click:Connect(joinServer)
    jobInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            joinServer()
        end
    end)

    copyButton.MouseButton1Click:Connect(function()
        if game.JobId == "" then
            setStatus("No JobId available here.", "warn")
            return
        end
        if setclipboard then
            setclipboard(game.JobId)
            setStatus("JobId copied to clipboard.", "ok")
        else
            jobInput.Text = game.JobId
            setStatus("Clipboard unsupported - JobId put in the box.", "warn")
        end
    end)

    rejoinButton.MouseButton1Click:Connect(function()
        setStatus("Rejoining current server...", "info")
        local ok, err = pcall(function()
            if game.JobId ~= "" then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            else
                TeleportService:Teleport(game.PlaceId, player)
            end
        end)
        if not ok then
            setStatus("Error: " .. tostring(err), "error")
        end
    end)
end

----------------------------------------------------------------
-- HOP PAGE
----------------------------------------------------------------
do
    local hopPage = pages.Hop

    local AUTO_INTERVAL = 30
    local MAX_PAGES = 5

    local autoEnabled = false
    local busy = false
    local lastHop = 0
    local visited = {}

    label(hopPage, "RANDOM SERVER HOP", UDim2.fromOffset(14, 12),
        UDim2.new(1, -28, 0, 16), 11, C.muted, true)

    local hopCard = create("Frame", {
        Position = UDim2.fromOffset(14, 34),
        Size = UDim2.new(1, -28, 0, 72),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, hopPage)
    corner(hopCard, 8)
    stroke(hopCard)

    label(hopCard, "Current", UDim2.fromOffset(12, 8), UDim2.fromOffset(70, 20), 12, C.muted)
    label(hopCard, game.JobId ~= "" and game.JobId or "Unavailable",
        UDim2.fromOffset(84, 8), UDim2.new(1, -96, 0, 20), 12, C.text)

    label(hopCard, "Target", UDim2.fromOffset(12, 40), UDim2.fromOffset(70, 20), 12, C.muted)
    local targetLabel = label(hopCard, "-",
        UDim2.fromOffset(84, 40), UDim2.new(1, -96, 0, 20), 12, C.text)

    local hopButton = button(hopPage, "HOP NOW",
        UDim2.fromOffset(14, 118), UDim2.new(1, -28, 0, 40), C.accent)
    hopButton.TextSize = 14

    local autoButton = button(hopPage, "AUTO HOP: OFF",
        UDim2.fromOffset(14, 166), UDim2.new(1, -28, 0, 38), C.ok)

    label(hopPage, "Auto interval: " .. AUTO_INTERVAL .. " seconds",
        UDim2.fromOffset(14, 214), UDim2.new(1, -28, 0, 20), 11, C.muted)

    local function getServers()
        local candidates = {}
        local cursor = nil

        for _ = 1, MAX_PAGES do
            local url = "https://games.roblox.com/v1/games/"
                .. tostring(game.PlaceId)
                .. "/servers/Public?limit=100&sortOrder=2"

            if cursor then
                url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
            end

            local response = game:HttpGet(url)
            local data = HttpService:JSONDecode(response)

            if type(data) ~= "table" then
                error("Invalid server-list response")
            end

            for _, server in ipairs(data.data or {}) do
                local id = server.id
                local playing = tonumber(server.playing) or 0
                local capacity = tonumber(server.maxPlayers) or 0

                if type(id) == "string"
                    and id ~= ""
                    and id ~= game.JobId
                    and not visited[id]
                    and capacity > 0
                    and playing < capacity then
                    table.insert(candidates, id)
                end
            end

            cursor = data.nextPageCursor
            if not cursor or cursor == "" then
                break
            end

            task.wait(0.2)
        end

        return candidates
    end

    local function hopNow()
        if busy then
            setStatus("Already searching...", "warn")
            return
        end

        if os.clock() - lastHop < 5 then
            setStatus("Please wait before retrying.", "warn")
            return
        end

        busy = true
        lastHop = os.clock()
        hopButton.Text = "SEARCHING..."
        setStatus("Fetching public servers...", "info")

        task.spawn(function()
            local ok, candidates = pcall(getServers)

            if not ok then
                setStatus("HTTP error: " .. tostring(candidates), "error")
                busy = false
                hopButton.Text = "HOP NOW"
                return
            end

            if #candidates == 0 and next(visited) ~= nil then
                visited = {}
                ok, candidates = pcall(getServers)

                if not ok then
                    setStatus("Retry failed: " .. tostring(candidates), "error")
                    busy = false
                    hopButton.Text = "HOP NOW"
                    return
                end
            end

            if #candidates == 0 then
                setStatus("No available server found.", "warn")
                busy = false
                hopButton.Text = "HOP NOW"
                return
            end

            local jobId = candidates[math.random(1, #candidates)]
            visited[jobId] = true

            targetLabel.Text = jobId
            setStatus("Found " .. #candidates .. " servers. Teleporting...", "info")
            hopButton.Text = "TELEPORTING..."

            local teleportOK, teleportError = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
            end)

            if not teleportOK then
                setStatus("Teleport error: " .. tostring(teleportError), "error")
                busy = false
                hopButton.Text = "HOP NOW"
                return
            end

            setStatus("Teleport requested; waiting for Roblox...", "ok")

            task.delay(15, function()
                if busy and gui.Parent then
                    busy = false
                    hopButton.Text = "HOP NOW"
                    setStatus("Still here? Check teleport errors.", "warn")
                end
            end)
        end)
    end

    hopButton.MouseButton1Click:Connect(hopNow)

    autoButton.MouseButton1Click:Connect(function()
        autoEnabled = not autoEnabled

        autoButton.Text = autoEnabled and "AUTO HOP: ON" or "AUTO HOP: OFF"
        setButtonColor(autoButton, autoEnabled and C.danger or C.ok)

        setStatus(autoEnabled and "Auto hop enabled." or "Auto hop disabled.",
            autoEnabled and "ok" or nil)
    end)

    task.spawn(function()
        while gui.Parent and isActive() do
            task.wait(1)
            if autoEnabled and not busy then
                if AUTO_INTERVAL - (os.clock() - lastHop) <= 0 then
                    hopNow()
                end
            end
        end
    end)

    connect(TeleportService.TeleportInitFailed, function(failedPlayer, result, errorMessage)
        if failedPlayer == player then
            busy = false
            if gui.Parent then
                hopButton.Text = "HOP NOW"
                setStatus("Teleport failed: " .. tostring(result)
                    .. " / " .. tostring(errorMessage), "error")
            end
        end
    end)
end

----------------------------------------------------------------
-- NPC PAGE
----------------------------------------------------------------
do
    local npcPage = pages.NPC

    local searchBox = textBox(npcPage, "🔍  Search NPC name...",
        UDim2.fromOffset(14, 10), UDim2.new(1, -116, 0, 34))

    local refreshButton = button(npcPage, "↻ Refresh",
        UDim2.new(1, -96, 0, 10), UDim2.fromOffset(82, 34), C.panel)
    stroke(refreshButton)

    local categories = { "All", "Boss", "Shop", "Quest", "Function" }
    local activeCategory = "All"
    local categoryButtons = {}

    local categoryFrame = create("Frame", {
        Position = UDim2.fromOffset(14, 52),
        Size = UDim2.new(1, -28, 0, 28),
        BackgroundTransparency = 1,
    }, npcPage)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, categoryFrame)

    for i, name in ipairs(categories) do
        local b = button(categoryFrame, name, UDim2.new(),
            UDim2.new(1 / #categories, -4, 1, 0),
            name == activeCategory and C.accent or C.panel)
        b.TextSize = 12
        b.LayoutOrder = i
        categoryButtons[name] = b
    end

    local countLabel = label(npcPage, "NPCs: 0  |  Results: 0",
        UDim2.fromOffset(14, 88), UDim2.new(1, -150, 0, 18), 11, C.muted)

    local sortMode = "Name"
    local sortButton = button(npcPage, "Sort: Name",
        UDim2.new(1, -124, 0, 86), UDim2.fromOffset(110, 22), C.panel)
    sortButton.TextSize = 11

    local npcList = create("ScrollingFrame", {
        Position = UDim2.fromOffset(14, 114),
        Size = UDim2.new(1, -28, 1, -114 - 100),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.muted,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, npcPage)
    corner(npcList, 8)
    stroke(npcList)

    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, npcList)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 6),
    }, npcList)

    local emptyLabel = label(npcPage, "No NPCs to show.",
        UDim2.fromOffset(14, 150), UDim2.new(1, -28, 0, 30), 13, C.muted)
    emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
    emptyLabel.ZIndex = 0
    emptyLabel.Visible = false

    local selectedLabel = label(npcPage, "Selected: none",
        UDim2.new(0, 14, 1, -88), UDim2.new(1, -28, 0, 20), 12, C.muted)

    local teleportButton = button(npcPage, "TELEPORT TO NPC",
        UDim2.new(0, 14, 1, -62), UDim2.new(1, -134, 0, 38), C.accent)
    teleportButton.TextSize = 14

    local cycleButton = button(npcPage, "Next ▸",
        UDim2.new(1, -112, 1, -62), UDim2.fromOffset(98, 38), C.panel)
    stroke(cycleButton)

    label(npcPage, "Tip: double-click to teleport. Next switches between locations.",
        UDim2.new(0, 14, 1, -20), UDim2.new(1, -28, 0, 16), 11, C.muted)

    local allNPCs = {}
    local groupedNPCs = {}
    local filteredNPCs = {}
    local selectedNPC = nil
    local selectedGroup = nil
    local locationIndex = 1
    local scanBusy = false
    local rows = {}
    local MAX_ROWS = 250

    local function getRoot(model)
        if not model or not model:IsA("Model") then
            return nil
        end
        return model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart")
    end

    local function isNPC(model)
        if not model:IsA("Model") then
            return false
        end
        if Players:GetPlayerFromCharacter(model) then
            return false
        end
        return model:FindFirstChildOfClass("Humanoid") ~= nil
            and getRoot(model) ~= nil
    end

    local function getCategory(npc)
        local name = npc.Name:lower()
        if name:find("boss", 1, true) then
            return "Boss"
        elseif name:find("shop", 1, true)
            or name:find("buy", 1, true)
            or name:find("seller", 1, true)
            or name:find("merchant", 1, true)
            or name:find("store", 1, true) then
            return "Shop"
        elseif name:find("quest", 1, true)
            or name:find("mission", 1, true) then
            return "Quest"
        end
        return "Function"
    end

    local function getDistance(npc)
        local pr, nr = getPlayerRoot(), getRoot(npc)
        if pr and nr then
            return math.floor((pr.Position - nr.Position).Magnitude)
        end
        return math.huge
    end

    local function getGroupDistance(group)
        local best = math.huge
        for _, npc in ipairs(group.locations) do
            if npc:IsDescendantOf(Workspace) then
                best = math.min(best, getDistance(npc))
            end
        end
        return best
    end

    local function updateSelectedLabel()
        if selectedGroup and selectedNPC then
            local count = #selectedGroup.locations
            selectedLabel.Text = "Selected: " .. selectedGroup.name
                .. "  |  location " .. locationIndex .. "/" .. count
            selectedLabel.TextColor3 = C.text
            cycleButton.Text = count > 1 and "Next ▸" or "1 location"
        else
            selectedLabel.Text = "Selected: none"
            selectedLabel.TextColor3 = C.muted
            cycleButton.Text = "Next ▸"
        end
    end

    local function setSelected(group, index)
        selectedGroup = group
        locationIndex = index or 1
        selectedNPC = group and group.locations[locationIndex] or nil

        for g, row in pairs(rows) do
            row.BackgroundColor3 = g == group and C.selected or C.item
            row:SetAttribute("BaseColor", row.BackgroundColor3)
        end
        updateSelectedLabel()
    end

    local function teleportToNPC(npc)
        if not npc or not npc:IsDescendantOf(Workspace) then
            setStatus("NPC no longer exists. Press Refresh.", "warn")
            return
        end

        local targetRoot = getRoot(npc)
        local character = player.Character
        if not targetRoot or not character or not getPlayerRoot() then
            setStatus("NPC or your character root was not found.", "error")
            return
        end

        local ok, err = pcall(function()
            character:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, 4))
        end)

        if ok then
            setStatus("Teleported to " .. npc.Name .. " (" .. locationIndex .. "/"
                .. (selectedGroup and #selectedGroup.locations or 1) .. ").", "ok")
        else
            setStatus("Teleport failed: " .. tostring(err), "error")
        end
    end

    local lastClickGroup, lastClickTime = nil, 0

    local function clearList()
        for _, child in ipairs(npcList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        rows = {}
    end

    local function renderList()
        clearList()

        local total = #filteredNPCs
        local shown = math.min(total, MAX_ROWS)

        for i = 1, shown do
            local group = filteredNPCs[i]
            local count = #group.locations
            local category = getCategory(group.locations[1])
            local dist = getGroupDistance(group)

            local row = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = group == selectedGroup and C.selected or C.item,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = i,
            }, npcList)
            corner(row, 6)
            row:SetAttribute("BaseColor", row.BackgroundColor3)

            create("Frame", {
                Size = UDim2.new(0, 3, 1, -12),
                Position = UDim2.fromOffset(4, 6),
                BackgroundColor3 = CATEGORY_COLORS[category],
                BorderSizePixel = 0,
            }, row)

            local displayName = group.name .. (count > 1 and ("  (x" .. count .. ")") or "")
            label(row, displayName, UDim2.fromOffset(16, 0),
                UDim2.new(1, -150, 1, 0), 13, C.text)

            local tag = label(row, category, UDim2.new(1, -128, 0, 0),
                UDim2.fromOffset(60, 34), 11, CATEGORY_COLORS[category])
            tag.TextXAlignment = Enum.TextXAlignment.Right

            local distText = dist == math.huge and "-" or (dist .. "m")
            local distLabel = label(row, distText, UDim2.new(1, -62, 0, 0),
                UDim2.fromOffset(54, 34), 11, C.muted)
            distLabel.TextXAlignment = Enum.TextXAlignment.Right

            row.MouseEnter:Connect(function()
                if group ~= selectedGroup then
                    row.BackgroundColor3 = C.itemHover
                end
            end)
            row.MouseLeave:Connect(function()
                row.BackgroundColor3 = group == selectedGroup and C.selected or C.item
            end)

            row.MouseButton1Click:Connect(function()
                local now = os.clock()
                local isDouble = lastClickGroup == group and now - lastClickTime < 0.4
                lastClickGroup, lastClickTime = group, now

                if group ~= selectedGroup then
                    setSelected(group, 1)
                end

                if isDouble then
                    lastClickGroup = nil
                    teleportToNPC(selectedNPC)
                else
                    setStatus(count > 1
                        and (group.name .. ": " .. count .. " locations. Use Next to switch.")
                        or ("Selected " .. group.name .. "."), "info")
                end
            end)

            rows[group] = row
        end

        npcList.CanvasPosition = Vector2.zero

        local suffix = total > MAX_ROWS and (" (showing " .. MAX_ROWS .. ")") or ""
        countLabel.Text = "NPCs: " .. #allNPCs .. "  |  Names: " .. total .. suffix
        emptyLabel.Visible = total == 0
    end

    local function updateFilter()
        local query = searchBox.Text:lower():match("^%s*(.-)%s*$")
        filteredNPCs = {}
        local distances = {}

        for _, group in ipairs(groupedNPCs) do
            if #group.locations > 0 then
                local matchesName = query == ""
                    or group.name:lower():find(query, 1, true) ~= nil
                local matchesCategory = activeCategory == "All"
                    or getCategory(group.locations[1]) == activeCategory

                if matchesName and matchesCategory then
                    table.insert(filteredNPCs, group)
                    distances[group] = getGroupDistance(group)
                end
            end
        end

        table.sort(filteredNPCs, function(a, b)
            if sortMode == "Distance" and distances[a] ~= distances[b] then
                return distances[a] < distances[b]
            end
            return a.name:lower() < b.name:lower()
        end)
    end

    local function refreshView()
        updateFilter()
        renderList()
    end

    local function refreshNPCs()
        if scanBusy then
            return
        end

        scanBusy = true
        refreshButton.Text = "Scanning..."
        setStatus("Scanning workspace for NPCs...", "info")

        task.spawn(function()
            local found = {}
            local groups = {}

            local ok, err = pcall(function()
                for i, instance in ipairs(Workspace:GetDescendants()) do
                    if isNPC(instance) then
                        table.insert(found, instance)

                        local name = instance.Name
                        if not groups[name] then
                            groups[name] = { name = name, locations = {} }
                        end
                        table.insert(groups[name].locations, instance)
                    end
                    if i % 2000 == 0 then
                        task.wait()
                    end
                end
            end)

            if ok then
                allNPCs = found
                groupedNPCs = {}

                for _, group in pairs(groups) do
                    table.sort(group.locations, function(a, b)
                        return a:GetFullName() < b:GetFullName()
                    end)
                    table.insert(groupedNPCs, group)
                end

                table.sort(groupedNPCs, function(a, b)
                    return a.name:lower() < b.name:lower()
                end)

                local previousName = selectedGroup and selectedGroup.name
                local previousIndex = locationIndex
                selectedGroup, selectedNPC = nil, nil

                if previousName then
                    for _, group in ipairs(groupedNPCs) do
                        if group.name == previousName then
                            selectedGroup = group
                            locationIndex = math.min(previousIndex, #group.locations)
                            selectedNPC = group.locations[locationIndex]
                            break
                        end
                    end
                end

                refreshView()
                updateSelectedLabel()
                setStatus("Scan complete: " .. #found .. " NPC(s), "
                    .. #groupedNPCs .. " unique name(s).", "ok")
            else
                setStatus("Scan failed: " .. tostring(err), "error")
            end

            refreshButton.Text = "↻ Refresh"
            scanBusy = false
        end)
    end

    for name, b in pairs(categoryButtons) do
        b.MouseButton1Click:Connect(function()
            activeCategory = name
            for category, item in pairs(categoryButtons) do
                setButtonColor(item, category == activeCategory and C.accent or C.panel)
            end
            refreshView()
        end)
    end

    connect(searchBox:GetPropertyChangedSignal("Text"), refreshView)
    refreshButton.MouseButton1Click:Connect(refreshNPCs)

    sortButton.MouseButton1Click:Connect(function()
        sortMode = sortMode == "Name" and "Distance" or "Name"
        sortButton.Text = "Sort: " .. sortMode
        refreshView()
    end)

    cycleButton.MouseButton1Click:Connect(function()
        if not selectedGroup then
            setStatus("Select an NPC from the list first.", "warn")
            return
        end

        local count = #selectedGroup.locations
        if count <= 1 then
            setStatus("This NPC has only one location.", "info")
            return
        end

        locationIndex = locationIndex % count + 1
        selectedNPC = selectedGroup.locations[locationIndex]
        updateSelectedLabel()
        setStatus("Location " .. locationIndex .. "/" .. count
            .. " selected. Press TELEPORT.", "info")
    end)

    teleportButton.MouseButton1Click:Connect(function()
        if not selectedNPC then
            setStatus("Select an NPC from the list first.", "warn")
            return
        end
        teleportToNPC(selectedNPC)
    end)

    task.spawn(refreshNPCs)
end

----------------------------------------------------------------
-- ISLAND PAGE (đảo + cần bí mật + điểm quan trọng)
----------------------------------------------------------------
do
    local islandPage = pages.Island

    local ISLAND_NAMES = {
        "Battlefield Isle", "Mistpeak Isle", "Fallout Isle", "Frost Isle",
        "Bamboo Isle", "Weather Isle", "Amber Isle", "World Angler Isle",
        "Perch Isle", "Sovereign Isle", "Beginning Isle", "Coconut Isle",
        "Mystic Reef Isle",
    }

    local KIND_COLORS = {
        Island = C.accent,
        Rod = C.danger,
        Spot = C.ok,
    }

    local islandSearch = textBox(islandPage, "🔍  Search island / rod / spot...",
        UDim2.fromOffset(14, 10), UDim2.new(1, -116, 0, 34))

    local islandRefresh = button(islandPage, "↻ Refresh",
        UDim2.new(1, -96, 0, 10), UDim2.fromOffset(82, 34), C.panel)
    stroke(islandRefresh)

    local islandCount = label(islandPage, "Entries: 0  |  Results: 0",
        UDim2.fromOffset(14, 52), UDim2.new(1, -28, 0, 18), 11, C.muted)

    local islandList = create("ScrollingFrame", {
        Position = UDim2.fromOffset(14, 76),
        Size = UDim2.new(1, -28, 1, -76 - 100),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.muted,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, islandPage)
    corner(islandList, 8)
    stroke(islandList)

    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, islandList)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 6),
    }, islandList)

    local islandEmpty = label(islandPage, "No entries found in this game.",
        UDim2.fromOffset(14, 120), UDim2.new(1, -28, 0, 30), 13, C.muted)
    islandEmpty.TextXAlignment = Enum.TextXAlignment.Center
    islandEmpty.ZIndex = 0
    islandEmpty.Visible = false

    local islandSelectedLabel = label(islandPage, "Selected: none",
        UDim2.new(0, 14, 1, -88), UDim2.new(1, -28, 0, 20), 12, C.muted)

    local islandTeleport = button(islandPage, "TELEPORT",
        UDim2.new(0, 14, 1, -62), UDim2.new(1, -28, 0, 38), C.accent)
    islandTeleport.TextSize = 14

    label(islandPage, "Tip: double-click an entry to teleport.",
        UDim2.new(0, 14, 1, -20), UDim2.new(1, -28, 0, 16), 11, C.muted)

    -- entry = { name, kind, getPos = function() -> Vector3|nil, lift = number }
    local entries = {}
    local filtered = {}
    local islandRows = {}
    local selectedEntry = nil
    local lastClick, lastTime = nil, 0

    local function scanEntries()
        entries = {}
        local folder = Workspace:FindFirstChild("Spawnpoint")
        if folder then
            for _, islandName in ipairs(ISLAND_NAMES) do
                local part = folder:FindFirstChild(islandName)
                if part and part:IsA("BasePart") then
                    table.insert(entries, {
                        name = islandName,
                        kind = "Island",
                        lift = 5,
                        getPos = function()
                            return part:IsDescendantOf(Workspace) and part.Position or nil
                        end,
                    })
                end
            end
        end

        if isFishingGame then
            local function addStatic(tbl, kind, prefix)
                local names = {}
                for n in pairs(tbl) do table.insert(names, n) end
                table.sort(names)
                for _, n in ipairs(names) do
                    local pos = tbl[n]
                    table.insert(entries, {
                        name = prefix .. n,
                        kind = kind,
                        lift = 3,
                        getPos = function() return pos end,
                    })
                end
            end
            addStatic(KEY_SPOTS, "Spot", "📍 ")
            addStatic(SECRET_RODS, "Rod", "🎣 ")
        end

        return folder ~= nil
    end

    local function setSelectedEntry(entry)
        selectedEntry = entry
        for e, row in pairs(islandRows) do
            row.BackgroundColor3 = e == entry and C.selected or C.item
            row:SetAttribute("BaseColor", row.BackgroundColor3)
        end
        if entry then
            islandSelectedLabel.Text = "Selected: " .. entry.name
            islandSelectedLabel.TextColor3 = C.text
        else
            islandSelectedLabel.Text = "Selected: none"
            islandSelectedLabel.TextColor3 = C.muted
        end
    end

    local function teleportToEntry(entry)
        local pos = entry and entry.getPos()
        if not pos then
            setStatus("Target no longer exists. Press Refresh.", "warn")
            return
        end
        local character = player.Character
        if not character or not getPlayerRoot() then
            setStatus("Your character root was not found.", "error")
            return
        end
        local ok, err = pcall(function()
            character:PivotTo(CFrame.new(pos + Vector3.new(0, entry.lift, 0)))
        end)
        if ok then
            setStatus("Teleported to " .. entry.name .. ".", "ok")
        else
            setStatus("Teleport failed: " .. tostring(err), "error")
        end
    end

    local function renderEntries()
        for _, child in ipairs(islandList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        islandRows = {}

        local query = islandSearch.Text:lower():match("^%s*(.-)%s*$")
        filtered = {}
        for _, entry in ipairs(entries) do
            if query == "" or entry.name:lower():find(query, 1, true) then
                table.insert(filtered, entry)
            end
        end

        for i, entry in ipairs(filtered) do
            local row = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = entry == selectedEntry and C.selected or C.item,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = i,
            }, islandList)
            corner(row, 6)
            row:SetAttribute("BaseColor", row.BackgroundColor3)

            create("Frame", {
                Size = UDim2.new(0, 3, 1, -12),
                Position = UDim2.fromOffset(4, 6),
                BackgroundColor3 = KIND_COLORS[entry.kind] or C.accent,
                BorderSizePixel = 0,
            }, row)

            label(row, entry.name, UDim2.fromOffset(16, 0),
                UDim2.new(1, -150, 1, 0), 13, C.text)

            local tag = label(row, entry.kind, UDim2.new(1, -128, 0, 0),
                UDim2.fromOffset(60, 34), 11, KIND_COLORS[entry.kind] or C.accent)
            tag.TextXAlignment = Enum.TextXAlignment.Right

            local distLabel = label(row, "-", UDim2.new(1, -62, 0, 0),
                UDim2.fromOffset(54, 34), 11, C.muted)
            distLabel.TextXAlignment = Enum.TextXAlignment.Right
            local pr, pos = getPlayerRoot(), entry.getPos()
            if pr and pos then
                distLabel.Text = math.floor((pr.Position - pos).Magnitude) .. "m"
            end

            row.MouseEnter:Connect(function()
                if entry ~= selectedEntry then
                    row.BackgroundColor3 = C.itemHover
                end
            end)
            row.MouseLeave:Connect(function()
                row.BackgroundColor3 = entry == selectedEntry and C.selected or C.item
            end)

            row.MouseButton1Click:Connect(function()
                local now = os.clock()
                local isDouble = lastClick == entry and now - lastTime < 0.4
                lastClick, lastTime = entry, now

                setSelectedEntry(entry)
                if isDouble then
                    lastClick = nil
                    teleportToEntry(entry)
                else
                    setStatus("Selected " .. entry.name .. ".", "info")
                end
            end)

            islandRows[entry] = row
        end

        islandList.CanvasPosition = Vector2.zero
        islandCount.Text = "Entries: " .. #entries .. "  |  Results: " .. #filtered
        islandEmpty.Visible = #filtered == 0
    end

    local function refreshEntries()
        local hasFolder = scanEntries()

        local previousName = selectedEntry and selectedEntry.name
        selectedEntry = nil
        if previousName then
            for _, entry in ipairs(entries) do
                if entry.name == previousName then
                    selectedEntry = entry
                    break
                end
            end
        end

        renderEntries()
        setSelectedEntry(selectedEntry)

        if not hasFolder and #entries == 0 then
            setStatus("Workspace.Spawnpoint not found (wrong game?).", "warn")
        else
            setStatus("Found " .. #entries .. " teleport entr(ies).", "ok")
        end
    end

    connect(islandSearch:GetPropertyChangedSignal("Text"), renderEntries)
    islandRefresh.MouseButton1Click:Connect(refreshEntries)
    islandTeleport.MouseButton1Click:Connect(function()
        if not selectedEntry then
            setStatus("Select an entry from the list first.", "warn")
            return
        end
        teleportToEntry(selectedEntry)
    end)

    refreshEntries()
end

----------------------------------------------------------------
-- FARM PAGE
----------------------------------------------------------------
do
    local p = scrollPage(pages.Farm)

    if not isFishingGame then
        local warn = infoCard(p, 44, C.warn)
        warn.Text = "⚠ Không tìm thấy ReplicatedStorage.Events.Fishing — các tính năng câu cá chỉ chạy trong Heavy Fishing."
    end

    sectionLabel(p, "ĐIỀU KHIỂN CÂU CÁ")
    toggleCard(p, "🎣 Tự câu cá", "Quăng cần & vòng lặp câu tự động", Config.AutoFish, function(v)
        Config.AutoFish = v
    end)
    toggleCard(p, "⚡ Tự dùng Skill", "Spam Z/X/C/V trong minigame", Config.AutoSkill, function(v)
        Config.AutoSkill = v
    end)

    sectionLabel(p, "HỖ TRỢ")
    toggleCard(p, "💰 Tự bán cá", "Bán sau mỗi 30s hoặc khi túi gần đầy", Config.AutoSell, function(v)
        Config.AutoSell = v
        if v then Farm.checkSell(true) end
    end)
    toggleCard(p, "🪱 Tự mua & lắp mồi", "Tự mua thêm 20 mồi khi số lượng ≤ 2", Config.AutoBait, function(v)
        Config.AutoBait = v
        if v then Farm.checkBait() end
    end)

    -- Bộ chọn loại mồi câu (Bait Selector)
    local ALL_BAITS = {
        "Basic Bait", "Thunder Bait", "Frost Bait", "Rainbow Bait",
        "Elite Bait", "Corrupted Essence Bait", "Crude Mash Bait",
        "Ancestral Bait", "Intuitive Bait", "Nameless Bait"
    }

    local baitCard = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, p)
    corner(baitCard, 8)
    stroke(baitCard)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, baitCard)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
    }, baitCard)

    local baitTitle = label(baitCard, "Chọn mồi câu: " .. Config.SelectedBait,
        UDim2.new(), UDim2.new(1, 0, 0, 20), 12, C.accent, true)
    baitTitle.LayoutOrder = 1

    local baitGrid = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
    }, baitCard)
    create("UIGridLayout", {
        CellSize = UDim2.new(0.5, -3, 0, 28),
        CellPadding = UDim2.fromOffset(4, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, baitGrid)

    local baitButtons = {}
    for _, bName in ipairs(ALL_BAITS) do
        local bBtn = button(baitGrid, bName, UDim2.new(), UDim2.new(),
            bName == Config.SelectedBait and C.selected or C.item)
        bBtn.TextSize = 11
        bBtn.TextTruncate = Enum.TextTruncate.AtEnd
        baitButtons[bName] = bBtn

        bBtn.MouseButton1Click:Connect(function()
            Config.SelectedBait = bName
            baitTitle.Text = "Chọn mồi câu: " .. bName
            for name, btn in pairs(baitButtons) do
                setButtonColor(btn, name == bName and C.selected or C.item)
            end
            if Config.AutoBait then
                Farm.checkBait()
            end
            setStatus("Đã chọn mồi câu: " .. bName, "info")
        end)
    end

    toggleCard(p, "🛡 Chống AFK", "Treo máy không bị kick", Config.AntiAFK, function(v)
        Config.AntiAFK = v
        updateAntiAFK()
    end)
    toggleCard(p, "⚡ Tối ưu FPS (Boost FPS)", "Tắt bóng, hiệu ứng, texture để tăng mượt và giảm giật lag", Config.BoostFps, function(v)
        Config.BoostFps = v
        toggleBoostFps(v)
        setStatus(v and "Đã bật Boost FPS (đồ họa tối giản)." or "Đã khôi phục đồ họa ban đầu.", v and "ok" or "info")
    end)
end

----------------------------------------------------------------
-- FILTER PAGE
----------------------------------------------------------------
do
    local p = scrollPage(pages.Filter)

    sectionLabel(p, "BỘ LỌC CÁ")
    toggleCard(p, "🐟 Bật lọc cá", "Chỉ câu cá trong bảng, skip cá còn lại", Config.SkipFilterEnabled, function(v)
        Config.SkipFilterEnabled = v
    end)

    local skipLbl = infoCard(p, 32, C.warn)
    skipLbl.Text = "⏩ Đã skip: 0 con | Gần nhất: Chưa có"

    -- Thanh tìm kiếm (lọc cả bảng cá và danh sách chọn nhanh)
    local searchBox = textBox(p, "🔍  Search fish name...", UDim2.new(), UDim2.new(1, 0, 0, 34))
    local fishCountLbl = label(p, "Fish: 0  |  Results: 0", UDim2.new(), UDim2.new(1, 0, 0, 16), 11, C.muted)

    local applyFilter          -- được gán sau khi pickerBody được tạo
    local pickerAreas = {}     -- { {header=, grid=, items={ {btn=, name=} }} }
    local pickerOpen = false

    sectionLabel(p, "BẢNG CÁ  (Bật = Câu | Tắt = Skip)")
    local listContainer = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, p)
    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, listContainer)

    local function createRow(fName, active)
        if listContainer:FindFirstChild("Row_" .. fName) then return end
        local row = create("Frame", {
            Name = "Row_" .. fName,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = C.item,
            BorderSizePixel = 0,
        }, listContainer)
        corner(row, 6)

        label(row, fName, UDim2.fromOffset(12, 0), UDim2.new(1, -110, 1, 0), 13, C.text)

        Config.CustomFishTable[fName] = active ~= false
        switchControl(row, UDim2.new(1, -92, 0.5, -11), active ~= false, function(v)
            Config.CustomFishTable[fName] = v
        end)

        local del = button(row, "✕", UDim2.new(1, -36, 0.5, -12), UDim2.fromOffset(26, 24), C.danger)
        del.TextSize = 12
        del.MouseButton1Click:Connect(function()
            Config.CustomFishTable[fName] = nil
            row:Destroy()
            if applyFilter then applyFilter() end
        end)

        if applyFilter then applyFilter() end
    end

    local function addFish(fishName)
        local name = (tostring(fishName or ""):gsub("^%s*(.-)%s*$", "%1"))
        if name ~= "" then
            createRow(name, true)
        end
    end

    -- Danh sách chọn nhanh
    sectionLabel(p, "CHỌN NHANH TỪ DANH SÁCH")
    local pickerHeader = button(p, "▼  Danh sách cá trong game (bấm để mở)",
        UDim2.new(), UDim2.new(1, 0, 0, 32), C.panel)
    pickerHeader.TextXAlignment = Enum.TextXAlignment.Left
    pickerHeader.TextSize = 12
    create("UIPadding", { PaddingLeft = UDim.new(0, 10) }, pickerHeader)

    local pickerBody = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Visible = false,
    }, p)
    corner(pickerBody, 8)
    stroke(pickerBody)
    create("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, pickerBody)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
    }, pickerBody)

    applyFilter = function()
        local query = searchBox.Text:lower():match("^%s*(.-)%s*$")

        -- Bảng cá đã chọn
        local total, shown = 0, 0
        for _, child in ipairs(listContainer:GetChildren()) do
            if child:IsA("Frame") and child.Name:sub(1, 4) == "Row_" then
                total = total + 1
                local match = query == ""
                    or child.Name:sub(5):lower():find(query, 1, true) ~= nil
                child.Visible = match
                if match then shown = shown + 1 end
            end
        end
        fishCountLbl.Text = "Fish: " .. total .. "  |  Results: " .. shown

        -- Danh sách chọn nhanh
        local pickerAny = false
        for _, area in ipairs(pickerAreas) do
            local any = false
            for _, item in ipairs(area.items) do
                local match = query == ""
                    or item.name:lower():find(query, 1, true) ~= nil
                item.btn.Visible = match
                if match then any = true end
            end
            area.header.Visible = any
            area.grid.Visible = any
            if any then pickerAny = true end
        end

        -- Khi đang tìm kiếm thì tự mở danh sách nếu có kết quả
        pickerBody.Visible = pickerOpen or (query ~= "" and pickerAny)
    end

    connect(searchBox:GetPropertyChangedSignal("Text"), function()
        applyFilter()
    end)

    pickerHeader.MouseButton1Click:Connect(function()
        pickerOpen = not pickerOpen
        pickerHeader.Text = (pickerOpen and "▲" or "▼") .. "  Danh sách cá trong game (bấm để mở)"
        applyFilter()
    end)

    task.spawn(function()
        local ok, far = pcall(function()
            local info = ReplicatedStorage:FindFirstChild("Info")
            local m = info and info:FindFirstChild("FishingAreaRarity")
            return m and require(m)
        end)

        local grouped = {}
        if ok and type(far) == "table" then
            for area, fishTable in pairs(far) do
                if type(fishTable) == "table" then
                    local list = {}
                    for fName in pairs(fishTable) do table.insert(list, tostring(fName)) end
                    table.sort(list)
                    grouped[tostring(area)] = list
                end
            end
        elseif isFishingGame then
            grouped = {
                ["Beginning Isle"] = {
                    "Trout", "Catfish", "Tilapia", "Crimson Carp", "Crimson Catfish",
                    "Emerald Carp", "Volt Grass Carp", "Arrogant Fish", "Golden Carp",
                    "Platinum Carp", "Royal Carp", "Azure Carp",
                },
                ["Boss / Exclusive"] = {
                    "Mountain Dragonwhale", "Tigerfang Whale", "Colossal Bull Shark",
                    "Thunder Bull Shark", "Vermilion Birdblood", "Valentine Dolphin",
                    "Glorious Oarfish", "Glorious Blobfish", "Yangfish Empress",
                    "Yangfish Sovereign", "Yinfish Sovereign",
                },
            }
        end

        local areaNames = {}
        for n in pairs(grouped) do table.insert(areaNames, n) end
        table.sort(areaNames)

        if #areaNames == 0 then
            local l = label(pickerBody, "(Không có dữ liệu cá ở game này)",
                UDim2.new(), UDim2.new(1, 0, 0, 20), 12, C.muted)
            l.LayoutOrder = 1
            return
        end

        local order = 0
        for _, areaName in ipairs(areaNames) do
            order = order + 1
            local areaLbl = label(pickerBody, "— " .. areaName .. " —",
                UDim2.new(), UDim2.new(1, 0, 0, 18), 11, C.accent, true)
            areaLbl.LayoutOrder = order

            order = order + 1
            local grid = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = order,
            }, pickerBody)
            create("UIGridLayout", {
                CellSize = UDim2.new(0.5, -3, 0, 26),
                CellPadding = UDim2.fromOffset(4, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, grid)

            local area = { header = areaLbl, grid = grid, items = {} }
            table.insert(pickerAreas, area)

            for _, fName in ipairs(grouped[areaName]) do
                local b = button(grid, "+ " .. fName, UDim2.new(), UDim2.new(), C.item)
                b.TextSize = 11
                b.TextTruncate = Enum.TextTruncate.AtEnd
                table.insert(area.items, { btn = b, name = fName })
                b.MouseButton1Click:Connect(function()
                    addFish(fName)
                    setButtonColor(b, C.ok)
                    task.delay(0.5, function()
                        if b.Parent then setButtonColor(b, C.item) end
                    end)
                end)
            end
        end

        applyFilter()
    end)

    applyFilter()

    task.spawn(function()
        while gui.Parent and isActive() do
            task.wait(1)
            if activeTab == "Filter" and frame.Visible then
                skipLbl.Text = string.format("⏩ Đã skip: %d con | Gần nhất: %s",
                    SkipStats.Count, SkipStats.LastFish)
            end
        end
    end)
end

----------------------------------------------------------------
-- QUEST PAGE (Ticket Quest + Giftcode + Daily)
----------------------------------------------------------------
do
    local p = scrollPage(pages.Quest)

    sectionLabel(p, "TICKET QUEST")
    toggleCard(p, "⭐ Auto Ticket Quest", "Tự nhận, làm và trả quest tại NPC", Config.TicketQuestEnabled, function(v)
        Config.TicketQuestEnabled = v
    end)

    local diffCard = create("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
    }, p)
    corner(diffCard, 8)
    stroke(diffCard)
    label(diffCard, "Độ khó Quest", UDim2.fromOffset(12, 0), UDim2.new(0.4, 0, 1, 0), 13, C.text, true)

    local easyBtn = button(diffCard, "🟢 Easy", UDim2.new(1, -164, 0.5, -14), UDim2.fromOffset(74, 28), C.item)
    local hardBtn = button(diffCard, "🔴 Hard", UDim2.new(1, -82, 0.5, -14), UDim2.fromOffset(74, 28), C.item)
    easyBtn.TextSize = 12
    hardBtn.TextSize = 12

    local function updateDiff()
        setButtonColor(easyBtn, Config.TicketDifficulty == "Easy" and C.ok or C.item)
        setButtonColor(hardBtn, Config.TicketDifficulty == "Hard" and C.danger or C.item)
    end
    updateDiff()
    easyBtn.MouseButton1Click:Connect(function() Config.TicketDifficulty = "Easy"; updateDiff() end)
    hardBtn.MouseButton1Click:Connect(function() Config.TicketDifficulty = "Hard"; updateDiff() end)

    local qStatus = infoCard(p, 34, C.warn)
    qStatus.Text = "Đang kiểm tra tiến độ..."

    actionButton(p, "⚡ Nhận Quest từ xa ngay", C.ok, function()
        if not Farm.events() then
            setStatus("Game này không có hệ thống Ticket Quest.", "warn")
            return
        end
        teleportFacingNPC()
        task.wait(0.5)
        local ok = Farm.interactWithNPC(Config.TicketDifficulty)
        setStatus(ok and "Đã tương tác nhận quest thành công." or "Không nhận được quest (thiếu NPC/executor API).",
            ok and "ok" or "warn")
    end)
    actionButton(p, "🎟 Nhận thưởng Vé quay ngay", C.warn, function()
        local ok = Farm.claimQuest()
        setStatus(ok and "Đã nhận thưởng quest." or "Quest chưa hoàn thành hoặc không có quest.",
            ok and "ok" or "warn")
    end)

    sectionLabel(p, "QUÀ & MÃ")
    local giftLbl = infoCard(p, 48, C.muted)
    giftLbl.Text = "Nhập giftcode chính thức → nhận Cash, Crystals & Tickets. Daily Rewards nhận 7 ngày một lần."

    actionButton(p, "🎁 Nhập toàn bộ Giftcodes", C.accent, function()
        local n = Farm.redeemCodes()
        giftLbl.Text = string.format("✅ Đã kích hoạt %d giftcode.", n)
        giftLbl.TextColor3 = C.ok
        setStatus("Đã kích hoạt " .. n .. " giftcode.", "ok")
    end)
    actionButton(p, "⭐ Nhận Daily Rewards (7 ngày)", C.item, function()
        local E = Farm.events()
        if E and E:FindFirstChild("DailyReward") then
            for i = 1, 7 do E.DailyReward:FireServer(i) end
            setStatus("Đã gửi yêu cầu nhận Daily Rewards.", "ok")
        else
            setStatus("Game này không có DailyReward.", "warn")
        end
    end)

    task.spawn(function()
        while gui.Parent and isActive() do
            task.wait(1)
            if activeTab == "Quest" and frame.Visible then
                if not Farm.events() then
                    qStatus.Text = "⚠ Không phải game Heavy Fishing"
                    qStatus.TextColor3 = C.muted
                else
                    local qName, prog, target = Farm.questProgress(25)
                    local cd = Farm.questCooldown()
                    if qName then
                        local pct = target > 0 and (prog / target) * 100 or 0
                        qStatus.Text = string.format("🎯 %s: %d / %d (%.0f%%)", qName, prog, target, pct)
                        qStatus.TextColor3 = C.warn
                    elseif cd > 0 then
                        qStatus.Text = string.format("⏳ Cooldown: %02d:%02d", math.floor(cd / 60), cd % 60)
                        qStatus.TextColor3 = C.muted
                    else
                        qStatus.Text = "🟢 Sẵn sàng nhận Quest mới!"
                        qStatus.TextColor3 = C.ok
                    end
                end
            end
        end
    end)
end

----------------------------------------------------------------
-- Dragging
----------------------------------------------------------------
local dragging = false
local dragStart, startPosition

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = frame.Position
    end
end)

connect(UserInputService.InputChanged, function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart
        local s = uiScale.Scale
        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X / s,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y / s
        )
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

----------------------------------------------------------------
-- Minimize / close / hotkey
----------------------------------------------------------------
local minimized = false

minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    tabBar.Visible = not minimized
    pageArea.Visible = not minimized
    statusBar.Visible = not minimized
    frame.Size = minimized
        and UDim2.fromOffset(WIDTH, TITLE_H)
        or UDim2.fromOffset(WIDTH, HEIGHT)
    minimize.Text = minimized and "+" or "–"
end)

local function destroyGui()
    -- dừng toàn bộ vòng lặp farm / hop
    genv._ACTIVE_FARM_RUNNER = nil
    Config.AutoFish, Config.AutoSkill, Config.TicketQuestEnabled, Config.BoostFps = false, false, false, false
    restoreFpsProperties()
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    gui:Destroy()
end

close.MouseButton1Click:Connect(destroyGui)

connect(UserInputService.InputBegan, function(input, processed)
    if processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift
        or input.KeyCode == Enum.KeyCode.RightControl
        or input.KeyCode == Enum.KeyCode.Insert then
        frame.Visible = not frame.Visible
    end
end)

----------------------------------------------------------------
-- Start
----------------------------------------------------------------
selectTab("Server")
setStatus("Ready. Press RightShift to hide/show.", nil)
