-- LPRoles - the random events: the frame shared by the twelve events (D129).
-- Each event is a module of its own, lpr_evm_<id>.lua (API: .omc/plans/evenements-api.md). It
-- declares its texts, its settings and its conditions, and acts only through the `ctx` handed to
-- it on the host and the `cx` handed to it on every machine, and through lpr_ev_world.lua (W) and
-- lpr_ev_body.lua (B). A module that is missing or does not load is left out: its switch stays
-- in the menu, it never fires.
--   - Host: which event runs (one at a time), when the next one comes, what each one did (all
--     undone when it stops, in the reverse order), the players' keys, deaths, raises, blows and
--     pick-ups passed on to it.
--   - Every machine: the host's messages (EVON, EVOFF, EV, EVKEY, EVLINE, EVMARK, EVGLOW,
--     EVLIGHT, EVSND, EVSIREN, EVCAM, EVBODY, EVFX) and what they show, taken back at the end.
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local N = require("lpr_net")
local S = require("lpr_strings")
local RC = require("lpr_recap")
local A = require("lpr_audio")
local K = require("lpr_marks")
local T = require("lpr_tablet")
local W = require("lpr_ev_world")
local B = require("lpr_ev_body")

local EV = {}

-- The events, by id (file lpr_evm_<id>.lua, setting event_<id>, TEST choice <id>).
EV.IDS = { "meeting", "tape", "weapons", "blackout", "mic", "parcel", "deadknow", "potato", "sun", "gas",
           "shuttle", "magnets" }
-- Causes of death an event brings about (ctx.cause, ctx.kill): such a death has no killer, whatever
-- blow came just before (lpr_server.lua: no Martyr's reveal, no Bouffon's win, no Vampire's meal).
EV.CAUSES = { gas = true, bomb = true, shuttle = true }
-- What the values of a banner, a notice, a tablet line or a summary line may be (lpr_recap.lua,
-- R.arg). "room" is the older name of "sector_low".
EV.KINDS = { name = true, names = true, num = true, clock = true, sector = true, sector_low = true, room = true,
             weapon = true, key = true }
-- A player's name in a notice is cut to this many characters: the notice has one line only
-- (tools/lp/banners.py checks the notices with the longest name so cut).
EV.NOTICE_NAME = 16
-- The marks' slots (the Shérif's card has its own); lights, sounds and sirens take free names.
EV.MARK_SLOTS = { e1 = true, e2 = true, e3 = true, e4 = true }
EV.MAX = { lights = 8, sounds = 32, sirens = 8 }
-- Messages of a module's own a machine answers itself (a module's M.client never has these names).
EV.RESERVED = { say = true, note = true, sfx = true }
-- An event kept for the last moments of a game (M.only_last, the shuttle): from this long before
-- its window opens, no other event starts.
EV.RESERVE = 30
-- How far ctx.aimed looks when the module gives no reach (cm): about the length of a room.
EV.AIM_CM = 300
-- The shortest beat of a light's pulse (ctx.glow, s): the machines draw it at each tick, ten
-- times a second.
EV.MIN_PULSE = 0.3

EV.mods = {}                 -- id -> module, the ones loaded

local loaded = false
local env = nil              -- host: what lpr_server.lua lends (EV.setup)
local sched = { done = {}, last = nil, next_at = nil, started = 0, reserve_at = 0 }
local run = nil              -- host: the running event's ctx
local CL = { keys = { act = false, use = false }, glows = {}, sounds = {}, sirens = {}, dirty = false }   -- this machine

-- ---------------------------------------------------------------- loading the modules
-- Number of values a text takes ("%s", "%d"; "%%" is a sign).
local function formats(fmt)
    local n = 0
    for _ in (tostring(fmt):gsub("%%%%", "")):gmatch("%%[sd]") do n = n + 1 end
    return n
end

-- What is wrong with one entry of M.TEXT, M.LINES or M.RECAP, or nil.
local function bad_spec(spec, numeric)
    if type(spec) ~= "table" or type(spec[1]) ~= "string" then return "pas de texte" end
    for i = 2, #spec do
        if not EV.KINDS[spec[i]] then return "type de valeur inconnu : " .. tostring(spec[i]) end
        if numeric and (spec[i] == "names" or spec[i] == "key") then return "le récapitulatif ne porte que des nombres" end
    end
    if formats(spec[1]) ~= #spec - 1 then return "autant de %s que de valeurs attendu" end
    if spec.c ~= nil and not S.COLOR[spec.c] then return "couleur inconnue : " .. tostring(spec.c) end
    if numeric and #spec > 3 then return "deux valeurs au plus" end
    return nil
end

