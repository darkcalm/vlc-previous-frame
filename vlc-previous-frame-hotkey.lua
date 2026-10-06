-- VLC 3 startup interface: W seeks backward using local video frame timestamps.
-- Install in lua/intf; extraintf=luaintf; lua-intf=vlc-previous-frame-hotkey.
-- macOS requires key-pause=w so it forwards W into key-pressed.
local core = vlc.object.libvlc()
local cache_uri, frames, last_target, last_observed
local pending_forward, pending_origin, pending_uri = 0, nil, nil
local previous_state
local function quote(s) return string.char(39) .. s:gsub(string.char(39), string.char(39,34,39,34,39)) .. string.char(39) end
local function backward()
    local input = vlc.object.input()
    local item = vlc.input.item()
    if not input or not item then return end
    local uri = item:uri()
    if not uri or not uri:match("^file://") then
        vlc.msg.warn("Previous frame requires a local video file")
        return
    end
    vlc.var.set(input, "state", 3) -- pause, without toggling playback
    vlc.misc.mwait(vlc.misc.mdate() + 50000)
    local now = vlc.var.get(input, "time") / 1000000
    if cache_uri ~= uri then frames, last_target, last_observed = nil, nil, nil end
    local current = (pending_uri == uri and pending_origin) or now
    if last_target and last_observed and math.abs(now - last_observed) < 0.002 then
        current = last_target
    end
    if not frames or current < frames[1] or current > frames[#frames] then
        local path = vlc.strings.decode_uri(uri:gsub("^file://", ""))
        local interval = string.format("%.6f%%%.6f", math.max(0, current - 10), current + 3 + pending_forward)
        local command = "/opt/homebrew/bin/ffprobe -v error -select_streams v:0 -read_intervals "
            .. quote(interval) .. " -show_frames -show_entries frame=best_effort_timestamp_time -of csv=p=0 "
            .. quote(path) .. " 2>/dev/null"
        local pipe = io.popen(command, "r")
        if not pipe then return end
        frames = {}
        for line in pipe:lines() do
            local timestamp = tonumber(line:match("^([%d%.%-]+)"))
            if timestamp then frames[#frames + 1] = timestamp end
        end
        pipe:close()
        if #frames == 0 then frames = nil; vlc.msg.warn("No frame timestamps available"); return end
        table.sort(frames)
        cache_uri = uri
    end
    if current > frames[#frames] + 0.1 then
        vlc.msg.warn("Frame scan did not reach current position; refusing a large backward jump")
        frames = nil
        return
    end
    -- Time may sit between two frame timestamps; identify that frame first.
    local index = 1
    for i, timestamp in ipairs(frames) do
        if timestamp <= current + 0.002 then index = i else break end
    end
    if pending_uri == uri then index = math.min(#frames, index + pending_forward) end
    pending_forward, pending_origin, pending_uri = 0, nil, nil
    local target = math.max(0, frames[math.max(1, index - 1)])
    vlc.var.set(input, "time", math.floor(target * 1000000 + 0.5))
    last_target = target
    vlc.misc.mwait(vlc.misc.mdate() + 150000)
    last_observed = vlc.var.get(input, "time") / 1000000
    vlc.msg.info(string.format("Previous frame: %.6f -> %.6f", current, target))
end
local function forward_observed()
    local input = vlc.object.input()
    local item = vlc.input.item()
    if not input or not item then return end
    if previous_state == 2 then
        -- Native E first pauses a playing video; it does not advance a frame.
        last_target, last_observed = nil, nil
        pending_forward, pending_origin, pending_uri = 0, nil, nil
        return
    end
    if cache_uri ~= item:uri() or not frames then
        if pending_uri ~= item:uri() then
            pending_forward = 0
            pending_origin = vlc.var.get(input, "time") / 1000000
            pending_uri = item:uri()
        end
        pending_forward = pending_forward + 1
        last_target, last_observed = nil, nil
        return
    end
    local now = vlc.var.get(input, "time") / 1000000
    if not last_target or not last_observed or math.abs(now - last_observed) > 0.002 then
        last_target = now
    end
    for _, timestamp in ipairs(frames) do
        if timestamp > last_target + 0.002 then
            last_target = timestamp
            vlc.misc.mwait(vlc.misc.mdate() + 80000)
            last_observed = vlc.var.get(input, "time") / 1000000
            return
        end
    end
    last_target, last_observed = nil, nil
end
vlc.msg.info("Previous-frame listener ready: W (video window focused)")
while true do
    local key = vlc.var.get(core, "key-pressed")
    if key == string.byte("w") then
        vlc.var.set(core, "key-pressed", 0)
        local ok, err = pcall(backward)
        if not ok then vlc.msg.err("Previous frame: " .. tostring(err)) end
    elseif key == string.byte("e") then
        vlc.var.set(core, "key-pressed", 0)
        local ok, err = pcall(forward_observed)
        if not ok then vlc.msg.err("Frame tracking: " .. tostring(err)) end
    end
    local input = vlc.object.input()
    previous_state = input and vlc.var.get(input, "state") or nil
    if previous_state ~= 3 then
        last_target, last_observed = nil, nil
        pending_forward, pending_origin, pending_uri = 0, nil, nil
    end
    vlc.misc.mwait(vlc.misc.mdate() + 10000)
end
