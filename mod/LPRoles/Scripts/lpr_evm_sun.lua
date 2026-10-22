-- LPRoles - the random event « 1, 2, 3, SOLEIL ! »: move while the music plays, freeze when it
-- stops. Every radio of the ship that plays no cassette plays the same song of the game, loud;
-- a voice says "un, deux, trois... soleil !" and the music stops dead on "soleil". Then, for a few
-- seconds, a player who moves (beyond the tolerance), hits someone or fires is caught: exhausted
-- on the spot (the item drops, the player staggers). Four rounds by default.
--   - Host: the radios (their song, played and cut through the game's own multicasts, put back
--     at the end as their players left them), the rounds, who is judged and who is caught, the
--     summary.
--   - Every machine: a quiet copy of the song heard as it is, for whoever is far from a radio
--     (the radios carry it only so far), stopped at each cut.
-- Judged: living players with the mod, in their body (not dreaming, flying, hidden nor getting
-- back into it). A player without the mod has neither the signal nor the rule: never judged.
-- Radios already playing a cassette are left alone.
local C = require("lpr_config")
local G = require("lpr_game")
local U = require("lpr_util")
local W = require("lpr_ev_world")

local INTRO, GRACE = 4.0, 0.8           -- s: the banners before the first song; after a cut, before anyone is judged
-- s: the voice starts this long before the cut, so that "soleil" falls on it (ev_sun_voice.wav:
-- "soleil" begins at about 1.55-1.58 s)
local VOICE_LEAD = 1.56
local MUSIC = { min = 6.0, max = 15.0 } -- s of music per round, drawn at random
-- s: a blow given that soon after the cut was begun before it (no fault); s: a player hit is
-- pushed, not moving of its own (excused that long); cm from one tick to the next: moved by a
-- power (Échangeur, Écho, out of hiding), noted again rather than caught
local HIT_LAG, EXCUSE, JUMP = 0.3, 1.5, 250
-- s: a player the game teleported (Net Request TP) is noted again that long where it lands. The
-- host has the new place in the hook itself (All TP runs there inside it); the player's machine
-- sends Net Request TP first and moves there right after (Mec 0x3a64f), so its next positions are
-- the new place too: a short while is enough, and a longer one would let the swapped player walk
-- away unpunished.
local TP_EXCUSE = 0.5
local VOLUME = 10                       -- the radios' loudest
-- each machine's own copy of the song: softer than a radio; a moment after the "go" (the radios'
-- song comes by the game's multicast, in no set order with the event's message); the radio it is
-- read from, found within this distance of where the host says it is (cm)
local COPY = { volume = 0.35, delay = 0.3, near = 150 }

local M = { id = "sun", switch = "event_sun",
            KEYS = { "event_sun_rounds", "event_sun_freeze", "event_sun_tolerance" },
            min_living = 3, min_present = 2, not_last = 90 }

M.TEXT = {
    START     = { "1, 2, 3, SOLEIL !" },
    RULE1     = { "BOUGEZ PENDANT LA MUSIQUE" },
    RULE2     = { "FIGEZ-VOUS AU SILENCE !" },
    SUN       = { "SOLEIL !", c = "warn", n = true },          -- at once, never queued
    MOVE      = { "BOUGEZ !", c = "good", n = true },
    YOU_MOVED = { "TU AS BOUGÉ : ÉPUISÉ", c = "bad", n = true },
    YOU_HIT   = { "TU AS FRAPPÉ : ÉPUISÉ", c = "bad", n = true },
    YOU_SHOT  = { "TU AS TIRÉ : ÉPUISÉ", c = "bad", n = true },
    CAUGHT    = { "PRIS : %s", "names", c = "bad" },           -- the faces worn: an announcement by sight
    END       = { "SOLEIL : FIN DU JEU", c = "good" },
    NORADIO   = { "TEST : AUCUNE RADIO LIBRE", c = "warn" },
    NOBODY    = { "TEST : PERSONNE À JUGER", c = "warn" },
}

M.LINES = {
    PLAY = { "Manche %s sur %s : bougez pendant la musique, figez-vous dès qu'elle s'arrête - {t}", "num", "num" },
}

M.RECAP = {
    ev_sun        = { "Évènement : 1, 2, 3, soleil ! (%s manches)", "num" },
    ev_sun_caught = { "Soleil : %s pris %s fois", "name", "num" },
    ev_sun_none   = { "Soleil : personne n'a été pris" },
}

M.SOUNDS = { "ev_sun_voice" }           -- made ready at EVON: it must come right on time

