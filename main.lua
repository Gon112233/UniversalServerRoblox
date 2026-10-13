
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local guiParent = game:GetService("CoreGui")

local oldGui = guiParent:FindFirstChild("UniversalServerJoiner")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "UniversalServerJoiner"
gui.ResetOnSpawn = false
gui.Parent = guiParent

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 180)
frame.Position = UDim2.new(0.5, -160, 0.5, -90)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

-- Title bar: drag the window using this area
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(43, 43, 55)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = frame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "Universal Server Joiner"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 15
title.Font = Enum.Font.GothamSemibold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(30, 28)
minimize.Position = UDim2.new(1, -66, 0, 4)
minimize.Text = "–"
minimize.TextSize = 22
minimize.Font = Enum.Font.GothamBold
minimize.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.Parent = titleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimize

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(28, 28)
close.Position = UDim2.new(1, -32, 0, 4)
close.Text = "X"
close.TextSize = 13
close.Font = Enum.Font.GothamBold
close.BackgroundColor3 = Color3.fromRGB(180, 55, 60)
close.TextColor3 = Color3.new(1, 1, 1)
close.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = close

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -36)
content.Position = UDim2.fromOffset(0, 36)
content.BackgroundTransparency = 1
content.Parent = frame

local input = Instance.new("TextBox")
input.Size = UDim2.new(1, -20, 0, 36)
input.Position = UDim2.fromOffset(10, 10)
input.PlaceholderText = "Paste JobId here..."
input.Text = ""
input.ClearTextOnFocus = false
input.TextSize = 13
input.Font = Enum.Font.Gotham
input.BackgroundColor3 = Color3.fromRGB(48, 48, 60)
input.TextColor3 = Color3.new(1, 1, 1)
input.PlaceholderColor3 = Color3.fromRGB(170, 170, 180)
input.Parent = content

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 6)
inputCorner.Parent = input

local join = Instance.new("TextButton")
join.Size = UDim2.new(1, -20, 0, 32)
join.Position = UDim2.fromOffset(10, 54)
join.Text = "JOIN SERVER"
join.TextSize = 14
join.Font = Enum.Font.GothamBold
join.BackgroundColor3 = Color3.fromRGB(60, 125, 220)
join.TextColor3 = Color3.new(1, 1, 1)
join.Parent = content

local joinCorner = Instance.new("UICorner")
joinCorner.CornerRadius = UDim.new(0, 6)
joinCorner.Parent = join

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 28)
status.Position = UDim2.fromOffset(10, 92)
status.BackgroundTransparency = 1
status.Text = "PlaceId: " .. game.PlaceId
status.TextColor3 = Color3.fromRGB(180, 220, 180)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.Parent = content

-- Drag support for mouse and touch
local dragging = false
local dragStart
local startPosition
local dragInput

local function updatePosition(inputObject)
    local delta = inputObject.Position - dragStart
    frame.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end

titleBar.InputBegan:Connect(function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1
        or inputObject.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inputObject.Position
        startPosition = frame.Position
        dragInput = inputObject
    end
end)

UserInputService.InputChanged:Connect(function(inputObject)
    if dragging and (
        inputObject.UserInputType == Enum.UserInputType.MouseMovement
        or inputObject.UserInputType == Enum.UserInputType.Touch
    ) then
        updatePosition(inputObject)
    end
end)

UserInputService.InputEnded:Connect(function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1
        or inputObject.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Minimize and restore
local minimized = false
local expandedSize = frame.Size

minimize.MouseButton1Click:Connect(function()
    minimized = not minimized

    if minimized then
        expandedSize = frame.Size
        content.Visible = false
        frame.Size = UDim2.new(
            expandedSize.X.Scale,
            expandedSize.X.Offset,
            0,
            36
        )
        minimize.Text = "+"
    else
        frame.Size = expandedSize
        content.Visible = true
        minimize.Text = "–"
    end
end)

-- Join the selected server
join.MouseButton1Click:Connect(function()
    local jobId = input.Text:match("^%s*(.-)%s*$")

    if jobId == "" then
        status.Text = "Please enter a JobId."
        return
    end

    status.Text = "Attempting to join..."

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId,
            jobId,
            player
        )
    end)

    if not ok then
        status.Text = "Failed: " .. tostring(err)
    end
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)
