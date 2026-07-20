-- ZeroxUI v4.0
-- Animated dark/red UI kit for Roblox tools — component library only
-- Standalone module: require() it from a LocalScript in your own place/tool
--
-- Changelog (v3 -> v4):
--   - Removed the full-screen black backdrop dim entirely. It sat behind
--     the window at ZIndex 0 and faded to 0.55 transparency on open —
--     visually it read as "everything behind the UI got darker," which
--     is unwanted for a floating tool panel. Window now sits on its own
--     with a soft drop-shadow + accent glow instead of dimming the world.
--   - Visual pass: layered surface depth (Background -> Surface ->
--     SurfaceLight -> SurfaceLighter reads as real elevation now),
--     glow accents behind key elements, refined spacing and type scale,
--     card-style sections with hover lift, redesigned tab rail with
--     active-tab glow, gradient-backed accent bar, icon-badge headers.
--   - Tab switching still goes through the v3 fix: Window:SelectTab(index)
--     is the single authoritative mutator. Untouched, still correct.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Zerox = {}
Zerox.__index = Zerox

--============================================================
-- EASING PRESETS
--============================================================

local EASE_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_OUT_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_SPRING = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EASE_LINEAR = TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local EASE_SMOOTH = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local EASE_ELASTIC = TweenInfo.new(0.55, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local EASE_PULSE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local EASE_GLOW = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local EASE_ENTRY = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

--============================================================
-- PALETTE — layered elevation, not flat panels
--============================================================

local COLORS = {
	Background = Color3.fromRGB(13, 13, 13),
	Surface = Color3.fromRGB(19, 19, 19),
	SurfaceLight = Color3.fromRGB(26, 26, 26),
	SurfaceLighter = Color3.fromRGB(35, 35, 35),
	SurfaceElevated = Color3.fromRGB(44, 44, 44),
	Border = Color3.fromRGB(46, 46, 46),
	BorderBright = Color3.fromRGB(70, 70, 70),
	Text = Color3.fromRGB(240, 240, 240),
	SubText = Color3.fromRGB(150, 150, 150),
	Muted = Color3.fromRGB(92, 92, 92),
	Accent = Color3.fromRGB(180, 0, 0),
	AccentBright = Color3.fromRGB(230, 35, 35),
	AccentDim = Color3.fromRGB(105, 12, 12),
	AccentGlow = Color3.fromRGB(255, 60, 60),
	Success = Color3.fromRGB(72, 202, 112),
	Warning = Color3.fromRGB(232, 182, 62),
	Error = Color3.fromRGB(232, 72, 72),
}

--============================================================
-- CORE HELPERS
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

local function Stroke(color, thickness, parent, transparency)
	return Create("UIStroke", {
		Color = color or COLORS.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
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

local function Gradient(colorA, colorB, rotation, parent, transparencySeq)
	return Create("UIGradient", {
		Color = ColorSequence.new(colorA, colorB),
		Rotation = rotation or 0,
		Transparency = transparencySeq,
		Parent = parent,
	})
end

-- Soft drop shadow using a 9-slice ImageLabel, scales with parent
local function DropShadow(parent, transparency, size)
	local shadow = Create("ImageLabel", {
		Name = "Shadow",
		Image = "rbxassetid://1316045217",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = transparency or 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, size or 40, 1, size or 40),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = parent.ZIndex - 1,
		Parent = parent,
	})
	return shadow
end

-- Soft glow using a blurred circular gradient image
local function GlowAccent(parent, color, size, transparency)
	local glow = Create("ImageLabel", {
		Name = "Glow",
		Image = "rbxassetid://4996891970",
		ImageColor3 = color,
		ImageTransparency = transparency or 0.75,
		BackgroundTransparency = 1,
		Size = size or UDim2.new(1, 120, 1, 120),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = parent.ZIndex - 1,
		Parent = parent,
	})
	return glow
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

-- Card lift: slight upward shift + brighten on hover, used on sections
local function HoverLift(obj, stroke)
	local basePos = obj.Position
	obj.MouseEnter:Connect(function()
		Tween(obj, EASE_OUT_FAST, { Position = basePos - UDim2.new(0, 0, 0, 2) })
		if stroke then Tween(stroke, EASE_OUT_FAST, { Transparency = 0.2, Color = COLORS.BorderBright }) end
	end)
	obj.MouseLeave:Connect(function()
		Tween(obj, EASE_OUT_FAST, { Position = basePos })
		if stroke then Tween(stroke, EASE_OUT_FAST, { Transparency = 0.5, Color = COLORS.Border }) end
	end)
end

local function Pulse(obj, propTable)
	Tween(obj, EASE_PULSE, propTable)
end

local function GlowPulse(obj, propTable)
	Tween(obj, EASE_GLOW, propTable)
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

	-- Notifications float independently, top-right, above everything.
	-- No backdrop frame exists anywhere in this file.
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

	-- Main window — just the panel itself with a shadow, no world dimming
	self.Main = Create("Frame", {
		Name = "MainFrame",
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = self.ScreenGui,
	})
	Corner(12, self.Main)
	Stroke(COLORS.Border, 1.5, self.Main, 0.2)
	DropShadow(self.Main, 0.55, 60)

	self.FullSize = UDim2.new(0, 700, 0, 520)
	Tween(self.Main, EASE_ENTRY, { Size = self.FullSize })

	self:_BuildTopBar(config)
	self:_BuildTabRail()

	self.Pages = Create("Frame", {
		Name = "Pages",
		Size = UDim2.new(1, -196, 1, -76),
		Position = UDim2.new(0, 186, 0, 66),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = self.Main,
	})

	self.Tabs = {}
	self.TabIndex = nil

	return self
end

function Zerox:_BuildTopBar(config)
	local TopBar = Create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = COLORS.Surface,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = self.Main,
	})
	Corner(12, TopBar)
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = COLORS.Surface,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = TopBar,
	})
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = COLORS.Border,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = TopBar,
	})

	local accentBar = Create("Frame", {
		Size = UDim2.new(0, 4, 1, -18),
		Position = UDim2.new(0, 0, 0, 9),
		BackgroundColor3 = self.Accent,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = TopBar,
	})
	Corner(4, accentBar)
	Gradient(self.AccentBright, self.Accent, 90, accentBar)

	local badge = Create("Frame", {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(0, 20, 0, 12),
		BackgroundColor3 = COLORS.SurfaceLighter,
		ZIndex = 3,
		Parent = TopBar,
	})
	Corner(8, badge)
	Stroke(COLORS.Border, 1, badge, 0.3)
	Gradient(self.Accent, COLORS.SurfaceLighter, 45, badge, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.9),
	}))
	Create("TextLabel", {
		Text = config.Icon or "Z",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		ZIndex = 3,
		Parent = badge,
	})

	Create("TextLabel", {
		Text = config.Title or "ZER0X",
		Size = UDim2.new(0.5, 0, 0, 22),
		Position = UDim2.new(0, 64, 0, 10),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = TopBar,
	})

	local subRow = Create("Frame", {
		Size = UDim2.new(0.5, 0, 0, 16),
		Position = UDim2.new(0, 64, 0, 33),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = TopBar,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = subRow,
	})

	local statusDot = Create("Frame", {
		Size = UDim2.new(0, 7, 0, 7),
		BackgroundColor3 = COLORS.Success,
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = subRow,
	})
	Corner(4, statusDot)
	GlowPulse(statusDot, { BackgroundTransparency = 0.45 })

	Create("TextLabel", {
		Text = config.SubTitle or "ready",
		Size = UDim2.new(0, 200, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = subRow,
	})

	local controls = Create("Frame", {
		Size = UDim2.new(0, 84, 0, 36),
		Position = UDim2.new(1, -94, 0.5, -18),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = TopBar,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		Parent = controls,
	})

	local Minimize = Create("TextButton", {
		Text = "—",
		Size = UDim2.new(0, 36, 0, 36),
		BackgroundColor3 = COLORS.SurfaceLight,
		BackgroundTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		AutoButtonColor = false,
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = controls,
	})
	Corner(8, Minimize)
	Minimize.MouseEnter:Connect(function()
		Tween(Minimize, EASE_OUT_FAST, { BackgroundTransparency = 0, TextColor3 = COLORS.Text })
	end)
	Minimize.MouseLeave:Connect(function()
		Tween(Minimize, EASE_OUT_FAST, { BackgroundTransparency = 1, TextColor3 = COLORS.SubText })
	end)

	self.Minimized = false
	Minimize.MouseButton1Click:Connect(function()
		self.Minimized = not self.Minimized
		if self.Minimized then
			Tween(self.Main, EASE_OUT, { Size = UDim2.new(0, self.FullSize.X.Offset, 0, 58) })
		else
			Tween(self.Main, EASE_OUT, { Size = self.FullSize })
		end
	end)

	local Close = Create("TextButton", {
		Text = "✕",
		Size = UDim2.new(0, 36, 0, 36),
		BackgroundColor3 = COLORS.SurfaceLight,
		BackgroundTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		AutoButtonColor = false,
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = controls,
	})
	Corner(8, Close)
	Close.MouseEnter:Connect(function()
		Tween(Close, EASE_OUT_FAST, { BackgroundTransparency = 0, TextColor3 = COLORS.Error })
	end)
	Close.MouseLeave:Connect(function()
		Tween(Close, EASE_OUT_FAST, { BackgroundTransparency = 1, TextColor3 = COLORS.SubText })
	end)
	Close.MouseButton1Click:Connect(function()
		local t = Tween(self.Main, EASE_OUT, { Size = UDim2.new(0, 0, 0, 0) })
		t.Completed:Wait()
		self.ScreenGui:Destroy()
	end)

	self:_MakeDraggable(TopBar)
end

function Zerox:_BuildTabRail()
	local rail = Create("Frame", {
		Name = "TabRail",
		Size = UDim2.new(0, 166, 1, -76),
		Position = UDim2.new(0, 10, 0, 66),
		BackgroundColor3 = COLORS.Surface,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = self.Main,
	})
	Corner(10, rail)
	Stroke(COLORS.Border, 1, rail, 0.4)

	Create("TextLabel", {
		Text = "NAVIGATION",
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 12, 0, 8),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Muted,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = rail,
	})

	self.TabBar = Create("ScrollingFrame", {
		Name = "TabBar",
		Size = UDim2.new(1, 0, 1, -34),
		Position = UDim2.new(0, 0, 0, 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = self.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 3,
		Parent = rail,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.TabBar,
	})
	Padding(8, self.TabBar)

	self.TabRail = rail
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
local NOTIFY_ICONS = {
	Info = "ℹ",
	Success = "✓",
	Warning = "!",
	Error = "✕",
}

function Zerox:Notify(config)
	if type(config) == "string" then
		config = { Title = "Notice", Text = config }
	end
	local kind = config.Type or "Info"
	local duration = config.Duration or 3.5
	local barColor = NOTIFY_COLORS[kind] or self.Accent
	local icon = NOTIFY_ICONS[kind] or "•"

	local card = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.Surface,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 50,
		Parent = self.NotifyHolder,
	})
	Corner(9, card)
	local cardStroke = Stroke(COLORS.Border, 1, card, 1)
	DropShadow(card, 0.7, 24)

	local bar = Create("Frame", {
		Size = UDim2.new(0, 4, 1, -12),
		Position = UDim2.new(0, 0, 0, 6),
		BackgroundColor3 = barColor,
		BackgroundTransparency = 1,
		ZIndex = 51,
		Parent = card,
	})
	Corner(4, bar)

	local iconBadge = Create("Frame", {
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(0, 14, 0, 10),
		BackgroundColor3 = barColor,
		BackgroundTransparency = 1,
		ZIndex = 51,
		Parent = card,
	})
	Corner(6, iconBadge)
	local iconLabel = Create("TextLabel", {
		Text = icon,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		ZIndex = 51,
		Parent = iconBadge,
	})

	local title = Create("TextLabel", {
		Text = config.Title or kind,
		Size = UDim2.new(1, -50, 0, 20),
		Position = UDim2.new(0, 44, 0, 9),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextColor3 = COLORS.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 51,
		Parent = card,
	})

	local body = Create("TextLabel", {
		Text = config.Text or "",
		Size = UDim2.new(1, -58, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 44, 0, 29),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 51,
		Parent = card,
	})

	Create("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = card })

	card.Position = UDim2.new(1, 40, 0, 0)
	Tween(card, EASE_SPRING, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
	Tween(cardStroke, EASE_OUT, { Transparency = 0.3 })
	Tween(bar, EASE_OUT, { BackgroundTransparency = 0 })
	Tween(iconBadge, EASE_OUT, { BackgroundTransparency = 0.75 })
	Tween(iconLabel, EASE_OUT, { TextTransparency = 0 })
	Tween(title, EASE_OUT, { TextTransparency = 0 })
	Tween(body, EASE_OUT, { TextTransparency = 0 })

	local lifeTrack = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = barColor,
		BackgroundTransparency = 0.5,
		ZIndex = 51,
		Parent = card,
	})
	Tween(lifeTrack, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 0, 2),
	})

	task.delay(duration, function()
		local closeTween = Tween(card, EASE_OUT, {
			BackgroundTransparency = 1,
			Position = UDim2.new(1, 40, 0, 0),
		})
		Tween(cardStroke, EASE_OUT, { Transparency = 1 })
		Tween(bar, EASE_OUT, { BackgroundTransparency = 1 })
		Tween(iconBadge, EASE_OUT, { BackgroundTransparency = 1 })
		Tween(iconLabel, EASE_OUT, { TextTransparency = 1 })
		Tween(title, EASE_OUT, { TextTransparency = 1 })
		Tween(body, EASE_OUT, { TextTransparency = 1 })
		closeTween.Completed:Wait()
		card:Destroy()
	end)
