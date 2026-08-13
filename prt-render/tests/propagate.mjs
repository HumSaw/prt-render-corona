/*
  Propagates the audited v0.28 body from the fixed 2020 file to all other
  year variants, preserving each variant's own year-specific header block.
  The pre-fix bodies were verified identical across years except 2024's
  broken camWnd[7] variant (defect C3), which this intentionally replaces.
*/
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const dir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const MARKER = "global PRT_Corona_Renderer";

const fixed2020 = readFileSync(path.join(dir, "Rubis_Pro_Camera_2020_v27.ms"), "utf8");
const bodyStart = fixed2020.indexOf(MARKER);
if (bodyStart < 0) throw new Error("marker not found in 2020 file");
const fixedBody = fixed2020.slice(bodyStart);

const changelog = `
    Changes in v0.28 (audit fixes):
    - CANCEL/STOP now actually stops the camera queue (sets stopRequested).
    - "Copy from Global" HWND search rewritten: windows.getChildHWND returns ONE
      window's property array, not a window list; the old code never reached the
      button. Now searches the HWND tree recursively by text, with a documented
      direct-property fallback (colorMappingPipeline copy).
    - "Use Corona VFB only" / "Duplicate to MAX frame buffer" / "Preview scale"
      controls were dead; they are now wired into the render() calls.
    - Render Element filenames and Active/Display flags are snapshotted before
      the batch and restored afterwards (scene setup is no longer mutated).
    - Render queue wrapped in try/catch: an error can no longer leave the
      RENDER button permanently disabled.
    - Viewport redraws are batched: one redraw per operation instead of a full
      redraw per property per camera.
    - Removed dead helpers (selectedOrActiveCamera with its forward-reference
      bug, getCameraClassName); fixed double saveAnimUIToCamera; informational
      Custom-aspect dialog uses messageBox instead of Yes/No queryBox.
`;

for (const year of [2021, 2022, 2023, 2024, 2025, 2026]) {
  const file = path.join(dir, `Rubis_Pro_Camera_${year}_v27.ms`);
  const src = readFileSync(file, "utf8");
  const idx = src.indexOf(MARKER);
  if (idx < 0) throw new Error(`marker not found in ${year}`);

  let header = src.slice(0, idx);
  header = header.replace(/v0\.27/, "v0.28");
  // Insert the v0.28 changelog right after the version line.
  header = header.replace(/(v0\.28\r?\n)/, `$1${changelog}`);
  // Fix the lying "height (930)" comment where present.
  header = header.replace(/height \(930\)/g, "height (925)");

  writeFileSync(file, header + fixedBody);
  console.log(`patched ${year}: header ${idx} chars + fixed body ${fixedBody.length} chars`);
}
