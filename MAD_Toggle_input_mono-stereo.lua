--[[
  ReaScript Name: Toggle selected audio tracks mono/stereo input

  Behavior:

    MONO -> STEREO

      Mono 1 -> Stereo 1/2
      Mono 2 -> Stereo 1/2
      Mono 3 -> Stereo 3/4
      Mono 4 -> Stereo 3/4
      etc.


    STEREO -> MONO

      Stereo 1/2 -> Mono 1
      Stereo 3/4 -> Mono 3
      Stereo 5/6 -> Mono 5
      etc.


  Tracks with:

    - Input: None
    - MIDI input

  are ignored.

  REAPER I_RECINPUT encoding:

    Mono audio:
      0, 1, 2, 3, ...

    Stereo audio:
      1024 + first_channel_index

    MIDI:
      4096 + MIDI device/channel information

    None:
      -1
--]]


---------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------

local STEREO_OFFSET = 1024
local MIDI_OFFSET   = 4096


---------------------------------------------------------------
-- CHECK FOR NONE
---------------------------------------------------------------

local function IsInputNone(rec_input)

  return rec_input < 0

end


---------------------------------------------------------------
-- CHECK FOR MIDI
---------------------------------------------------------------

local function IsMIDIInput(rec_input)

  -- REAPER MIDI inputs use values starting at 4096.
  return rec_input >= MIDI_OFFSET

end


---------------------------------------------------------------
-- CHECK FOR STEREO AUDIO
---------------------------------------------------------------

local function IsStereoInput(rec_input)

  return rec_input >= STEREO_OFFSET
     and rec_input < MIDI_OFFSET

end


---------------------------------------------------------------
-- MONO -> STEREO
---------------------------------------------------------------

local function MonoToStereo(mono_index)

  -- Find the first channel of the stereo pair.
  --
  -- 0 -> 0
  -- 1 -> 0
  -- 2 -> 2
  -- 3 -> 2
  -- 4 -> 4
  -- 5 -> 4

  local first_index =
    math.floor(mono_index / 2) * 2

  return STEREO_OFFSET + first_index

end


---------------------------------------------------------------
-- STEREO -> MONO
---------------------------------------------------------------

local function StereoToMono(stereo_value)

  return stereo_value - STEREO_OFFSET

end


---------------------------------------------------------------
-- TOGGLE ONE TRACK
---------------------------------------------------------------

local function ToggleTrackInput(track)

  local rec_input =
    reaper.GetMediaTrackInfo_Value(
      track,
      "I_RECINPUT"
    )


  -------------------------------------------------------------
  -- INPUT: NONE
  -------------------------------------------------------------

  if IsInputNone(rec_input) then

    return false

  end


  -------------------------------------------------------------
  -- MIDI INPUT
  -------------------------------------------------------------

  if IsMIDIInput(rec_input) then

    return false

  end


  -------------------------------------------------------------
  -- STEREO AUDIO -> MONO
  -------------------------------------------------------------

  if IsStereoInput(rec_input) then

    local mono_input =
      StereoToMono(rec_input)


    reaper.SetMediaTrackInfo_Value(
      track,
      "I_RECINPUT",
      mono_input
    )


    return true

  end


  -------------------------------------------------------------
  -- MONO AUDIO -> STEREO
  -------------------------------------------------------------

  local stereo_input =
    MonoToStereo(rec_input)


  reaper.SetMediaTrackInfo_Value(
    track,
    "I_RECINPUT",
    stereo_input
  )


  return true

end


---------------------------------------------------------------
-- MAIN
---------------------------------------------------------------

local function Main()

  local count =
    reaper.CountSelectedTracks(0)


  if count == 0 then
    return 0
  end


  local changed = 0


  for i = 0, count - 1 do

    local track =
      reaper.GetSelectedTrack(0, i)


    if ToggleTrackInput(track) then

      changed = changed + 1

    end

  end


  return changed

end


---------------------------------------------------------------
-- RUN
---------------------------------------------------------------

reaper.Undo_BeginBlock()

reaper.PreventUIRefresh(1)


Main()


reaper.PreventUIRefresh(-1)

reaper.TrackList_AdjustWindows(false)


reaper.Undo_EndBlock(
  "Toggle selected audio tracks mono/stereo input",
  0
)
