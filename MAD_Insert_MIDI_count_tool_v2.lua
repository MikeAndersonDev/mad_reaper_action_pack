--[[
    REAPER Lua Action
    Insert Drum MIDI Pattern
]]

------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------

local PROJ = 0

local TITLE = "Insert Drum MIDI"

------------------------------------------------------------
-- WINDOW
------------------------------------------------------------

local WINDOW_W = 420
local WINDOW_H = 365

------------------------------------------------------------
-- MIDI
------------------------------------------------------------

local MIDI_CHANNEL = 9 -- MIDI channel 10, zero based

------------------------------------------------------------
-- INSTRUMENTS
------------------------------------------------------------

local instruments = {
    { name = "Kick",          note = 36 },
    { name = "Snare",         note = 38 },
    { name = "Rim",           note = 37 },
    { name = "Clap",          note = 39 },
    { name = "Closed Hi-Hat", note = 42 },
    { name = "Open Hi-Hat",   note = 46 },
    { name = "Low Tom",       note = 45 },
    { name = "Mid Tom",       note = 47 },
    { name = "High Tom",      note = 50 },
    { name = "Floor Tom",     note = 43 },
    { name = "Cowbell",       note = 56 },
    { name = "Crash",         note = 49 },
    { name = "Ride",          note = 51 },
    { name = "Ride Bell",     note = 53 },
    { name = "Tambourine",    note = 54 },
    { name = "Shaker",        note = 70 }
}

local instrumentNames = {}

for i = 1, #instruments do
    instrumentNames[i] = instruments[i].name
end

------------------------------------------------------------
-- SUBDIVISIONS
------------------------------------------------------------

local subdivisionNames = {
    "Single Note / Measure",
    "Half Note",
    "Quarter Note",
    "Eighth Note",
    "16th Note",
    "32nd Note",
    "64th Note"
}

local subdivisionQN = {
    nil,
    2.0,
    1.0,
    0.5,
    0.25,
    0.125,
    0.0625
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
-- LENGTH
------------------------------------------------------------

local lengthNames = {
    "1 Measure",
    "x2",
    "x3",
    "x4",
    "x5",
    "x6",
    "x7",
    "x8"
}

local lengthMeasures = {
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8
}

------------------------------------------------------------
-- DEFAULTS
------------------------------------------------------------

local instrumentChoice = 5
local subdivisionChoice = 3
local feelChoice = 1
local lengthChoice = 1

local humanize = 0
local intensity = 80

------------------------------------------------------------
-- TRACK
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
    white      = {1, 1, 1, 1},
    slider     = {0.28, 0.28, 0.31, 1},
    sliderFill = {0.20, 0.48, 0.78, 1}
}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function clamp(v, lo, hi)

    if v < lo then
        return lo
    end

    if v > hi then
        return hi
    end

    return v
end

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
        y + 7

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

    local arrowX =
        x + w - 18

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
-- NATIVE DROPDOWN
------------------------------------------------------------

local function chooseFromList(
    items,
    current
)

    local menu =
        table.concat(
            items,
            "|"
        )

    local oldX = gfx.x
    local oldY = gfx.y

    gfx.x = gfx.mouse_x
    gfx.y = gfx.mouse_y

    local result =
        gfx.showmenu(menu)

    gfx.x = oldX
    gfx.y = oldY

    if result >= 1
    and result <= #items then

        return result
    end

    return current
end

------------------------------------------------------------
-- SLIDER
------------------------------------------------------------

local function drawSlider(
    x,
    y,
    w,
    value,
    label
)

    gfx.setfont(
        1,
        "Arial",
        14
    )

    setColor(COLORS.label)

    gfx.x = x
    gfx.y = y

    gfx.drawstr(label)

    local valueText =
        tostring(
            math.floor(value + 0.5)
        ) .. "%"

    local valueW =
        gfx.measurestr(valueText)

    setColor(COLORS.text)

    gfx.x =
        x + w - valueW

    gfx.y = y

    gfx.drawstr(valueText)

    local trackY = y + 23
    local trackH = 6

    drawRect(
        x,
        trackY,
        w,
        trackH,
        COLORS.slider,
        true
    )

    local fillW =
        w * clamp(value, 0, 100) / 100

    drawRect(
        x,
        trackY,
        fillW,
        trackH,
        COLORS.sliderFill,
        true
    )

    local knobX =
        x + fillW

    setColor(COLORS.white)

    gfx.circle(
        knobX,
        trackY + trackH / 2,
        6,
        true
    )
