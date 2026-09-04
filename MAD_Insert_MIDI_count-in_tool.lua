--[[
    REAPER Lua Action
    Insert Hi-Hat MIDI - Exactly One Bar

    CROSS-PLATFORM VERSION
    ----------------------

    Popup:
        320 x 190

    The popup is centered on the monitor containing
    the REAPER main window.

    Subdivision:
        Quarter
        Eighth
        Sixteenth
        32nd
        64th

    Feel:
        Normal
        Swing
        Triplet

    Defaults:
        Quarter
        Normal

    Keyboard:
        Enter = Insert
        Esc   = Cancel

    MIDI:
        Closed Hi-Hat = 42
        Channel       = 10
        Velocity      = 100

    Requires:
        JS_ReaScriptAPI

    Time signature:
        Uses REAPER's exact measure QN boundaries.
        Works with 2/4, 3/4, 4/4, 5/4,
        6/8, 7/8, 9/8, 12/8, etc.
]]

------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------

local PROJ = 0

local TITLE = "Insert Hi-Hat MIDI"

local WINDOW_W = 320
local WINDOW_H = 190

------------------------------------------------------------
-- SUBDIVISIONS
------------------------------------------------------------

local subdivisionNames = {
    "Quarter",
    "Eighth",
    "Sixteenth",
    "32nd",
    "64th"
}

local subdivisionValues = {
    1,
    2,
    4,
    8,
    16
}

------------------------------------------------------------
-- FEEL
------------------------------------------------------------

local feelNames = {
    "Normal",
    "Swing",
    "Triplet"
}

------------------------------------------------------------
-- DEFAULTS
------------------------------------------------------------

local subdivisionChoice = 1
local feelChoice = 1

------------------------------------------------------------
-- MIDI
------------------------------------------------------------

local MIDI_NOTE = 42
local MIDI_CHANNEL = 9
local MIDI_VELOCITY = 100

------------------------------------------------------------
-- SELECTED TRACK
------------------------------------------------------------

local track =
    reaper.GetSelectedTrack(
        PROJ,
        0
    )

if not track then

    reaper.ShowMessageBox(
        "Please select a track first.",
        TITLE,
        0
    )

    return
end

------------------------------------------------------------
-- GUI STATE
------------------------------------------------------------

local dialogDone = false
local cancelled = false

local lastMouseCap = 0

------------------------------------------------------------
-- COLORS
------------------------------------------------------------

local COLORS = {
    background = {0.115, 0.115, 0.125, 1},
    panel      = {0.155, 0.155, 0.170, 1},
    border     = {0.32, 0.32, 0.35, 1},
    text       = {0.92, 0.92, 0.94, 1},
    label      = {0.68, 0.68, 0.72, 1},
    blue       = {0.20, 0.48, 0.78, 1},
    blueHover  = {0.25, 0.55, 0.88, 1},
    button     = {0.22, 0.22, 0.24, 1},
    hover      = {0.28, 0.28, 0.31, 1},
    white      = {1, 1, 1, 1}
}

------------------------------------------------------------
-- GUI LAYOUT
------------------------------------------------------------

local labelX = 20
local fieldX = 125

local fieldW = 175
local fieldH = 28

local subdivisionY = 53
local feelY = 91

local insertX = 55
local cancelX = 170

local buttonY = 140
local buttonW = 100
local buttonH = 30

------------------------------------------------------------
-- DRAW HELPERS
------------------------------------------------------------

local function setColor(c)

    gfx.set(
        c[1],
        c[2],
        c[3],
        c[4]
    )
end

------------------------------------------------------------

local function drawRect(
    x,
    y,
    w,
    h,
    color,
    filled
)

    setColor(color)

    gfx.rect(
        x,
        y,
        w,
        h,
        filled ~= false
    )
end

------------------------------------------------------------

local function mouseIn(
    x,
    y,
    w,
    h
)

    return
        gfx.mouse_x >= x
        and
        gfx.mouse_x <= x + w
        and
        gfx.mouse_y >= y
        and
        gfx.mouse_y <= y + h
