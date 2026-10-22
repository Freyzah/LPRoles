-- LPRoles - random event FUITE DE GAZ (gas leak): gas leaks in a sector where players are, then
-- blows up; the air around the leak stays foul for a while after.
--   - Notice (event_gas_notice): the sector's alarm boxes ring without a pause, the gas hisses
--     around the leak, a green ball and a green light mark it (not through the walls), a light
--     green veil warns whoever comes near; the last five seconds are counted down at the top of
--     the screen. The siren wakes a dreaming Rêveur whose body is near enough: on its machine the
--     game would measure the blast from its ghost, not from its body.
--   - Explosion at the leak: by default the game's own blast ("Get Explosion" on each player's
--     machine, players without the mod included: walls protect, damage down to nothing at 15 m,
--     may kill a player already low), with the game's gas explosion effects. Option: the game's
--     real explosion (the one of a gas bottle: deadly near, 30 m). A death by it has no killer.
--   - Cloud (event_gas_cloud, 0 = none): near the leak the players tire every second (veil,
--     cough heard around them), until exhausted (the item drops, nothing can be used).
--   - Only players present in the ship are veiled, blown or tired: not the dead, a dreaming
--     Rêveur's body, a flying Fée, a hidden Clandestin (whose real place is never looked at).
-- Everything shown (sirens, sounds, mark, light, veils, lines) is the frame's and is taken back by
-- it at the end; the damage and the deaths stay, they are the event.
local C = require("lpr_config")
local G = require("lpr_game")
local U = require("lpr_util")
local W = require("lpr_ev_world")

-- Distances, from the leak (cm).
local REACH = {
    blast = 1500,            -- the softened blast's range (the game's "Get Explosion" on each machine)
    real = 3500,             -- where the game's real explosion strikes (Explosion_C, host only)
    near = 600,              -- the light veil during the notice
    cloud = 1200,            -- the foul air after the explosion
    wake = 500,              -- the siren wakes a dreaming body this much beyond the blast's range
}
-- Paces and amounts.
local PACE = {
    tire = 12,               -- tiredness a second in the cloud (to tune in game against the recovery)
    hold = 1.5,              -- the game's own recovery held this long after each second in the cloud
    hurt = 1.5,              -- s after the blast: a player's machine reporting damage is the blast's
    cough = 3,               -- a cough every 3 s around a player in the cloud
    told = 10,               -- "GAZ : TU T'ÉPUISES" at most this often to one player (s)
}
local LEAK_Z = 100           -- the leak, above a spawn point (on the floor, clear: its blast is not walled in)
local VEIL_NEAR, VEIL_CLOUD = { 0.85, 1.0, 0.75 }, { 0.6, 1.0, 0.45 }
local VEIL_PULSE = false     -- true: the veils as short flashes, should the steady ones flicker in game
local MAX_SIRENS = 8         -- the frame's sirens at once
local OVERPRESSURE = 3       -- BottleSlot_C State: 3 overpressure, 4 explodes

local M = { id = "gas", switch = "event_gas",
            KEYS = { "event_gas_notice", "event_gas_cloud", "event_gas_damage", "event_gas_real" },
            min_present = 1, not_last = 60 }

M.TEXT = {
    START  = { "FUITE DE GAZ : %s", "sector", c = "warn" },
    NOTICE = { "EXPLOSION DANS %s S", "num", c = "warn" },
    WAKE   = { "LA SIRÈNE TE RÉVEILLE", c = "warn" },
    COUNT  = { "EXPLOSION : %s", "num", c = "bad", n = true },
    BOOM   = { "EXPLOSION !", c = "bad", n = true },
    CLOUD  = { "%s IRRESPIRABLE", "sector", c = "warn" },
    GASSED = { "GAZ : TU T'ÉPUISES", c = "bad" },
    CLEAR  = { "%s RESPIRABLE", "sector", c = "good" },
    -- stopped before the explosion (switched off, TEST): nobody waits for a blast that never comes
    FIXED  = { "FUITE DE GAZ COLMATÉE", c = "good" },
    NOPE   = { "TEST : AUCUN SECTEUR OCCUPÉ", c = "warn" },
}
M.LINES = {
    NOTICE = { "Fuite de gaz (%s) : quittez les abords de la fuite, explosion dans {t}", "sector_low" },
    CLOUD  = { "Gaz (%s) : à moins de %s m de la fuite, on s'épuise - air pur dans {t}", "sector_low", "num" },
}
-- The dead have the usual "Mort de X" line and the fate "meurt (fuite de gaz)" (the cause the
-- blast writes): only the players hurt who live on get a line of their own.
M.RECAP = {
    ev_gas      = { "Évènement : fuite de gaz, %s", "sector_low" },
    ev_gas_hurt = { "Gaz : %s blessé par l'explosion", "name" },
}
M.SOUNDS = { "ev_gas_hiss", "ev_gas_cough" }