end

------------------------------------------------------------
-- SLIDER VALUE FROM MOUSE
------------------------------------------------------------

local function sliderValueFromMouse(
    x,
    w
)

    local value =
        ((gfx.mouse_x - x) / w) * 100

    return clamp(
        math.floor(value + 0.5),
        0,
        100
    )
end

------------------------------------------------------------
-- GUI LAYOUT
------------------------------------------------------------

local margin = 25

local labelX = margin
local fieldX = 165

local fieldW = 230
local fieldH = 28

local instrumentY = 55
local subdivisionY = 91
local feelY = 127
local lengthY = 163

local sliderX = 25
local sliderW = 370

local humanizeY = 208
local intensityY = 260

local buttonY = 315

local buttonW = 110
local buttonH = 30

local insertX = 85
local cancelX = 225

------------------------------------------------------------
-- DRAW WINDOW
------------------------------------------------------------

local function drawWindow()

    drawRect(
        0,
        0,
        WINDOW_W,
        WINDOW_H,
        COLORS.background,
        true
    )

    gfx.setfont(
        1,
        "Arial",
        18
    )

    setColor(COLORS.text)

    gfx.x = margin
    gfx.y = 16

    gfx.drawstr(TITLE)

    gfx.setfont(
        1,
        "Arial",
        14
    )

    setColor(COLORS.label)

    gfx.x = labelX
    gfx.y = instrumentY + 7

    gfx.drawstr("Instrument")

    gfx.x = labelX
    gfx.y = subdivisionY + 7

    gfx.drawstr("Subdivision")

    gfx.x = labelX
    gfx.y = feelY + 7

    gfx.drawstr("Feel")

    gfx.x = labelX
    gfx.y = lengthY + 7

    gfx.drawstr("Length")

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

    drawDropdown(
        fieldX,
        lengthY,
        fieldW,
        fieldH,
        lengthNames[lengthChoice],
        mouseIn(
            fieldX,
            lengthY,
            fieldW,
            fieldH
        )
    )

    drawSlider(
        sliderX,
        humanizeY,
        sliderW,
        humanize,
        "Humanize"
    )

    drawSlider(
        sliderX,
        intensityY,
        sliderW,
        intensity,
        "Intensity"
    )

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
-- CENTER WINDOW ON SCREEN
------------------------------------------------------------
--
-- The old version centered against REAPER's main window.
--
-- This version centers the actual gfx window on the screen.
--
-- gfx.init(..., -1, -1) already asks REAPER to center the
-- window. JS_ReaScriptAPI then corrects the actual native
-- frame using the monitor containing the window.
--
------------------------------------------------------------

local function centerNativeWindow()

    if not reaper.JS_Window_Find
    or not reaper.JS_Window_GetRect
    or not reaper.JS_Window_SetPosition then

        return
    end

    local popup =
        reaper.JS_Window_Find(
            TITLE,
            true
        )

    if not popup then
        return
    end

    local ok,
          pl,
          pt,
          pr,
          pb =
        reaper.JS_Window_GetRect(
            popup
        )

    if not ok then
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
    -- Get the monitor/work-area containing the popup.
    --
    -- JS_Window_GetRect gives screen coordinates.
    -- JS_Window_GetClientRect is intentionally not used
    -- here because we need the native outer dimensions.
    --
    -- If the JS monitor API is unavailable, gfx's native
    -- -1/-1 centering remains in effect.
    --------------------------------------------------------

    if reaper.JS_Window_GetViewport then

        local vok,
              vl,
              vt,
              vr,
              vb =
            reaper.JS_Window_GetViewport(
                popup
            )

        if vok then

            local vw =
                vr - vl

            local vh =
                vb - vt

            local newX =
                math.floor(
                    vl +
                    (vw - popupW) / 2
                    + 0.5
                )

            local newY =
                math.floor(
                    vt +
                    (vh - popupH) / 2
                    + 0.5
                )

            reaper.JS_Window_SetPosition(
                popup,
                newX,
                newY,
                popupW,
                popupH
            )

            return
        end
    end
end

------------------------------------------------------------
-- RANDOM
------------------------------------------------------------

