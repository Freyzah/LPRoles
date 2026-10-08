-- LPRoles - shared helpers (logging, safe calls, scheduler)
local U = {}

U.VERSION = "0.11.2"

-- Mod folder as a path that file functions can really open. Relative paths depend on the
-- game's working directory, so every candidate is tested by opening the mod's own main.lua.
local function mod_dir()
    local candidates = {}
    local ok, dirs = pcall(IterateGameDirectories)
    if ok and type(dirs) == "table" then
        pcall(function()
            candidates[#candidates + 1] = dirs.Game.Binaries.Win64.ue4ss.Mods.LPRoles.__absolute_path
        end)
    end
    local ok2, info = pcall(debug.getinfo, 1, "S")
    if ok2 and info and info.source then
        local src = info.source:gsub("^@", "")
        candidates[#candidates + 1] = src:match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
    end
    for _, rel in ipairs({ "ue4ss/Mods/LPRoles", "Mods/LPRoles",
                           "LockdownProtocol/Binaries/Win64/ue4ss/Mods/LPRoles",
                           "../../../LockdownProtocol/Binaries/Win64/ue4ss/Mods/LPRoles" }) do
        candidates[#candidates + 1] = rel
    end
    for _, dir in ipairs(candidates) do
        if type(dir) == "string" and dir ~= "" then
            local f = io.open(dir .. "/Scripts/main.lua", "r")
            if f then
                f:close()
                return dir
            end
        end
    end
    return "Mods/LPRoles"
end
U.MOD_DIR = mod_dir()

-- "manifest.txt", written by the installer, lists the version and the size of every script.
-- A copy gone wrong (files of two versions mixed, a file missing) is told from it: the
-- problem as a text, or nil when all is as listed.
U.install_problem = nil
function U.check_install()
    local f = io.open(U.MOD_DIR .. "/manifest.txt", "r")
    if not f then return nil end                 -- copied without it: nothing to compare with
    local bad = {}
    for line in f:lines() do
        local version = line:match("^version (%S+)")
        if version and version ~= U.VERSION then bad[#bad + 1] = "version " .. version end
        local size, name = line:match("^(%d+) (.-)%s*$")
        if size then
            local g = io.open(U.MOD_DIR .. "/" .. name, "rb")
            local real = g and g:seek("end") or -1
            if g then g:close() end
            if real ~= tonumber(size) then bad[#bad + 1] = name end
        end
    end
    f:close()
    if #bad > 0 then U.install_problem = "fichiers d'une autre version : " .. table.concat(bad, ", ") end
    return U.install_problem
end

-- The mod's own journal, kept from one launch to the next (UE4SS.log starts again at every
-- launch, which lost the trace of games played before the last one): the same lines, without
-- the detailed ones, dated. Past 300 KB it becomes "journal-ancien.txt" and a new one starts.
local JOURNAL = U.MOD_DIR .. "/journal.txt"
pcall(function()
    local f = io.open(JOURNAL, "rb")
    if not f then return end
    local size = f:seek("end")
    f:close()
    if size and size > 300 * 1024 then
        local old = U.MOD_DIR .. "/journal-ancien.txt"
        os.remove(old)
        os.rename(JOURNAL, old)
    end
end)

-- A line said again and again (an error at every tick) is written once, then counted; and a
-- session never writes more than 1 MB.
local SESSION_BYTES = 1024 * 1024
local last_line, repeats, written, warned = nil, 0, 0, false

local function write_journal(text)
    local f = io.open(JOURNAL, "a")
    if not f then
        if not warned then
            warned = true
            print("[LPRoles] journal.txt ne peut pas être écrit (" .. JOURNAL .. ")\n")
        end
        return
    end
    local line = os.date("%Y-%m-%d %H:%M:%S") .. " " .. text .. "\n"
    f:write(line)
    f:close()
    written = written + #line
end

local function journal(msg)
    if written > SESSION_BYTES then return end
    if msg == last_line then
        repeats = repeats + 1
        return
    end
    if repeats > 0 then write_journal(string.format("  (ligne précédente répétée %d fois)", repeats)) end
    last_line, repeats = msg, 0
    write_journal(msg)
    if written > SESSION_BYTES then write_journal("Journal arrêté pour cette session : trop de lignes") end
end

function U.log(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    msg = ok and msg or tostring(fmt)
    print("[LPRoles] " .. msg .. "\n")
    if msg:sub(1, 7) ~= "(debug)" then pcall(journal, msg) end
end

U.debug_enabled = false
function U.dbg(fmt, ...)
    if U.debug_enabled then U.log("(debug) " .. fmt, ...) end
end

-- Seconds since the process started (wall clock on Windows).
function U.now()
    return os.clock()
end

-- Runs fn(...) and logs any Lua error instead of propagating it.
function U.try(what, fn, ...)
    local res = table.pack(pcall(fn, ...))
    if not res[1] then
        U.log("ERREUR dans %s : %s", tostring(what), tostring(res[2]))
        return nil
    end
    return table.unpack(res, 2, res.n)
end

-- True for a live UObject wrapper.
function U.valid(obj)
    if obj == nil or type(obj) ~= "userdata" then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and v == true
end

-- Calls a UFunction by name; works for Blueprint names containing spaces.
-- Equivalent to the colon call syntax, which Lua cannot express when the name has spaces.
function U.call(obj, fname, ...)
    local f = obj[fname]
    if f == nil then error("fonction introuvable : " .. tostring(fname)) end
    return f(obj, ...)
end

-- Same as U.call but never raises; returns nil on failure.
function U.tcall(obj, fname, ...)
    if not U.valid(obj) then return nil end
    return U.try(fname, U.call, obj, fname, ...)
end

-- Reads a property, returning `default` when the object or property is unusable.
function U.get(obj, prop, default)
    if not U.valid(obj) then return default end
    local ok, v = pcall(function() return obj[prop] end)
    if not ok or v == nil then return default end
    return v
end

function U.set(obj, prop, value)
    if not U.valid(obj) then return false end
    local ok, err = pcall(function() obj[prop] = value end)
    if not ok then U.log("ERREUR en écrivant %s : %s", tostring(prop), tostring(err)) end
    return ok
end

-- Stable key for an object while it is alive.
function U.key(obj)
    local ok, a = pcall(function() return obj:GetAddress() end)
    return ok and a or nil
end

function U.split(s, sep)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
    return out
end

-- Cuts a text into lines of at most `width` characters, breaking at spaces.
function U.wrap(text, width)
    local lines, line = {}, ""
    for word in tostring(text):gmatch("%S+") do
        if line == "" then
            line = word
        elseif #line + 1 + #word <= width then
            line = line .. " " .. word
        else
            lines[#lines + 1] = line
            line = word
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

function U.shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function U.vec(x, y, z)
    return { X = x or 0.0, Y = y or 0.0, Z = z or 0.0 }
end

-- Copies an FVector-like value (struct wrapper or table) into a plain Lua table.
function U.vec_copy(v)
    local ok, t = pcall(function() return { X = v.X + 0.0, Y = v.Y + 0.0, Z = v.Z + 0.0 } end)
    return ok and t or nil
end

-- Rounds to the nearest integer. Network messages carry integers only, so that the
-- decimal separator of each machine does not matter.
function U.round(v)
    return math.floor((v or 0) + 0.5)
end

function U.dist(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- ---------------------------------------------------------------- crash guards
-- Building the LPROLES tab or the tablet page calls a lot of game code. A witness file says
-- "busy" while that is done; if the game stops in between, the file still says so at the
-- next launch and the building is skipped for that launch.
--   - Only the building is guarded: the file is written twice per build, not at every update
--     (it used to be written several times a second, and one failed write - an antivirus
--     looking at the file is enough - turned the tab and the page off for good).
--   - A write that fails is tried again at every tick.
--   - One stop: skipped for that launch only. Two in a row: skipped until F10 is pressed.
--   - Nothing is written to the settings any more.
-- File content: "S<n>" (idle, n stops in a row so far) or "B<n>" (busy); "0"/"1" before 0.6.1.
U.guards = {}

function U.guard(file_name)
    local path = U.MOD_DIR .. "/" .. file_name
    local g = { name = file_name, strikes = 0, blocked = false, tripped = false, pending = nil }

    local function write(v)
        local f = io.open(path, "w")
        if not f then
            g.pending = v
            return
        end
        f:write(v)
        f:close()
        g.pending = nil
    end

    local v = "S0"
    local f = io.open(path, "r")
    if f then
        v = f:read("a") or "S0"
        f:close()
    end
    if v == "1" then v = "B0" elseif v == "0" then v = "S0" end
    local n = tonumber(v:match("^[SB](%d+)")) or 0
    if v:sub(1, 1) == "B" then
        g.strikes, g.blocked, g.tripped = n + 1, true, true
        write("S" .. g.strikes)
    else
        g.strikes = n
        g.blocked = n >= 2
    end

    -- Runs fn(...) with the witness file saying "busy". Returns pcall's results.
    function g.run(fn, ...)
        write("B" .. g.strikes)
        local res = table.pack(pcall(fn, ...))
        if res[1] then g.strikes = 0 end
        write("S" .. g.strikes)
        return table.unpack(res, 1, res.n)
    end

    function g.flush()
        if g.pending then write(g.pending) end
    end

    function g.reset()
        g.strikes, g.blocked, g.tripped = 0, false, false
        write("S0")
    end

    U.guards[#U.guards + 1] = g
    return g
end

function U.flush_guards()
    for _, g in ipairs(U.guards) do g.flush() end
end

-- ---------------------------------------------------------------- keys
-- UE4SS calls a key bind on its input thread. There, the mod only raises a flag in a table
-- filled in advance: nothing is created and no game function is called outside the game
-- thread. The next tick does the work (a tenth of a second later at most).
local key_flags, key_actions, key_order = {}, {}, {}

function U.on_key(code, name, fn)
    key_flags[name] = false
    key_actions[name] = fn
    key_order[#key_order + 1] = name
    return pcall(RegisterKeyBind, code, function() key_flags[name] = true end)
end

local function run_keys(forget)
    for _, name in ipairs(key_order) do
        if key_flags[name] then
            key_flags[name] = false
            -- the diagnostic key is kept: it is the one wanted when the clock is unwell
            if not forget or name == "F10" then U.try("touche " .. name, key_actions[name]) end
        end
    end
end

local hook_alive = function() end      -- set by the scheduler below

-- ---------------------------------------------------------------- deferred hooks
-- RegisterHook needs the target function to be loaded. Blueprint classes are only
-- loaded with their map, so hooks are queued and registered as soon as possible.
local pending_hooks = {}
local last_hook_scan = -10

function U.hook(path, fn)
    pending_hooks[#pending_hooks + 1] = { path = path, fn = fn, tries = 0 }
end

local function process_hooks(now)
    if #pending_hooks == 0 or now - last_hook_scan < 1 then return end
    last_hook_scan = now
    local keep = {}
    for _, h in ipairs(pending_hooks) do
        local target = StaticFindObject(h.path)
        if U.valid(target) then
            local ok, err = pcall(RegisterHook, h.path, function(...)
                U.try(h.path, h.fn, ...)
                pcall(hook_alive)
            end)
            if ok then
                U.log("Accroche posée : %s", h.path)
            else
                h.tries = h.tries + 1
                U.log("Accroche impossible sur %s (essai %d) : %s", h.path, h.tries, tostring(err))
                if h.tries < 5 then keep[#keep + 1] = h end
            end
        else
            keep[#keep + 1] = h
        end
    end
    pending_hooks = keep
end

function U.pending_hook_count()
    return #pending_hooks
end

-- ---------------------------------------------------------------- scheduler
-- Everything that touches game objects runs in a "tick", ten times a second, on the game's
-- own thread.
--
-- Up to 0.6.0 a loop on a separate thread asked the game thread for each tick. On a player's
-- machine that chain stopped for good when she joined a game: the hooks still answered the
-- host, but nothing that depends on the tick ran any more (no tab, no banner, no tablet page,
-- D63). Lua is not made to run on two threads at once, and that loop ran Lua on a second
-- thread ten times a second, on the very Lua state the game thread uses.
--
-- Now the tick is driven by a loop that UE4SS itself runs on the game thread. Two things keep
-- an eye on it, and neither does anything while the loop beats:
--   - every hook of the mod (already on the game thread): when the loop has been silent for
--     5 s it asks the game thread for a "rescue"; if nothing has served the mod for 30 s
--     (neither the loop nor a rescue), the hook ticks by itself;
--   - a watch on the separate thread, once a second, that only compares numbers: when nothing
--     has ticked for 60 s (longer than any map load, so that it stays out of the way of the
--     game thread) it asks for a rescue too.
-- A rescue ticks once, and starts the loop again when it has been found silent twice, 2 s
-- apart (found once, the game was just busy loading a map), then less and less often if it
-- still does not beat. UE4SS ignores what the loop's function returns: an old loop is stopped
-- with CancelDelayedAction. On a UE4SS without the game-thread loop, the watch asks for every
-- tick, as before.
local tasks = {}        -- { at = time, fn = function, name = string }
local tickers = {}      -- functions called on every tick
local started = false
local last_run = 0           -- os.clock() when the last tick started
local ticking_since = nil    -- set while a tick runs: never a tick inside a tick
local loop_gen, loop_last, loop_handle = 0, 0, nil
local use_loop = false
local period = 100
local rescue_pending, rescue_at = false, 0
local unserved_since = nil   -- game thread only: since when a hook has seen nothing serve the mod
local suspect_at = nil       -- when the loop was first found silent
local restarts, restart_at, restart_wait = 0, 0, 5
local beats = { loop = 0, rescue = 0, hook = 0 }     -- who made the mod tick (for F10)
local longest_gap = 0
local announced = false

function U.after(seconds, name, fn)
    tasks[#tasks + 1] = { at = U.now() + seconds, fn = fn, name = name }
end

function U.every_tick(name, fn)
    tickers[#tickers + 1] = { fn = fn, name = name }
end

local function run_tick(gap)
    local now = U.now()
    if not announced then
        announced = true
        U.log("Horloge du mod : %s", use_loop and "boucle du fil du jeu" or "fil séparé (ancienne méthode)")
    end
    U.try("gardes", U.flush_guards)
    U.try("touches", run_keys, gap > 2)      -- keys pressed during a long stop are forgotten
    U.try("accroches", process_hooks, now)
    for _, t in ipairs(tickers) do U.try("tick " .. t.name, t.fn, now) end
    if #tasks == 0 then return end
    local due, keep = {}, {}
    for _, t in ipairs(tasks) do
        if t.at <= now then due[#due + 1] = t else keep[#keep + 1] = t end
    end
    tasks = keep
    for _, t in ipairs(due) do U.try("tâche " .. tostring(t.name), t.fn) end
end

-- One tick, whoever asks for it: two askers at the same moment make one tick, and nobody
-- starts a tick while one is running (the mark is ignored after 60 s, so that a tick that
-- ended badly cannot stop the clock for good).
local function tick_once(source)
    local now = os.clock()
    if ticking_since and now - ticking_since < 60 then return end
    local gap = now - last_run
    if gap < 0.05 then return end
    if started and gap > longest_gap then longest_gap = gap end
    last_run, ticking_since = now, now
    beats[source] = beats[source] + 1
    local ok, err = pcall(run_tick, gap)
    ticking_since = nil
    if not ok then U.log("ERREUR dans ordonnanceur : %s", tostring(err)) end
end

-- The loop on the game thread; the one it replaces is cancelled.
local function start_loop()
    if loop_handle ~= nil and type(CancelDelayedAction) == "function" then
        pcall(CancelDelayedAction, loop_handle)
    end
    loop_gen = loop_gen + 1
    local mine = loop_gen
    local ok, handle = pcall(LoopInGameThreadWithDelay, period, function()
        if mine ~= loop_gen then return end      -- an older loop that could not be cancelled
        loop_last, suspect_at, restart_wait, unserved_since = os.clock(), nil, 5, nil
        tick_once("loop")
    end)
    loop_handle = ok and handle or nil
    return ok, handle
end

-- On the game thread: one tick, and the loop again if it has stopped.
local function revive(source)
    tick_once(source)
    if not use_loop then return end
    local now = os.clock()
    if now - loop_last <= 5 then
        suspect_at = nil
    elseif not suspect_at then
        suspect_at = now
    elseif now - suspect_at >= 2 and now - restart_at >= restart_wait then
        suspect_at = nil
        restarts = restarts + 1
        restart_at, restart_wait = now, math.min(restart_wait * 2, 60)
        U.log("Horloge du mod muette depuis %d s : relancée (%d fois depuis le lancement)",
            math.floor(now - loop_last), restarts)
        local ok, err = start_loop()
        if not ok then U.log("Boucle du fil du jeu non relancée : %s", tostring(err)) end
    end
end

local function rescue()
    rescue_pending, unserved_since = false, nil
    revive("rescue")
end

-- Called after each hook of the mod, on the game thread.
local hook_told = false
hook_alive = function()
    local now = os.clock()
    if now - last_run <= 0.5 then return end
    if use_loop then
        if now - loop_last <= 5 then return end              -- a long frame, or a map being loaded
    elseif now - last_run <= 2 then
        return
    end
    unserved_since = unserved_since or now
    if now - unserved_since > 30 then
        -- neither the loop nor a rescue has run for 30 s: the mod ticks from its hooks
        if not hook_told then
            hook_told = true
            U.log("Horloge du mod : ni la boucle ni la demande de secours ne répondent, les accroches font battre le mod")
        end
        revive("hook")
    elseif not rescue_pending then
        rescue_pending, rescue_at = true, now
        if not pcall(ExecuteInGameThread, rescue) then rescue_pending = false end
    end
end

-- For the diagnostic key.
function U.clock_state()
    return string.format("%s, battements : boucle %d, secours %d, accroches %d ; %d relance(s) ; plus long silence %.1f s",
        use_loop and "boucle du fil du jeu" or "fil séparé", beats.loop, beats.rescue, beats.hook, restarts, longest_gap)
end

function U.start_scheduler(period_ms)
    if started then return end
    period = math.floor(period_ms or 100)
    last_run, loop_last = os.clock(), os.clock()
    started = true
    if type(LoopInGameThreadWithDelay) == "function" then
        local ok, err = start_loop()
        use_loop = ok == true
        if not ok then U.log("Boucle du fil du jeu indisponible (%s) : ancienne méthode", tostring(err)) end
    end
    -- The watch (or, without the game-thread loop, the one that asks for every tick). It
    -- creates nothing, and calls nothing while ticks are running or a tick is under way.
    local stale_after = use_loop and 60 or (period / 1000 * 0.5)
    local ok, err = pcall(LoopAsync, use_loop and 1000 or period, function()
        local now = os.clock()
        if ticking_since and now - ticking_since < 60 then return false end
        if rescue_pending then
            if now - rescue_at > 10 then rescue_pending = false end      -- lost: asked again
        elseif now - last_run > ((use_loop and suspect_at) and 3 or stale_after) then
            rescue_pending, rescue_at = true, now
            if not pcall(ExecuteInGameThread, rescue) then rescue_pending = false end
        end
        return false
    end)
    if not ok then
        U.log("Surveillance de l'horloge non démarrée : %s", tostring(err))
        if not use_loop then U.log("AUCUNE HORLOGE : le mod ne peut pas fonctionner avec cette version d'UE4SS") end
    end
end

math.randomseed(os.time())

return U
