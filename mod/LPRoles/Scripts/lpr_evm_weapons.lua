-- LPRoles - random event CONTRÔLE DES ARMES (weapons): a notice, then the ship scans the hand and
-- the bag of every living player and tells who carries a weapon. By default nothing is taken:
-- the information is public, each does with it what it wants; an option takes the weapons found
-- away and puts them down far from their carrier.
--   - Host: the notice and its reminder (each carrier reads, for itself alone, what it carries:
--     a bag is easily forgotten), the scan (every alarm box's siren for a second, a scanner's
--     beep, a cyan flash), the reading (again a moment later for a player swapping hand and bag),
--     the result, the confiscations (put off until a sleeping, flying or hidden player is back,
--     with the state the carrier's own machine counts: locate).
--   - Every machine: the list written on the tablet, with the names that machine knows; with the
--     option on, its own hand and bag told to the host (M.client.real).
-- Only the living are scanned: weapons on the ground, in cases or machines, a C4 set, a grenade
-- thrown escape it. The scan reads the person, not the face: a disguised Métamorphe is named as
-- itself (the real index), a clue on purpose. Weapons: knife, guns, C4, detonator, grenade, and
-- the scalpel (it strikes as the knife does): W.weapon_code.
local C = require("lpr_config")
local G = require("lpr_game")
local N = require("lpr_net")
local U = require("lpr_util")
local S = require("lpr_strings")
local W = require("lpr_ev_world")

local M = { id = "weapons", switch = "event_weapons", KEYS = { "event_weapons_notice", "event_weapons_seize" },
            min_living = 3, not_last = 60, once = true }

-- Banners queue 2.6 s each: the result names three carriers at most (each banner says it all by
-- itself), more are counted and listed on the tablets. The countdown and the scan are notices.
M.TEXT = {
    START  = { "CONTRÔLE DES ARMES", c = "warn" },
    NOTICE = { "DANS %s S : MAIN ET SAC", "num", c = "warn" },
    SOON   = { "CONTRÔLE DANS %s S", "num", c = "warn", n = true },
    YOU    = { "TU PORTES : %s", "weapon", c = "info" },
    SCAN   = { "SCAN DU VAISSEAU", c = "warn", n = true },
    COUNT  = { "PORTEURS D'ARMES : %s", "num", c = "warn", n = true },
    ONE    = { "%s PORTE : %s", "name", "weapon", c = "warn" },
    TWO    = { "%s PORTE : %s + %s", "name", "weapon", "weapon", c = "warn" },
    MANY   = { "%s PORTEURS : VOIR TABLETTE", "num", c = "warn" },
    NONE   = { "AUCUNE ARME DÉTECTÉE", c = "good" },
    SEIZED = { "ARMES CONFISQUÉES", c = "warn" },
    TAKEN1 = { "TON ARME EST CONFISQUÉE", c = "bad" },
    TAKEN2 = { "TES ARMES SONT CONFISQUÉES", c = "bad" },
}

-- WAIT is the host's line; the three others are written by each machine (M.client.list).
M.LINES = {
    WAIT   = { "Contrôle des armes dans {t} : main et sac de chaque vivant" },
    LIST   = { "Contrôle des armes : %s porteur(s) - {t}", "num" },
    LIST_0 = { "Contrôle des armes : aucune arme détectée - {t}" },
    MORE   = { "+ %s autres", "num" },
}

M.RECAP = {
    ev_weapons       = { "Évènement : contrôle des armes" },
    ev_weapons_found = { "Contrôle : %s portait : %s", "name", "weapon" },
    ev_weapons_taken = { "Contrôle : arme confisquée à %s (%s)", "name", "weapon" },
    ev_weapons_none  = { "Contrôle : aucune arme détectée" },
}

M.SOUNDS = { "ev_weapons_scan" }

local RESULT = 40            -- s: the list stays on the tablets, confiscations put off may still happen
local MAXB = 3               -- carriers named by banner
local SOON = 10              -- s: the reminder before the scan
-- A reading every PASS s, PASSES at most; the result PUBLISH_BY s after the scan whatever is
-- still unread.
local PASS, PASSES, PUBLISH_BY = 0.3, 4, 1.0
local SWITCHING = 3          -- readings put off for a player swapping hand and bag, then read as it is
local SEIZE_MIN = 2500       -- cm: a weapon taken away is put down at least this far from its carrier
-- Tries (one every 0.5 s) at a carrier whose hand and bag are being swapped before giving up. The
-- host's "Net Item Switching" may stay stuck: W.switching (which ctx.take asks too) no longer
-- counts it after a second, so a stuck flag costs a few tries, not the confiscation.
local SEIZE_TRIES = 6
-- With the option on, the carriers' machines are asked at the scan for their own hand and bag
-- (M.client.real, see locate). They answer through the game's interaction request, at the
-- indexes lpr_net keeps for the events (N.EV_REPLY, just above N.report's): REPLY + 16 x the
-- place (1 hand, 2 bag) + the weapon's code, then REPLY alone to end the answer. A confiscation
-- waits for it REPLY_WAIT s at most.
local REPLY, REPLY_WAIT = N.EV_REPLY, 2.0
local MAX_SIRENS = 8         -- the frame's sirens at once (EV.MAX)
local ROWS = 5               -- rows of the tablet under its band
local PLACES = { "hand", "bag" }

-- ---------------------------------------------------------------- host
-- Ten seconds before: everyone is told, and each carrier reads what it carries, for itself alone.
local function remind(ctx, r)
    r.soon_done = true
    ctx.notice(nil, "SOON", SOON)
    for _, P in ipairs(ctx.living()) do
        local h = ctx.held(P)
        for _, where in ipairs(PLACES) do
            local code = h[where] and W.weapon_code(h[where].data)
            if code and code > 0 then ctx.say(P, "YOU", code) end
        end
    end
end

-- The players scanned and not read yet (gone or dead since: not read at all).
local function unread(ctx, r)
    for _, P in ipairs(r.to_read) do
        if not r.read[P.key] and ctx.valid(P) and G.is_alive(P.mec) then return true end
    end
    return false
end

-- One reading of those still unread: hand and bag as the host holds them ("Net Hand ItemNew",
-- "Net Bag ItemNew": right for players without the mod too). A player swapping hand and bag
-- ("Net Item Switching") is read again on the next pass, a few times at most (the flag may stay
-- stuck), then as it is. The real index is noted now: a player who leaves stays in the list.
local function read_all(ctx, r)
    for _, P in ipairs(r.to_read) do
        if not r.read[P.key] and ctx.valid(P) and G.is_alive(P.mec)
                and (U.get(P.mec, "Net Item Switching", false) ~= true or r.passes >= SWITCHING) then
            r.read[P.key] = true
            local h = ctx.held(P)
            local items = {}
            for _, where in ipairs(PLACES) do
                local code = h[where] and W.weapon_code(h[where].data)
                if code and code > 0 then items[#items + 1] = { where = where, code = code } end
            end
            if #items > 0 then r.found[#r.found + 1] = { P = P, idx = ctx.idx(P), items = items } end
        end
    end
    r.passes = r.passes + 1
end

local function scan(ctx, r)
    r.scanned = true
    r.to_read = ctx.living()
    for i, a in ipairs(W.alarms()) do
        if i > MAX_SIRENS then break end
        ctx.siren("w" .. i, a, 1.0, 0, 1.0)         -- one second each, a slot per box
    end
    ctx.sound("w0", "ev_weapons_scan", nil, { mode = "flat" })
    for _, P in ipairs(r.to_read) do ctx.flash(P, "cyan") end
    ctx.notice(nil, "SCAN")
    if r.seize then
        -- who carries what is not known yet: every machine with the mod is asked (the others
        -- are not sent anything); a confiscation waits for its carrier's answer (seize)
        for _, P in ipairs(r.to_read) do
            if P.modded then r.asked[P.key] = true end
        end
        r.asked_at = ctx.now()
        ctx.to(r.to_read, "real")
    end
end

-- A weapon still where the scan saw it (or in the other place: hand and bag swapped since):
-- where it is now, and what is there, with its state as its carrier really has it (the "real
-- state"). The host's record ("Net Hand ItemNew", "Net Bag ItemNew") is the state the item had
-- when it was taken (Mec 0xb49d): a gun's shots lower only its carrier's own "Hand State"
-- (0x3329d), and a gun put in the bag takes the host's old record along (0xed15-0xed67). Put
-- down with that record, an emptied gun would come back loaded. So the record is corrected by
-- what the carrier's machine answered and by the shots heard since (M.hooks), looked for in the
-- place where the weapon is now, else in the other one (swapped since). A gun is never refilled
-- while it is carried: of these, the lowest is the nearest to the truth, and never more than the
-- record. Without the mod, the shots fired before the event are not known; another gun of the
-- same kind fired by the same player may give less, never more. Any other weapon (C4,
-- grenade...) takes its machine's answer as it is.
local function locate(ctx, r, P, it)
    local h, k = ctx.held(P), r.known[P.key] or {}
    for _, where in ipairs({ it.where, it.where == "hand" and "bag" or "hand" }) do
        local x = h[where]
        if x and W.weapon_code(x.data) == it.code then
            local got = k[where]
            if not (got and got.code == it.code) then got = k[where == "hand" and "bag" or "hand"] end
            if got and got.code == it.code then
                local gun = it.code >= 2 and it.code <= 7
                x.value = gun and math.min(x.value or 0, got.value) or got.value
                x.time = got.time or x.time
            end
            return where, x
        end
    end
    return nil
end

-- Confiscation of what one carrier was found with. A copy is put down first, far from the carrier
-- (its whole real state, locate: a gun's ammunition in Value, its flag in Time; kept in the game
-- after the event), then the original is taken away without dropping it; should that fail (hand
-- and bag being swapped), the copy goes and it is tried again. True when there is nothing more
-- to do; false: tried again later (a sleeping, flying or hidden player, or one just woken, is
-- left alone until back: taking an item from under the map is too risky; a carrier whose
-- machine has not answered yet is waited for a moment).
local function seize(ctx, r, f)
    local P = f.P
    if not (ctx.valid(P) and G.is_alive(P.mec)) then return true end   -- its things fell with it
    if not ctx.present(P) then return false end
    if r.asked[P.key] and not (r.known[P.key] or {}).answered and ctx.now() < r.asked_at + REPLY_WAIT then
        return false
    end
    -- hand and bag being swapped: no copy put down for nothing; given up after a few tries (the
    -- player keeps its weapons, but it has been named)
    local function busy()
        f.tries = (f.tries or 0) + 1
        if f.tries < SEIZE_TRIES then return false end
        ctx.log("armes du joueur %d laissées : main et sac toujours en cours d'échange", f.idx)
        return true
    end
    local stuck = W.switching(P.mec)
    if stuck and not busy() then return false end
    for _, it in ipairs(stuck and {} or f.items) do
        if not it.done then
            local where, x = locate(ctx, r, P, it)
            if not where then
                it.done = true                       -- put down or passed on since: it escapes
            else
                local copy = ctx.place(x.data, { value = x.value or 0, time = x.time or 0, keep = true,
                                                 far_from = { ctx.where(P) }, min_dist = SEIZE_MIN })
                if not copy then
                    it.done = true
                    ctx.log("arme du joueur %d laissée : aucun emplacement libre assez loin", f.idx)
                elseif not ctx.take(P, where) then
                    ctx.remove(copy)
                    if busy() then break end
                    return false
                else
                    it.done = true
                    f.taken = (f.taken or 0) + 1
                    ctx.recap("ev_weapons_taken", f.idx, it.code)
                    if not r.seized_said then
                        r.seized_said = true
                        ctx.say(nil, "SEIZED")
                    end
                end
            end
        end
    end
    if (f.taken or 0) > 0 then ctx.say(P, f.taken > 1 and "TAKEN2" or "TAKEN1") end
    return true
end

-- The result, to everyone, in the players' order; the whole list on every tablet for RESULT s
-- (sent as numbers: "idx.hand.bag;...", 0 for nothing; each machine writes the names it knows).
local function publish(ctx, r, now)
    r.published = true
    table.sort(r.found, function(a, b) return a.idx < b.idx end)
    ctx.line(nil, nil)
    if #r.found == 0 then
        ctx.say(nil, "NONE")
        ctx.recap("ev_weapons_none")
    else
        ctx.notice(nil, "COUNT", #r.found)
        if #r.found <= MAXB then
            for _, f in ipairs(r.found) do
                local a, b = f.items[1], f.items[2]
                if b then ctx.say(nil, "TWO", f.idx, a.code, b.code) else ctx.say(nil, "ONE", f.idx, a.code) end
            end
        else
            ctx.say(nil, "MANY", #r.found)
        end
    end
    local packed = {}
    for _, f in ipairs(r.found) do
        local hand, bag = 0, 0
        for _, it in ipairs(f.items) do
            ctx.recap("ev_weapons_found", f.idx, it.code)
            if it.where == "hand" then hand = it.code else bag = it.code end
        end
        packed[#packed + 1] = string.format("%d.%d.%d", U.round(f.idx), hand, bag)
    end
    ctx.all("list", #packed > 0 and table.concat(packed, ";") or "-", math.max(1, r.scan_at + RESULT - now))
    if r.seize then
        for _, f in ipairs(r.found) do
            if not seize(ctx, r, f) then r.pending[#r.pending + 1] = f end
        end
    end
end

-- What the host hears of the carriers' real hand and bag (locate), with the option on.
--   "Net Gun Fire": what is left in the gun, counted by the shooter's machine (Mec 0x3329d) and
--     sent with the shot (0x2115c), by every player, with the mod or not; the gun is the one in
--     the hand of the host's record.
--   "Request Net Interaction": the answer of a machine with the mod (M.client.real), one call per
--     place holding an item, then the end; reliable calls of one machine arrive in order, so a
--     shot fired after the answer is heard after it. The answer replaces whatever was known.
M.hooks = {
    { path = G.PATH_MEC .. ":Net Gun Fire", fn = function(ctx, hc, _, ammo)
        local r = ctx.run
        local P = r.seize and ctx.by_key(U.key(hc:get()))
        local hand = P and ctx.held(P).hand
        local ok, n = pcall(function() return ammo:get() end)
        if not (hand and ok and type(n) == "number") then return end
        local k = r.known[P.key] or {}
        r.known[P.key] = k
        local code, was = W.weapon_code(hand.data) or 0, k.hand
        k.hand = { code = code, value = n, time = was and was.code == code and was.time or nil }
    end },
    { path = G.PATH_MEC .. ":Request Net Interaction", fn = function(ctx, hc, _, index, state)
        local r = ctx.run
        local ok, v = pcall(function() return index:get() end)
        if not (r.asked and ok and type(v) == "number" and v >= REPLY and v < REPLY + 48) then return end
        local P = ctx.by_key(U.key(hc:get()))
        if not (P and r.asked[P.key]) then return end
        v = v - REPLY
        local wip = r.wip[P.key] or {}
        local place = PLACES[v // 16]
        if not place then                            -- REPLY alone: the end of the answer
            r.known[P.key] = { answered = true, hand = wip.hand, bag = wip.bag }
            r.wip[P.key] = nil
            return
        end
        local ok2, value, time = pcall(function()
            local st = state:get()
            return st[G.F_STATE_VALUE], st[G.F_STATE_TIME]
        end)
        if ok2 and type(value) == "number" then
            wip[place] = { code = v % 16, value = value, time = time or 0 }
            r.wip[P.key] = wip
        end
    end },
}

function M.can_start(ctx, now, test)
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    r.notice = C.get("event_weapons_notice")
    r.seize = C.get("event_weapons_seize") == true
    r.scan_at = now + r.notice
    r.soon_done = r.notice <= SOON + 2               -- the notice itself is the reminder
    r.read, r.found, r.pending, r.passes = {}, {}, {}, 0
    -- the carriers' real hand and bag (locate): asked, answers being received, known
    r.asked, r.wip, r.known = {}, {}, {}
    ctx.say(nil, "START")
    ctx.say(nil, "NOTICE", r.notice)
    ctx.line(nil, "WAIT", r.notice)
    ctx.recap("ev_weapons")
    return r.notice + RESULT
end

function M.tick(ctx, now)
    local r = ctx.run
    if not r.soon_done and now >= r.scan_at - SOON then remind(ctx, r) end
    if not r.scanned then
        if now < r.scan_at then return end
        scan(ctx, r)
    end
    if not r.published then
        if r.passes < PASSES and unread(ctx, r) then
            ctx.every(PASS, "pass", function() read_all(ctx, r) end)
        end
        if not unread(ctx, r) or r.passes >= PASSES or now >= r.scan_at + PUBLISH_BY then
            publish(ctx, r, now)
        end
    elseif #r.pending > 0 then
        ctx.every(0.5, "seize", function()
            local still = {}
            for _, f in ipairs(r.pending) do
                if not seize(ctx, r, f) then still[#still + 1] = f end
            end
            r.pending = still
        end)
    end
    if now >= r.scan_at + RESULT then ctx.finish("done") end
end

-- Nothing of its own to undo: the sirens, the line and the list are taken back by the frame on
-- every machine; the weapons already put down stay in the game (the game's Game Clear empties the
-- world at the end); confiscations still put off are given up.
function M.stop(ctx, reason) end

-- ---------------------------------------------------------------- every machine
M.client = {
    -- packed: "idx.hand.bag;..." (weapon codes, 0 for nothing) or "-"; secs: how long it stays.
    -- The first row goes in the tablet's band, the next ones (ROWS at most) under it.
    list = function(cx, packed, secs)
        local rows, n = {}, 0
        for rec in tostring(packed or ""):gmatch("[^;]+") do
            local f = {}
            for v in rec:gmatch("[^.]+") do f[#f + 1] = tonumber(v) end
            if f[1] then
                n = n + 1
                local names = {}
                for i = 2, 3 do
                    if (f[i] or 0) > 0 then names[#names + 1] = S.WEAPON_LOW[f[i]] or "?" end
                end
                if #rows < ROWS then rows[#rows + 1] = cx.name(f[1]) .. " : " .. table.concat(names, ", ") end
            end
        end
        if n > ROWS then rows[ROWS] = string.format(M.LINES.MORE[1], n - ROWS + 1) end
        table.insert(rows, 1, n == 0 and M.LINES.LIST_0[1] or string.format(M.LINES.LIST[1], n))
        cx.set_line(table.concat(rows, "\n"), tonumber(secs) or 0)
    end,
    -- The host asks for this machine's own hand and bag (locate): each place holding an item
    -- is told with its state as this machine counts it, then the end. Item and state are read in
    -- pairs from this machine's own variables ("Hand Item" and "Hand State", "Bag Item" and "Bag
    -- State", set together by the game's Set Hand Item / Set Bag Item): right even while hand and
    -- bag are being swapped, when the host's record still shows them the other way round (the
    -- host then finds each weapon in the other place). Sent through the game's interaction
    -- request aimed at this player's own PlayerState, which the game leaves alone (not an
    -- interactive actor, Mec 0x3e521), as lpr_net's N.report does.
    real = function(cx)
        local me = cx.me()
        local ps = U.get(me, "PlayerState", nil)
        if not U.valid(ps) then return end
        local places = { { U.get(me, "Hand Item", nil), U.get(me, "Hand State", nil) },
                         { U.get(me, "Bag Item", nil), U.get(me, "Bag State", nil) } }
        for i, p in ipairs(places) do
            local data, st = p[1], p[2]
            local ok, v, t = pcall(function() return st[G.F_STATE_VALUE], st[G.F_STATE_TIME] end)
            if U.valid(data) and ok and type(v) == "number" then
                U.tcall(me, "Request Net Interaction", ps, REPLY + 16 * i + (W.weapon_code(data) or 0),
                    W.item_state(v, t))
            end
        end
        U.tcall(me, "Request Net Interaction", ps, REPLY, W.item_state(0, 0))
    end,
}

return M
