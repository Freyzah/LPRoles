-- LPRoles - évènement « COLIS PRIORITAIRE » : the ship puts a parcel (a food can, user's decision:
-- the jerrican is a heavy weapon) down in one sector and a beacon in one of the two sectors
-- furthest from it. Whoever stays 3 s by the beacon, parcel in hand, delivers it: the clock gains
-- time. Not delivered in time: the clock loses some. Anyone may deliver, keep it, lose it or kill
-- its carrier: the carrier is at once the escort, the target and the suspect (it glows and beeps).
--   Host: the parcel followed wherever it goes (ground, hands, bags), its carrier's light and
--   beep, the delivery by the beacon, the clock, the end.
--   Every machine: nothing of its own; the frame's messages show it all (columns, light, beep,
--   banners, notices, the tablet's line).
-- It may come back in the same game.
local C = require("lpr_config")
local G = require("lpr_game")
local W = require("lpr_ev_world")

local M = { id = "parcel", switch = "event_parcel",
            KEYS = { "event_parcel_seconds", "event_parcel_bonus", "event_parcel_malus" },
            min_living = 3, not_last = 180 }

local ZONE, ZONE_DZ = 300, 200   -- cm around the beacon, and up or down (the same floor)
local HOLD = 3                   -- s by the beacon, parcel in hand, to deliver it
local FAR = 1200                 -- cm: put down this far from every living player when it can be
local GRACE = 2                  -- s: an item moves in one go on the host; this is a margin before "gone"
local LATE = 30                  -- s left when everyone is reminded
local FLOOR = 30                 -- s: the penalty never takes the clock below this
-- The carrier's faint light (the Fée's is 8000 for 350 cm) and its soft beep, heard a few metres
-- around (full up to 1.5 m, nothing beyond about 10 m), never across the ship.
local GLOW = { color = "green", radius = 250, pulse = 1.0, power = 3000 }
local BEEP = { inner = 150, falloff = 900, period = 2.0 }

