--[[
  ReaScript Name: Toggle selected tracks pan width 100% / 0%

  Toggles track pan width between:

    100% = Stereo
      0% = Mono

  Does not change:
    - Track pan
    - Record input
    - Track channel count
    - Routing
--]]


---------------------------------------------------------------
-- USER CONFIGURATION
---------------------------------------------------------------

local STEREO_WIDTH = 1.0
local MONO_WIDTH   = 0.0


---------------------------------------------------------------
-- GET SELECTED TRACK COUNT
---------------------------------------------------------------

local track_count =
    reaper.CountSelectedTracks(0)

if track_count == 0 then
    return
end


---------------------------------------------------------------
-- BEGIN UNDO
---------------------------------------------------------------

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)


---------------------------------------------------------------
-- TOGGLE WIDTH
---------------------------------------------------------------

for i = 0, track_count - 1 do

    local track =
        reaper.GetSelectedTrack(0, i)

    local current_width =
        reaper.GetMediaTrackInfo_Value(
            track,
            "D_WIDTH"
        )


    -----------------------------------------------------------
    -- Stereo (100%) -> Mono (0%)
    -----------------------------------------------------------

    if current_width > 0.5 then

        reaper.SetMediaTrackInfo_Value(
            track,
            "D_WIDTH",
            MONO_WIDTH
        )


    -----------------------------------------------------------
    -- Mono (0%) -> Stereo (100%)
    -----------------------------------------------------------

    else

        reaper.SetMediaTrackInfo_Value(
            track,
            "D_WIDTH",
            STEREO_WIDTH
        )

    end

end


---------------------------------------------------------------
-- UPDATE REAPER
---------------------------------------------------------------

reaper.PreventUIRefresh(-1)

reaper.TrackList_AdjustWindows(false)

reaper.UpdateArrange()


---------------------------------------------------------------
-- UNDO
---------------------------------------------------------------

reaper.Undo_EndBlock(
    "Toggle selected tracks width 100% / 0%",
    -1
)
