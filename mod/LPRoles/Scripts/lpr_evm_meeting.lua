-- LPRoles - random event RÉUNION D'URGENCE (meeting): everyone is called to one place of the
-- ship, the clock and the task machines stopped; a roll call, a debate under a truce, a vote
-- with the power key, then the search of the player voted out and a consigne.
--   - Host: the place (the spawn point nearest the middle of a sector, a column seen through
--     the walls, the sector's alarm box sounding to guide by ear), the clock held and the task
--     machines' slots locked while everyone walks there; the roll call by the bodies; the truce
--     of those present (the game's blows, shots, pick-ups... and their role powers: decision 7);
--     the vote; the result (lifts clock, machines and truce at once); the search and consigne.
--   - Every machine: nothing of its own. Banners, notices, tablet lines, the column, the siren
--     and the chime all go through the frame (lpr_ev.lua), which takes them back at the end.
-- Who is named how: presence, absence, lateness, the search and the votes of the summary are the
-- system's announcements (the real name); "TON VOTE", "A FRAPPÉ", "ATTAQUE" are seen (the face
-- worn: a Métamorphe's disguise). The contradiction is a clue, on purpose.
local C = require("lpr_config")
local G = require("lpr_game")
local U = require("lpr_util")
local W = require("lpr_ev_world")

local M = { id = "meeting", switch = "event_meeting",
            KEYS = { "event_meeting_walk", "event_meeting_debate", "event_meeting_vote", "event_meeting_radius",
                     "event_meeting_hold" },
            min_living = 4, not_before = 180, not_last = 90, once = true }

-- Banners queue 2.6 s each: at most three at a time; what is urgent or personal (the vote, the
-- consigne, the restart) is a notice, shown at once.
M.TEXT = {
    START    = { "RÉUNION D'URGENCE" },
    WHERE    = { "%s, DANS %s S", "sector", "num" },
    FROZEN   = { "CHRONO ET MACHINES ARRÊTÉS" },
    ALL      = { "TOUT LE MONDE EST LÀ", c = "good" },
    ABSENT   = { "ABSENTS : %s", "names", c = "warn" },
    ABSENT_N = { "%s ABSENTS : VOIR TABLETTE", "num", c = "warn" },
    TRUCE    = { "DÉBAT : TRÊVE DE %s S", "num" },
    NOKEY    = { "TRÊVE : POUVOIR BLOQUÉ", c = "warn", n = true },
    VOTE     = { "POUR VOTER : VISE + %s", "key", n = true },
    MYVOTE   = { "TON VOTE : %s", "name", c = "good", n = true },
    NOVOTE   = { "TON VOTE : AUCUN", n = true },
    BADVOTE  = { "VISE UN JOUEUR DE LA RÉUNION", c = "warn", n = true },
    LATE     = { "EN RETARD : %s", "name", c = "warn" },
    HIT      = { "%s A FRAPPÉ EN RÉUNION", "name", c = "bad" },
    ATTACK   = { "%s ATTAQUE LA RÉUNION", "name", c = "bad" },
    END      = { "FIN DE LA RÉUNION" },
    NOMAJ    = { "PAS DE MAJORITÉ", c = "warn" },
    RESUME   = { "CHRONO ET MACHINES RELANCÉS", c = "good", n = true },
    SEARCH   = { "FOUILLÉ : %s", "name", c = "warn" },
    HAND     = { "MAIN : %s", "weapon", c = "warn" },
    BAG      = { "SAC : %s", "weapon", c = "warn" },
    EMPTY    = { "POCHES VIDES", c = "warn" },
    HELD     = { "TU ES CONSIGNÉ %s S", "num", c = "bad", n = true },
    FREE     = { "CONSIGNE LEVÉE", c = "good", n = true },
    NOPE     = { "TEST : AUCUN LIEU DE RÉUNION", c = "warn" },
}

M.LINES = {
    WALK   = { "Réunion d'urgence : %s, à moins de %s m de la colonne - {t}", "sector", "num" },
    OUT    = { "Réunion en cours : %s - fin du débat dans {t}", "sector" },
    OUT_A  = { "Réunion en cours : %s - absents : %s - fin du débat dans {t}", "sector", "names" },
    DEB_A  = { "Trêve, pouvoirs bloqués - absents : %s - vote dans {t}", "names" },
    DEB_0  = { "Trêve, pouvoirs bloqués - tout le monde est là - vote dans {t}" },
    VOTE   = { "Vote : vise un joueur et appuie sur %s (sans cible : aucun) - {t}", "key" },
    MYVOTE = { "Ton vote : %s (modifiable) - {t}", "name" },
    NOVOTE = { "Ton vote : aucun (modifiable) - {t}" },
    HELD   = { "Consigné : ni marcher ni agir, tu peux parler - {t}" },
}

M.RECAP = {
    ev_meeting        = { "Évènement : réunion d'urgence (%s)", "sector_low" },
    ev_meeting_all    = { "Réunion : tout le monde était là" },
    ev_meeting_absent = { "Réunion : %s n'était pas là", "name" },
    ev_meeting_late   = { "Réunion : %s est arrivé en retard", "name" },
    ev_meeting_hit    = { "Réunion : %s a frappé pendant la trêve", "name" },
    ev_meeting_vote   = { "Réunion : %s a voté contre %s", "name", "name" },
    ev_meeting_none   = { "Réunion : pas de majorité" },
    ev_meeting_search = { "Réunion : %s a été fouillé", "name" },
    ev_meeting_hand   = { "Réunion : %s avait en main : %s", "name", "weapon" },
    ev_meeting_bag    = { "Réunion : %s avait dans son sac : %s", "name", "weapon" },
    ev_meeting_cut    = { "Réunion : interrompue avant le vote" },
}

M.SOUNDS = { "ev_meeting_chime" }

local DZ = 250               -- cm: the same deck (a body further up or down is on another floor)
local AIM_MAX = 3000         -- cm: the vote's aim reaches twice the radius, never more than this
local SIREN = { on = 1.0, off = 2.0 }    -- s: the box sounds in pulses, to be followed by ear
local MAX_NAMED = 4          -- absents named in the banner; more: their number, the names on the tablet
-- A sleeping, flying or hidden player voted out is woken first and searched this much later: the
-- game puts the Rêveur's body back meanwhile (lpr_server's P.tail, 1.5 s).
local WAKE_DELAY = 2.0
-- The truce lasts this long past the vote: the result lifts it itself, and keeps the named one's
-- until the search (a moment later when that player had to be woken).
local MARGIN = WAKE_DELAY + 1
-- A shot this soon after joining left the gun before the truce reached that player's machine.
local GRACE = 0.5
-- The chime has to be heard before the event's end takes the sounds back (EVOFF).
local CHIME_TAIL = 2.5

-- ---------------------------------------------------------------- host
-- In the circle: the body (a sleeping Rêveur's sits where it fell asleep; a hidden Clandestin
-- has none: it is never present, and its place is never told), within the radius, same deck.
-- (Not ctx.present: that one leaves the sleeping Rêveur out, whose body does count here.)
local function inside(ctx, r, P)
    local at = ctx.where(P)
    if not at then return false end
    local dx, dy = at.X - r.spot.X, at.Y - r.spot.Y
    return dx * dx + dy * dy <= r.radius2 and math.abs(at.Z - r.spot.Z) <= DZ
end

-- The members still connected (in the order they came); alive: only the living ones. A player
-- who left drops out of the members and of the votes that way.
local function members(ctx, r, alive)
    local out = {}
    for _, P in ipairs(r.list) do
        if ctx.valid(P) and (not alive or G.is_alive(P.mec)) then out[#out + 1] = P end
    end
    return out
end

local function is_member(r, P)
    return P ~= nil and r.member ~= nil and r.member[P.key] == P
end

-- The meeting place: the spawn point of the sector nearest its middle (on the floor, clear).
local function place_of(s)
    local c = W.sector_center(s)
    if not c then return nil end
    local best, best_d = nil, math.huge
    for _, e in ipairs(W.spawn_spots(s)) do
        local d = U.dist(e.at, c)
        if d < best_d then best, best_d = e, d end
    end
    return best and U.vec_copy(best.at) or nil
end

-- A member's own tablet line: what comes next and when.
local function member_line(ctx, r, P, now)
    if r.phase == "vote" then
        ctx.line(P, "VOTE", r.t_result - now, "act")
    elseif #r.absent > 0 then
        ctx.line(P, "DEB_A", r.t_vote - now, r.absent)
    else
        ctx.line(P, "DEB_0", r.t_vote - now)
    end
end

-- A living player in the circle becomes a member: in the truce until the result, its power key
-- the meeting's (decision 7: the truce holds the role powers too; during the vote the key votes).
-- A member stays one wherever it walks (a swap of places included).
local function join(ctx, r, P, now)
    r.member[P.key] = P
    r.list[#r.list + 1] = P
    r.since[P.key] = now
    ctx.truce(P, r.t_result - now + MARGIN)
    ctx.key(P, true, false)
end

local result               -- defined below (the roll call ends at once when nobody came)

local function roll_call(ctx, r, now)
    for _, P in ipairs(ctx.living()) do
        if inside(ctx, r, P) then join(ctx, r, P, now) end
    end
    -- absent: every player of the game who is not there, the dead mixed in, never told apart
    ctx.each(function(P)
        if not is_member(r, P) then
            r.absent[#r.absent + 1] = ctx.idx(P)
            ctx.recap("ev_meeting_absent", P)
        end
    end)
    table.sort(r.absent)
    ctx.siren_off("s1")
    ctx.sound("chime", "ev_meeting_chime", nil, { mode = "flat" })
    if #r.absent == 0 then
        ctx.say(nil, "ALL")
        ctx.recap("ev_meeting_all")
    elseif #r.absent <= MAX_NAMED then
        ctx.say(nil, "ABSENT", r.absent)
    else
        ctx.say(nil, "ABSENT_N", #r.absent)
    end
    -- everyone reads where the meeting is and who is missing; the members then their own line
    if #r.absent > 0 then
        ctx.line(nil, "OUT_A", r.debate, r.sector, r.absent)
    else
        ctx.line(nil, "OUT", r.debate, r.sector)
    end
    r.phase = "debate"
    local list = members(ctx, r)
    if #list == 0 then return result(ctx, r, now) end
    ctx.say(list, "TRUCE", r.debate)
    for _, P in ipairs(list) do member_line(ctx, r, P, now) end
end

local function open_vote(ctx, r, now)
    r.phase = "vote"
    -- a member without the mod has no key to send: nothing reaches its machine
    for _, P in ipairs(members(ctx, r, true)) do
        ctx.notice(P, "VOTE", "act")
        member_line(ctx, r, P, now)
    end
end

-- A living player who comes into the circle during the debate or the vote: late, announced by
-- its real name (the system sees who comes in), in the truce for what is left, may vote.
local function late_check(ctx, r, now)
    for _, P in ipairs(ctx.living()) do
        if not is_member(r, P) and inside(ctx, r, P) then
            join(ctx, r, P, now)
            ctx.say(nil, "LATE", P)
            ctx.recap("ev_meeting_late", P)
            if r.phase == "vote" then ctx.notice(P, "VOTE", "act") end
            member_line(ctx, r, P, now)
        end
    end
end

-- The votes counted: only those whose voter and target are both alive and still there. The
-- target needs `need` votes, half of those cast at least, and no tie at the top.
local function tally(ctx, r)
    local count, cast, seen = {}, 0, {}
    for vk, tk in pairs(r.votes) do
        local V, T = r.member[vk], r.member[tk]
        if V and T and ctx.valid(V) and ctx.valid(T) and G.is_alive(V.mec) and G.is_alive(T.mec) then
            cast = cast + 1
            count[tk] = (count[tk] or 0) + 1
            seen[#seen + 1] = { ctx.idx(V), ctx.idx(T) }
        end
    end
    -- the votes are anonymous until the end of the game: only the summary tells them
    table.sort(seen, function(a, b) return a[1] < b[1] end)
    for _, v in ipairs(seen) do ctx.recap("ev_meeting_vote", v[1], v[2]) end
    local best, n, tie = nil, 0, false
    for tk, c in pairs(count) do
        if c > n then
            best, n, tie = tk, c, false
        elseif c == n then
            tie = true
        end
    end
    local need = ctx.test and 1 or 2              -- a test is played by one or two players
    if best and n >= need and 2 * n >= cast and not tie then return r.member[best] end
    return nil
end

-- The search: hand and bag read, then dropped at the player's feet (anybody may pick them up),
-- then the consigne: neither walking nor acting, still talking, looking, and open to blows. The
-- camp is never told.
local function search(ctx, r)
    local T = r.target
    if not (ctx.valid(T) and G.is_alive(T.mec)) then return ctx.finish("done") end
    local got = ctx.search(T)
    if got.hand then ctx.say(nil, "HAND", got.hand) end
    if got.bag then ctx.say(nil, "BAG", got.bag) end
    if not (got.hand or got.bag) then ctx.say(nil, "EMPTY") end
    ctx.recap("ev_meeting_search", T)
    if got.hand then ctx.recap("ev_meeting_hand", T, got.hand) end
    if got.bag then ctx.recap("ev_meeting_bag", T, got.bag) end
    local now = ctx.now()
    if r.hold > 0 then
        -- the freeze first: it holds "Net Can Interact" too, so lifting the truce after it leaves
        -- no moment when the player could pick its things up again (B counts the holds)
        ctx.freeze(T, r.hold, { move = true, act = true })
        ctx.truce_off(T)
        ctx.notice(T, "HELD", r.hold)
        ctx.line(T, "HELD", r.hold)
        r.t_free = now + r.hold
        r.phase = "held"
    else
        ctx.truce_off(T)
        r.phase = "over"
        ctx.at(CHIME_TAIL, function() ctx.finish("done") end)
    end
end

-- The result: the ship comes back to life now (clock, machines, truce), whatever follows.
result = function(ctx, r, now)
    r.phase = "result"
    for _, P in ipairs(members(ctx, r)) do ctx.key(P, false, false) end
    local T = tally(ctx, r)
    r.target = T
    for _, P in ipairs(members(ctx, r)) do
        if P ~= T then ctx.truce_off(P) end   -- the named one keeps it until searched
    end
    ctx.unlock_slots()
    ctx.freeze_clock(false)
    ctx.unmark("e1")
    ctx.line(nil, nil)
    ctx.notice(nil, "RESUME")
    ctx.sound("chime", "ev_meeting_chime", nil, { mode = "flat" })
    if not T then
        ctx.say(nil, "END")
        ctx.say(nil, "NOMAJ")
        ctx.recap("ev_meeting_none")
        r.phase = "over"
        ctx.at(CHIME_TAIL, function() ctx.finish("done") end)
        return
    end
    ctx.say(nil, "SEARCH", T)
    if ctx.present(T) then return search(ctx, r) end
    -- dreaming, flying, hidden or just woken: brought back first (a hidden Clandestin's real
    -- place is never told: it comes out where it hid), searched once its body is back
    ctx.wake(T, "meeting")
    r.phase = "search"
    ctx.at(WAKE_DELAY, function()
        if r.phase == "search" then search(ctx, r) end
    end)
end

function M.can_start(ctx, now, test)
    if #W.spawn_spots() == 0 then return false, "NOPE" end
    return true
end

function M.start(ctx, now, test)
    local r = ctx.run
    r.walk = C.get("event_meeting_walk")
    r.debate = C.get("event_meeting_debate")
    r.vote_s = math.min(C.get("event_meeting_vote"), r.debate)
    r.hold = C.get("event_meeting_hold")
    local radius = C.get("event_meeting_radius")
    r.radius2 = radius * radius
    r.aim = math.min(2 * radius, AIM_MAX)
    -- a sector with an alarm box when there is one (its siren guides by ear), else any sector
    -- with a spawn point
    local s = W.random_sector(function(x) return #W.spawn_spots(x) > 0 and W.alarm_of(x) ~= nil end)
        or W.random_sector(function(x) return #W.spawn_spots(x) > 0 end)
    r.spot = s and place_of(s)
    if not r.spot then return false end
    r.sector = s
    r.member, r.list, r.since, r.votes, r.hit, r.absent = {}, {}, {}, {}, {}, {}
    -- seen by everyone through the walls, the dead included; nobody is teleported: who comes
    -- with whom is seen
    ctx.mark("e1", r.spot, "cyan", true, "col")
    local alarm = W.alarm_of(s)
    if alarm then ctx.siren("s1", alarm, SIREN.on, SIREN.off, r.walk) end
    ctx.sound("chime", "ev_meeting_chime", nil, { mode = "flat" })
    -- the clock held (shown fixed to everyone, players without the mod included) and the task
    -- machines' slots locked: skipping the meeting wins no time on the tasks with items
    if not ctx.freeze_clock(true) then ctx.log("chrono non figé (moins de 2 s au chrono)") end
    ctx.lock_slots("task")
    ctx.say(nil, "START")
    ctx.say(nil, "WHERE", s, r.walk)
    ctx.say(nil, "FROZEN")
    ctx.line(nil, "WALK", r.walk, s, radius // 100)
    ctx.recap("ev_meeting", s)
    r.t_call = now + r.walk
    r.t_result = r.t_call + r.debate
    r.t_vote = r.t_result - r.vote_s
    r.phase = "walk"
    -- (the frame's hard stop, planned + 15 s, also covers the wait for a player to wake)
    return r.walk + r.debate + r.hold
end

function M.tick(ctx, now)
    local r = ctx.run
    if r.phase == "walk" then
        if now >= r.t_call then roll_call(ctx, r, now) end
    elseif r.phase == "debate" or r.phase == "vote" then
        ctx.every(0.5, "late", function() late_check(ctx, r, now) end)
        if r.phase == "debate" and now >= r.t_vote then open_vote(ctx, r, now) end
        if now >= r.t_result then result(ctx, r, now) end
    elseif r.phase == "search" then
        if not ctx.valid(r.target) then ctx.finish("done") end
    elseif r.phase == "held" then
        local T = r.target
        if not (ctx.valid(T) and G.is_alive(T.mec)) then return ctx.finish("done") end
        if now >= r.t_free then
            ctx.notice(T, "FREE")
            ctx.finish("done")
        end
    end
end

-- The power key of a member (routed for the whole debate). During the debate it does nothing
-- (the truce holds the role powers, decision 7); during the vote it votes for the player aimed
-- at, or for nobody when nobody is aimed at. A hidden Clandestin's key keeps its meaning (out of
-- the vent). A sleeping Rêveur's key never comes here (it always means "my dream ended").
function M.on_key(ctx, P, kind)
    local r = ctx.run
    if kind ~= "act" or not is_member(r, P) then return false end
    if P.hiding then return false end
    if r.phase ~= "vote" or P.fairy or not G.is_alive(P.mec) then
        ctx.sfx(P, "fail")
        if r.phase == "debate" then ctx.notice(P, "NOKEY") end
        return true
    end
    local T = ctx.aimed(P, r.aim)
    local left = r.t_result - ctx.now()
    if T and is_member(r, T) and G.is_alive(T.mec) then
        r.votes[P.key] = T.key
        ctx.notice(P, "MYVOTE", ctx.face(T))       -- the voter names the face it sees
        ctx.line(P, "MYVOTE", left, ctx.face(T))
        ctx.sfx(P, "ok")
    elseif T then
        ctx.notice(P, "BADVOTE")                   -- the vote before is kept
        ctx.sfx(P, "fail")
    else
        r.votes[P.key] = nil                       -- no one aimed at: an abstention
        ctx.notice(P, "NOVOTE")
        ctx.line(P, "NOVOTE", left)
        ctx.sfx(P, "ok")
    end
    return true
end

-- A blow during the truce: by a member (the truce did not hold: a held SMG trigger, say), or on a
-- member from outside. Seen, so the face is named. Once per attacker.
function M.on_hit(ctx, A, V)
    local r = ctx.run
    if r.phase ~= "debate" and r.phase ~= "vote" then return end
    local inner = is_member(r, A)
    if r.hit[A.key] or not (inner or is_member(r, V)) then return end
    r.hit[A.key] = true
    ctx.say(nil, inner and "HIT" or "ATTACK", ctx.face(A))
    ctx.recap("ev_meeting_hit", A)
end

-- A shot by a member: the SMG's automatic fire escapes the game's test of the truce. Swings
-- ("melee") are left out: one that lands is a hit (above), one in the air harms nobody, and the
-- truce keeps the game from swinging anyway.
function M.on_attack(ctx, P, kind)
    local r = ctx.run
    if kind ~= "gun" or (r.phase ~= "debate" and r.phase ~= "vote") then return end
    if not is_member(r, P) or r.hit[P.key] or ctx.now() - (r.since[P.key] or 0) < GRACE then return end
    r.hit[P.key] = true
    ctx.say(nil, "HIT", ctx.face(P))
    ctx.recap("ev_meeting_hit", P)
end

-- A member dies (killed by an absent, or following its Lié): its vote and the votes for it go;
-- the voters who lose theirs are told. The named player dies: nothing left to do.
function M.on_death(ctx, P)
    local r = ctx.run
    if (r.phase == "debate" or r.phase == "vote") and is_member(r, P) then
        r.votes[P.key] = nil
        ctx.key(P, false, false)                   -- a dead Revenant's key is its own again
        ctx.truce_off(P)
        ctx.line(P, nil)                           -- back to the line everyone reads
        local now = ctx.now()
        for vk, tk in pairs(r.votes) do
            if tk == P.key then
                r.votes[vk] = nil
                local V = r.member[vk]
                if V and ctx.valid(V) then
                    ctx.notice(V, "NOVOTE")
                    ctx.line(V, "NOVOTE", r.t_result - now)
                end
            end
        end
    elseif P == r.target and (r.phase == "search" or r.phase == "held" or r.phase == "over") then
        ctx.finish("done")
    end
end

-- A member raised (Ange gardien) during the debate or the vote: truce and key again. The truce
-- is lifted then set again, so that "Net Can Interact" is sent anew whatever the raise did to it.
function M.on_rez(ctx, P)
    local r = ctx.run
    if (r.phase ~= "debate" and r.phase ~= "vote") or not is_member(r, P) then return end
    local now = ctx.now()
    ctx.truce_off(P)
    ctx.truce(P, r.t_result - now + MARGIN)
    ctx.key(P, true, false)
    if r.phase == "vote" then ctx.notice(P, "VOTE", "act") end
    member_line(ctx, r, P, now)
end

-- Stopped before its result (TEST, a switch turned off, the hard stop): called off, no search.
-- At the end of the game nothing is said: the game has its own screens. Everything is undone by
-- the frame after this (column, siren, clock, slots, truces, keys, freeze, lines).
function M.stop(ctx, reason)
    local r = ctx.run
    if reason == "end" then return end
    if r.phase == "walk" or r.phase == "debate" or r.phase == "vote" then
        ctx.say(nil, "END")
        ctx.notice(nil, "RESUME")
        ctx.recap("ev_meeting_cut")
    end
end

-- ---------------------------------------------------------------- every machine
M.client = {}                -- nothing local: the frame's messages do it all

return M
