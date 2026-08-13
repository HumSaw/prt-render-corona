# PRT Render — Corona (v0.28)

Batch camera rendering tool for **3ds Max 2020–2026** + **Corona Renderer**, written in MAXScript.

Renders multiple cameras in a queue into a single output folder, with per-camera settings, custom frame sizes, preview scaling, and Render Elements support.

## Files

| File | 3ds Max version |
|---|---|
| `Rubis_Pro_Camera_2020_v27.ms` | 2020 |
| `Rubis_Pro_Camera_2021_v27.ms` | 2021 |
| `Rubis_Pro_Camera_2022_v27.ms` | 2022 |
| `Rubis_Pro_Camera_2023_v27.ms` | 2023 |
| `Rubis_Pro_Camera_2024_v27.ms` | 2024 |
| `Rubis_Pro_Camera_2025_v27.ms` | 2025 |
| `Rubis_Pro_Camera_2026_v27.ms` | 2026 |

The script bodies are identical across versions; only the header targets differ.

## Installation

1. Pick the file matching your 3ds Max version.
2. In 3ds Max: **Scripting → Run Script** and select the file (or drag the file into the viewport).
3. The **PRT Render — Corona** window opens.

For permanent installation, place the file into `...\3ds Max XXXX\scripts\Startup\`.

## Usage

### 1. Camera list
- **REFRESH** — collects all scene cameras into the list.
- Select the cameras to render (Ctrl/Shift for multi-select).
- Double-click a camera to show it in the viewport.

### 2. Camera settings (optional, applied to selected cameras)
- **Focal** — focal length (mm).
- **Clipping + Near/Far** — manual clipping planes.
- **Copy Global Corona settings** — copies the global tone mapping (Corona color pipeline) into the camera and enables its override. If the native Corona UI button cannot be reached, the script copies the pipeline directly via camera properties — same result.

### 3. Frame size
- **Custom size** — custom Width/Height instead of scene settings.
- **Lock ratio** — height recalculates automatically when width changes (and vice versa).
- Aspect preset buttons (16:9, 4:3, ...) for quick proportions.
- **Preview scale** — reduced resolution for draft renders: 100%, 75%, 62%, 50%, 31%, 15%, 7%.

### 4. Output
- **Folder** — single folder for ALL cameras. File name = camera name.
- **Format** — output file format (PNG/JPG/EXR, ...).
- **Save to file** — when off, renders go to the frame buffer only.
- **Render Elements** — elements are saved as `Camera_ElementName`. Original element paths and flags in the scene are **restored automatically** after the batch.
- **Use Corona VFB only** — render into the Corona VFB only, no MAX Frame Buffer window.
- **Duplicate to MAX frame buffer** — duplicate the image into the standard Max buffer (works when the previous checkbox is off).

### 5. Animation (optional)
- **Animation + From/To** — renders a frame range for the selected camera instead of the current frame. The range is remembered per camera.

### 6. Render
- **RENDER** — starts the queue; progress bar and status show progress.
- **CANCEL/STOP** — stops the queue: the current render finishes (or abort it with Cancel in the progress dialog / **ESC**), and no further cameras start.
- **After render** — action on completion: nothing / close Max / shut down the PC.

## Notes

- **Stopping**: the STOP button cannot instantly interrupt a frame already rendering (Max renders synchronously) — use Cancel/ESC for that. STOP reliably halts the queue after the current frame.
- **Errors**: if one camera's render fails, the queue finishes gracefully, the RENDER button becomes available again, and details appear in the MAXScript Listener.
- **Renaming cameras**: per-camera animation settings are bound to the camera name — after renaming, press REFRESH and set the range again.
- **File names**: invalid characters in camera names are replaced automatically.

## Changelog — v0.28 (audit fixes)

- CANCEL/STOP now actually stops the camera queue.
- "Copy from Global" HWND search rewritten (the old loop always threw silently); recursive HWND-tree search by button text with a direct-property fallback.
- "Use Corona VFB only" / "Duplicate to MAX frame buffer" / "Preview scale" controls were dead; now wired into the render calls.
- Render Element filenames and flags are snapshotted before the batch and restored afterwards.
- Render queue wrapped in try/catch: an error can no longer leave the RENDER button permanently disabled.
- Viewport redraws are batched (one redraw per operation instead of per property per camera).
- Removed dead helpers, fixed double save in the animation handler, informational dialog uses messageBox instead of a Yes/No queryBox.

## Verification

Static test harness: `tests/check.mjs` (Node.js) — 43 checks covering bracket balance, dead code, forward references, safety patterns, and cross-version body identity.

```bash
node tests/check.mjs
```

Live 3ds Max behavior (HWND button search, RenderElementMgr method names) was verified against MAXScript documentation only — run a smoke test in your Max build: 2 cameras + STOP after the first; "Copy Global Corona settings"; Preview scale 50%.
