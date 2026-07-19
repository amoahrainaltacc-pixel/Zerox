-- ZeroxUI v2.0
-- Da Hood inspired UI kit for Roblox — animated, extended component set
-- Standalone module: require() it from a LocalScript in your own place/tool

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Zerox = {}
Zerox.__index = Zerox

--============================================================
-- CONSTANTS
--============================================================

local EASE_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_OUT_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_SPRING = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EASE_LINEAR = TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

local COLORS = {
	Background = Color3.fromRGB(15, 15, 15),
	Surface = Color3.fromRGB(22, 22, 22),
	SurfaceLight = Color3.fromRGB(30, 30, 30),
	Border = Color3.fromRGB(50, 50, 50),
	Text = Color3.fromRGB(235, 235, 235),
	SubText = Color3.fromRGB(150, 150, 150),
	Accent = Color3.fromRGB(178, 0, 0),
	AccentBright = Color3.fromRGB(220, 30, 30),
	Success = Color3.fromRGB(70, 200, 110),
	Warning = Color3.fromRGB(230, 180, 60),
	Error = Color3.fromRGB(230, 70, 70),
}

--============================================================
-- HELPERS
--============================================================

local function Create(class, props, children)
	local obj = Instance.new(class)
	for prop, value in pairs(props or {}) do
		obj[prop] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	return obj
end

local function Tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function Corner(radius, parent)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function Stroke(color, thickness, parent)
	return Create("UIStroke", {
		Color = color or COLORS.Border,
		Thickness = thickness or 1,
		Parent = parent,
	})
end

local function Ripple(button, color)
	button.MouseButton1Down:Connect(function(x, y)
		local rel = Vector2.new(x, y) - Vector2.new(button.AbsolutePosition.X, button.AbsolutePosition.Y)
		local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.6

		local circle = Create("Frame", {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0, rel.X, 0, rel.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color or COLORS.AccentBright,
			BackgroundTransparency = 0.6,
			ZIndex = button.ZIndex + 1,
			Parent = button,
		})
		Corner(size, circle)

		Tween(circle, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, size, 0, size),
			BackgroundTransparency = 1,
		})

		task.delay(0.45, function()
			circle:Destroy()
		end)
	end)
end

local function HoverGlow(obj, baseColor, hoverColor)
	obj.MouseEnter:Connect(function()
		Tween(obj, EASE_OUT_FAST, { BackgroundColor3 = hoverColor })
	end)
	obj.MouseLeave:Connect(function()
		Tween(obj, EASE_OUT_FAST, { BackgroundColor3 = baseColor })
	end)
end

--============================================================
-- WINDOW
--============================================================

