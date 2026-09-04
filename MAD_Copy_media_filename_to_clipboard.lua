--[[
  ReaScript Name: Copy selected audio clip name to clipboard

  Copies the name of the currently selected audio media item to the system clipboard.

  Requires:
    SWS Extension (SWS 2.9.5 or newer), for cross-platform clipboard access
--]]


---------------------------------------------------------------
-- FIND SELECTED AUDIO ITEM
---------------------------------------------------------------

local function GetSelectedAudioItem()

    local item_count = reaper.CountSelectedMediaItems(0)

    for i = 0, item_count - 1 do

        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)

        if take and not reaper.TakeIsMIDI(take) then
            return item, take
        end

    end

    return nil, nil

end


---------------------------------------------------------------
-- MAIN
---------------------------------------------------------------

local item, take = GetSelectedAudioItem()


if not item then

    reaper.ShowMessageBox(
        "No selected audio clip.",
        "Copy Clip Name",
        0
    )

    return

end


---------------------------------------------------------------
-- GET SOURCE NAME
---------------------------------------------------------------

local source = reaper.GetMediaItemTake_Source(take)
local filename = reaper.GetMediaSourceFileName(source, "")

if not filename or filename == "" then

    reaper.ShowMessageBox(
        "Could not determine the audio file name.",
        "Copy Clip Name",
        0
    )

    return

end


---------------------------------------------------------------
-- GET FILE NAME ONLY
---------------------------------------------------------------

local filename_only = filename:match("([^/\\]+)$")

if not filename_only then
    filename_only = filename
end


---------------------------------------------------------------
-- COPY TO SYSTEM CLIPBOARD
---------------------------------------------------------------

if not reaper.CF_SetClipboard then

    reaper.ShowMessageBox(
        "SWS Extension is required for clipboard access.\n\n" ..
        "Please install SWS and try again.",
        "Copy Clip Name",
        0
    )

    return

end


reaper.CF_SetClipboard(filename_only)


---------------------------------------------------------------
-- NO UNDO POINT
---------------------------------------------------------------

reaper.defer(function() end)
