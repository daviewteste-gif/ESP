local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local flySpeed = 60
local maxFlySpeed = 150
local acceleration = 25
local deceleration = 35
local cameraSensitivity = 0.003
local verticalSpeed = 80
local maxCameraAngle = math.rad(70)

local player = game.Players.LocalPlayer
local character
local humanoid
local rootPart
local isFlying = false
local currentFlySpeed = 0
local moveDirection = Vector3.new(0, 0, 0)
local cameraCF = CFrame.new() -- Used for delta rotation calculation
local flyGui
local flyButton
local upButton
local downButton
local isTouch = UserInputService.TouchEnabled

local joystickX, joystickY = 0, 0
local isDraggingJoystick = false

local joystickBase
local joystickThumb

local joystickUpdateConnection -- Connection for joystick input handling

local function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

local function destroyGui()
    if flyGui then
        flyGui:Destroy()
        flyGui = nil
    end
    if joystickUpdateConnection then
        joystickUpdateConnection:Disconnect()
        joystickUpdateConnection = nil
    end
end

local function updateFlyState()
    if not character or not rootPart or not humanoid then return end
    if isFlying then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        flyButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
        flyButton.Text = "Desativar Fly"
    else
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        flyButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
        flyButton.Text = "Ativar Fly"
    end
end

local function toggleFly()
    isFlying = not isFlying
    currentFlySpeed = 0
    updateFlyState()
end

local function limitCameraAngle(cameraCFrame)
    local camera = workspace.CurrentCamera
    if not camera then return cameraCFrame end

    local currentCFrame = camera.CFrame
    local lookVector = currentCFrame.LookVector
    local pitch = math.asin(lookVector.Y)
    local yaw = math.atan2(-lookVector.Z, lookVector.X)

    pitch = clamp(pitch + cameraCF.X, -maxCameraAngle, maxCameraAngle)

    local newCFrame = CFrame.new(currentCFrame.Position) * CFrame.Angles(pitch, yaw, 0)
    return newCFrame
end

local function getCameraDirection()
    local camera = workspace.CurrentCamera
    if not camera then return Vector3.new(0, 0, 0) end
    return (camera.CFrame.LookVector * moveDirection.Z + camera.CFrame.RightVector * moveDirection.X).Unit
end

local function getJoystickDirection()
    return joystickX, joystickY
end

local function handleMovement(dt)
    if not isFlying or not rootPart then return end

    local targetSpeed = 0
    if moveDirection.Z ~= 0 or moveDirection.X ~= 0 then
        targetSpeed = maxFlySpeed
    end

    local accelRate = (moveDirection.Z ~= 0 or moveDirection.X ~= 0) and acceleration or deceleration
    currentFlySpeed = math.lerp(currentFlySpeed, targetSpeed, accelRate * dt)

    local moveVector = getCameraDirection() * currentFlySpeed
    local verticalMovement = Vector3.new(0, moveDirection.Y * verticalSpeed, 0)

    rootPart.Velocity = moveVector + verticalMovement
    rootPart.RotVelocity = Vector3.new(0, 0, 0)
end

local function createButton(text, sizeX, sizeY, posX, posY, callback, parent)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, sizeX, 0, sizeY)
    button.Position = UDim2.new(0, posX, 0, posY)
    button.Text = text
    button.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextScaled = true
    button.Parent = parent
    button.MouseButton1Click:Connect(callback)
    return button
end

local function createTouchButton(sizeX, sizeY, posX, posY, eventType, callback, parent)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, sizeX, 0, sizeY)
    frame.Position = UDim2.new(0, posX, 0, posY)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    frame.InputBegan:Connect(function(inputObject)
        if inputObject.UserInputType == eventType then
            callback(true)
        end
    end)
    frame.InputEnded:Connect(function(inputObject)
        if inputObject.UserInputType == eventType then
            callback(false)
        end
    end)
    return frame
end