end

------------------------------------------------------------
-- BUTTON
------------------------------------------------------------

local function drawButton(
    x,
    y,
    w,
    h,
    text,
    hovered,
    primary
)

    local color

    if primary then

        color =
            hovered
            and COLORS.blueHover
            or COLORS.blue

    else

        color =
            hovered
            and COLORS.hover
            or COLORS.button
    end

    drawRect(
        x,
        y,
        w,
        h,
        color,
        true
    )

    setColor(COLORS.border)

    gfx.rect(
        x,
        y,
        w,
        h,
        false
    )

    gfx.setfont(
        1,
        "Arial",
        14
    )

    setColor(COLORS.white)

    local tw =
        gfx.measurestr(text)

    gfx.x =
        x + (w - tw) / 2

    gfx.y =
        y + (h - 14) / 2

    gfx.drawstr(text)
end

------------------------------------------------------------
-- DROPDOWN
------------------------------------------------------------

local function drawDropdown(
    x,
    y,
    w,
    h,
    text,
    hovered
)

    local color =
        hovered
        and COLORS.hover
        or COLORS.panel

    drawRect(
        x,
        y,
        w,
        h,
        color,
        true
    )

    setColor(COLORS.border)

    gfx.rect(
        x,
        y,
        w,
        h,
        false
    )

    gfx.setfont(
        1,
        "Arial",
        14
    )

    setColor(COLORS.text)

    gfx.x = x + 10
    gfx.y = y + 7

    gfx.drawstr(text)

    --------------------------------------------------------
    -- Arrow
    --------------------------------------------------------

    local arrowX =
        x + w - 20

    local arrowY =
        y + h / 2

    setColor(COLORS.label)

    gfx.triangle(
        arrowX - 5,
        arrowY - 3,
        arrowX + 5,
        arrowY - 3,
        arrowX,
        arrowY + 4
    )
end

------------------------------------------------------------
-- DROPDOWN MENU
------------------------------------------------------------

local function showDropdown(
    items,
    current
)

    local menu =
        table.concat(
            items,
            "|"
        )

    local selected =
        gfx.showmenu(menu)

    if selected >= 1
    and selected <= #items then

        return selected
    end

    return current
end

------------------------------------------------------------
-- DRAW WINDOW
------------------------------------------------------------

local function drawWindow()

    --------------------------------------------------------
    -- Background
    --------------------------------------------------------

    drawRect(
        0,
        0,
        WINDOW_W,
        WINDOW_H,
        COLORS.background,
        true
    )

    --------------------------------------------------------
    -- Title
    --------------------------------------------------------

    gfx.setfont(
        1,
        "Arial",
        18
    )

    setColor(COLORS.text)

    gfx.x = 20
    gfx.y = 15

    gfx.drawstr(TITLE)

    --------------------------------------------------------
    -- Labels
    --------------------------------------------------------

    gfx.setfont(
        1,
        "Arial",
        14
    )

    setColor(COLORS.label)

    gfx.x = labelX
    gfx.y = subdivisionY + 6

    gfx.drawstr("Subdivision")

    gfx.x = labelX
    gfx.y = feelY + 6

    gfx.drawstr("Feel")

    --------------------------------------------------------
    -- Subdivision
    --------------------------------------------------------

    drawDropdown(
        fieldX,
        subdivisionY,
        fieldW,
        fieldH,
        subdivisionNames[subdivisionChoice],
        mouseIn(
            fieldX,
            subdivisionY,
            fieldW,
            fieldH
        )
    )

    --------------------------------------------------------
    -- Feel
    --------------------------------------------------------

    drawDropdown(
        fieldX,
        feelY,
        fieldW,
        fieldH,
        feelNames[feelChoice],
        mouseIn(
            fieldX,
            feelY,
            fieldW,
            fieldH
        )
    )

    --------------------------------------------------------
    -- Insert
    --------------------------------------------------------

    drawButton(
        insertX,
        buttonY,
        buttonW,
        buttonH,
        "Insert",
        mouseIn(
            insertX,
            buttonY,
            buttonW,
            buttonH
        ),
        true
    )

    --------------------------------------------------------
    -- Cancel
    --------------------------------------------------------

    drawButton(
        cancelX,
        buttonY,
        buttonW,
        buttonH,
        "Cancel",
        mouseIn(
            cancelX,
            buttonY,
            buttonW,
            buttonH
        ),
        false
    )
