
local Zerox = {}
Zerox.__index = Zerox

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function Create(class, properties)
    local obj = Instance.new(class)
    for prop, value in pairs(properties or {}) do
        obj[prop] = value
    end
    return obj
end

function Zerox:CreateWindow(config)
    local self = setmetatable({}, Zerox)
    
    -- Main ScreenGui
    self.ScreenGui = Create("ScreenGui", {
        Name = "Zerox",
        ResetOnSpawn = false,
        Parent = player:WaitForChild("PlayerGui")
    })

    -- Main Frame (Da Hood dark style)
    self.Main = Create("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0, 620, 0, 480),
        Position = UDim2.new(0.5, -310, 0.5, -240),
        BackgroundColor3 = Color3.fromRGB(18, 18, 18),
        BorderSizePixel = 0,
        Parent = self.ScreenGui
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = self.Main})
    Create("UIStroke", {Color = Color3.fromRGB(60, 60, 60), Thickness = 1.5, Parent = self.Main})

    -- Top Bar
    local TopBar = Create("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Color3.fromRGB(25, 25, 25),
        BorderSizePixel = 0,
        Parent = self.Main
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = TopBar})

    Create("TextLabel", {
        Text = "ZER0X",
        Size = UDim2.new(0.4, 0, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 60, 60),
        Font = Enum.Font.GothamBold,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 20, 0, 0),
        Parent = TopBar
    })

    -- Close Button
    local Close = Create("TextButton", {
        Text = "✕",
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(1, -45, 0.5, -20),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 80, 80),
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        Parent = TopBar
    })
    Close.MouseButton1Click:Connect(function() self.ScreenGui:Destroy() end)

    self.Accent = config.Accent or Color3.fromRGB(170, 0, 0)

    -- Tab Container
    self.TabBar = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 40),
        Position = UDim2.new(0, 10, 0, 60),
        BackgroundTransparency = 1,
        Parent = self.Main
    })

    self.Pages = Create("Frame", {
        Size = UDim2.new(1, -20, 1, -120),
        Position = UDim2.new(0, 10, 0, 110),
        BackgroundTransparency = 1,
        Parent = self.Main
    })

    self.CurrentTab = nil
    self.Tabs = {}

    self:MakeDraggable(TopBar)
    return self
end

function Zerox:MakeDraggable(bar)
    local dragging, dragStart, startPos
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = self.Main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            self.Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

function Zerox:CreateTab(name, icon)
    local tabButton = Create("TextButton", {
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        Text = (icon or "●") .. " " .. name,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        Parent = self.TabBar
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = tabButton})

    local page = Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = self.Accent,
        Visible = false,
        Parent = self.Pages
    })
    Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page})

    tabButton.MouseButton1Click:Connect(function()
        if self.CurrentTab then self.CurrentTab.Visible = false end
        page.Visible = true
        self.CurrentTab = page
    end)

    if not self.CurrentTab then
        page.Visible = true
        self.CurrentTab = page
    end

    local tab = {
        page = page,
        Accent = self.Accent
    }

    function tab:CreateSection(title)
        local section = Create("Frame", {
            Size = UDim2.new(1, -10, 0, 40),
            BackgroundColor3 = Color3.fromRGB(25, 25, 25),
            Parent = self.page
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = section})

        Create("TextLabel", {
            Text = "  " .. title,
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            TextColor3 = self.Accent,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = section
        })

        return {
            CreateButton = function(_, cfg)
                local btn = Create("TextButton", {
                    Size = UDim2.new(1, -20, 0, 42),
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                    Text = cfg.Name,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Font = Enum.Font.GothamSemibold,
                    TextSize = 15,
                    Parent = self.page
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = btn})
                btn.MouseButton1Click:Connect(cfg.Callback or function() end)
            end,

            CreateToggle = function(_, cfg)
                local toggled = cfg.Default or false
                local toggle = Create("TextButton", {
                    Size = UDim2.new(1, -20, 0, 42),
                    BackgroundColor3 = toggled and self.Accent or Color3.fromRGB(40, 40, 40),
                    Text = "  " .. cfg.Name,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Font = Enum.Font.GothamSemibold,
                    TextSize = 15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = self.page
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = toggle})

                toggle.MouseButton1Click:Connect(function()
                    toggled = not toggled
                    toggle.BackgroundColor3 = toggled and self.Accent or Color3.fromRGB(40, 40, 40)
                    if cfg.Callback then cfg.Callback(toggled) end
                end)
            end
        }
    end

    table.insert(self.Tabs, tab)
    return tab
end

function Zerox:Notify(text, duration)
    duration = duration or 3
    print("[ZER0X] " .. text)
    -- You can expand this into actual GUI notifications later
end

return Zerox