end

--============================================================
-- TABS — explicit registry, single mutation point (unchanged from v3)
--============================================================

function Zerox:CreateTab(name, icon)
	local index = #self.Tabs + 1

	local tabButton = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = COLORS.SurfaceLight,
		BackgroundTransparency = 0.4,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = self.TabBar,
	})
	Corner(7, tabButton)

	local indicator = Create("Frame", {
		Size = UDim2.new(0, 3, 0, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = self.Accent,
		ZIndex = 4,
		Parent = tabButton,
	})
	Corner(3, indicator)
	Gradient(self.AccentBright, self.Accent, 90, indicator)

	local iconLabel = Create("TextLabel", {
		Text = icon or "●",
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		ZIndex = 3,
		Parent = tabButton,
	})

	local label = Create("TextLabel", {
		Text = name,
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 34, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.SubText,
		Font = Enum.Font.GothamSemibold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
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
		ZIndex = 3,
		Parent = self.Pages,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	Create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = page })

	local entry = {
		index = index,
		button = tabButton,
		iconLabel = iconLabel,
		label = label,
		indicator = indicator,
		page = page,
	}
	self.Tabs[index] = entry

	tabButton.MouseButton1Click:Connect(function()
		self:SelectTab(index)
	end)
	tabButton.MouseEnter:Connect(function()
		if self.TabIndex ~= index then
			Tween(tabButton, EASE_OUT_FAST, { BackgroundTransparency = 0.15 })
		end
	end)
	tabButton.MouseLeave:Connect(function()
		if self.TabIndex ~= index then
			Tween(tabButton, EASE_OUT_FAST, { BackgroundTransparency = 0.4 })
		end
	end)

	if self.TabIndex == nil then
		self:SelectTab(index)
	end

	local tabHandle = { page = page, Accent = self.Accent }
	return self:_WrapTab(tabHandle)
end

function Zerox:SelectTab(index)
	local target = self.Tabs[index]
	if not target then return end
	if self.TabIndex == index then return end

	local previous = self.TabIndex and self.Tabs[self.TabIndex] or nil
	self.TabIndex = index

	if previous then
		Tween(previous.button, EASE_OUT_FAST, { BackgroundTransparency = 0.4 })
		Tween(previous.label, EASE_OUT_FAST, { TextColor3 = COLORS.SubText })
		Tween(previous.iconLabel, EASE_OUT_FAST, { TextColor3 = COLORS.SubText })
		Tween(previous.indicator, EASE_OUT_FAST, { Size = UDim2.new(0, 3, 0, 0) })
		local prevPage = previous.page
		Tween(prevPage, EASE_OUT_FAST, { Position = UDim2.new(0, -14, 0, 0) })
		task.delay(0.14, function()
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
	Tween(target.iconLabel, EASE_OUT_FAST, { TextColor3 = self.Accent })
	Tween(target.indicator, EASE_SPRING, { Size = UDim2.new(0, 3, 0, 24) })
end

--============================================================
-- COMPONENTS
--============================================================

function Zerox:_WrapTab(tab)
	local page = tab.page
	local accent = tab.Accent

	function tab:CreateSection(title, opts)
		opts = opts or {}
		local section = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = COLORS.Surface,
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = page,
		})
		Corner(9, section)
		local sectionStroke = Stroke(COLORS.Border, 1, section, 1)

		Tween(section, EASE_SMOOTH, { BackgroundTransparency = 0 })
		Tween(sectionStroke, EASE_SMOOTH, { Transparency = 0.5 })

		if opts.Hoverable ~= false then
			HoverLift(section, sectionStroke)
		end

		local header = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = section,
		})

		local titleDot = Create("Frame", {
			Size = UDim2.new(0, 5, 0, 5),
			Position = UDim2.new(0, 14, 0.5, -2),
			BackgroundColor3 = accent,
			ZIndex = 3,
			Parent = header,
		})
		Corner(3, titleDot)

		Create("TextLabel", {
			Text = title,
			Size = UDim2.new(1, -44, 1, 0),
			Position = UDim2.new(0, 26, 0, 0),
			BackgroundTransparency = 1,
			TextColor3 = accent,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = header,
		})

		local content = Create("Frame", {
			Size = UDim2.new(1, -20, 0, 0),
			Position = UDim2.new(0, 10, 0, 38),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = section,
		})
		Create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = content,
		})
		Create("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = content })

		local sec = { content = content, Accent = accent }

		----------------------------------------------------------------
		-- BUTTON
		----------------------------------------------------------------
		function sec:CreateButton(cfg)
			cfg = cfg or {}
			local btn = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = COLORS.SurfaceLight,
				Text = "",
				AutoButtonColor = false,
				ClipsDescendants = true,
				ZIndex = 3,
				Parent = self.content,
			})
			Corner(7, btn)
			local btnStroke = Stroke(COLORS.Border, 1, btn, 0.5)

			Create("TextLabel", {
				Text = cfg.Name or "Button",
				Size = UDim2.new(1, -50, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
				Parent = btn,
			})

			local chevron = Create("TextLabel", {
				Text = "›",
				Size = UDim2.new(0, 24, 1, 0),
				Position = UDim2.new(1, -34, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Muted,
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				ZIndex = 3,
				Parent = btn,
			})

			if cfg.Description then
				btn.Size = UDim2.new(1, 0, 0, 56)
				Create("TextLabel", {
					Text = cfg.Description,
					Size = UDim2.new(1, -50, 0, 16),
					Position = UDim2.new(0, 14, 0, 28),
					BackgroundTransparency = 1,
					TextColor3 = COLORS.SubText,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,
					Parent = btn,
				})
			end

			btn.MouseEnter:Connect(function()
				Tween(btn, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLighter })
				Tween(btnStroke, EASE_OUT_FAST, { Color = accent, Transparency = 0.2 })
				Tween(chevron, EASE_OUT_FAST, { TextColor3 = accent, Position = UDim2.new(1, -30, 0, 0) })
			end)
			btn.MouseLeave:Connect(function()
				Tween(btn, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLight })
				Tween(btnStroke, EASE_OUT_FAST, { Color = COLORS.Border, Transparency = 0.5 })
				Tween(chevron, EASE_OUT_FAST, { TextColor3 = COLORS.Muted, Position = UDim2.new(1, -34, 0, 0) })
			end)
			Ripple(btn, accent)

			btn.MouseButton1Click:Connect(function()
				Tween(btn, EASE_OUT_FAST, { BackgroundColor3 = accent })
				task.delay(0.12, function()
					Tween(btn, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLighter })
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
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = COLORS.SurfaceLight,
				ZIndex = 3,
				Parent = self.content,
			})
			Corner(7, holder)
			local holderStroke = Stroke(COLORS.Border, 1, holder, 0.5)

			Create("TextLabel", {
				Text = cfg.Name or "Toggle",
				Size = UDim2.new(1, -74, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
				Parent = holder,
			})

			local track = Create("Frame", {
				Size = UDim2.new(0, 46, 0, 25),
				Position = UDim2.new(1, -60, 0.5, -12.5),
				BackgroundColor3 = state and accent or Color3.fromRGB(55, 55, 55),
				ZIndex = 3,
				Parent = holder,
			})
			Corner(13, track)
			local trackGlow = GlowAccent(track, accent, UDim2.new(1, 30, 1, 30), state and 0.7 or 1)

			local knob = Create("Frame", {
				Size = UDim2.new(0, 19, 0, 19),
				Position = state and UDim2.new(1, -22, 0.5, -9.5) or UDim2.new(0, 3, 0.5, -9.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				ZIndex = 4,
				Parent = track,
			})
			Corner(10, knob)

			local clicker = Create("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 4,
				Parent = holder,
			})

			clicker.MouseEnter:Connect(function()
				Tween(holderStroke, EASE_OUT_FAST, { Transparency = 0.2 })
			end)
			clicker.MouseLeave:Connect(function()
				Tween(holderStroke, EASE_OUT_FAST, { Transparency = 0.5 })
			end)

			local function setState(newState, silent)
				state = newState
				Tween(track, EASE_OUT, { BackgroundColor3 = state and accent or Color3.fromRGB(55, 55, 55) })
				Tween(trackGlow, EASE_OUT, { ImageTransparency = state and 0.7 or 1 })
				Tween(knob, EASE_SPRING, {
					Position = state and UDim2.new(1, -22, 0.5, -9.5) or UDim2.new(0, 3, 0.5, -9.5),
					Size = UDim2.new(0, 21, 0, 21),
				})
				task.delay(0.12, function()
					Tween(knob, EASE_OUT_FAST, { Size = UDim2.new(0, 19, 0, 19) })
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
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundColor3 = COLORS.SurfaceLight,
				ZIndex = 3,
				Parent = self.content,
			})
			Corner(7, holder)
			Stroke(COLORS.Border, 1, holder, 0.5)

			Create("TextLabel", {
				Text = cfg.Name or "Slider",
				Size = UDim2.new(1, -90, 0, 20),
				Position = UDim2.new(0, 14, 0, 7),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
				Parent = holder,
			})

			local valuePill = Create("Frame", {
				Size = UDim2.new(0, 60, 0, 20),
				Position = UDim2.new(1, -74, 0, 7),
				BackgroundColor3 = COLORS.SurfaceLighter,
				ZIndex = 3,
				Parent = holder,
			})
			Corner(5, valuePill)
			local valueLabel = Create("TextLabel", {
				Text = tostring(value) .. suffix,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				ZIndex = 3,
				Parent = valuePill,
			})

			local track = Create("Frame", {
				Size = UDim2.new(1, -28, 0, 7),
				Position = UDim2.new(0, 14, 1, -17),
				BackgroundColor3 = Color3.fromRGB(48, 48, 48),
				ZIndex = 3,
				Parent = holder,
			})
			Corner(4, track)

			local fillFrac = (value - min) / math.max(max - min, 1e-6)
			local fill = Create("Frame", {
				Size = UDim2.new(fillFrac, 0, 1, 0),
				BackgroundColor3 = accent,
				ZIndex = 3,
				Parent = track,
			})
			Corner(4, fill)
			Gradient(COLORS.AccentBright, accent, 0, fill)

			local knob = Create("Frame", {
				Size = UDim2.new(0, 15, 0, 15),
				Position = UDim2.new(fillFrac, -7.5, 0.5, -7.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				ZIndex = 4,
				Parent = track,
			})
			Corner(8, knob)
			Stroke(accent, 2, knob, 0)

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
				Tween(knob, EASE_LINEAR, { Position = UDim2.new(frac, -7.5, 0.5, -7.5) })
				valueLabel.Text = tostring(value) .. suffix

				SafeCall(cfg.Callback, value)
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					Tween(knob, EASE_OUT_FAST, { Size = UDim2.new(0, 19, 0, 19) })
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
						Tween(knob, EASE_OUT_FAST, { Size = UDim2.new(0, 15, 0, 15) })
					end
					dragging = false
				end
			end)

			return {
				Set = function(_, v)
					value = math.clamp(v, min, max)
					local frac = (value - min) / math.max(max - min, 1e-6)
					Tween(fill, EASE_OUT, { Size = UDim2.new(frac, 0, 1, 0) })
					Tween(knob, EASE_OUT, { Position = UDim2.new(frac, -7.5, 0.5, -7.5) })
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
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = COLORS.SurfaceLight,
				ClipsDescendants = true,
				ZIndex = 5,
				Parent = self.content,
			})
			Corner(7, holder)
			Stroke(COLORS.Border, 1, holder, 0.5)

			Create("TextLabel", {
				Text = cfg.Name or "Dropdown",
				Size = UDim2.new(0.5, 0, 0, 42),
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
				Size = UDim2.new(0.4, -30, 0, 42),
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
				Size = UDim2.new(0, 26, 0, 42),
				Position = UDim2.new(1, -30, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.SubText,
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				ZIndex = 5,
				Parent = holder,
			})

			local clicker = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 6,
				Parent = holder,
			})

			local optionsFrame = Create("Frame", {
				Size = UDim2.new(1, 0, 0, #options * 32),
				Position = UDim2.new(0, 0, 0, 42),
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
						BackgroundTransparency = isSel and 0.05 or 0.2,
					})
				end
			end

			for _, opt in ipairs(options) do
				local optBtn = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundColor3 = COLORS.SurfaceLighter,
					BackgroundTransparency = 0.2,
					Text = tostring(opt),
					TextColor3 = COLORS.SubText,
					Font = Enum.Font.Gotham,
					TextSize = 13,
					AutoButtonColor = false,
					ZIndex = 5,
					Parent = optionsFrame,
				})
				HoverGlow(optBtn, COLORS.SurfaceLighter, COLORS.SurfaceElevated)
				table.insert(optionButtons, { btn = optBtn, value = opt })

				optBtn.MouseButton1Click:Connect(function()
					selected = opt
					selectedLabel.Text = tostring(opt)
					refreshHighlight()
					SafeCall(cfg.Callback, selected)
					open = false
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 42) })
					Tween(arrow, EASE_OUT, { Rotation = 0 })
				end)
			end
			refreshHighlight()

			clicker.MouseButton1Click:Connect(function()
				open = not open
				if open then
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 42 + #options * 32) })
					Tween(arrow, EASE_OUT, { Rotation = 180 })
				else
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 42) })
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
		-- MULTI-SELECT DROPDOWN
		----------------------------------------------------------------
		function sec:CreateMultiDropdown(cfg)
			cfg = cfg or {}
			local options = cfg.Options or {}
			local selected = {}
			for _, v in ipairs(cfg.Default or {}) do selected[v] = true end
			local open = false

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = COLORS.SurfaceLight,
				ClipsDescendants = true,
				ZIndex = 5,
				Parent = self.content,
			})
			Corner(7, holder)
			Stroke(COLORS.Border, 1, holder, 0.5)

			Create("TextLabel", {
				Text = cfg.Name or "Select",
				Size = UDim2.new(0.5, 0, 0, 42),
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
				Size = UDim2.new(0.4, -30, 0, 42),
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
				Size = UDim2.new(0, 26, 0, 42),
				Position = UDim2.new(1, -30, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.SubText,
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				ZIndex = 5,
				Parent = holder,
			})

			local clicker = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 6,
				Parent = holder,
			})

			local optionsFrame = Create("Frame", {
				Size = UDim2.new(1, 0, 0, #options * 32),
				Position = UDim2.new(0, 0, 0, 42),
				BackgroundTransparency = 1,
				ZIndex = 5,
				Parent = holder,
			})
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = optionsFrame })

			for _, opt in ipairs(options) do
				local row = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundColor3 = COLORS.SurfaceLighter,
					BackgroundTransparency = 0.2,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 5,
					Parent = optionsFrame,
				})
				HoverGlow(row, COLORS.SurfaceLighter, COLORS.SurfaceElevated)

				local check = Create("Frame", {
					Size = UDim2.new(0, 15, 0, 15),
					Position = UDim2.new(0, 12, 0.5, -7.5),
					BackgroundColor3 = selected[opt] and accent or Color3.fromRGB(55, 55, 55),
					ZIndex = 5,
					Parent = row,
				})
				Corner(4, check)
				local checkMark = Create("TextLabel", {
					Text = "✓",
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					TextTransparency = selected[opt] and 0 or 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					ZIndex = 5,
					Parent = check,
				})

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
					Tween(checkMark, EASE_OUT_FAST, { TextTransparency = selected[opt] and 0 or 1 })
					countLabel.Text = countText()
					local list = {}
					for k in pairs(selected) do table.insert(list, k) end
					SafeCall(cfg.Callback, list)
				end)
			end

			clicker.MouseButton1Click:Connect(function()
				open = not open
				if open then
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 42 + #options * 32) })
					Tween(arrow, EASE_OUT, { Rotation = 180 })
				else
					Tween(holder, EASE_OUT, { Size = UDim2.new(1, 0, 0, 42) })
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
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = COLORS.SurfaceLight,
				ZIndex = 3,
				Parent = self.content,
			})
			Corner(7, holder)
			local activeStroke = Stroke(COLORS.Border, 1, holder, 0.5)

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
				ZIndex = 3,
				Parent = holder,
			})

			box.Focused:Connect(function()
				Tween(activeStroke, EASE_OUT_FAST, { Color = accent, Thickness = 1.5, Transparency = 0 })
				Tween(holder, EASE_OUT_FAST, { BackgroundColor3 = COLORS.SurfaceLighter })
			end)
			box.FocusLost:Connect(function(enterPressed)
				Tween(activeStroke, EASE_OUT_FAST, { Color = COLORS.Border, Thickness = 1, Transparency = 0.5 })
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
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = COLORS.SurfaceLight,
				ZIndex = 3,
				Parent = self.content,
			})
			Corner(7, holder)
			Stroke(COLORS.Border, 1, holder, 0.5)

			Create("TextLabel", {
				Text = cfg.Name or "Keybind",
				Size = UDim2.new(1, -110, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
				Parent = holder,
			})

			local keyBtn = Create("TextButton", {
				Size = UDim2.new(0, 92, 0, 28),
				Position = UDim2.new(1, -102, 0.5, -14),
				BackgroundColor3 = COLORS.SurfaceLighter,
				Text = currentKey.Name,
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				AutoButtonColor = false,
				ZIndex = 3,
				Parent = holder,
			})
			Corner(6, keyBtn)
			Stroke(COLORS.Border, 1, keyBtn, 0.4)

			local conn
			keyBtn.MouseButton1Click:Connect(function()
				if listening then return end
				listening = true
				keyBtn.Text = "..."
				GlowPulse(keyBtn, { BackgroundColor3 = COLORS.SurfaceElevated })

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
		-- COLOR PICKER
		----------------------------------------------------------------
		function sec:CreateColorPicker(cfg)
			cfg = cfg or {}
			local current = cfg.Default or Color3.fromRGB(180, 0, 0)

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = COLORS.SurfaceLight,
				ClipsDescendants = true,
				ZIndex = 3,
				Parent = self.content,
			})
			Corner(7, holder)
			Stroke(COLORS.Border, 1, holder, 0.5)

			Create("TextLabel", {
				Text = cfg.Name or "Color",
				Size = UDim2.new(1, -70, 0, 42),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
				Parent = holder,
			})

			local swatch = Create("TextButton", {
				Size = UDim2.new(0, 30, 0, 30),
				Position = UDim2.new(1, -44, 0, 6),
				BackgroundColor3 = current,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 3,
				Parent = holder,
			})
			Corner(7, swatch)
			Stroke(COLORS.BorderBright, 1.5, swatch, 0.2)

			local open = false
			local hueFrame = Create("Frame", {
				Size = UDim2.new(1, -28, 0, 22),
				Position = UDim2.new(0, 14, 0, 48),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				ZIndex = 3,
				Parent = holder,
			})
			Corner(5, hueFrame)
			Create("UIGradient", {
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
				Tween(holder, EASE_OUT, { Size = open and UDim2.new(1, 0, 0, 80) or UDim2.new(1, 0, 0, 42) })
			end)

			return {
				Get = function() return current end,
				Set = function(_, c) current = c; swatch.BackgroundColor3 = c end,
			}
		end

		----------------------------------------------------------------
		-- LABEL / DIVIDER / PROGRESS BAR / STAT ROW
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
				ZIndex = 3,
				Parent = self.content,
			})
			Tween(lbl, EASE_SMOOTH, { TextTransparency = 0 })
			return lbl
		end

		function sec:CreateDivider()
			local wrap = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 9),
				BackgroundTransparency = 1,
				ZIndex = 3,
				Parent = self.content,
			})
			local div = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, 0.5, 0),
				BackgroundColor3 = COLORS.Border,
				ZIndex = 3,
				Parent = wrap,
			})
			Gradient(COLORS.Border, COLORS.Background, 0, div, NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0.6),
			}))
			return div
		end

		function sec:CreateProgressBar(cfg)
			cfg = cfg or {}
			local min, max = cfg.Min or 0, cfg.Max or 100
			local value = math.clamp(cfg.Default or min, min, max)

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = COLORS.SurfaceLight,
				ZIndex = 3,
				Parent = self.content,
			})
			Corner(7, holder)
			Stroke(COLORS.Border, 1, holder, 0.5)

			Create("TextLabel", {
				Text = cfg.Name or "Progress",
				Size = UDim2.new(0.6, 0, 0, 18),
				Position = UDim2.new(0, 12, 0, 5),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
				Parent = holder,
			})

			local pctLabel = Create("TextLabel", {
				Text = string.format("%d%%", math.floor((value - min) / math.max(max - min, 1e-6) * 100)),
				Size = UDim2.new(0.35, 0, 0, 18),
				Position = UDim2.new(0.65, 0, 0, 5),
				BackgroundTransparency = 1,
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 3,
				Parent = holder,
			})

			local track = Create("Frame", {
				Size = UDim2.new(1, -24, 0, 8),
				Position = UDim2.new(0, 12, 1, -16),
				BackgroundColor3 = Color3.fromRGB(48, 48, 48),
				ZIndex = 3,
				Parent = holder,
			})
			Corner(4, track)

			local frac = (value - min) / math.max(max - min, 1e-6)
			local fill = Create("Frame", {
				Size = UDim2.new(frac, 0, 1, 0),
				BackgroundColor3 = accent,
				ZIndex = 3,
				Parent = track,
			})
			Corner(4, fill)
			Gradient(COLORS.AccentBright, accent, 0, fill)

			return {
				Set = function(_, v)
					value = math.clamp(v, min, max)
					local f = (value - min) / math.max(max - min, 1e-6)
					Tween(fill, EASE_SMOOTH, { Size = UDim2.new(f, 0, 1, 0) })
					pctLabel.Text = string.format("%d%%", math.floor(f * 100))
				end,
				Get = function() return value end,
			}
		end

		-- Compact key/value readout row, e.g. for status displays
		function sec:CreateStatRow(cfg)
			cfg = cfg or {}
			local row = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				ZIndex = 3,
				Parent = self.content,
			})
			Create("TextLabel", {
				Text = cfg.Name or "Stat",
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.SubText,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
				Parent = row,
			})
			local valueLabel = Create("TextLabel", {
				Text = tostring(cfg.Value or ""),
				Size = UDim2.new(0.5, 0, 1, 0),
				Position = UDim2.new(0.5, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = COLORS.Text,
				Font = Enum.Font.GothamSemibold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 3,
				Parent = row,
			})
			return {
				Set = function(_, v) valueLabel.Text = tostring(v) end,
			}
		end

		return sec
	end

	return tab
end

return Zerox
