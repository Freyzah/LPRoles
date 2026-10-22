-- LPRoles - random event AIMANTÉS (magnets): for a while, the players present push each other away
-- like magnets of the same pole.
--   - Two of them close to each other (across and in height), in sight, for a moment: each gets a
--     discharge (a weak push away from the other - from all the others when several -, a blue
--     flash, "DÉCHARGE !", a crack around them, a little tiredness), then nothing more for that
--     pair for a moment. Three discharges within ten seconds exhaust the player.
--   - Not through a wall, and never for a pair where one is off the ground: nobody is pushed over
--     a void.
--   - Only the players present are magnets: not the dead, a dreaming Rêveur's body, a Rêveur
--     getting back into its body, a flying Fée, a hidden Clandestin. Bodies are not magnets either.
--   - The push is the game's own client call ("Hit Health" with no damage): players without the mod
--     are pushed too. The rest (flash, tiredness, notices, the warning of each machine) needs it.
-- Each machine warns its own player (a light blue veil and a crackle) while another magnet is near.
local C = require("lpr_config")
local G = require("lpr_game")
local U = require("lpr_util")

local CONTACT, PAIR_CD, DZ = 0.3, 1.5, 200   -- close this long (s) for a discharge; then a rest for that pair (s); height (cm)
local OVERLOAD, OVER_WINDOW = 3, 10          -- this many discharges within this many seconds exhaust the player
local TIRE, FLASH = 15, 4                    -- tiredness of a discharge; a light flash (one may come every 1.5 s)
local ZAP_SLOTS = 4                          -- crack sounds taken in turn: two discharges close in time are both heard
local RESEND = 5                             -- the list of the magnets sent again now and then (a machine that joined late)
local WARN, CRACKLE = 400, 1.2               -- on each machine: another magnet within WARN cm; a crackle every CRACKLE s
local VEIL = { 0.6, 0.8, 1.0 }               -- the warning veil, a light blue
local VEIL_PULSE = false                     -- true: the veil as short flashes, should the steady one flicker in game

local M = { id = "magnets", switch = "event_magnets",
            KEYS = { "event_magnets_seconds", "event_magnets_range", "event_magnets_push" },
            min_present = 3, not_last = 60 }

M.TEXT = {
    START = { "AIMANTÉS : %s S", "num" },
    RULE  = { "GARDEZ VOS DISTANCES !" },
    ZAP   = { "DÉCHARGE !", c = "info", n = true },
    OVER  = { "SURCHARGE : ÉPUISÉ", c = "bad", n = true },
    END   = { "VOUS POUVEZ VOUS RAPPROCHER", c = "good" },
    NOPE  = { "TEST : PERSONNE À AIMANTER", c = "warn" },
}
M.LINES = {
    MAG = { "Aimantés : à moins de %s cm d'un autre joueur, décharge et recul - {t}", "num" },
}
M.RECAP = {
    ev_magnets      = { "Évènement : aimantés pendant %s s", "num" },
    ev_magnets_most = { "Aimantés : %s repoussé %s fois", "name", "num" },
    ev_magnets_pair = { "Aimantés : %s et %s se sont le plus repoussés", "name", "name" },
    ev_magnets_none = { "Aimantés : aucune décharge" },
}
M.SOUNDS = { "ev_magnets_zap", "ev_magnets_static" }

-- The magnets of the moment: the players present (ctx.present leaves out the dead, the dreaming,
-- the flying, the hidden and a Rêveur getting back into its body).
local function magnetized(ctx)
    return ctx.living(function(P) return ctx.present(P) end)
end

-- Off the ground (jumping or falling): the game's own stance, sent by the player's machine.
local function in_air(P)
    return U.get(P.mec, "Net Stance", G.STANCE_STAND) == G.STANCE_AIR
end