function Zerox:CreateWindow(config)
	config = config or {}
	local self = setmetatable({}, Zerox)

	self.Accent = config.Accent or COLORS.Accent
	self.AccentBright = config.AccentBright or COLORS.AccentBright

	self.ScreenGui = Create("ScreenGui", {
		Name = "ZeroxUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Notification container (top right stack)
	self.NotifyHolder = Create("Frame", {
		Name = "Notifications",
		Size = UDim2.new(0, 280, 1, -20),
		Position = UDim2.new(1, -300, 0, 10),
		BackgroundTransparency = 1,
		Parent = self.ScreenGui,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self.Main = Create("Frame", {
		Name = "MainFrame",
		Size = UDim2.new(0, 640, 0, 480),
		Position = UDim2.new(0.5, -320, 0.5, -230),
		BackgroundColor3 = COLORS.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.ScreenGui,
	})
	Corner(10, self.Main)
	Stroke(COLORS.Border, 1.5, self.Main)

	-- Intro pop-in animation
	self.Main.Size = UDim2.new(0, 0, 0, 0)
	self.Main.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
	Tween(self.Main, EASE_SPRING, {
		Size = UDim2.new(0, 640, 0, 480),
	})

	-- Top bar
	local TopBar = Create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = COLORS.Surface,
		BorderSizePixel = 0,
		Parent = self.Main,
	})
	Corner(10, TopBar)
	-- mask the bottom corners of the topbar so it looks square-bottomed
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = COLORS.Surface,
		BorderSizePixel = 0,
		Parent = TopBar,
	})

	local accentBar = Create("Frame", {
		Size = UDim2.new(0, 4, 1, -16),
		Position = UDim2.new(0, 0, 0, 8),
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		Parent = TopBar,
	})
	Corner(4, accentBar)

	Create("TextLabel", {
		Text = config.Title or "ZER0X",
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0, 24, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = TopBar,
	})

	if config.SubTitle then
		Create("TextLabel", {
			Text = config.SubTitle,
			Size = UDim2.new(0.5, 0, 0, 14),
			Position = UDim2.new(0, 24, 0, 30),
			BackgroundTransparency = 1,
			TextColor3 = COLORS.SubText,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = TopBar,
		})
	end

	-- Close button
	local Close = Create("TextButton", {
		Text = "✕",
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -46, 0.5, -18),
		BackgroundColor3 = COLORS.SurfaceLight,
		BackgroundTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		AutoButtonColor = false,
		Parent = TopBar,
	})
	Corner(8, Close)
	Close.MouseEnter:Connect(function()
		Tween(Close, EASE_OUT_FAST, { BackgroundTransparency = 0, TextColor3 = COLORS.Error })
	end)
	Close.MouseLeave:Connect(function()
		Tween(Close, EASE_OUT_FAST, { BackgroundTransparency = 1, TextColor3 = COLORS.SubText })
	end)
	Close.MouseButton1Click:Connect(function()
		local t = Tween(self.Main, EASE_OUT, {
			Size = UDim2.new(0, 0, 0, 0),
		})
		t.Completed:Wait()
		self.ScreenGui:Destroy()
	end)

	-- Minimize button
	local Minimize = Create("TextButton", {
		Text = "—",
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -86, 0.5, -18),
		BackgroundColor3 = COLORS.SurfaceLight,
		BackgroundTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		AutoButtonColor = false,
		Parent = TopBar,
	})
	Corner(8, Minimize)
	Minimize.MouseEnter:Connect(function()
		Tween(Minimize, EASE_OUT_FAST, { BackgroundTransparency = 0 })
	end)
	Minimize.MouseLeave:Connect(function()
		Tween(Minimize, EASE_OUT_FAST, { BackgroundTransparency = 1 })
	end)

	self.Minimized = false
	self.FullSize = UDim2.new(0, 640, 0, 480)
	Minimize.MouseButton1Click:Connect(function()
		self.Minimized = not self.Minimized
		if self.Minimized then
			Tween(self.Main, EASE_OUT, { Size = UDim2.new(0, 640, 0, 52) })
		else
			Tween(self.Main, EASE_OUT, { Size = self.FullSize })
		end
	end)

	-- Tab bar (left rail style, Da Hood menus read vertical)
	self.TabBar = Create("ScrollingFrame", {
		Name = "TabBar",
		Size = UDim2.new(0, 150, 1, -68),
		Position = UDim2.new(0, 10, 0, 60),
		BackgroundColor3 = COLORS.Surface,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = self.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.Main,
	})
	Corner(8, self.TabBar)
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.TabBar,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = self.TabBar,
	})

	self.Pages = Create("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, -180, 1, -68),
		Position = UDim2.new(0, 170, 0, 60),
		BackgroundTransparency = 1,
		Parent = self.Main,
	})

	self.CurrentTab = nil
	self.CurrentTabButton = nil
	self.Tabs = {}

	self:_MakeDraggable(TopBar)
	return self
end

function Zerox:_MakeDraggable(bar)
	local dragging, dragStart, startPos
	local mainFrame = self.Main

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--============================================================
-- NOTIFICATIONS
--============================================================

local NOTIFY_COLORS = {
	Info = COLORS.Accent,
	Success = COLORS.Success,
	Warning = COLORS.Warning,
	Error = COLORS.Error,
}

