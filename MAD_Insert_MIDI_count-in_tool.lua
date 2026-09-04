--[[
    REAPER Lua Action
    Insert Drum MIDI - Exactly One Bar

    --------------------------------------------------------
    FEATURES
    --------------------------------------------------------

    Popup:
        320 x 190

    Dropdowns:
        Instrument
        Subdivision
        Feel

    Instruments:
        Hi-Hat
        Kick
        Snare
        Low Tom
        Mid Tom
        High Tom
        Floor Tom
        Crash
        Ride
        Ride Bell
        Rim
        Clap
        Cowbell

    Subdivisions:
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
        Instrument  = Hi-Hat
        Subdivision = Quarter
        Feel        = Normal

    Keyboard:
        Enter = Insert
        Esc   = Cancel

    MIDI:
        General MIDI percussion
        Channel 10 / zero-based channel 9

    TIME SIGNATURE
    --------------------------------------------------------

    Uses REAPER's exact measure QN boundaries.

    Therefore the MIDI item follows the actual project
    measure regardless of time signature:

        2/4
        3/4
        4/4
        5/4
        6/8
        7/8
        9/8
        12/8
        etc.

    The script never calculates the bar length from the
    time signature. REAPER supplies the exact measure
    boundaries.

    --------------------------------------------------------
    REQUIRES
    --------------------------------------------------------

    JS_ReaScriptAPI

    The script will still run if JS_ReaScriptAPI is missing,
    but monitor-specific centering will fall back to
    centering over the REAPER window.
]]

------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------

local PROJ = 0

local TITLE = "Insert Drum MIDI"

local WINDOW_W = 320
local WINDOW_H = 190

------------------------------------------------------------
-- MIDI CHANNEL
--
-- REAPER uses zero-based MIDI channels.
--
-- 9 = MIDI channel 10.
------------------------------------------------------------

local MIDI_CHANNEL = 9

------------------------------------------------------------
-- INSTRUMENTS
--
-- General MIDI percussion note numbers.
------------------------------------------------------------

local instruments = {
    { name = "Hi-Hat",    note = 42 },
    { name = "Kick",      note = 36 },
    { name = "Snare",     note = 38 },
    { name = "Low Tom",   note = 45 },
    { name = "Mid Tom",   note = 47 },
    { name = "High Tom",  note = 50 },
    { name = "Floor Tom", note = 41 },
    { name = "Crash",     note = 49 },
    { name = "Ride",      note = 51 },
    { name = "Ride Bell", note = 53 },
    { name = "Rim",       note = 37 },
    { name = "Clap",      note = 39 },
    { name = "Cowbell",   note = 56 }
}

local instrumentNames = {}

for i = 1, #instruments do
    instrumentNames[i] = instruments[i].name
end

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

------------------------------------------------------------
-- Number of notes per quarter note.
------------------------------------------------------------

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

local instrumentChoice = 1      -- Hi-Hat
local subdivisionChoice = 1     -- Quarter
local feelChoice = 1             -- Normal

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
--
-- Three dropdowns now fit into the original 320 x 190
-- window.
------------------------------------------------------------

local labelX = 18
local fieldX = 115

local fieldW = 187
local fieldH = 25

local instrumentY  = 39
local subdivisionY = 69
local feelY        = 99

local insertX = 55
local cancelX = 170

local buttonY = 143
local buttonW = 100
local buttonH = 30

------------------------------------------------------------
-- COLOR HELPER
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
-- RECTANGLE HELPER
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
-- MOUSE HIT TEST
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
-- DRAW BUTTON
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
-- DRAW DROPDOWN
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

    --------------------------------------------------------
    -- Text
    --------------------------------------------------------

    gfx.setfont(
        1,
        "Arial",
        14
    )

    setColor(COLORS.text)

    gfx.x =
        x + 9

    gfx.y =
        y + 5

    gfx.drawstr(text)

    --------------------------------------------------------
    -- Arrow
    --------------------------------------------------------

    local arrowX =
        x + w - 17

    local arrowY =
        y + h / 2

    setColor(
        COLORS.label
    )

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
-- SHOW DROPDOWN
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

    setColor(
        COLORS.text
    )

    gfx.x = 18
    gfx.y = 10

    gfx.drawstr(
        TITLE
    )

    --------------------------------------------------------
    -- Labels
    --------------------------------------------------------

    gfx.setfont(
        1,
        "Arial",
        14
    )

    setColor(
        COLORS.label
    )

    gfx.x = labelX
    gfx.y = instrumentY + 5

    gfx.drawstr(
        "Instrument"
    )

    gfx.x = labelX
    gfx.y = subdivisionY + 5

    gfx.drawstr(
        "Subdivision"
    )

    gfx.x = labelX
    gfx.y = feelY + 5

    gfx.drawstr(
        "Feel"
    )

    --------------------------------------------------------
    -- Instrument
    --------------------------------------------------------

    drawDropdown(
        fieldX,
        instrumentY,
        fieldW,
        fieldH,
        instrumentNames[instrumentChoice],
        mouseIn(
            fieldX,
            instrumentY,
            fieldW,
            fieldH
        )
    )

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
-- CENTER POPUP
--
-- IMPORTANT:
--
-- JS_Window_FromPoint() is NOT used here.
--
-- It returns a window, not a monitor.
--
-- JS_Window_GetViewportFromRect() is used to determine
-- which monitor contains the center of the REAPER window.
--
-- wantWork = true means use the usable monitor work area
-- rather than positioning underneath a taskbar/dock.
------------------------------------------------------------

