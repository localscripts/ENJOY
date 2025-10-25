local ENJOY = {}

function ENJOY.Play(link, pitch, volume)
    local file = "hitsound_enjoy.wav"

    -- Download once
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
    s.SoundId = getcustomasset(file)
    s.Volume = volume or 1
    s.PlaybackSpeed = pitch or 1
    s.Parent = workspace
    s:Play()
    s.Ended:Connect(function()
        s:Destroy()
    end)
end

return ENJOY
