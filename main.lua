local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local guiParent = game:GetService("CoreGui")

local oldGui = guiParent:FindFirstChild("UniversalServerJoiner")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "UniversalServerJoiner"
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

----------------------------------------------------------------
-- Main window
----------------------------------------------------------------
local WIDTH, HEIGHT = 460, 520
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

label(titleBar, "Universal Server Joiner", UDim2.fromOffset(14, 0),
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

local tabNames = { "Server", "NPC", "Island" }
local tabTitles = {
    Server = "🌐  Server",
    NPC = "👤  NPC",
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

----------------------------------------------------------------
-- SERVER PAGE
----------------------------------------------------------------
local serverPage = pages.Server

label(serverPage, "JOIN SERVER BY JOBID", UDim2.fromOffset(14, 12),
    UDim2.new(1, -28, 0, 16), 11, C.muted, true)

local jobInput = textBox(serverPage, "Paste server JobId here...",
    UDim2.fromOffset(14, 34), UDim2.new(1, -28, 0, 38))

local joinButton = button(serverPage, "JOIN SERVER",
    UDim2.fromOffset(14, 80), UDim2.new(1, -28, 0, 40), C.accent)
joinButton.TextSize = 14

-- Current server card
label(serverPage, "CURRENT SERVER", UDim2.fromOffset(14, 138),
    UDim2.new(1, -28, 0, 16), 11, C.muted, true)

local infoCard = create("Frame", {
    Position = UDim2.fromOffset(14, 160),
    Size = UDim2.new(1, -28, 0, 96),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, serverPage)
corner(infoCard, 8)
stroke(infoCard)

local function infoRow(y, title)
    label(infoCard, title, UDim2.fromOffset(12, y), UDim2.fromOffset(70, 20), 12, C.muted)
    return label(infoCard, "-", UDim2.fromOffset(84, y),
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

local pasteHint = label(serverPage,
    "Tip: press Enter in the box to join quickly.",
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

----------------------------------------------------------------
-- NPC PAGE
----------------------------------------------------------------
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

local hintLabel = label(npcPage, "Tip: double-click to teleport. Next switches between locations.",
    UDim2.new(0, 14, 1, -20), UDim2.new(1, -28, 0, 16), 11, C.muted)

----------------------------------------------------------------
-- NPC logic (NPCs with the same name are grouped together)
----------------------------------------------------------------
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

local function getPlayerRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getDistance(npc)
    local pr, nr = getPlayerRoot(), getRoot(npc)
    if pr and nr then
        return math.floor((pr.Position - nr.Position).Magnitude)
    end
    return math.huge
end

-- Distance to the nearest location of a group
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

            -- Selecting a different group starts at its first location
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

            -- Keep the previous selection (by name) if it still exists
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

-- Events
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

local function destroyGui()
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    gui:Destroy()
end

close.MouseButton1Click:Connect(destroyGui)

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
selectTab("Server")
setStatus("Ready. Press RightShift to hide/show.", nil)
refreshNPCs()
refreshIslands()