local function createJoystick(sizeX, sizeY, posX, posY, parent)
    joystickBase = Instance.new("Frame")
    joystickBase.Size = UDim2.new(0, sizeX, 0, sizeY)
    joystickBase.Position = UDim2.new(0, posX, 0, posY)
    joystickBase.BackgroundColor3 = Color3.new(0,0,0)
    joystickBase.BackgroundTransparency = 0.5
    joystickBase.Parent = parent
    joystickBase.ZIndex = 2

    joystickThumb = Instance.new("Frame")
    joystickThumb.Size = UDim2.new(0, sizeY/3, 0, sizeY/3)
    joystickThumb.Position = UDim2.new(0, sizeY/3, 0, sizeY/3)
    joystickThumb.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
    joystickThumb.Parent = joystickBase

    local function updateJoystick(input)
        local touchPos = input.Position
        local baseSize = joystickBase.AbsoluteSize.X
        local thumbSize = joystickThumb.AbsoluteSize.X
        local baseX = joystickBase.AbsolutePosition.X
        local baseY = joystickBase.AbsolutePosition.Y
        local thumbX = clamp(touchPos.X - baseX, -baseSize/2, baseSize/2)
        local thumbY = clamp(touchPos.Y - baseY, -baseSize/2, baseSize/2)

        local x = thumbX / (baseSize/2)
        local y = thumbY / (baseSize/2)

        joystickX = x
        joystickY = y
        moveDirection = Vector3.new(joystickX, moveDirection.Y, joystickY) -- Update moveDirection directly

        joystickThumb.Position = UDim2.new(0, thumbX + baseSize/2 - thumbSize/2, 0, thumbY + baseSize/2 - thumbSize/2)
    end

    joystickBase.InputBegan:Connect(function(inputObject)
        if inputObject.UserInputType == Enum.UserInputType.Touch or inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingJoystick = true
            updateJoystick(inputObject)
            joystickThumb.BackgroundColor3 = Color3.new(0.6, 0.6, 0.6) -- Feedback visual
        end
    end)

    joystickBase.InputChanged:Connect(function(inputObject)
        if isDraggingJoystick and (inputObject.UserInputType == Enum.UserInputType.Touch or inputObject.UserInputType == Enum.UserInputType.MouseButton1) then
            updateJoystick(inputObject)
        end
    end)

    joystickBase.InputEnded:Connect(function(inputObject)
        if inputObject.UserInputType == Enum.UserInputType.Touch or inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingJoystick = false
            joystickX = 0
            joystickY = 0
            moveDirection = Vector3.new(0, moveDirection.Y, 0) -- Reset X/Z when joystick released
            joystickThumb.Position = UDim2.new(0, sizeY/3, 0, sizeY/3)
            joystickThumb.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8) -- Resetar cor
        end
    end)

    return joystickBase
end

local function createGui()
    flyGui = Instance.new("ScreenGui")
    flyGui.Parent = player.PlayerGui
    flyGui.IgnoreGuiInset = true

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 250)
    frame.Position = UDim2.new(0.1, 0, 0.1, 0)
    frame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.new(0, 0, 0)
    frame.Parent = flyGui

    local closeButton = createButton("X", 30, 30, 170, 10, function()
        destroyGui()
    end, frame)

    flyButton = createButton("Ativar Fly", 180, 30, 10, 10, toggleFly, frame)
    joystickBase = createJoystick(100, 100, 10, 50, frame)

    upButton = createTouchButton(80, 30, 10, 160, Enum.UserInputType.Touch, function(isDown)
        moveDirection = Vector3.new(moveDirection.X, isDown and 1 or 0, moveDirection.Z)
    end, frame)

    downButton = createTouchButton(80, 30, 110, 160, Enum.UserInputType.Touch, function(isDown)
        moveDirection = Vector3.new(moveDirection.X, isDown and -1 or 0, moveDirection.Z)
    end, frame)
end

local function onCharacterAdded(char)
    character = char
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    updateFlyState()
end

local function onCharacterRemoving()
    if isFlying then
        toggleFly()
    end
    destroyGui()
end

player.CharacterAppearanceLoaded:Connect(function(char)
    onCharacterAdded(char)
end)

player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(onCharacterRemoving)
RunService.Heartbeat:Connect(handleMovement)

UserInputService.InputChanged:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if isFlying and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local deltaX = input.Delta.X * cameraSensitivity
        local deltaY = input.Delta.Y * cameraSensitivity

        local camera = workspace.CurrentCamera
        if not camera then return end

        local currentCFrame = camera.CFrame
        local potentialNewCFrame = currentCFrame * CFrame.Angles(-deltaY, -deltaX, 0)

        camera.CFrame = limitCameraAngle(potentialNewCFrame)
    end
end)

if player.Character then
    onCharacterAdded(player.Character)
end
createGui()

game:BindToClose(function()
    if isFlying then
        toggleFly()
    end
    destroyGui()
end)
