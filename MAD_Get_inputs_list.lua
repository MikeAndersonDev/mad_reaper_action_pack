local inputs = {}
local count = reaper.GetNumAudioInputs()

for i = 0, count - 1 do
    local name = reaper.GetInputChannelName(i)
    if name then
        inputs[#inputs + 1] = name
    end
end

reaper.ShowMessageBox(
    table.concat(inputs, ", "),
    "Audio Inputs",
    0
)
