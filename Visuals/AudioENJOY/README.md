# ENJOY:AUDIO()

**Warning:**
This code may change at any time.
If you use it in your scripts, **fork or copy the repository** — future updates may break your implementation.

---

## Notes

* **Reverse playback:** Roblox does **not** support playing sounds backward. (`PlaybackSpeed = -1` will not work.)
  To “invert” a sound, you must upload or host a reversed version yourself.

* **Supported formats:** `.mp3` and `.wav` work reliably. Other formats may fail to load.

* **Executor requirements:**
  Your environment must support:

  ```
  request, isfile, writefile, isfolder, makefolder, getcustomasset
  ```

* **Cache behavior:**

  * All downloaded sounds are stored in an `ENJOY/` folder.
  * Each file is saved with its original name and a short hash to prevent collisions.
  * You can safely delete the folder to clear cached sounds.

---

## Overview

`ENJOY` is a lightweight Roblox audio module that automatically downloads, caches, and plays sounds from direct links.
It’s designed for simplicity and performance — download once, then reuse locally.

---

## Basic Example

```lua
-- Load the module (example hosting)
local ENJOY = loadstring(game:HttpGet('https://raw.githubusercontent.com/localscripts/ENJOY/refs/heads/main/Visuals/AudioENJOY/1.0.1.lua'))()

-- Play a sound
local sound = ENJOY.Play('https://github.com/localscripts/ENJOY/raw/refs/heads/main/Visuals/AudioENJOY/Audios/u-have-no-heart.mp3', {
    pitch  = 1,        -- Playback speed
    volume = 1,        -- Volume level
    looped = false,    -- true to loop continuously
    parent = workspace -- Optional, defaults to workspace
})

-- Stop and destroy this sound
ENJOY.Destroy(sound)

-- Stop and destroy all active sounds
ENJOY.StopAll()
```

---

## Folder Structure

When ENJOY downloads sounds, it creates and caches them like this:

```
ENJOY/
  u-have-no-heart-mp3_4f8c22.mp3
  hitsound_rust_9ab231.wav
```

Each file is stored once per unique link.

---

## API Reference

### `ENJOY.Play(link, options) → Sound | nil`

Plays and caches a sound from a direct URL.

**Parameters**

| Name             | Type     | Default   | Description                 |
| ---------------- | -------- | --------- | --------------------------- |
| `link`           | string   | —         | Direct URL to a sound file  |
| `options.pitch`  | number   | 1         | Playback speed              |
| `options.volume` | number   | 1         | Volume level                |
| `options.looped` | boolean  | false     | Whether to loop the sound   |
| `options.parent` | Instance | workspace | Parent object for the sound |

**Returns:**
A Roblox `Sound` instance, or `nil` if the download fails.

**Example:**

```lua
local sound = ENJOY.Play('https://github.com/localscripts/ENJOY/raw/refs/heads/main/Visuals/AudioENJOY/Audios/u-have-no-heart.mp3', {
    pitch = 20,
    volume = 10,
    looped = true,
    parent = workspace
})
```

This will:

1. Download and cache the file to `ENJOY/music_xxxxxx.mp3` (if not already cached)
2. Play it immediately
3. Keep looping until destroyed

---

### `ENJOY.Destroy(sound)`

Stops and destroys a specific sound created by ENJOY.

**Parameters**

| Name    | Type  | Description                                     |
| ------- | ----- | ----------------------------------------------- |
| `sound` | Sound | A `Sound` instance returned from `ENJOY.Play()` |

**Example:**

```lua
local s = ENJOY.Play('https://github.com/localscripts/ENJOY/raw/refs/heads/main/Visuals/AudioENJOY/Audios/u-have-no-heart.mp3', { looped = true })
wait(5)
ENJOY.Destroy(s)  -- stops and deletes the sound
```

---

### `ENJOY.StopAll()`

Stops and destroys **all active sounds** created by ENJOY.

**Example:**

```lua
ENJOY.Play('https://github.com/localscripts/ENJOY/raw/refs/heads/main/Visuals/AudioENJOY/Audios/u-have-no-heart.mp3')
wait()
ENJOY.Play('https://github.com/localscripts/ENJOY/raw/refs/heads/main/Visuals/AudioENJOY/Audios/u-have-no-heart.mp3')
wait(1)
ENJOY.StopAll()  -- stops and cleans up both
```

---

## Summary

ENJOY is a simple way to load, cache, and play external sounds in Roblox executor environments.

**Main advantages:**

* Caches per-link for instant replay
* Minimal API (Play, Destroy, StopAll)
* Safe, organized local file structure
* Clean auto-removal of one-shot sounds