math.randomseed(
    math.floor(
        reaper.time_precise() * 1000000
    )
)

------------------------------------------------------------
-- HUMANIZE TIMING
------------------------------------------------------------

local function humanizePPQ(
    ppq,
    spacingPPQ
)

    if humanize <= 0 then
        return ppq
    end

    local maximum =
        math.max(
            1,
            spacingPPQ * 0.20
        )

    local amount =
        maximum *
        (humanize / 100)

    local random =
        (math.random() * 2) - 1

    return ppq + random * amount
end

------------------------------------------------------------
-- HUMANIZE VELOCITY
------------------------------------------------------------

local function humanizeVelocity(
    baseVelocity
)

    if humanize <= 0 then
        return baseVelocity
    end

    local amount =
        baseVelocity *
        0.20 *
        (humanize / 100)

    local random =
        (math.random() * 2) - 1

    return
        math.floor(
            baseVelocity +
            random * amount +
            0.5
        )
end

------------------------------------------------------------
-- INSERT NOTE
------------------------------------------------------------

local function insertNote(
    take,
    startQN,
    endQN,
    itemStartQN,
    itemEndQN
)

    if startQN >= itemEndQN then
        return
    end

    if endQN <= startQN then
        return
    end

    endQN =
        math.min(
            endQN,
            itemEndQN
        )

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

    if endPPQ <= startPPQ then
        return
    end

    local spacingPPQ =
        endPPQ - startPPQ

    local noteLength =
        math.max(
            1,
            spacingPPQ * 0.25
        )

    local humanizedStart =
        humanizePPQ(
            startPPQ,
            spacingPPQ
        )

    local itemStartPPQ =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            itemStartQN
        )

    local itemEndPPQ =
        reaper.MIDI_GetPPQPosFromProjQN(
            take,
            itemEndQN
        )

    humanizedStart =
        clamp(
            humanizedStart,
            itemStartPPQ,
            math.max(
                itemStartPPQ,
                itemEndPPQ - 1
            )
        )

    local humanizedEnd =
        humanizedStart +
        noteLength

    humanizedEnd =
        math.min(
            humanizedEnd,
            itemEndPPQ
        )

    if humanizedEnd <= humanizedStart then
        return
    end

    local velocity =
        math.floor(
            1 +
            (126 * intensity / 100)
            + 0.5
        )

    velocity =
        humanizeVelocity(
            velocity
        )

    velocity =
        clamp(
            math.floor(
                velocity + 0.5
            ),
            1,
            127
        )

    reaper.MIDI_InsertNote(
        take,
        false,
        false,
        humanizedStart,
        humanizedEnd,
        MIDI_CHANNEL,
        instruments[instrumentChoice].note,
        velocity,
        true
    )
end

------------------------------------------------------------
-- NORMAL GRID
------------------------------------------------------------

local function insertNormalGrid(
    take,
    startQN,
    endQN,
    gridQN
)

    local currentQN =
        startQN

    while currentQN <
          endQN - 0.000000001 do

        local nextQN =
            math.min(
                currentQN + gridQN,
                endQN
            )

        insertNote(
            take,
            currentQN,
            nextQN,
            startQN,
            endQN
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
    startQN,
    endQN,
    gridQN
)

    local pairQN =
        gridQN * 2

    local currentQN =
        startQN

    while currentQN <
          endQN - 0.000000001 do

        local pairEndQN =
            math.min(
                currentQN + pairQN,
                endQN
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
            startQN,
            endQN
        )

        if secondQN <
           pairEndQN - 0.000000001 then

            insertNote(
                take,
                secondQN,
                pairEndQN,
                startQN,
                endQN
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
    startQN,
    endQN,
    gridQN
)

    local tripletQN =
        gridQN / 3

    local currentQN =
        startQN

    while currentQN <
          endQN - 0.000000001 do

        local nextQN =
            math.min(
                currentQN + tripletQN,
                endQN
            )

        insertNote(
            take,
            currentQN,
            nextQN,
            startQN,
            endQN
        )

        currentQN =
            nextQN
    end
end

------------------------------------------------------------
-- GET CURRENT MEASURE
------------------------------------------------------------

