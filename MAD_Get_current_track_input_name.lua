--[[
  ReaScript Name: Get selected track record input name

  Reads the record input from the selected track and reports
  it by name.

  Examples:

    Mono:
      Input L

    Stereo:
      Input L/Input R

    MIDI:
      MIDI input

    None:
      None

  If multiple tracks are selected, the input of the first selected track is reported.
--]]


---------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------

local STEREO_OFFSET = 1024
local MIDI_OFFSET   = 4096


---------------------------------------------------------------
-- GET INPUT NAME
---------------------------------------------------------------

function GetRecordInputName(track)

  local rec_input =
    reaper.GetMediaTrackInfo_Value(
      track,
      "I_RECINPUT"
    )


  -------------------------------------------------------------
  -- INPUT: NONE
  -------------------------------------------------------------

  if rec_input < 0 then

    return "None"

  end


  -------------------------------------------------------------
  -- MIDI INPUT
  -------------------------------------------------------------

  if rec_input >= MIDI_OFFSET then

    return "MIDI"

  end


  -------------------------------------------------------------
  -- STEREO AUDIO INPUT
  -------------------------------------------------------------

  if rec_input >= STEREO_OFFSET then

    local first_input =
      rec_input - STEREO_OFFSET


    local left_name =
      reaper.GetInputChannelName(first_input)


    local right_name =
      reaper.GetInputChannelName(first_input + 1)


    if left_name and right_name then

      return left_name .. "/" .. right_name

    elseif left_name then

      return left_name

    else

      return "Unknown stereo input"

    end

  end


  -------------------------------------------------------------
  -- MONO AUDIO INPUT
  -------------------------------------------------------------

  local input_index = rec_input

  local input_name =
    reaper.GetInputChannelName(input_index)


  if input_name then

    return input_name

  end


  return "Unknown input"

end


---------------------------------------------------------------
-- MAIN
---------------------------------------------------------------

function Main()

  local selected_count =
    reaper.CountSelectedTracks(0)


  if selected_count == 0 then

    reaper.ShowMessageBox(
      "No tracks are selected.",
      "Get Record Input",
      0
    )

    return

  end


  -------------------------------------------------------------
  -- Get first selected track
  -------------------------------------------------------------

  local track =
    reaper.GetSelectedTrack(0, 0)


  local input_name =
    GetRecordInputName(track)


  -------------------------------------------------------------
  -- Display result
  -------------------------------------------------------------

  reaper.ShowMessageBox(
    "Record input:\n\n" ..
    input_name,
    "Current Record Input",
    0
  )

end


---------------------------------------------------------------
-- RUN
---------------------------------------------------------------

Main()
