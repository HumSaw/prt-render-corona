# PRT Render — Corona

Batch camera rendering for **Autodesk 3ds Max 2020–2026** and **Corona Renderer**, implemented in MAXScript.

PRT Render turns a scene camera list into a controlled render queue: each camera can keep its own focal length, clipping, frame size, preview scale, animation range, and Corona tone-mapping override while all output lands in one predictable folder.

> Current release: **v0.28** · [Release notes](../../releases/tag/v0.28)

## What it does

The script collects cameras from the active scene, applies optional per-camera overrides, and renders them sequentially. It preserves scene-level Render Element paths and flags, restores them after the queue, and recovers cleanly when an individual camera fails.

## Features

- Multi-camera render queue with Ctrl/Shift selection
- Per-camera focal length, clipping planes, and animation range
- Custom frame size, locked aspect ratio, and preview scaling
- Corona color-pipeline copy with a direct-property fallback
- PNG, JPG, EXR, and other 3ds Max output formats
- Render Elements named per camera, with original settings restored afterwards
- Corona VFB-only and standard MAX frame-buffer modes
- Graceful stop after the current frame and error-safe UI recovery
- Optional close-3ds-Max or shut-down action after the queue

## Compatibility

| 3ds Max | Script |
|---|---|
| 2020 | [`Rubis_Pro_Camera_2020_v27.ms`](prt-render/Rubis_Pro_Camera_2020_v27.ms) |
| 2021 | [`Rubis_Pro_Camera_2021_v27.ms`](prt-render/Rubis_Pro_Camera_2021_v27.ms) |
| 2022 | [`Rubis_Pro_Camera_2022_v27.ms`](prt-render/Rubis_Pro_Camera_2022_v27.ms) |
| 2023 | [`Rubis_Pro_Camera_2023_v27.ms`](prt-render/Rubis_Pro_Camera_2023_v27.ms) |
| 2024 | [`Rubis_Pro_Camera_2024_v27.ms`](prt-render/Rubis_Pro_Camera_2024_v27.ms) |
| 2025 | [`Rubis_Pro_Camera_2025_v27.ms`](prt-render/Rubis_Pro_Camera_2025_v27.ms) |
| 2026 | [`Rubis_Pro_Camera_2026_v27.ms`](prt-render/Rubis_Pro_Camera_2026_v27.ms) |

The script bodies are identical; only the target-version header differs.

## Getting started

1. Download the `.ms` file that matches your 3ds Max version.
2. In 3ds Max, choose **Scripting → Run Script**, or drag the file into the viewport.
3. Select cameras, configure the output folder and optional overrides, then press **RENDER**.

For permanent installation, place the script in `3ds Max XXXX/scripts/Startup/`.

## Workflow

1. **REFRESH** collects scene cameras.
2. Select one or more cameras and apply optional camera or frame overrides.
3. Choose one output folder and format.
4. Enable Render Elements, VFB behavior, or animation ranges when needed.
5. Start the queue. **STOP** prevents the next camera from starting; use 3ds Max Cancel/ESC to abort a frame already rendering.

## Reliability work in v0.28

- Fixed queue cancellation and UI recovery after render errors
- Reworked Corona global-settings lookup with a property fallback
- Connected previously inactive VFB and preview-scale controls
- Snapshot and restore of Render Element filenames and enabled flags
- Batched viewport redraws and removed dead helpers

## Verification

The repository includes a Node.js static harness with **43 checks** for bracket balance, forward references, dead code, safety patterns, and cross-version body identity:

```bash
node prt-render/tests/check.mjs
```

Hardware-dependent Corona and 3ds Max behavior still needs a smoke test in the target host: render two cameras, stop after the first, copy global Corona settings, and verify 50% preview scaling.

## Project structure

```text
prt-render/
├── Rubis_Pro_Camera_2020_v27.ms … Rubis_Pro_Camera_2026_v27.ms
└── tests/
    ├── check.mjs       # static verification
    └── propagate.mjs   # keeps versioned bodies synchronized
```

Detailed control-by-control documentation is available in [`prt-render/README.md`](prt-render/README.md).