local function getCurrentMeasure()

    local cursorTime =
        reaper.GetCursorPosition()

    local cursorQN =
        reaper.TimeMap2_timeToQN(
            PROJ,
            cursorTime
        )

    local measureIndex,
          measureStartQN,
          measureEndQN =
        reaper.TimeMap_QNToMeasures(
            PROJ,
            cursorQN
        )

    if not measureIndex
    or not measureStartQN
    or not measureEndQN then

        return nil
    end

    return
        cursorTime,
        cursorQN,
        measureIndex,
        measureStartQN,
        measureEndQN
end

------------------------------------------------------------
-- GET NEXT MEASURE END
------------------------------------------------------------
--
-- Used only for determining how the current measure is
-- structured. The actual MIDI item length is calculated
-- separately below.
--
------------------------------------------------------------

local function getMeasureEnd(
    measureIndex
)

    local ok,
          startQN,
          endQN

    ok,
    startQN,
    endQN =
        pcall(
            function()

                local a,
                      b,
                      c =
                    reaper.TimeMap_GetMeasureInfo(
                        PROJ,
                        measureIndex
                    )

                return a, b, c
            end
        )

    if not ok
    or not endQN then

        return nil
    end

    return endQN
end

------------------------------------------------------------
-- CALCULATE FULL-MEASURE LENGTH
------------------------------------------------------------
--
-- IMPORTANT:
--
-- This is the key fix.
--
-- The old code did:
--
--     cursor -> current measure end
--
-- which means a cursor in the middle of a bar produced only
-- the remaining part of the bar.
--
-- This version does:
--
--     cursor -> one COMPLETE current-measure duration
--
-- and repeats that musical measure duration for x2, x3,
-- etc.
--
-- For example:
--
-- 4/4:
--     1 measure = 4 QN
--
-- 3/4:
--     1 measure = 3 QN
--
-- 6/8:
--     1 measure = 3 QN
--
-- 7/8:
--     1 measure = 3.5 QN
--
-- The duration is obtained from the actual time-map measure
-- boundaries, so time signature changes are respected.
--
------------------------------------------------------------

local function calculateItemEndQN(
    cursorQN,
    measureIndex,
    measureStartQN,
    measureEndQN,
    numberOfMeasures
)

    --------------------------------------------------------
    -- Duration of the COMPLETE measure containing the cursor.
    --------------------------------------------------------

    local currentMeasureLength =
        measureEndQN - measureStartQN

    if currentMeasureLength <= 0 then
        return nil
    end

    --------------------------------------------------------
    -- Start at the edit cursor.
    --
    -- Then add COMPLETE measure durations.
    --
    -- This is deliberately NOT:
    --
    --     measureEndQN + following measures
    --
    -- because that would make the first measure shorter when
    -- the cursor is inside the bar.
    --------------------------------------------------------

    local endQN =
        cursorQN +
        currentMeasureLength * numberOfMeasures

    return endQN
end

------------------------------------------------------------
-- INSERT DRUM PATTERN
------------------------------------------------------------

