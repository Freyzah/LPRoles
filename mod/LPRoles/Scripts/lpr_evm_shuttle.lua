-- LPRoles - the random event « DERNIÈRE NAVETTE », kept for the last minutes of a game (its own
-- switch, off by default: it can decide the game). A shuttle waits at a dock of one sector, with
-- two seats marked by columns. A living player who stands on a free seat and presses the power key
-- boards (and can no more walk, but can look, talk, use its items and defend itself); pressed
-- again, up to 10 s before the departure, it gets off. At the departure the two passengers decide:
--   - two non-dissidents (a Bouffon or an Amnésique counts as one: nothing is revealed): the
--     employees win;
--   - one dissident and one non-dissident: the dissidents win;
--   - two dissidents: they leave the ship (they die, with no killer, no body, never raised) and
--     the game goes on under its own rules;
--   - nobody or a single passenger: the shuttle leaves empty.
-- A win goes through the game's real End Game (counted as a normal win in the statistics); each
-- player with the mod reads on the end screen whether its side won by the shuttle. Sides are
-- judged at the departure (a recruit converted meanwhile, the Taupe: dissidents) and the
-- announcements by sight name the face worn (a Métamorphe), the summary the real names.
-- Host only: the machines show what the frame sends (marks, banners, notices, lines, the freeze of
-- the passengers, the dock's siren).
local C = require("lpr_config")
local G = require("lpr_game")
local U = require("lpr_util")
local W = require("lpr_ev_world")

local SEAT_RADIUS, SEAT_DZ = 130, 200   -- cm (on the floor, up or down) from a seat to board it
local OFF_SEAT = 250                    -- cm: a passenger carried further away (Échangeur, Écho, a blast) is off
local SEAT_MIN, SEAT_MAX = 150, 1200    -- cm between the two seats, both spawn points of the dock's sector
local SEAT_SIDE = 200                   -- cm: with one spawn point only, the second seat on its right
local CLOSE_BEFORE = 10                 -- s before the departure: doors closed, nobody boards or gets off
local KEY_GAP = 1                       -- s between two boardings or gettings off of one player
local MARGIN = 20                       -- s the clock must hold beyond the wait (the departure and its 3 s come first)

local M = { id = "shuttle", switch = "event_shuttle", KEYS = { "event_shuttle_seconds", "event_shuttle_window" },
            min_living = 2, min_employees = 2, only_last = "event_shuttle_window", once = true }

M.TEXT = {
    START    = { "DERNIÈRE NAVETTE : %s", "sector" },     -- the dock's sector
    RULE_EMP = { "2 EMPLOYÉS : ILS GAGNENT" },
    RULE_DIS = { "UN SEUL DISSIDENT : IL GAGNE" },
    HOW      = { "MONTER : TOUCHE %s", "key", n = true },
    BOARD    = { "À BORD : %s", "name" },                 -- the face worn: an announcement by sight
    LEAVE    = { "%s DESCEND", "name" },
    FREED    = { "PLACE LIBÉRÉE", c = "info" },
    TAKEN    = { "PLACE PRISE", c = "warn" },
    CLOSED   = { "PORTES FERMÉES", c = "warn" },
    COUNT    = { "NAVETTE : %s", "num", c = "warn", n = true },
    DEPART   = { "DÉPART : %s ET %s", "name", "name" },
    WIN_EMP  = { "LES EMPLOYÉS GAGNENT", c = "good" },
    WIN_DIS  = { "LES DISSIDENTS GAGNENT", c = "bad" },
    GONE     = { "DEUX DISSIDENTS S'EN VONT" },
    GOES_ON  = { "LA PARTIE CONTINUE", c = "info" },
    EMPTY    = { "LA NAVETTE PART À VIDE", c = "info" },
    SOLO     = { "TEST : UN SEUL PASSAGER", c = "warn" },
    NOPE     = { "TEST : PAS DE QUAI TROUVÉ", c = "warn" },
}

M.LINES = {
    DOCK   = { "Navette %s : 2 employés gagnent, 1 dissident gagne, 2 dissidents meurent - {t}", "sector_low" },
    ABOARD = { "À bord : touche de pouvoir pour descendre, portes fermées à 0:10 - départ {t}" },
    CLOSED = { "Portes fermées : plus personne ne monte ni ne descend - départ {t}" },
}

M.RECAP = {
    ev_shuttle       = { "Évènement : dernière navette, quai %s", "sector_low" },
    ev_shuttle_board = { "Navette : %s monte à bord", "name" },
    ev_shuttle_leave = { "Navette : %s descend", "name" },
    ev_shuttle_emp   = { "Navette : %s et %s partent, victoire des employés", "name", "name" },
    ev_shuttle_dis   = { "Navette : %s et %s partent, victoire des dissidents", "name", "name" },
    ev_shuttle_gone  = { "Navette : %s et %s, deux dissidents, quittent le vaisseau", "name", "name" },
    ev_shuttle_empty = { "Navette : partie à vide" },
}

M.SOUNDS = {}                           -- no file of its own: the dock's siren tells the last seconds

-- The dock: a sector with spawn points (on the floor, clear: the game puts the players there) and
-- two seats there, two distinct points SEAT_MIN to SEAT_MAX apart on one deck; with no such pair,
-- one point and a second seat at its right. Returns the sector and the two seats, or nil.
local function pick_dock()
    local sectors = {}
    for _, s in ipairs(W.SECTORS) do
        if #W.spawn_spots(s) > 0 then sectors[#sectors + 1] = s end
    end
    if #sectors == 0 then return nil end
    local s = sectors[math.random(#sectors)]
    local spots = W.spawn_spots(s)
    local couples = {}
    for i = 1, #spots do
        for j = i + 1, #spots do
            local a, b = spots[i].at, spots[j].at
            local d = W.dist2d(a, b)
            if d >= SEAT_MIN and d <= SEAT_MAX and math.abs(a.Z - b.Z) <= SEAT_DZ / 2 then couples[#couples + 1] = { a, b } end
        end
    end
    if #couples > 0 then
        local c = couples[math.random(#couples)]
        return s, U.vec_copy(c[1]), U.vec_copy(c[2])
    end
    local e = spots[math.random(#spots)]
    local yaw = math.rad((e.yaw or 0) + 90)
    return s, U.vec_copy(e.at), { X = e.at.X + SEAT_SIDE * math.cos(yaw), Y = e.at.Y + SEAT_SIDE * math.sin(yaw), Z = e.at.Z }
end

-- The seat a player sits on, or nil.
local function seat_of(r, P)
    for _, seat in ipairs(r.seats) do
        if seat.P and seat.P.key == P.key then return seat end
    end
    return nil
end

-- The nearest seat within reach of a position: the nearest free one, else whether a taken one is
-- within reach (nil, true).
local function near_seat(r, at)
    local best, best_d, taken = nil, SEAT_RADIUS, false
    for _, seat in ipairs(r.seats) do
        local d = W.dist2d(at, seat.at)
        if d <= SEAT_RADIUS and math.abs(at.Z - seat.at.Z) <= SEAT_DZ then
            if seat.P then
                taken = true
            elseif d <= best_d then
                best, best_d = seat, d
            end
        end
    end
    return best, taken
end

-- A passenger off its seat: walking again, its seat free (cyan), told. why: "LEAVE" (it got off by
-- itself: named, the face worn) or "FREED" (killed, gone, carried away).
local function get_off(ctx, seat, why)
    local P = seat.P
    if seat.h then ctx.undo(seat.h) end
    seat.P, seat.h = nil, nil
    ctx.mark(seat.slot, seat.at, "cyan", true, "col")
    if why == "LEAVE" then
        ctx.say(nil, "LEAVE", ctx.face(P))
        ctx.recap("ev_shuttle_leave", seat.idx)
    else
        ctx.say(nil, "FREED")
    end
    if ctx.valid(P) then ctx.line(P, nil) end    -- the line of everyone again (the dock, or the doors closed)
end

-- 10 s before the departure: nobody boards or gets off any more, the dock's siren sounds.
local function close(ctx, now)
    local r = ctx.run
    r.closed = true
    ctx.say(nil, "CLOSED")
    ctx.line(nil, "CLOSED", r.ends - now)
    for i, box in ipairs(W.alarms()) do
        if box.sector == r.s then ctx.siren("q" .. i, box, 1, 1, r.ends - now) end
    end
end

-- A win by the shuttle: the game's own End Game 3 s later (the frame's), each side's title.
local function win(ctx, side, i1, i2)
    local emp = side == "employees"
    ctx.say(nil, emp and "WIN_EMP" or "WIN_DIS")
    ctx.recap(emp and "ev_shuttle_emp" or "ev_shuttle_dis", i1, i2)
    ctx.log("départ, victoire des %s", emp and "employés" or "dissidents")
    ctx.end_game(side, { won = "shuttle_won", lost = "shuttle_lost" })
end

-- The departure: the living passengers decide (their sides as they are now).
local function depart(ctx, now)
    local r = ctx.run
    r.departed = true
    local list, idx = {}, {}
    for _, seat in ipairs(r.seats) do
        local P = seat.P
        if P and ctx.valid(P) and G.is_alive(P.mec) then
            list[#list + 1] = P
            idx[#idx + 1] = seat.idx
        end
    end
    -- a test alone: the one passenger decides by its side, to see the end screen (a tested game
    -- is not counted in the statistics)
    if r.solo and #list == 1 then
        ctx.say(nil, "SOLO")
        return win(ctx, ctx.camp(list[1]) == "dissident" and "dissidents" or "employees", idx[1], idx[1])
    end
    if #list < 2 then
        ctx.say(nil, "EMPTY")
        ctx.recap("ev_shuttle_empty")
        ctx.log("départ à vide")
        return ctx.finish("done")                -- the passenger, if any, let go by the frame
    end
    local P1, P2 = list[1], list[2]
    local d1, d2 = ctx.camp(P1) == "dissident", ctx.camp(P2) == "dissident"
    ctx.say(nil, "DEPART", ctx.face(P1), ctx.face(P2))
    if d1 and d2 then
        -- they leave the ship: dead with no killer and no body, never raised (the Liés follow, the
        -- Revenant keeps its apparitions: lpr_server.lua's own rules); the game goes on
        ctx.say(nil, "GONE")
        ctx.say(nil, "GOES_ON")
        ctx.recap("ev_shuttle_gone", idx[1], idx[2])
        ctx.log("départ de deux dissidents")
        ctx.kill(P1, "shuttle", { no_save = true, body = false })
        ctx.kill(P2, "shuttle", { no_save = true, body = false })
        ctx.at(2.5, function() ctx.finish("done") end)
    elseif d1 or d2 then
        win(ctx, "dissidents", idx[1], idx[2])
    else
        win(ctx, "employees", idx[1], idx[2])
    end
end

function M.can_start(ctx, now, test)
    if not test then
        local gm = G.gm()
        if U.get(gm, "Difficulty", 1) == 0 then return false end      -- training: no dissident
        -- the departure and the 3 s before the end screen must come before the clock runs out
        if ctx.clock() < C.get("event_shuttle_seconds") + MARGIN then return false end
    end
    if not pick_dock() then return false, "NOPE" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    local secs = C.get("event_shuttle_seconds")
    local s, a, b = pick_dock()
    if not s then return false end
    r.s = s
    r.seats = { { slot = "e1", at = a }, { slot = "e2", at = b } }
    r.ends, r.close_at = now + secs, now + secs - CLOSE_BEFORE
    r.solo = test and #ctx.living() <= 1
    r.departed, r.closed, r.last_key = false, false, {}
    ctx.mark("e1", a, "cyan", true, "col")
    ctx.mark("e2", b, "cyan", true, "col")
    -- three banners at most at once; how to board goes in the notice at the top of the screen,
    -- the whole rule on the tablet
    ctx.say(nil, "START", s)
    ctx.say(nil, "RULE_EMP")
    ctx.say(nil, "RULE_DIS")
    ctx.notice("living", "HOW", "act")
    ctx.line(nil, "DOCK", secs, s)
    -- the living players' power key comes here: M.on_key keeps it only on or by a seat, and
    -- everywhere else the role's power runs as usual
    for _, P in ipairs(ctx.living()) do ctx.key(P, true, false) end
    ctx.recap("ev_shuttle", s)
    ctx.log("quai : secteur %d", s)
    return secs + 4
end

function M.tick(ctx, now)
    local r = ctx.run
    if r.departed then return end
    -- a passenger killed, gone, or carried away from its seat gives it up; a dreaming Rêveur
    -- stays aboard (its body sits on the seat, and counts at the departure)
    ctx.every(0.2, "seats", function()
        for _, seat in ipairs(r.seats) do
            local P = seat.P
            if P then
                local at = ctx.valid(P) and G.is_alive(P.mec) and ctx.where(P) or nil
                if not at or W.dist2d(at, seat.at) > OFF_SEAT or math.abs(at.Z - seat.at.Z) > OFF_SEAT then
                    get_off(ctx, seat, "FREED")
                end
            end
        end
    end)
    if not r.closed and now >= r.close_at then close(ctx, now) end
    -- the countdown at the top of the screen
    local n = math.ceil(r.ends - now)
    if n >= 1 and n <= 3 and n ~= r.counted then
        r.counted = n
        ctx.notice(nil, "COUNT", n)
    end
    if now >= r.ends then depart(ctx, now) end
end

function M.on_key(ctx, P, kind)
    local r, now = ctx.run, ctx.now()
    if kind ~= "act" or r.departed then return false end
    -- away from its body (dead, dreaming, flying, hidden, getting up): the role's power
    if not ctx.present(P) then return false end
    if now - (r.last_key[P.key] or -math.huge) < KEY_GAP then return true end
    local seat = seat_of(r, P)
    if seat then
        -- aboard, the key only gets off (a Fée does not fly, a Clandestin does not hide from a seat)
        if r.closed then
            ctx.say(P, "CLOSED")
            ctx.sfx(P, "fail")
        else
            r.last_key[P.key] = now
            ctx.sfx(P, "ok")
            get_off(ctx, seat, "LEAVE")
        end
        return true
    end
    local at = ctx.where(P)
    if not at then return false end
    local free, taken = near_seat(r, at)
    if not free then
        if not taken then return false end
        ctx.say(P, "TAKEN")
        ctx.sfx(P, "fail")
        return true
    end
    if r.closed then
        ctx.say(P, "CLOSED")
        ctx.sfx(P, "fail")
        return true
    end
    -- boards: walking held until the departure (and a little after: the frame lets go at the end)
    free.P, free.idx = P, ctx.idx(P)
    free.h = ctx.freeze(P, r.ends - now + 5, { move = true, act = false })
    r.last_key[P.key] = now
    ctx.sfx(P, "ok")
    ctx.mark(free.slot, free.at, "orange", true, "col")
    ctx.say(nil, "BOARD", ctx.face(P))
    ctx.line(P, "ABOARD", r.ends - now)
    ctx.recap("ev_shuttle_board", free.idx)
    return true
end

-- The dead do not board (their key is theirs again); a passenger who dies frees its seat.
function M.on_death(ctx, P)
    local r = ctx.run
    ctx.key(P, false, false)
    if r.departed then return end
    local seat = seat_of(r, P)
    if seat then get_off(ctx, seat, "FREED") end
end

-- A player raised may board.
function M.on_rez(ctx, P)
    if not ctx.run.departed then ctx.key(P, true, false) end
end

-- Nothing of its own: the frame lets the passengers walk again, takes the marks, the keys, the
-- siren and the line back.
function M.stop(ctx, reason) end

M.client = {}                           -- nothing local: the frame's messages do it all

return M
