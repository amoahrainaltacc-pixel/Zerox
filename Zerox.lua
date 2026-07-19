-- ZeroxUI v3.0
-- Animated dark/red UI kit for Roblox tools — component library only
-- Standalone module: require() it from a LocalScript in your own place/tool
--
-- Fix notes (v2 -> v3):
--   Tab switching in v2 relied on closures over a single mutable
--   `zerox.CurrentTab` / `zerox.CurrentTabButton` pair, captured per-tab at
--   creation time. Because every CreateTab() call re-defined `selectTab`
--   against the *same* outer variables, and the first tab auto-selected
--   itself *during* its own construction (before later tabs existed),
--   tab state could desync the moment a 3rd+ tab was added — clicks would
--   fire but `CurrentTab` no longer matched what was visually on screen,
--   so pages stopped toggling. Fixed by giving the Window an explicit
--   tab registry (self.Tabs, self.TabIndex) and a single SelectTab(index)
--   method that is the only thing allowed to mutate selection state.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

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
local EASE_SMOOTH = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local EASE_ELASTIC = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local EASE_PULSE = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local COLORS = {
	Background = Color3.fromRGB(14, 14, 14),
	Surface = Color3.fromRGB(21, 21, 21),
	SurfaceLight = Color3.fromRGB(29, 29, 29),
	SurfaceLighter = Color3.fromRGB(38, 38, 38),
	Border = Color3.fromRGB(48, 48, 48),
	Text = Color3.fromRGB(235, 235, 235),
	SubText = Color3.fromRGB(148, 148, 148),
	Muted = Color3.fromRGB(90, 90, 90),
	Accent = Color3.fromRGB(178, 0, 0),
	AccentBright = Color3.fromRGB(224, 32, 32),
	AccentDim = Color3.fromRGB(110, 15, 15),
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

local function Padding(all, parent)
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		Parent = parent,
	})
end

local function Gradient(colorA, colorB, rotation, parent)
	return Create("UIGradient", {
		Color = ColorSequence.new(colorA, colorB),
		Rotation = rotation or 0,
		Parent = parent,
	})
end

local function Ripple(button, color)
	button.MouseButton1Down:Connect(function(x, y)
		local rel = Vector2.new(x, y) - Vector2.new(button.AbsolutePosition.X, button.AbsolutePosition.Y)
		local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.7

		local circle = Create("Frame", {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0, rel.X, 0, rel.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color or COLORS.AccentBright,
			BackgroundTransparency = 0.55,
			ZIndex = button.ZIndex + 1,
			Parent = button,
		})
		Corner(size, circle)

		Tween(circle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, size, 0, size),
			BackgroundTransparency = 1,
		})

		task.delay(0.5, function()
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

local function HoverScale(obj, from, to)
	obj.MouseEnter:Connect(function()
		Tween(obj, EASE_OUT_FAST, { Size = to })
	end)
	obj.MouseLeave:Connect(function()
		Tween(obj, EASE_OUT_FAST, { Size = from })
	end)
end

-- Continuous subtle pulse, used sparingly (status dots, live indicators)
local function Pulse(obj, propTable)
	Tween(obj, EASE_PULSE, propTable)
end

local function SafeCall(fn, ...)
	if not fn then return end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[ZeroxUI] callback error: " .. tostring(err))
	end
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

	-- backdrop blur-style dim (soft dark overlay, purely decorative)
	self.Backdrop = Create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = self.ScreenGui,
	})

	self.NotifyHolder = Create("Frame", {
		Name = "Notifications",
		Size = UDim2.new(0, 300, 1, -20),
		Position = UDim2.new(1, -320, 0, 10),
		BackgroundTransparency = 1,
		ZIndex = 50,
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
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.ScreenGui,
	})
	Corner(10, self.Main)
	Stroke(COLORS.Border, 1.5, self.Main)

	self.FullSize = UDim2.new(0, 680, 0, 500)
	Tween(self.Main, EASE_SPRING, { Size = self.FullSize })
	Tween(self.Backdrop, EASE_SMOOTH, { BackgroundTransparency = 0.55 })

	self:_BuildTopBar(config)
	self:_BuildTabRail()

	self.Pages = Create("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, -180, 1, -68),
		Position = UDim2.new(0, 170, 0, 60),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.Main,
	})

	-- explicit tab registry — the only source of truth for what's selected
	self.Tabs = {}
	self.TabIndex = nil

	return self
end