local function insertDrumPattern()

    --------------------------------------------------------
    -- Get cursor/current measure.
    --------------------------------------------------------

    local cursorTime,
          cursorQN,
          measureIndex,
          measureStartQN,
          measureEndQN =
        getCurrentMeasure()

    if not cursorTime
    or not cursorQN
    or not measureIndex
    or not measureStartQN
    or not measureEndQN then

        reaper.ShowMessageBox(
            "Could not determine the measure containing the edit cursor.",
            TITLE,
            0
        )

        return
    end

    if measureEndQN <= measureStartQN then

        reaper.ShowMessageBox(
            "Invalid measure boundaries.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Number of COMPLETE measures requested.
    --------------------------------------------------------

    local numberOfMeasures =
        lengthMeasures[lengthChoice]

    if not numberOfMeasures then
        numberOfMeasures = 1
    end

    --------------------------------------------------------
    -- KEY FIX:
    --
    -- Calculate a FULL measure from the cursor.
    --------------------------------------------------------

    local itemEndQN =
        calculateItemEndQN(
            cursorQN,
            measureIndex,
            measureStartQN,
            measureEndQN,
            numberOfMeasures
        )

    if not itemEndQN
    or itemEndQN <= cursorQN then

        reaper.ShowMessageBox(
            "Could not determine a valid MIDI item length.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Convert exact QN boundaries to project time.
    --------------------------------------------------------

    local itemStartTime =
        reaper.TimeMap2_QNToTime(
            PROJ,
            cursorQN
        )

    local itemEndTime =
        reaper.TimeMap2_QNToTime(
            PROJ,
            itemEndQN
        )

    if not itemStartTime
    or not itemEndTime
    or itemEndTime <= itemStartTime then

        reaper.ShowMessageBox(
            "Invalid MIDI item boundaries.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Undo.
    --------------------------------------------------------

    reaper.Undo_BeginBlock()

    reaper.PreventUIRefresh(1)

    --------------------------------------------------------
    -- Create MIDI item.
    --
    -- Start and end are project QN positions.
    --------------------------------------------------------

    local item =
        reaper.CreateNewMIDIItemInProj(
            track,
            itemStartTime,
            itemEndTime,
            true
        )

    if not item then

        reaper.PreventUIRefresh(-1)

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
    -- Force exact project-time position and length.
    --------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "D_POSITION",
        itemStartTime
    )

    reaper.SetMediaItemInfo_Value(
        item,
        "D_LENGTH",
        itemEndTime - itemStartTime
    )

    --------------------------------------------------------
    -- Do not loop MIDI source.
    --------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "B_LOOPSRC",
        0
    )

    --------------------------------------------------------
    -- MIDI beat attachment.
    --------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "C_BEATATTACHMODE",
        1
    )

    --------------------------------------------------------
    -- Take.
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
    -- Pattern boundaries are the actual item boundaries.
    --------------------------------------------------------

    local patternStartQN =
        cursorQN

    local patternEndQN =
        itemEndQN

    --------------------------------------------------------
    -- SINGLE NOTE / MEASURE
    --------------------------------------------------------

    if subdivisionChoice == 1 then

        ----------------------------------------------------
        -- Put one note at the beginning of every COMPLETE
        -- measure-sized section starting from the cursor.
        --
        -- Because the item itself is now exactly N complete
        -- measure durations, the first note is at the cursor
        -- and subsequent notes are one current-measure length
        -- apart.
        ----------------------------------------------------

        local currentQN =
            patternStartQN

        local measureLength =
            measureEndQN - measureStartQN

        while currentQN <
              patternEndQN - 0.000000001 do

            local nextQN =
                math.min(
                    currentQN + measureLength,
                    patternEndQN
                )

            insertNote(
                take,
                currentQN,
                nextQN,
                patternStartQN,
                patternEndQN
            )

            currentQN =
                nextQN
        end

    else

        ----------------------------------------------------
        -- Normal / Swing / Triplet.
        ----------------------------------------------------

        local gridQN =
            subdivisionQN[subdivisionChoice]

        if not gridQN
        or gridQN <= 0 then

            reaper.DeleteTrackMediaItem(
                track,
                item
            )

            reaper.PreventUIRefresh(-1)

            reaper.Undo_EndBlock(
                "Insert Drum MIDI",
                -1
            )

            reaper.ShowMessageBox(
                "Invalid subdivision.",
                TITLE,
                0
            )

            return
        end

        if feelChoice == 1 then

            insertNormalGrid(
                take,
                patternStartQN,
                patternEndQN,
                gridQN
            )

        elseif feelChoice == 2 then

            insertSwingGrid(
                take,
                patternStartQN,
                patternEndQN,
                gridQN
            )

        elseif feelChoice == 3 then

            insertTripletGrid(
                take,
                patternStartQN,
                patternEndQN,
                gridQN
            )
        end
    end

    --------------------------------------------------------
    -- Sort.
    --------------------------------------------------------

    reaper.MIDI_Sort(
        take
    )

    --------------------------------------------------------
    -- Select track.
    --------------------------------------------------------

    reaper.SetOnlyTrackSelected(
        track
    )

    --------------------------------------------------------
    -- Select item.
    --------------------------------------------------------

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

    reaper.PreventUIRefresh(-1)

    reaper.Undo_EndBlock(
        "Insert Drum MIDI - "
        .. instruments[instrumentChoice].name,
        -1
    )
end

------------------------------------------------------------
-- KEYBOARD / GUI
------------------------------------------------------------

local function finishInsert()

    dialogDone = true

    gfx.quit()
end

------------------------------------------------------------

local function cancelDialog()

    cancelled = true
    dialogDone = true

    gfx.quit()
end

------------------------------------------------------------
-- GUI LOOP
------------------------------------------------------------