end

------------------------------------------------------------
-- CROSS-PLATFORM CENTER POSITION
--
-- Centers the popup on the monitor containing the CENTER
-- of the REAPER main window.
--
-- Uses JS_Window_GetViewportFromRect(), which is designed
-- specifically to determine the monitor/work area.
--
-- wantWork = true:
--   Excludes taskbar / dock / desktop toolbars where the
--   operating system provides that information.
--
-- This is preferable to JS_Window_FromPoint(), because
-- JS_Window_FromPoint() returns a WINDOW, not a MONITOR.
------------------------------------------------------------

local function getCenteredPosition()

    --------------------------------------------------------
    -- Start with a safe fallback.
    --------------------------------------------------------

    local x = 0
    local y = 0

    --------------------------------------------------------
    -- JS_ReaScriptAPI required.
    --------------------------------------------------------

    if not reaper.JS_Window_GetRect
    or not reaper.JS_Window_GetViewportFromRect then

        return x, y
    end

    --------------------------------------------------------
    -- Get REAPER main window.
    --------------------------------------------------------

    local mainHWND =
        reaper.GetMainHwnd()

    if not mainHWND then
        return x, y
    end

    --------------------------------------------------------
    -- Get REAPER's actual screen rectangle.
    --------------------------------------------------------

    local ok,
          left,
          top,
          right,
          bottom =
        reaper.JS_Window_GetRect(
            mainHWND
        )

    if not ok then
        return x, y
    end

    --------------------------------------------------------
    -- Use the CENTER POINT of REAPER's main window.
    --
    -- We make this a 1x1 rectangle.
    --
    -- GetViewportFromRect() will therefore select the
    -- monitor containing this point.
    --------------------------------------------------------

    local centerX =
        math.floor(
            (left + right) / 2
        )

    local centerY =
        math.floor(
            (top + bottom) / 2
        )

    --------------------------------------------------------
    -- Ask JS_ReaScriptAPI for the monitor WORK AREA.
    --
    -- true = exclude taskbar / dock / desktop toolbar.
    --------------------------------------------------------

    local monitorLeft,
          monitorTop,
          monitorRight,
          monitorBottom =
        reaper.JS_Window_GetViewportFromRect(
            centerX,
            centerY,
            centerX + 1,
            centerY + 1,
            true
        )

    --------------------------------------------------------
    -- Validate returned monitor rectangle.
    --------------------------------------------------------

    if not monitorLeft
    or not monitorTop
    or not monitorRight
    or not monitorBottom then

        ----------------------------------------------------
        -- Fallback: center on REAPER itself.
        ----------------------------------------------------

        x =
            math.floor(
                (left + right - WINDOW_W) / 2
            )

        y =
            math.floor(
                (top + bottom - WINDOW_H) / 2
            )

        return x, y
    end

    --------------------------------------------------------
    -- Center the 320 x 190 popup inside the monitor's
    -- usable work area.
    --
    -- IMPORTANT:
    --
    -- These coordinates are the TOP-LEFT of the popup.
    -- We subtract HALF the popup dimensions.
    --------------------------------------------------------

    x =
        math.floor(
            monitorLeft +
            (
                (monitorRight - monitorLeft)
                - WINDOW_W
            ) / 2
        )

    y =
        math.floor(
            monitorTop +
            (
                (monitorBottom - monitorTop)
                - WINDOW_H
            ) / 2
        )

    return x, y
end


------------------------------------------------------------
-- OPEN WINDOW
------------------------------------------------------------

local popupX,
      popupY =
    getCenteredPosition()

gfx.init(
    TITLE,
    WINDOW_W,
    WINDOW_H,
    0,
    popupX,
    popupY
)