-- Why a module cannot be taken, or nil.
local function refused(M, id)
    if type(M) ~= "table" then return "le fichier ne rend pas de table" end
    if M.id ~= id then return "M.id vaut " .. tostring(M.id) end
    local sw = C.def(M.switch or "")
    if not sw or sw.kind ~= "bool" then return "interrupteur absent des réglages : " .. tostring(M.switch) end
    for _, key in ipairs(M.KEYS or {}) do
        if not C.def(key) then return "réglage absent : " .. tostring(key) end
    end
    if M.only_last and not C.def(M.only_last) then return "réglage absent : " .. tostring(M.only_last) end
    if type(M.start) ~= "function" then return "pas de M.start" end
    for field, list in pairs({ TEXT = M.TEXT or {}, LINES = M.LINES or {}, RECAP = M.RECAP or {} }) do
        for key, spec in pairs(list) do
            local why = bad_spec(spec, field == "RECAP")
            if why then return string.format("M.%s.%s : %s", field, tostring(key), why) end
            if field == "RECAP" then
                local k = tostring(key)
                local own = "ev_" .. id
                if not (k == own or k:sub(1, #own + 1) == own .. "_") or not k:match("^[a-z0-9_]+$") then
                    return "récapitulatif mal nommé : " .. k
                end
            end
        end
    end
    for name in pairs((M.client) or {}) do
        if EV.RESERVED[name] then return "M.client." .. name .. " : nom réservé" end
    end
    -- the names of its sound files (sounds/<name>.wav or .mp3), made ready on every machine at EVON
    if M.SOUNDS ~= nil and type(M.SOUNDS) ~= "table" then return "M.SOUNDS : une liste de noms attendue" end
    for _, name in ipairs(M.SOUNDS or {}) do
        if type(name) ~= "string" or not name:match("^[a-z0-9_]+$") then
            return "M.SOUNDS : nom de son refusé (a-z, 0-9, _) : " .. tostring(name)
        end
    end
    for _, h in ipairs(M.hooks or {}) do
        if type(h.path) ~= "string" or type(h.fn) ~= "function" then return "M.hooks : chemin ou fonction manquant" end
    end
    return nil
end

-- A hook of a module: called only on the host, while that module runs.
local function module_hook(M, h)
    U.hook(h.path, function(hc, ...)
        local ctx = run
        if ctx and ctx.M == M and not ctx.over and G.is_host() then
            U.try("évènement " .. M.id .. " : accroche", h.fn, ctx, hc, ...)
        end
    end)
end

-- Loads every module there is (once, on every machine): its summary lines join the others,
-- its hooks are set.
function EV.load()
    if loaded then return end
    loaded = true
    local missing, taken = {}, {}
    for _, id in ipairs(EV.IDS) do
        local ok, M = pcall(require, "lpr_evm_" .. id)
        if not ok then
            if tostring(M):find("not found", 1, true) then
                missing[#missing + 1] = id
            else
                U.log("Évènement %s : module illisible, laissé de côté (%s)", id, tostring(M))
            end
        else
            local why = refused(M, id)
            if why then
                U.log("Évènement %s : module laissé de côté (%s)", id, why)
            else
                EV.mods[id] = M
                taken[#taken + 1] = id
                for kind, spec in pairs(M.RECAP or {}) do
                    S.RECAP_EVENT[kind] = spec[1]
                    local kinds = {}
                    for i = 2, #spec do kinds[#kinds + 1] = spec[i] end
                    S.RECAP_ARGS[kind] = kinds
                end
                for _, h in ipairs(M.hooks or {}) do module_hook(M, h) end
            end
        end
    end
    U.log("Évènements chargés : %s%s", #taken > 0 and table.concat(taken, ", ") or "aucun",
        #missing > 0 and (" ; absents : " .. table.concat(missing, ", ")) or "")
end

-- ---------------------------------------------------------------- host: players
local function valid(P)
    return type(P) == "table" and P.key ~= nil and U.valid(P.mec) and env.by_key(P.key) == P
end

-- Alive, in the game, and where its character is: not dreaming (its body sits elsewhere), not
-- flying (Fée), not hidden (Clandestin), not getting back into its body (a Rêveur just woken).
local function present(P, now)
    return valid(P) and P.camp ~= nil and G.is_alive(P.mec) and not (P.dreaming or P.fairy or P.hiding)
        and not (P.tail and (now or U.now()) < (P.tail.ends or 0))
end

-- "employee", "dissident" or "neutral" (a Bouffon, an Amnésique with no role taken). The Taupe and
-- the converted recruits are dissidents.
local function camp_of(P)
    if P.camp == "dissident" then return "dissident" end
    if P.role == "jester" or P.role == "amnesiac" then return "neutral" end
    return "employee"
end

-- Where the player's body is: a dreaming Rêveur's sits where it fell asleep; a hidden Clandestin
-- has none (never its real place: it is not to be told).
local function where(P)
    if not valid(P) or P.hiding then return nil end
    if P.dreaming then return U.vec_copy(P.dreaming.loc) end
    return G.location(P.mec)
end

local function game_players(filter)
    local out = {}
    env.each_player(function(P)
        if P.camp and (not filter or filter(P)) then out[#out + 1] = P end
    end)
    return out
end

-- ---------------------------------------------------------------- host: messages
-- Every argument travels as ASCII: integers, short words (printable ASCII; "|" separates the
-- arguments, so it is taken out).
local function ascii(v)
    if type(v) == "number" then return string.format("%d", U.round(v)) end
    if type(v) == "boolean" then return v and "1" or "0" end
    if v == nil then return "-" end
    local s = tostring(v):gsub("[^\32-\126]", ""):gsub("|", "")
    return s ~= "" and s or "-"
end

-- A value of a text, by its kind: a player (P) or an index for "name"; a list for "names"...
local function wire(kind, v)
    if kind == "name" then
        if type(v) == "table" and v.mec then return ascii(env.idx(v)) end
        return ascii(tonumber(v) or -1)
    elseif kind == "names" then
        if type(v) == "table" then
            local t = {}
            for _, x in ipairs(v) do
                -- a player who left (-1, or no index) is left out: "3--1-5" would read as 3, 1, 5
                local w = wire("name", x)
                if (tonumber(w) or -1) >= 0 then t[#t + 1] = w end
            end
            return #t > 0 and table.concat(t, "-") or "-"
        end
        return ascii(v)
    elseif kind == "key" then
        return v == "use" and "use" or "act"
    end
    return ascii(tonumber(v) or 0)
end

local function wired(spec, ...)
    local args = table.pack(...)
    local out = {}
    for i = 2, #spec do out[#out + 1] = wire(spec[i], args[i - 1]) end
    return table.unpack(out, 1, #spec - 1)
end

-- The players a message goes to: nil for every machine (players of the game or not), "dead",
-- "living" (players of the game), a player, a list of players.
local function targets(who)
    if who == nil then return nil end
    if who == "dead" or who == "living" then
        return game_players(function(P) return G.is_alive(P.mec) == (who == "living") end)
    end
    if type(who) == "table" and who.key ~= nil then return { who } end
    if type(who) == "table" then return who end
    return {}
end

local function deliver(who, cmd, ...)
    local list = targets(who)
    if list == nil then
        env.broadcast(cmd, ...)
        return
    end
    for _, P in ipairs(list) do
        if valid(P) then env.tell(P, cmd, ...) end
    end
end

-- While an event starts, what it says waits: "EVON" goes first (it carries the planned length),
-- and nothing is said of an event that could not start after all.
local function put(who, cmd, ...)
    local q = run and run._.queue
    if q then
        q[#q + 1] = { who = who, cmd = cmd, args = table.pack(...) }
        return
    end
    deliver(who, cmd, ...)
end

local function warn(ctx, what)
    if ctx._.warned[what] then return end
    ctx._.warned[what] = true
    U.log("Évènement %s : %s", ctx.id, what)
end

-- ---------------------------------------------------------------- host: what lasts, undone at the end
-- Every effect that lasts is a handle on the run's stack: undone when the event stops (newest
-- first, with the reason), or before with ctx.undo. client_only: what EVOFF takes back on every
-- machine anyway (marks, lights, sounds, lines...): not sent again when the event stops.
local function handle(ctx, fn, client_only, group, key)
    local h = { fn = fn, client_only = client_only }
    ctx._.undo[#ctx._.undo + 1] = h
    if group then
        local g = ctx._[group]
        if key ~= nil then
            g[key] = g[key] or {}
            g = g[key]
        end
        g[#g + 1] = h
    end
    return h
end

local function undo(ctx, h, reason)
    if not h or h.done then return false end
    h.done = true
    U.try("évènement " .. ctx.id .. " : annulation", h.fn, reason or "done")
    return true
end

local function undo_all(ctx, reason)
    local stack = ctx._.undo
    for i = #stack, 1, -1 do
        local h = stack[i]
        if not h.done then
            h.done = true
            if not h.client_only then U.try("évènement " .. ctx.id .. " : annulation", h.fn, reason) end
        end
    end
end

-- ---------------------------------------------------------------- host: tablet lines
-- A line goes to an audience: everyone (nil), the dead or the living (kept up to date when a
-- player dies or is raised), or players one by one. A player's own line wins over the
-- audience's until it is taken off; a line to everyone replaces all the others.
local function line_msg(ctx, rec, now)
    if not rec then return ctx.id, "-", 0 end
    local tenths = rec.ends and math.max(1, U.round((rec.ends - now) * 10)) or 0
    return ctx.id, rec.key, tenths, table.unpack(rec.args, 1, rec.args.n)
end

local function line_of(ctx, P)
    local L = ctx._.lines
    if L.per[P.key] ~= nil then return L.per[P.key] end
    if P.camp then
        local aud = G.is_alive(P.mec) and L.living or L.dead
        if aud ~= nil then return aud end
    end
    return L.all
end

-- ---------------------------------------------------------------- host: marks
local function mark_args(m, on, pos)
    pos = pos or m.pos or U.vec()
    return m.slot, on and 1 or 0, U.round(pos.X), U.round(pos.Y), U.round(pos.Z), ascii(m.color or "white"),
        m.walls and 1 or 0, ascii(m.shape or "col"), m.rec and ascii(m.rec.name) or "-"
end

-- An item's mark: shown where the item lies, sent again when it moved more than 20 cm, taken
-- off while it is held or gone (checked twice a second).
local function check_item_mark(ctx, m, now)
    m.checked = now
    local t = W.track(m.rec, env.each_player, now)
    if t.where == "ground" and t.at then
        if not m.shown or U.dist(m.shown, t.at) > 20 then
            m.shown = t.at
            put(m.who, "EVMARK", mark_args(m, true, t.at))
        end
    elseif m.shown then
        m.shown = nil
        put(m.who, "EVMARK", mark_args(m, false))
    end
end

-- A player died or was raised: the lines and marks of the dead and of the living follow.
local function refresh_audiences(ctx, P)
    local L = ctx._.lines
    if L.dead ~= nil or L.living ~= nil then put(P, "EVLINE", line_msg(ctx, line_of(ctx, P), U.now())) end
    local alive = G.is_alive(P.mec)
    for _, m in pairs(ctx._.marks) do
        if m.who == "dead" or m.who == "living" then
            local wanted = (m.who == "living") == alive
            local pos = m.rec and m.shown or m.pos
            put(P, "EVMARK", mark_args(m, wanted and pos ~= nil, pos))
        end
    end
end

-- ---------------------------------------------------------------- host: the ctx of a run
local function free_slot(ctx, slot, kind)
    if type(slot) ~= "string" or #slot > 6 or not slot:match("^[a-z0-9]+$") then
        warn(ctx, "nom d'emplacement refusé : " .. tostring(slot))
        return false
    end
    local used = ctx._.slots[kind]
    if not used[slot] then
        local n = 0
        for _ in pairs(used) do n = n + 1 end
        if n >= (EV.MAX[kind] or 8) then
            warn(ctx, "trop d'emplacements " .. kind)
            return false
        end
    end
    used[slot] = true
    return true
end

local stop_run          -- defined below

local function new_ctx(M, now, test)
    local ctx = { id = M.id, M = M, test = test == true, started = now, ends = nil, run = {}, over = false }
    local priv = { undo = {}, every = {}, warned = {}, routes = {}, pressed = {},
                lines = { all = nil, dead = nil, living = nil, per = {} }, marks = {},
                slots = { lights = {}, sounds = {}, sirens = {} },
                truces = {}, freezes = {}, locks = {}, clocks = {}, tints = {} }
    ctx._ = priv

    -- time
    function ctx.now() return U.now() end
    function ctx.at(secs, fn)
        if type(fn) ~= "function" then return warn(ctx, "ctx.at sans fonction (ctx.at(3, function() ... end))") end
        U.after(math.max(0, secs or 0), "évènement " .. ctx.id, function()
            if not ctx.over then U.try("évènement " .. ctx.id .. " : ctx.at", fn) end
        end)
    end
    function ctx.every(secs, key, fn)
        local t = U.now()
        local last = priv.every[key]
        if last and t - last < (secs or 0) - 0.02 then return nil end
        priv.every[key] = t
        return fn(ctx, t)
    end
    function ctx.finish(reason)
        if ctx.over or priv.stopping then return end
        if priv.starting then
            priv.finish = reason or "done"          -- stopped as soon as it has started
            return
        end
        stop_run(ctx, reason or "done")
    end
    function ctx.defer(fn) return handle(ctx, fn, false) end
    function ctx.undo(h) return undo(ctx, h, "done") end
    function ctx.log(fmt, ...)
        local ok, msg = pcall(string.format, fmt, ...)
        U.log("Évènement %s : %s", ctx.id, ok and msg or tostring(fmt))
    end

    -- players
    function ctx.valid(P) return valid(P) end
    function ctx.present(P) return present(P) end
    function ctx.movable(P) return present(P) and where(P) ~= nil end
    function ctx.idx(P) return valid(P) and env.idx(P) or -1 end
    function ctx.by_key(key) return env.by_key(key) end
    function ctx.by_idx(i)
        local found = nil
        env.each_player(function(P) if not found and env.idx(P) == i then found = P end end)
        return found
    end
    function ctx.each(fn) for _, P in ipairs(game_players()) do fn(P) end end
    function ctx.living(filter)
        return game_players(function(P) return G.is_alive(P.mec) and (not filter or filter(P)) end)
    end
    function ctx.dead(filter)
        return game_players(function(P) return not G.is_alive(P.mec) and (not filter or filter(P)) end)
    end
    function ctx.camp(P) return camp_of(P) end
    function ctx.face(P)
        if P.mimic and P.mimic.as_idx then return P.mimic.as_idx end
        return ctx.idx(P)
    end
    function ctx.where(P) return where(P) end
    function ctx.ghost_at(P)
        if not valid(P) then return nil end
        if G.is_local(P.mec) then return G.location(P.mec) end
        local p = U.vec_copy(U.get(P.mec, "Net Location", nil))
        if p then p.Z = p.Z + 160 end
        return p
    end
    function ctx.aimed(P, cm)
        if not valid(P) then return nil end
        return env.aimed(P, cm or EV.AIM_CM)
    end
    function ctx.sees(P, Q, h)
        local a, b = where(P), where(Q)
        if not (a and b) then return false end
        h = h or 100
        return W.sees(P.mec, Q.mec, { X = a.X, Y = a.Y, Z = a.Z + h }, { X = b.X, Y = b.Y, Z = b.Z + h })
    end
    function ctx.wake(P, why) if valid(P) then env.wake(P, why or "event") end end

    -- messages
    function ctx.all(what, ...) ctx.to(nil, what, ...) end
    function ctx.to(who, what, ...)
        if ctx.over then return end
        if EV.RESERVED[what] or what == "on" or what == "off" or what == "tick" then
            return warn(ctx, "message réservé : " .. tostring(what))
        end
        local args = table.pack(...)
        local out = {}
        for i = 1, args.n do out[i] = ascii(args[i]) end
        put(who, "EV", ctx.id, ascii(what), table.unpack(out, 1, args.n))
    end
    function ctx.to_dead(what, ...) ctx.to("dead", what, ...) end
    function ctx.to_living(what, ...) ctx.to("living", what, ...) end
    function ctx.say(who, key, ...)
        if ctx.over then return end
        local spec = M.TEXT and M.TEXT[key]
        if not spec then return warn(ctx, "bandeau inconnu : " .. tostring(key)) end
        put(who, "EV", ctx.id, "say", key, wired(spec, ...))
    end
    function ctx.notice(who, key, ...)
        if ctx.over then return end
        local spec = M.TEXT and M.TEXT[key]
        if not spec then return warn(ctx, "avis inconnu : " .. tostring(key)) end
        put(who, "EV", ctx.id, "note", key, wired(spec, ...))
    end
    function ctx.sfx(P, kind)
        if not ctx.over then put(P, "EV", ctx.id, "sfx", kind == "fail" and "fail" or "ok") end
    end
    function ctx.line(who, key, secs, ...)
        if ctx.over then return end
        local rec = nil
        if key ~= nil then
            local spec = M.LINES and M.LINES[key]
            if not spec then return warn(ctx, "ligne inconnue : " .. tostring(key)) end
            rec = { key = key, ends = (secs and secs > 0) and (U.now() + secs) or nil, args = table.pack(wired(spec, ...)) }
        end
        local L, t = priv.lines, U.now()
        if who == nil then
            L.all, L.dead, L.living, L.per = rec, nil, nil, {}
            put(nil, "EVLINE", line_msg(ctx, rec, t))
            return
        end
        if who == "dead" or who == "living" then
            -- a player's own line stays until the module takes it off (ctx.line(P, nil)): only a
            -- line to everyone replaces it
            L[who] = rec
            for _, P in ipairs(targets(who)) do
                if L.per[P.key] == nil then put(P, "EVLINE", line_msg(ctx, line_of(ctx, P), t)) end
            end
            return
        end
        for _, P in ipairs(targets(who)) do
            if valid(P) then
                L.per[P.key] = rec
                put(P, "EVLINE", line_msg(ctx, line_of(ctx, P), t))
            end
        end
    end
    function ctx.key(P, act, use)
        if ctx.over or not valid(P) then return end
        priv.routes[P.key] = (act or use) and { act = act == true, use = use == true } or nil
        put(P, "EVKEY", act and 1 or 0, use and 1 or 0)
    end
    function ctx.recap(kind, a, b)
        local spec = M.RECAP and M.RECAP[kind]
        if not spec then return warn(ctx, "récapitulatif inconnu : " .. tostring(kind)) end
        local function n(v)
            if type(v) == "table" and v.mec then return ctx.idx(v) end
            return U.round(tonumber(v) or -1)
        end
        RC.add(kind, n(a), n(b))
    end

    -- marks, lights, sounds, sirens (on the machines; EVOFF takes them back)
    function ctx.mark(slot, pos, color, walls, shape, who)
        if ctx.over or not EV.MARK_SLOTS[slot] or not pos then return warn(ctx, "marque refusée : " .. tostring(slot)) end
        local m = { slot = slot, who = who, pos = U.vec_copy(pos), color = color, walls = walls == true, shape = shape or "col" }
        priv.marks[slot] = m
        put(who, "EVMARK", mark_args(m, true))
        return handle(ctx, function() ctx.unmark(slot) end, true)
    end
    function ctx.mark_item(slot, rec, color, walls, who, shape)
        if ctx.over or not EV.MARK_SLOTS[slot] or not rec then return warn(ctx, "marque refusée : " .. tostring(slot)) end
        local m = { slot = slot, who = who, rec = rec, color = color, walls = walls == true, shape = shape or "both" }
        priv.marks[slot] = m
        check_item_mark(ctx, m, U.now())
        return handle(ctx, function() ctx.unmark(slot) end, true)
    end
    function ctx.unmark(slot)
        local m = priv.marks[slot]
        priv.marks[slot] = nil
        if m and not ctx.over then put(nil, "EVMARK", mark_args(m, false)) end
    end
    function ctx.glow(slot, P, color, radius, pulse, intensity)
        if ctx.over or not valid(P) or not free_slot(ctx, slot, "lights") then return nil end
        -- the machines draw the pulse at each tick (ten times a second): a shorter beat would be
        -- caught at the same point of its wave every time, a steady light or an odd flicker
        pulse = pulse or 0
        if pulse > 0 and pulse < EV.MIN_PULSE then pulse = EV.MIN_PULSE end
        put(nil, "EVGLOW", slot, 1, env.idx(P), ascii(color or "white"), U.round(radius or 300), U.round(pulse * 10),
            U.round(intensity or 5000))
        return handle(ctx, function() ctx.glow_off(slot) end, true)
    end
    function ctx.glow_off(slot)
        priv.slots.lights[slot] = nil
        if not ctx.over then put(nil, "EVGLOW", slot, 0) end
    end
    function ctx.light_at(slot, pos, color, radius, intensity, who)
        if ctx.over or not pos or not free_slot(ctx, slot, "lights") then return nil end
        put(who, "EVLIGHT", slot, 1, U.round(pos.X), U.round(pos.Y), U.round(pos.Z), ascii(color or "white"),
            U.round(radius or 300), U.round(intensity or 5000))
        return handle(ctx, function() ctx.light_off(slot) end, true)
    end
    function ctx.light_off(slot)
        priv.slots.lights[slot] = nil
        if not ctx.over then put(nil, "EVLIGHT", slot, 0) end
    end
    function ctx.sound(slot, name, at, opts)
        if ctx.over or (type(at) == "table" and at.key ~= nil and not valid(at)) then return nil end
        if not free_slot(ctx, slot, "sounds") then return nil end
        opts = opts or {}
        local mode, idx, pos = "flat", -1, U.vec()
        if type(at) == "table" and at.key ~= nil then
            mode, idx = "on", env.idx(at)
        elseif type(at) == "table" and at.X ~= nil then
            mode, pos = "spot", at
        end
        if opts.mode == "flat" then mode = "flat" end
        local period = opts.period or 0
        if period > 0 and period < 0.1 then period = 0.1 end
        put(opts.who, "EVSND", slot, ascii(name), mode, idx, U.round(pos.X), U.round(pos.Y), U.round(pos.Z),
            U.round(opts.inner or 300), U.round(opts.falloff or 1800), U.round(period * 10))
        return handle(ctx, function() ctx.sound_off(slot) end, true)
    end
    function ctx.sound_off(slot)
        priv.slots.sounds[slot] = nil
        if not ctx.over then put(nil, "EVSND", slot, "-") end
    end
    function ctx.siren(slot, alarm, on_s, off_s, total_s, who)
        if ctx.over then return nil end
        -- the box first: a slot taken for a box that is not there would never be given back
        local at = nil
        if type(alarm) == "table" then at = alarm.at or G.location(alarm.actor) else at = G.location(alarm) end
        if not at then return warn(ctx, "sirène sans boîtier") end
        if not free_slot(ctx, slot, "sirens") then return nil end
        put(who, "EVSIREN", slot, 1, U.round(at.X), U.round(at.Y), U.round(at.Z), U.round((on_s or 1) * 10),
            U.round((off_s or 0) * 10), U.round((total_s or 10) * 10))
        return handle(ctx, function() ctx.siren_off(slot) end, true)
    end
    function ctx.siren_off(slot)
        priv.slots.sirens[slot] = nil
        if not ctx.over then put(nil, "EVSIREN", slot, 0) end
    end
    function ctx.cameras_off(who)
        if ctx.over then return nil end
        put(who, "EVCAM", 0)
        return handle(ctx, function() if not ctx.over then put(who, "EVCAM", 1) end end, true)
    end

    -- machines, radios, clock (the game's state, on the host)
    function ctx.lock_slots(set, keep)
        if ctx.over then return nil end
        local hold = W.lock_slots(set, keep)
        return handle(ctx, function() W.unlock_slots(hold) end, false, "locks")
    end
    function ctx.unlock_slots()
        for _, h in ipairs(priv.locks) do undo(ctx, h) end
    end
    function ctx.radios_pause()
        if ctx.over then return nil end
        local hold = { paused = {} }
        priv.radio_hold = hold
        for _, a in ipairs(W.radios_playing()) do
            U.tcall(a, "Pause Song")
            hold.paused[a:GetAddress()] = a
        end
        return handle(ctx, function(reason)
            if priv.radio_hold == hold then priv.radio_hold = nil end
            if reason == "end" then return end              -- nothing started again at the end of a game
            for _, a in pairs(hold.paused) do
                -- only a radio nobody touched meanwhile: still "playing" (4), its cassette in
                local slot = U.get(a, "Music", nil)
                if U.valid(a) and U.get(a, "State", 0) == 4 and U.valid(slot) and U.get(slot, "Item In", false) == true then
                    U.tcall(a, "Start Song")
                end
            end
        end, false)
    end
    function ctx.freeze_clock(on)
        if on == false then
            for _, h in ipairs(priv.clocks) do undo(ctx, h) end
            return nil
        end
        if ctx.over or not W.freeze_clock() then return nil end
        return handle(ctx, function() W.release_clock() end, false, "clocks")
    end
    function ctx.add_time(secs, floor) return W.add_time(secs or 0, floor) end
    function ctx.clock() return W.clock() end

    -- players' bodies
    function ctx.truce(P, secs)
        if ctx.over or not valid(P) then return nil end
        B.truce(P, secs or 1)
        local h = handle(ctx, function() B.truce_end(P) end, false, "truces", P.key)
        ctx.at(secs or 1, function() undo(ctx, h) end)
        return h
    end
    function ctx.truce_off(P)
        for key, list in pairs(priv.truces) do
            if P == nil or key == P.key then
                for _, h in ipairs(list) do undo(ctx, h) end
            end
        end
    end
    function ctx.freeze(P, secs, opts)
        if ctx.over or not valid(P) then return nil end
        opts = opts or {}
        local move, act = opts.move ~= false, opts.act ~= false
        -- B counts the freezes on each player: the end of one leaves the others in place
        local f = B.freeze(P, secs or 1, move, act)
        local h = handle(ctx, function() B.unfreeze(P, f) end, false, "freezes", P.key)
        ctx.at((secs or 1) + 0.1, function() undo(ctx, h) end)
        return h
    end
    function ctx.unfreeze(P)
        for _, h in ipairs((P and priv.freezes[P.key]) or {}) do undo(ctx, h) end
    end
    function ctx.exhaust(P) if not ctx.over and valid(P) and G.is_alive(P.mec) then B.exhaust(P) end end
    function ctx.tire(P, n, hold) if not ctx.over and valid(P) and G.is_alive(P.mec) then B.tire(P, n, hold) end end
    function ctx.push(P, yaw, strength) if not ctx.over and valid(P) and G.is_alive(P.mec) then B.push(P, yaw, strength) end end
    function ctx.halt(P) if not ctx.over and valid(P) and G.is_alive(P.mec) then B.halt(P) end end
    function ctx.drop(P) if not ctx.over and valid(P) and G.is_alive(P.mec) then B.drop(P) end end
    function ctx.search(P)
        if ctx.over or not valid(P) then return {} end
        return B.search(P)
    end
    function ctx.take(P, where_)
        if ctx.over or not valid(P) then return nil end
        return W.take(P.mec, where_)
    end
    function ctx.held(P)
        local out = {}
        if not valid(P) then return out end
        for _, w in ipairs({ { "hand", G.hand_item_data }, { "bag", G.bag_item_data } }) do
            local data, value, time = w[2](P.mec)
            if data then out[w[1]] = { data = data, name = W.data_name(data), value = value, time = time } end
        end
        return out
    end
    function ctx.blast(at, range, hp, opts)
        if ctx.over or not at then return {} end
        opts = opts or {}
        local skip = {}
        for _, Q in ipairs(opts.skip or {}) do skip[Q.key] = true end
        local victims, hit = {}, {}
        local reach = opts.lethal and (range + 200) or range
        env.each_player(function(P)
            if skip[P.key] or not present(P) then return end
            local p = where(P)
            if not p then return end
            local d = U.dist(at, { X = p.X, Y = p.Y, Z = p.Z + 140 })
            if d <= reach then
                victims[#victims + 1] = { P = P, d = d, at = p }
                hit[#hit + 1] = P
                if opts.cause then B.cause(P, opts.cause, 3) end
            end
        end)
        B.blast(at, range, hp, opts, victims)
        return hit
    end
    function ctx.hurt(P, hp, opts)
        if ctx.over or not valid(P) or not G.is_alive(P.mec) then return end
        opts = opts or {}
        if opts.cause then B.cause(P, opts.cause, 3) end
        B.hurt(P, hp, opts)
    end
    function ctx.tint(P, color, opts)
        if ctx.over then return nil end
        local list = (P == nil) and game_players() or { P }
        for _, Q in ipairs(list) do
            if valid(Q) then
                B.tint(Q, color, opts and opts.pulse)
                priv.tints[Q.key] = color ~= nil or nil
            end
        end
        if color == nil then return nil end
        return handle(ctx, function()
            if ctx.over then return end
            for _, Q in ipairs(list) do if valid(Q) then B.tint(Q, nil) end end
        end, true)
    end
    function ctx.flash(P, color, aberration)
        if not ctx.over and valid(P) then B.flash(P, color, aberration) end
    end
    function ctx.cause(P, cause, secs)
        if not valid(P) then return false end
        return B.cause(P, cause, secs)
    end
    function ctx.kill(P, cause, opts)
        if not valid(P) then return false end
        return B.kill(P, cause, opts)
    end
    function ctx.game_explosion(at, kind) return B.game_explosion(at, kind) end

    -- items
    function ctx.place(what, opts)
        if ctx.over then return nil end
        local rec = W.place(what, opts)
        if rec and not rec.keep then
            handle(ctx, function() W.remove(rec, env.each_player) end, false)
        end
        return rec
    end
    function ctx.track(rec) return W.track(rec, env.each_player, U.now()) end
    function ctx.remove(rec) return W.remove(rec, env.each_player) end

    -- the end of the game, with a winner ("employees", "dissidents", or "none": the end the host's
    -- own stop gives, with no winner) and the title each player reads on the end screen: a kind of
    -- S.END_TITLE for all, or { won = kind, lost = kind } (the winners: the winning side; for
    -- "employees", every player who is not a dissident, neutral ones included). The event stops
    -- at once (reason "end"); the game ends `delay` seconds later (3), if it is still on.
    function ctx.end_game(winner, titles, delay)
        local game = env.game
        if game.ending then return false end
        game.ending = true
        local started = game.started_at
        U.after(delay or 3, "fin de partie (évènement)", function()
            local gm = G.gm()
            if not (gm and game.active and game.started_at == started and U.get(gm, "In Game", false)) then return end
            if titles then
                for _, P in ipairs(game_players()) do
                    local kind = titles
                    if type(titles) == "table" then
                        local won = winner ~= "none" and ((winner == "employees") == (camp_of(P) ~= "dissident"))
                        kind = won and titles.won or titles.lost
                    end
                    if kind then env.tell(P, "ENDTITLE", kind) end
                end
            end
            U.log("Évènement %s : fin de la partie (%s)", ctx.id, tostring(winner))
            if winner == "none" then
                U.tcall(gm, "End Game", false, true)
            else
                U.tcall(gm, "End Game", winner == "employees", false)
            end
        end)
        return true
    end

    return ctx
end

-- ---------------------------------------------------------------- host: starting and stopping
-- A stop's reason as it travels in EVOFF: a short word [a-z0-9_] (a module's own reason with an
-- accent or a "|" would break the message), "done" for anything else.
local function reason_word(reason)
    if type(reason) == "string" and #reason <= 24 and reason:match("^[a-z0-9_]+$") then return reason end
    return "done"
end

stop_run = function(ctx, reason)
    if ctx.over or ctx._.stopping then return end
    ctx._.stopping = true
    reason = reason_word(reason)          -- the same word for M.stop, the undos, every machine and the log
    local M = ctx.M
    if M.stop then U.try("évènement " .. ctx.id .. " : arrêt", M.stop, ctx, reason) end
    ctx.over = true
    undo_all(ctx, reason)
    deliver(nil, "EVOFF", ctx.id, reason)
    if run == ctx then run = nil end
    sched.last = ctx.id
    if not ctx.test then sched.done[ctx.id] = true end
    sched.next_at = U.now() + C.get("event_interval") * (0.75 + 0.5 * math.random())
    U.log("Évènement %s terminé (%s, %d s)", ctx.id, tostring(reason), math.floor(U.now() - ctx.started))
end

-- Tries to start an event. Returns true, or false and the module's reason (a key of its M.TEXT).
local function try_start(M, now, test)
    local ctx = new_ctx(M, now, test)
    if M.can_start then
        local res = table.pack(pcall(M.can_start, ctx, now, test == true))
        if not res[1] then
            U.log("ERREUR dans évènement %s : can_start : %s", M.id, tostring(res[2]))
            ctx.over = true
            return false
        end
        if res[2] ~= true then
            ctx.over = true
            return false, res[3]
        end
    end
    run = ctx
    ctx._.queue, ctx._.starting = {}, true
    local ok, planned = pcall(M.start, ctx, now, test == true)
    local queue = ctx._.queue
    ctx._.queue, ctx._.starting = nil, false
    if not ok or planned == false or planned == nil then
        if not ok then U.log("ERREUR dans évènement %s : départ : %s", M.id, tostring(planned)) end
        -- could not after all: what it began is taken back, and nobody hears of it
        ctx.over = true
        undo_all(ctx, "done")
        if run == ctx then run = nil end
        return false
    end
    planned = math.max(0, tonumber(planned) or 0)
    ctx.planned = planned
    ctx.ends = now + planned
    ctx.hard_end = now + planned + (planned > 0 and 15 or 5)
    deliver(nil, "EVON", M.id, U.round(planned))
    for _, m in ipairs(queue) do deliver(m.who, m.cmd, table.unpack(m.args, 1, m.args.n)) end
    U.log("Évènement %s commencé (%d s prévues%s)", M.id, U.round(planned), test and ", essai de l'hôte" or "")
    if ctx._.finish then stop_run(ctx, ctx._.finish) end
    return true
end

-- What the scheduler counts among the players of the game.
local function counts(now)
    local c = { living = 0, present = 0, dead = 0, dissidents = 0, employees = 0 }
    for _, P in ipairs(game_players()) do
        if G.is_alive(P.mec) then
            c.living = c.living + 1
            if present(P, now) then c.present = c.present + 1 end
            local camp = camp_of(P)
            if camp == "dissident" then c.dissidents = c.dissidents + 1 end
            if camp == "employee" then c.employees = c.employees + 1 end
        else
            c.dead = c.dead + 1
        end
    end
    return c
end

-- The conditions every module declares (skipped by TEST). window: also out of an only_last
-- event's window.
local function eligible(M, c, now, clock, out_of_window)
    if M.once and sched.done[M.id] then return false end
    if c.living < (M.min_living or 0) or c.present < (M.min_present or 0) then return false end
    if now - sched.started < (M.not_before or 0) then return false end
    if M.only_last then
        if not out_of_window and clock > (C.get(M.only_last) or 0) then return false end
    elseif clock < 60 or (M.not_last and clock <= M.not_last) then
        return false
    end
    if M.needs_dead and c.dead < 1 then return false end
    if M.needs_dissident and c.dissidents < 1 then return false end
    if c.employees < (M.min_employees or 0) then return false end
    return true
end

-- The candidates in a random order weighed by M.weight; the last event goes last (it comes
-- again only when none of the others can).
local function draw_order(list)
    local pool, out = {}, {}
    for _, M in ipairs(list) do pool[#pool + 1] = M end
    while #pool > 0 do
        local total = 0
        for _, M in ipairs(pool) do total = total + math.max(0.01, M.weight or 1) end
        local x, pick = math.random() * total, #pool
        for i, M in ipairs(pool) do
            x = x - math.max(0.01, M.weight or 1)
            if x <= 0 then
                pick = i
                break
            end
        end
        out[#out + 1] = table.remove(pool, pick)
    end
    for i, M in ipairs(out) do
        if M.id == sched.last and i < #out then
            table.remove(out, i)
            out[#out + 1] = M
            break
        end
    end
    return out
end

local function schedule(now)
    sched.next_at = sched.next_at or (sched.started + C.get("event_first_delay"))
    local clock = W.clock()
    local c = counts(now)
    -- An event kept for the last moments (the shuttle), switched on and able to come: from
    -- EV.RESERVE s before its window nothing else starts, and it comes first as soon as the window
    -- opens, whatever the pause. If it cannot start then, the others may (as usual). Never before
    -- the first delay, nor while the clock reads 0 (not started yet, or already run out: a short
    -- game must not open with the shuttle).
    local reserved = nil
    if now >= sched.started + C.get("event_first_delay") and clock > 0 then
        for _, id in ipairs(EV.IDS) do
            local M = EV.mods[id]
            if not reserved and M and M.only_last and C.get(M.switch) and eligible(M, c, now, clock, true)
                    and clock <= (C.get(M.only_last) or 0) + EV.RESERVE then
                reserved = M
            end
        end
    end
    if reserved then
        if clock > (C.get(reserved.only_last) or 0) then return end
        if now >= sched.reserve_at then
            sched.reserve_at = now + 5
            if try_start(reserved, now, false) then return end
        end
    end
    if now < sched.next_at then return end
    local list = {}
    for _, id in ipairs(EV.IDS) do
        local M = EV.mods[id]
        if M and M ~= reserved and C.get(M.switch) and eligible(M, c, now, clock, false) then list[#list + 1] = M end
    end
    for _, M in ipairs(draw_order(list)) do
        if try_start(M, now, false) then return end
    end
    sched.next_at = now + 10                    -- none could: tried again a little later
end

-- ---------------------------------------------------------------- host: entry points
-- e: each_player, tell, broadcast, idx, game, by_key, player(mec, create), aimed(P, cm), wake(P, why)
function EV.setup(e)
    env = e
    -- what lpr_ev_body.lua says goes the way the events' messages go (after "EVON" when it starts)
    B.setup({ tell = function(P, ...) put(P, ...) end, broadcast = function(...) put(nil, ...) end,
              wake = e.wake, game = e.game })
    EV.load()
    U.hook(W.PATH_SLOT .. ":Lock", function(hc)
        if G.is_host() then W.on_slot_lock(hc:get()) end
    end)
    U.hook(G.PATH_MEC .. ":Net Pick Item", function(hc)
        local P = env.player(hc:get(), false)
        if P then EV.on_pick(P) end
    end)
    U.hook(G.PATH_MEC .. ":Net Melee", function(hc)
        local P = env.player(hc:get(), false)
        if P then EV.on_attack(P, "melee") end
    end)
    U.hook(G.PATH_MEC .. ":Net Gun Fire", function(hc)
        local P = env.player(hc:get(), false)
        if P then EV.on_attack(P, "gun") end
    end)
end

-- A game starts (when it started): nothing kept from the one before.
function EV.start(t)
    if run then stop_run(run, "end") end
    sched = { done = {}, last = nil, next_at = nil, started = t or U.now(), reserve_at = 0 }
    W.reset()
    W.release_all()
    B.reset_holds()
end

-- The running event stops (reason: "end" for the end of the game, by default).
function EV.stop(reason)
    if run then stop_run(run, reason or "end") end
end

-- Host's tick, ten times a second, once the roles are announced.
function EV.tick(now)
    if not env then return end
    W.tick_clock()
    local game = env.game
    local ctx = run
    if ctx then
        local M = ctx.M
        -- a run started from TEST ignores the events' switches (the shuttle is off by default and
        -- must still be testable): only the mod's own switch and the end of the game stop it
        local switched_off = not C.get("enabled")
            or (not ctx.test and not (C.get("events_on") and C.get(M.switch)))
        if game.ending or switched_off then
            return stop_run(ctx, game.ending and "end" or "off")
        end
        if ctx.planned == 0 then return stop_run(ctx, "done") end
        local hold = ctx._.radio_hold
        if hold and now - (ctx._.radio_at or 0) >= 0.5 then
            ctx._.radio_at = now
            for _, a in ipairs(W.radios_playing()) do          -- somebody pressed "play": paused again
                U.tcall(a, "Pause Song")
                hold.paused[a:GetAddress()] = a
            end
        end
        for _, m in pairs(ctx._.marks) do
            if m.rec and now - (m.checked or 0) >= 0.5 then check_item_mark(ctx, m, now) end
        end
        if M.tick then U.try("évènement " .. ctx.id, M.tick, ctx, now) end
        if not ctx.over and now >= ctx.hard_end then stop_run(ctx, "timeout") end
        return
    end
    if not (C.get("enabled") and C.get("events_on")) or game.ending or not game.active then return end
    schedule(now)
end

-- The id of the running event, or nil.
function EV.running()
    return run and run.id or nil
end

-- Deaths and raises (lpr_server.lua): the dead's freeze is let go, lines and marks of the dead
-- and of the living follow, then the module hears of it.
function EV.on_death(P)
    local ctx = run
    if not ctx or ctx.over then return end
    for _, h in ipairs(ctx._.freezes[P.key] or {}) do undo(ctx, h) end
    refresh_audiences(ctx, P)
    if ctx.M.on_death then U.try("évènement " .. ctx.id .. " : mort", ctx.M.on_death, ctx, P) end
end

function EV.on_rez(P)
    local ctx = run
    if not ctx or ctx.over then return end
    refresh_audiences(ctx, P)
    if ctx.M.on_rez then U.try("évènement " .. ctx.id .. " : relève", ctx.M.on_rez, ctx, P) end
end

-- A hit A gave V ("Net Deal Damage"), a blow or a shot by P ("Net Melee", "Net Gun Fire"), an
-- item P picked up ("Net Pick Item", or the Voleur's theft).
function EV.on_hit(A, V)
    local ctx = run
    if ctx and not ctx.over and ctx.M.on_hit then U.try("évènement " .. ctx.id .. " : coup", ctx.M.on_hit, ctx, A, V) end
end

function EV.on_attack(P, kind)
    local ctx = run
    if ctx and not ctx.over and ctx.M.on_attack then
        U.try("évènement " .. ctx.id .. " : attaque", ctx.M.on_attack, ctx, P, kind)
    end
end

function EV.on_pick(P)
    local ctx = run
    if ctx and not ctx.over and ctx.M.on_pick then U.try("évènement " .. ctx.id .. " : ramassage", ctx.M.on_pick, ctx, P) end
end

-- A player pressed the power key ("act") or the "consume" key ("use"). True when the running
-- event took it (the role's own power is then not run): only while the event routes that key of
-- that player (ctx.key). A press within 0.3 s of one the event took is taken too, and nothing
-- more (a vote, a seat: never twice for one gesture); one the event gave back to the role leaves
-- the next press free (the shuttle routes everyone's key for its whole wait: a quick double
-- press elsewhere is the role's own business). A player whose eyes the Hypnotiseur holds shut
-- can no more use an event's key than a power.
function EV.on_key(P, kind)
    local ctx = run
    if not ctx or ctx.over or not P then return false end
    local r = ctx._.routes[P.key]
    if not (r and r[kind]) then return false end
    local now = U.now()
    local k = P.key .. kind
    local last = ctx._.pressed[k]
    if last and last.taken and now - last.at < 0.3 then return true end
    local taken
    if P.hypno_until and now < P.hypno_until then
        env.tell(P, "SFX", "fail")
        taken = true
    elseif not ctx.M.on_key then
        taken = false
    else
        taken = U.try("évènement " .. ctx.id .. " : touche", ctx.M.on_key, ctx, P, kind) == true
    end
    ctx._.pressed[k] = { at = now, taken = taken }
    return taken
end

-- TEST group: kind = an event's id (started at once, without its conditions and without
-- counting as its one time in the game, any event running being stopped first) or "stop".
function EV.test(kind, now)
    if not env then return end
    local mine = G.local_mec()
    local me = mine and env.player(mine, false)
    local function say(id) if me then env.tell(me, "MSG", id) end end
    local game = env.game
    if not (game.active and game.announced) then
        say("TEST_EVENT_NO")
        U.log("Test : évènement %s refusé (pas de partie en cours)", tostring(kind))
        return
    end
    if kind == "stop" then
        if run then
            stop_run(run, "test")
            say("TEST_EVENT_STOP")
        else
            say("TEST_EVENT_IDLE")
        end
        return
    end
    local M = EV.mods[kind]
    if not M then
        say("TEST_EVENT_MISSING")
        U.log("Test : évènement %s absent (module non chargé)", tostring(kind))
        return
    end
    if run then stop_run(run, "test") end
    local ok, why = try_start(M, now or U.now(), true)
    if ok then return end
    if why and M.TEXT and M.TEXT[why] and me then
        env.tell(me, "EV", M.id, "say", why)          -- the module's own reason
    else
        say("TEST_EVENT_NONE")
    end
    U.log("Test : évènement %s impossible maintenant (%s)", kind, tostring(why or "refusé"))
end

-- ---------------------------------------------------------------- every machine
local function is_ghost()
    return CL.ghost ~= nil and CL.ghost() ~= nil
end

-- A text of a module written out ("note": a notice, names cut).
local function text_of(spec, args, width)
    if not spec then return nil end
    local kinds = {}
    for i = 2, #spec do kinds[#kinds + 1] = spec[i] end
    return RC.write(spec[1], kinds, args, false, width)
end

local function show(M, key, args, notice)
    local spec = M.TEXT and M.TEXT[key]
    if not spec then return end
    local text = text_of(spec, args, notice and EV.NOTICE_NAME or nil)
    local color = S.COLOR[spec.c or "role"] or S.COLOR.role
    if notice then G.notice(text, color) else G.say(text, color) end
end

-- What a module sees on this machine.
local function new_cx(M)
    local cx = { id = M.id, M = M, run = {} }
    function cx.now() return U.now() end
    function cx.me() return G.local_mec() end
    function cx.my_idx()
        local me = G.local_mec()
        return me and G.player_index(me) or -1
    end
    function cx.is_me(idx) return cx.my_idx() == tonumber(idx) end
    function cx.mec(idx) return G.mec_by_index(tonumber(idx) or -1) end
    function cx.name(idx) return RC.name_of(tonumber(idx) or -1) end
    function cx.fmt(key, ...) return text_of(M.TEXT and M.TEXT[key], { ... }) end
    function cx.say(key, ...) show(M, key, { ... }, false) end
    function cx.notice(key, ...) show(M, key, { ... }, true) end
    function cx.ghost() return is_ghost() end
    function cx.light(slot, idx, color, radius, intensity)
        local mec = cx.mec(idx)
        if not mec or (G.is_local(mec) and is_ghost()) then return false end
        CL.dirty = true
        return K.light(slot, mec, color, radius, intensity)
    end
    function cx.light_at(slot, x, y, z, color, radius, intensity)
        CL.dirty = true
        return K.light_at(slot, x, y, z, color, radius, intensity)
    end
    function cx.light_off(slot) K.light_off(slot) end
    function cx.mark(slot, on, x, y, z, color, walls, shape)
        if not EV.MARK_SLOTS[slot] then return 0 end
        CL.dirty = true
        return K.mark(slot, on ~= false, x, y, z, color, walls == true, shape)
    end
    function cx.sound(slot, name, how)
        CL.dirty = true
        return A.slot_play("m" .. tostring(slot), name, how)
    end
    function cx.sound_off(slot) A.slot_stop("m" .. tostring(slot)) end
    function cx.tint(rgb, pulse)
        CL.dirty = true
        B.local_tint(rgb, pulse)
    end
    -- the game's own sounds: an asset (or its path) at a spot with one of the game's attenuations;
    -- or a SoundBase heard as it is, from `start` seconds (returns the engine's AudioComponent:
    -- Stop() ends it; check it with U.valid, the engine destroys it once over)
    function cx.game_sound_at(asset, at, attenuation) return A.game_sound_at(asset, at, attenuation) end
    function cx.game_sound_2d(sound, volume, start) return A.game_sound_2d(sound, volume, start) end
    function cx.set_line(text, secs)
        CL.dirty = true
        T.event_line(text, (secs and secs > 0) and (U.now() + secs) or nil)
    end
    function cx.log(fmt, ...)
        local ok, msg = pcall(string.format, fmt, ...)
        U.log("Évènement %s : %s", M.id, ok and msg or tostring(fmt))
    end
    return cx
end

local function call(M, cx, what, ...)
    local fn = M.client and M.client[what]
    if type(fn) == "function" then U.try("évènement " .. M.id .. " : " .. what, fn, cx, ...) end
end

-- Everything an event showed on this machine taken back: marks, lights, sounds, sirens, camera
-- screens, a freeze, a veil, the tablet line, the keys; and the module told ("off").
function EV.client_reset(reason)
    local M, cx = CL.M, CL.cx
    CL.id, CL.M, CL.cx = nil, nil, nil
    if M and cx then call(M, cx, "off", reason or "end") end
    CL.keys.act, CL.keys.use = false, false
    if not CL.dirty then return end
    CL.dirty = false
    K.events_off()
    A.slots_clear()
    for slot, s in pairs(CL.sirens) do
        CL.sirens[slot] = nil
        if U.valid(s.alarm) then W.siren(s.alarm, false) end
    end
    CL.sounds, CL.glows = {}, {}
    if CL.cams then
        CL.cams = false
        W.cameras(true)
    end
    B.client_reset()
    T.event_line(nil)
end

-- This machine's part of the event `id`, made when it first hears of it.
local function attach(id, secs)
    local M = EV.mods[id]
    if not M then return nil end
    if CL.id ~= id then
        if CL.id then EV.client_reset("new") end
        CL.id, CL.M, CL.cx = id, M, new_cx(M)
        CL.dirty = true
        for _, name in ipairs(M.SOUNDS or {}) do A.prepare(name) end
        call(M, CL.cx, "on", secs or -1)
    end
    return CL.cx
end

local function on_evon(id, secs)
    if CL.id then EV.client_reset("new") end
    attach(id, tonumber(secs) or -1)
end

local function on_evoff(id, reason)
    if CL.id == nil or CL.id == id then EV.client_reset(reason or "done") end
end

local function on_ev(id, what, ...)
    local M = EV.mods[id]
    if not M then return end
    if what == "say" or what == "note" then
        local args = table.pack(...)
        show(M, args[1], { table.unpack(args, 2, args.n) }, what == "note")
        return
    end
    if what == "sfx" then
        A.power_sfx((...) == "fail" and "fail" or "ok")
        return
    end
    local cx = attach(id)
    if cx then call(M, cx, what, ...) end
end

local function on_key(act, use)
    CL.keys.act, CL.keys.use = act == "1", use == "1"
    CL.dirty = true
end

local function on_line(id, key, tenths, ...)
    if key == nil or key == "-" then
        T.event_line(nil)
        return
    end
    local M = EV.mods[id]
    local spec = M and M.LINES and M.LINES[key]
    if not spec then return end
    local t = tonumber(tenths) or 0
    CL.dirty = true
    T.event_line(text_of(spec, { ... }), t > 0 and (U.now() + t / 10) or nil)
end

local function on_mark(slot, on, x, y, z, color, walls, shape, item)
    if not EV.MARK_SLOTS[slot] then return end
    CL.dirty = true
    K.mark(slot, on == "1", x, y, z, color, walls == "1", shape, (item and item ~= "-") and item or nil)
end

-- A light on a player follows its character; never on this machine's own character while it is
-- a ghost of its own (a dreaming Rêveur, a flying Fée: the light would follow the ghost).
local function glow_place(slot, g)
    local mec = G.mec_by_index(g.idx)
    if mec and not (G.is_local(mec) and is_ghost()) then
        local a = mec:GetAddress()
        if g.on ~= a then g.on = K.light(slot, mec, g.color, g.radius, g.intensity) and a or false end
    elseif g.on then
        K.light_off(slot)
        g.on = false
    end
end

local function on_glow(slot, on, idx, color, radius, pulse, intensity)
    if on ~= "1" then
        CL.glows[slot] = nil
        K.light_off(slot)
        return
    end
    K.light_off(slot)
    local g = { idx = tonumber(idx) or -1, color = color, radius = tonumber(radius) or 300,
                pulse = (tonumber(pulse) or 0) / 10, intensity = tonumber(intensity) or 5000, on = false, placed = 0 }
    CL.glows[slot] = g
    CL.dirty = true
    glow_place(slot, g)
end

local function on_light(slot, on, x, y, z, color, radius, intensity)
    if on ~= "1" then
        K.light_off(slot)
        return
    end
    CL.dirty = true
    K.light_at(slot, x, y, z, color, tonumber(radius) or 300, tonumber(intensity) or 5000)
end

local function play_slot(slot, s)
    local how = { mode = "flat" }
    if s.mode == "on" then
        local mec = G.mec_by_index(s.idx)
        if not mec then return end
        if not G.is_local(mec) then how = { mode = "around", mec = mec, inner = s.inner, falloff = s.falloff } end
    elseif s.mode == "spot" then
        how = { mode = "spot", spot = s.spot, inner = s.inner, falloff = s.falloff }
    end
    A.slot_play(slot, s.name, how)
end

local function on_sound(slot, name, mode, idx, x, y, z, inner, falloff, period)
    if name == nil or name == "-" then
        CL.sounds[slot] = nil
        A.slot_stop(slot)
        return
    end
    local s = { name = name, mode = mode, idx = tonumber(idx) or -1,
                spot = U.vec(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0),
                inner = tonumber(inner) or 300, falloff = tonumber(falloff) or 1800, period = (tonumber(period) or 0) / 10 }
    CL.dirty = true
    play_slot(slot, s)
    if s.period > 0 then
        s.next = U.now() + s.period
        CL.sounds[slot] = s
    else
        CL.sounds[slot] = nil
    end
end

-- A box's siren on this machine: `on` seconds of sound, `off` seconds of silence (0: always on,
-- sounded again every 5 s), for `total` seconds.
local function siren_stop(slot)
    local s = CL.sirens[slot]
    CL.sirens[slot] = nil
    if s and U.valid(s.alarm) then W.siren(s.alarm, false) end
end

local function siren_step(slot, s, now)
    if now >= s.ends then return siren_stop(slot) end
    if not U.valid(s.alarm) then
        if now < (s.find_at or 0) then return end
        s.find_at = now + 1
        s.alarm = W.find_near("AlarmButton_C", s.at, 300)
        if not s.alarm then return end
    end
    if now < s.next then return end
    if s.phase ~= "on" or s.off <= 0 then
        W.siren(s.alarm, true)
        s.phase = "on"
        s.next = now + ((s.off <= 0) and 5 or s.on)
    else
        W.siren(s.alarm, false)
        s.phase = "off"
        s.next = now + s.off
    end
end

local function on_siren(slot, on, x, y, z, on_t, off_t, total_t)
    if on ~= "1" then return siren_stop(slot) end
    siren_stop(slot)
    local now = U.now()
    local s = { at = U.vec(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0), on = (tonumber(on_t) or 10) / 10,
                off = (tonumber(off_t) or 0) / 10, ends = now + (tonumber(total_t) or 100) / 10, next = now, phase = "off" }
    CL.sirens[slot] = s
    CL.dirty = true
    siren_step(slot, s, now)
end

local function on_cam(on)
    CL.dirty = true
    CL.cams = on ~= "1"
    W.cameras(on == "1")
end

local function client_tick(now)
    local M, cx = CL.M, CL.cx
    if M and cx then call(M, cx, "tick", now) end
    if not CL.dirty then return end
    for slot, g in pairs(CL.glows) do
        if now - g.placed >= 0.5 then
            g.placed = now
            glow_place(slot, g)
        end
        if g.on and g.pulse > 0 then
            K.light_level(slot, 0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * now / g.pulse)))
        end
    end
    for slot, s in pairs(CL.sounds) do
        if now >= s.next then
            s.next = now + s.period
            play_slot(slot, s)
        end
    end
    for slot, s in pairs(CL.sirens) do siren_step(slot, s, now) end
    K.tick(now)
    B.client_tick(now)
end

-- Whether the running event wants this machine's key ("act": the power key, "use": the
-- "consume" key) sent to the host even without a role that uses it (lpr_client.lua).
function EV.key_wanted(kind)
    return CL.keys[kind] == true
end

-- e: ghost (a function: the local player's own ghost for a while, a dreaming Rêveur's or a
-- flying Fée's, or nil).
function EV.client_setup(e)
    CL.ghost = e and e.ghost or nil
    B.client_setup(is_ghost)
end

function EV.install_client()
    EV.load()
    N.on("EVON", on_evon)
    N.on("EVOFF", on_evoff)
    N.on("EV", on_ev)
    N.on("EVKEY", on_key)
    N.on("EVLINE", on_line)
    N.on("EVMARK", on_mark)
    N.on("EVGLOW", on_glow)
    N.on("EVLIGHT", on_light)
    N.on("EVSND", on_sound)
    N.on("EVSIREN", on_siren)
    N.on("EVCAM", on_cam)
    N.on("EVBODY", function(...)
        CL.dirty = true
        B.on_body(...)
    end)
    N.on("EVFX", B.on_fx)
    U.every_tick("évènement (machine)", client_tick)
end

return EV
