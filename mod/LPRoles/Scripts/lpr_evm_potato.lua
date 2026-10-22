-- LPRoles - random event PATATE CHAUDE (hot potato): a time bomb goes from player to player at a
-- touch and blows up on whoever carries it when its hidden delay runs out.
--   - Only a player present in the ship carries it or receives it (alive, in its own body, not
--     dreaming, flying, hiding, nor getting back into its body), and only with the mod: a player
--     without it would not know it carries the bomb.
--   - A carrier who can no longer carry it (dead, asleep, flown off, hidden, gone) loses it to the
--     nearest player who can; nobody left: the bomb is defused.
--   - Everything shown (the carrier's light, its beep, its veil, the tablet lines) is the frame's
--     and is taken back by it at the end; the damage, the tiredness and the item dropped by the
--     blast are the game's own consequences and stay.
-- What is said by sight names the face worn (a Métamorphe's disguise), the summary the real player.
local C = require("lpr_config")
local U = require("lpr_util")

local TOUCH, TOUCH_Z = 150, 150          -- a pass: closer than this across and in height (cm), in sight
local PASS_GAP, NO_RETURN = 1.0, 5.0     -- at most one pass a second; never handed straight back within 5 s
local FAST = 10                          -- the last seconds: the beep and the light speed up
local BLAST, FLOOR, PUSH = 800, 10, 0.4  -- reach (cm); life always left when it may not kill; strongest push then
local MAX_PASS_LINES = 12                -- passes written one by one in the summary, the rest as a count
local TINT = { 1.0, 0.75, 0.5 }          -- the carrier's veil, a light orange (never red: the dissidents' colour)
local VEIL_PULSE = false                 -- true: the veil as short flashes, should the steady one flicker in game

local M = { id = "potato", switch = "event_potato",
            KEYS = { "event_potato_min", "event_potato_max", "event_potato_damage", "event_potato_lethal" },
            min_living = 3, min_present = 3, not_before = 60, not_last = 90 }

-- The passes may follow each other every second: they are told by the notice at the top of the
-- screen (shown at once, replacing the one before), never by the banners, which queue.
M.TEXT = {
    START   = { "PATATE CHAUDE !" },
    WHO     = { "%s A LA BOMBE", "name", c = "warn" },
    RULE    = { "COLLEZ-LA À QUELQU'UN !" },
    HAS     = { "%s A LA BOMBE", "name", c = "warn", n = true },
    YOU     = { "TU AS LA BOMBE !", c = "bad", n = true },
    PASSED  = { "BOMBE PASSÉE", c = "good", n = true },
    -- the name goes in the notice that follows (HAS): with it, a notice would not fit its one line
    JUMP    = { "LA BOMBE SAUTE !", c = "warn" },
    BOOM    = { "BOUM SUR %s !", "name", c = "bad" },
    DEFUSED = { "BOMBE DÉSAMORCÉE", c = "good" },
    NOPE    = { "TEST : PERSONNE POUR LA BOMBE", c = "warn" },
}
-- No countdown in the lines: the delay is a secret.
M.LINES = {
    CARRY = { "Tu as la bombe : colle-toi à un joueur pour la lui passer. Elle explose sans prévenir." },
    WATCH = { "La bombe est sur %s : elle explose sans prévenir, sur lui et autour de lui.", "name" },
}
M.RECAP = {
    ev_potato         = { "Évènement : patate chaude, bombe donnée à %s", "name" },
    ev_potato_pass    = { "Bombe : %s l'a passée à %s", "name", "name" },
    ev_potato_jump    = { "Bombe : sautée sur %s", "name" },
    ev_potato_more    = { "Bombe : %s passes de plus", "num" },
    ev_potato_boom    = { "Bombe : explosion sur %s (%s joueur(s) à portée)", "name", "num" },
    ev_potato_defused = { "Bombe : désamorcée" },
}
M.SOUNDS = { "ev_potato_beep", "ev_potato_beep_fast" }

-- Who may carry the bomb: present (ctx.present: alive, of the game, in its own body, not hidden,
-- not flying, not just woken) and with the mod.
local function can_carry(ctx, P)
    return P ~= nil and P.modded == true and ctx.present(P)
end

local function candidates(ctx, but)
    return ctx.living(function(P) return P ~= but and can_carry(ctx, P) end)
end

-- The players of the game but a and b (the dead included: they watch).
local function others(ctx, a, b)
    local out = {}
    ctx.each(function(Q) if Q ~= a and Q ~= b then out[#out + 1] = Q end end)
    return out
end

-- The carrier's light and beep at the pace of the moment: the same slots, so a pass or the last
-- seconds replace them. The fast pulse stays at 0.3 s: the machines redraw a light ten times a
-- second, and a beat of 0.2 s would be read at the same point every time (no pulse at all).
local function rate(ctx, P)
    local fast = ctx.run.fast
    ctx.glow("bomb", P, "orange", 350, fast and 0.3 or 0.5, 6000)
    ctx.sound("beep", fast and "ev_potato_beep_fast" or "ev_potato_beep", P,
              { period = fast and 0.35 or 1.0, inner = 300, falloff = 1200 })
end

-- The tablet: everyone reads who carries it (the face worn), the carrier its own line. The line
-- to everyone also takes the last carrier's own line off.
local function show_lines(ctx)
    local r = ctx.run
    ctx.line(nil, "WATCH", 0, r.face)
    ctx.line(r.P, "CARRY", 0)
end

-- The passes past the first twelve, as one line of the summary (once, before the last line).
local function tell_more(ctx)
    local r = ctx.run
    if r.more_told or (r.passes or 0) <= MAX_PASS_LINES then return end
    r.more_told = true
    ctx.recap("ev_potato_more", r.passes - MAX_PASS_LINES)
end

-- P gets the bomb. how: "start", "pass" (from the carrier, at a touch) or "jump" (the carrier
-- could no longer carry it).
local function give(ctx, P, now, how)
    local r = ctx.run
    local from = r.P
    if from and from ~= P and ctx.valid(from) then ctx.tint(from, nil) end
    -- the one who had it cannot get it straight back (a Fée who lands again included)
    r.prev, r.P, r.passed_at = from, P, now
    r.last_at, r.face = ctx.where(P) or r.last_at, ctx.face(P)
    rate(ctx, P)
    ctx.tint(P, TINT, { pulse = VEIL_PULSE })
    ctx.flash(P, "orange", 4)
    if how == "pass" then
        ctx.notice(from, "PASSED")
        ctx.notice(others(ctx, P, from), "HAS", r.face)
        r.passes = r.passes + 1
        if r.passes <= MAX_PASS_LINES then ctx.recap("ev_potato_pass", ctx.idx(from), ctx.idx(P)) end
    elseif how == "jump" then
        ctx.say(nil, "JUMP")
        ctx.notice(others(ctx, P), "HAS", r.face)
        ctx.recap("ev_potato_jump", ctx.idx(P))
    end
    ctx.notice(P, "YOU")
    show_lines(ctx)
end

-- Nobody can carry it any more.
local function defuse(ctx)
    local r = ctx.run
    r.defused = true
    tell_more(ctx)
    ctx.say(nil, "DEFUSED")
    ctx.recap("ev_potato_defused")
    ctx.finish("done")
end

-- The carrier can no longer carry it: the bomb goes to the nearest player who can, from where the
-- carrier was last seen (no sight needed: a carrier who hides or flies off must not keep it, and a
-- hidden Clandestin's real place is never looked at).
local function jump(ctx, now)
    local r = ctx.run
    local from, best, bd = r.last_at, nil, nil
    for _, T in ipairs(candidates(ctx, r.P)) do
        local p = ctx.where(T)
        local d = (p and from) and U.dist(p, from) or math.huge
        if not best or d < bd then best, bd = T, d end
    end
    if not best then return defuse(ctx) end
    give(ctx, best, now, "jump")
end

-- Zero: the game's C4 effects on the carrier. The others within reach and in sight take a blast
-- that weakens fast with the distance and pushes them away; the carrier (who must not get the
-- game's blast: its trace would start inside its own head and throw it any way) takes a blow with
-- no direction that stops it dead, then is exhausted (its item drops, it staggers and can pick
-- nothing up for a moment). Not lethal by default: everyone keeps FLOOR.
local function boom(ctx)
    local r = ctx.run
    local P = r.P
    r.boomed = true
    local hp, lethal = C.get("event_potato_damage"), C.get("event_potato_lethal") == true
    local c = ctx.where(P) or r.last_at
    ctx.glow_off("bomb")
    ctx.sound_off("beep")
    ctx.tint(P, nil)
    ctx.line(nil, nil)
    local near = {}
    if c then
        local at = { X = c.X, Y = c.Y, Z = c.Z + 100 }
        near = ctx.blast(at, BLAST, hp, { lethal = lethal, floor = FLOOR, push = PUSH, fx = "c4", cause = "bomb",
                                          skip = { P } })
    end
    ctx.hurt(P, hp, { lethal = lethal, floor = FLOOR, stun = 0.8, cause = "bomb" })
    -- (the frame's exhaust drops the item itself when the player is already exhausted)
    ctx.exhaust(P)
    ctx.say(nil, "BOOM", ctx.face(P))
    tell_more(ctx)
    ctx.recap("ev_potato_boom", ctx.idx(P), #near)
    ctx.at(1.5, function() ctx.finish("done") end)
end

-- Two carriers at least (one in TEST: the host alone gets it and tests the blast on itself).
function M.can_start(ctx, now, test)
    if #candidates(ctx) < (test and 1 or 2) then return false, "NOPE" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    local list = candidates(ctx)
    if #list == 0 then return false end
    local lo, hi = C.get("event_potato_min"), C.get("event_potato_max")
    if hi < lo then lo, hi = hi, lo end
    r.boom_at, r.passes = now + lo + math.random() * (hi - lo), 0
    local P = list[math.random(#list)]
    ctx.say(nil, "START")
    ctx.say(nil, "WHO", ctx.face(P))
    ctx.say(nil, "RULE")
    give(ctx, P, now, "start")
    ctx.recap("ev_potato", ctx.idx(P))
    ctx.log("bombe donnée au joueur %d, explosion dans %d s", ctx.idx(P), math.floor(r.boom_at - now))
    -- the longest delay, never the one drawn: EVON tells this number to every machine
    return hi + 5
end

function M.tick(ctx, now)
    local r = ctx.run
    if r.boomed or r.defused then return end
    local P = r.P
    if not can_carry(ctx, P) then return jump(ctx, now) end
    r.last_at = ctx.where(P) or r.last_at
    if now >= r.boom_at then return boom(ctx) end
    if not r.fast and now >= r.boom_at - FAST then
        r.fast = true
        rate(ctx, P)
    end
    -- a Métamorphe carrier who takes another face: the line names the face now worn
    ctx.every(1, "face", function()
        local face = ctx.face(P)
        if face ~= r.face then
            r.face = face
            show_lines(ctx)
        end
    end)
    if now - r.passed_at < PASS_GAP then return end
    local a, best, bd = r.last_at, nil, nil
    for _, T in ipairs(candidates(ctx, P)) do
        if not (T == r.prev and now - r.passed_at < NO_RETURN) then
            local b = ctx.where(T)
            if a and b and math.abs(a.Z - b.Z) <= TOUCH_Z then
                local d = math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2)
                -- a wall between them stops the pass (sight looked at only for those close enough)
                if d <= TOUCH and (not bd or d < bd) and ctx.sees(P, T) then best, bd = T, d end
            end
        end
    end
    if best then give(ctx, best, now, "pass") end
end

-- The carrier died before the end (a blow, a poison, a bond...): the bomb jumps at once.
function M.on_death(ctx, P)
    local r = ctx.run
    if P == r.P and not (r.boomed or r.defused) then jump(ctx, ctx.now()) end
end

-- Stopped before its time: switched off, TEST, timeout (defused, said); the end of the game:
-- nothing blows up and nothing is said. The frame takes the light, the beep, the veil and the
-- lines back.
function M.stop(ctx, reason)
    local r = ctx.run
    if r.boomed or r.defused then return end
    tell_more(ctx)
    if reason == "end" then return end
    ctx.say(nil, "DEFUSED")
    ctx.recap("ev_potato_defused")
end

-- Nothing of its own on the machines: the frame's messages (EVGLOW, EVSND, EVBODY, EVFX, EVLINE)
-- do it all.
M.client = {}

return M
