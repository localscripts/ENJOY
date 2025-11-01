--// GaugeLib.lua — glass gauge UI (ModuleScript)
--// Manual/Pluggable value source; scalable text; invisible resize hitbox; hold-to-close;
--// spring needle + jitter; themeable; NO global blur by default.
--// Needle base auto-matches cap width, slightly smaller by default (baseMatchCapScale=0.92).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local GaugeLib = {}
GaugeLib.__index = GaugeLib
GaugeLib.Providers = {}

--==================== DEFAULTS ====================
-- ==================== DEFAULTS (replace this whole table) ====================
local DEFAULTS = {
	parent = nil,
	sizePx = 340,                                -- your default size
	position = UDim2.fromOffset(28, 28),

	startAngle = -120,
	endAngle   =  120,
	valueMin   = 0,
	valueMax   = 10,

	inputMaxForFullScale = 200,

	ticks = {
		minorsPerStep = 5,
		outerFrac  = 0.95,
		majorInner = 0.70,
		minorInner = 0.80,
		labelPad   = 0.05,
		labelAngleOffset = 0,

		majorThickness = 3,
		minorThickness = 2,
		color = Color3.fromRGB(0, 185, 255),      -- BLUE
		labelColor = Color3.fromRGB(0, 185, 255), -- BLUE
		labelFont = Enum.Font.GothamSemibold,
		labelSize = 14,
		labelStrokeColor = Color3.fromRGB(0, 0, 0),
		labelStrokeTransparency = 0.35,
	},

	needle = {
		color = Color3.fromRGB(0, 185, 255),      -- BLUE
		lenFrac = 0.46,
		baseWidthPx = 12,
		tipWidthPx  = 1,
		segments = 28,
		capFrac = 0.10,

		-- wider logic (radius-based)
		baseWidthFrac = 0.090,
		tipWidthFrac  = 0.020,
		widthScale    = 0.30,                     -- your thin default
		-- base matches cap (slightly smaller)
		baseMatchCapScale    = 0.92,
		baseMatchCapMarginPx = 0,
	},

	-- pixel-lock (keep scaling behavior as you set)
	pixelLock = {
		labels  = false,
		readout = false,
		capPx   = nil,
		needleWidth = false,
	},

	readout = {
		visible = true,
		format = '%.1f',
		font = Enum.Font.GothamBold,
		size = 22,
		color = Color3.fromRGB(0, 185, 255),      -- BLUE
		strokeColor = Color3.fromRGB(0, 0, 0),
		strokeT = 0.35,
		posYFrac = 0.965,
	},

	dynamics = {
		freqHz = 3.2,
		damping = 0.75,
		maxSweepDps = 540,
	},

	jitter = {
		enableAbove = 1.0,
		baseDeg = 0.35,
		rowMult = 1.5,
		maxDeg = 2.0,
		noiseHz = 7.5,
		microHz = 23.0,
		stabNeedleDps = 60.0,
		stabTargetDps = 40.0,
		stabErrDeg = 3.0,
	},

	background = {
		show = true,
		gradientTopColor    = Color3.fromRGB(0, 0, 0),   -- BLACK
		gradientBottomColor = Color3.fromRGB(0, 0, 0),   -- BLACK
		strokeColor         = Color3.fromRGB(0, 185, 255), -- BLUE

		idleBgTransparency   = 1.0,
		activeBgTransparency = 0.80,
		idleStrokeT   = 1.0,
		activeStrokeT = 0.20,

		cornerRadiusPx = 18,
		dragScale      = 1.05,
		tweenTime      = 0.18,

		useGlobalBlur  = false,  -- still off by default
		blurSizeActive = 12,
	},

	dragging = { enabled = true },

	resizing = {
		enabled =  true,
		minPx = 140,
		maxPx = 720,
		handleSizePx = 20,
		hoverPadPx  = 36,
		handleFadeTime = 0.15,

		handleShowFill = false,
		handleBgTIdle  = 1.0,
		handleBgTHover = 1.0,

		gripColor = Color3.fromRGB(0, 185, 255), -- BLUE
		gripTIdle  = 1.0,
		gripTHover = 0.15,                       -- your hover translucency
	},

	closing = {
		enabled = true,
		holdSeconds = 0.9,
		buttonSizePx = 22,
		iconColor = Color3.fromRGB(0, 185, 255),     -- BLUE
		progressColor = Color3.fromRGB(0, 185, 255), -- BLUE
		hoverBgTransparency = 0.85,
		hoverStrokeTransparency = 0.35,
	},

	valueProvider = nil, -- manual by default
}
-- ================== end DEFAULTS ==================


--==================== UTILS ====================
local function merge(dst, src)
	for k,v in pairs(src or {}) do
		if typeof(v) == "table" and typeof(dst[k]) == "table" then
			merge(dst[k], v)
		else
			dst[k] = v
		end
	end
	return dst
