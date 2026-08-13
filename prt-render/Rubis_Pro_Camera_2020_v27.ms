/*
    PRT Run - Corona Edition
    3ds Max 2020
    Corona 11+ (works with the Corona version available for this 3ds Max release)
    v0.28

    Changes in v0.28 (audit fixes):
    - CANCEL/STOP now actually stops the camera queue (sets stopRequested).
    - "Copy from Global" HWND search rewritten: windows.getChildHWND returns ONE
      window's property array, not a window list; the old loop always threw and
      the click never happened. Now searches the HWND tree recursively by text,
      with a documented direct-property fallback (colorMappingPipeline copy).
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

    Changes (v0.27):
    - Only the Corona VFB is used by the batch render call (native 3ds Max RFW is disabled).
    - All camera renders go directly into ONE selected output folder.
    - Optional Render Elements saving, with automatic filenames in the same folder.
    - Fixed dialog height: createDialog now matches the rollout height (925), and the window is vertically resizable.
    - Output aspect ratio presets + custom ratio.
    - Optional "Lock aspect ratio" applies to all cameras because output resolution is global.
    - MacroScript included in this file: category "PRT Render".

    Compatibility notes for this build (3ds Max 2020):
        - No known API gaps for the functions used in this script; targets classic Win32-based Modify panel.
    All rollout controls, render() call signatures (vfb:/outputSize:/renderElements:/
    cancelled:/progressbar:) and maxOps.GetCurRenderElementMgr() used here are part of
    core MAXScript and are stable across 3ds Max 2020-2026, so no logic changes were
    needed for those parts. The one historically fragile piece is the native-UI click
    used by "Copy from Global" (clickCoronaCopyFromGlobalUI), which walks the Modify
    panel's HWND tree; this build searches by button text across all rollout children
    instead of a fixed child index, to survive UI layout differences between versions.
*/

global PRT_Corona_Renderer
try (destroyDialog PRT_Corona_Renderer) catch()