local function guiLoop()

    local char =
        gfx.getchar()

    if char == -1 then

        cancelDialog()

        return
    end

    if char == 27 then

        cancelDialog()

        return
    end

    if char == 13 then

        finishInsert()

        return
    end

    drawWindow()

    local mouseCap =
        gfx.mouse_cap

    local leftDown =
        (mouseCap & 1) ~= 0

    local wasLeftDown =
        (lastMouseCap & 1) ~= 0

    local clicked =
        leftDown
        and
        not wasLeftDown

    if clicked then

        ----------------------------------------------------
        -- DROPDOWNS FIRST
        ----------------------------------------------------

        if mouseIn(
            fieldX,
            instrumentY,
            fieldW,
            fieldH
        ) then

            instrumentChoice =
                chooseFromList(
                    instrumentNames,
                    instrumentChoice
                )

            lastMouseCap =
                mouseCap

            reaper.defer(
                guiLoop
            )

            return

        elseif mouseIn(
            fieldX,
            subdivisionY,
            fieldW,
            fieldH
        ) then

            subdivisionChoice =
                chooseFromList(
                    subdivisionNames,
                    subdivisionChoice
                )

            lastMouseCap =
                mouseCap

            reaper.defer(
                guiLoop
            )

            return

        elseif mouseIn(
            fieldX,
            feelY,
            fieldW,
            fieldH
        ) then

            feelChoice =
                chooseFromList(
                    feelNames,
                    feelChoice
                )

            lastMouseCap =
                mouseCap

            reaper.defer(
                guiLoop
            )

            return

        elseif mouseIn(
            fieldX,
            lengthY,
            fieldW,
            fieldH
        ) then

            lengthChoice =
                chooseFromList(
                    lengthNames,
                    lengthChoice
                )

            lastMouseCap =
                mouseCap

            reaper.defer(
                guiLoop
            )

            return

        ----------------------------------------------------
        -- INSERT
        ----------------------------------------------------

        elseif mouseIn(
            insertX,
            buttonY,
            buttonW,
            buttonH
        ) then

            finishInsert()

            return

        ----------------------------------------------------
        -- CANCEL
        ----------------------------------------------------

        elseif mouseIn(
            cancelX,
            buttonY,
            buttonW,
            buttonH
        ) then

            cancelDialog()

            return
        end
    end

    --------------------------------------------------------
    -- SLIDER DRAGGING
    --------------------------------------------------------

    if leftDown then

        if mouseIn(
            sliderX,
            humanizeY + 14,
            sliderW,
            25
        ) then

            humanize =
                sliderValueFromMouse(
                    sliderX,
                    sliderW
                )

        elseif mouseIn(
            sliderX,
            intensityY + 14,
            sliderW,
            25
        ) then

            intensity =
                sliderValueFromMouse(
                    sliderX,
                    sliderW
                )
        end
    end

    lastMouseCap =
        mouseCap

    reaper.defer(
        guiLoop
    )
end

------------------------------------------------------------
-- WAIT FOR DIALOG
------------------------------------------------------------

local function waitForDialog()

    if not dialogDone then

        reaper.defer(
            waitForDialog
        )

        return
    end

    if cancelled then
        return
    end

    insertDrumPattern()
end

------------------------------------------------------------
-- OPEN WINDOW
------------------------------------------------------------
--
-- -1, -1 tells REAPER to initially center the window.
--
-- This is preferable to 0, 0 followed by manually moving
-- it from the top-left corner.
--
------------------------------------------------------------

gfx.init(
    TITLE,
    WINDOW_W,
    WINDOW_H,
    0,
    -1,
    -1
)

------------------------------------------------------------
-- CENTER AFTER NATIVE WINDOW EXISTS
------------------------------------------------------------

local centerAttempts = 0

local function centerWindowDeferred()

    centerAttempts =
        centerAttempts + 1

    centerNativeWindow()

    --------------------------------------------------------
    -- Allow the native frame to settle.
    --------------------------------------------------------

    if centerAttempts < 3 then

        reaper.defer(
            centerWindowDeferred
        )
    end
end

reaper.defer(
    centerWindowDeferred
)

------------------------------------------------------------
-- START
------------------------------------------------------------

reaper.defer(
    guiLoop
)

reaper.defer(
    waitForDialog
)