function Zerox:_BuildTopBar(config)
	local TopBar = Create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = COLORS.Surface,
		BorderSizePixel = 0,
		Parent = self.Main,
	})
	Corner(10, TopBar)
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
	Gradient(self.AccentBright, self.Accent, 90, accentBar)

	Create("TextLabel", {
		Text = config.Title or "ZER0X",
		Size = UDim2.new(0.5, 0, 0, 22),
		Position = UDim2.new(0, 24, 0, 6),
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

	-- live status dot, subtle pulse, purely cosmetic
	local statusDot = Create("Frame", {
		Size = UDim2.new(0, 8, 0, 8),
		Position = UDim2.new(0, 24, 0, 34),
		BackgroundColor3 = COLORS.Success,
		Visible = config.SubTitle == nil,
		Parent = TopBar,
	})
	Corner(4, statusDot)
	if statusDot.Visible then
		Pulse(statusDot, { BackgroundTransparency = 0.5 })
	end

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
		Tween(self.Backdrop, EASE_SMOOTH, { BackgroundTransparency = 1 })
		local t = Tween(self.Main, EASE_OUT, { Size = UDim2.new(0, 0, 0, 0) })
		t.Completed:Wait()
		self.ScreenGui:Destroy()
	end)

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
	Minimize.MouseButton1Click:Connect(function()
		self.Minimized = not self.Minimized
		if self.Minimized then
			Tween(self.Main, EASE_OUT, { Size = UDim2.new(0, self.FullSize.X.Offset, 0, 52) })
		else
			Tween(self.Main, EASE_OUT, { Size = self.FullSize })
		end
	end)

	self:_MakeDraggable(TopBar)
end

function Zerox:_BuildTabRail()
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
	Padding(8, self.TabBar)
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

	card.Position = UDim2.new(1, 40, 0, 0)
	Tween(card, EASE_SPRING, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
	Tween(bar, EASE_OUT, { BackgroundTransparency = 0 })
	Tween(title, EASE_OUT, { TextTransparency = 0 })
	Tween(body, EASE_OUT, { TextTransparency = 0 })

	task.delay(duration, function()
		local closeTween = Tween(card, EASE_OUT, {
			BackgroundTransparency = 1,
			Position = UDim2.new(1, 40, 0, 0),
		})
		Tween(bar, EASE_OUT, { BackgroundTransparency = 1 })
		Tween(title, EASE_OUT, { TextTransparency = 1 })
		Tween(body, EASE_OUT, { TextTransparency = 1 })
		closeTween.Completed:Wait()
		card:Destroy()
	end)
end

--============================================================
-- TABS — explicit registry, single mutation point
--============================================================

function Zerox:CreateTab(name, icon)
	local index = #self.Tabs + 1

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

	local label = Create("TextLabel", {
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

	local page = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
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

	local entry = {
		index = index,
		button = tabButton,
		label = label,
		indicator = indicator,
		page = page,
	}
	self.Tabs[index] = entry

	tabButton.MouseButton1Click:Connect(function()
		self:SelectTab(index)
	end)
	HoverGlow(tabButton, COLORS.SurfaceLight, COLORS.SurfaceLighter)

	if self.TabIndex == nil then
		self:SelectTab(index)
	end

	local tabHandle = { page = page, Accent = self.Accent }
	return self:_WrapTab(tabHandle)
end

-- The single authoritative place tab selection state changes.
function Zerox:SelectTab(index)
	local target = self.Tabs[index]
	if not target then return end
	if self.TabIndex == index then return end

	local previous = self.TabIndex and self.Tabs[self.TabIndex] or nil
	self.TabIndex = index

	if previous then
		Tween(previous.button, EASE_OUT_FAST, { BackgroundTransparency = 0.3 })
		Tween(previous.label, EASE_OUT_FAST, { TextColor3 = COLORS.SubText })
		Tween(previous.indicator, EASE_OUT_FAST, { Size = UDim2.new(0, 3, 0, 0) })
		local prevPage = previous.page
		Tween(prevPage, EASE_OUT_FAST, { Position = UDim2.new(0, -14, 0, 0) })
		task.delay(0.14, function()
			-- guard: only hide if it's still not the selected page
			if self.TabIndex ~= previous.index then
				prevPage.Visible = false
				prevPage.Position = UDim2.new(0, 0, 0, 0)
			end
		end)
	end

	target.page.Visible = true
	target.page.Position = UDim2.new(0, 14, 0, 0)
	Tween(target.page, EASE_OUT, { Position = UDim2.new(0, 0, 0, 0) })

	Tween(target.button, EASE_OUT_FAST, { BackgroundTransparency = 0 })
	Tween(target.label, EASE_OUT_FAST, { TextColor3 = COLORS.Text })
	Tween(target.indicator, EASE_SPRING, { Size = UDim2.new(0, 3, 0, 22) })
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
			BackgroundTransparency = 1,
			Parent = page,
		})
		Corner(8, section)
		Stroke(COLORS.Border, 1, section)

		-- fade-in when section first renders
		Tween(section, EASE_SMOOTH, { BackgroundTransparency = 0 })

		local header = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			Parent = section,
		})

		Create("TextLabel", {
			Text = title,
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			TextColor3 = accent,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = header,
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

		----------------------------------------------------------------
		-- BUTTON
		----------------------------------------------------------------
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
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = btn,
			})

			if cfg.Description then
				btn.Size = UDim2.new(1, 0, 0, 54)
				Create("TextLabel", {
					Text = cfg.Description,
					Size = UDim2.new(1, -16, 0, 16),
					Position = UDim2.new(0, 14, 0, 26),
					BackgroundTransparency = 1,
					TextColor3 = COLORS.SubText,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = btn,
				})
			end

			HoverGlow(btn, COLORS.SurfaceLight, COLORS.SurfaceLighter)
			Ripple(btn, accent)

			btn.MouseButton1Click:Connect(function()
				Tween(btn, EASE_OUT_FAST, { BackgroundColor3 = accent })
				task.delay(0.12, function()
					Tween(btn, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLight })
				end)
				SafeCall(cfg.Callback)
			end)

			return {
				SetName = function(_, text)
					local lbl = btn:FindFirstChildOfClass("TextLabel")
					if lbl then lbl.Text = text end
				end,
			}
		end

		----------------------------------------------------------------
		-- TOGGLE
		----------------------------------------------------------------
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
				Tween(knob, EASE_SPRING, {
					Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
					Size = UDim2.new(0, 20, 0, 20),
				})
				task.delay(0.12, function()
					Tween(knob, EASE_OUT_FAST, { Size = UDim2.new(0, 18, 0, 18) })
				end)
				if not silent then SafeCall(cfg.Callback, state) end
			end

			clicker.MouseButton1Click:Connect(function()
				setState(not state)
			end)

			return { Set = setState, Get = function() return state end }
		end

		----------------------------------------------------------------
		-- SLIDER
		----------------------------------------------------------------
		function sec:CreateSlider(cfg)
			cfg = cfg or {}
			local min = cfg.Min or 0
			local max = cfg.Max or 100
			local value = math.clamp(cfg.Default or min, min, max)
			local decimals = cfg.Decimals or 0
			local suffix = cfg.Suffix or ""

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundColor3 = COLORS.SurfaceLight,
				Parent = self.content,
			})
			Corner(6, holder)

			Create("TextLabel", {
				Text = cfg.Name or "Slider",
				Size = UDim2.new(1, -90, 0, 20),
				Position = UDim2.new(0, 14, 0, 6),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local valueLabel = Create("TextLabel", {
				Text = tostring(value) .. suffix,
				Size = UDim2.new(0, 76, 0, 20),
				Position = UDim2.new(1, -86, 0, 6),
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
			Gradient(COLORS.AccentBright, accent, 0, fill)

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
				valueLabel.Text = tostring(value) .. suffix

				SafeCall(cfg.Callback, value)
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					Tween(knob, EASE_OUT_FAST, { Size = UDim2.new(0, 18, 0, 18) })
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
					if dragging then
						Tween(knob, EASE_OUT_FAST, { Size = UDim2.new(0, 14, 0, 14) })
					end
					dragging = false
				end
			end)

			return {
				Set = function(_, v)
					value = math.clamp(v, min, max)
					local frac = (value - min) / math.max(max - min, 1e-6)
					Tween(fill, EASE_OUT, { Size = UDim2.new(frac, 0, 1, 0) })
					Tween(knob, EASE_OUT, { Position = UDim2.new(frac, -7, 0.5, -7) })
					valueLabel.Text = tostring(value) .. suffix
				end,
				Get = function() return value end,
			}
		end

		----------------------------------------------------------------
		-- DROPDOWN
		----------------------------------------------------------------
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

			local optionButtons = {}
			local function refreshHighlight()
				for _, entry in ipairs(optionButtons) do
					local isSel = entry.value == selected
					Tween(entry.btn, EASE_OUT_FAST, {
						TextColor3 = isSel and accent or COLORS.SubText,
					})
				end
			end

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
				table.insert(optionButtons, { btn = optBtn, value = opt })

				optBtn.MouseButton1Click:Connect(function()
					selected = opt
					selectedLabel.Text = tostring(opt)
					refreshHighlight()
					SafeCall(cfg.Callback, selected)
					open = false
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 40) })
					Tween(arrow, EASE_OUT, { Rotation = 0 })
				end)
			end
			refreshHighlight()

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
					refreshHighlight()
				end,
			}
		end

		----------------------------------------------------------------
		-- MULTI-SELECT DROPDOWN (checklist variant)
		----------------------------------------------------------------
		function sec:CreateMultiDropdown(cfg)
			cfg = cfg or {}
			local options = cfg.Options or {}
			local selected = {}
			for _, v in ipairs(cfg.Default or {}) do selected[v] = true end
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
				Text = cfg.Name or "Select",
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

			local function countText()
				local n = 0
				for _ in pairs(selected) do n += 1 end
				return n .. " selected"
			end

			local countLabel = Create("TextLabel", {
				Text = countText(),
				Size = UDim2.new(0.4, -30, 0, 40),
				Position = UDim2.new(0.5, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
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
				local row = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundColor3 = COLORS.Surface,
					BackgroundTransparency = 0.2,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 5,
					Parent = optionsFrame,
				})
				HoverGlow(row, Color3.fromRGB(24, 24, 24), Color3.fromRGB(38, 38, 38))

				local check = Create("Frame", {
					Size = UDim2.new(0, 14, 0, 14),
					Position = UDim2.new(0, 12, 0.5, -7),
					BackgroundColor3 = selected[opt] and accent or Color3.fromRGB(55, 55, 55),
					ZIndex = 5,
					Parent = row,
				})
				Corner(3, check)

				Create("TextLabel", {
					Text = tostring(opt),
					Size = UDim2.new(1, -40, 1, 0),
					Position = UDim2.new(0, 34, 0, 0),
					BackgroundTransparency = 1,
					TextColor3 = COLORS.SubText,
					Font = Enum.Font.Gotham,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
					Parent = row,
				})

				row.MouseButton1Click:Connect(function()
					selected[opt] = not selected[opt] or nil
					Tween(check, EASE_SPRING, {
						BackgroundColor3 = selected[opt] and accent or Color3.fromRGB(55, 55, 55),
					})
					countLabel.Text = countText()
					local list = {}
					for k in pairs(selected) do table.insert(list, k) end
					SafeCall(cfg.Callback, list)
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
				Get = function()
					local list = {}
					for k in pairs(selected) do table.insert(list, k) end
					return list
				end,
			}
		end

		----------------------------------------------------------------
		-- TEXTBOX
		----------------------------------------------------------------
		function sec:CreateTextbox(cfg)
			cfg = cfg or {}
			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = COLORS.SurfaceLight,
				Parent = self.content,
			})
			Corner(6, holder)
			local activeStroke = Stroke(COLORS.Border, 1, holder)

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

			box.Focused:Connect(function()
				Tween(activeStroke, EASE_OUT_FAST, { Color = accent, Thickness = 1.5 })
				Tween(holder, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLighter })
			end)
			box.FocusLost:Connect(function(enterPressed)
				Tween(activeStroke, EASE_OUT_FAST, { Color = COLORS.Border, Thickness = 1 })
				Tween(holder, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLight })
				SafeCall(cfg.Callback, box.Text, enterPressed)
			end)

			return {
				Get = function() return box.Text end,
				Set = function(_, v) box.Text = v end,
			}
		end

		----------------------------------------------------------------
		-- KEYBIND
		----------------------------------------------------------------
		function sec:CreateKeybind(cfg)
			cfg = cfg or {}
			local currentKey = cfg.Default or Enum.KeyCode.Unknown
			local listening = false

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = COLORS.SurfaceLight,
				Parent = self.content,
			})
			Corner(6, holder)

			Create("TextLabel", {
				Text = cfg.Name or "Keybind",
				Size = UDim2.new(1, -110, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local keyBtn = Create("TextButton", {
				Size = UDim2.new(0, 90, 0, 28),
				Position = UDim2.new(1, -100, 0.5, -14),
				BackgroundColor3 = COLORS.SurfaceLighter,
				Text = currentKey.Name,
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				AutoButtonColor = false,
				Parent = holder,
			})
			Corner(6, keyBtn)

			local conn
			keyBtn.MouseButton1Click:Connect(function()
				if listening then return end
				listening = true
				keyBtn.Text = "..."
				Pulse(keyBtn, { BackgroundColor3 = COLORS.SurfaceLight })

				conn = UserInputService.InputBegan:Connect(function(input, processed)
					if input.UserInputType == Enum.UserInputType.Keyboard then
						currentKey = input.KeyCode
						keyBtn.Text = currentKey.Name
						listening = false
						Tween(keyBtn, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLighter })
						conn:Disconnect()
						SafeCall(cfg.Callback, currentKey)
					end
				end)
			end)

			return {
				Get = function() return currentKey end,
				Set = function(_, key) currentKey = key; keyBtn.Text = key.Name end,
			}
		end

		----------------------------------------------------------------
		-- COLOR PICKER (simplified HSV strip)
		----------------------------------------------------------------
		function sec:CreateColorPicker(cfg)
			cfg = cfg or {}
			local current = cfg.Default or Color3.fromRGB(178, 0, 0)

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = COLORS.SurfaceLight,
				ClipsDescendants = true,
				Parent = self.content,
			})
			Corner(6, holder)

			Create("TextLabel", {
				Text = cfg.Name or "Color",
				Size = UDim2.new(1, -70, 0, 40),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local swatch = Create("TextButton", {
				Size = UDim2.new(0, 28, 0, 28),
				Position = UDim2.new(1, -42, 0, 6),
				BackgroundColor3 = current,
				Text = "",
				AutoButtonColor = false,
				Parent = holder,
			})
			Corner(6, swatch)
			Stroke(COLORS.Border, 1, swatch)

			local open = false
			local hueFrame = Create("Frame", {
				Size = UDim2.new(1, -28, 0, 20),
				Position = UDim2.new(0, 14, 0, 46),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = holder,
			})
			Corner(4, hueFrame)
			local hueGradient = Create("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
					ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
					ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
					ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
					ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
					ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
				}),
				Parent = hueFrame,
			})

			local hueDragging = false
			local function setFromInput(input)
				local relX = math.clamp((input.Position.X - hueFrame.AbsolutePosition.X) / hueFrame.AbsoluteSize.X, 0, 1)
				current = Color3.fromHSV(relX, 1, 1)
				Tween(swatch, EASE_LINEAR, { BackgroundColor3 = current })
				SafeCall(cfg.Callback, current)
			end
			hueFrame.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					hueDragging = true
					setFromInput(input)
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if hueDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					setFromInput(input)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then hueDragging = false end
			end)

			swatch.MouseButton1Click:Connect(function()
				open = not open
				Tween(holder, EASE_OUT, { Size = open and UDim2.new(1, 0, 0, 76) or UDim2.new(1, 0, 0, 40) })
			end)

			return {
				Get = function() return current end,
				Set = function(_, c) current = c; swatch.BackgroundColor3 = c end,
			}
		end

		----------------------------------------------------------------
		-- LABEL / DIVIDER / PROGRESS BAR
		----------------------------------------------------------------
		function sec:CreateLabel(text)
			local lbl = Create("TextLabel", {
				Text = text,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				TextTransparency = 1,
				TextColor3 = COLORS.SubText,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Parent = self.content,
			})
			Tween(lbl, EASE_SMOOTH, { TextTransparency = 0 })
			return lbl
		end

		function sec:CreateDivider()
			local div = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = COLORS.Border,
				Parent = self.content,
			})
			return div
		end

		function sec:CreateProgressBar(cfg)
			cfg = cfg or {}
			local min, max = cfg.Min or 0, cfg.Max or 100
			local value = math.clamp(cfg.Default or min, min, max)

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = COLORS.SurfaceLight,
				Parent = self.content,
			})
			Corner(6, holder)

			Create("TextLabel", {
				Text = cfg.Name or "Progress",
				Size = UDim2.new(1, -20, 0, 18),
				Position = UDim2.new(0, 12, 0, 4),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = holder,
			})

			local track = Create("Frame", {
				Size = UDim2.new(1, -24, 0, 8),
				Position = UDim2.new(0, 12, 1, -16),
				BackgroundColor3 = Color3.fromRGB(50, 50, 50),
				Parent = holder,
			})
			Corner(4, track)

			local frac = (value - min) / math.max(max - min, 1e-6)
			local fill = Create("Frame", {
				Size = UDim2.new(frac, 0, 1, 0),
				BackgroundColor3 = accent,
				Parent = track,
			})
			Corner(4, fill)
			Gradient(COLORS.AccentBright, accent, 0, fill)

			return {
				Set = function(_, v)
					value = math.clamp(v, min, max)
					local f = (value - min) / math.max(max - min, 1e-6)
					Tween(fill, EASE_SMOOTH, { Size = UDim2.new(f, 0, 1, 0) })
				end,
				Get = function() return value end,
			}
		end

		return sec
	end

	return tab
end

return Zerox