rollout PRT_Corona_Renderer "PRT Render - Corona" width:560 height:925
(
    -- Muted UI palette: navy, slate-blue and restrained violet.
    local cNavy = (color 55 72 96)
    local cSlate = (color 72 88 108)
    local cBlue = (color 78 96 118)
    local cViolet = (color 92 82 112)
    local cSoft = (color 82 92 104)

    groupBox gbCams "Cameras" pos:[10,10] width:540 height:175
    pickButton btnPick "Pick Camera" pos:[25,35] width:105 height:28 autoDisplay:false
    button btnDelete "Delete" pos:[140,35] width:80 height:28 color:cSoft
    button btnAdd "Add Selected" pos:[230,35] width:105 height:28 color:cBlue
    button btnAll "All" pos:[345,35] width:70 height:28 color:cSlate
    button btnClear "Clear" pos:[425,35] width:105 height:28 color:cSoft
    multiListBox lbCameras "" pos:[25,68] width:515 height:8 items:#()

    groupBox gbRender "Camera / output settings" pos:[10,195] width:265 height:565

    checkbox chkAnim "Animation (selected camera)" pos:[25,220] checked:false
    spinner spFrom "From:" pos:[100,217] width:75 range:[-100000,100000,0] type:#integer enabled:false
    spinner spTo "To:" pos:[190,217] width:75 range:[-100000,100000,100] type:#integer enabled:false

    checkbox chkSize "Set output size for all cameras" pos:[25,250] checked:true
    label lblW "Width:" pos:[40,280] width:50
    spinner spW "" pos:[95,277] width:100 range:[1,20000,1920] type:#integer
    label lblH "Height:" pos:[40,313] width:50
    spinner spH "" pos:[95,310] width:100 range:[1,20000,1080] type:#integer

    label lblAspect "Aspect ratio:" pos:[25,345] width:75
    dropdownList ddlAspect "" pos:[105,342] width:150 items:#(
        "Current","16 : 9","3 : 2","4 : 3","1 : 1","2 : 3","9 : 16","Custom"
    ) selection:1
    checkbox chkLockAspect "Lock ratio" pos:[25,375] checked:false
    button btnApplyFrame "Apply aspect + viewport frame" pos:[105,371] width:150 height:24 color:cSlate

    groupBox gbCamControls "Selected camera" pos:[20,405] width:245 height:245
    label lblFocal "Focal length, mm:" pos:[30,430] width:95
    spinner spFocal "" pos:[130,427] width:105 range:[1,5000,40] type:#float scale:0.1
    checkbox chkClip "Enable clipping" pos:[30,458] checked:false
    label lblNear "Near:" pos:[50,486] width:45
    spinner spNear "" pos:[95,483] width:75 range:[0,100000000,1] type:#float scale:0.1
    label lblFar "Far:" pos:[50,516] width:45
    spinner spFar "" pos:[95,513] width:75 range:[0,100000000,100000] type:#float scale:0.1
    button btnApplyCam "Apply / Refresh camera(s)" pos:[30,548] width:205 height:28 color:cBlue

    groupBox gbTM "Tone Mapping override" pos:[30,580] width:225 height:58
    checkbox chkTMOverride "Individual TM override" pos:[40,594] checked:false
    button btnTMCopy "Copy from Global" pos:[40,616] width:185 height:24 color:cViolet

    label lblCamInfo "Select a camera in the list to load its values." pos:[25,650] width:235 height:22
    label lblPreview "Preview scale:" pos:[25,677] width:85
    dropdownList ddlPreview "" pos:[110,674] width:140 items:#(
        "100% - full","75%","62%","50%","31%","15%","7%"
    ) selection:1
    label lblInfo "Output size/aspect are shared; animation is per camera." pos:[25,707] width:235 height:30

    button btnSceneSave "Save Scene" pos:[25,740] width:105 height:28 color:cSlate
    button btnSceneOpen "Open Output Folder" pos:[140,740] width:125 height:28 color:cSoft

    groupBox gbAfter "Action After" pos:[285,195] width:265 height:165
    radiobuttons rbPower labels:#("None","Power Off","Sleep Mode","Waiting mode") columns:1 default:1 pos:[305,220]
    checkbox chkAutoSave "Auto Save Scene before render" pos:[305,320] checked:true

    groupBox gbOutput "Save Image" pos:[285,370] width:265 height:150
    checkbox chkSave "Save Output" pos:[300,395] checked:true
    dropdownList ddlFormat "" pos:[420,392] width:105 items:#("PNG","JPG","TIF","EXR","BMP") selection:1
    label lblFolder "Folder:" pos:[300,430] width:45
    editText edtFolder "" pos:[345,427] width:165 text:""
    button btnFolder "..." pos:[515,427] width:25 height:20 color:cSoft
    checkbox chkElements "Save Render Elements" pos:[300,458] checked:false
    label lblElem "Elements use same folder and camera prefix." pos:[300,484] width:235 height:25

    groupBox gbRenderBtn "RENDER" pos:[10,775] width:540 height:135
    checkbox chkVFB "Use Corona VFB only" pos:[25,800] checked:true
    checkbox chkDuplicate "Duplicate to MAX frame buffer" pos:[25,824] checked:false
    progressBar pbProgress "" pos:[25,850] width:510 height:12
    label lblStatus "Ready." pos:[25,866] width:510 height:18
    button btnRender "RENDER" pos:[25,885] width:245 height:28 color:cNavy
    button btnStop "CANCEL / STOP" pos:[295,885] width:245 height:28 color:cViolet

    local stopRequested = false
    local updatingAspect = false
    local savedAspect = 16.0/9.0

    -- Per-camera animation settings.
    local camAnimNames = #()
    local camAnimEnabled = #()
    local camAnimFrom = #()
    local camAnimTo = #()

    fn findAnimIndex cam =
    (
        if cam == undefined then return 0
        for i = 1 to camAnimNames.count do
            if camAnimNames[i] == cam.name do return i
        0
    )

    fn ensureAnimEntry cam =
    (
        if cam == undefined then return 0
        local idx = findAnimIndex cam
        if idx == 0 then
        (
            append camAnimNames cam.name
            append camAnimEnabled false
            append camAnimFrom animationRange.start
            append camAnimTo animationRange.end
            idx = camAnimNames.count
        )
        idx
    )

    fn saveAnimUIToCamera cam =
    (
        if cam == undefined then return false
        local idx = ensureAnimEntry cam
        if idx == 0 then return false
        camAnimEnabled[idx] = chkAnim.checked
        camAnimFrom[idx] = spFrom.value
        camAnimTo[idx] = spTo.value
        true
    )

    fn loadAnimUIFromCamera cam =
    (
        if cam == undefined then
        (
            chkAnim.checked = false
            spFrom.value = animationRange.start
            spTo.value = animationRange.end
            spFrom.enabled = false
            spTo.enabled = false
            return false
        )

        local idx = ensureAnimEntry cam
        chkAnim.checked = camAnimEnabled[idx]
        spFrom.value = camAnimFrom[idx]
        spTo.value = camAnimTo[idx]
        spFrom.enabled = chkAnim.checked
        spTo.enabled = chkAnim.checked
        true
    )

    fn getAnimForCamera cam =
    (
        local idx = ensureAnimEntry cam
        if idx == 0 then #(false, animationRange.start, animationRange.start)
        else #(camAnimEnabled[idx], camAnimFrom[idx], camAnimTo[idx])
    )

    fn validateCameraAnimationRanges =
    (
        for i = 1 to camAnimNames.count do
        (
            if camAnimEnabled[i] and camAnimTo[i] < camAnimFrom[i] then
            (
                messageBox ("Camera '" + camAnimNames[i] + "' has invalid animation range: " +
                 (camAnimFrom[i] as string) + " to " + (camAnimTo[i] as string)) title:"PRT Render - Corona"
                return false
            )
        )
        true
    )

    fn isCoronaRenderer =
    (
        local r = renderers.current
        if r == undefined then return false
        local s = (classOf r as string)
        (findString (toLower s) "corona") != undefined
    )

    fn addCamera c =
    (
        if c != undefined and isValidNode c and isKindOf c Camera then
        (
            local exists = false
            for n in lbCameras.items do if n == c.name do exists = true
            if not exists do
            (
                lbCameras.items = append lbCameras.items c.name
                ensureAnimEntry c
            )
        )
    )

    fn addSelectedCameras =
    (
        for o in selection do if isValidNode o and isKindOf o Camera do addCamera o
    )

    fn addAllCameras =
    (
        for c in cameras do if isValidNode c do addCamera c
    )

    fn removeSelectedCameras =
    (
        local sel = lbCameras.selection as array
        if sel.count > 0 do
        (
            for i = sel.count to 1 by -1 do
            (
                local camName = lbCameras.items[sel[i]]
                deleteItem lbCameras.items sel[i]
                for j = camAnimNames.count to 1 by -1 do
                (
                    if camAnimNames[j] == camName then
                    (
                        deleteItem camAnimNames j
                        deleteItem camAnimEnabled j
                        deleteItem camAnimFrom j
                        deleteItem camAnimTo j
                    )
                )
            )
        )
    )

    fn clearCameras =
    (
        lbCameras.items = #()
        camAnimNames = #()
        camAnimEnabled = #()
        camAnimFrom = #()
        camAnimTo = #()
    )

    fn getCameraByName n =
    (
        for c in cameras do if c.name == n do return c
        undefined
    )

    fn chooseOutputFolder =
    (
        local p = getSavePath caption:"Choose ONE render output folder"
        if p != undefined do edtFolder.text = p
    )

    fn getExt =
    (
        case ddlFormat.selection of
        (
            1: ".png"
            2: ".jpg"
            3: ".tif"
            4: ".exr"
            5: ".bmp"
            default: ".png"
        )
    )

    fn safeName s =
    (
        local result = s
        for ch in #("\\","/",":","*","?","\"","<",">","|") do result = substituteString result ch "_"
        result
    )

    fn ensureFolder p =
    (
        if p == undefined or p == "" then false
        else if doesDirectoryExist p then true
        else
        (
            makeDir p all:true
            doesDirectoryExist p
        )
    )

    fn saveCurrentScene =
    (
        if maxFilePath != "" and maxFileName != "" then
        (
            try (saveMaxFile (maxFilePath + maxFileName) quiet:true; true) catch false
        )
        else
        (
            local f = getSaveFileName caption:"Save 3ds Max scene" types:"3ds Max Scene (*.max)|*.max|"
            if f != undefined then
                try (saveMaxFile f quiet:true; true) catch false
            else false
        )
    )

    fn aspectFromSelection =
    (
        case ddlAspect.selection of
        (
            2: 16.0/9.0
            3: 3.0/2.0
            4: 4.0/3.0
            5: 1.0
            6: 2.0/3.0
            7: 9.0/16.0
            8: (if spH.value != 0 then (spW.value as float / spH.value as float) else savedAspect)
            default: (if renderHeight != 0 then (renderWidth as float / renderHeight as float) else savedAspect)
        )
    )

    fn applyAspectFromWidth =
    (
        if updatingAspect or not chkLockAspect.checked then return()
        local a = aspectFromSelection()
        if a > 0 then
        (
            updatingAspect = true
            spH.value = amax 1 ((spW.value as float / a) as integer)
            updatingAspect = false
        )
    )

    fn applyAspectFromHeight =
    (
        if updatingAspect or not chkLockAspect.checked then return()
        local a = aspectFromSelection()
        if a > 0 then
        (
            updatingAspect = true
            spW.value = amax 1 ((spH.value as float * a) as integer)
            updatingAspect = false
        )
    )

    fn applySelectedAspect =
    (
        local a = aspectFromSelection()
        if a > 0 then
        (
            savedAspect = a
            updatingAspect = true
            spH.value = amax 1 ((spW.value as float / a) as integer)
            updatingAspect = false

            renderWidth = spW.value
            renderHeight = spH.value
            renderPixelAspect = 1.0
            displaySafeFrames = true
            forceCompleteRedraw()
            try (viewport.redraw()) catch()
        )
    )

    fn elementExtension =
    (
        -- Render Elements must use the same format as the Beauty output.
        getExt()
    )

    fn configureElementOutputs baseFolder cameraBase =
    (
        local mgr = maxOps.GetCurRenderElementMgr()
        if mgr == undefined then return()

        local count = mgr.NumRenderElements()
        for i = 0 to count - 1 do
        (
            local el = mgr.GetRenderElement i
            local elName = "Element"
            try elName = el.elementName catch()
            local fileName = baseFolder + "\\" + cameraBase + "_" + safeName elName + (elementExtension())
            try mgr.SetRenderElementFilename i fileName catch()
        )
        try mgr.SetElementsActive true catch()
        try mgr.SetDisplayElements false catch()
    )

    /*
        v0.28: configureElementOutputs permanently rewrote the scene's Render
        Element filenames and Active/Display flags. These two functions
        snapshot the state before the batch and restore it afterwards, so a
        batch render no longer mutates the user's scene setup.
    */
    fn snapshotElementOutputs =
    (
        local mgr = maxOps.GetCurRenderElementMgr()
        if mgr == undefined then return undefined

        local names = #()
        local count = mgr.NumRenderElements()
        for i = 0 to count - 1 do
        (
            local fname = ""
            try (fname = mgr.GetRenderElementFilename i) catch()
            append names fname
        )

        local active = true
        local display = true
        try (active = mgr.GetElementsActive()) catch()
        try (display = mgr.GetDisplayElements()) catch()
        #(names, active, display)
    )

    fn restoreElementOutputs snap =
    (
        if snap == undefined then return()
        local mgr = maxOps.GetCurRenderElementMgr()
        if mgr == undefined then return()

        local names = snap[1]
        local count = mgr.NumRenderElements()
        for i = 0 to count - 1 do
            if i + 1 <= names.count do
                try (mgr.SetRenderElementFilename i names[i + 1]) catch()

        try (mgr.SetElementsActive snap[2]) catch()
        try (mgr.SetDisplayElements snap[3]) catch()
    )

    fn setPropSafe obj prop value =
    (
        try
        (
            if isProperty obj prop then
            (
                setProperty obj prop value
                true
            )
            else false
        )
        catch false
    )

    fn getPropSafe obj prop defaultValue:undefined =
    (
        try
        (
            if isProperty obj prop then getProperty obj prop else defaultValue
        )
        catch defaultValue
    )

    fn findFirstProperty cam candidates =
    (
        for p in candidates do
        (
            try (if isProperty cam p then return p) catch()
        )
        undefined
    )

    fn getCameraSensorWidth cam =
    (
        local p = findFirstProperty cam #(#film_width, #filmWidth, #sensor_width, #sensorWidth, #film_gate_width, #filmGateWidth)
        if p != undefined then
        (
            local v = getPropSafe cam p
            if v != undefined and v > 0 then return v
        )
        36.0
    )

    fn focalToFov cam focal =
    (
        local sw = getCameraSensorWidth cam
        2.0 * atan (sw / (2.0 * focal))
    )

    fn fovToFocal cam fov =
    (
        local sw = getCameraSensorWidth cam
        sw / (2.0 * tan (fov / 2.0))
    )

    -- v0.28: property setters accept redraw:false so batch operations
    -- (many cameras / many properties) trigger ONE viewport redraw instead
    -- of a full redraw per property per camera.
    fn setCameraFocal cam value redraw:true =
    (
        local ok = false
        local p = findFirstProperty cam #(#focal_length_mm, #focalLength, #focal_length, #lens)
        if p != undefined and setPropSafe cam p value then ok = true
        else
        (
            local fovP = findFirstProperty cam #(#fov, #fieldOfView, #field_of_view)
            if fovP != undefined and setPropSafe cam fovP (focalToFov cam value) then ok = true
        )

        if ok and redraw do
        (
            try (updateCameraUI cam) catch()
            forceCompleteRedraw()
            try (viewport.redraw()) catch()
        )
        ok
    )

    fn getCameraFocal cam =
    (
        local p = findFirstProperty cam #(#focal_length_mm, #focalLength, #focal_length, #lens)
        if p != undefined then
        (
            local v = getPropSafe cam p
            if v != undefined then return v
        )
        local fovP = findFirstProperty cam #(#fov, #fieldOfView, #field_of_view)
        if fovP != undefined then
        (
            local fov = getPropSafe cam fovP
            if fov != undefined then return fovToFocal cam fov
        )
        undefined
    )

    fn setCameraClipEnabled cam state redraw:true =
    (
        local ok = false
        for q in #(#clipManually, #clip_on, #clipEnabled, #clippingEnabled) do
            if isProperty cam q then ok = (setPropSafe cam q state) or ok
        if redraw do
        (
            try (updateCameraUI cam) catch()
            forceCompleteRedraw()
            try (viewport.redraw()) catch()
        )
        ok
    )

    fn setCameraNearClip cam value redraw:true =
    (
        local ok = false
        for q in #(#nearclip, #clip_near, #near_clip, #clipNear, #clippingNear) do
            if isProperty cam q then ok = (setPropSafe cam q value) or ok
        if redraw do
        (
            try (updateCameraUI cam) catch()
            forceCompleteRedraw()
            try (viewport.redraw()) catch()
        )
        ok
    )

    fn setCameraFarClip cam value redraw:true =
    (
        local ok = false
        for q in #(#farclip, #clip_far, #far_clip, #clipFar, #clippingFar) do
            if isProperty cam q then ok = (setPropSafe cam q value) or ok
        if redraw do
        (
            try (updateCameraUI cam) catch()
            forceCompleteRedraw()
            try (viewport.redraw()) catch()
        )
        ok
    )

    fn getCameraClipEnabled cam =
    (
        local p = findFirstProperty cam #(#clipManually, #clip_on, #clipEnabled, #clippingEnabled)
        if p != undefined then getPropSafe cam p defaultValue:false else false
    )

    fn getCameraNearClip cam =
    (
        local p = findFirstProperty cam #(#nearclip, #clip_near, #near_clip, #clipNear, #clippingNear)
        if p != undefined then getPropSafe cam p else undefined
    )

    fn getCameraFarClip cam =
    (
        local p = findFirstProperty cam #(#farclip, #clip_far, #far_clip, #clipFar, #clippingFar)
        if p != undefined then getPropSafe cam p else undefined
    )

    -- Corona 8+ / Corona 12: local camera tone mapping is stored in
    -- the Corona Camera property "colorMappingPipeline".
    -- Corona per-camera Tone Mapping.
    -- Supported Corona workflow:
    -- cam.colorMappingPipeline = renderers.current.colormap_pipeline
    -- cam.colorMappingOverride = true
    fn getCameraTMPipeline cam =
    (
        if cam == undefined then undefined
        else if isProperty cam #colorMappingPipeline then
            try (getProperty cam "colorMappingPipeline") catch undefined
        else undefined
    )

    fn setCameraTMPipeline cam pipe =
    (
        if cam == undefined then return false
        if not isProperty cam #colorMappingPipeline then return false
        try
        (
            setProperty cam "colorMappingPipeline" pipe
            true
        )
        catch false
    )

    fn getCameraTMOverride cam =
    (
        if cam == undefined then false
        else
        (
            local p = getCameraTMPipeline cam
            if isProperty cam #colorMappingOverride then
            (
                try ((getProperty cam "colorMappingOverride") or (p != undefined))
                catch (p != undefined)
            )
            else (p != undefined)
        )
    )

    fn getGlobalTMPipeline =
    (
        try (renderers.current.colorMap_pipeline) catch undefined
    )

    fn showCameraInViewport cam =
    (
        if cam == undefined then return false
        try
        (
            select cam
            viewport.setCamera cam
            completeRedraw()
            try (viewport.redraw()) catch()
            true
        )
        catch
        (
            try (select cam; completeRedraw(); true) catch false
        )
    )

    fn findChildByText parentHwnd wantedText depth:0 =
    (
        /*
            Recursive HWND-tree search by window text.
            Depth-limited so a pathological window tree cannot hang the UI.
        */
        if depth > 8 then return undefined

        local result = undefined
        local children = undefined

        try (children = windows.getChildrenHWND parentHwnd) catch()
        if children == undefined then return undefined

        local wanted = toLower wantedText

        for w in children while result == undefined do
        (
            if classOf w == Array and w.count >= 5 then
            (
                local txt = ""
                try (txt = w[5] as string) catch()

                if (toLower txt) == wanted then
                    result = w
                else
                    result = findChildByText w[1] wantedText depth:(depth + 1)
            )
        )
        result
    )

    fn clickCoronaCopyFromGlobalUI cam =
    (
        if cam == undefined then return false
        if classOf cam != CoronaCam then return false

        try
        (
            /*
                This deliberately uses the REAL Corona Camera control.
                Chaos documents "Copy from global" as the operation that creates
                the camera-local tone mapping stack. Direct assignment of the
                MaxObject is not used here.
            */
            max modify mode
            select cam
            completeRedraw()

            /*
                NOTE (version portability): earlier revisions assumed the Corona
                Camera modifier rollout was always the 7th child window
                (camWnd[7]). That index is NOT guaranteed to be stable across
                3ds Max versions/UI builds (2020-2026).

                FIX (v0.28): windows.getChildHWND returns a FLAT property array
                describing ONE window (#(hwnd, parent, class, ..., text, ...)),
                not a list of windows. The previous `for w in camWnd` iterated
                over scalar properties and always threw (silently swallowed by
                the outer catch), so the button was never found. We now search
                the command panel's HWND tree recursively by button text,
                starting from the Modify panel root.
            */
            local btn = undefined
            local panelRoot = undefined
            try (panelRoot = windows.getChildHWND #max "Command Panel") catch()

            local searchRoots = #()
            if panelRoot != undefined do append searchRoots panelRoot[1]
            local camWnd = windows.getChildHWND #max cam.name
            if camWnd != undefined do append searchRoots camWnd[1]

            for root in searchRoots while btn == undefined do
            (
                btn = findChildByText root "Copy from global"
                -- Some Corona builds capitalize Global.
                if btn == undefined do btn = findChildByText root "Copy from Global"
            )

            if btn == undefined then
                return false

            windows.sendMessage btn[1] 0x201 0 0
            windows.sendMessage btn[1] 0x202 0 0
            windows.processPostedMessages()

            completeRedraw()
            true
        )
        catch
        (
            false
        )
    )

    fn copyGlobalTMToCamera cam =
    (
        if cam == undefined then return false

        if classOf cam != CoronaCam then
        (
            messageBox "Select a Corona Camera first." title:"PRT Render - Corona"
            return false
        )

        -- IMPORTANT: prefer Corona's actual Camera UI command.
        if clickCoronaCopyFromGlobalUI cam then
        (
            try (cam.colorMappingOverride = true) catch()
            showCameraInViewport cam
            true
        )
        else
        (
            /*
                FALLBACK (v0.28): if the native UI button cannot be reached
                (Qt/Win32 layout differences, panel not open, localized UI),
                assign the documented Corona properties directly:
                    cam.colorMappingPipeline = renderers.current.colormap_pipeline
                    cam.colorMappingOverride = true
                This is the workflow Chaos documents for per-camera tone mapping.
            */
            local ok = false
            try
            (
                local pipe = getGlobalTMPipeline()
                if pipe != undefined and (setCameraTMPipeline cam pipe) then
                (
                    cam.colorMappingOverride = true
                    showCameraInViewport cam
                    ok = true
                )
            )
            catch (ok = false)
            ok
        )
    )

    fn setCameraTMOverride cam state =
    (
        if cam == undefined then return false
        if classOf cam != CoronaCam then return false

        if state then
        (
            -- If there is no local stack, Copy from Global creates it.
            if cam.colorMappingPipeline == undefined then
                copyGlobalTMToCamera cam
            else
            (
                cam.colorMappingOverride = true
                true
            )
        )
        else
        (
            try
            (
                cam.colorMappingOverride = false
                -- Corona's supported way to remove the camera-local stack.
                setProperty cam "colorMappingPipeline" undefined

                try (completeRedraw()) catch()
                try (viewport.redraw()) catch()
                true
            )
            catch
            (
                false
            )
        )
    )

    /*
        v0.28: removed dead helper `selectedOrActiveCamera` - it was never
        called and contained a forward reference to `selectedCameraNodes`,
        which MAXScript resolves to an (undefined) global at parse time and
        would therefore throw at runtime if it were ever invoked.
    */
    fn selectedCameraNodes =
    (
        local result = #()
        local rawSel = undefined
        try rawSel = lbCameras.selection catch rawSel = undefined
        if rawSel == undefined then return result

        local sel = #()
        case (classOf rawSel) of
        (
            Integer: (if rawSel > 0 do append sel rawSel)
            Array: (for x in rawSel where (classOf x == Integer and x > 0) do append sel x)
            BitArray: (for x in rawSel where (classOf x == Integer and x > 0) do append sel x)
        )

        for idx in sel do
        (
            if idx >= 1 and idx <= lbCameras.items.count then
            (
                local c = getCameraByName lbCameras.items[idx]
                if c != undefined do append result c
            )
        )
        result
    )

    fn applyCameraControls =
    (
        local cams = selectedCameraNodes()
        if cams.count == 0 then
        (
            messageBox "Select one or more cameras in the list first." title:"PRT Render"
            return false
        )

        local applied = 0
        for c in cams do
        (
            -- redraw:false = one viewport redraw for the whole batch (below)
            local okF = setCameraFocal c spFocal.value redraw:false
            local okC = setCameraClipEnabled c chkClip.checked redraw:false
            local okN = setCameraNearClip c spNear.value redraw:false
            local okFar = setCameraFarClip c spFar.value redraw:false
            if okF or okC or okN or okFar do
            (
                applied += 1
                try (updateCameraUI c) catch()
            )
        )

        forceCompleteRedraw()
        try (viewport.redraw()) catch()
        lblCamInfo.text = ("Applied: " + (applied as string) + "/" + (cams.count as string) + " camera(s)")
        true
    )

    fn applyViewportFrame =
    (
        if chkSize.checked then
        (
            renderWidth = spW.value
            renderHeight = spH.value
        )

        displaySafeFrames = true
        forceCompleteRedraw()
    )

    /*
        v0.28: "Preview scale" dropdown is now functional. It scales the
        effective render resolution for quick draft renders.
    */
    fn previewScaleFactor =
    (
        case ddlPreview.selection of
        (
            1: 1.0
            2: 0.75
            3: 0.62
            4: 0.5
            5: 0.31
            6: 0.15
            7: 0.07
            default: 1.0
        )
    )

    fn renderOneCamera cam =
    (
        if stopRequested then return false

        local folder = edtFolder.text
        if folder == "" then folder = getDir #renderoutput
        edtFolder.text = folder

        if not ensureFolder folder then return false

        local cameraBase = safeName cam.name
        local outputFile = folder + "\\" + cameraBase + getExt()
        local oldTime = sliderTime
        local ok = true
        local wasCancelled = false

        /*
            v0.28: previously-dead UI controls are now wired up:
            - "Use Corona VFB only"  -> suppresses the MAX frame buffer
            - "Duplicate to MAX frame buffer" -> vfb:true on render()
            - "Preview scale" -> scales the effective output resolution
        */
        local useMaxVfb = chkDuplicate.checked and not chkVFB.checked
        local scale = previewScaleFactor()
        local baseW = if chkSize.checked then spW.value else renderWidth
        local baseH = if chkSize.checked then spH.value else renderHeight
        local effW = amax 1 ((baseW * scale) as integer)
        local effH = amax 1 ((baseH * scale) as integer)
        local useOutputSize = chkSize.checked or scale != 1.0

        if chkElements.checked do configureElementOutputs folder cameraBase

        if chkSize.checked do applyViewportFrame()

        try
        (
            /*
                render() is synchronous. While it is inside Corona, the rollout
                cannot receive button events. The previous STOP flag therefore
                could not cancel the active render.

                v0.5 uses MAX's native cancellation state:
                - Cancel in the render progress dialog, or
                - press ESC
                sets wasCancelled=true.

                Once render() returns, the camera queue is stopped immediately.
            */
            local animData = getAnimForCamera cam
            local camAnimOn = animData[1]
            local camFrom = animData[2]
            local camTo = animData[3]

            if camAnimOn then
            (
                local fr = interval camFrom camTo
                if chkSave.checked then
                (
                    if useOutputSize then
                        render camera:cam framerange:fr outputfile:outputFile outputSize:[effW,effH] vfb:useMaxVfb renderElements:chkElements.checked progressbar:true cancelled:&wasCancelled
                    else
                        render camera:cam framerange:fr outputfile:outputFile vfb:useMaxVfb renderElements:chkElements.checked progressbar:true cancelled:&wasCancelled
                )
                else
                (
                    if useOutputSize then
                        render camera:cam framerange:fr outputSize:[effW,effH] vfb:useMaxVfb renderElements:chkElements.checked progressbar:true cancelled:&wasCancelled
                    else
                        render camera:cam framerange:fr vfb:useMaxVfb renderElements:chkElements.checked progressbar:true cancelled:&wasCancelled
                )
            )
            else
            (
                if chkSave.checked then
                (
                    if useOutputSize then
                        render camera:cam frame:oldTime outputfile:outputFile outputSize:[effW,effH] vfb:useMaxVfb renderElements:chkElements.checked progressbar:true cancelled:&wasCancelled
                    else
                        render camera:cam frame:oldTime outputfile:outputFile vfb:useMaxVfb renderElements:chkElements.checked progressbar:true cancelled:&wasCancelled
                )
                else
                (
                    if useOutputSize then
                        render camera:cam frame:oldTime outputSize:[effW,effH] vfb:useMaxVfb renderElements:chkElements.checked progressbar:true cancelled:&wasCancelled
                    else
                        render camera:cam frame:oldTime vfb:useMaxVfb renderElements:chkElements.checked progressbar:true cancelled:&wasCancelled
                )
            )
        )
        catch
        (
            ok = false
            format "PRT Render: render failed for %\n" cam.name
        )

        sliderTime = oldTime

        if wasCancelled then
        (
            stopRequested = true
            ok = false
            lblStatus.text = ("Render CANCELLED: " + cam.name)
        )

        ok
    )

    fn performAfterAction =
    (
        case rbPower.state of
        (
            1: ()
            2: shellLaunch "shutdown.exe" "/s /t 60"
            3: shellLaunch "rundll32.exe" "powrprof.dll,SetSuspendState 0,1,0"
            4: messageBox "Rendering completed." title:"PRT Render"
        )
    )

    fn openOutputFolder =
    (
        local p = edtFolder.text
        if p != "" and doesDirectoryExist p then shellLaunch "explorer.exe" p
        else messageBox "Output folder does not exist yet." title:"PRT Render"
    )

    fn renderAll =
    (
        if not isCoronaRenderer() then
        (
            messageBox "The current production renderer does not appear to be Corona Renderer." title:"PRT Render"
            return false
        )

        if lbCameras.items.count == 0 then
        (
            messageBox "Add at least one camera to the list." title:"PRT Render"
            return false
        )

        if not validateCameraAnimationRanges() then return false

        if chkAnim.checked and spTo.value < spFrom.value then
        (
            messageBox "Animation end frame must be greater than or equal to start frame." title:"PRT Render"
            return false
        )

        local folder = edtFolder.text
        if folder == "" then
        (
            folder = getDir #renderoutput
            edtFolder.text = folder
        )

        if not ensureFolder folder then
        (
            messageBox ("Cannot create output folder:\n" + folder) title:"PRT Render"
            return false
        )

        if chkSize.checked then
        (
            renderWidth = spW.value
            renderHeight = spH.value
        )

        if chkAutoSave.checked then
        (
            lblStatus.text = "Saving scene..."
            if not saveCurrentScene() do messageBox "Scene was not saved. Rendering will continue." title:"PRT Render"
        )

        stopRequested = false
        btnRender.enabled = false
        btnStop.enabled = true

        local total = lbCameras.items.count
        local completed = 0

        /*
            v0.28:
            - Element output filenames/flags are snapshotted and restored, so
              batch rendering no longer permanently rewrites the scene setup.
            - The queue loop is wrapped in try/catch: an unexpected error can
              no longer leave the RENDER button permanently disabled.
        */
        local elemSnap = if chkElements.checked then snapshotElementOutputs() else undefined
        local queueError = false

        try
        (
            for i = 1 to total while not stopRequested do
            (
                local cam = getCameraByName lbCameras.items[i]
                if cam != undefined then
                (
                    lblStatus.text = ("Rendering " + (i as string) + "/" + (total as string) + ": " + cam.name)
                    pbProgress.value = ((i - 1) * 100.0 / total) as integer
                    if renderOneCamera cam then completed += 1
                )
            )
        )
        catch
        (
            queueError = true
            format "PRT Render: queue aborted by error: %\n" (getCurrentException())
        )

        restoreElementOutputs elemSnap

        pbProgress.value = 100
        btnRender.enabled = true
        btnStop.enabled = false

        if queueError then
            lblStatus.text = ("Render stopped by an error. Completed: " + (completed as string) + "/" + (total as string) + ". See MAXScript Listener.")
        else if stopRequested then
            lblStatus.text = ("Render cancelled. Completed: " + (completed as string) + "/" + (total as string))
        else
        (
            lblStatus.text = ("Finished. Completed: " + (completed as string) + "/" + (total as string))
            performAfterAction()
        )
    )

    fn loadCameraControls cam =
    (
        if cam == undefined then return()

        local f = getCameraFocal cam
        if f != undefined do spFocal.value = f

        chkClip.checked = getCameraClipEnabled cam

        local n = getCameraNearClip cam
        if n != undefined do spNear.value = n

        local farv = getCameraFarClip cam
        if farv != undefined do spFar.value = farv

        chkTMOverride.checked = getCameraTMOverride cam

        local fOk = (f != undefined)
        local nOk = (n != undefined)
        local farOk = (farv != undefined)

        lblCamInfo.text = ("Focal " + (if fOk then "OK" else "N/A") +
                           " | Clip " + (if nOk and farOk then "OK" else "N/A") +
                           " | TM " + (if isProperty cam #colorMappingPipeline then "OK" else "N/A"))
    )



    on PRT_Corona_Renderer open do
    (
        edtFolder.text = getDir #renderoutput
        spFrom.value = animationRange.start
        spTo.value = animationRange.end
        spW.value = renderWidth
        spH.value = renderHeight
        if renderHeight != 0 then savedAspect = renderWidth as float / renderHeight as float
        displaySafeFrames = true
        forceCompleteRedraw()
    )

    on btnPick picked obj do
    (
        if obj != undefined and isValidNode obj and isKindOf obj Camera then addCamera obj
    )

    on btnDelete pressed do removeSelectedCameras()
    on btnAdd pressed do addSelectedCameras()
    on btnAll pressed do addAllCameras()
    on btnClear pressed do clearCameras()
    on btnFolder pressed do chooseOutputFolder()
    on btnSceneOpen pressed do openOutputFolder()

    on btnSceneSave pressed do
    (
        if not saveCurrentScene() then messageBox "Scene was not saved." title:"PRT Render"
    )

    on chkAnim changed state do
    (
        local cams = selectedCameraNodes()
        if cams.count == 0 then
        (
            chkAnim.checked = false
            spFrom.enabled = false
            spTo.enabled = false
            lblCamInfo.text = "Select a camera first."
        )
        else
        (
            spFrom.enabled = state
            spTo.enabled = state
            if spTo.value < spFrom.value then spTo.value = spFrom.value
            saveAnimUIToCamera cams[1]
            lblCamInfo.text = ("Animation settings: " + cams[1].name)
        )
    )

    on spFrom changed v do
    (
        local cams = selectedCameraNodes()
        if cams.count > 0 then
        (
            if spTo.value < v then spTo.value = v
            saveAnimUIToCamera cams[1]
        )
    )

    on spTo changed v do
    (
        local cams = selectedCameraNodes()
        if cams.count > 0 then
        (
            if v < spFrom.value then spFrom.value = v
            saveAnimUIToCamera cams[1]
        )
    )

    on chkSize changed state do
    (
        spW.enabled = state
        spH.enabled = state
        if state then
        (
            spW.value = renderWidth
            spH.value = renderHeight
        )
    )

    on ddlAspect selected i do
    (
        if i == 8 then
            -- v0.28: informational message, not a Yes/No question (was queryBox).
            messageBox "Custom aspect uses current Width / Height. Lock ratio only controls automatic W/H coupling." title:"PRT Render"
        else
        (
            applySelectedAspect()
            if chkSize.checked then
            (
                renderWidth = spW.value
                renderHeight = spH.value
                renderPixelAspect = 1.0
                displaySafeFrames = true
                forceCompleteRedraw()
                try (viewport.redraw()) catch()
            )
        )
    )

    on chkLockAspect changed state do
    (
        if state then
        (
            if ddlAspect.selection == 1 then
            (
                if spH.value != 0 then savedAspect = spW.value as float / spH.value as float
            )
            else applySelectedAspect()
        )
    )


    on btnStop pressed do
    (
        /*
            This button cannot interrupt a synchronous render() call because
            3ds Max is executing the render on its main thread. The ACTIVE
            frame is cancelled with MAX/Corona's render progress Cancel button
            or ESC (detected via cancelled:&wasCancelled).

            However, this button CAN and now DOES stop the camera QUEUE:
            stopRequested halts the batch loop before the next camera starts.
        */
        stopRequested = true
        lblStatus.text = "Stop requested: queue halts after the current render. Use Cancel/ESC to abort the active frame."
    )

    on lbCameras selected i do
    (
        local cams = selectedCameraNodes()
        if cams.count > 0 then
        (
            local c = cams[1]
            try (select c) catch()
            try (viewport.setCamera c) catch()
            loadCameraControls c
            loadAnimUIFromCamera c
            forceCompleteRedraw()
            try (viewport.redraw()) catch()
        )
    )

    on btnApplyCam pressed do applyCameraControls()

    on btnApplyFrame pressed do
    (
        applySelectedAspect()
        applyViewportFrame()
    )

    on spW changed v do
    (
        applyAspectFromWidth()
        if chkSize.checked then
        (
            renderWidth = spW.value
            renderHeight = spH.value
            displaySafeFrames = true
            forceCompleteRedraw()
        )
    )

    on spH changed v do
    (
        applyAspectFromHeight()
        if chkSize.checked then
        (
            renderWidth = spW.value
            renderHeight = spH.value
            displaySafeFrames = true
            forceCompleteRedraw()
        )
    )


    on spFocal changed v do
    (
        local cams = selectedCameraNodes()
        for c in cams do setCameraFocal c v redraw:false
        if cams.count > 0 then
        (
            try (select cams[1]) catch()
            try (viewport.setCamera cams[1]) catch()
            forceCompleteRedraw()
            try (viewport.redraw()) catch()
        )
    )

    on chkClip changed state do
    (
        local cams = selectedCameraNodes()
        for c in cams do setCameraClipEnabled c state redraw:false
        if cams.count > 0 do
        (
            forceCompleteRedraw()
            try (viewport.redraw()) catch()
        )
        if state then
            lblCamInfo.text = "Clipping ON - Near/Far are live."
        else
            lblCamInfo.text = "Clipping OFF - automatic camera clipping."
    )

    on spNear changed v do
    (
        if chkClip.checked then
        (
            local cams = selectedCameraNodes()
            for c in cams do setCameraNearClip c v redraw:false
            try (viewport.redraw()) catch()
        )
    )

    on spFar changed v do
    (
        if chkClip.checked then
        (
            local cams = selectedCameraNodes()
            for c in cams do setCameraFarClip c v redraw:false
            try (viewport.redraw()) catch()
        )
    )

    on chkTMOverride changed state do
    (
        local cams = selectedCameraNodes()
        if cams.count == 0 then
        (
            chkTMOverride.checked = false
            lblCamInfo.text = "Select a camera first."
        )
        else
        (
            local success = 0
            for c in cams do
            (
                if setCameraTMOverride c state do success += 1
            )

            if state then
                lblCamInfo.text = ("Individual TM ON | " + (success as string) + " camera(s)")
            else
                lblCamInfo.text = ("Individual TM OFF / Global | " + (success as string) + " camera(s)")

            local c0 = cams[1]
            chkTMOverride.checked = getCameraTMOverride c0
        )
    )

    on btnTMCopy pressed do
    (
        local cams = selectedCameraNodes()

        if cams.count == 0 then
        (
            messageBox "Select a camera in the list first." title:"PRT Render - Corona"
        )
        else
        (
            local success = 0

            for c in cams do
            (
                if copyGlobalTMToCamera c then
                    success += 1
            )

            if success > 0 then
            (
                chkTMOverride.checked = true
                lblCamInfo.text = ("Individual TM ON | copied from Global to " +
                                   (success as string) + " camera(s)")
            )
            else
            (
                messageBox "Could not find Corona Camera's native 'Copy from global' button. Select the camera once in the Modify panel and expand Tone Mapping, then try again." title:"PRT Render - Corona"
            )
        )
    )

    on btnRender pressed do renderAll()
)

createDialog PRT_Corona_Renderer \
    width:560 height:925 \
    style:#(#style_titlebar, #style_sysmenu, #style_minimizebox, #style_toolwindow, #style_resizing) \
    parent:(windows.getMAXHWND())

/* Toolbar macro: can be installed in Customize User Interface. */
macroScript PRT_Render_Corona
category:"PRT Render"
buttonText:"PRT Render"
toolTip:"PRT Render - Corona"
(
    try (destroyDialog PRT_Corona_Renderer) catch()
    createDialog PRT_Corona_Renderer \
        width:560 height:925 \
        style:#(#style_titlebar, #style_sysmenu, #style_minimizebox, #style_toolwindow, #style_resizing) \
        parent:(windows.getMAXHWND())
)
