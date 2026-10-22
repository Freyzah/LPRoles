-- LPRoles - random event CONTRÔLE DES ARMES (weapons): a notice, then the ship scans the hand and
-- the bag of every living player and tells who carries a weapon. By default nothing is taken:
-- the information is public, each does with it what it wants; an option takes the weapons found
-- away and puts them down far from their carrier.
--   - Host: the notice and its reminder (each carrier reads, for itself alone, what it carries:
--     a bag is easily forgotten), the scan (every alarm box's siren for a second, a scanner's
--     beep, a cyan flash), the reading (again a moment later for a player swapping hand and bag),
--     the result, the confiscations (put off until a sleeping, flying or hidden player is back).
--   - Every machine: the list written on the tablet, with the names that machine knows.
-- Only the living are scanned: weapons on the ground, in cases or machines, a C4 set, a grenade
-- thrown escape it. The scan reads the person, not the face: a disguised Métamorphe is named as
-- itself (the real index), a clue on purpose. Weapons: knife, guns, C4, detonator, grenade, and
-- the scalpel (it strikes as the knife does): W.weapon_code.
local C = require("lpr_config")
local G = require("lpr_game")
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
local PASS, PASSES = 0.3, 4  -- a reading every PASS s, PASSES at most
local SWITCHING = 3          -- readings put off for a player swapping hand and bag, then read as it is
local PUBLISH_BY = 1.0       -- s after the scan: the result whatever is still unread
local SEIZE_MIN = 2500       -- cm: a weapon taken away is put down at least this far from its carrier
-- Tries (one every 0.5 s) at a carrier whose hand and bag are being swapped before giving up. The
-- host's "Net Item Switching" may stay stuck: W.switching (which ctx.take asks too) no longer
-- counts it after a second, so a stuck flag costs a few tries, not the confiscation.
local SEIZE_TRIES = 6
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
end

-- A weapon still where the scan saw it (or in the other place: hand and bag swapped since):
-- where it is now, and what is there.
local function locate(ctx, P, it)
    local h = ctx.held(P)
    for _, where in ipairs({ it.where, it.where == "hand" and "bag" or "hand" }) do
        local x = h[where]
        if x and W.weapon_code(x.data) == it.code then return where, x end
    end
    return nil
end

-- Confiscation of what one carrier was found with. A copy is put down first, far from the carrier
-- (its whole state: a gun's ammunition in Value, its flag in Time; kept in the game after the
-- event), then the original is taken away without dropping it; should that fail (hand and bag
-- being swapped), the copy goes and it is tried again. True when there is nothing more to do;
-- false: tried again later (a sleeping, flying or hidden player, or one just woken, is left
-- alone until back: taking an item from under the map is too risky).
local function seize(ctx, r, f)
    local P = f.P
    if not (ctx.valid(P) and G.is_alive(P.mec)) then return true end   -- its things fell with it
    if not ctx.present(P) then return false end
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
            local where, x = locate(ctx, P, it)
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
}

return M