------------------------------------------------------------
-- OPTIONAL NATIVE CORRECTION
--
-- gfx.init() normally positions the window correctly.
--
-- On systems with unusual DPI/window-manager behavior,
-- perform one correction after the native window exists.
------------------------------------------------------------

local function correctPopupPosition()

    if not reaper.JS_Window_Find
    or not reaper.JS_Window_GetRect
    or not reaper.JS_Window_SetPosition then

        return
    end

    local popupHWND =
        reaper.JS_Window_Find(
            TITLE,
            true
        )

    if not popupHWND then
        return
    end

    local mainHWND =
        reaper.GetMainHwnd()

    if not mainHWND then
        return
    end

    --------------------------------------------------------
    -- Get REAPER.
    --------------------------------------------------------

    local ok,
          left,
          top,
          right,
          bottom =
        reaper.JS_Window_GetRect(
            mainHWND
        )

    if not ok then
        return
    end

    --------------------------------------------------------
    -- Center based on the monitor containing REAPER's
    -- center point.
    --------------------------------------------------------

    local cx =
        math.floor(
            (left + right) / 2
        )

    local cy =
        math.floor(
            (top + bottom) / 2
        )

    local monitorHWND = nil

    if reaper.JS_Window_FromPoint then

        monitorHWND =
            reaper.JS_Window_FromPoint(
                cx,
                cy
            )
    end

    if not monitorHWND then
        return
    end

    local mok,
          ml,
          mt,
          mr,
          mb =
        reaper.JS_Window_GetRect(
            monitorHWND
        )

    if not mok then
        return
    end

    --------------------------------------------------------
    -- Popup's actual outer size.
    --------------------------------------------------------

    local pok,
          pl,
          pt,
          pr,
          pb =
        reaper.JS_Window_GetRect(
            popupHWND
        )

    if not pok then
        return
    end

    local popupW =
        pr - pl

    local popupH =
        pb - pt

    if popupW <= 0
    or popupH <= 0 then
        return
    end

    --------------------------------------------------------
    -- Center actual native window.
    --------------------------------------------------------

    local nx =
        math.floor(
            ml +
            ((mr - ml) - popupW) / 2
        )

    local ny =
        math.floor(
            mt +
            ((mb - mt) - popupH) / 2
        )

    reaper.JS_Window_SetPosition(
        popupHWND,
        nx,
        ny,
        popupW,
        popupH
    )
end

------------------------------------------------------------
-- INSERT NOTE
------------------------------------------------------------

local function insertNote(
    take,
    startQN,
    endQN,
    barEndQN
)

    if startQN >= barEndQN then
        return
    end

    endQN =
        math.min(
            endQN,
            barEndQN
        )

    if endQN <= startQN then
        return
    end

    local startPPQ =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            startQN
        )

    local endPPQ =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            endQN
        )

    local spacingPPQ =
        endPPQ - startPPQ

    local noteLengthPPQ =
        math.max(
            1,
            spacingPPQ * 0.25
        )

    local barEndPPQ =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            barEndQN
        )

    local noteEndPPQ =
        math.min(
            startPPQ + noteLengthPPQ,
            barEndPPQ
        )

    if noteEndPPQ > startPPQ then

        reaper.MIDI_InsertNote(
            take,
            false,
            false,
            startPPQ,
            noteEndPPQ,
            MIDI_CHANNEL,
            MIDI_NOTE,
            MIDI_VELOCITY,
            true
        )
    end
end

------------------------------------------------------------
-- NORMAL GRID
------------------------------------------------------------

local function insertNormalGrid(
    take,
    qnStart,
    qnEnd,
    subdivisionQN
)

    local currentQN =
        qnStart

    while currentQN <
          qnEnd - 0.0000001 do

        local nextQN =
            math.min(
                currentQN + subdivisionQN,
                qnEnd
            )

        insertNote(
            take,
            currentQN,
            nextQN,
            qnEnd
        )

        currentQN =
            nextQN
    end
end

------------------------------------------------------------
-- SWING GRID
------------------------------------------------------------

