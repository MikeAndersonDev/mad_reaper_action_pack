--[[
  ReaScript Name: Change project playback rate by semitones

  Changes the ENTIRE PROJECT playback rate by the specified
  number of semitone steps.

  Positive values:
    Increase playback rate / pitch

  Negative values:
    Decrease playback rate / pitch

  Examples:

    1   = +1 semitone
    -1  = -1 semitone
    12  = +1 octave
    -12 = -1 octave

  The change is relative to the CURRENT project playback rate.

  Example with PITCH_STEPS = 1:

    1.000000 -> 1.059463
    1.059463 -> 1.122462
    1.122462 -> 1.189207

--]]


---------------------------------------------------------------
-- USER CONFIGURATION
---------------------------------------------------------------

local PITCH_STEPS = 1


---------------------------------------------------------------
-- GET CURRENT PROJECT PLAYBACK RATE
---------------------------------------------------------------

local current_rate =
    reaper.Master_GetPlayRate(0)


---------------------------------------------------------------
-- CALCULATE SEMITONE MULTIPLIER
---------------------------------------------------------------

local rate_multiplier =
    2 ^ (PITCH_STEPS / 12)


---------------------------------------------------------------
-- CALCULATE NEW PLAYBACK RATE
---------------------------------------------------------------

local new_rate =
    current_rate * rate_multiplier


---------------------------------------------------------------
-- SET PROJECT PLAYBACK RATE
---------------------------------------------------------------

reaper.CSurf_OnPlayRateChange(new_rate)


---------------------------------------------------------------
-- UPDATE
---------------------------------------------------------------

reaper.UpdateArrange()