-- The title as a notice (shown at once), then three banners at most: the frame's budget. The
-- carrier is never named (a Métamorphe's face would be anyway): the light shows who has it.
M.TEXT = {
    START   = { "COLIS PRIORITAIRE", n = true },
    ROUTE   = { "%s VERS %s", "sector", "sector" },
    TIME    = { "À LIVRER EN %s", "clock" },
    STAKES  = { "LIVRÉ : +%s, PERDU : -%s", "clock", "clock" },
    WIN     = { "LIVRÉ : +%s AU CHRONO", "clock" },
    RISK    = { "PERDU : -%s AU CHRONO", "clock" },
    YOU     = { "TU PORTES LE COLIS", c = "info" },
    BEACON  = { "BALISE : %s", "sector", c = "info" },
    HAND    = { "SORS LE COLIS DU SAC", c = "warn", n = true },
    COUNT   = { "LIVRAISON : %s", "num", c = "good", n = true },
    LATE    = { "COLIS : PLUS QUE %s SECONDES", "num", c = "warn" },
    DONE    = { "COLIS LIVRÉ : +%s", "clock", c = "good" },
    DONE0   = { "COLIS LIVRÉ", c = "good" },
    LOST    = { "COLIS PERDU : -%s", "clock", c = "bad" },
    LOST0   = { "COLIS PERDU", c = "bad" },
    BACK    = { "LE COLIS RÉAPPARAÎT" },
    WHERE   = { "SECTEUR %s", "sector" },
    NOPLACE = { "TEST : AUCUNE PLACE LIBRE", c = "warn" },
}

M.LINES = {
    GROUND = { "Colis prioritaire au sol : balise secteur %s - {t}", "sector" },
    MOVING = { "Colis prioritaire en route vers la balise, secteur %s - {t}", "sector" },
    CARRY  = { "Tu portes le colis : balise secteur %s, 3 s colis en main - {t}", "sector" },
}

M.RECAP = {
    ev_parcel          = { "Évènement : colis prioritaire, secteur %s vers secteur %s", "sector_low", "sector_low" },
    ev_parcel_carry    = { "Colis : porté par %s", "name" },
    ev_parcel_done     = { "Colis : livré par %s (+%s au chrono)", "name", "clock" },
    ev_parcel_done0    = { "Colis : livré par %s", "name" },
    ev_parcel_lost     = { "Colis : perdu (-%s au chrono)", "clock" },
    ev_parcel_lost0    = { "Colis : perdu" },
    ev_parcel_back     = { "Colis : réapparu secteur %s, son porteur est parti", "sector_low" },
    ev_parcel_vanished = { "Colis : parti avec son porteur, sans pénalité" },
}

M.SOUNDS = { "ev_parcel_beep", "ev_parcel_done" }

-- ---------------------------------------------------------------- host
-- A sector where the parcel can lie: one of its item places is free.
local function has_free(s)
    return #W.spawners(s, true) > 0
end

-- The parcel put down in sector s (any sector when nil); far: away from every living player when
-- it can be (a hidden Clandestin gives no place, never its real one, and is left out).
local function put_down(ctx, s, far)
    local spots = {}
    if far then
        for _, P in ipairs(ctx.living()) do
            local p = ctx.where(P)
            if p then spots[#spots + 1] = p end
        end
    end
    return ctx.place(W.ASSET.FOODCAN, { sector = s, value = 0, far_from = spots, min_dist = FAR })
        or (far and ctx.place(W.ASSET.FOODCAN, { sector = s, value = 0 })) or nil
end

-- Whether H's being by the beacon counts: alive, not flying (land first), not hidden (no place),
-- not getting back into its body (a Rêveur just woken). A dreaming Rêveur's body sitting in the
-- zone, parcel in hand, counts: it brought it there.
local function can_deliver(ctx, H, now)
    return ctx.valid(H) and G.is_alive(H.mec) and not H.fairy and not H.hiding
        and not (H.tail and now < (H.tail.ends or 0))
end

-- The tablet's lines: where the parcel is for everyone, and its carrier's own.
local function lines(ctx, now)
    local r = ctx.run
    local left = math.max(1, ctx.ends - now)
    ctx.line(nil, r.holder and "MOVING" or "GROUND", left, r.to)
    if r.holder then ctx.line(r.holder, "CARRY", left, r.to) end
end

-- The light and the beep on P (none when nil): they follow the carrier, and go out while it
-- cannot be seen (a hidden Clandestin: nothing that would show where it really is).
local function light(ctx, P)
    local r = ctx.run
    if P == r.shown then return end
    if r.shown then
        ctx.glow_off("g1")
        ctx.sound_off("b1")
    end
    r.shown = P
    if P then
        ctx.glow("g1", P, GLOW.color, GLOW.radius, GLOW.pulse, GLOW.power)
        -- around the carrier for the others, heard as it is by the carrier
        ctx.sound("b1", "ev_parcel_beep", P, BEEP)
    end
end

-- Delivered: the parcel gone, the clock up, a short success sound heard by everyone. The end
-- waits for the sound (the end of the event cuts its sounds).
local function deliver(ctx, H)
    local r = ctx.run
    r.closed = true
    light(ctx, nil)
    ctx.remove(r.rec)
    ctx.unmark("e1")
    ctx.unmark("e2")
    local bonus = C.get("event_parcel_bonus")
    local gain = bonus > 0 and ctx.add_time(bonus) or 0
    if gain > 0 then
        ctx.say(nil, "DONE", gain)
        ctx.recap("ev_parcel_done", H, gain)
    else
        ctx.say(nil, "DONE0")
        ctx.recap("ev_parcel_done0", H)
    end
    ctx.sound("p2", "ev_parcel_done", nil, {})
    ctx.log("colis livré par %s (+%d s)", G.player_name(H.mec), gain)
    ctx.at(1.5, function() ctx.finish("delivered") end)
end

-- Not delivered: the clock loses the penalty, never below FLOOR and never up (the frame's
-- add_time). The undo takes the parcel, its column, the beacon, the light away.
local function fail(ctx)
    local r = ctx.run
    r.closed = true
    local malus = C.get("event_parcel_malus")
    local lost = malus > 0 and -ctx.add_time(-malus, FLOOR) or 0
    if lost > 0 then
        ctx.say(nil, "LOST", lost)
        ctx.recap("ev_parcel_lost", lost)
    else
        ctx.say(nil, "LOST0")
        ctx.recap("ev_parcel_lost0")
    end
    ctx.finish("failed")
end

-- Its carrier left the game with it: the parcel comes back in the sector the carrier was last
-- seen in (anywhere if that sector has no free place), with no penalty. None at all: the event
-- ends, with no penalty either (nobody failed).
local function reappear(ctx, now)
    local r = ctx.run
    light(ctx, nil)
    local rec = put_down(ctx, W.sector_at(r.last_at) or r.from, false) or put_down(ctx, nil, false)
    if not rec then
        r.closed = true
        ctx.say(nil, "LOST0")
        ctx.recap("ev_parcel_vanished")
        return ctx.finish("vanished")
    end
    r.rec, r.holder, r.hold, r.count = rec, nil, nil, nil
    local s = W.sector_at(rec.at) or r.from
    ctx.mark_item("e1", rec, "green", true)
    ctx.say(nil, "BACK")
    ctx.say(nil, "WHERE", s)
    ctx.recap("ev_parcel_back", s)
    lines(ctx, now)
end

-- Where the parcel is now, ten times a second (and at once after a pick-up).
local function update(ctx, now)
    local r = ctx.run
    if r.closed then return end
    local t = ctx.track(r.rec)
    if t.where == "slot" then
        -- no machine known takes a food can: one that did keeps it from being delivered
        ctx.remove(r.rec)
        return fail(ctx)
    end
    if t.where == "gone" then
        r.gone_since = r.gone_since or now
        if now - r.gone_since < GRACE then return end
        r.gone_since = nil
        if r.holder and not ctx.valid(r.holder) then return reappear(ctx, now) end
        return fail(ctx)                    -- fallen out of the ship: a failure, penalty included
    end
    r.gone_since = nil
    local H = (t.where == "hand" or t.where == "bag") and t.P or nil
    if H ~= r.holder then
        light(ctx, nil)
        r.holder, r.hold, r.count = H, nil, nil
        if H and not r.carried[H.key] then
            -- each carrier once: told what it has and where to take it (the summary has them all)
            r.carried[H.key] = true
            ctx.recap("ev_parcel_carry", H)
            ctx.say(H, "YOU")
            ctx.say(H, "BEACON", r.to)
        end
        lines(ctx, now)
    end
    -- in a hand or a bag alike, the parcel does not hide
    local at = H and ctx.where(H) or nil
    light(ctx, at and H or nil)
    if at then r.last_at = at end
    -- the delivery: HOLD seconds in the zone, parcel in hand, counted down on the carrier's notice
    local near = at ~= nil and can_deliver(ctx, H, now) and W.dist2d(at, r.spot) <= ZONE
        and math.abs(at.Z - r.spot.Z) <= ZONE_DZ
    if near and t.where == "hand" then
        r.hold = r.hold or now
        if now - r.hold >= HOLD then return deliver(ctx, H) end
        local n = math.ceil(HOLD - (now - r.hold))
        if n ~= r.count then
            r.count = n
            ctx.notice(H, "COUNT", n)
        end
    else
        r.hold, r.count = nil, nil
        if near and now - (r.bag_told or -1e9) >= 4 then          -- in the bag, right by the beacon
            r.bag_told = now
            ctx.notice(H, "HAND")
        end
    end
    if not r.late_told and ctx.planned >= 60 and ctx.ends - now <= LATE then
        r.late_told = true
        ctx.say(nil, "LATE", LATE)
    end
end

-- Outside TEST the game must not end during the delivery (the clock is above the time to
-- deliver + 30 s); a free item place and a sector with spawn points (the beacon) are needed.
function M.can_start(ctx, now, test)
    if not test and ctx.clock() <= C.get("event_parcel_seconds") + 30 then return false end
    if not W.random_sector(has_free) or #W.spawn_spots() == 0 then return false, "NOPLACE" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    local secs, bonus, malus = C.get("event_parcel_seconds"), C.get("event_parcel_bonus"), C.get("event_parcel_malus")
    r.from = W.random_sector(has_free)
    if not r.from then return false end
    -- the beacon: one of the two sectors furthest from the start, so that the pair is not always
    -- the same; a sector of spawn points anyway if the start has none to measure from
    local far = W.far_sectors(r.from, 2)
    r.to = far[math.random(math.max(1, #far))]
        or W.random_sector(function(s) return s ~= r.from and #W.spawn_spots(s) > 0 end)
    r.spot = r.to and W.spawn_spot(r.to)
    r.rec = r.spot and put_down(ctx, r.from, true)
    if not r.rec then return false end
    r.carried, r.holder = {}, nil
    ctx.mark_item("e1", r.rec, "green", true)
    ctx.mark("e2", r.spot, "cyan", true, "col")
    ctx.notice(nil, "START")
    ctx.say(nil, "ROUTE", r.from, r.to)
    ctx.say(nil, "TIME", secs)
    if bonus > 0 and malus > 0 then
        ctx.say(nil, "STAKES", bonus, malus)
    elseif bonus > 0 then
        ctx.say(nil, "WIN", bonus)
    elseif malus > 0 then
        ctx.say(nil, "RISK", malus)
    end
    ctx.line(nil, "GROUND", secs, r.to)
    ctx.recap("ev_parcel", r.from, r.to)
    ctx.log("colis secteur %d vers secteur %d", r.from, r.to)
    return secs
end

function M.tick(ctx, now)
    ctx.every(0.1, "track", update)
    if not ctx.over and not ctx.run.closed and now >= ctx.ends then fail(ctx) end
end

-- The game's pick-up, or a Voleur's theft: the light changes hands at once.
function M.on_pick(ctx, P)
    update(ctx, ctx.now())
end

-- A carrier who dies drops the parcel (the game does it): its count starts again for the next one.
function M.on_death(ctx, P)
    local r = ctx.run
    if P == r.holder then r.hold, r.count = nil, nil end
end

-- Only the module's own end touches the clock (delivered or failed): a stop of the frame (off,
-- TEST, the end of the game, timeout) gives and takes nothing. Everything else is the frame's
-- undo: the parcel taken away wherever it is, the columns, the light, the beep, the lines.
function M.stop(ctx, reason)
    if not ctx.run.closed then ctx.log("arrêté (%s) : ni gain ni perte", reason) end
end

-- Nothing local: the frame's messages show everything (and take it back at the end).
M.client = {}

return M