local function getCenteredPosition()

    --------------------------------------------------------
    -- Safe fallback.
    --------------------------------------------------------

    local fallbackX = 100
    local fallbackY = 100

    --------------------------------------------------------
    -- Need JS_ReaScriptAPI for monitor-aware positioning.
    --------------------------------------------------------

    if not reaper.JS_Window_GetRect
    or not reaper.JS_Window_GetViewportFromRect then

        return fallbackX, fallbackY
    end

    --------------------------------------------------------
    -- REAPER main window.
    --------------------------------------------------------

    local mainHWND =
        reaper.GetMainHwnd()

    if not mainHWND then
        return fallbackX, fallbackY
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
        return fallbackX, fallbackY
    end

    --------------------------------------------------------
    -- Center point of REAPER.
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
    -- Find the monitor/work area containing that point.
    --
    -- A 1x1 rectangle is used so the selected viewport is
    -- the monitor containing the REAPER center.
    --------------------------------------------------------

    local viewportLeft,
          viewportTop,
          viewportRight,
          viewportBottom =
        reaper.JS_Window_GetViewportFromRect(
            centerX,
            centerY,
            centerX + 1,
            centerY + 1,
            true
        )

    --------------------------------------------------------
    -- Validate.
    --------------------------------------------------------

    if not viewportLeft
    or not viewportTop
    or not viewportRight
    or not viewportBottom then

        ----------------------------------------------------
        -- Fallback to REAPER window center.
        ----------------------------------------------------

        return
            math.floor(
                (left + right - WINDOW_W) / 2
            ),
            math.floor(
                (top + bottom - WINDOW_H) / 2
            )
    end

    --------------------------------------------------------
    -- Center the 320 x 190 popup.
    --
    -- These are TOP-LEFT coordinates.
    --------------------------------------------------------

    local x =
        math.floor(
            viewportLeft +
            (
                (viewportRight - viewportLeft)
                - WINDOW_W
            ) / 2
        )

    local y =
        math.floor(
            viewportTop +
            (
                (viewportBottom - viewportTop)
                - WINDOW_H
            ) / 2
        )

    return x, y
end

------------------------------------------------------------
-- INSERT NOTE
------------------------------------------------------------

local function insertNote(
    take,
    startQN,
    nextQN,
    barEndQN
)

    --------------------------------------------------------
    -- Never place a note at or beyond the end of the bar.
    --------------------------------------------------------

    if startQN >= barEndQN then
        return
    end

    nextQN =
        math.min(
            nextQN,
            barEndQN
        )

    if nextQN <= startQN then
        return
    end

    --------------------------------------------------------
    -- Convert project QN positions to MIDI PPQ.
    --------------------------------------------------------

    local startPPQ =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            startQN
        )

    local nextPPQ =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            nextQN
        )

    local spacingPPQ =
        nextPPQ - startPPQ

    --------------------------------------------------------
    -- Short drum note.
    --
    -- 25% of the spacing.
    --
    -- This gives enough separation for hi-hats, kicks,
    -- snares and toms while remaining musically useful.
    --------------------------------------------------------

    local noteLengthPPQ =
        math.max(
            1,
            spacingPPQ * 0.25
        )

    --------------------------------------------------------
    -- Exact end of bar in PPQ.
    --------------------------------------------------------

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

    if noteEndPPQ <= startPPQ then
        return
    end

    --------------------------------------------------------
    -- Insert General MIDI percussion note.
    --------------------------------------------------------

    local midiNote =
        instruments[instrumentChoice].note

    reaper.MIDI_InsertNote(
        take,

        false,          -- selected
        false,          -- muted

        startPPQ,
        noteEndPPQ,

        MIDI_CHANNEL,

        midiNote,

        100,            -- velocity

        true            -- noSort
    )
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

    --------------------------------------------------------
    -- Swing pairs the selected subdivision.
    --
    -- Example:
    --
    -- Eighth-note subdivision:
    --
    -- straight:
    --
    -- | 0.0 | 0.5 | 1.0 | 1.5 |
    --
    -- swing:
    --
    -- | 0.0 | 0.6667 | 1.0 | 1.6667 |
    --
    -- This creates a 2:1 long/short relationship.
    --------------------------------------------------------

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

        ----------------------------------------------------
        -- First note.
        ----------------------------------------------------

        local firstQN =
            currentQN

        ----------------------------------------------------
        -- Second note at 2/3 of the pair.
        ----------------------------------------------------

        local secondQN =
            currentQN +
            pairLength * (2 / 3)

        insertNote(
            take,
            firstQN,
            secondQN,
            qnEnd
        )

        ----------------------------------------------------
        -- Second note.
        ----------------------------------------------------

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

    --------------------------------------------------------
    -- Divide every selected subdivision into three equal
    -- parts.
    --
    -- Example:
    --
    -- Eighth:
    --
    -- 0.5 QN
    --
    -- triplet spacing:
    --
    -- 0.1666667 QN
    --------------------------------------------------------

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
-- INSERT HI-HAT / DRUM
------------------------------------------------------------

