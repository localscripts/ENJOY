Perfect — here’s a clean, ready-to-share **GaugeLib documentation file header**, specifically for the **HTTP (loadstring)** setup.

It includes:

* 📦 Example usage at the top
* 🧾 Key info (how it loads, default behavior, customization)
* ⚙️ Important notes for web-hosted usage
* ✅ Your current **all-white default** theme

---

## 🔰 Example usage (copy this into your script)

```lua
-- 🎯 Load GaugeLib directly from HTTP (always latest version)
local GaugeLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/localscripts/ENJOY/refs/heads/main/Lib/GaugeENJOY/main.lua"))()

-- 🧪 Create a gauge with default white theme
local g = GaugeLib.new() -- no args needed; uses built-in defaults

-- Optional: configure range and display
g:SetRange(0, 10)
 :SetMaxInputForFullScale(10)
 :SetReadoutFormat("%.1f")

-- 🔄 Animate demo (just for showcase)
task.spawn(function()
	while task.wait(0.05) do
		local t = os.clock()
		g:SetValue(5 + math.sin(t) * 4)
	end
end)
```

---

## ⚙️ Key details

### 1️⃣  Loading

```lua
local GaugeLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/localscripts/ENJOY/refs/heads/main/Lib/GaugeENJOY/main.luat"))()
```

✅ No `require()` or file import needed — everything runs from your hosted script.
💾 Roblox caches it in memory for the current session.
You can update your hosted file anytime — users automatically get the new version.

---

### 2️⃣  Defaults

**Current default theme:** All-white (white tick marks, labels, needle, readout, close button, etc.)
**Background:** Black (high contrast).
**UseGlobalBlur:** Disabled — no full-screen blur.
**Size:** 340×340 px, draggable, resizable, smooth spring needle motion, jitter when stable.

---

### 3️⃣  Customization

You can still override any section per instance:

```lua
local g = GaugeLib.new({
	readout = { color = Color3.fromRGB(0, 255, 120) }, -- green readout
	needle  = { widthScale = 0.8 },                    -- thicker needle
	background = { useGlobalBlur = true },             -- re-enable blur
})
```

Or recolor everything dynamically:

```lua
g:SetThemeColors({
	tickColor = Color3.new(1, 0, 0),    -- red
	labelColor = Color3.new(1, 0, 0),
	needleColor = Color3.new(1, 0, 0),
	readoutColor = Color3.new(1, 0, 0),
	strokeColor = Color3.new(1, 0, 0),
})
```

---

## 🎨 Default settings (All-White Theme)

> These are baked into the remote file (`https://raw.githubusercontent.com/localscripts/ENJOY/refs/heads/main/Lib/GaugeENJOY/main.lua`)
> You don’t need to paste them locally unless you’re self-hosting a variant.

```lua
local DEFAULTS = {
	sizePx = 340,
	position = UDim2.fromOffset(28, 28),
	startAngle = -120,
	endAngle   = 120,
	valueMin   = 0,
	valueMax   = 10,
	inputMaxForFullScale = 200,

	ticks = {
		color = Color3.fromRGB(255,255,255),
		labelColor = Color3.fromRGB(255,255,255),
		labelFont = Enum.Font.GothamSemibold,
		labelSize = 14,
		labelStrokeColor = Color3.fromRGB(0,0,0),
		labelStrokeTransparency = 0.35,
	},

	needle = {
		color = Color3.fromRGB(255,255,255),
		lenFrac = 0.46,
		segments = 28,
		baseWidthFrac = 0.090,
		tipWidthFrac  = 0.020,
		widthScale    = 0.3,
		baseMatchCapScale = 0.92,
	},

	readout = {
		color = Color3.fromRGB(255,255,255),
		strokeColor = Color3.fromRGB(0,0,0),
		strokeT = 0.35,
		font = Enum.Font.GothamBold,
		size = 22,
		format = "%.1f",
	},

	background = {
		gradientTopColor    = Color3.fromRGB(0,0,0),
		gradientBottomColor = Color3.fromRGB(0,0,0),
		strokeColor         = Color3.fromRGB(255,255,255),
		idleBgTransparency   = 1.0,
		activeBgTransparency = 0.8,
		useGlobalBlur = false,
	},

	resizing = {
		gripColor = Color3.fromRGB(255,255,255),
		gripTIdle = 1.0,
		gripTHover = 0.15,
	},

	closing = {
		iconColor = Color3.fromRGB(255,255,255),
		progressColor = Color3.fromRGB(255,255,255),
		hoverBgTransparency = 0.85,
		hoverStrokeTransparency = 0.35,
	},
}
```

---

## 🧩 Quick API summary

| Method                                              | Description                  |
| :-------------------------------------------------- | :--------------------------- |
| `GaugeLib.new(opts?)`                               | Create a new gauge           |
| `g:SetValue(x)`                                     | Manually set value           |
| `g:NudgeValue(dx)`                                  | Add to current value         |
| `g:SetValueProvider(fn)`                            | Supply a custom value getter |
| `g:SetRange(min, max)`                              | Define label range           |
| `g:SetMaxInputForFullScale(v)`                      | Set full-scale mapping       |
| `g:SetNeedleDynamics(freqHz, damping, maxSweepDps)` | Adjust spring behavior       |
| `g:SetJitter({...})`                                | Customize idle needle jitter |
| `g:SetThemeColors({...})`                           | Recolor UI dynamically       |
| `g:SetFonts({...})`                                 | Change fonts/sizes           |
| `g:SetPixelLock({...})`                             | Control scaling behavior     |
| `g:SetSizePx(px)`                                   | Resize programmatically      |
| `g:Destroy()`                                       | Remove gauge manually        |

---

## 💡 Tips

* Gauges are **draggable** and **resizable**.
* The **resize handle** only appears on hover.
* The **close button** requires holding down for ~1 second.
* You can attach to anything numeric (speed, HP, money, etc.).
* No local `require` needed — pure HTTP import.
* For best results, host on **raw GitHub** or **your own API** for auto-updates.

---

Would you like me to make a **“self-hosting boilerplate” version** (so you can easily deploy to your own URL with custom defaults and version tags)?
