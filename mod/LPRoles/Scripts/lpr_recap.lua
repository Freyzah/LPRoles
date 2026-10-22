-- LPRoles - the summary of the last game, shown in the LPROLES tab.
-- The host notes, as the game goes, who does what to whom and when. At the end it sends that,
-- with every player's role, camp and fate, to all machines ("RECAP" messages). Only numbers
-- travel: each machine writes the summary out with the names it knows, and keeps it until the
-- next game starts.
local U = require("lpr_util")
local G = require("lpr_game")
local N = require("lpr_net")
local S = require("lpr_strings")

local R = {}

local MAX_EVENTS = 60        -- noted per game: more than a long game gives
local PER_MESSAGE = 20       -- events per message

-- ---------------------------------------------------------------- host
local events, started = {}, 0

function R.start(now)
    events, started = {}, now or U.now()
end

-- kind: one of S.RECAP_EVENT; a, b: player indexes (b when there is a second player).
function R.add(kind, a, b)
    if #events >= MAX_EVENTS then return end
    events[#events + 1] = string.format("%d.%s.%d.%d", math.max(0, math.floor(U.now() - started)), kind,
        tonumber(a) or -1, tonumber(b) or -1)
end

-- The messages carrying the summary: how the game ended, then the players, then the events.
-- ending: "employees" | "dissidents" | "jester" | "stopped"; winner: the Bouffon's index;
-- players: { { idx, first, role, camp, state, other }, ... } (see R.install_client).
function R.messages(ending, winner, players)
    local seconds = math.max(0, math.floor(U.now() - started))
    local out = { { "H", ending, tonumber(winner) or -1, seconds } }
    local parts = {}
    for _, p in ipairs(players) do
        parts[#parts + 1] = table.concat({ p.idx, p.first or "none", p.role or "none", p.camp or "employee",
                                            p.state or "alive", p.other or -1 }, ".")
    end
    out[#out + 1] = { "P", table.concat(parts, ";") }
    for i = 1, #events, PER_MESSAGE do
        out[#out + 1] = { "E", table.concat(events, ";", i, math.min(#events, i + PER_MESSAGE - 1)) }
    end
    out[#out + 1] = { "Z" }
    return out
end

-- ---------------------------------------------------------------- every machine
local names = {}             -- player index -> name, noted during the game (a player who left keeps it)
local incoming = nil         -- the summary being received
local lines = {}             -- the summary written out, one sentence per line
local listeners = {}

local function name_of(i)
    i = tonumber(i) or -1
    if i < 0 then return "?" end
    local mec = G.mec_by_index(i)
    local n = mec and G.player_name(mec) or nil
    if n and n ~= "?" then
        names[i] = n
        return n
    end
    return names[i] or "?"
end

local function role_name(id)
    if not id or id == "none" then return S.RECAP_NO_ROLE end
    return S.ROLE_NAME[id] or id
end

local function write_out(r)
    local out = {}
    local ending = string.format(S.RECAP_END[r.ending] or S.RECAP_END.stopped, name_of(r.winner))
    out[#out + 1] = string.format(S.RECAP_LENGTH, ending, r.seconds // 60, r.seconds % 60)
    for _, p in ipairs(r.players) do
        local role = role_name(p.first)
        if p.role ~= p.first then role = string.format(S.RECAP_HEIR, role, role_name(p.role)) end
        local fate = string.format(S.RECAP_FATE[p.state] or S.RECAP_FATE.dead, name_of(p.other))
        out[#out + 1] = string.format(S.RECAP_PLAYER, name_of(p.idx), role, S.RECAP_CAMP[p.camp] or p.camp, fate)
    end
    for _, e in ipairs(r.events) do
        local fmt = S.RECAP_EVENT[e.kind]
        if fmt then
            out[#out + 1] = string.format("%d:%02d  ", e.t // 60, e.t % 60) .. string.format(fmt, name_of(e.a), name_of(e.b))
        end
    end
    return out
end

local function changed()
    for _, fn in ipairs(listeners) do U.try("récapitulatif", fn) end
end

local function fields(rec)
    return U.split(rec, ".")
end

local function on_recap(part, a, b, c)
    if part == "H" then
        incoming = { ending = a, winner = tonumber(b) or -1, seconds = tonumber(c) or 0, players = {}, events = {} }
    elseif not incoming then
        return
    elseif part == "P" then
        -- a player: index, role drawn, role at the end, camp, fate ("alive", "kill", "poison",
        -- "link", "dead"), the other player of that fate (killer, or the one it was linked to)
        for rec in (a or ""):gmatch("[^;]+") do
            local f = fields(rec)
            incoming.players[#incoming.players + 1] = { idx = tonumber(f[1]) or -1, first = f[2], role = f[3],
                camp = f[4], state = f[5], other = tonumber(f[6]) or -1 }
        end
    elseif part == "E" then
        -- an event: seconds since the start, kind, the player who acted, the one it was done to
        for rec in (a or ""):gmatch("[^;]+") do
            local f = fields(rec)
            incoming.events[#incoming.events + 1] = { t = tonumber(f[1]) or 0, kind = f[2],
                a = tonumber(f[3]) or -1, b = tonumber(f[4]) or -1 }
        end
    elseif part == "Z" then
        lines = write_out(incoming)
        incoming = nil
        U.log("Récapitulatif de la partie reçu (%d lignes)", #lines)
        changed()
    end
end

-- A new game: the summary of the one before is no longer shown.
function R.clear()
    incoming = nil
    if #lines > 0 then
        lines = {}
        changed()
    end
end

function R.lines()
    return lines
end

-- fn() is called whenever the summary changes.
function R.on_change(fn)
    listeners[#listeners + 1] = fn
end

function R.install_client()
    N.on("RECAP", on_recap)
    -- names noted while everyone is there: a player who leaves before the end keeps one
    local last = 0
    U.every_tick("noms des joueurs", function(now)
        if now - last < 3 then return end
        last = now
        for _, mec in ipairs(G.all_mecs()) do
            local i, n = G.player_index(mec), G.player_name(mec)
            if type(i) == "number" and i >= 0 and n ~= "?" then names[i] = n end
        end
    end)
end

return R
