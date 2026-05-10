local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP_ENABLED = true
local MAX_DISTANCE = 500

local ESP_DATA = {}

local function CreateDrawing(type, properties)
    local drawing = Drawing.new(type)
    for prop, val in pairs(properties) do
        drawing[prop] = val
    end
    return drawing
end

local function RemovePlayerESP(player, forceRemove)
    local data = ESP_DATA[player]
    if not data then return end
    
    if data.Connection then 
        data.Connection:Disconnect() 
    end
    
    for _, drawing in pairs(data.Drawings) do
        drawing.Visible = false
        drawing:Remove()
    end
    ESP_DATA[player] = nil
end

local function AddESP(player)
    if player == LocalPlayer then return end
    if ESP_DATA[player] then RemovePlayerESP(player, true) end

    local data = {
        Drawings = {
            Box = CreateDrawing("Square", {Thickness = 2, Color = Color3.new(1, 1, 1), Filled = false, Visible = false}),
            Tracer = CreateDrawing("Line", {Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 1, Visible = false}),
            Text = CreateDrawing("Text", {Size = 14, Center = true, Outline = true, OutlineColor = Color3.new(0, 0, 0), Color = Color3.new(1, 1, 1), Visible = false})
        }
    }

    local function UpdateRefs(char)
        data.Character = char
        data.Root = char:WaitForChild("HumanoidRootPart", 5)
        data.Hum = char:WaitForChild("Humanoid", 5) -- Mantido caso precise para algo
        data.Head = char:WaitForChild("Head", 5)
    end

    data.Connection = player.CharacterAdded:Connect(UpdateRefs)
    if player.Character then UpdateRefs(player.Character) end

    ESP_DATA[player] = data
end

local function UpdateDrawingsVisibility(enable)
    ESP_ENABLED = enable
    for _, data in pairs(ESP_DATA) do
        if not data then continue end
        for _, d in pairs(data.Drawings) do
            d.Visible = enable
        end
    end
end

local function CleanAllDrawings()
    for _, data in pairs(ESP_DATA) do
        if not data then continue end
        for _, d in pairs(data.Drawings) do
            d.Visible = false
            d:Remove()
        end
        if data.Connection then data.Connection:Disconnect() end
    end
    ESP_DATA = {} 
end

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Insert then
        UpdateDrawingsVisibility(not ESP_ENABLED) 
        if not ESP_ENABLED then
            ToggleButton.Text = "ESP OFF"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
            CleanAllDrawings() 
        else
            ToggleButton.Text = "ESP ON"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            for player, data in pairs(ESP_DATA) do
                if data and data.Character and data.Character.Parent and data.Head then
                    local _, onScreen = Camera:WorldToViewportPoint(data.Head.Position)
                    if onScreen then
                        for _, d in pairs(data.Drawings) do
                            d.Visible = true
                        end
                    end
                end
            end
        end
    end
end)

Players.PlayerAdded:Connect(AddESP)
Players.PlayerRemoving:Connect(RemovePlayerESP)

for _, p in ipairs(Players:GetPlayers()) do
    AddESP(p)
end

RunService.RenderStepped:Connect(function()
    if not ESP_ENABLED then return end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myTeam = LocalPlayer.Team

    local playersToRemove = {}

    for player, data in pairs(ESP_DATA) do
        if not data or not data.Character or not data.Root or not data.Hum or not data.Head or not data.Hum.Parent or not data.Root.Parent or not data.Head.Parent or data.Hum.Health <= 0 then
            table.insert(playersToRemove, player)
            continue
        end
        
        local root = data.Root
        local head = data.Head
        local drawings = data.Drawings

        local isAlly = (player.Team and myTeam and player.Team == myTeam)
        if isAlly then
          for _, d in pairs(drawings) do 
              d.Visible = false
          end
          continue
        end

        local dist = myRoot and (myRoot.Position - root.Position).Magnitude or 0

        if dist > MAX_DISTANCE then
            for _, d in pairs(drawings) do 
                d.Visible = false
            end
            continue
        end
        
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        
        if onScreen then
            local legPos = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, -3.5, 0))
            
            local height = math.abs(headPos.Y - legPos.Y)
            local width = height / 1.6
            local xPos = headPos.X - width / 2
            local yPos = headPos.Y

            drawings.Box.Size = Vector2.new(width, height)
            drawings.Box.Position = Vector2.new(xPos, yPos)
            drawings.Box.Visible = true

            drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            drawings.Tracer.To = Vector2.new(headPos.X, legPos.Y)
            drawings.Tracer.Visible = true

            local textColor = Color3.new(1,1,1)
            if dist < 50 then textColor = Color3.new(1,0,0)
            elseif dist < 150 then textColor = Color3.new(1,1,0) end
            drawings.Text.Position = Vector2.new(headPos.X, yPos - 30)
            drawings.Text.Color = textColor
            drawings.Text.Text = string.format("%s\n[%d studs]", player.Name, math.floor(dist))
            drawings.Text.Visible = true

            -- Esconde tudo se ESP_ENABLED for false (se o botão estiver desligado)
            if not ESP_ENABLED then
                for _, d in pairs(drawings) do d.Visible = false end
                continue
            end

        else 
            for _, d in pairs(drawings) do 
                d.Visible = false
            end
        end
    end

    for _, player in pairs(playersToRemove) do
        RemovePlayerESP(player)
    end
end)

-- GUI para Ligar/Desligar no Mobile (sem comentários)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ESP_GUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleESP"
ToggleButton.Size = UDim2.new(0, 120, 0, 50) 
ToggleButton.Position = UDim2.new(0.05, 0, 0.85, 0) 
ToggleButton.Text = "ESP ON"
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0) 
ToggleButton.BorderSizePixel = 2
ToggleButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
ToggleButton.Parent = ScreenGui

ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

ToggleButton.MouseButton1Click:Connect(function()
    UpdateDrawingsVisibility(not ESP_ENABLED) 
    if not ESP_ENABLED then
        ToggleButton.Text = "ESP OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        -- CleanAllDrawings() -- Remover essa linha se o problema for a limpeza completa
    else
        ToggleButton.Text = "ESP ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    end
end)
