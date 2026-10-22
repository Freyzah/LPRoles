-- LPRoles - évènement « LES MORTS SAVENT » : an emergency capsule (a cyan egg, an item of the game no
-- task uses) is lost somewhere in the ship, far from every living player. Only the dead see where
-- it is; each ghost can make a beep sound where it floats, heard by everyone. The living player who
-- picks it up gives the clock some time, whatever its camp (a dissident cannot keep it). Not found
-- in time: it goes out, with no penalty. The dead dissidents may of course beep in the wrong places.
--   Host: the capsule followed, the dead's keys (B, or G for a Revenant that still has
--   apparitions: B keeps its power), each beep placed at the ghost, deaths and raises during the
--   event, the end.
--   Every machine: nothing of its own; the frame's messages show it all (the column for the dead,
--   the beeps, banners, the tablet's line).
local C = require("lpr_config")
local G = require("lpr_game")
local W = require("lpr_ev_world")

local M = { id = "deadknow", switch = "event_deadknow",
            KEYS = { "event_deadknow_seconds", "event_deadknow_bonus", "event_deadknow_cooldown" },
            min_living = 2, needs_dead = true, not_last = 150 }

-- How far from every living player the capsule is put down (cm), tried in this order: as far as
-- the ship allows.
local MIN_DIST = { 1500, 1000, 500, 0 }
-- A beep: full up to 3 m, nothing beyond about 18 m (through the walls too: the frame's sound).
local BEEP = { inner = 300, falloff = 1500 }
local EGG_VALUE = 1        -- the egg's colour (state Value): 1 is cyan
local WELCOME = 2.5        -- s after a death before the new ghost is told: its death screen first
local GRACE = 2            -- s: an item moves in one go on the host; this is a margin before "gone"

-- The living read three banners, the dead two; the dead keep their orders in a banner (they may
-- not be able to open their tablet). Whoever finds it is named by the face it wears (it is seen
-- picking it up), the summary gives the real name.
M.TEXT = {
    START   = { "CAPSULE DE SECOURS PERDUE" },
    HINT    = { "LES MORTS SAVENT OÙ" },
    BONUS   = { "TROUVEZ-LA : +%s AU CHRONO", "clock" },
    DSTART  = { "LA CAPSULE BRILLE POUR VOUS" },
    DKEY    = { "%s : BIPER OÙ TU ES", "key" },
    ALIVE   = { "TU ES VIVANT : PLUS DE BIP" },
    FOUND   = { "CAPSULE TROUVÉE : +%s", "clock", c = "good" },
    FOUNDBY = { "TROUVÉE PAR %s", "name", c = "good" },
    LOST    = { "LA CAPSULE S'EST ÉTEINTE", c = "warn" },
    NOPE    = { "TEST : AUCUN MORT AVEC LE MOD", c = "warn" },
    NOSPOT  = { "TEST : AUCUN EMPLACEMENT", c = "warn" },
}

M.LINES = {
    LIVE = { "Capsule de secours (+%s) : suivez les bips des morts - {t}", "clock" },
    DEAD = { "La capsule brille pour toi : %s pour biper où tu flottes - {t}", "key" },
}

M.RECAP = {
    ev_deadknow       = { "Évènement : les morts savent (capsule : %s)", "sector_low" },
    ev_deadknow_found = { "Capsule : trouvée par %s (+%s au chrono)", "name", "clock" },
    ev_deadknow_beeps = { "Capsule : %s a bipé %s fois", "name", "num" },
    ev_deadknow_lost  = { "Capsule : jamais trouvée" },
}

M.SOUNDS = { "ev_deadknow_beep" }

-- ---------------------------------------------------------------- host
local function modded(P) return P.modded == true end

-- The key P beeps with: "use" (G) for a dead Revenant that still has apparitions (B starts one),
-- "act" (B) for everyone else. Routes it when it changed (a Revenant that has just used its last
-- apparition beeps with B from then on); true when it changed.
local function route(ctx, P)
    local r = ctx.run
    local kind = (P.role == "revenant" and (P.charges or 0) > 0) and "use" or "act"
    if r.route[P.key] == kind then return false end
    r.route[P.key] = kind
    ctx.key(P, kind == "act", kind == "use")
    return true
end

-- A dead player with the mod is told what it can do and its key is taken. The column and the
-- dead's line reach it through the frame's audience "dead"; a Revenant beeping with G gets a line
-- of its own that names that key.
local function welcome(ctx, P, left)
    local r = ctx.run
    route(ctx, P)
    ctx.say(P, "DSTART")
    ctx.say(P, "DKEY", r.route[P.key])
    if r.route[P.key] == "use" then ctx.line(P, "DEAD", left, "use") end
end

-- A living player has it: the capsule taken from its hand (or bag), the time given to everyone,
-- the end. The end waits a moment for the sound (the end of the event cuts its sounds).
local function found(ctx, P)
    local r = ctx.run
    r.done, r.found = true, true
    ctx.remove(r.rec)
    ctx.unmark("e1")
    local gain = ctx.add_time(r.bonus)
    ctx.say(nil, "FOUND", gain)
    ctx.say(nil, "FOUNDBY", ctx.face(P))
    ctx.sound("found", "ev_deadknow_beep", nil, {})
    ctx.recap("ev_deadknow_found", P, gain)
    ctx.log("capsule trouvée par %s (+%d s)", G.player_name(P.mec), gain)
    ctx.at(1, function() ctx.finish("found") end)
end

-- Where the capsule is, ten times a second: behind the pick-up hook, in case it is missed. A
-- capsule the game destroyed (fallen out of the ship) ends the event without a banner.
local function check(ctx, now)
    local r = ctx.run
    if r.done then return end
    local t = ctx.track(r.rec)
    local P = (t.where == "hand" or t.where == "bag") and t.P or nil
    if P and ctx.valid(P) and G.is_alive(P.mec) then return found(ctx, P) end
    if t.where == "gone" or t.where == "slot" then
        r.gone_since = r.gone_since or now
        if now - r.gone_since >= GRACE then
            r.done = true
            ctx.finish("gone")
        end
    else
        r.gone_since = nil
    end
end

-- Outside TEST at least one dead and two living (the frame's conditions); in TEST too, a dead
-- player with the mod is needed (no one else could beep) and a free item place.
function M.can_start(ctx, now, test)
    if #ctx.dead(modded) == 0 then return false, "NOPE" end
    if #W.spawners(nil, true) == 0 then return false, "NOSPOT" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    local secs = C.get("event_deadknow_seconds")
    r.bonus, r.cd = C.get("event_deadknow_bonus"), C.get("event_deadknow_cooldown")
    r.route, r.last, r.beeps, r.pending = {}, {}, {}, {}
    -- far from the living: a dreaming Rêveur's body counts, a hidden Clandestin has no place
    local far = {}
    for _, P in ipairs(ctx.living()) do
        local p = ctx.where(P)
        if p then far[#far + 1] = p end
    end
    for _, d in ipairs(MIN_DIST) do
        r.rec = ctx.place(W.ASSET.EASTEREGG, { value = EGG_VALUE, far_from = far, min_dist = d })
        if r.rec then break end
    end
    if not r.rec then return false end
    -- the column for the dead only: the frame keeps the audience up to date as players die or
    -- are raised, and moves the column when the capsule is knocked about
    ctx.mark_item("e1", r.rec, "cyan", true, "dead")
    ctx.say("living", "START")
    ctx.say("living", "HINT")
    ctx.say("living", "BONUS", r.bonus)
    ctx.line("living", "LIVE", secs, r.bonus)
    ctx.line("dead", "DEAD", secs, "act")
    for _, P in ipairs(ctx.dead(modded)) do welcome(ctx, P, secs) end
    local s = W.sector_at(r.rec.at)
    ctx.recap("ev_deadknow", s or -1)
    ctx.log("capsule posée secteur %d", s or 0)
    return secs
end

function M.tick(ctx, now)
    local r = ctx.run
    if r.done then return end
    -- every second, the dead's keys: a Revenant that used its last apparition beeps with B now;
    -- a dead player not welcomed yet (the mod known late) is welcomed. A death just now waits for
    -- its own welcome (M.on_death).
    ctx.every(1, "route", function()
        for _, P in ipairs(ctx.dead(modded)) do
            if not r.pending[P.key] then
                local was = r.route[P.key]
                if route(ctx, P) then
                    if not was then ctx.say(P, "DSTART") end
                    ctx.say(P, "DKEY", r.route[P.key])
                    if r.route[P.key] == "use" then
                        ctx.line(P, "DEAD", ctx.ends - now, "use")
                    else
                        ctx.line(P, nil)        -- back to the dead's line, which names B
                    end
                end
            end
        end
    end)
    ctx.every(0.1, "track", check)
    if not r.done and now >= ctx.ends then
        r.done = true
        ctx.say(nil, "LOST")
        ctx.finish("lost")                      -- no penalty; the undo takes the capsule away
    end
end

-- A living player picked something up: the capsule, perhaps.
function M.on_pick(ctx, P)
    check(ctx, ctx.now())
end

-- A ghost's key: a beep where it floats, heard by everyone around it (the living do not see or
-- hear the ghost itself, only the beep). One every few seconds per ghost: too soon, the short
-- failure sound. Each ghost has its own sound slot, so beeps of several ghosts may overlap.
function M.on_key(ctx, P, kind)
    local r = ctx.run
    if r.route[P.key] ~= kind or G.is_alive(P.mec) then return false end      -- a Revenant's B: its apparition
    if r.done then return true end
    local now = ctx.now()
    if now - (r.last[P.key] or -1e9) < r.cd then
        ctx.sfx(P, "fail")
        return true
    end
    local at = ctx.ghost_at(P)
    if not at then
        ctx.sfx(P, "fail")
        return true
    end
    r.last[P.key] = now
    r.beeps[P.key] = (r.beeps[P.key] or 0) + 1
    ctx.sound("b" .. ctx.idx(P), "ev_deadknow_beep", at, BEEP)
    return true
end

-- A player of the game died during the event: once its death screen is past, it sees the column
-- (the frame's audience) and may beep. A Lié following its partner in death does too.
function M.on_death(ctx, P)
    local r = ctx.run
    if r.done or not P.modded then return end
    r.pending[P.key] = true
    ctx.at(WELCOME, function()
        r.pending[P.key] = nil
        if r.done or not ctx.valid(P) or G.is_alive(P.mec) then return end
        r.route[P.key] = nil                    -- routed again, whatever it had before a raise
        welcome(ctx, P, ctx.ends - ctx.now())
    end)
end

-- Raised (Ange gardien, defibrillator): no more beeps. The column and the dead's line go with the
-- frame's audience; a Revenant's own line gives way to the living's. A body the Nettoyeur cleaned
-- is not told it lives: lpr_server undoes that raise at once (0.3 s), and the death that follows
-- welcomes it back (M.on_death).
function M.on_rez(ctx, P)
    local r = ctx.run
    r.pending[P.key] = nil
    if r.route[P.key] then
        r.route[P.key] = nil
        ctx.key(P, false, false)
        if not r.done and not P.cleaned then ctx.say(P, "ALIVE") end
    end
    ctx.line(P, nil)
end

-- The summary: how many beeps each dead player still here gave (one who left is forgotten), and
-- a capsule never found. Everything else is the frame's undo: the capsule taken away wherever it
-- is, its column, the keys given back, the lines. The time given is never taken back.
function M.stop(ctx, reason)
    local r = ctx.run
    for key, n in pairs(r.beeps or {}) do
        local P = ctx.by_key(key)
        if P and ctx.valid(P) and n > 0 then ctx.recap("ev_deadknow_beeps", P, n) end
    end
    if r.found then return end
    if reason == "timeout" then ctx.say(nil, "LOST") end
    if reason ~= "off" and reason ~= "test" and reason ~= "end" then ctx.recap("ev_deadknow_lost") end
end

-- Nothing local: the frame's messages show everything (and take it back at the end).
M.client = {}

return M