local function insertSwingGrid(
    take,
    qnStart,
    qnEnd,
    subdivisionQN
)

    local pairQN =
        subdivisionQN * 2

    local currentQN =
        qnStart

    while currentQN <
          qnEnd - 0.0000001 do

        local pairEndQN =
            math.min(
                currentQN + pairQN,
                qnEnd
            )

        local pairLength =
            pairEndQN - currentQN

        if pairLength <= 0 then
            break
        end

        local secondQN =
            currentQN +
            pairLength * (2 / 3)

        insertNote(
            take,
            currentQN,
            secondQN,
            qnEnd
        )

        if secondQN <
           pairEndQN - 0.0000001 then

            insertNote(
                take,
                secondQN,
                pairEndQN,
                qnEnd
            )
        end

        currentQN =
            pairEndQN
    end
end

------------------------------------------------------------
-- TRIPLET GRID
------------------------------------------------------------

local function insertTripletGrid(
    take,
    qnStart,
    qnEnd,
    subdivisionQN
)

    local tripletQN =
        subdivisionQN / 3

    local currentQN =
        qnStart

    while currentQN <
          qnEnd - 0.0000001 do

        local nextQN =
            math.min(
                currentQN + tripletQN,
                qnEnd
            )

        insertNote(
            take,
            currentQN,
            nextQN,
            qnEnd
        )

        currentQN =
            nextQN
    end
end

------------------------------------------------------------
-- INSERT HI-HAT
------------------------------------------------------------