-- "Net Damage Effect" is the player's own machine telling the host (a server call) that a blow
-- took some of its life (Mec 0x394d5; only when it lives on). The blast is worked out on each
-- machine (its line of sight, its life): this is the only way the host learns whom it hurt.
M.hooks = {
    { path = G.PATH_MEC .. ":Net Damage Effect", fn = function(ctx, hc)
        local r = ctx.run
        if not (r.hurt_until and ctx.now() <= r.hurt_until) then return end
        local P = ctx.by_key(U.key(hc:get()))
        if not (P and r.in_range[P.key]) then return end
        -- a blow from another player meanwhile (lpr_server.lua notes it) is not the blast's
        local hit = P.last_hit
        if hit and hit.at >= r.boomed_at - 0.5 then return end
        r.hurt[P.key] = ctx.idx(P)
    end },
}

local function present_list(ctx)
    return ctx.living(function(P) return ctx.present(P) end)
end

-- The sectors the leak may be in: one where a player present stands, with a spawn point for the
-- leak, and not one where a gas bottle is in overpressure (never two explosions in a row).
local function sectors(ctx)
    local hot = {}
    for _, b in ipairs(W.all_of("BottleSlot_C")) do
        if (U.get(b, "State", 0) or 0) >= OVERPRESSURE then
            local s = W.sector_at(G.location(b))
            if s then hot[s] = true end
        end
    end
    local seen, out = {}, {}
    for _, P in ipairs(present_list(ctx)) do
        local s = W.sector_at(ctx.where(P))
        if s and not seen[s] and not hot[s] and #W.spawn_spots(s) > 0 then
            seen[s] = true
            out[#out + 1] = s
        end
    end
    return out
end

-- The leak: the sector's spawn point nearest the players who stand in it (on the floor and clear,
-- unlike the alarm box on its wall: a wall would stop the blast's line of sight).
local function leak_point(ctx, s)
    local x, y, z, n = 0, 0, 0, 0
    for _, P in ipairs(present_list(ctx)) do
        local p = ctx.where(P)
        if p and W.sector_at(p) == s then x, y, z, n = x + p.X, y + p.Y, z + p.Z, n + 1 end
    end
    local mid = (n > 0) and { X = x / n, Y = y / n, Z = z / n } or W.sector_center(s)
    local best, bd = nil, nil
    for _, e in ipairs(W.spawn_spots(s)) do
        local d = mid and U.dist(e.at, mid) or 0
        if not bd or d < bd then best, bd = e, d end
    end
    if not best then return nil end
    return { X = best.at.X, Y = best.at.Y, Z = best.at.Z + LEAK_Z }
end

-- A player's veil, sent only when it changes (each call is a message to that machine).
local function veil(ctx, P, color)
    local v = ctx.run.veiled
    local cur = v[P.key]
    if (cur and cur.color) == color then return end
    if color then
        v[P.key] = { P = P, color = color }
        ctx.tint(P, color, { pulse = VEIL_PULSE })
    else
        v[P.key] = nil
        if ctx.valid(P) then ctx.tint(P, nil) end
    end
end

local function cough_off(ctx, key)
    local r = ctx.run
    local slot = r.cough[key]
    if slot then
        r.cough[key] = nil
        ctx.sound_off(slot)
    end
end

-- The siren wakes a dreaming Rêveur whose body is in reach (at the start, and during the notice
-- for one who falls asleep there). Only a dreaming player: ctx.wake would also bring a hidden
-- Clandestin out, which the gas must never do.
local function wake_sleepers(ctx)
    local r = ctx.run
    for _, P in ipairs(ctx.living(function(Q) return Q.dreaming ~= nil and not Q.hiding end)) do
        local p = ctx.where(P)
        if p and U.dist(p, r.at) <= r.wake_range then
            ctx.wake(P, "gas")
            ctx.say(P, "WAKE")
        end
    end
end

-- Every second of the notice: the light veil near the leak, the sleepers.
local function notice_tick(ctx)
    local r = ctx.run
    local seen = {}
    for _, P in ipairs(present_list(ctx)) do
        local p = ctx.where(P)
        if p and U.dist(p, r.at) <= REACH.near then
            seen[P.key] = true
            veil(ctx, P, VEIL_NEAR)
        end
    end
    for key, e in pairs(r.veiled) do
        if not seen[key] then veil(ctx, e.P, nil) end
    end
    wake_sleepers(ctx)
end

-- Every second of the cloud: whoever is present near the leak tires (the game's recovery held
-- meanwhile); on coming in, a thick veil, a cough the others hear around the player, and a word
-- for the player alone. Whoever leaves the cloud, dies, falls asleep, flies, hides or leaves the
-- game: veil and cough off.
local function cloud_tick(ctx, now)
    local r = ctx.run
    local seen = {}
    for _, P in ipairs(present_list(ctx)) do
        local p = ctx.where(P)
        if p and U.dist(p, r.at) <= REACH.cloud then
            seen[P.key] = true
            ctx.tire(P, PACE.tire, PACE.hold)
            local i = ctx.idx(P)
            if not r.cough[P.key] and i >= 0 then
                veil(ctx, P, VEIL_CLOUD)
                r.cough[P.key] = "c" .. i      -- the slot noted: the index is lost if the player leaves
                ctx.sound("c" .. i, "ev_gas_cough", P, { inner = 200, falloff = 1200, period = PACE.cough })
                if now >= (r.told[P.key] or 0) then
                    r.told[P.key] = now + PACE.told
                    ctx.say(P, "GASSED")
                end
            end
        end
    end
    for key, e in pairs(r.veiled) do
        if not seen[key] then
            veil(ctx, e.P, nil)
            cough_off(ctx, key)
        end
    end
end

-- One line of the summary per player the blast hurt who lives on (written once, 2 s after it).
local function report_hurt(ctx)
    local r = ctx.run
    if r.reported or not r.boomed_at then return end
    r.reported = true
    for key, i in pairs(r.hurt) do
        local P = ctx.by_key(key)
        if P and ctx.valid(P) and G.is_alive(P.mec) and i >= 0 then ctx.recap("ev_gas_hurt", i) end
    end
end

local function boom(ctx, now)
    local r = ctx.run
    r.phase, r.boomed_at = "after", now
    for i = 1, r.sirens do ctx.siren_off("a" .. i) end
    for _, e in pairs(r.veiled) do veil(ctx, e.P, nil) end
    ctx.notice(nil, "BOOM")
    local real = r.real
    if real then
        -- the game's own actor deals its damage to every character within 35 m: the living there
        -- get the cause first (no killer, "meurt (fuite de gaz)"); it makes its own effects
        r.in_range = {}
        for _, P in ipairs(ctx.living()) do
            local p = ctx.where(P)
            if p and U.dist(p, r.at) <= REACH.real then
                r.in_range[P.key] = true
                ctx.cause(P, "gas", 3)
            end
        end
        if not ctx.game_explosion(r.at, 0) then
            ctx.log("explosion du jeu impossible : explosion adoucie à la place")
            real = false
        end
    end
    if not real then
        r.in_range = {}
        local hit = ctx.blast(r.at, REACH.blast, C.get("event_gas_damage"), { lethal = true, fx = "gas", cause = "gas" })
        for _, P in ipairs(hit) do r.in_range[P.key] = true end
    end
    r.hurt_until = now + PACE.hurt
    local cloud = r.cloud
    ctx.at(2, function()
        report_hurt(ctx)
        if cloud <= 0 then ctx.finish("done") end
    end)
    if cloud <= 0 then
        ctx.line(nil, nil)                    -- no cloud: over 2 s after the blast, nothing said
        return
    end
    r.phase, r.end_at = "cloud", now + cloud
    ctx.say(nil, "CLOUD", r.s)
    ctx.line(nil, "CLOUD", cloud, r.s, REACH.cloud / 100)
end

-- The explosion must come before the end of the game (outside TEST); a sector must be fit for it.
function M.can_start(ctx, now, test)
    if not test and ctx.clock() < C.get("event_gas_notice") + 15 then return false end
    if #sectors(ctx) == 0 then return false, "NOPE" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    local list = sectors(ctx)
    if #list == 0 then return false end
    local s = list[math.random(#list)]
    local at = leak_point(ctx, s)
    if not at then return false end
    local notice, cloud = C.get("event_gas_notice"), C.get("event_gas_cloud")
    r.s, r.at, r.phase, r.cloud, r.boom_at = s, at, "notice", cloud, now + notice
    r.real = C.get("event_gas_real") == true
    r.wake_range = r.real and REACH.real or (REACH.blast + REACH.wake)
    r.veiled, r.cough, r.told, r.hurt, r.in_range, r.sirens = {}, {}, {}, {}, {}, 0
    -- the sector's boxes ring without a pause (sounded again every 5 s) until the explosion; a
    -- sector without a box has none (the hiss, the mark and the banners stay)
    for _, box in ipairs(W.alarms()) do
        if box.sector == s and r.sirens < MAX_SIRENS then
            r.sirens = r.sirens + 1
            ctx.siren("a" .. r.sirens, box, notice, 0, notice)
        end
    end
    ctx.sound("hiss", "ev_gas_hiss", at, { inner = 300, falloff = 1500, period = 4 })   -- the file lasts 4 s
    ctx.mark("e1", at, "green", false, "ball")
    ctx.light_at("leak", at, "green", 900, 6000)
    ctx.say(nil, "START", s)
    ctx.say(nil, "NOTICE", notice)
    ctx.line(nil, "NOTICE", notice, s)
    wake_sleepers(ctx)
    for n = 5, 1, -1 do
        ctx.at(notice - n, function() ctx.notice("living", "COUNT", n) end)
    end
    ctx.recap("ev_gas", s)
    ctx.log("fuite dans le secteur %d (%d, %d, %d)%s", s, U.round(at.X), U.round(at.Y), U.round(at.Z),
        r.real and ", vraie explosion" or "")
    return notice + cloud + 2
end

function M.tick(ctx, now)
    local r = ctx.run
    if r.phase == "notice" and now >= r.boom_at then return boom(ctx, now) end
    if r.phase == "cloud" and now >= r.end_at then
        r.phase = "over"
        ctx.say(nil, "CLEAR", r.s)
        return ctx.finish("done")
    end
    ctx.every(1, "air", function(_, t)
        if r.phase == "notice" then
            notice_tick(ctx)
        elseif r.phase == "cloud" then
            cloud_tick(ctx, t)
        end
    end)
end

-- A player dead meanwhile: veil and cough off at once (one raised is looked at again the next
-- second, like anybody).
function M.on_death(ctx, P)
    veil(ctx, P, nil)
    cough_off(ctx, P.key)
end

-- Stopped before its time (switched off, TEST, timeout): said, so that nobody waits for a blast or
-- holds their breath for nothing; at the end of the game nothing is said. The frame takes the
-- sirens (each box back as its real state wants), sounds, mark, light, veils and lines back.
function M.stop(ctx, reason)
    local r = ctx.run
    report_hurt(ctx)
    if reason == "end" or reason == "done" then return end
    if r.phase == "notice" then
        ctx.say(nil, "FIXED")
    elseif r.phase == "cloud" then
        ctx.say(nil, "CLEAR", r.s)
    end
end

-- Nothing of its own on the machines: the frame's messages (EVSIREN, EVSND, EVMARK, EVLIGHT,
-- EVBODY, EVFX, EVLINE) do it all.
M.client = {}

return M
