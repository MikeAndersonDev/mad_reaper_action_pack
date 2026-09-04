--[[
  ReaScript Name: Set selected tracks record input by name

  INPUT_NAME determines the record mode:

    Mono:
      INPUT_NAME = "Input L"

    Stereo:
      INPUT_NAME = "Input L/Input R"

  Multiple input names are separated with "/".

  One name  = mono
  Two names = stereo

  If a selected track is ALREADY set to INPUT_NAME,
  it will instead be set to Input: None.

  The names must exactly match the names reported by REAPER.
--]]


---------------------------------------------------------------
-- USER CONFIGURATION
---------------------------------------------------------------

INPUT_NAME = "AxeFx2 L"

-- Set this to true if you want matching to ignore
-- capitalization.
IGNORE_CASE = false


---------------------------------------------------------------
-- STRING TRIM
---------------------------------------------------------------

function Trim(str)

  return str:match("^%s*(.-)%s*$")

end


---------------------------------------------------------------
-- COMPARE INPUT NAMES
---------------------------------------------------------------

function NamesMatch(name1, name2)

  name1 = Trim(name1)
  name2 = Trim(name2)

  if IGNORE_CASE then
    return name1:lower() == name2:lower()
  else
    return name1 == name2
  end

end


---------------------------------------------------------------
-- GET ALL REAPER AUDIO INPUTS
---------------------------------------------------------------

function GetAudioInputs()

  local inputs = {}

  local count = reaper.GetNumAudioInputs()

  for i = 0, count - 1 do

    local name = reaper.GetInputChannelName(i)

    if name then

      inputs[#inputs + 1] = {
        index = i,
        name = name
      }

    end

  end

  return inputs

end


---------------------------------------------------------------
-- FIND INPUT BY NAME
---------------------------------------------------------------

function FindInputByName(name, inputs)

  for _, input in ipairs(inputs) do

    if NamesMatch(input.name, name) then

      return input.index

    end

  end

  return nil

end


---------------------------------------------------------------
-- SPLIT INPUT_NAME USING "/"
---------------------------------------------------------------

function ParseInputNames(input_string)

  local names = {}

  for name in input_string:gmatch("[^/]+") do

    name = Trim(name)

    if name ~= "" then
      names[#names + 1] = name
    end

  end

  return names

end


---------------------------------------------------------------
-- BUILD LIST OF AVAILABLE INPUTS
---------------------------------------------------------------

function GetAvailableInputs(inputs)

  local result = ""

  for _, input in ipairs(inputs) do

    if result ~= "" then
      result = result .. ", "
    end

    result = result ..
      tostring(input.index) ..
      " = " ..
      input.name

  end

  return result

end


---------------------------------------------------------------
-- MAIN
---------------------------------------------------------------

function Main()

  -------------------------------------------------------------
  -- Get all available audio inputs
  -------------------------------------------------------------

  local inputs = GetAudioInputs()


  -------------------------------------------------------------
  -- Parse INPUT_NAME
  -------------------------------------------------------------

  local requested_names =
    ParseInputNames(INPUT_NAME)


  -------------------------------------------------------------
  -- Validate number of names
  -------------------------------------------------------------

  if #requested_names == 0 then

    reaper.ShowMessageBox(
      "INPUT_NAME is empty.",
      "Set Record Input",
      0
    )

    return false

  end


  if #requested_names > 2 then

    reaper.ShowMessageBox(
      "Too many input names were specified.\n\n" ..
      "Use either:\n\n" ..
      "One name for mono:\n" ..
      "  Input 1\n\n" ..
      "Two names for stereo:\n" ..
      "  Input 1/Input 2",
      "Invalid Input",
      0
    )

    return false

  end


  -------------------------------------------------------------
  -- Find requested input(s)
  -------------------------------------------------------------

  local input_indices = {}

  for _, name in ipairs(requested_names) do

    local index =
      FindInputByName(name, inputs)

    if index == nil then

      reaper.ShowMessageBox(
        "Could not find this audio input:\n\n" ..
        '"' .. name .. '"' ..
        "\n\n" ..
        "Available inputs:\n\n" ..
        GetAvailableInputs(inputs),
        "Input Not Found",
        0
      )

      return false

    end

    input_indices[#input_indices + 1] = index

  end


  -------------------------------------------------------------
  -- Determine mono / stereo
  -------------------------------------------------------------

  local set_track_input
  local mode


  if #input_indices == 1 then

    -----------------------------------------------------------
    -- MONO
    -----------------------------------------------------------

    mode = "mono"

    set_track_input = input_indices[1]


  elseif #input_indices == 2 then

    -----------------------------------------------------------
    -- STEREO
    -----------------------------------------------------------

    mode = "stereo"

    local left_index = input_indices[1]
    local right_index = input_indices[2]


    -----------------------------------------------------------
    -- Stereo channels must be adjacent
    -----------------------------------------------------------

    if right_index ~= left_index + 1 then

      reaper.ShowMessageBox(
        "The requested stereo inputs are not adjacent.\n\n" ..
        requested_names[1] ..
        " = input " ..
        left_index ..
        "\n" ..
        requested_names[2] ..
        " = input " ..
        right_index ..
        "\n\n" ..
        "For a stereo input, the channels must be adjacent.",
        "Invalid Stereo Pair",
        0
      )

      return false

    end


    -----------------------------------------------------------
    -- REAPER stereo input encoding
    -----------------------------------------------------------

    set_track_input = 1024 + left_index

  end


  -------------------------------------------------------------
  -- Set selected tracks
  -------------------------------------------------------------

  for i = 0, count_sel_tracks - 1 do

    local track =
      reaper.GetSelectedTrack(0, i)

    local current_input =
      reaper.GetMediaTrackInfo_Value(
        track,
        "I_RECINPUT"
      )


    -----------------------------------------------------------
    -- INPUT ALREADY SELECTED
    --
    -- Toggle it to Input: None
    -----------------------------------------------------------

    if current_input == set_track_input then

      reaper.SetMediaTrackInfo_Value(
        track,
        "I_RECINPUT",
        -1
      )


    -----------------------------------------------------------
    -- DIFFERENT INPUT
    --
    -- Set requested input
    -----------------------------------------------------------

    else

      reaper.SetMediaTrackInfo_Value(
        track,
        "I_RECINPUT",
        set_track_input
      )

    end

  end


  -------------------------------------------------------------
  -- Update REAPER
  -------------------------------------------------------------

  reaper.TrackList_AdjustWindows(false)

  return true

end


---------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------

function Init()

  count_sel_tracks =
    reaper.CountSelectedTracks(0)


  if count_sel_tracks == 0 then

    reaper.ShowMessageBox(
      "No tracks are selected.",
      "Set Record Input",
      0
    )

    return

  end


  reaper.PreventUIRefresh(1)

  reaper.Undo_BeginBlock()


  local success = Main()


  if success then

    reaper.Undo_EndBlock(
      "Toggle selected tracks record input: " ..
      INPUT_NAME,
      0
    )

  else

    reaper.Undo_EndBlock(
      "Set selected tracks record input - failed",
      0
    )

  end


  reaper.PreventUIRefresh(-1)

end


---------------------------------------------------------------
-- RUN
---------------------------------------------------------------

Init()