-- Every machine is told who the magnets are ("3-7-9"), for its own warning: when it changes (a
-- death, a raise, a dream, a flight, a hiding), and now and then for a machine that joined late.
local function send_set(ctx, list, now)
    local r = ctx.run
    local ids = {}
    for _, P in ipairs(list) do
        local i = ctx.idx(P)
        if i >= 0 then ids[#ids + 1] = i end
    end
    table.sort(ids)
    local s = #ids > 0 and table.concat(ids, "-") or "-"
    if s ~= r.sent or now >= (r.sent_at or 0) + RESEND then
        r.sent, r.sent_at = s, now
        ctx.all("set", s)
    end
end

local function pair_key(P, Q)
    local a, b = tostring(P.key), tostring(Q.key)
    if a < b then return a .. "|" .. b end
    return b .. "|" .. a
end

-- The crack of a discharge, heard around the middle of the pair.
local function crack(ctx, a, b)
    local r = ctx.run
    r.zap = r.zap % ZAP_SLOTS + 1
    ctx.sound("zap" .. r.zap, "ev_magnets_zap", { X = (a.X + b.X) / 2, Y = (a.Y + b.Y) / 2, Z = (a.Z + b.Z) / 2 + 100 },
              { inner = 200, falloff = 1300 })
end

-- What a discharge does to P besides the push; three within OVER_WINDOW: overload, exhausted (the
-- item drops, the player staggers and cannot act for a moment; without the mod, the frame drops
-- the item and stops the player).
local function discharge(ctx, P, now)
    local r = ctx.run
    ctx.flash(P, "blue", FLASH)
    ctx.tire(P, TIRE)
    ctx.notice(P, "ZAP")
    r.hits[P.key], r.idx[P.key] = (r.hits[P.key] or 0) + 1, ctx.idx(P)
    local kept = {}
    for _, t in ipairs(r.recent[P.key] or {}) do
        if now - t < OVER_WINDOW then kept[#kept + 1] = t end
    end
    kept[#kept + 1] = now
    if #kept >= OVERLOAD then
        kept = {}
        ctx.exhaust(P)
        ctx.notice(P, "OVER")
    end
    r.recent[P.key] = kept
end

-- Two magnets at least (one in TEST: accepted, but nothing happens without a second player).
function M.can_start(ctx, now, test)
    if #magnetized(ctx) < (test and 1 or 2) then return false, "NOPE" end
    return true
end

function M.start(ctx, now, test)
    local r, secs = ctx.run, C.get("event_magnets_seconds")
    r.close, r.cd, r.hits, r.idx, r.recent, r.pairs, r.pair_idx, r.zap = {}, {}, {}, {}, {}, {}, {}, 0
    ctx.say(nil, "START", secs)
    ctx.say(nil, "RULE")
    ctx.line(nil, "MAG", secs, C.get("event_magnets_range"))
    ctx.recap("ev_magnets", secs)
    send_set(ctx, magnetized(ctx), now)
    return secs
end

function M.tick(ctx, now)
    local r = ctx.run
    if now >= ctx.ends then return ctx.finish("done") end
    local list = magnetized(ctx)
    send_set(ctx, list, now)
    local range, strength = C.get("event_magnets_range"), C.get("event_magnets_push")
    local pos, push, close = {}, {}, {}
    for _, P in ipairs(list) do
        local p = ctx.where(P)
        if p and not in_air(P) then pos[P] = p end
    end
    -- every pair: only distances (66 pairs for 12 players); the line of sight is traced only for
    -- a pair close for CONTACT and out of its rest
    for i = 1, #list do
        local P = list[i]
        for j = i + 1, #list do
            local Q = list[j]
            local a, b = pos[P], pos[Q]
            if a and b and math.abs(a.Z - b.Z) <= DZ then
                local dx, dy = a.X - b.X, a.Y - b.Y
                local dh = math.sqrt(dx * dx + dy * dy)
                if dh <= range then
                    local key = pair_key(P, Q)
                    -- (a pair no longer close, or one of them gone, starts again from nothing)
                    close[key] = r.close[key] or now
                    if now - close[key] >= CONTACT and now >= (r.cd[key] or 0) and ctx.sees(P, Q) then
                        r.cd[key], close[key] = now + PAIR_CD, nil
                        local ux, uy
                        if dh < 1 then
                            local t = math.random() * 2 * math.pi
                            ux, uy = math.cos(t), math.sin(t)
                        else
                            ux, uy = dx / dh, dy / dh
                        end
                        for _, e in ipairs({ { P, ux, uy }, { Q, -ux, -uy } }) do
                            local v = push[e[1]] or { x = 0, y = 0 }
                            push[e[1]] = v
                            v.x, v.y = v.x + e[2], v.y + e[3]
                        end
                        r.pairs[key] = (r.pairs[key] or 0) + 1
                        r.pair_idx[key] = { ctx.idx(P), ctx.idx(Q) }
                        crack(ctx, a, b)
                    end
                end
            end
        end
    end
    r.close = close
    -- one push per player and per tick, away from all the others that discharged it at once
    for P, v in pairs(push) do
        local yaw = (v.x * v.x + v.y * v.y > 1e-4) and math.deg(math.atan(v.y, v.x)) or (math.random() * 360 - 180)
        ctx.push(P, yaw, strength)
        discharge(ctx, P, now)
    end
end

-- Before its time (switched off, TEST, timeout): said. At the end of the game: nothing said, the
-- summary still written. The pushes, the tiredness and the dropped items stay: the game's own.
function M.stop(ctx, reason)
    local r = ctx.run
    if reason ~= "end" then ctx.say(nil, "END") end
    local best, bn = nil, 0
    for key, n in pairs(r.hits or {}) do
        if n > bn then best, bn = key, n end
    end
    if best then ctx.recap("ev_magnets_most", r.idx[best], bn) else ctx.recap("ev_magnets_none") end
    local pk, pn = nil, 0
    for key, n in pairs(r.pairs or {}) do
        if n > pn then pk, pn = key, n end
    end
    if pk and pn >= 2 then ctx.recap("ev_magnets_pair", r.pair_idx[pk][1], r.pair_idx[pk][2]) end
end

-- Each machine: while its own player is a magnet and another magnet stands within WARN (the
-- characters as this machine sees them), a light blue veil and a crackle. Never for a player who is
-- not a magnet (dead, a ghost of its own for a while: a dreaming Rêveur, a flying Fée).
M.client = {
    set = function(cx, list)
        local s = {}
        for i in tostring(list or ""):gmatch("%d+") do s[tonumber(i)] = true end
        cx.run.set = s
    end,
    tick = function(cx, now)
        local run = cx.run
        if now < (run.check_at or 0) then return end
        run.check_at = now + 0.25
        local me, near = cx.me(), false
        local here = me and run.set and run.set[cx.my_idx()] and not cx.ghost() and G.is_alive(me) and G.location(me)
        if here then
            for i in pairs(run.set) do
                local m = (not cx.is_me(i)) and cx.mec(i) or nil
                local p = m and G.location(m)
                if p and (p.X - here.X) ^ 2 + (p.Y - here.Y) ^ 2 <= WARN * WARN and math.abs(p.Z - here.Z) <= DZ then
                    near = true
                    break
                end
            end
        end
        if near ~= (run.near == true) then
            run.near = near
            cx.tint(near and VEIL or nil, VEIL_PULSE)
            if not near then cx.sound_off("crk") end
        end
        -- its own slot: a sound of another event or a role's is never cut by it
        if near and now >= (run.crackle_at or 0) then
            run.crackle_at = now + CRACKLE
            cx.sound("crk", "ev_magnets_static", { mode = "flat" })
        end
    end,
    off = function(cx)
        cx.tint(nil)
        cx.sound_off("crk")
    end,
}

return M
