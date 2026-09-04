--[[
    REAPER Lua Action
    Insert Hi-Hat count-in MIDI, for One Bar

    TIME-SIGNATURE-AWARE HI-HAT GENERATOR

    Requirement: JS_ReaScriptAPI, REAPER extension for reliable window positioning.


    Popup:
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
        Note     = 42 (GM Closed Hi-Hat)
        Channel  = 10 (zero-based channel 9)
        Velocity = 100

    The MIDI item:
        - Is exactly one project measure long
        - Starts at the exact measure boundary
        - Ends at the exact measure boundary
        - Does not loop
        - Uses the current project time signature

    FEEL BEHAVIOR

        Normal:
            Evenly spaced selected subdivisions.

        Swing:
            Pairs of subdivisions use a 2:1 long/short ratio.

            Example: Eighths

                1     &     2     &
                X           X     X
                <---2---><--1-->

            Swing is applied to pairs of the selected
            subdivision.

        Triplet:
            Each normal subdivision is divided into
            three evenly spaced triplet positions.

    TIME SIGNATURE EXAMPLES

        3/4:
            Quarter = 3
            Eighth  = 6
            16th    = 12

        4/4:
            Quarter = 4
            Eighth  = 8
            16th    = 16

        6/8:
            Eighth         = 6
            Dotted-quarter = 2

        9/8:
            Eighth         = 9
            Dotted-quarter = 3

        12/8:
            Eighth         = 12
            Dotted-quarter = 4
]]

------------------------------------------------------------
-- CONFIGURATION
------------------------------------------------------------

local PROJ = 0

local WINDOW_W = 320
local WINDOW_H = 190

local TITLE = "Insert Hi-Hat MIDI"

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

-- Number of selected notes per quarter note.
local subdivisionValues = {
    1,      -- Quarter
    2,      -- Eighth
    4,      -- Sixteenth
    8,      -- 32nd
    16      -- 64th
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
-- MIDI SETTINGS
------------------------------------------------------------

local MIDI_NOTE = 42
local MIDI_CHANNEL = 9       -- MIDI channel 10, zero-based
local MIDI_VELOCITY = 100

------------------------------------------------------------
-- DEFAULTS
------------------------------------------------------------

local subdivisionChoice = 1  -- Quarter
local feelChoice = 1         -- Normal

------------------------------------------------------------
-- SELECTED TRACK
------------------------------------------------------------

local track = reaper.GetSelectedTrack(PROJ, 0)

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
    background = {0.115, 0.115, 0.125, 1.0},
    panel      = {0.155, 0.155, 0.170, 1.0},
    border     = {0.32,  0.32,  0.35,  1.0},
    text       = {0.92,  0.92,  0.94,  1.0},
    label      = {0.68,  0.68,  0.72,  1.0},
    blue       = {0.20,  0.48,  0.78,  1.0},
    blueHover  = {0.25,  0.55,  0.88,  1.0},
    button     = {0.22,  0.22,  0.24,  1.0},
    hover      = {0.28,  0.28,  0.31,  1.0},
    white      = {1.0, 1.0, 1.0, 1.0}
}

------------------------------------------------------------
-- COLOR HELPER
------------------------------------------------------------

local function setColor(c)
    gfx.set(c[1], c[2], c[3], c[4])
end

------------------------------------------------------------
-- RECTANGLE HELPER
------------------------------------------------------------

local function drawRect(x, y, w, h, color, filled)
    setColor(color)
    gfx.rect(x, y, w, h, filled ~= false)
end

------------------------------------------------------------
-- MOUSE HIT TEST
------------------------------------------------------------

local function mouseIn(x, y, w, h)
    return gfx.mouse_x >= x
       and gfx.mouse_x <= x + w
       and gfx.mouse_y >= y
       and gfx.mouse_y <= y + h
end

------------------------------------------------------------
-- DRAW BUTTON
------------------------------------------------------------

local function drawButton(x, y, w, h, text, hovered, primary)

    local color

    if primary then
        color = hovered and COLORS.blueHover or COLORS.blue
    else
        color = hovered and COLORS.hover or COLORS.button
    end

    drawRect(x, y, w, h, color, true)

    setColor(COLORS.border)
    gfx.rect(x, y, w, h, false)

    gfx.setfont(1, "Arial", 14)
    setColor(COLORS.white)

    local tw = gfx.measurestr(text)

    gfx.x = x + (w - tw) * 0.5
    gfx.y = y + (h - 14) * 0.5

    gfx.drawstr(text)
