-- enjoy.lua
-- Portable Roblox hitsound library
-- Usage example:
-- local ENJOY = loadstring(game:HttpGet("https://raw.githubusercontent.com/YourName/YourRepo/main/enjoy.lua"))()
-- ENJOY.Play("https://github.com/localscripts/Audio/raw/refs/heads/main/Hitsound/Rust.wav", 1, 1)
-- ENJOY.Debunk(Enum.KeyCode.X, Enum.KeyCode.Z)

local ENJOY = {}
local uis = game:GetService("UserInputService")

-- Default keys
local playKey = Enum.KeyCode.M
local destroyKey = Enum.KeyCode.N
local connection
local running = false

-- Internal play function
local function playSound(link, pitch, volume)
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

-- Public function: setup sound keys
function ENJOY.Play(link, pitch, volume)
    running = true
    if connection then connection:Disconnect() end

    connection = uis.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == playKey and running then
            playSound(link, pitch, volume)
        elseif input.KeyCode == destroyKey then
            running = false
            if connection then connection:Disconnect() end
            local sc = rawget(getfenv(), "script")
            if sc and typeof(sc) == "Instance" and sc.Destroy then
                pcall(function() sc:Destroy() end)
            else
                warn("Script instance unavailable; input unbound and disabled instead.")
            end
        end
    end)
end

-- Public function: change hotkeys dynamically
function ENJOY.Debunk(newDestroyKey, newPlayKey)
    if newDestroyKey then destroyKey = newDestroyKey end
    if newPlayKey then playKey = newPlayKey end
    print(string.format("ENJOY hotkeys updated → Play: %s | Destroy: %s", tostring(playKey), tostring(destroyKey)))
end

return ENJOY
