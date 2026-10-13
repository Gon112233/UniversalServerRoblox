--========================================================
-- CHU TIANJIAO AUTO HOP + ISLAND TELEPORT
--========================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local PLACE_ID = game.PlaceId

local enabled = false
local running = false
local visited = {}

local KNOWN_DIALOGUES = {
    ["I can feel it. Something is approaching"] = true,
    ["This sea... still bears no trace of the Four Sacred Beasts"] = true,
}

local oldGui = CoreGui:FindFirstChild("ChuTianjiaoAutoHop")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ChuTianjiaoAutoHop"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999

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
    return create("UIStroke", {
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

----------------------------------------------------------------
-- Main window
----------------------------------------------------------------
local WIDTH, HEIGHT = 440, 480
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

local titleBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, TITLE_H),
    BackgroundColor3 = C.header,
    BorderSizePixel = 0,
    Active = true,
}, frame)

label(titleBar, "Chu Tianjiao Auto Hop", UDim2.fromOffset(14, 0),
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

local function selectTab(name)
    for tabName, b in pairs(tabButtons) do
        local active = tabName == name
        setButtonColor(b, active and C.accent or C.header)
        b.TextColor3 = active and C.text or C.muted
    end
    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end
end

local tabNames = { "AutoHop", "Island" }
local tabTitles = {
    AutoHop = "🤖  CHU TIANJIAO AUTO HOP",
    Island = "🏝  Island",
}
for i, name in ipairs(tabNames) do
    local b = button(tabBar, tabTitles[name],
        UDim2.new((i - 1) / #tabNames, 6, 0, 4),
        UDim2.new(1 / #tabNames, -12, 1, -8), C.header)
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

local statusText = label(statusBar, "Idle.", UDim2.fromOffset(30, 0),
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

----------------------------------------------------------------
-- AUTO HOP PAGE (UI)
----------------------------------------------------------------
local hopPage = pages.AutoHop

label(hopPage, "AUTO HOP", UDim2.fromOffset(14, 12),
    UDim2.new(0.5, -18, 0, 16), 11, C.muted, true)
label(hopPage, "DELAY BEFORE HOP (SEC)", UDim2.new(0.5, 4, 0, 12),
    UDim2.new(0.5, -18, 0, 16), 11, C.muted, true)

local toggle = button(hopPage, "AUTO HOP: OFF",
    UDim2.fromOffset(14, 34), UDim2.new(0.5, -18, 0, 40), C.ok)

local delayBox = textBox(hopPage, "Delay seconds",
    UDim2.new(0.5, 4, 0, 34), UDim2.new(0.5, -18, 0, 40))
delayBox.Text = "10"

label(hopPage, "CURRENT SERVER", UDim2.fromOffset(14, 92),
    UDim2.new(1, -28, 0, 16), 11, C.muted, true)

local jobCard = create("Frame", {
    Position = UDim2.fromOffset(14, 114),
    Size = UDim2.new(1, -28, 0, 40),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, hopPage)
corner(jobCard, 8)
stroke(jobCard)

label(jobCard, "JobId", UDim2.fromOffset(12, 10), UDim2.fromOffset(50, 20), 12, C.muted)
local job = label(jobCard, game.JobId ~= "" and game.JobId or "(Studio / none)",
    UDim2.fromOffset(64, 10), UDim2.new(1, -76, 0, 20), 12, C.text)

label(hopPage, "NPC DIALOGUE", UDim2.fromOffset(14, 170),
    UDim2.new(1, -28, 0, 16), 11, C.muted, true)

local dialogueCard = create("Frame", {
    Position = UDim2.fromOffset(14, 192),
    Size = UDim2.new(1, -28, 0, 110),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, hopPage)
corner(dialogueCard, 8)
local dialogueStroke = stroke(dialogueCard)

local dialogue = label(dialogueCard, "Waiting for Chu Tianjiao...",
    UDim2.fromOffset(12, 8), UDim2.new(1, -24, 1, -16), 13, C.text)
dialogue.TextWrapped = true
dialogue.TextTruncate = Enum.TextTruncate.None
dialogue.TextYAlignment = Enum.TextYAlignment.Top

local hopTip = label(hopPage,
    "Tip: stops automatically when the NPC says something unknown. RightShift hides the window.",
    UDim2.fromOffset(14, 314), UDim2.new(1, -28, 0, 32), 11, C.muted)
hopTip.TextWrapped = true
hopTip.TextTruncate = Enum.TextTruncate.None
hopTip.TextYAlignment = Enum.TextYAlignment.Top

local function alertDialogue(on)
    dialogueStroke.Color = on and C.warn or C.border
    dialogueStroke.Thickness = on and 2 or 1
end

local function setEnabled(value)
    enabled = value
    toggle.Text = value and "AUTO HOP: ON" or "AUTO HOP: OFF"
    setButtonColor(toggle, value and C.danger or C.ok)
    tabButtons.AutoHop.Text = value and "🤖  Auto Hop  ●" or tabTitles.AutoHop

    if not value then
        setStatus("OFF", nil)
    end
end

----------------------------------------------------------------
-- NPC lookup
----------------------------------------------------------------
local function findChuNPC()
    local npcFolder = Workspace:FindFirstChild("NPC")
    local functionFolder = npcFolder
        and npcFolder:FindFirstChild("Function")

    return functionFolder
        and functionFolder:FindFirstChild("Chu Tianjiao")
end

local function getRoot(object)
    if not object then
        return nil
    end

    if object:IsA("BasePart") then
        return object
    end

    if object:IsA("Model") then
        return object:FindFirstChild("HumanoidRootPart")
            or object.PrimaryPart
            or object:FindFirstChildWhichIsA("BasePart", true)
    end

    return object:FindFirstChildWhichIsA("BasePart", true)
end

local function teleportToChu(npc)
    local character = player.Character
    if not character then
        return false, "Character not loaded"
    end

    local npcRoot = getRoot(npc)
    if not npcRoot then
        return false, "NPC root part not found"
    end

    character:PivotTo(npcRoot.CFrame * CFrame.new(0, 0, 4))
    return true
end

--========================================================
-- Press E
--========================================================

local function pressE()
    local ok, err = pcall(function()
        VirtualInputManager:SendKeyEvent(
            true, Enum.KeyCode.E, false, game
        )

        task.wait(0.15)

        VirtualInputManager:SendKeyEvent(
            false, Enum.KeyCode.E, false, game
        )
    end)

    if not ok then
        warn("[ChuAutoHop] Press E failed:", err)
    end

    return ok
end

--========================================================
-- Dialogue detection
--========================================================

local function isVisibleInTree(object)
    local current = object

    while current and current ~= player.PlayerGui do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        current = current.Parent
    end

    return true
end

local function readDialogue()
    local pg = player:FindFirstChild("PlayerGui")
    local mainGui = pg and pg:FindFirstChild("MainGui")
    local menu = mainGui and mainGui:FindFirstChild("Menu")
    local frameDialogue = menu and menu:FindFirstChild("Dialogue")

    if not frameDialogue or not isVisibleInTree(frameDialogue) then
        return nil, nil
    end

    local body = frameDialogue:FindFirstChild("Dialog")
    local title = frameDialogue:FindFirstChild("Title")

    if not body or not body:IsA("TextLabel") then
        return nil, nil
    end

    if body.Text == "" then
        return nil, nil
    end

    local titleText = ""
    if title and title:IsA("TextLabel") then
        titleText = title.Text
    end

    return titleText, body.Text
end

--========================================================
-- Public server hopping
--========================================================

local function hopServer()
    setStatus("Searching public servers...", "info")

    local cursor = ""
    local candidates = {}

    for _ = 1, 3 do
        if not enabled then
            return false
        end

        local url = "https://games.roblox.com/v1/games/"
            .. PLACE_ID
            .. "/servers/Public?sortOrder=Asc&limit=100"

        if cursor ~= "" then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end

        local ok, response = pcall(function()
            return game:HttpGet(url)
        end)

        if not ok then
            setStatus("Server request failed", "error")
            return false
        end

        local decoded, data = pcall(function()
            return HttpService:JSONDecode(response)
        end)

        if not decoded or type(data) ~= "table" then
            setStatus("Invalid server response", "error")
            return false
        end

        for _, server in ipairs(data.data or {}) do
            if server.id ~= game.JobId
                and (server.playing or 0) < (server.maxPlayers or 0)
                and not visited[server.id] then

                table.insert(candidates, server.id)
            end
        end

        cursor = data.nextPageCursor or ""

        if #candidates > 0 or cursor == "" then
            break
        end
    end

    if #candidates == 0 then
        setStatus("No available new server", "warn")
        return false
    end

    local serverId = candidates[math.random(1, #candidates)]
    visited[serverId] = true

    setStatus("Teleporting to new server...", "info")

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            PLACE_ID,
            serverId,
            player
        )
    end)

    if not ok then
        setStatus("Teleport failed", "error")
        warn("[ChuAutoHop] Teleport error:", err)
        return false
    end

    return true
end

--========================================================
-- Main Auto Hop loop
--========================================================

local function startAutoHop()
    if running then
        return
    end

    running = true

    task.spawn(function()
        while enabled and gui.Parent do
            local npc = findChuNPC()

            if not npc then
                setStatus("Chu Tianjiao not found", "warn")
                task.wait(2)
            else
                setStatus("Teleporting to NPC...", "info")

                local tpOK, tpError = teleportToChu(npc)

                if not tpOK then
                    setStatus(tostring(tpError), "warn")
                    task.wait(2)
                else
                    task.wait(0.7)

                    setStatus("Sending E...", "info")
                    local eOK = pressE()

                    if not eOK then
                        setStatus("Failed to send E", "error")
                    else
                        setStatus("E sent; waiting dialogue...", "info")
                    end

                    local titleText, bodyText

                    for _ = 1, 30 do
                        if not enabled then
                            break
                        end

                        titleText, bodyText = readDialogue()

                        if bodyText then
                            break
                        end

                        task.wait(0.5)
                    end

                    if not enabled then
                        break
                    end

                    if not bodyText then
                        setStatus("Dialogue not detected", "warn")
                        task.wait(2)
                    else
                        dialogue.Text = "NPC: " .. tostring(titleText)
                            .. "\n" .. tostring(bodyText)

                        job.Text = game.JobId

                        if not KNOWN_DIALOGUES[bodyText] then
                            setEnabled(false)
                            alertDialogue(true)
                            setStatus("Stopped: Unknown dialogue", "warn")
                            break
                        end

                        local delaySeconds = tonumber(delayBox.Text) or 10
                        delaySeconds = math.clamp(
                            math.floor(delaySeconds), 1, 300
                        )

                        local cancelled = false

                        for remaining = delaySeconds, 1, -1 do
                            if not enabled then
                                cancelled = true
                                break
                            end

                            setStatus("Hopping in "
                                .. remaining .. " seconds", "info")

                            task.wait(1)

                            local _, currentBody = readDialogue()

                            if currentBody and currentBody ~= bodyText then
                                dialogue.Text =
                                    "NPC dialogue changed:\n" .. currentBody

                                if not KNOWN_DIALOGUES[currentBody] then
                                    setEnabled(false)
                                    alertDialogue(true)
                                    setStatus("Stopped: Unknown dialogue", "warn")
                                    cancelled = true
                                    break
                                end

                                cancelled = true
                                break
                            end
                        end

                        if not enabled then
                            break
                        end

                        if not cancelled then
                            hopServer()
                            task.wait(5)
                        end
                    end
                end
            end
        end

        running = false
    end)
end

toggle.MouseButton1Click:Connect(function()
    setEnabled(not enabled)

    if enabled then
        alertDialogue(false)
        startAutoHop()
    end
end)

----------------------------------------------------------------
-- ISLAND PAGE (Heavyweight Fishing)
----------------------------------------------------------------
local islandPage = pages.Island

local ISLAND_NAMES = {
    "Battlefield Isle",
    "Mistpeak Isle",
    "Fallout Isle",
    "Frost Isle",
    "Bamboo Isle",
    "Weather Isle",
    "Amber Isle",
    "World Angler Isle",
    "Perch Isle",
    "Sovereign Isle",
    "Beginning Isle",
    "Coconut Isle",
    "Mystic Reef Isle",
}

local function getPlayerRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local islandSearch = textBox(islandPage, "🔍  Search island name...",
    UDim2.fromOffset(14, 10), UDim2.new(1, -116, 0, 34))

local islandRefresh = button(islandPage, "↻ Refresh",
    UDim2.new(1, -96, 0, 10), UDim2.fromOffset(82, 34), C.panel)
stroke(islandRefresh)

local islandCount = label(islandPage, "Islands: 0  |  Results: 0",
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

local islandEmpty = label(islandPage, "No islands found in this game.",
    UDim2.fromOffset(14, 120), UDim2.new(1, -28, 0, 30), 13, C.muted)
islandEmpty.TextXAlignment = Enum.TextXAlignment.Center
islandEmpty.ZIndex = 0
islandEmpty.Visible = false

local islandSelectedLabel = label(islandPage, "Selected: none",
    UDim2.new(0, 14, 1, -88), UDim2.new(1, -28, 0, 20), 12, C.muted)

local islandTeleport = button(islandPage, "TELEPORT TO ISLAND",
    UDim2.new(0, 14, 1, -62), UDim2.new(1, -28, 0, 38), C.accent)
islandTeleport.TextSize = 14

label(islandPage, "Tip: double-click an island to teleport.",
    UDim2.new(0, 14, 1, -20), UDim2.new(1, -28, 0, 16), 11, C.muted)

local islandSpawns = {}      -- { {name = string, part = BasePart}, ... }
local islandFiltered = {}
local islandRows = {}
local selectedIsland = nil
local lastIslandClick, lastIslandTime = nil, 0

local function scanIslands()
    islandSpawns = {}
    local folder = Workspace:FindFirstChild("Spawnpoint")
    if not folder then
        return false
    end
    for _, islandName in ipairs(ISLAND_NAMES) do
        local part = folder:FindFirstChild(islandName)
        if part and part:IsA("BasePart") then
            table.insert(islandSpawns, { name = islandName, part = part })
        end
    end
    return true
end

local function setSelectedIsland(entry)
    selectedIsland = entry
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

local function teleportToIsland(entry)
    if not entry or not entry.part or not entry.part:IsDescendantOf(Workspace) then
        setStatus("Island no longer exists. Press Refresh.", "warn")
        return
    end
    local character = player.Character
    if not character or not getPlayerRoot() then
        setStatus("Your character root was not found.", "error")
        return
    end
    local ok, err = pcall(function()
        character:PivotTo(entry.part.CFrame + Vector3.new(0, 5, 0))
    end)
    if ok then
        setStatus("Teleported to " .. entry.name .. ".", "ok")
    else
        setStatus("Teleport failed: " .. tostring(err), "error")
    end
end

local function renderIslands()
    for _, child in ipairs(islandList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    islandRows = {}

    local query = islandSearch.Text:lower():match("^%s*(.-)%s*$")
    islandFiltered = {}
    for _, entry in ipairs(islandSpawns) do
        if query == "" or entry.name:lower():find(query, 1, true) then
            table.insert(islandFiltered, entry)
        end
    end

    for i, entry in ipairs(islandFiltered) do
        local row = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = entry == selectedIsland and C.selected or C.item,
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
            BackgroundColor3 = C.accent,
            BorderSizePixel = 0,
        }, row)

        label(row, entry.name, UDim2.fromOffset(16, 0),
            UDim2.new(1, -90, 1, 0), 13, C.text)

        local distLabel = label(row, "", UDim2.new(1, -72, 0, 0),
            UDim2.fromOffset(62, 34), 11, C.muted)
        distLabel.TextXAlignment = Enum.TextXAlignment.Right
        local pr = getPlayerRoot()
        if pr then
            distLabel.Text = math.floor((pr.Position - entry.part.Position).Magnitude) .. "m"
        else
            distLabel.Text = "-"
        end

        row.MouseEnter:Connect(function()
            if entry ~= selectedIsland then
                row.BackgroundColor3 = C.itemHover
            end
        end)
        row.MouseLeave:Connect(function()
            row.BackgroundColor3 = entry == selectedIsland and C.selected or C.item
        end)

        row.MouseButton1Click:Connect(function()
            local now = os.clock()
            local isDouble = lastIslandClick == entry and now - lastIslandTime < 0.4
            lastIslandClick, lastIslandTime = entry, now

            setSelectedIsland(entry)
            if isDouble then
                lastIslandClick = nil
                teleportToIsland(entry)
            else
                setStatus("Selected " .. entry.name .. ".", "info")
            end
        end)

        islandRows[entry] = row
    end

    islandList.CanvasPosition = Vector2.zero
    islandCount.Text = "Islands: " .. #islandSpawns .. "  |  Results: " .. #islandFiltered
    islandEmpty.Visible = #islandFiltered == 0
end

local function refreshIslands()
    local hasFolder = scanIslands()

    -- Keep the previous selection (by name) if it still exists
    local previousName = selectedIsland and selectedIsland.name
    selectedIsland = nil
    if previousName then
        for _, entry in ipairs(islandSpawns) do
            if entry.name == previousName then
                selectedIsland = entry
                break
            end
        end
    end

    renderIslands()
    setSelectedIsland(selectedIsland)

    if not hasFolder then
        setStatus("Workspace.Spawnpoint not found (wrong game?).", "warn")
    else
        setStatus("Found " .. #islandSpawns .. " island(s).", "ok")
    end
end

connect(islandSearch:GetPropertyChangedSignal("Text"), renderIslands)
islandRefresh.MouseButton1Click:Connect(refreshIslands)
islandTeleport.MouseButton1Click:Connect(function()
    if not selectedIsland then
        setStatus("Select an island from the list first.", "warn")
        return
    end
    teleportToIsland(selectedIsland)
end)

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
        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
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

close.MouseButton1Click:Connect(function()
    setEnabled(false)
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    gui:Destroy()
end)

-- RightShift: show / hide the whole window
connect(UserInputService.InputBegan, function(input, processed)
    if processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        frame.Visible = not frame.Visible
    end
end)

----------------------------------------------------------------
-- Start
----------------------------------------------------------------
gui.Parent = CoreGui

selectTab("AutoHop")
refreshIslands()
setStatus("Idle. Press RightShift to hide/show.", nil)

print("[ChuTianjiaoAutoHop] Loaded successfully")