local function insertDrum()

    --------------------------------------------------------
    -- Get exact first measure boundaries.
    --------------------------------------------------------

    local measureStartTime,
          qnStart,
          qnEnd,
          numerator,
          denominator =
        reaper.TimeMap_GetMeasureInfo(
            PROJ,
            0
        )

    --------------------------------------------------------
    -- Validate.
    --------------------------------------------------------

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

    --------------------------------------------------------
    -- IMPORTANT:
    --
    -- Do not calculate the bar length from numerator /
    -- denominator.
    --
    -- REAPER has already supplied the exact QN boundaries.
    --------------------------------------------------------

    if qnEnd <= qnStart then

        reaper.ShowMessageBox(
            "The first project measure has an invalid QN range.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Convert exact QN end to project time.
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
    -- Selected subdivision in quarter-note units.
    --
    -- Quarter = 1 QN
    -- Eighth  = 0.5 QN
    -- 16th    = 0.25 QN
    -- 32nd    = 0.125 QN
    -- 64th    = 0.0625 QN
    --------------------------------------------------------

    local subdivisionQN =
        1 /
        subdivisionValues[subdivisionChoice]

    if subdivisionQN <= 0 then

        reaper.ShowMessageBox(
            "Could not calculate the subdivision.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Begin undo.
    --------------------------------------------------------

    reaper.Undo_BeginBlock()

    reaper.PreventUIRefresh(
        1
    )

    --------------------------------------------------------
    -- Create exact one-measure MIDI item.
    --------------------------------------------------------

    local item =
        reaper.CreateNewMIDIItemInProj(
            track,
            measureStartTime,
            measureEndTime,
            false
        )

    if not item then

        reaper.PreventUIRefresh(
            -1
        )

        reaper.Undo_EndBlock(
            "Insert Drum MIDI",
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
    -- Force exact item position.
    --------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "D_POSITION",
        measureStartTime
    )

    --------------------------------------------------------
    -- Force exact item length.
    --------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "D_LENGTH",
        measureEndTime - measureStartTime
    )

    --------------------------------------------------------
    -- Never loop the MIDI source.
    --------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "B_LOOPSRC",
        0
    )

    --------------------------------------------------------
    -- Get MIDI take.
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

        reaper.PreventUIRefresh(
            -1
        )

        reaper.Undo_EndBlock(
            "Insert Drum MIDI",
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
    -- Generate selected feel.
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
    -- Sort MIDI events.
    --------------------------------------------------------

    reaper.MIDI_Sort(
        take
    )

    --------------------------------------------------------
    -- Select track and item.
    --------------------------------------------------------

    reaper.SetOnlyTrackSelected(
        track
    )

    reaper.SetMediaItemSelected(
        item,
        true
    )

    --------------------------------------------------------
    -- Update.
    --------------------------------------------------------

    reaper.UpdateItemInProject(
        item
    )

    reaper.UpdateArrange()

    --------------------------------------------------------
    -- Finish.
    --------------------------------------------------------

    reaper.PreventUIRefresh(
        -1
    )

    reaper.Undo_EndBlock(
        "Insert Drum MIDI - Exactly One Bar",
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
    -- ESC = CANCEL
    --------------------------------------------------------

    if char == 27 then

        cancelled = true
        dialogDone = true

        gfx.quit()

        return
    end

    --------------------------------------------------------
    -- ENTER = INSERT
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
    -- Mouse state.
    --------------------------------------------------------

    local mouseCap =
        gfx.mouse_cap

    local clicked =
        (mouseCap & 1) ~= 0
        and
        (lastMouseCap & 1) == 0

    if clicked then

        ----------------------------------------------------
        -- Instrument dropdown.
        ----------------------------------------------------

        if mouseIn(
            fieldX,
            instrumentY,
            fieldW,
            fieldH
        ) then

            instrumentChoice =
                showDropdown(
                    instrumentNames,
                    instrumentChoice
                )

        ----------------------------------------------------
        -- Subdivision dropdown.
        ----------------------------------------------------

        elseif mouseIn(
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
        -- Feel dropdown.
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
        -- INSERT.
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
        -- CANCEL.
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
    -- Continue GUI.
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

    insertDrum()
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
-- WAIT FOR DIALOG
------------------------------------------------------------

reaper.defer(
    finishDialog
)