local function insertHiHat()

    local measureStartTime,
          qnStart,
          qnEnd,
          numerator,
          denominator =
        reaper.TimeMap_GetMeasureInfo(
            PROJ,
            0
        )

    if not measureStartTime
    or not qnStart
    or not qnEnd then

        reaper.ShowMessageBox(
            "Could not determine the first project measure.",
            TITLE,
            0
        )

        return
    end

    if qnEnd <= qnStart then

        reaper.ShowMessageBox(
            "The first project measure has an invalid QN range.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Exact measure end.
    --------------------------------------------------------

    local measureEndTime =
        reaper.TimeMap2_QNToTime(
            PROJ,
            qnEnd
        )

    if not measureEndTime
    or measureEndTime <= measureStartTime then

        reaper.ShowMessageBox(
            "The first project measure has an invalid time range.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Selected subdivision.
    --------------------------------------------------------

    local subdivisionQN =
        1 /
        subdivisionValues[subdivisionChoice]

    --------------------------------------------------------
    -- Undo.
    --------------------------------------------------------

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    --------------------------------------------------------
    -- Create MIDI item.
    --------------------------------------------------------

    local item =
        reaper.CreateNewMIDIItemInProj(
            track,
            measureStartTime,
            measureEndTime,
            false
        )

    if not item then

        reaper.PreventUIRefresh(-1)

        reaper.Undo_EndBlock(
            "Insert Hi-Hat MIDI",
            -1
        )

        reaper.ShowMessageBox(
            "Could not create the MIDI item.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Exact boundaries.
    --------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "D_POSITION",
        measureStartTime
    )

    reaper.SetMediaItemInfo_Value(
        item,
        "D_LENGTH",
        measureEndTime - measureStartTime
    )

    reaper.SetMediaItemInfo_Value(
        item,
        "B_LOOPSRC",
        0
    )

    --------------------------------------------------------
    -- MIDI take.
    --------------------------------------------------------

    local take =
        reaper.GetActiveTake(
            item
        )

    if not take
    or not reaper.TakeIsMIDI(take) then

        reaper.DeleteTrackMediaItem(
            track,
            item
        )

        reaper.PreventUIRefresh(-1)

        reaper.Undo_EndBlock(
            "Insert Hi-Hat MIDI",
            -1
        )

        reaper.ShowMessageBox(
            "Could not create a MIDI take.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Generate.
    --------------------------------------------------------

    if feelChoice == 1 then

        insertNormalGrid(
            take,
            qnStart,
            qnEnd,
            subdivisionQN
        )

    elseif feelChoice == 2 then

        insertSwingGrid(
            take,
            qnStart,
            qnEnd,
            subdivisionQN
        )

    elseif feelChoice == 3 then

        insertTripletGrid(
            take,
            qnStart,
            qnEnd,
            subdivisionQN
        )
    end

    --------------------------------------------------------
    -- Sort.
    --------------------------------------------------------

    reaper.MIDI_Sort(
        take
    )

    --------------------------------------------------------
    -- Select.
    --------------------------------------------------------

    reaper.SetOnlyTrackSelected(
        track
    )

    reaper.SetMediaItemSelected(
        item,
        true
    )

    reaper.UpdateItemInProject(
        item
    )

    reaper.UpdateArrange()

    reaper.PreventUIRefresh(-1)

    reaper.Undo_EndBlock(
        "Insert Hi-Hat MIDI - Exactly One Bar",
        -1
    )
end

------------------------------------------------------------
-- GUI LOOP
------------------------------------------------------------

local function guiLoop()

    --------------------------------------------------------
    -- Keyboard.
    --------------------------------------------------------

    local char =
        gfx.getchar()

    --------------------------------------------------------
    -- Window closed.
    --------------------------------------------------------

    if char == -1 then

        cancelled = true
        dialogDone = true

        gfx.quit()

        return
    end

    --------------------------------------------------------
    -- ESC.
    --------------------------------------------------------

    if char == 27 then

        cancelled = true
        dialogDone = true

        gfx.quit()

        return
    end

    --------------------------------------------------------
    -- ENTER.
    --------------------------------------------------------

    if char == 13 then

        dialogDone = true

        gfx.quit()

        return
    end

    --------------------------------------------------------
    -- Draw.
    --------------------------------------------------------

    drawWindow()

    --------------------------------------------------------
    -- Mouse.
    --------------------------------------------------------

    local mouseCap =
        gfx.mouse_cap

    local clicked =
        (mouseCap & 1) ~= 0
        and
        (lastMouseCap & 1) == 0

    if clicked then

        ----------------------------------------------------
        -- Subdivision.
        ----------------------------------------------------

        if mouseIn(
            fieldX,
            subdivisionY,
            fieldW,
            fieldH
        ) then

            subdivisionChoice =
                showDropdown(
                    subdivisionNames,
                    subdivisionChoice
                )

        ----------------------------------------------------
        -- Feel.
        ----------------------------------------------------

        elseif mouseIn(
            fieldX,
            feelY,
            fieldW,
            fieldH
        ) then

            feelChoice =
                showDropdown(
                    feelNames,
                    feelChoice
                )

        ----------------------------------------------------
        -- Insert.
        ----------------------------------------------------

        elseif mouseIn(
            insertX,
            buttonY,
            buttonW,
            buttonH
        ) then

            dialogDone = true

            gfx.quit()

            return

        ----------------------------------------------------
        -- Cancel.
        ----------------------------------------------------

        elseif mouseIn(
            cancelX,
            buttonY,
            buttonW,
            buttonH
        ) then

            cancelled = true
            dialogDone = true

            gfx.quit()

            return
        end
    end

    lastMouseCap =
        mouseCap

    --------------------------------------------------------
    -- Continue.
    --------------------------------------------------------

    reaper.defer(
        guiLoop
    )
end

------------------------------------------------------------
-- FINISH DIALOG
------------------------------------------------------------

local function finishDialog()

    if not dialogDone then

        reaper.defer(
            finishDialog
        )

        return
    end

    if cancelled then
        return
    end

    insertHiHat()
end

------------------------------------------------------------
-- CREATE CENTERED WINDOW
------------------------------------------------------------

local popupX,
      popupY =
    getCenteredPosition()

gfx.init(
    TITLE,
    WINDOW_W,
    WINDOW_H,
    0,
    popupX,
    popupY
)

------------------------------------------------------------
-- START GUI
------------------------------------------------------------

reaper.defer(
    guiLoop
)

------------------------------------------------------------
-- WAIT FOR COMPLETION
------------------------------------------------------------

reaper.defer(
    finishDialog
)
