-- LPRoles - statistics kept by the host from one game and one evening to the next, shown to
-- every player in the LPROLES tab under the summary of the last game.
-- The host appends each counted game to statistiques.txt in the mod folder (a file the mod
-- writes itself: updates and installs leave it alone) and adds it up per player name and per
-- role. Players receive numbers only (player indexes, role ids) and write the lines with the
-- names they know, as for the summary.
local U = require("lpr_util")
local N = require("lpr_net")
local S = require("lpr_strings")
local RC = require("lpr_recap")

local ST = {}

local PER_MESSAGE = 20

-- ---------------------------------------------------------------- host
-- File: a comment line, then per game a line "P<tab>date<tab>ending<tab>seconds<tab>players"
-- followed by one line per player "J<tab>name<tab>role drawn<tab>role at the end<tab>camp<tab>
-- won<tab>survived<tab>kills". In a name, %, tab and line breaks are written %XX.
local FILE = U.MOD_DIR .. "/statistiques.txt"
local loaded = false
local totals = { games = 0, tonight = 0 }
local by_name = {}           -- name -> { g, w, k, s, tg, tw }: games, wins, kills, survivals, tonight's games and wins
local by_role = {}           -- role drawn -> { g, w }

local function esc(s)
    return (tostring(s):gsub("[%%\t\r\n]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function unesc(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function add(name, role, won, survived, kills, tonight)
    if name ~= "?" and name ~= "" then
        local r = by_name[name] or { g = 0, w = 0, k = 0, s = 0, tg = 0, tw = 0 }
        by_name[name] = r
        r.g = r.g + 1
        if won then r.w = r.w + 1 end
        r.k = r.k + kills
        if survived then r.s = r.s + 1 end
        if tonight then
            r.tg = r.tg + 1
            if won then r.tw = r.tw + 1 end
        end
    end
    local q = by_role[role] or { g = 0, w = 0 }
    by_role[role] = q
    q.g = q.g + 1
    if won then q.w = q.w + 1 end
end

-- The file is read once, the first time the statistics are needed (on the host only).
local function load()
    if loaded then return end
    loaded = true
    local f = io.open(FILE, "r")
    if not f then
        U.log("Statistiques : pas encore de fichier (%s)", FILE)
        return
    end
    local games, skipped, in_game = 0, 0, false
    for line in f:lines() do
        line = line:gsub("\r$", "")
        local p = U.split(line, "\t")
        if p[1] == "P" and #p == 5 then
            games, in_game = games + 1, true
        elseif p[1] == "J" and #p == 8 and in_game then
            add(unesc(p[2]), p[3], p[6] == "1", p[7] == "1", tonumber(p[8]) or 0, false)
        elseif line ~= "" and line:sub(1, 1) ~= "#" then
            skipped = skipped + 1
        end
    end
    f:close()
    totals.games = games
    U.log("Statistiques : %d partie(s) lue(s) dans %s%s", games, FILE,
        skipped > 0 and string.format(", %d ligne(s) illisible(s) ignorée(s)", skipped) or "")
end

-- A counted game. players: { { name, first, role, camp, won, survived, kills }, ... }
function ST.record(ending, seconds, players)
    load()
    local parts = { string.format("P\t%s\t%s\t%d\t%d\n", os.date("%Y-%m-%d %H:%M"), ending, math.floor(seconds), #players) }
    for _, p in ipairs(players) do
        parts[#parts + 1] = string.format("J\t%s\t%s\t%s\t%s\t%d\t%d\t%d\n", esc(p.name), p.first, p.role, p.camp,
            p.won and 1 or 0, p.survived and 1 or 0, p.kills or 0)
        add(p.name, p.first, p.won, p.survived, p.kills or 0, true)
    end
    totals.games, totals.tonight = totals.games + 1, totals.tonight + 1
    local existed, cut = io.open(FILE, "rb"), false
    if existed then
        local size = existed:seek("end")
        if size and size > 0 then
            existed:seek("set", size - 1)
            cut = existed:read(1) ~= "\n"          -- the last line was cut (or edited by hand)
        end
        existed:close()
    end
    local f = io.open(FILE, "a")
    if not f then
        U.log("Statistiques : %s n'a pas pu être écrit (la partie compte pour ce soir seulement)", FILE)
        return
    end
    if not existed then
        f:write("# LPRoles - statistiques des parties : une ligne P par partie, puis une ligne J par joueur (séparées par des tabulations)\n")
    end
    f:write((cut and "\n" or "") .. table.concat(parts))       -- one write per game
    f:close()
    U.log("Statistiques : partie enregistrée (%s, %d joueurs)", ending, #players)
end

-- The messages for the players present ({ { idx, name }, ... }), and their content as one
-- string (to send them again only when it changed). nil when no game was ever counted.
function ST.messages(present)
    load()
    if totals.games == 0 then return nil end
    local out = { { "H", totals.games, totals.tonight } }
    local recs = {}
    for _, p in ipairs(present) do
        local r = by_name[p.name]
        if r then recs[#recs + 1] = table.concat({ p.idx, r.g, r.w, r.k, r.s, r.tg, r.tw }, ".") end
    end
    for i = 1, #recs, PER_MESSAGE do
        out[#out + 1] = { "P", table.concat(recs, ";", i, math.min(#recs, i + PER_MESSAGE - 1)) }
    end
    local roles = {}
    for id, q in pairs(by_role) do roles[#roles + 1] = { id = id, g = q.g, w = q.w } end
    table.sort(roles, function(a, b)
        if a.g ~= b.g then return a.g > b.g end
        return a.id < b.id
    end)
    local rr = {}
    for _, q in ipairs(roles) do rr[#rr + 1] = q.id .. "." .. q.g .. "." .. q.w end
    for i = 1, #rr, PER_MESSAGE do
        out[#out + 1] = { "R", table.concat(rr, ";", i, math.min(#rr, i + PER_MESSAGE - 1)) }
    end
    out[#out + 1] = { "Z" }
    local flat = {}
    for _, m in ipairs(out) do flat[#flat + 1] = table.concat(m, "|") end
    return out, table.concat(flat, "/")
end

-- ---------------------------------------------------------------- every machine
local incoming = nil
local lines = {}
local listeners = {}

local function percent(w, g)
    return g > 0 and math.floor(w * 100 / g + 0.5) or 0
end

local function write_out(r)
    local T = S.STATS
    local out = { string.format(T.head, r.games, r.tonight) }
    table.sort(r.players, function(a, b)
        if a.w ~= b.w then return a.w > b.w end
        return a.g < b.g
    end)
    for _, p in ipairs(r.players) do
        out[#out + 1] = string.format(T.player, RC.name_of(p.idx), p.w, p.g, percent(p.w, p.g), p.k, p.s, p.tw, p.tg)
    end
    if #r.roles > 0 then
        local parts = {}
        for _, q in ipairs(r.roles) do
            local name = q.id == "none" and S.RECAP_NO_ROLE or (S.ROLE_NAME[q.id] or q.id)
            parts[#parts + 1] = string.format(T.role, name, q.w, q.g)
        end
        out[#out + 1] = T.roles .. table.concat(parts, ", ")
    end
    return out
end

local function changed()
    for _, fn in ipairs(listeners) do U.try("statistiques", fn) end
end

-- None to show any more (a new host, or one with none to show).
function ST.reset()
    incoming = nil
    if #lines > 0 then
        lines = {}
        changed()
    end
end

local function on_stats(part, a, b)
    if part == "C" then return ST.reset() end
    if part == "H" then
        incoming = { games = tonumber(a) or 0, tonight = tonumber(b) or 0, players = {}, roles = {} }
    elseif not incoming then
        return
    elseif part == "P" then
        -- a player: index, games, wins, kills, survivals, tonight's games, tonight's wins
        for rec in (a or ""):gmatch("[^;]+") do
            local f = U.split(rec, ".")
            incoming.players[#incoming.players + 1] = { idx = tonumber(f[1]) or -1, g = tonumber(f[2]) or 0,
                w = tonumber(f[3]) or 0, k = tonumber(f[4]) or 0, s = tonumber(f[5]) or 0,
                tg = tonumber(f[6]) or 0, tw = tonumber(f[7]) or 0 }
        end
    elseif part == "R" then
        -- a role: id, games, wins
        for rec in (a or ""):gmatch("[^;]+") do
            local f = U.split(rec, ".")
            incoming.roles[#incoming.roles + 1] = { id = f[1], g = tonumber(f[2]) or 0, w = tonumber(f[3]) or 0 }
        end
    elseif part == "Z" then
        lines = write_out(incoming)
        incoming = nil
        changed()
    end
end

function ST.lines()
    return lines
end

-- fn() is called whenever the statistics change.
function ST.on_change(fn)
    listeners[#listeners + 1] = fn
end

function ST.install_client()
    N.on("STATS", on_stats)
end

return ST