-- ---------------------------------------------------------------- host
-- The radios that play no cassette now ("Is Playing", known to the host only), and how many
-- songs the game's list has (every radio fills "Musics" itself: 0 when it cannot be read).
local function free_radios()
    local out, songs = {}, 0
    for _, rd in ipairs(W.radios()) do
        local a = rd.actor
        if U.valid(a) and U.get(a, "Is Playing", false) ~= true then
            out[#out + 1] = a
            if songs == 0 then
                local list = U.get(a, "Musics", nil)
                pcall(function() songs = #list end)
            end
        end
    end
    return out, songs
end

local function judged(ctx, P)
    return P.modded and ctx.present(P)
end

-- Where a player stands now, to be compared; none while it is off the ground (noted where it
-- lands: jumping on the spot is allowed, only the distance on the floor counts).
local function note(ctx, P)
    local r = ctx.run
    local p = ctx.where(P)
    local air = U.get(P.mec, "Net Stance", G.STANCE_STAND) == G.STANCE_AIR
    r.pos[P.key] = (p and not air) and { X = p.X, Y = p.Y } or nil
end

-- The music again, on every radio of the event, where it stopped (the song set again: a
-- cassette put in meanwhile would have changed it; a song near its end starts over instead).
local function go(ctx, now)
    local r = ctx.run
    r.round = r.round + 1
    local m = r.music[r.round]
    if r.dur > 0 and r.t + m > r.dur - 1 then r.t = 0 end
    local at = nil
    for _, rd in ipairs(r.radios) do
        local a = rd.actor
        if not rd.released and U.valid(a) then
            W.radio_play(a, r.track, r.t, VOLUME)
            at = at or G.location(a)
        end
    end
    if at then ctx.all("go", math.floor(r.t * 10 + 0.5), at.X, at.Y, at.Z) end
    if r.round > 1 then ctx.notice(nil, "MOVE") end
    ctx.line(nil, "PLAY", math.max(1, ctx.ends - now), r.round, r.rounds)
    r.phase, r.go_at, r.next, r.voiced = "music", now, now + m, false
end

-- Silence everywhere at once: the radios cut (the time shown where the song stopped), each
-- machine's copy stopped, the notice at the top of the screen.
local function cut(ctx, now)
    local r = ctx.run
    r.t = r.t + (now - r.go_at)
    for _, rd in ipairs(r.radios) do
        local a = rd.actor
        if not rd.released and U.valid(a) then W.radio_cut(a, r.t) end
    end
    ctx.all("cut")
    ctx.notice(nil, "SUN")
    r.phase, r.cut_at, r.next = "grace", now, now + GRACE
    r.caught, r.pos, r.last, r.excused, r.skip = {}, {}, {}, {}, {}
end

-- A player caught (how: "move", "hit", "gun"): exhausted (the item drops; one already exhausted
-- drops it all the same: the frame's), told at once, counted under its real name.
local function catch(ctx, P, how)
    local r = ctx.run
    local key = P.key
    r.caught[key] = ctx.face(P)
    r.count[key] = (r.count[key] or 0) + 1
    r.idx[key] = ctx.idx(P)                  -- noted now: a player who leaves has no index any more
    r.pos[key] = nil
    ctx.exhaust(P)
    ctx.notice(P, (how == "move" and "YOU_MOVED") or (how == "gun" and "YOU_SHOT") or "YOU_HIT")
end

-- The blows and shots that count: from a little after the cut to the end of the round.
local function live(r, now)
    return (r.phase == "grace" and now - r.cut_at >= HIT_LAG) or r.phase == "watch"
end

-- Ten times a second during the freeze: each judged player against where it was noted.
local function watch(ctx, now)
    local r = ctx.run
    for _, P in ipairs(ctx.living()) do
        local key = P.key
        if r.caught[key] == nil and not r.skip[key] then
            if not judged(ctx, P) then
                -- away for a while (a Fée flying, a Clandestin hidden, a Rêveur dreaming or
                -- getting up): noted afresh where it comes back, not caught for it
                r.pos[key], r.last[key] = nil, nil
            else
                local p = ctx.where(P)
                local last, o = r.last[key], r.pos[key]
                r.last[key] = p and { X = p.X, Y = p.Y } or nil
                if p then
                    -- a teleport of any length is excused by the Net Request TP hook below; the
                    -- JUMP stays for one that does not go through it
                    if (last and W.dist2d(p, last) > JUMP) or (r.excused[key] or 0) > now or not o then
                        note(ctx, P)             -- moved by a power, pushed by a blow, not noted yet (in the air)
                    elseif W.dist2d(p, o) > r.tol then
                        catch(ctx, P, "move")
                    end
                end
            end
        end
    end
end

-- The round is over: who was caught (the faces worn), then the next round or the end.
local function end_round(ctx, now)
    local r = ctx.run
    local faces = {}
    for _, f in pairs(r.caught) do
        if f >= 0 then faces[#faces + 1] = f end
    end
    if #faces > 0 then ctx.say(nil, "CAUGHT", faces) end
    if r.round < r.rounds then
        go(ctx, now)
    else
        ctx.finish("done")
    end
end

function M.can_start(ctx, now, test)
    local radios, songs = free_radios()
    if #radios == 0 or songs == 0 then return false, "NORADIO" end
    -- alone in a test, the host (who has the mod) is judged
    if #ctx.living(function(P) return judged(ctx, P) end) < (test and 1 or 2) then return false, "NOBODY" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    local list, songs = free_radios()
    if #list == 0 or songs == 0 then return false end
    r.radios = {}
    for _, a in ipairs(list) do
        local rd = { actor = a }
        r.radios[#r.radios + 1] = rd
        -- put back whatever stops the event (the end of the game included: it stops the song, it
        -- starts nothing); not a radio given back to a player meanwhile. Its state is read at that
        -- moment, not kept from now: the reader is never locked, so a cassette may have been put
        -- in, swapped or taken out during the event (and the volume changed), and a snapshot would
        -- put the old cassette's song, or none, on the screen and in the sound the Play button
        -- starts. The event itself never writes the reader, "Time Elapsed" nor "Volume" (its
        -- multicasts set only the sound, the screen and the loudness heard), so what they say at
        -- the end is the radio's own state, which the restore makes the sound and screen match.
        ctx.defer(function()
            if not rd.released and U.valid(a) then W.radio_restore(a, W.radio_state(a)) end
        end)
    end
    r.track = math.random(0, songs - 1)
    for _, rd in ipairs(r.radios) do
        local a = rd.actor
        pcall(function() a:FlushNetDormancy() end)
        U.tcall(a, "All Set Song", r.track)
    end
    -- the song's length (a multicast runs on the host at once: its sound is already set)
    local first = r.radios[1].actor
    local src = U.get(first, "AudioSource", nil)
    local snd = U.valid(src) and U.get(src, "Sound", nil) or nil
    r.dur = U.valid(snd) and (tonumber(U.get(snd, "Duration", 0)) or 0) or 0
    r.rounds = C.get("event_sun_rounds")
    r.freeze, r.tol = C.get("event_sun_freeze"), C.get("event_sun_tolerance")
    r.music, r.count, r.idx, r.round = {}, {}, {}, 0
    r.caught, r.pos, r.last, r.excused, r.skip = {}, {}, {}, {}, {}
    local total = 0
    for i = 1, r.rounds do
        r.music[i] = MUSIC.min + math.random() * (MUSIC.max - MUSIC.min)
        total = total + r.music[i]
    end
    -- somewhere in the song, so that the whole event fits in it when it is long enough
    r.t = (r.dur > total + 5) and math.random() * math.min(30, r.dur - total - 5) or 0
    r.phase, r.next = "intro", now + INTRO
    ctx.say(nil, "START")
    ctx.say(nil, "RULE1")
    ctx.say(nil, "RULE2")
    local planned = INTRO + total + r.rounds * (GRACE + r.freeze) + 2
    ctx.line(nil, "PLAY", planned, 1, r.rounds)
    ctx.recap("ev_sun", r.rounds)
    return planned
end

function M.tick(ctx, now)
    local r = ctx.run
    if r.phase == "intro" then
        if now >= r.next then go(ctx, now) end
    elseif r.phase == "music" then
        if not r.voiced and now >= r.next - VOICE_LEAD then
            r.voiced = true
            ctx.sound("voice", "ev_sun_voice", nil, { mode = "flat" })
        end
        if now >= r.next then cut(ctx, now) end
    elseif r.phase == "grace" then
        if now >= r.next then
            -- the replicated positions have caught up with the cut: everyone judged is noted
            r.phase, r.next = "watch", now + r.freeze
            for _, P in ipairs(ctx.living(function(P) return judged(ctx, P) end)) do
                if not r.caught[P.key] and not r.skip[P.key] then note(ctx, P) end
            end
        end
    elseif r.phase == "watch" then
        watch(ctx, now)
        if now >= r.next then end_round(ctx, now) end
    end
end

-- A shot fired during the freeze (Net Gun Fire) is caught. Any swing with an item in hand
-- ("melee": a jar, a fish...) is not: only a blow that hits someone, seen by M.on_hit.
function M.on_attack(ctx, P, kind)
    local r, now = ctx.run, ctx.now()
    if kind ~= "gun" or not live(r, now) then return end
    if not r.caught[P.key] and not r.skip[P.key] and judged(ctx, P) then catch(ctx, P, "gun") end
end

-- A blow that hit (Net Deal Damage): the attacker is caught; the victim, pushed by it, is
-- excused a moment (noted again where the blow left it).
function M.on_hit(ctx, A, V)
    local r, now = ctx.run, ctx.now()
    if r.phase ~= "grace" and r.phase ~= "watch" then return end
    r.excused[V.key] = now + EXCUSE
    if live(r, now) and not r.caught[A.key] and not r.skip[A.key] and judged(ctx, A) then catch(ctx, A, "hit") end
end

-- A player raised during a freeze gets up where the defibrillator left it: judged from the next
-- round on (a player killed meanwhile is out already: only the living are looked at).
function M.on_rez(ctx, P)
    local r = ctx.run
    if r.phase == "grace" or r.phase == "watch" then r.skip[P.key] = true end
end

function M.stop(ctx, reason)
    local r = ctx.run
    if reason ~= "end" then ctx.say(nil, "END") end
    -- how many times each player was caught, under the real name
    local any = false
    for key, n in pairs(r.count or {}) do
        local i = r.idx[key]
        if i and i >= 0 then
            ctx.recap("ev_sun_caught", i, n)
            any = true
        end
    end
    if not any and (r.round or 0) > 0 then ctx.recap("ev_sun_none") end
    -- the radios are put back by the frame's undo stack (ctx.defer in M.start)
end

-- A player pressed "play" on a radio of the event (Start Song runs on the host, after the
-- button, through OnRep_State 4). It played the event's song with a timer for that song's length:
-- the radio is given back, its cassette's song from its own time, and the event no longer uses it.
local function give_back(a)
    local st = W.radio_state(a)
    if not st.item_in then return end
    pcall(function() a:FlushNetDormancy() end)
    U.tcall(a, "Pause Song")                     -- silent everywhere, the timer of the wrong song cleared
    U.tcall(a, "All Set Song", math.floor(st.value))  -- stopped: setting the song starts nothing
    U.tcall(a, "Start Song")                     -- from its own time, with a timer for its own song
end

-- A player teleported by the game during a freeze: "Net Request TP" is the host's half of the
-- game's own "Request TP", which the host sends for an Échangeur's swap (to both players), an
-- Écho's return or a Rêveur's waking. The jump can be shorter than JUMP (a swap with someone
-- 1.5 m away, an Écho that walked slowly), and then neither of the two swapped players, the
-- target least of all, must be caught for it. The hook runs after the function, whose All TP has
-- already put the player at its new place on the host: noted again there for a moment.
local function teleported(ctx, hc)
    local r = ctx.run
    if r.phase ~= "grace" and r.phase ~= "watch" then return end
    local P = ctx.by_key(U.key(hc:get()))
    if not P then return end
    r.excused[P.key] = math.max(r.excused[P.key] or 0, ctx.now() + TP_EXCUSE)   -- a blow's longer excuse kept
end

M.hooks = {
    { path = W.PATH_RADIO .. ":Start Song", fn = function(ctx, hc)
        local a = hc:get()
        if not U.valid(a) then return end
        for _, rd in ipairs(ctx.run.radios or {}) do
            local b = rd.actor
            if not rd.released and U.valid(b) and b:GetAddress() == a:GetAddress() then
                rd.released = true               -- first: the Start Song below comes back here
                U.try("soleil : radio rendue", give_back, a)
                return
            end
        end
    end },
    { path = G.PATH_MEC .. ":Net Request TP", fn = teleported },
}

-- ---------------------------------------------------------------- every machine
local function stop_copy(run)
    local c = run.copy
    run.copy, run.copy_at = nil, nil
    -- the engine destroys the component once it is over: never used after that
    if c and U.valid(c) then pcall(function() c:Stop() end) end
end

M.client = {
    -- the song plays again from `tenths`; x, y, z: a radio of the event, to read the song from
    go = function(cx, tenths, x, y, z)
        local run = cx.run
        stop_copy(run)
        run.t = (tonumber(tenths) or 0) / 10
        run.at = U.vec(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
        run.copy_at = cx.now() + COPY.delay
    end,
    cut = function(cx)
        stop_copy(cx.run)
    end,
    tick = function(cx, now)
        local run = cx.run
        if not run.copy_at or now < run.copy_at then return end
        run.copy_at = nil
        if not C.get("event_sounds") then return end          -- this player's own setting
        local radio = W.find_near("Music_Small_C", run.at, COPY.near)
        local src = radio and U.get(radio, "AudioSource", nil) or nil
        local snd = U.valid(src) and U.get(src, "Sound", nil) or nil
        if U.valid(snd) then
            local vol = COPY.volume * (C.get("sound_volume") or 100) / 100
            run.copy = cx.game_sound_2d(snd, vol, run.t + COPY.delay)
        end
    end,
    off = function(cx, reason)
        stop_copy(cx.run)
    end,
}

return M
