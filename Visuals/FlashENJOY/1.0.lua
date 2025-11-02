-- ENJOY_Overlay.lua
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local Players      = game:GetService("Players")

local OVERLAY = {}

-- Internal: where to parent the ScreenGui
local function getGuiRoot()
    local ok, ui = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    if ok and ui then return ui end
    local lp = Players.LocalPlayer
    if lp then
        local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 1)
        if pg then return pg end
    end
    return game:GetService("CoreGui")
end

-- Singleton ScreenGui
local GUI
local function ensureGui()
    if GUI and GUI.Parent then return GUI end
    GUI = Instance.new("ScreenGui")
    GUI.Name = "ENJOY_Overlay"
    GUI.IgnoreGuiInset = true
    GUI.ResetOnSpawn = false
    GUI.DisplayOrder = 9e6 -- very high to sit on top
    GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    GUI.Parent = getGuiRoot()
    return GUI
end

-- Track active layers so you can close/destroy all
local active = {}

local function mkTweenInfo(t, style, dir)
    return TweenInfo.new(
        tonumber(t) or 0.5,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    )
end

local function tweenProps(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

-- Creates a full-screen frame (or image) and (optionally) a tweened BlurEffect.
-- Returns {frame=..., image=..., blur=..., _tw=...}
local function createLayer(opts)
    opts = opts or {}
    ensureGui()

    local container = Instance.new("Frame")
    container.Name = "ENJOY_Layer"
    container.Size = UDim2.fromScale(1, 1)
    container.Position = UDim2.fromScale(0, 0)
    container.BackgroundColor3 = opts.color or Color3.new(0, 0, 0)
    -- ui "opacity" (0..1) -> Roblox BackgroundTransparency (1..0)
    local opacity = math.clamp(tonumber(opts.opacity) or 0.6, 0, 1)
    local targetBgT = 1 - opacity
    local startBgT  = 1 -- start fully transparent; we’ll tween in
    container.BackgroundTransparency = startBgT
    container.BorderSizePixel = 0
    container.ZIndex = 9e6

    -- Optional image overlay on top (e.g., vignette). If not provided, we just use the solid color.
    local imageLabel
    if opts.imageId then
        imageLabel = Instance.new("ImageLabel")
        imageLabel.Name = "OverlayImage"
        imageLabel.Size = UDim2.fromScale(1, 1)
        imageLabel.Position = UDim2.fromScale(0, 0)
        imageLabel.BackgroundTransparency = 1
        imageLabel.Image = opts.imageId -- "rbxassetid://..." or "rbxasset://..."
        imageLabel.ScaleType = Enum.ScaleType.Stretch
        imageLabel.ImageTransparency = 1
        imageLabel.ZIndex = container.ZIndex + 1
        imageLabel.Parent = container
    end

    container.Parent = GUI

    -- Optional blur
    local blurEffect
    local blurSize = tonumber(opts.blur) or 0
    if blurSize > 0 then
        blurEffect = Instance.new("BlurEffect")
        blurEffect.Size = 0
        blurEffect.Parent = Lighting
    end

    local infoIn = mkTweenInfo(opts.timeIn or opts.time or 0.5, opts.easingStyle, opts.easingDirection)
    local tws = {}

    table.insert(tws, tweenProps(container, infoIn, { BackgroundTransparency = targetBgT }))

    if imageLabel then
        local imgOpacity = (opts.imageOpacity ~= nil) and math.clamp(opts.imageOpacity, 0, 1) or 1
        table.insert(tws, tweenProps(imageLabel, infoIn, { ImageTransparency = 1 - imgOpacity }))
    end

    if blurEffect then
        table.insert(tws, tweenProps(blurEffect, infoIn, { Size = blurSize }))
    end

    local layer = { frame = container, image = imageLabel, blur = blurEffect, _tw = tws, _bgTarget = targetBgT }
    active[layer] = true
    return layer
end

--- Fade in a fullscreen overlay.
-- opts:
--   color: Color3 (default black)
--   opacity: 0..1 where 1 is fully opaque color (default 0.6)
--   timeIn: seconds (default 0.5)
--   easingStyle, easingDirection: Enum values (optional)
--   imageId: optional image overlay (e.g., "rbxassetid://...")
--   imageOpacity: 0..1 (default 1)
--   blur: 0..56 optional blur size
function OVERLAY.FadeIn(opts)
    return createLayer(opts)
end

--- Fade out and destroy a specific overlay layer (or all if nil).
-- timeOut: seconds (default 0.5)
function OVERLAY.FadeOut(layer, timeOut, easingStyle, easingDirection)
    local targets = {}

    if layer then
        if active[layer] then table.insert(targets, layer) end
    else
        for lyr in pairs(active) do
            table.insert(targets, lyr)
        end
    end

    for _, lyr in ipairs(targets) do
        active[lyr] = nil
        local infoOut = mkTweenInfo(timeOut or 0.5, easingStyle, easingDirection)

        local tws = {}
        if lyr.frame and lyr.frame.Parent then
            table.insert(tws, tweenProps(lyr.frame, infoOut, { BackgroundTransparency = 1 }))
        end
        if lyr.image and lyr.image.Parent then
            table.insert(tws, tweenProps(lyr.image, infoOut, { ImageTransparency = 1 }))
        end
        if lyr.blur and lyr.blur.Parent then
            table.insert(tws, tweenProps(lyr.blur, infoOut, { Size = 0 }))
        end

        -- Cleanup when the longest tween finishes
        local longest = tws[#tws]
        if longest then
            longest.Completed:Connect(function()
                if lyr.blur and lyr.blur.Parent then pcall(function() lyr.blur:Destroy() end) end
                if lyr.frame and lyr.frame.Parent then pcall(function() lyr.frame:Destroy() end) end
            end)
        else
            -- nothing to tween; just destroy
            if lyr.blur then pcall(function() lyr.blur:Destroy() end) end
            if lyr.frame then pcall(function() lyr.frame:Destroy() end) end
        end
    end
end

--- Convenience: Quick flash — fade in, hold, fade out
-- opts: same as FadeIn + { hold = seconds (default 0.1), timeOut = seconds (default = timeIn) }
function OVERLAY.Flash(opts)
    opts = opts or {}
    local hold = tonumber(opts.hold) or 0.1
    local timeOut = tonumber(opts.timeOut) or tonumber(opts.timeIn) or tonumber(opts.time) or 0.5
    local layer = OVERLAY.FadeIn(opts)
    task.delay((tonumber(opts.timeIn) or tonumber(opts.time) or 0.5) + hold, function()
        OVERLAY.FadeOut(layer, timeOut, opts.easingStyle, opts.easingDirection)
    end)
    return layer
end

--- Destroy everything immediately (no fade)
function OVERLAY.DestroyAll()
    for lyr in pairs(active) do
        active[lyr] = nil
        if lyr.blur then pcall(function() lyr.blur:Destroy() end) end
        if lyr.frame then pcall(function() lyr.frame:Destroy() end) end
    end
    if GUI and GUI.Parent then pcall(function() GUI:Destroy() end) end
    GUI = nil
end

return OVERLAY
