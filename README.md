# 🎧 ENJOY Library Documentation

A minimal Roblox **audio utility** for instantly playing custom hitsounds or sound effects.
Automatically handles file download, caching, and playback — **no keybinds or setup needed.**

---

## 📦 Installation

Add this line at the top of your Roblox script to load ENJOY directly from your GitHub:

```lua
local ENJOY = loadstring(game:HttpGet("https://raw.githubusercontent.com/localscripts/ENJOY/refs/heads/main/test.lua"))()
```

This loads the ENJOY library into your script environment.

---

## ⚙️ Function Reference

### 🟢 `ENJOY.Play(link, pitch, volume)`

Plays a sound immediately when called.
If the file hasn’t been downloaded before, it will be fetched and cached automatically for faster reuse.

#### **Parameters**

| Name     | Type     | Default | Description                               |
| -------- | -------- | ------- | ----------------------------------------- |
| `link`   | `string` | —       | Direct link to a `.wav` or `.mp3` file.   |
| `pitch`  | `number` | `1`     | Playback speed / pitch multiplier.        |
| `volume` | `number` | `1`     | Volume level of the sound (0–10 typical). |

#### **Behavior**

* Downloads the file once and saves it locally via `writefile()`.
* Plays the sound from `workspace` using `getcustomasset()`.
* Automatically destroys the sound after it finishes playing.

#### **Example**

```lua
ENJOY.Play("https://github.com/localscripts/Audio/raw/refs/heads/main/Hitsound/Rust.wav", 1, 1)
```

➡️ Instantly plays the **Rust hitsound** one time.

---

## 💾 File Caching

* The sound is downloaded once and stored locally (using the audio file’s name, or `hitsound_enjoy.wav` by default).
* Future calls reuse the local file — no need to re-download unless deleted manually.

---

## 🧠 Behavior Summary

| Action            | Description                                            |
| ----------------- | ------------------------------------------------------ |
| `ENJOY.Play(...)` | Immediately downloads (if needed) and plays the sound. |
| Automatic cleanup | Sound instance destroys itself after playback.         |
| Local caching     | Reduces network usage on repeated plays.               |

---

## 🧩 Example Usage

```lua
local ENJOY = loadstring(game:HttpGet("https://raw.githubusercontent.com/localscripts/ENJOY/refs/heads/main/test.lua"))()

-- Play immediately on script run
ENJOY.Play("https://github.com/localscripts/Audio/raw/refs/heads/main/Hitsound/Rust.wav", 1, 1)

-- You can call ENJOY.Play() again with different sounds or settings:
-- ENJOY.Play("https://example.com/another_sound.wav", 1.2, 0.8)
```

---

## 🪶 Notes

* Works in environments that support:
  `request`, `isfile`, `writefile`, and `getcustomasset`.
* Each sound plays in **workspace** and is automatically cleaned up.
* If the sound fails to download, a warning is printed — no crash or error.


