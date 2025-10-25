
# 🎧 ENJOY — Quick Docs

Minimal Roblox audio helper: downloads once, caches, and plays a sound immediately. No keybinds.

## Example
```lua
local ENJOY = loadstring(game:HttpGet("https://raw.githubusercontent.com/localscripts/ENJOY/refs/heads/main/test.lua"))()
ENJOY.Play("https://github.com/localscripts/Audio/raw/refs/heads/main/Hitsound/Rust.wav", 1, 1)
````

## API

### ENJOY.Play(link, pitch, volume)

* **link** (`string`) — direct URL to `.wav`/`.mp3`
* **pitch** (`number`, default `1`) — playback speed
* **volume** (`number`, default `1`) — 0–10 typical

**Behavior:**
Downloads once (`writefile`), loads via `getcustomasset`, plays from `workspace`, destroys after `Ended`.


## Notes

* Requires `request`, `isfile`, `writefile`, `getcustomasset`.
* Uses the file name from the URL (fallback: `hitsound_enjoy.wav`).
* Prints a warning if download fails; won’t crash.

