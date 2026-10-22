-- LPRoles - random events during a game (group ÉVÈNEMENTS of the LPROLES tab).
-- Now and then the host draws one among those switched on; every machine announces it with a
-- banner. Each event reuses what a role already does: the Bâillonneur's gag (radio blackout),
-- the Échangeur's swap (two players change places), the Médecin's heal (everyone's life back),
-- the Revenant's apparition (the dead seen and heard by all) and the host's knowledge of the
-- camps (how many dissidents are still alive).
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local N = require("lpr_net")
local S = require("lpr_strings")
local RC = require("lpr_recap")

local EV = {}

EV.KINDS = { "radio", "swap", "heal", "ghosts", "leak" }
local SWITCH = { radio = "event_radio", swap = "event_swap", heal = "event_heal", ghosts = "event_ghosts",
                 leak = "event_leak" }

-- ---------------------------------------------------------------- host
-- What the host side lends (lpr_server.lua): each_player, tell, broadcast, idx, swap_places
-- and the game's state table (active, started_at, ending).
local env = nil
local started, next_at, busy_until, last = 0, nil, 0, nil

function EV.setup(e)
    env = e
end

-- A game starts (the time it started) / ends.
function EV.start(t)
    started, next_at, busy_until, last = t, nil, 0, nil
end

function EV.stop()
    next_at, busy_until = nil, 0
end

-- A living player of this game (a player who came during the game has no camp).
local function living(filter)
    local out = {}
    env.each_player(function(P)
        if P.camp and G.is_alive(P.mec) and (not filter or filter(P)) then out[#out + 1] = P end
    end)
    return out
end

-- Each event returns true when it took place (its conditions may not be met).
local RUN = {}

-- Panne de radio: every living player's microphone is cut. Only a machine with the mod can cut
-- its own microphone (the game does not share that setting). A gag already running is never
-- shortened.
function RUN.radio(now)
    local list = living(function(P) return P.modded end)
    if #list == 0 then return false end
    local secs = C.get("event_radio_seconds")
    env.broadcast("EVENT", "radio", U.round(secs))
    for _, P in ipairs(list) do
        P.gag_until = math.max(P.gag_until or 0, now + secs)
        env.tell(P, "GAG", U.round((P.gag_until - now) * 10), 1)     -- 1: no "BÂILLONNÉ" banner
    end
    RC.add("ev_radio")
    busy_until = now + secs
    return true
end

-- Grand échange: two living players drawn at random change places, a second after the banner.
-- Left out: a dreaming Rêveur, a flying Fée, a hidden Clandestin (their characters are not where
-- they seem to be), and a Rêveur who has just woken up (the game still puts the body back).
function RUN.swap(now)
    local list = living(function(P)
        return not (P.dreaming or P.fairy or P.hiding or (P.tail and now < (P.tail.ends or 0)))
            and G.location(P.mec) ~= nil
    end)
    if #list < 2 then return false end
    local A = table.remove(list, math.random(#list))
    local B = list[math.random(#list)]
    env.broadcast("EVENT", "swap")
    local game, at = env.game, env.game.started_at
    U.after(1.0, "évènement : échange", function()
        if not (game.active and game.started_at == at) then return end
        if A.dreaming or A.fairy or A.hiding or B.dreaming or B.fairy or B.hiding then return end
        if not (G.is_alive(A.mec) and G.is_alive(B.mec)) then return end
        if env.swap_places(A, B) then
            env.tell(A, "EVENT", "swapyou")
            env.tell(B, "EVENT", "swapyou")
            RC.add("ev_swap", env.idx(A), env.idx(B))
            U.log("Évènement : %s et %s échangent leurs places", G.player_name(A.mec), G.player_name(B.mec))
        end
    end)
    return true
end

-- Soins pour tous: every living player gets all their life back (as with the Médecin's heal,
-- the player's own machine does it: players with the mod only).
function RUN.heal()
    local list = living(function(P) return P.modded end)
    if #list == 0 then return false end
    env.broadcast("EVENT", "heal")
    for _, P in ipairs(list) do env.tell(P, "HEAL") end
    RC.add("ev_heal")
    return true
end

-- Les morts se montrent: every dead player's ghost is seen and heard by all for a while, as a
-- Revenant's. An apparition already running is never shortened, and a Revenant who still has
-- one of its own keeps its power free (the host refuses it while an apparition runs).
function RUN.ghosts(now)
    local dead = {}
    env.each_player(function(P)
        if P.camp and U.valid(P.mec) and not G.is_alive(P.mec) then dead[#dead + 1] = P end
    end)
    if #dead == 0 then return false end
    local secs = C.get("event_ghosts_seconds")
    env.broadcast("EVENT", "ghosts", U.round(secs))
    for _, P in ipairs(dead) do
        local ends = math.max(P.spirit_until or 0, now + secs)
        if P.role == "revenant" and (P.charges or 0) > 0 then
            P.ghost_event_until = ends          -- its own apparition, if it starts one, lasts at least as long
        else
            P.spirit_until = ends
        end
        env.broadcast("SPIRIT", env.idx(P), U.round((ends - now) * 10))
    end
    RC.add("ev_ghosts")
    busy_until = now + secs
    return true
end

-- Fuite d'informations: everyone learns how many dissidents are alive (the Taupe and the
-- Vampire are dissidents; a recruit counts once converted; Bouffon and Amnésique do not).
function RUN.leak()
    if #living() == 0 then return false end   -- no camps in this game (the mod was off at the draw)
    local n = #living(function(P) return P.camp == "dissident" end)
    env.broadcast("EVENT", "leak", n)
    RC.add("ev_leak", n)
    return true
end

-- Sets off one event now (also used by the TEST group). Returns whether it took place.
function EV.run(kind, now)
    if not env or not RUN[kind] then return false end
    local done = U.try("évènement " .. kind, RUN[kind], now) == true
    if done then
        last = kind
        U.log("Évènement : %s", kind)
    end
    return done
end

-- Called by the host's tick while a game is running and the roles are announced.
function EV.tick(now)
    if not env or not C.get("events_on") or not C.get("enabled") or env.game.ending then return end
    next_at = next_at or (started + C.get("event_first_delay"))
    if now < next_at or now < busy_until then return end
    local choices = {}
    for _, kind in ipairs(EV.KINDS) do
        if C.get(SWITCH[kind]) and kind ~= last then choices[#choices + 1] = kind end
    end
    for i = #choices, 2, -1 do                  -- in a random order, until one can take place
        local j = math.random(i)
        choices[i], choices[j] = choices[j], choices[i]
    end
    -- the last one comes again only when none of the others can take place
    if last and C.get(SWITCH[last]) and choices[#choices] ~= last then choices[#choices + 1] = last end
    for _, kind in ipairs(choices) do
        if EV.run(kind, now) then
            next_at = now + C.get("event_interval") * (0.75 + 0.5 * math.random())
            return
        end
    end
    next_at = now + 10                          -- none could take place: tried again a little later
end

-- ---------------------------------------------------------------- every machine
local BANNER = { radio = "EV_RADIO", swap = "EV_SWAP", swapyou = "EV_SWAP_YOU", heal = "EV_HEAL",
                 ghosts = "EV_GHOSTS", leak = "EV_LEAK" }

-- The host's "EVENT kind value".
local function on_event(kind, value)
    local id = BANNER[kind]
    if not id then return end
    if kind == "leak" then G.say(S.EV_LEAK_TITLE, S.COLOR.role) end
    local n = tonumber(value)
    local ok, text = pcall(string.format, S[id], n or 0)
    G.say(ok and text or S[id], S.COLOR.role)
end

function EV.install_client()
    N.on("EVENT", on_event)
end

return EV