end

------------------------------------------------------------
-- DRAW DROPDOWN
------------------------------------------------------------

local function drawDropdown(x, y, w, h, text, hovered)

    local color = hovered and COLORS.hover or COLORS.panel

    drawRect(x, y, w, h, color, true)

    setColor(COLORS.border)
    gfx.rect(x, y, w, h, false)

    --------------------------------------------------------
    -- Text
    --------------------------------------------------------

    gfx.setfont(1, "Arial", 14)
    setColor(COLORS.text)

    gfx.x = x + 10
    gfx.y = y + (h - 14) * 0.5

    gfx.drawstr(text)

    --------------------------------------------------------
    -- Dropdown arrow
    --------------------------------------------------------

    local arrowX = x + w - 20
    local arrowY = y + h * 0.5

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
-- SHOW DROPDOWN
------------------------------------------------------------

local function showDropdown(items, current)

    local menu = table.concat(items, "|")

    local selected = gfx.showmenu(menu)

    if selected >= 1 and selected <= #items then
        return selected
    end

    return current
end

------------------------------------------------------------
-- INSERT NOTE HELPER
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

    endQN = math.min(endQN, barEndQN)

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

    --------------------------------------------------------
    -- Short hi-hat note.
    --
    -- 25% of the interval, minimum 1 PPQ.
    --------------------------------------------------------

    local spacingPPQ = endPPQ - startPPQ

    local noteLengthPPQ =
        math.max(
            1,
            spacingPPQ * 0.25
        )

    local noteEndPPQ =
        math.min(
            startPPQ + noteLengthPPQ,
            reaper.MIDI_GetPPQPosFromProjQN(
                take,
                barEndQN
            )
        )

    if noteEndPPQ > startPPQ then

        reaper.MIDI_InsertNote(
            take,
            false,              -- selected
            false,              -- muted
            startPPQ,
            noteEndPPQ,
            MIDI_CHANNEL,
            MIDI_NOTE,
            MIDI_VELOCITY,
            true                -- noSort
        )
    end
end

------------------------------------------------------------
-- INSERT NORMAL GRID
------------------------------------------------------------

local function insertNormalGrid(
    take,
    qnStart,
    qnEnd,
    subdivisionQN
)

    local currentQN = qnStart

    while currentQN < qnEnd - 0.0000001 do

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

        currentQN = nextQN
    end
end

------------------------------------------------------------
-- INSERT SWING GRID
------------------------------------------------------------

local function insertSwingGrid(
    take,
    qnStart,
    qnEnd,
    subdivisionQN
)

    --------------------------------------------------------
    -- Swing works in pairs.
    --
    -- A pair has the duration of:
    --
    --     2 x subdivision
    --
    -- The first note occupies 2/3 of the pair.
    -- The second note occurs at 2/3.
    --
    -- This produces a 2:1 long-short relationship.
    --
    -- Example with eighth notes:
    --
    -- Straight:
    --     0.0     0.5
    --
    -- Swing:
    --     0.0     0.6667
    --
    --------------------------------------------------------

    local pairQN = subdivisionQN * 2.0

    local currentQN = qnStart

    while currentQN < qnEnd - 0.0000001 do

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
        -- For a complete pair:
        --
        -- first position = 0
        -- second position = 2/3
        ----------------------------------------------------

        local firstQN = currentQN

        local secondQN =
            currentQN + pairLength * (2.0 / 3.0)

        ----------------------------------------------------
        -- First note
        ----------------------------------------------------

        insertNote(
            take,
            firstQN,
            secondQN,
            qnEnd
        )

        ----------------------------------------------------
        -- Second note
        --
        -- Only insert if there is enough room.
        ----------------------------------------------------

        if secondQN < pairEndQN - 0.0000001 then

            insertNote(
                take,
                secondQN,
                pairEndQN,
                qnEnd
            )
        end

        currentQN = pairEndQN
    end
end

------------------------------------------------------------
-- INSERT TRIPLET GRID
------------------------------------------------------------

