-- LPRoles - the random event « MICRO OUVERT »: the camera room's desk becomes the ship's
-- loudspeaker. The living player nearest to its keyboard (2 m by default, on the same deck) takes
-- the microphone: every machine with the mod then hears that player's voice as if it were spoken
-- right in front of it, with a loudspeaker's tone, the dead included. One speaker at a time; the
-- next one who comes near takes a place left empty. The Bâillonneur's gag wins: a gagged player
-- cannot take a free microphone, a gagged speaker keeps the place and stays silent. At the end
-- the voices are the game's own again (heard by proximity).
--   - Host: the desk, who holds the microphone (looked at ten times a second), the banners, the
--     notice at the top of the screen, the tablet line, and each speaker's time at the desk.
--   - Every machine: the speaker's voice moved under this machine's own ears, and put back the
--     way the game has it when the speaker changes or the event ends. Nothing is replicated:
--     each machine moves the voice it hears (a player without the mod hears the game's voices).
local C = require("lpr_config")
local G = require("lpr_game")
local U = require("lpr_util")
local W = require("lpr_ev_world")

local KEEP = 50               -- cm beyond the range the speaker may move and keep the place (no crackle at the edge)
local DZ = 250                -- cm: on the desk's deck (a floor above or below does not count)
local CHIME_GAP = 2           -- s: at most one chime so often, when the place changes hands fast
-- s between the microphone's end and the event's: the closing chime plays out (EVOFF stops the
-- event's sounds on every machine)
local TAIL = 2.5
local EAR_OFFSET = { X = 60.0, Y = 0.0, Z = 0.0 }    -- the voice 60 cm in front of the listener's ears
local LPF_HZ = 3500.0         -- a loudspeaker's tone
-- the game's voice of a remote player: its own sound component, made at the first word heard
local VOIP = "/Script/OnlineSubsystemUtils.VoipListenerSynthComponent"
-- where the game itself puts a voice under its Sound Path (Mec 0x31201, Death Update 0x0371 /
-- 0x03fd): a living player's mouth, a dead one's ghost
local ALIVE_AT, DEAD_AT = { X = 0.0, Y = 0.0, Z = 160.0 }, { X = 0.0, Y = 0.0, Z = 0.0 }

local M = { id = "mic", switch = "event_mic", KEYS = { "event_mic_seconds", "event_mic_range" },
            min_living = 3 }

M.TEXT = {
    START = { "MICRO OUVERT (%s S)", "num" },
    WHERE = { "PUPITRE DES CAMÉRAS" },
    ON    = { "AU MICRO : %s", "name", n = true },        -- the face worn: an announcement by sight
    FREE  = { "MICRO LIBRE", n = true },
    YOU   = { "TU ES AU MICRO", c = "good" },
    LOST  = { "TU AS QUITTÉ LE MICRO" },
    END   = { "MICRO FERMÉ" },
    NOPE  = { "TEST : PAS DE PUPITRE", c = "warn" },
}

M.LINES = {
    ALL = { "Micro ouvert au pupitre des caméras : libre - {t}" },
    ON  = { "Micro ouvert : %s parle à tout le vaisseau - {t}", "name" },
    SPK = { "Tu es au micro : tout le vaisseau t'entend - {t}" },
}

M.RECAP = {
    ev_mic      = { "Évènement : micro ouvert" },
    ev_mic_talk = { "Micro : %s au pupitre pendant %s s", "name", "num" },
}

M.SOUNDS = { "ev_mic_chime" }

-- ---------------------------------------------------------------- host
-- The desk: the camera room's computer (Map_Main has one PC_Cameras_C), at its keyboard, where a
-- player stands to speak; the computer itself if the keyboard cannot be read.
local function find_desk()
    local pc = W.all_of("PC_Cameras_C")[1]
    if not pc then return nil end
    local kb = U.get(pc, "MapMesh_TaskMachine_Computer_Keyboard", nil)
    if U.valid(kb) then
        local ok, at = pcall(function() return U.vec_copy(kb:K2_GetComponentLocation()) end)
        if ok and at then return at end
    end
    return G.location(pc)
end

-- How far a player stands from the desk, on its deck; nil when elsewhere (another deck, or a
-- hidden Clandestin, whose place is never told).
local function dist(ctx, P, desk)
    local at = ctx.where(P)
    if not at or math.abs(at.Z - desk.Z) > DZ then return nil end
    return W.dist2d(at, desk)
end

-- The living player nearest to the desk within its range who may take a free microphone: there,
-- in its body (not dreaming, flying, hidden, nor getting back into its body), and not gagged.
local function nearest(ctx, now)
    local r = ctx.run
    local best, best_d = nil, r.range
    for _, P in ipairs(ctx.living()) do
        if ctx.present(P) and not (P.gag_until and P.gag_until > now) then
            local d = dist(ctx, P, r.desk)
            if d and d <= best_d then best, best_d = P, d end
        end
    end
    return best
end

local function chime(ctx, now)
    ctx.run.chimed = now
    ctx.sound("chime", "ev_mic_chime", nil, { mode = "flat" })
end

-- The microphone changes hands. S: the new speaker (nil: the desk is left empty); prev: the one
-- who had it (nil when that player left the game).
local function change(ctx, S, prev, now)
    local r = ctx.run
    r.spk = S and S.key or nil
    local left = math.max(1, r.close_at - now)
    -- the real index: it is the real voice that every machine moves (a Métamorphe at the desk is
    -- named by the face it wears and heard with its own voice, a clue left on purpose)
    ctx.all("spk", S and ctx.idx(S) or -1)
    if S then
        r.idx[S.key] = ctx.idx(S)                -- noted now: a player who leaves has no index any more
        ctx.notice(nil, "ON", ctx.face(S))
        ctx.line(nil, "ON", left, ctx.face(S))
        ctx.say(S, "YOU")
        ctx.line(S, "SPK", left)                 -- after the line to everyone, which it replaces for the speaker
    else
        ctx.notice(nil, "FREE")
        ctx.line(nil, "ALL", left)
    end
    if prev and prev ~= S and ctx.valid(prev) and G.is_alive(prev.mec) then ctx.say(prev, "LOST") end
    if now - (r.chimed or -math.huge) >= CHIME_GAP then chime(ctx, now) end
end

-- The microphone's time is over: every voice back to the game's own at once, the desk's column
-- and lamp off, the banner and the chime; the event itself ends once the chime has played (TAIL).
local function close(ctx, now)
    local r = ctx.run
    r.closed, r.spk = true, nil
    ctx.all("spk", -1)
    ctx.unmark("e1")
    ctx.light_off("air")
    ctx.line(nil, nil)
    ctx.say(nil, "END")
    chime(ctx, now)
end

function M.can_start(ctx, now, test)
    if not find_desk() then return false, "NOPE" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    local secs = C.get("event_mic_seconds")
    r.desk = find_desk()
    if not r.desk then return false end
    r.range = C.get("event_mic_range")
    r.close_at, r.last = now + secs, now
    r.held, r.idx = {}, {}                       -- player key -> seconds at the desk, real index
    ctx.mark("e1", r.desk, "orange", true, "col")
    -- the "on air" lamp above the desk (orange: red is the dissidents' colour)
    ctx.light_at("air", { X = r.desk.X, Y = r.desk.Y, Z = r.desk.Z + 150 }, "orange", 400, 8000)
    chime(ctx, now)
    ctx.say(nil, "START", secs)
    ctx.say(nil, "WHERE")
    ctx.line(nil, "ALL", secs)
    ctx.recap("ev_mic")
    return secs + TAIL
end

function M.tick(ctx, now)
    local r = ctx.run
    if r.closed then
        if now >= r.close_at + TAIL then ctx.finish("done") end
        return
    end
    if r.spk then r.held[r.spk] = (r.held[r.spk] or 0) + (now - r.last) end
    r.last = now
    if now >= r.close_at then return close(ctx, now) end
    -- the speaker keeps the place up to range + KEEP, gagged or not (the gag wins: silent); one
    -- who died, fell asleep, flew off, hid, left or walked away gives it up to the nearest
    -- (deaths, raises and departures need nothing else: this runs again 0.1 s later)
    local cur = r.spk and ctx.by_key(r.spk) or nil
    local S = cur
    if not (cur and ctx.present(cur) and (dist(ctx, cur, r.desk) or math.huge) <= r.range + KEEP) then
        S = nearest(ctx, now)
    end
    if (S and S.key) ~= r.spk then change(ctx, S, cur, now) end
    -- a machine that came in late does not know who speaks: told again now and then (the same
    -- speaker again changes nothing on a machine that already has it)
    ctx.every(5, "spk", function() ctx.all("spk", S and ctx.idx(S) or -1) end)
end

function M.stop(ctx, reason)
    local r = ctx.run
    if r.spk and r.last then r.held[r.spk] = (r.held[r.spk] or 0) + (ctx.now() - r.last) end
    if reason == "timeout" and not r.closed then ctx.say(nil, "END") end
    -- each speaker's time at the desk, under the real name
    for key, secs in pairs(r.held or {}) do
        local i = r.idx[key]
        if i and i >= 0 and secs >= 1 then ctx.recap("ev_mic_talk", i, math.floor(secs + 0.5)) end
    end
    -- the voices are put back on every machine by EVOFF (M.client.off)
end

-- ---------------------------------------------------------------- every machine
-- Two wrappers of one engine object are not equal in Lua: compared by address.
local function same(a, b)
    return U.valid(a) and U.valid(b) and a:GetAddress() == b:GetAddress()
end

-- The speaker's voice (its "Voice Source", which the game's voice component follows) put under
-- this machine's ears, 60 cm in front: heard at full voice wherever the speaker is. Called again
-- every tick: the game's Death Update (at every death, and when a dreaming Rêveur or a flying Fée
-- of this machine gets back into its body) puts the voice's height back, under the new parent.
local function attach(cx, rec)
    local vs = U.get(rec.mec, "Voice Source", nil)
    local me = cx.me()
    local ears = me and U.get(me, "Ears", nil)
    if not (U.valid(vs) and U.valid(ears)) then return false end
    rec.vs = vs
    return pcall(function()
        if not same(vs:GetAttachParent(), ears) then
            vs:K2_AttachToComponent(ears, FName("None"), 2, 1, 1, true)       -- the game's own rules (Mec 0x311a4)
        end
        vs:K2_SetRelativeLocation(EAR_OFFSET, false, {}, false)
    end)
end

-- A loudspeaker's tone on the voice, or none. The voice's component exists only once the speaker
-- has been heard: tried again every second (which also covers a component the engine made again).
local function filter(rec, on)
    local vs = rec.vs
    if not U.valid(vs) then return end
    pcall(function()
        for i = 0, vs:GetNumChildrenComponents() - 1 do
            local c = vs:GetChildComponent(i)
            if U.valid(c) and c:IsA(VOIP) then
                c:SetLowPassFilterEnabled(on)
                if on then c:SetLowPassFilterFrequency(LPF_HZ) end
                rec.filtered = on
            end
        end
    end)
end

-- The voice back the way the game has it: under the character's Sound Path, which carries it
-- to the listener and silences it beyond reach (Mec 0x311a4, 0x31201), then the game's own Death
-- Update, which mutes or unmutes it as the two players' lives want. Nothing when the speaker's
-- character is gone (a player who left).
local function restore(rec)
    if not rec or not U.valid(rec.mec) then return end
    filter(rec, false)
    local mec = rec.mec
    local vs = U.get(mec, "Voice Source", nil)
    local sp = U.get(mec, "Sound Path", nil)
    local src = U.valid(sp) and U.get(sp, "Source", nil) or nil
    if U.valid(vs) and U.valid(src) then
        local at = G.is_alive(mec) and ALIVE_AT or DEAD_AT
        pcall(function()
            vs:K2_AttachToComponent(src, FName("None"), 2, 1, 1, true)
            vs:K2_SetRelativeLocation(at, false, {}, false)
        end)
    end
    U.tcall(mec, "Death Update")
end

-- The voice of the speaker this machine was told about, if its character is here (never this
-- machine's own: the game never lets a player hear itself).
local function take(cx)
    local run = cx.run
    local idx = run.want or -1
    if idx < 0 or cx.is_me(idx) then return end
    local mec = cx.mec(idx)
    if not mec then return end
    run.cur = { idx = idx, mec = mec }
    attach(cx, run.cur)
end

M.client = {
    on = function(cx, secs)
        cx.run.cur, cx.run.want = nil, -1
    end,
    -- the speaker's real index (-1: nobody at the desk)
    spk = function(cx, idx)
        local run = cx.run
        idx = tonumber(idx) or -1
        local cur = run.cur
        -- the same speaker told again (every 5 s): nothing moves, nothing is heard to jump
        if cur and cur.idx == idx and U.valid(cur.mec) then return end
        run.want = idx
        restore(cur)
        run.cur = nil
        take(cx)
    end,
    tick = function(cx, now)
        local run = cx.run
        local rec = run.cur
        if not rec then
            -- a speaker whose character this machine did not have yet: looked for once a second
            if (run.want or -1) >= 0 and now >= (run.retry or 0) then
                run.retry = now + 1
                take(cx)
            end
            return
        end
        if not U.valid(rec.mec) then
            run.cur = nil                       -- the speaker left: its character is gone, nothing to put back
            return
        end
        attach(cx, rec)
        if not rec.filtered or now - (rec.ft or 0) >= 1 then
            rec.ft = now
            filter(rec, true)
        end
    end,
    -- EVOFF, the end of the game, a new game, this machine's character lost: the voice put back
    off = function(cx, reason)
        restore(cx.run.cur)
        cx.run.cur, cx.run.want = nil, -1
    end,
}

return M
