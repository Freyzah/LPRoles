-- LPRoles - sound files made ready for the engine's media player.
--
-- The media player stops sending the sound out as soon as it has read the end of the file,
-- while the last fraction of a second is still waiting to be heard: the end of every sound
-- was cut (D54). So each sound is played from a copy with a second of silence added at the
-- end, written in the mod's folder (a path the media player is known to accept, whatever the
-- Windows user name). WAV and MP3 are handled; a file that is not understood, or too large,
-- is played as it is.
-- A WAV sound can also be made to last a given time (the Fée's flight, whose length the host
-- sets): the copy then comes in with a fade and is cut at that length with a short fade-out,
-- the sound being repeated first if it is shorter.
local U = require("lpr_util")

local SND = {}

local PAD_SECONDS = 1.0
local FADE_SECONDS = 0.4     -- fade-out at the end of a sound cut to a length
local FADE_IN_SECONDS = 1.0  -- and fade-in at its start (about as long as the sound of a power that starts)
local MAX_BYTES = 16 * 1024 * 1024
local cache = {}             -- sound file -> { key, path = the file to play }

-- ---------------------------------------------------------------- WAV
-- The parts of a WAV file: { fmt, head (the chunks before the samples, then "data"), fact_at
-- (where head holds the sample count of a "fact" chunk, if any), samples }. Chunks after the
-- samples (tags only) are dropped. nil when the file is not understood.
local function read_wav(d)
    if #d < 44 or d:sub(1, 4) ~= "RIFF" or d:sub(9, 12) ~= "WAVE" then return nil end
    local p, fmt, fact_at, data_at, data_len = 13, nil, nil, nil, nil
    while p + 7 <= #d do
        local id, n = d:sub(p, p + 3), string.unpack("<I4", d, p + 4)
        if id == "fmt " then
            local tag, ch, sr, _, align, bits = string.unpack("<I2I2I4I4I2I2", d, p + 8)
            fmt = { tag = tag, ch = ch, sr = sr, align = align, bits = bits }
        elseif id == "fact" and n >= 4 then
            fact_at = p
        elseif id == "data" then
            data_at, data_len = p, math.min(n, #d - (p + 8) + 1)
            break
        end
        p = p + 8 + n + (n % 2)
    end
    if not fmt or not data_at or data_len <= 0 or fmt.align == 0 or fmt.sr == 0 then return nil end
    if fmt.tag ~= 1 and fmt.tag ~= 3 and fmt.tag ~= 0xFFFE then return nil end   -- PCM, float, extensible
    return { fmt = fmt, head = d:sub(13, data_at + 3), fact_at = fact_at and (fact_at + 8 - 12) or nil,
             samples = d:sub(data_at + 8, data_at + 8 + data_len - 1) }
end

-- `count` frames from frame `first` on (the first frame is 0), each multiplied by gain(i),
-- i going from 0 to count - 1. 16-bit samples.
local function scaled(fmt, samples, first, count, gain)
    local per = fmt.align // 2                           -- samples in a frame (one per channel)
    local parts, pos = {}, first * fmt.align + 1
    for i = 0, count - 1 do
        local g = gain(i)
        for _ = 1, per do
            parts[#parts + 1] = string.pack("<i2", math.floor(string.unpack("<i2", samples, pos) * g + 0.5))
            pos = pos + 2
        end
    end
    return table.concat(parts)
end

-- Samples made to last `seconds`: repeated first when the sound is shorter, cut at that
-- length, faded in over the first moments and out over the last (16-bit whole-number
-- samples; the other kinds are cut without fades). On a very short length the fade-in takes
-- half of it at most, the fade-out the rest.
local function fit(fmt, samples, seconds)
    local frames = #samples // fmt.align
    local want = math.floor(fmt.sr * seconds + 0.5)
    if frames <= 0 or want <= 0 then return samples end
    samples = samples:sub(1, frames * fmt.align)
    if frames < want then samples = string.rep(samples, math.ceil(want / frames)) end
    samples = samples:sub(1, want * fmt.align)
    if fmt.bits ~= 16 or fmt.tag == 3 then return samples end
    local n_in = math.min(want // 2, math.floor(fmt.sr * FADE_IN_SECONDS))
    local n_out = math.min(want - n_in, math.floor(fmt.sr * FADE_SECONDS))
    return scaled(fmt, samples, 0, n_in, function(i) return i / n_in end)
        .. samples:sub(n_in * fmt.align + 1, (want - n_out) * fmt.align)
        .. scaled(fmt, samples, want - n_out, n_out, function(i) return (n_out - 1 - i) / n_out end)
end

-- The file again, its samples followed by silence (zeros; 128 for 8-bit sound, which is
-- unsigned). The sample count of a "fact" chunk is set to what is written.
local function write_wav(w, samples)
    local fmt = w.fmt
    local body = samples .. string.rep(fmt.bits == 8 and "\128" or "\0", math.floor(fmt.sr * PAD_SECONDS) * fmt.align)
    local head = w.head
    if w.fact_at then
        head = head:sub(1, w.fact_at - 1) .. string.pack("<I4", (#body // fmt.align) & 0xFFFFFFFF) .. head:sub(w.fact_at + 4)
    end
    local out = head .. string.pack("<I4", #body) .. body .. ((#body % 2 == 1) and "\0" or "")
    return "RIFF" .. string.pack("<I4", #out + 4) .. "WAVE" .. out
end

-- ---------------------------------------------------------------- MP3
-- Silent frames are added: the first frame's header (no checksum, no padding byte) followed by
-- zeros, which decode as silence. A "Xing"/"Info" header, which gives the number of frames, is
-- updated; an ID3v1 tag at the end stays at the end.
local BITRATES = {
    mpeg1 = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 },
    mpeg2 = { 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 },
}
local RATES = { [3] = { 44100, 48000, 32000 }, [2] = { 22050, 24000, 16000 }, [0] = { 11025, 12000, 8000 } }

local function u32be(s, i) return (string.unpack(">I4", s, i)) end

-- The frame header at p, if it is one: { b1, b2, b3, len, mpeg1, sr, mono }.
local function frame_at(d, p)
    if p + 3 > #d or d:byte(p) ~= 255 or (d:byte(p + 1) & 0xE0) ~= 0xE0 then return nil end
    local b1, b2, b3 = d:byte(p + 1), d:byte(p + 2), d:byte(p + 3)
    local ver, layer = (b1 >> 3) & 3, (b1 >> 1) & 3      -- version 3/2/0 = MPEG-1/2/2.5; layer 1 = III
    local br_i, sr_i = b2 >> 4, (b2 >> 2) & 3
    if ver == 1 or layer ~= 1 or br_i == 0 or br_i == 15 or sr_i == 3 then return nil end
    local mpeg1 = ver == 3
    local kbps = (mpeg1 and BITRATES.mpeg1 or BITRATES.mpeg2)[br_i]
    local sr = RATES[ver][sr_i + 1]
    local base = math.floor((mpeg1 and 144000 or 72000) * kbps / sr)
    return { b1 = b1, b2 = b2, b3 = b3, base = base, len = base + ((b2 >> 1) & 1),
             mpeg1 = mpeg1, sr = sr, mono = ((b3 >> 6) & 3) == 3 }
end

local function pad_mp3(d)
    local p = 1
    if d:sub(1, 3) == "ID3" and #d >= 10 then
        local size = ((d:byte(7) & 127) << 21) | ((d:byte(8) & 127) << 14) | ((d:byte(9) & 127) << 7) | (d:byte(10) & 127)
        p = 11 + size + (((d:byte(6) & 16) ~= 0) and 10 or 0)
    end
    -- the first real frame: a header followed by another one right after it
    local h, limit = nil, math.min(#d, p + 65536)
    while p <= limit do
        h = frame_at(d, p)
        if h and (p + h.len > #d - 3 or frame_at(d, p + h.len)) then break end
        h = nil
        p = p + 1
    end
    if not h then return nil end
    local n = math.ceil(h.sr * PAD_SECONDS / (h.mpeg1 and 1152 or 576))
    local frame = string.char(255, h.b1 | 1, h.b2 & 0xFD, h.b3) .. string.rep("\0", h.base - 4)
    -- "Xing"/"Info" sits right after the side information (no allowance for a checksum)
    local x = p + 4 + (h.mpeg1 and (h.mono and 17 or 32) or (h.mono and 9 or 17))
    local tag = d:sub(x, x + 3)
    if tag == "Xing" or tag == "Info" then
        local flags = u32be(d, x + 4)
        local q = x + 8
        local head = d:sub(1, q - 1)
        if (flags & 1) ~= 0 then head = head .. string.pack(">I4", (u32be(d, q) + n) & 0xFFFFFFFF); q = q + 4 end
        if (flags & 2) ~= 0 then head = head .. string.pack(">I4", (u32be(d, q) + n * h.base) & 0xFFFFFFFF); q = q + 4 end
        d = head .. d:sub(q)
    end
    local tail = ""
    if #d >= 128 and d:sub(#d - 127, #d - 125) == "TAG" then
        tail = d:sub(#d - 127)
        d = d:sub(1, #d - 128)
    end
    return d .. string.rep(frame, n) .. tail
end

-- ---------------------------------------------------------------- the file to play
-- A short fingerprint of the file's content (length and a sample of its bytes), which also
-- names the copy: the same sound always gives the same copy, even after a reload of the mod.
local function fingerprint(d)
    local h, step = #d, math.max(1, #d // 4096)
    for i = 1, #d, step do h = (h * 31 + d:byte(i)) & 0xFFFFFFFF end
    return h
end

local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

-- The file to hand to the media player for this sound. seconds (optional): the sound must
-- last that long (WAV only; an MP3 is played whole, the caller stops it).
function SND.playable(path, seconds)
    local f = io.open(path, "rb")
    if not f then return path end
    local size = f:seek("end")
    if not size or size > MAX_BYTES then f:close() return path end
    f:seek("set", 0)
    local d = f:read("a")
    f:close()
    if not d then return path end
    local key = fingerprint(d)
    local is_wav = path:lower():match("%.wav$") ~= nil
    local tenths = (seconds and is_wav) and math.floor(seconds * 10 + 0.5) or nil
    local slot = tenths and (path .. "|" .. tenths) or path
    local c = cache[slot]
    if c and c.key == key and (c.path == path or exists(c.path)) then return c.path end
    local ok, out = pcall(function()
        if not is_wav then return pad_mp3(d) end
        local w = read_wav(d)
        if not w then return nil end
        return write_wav(w, tenths and fit(w.fmt, w.samples, tenths / 10) or w.samples)
    end)
    if not ok or not out then
        U.log("Son %s lu tel quel (%s)", path, ok and "format non reconnu" or tostring(out))
        cache[slot] = { key = key, path = path }
        return path
    end
    -- one copy per length asked for ("b": with the fade-in; copies of older versions, which
    -- had none, have another name and are not taken for these)
    local copy = string.format("%s\\LPRoles-son-%08x%s%s", (U.MOD_DIR:gsub("/", "\\")), key,
        tenths and ("-" .. tenths .. "b") or "", path:match("(%.%w+)$") or ".wav")
    local done = false
    local r = io.open(copy, "rb")
    if r then                                             -- already made (earlier session, reload)
        done = r:seek("end") == #out
        r:close()
    end
    if not done then
        local w = io.open(copy, "wb")
        if not w then return path end                     -- tried again next time
        local written = w:write(out)
        local closed = w:close()
        if not (written and closed) then
            os.remove(copy)
            return path
        end
    end
    cache[slot] = { key = key, path = copy }
    U.log("Son %s : copie %savec %.1f s de silence à la fin (%s)", path,
        tenths and string.format("de %.1f s ", tenths / 10) or "", PAD_SECONDS, copy)
    return copy
end

return SND