local function insertTripletGrid(
    take,
    qnStart,
    qnEnd,
    subdivisionQN
)

    --------------------------------------------------------
    -- One normal subdivision is divided into 3 parts.
    --
    -- Example:
    --
    -- Eighth = 0.5 QN
    --
    -- Triplet positions:
    --
    -- 0
    -- 0.1666667
    -- 0.3333333
    --
    -- then next eighth:
    -- 0.5
    --
    --------------------------------------------------------

    local tripletQN =
        subdivisionQN / 3.0

    local currentQN = qnStart

    while currentQN < qnEnd - 0.0000001 do

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

        currentQN = nextQN
    end
end

------------------------------------------------------------
-- INSERT HI-HAT
------------------------------------------------------------

local function insertHiHat()

    --------------------------------------------------------
    -- Get exact first measure information.
    --------------------------------------------------------

    local measureStartTime,
          qnStart,
          qnEnd,
          numerator,
          denominator,
          tempo =
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

    --------------------------------------------------------
    -- Validate QN range.
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
    -- Get exact measure end in project time.
    --
    -- TimeMap2_QNToTime takes the project and QN.
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
    -- Get time signature.
    --------------------------------------------------------

    numerator =
        tonumber(numerator) or 4

    denominator =
        tonumber(denominator) or 4

    --------------------------------------------------------
    -- Actual bar length.
    --
    -- We intentionally use the QN range returned by REAPER
    -- rather than calculating the bar ourselves.
    --
    -- This makes the script safe with:
    --
    -- 2/4
    -- 3/4
    -- 4/4
    -- 5/4
    -- 6/8
    -- 7/8
    -- 9/8
    -- 12/8
    -- etc.
    --------------------------------------------------------

    local barQN =
        qnEnd - qnStart

    if barQN <= 0 then

        reaper.ShowMessageBox(
            "The measure duration is invalid.",
            TITLE,
            0
        )

        return
    end

    --------------------------------------------------------
    -- Base subdivision.
    --------------------------------------------------------

    local subdivisionQN =
        1.0 /
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
    -- BEGIN UNDO
    --------------------------------------------------------

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    --------------------------------------------------------
    -- CREATE EXACT ONE-BAR MIDI ITEM
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
            "Insert Hi-Hat MIDI - Exactly One Bar",
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
    -- FORCE EXACT ITEM BOUNDARIES
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

    --------------------------------------------------------
    -- DISABLE MIDI SOURCE LOOPING
    --------------------------------------------------------

    reaper.SetMediaItemInfo_Value(
        item,
        "B_LOOPSRC",
        0
    )

    --------------------------------------------------------
    -- GET MIDI TAKE
    --------------------------------------------------------

    local take =
        reaper.GetActiveTake(item)

    if not take
    or not reaper.TakeIsMIDI(take) then

        reaper.DeleteTrackMediaItem(
            track,
            item
        )

        reaper.PreventUIRefresh(-1)

        reaper.Undo_EndBlock(
            "Insert Hi-Hat MIDI - Exactly One Bar",
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
    -- GENERATE THE SELECTED FEEL
    --------------------------------------------------------

    if feelChoice == 1 then

        ----------------------------------------------------
        -- NORMAL
        ----------------------------------------------------

        insertNormalGrid(
            take,
            qnStart,
            qnEnd,
            subdivisionQN
        )

    elseif feelChoice == 2 then

        ----------------------------------------------------
        -- SWING
        ----------------------------------------------------

        insertSwingGrid(
            take,
            qnStart,
            qnEnd,
            subdivisionQN
        )

    elseif feelChoice == 3 then

        ----------------------------------------------------
        -- TRIPLET
        ----------------------------------------------------

        insertTripletGrid(
            take,
            qnStart,
            qnEnd,
            subdivisionQN
        )
    end

    --------------------------------------------------------
    -- SORT MIDI
    --------------------------------------------------------

    reaper.MIDI_Sort(take)

    --------------------------------------------------------
    -- SELECT NEW ITEM
    --------------------------------------------------------

    reaper.SetOnlyTrackSelected(track)

    reaper.SetMediaItemSelected(
        item,
        true
    )

    --------------------------------------------------------
    -- UPDATE
    --------------------------------------------------------

    reaper.UpdateItemInProject(item)
    reaper.UpdateArrange()

    reaper.PreventUIRefresh(-1)

    reaper.Undo_EndBlock(
        "Insert Hi-Hat MIDI - Exactly One Bar",
        -1
    )
end

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
-- GUI LOOP
------------------------------------------------------------

local function main()

    local char = gfx.getchar()

    --------------------------------------------------------
    -- Window closed
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
    -- DRAW
    --------------------------------------------------------

    drawWindow()

    --------------------------------------------------------
    -- MOUSE
    --------------------------------------------------------

    local mouseCap =
        gfx.mouse_cap

    local clicked =
        ((mouseCap & 1) ~= 0)
        and
        ((lastMouseCap & 1) == 0)

    if clicked then

        ----------------------------------------------------
        -- Subdivision dropdown
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
        -- Feel dropdown
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
        -- Insert
        ----------------------------------------------------

        elseif mouseIn(
            insertX,
            buttonY,
            buttonW,
            buttonH
        ) then

            dialogDone = true

            gfx.quit()

            lastMouseCap = mouseCap

            return

        ----------------------------------------------------
        -- Cancel
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

            lastMouseCap = mouseCap

            return
        end
    end

    lastMouseCap = mouseCap

    --------------------------------------------------------
    -- Continue
    --------------------------------------------------------

    reaper.defer(main)
end

------------------------------------------------------------
-- WAIT FOR DIALOG
------------------------------------------------------------

local function waitForDialog()

    if not dialogDone then
        reaper.defer(waitForDialog)
        return
    end

    if cancelled then
        return
    end

    insertHiHat()
end

------------------------------------------------------------
-- OPEN WINDOW AND CENTER IT OVER REAPER
------------------------------------------------------------

gfx.init(
    TITLE,
    WINDOW_W,
    WINDOW_H,
    0,
    0,
    0
)

------------------------------------------------------------
-- Center the actual gfx window AFTER it exists.
------------------------------------------------------------

local function centerPopup()

    -- JS_ReaScriptAPI required for reliable positioning.
    if not reaper.JS_Window_Find
    or not reaper.JS_Window_GetRect
    or not reaper.JS_Window_SetPosition then

        return
    end

    --------------------------------------------------------
    -- Find the gfx popup window.
    --------------------------------------------------------

    local popupHWND =
        reaper.JS_Window_Find(
            TITLE,
            true
        )

    if not popupHWND then
        return
    end

    --------------------------------------------------------
    -- Get REAPER main-window rectangle.
    --------------------------------------------------------

    local mainHWND =
        reaper.GetMainHwnd()

    if not mainHWND then
        return
    end

    local mainOK,
          mainLeft,
          mainTop,
          mainRight,
          mainBottom =
        reaper.JS_Window_GetRect(
            mainHWND
        )

    if not mainOK then
        return
    end

    --------------------------------------------------------
    -- Get actual popup rectangle.
    --------------------------------------------------------

    local popupOK,
          popupLeft,
          popupTop,
          popupRight,
          popupBottom =
        reaper.JS_Window_GetRect(
            popupHWND
        )

    if not popupOK then
        return
    end

    --------------------------------------------------------
    -- Actual popup dimensions.
    --------------------------------------------------------

    local popupWidth =
        popupRight - popupLeft

    local popupHeight =
        popupBottom - popupTop

    --------------------------------------------------------
    -- REAPER window dimensions.
    --------------------------------------------------------

    local mainWidth =
        mainRight - mainLeft

    local mainHeight =
        mainBottom - mainTop

    --------------------------------------------------------
    -- Calculate exact center.
    --------------------------------------------------------

    local newX =
        math.floor(
            mainLeft +
            (mainWidth - popupWidth) / 2
        )

    local newY =
        math.floor(
            mainTop +
            (mainHeight - popupHeight) / 2
        )

    --------------------------------------------------------
    -- Move the actual popup window.
    --------------------------------------------------------

    reaper.JS_Window_SetPosition(
        popupHWND,
        newX,
        newY,
        popupWidth,
        popupHeight
    )
end

------------------------------------------------------------
-- Give Windows/macOS/Linux a moment to create the
-- gfx window, then center it.
------------------------------------------------------------

centerPopup()

------------------------------------------------------------
-- Start GUI
------------------------------------------------------------

main()
reaper.defer(waitForDialog)
