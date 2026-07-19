-- Zerox UI Library - Da Hood Style
-- Made for Roblox Executors

local Zerox = {}
Zerox.__index = Zerox

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function Create(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    return obj
end

function Zerox:CreateWindow(config)
    local self = setmetatable({}, Zerox)
    
    self.Window = Create("ScreenGui", {
        Name = "Zerox",
        ResetOnSpawn = false,
        Parent = player:WaitForChild("PlayerGui")
    })

    local MainFrame = Create("Frame", {
        Name = "Main",
        Size = config.Size or UDim2.new(0, 580, 0, 460),
        Position = UDim2.new(0.5, -290, 0.5, -230),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel = 0,
        Parent = self.Window
    })

    -- Top Bar (Da Hood style)
    local TopBar = Create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0,
        Parent = MainFrame
    })

    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = TopBar})
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = MainFrame})

    local Title = Create("TextLabel", {
        Text = config.Name or "ZER0X",
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar
    })
    Title.Position = UDim2.new(0, 15, 0, 0)

    -- Close Button
    local CloseBtn = Create("TextButton", {
        Text = "✕",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 80, 80),
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        Parent = TopBar
    })
    CloseBtn.MouseButton1Click:Connect(function()
        self.Window:Destroy()
    end)

    self.Accent = config.Accent or Color3.fromRGB(170, 0, 0)

    -- Content Area
    self.Content = Create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -20, 1, -60),
        Position = UDim2.new(0, 10, 0, 50),
        BackgroundTransparency = 1,
        Parent = MainFrame
    })

    -- Dragging
    local dragging, dragInput, dragStart
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            dragStartPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X, dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    self.Tabs = {}
    return self
end

function Zerox:CreateTab(name, icon)
    local TabBtn = Create("TextButton", {
        Name = name,
        Text = (icon or "") .. "  " .. name,
        Size = UDim2.new(0, 120, 0, 35),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.Gotham,
        Parent = self.Content -- You can make a TabBar here
    })

    -- For simplicity, I'll add a basic container. You can expand this.
    local TabPage = Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        Parent = self.Content
    })

    local Layout = Create("UIListLayout", {Parent = TabPage, Padding = UDim.new(0, 8)})

    return {
        CreateSection = function(_, sectionName)
            local Section = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Color3.fromRGB(25, 25, 25),
                Parent = TabPage
            })
            Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = Section})

            Create("TextLabel", {
                Text = sectionName,
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                TextColor3 = self.Accent,
                Font = Enum.Font.GothamBold,
                TextSize = 16,
                Parent = Section
            })

            return {
                CreateToggle = function(_, cfg)
                    -- Simple toggle example
                    local Toggle = Create("TextButton", {
                        Text = cfg.Name,
                        Size = UDim2.new(1, 0, 0, 35),
                        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
                        Parent = TabPage
                    })
                    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = Toggle})

                    local enabled = cfg.Default or false
                    Toggle.MouseButton1Click:Connect(function()
                        enabled = not enabled
                        Toggle.BackgroundColor3 = enabled and self.Accent or Color3.fromRGB(35, 35, 35)
                        cfg.Callback(enabled)
                    end)
                end,

                CreateButton = function(_, cfg)
                    local Btn = Create("TextButton", {
                        Text = cfg.Name,
                        Size = UDim2.new(1, 0, 0, 35),
                        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        Parent = TabPage
                    })
                    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = Btn})
                    Btn.MouseButton1Click:Connect(cfg.Callback)
                end,

                -- Add Slider, Dropdown, etc. similarly
            }
        end
    }
end

-- Notification function
function Zerox:Notify(text, duration)
    -- Simple notification implementation (you can expand)
    print("[ZER0X NOTIFY] " .. text)
end

return Zerox