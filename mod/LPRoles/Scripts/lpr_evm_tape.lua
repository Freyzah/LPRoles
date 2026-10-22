-- LPRoles - évènement « LA CASSETTE DU CORBEAU » : an anonymous cassette appears somewhere in the
-- ship. It holds the clock time it was recorded at and two names of living players (three from six
-- living), at least one of them a dissident. Whoever picks it up first hears it alone; slipped into
-- a radio's reader, or played with the "consume" key next to a radio, it speaks to everyone; left
-- alone it erases itself.
--   Host: the content (drawn and frozen when the cassette is put down), the cassette followed
--   wherever it goes (ground, hands, bags, a radio's reader), each new holder reading it, the
--   airing, the end.
--   Every machine: nothing of its own; the frame's messages show it all (banners, notices, the
--   tablet's line, the cassette's column, the hiss).
-- Once per game, at least 3 living players of whom one dissident (user's decision): two cassettes
-- crossed would often give a certainty, and with two living players both would be named.
local C = require("lpr_config")
local G = require("lpr_game")
local U = require("lpr_util")
local W = require("lpr_ev_world")

local M = { id = "tape", switch = "event_tape", KEYS = { "event_tape_seconds" },
            min_living = 3, needs_dissident = true, not_last = 90, once = true }

-- Three names from this many living players, two below: with few players a third name would leave
-- hardly anyone out (a constant, not a setting: user's decision).
local THREE = 6
local REACH = 250          -- cm: the "consume" key airs the cassette this close to a radio
local GRACE = 2            -- s: an item moves in one go on the host; this is a margin before "gone"
local AIR_SHOW = 30        -- s: the content stays on every tablet once aired
local FAR = 1200           -- cm: put down this far from every living player when it can be
local NAMES = { "NAMES1", "NAMES2", "NAMES3" }

-- The banners carry no holder's name: the cassette is anonymous, and so is whoever has it. Notices
-- (n = true) for what must show at once: the hint to its reader, the airing, a radio too far.
M.TEXT = {
    START     = { "CASSETTE ANONYME" },
    WHERE     = { "SECTEUR %s", "sector" },
    FAKE      = { "TEST : CONTENU FICTIF", c = "warn" },
    TAKEN     = { "LA CASSETTE A ÉTÉ RAMASSÉE" },
    GROUND_AT = { "CASSETTE AU SOL : %s", "sector" },
    TIME      = { "ENREGISTRÉE À %s AU CHRONO", "clock" },
    NAMES1    = { "%s EST DISSIDENT", "name" },
    NAMES2    = { "%s OU %s", "name", "name" },
    NAMES3    = { "%s, %s OU %s", "name", "name", "name" },
    CLAIM     = { "AU MOINS UN EST DISSIDENT" },
    HINT      = { "GLISSE-LA DANS UNE RADIO", c = "info", n = true },
    RADIO_FAR = { "APPROCHE-TOI D'UNE RADIO", c = "warn", n = true },
    AIRED     = { "LA CASSETTE PARLE", c = "warn", n = true },
    ERASED    = { "LA CASSETTE S'EST EFFACÉE" },
    LOST      = { "LA CASSETTE EST PERDUE" },
    BACK      = { "LA CASSETTE RÉAPPARAÎT" },
    NOPLACE   = { "TEST : AUCUNE PLACE LIBRE", c = "warn" },
}

-- The readers keep the content on their tablet until the end, with how to air it on a second row
-- (their own "consume" key); once aired, everyone has it for AIR_SHOW seconds.
M.LINES = {
    GROUND = { "Cassette anonyme au sol, secteur %s : effacée dans {t}", "sector" },
    HELD   = { "Cassette anonyme ramassée : effacée dans {t}" },
    READ1  = { "Cassette écoutée (%s) : %s est dissident - {t}\nPour la diffuser : le lecteur d'une radio, ou %s juste à côté",
               "clock", "name", "key" },
    READ2  = { "Cassette écoutée (%s) : %s ou %s, au moins un dissident - {t}\nPour la diffuser : le lecteur d'une radio, ou %s juste à côté",
               "clock", "name", "name", "key" },
    READ3  = { "Cassette écoutée (%s) : %s, %s ou %s, au moins un dissident - {t}\nPour la diffuser : le lecteur d'une radio, ou %s juste à côté",
               "clock", "name", "name", "name", "key" },
    AIR1   = { "Cassette diffusée (%s) : %s est dissident", "clock", "name" },
    AIR2   = { "Cassette diffusée (%s) : %s ou %s, au moins un dissident", "clock", "name", "name" },
    AIR3   = { "Cassette diffusée (%s) : %s, %s ou %s, au moins un dissident", "clock", "name", "name", "name" },
}

-- Two values at most per summary line: three names take two lines.
M.RECAP = {
    ev_tape        = { "Évènement : cassette du corbeau, posée secteur %s, enregistrée à %s au chrono", "sector_low", "clock" },
    ev_tape_names  = { "Cassette : %s ou %s, au moins un dissident", "name", "name" },
    ev_tape_three  = { "Cassette : %s, %s ou le nom suivant, au moins un dissident", "name", "name" },
    ev_tape_name3  = { "Cassette, troisième nom : %s", "name" },
    ev_tape_name1  = { "Cassette : %s est dissident (essai à un seul vivant)", "name" },
    ev_tape_fake   = { "Cassette : contenu fictif (essai sans dissident)" },
    ev_tape_read   = { "Cassette écoutée par %s", "name" },
    ev_tape_aired  = { "Cassette diffusée par %s", "name" },
    ev_tape_back   = { "Cassette réapparue secteur %s, son porteur est parti", "sector_low" },
    ev_tape_erased = { "Cassette effacée sans avoir été diffusée" },
    ev_tape_lost   = { "Cassette perdue" },
}

M.SOUNDS = { "ev_tape_static" }

-- ---------------------------------------------------------------- host
-- A sector where the cassette can lie: one of its item places is free.
local function has_free(s)
    return #W.spawners(s, true) > 0
end

-- The cassette put down in sector s (any sector when nil): far from every living player when it
-- can be, nobody should find it at their feet. A hidden Clandestin gives no place (never its
-- real one) and is left out. Its song is 0, a valid index of the radios' list: a radio it is
-- slipped into shows a song, but plays nothing until somebody presses "play".
local function put_down(ctx, s)
    local far = {}
    for _, P in ipairs(ctx.living()) do
        local p = ctx.where(P)
        if p then far[#far + 1] = p end
    end
    return ctx.place(W.ASSET.MUSIC, { sector = s, value = 0, far_from = far, min_dist = FAR })
        or ctx.place(W.ASSET.MUSIC, { sector = s, value = 0 })
end

-- The content, frozen now: real indexes (the system speaks, a Métamorphe is named by its own
-- name), in a shuffled order, one dissident at least ("at least one" in the strict sense: they
-- may all be). Taupe and converted recruits count as dissidents; a Bouffon, an Amnésique with no
-- dissident role and a recruit not yet converted do not (ctx.camp). Without a living dissident
-- nothing is drawn, but for TEST: a made-up content, said so. Returns names, fake.
local function draw(ctx, test)
    local alive = ctx.living()
    local diss = {}
    for _, P in ipairs(alive) do
        if ctx.camp(P) == "dissident" then diss[#diss + 1] = P end
    end
    local fake = #diss == 0
    if (fake and not test) or #alive == 0 then return nil end
    local first = fake and alive[math.random(#alive)] or diss[math.random(#diss)]
    local rest = {}
    for _, P in ipairs(alive) do
        if P ~= first then rest[#rest + 1] = P end
    end
    U.shuffle(rest)
    local names = { ctx.idx(first) }
    for i = 1, math.min(((#alive >= THREE) and 3 or 2) - 1, #rest) do names[#names + 1] = ctx.idx(rest[i]) end
    return U.shuffle(names), fake
end

-- Every player of the game but H (the one who just picked the cassette up).
local function others(ctx, H)
    local out = {}
    ctx.each(function(P)
        if P ~= H then out[#out + 1] = P end
    end)
    return out
end

-- The values of a line about the content: the time, the names, then `extra` (the key of a
-- reader's second row).
local function values(r, extra)
    local v = { r.when }
    for _, i in ipairs(r.names) do v[#v + 1] = i end
    if extra then v[#v + 1] = extra end
    return table.unpack(v)
end

-- The content as banners: the time, the names, the claim (with one name, the name says it all).
local function tell_content(ctx, who)
    local r = ctx.run
    ctx.say(who, "TIME", r.when)
    ctx.say(who, NAMES[#r.names], table.unpack(r.names))
    if #r.names > 1 then ctx.say(who, "CLAIM") end
end

-- The tablet's lines: where the cassette is for everyone (lying in `sector`, or held), then the
-- content again for each reader still here. The line to everyone comes first: it replaces the
-- readers' own lines, sent again right after.
local function lines(ctx, now, sector)
    local r = ctx.run
    local left = math.max(1, ctx.ends - now)
    if sector then
        ctx.line(nil, "GROUND", left, sector)
    else
        ctx.line(nil, "HELD", left)
    end
    for _, R in pairs(r.readers) do
        if ctx.valid(R.P) then ctx.line(R.P, "READ" .. #r.names, left, values(r, "use")) end
    end
end

-- H has the cassette for the first time: H hears it alone (the hiss on H's machine only) and
-- keeps it on the tablet. A player without the mod reads nothing: the journal says so.
local function read(ctx, H)
    local r = ctx.run
    r.readers[H.key] = { P = H }
    ctx.notice(H, "HINT")
    tell_content(ctx, H)
    ctx.sound("t1", "ev_tape_static", nil, { who = H })
    ctx.recap("ev_tape_read", H)
    if not H.modded then ctx.log("%s a la cassette sans le mod : il n'en entend rien", G.player_name(H.mec)) end
end

-- The radio whose reader is `slot` (the item slot a cassette was slipped or thrown into).
local function radio_of(slot)
    if not U.valid(slot) then return nil end
    local a = slot:GetAddress()
    for _, rr in ipairs(W.radios()) do
        local m = rr.music
        if U.valid(m) and m:GetAddress() == a then return { actor = rr.actor } end
    end
    return nil
end

-- The radio nearest to `pos` and its distance. A map without radios: the alarm boxes' speakers
-- stand in for them.
local function nearest_radio(pos)
    local list = W.radios()
    if #list == 0 then list = W.alarms() end
    local best, best_d = nil, math.huge
    for _, e in ipairs(list) do
        local at = e.at or G.location(e.actor)
        local d = at and U.dist(at, pos) or math.huge
        if d < best_d then best, best_d = { actor = e.actor, at = at }, d end
    end
    return best, best_d
end

-- The cassette speaks: consumed (taken out of the reader, whose screen goes back to "no song", or
-- out of the hand), a hiss at the radio for everyone, the content to everyone and on every
-- tablet for a while. Ends AIR_SHOW s later, and always before the frame's own limit (planned
-- + 15 s).
local function air(ctx, rr, now)
    local r = ctx.run
    r.aired = true
    local at = rr.at or G.location(rr.actor)
    ctx.remove(r.rec)
    ctx.unmark("e1")
    if r.keyed then ctx.key(r.keyed, false, false) end
    r.keyed = nil
    if at then ctx.sound("t2", "ev_tape_static", at, { inner = 400, falloff = 3000 }) end
    ctx.notice(nil, "AIRED")
    tell_content(ctx, nil)
    local show = math.max(5, math.min(AIR_SHOW, ctx.ends + 12 - now))
    ctx.line(nil, "AIR" .. #r.names, show, values(r))
    r.finish_at = now + show
    -- the last holder aired it (by the key, or with the reader): its index noted when it took it
    if (r.last_idx or -1) >= 0 then ctx.recap("ev_tape_aired", r.last_idx) end
    ctx.log("cassette diffusée")
end

local function lose(ctx)
    ctx.run.closed = true
    ctx.say(nil, "LOST")
    ctx.recap("ev_tape_lost")
    ctx.finish("lost")
end

-- Its holder left the game with it: the cassette comes back in the sector the holder was last
-- seen in (anywhere if that sector has no free place), lying there, announced.
local function reappear(ctx, now)
    local r = ctx.run
    local rec = put_down(ctx, W.sector_at(r.last_at) or r.from) or put_down(ctx, nil)
    if not rec then return lose(ctx) end
    r.rec, r.holder, r.keyed = rec, nil, nil
    r.ground_since, r.ground_told = now, true
    local s = W.sector_at(rec.at) or r.from
    ctx.mark_item("e1", rec, "violet", true)
    ctx.say(nil, "BACK")
    ctx.say(nil, "WHERE", s)
    ctx.recap("ev_tape_back", s)
    lines(ctx, now, s)
end

-- Where the cassette is now, ten times a second (and at once after a pick-up).
local function update(ctx, now)
    local r = ctx.run
    if r.aired or r.closed then return end
    local t = ctx.track(r.rec)
    if t.where == "slot" then
        local rr = radio_of(t.actor)
        if rr then return air(ctx, rr, now) end
        return lose(ctx)                    -- only a radio's reader takes a cassette: not seen yet
    end
    if t.where == "gone" then
        r.gone_since = r.gone_since or now
        if now - r.gone_since < GRACE then return end
        r.gone_since = nil
        if r.holder and not ctx.valid(r.holder) then return reappear(ctx, now) end
        return lose(ctx)                    -- fallen out of the ship
    end
    r.gone_since = nil
    local H = (t.where == "hand" or t.where == "bag") and t.P or nil
    if H ~= r.holder then
        -- picked up from the ground: the others hear of it, without a name. Not when the one who
        -- just dropped it takes it back before the ground was told; not for a Voleur's theft
        -- (from hand to hand: nobody saw it)
        if H and not r.holder and (r.ground_told or H ~= r.last) then ctx.say(others(ctx, H), "TAKEN") end
        r.holder = H
        if H then
            -- the column goes out now, and stays out until the ground is told (below). Left with
            -- the frame, it would light again by itself as soon as the cassette touches the ground
            -- (its check, twice a second), through the walls: where an anonymous holder dropped it
            -- and picked it straight back up, or where a holder was just killed by whoever grabs
            -- it, all of which the GRACE keeps quiet. Nothing is sent when it is out already (a
            -- Voleur's theft, a quick pick-up again)
            ctx.unmark("e1")
            r.last, r.last_idx = H, ctx.idx(H)
            -- a new holder hears it once: two readers may confirm or contradict each other; a
            -- holder raised by the Ange gardien who takes it back does not hear it again
            if not r.readers[H.key] then read(ctx, H) end
        else
            r.ground_since, r.ground_told = now, false
        end
        lines(ctx, now)
    end
    if H then
        -- a hidden Clandestin has no place: the last one seen is kept (for a reappearance)
        local at = ctx.where(H)
        if at then r.last_at = at end
    end
    -- the "consume" key airs it, only while it is in the holder's hand (not in the bag)
    local want = (t.where == "hand") and H or nil
    if want ~= r.keyed then
        if r.keyed then ctx.key(r.keyed, false, false) end
        if want then ctx.key(want, false, true) end
        r.keyed = want
    end
    -- lying there for a moment (dropped, thrown, fallen from a dead holder): everyone is told where
    if not H and not r.ground_told and now - (r.ground_since or now) >= GRACE then
        r.ground_told = true
        -- the column comes back with the banner (the frame shows it at once: it lies on the
        -- ground). Outside any sector too: the banner needs a sector's name, the column does not
        ctx.mark_item("e1", r.rec, "violet", true)
        local s = t.at and W.sector_at(t.at)
        if s then
            ctx.say(nil, "GROUND_AT", s)
            lines(ctx, now, s)
        end
    end
end

-- A free item place somewhere (and somebody alive to be named: a TEST with every player dead
-- has none).
function M.can_start(ctx, now, test)
    if #ctx.living() == 0 then return false end
    if not W.random_sector(has_free) then return false, "NOPLACE" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    local secs = C.get("event_tape_seconds")
    r.names, r.fake = draw(ctx, test)
    if not r.names then return false end
    r.when = ctx.clock()
    r.from = W.random_sector(has_free)
    r.rec = r.from and put_down(ctx, r.from)
    if not r.rec then return false end
    r.readers, r.holder, r.last = {}, nil, nil
    r.ground_told = true                    -- the announcement says where: no "on the ground" banner
    ctx.mark_item("e1", r.rec, "violet", true)
    ctx.say(nil, "START")
    ctx.say(nil, "WHERE", r.from)
    if r.fake then ctx.say(nil, "FAKE") end
    ctx.line(nil, "GROUND", secs, r.from)
    ctx.recap("ev_tape", r.from, r.when)
    local n = r.names
    if r.fake then
        ctx.recap("ev_tape_fake")
    elseif #n == 1 then
        ctx.recap("ev_tape_name1", n[1])
    elseif #n == 2 then
        ctx.recap("ev_tape_names", n[1], n[2])
    else
        ctx.recap("ev_tape_three", n[1], n[2])
        ctx.recap("ev_tape_name3", n[3])
    end
    ctx.log("cassette posée secteur %d, %d nom(s)%s", r.from, #n, r.fake and " (contenu fictif)" or "")
    return secs
end

function M.tick(ctx, now)
    local r = ctx.run
    ctx.every(0.1, "track", update)
    if ctx.over or r.closed then return end
    if r.aired then
        if now >= r.finish_at then
            r.closed = true
            ctx.finish("aired")
        end
    elseif now >= ctx.ends then
        r.closed = true
        ctx.say(nil, "ERASED")
        ctx.recap("ev_tape_erased")
        ctx.finish("erased")                -- the undo takes it away, wherever it is
    end
end

-- The game's pick-up, or a Voleur's theft: read at once rather than at the next tick.
function M.on_pick(ctx, P)
    update(ctx, ctx.now())
end

-- The holder's "consume" key, cassette in hand: aired at a radio within reach, else told to come
-- closer. Taken in both cases: with the cassette in hand the role has nothing to consume.
function M.on_key(ctx, P, kind)
    local r = ctx.run
    if kind ~= "use" or r.aired or r.closed or P ~= r.holder then return false end
    local t = ctx.track(r.rec)
    if t.where ~= "hand" or t.P ~= P then return false end
    local at = ctx.where(P)                 -- a copy: the feet, raised to the hands (a radio stands on a table)
    local rr, d = nil, math.huge
    if at then
        at.Z = at.Z + 100
        rr, d = nearest_radio(at)
    end
    if rr and d <= REACH then
        air(ctx, rr, ctx.now())
    else
        ctx.notice(P, "RADIO_FAR")
        ctx.sfx(P, "fail")
    end
    return true
end

-- Everything else is the frame's undo: the cassette taken away wherever it is (ground, hand,
-- bag, a radio's reader), its column, the hiss, the lines and the key given back.
function M.stop(ctx, reason)
    local r = ctx.run
    if reason == "timeout" and not (r.aired or r.closed) then ctx.recap("ev_tape_erased") end
    if reason == "off" or reason == "test" then ctx.log("arrêtée (%s) : la cassette est retirée", reason) end
end

-- Nothing local: the frame's messages show everything (and take it back at the end).
M.client = {}

return M