function Zerox:Notify(config)
	if type(config) == "string" then
		config = { Title = "Notice", Text = config }
	end
	local kind = config.Type or "Info"
	local duration = config.Duration or 3.5
	local barColor = NOTIFY_COLORS[kind] or self.Accent

	local card = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.Surface,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.NotifyHolder,
	})
	Corner(8, card)
	Stroke(COLORS.Border, 1, card)

	local bar = Create("Frame", {
		Size = UDim2.new(0, 4, 1, -12),
		Position = UDim2.new(0, 0, 0, 6),
		BackgroundColor3 = barColor,
		BackgroundTransparency = 1,
		Parent = card,
	})
	Corner(4, bar)

	local title = Create("TextLabel", {
		Text = config.Title or kind,
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.new(0, 16, 0, 8),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	local body = Create("TextLabel", {
		Text = config.Text or "",
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 16, 0, 28),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	Create("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = card })

	-- slide + fade in
	card.Position = UDim2.new(1, 40, 0, 0)
	Tween(card, EASE_SPRING, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
	Tween(bar, EASE_OUT, { BackgroundTransparency = 0 })
	Tween(title, EASE_OUT, { TextTransparency = 0 })
	Tween(body, EASE_OUT, { TextTransparency = 0 })

	task.delay(duration, function()
		local outTweens = {
			Tween(card, EASE_OUT, { BackgroundTransparency = 1, Position = UDim2.new(1, 40, 0, 0) }),
			Tween(bar, EASE_OUT, { BackgroundTransparency = 1 }),
			Tween(title, EASE_OUT, { TextTransparency = 1 }),
			Tween(body, EASE_OUT, { TextTransparency = 1 }),
		}
		outTweens[1].Completed:Wait()
		card:Destroy()
	end)
end

--============================================================
-- TABS
--============================================================

function Zerox:CreateTab(name, icon)
	local tabButton = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = COLORS.SurfaceLight,
		BackgroundTransparency = 0.3,
		Text = "",
		AutoButtonColor = false,
		Parent = self.TabBar,
	})
	Corner(6, tabButton)

	local indicator = Create("Frame", {
		Size = UDim2.new(0, 3, 0, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = self.Accent,
		Parent = tabButton,
	})
	Corner(3, indicator)

	Create("TextLabel", {
		Text = (icon and (icon .. "  ") or "") .. name,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.GothamSemibold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tabButton,
	})
	local label = tabButton:FindFirstChildOfClass("TextLabel")

	local page = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = self.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.Pages,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	Create("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = page })

	local zerox = self
	local function selectTab()
		if zerox.CurrentTab == page then return end

		if zerox.CurrentTab then
			local oldPage = zerox.CurrentTab
			Tween(oldPage, EASE_OUT_FAST, {})
			oldPage.Visible = false
		end
		if zerox.CurrentTabButton then
			Tween(zerox.CurrentTabButton, EASE_OUT_FAST, { BackgroundTransparency = 0.3 })
			local oldLabel = zerox.CurrentTabButton:FindFirstChildOfClass("TextLabel")
			if oldLabel then Tween(oldLabel, EASE_OUT_FAST, { TextColor3 = COLORS.SubText }) end
			local oldIndicator = zerox.CurrentTabButton:FindFirstChildOfClass("Frame")
			if oldIndicator then Tween(oldIndicator, EASE_OUT_FAST, { Size = UDim2.new(0, 3, 0, 0) }) end
		end

		page.Visible = true
		page.GroupTransparency = 0
		page.Position = UDim2.new(0, 12, 0, 0)
		Tween(page, EASE_OUT, { Position = UDim2.new(0, 0, 0, 0) })

		Tween(tabButton, EASE_OUT_FAST, { BackgroundTransparency = 0 })
		Tween(label, EASE_OUT_FAST, { TextColor3 = COLORS.Text })
		Tween(indicator, EASE_SPRING, { Size = UDim2.new(0, 3, 0, 22) })

		zerox.CurrentTab = page
		zerox.CurrentTabButton = tabButton
	end

	tabButton.MouseButton1Click:Connect(selectTab)
	HoverGlow(tabButton, COLORS.SurfaceLight, COLORS.SurfaceLight)

	if not zerox.CurrentTab then
		selectTab()
	end

	local tab = { page = page, Accent = self.Accent, Zerox = self }
	setmetatable(tab, { __index = Zerox })
	return self:_WrapTab(tab)
end

--============================================================
-- COMPONENTS
--============================================================

function Zerox:_WrapTab(tab)
	local page = tab.page
	local accent = tab.Accent

	function tab:CreateSection(title)
		local section = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = COLORS.Surface,
			Parent = page,
		})
		Corner(8, section)
		Stroke(COLORS.Border, 1, section)

		Create("TextLabel", {
			Text = title,
			Size = UDim2.new(1, -24, 0, 34),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			TextColor3 = accent,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = section,
		})

		local content = Create("Frame", {
			Size = UDim2.new(1, -20, 0, 0),
			Position = UDim2.new(0, 10, 0, 36),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = section,
		})
		Create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = content,
		})
		Create("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = content })

		local sec = { content = content, Accent = accent }

		function sec:CreateButton(cfg)
			cfg = cfg or {}
			local btn = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = COLORS.SurfaceLight,
				Text = "",
				AutoButtonColor = false,
				ClipsDescendants = true,
				Parent = self.content,
			})
			Corner(6, btn)
			Create("TextLabel", {
				Text = cfg.Name or "Button",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				Parent = btn,
			})

			HoverGlow(btn, COLORS.SurfaceLight, Color3.fromRGB(45, 45, 45))
			Ripple(btn, accent)

			btn.MouseButton1Click:Connect(function()
				Tween(btn, EASE_OUT_FAST, { BackgroundColor3 = accent })
				task.delay(0.12, function()
					Tween(btn, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLight })
				end)
				if cfg.Callback then
					local ok, err = pcall(cfg.Callback)
					if not ok then warn("[ZeroxUI] Button callback error: " .. tostring(err)) end
				end
			end)

			return btn
		end

		function sec:CreateToggle(cfg)
			cfg = cfg or {}
			local state = cfg.Default or false

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = COLORS.SurfaceLight,
				Parent = self.content,
			})
			Corner(6, holder)

			Create("TextLabel", {
				Text = cfg.Name or "Toggle",
				Size = UDim2.new(1, -70, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local track = Create("Frame", {
				Size = UDim2.new(0, 44, 0, 24),
				Position = UDim2.new(1, -58, 0.5, -12),
				BackgroundColor3 = state and accent or Color3.fromRGB(55, 55, 55),
				Parent = holder,
			})
			Corner(12, track)

			local knob = Create("Frame", {
				Size = UDim2.new(0, 18, 0, 18),
				Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = track,
			})
			Corner(9, knob)

			local clicker = Create("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				Parent = holder,
			})

			local function setState(newState, silent)
				state = newState
				Tween(track, EASE_OUT, { BackgroundColor3 = state and accent or Color3.fromRGB(55, 55, 55) })
				Tween(knob, EASE_SPRING, { Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) })
				if not silent and cfg.Callback then
					local ok, err = pcall(cfg.Callback, state)
					if not ok then warn("[ZeroxUI] Toggle callback error: " .. tostring(err)) end
				end
			end

			clicker.MouseButton1Click:Connect(function()
				setState(not state)
			end)

			return { Set = setState, Get = function() return state end }
		end

		function sec:CreateSlider(cfg)
			cfg = cfg or {}
			local min = cfg.Min or 0
			local max = cfg.Max or 100
			local value = math.clamp(cfg.Default or min, min, max)
			local decimals = cfg.Decimals or 0

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundColor3 = COLORS.SurfaceLight,
				Parent = self.content,
			})
			Corner(6, holder)

			Create("TextLabel", {
				Text = cfg.Name or "Slider",
				Size = UDim2.new(1, -70, 0, 20),
				Position = UDim2.new(0, 14, 0, 6),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local valueLabel = Create("TextLabel", {
				Text = tostring(value),
				Size = UDim2.new(0, 56, 0, 20),
				Position = UDim2.new(1, -66, 0, 6),
				BackgroundTransparency = 1,
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = holder,
			})

			local track = Create("Frame", {
				Size = UDim2.new(1, -28, 0, 6),
				Position = UDim2.new(0, 14, 1, -16),
				BackgroundColor3 = Color3.fromRGB(50, 50, 50),
				Parent = holder,
			})
			Corner(3, track)

			local fillFrac = (value - min) / math.max(max - min, 1e-6)
			local fill = Create("Frame", {
				Size = UDim2.new(fillFrac, 0, 1, 0),
				BackgroundColor3 = accent,
				Parent = track,
			})
			Corner(3, fill)

			local knob = Create("Frame", {
				Size = UDim2.new(0, 14, 0, 14),
				Position = UDim2.new(fillFrac, -7, 0.5, -7),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = track,
			})
			Corner(7, knob)

			local dragging = false
			local function update(input)
				local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				local raw = min + relX * (max - min)
				local stepped = decimals > 0
					and math.floor(raw * (10 ^ decimals) + 0.5) / (10 ^ decimals)
					or math.floor(raw + 0.5)
				value = math.clamp(stepped, min, max)
				local frac = (value - min) / math.max(max - min, 1e-6)

				Tween(fill, EASE_LINEAR, { Size = UDim2.new(frac, 0, 1, 0) })
				Tween(knob, EASE_LINEAR, { Position = UDim2.new(frac, -7, 0.5, -7) })
				valueLabel.Text = tostring(value)

				if cfg.Callback then
					local ok, err = pcall(cfg.Callback, value)
					if not ok then warn("[ZeroxUI] Slider callback error: " .. tostring(err)) end
				end
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					update(input)
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
					update(input)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)

			return {
				Set = function(_, v)
					value = math.clamp(v, min, max)
					local frac = (value - min) / math.max(max - min, 1e-6)
					Tween(fill, EASE_OUT, { Size = UDim2.new(frac, 0, 1, 0) })
					Tween(knob, EASE_OUT, { Position = UDim2.new(frac, -7, 0.5, -7) })
					valueLabel.Text = tostring(value)
				end,
				Get = function() return value end,
			}
		end

		function sec:CreateDropdown(cfg)
			cfg = cfg or {}
			local options = cfg.Options or {}
			local selected = cfg.Default or options[1]
			local open = false

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = COLORS.SurfaceLight,
				ClipsDescendants = true,
				ZIndex = 5,
				Parent = self.content,
			})
			Corner(6, holder)

			Create("TextLabel", {
				Text = cfg.Name or "Dropdown",
				Size = UDim2.new(0.5, 0, 0, 40),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5,
				Parent = holder,
			})

			local selectedLabel = Create("TextLabel", {
				Text = tostring(selected or "None"),
				Size = UDim2.new(0.4, -30, 0, 40),
				Position = UDim2.new(0.5, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 5,
				Parent = holder,
			})

			local arrow = Create("TextLabel", {
				Text = "▾",
				Size = UDim2.new(0, 26, 0, 40),
				Position = UDim2.new(1, -28, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.SubText,
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				ZIndex = 5,
				Parent = holder,
			})

			local clicker = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 6,
				Parent = holder,
			})

			local optionsFrame = Create("Frame", {
				Size = UDim2.new(1, 0, 0, #options * 32),
				Position = UDim2.new(0, 0, 0, 40),
				BackgroundTransparency = 1,
				ZIndex = 5,
				Parent = holder,
			})
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = optionsFrame })

			for _, opt in ipairs(options) do
				local optBtn = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundColor3 = COLORS.Surface,
					BackgroundTransparency = 0.2,
					Text = tostring(opt),
					TextColor3 = COLORS.SubText,
					Font = Enum.Font.Gotham,
					TextSize = 13,
					AutoButtonColor = false,
					ZIndex = 5,
					Parent = optionsFrame,
				})
				HoverGlow(optBtn, Color3.fromRGB(24, 24, 24), Color3.fromRGB(38, 38, 38))
				optBtn.MouseButton1Click:Connect(function()
					selected = opt
					selectedLabel.Text = tostring(opt)
					if cfg.Callback then
						local ok, err = pcall(cfg.Callback, selected)
						if not ok then warn("[ZeroxUI] Dropdown callback error: " .. tostring(err)) end
					end
					open = false
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 40) })
					Tween(arrow, EASE_OUT, { Rotation = 0 })
				end)
			end

			clicker.MouseButton1Click:Connect(function()
				open = not open
				if open then
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 40 + #options * 32) })
					Tween(arrow, EASE_OUT, { Rotation = 180 })
				else
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 40) })
					Tween(arrow, EASE_OUT, { Rotation = 0 })
				end
			end)

			return {
				Get = function() return selected end,
				Set = function(_, v)
					selected = v
					selectedLabel.Text = tostring(v)
				end,
			}
		end

		function sec:CreateTextbox(cfg)
			cfg = cfg or {}
			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = COLORS.SurfaceLight,
				Parent = self.content,
			})
			Corner(6, holder)
			Stroke(COLORS.Border, 1, holder)

			local box = Create("TextBox", {
				Size = UDim2.new(1, -24, 1, 0),
				Position = UDim2.new(0, 12, 0, 0),
				BackgroundTransparency = 1,
				Text = cfg.Default or "",
				PlaceholderText = cfg.Placeholder or cfg.Name or "Enter text",
				PlaceholderColor3 = COLORS.SubText,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.Gotham,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
				Parent = holder,
			})

			local activeStroke = holder:FindFirstChildOfClass("UIStroke")
			box.Focused:Connect(function()
				Tween(activeStroke, EASE_OUT_FAST, { Color = accent, Thickness = 1.5 })
			end)
			box.FocusLost:Connect(function(enterPressed)
				Tween(activeStroke, EASE_OUT_FAST, { Color = COLORS.Border, Thickness = 1 })
				if cfg.Callback then
					local ok, err = pcall(cfg.Callback, box.Text, enterPressed)
					if not ok then warn("[ZeroxUI] Textbox callback error: " .. tostring(err)) end
				end
			end)

			return {
				Get = function() return box.Text end,
				Set = function(_, v) box.Text = v end,
			}
		end

		function sec:CreateLabel(text)
			return Create("TextLabel", {
				Text = text,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.SubText,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Parent = self.content,
			})
		end

		return sec
	end

	return tab
end

return Zerox
