-- LPRoles - the summary of the last game, shown in the LPROLES tab.
-- The host notes, as the game goes, who does what to whom and when. At the end it sends that,
-- with every player's role, camp and fate, to all machines ("RECAP" messages). Only numbers
-- travel: each machine writes the summary out with the names it knows, and keeps it until the
-- next game starts.
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local N = require("lpr_net")
local S = require("lpr_strings")

local R = {}

-- Noted per game, more than a long game gives. The random events' lines ("ev_..." kinds, a
-- meeting's votes for instance) have a budget of their own, so that they never push out the
-- deaths of the end of a game.
local MAX_EVENTS, MAX_EV_EVENTS = 60, 60
local PER_MESSAGE = 20       -- events per message
local NAME_NAME = { "name", "name" }      -- the values of an event, when nothing else is said

-- ---------------------------------------------------------------- host
local events, started = {}, 0
local counted = { other = 0, ev = 0 }

function R.start(now)
    events, started = {}, now or U.now()
    counted = { other = 0, ev = 0 }
end

-- kind: one of S.RECAP_EVENT; a, b: integers, player indexes unless S.RECAP_ARGS says otherwise
-- (b when there is a second value).
function R.add(kind, a, b)
    local budget = tostring(kind):sub(1, 3) == "ev_" and "ev" or "other"
    if counted[budget] >= (budget == "ev" and MAX_EV_EVENTS or MAX_EVENTS) then return end
    counted[budget] = counted[budget] + 1
    events[#events + 1] = string.format("%d.%s.%d.%d", math.max(0, math.floor(U.now() - started)), kind,
        math.floor(tonumber(a) or -1), math.floor(tonumber(b) or -1))
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

-- (also used by the statistics, lpr_stats.lua)
R.name_of = name_of

-- The first `width` characters of a text (an accented letter takes several bytes).
local function cut(s, width)
    if U.length(s) <= width then return s end
    local out, n = {}, 0
    for ch in s:gmatch("[\0-\x7F\xC2-\xF4][\x80-\xBF]*") do
        n = n + 1
        if n > width then break end
        out[n] = ch
    end
    return table.concat(out)
end

-- How a value travels and is written, by kind (the random events' banners, notices, tablet
-- lines and summary lines: lpr_ev.lua). v: what the message carried (a string or a number);
-- low: inside a sentence of the summary (small letters where the kind has them); width: names
-- cut to that many characters (the notice at the top of the screen has one line only).
--   name   a player's index        -> its name, as this machine knows it (kept for a player who left)
--   names  indexes "3-7-9"          -> "ANNA, PAUL, LÉA"
--   num    an integer               -> the integer
--   clock  seconds                  -> "2:05"
--   sector a sector, 1 to 7         -> S.SECTOR ("RESTAURANT"), or S.ROOM with low
--   sector_low (old name: room)     -> S.ROOM ("restaurant")
--   weapon a code, 0 to 11          -> S.WEAPON ("COUTEAU"), or S.WEAPON_LOW with low
--   key    "act" or "use"           -> this player's own key ("B", "SOURIS 5")
local function arg(kind, v, low, width)
    if kind == "room" or kind == "sector_low" then kind, low = "sector", true end
    if kind == "name" then
        local n = name_of(v)
        return width and cut(n, width) or n
    elseif kind == "names" then
        local out = {}
        for i in tostring(v or ""):gmatch("%d+") do out[#out + 1] = arg("name", i, low, width) end
        return table.concat(out, ", ")
    elseif kind == "num" then
        return string.format("%d", math.floor((tonumber(v) or 0) + 0.5))
    elseif kind == "clock" then
        local s = math.max(0, math.floor(tonumber(v) or 0))
        return string.format("%d:%02d", s // 60, s % 60)
    elseif kind == "sector" then
        return (low and S.ROOM or S.SECTOR)[tonumber(v) or -1] or "?"
    elseif kind == "weapon" then
        return (low and S.WEAPON_LOW or S.WEAPON)[tonumber(v) or -1] or "?"
    elseif kind == "key" then
        return C.format(v == "use" and "use_key" or "power_key")
    end
    return tostring(v or "?")
end
R.arg = arg

-- A format with its values written by kind ("%d" taken as "%s": every value is a text by then).
-- kinds: { kind of the first value, ... }; values: what the messages carried.
function R.write(fmt, kinds, values, low, width)
    local out = {}
    for i, kind in ipairs(kinds) do out[i] = arg(kind, values[i], low, width) end
    local ok, text = pcall(string.format, (tostring(fmt):gsub("%%d", "%%s")), table.unpack(out, 1, #kinds))
    return ok and text or tostring(fmt)
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
            -- two players, unless the kind says what its values are (a random event's sector, a count...)
            local kinds = S.RECAP_ARGS[e.kind] or NAME_NAME
            out[#out + 1] = string.format("%d:%02d  ", e.t // 60, e.t % 60) .. R.write(fmt, kinds, { e.a, e.b }, true)
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
        -- "link", "dead", or a random event's "gas", "bomb", "shuttle"), the other player of that
        -- fate (killer, or the one it was linked to)
        for rec in (a or ""):gmatch("[^;]+") do
            local f = fields(rec)
            incoming.players[#incoming.players + 1] = { idx = tonumber(f[1]) or -1, first = f[2], role = f[3],
                camp = f[4], state = f[5], other = tonumber(f[6]) or -1 }
        end
    elseif part == "E" then
        -- an event: seconds since the start, kind, the player who acted, the one it was done to
        -- (or the values S.RECAP_ARGS names; a kind this machine does not know is left out)
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
