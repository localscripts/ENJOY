-- ENJOY.lua
local ENJOY = {}

-- Ensure cache folder exists
local CACHE_DIR = "ENJOY"
if not isfolder(CACHE_DIR) then
    makefolder(CACHE_DIR)
end

-- Extract a safe filename from the URL (uses the last path segment),
-- appends a short djb2 hash to avoid collisions, and keeps/forces an extension.
local function djb2(s)
    local hash = 5381
    for i = 1, #s do
        hash = bit32.band(bit32.lshift(hash, 5) + hash + string.byte(s, i), 0xFFFFFFFF)
    end
    return ("%08x"):format(hash)
end

local function basenameFromUrl(link)
    -- strip query/fragment
    local core = link:gsub("[%?#].*$", "")
    -- last segment after /
    local name = core:match("([^/]+)$") or "audio"
    -- sanitize
    name = name:gsub("[^%w%._%-]", "_")
    return name
end

local function ensureExtension(name, fallbackExt)
    if name:find("%.[%w]+$") then
        return name
    else
        return name .. (fallbackExt or ".wav")
    end
end

local function cachedPathFor(link)
    local base = ensureExtension(basenameFromUrl(link), ".wav")
    -- Add short hash to avoid overwrite if two links share the same basename
    local hashed = base:gsub("(%.[%w]+)$", function(ext)
        return "_" .. djb2(link):sub(1, 6) .. ext
    end)
    return ("%s/%s"):format(CACHE_DIR, hashed)
end

-- Active sounds tracking so you can stop/destroy later
local active = {}

--- Plays (and caches) an audio from a direct link.
-- @param link (string) required
-- @param pitch (number|table) optional; OR pass an options table:
--        ENJOY.Play(link, { pitch=1, volume=1, looped=false, parent=workspace })
-- @param volume (number) optional (ignored if table used)
-- @param looped (boolean) optional (ignored if table used)
-- @return sound (Instance) The Sound instance created
function ENJOY.Play(link, pitch, volume, looped)
    assert(type(link) == "string" and #link > 0, "ENJOY.Play: link must be a non-empty string")

    -- Options handling (backward-compatible)
    local opts
    if type(pitch) == "table" then
        opts = pitch
    else
        opts = { pitch = pitch, volume = volume, looped = looped }
    end
    local pitchVal  = tonumber(opts.pitch)  or 1
    local volumeVal = tonumber(opts.volume) or 1
    local loopedVal = (opts.looped == true)
    local parentVal = opts.parent or workspace

    local file = cachedPathFor(link)

    -- Download if not cached
    if not isfile(file) then
        local ok, res = pcall(function()
            return request({ Url = link, Method = "GET" })
        end)
        if ok and res and res.StatusCode == 200 and res.Body then
            writefile(file, res.Body)
        else
            warn("ENJOY: failed to download sound: " .. tostring(link))
            return nil
        end
    end

    -- Create & play
    local s = Instance.new("Sound")
    s.SoundId = getcustomasset(file)
    s.Volume = volumeVal
    s.PlaybackSpeed = pitchVal
    s.Looped = loopedVal
    s.Parent = parentVal
    s:Play()

    -- Auto-remove when finished (non-looping)
    if not loopedVal then
        s.Ended:Connect(function()
            active[s] = nil
            if s and s.Parent then
                s:Destroy()
            end
        end)
    end

    active[s] = true
    return s
end

--- Stops & destroys a Sound created by ENJOY.Play
function ENJOY.Destroy(sound)
    if typeof(sound) == "Instance" and sound:IsA("Sound") then
        active[sound] = nil
        if sound.IsPlaying then
            pcall(function() sound:Stop() end)
        end
        pcall(function() sound:Destroy() end)
    end
end

--- Stops & destroys all currently tracked sounds
function ENJOY.StopAll()
    for s in pairs(active) do
        ENJOY.Destroy(s)
    end
    active = {}
end

return ENJOY
