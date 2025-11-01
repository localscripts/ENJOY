local ENJOY = {}

-- Make a deterministic per-link filename (djb2 hash to keep it short)
local function filenameFor(link)
    local hash = 5381
    for i = 1, #link do
        hash = bit32.band(bit32.lshift(hash, 5) + hash + string.byte(link, i), 0xFFFFFFFF)
    end
    return ("hitsound_enjoy_%08x.wav"):format(hash)
end

function ENJOY.Play(link, pitch, volume)
    assert(type(link) == "string" and #link > 0, "ENJOY.Play: link must be a non-empty string")

    local file = filenameFor(link)

    -- Download if this specific link hasn't been cached yet
    if not isfile(file) then
        local ok, res = pcall(function()
            return request({ Url = link, Method = "GET" })
        end)

        if ok and res and res.StatusCode == 200 and res.Body then
            writefile(file, res.Body)
        else
            warn("Failed to download sound: " .. tostring(link))
            return
        end
    end

    local s = Instance.new("Sound")
    s.SoundId = getcustomasset(file)  -- unique per link now
    s.Volume = volume or 1
    s.PlaybackSpeed = pitch or 1
    s.Parent = workspace
    s:Play()
    s.Ended:Connect(function()
        s:Destroy()
    end)
end

return ENJOY