end

local function clampToViewport(frame, pos)
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920,1080)
	local sz = frame.AbsoluteSize
	return UDim2.fromOffset(
		math.clamp(pos.X.Offset, 0, math.max(0, vp.X - sz.X)),
		math.clamp(pos.Y.Offset, 0, math.max(0, vp.Y - sz.Y))
	)
end

local function pointInFrame(f, p)
	if not (f and f:IsA("GuiObject")) then return false end
	local a, s = f.AbsolutePosition, f.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
end

local function angleForValue(val, minV, maxV, a0, a1)
	local t = math.clamp((val - minV)/math.max(1e-6, (maxV - minV)), 0, 1)
	return a0 + (a1 - a0)*t
end

-- provider helpers
function GaugeLib.Providers.Getter(getterFn)
	assert(type(getterFn) == "function", "Providers.Getter expects a function")
	return function() local ok,v = pcall(getterFn); return ok and (v or 0) or 0 end
end
function GaugeLib.Providers.NumberValue(numValue)
	return function() return (numValue and numValue.Value) or 0 end
end
function GaugeLib.Providers.HumanoidHealth(humanoid)
	return function()
		if humanoid and humanoid.Parent then
			return math.max(0, humanoid.Health)
		end
		return 0
	end
end

--==================== CLASS ====================
function GaugeLib.new(opts)
	opts = merge(table.clone(DEFAULTS), opts or {})

	local self = setmetatable({
		_opts = opts,
		_running = true,
		_nodes = {},
		_manualValue = 0,
		_useManual = (opts.valueProvider == nil),
	}, GaugeLib)

	-- parent
	local parentGui = opts.parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "GaugeLibGui"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 1000
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = parentGui

	local gauge = Instance.new("Frame")
	gauge.Name = "GaugeRoot"
	gauge.Size = UDim2.fromOffset(opts.sizePx, opts.sizePx)
	gauge.Position = opts.position
	gauge.BackgroundTransparency = 1
	gauge.Active = true
	gauge.Parent = screen
	Instance.new("UIAspectRatioConstraint", gauge).AspectRatio = 1

	-- scale helper
	local baseSizePx = opts.sizePx
	local function scaleFactor()
		local sz = gauge.AbsoluteSize
		return math.max(0.25, math.min(4, sz.X / math.max(1, baseSizePx)))
	end

	-- background
	local bg = opts.background
	local backplate = Instance.new("Frame")
	backplate.Name = "Backplate"
	backplate.Size = UDim2.fromScale(1,1)
	backplate.BackgroundColor3 = bg.gradientBottomColor
	backplate.BackgroundTransparency = bg.idleBgTransparency
	backplate.BorderSizePixel = 0
	backplate.ZIndex = 0
	backplate.Parent = gauge

	local bpCorner = Instance.new("UICorner")
	bpCorner.CornerRadius = UDim.new(0, bg.cornerRadiusPx)
	bpCorner.Parent = backplate

	local bpStroke = Instance.new("UIStroke")
	bpStroke.Thickness = 1
	bpStroke.Color = bg.strokeColor
	bpStroke.Transparency = bg.idleStrokeT
	bpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpStroke.Parent = backplate

	local bpGrad = Instance.new("UIGradient")
	bpGrad.Rotation = 90
	bpGrad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, bg.gradientTopColor),
		ColorSequenceKeypoint.new(1, bg.gradientBottomColor),
	}
	bpGrad.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.25),
	}
	bpGrad.Parent = backplate

	local bpScale = Instance.new("UIScale"); bpScale.Scale = 1; bpScale.Parent = backplate

	-- optional global blur
	local blurFx = nil
	if bg.useGlobalBlur then
		blurFx = Lighting:FindFirstChild("GaugeDragBlur") or Instance.new("BlurEffect")
		blurFx.Name = "GaugeDragBlur"
		blurFx.Enabled = false
		blurFx.Size = 0
		blurFx.Parent = Lighting
	end

	-- face layers
	local face = Instance.new("Frame"); face.Size = UDim2.fromScale(1,1); face.BackgroundTransparency=1; face.ZIndex=1; face.Parent=gauge
	local tickLayer = Instance.new("Frame"); tickLayer.Size=UDim2.fromScale(1,1); tickLayer.BackgroundTransparency=1; tickLayer.ZIndex=2; tickLayer.Parent=face
	local pivot = Instance.new("Frame"); pivot.Size=UDim2.fromScale(1,1); pivot.AnchorPoint=Vector2.new(0.5,0.5); pivot.Position=UDim2.fromScale(0.5,0.5); pivot.BackgroundTransparency=1; pivot.ZIndex=3; pivot.Parent=face

	-- needle container
	local needleContainer = Instance.new("Frame")
	needleContainer.AnchorPoint = Vector2.new(0.5,1)
	needleContainer.Position = UDim2.fromScale(0.5,0.5)
	needleContainer.BackgroundTransparency = 1
	needleContainer.Parent = pivot

	-- center cap
	local cap = Instance.new("Frame")
	cap.AnchorPoint = Vector2.new(0.5,0.5)
	cap.Position = UDim2.fromScale(0.5,0.5)
	if opts.pixelLock.capPx then
		cap.Size = UDim2.fromOffset(opts.pixelLock.capPx, opts.pixelLock.capPx)
	else
		cap.Size = UDim2.fromScale(opts.needle.capFrac, opts.needle.capFrac)
	end
	cap.BackgroundColor3 = opts.needle.color
	cap.BorderSizePixel = 0
	cap.Parent = face
	Instance.new("UICorner", cap).CornerRadius = UDim.new(1,0)
	self._nodes.cap = cap

	-- readout
	local rd = opts.readout
	local readout = Instance.new("TextLabel")
	readout.BackgroundTransparency = 1
	readout.AnchorPoint = Vector2.new(0.5,1)
	readout.Position = UDim2.fromScale(0.5, rd.posYFrac)
	readout.Size = UDim2.fromOffset(160,26)
	readout.Font = rd.font
	readout.TextSize = rd.size
	readout.TextColor3 = rd.color
	readout.TextStrokeColor3 = rd.strokeColor
	readout.TextStrokeTransparency = rd.strokeT
	readout.Text = rd.format:format(0)
	readout.Visible = rd.visible
	readout.TextScaled = false
	readout.AutoLocalize = false
	readout.Parent = face

	local function applyReadoutSize()
		local f = opts.pixelLock.readout and 1 or scaleFactor()
		readout.TextSize = math.max(8, math.floor((opts.readout.size * f) + 0.5))
	end
	applyReadoutSize()

	-- ticks & labels
	local labelNodes = {}
	local tk = opts.ticks

	local function makeTick(aDeg, innerFrac, outerFrac, thickness, color, radius)
		local innerPx = radius*innerFrac
		local outerPx = radius*outerFrac
		local lengthPx = math.max(0, outerPx - innerPx)

		local p = Instance.new("Frame")
		p.Size = UDim2.fromScale(1,1)
		p.AnchorPoint = Vector2.new(0.5,0.5)
		p.Position = UDim2.fromScale(0.5,0.5)
		p.BackgroundTransparency = 1
		p.Rotation = aDeg
		p.ZIndex = 2
		p.Parent = tickLayer

		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5,1)
		line.Position = UDim2.new(0.5, 0, 0.5, -innerPx)
		line.Size = UDim2.new(0, thickness, 0, lengthPx)
		line.BackgroundColor3 = color
		line.BorderSizePixel = 0
		line.Parent = p
		Instance.new("UICorner", line).CornerRadius = UDim.new(1,0)
	end

	local function rebuildTicks()
		for _,n in ipairs(labelNodes) do n:Destroy() end
		table.clear(labelNodes)
		tickLayer:ClearAllChildren()

		local sz = face.AbsoluteSize
		local radius = math.min(sz.X, sz.Y) * 0.5

		local labelSizeEff = tk.labelSize * (opts.pixelLock.labels and 1 or scaleFactor())
		labelSizeEff = math.max(8, math.floor(labelSizeEff + 0.5))

		local sample = TextService:GetTextSize("10", labelSizeEff, tk.labelFont, Vector2.new(512,256))
		local labelHalfH = sample.Y/2
		local majorBaseR = radius * tk.majorInner
		local padPixels = radius * tk.labelPad
		local labelCenterR = math.max(0, majorBaseR - padPixels - labelHalfH)

		for n = opts.valueMin, opts.valueMax do
			local tickAngle = angleForValue(n, opts.valueMin, opts.valueMax, opts.startAngle, opts.endAngle)
			makeTick(tickAngle, tk.majorInner, tk.outerFrac, tk.majorThickness, tk.color, radius)

			if n < opts.valueMax then
				for m=1, tk.minorsPerStep-1 do
					local a = angleForValue(n + m/tk.minorsPerStep, opts.valueMin, opts.valueMax, opts.startAngle, opts.endAngle)
					makeTick(a, tk.minorInner, tk.outerFrac, tk.minorThickness, tk.color, radius)
				end
			end

			local labelAngle = tickAngle + tk.labelAngleOffset
			local text = tostring(n)
			local bounds = TextService:GetTextSize(text, labelSizeEff, tk.labelFont, Vector2.new(512,256))

			local container = Instance.new("Frame")
			container.Size = UDim2.fromScale(1,1)
			container.AnchorPoint = Vector2.new(0.5,0.5)
			container.Position = UDim2.fromScale(0.5,0.5)
			container.BackgroundTransparency = 1
			container.ZIndex = 2
			container.Rotation = labelAngle
			container.Parent = tickLayer

			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.AnchorPoint = Vector2.new(0.5,1)
			lbl.Position = UDim2.new(0.5,0,0.5, -(math.max(0, labelCenterR)))
			lbl.Size = UDim2.fromOffset(bounds.X+4, bounds.Y)
			lbl.Font = tk.labelFont
			lbl.TextSize = labelSizeEff
			lbl.Text = text
			lbl.TextColor3 = tk.labelColor
			lbl.TextStrokeColor3 = tk.labelStrokeColor
			lbl.TextStrokeTransparency = tk.labelStrokeTransparency
			lbl.ZIndex = 2
			lbl.Rotation = -labelAngle
			lbl.TextScaled = false
			lbl.AutoLocalize = false
			lbl.Parent = container

			table.insert(labelNodes, container)
		end
	end

	--==== NEEDLE (base ~ cap width, slightly smaller by default) ====
	local function rebuildNeedle()
		local n = opts.needle or {}
		needleContainer:ClearAllChildren()

		local gsz = pivot.AbsoluteSize
		local radius = math.max(1, math.min(gsz.X, gsz.Y) * 0.5)
		local totalLen = math.max(1, gsz.Y) * (tonumber(n.lenFrac) or 0.46)

		local baseWidthPx   = tonumber(n.baseWidthPx)   or 12
		local tipWidthPx    = tonumber(n.tipWidthPx)    or 1
		local baseWidthFrac = tonumber(n.baseWidthFrac) or 0.075
		local tipWidthFrac  = tonumber(n.tipWidthFrac)  or 0.015
		local widthScale    = tonumber(n.widthScale)    or 1.0
		local segments      = tonumber(n.segments)      or 28
		local color         = n.color or Color3.fromRGB(255,0,0)

		-- pixel scaling unless locked
		local sfW = (opts.pixelLock and opts.pixelLock.needleWidth) and 1 or scaleFactor()

		-- cap diameter (px)
		local capDiameterPx
		if opts.pixelLock and opts.pixelLock.capPx then
			capDiameterPx = math.max(1, opts.pixelLock.capPx)
		else
			local capFrac = tonumber(n.capFrac) or 0.10
			capDiameterPx = math.max(1, gsz.X * capFrac)
		end

		local baseScale = tonumber(n.baseMatchCapScale) or 0.92
		local baseMargin = tonumber(n.baseMatchCapMarginPx) or 0
		local baseW = math.max(2, math.floor(capDiameterPx * baseScale - baseMargin + 0.5))

		-- tip width: take the wider of px-path and frac-path, then scale
		local tipW_pxScaled = tipWidthPx * sfW
		local tipW_frac     = tipWidthFrac * radius
		local tipW_raw      = math.max(tipW_pxScaled, tipW_frac) * widthScale
		local tipW          = math.clamp(math.floor(tipW_raw + 0.5), 2, math.max(2, baseW - 1))

		for i = 1, segments do
			local t = i / segments

			-- also consider original px baseline ramp to avoid ultra-thin early segments on tiny gauges
			local wPxRamp = (tipWidthPx + (baseWidthPx - tipWidthPx) * t) * sfW

			-- target ramp from tip to baseW
			local wRamp = tipW + (baseW - tipW) * t
			if i == segments then wRamp = baseW end

			local w = math.max(wPxRamp, wRamp) * widthScale
			w = math.max(2, math.floor(w + 0.5))

			local h = math.max(1, math.floor(totalLen * (1 - (t - 1 / segments)) + 0.5))

			local seg = Instance.new("Frame")
			seg.AnchorPoint = Vector2.new(0.5, 1)
			seg.Position    = UDim2.fromScale(0.5, 0.5)
			seg.Size        = UDim2.new(0, w, 0, h)
			seg.BackgroundColor3 = color
			seg.BorderSizePixel  = 0
			seg.ZIndex = 20 + i
			seg.Parent = needleContainer
			Instance.new("UICorner", seg).CornerRadius = UDim.new(1, 0)
		end
	end

	-- build visuals
	rebuildTicks()
	rebuildNeedle()
	face:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		applyReadoutSize()
		rebuildTicks()
		rebuildNeedle()
	end)

	--============ RESIZING (invisible hitbox; grips fade) ============
	local rs = opts.resizing
	local resizeHandle = Instance.new("Frame")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.Size = UDim2.fromOffset(rs.handleSizePx, rs.handleSizePx)
	resizeHandle.AnchorPoint = Vector2.new(1,1)
	resizeHandle.Position = UDim2.fromScale(1,1)
	resizeHandle.BackgroundTransparency = 1.0
	resizeHandle.BorderSizePixel = 0
	resizeHandle.ZIndex = 50
	resizeHandle.Active = true
	resizeHandle.Visible = rs.enabled
	resizeHandle.Parent = gauge
	Instance.new("UICorner", resizeHandle).CornerRadius = UDim.new(0,6)

	for n=0,2 do
		local grip = Instance.new("Frame")
		grip.Name = "Grip"..n
		grip.AnchorPoint = Vector2.new(1,1)
		grip.Size = UDim2.fromOffset(2,12)
		grip.Position = UDim2.new(1, -4 - n*5, 1, -4 - n*5)
		grip.BackgroundColor3 = rs.gripColor
		grip.BackgroundTransparency = rs.gripTIdle
		grip.Rotation = 45
		grip.BorderSizePixel = 0
		grip.ZIndex = 51
		grip.Parent = resizeHandle
	end

	local function setResizeHandleVisible(show)
		local ti = TweenInfo.new(rs.handleFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, child in ipairs(resizeHandle:GetChildren()) do
			if child:IsA("Frame") and child.Name:find("Grip",1,true) then
				local targetT = show and rs.gripTHover or rs.gripTIdle
				TweenService:Create(child, ti, { BackgroundTransparency = targetT }):Play()
			end
		end
	end
	setResizeHandleVisible(false)

	local resizeHoverPad = Instance.new("Frame")
	resizeHoverPad.Size = UDim2.fromOffset(rs.hoverPadPx, rs.hoverPadPx)
	resizeHoverPad.AnchorPoint = Vector2.new(1,1)
	resizeHoverPad.Position = UDim2.fromScale(1,1)
	resizeHoverPad.BackgroundTransparency = 1
	resizeHoverPad.BorderSizePixel = 0
	resizeHoverPad.ZIndex = resizeHandle.ZIndex - 1
	resizeHoverPad.Active = false
	resizeHoverPad.Parent = gauge

	--============ CLOSE (press & hold) ============
	local cl = opts.closing
	local closeButton = Instance.new("Frame")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(cl.buttonSizePx, cl.buttonSizePx)
	closeButton.AnchorPoint = Vector2.new(1,0)
	closeButton.Position = UDim2.new(1, -6, 0, 6)
	closeButton.BackgroundColor3 = bg.gradientTopColor
	closeButton.BackgroundTransparency = 1
	closeButton.BorderSizePixel = 0
	closeButton.ZIndex = 50
	closeButton.Active = cl.enabled
	closeButton.Visible = cl.enabled
	closeButton.Parent = gauge
	Instance.new("UICorner", closeButton).CornerRadius = UDim.new(1,0)

	local cbStroke = Instance.new("UIStroke")
	cbStroke.Thickness = 1
	cbStroke.Color = bg.strokeColor
	cbStroke.Transparency = 1
	cbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cbStroke.Parent = closeButton

	local cbGrad = Instance.new("UIGradient")
	cbGrad.Rotation = 90
	cbGrad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, bg.gradientTopColor),
		ColorSequenceKeypoint.new(1, bg.gradientBottomColor),
	}
	cbGrad.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.25),
	}
	cbGrad.Parent = closeButton

	local x1 = Instance.new("Frame"); x1.AnchorPoint=Vector2.new(0.5,0.5); x1.Position=UDim2.fromScale(0.5,0.5); x1.Size=UDim2.fromOffset(2,12); x1.BackgroundColor3=cl.iconColor; x1.BackgroundTransparency=1; x1.BorderSizePixel=0; x1.Rotation=45; x1.ZIndex=51; x1.Parent=closeButton
	local x2 = x1:Clone(); x2.Rotation=-45; x2.Parent=closeButton

	local progress = Instance.new("Frame")
	progress.AnchorPoint = Vector2.new(0,1)
	progress.Position = UDim2.new(0,5,1,-4)
	progress.Size = UDim2.new(0,0,0,2)
	progress.BackgroundColor3 = cl.progressColor
	progress.BackgroundTransparency = 1
	progress.BorderSizePixel = 0
	progress.ZIndex = 52
	progress.Parent = closeButton

	local hoveringClose = false
	local closeProgressTween, closeProgressMode = nil, nil

	local function setCloseButtonVisible(v)
		local ti = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(closeButton, ti, { BackgroundTransparency = v and cl.hoverBgTransparency or 1 }):Play()
		TweenService:Create(cbStroke,   ti, { Transparency = v and cl.hoverStrokeTransparency or 1 }):Play()
		x1.BackgroundTransparency = v and 0.15 or 1
		x2.BackgroundTransparency = v and 0.15 or 1
		progress.BackgroundTransparency = v and 0.2 or 1
		if not v then
			if closeProgressTween then pcall(function() closeProgressTween:Cancel() end) end
			progress.Size = UDim2.new(0,0,0,2)
			closeProgressMode = nil
		end
	end
	setCloseButtonVisible(false)

	local function removeGauge()
		self._running = false
		if blurFx then blurFx.Size = 0; blurFx.Enabled = false end
		screen:Destroy()
		if self._onClosed then self._onClosed() end
	end
	local function cancelCloseProgress(mode)
		if closeProgressMode and (mode == nil or mode == closeProgressMode) then
			if closeProgressTween then pcall(function() closeProgressTween:Cancel() end) end
			closeProgressTween = nil
			closeProgressMode = nil
			progress.Size = UDim2.new(0,0,0,2)
			if not hoveringClose then setCloseButtonVisible(false) end
		end
	end
	local function beginCloseProgress()
		cancelCloseProgress(nil)
		closeProgressMode = "press"
		setCloseButtonVisible(true)
		progress.Size = UDim2.new(0,0,0,2)
		closeProgressTween = TweenService:Create(progress, TweenInfo.new(cl.holdSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { Size = UDim2.new(1,-10,0,2) })
		closeProgressTween.Completed:Connect(function()
			if closeProgressMode == "press" then removeGauge() end
		end)
		closeProgressTween:Play()
	end

	if cl.enabled then
		closeButton.MouseEnter:Connect(function() hoveringClose = true; setCloseButtonVisible(true) end)
		closeButton.MouseLeave:Connect(function() hoveringClose = false; if not closeProgressMode then setCloseButtonVisible(false) end end)
		closeButton.InputBegan:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
			beginCloseProgress()
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					cancelCloseProgress("press")
				end
			end)
		end)
	end

	--============ DRAG / RESIZE LOGIC ============
	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
	local resizing, resizeInput, resizeStart, startSize = false, nil, nil, nil
	local dragTweens = {}

	local function setResizeHandleVisible(show)
		local ti = TweenInfo.new(rs.handleFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, child in ipairs(resizeHandle:GetChildren()) do
			if child:IsA("Frame") and child.Name:find("Grip",1,true) then
				local targetT = show and rs.gripTHover or rs.gripTIdle
				TweenService:Create(child, ti, { BackgroundTransparency = targetT }):Play()
			end
		end
	end

	local function setDraggingVisual(active)
		for _,t in ipairs(dragTweens) do pcall(function() t:Cancel() end) end
		table.clear(dragTweens)

		local ti = TweenInfo.new(bg.tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local bpTween = TweenService:Create(backplate, ti, { BackgroundTransparency = active and bg.activeBgTransparency or bg.idleBgTransparency })
		local stTween = TweenService:Create(bpStroke,   ti, { Transparency = active and bg.activeStrokeT or bg.idleStrokeT })
		local scTween = TweenService:Create(bpScale,    ti, { Scale = active and bg.dragScale or 1 })
		bpTween:Play(); stTween:Play(); scTween:Play()
		table.insert(dragTweens, bpTween); table.insert(dragTweens, stTween); table.insert(dragTweens, scTween)

		if blurFx then
			if active then blurFx.Enabled = true end
			local blurTween = TweenService:Create(blurFx, ti, { Size = active and bg.blurSizeActive or 0 })
			blurTween.Completed:Connect(function() if not active then blurFx.Enabled = false end end)
			blurTween:Play(); table.insert(dragTweens, blurTween)
		end

		setResizeHandleVisible(active or resizing)
		setCloseButtonVisible(active or (closeProgressMode ~= nil))
	end

	-- drag
	if opts.dragging.enabled then
		gauge.InputBegan:Connect(function(i)
			if resizing then return end
			if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
			if pointInFrame(closeButton, i.Position) or pointInFrame(resizeHandle, i.Position) then return end
			dragging, dragStart, startPos = true, i.Position, gauge.Position
			setDraggingVisual(true)
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging=false; setDraggingVisual(false) end
			end)
		end)
		gauge.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then dragInput = i end
		end)
	end

	-- resize
	if rs.enabled then
		resizeHandle.MouseEnter:Connect(function() setResizeHandleVisible(true) end)
		resizeHandle.MouseLeave:Connect(function() if not resizing then setResizeHandleVisible(false) end end)
		resizeHoverPad.MouseEnter:Connect(function() setResizeHandleVisible(true) end)
		resizeHoverPad.MouseLeave:Connect(function() if not resizing then setResizeHandleVisible(false) end end)

		resizeHandle.InputBegan:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
			resizing = true
			resizeStart = i.Position
			startSize = gauge.AbsoluteSize
			setDraggingVisual(true)
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					resizing=false
					setDraggingVisual(false)
					setResizeHandleVisible(false)
				end
			end)
		end)
		resizeHandle.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then resizeInput = i end
		end)
	end

	UserInputService.InputChanged:Connect(function(i)
		if not self._running then return end
		if dragging and i == dragInput then
			local d = i.Position - dragStart
			gauge.Position = clampToViewport(gauge, UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			))
		end
		if rs.enabled and resizing and i == resizeInput then
			local d = i.Position - resizeStart
			local target = math.clamp(startSize.X + d.X, rs.minPx, rs.maxPx)
			gauge.Size = UDim2.fromOffset(target, target)
			gauge.Position = clampToViewport(gauge, gauge.Position)
		end
	end)

	--============ DYNAMICS + JITTER ============
	local dyn = opts.dynamics
	local needleAngle = angleForValue(opts.valueMin, opts.valueMin, opts.valueMax, opts.startAngle, opts.endAngle)
	local needleVel   = 0
	local jitterTime, lastTarget = 0, needleAngle

	local provider = opts.valueProvider
	local function inputToAngle(val)
		local full = opts.inputMaxForFullScale or 1
		local frac = math.clamp(val / math.max(1e-6, full), 0, 1)
		local value = opts.valueMin + (opts.valueMax - opts.valueMin)*frac
		return angleForValue(value, opts.valueMin, opts.valueMax, opts.startAngle, opts.endAngle), value
	end

	self._conn = RunService.RenderStepped:Connect(function(dt)
		if not self._running then return end
		local raw = (self._useManual or not provider) and (self._manualValue or 0) or (provider(dt) or 0)

		local targetAngle, gaugeVal = inputToAngle(raw)

		if rd.visible then
			readout.Text = rd.format:format(raw)
		end

		-- spring
		local w = 2*math.pi*dyn.freqHz
		local k = w*w
		local c = 2*dyn.damping*w
		local err = targetAngle - needleAngle
		local acc = k*err - c*needleVel
		needleVel = needleVel + acc*dt
		if dyn.maxSweepDps then
			local m = dyn.maxSweepDps
			if needleVel >  m then needleVel =  m end
			if needleVel < -m then needleVel = -m end
		end
		needleAngle = needleAngle + needleVel*dt

		-- jitter on stable
		jitterTime += dt
		local j = opts.jitter
		local targetVelDps = (targetAngle - lastTarget)/math.max(dt, 1e-6)
		local stable = (math.abs(needleVel) < j.stabNeedleDps)
		           and (math.abs(targetVelDps) < j.stabTargetDps)
		           and (math.abs(err) < j.stabErrDeg)

		local jitterOffset = 0
		if gaugeVal >= j.enableAbove and stable then
			local rowsOverOne = math.max(0, gaugeVal - 1)
			local amp = math.min(j.baseDeg * (j.rowMult ^ rowsOverOne), j.maxDeg)
			local hum   = math.noise(jitterTime * j.noiseHz)
			local micro = math.sin(2*math.pi*j.microHz*jitterTime)
			jitterOffset = amp * (0.8*hum + 0.2*micro)
		end
		lastTarget = targetAngle

		pivot.Rotation = needleAngle + jitterOffset
	end)

	--============ PUBLIC API ============
	self.ScreenGui = screen
	self.Root = gauge

	function self:SetThemeColors(theme)
		if not theme then return end
		if theme.tickColor then opts.ticks.color = theme.tickColor end
		if theme.labelColor then opts.ticks.labelColor = theme.labelColor end
		if theme.labelStrokeColor then opts.ticks.labelStrokeColor = theme.labelStrokeColor end
		if theme.labelStrokeTransparency then opts.ticks.labelStrokeTransparency = theme.labelStrokeTransparency end
		if theme.needleColor then opts.needle.color = theme.needleColor; cap.BackgroundColor3 = theme.needleColor; rebuildNeedle() end
		if theme.readoutColor then readout.TextColor3 = theme.readoutColor; opts.readout.color = theme.readoutColor end
		if theme.readoutStrokeColor then readout.TextStrokeColor3 = theme.readoutStrokeColor; opts.readout.strokeColor = theme.readoutStrokeColor end
		if theme.glassTop or theme.glassBottom then
			local top = theme.glassTop or bg.gradientTopColor
			local bot = theme.glassBottom or bg.gradientBottomColor
			bpGrad.Color = ColorSequence.new{ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(1, bot) }
		end
		if theme.strokeColor then bpStroke.Color = theme.strokeColor end
		if theme.closeIconColor then
			x1.BackgroundColor3 = theme.closeIconColor; x2.BackgroundColor3 = theme.closeIconColor; opts.closing.iconColor = theme.closeIconColor
		end
		if theme.progressColor then progress.BackgroundColor3 = theme.progressColor; opts.closing.progressColor = theme.progressColor end
		if theme.resizeGripColor then
			for _,c in ipairs(resizeHandle:GetChildren()) do if c:IsA("Frame") and c.Name:find("Grip",1,true) then c.BackgroundColor3 = theme.resizeGripColor end end
			opts.resizing.gripColor = theme.resizeGripColor
		end
		rebuildTicks()
	end

	function self:SetFonts(f)
		if not f then return end
		if f.labelFont then opts.ticks.labelFont = f.labelFont end
		if f.labelSize then opts.ticks.labelSize = f.labelSize end
		if f.readoutFont then readout.Font = f.readoutFont; opts.readout.font = f.readoutFont end
		if f.readoutSize then opts.readout.size = f.readoutSize; applyReadoutSize() end
		rebuildTicks()
	end

	-- VALUE / PROVIDERS
	function self:SetValueProvider(fn) opts.valueProvider = fn; self._useManual = (fn == nil); return self end
	function self:UseManual(b) self._useManual = (b ~= false); return self end
	function self:SetValue(v) self._manualValue = tonumber(v) or 0; return self end
	function self:NudgeValue(dv) self._manualValue = (self._manualValue or 0) + (tonumber(dv) or 0); return self end

	function self:UseHumanoidHealth(humanoid)
		self:SetValueProvider(GaugeLib.Providers.HumanoidHealth(humanoid))
		local maxH = (humanoid and humanoid.MaxHealth) or 100
		self:SetRange(0, maxH)
		self:SetMaxInputForFullScale(maxH)
		return self
	end
	function self:UseNumberValue(numValue, minV, maxV)
		self:SetValueProvider(GaugeLib.Providers.NumberValue(numValue))
		if minV or maxV then self:SetRange(minV or opts.valueMin, maxV or opts.valueMax) end
		if maxV then self:SetMaxInputForFullScale(maxV) end
		return self
	end

	function self:SetReadoutFormat(fmt) opts.readout.format = fmt or opts.readout.format; return self end
	function self:SetMaxInputForFullScale(v) opts.inputMaxForFullScale = tonumber(v) or opts.inputMaxForFullScale; return self end

	-- PIXEL LOCK & STYLE
	function self:SetPixelLock(pl)
		opts.pixelLock = opts.pixelLock or {}
		for k,v in pairs(pl or {}) do opts.pixelLock[k] = v end
		local px = opts.pixelLock.capPx
		if px then cap.Size = UDim2.fromOffset(px, px) else cap.Size = UDim2.fromScale(opts.needle.capFrac, opts.needle.capFrac) end
		applyReadoutSize(); rebuildTicks(); rebuildNeedle()
		return self
	end

	function self:SetDragStyle(style)
		if not style then return self end
		merge(opts.background, style)

		if style.useGlobalBlur ~= nil then
			if style.useGlobalBlur and not blurFx then
				blurFx = Instance.new("BlurEffect")
				blurFx.Name = "GaugeDragBlur"
				blurFx.Enabled = false
				blurFx.Size = 0
				blurFx.Parent = Lighting
			elseif (not style.useGlobalBlur) and blurFx then
				blurFx.Enabled = false
				blurFx.Size = 0
				blurFx:Destroy()
				blurFx = nil
			end
		end

		if style.gradientTopColor or style.gradientBottomColor then
			bpGrad.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, opts.background.gradientTopColor),
				ColorSequenceKeypoint.new(1, opts.background.gradientBottomColor)
			}
		end
		if style.strokeColor then bpStroke.Color = style.strokeColor end
		return self
	end

	function self:SetResizeStyle(style) if style then merge(opts.resizing, style) end return self end
	function self:SetCloseStyle(style)
		if style then
			merge(opts.closing, style)
			x1.BackgroundColor3 = opts.closing.iconColor
			x2.BackgroundColor3 = opts.closing.iconColor
			progress.BackgroundColor3 = opts.closing.progressColor
		end
		return self
	end

	function self:SetNeedleDynamics(freqHz, damping, maxSweepDps)
		if freqHz then opts.dynamics.freqHz = freqHz end
		if damping then opts.dynamics.damping = damping end
		if maxSweepDps ~= nil then opts.dynamics.maxSweepDps = maxSweepDps end
		return self
	end

	function self:SetJitter(j) if j then merge(opts.jitter, j) end return self end
	function self:SetAngles(a0, a1) if a0 then opts.startAngle=a0 end; if a1 then opts.endAngle=a1 end; rebuildTicks(); return self end
	function self:SetRange(minV, maxV) if minV then opts.valueMin=minV end; if maxV then opts.valueMax=maxV end; rebuildTicks(); return self end
	function self:SetPosition(pos) gauge.Position = pos; return self end

	function self:SetSizePx(px)
		local r = opts.resizing
		local clamped = math.clamp(px, r.minPx, r.maxPx)
		gauge.Size = UDim2.fromOffset(clamped, clamped)
		applyReadoutSize(); rebuildTicks(); rebuildNeedle()
		return self
	end

	function self:EnableDragging(b) opts.dragging.enabled = not not b; return self end
	function self:EnableResizing(b) opts.resizing.enabled = not not b; resizeHandle.Visible = opts.resizing.enabled; return self end
	function self:ShowReadout(b) readout.Visible = not not b; opts.readout.visible = not not b; return self end
	function self:OnClosed(cb) self._onClosed = cb; return self end
	function self:Destroy() if self._conn then self._conn:Disconnect() end self._running=false; if blurFx then blurFx.Size=0; blurFx.Enabled=false; blurFx:Destroy() end screen:Destroy() end

	return self
end

return GaugeLib
