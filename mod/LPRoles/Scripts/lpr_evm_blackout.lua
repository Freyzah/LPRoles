-- LPRoles - random event PANNE GÉNÉRALE (blackout): the ship loses its power. No task machine
-- takes or gives an item, the camera screens go black, the radios fall silent; two alarm boxes
-- of two sectors become beacons, and the power comes back when two players press their buttons
-- together (within the allowed gap), or by itself at the end of the longest blackout.
--   - Host: the two boxes drawn (far apart, unarmed when possible), the machines' slots locked
--     (the defibrillator's charger included), the cameras off, the radios paused, the beacons;
--     the presses heard on the host (the box's own "Button Push", whatever its state: a blow on
--     the button counts too); the restart named by the real names (the ship's network records
--     the presses: a disguised Métamorphe is named as itself, a clue on purpose); the overdrive
--     option (machines twice as fast for a minute after a quick restart).
--   - Every machine: nothing of its own (sirens, screens, banners, lines, sounds: the frame).
-- Worth saying in the manual: pressing an armed box (fuse in) also sets off its real alarm for
-- 10 s and uses it up for the game; the draw avoids armed boxes when it can.
local C = require("lpr_config")
local G = require("lpr_game")
local U = require("lpr_util")
local W = require("lpr_ev_world")

local M = { id = "blackout", switch = "event_blackout",
            KEYS = { "event_blackout_max", "event_blackout_gap", "event_blackout_bonus" },
            min_living = 4, not_last = 90 }

M.TEXT = {
    START     = { "PANNE GÉNÉRALE" },
    BOXES     = { "%s + %s", "sector", "sector" },
    HOW       = { "APPUYEZ ENSEMBLE AUX ALARMES" },
    FIXED     = { "COURANT RÉTABLI", c = "good" },
    BY        = { "PAR %s ET %s", "name", "name", c = "good" },
    FAIL      = { "RATÉ, SEUL %s A APPUYÉ", "sector", c = "bad", n = true },
    SAME      = { "IL FAUT DEUX JOUEURS", c = "bad", n = true },
    BACK      = { "LE COURANT REVIENT", c = "info" },
    BONUS     = { "MACHINES DEUX FOIS PLUS VITE", c = "good" },
    BONUS_END = { "FIN DU SURRÉGIME", c = "info" },
    NOBOX     = { "TEST : PAS DEUX ALARMES", c = "warn" },
}

M.LINES = {
    RUN   = { "Panne : boutons d'alarme %s et %s, en même temps, à deux - retour {t}", "sector_low", "sector_low" },
    BONUS = { "Surrégime : machines deux fois plus rapides - {t}" },
}

M.RECAP = {
    ev_blackout       = { "Évènement : panne générale, alarmes %s et %s", "sector_low", "sector_low" },
    ev_blackout_fixed = { "Panne : courant rétabli par %s et %s", "name", "name" },
    ev_blackout_fail  = { "Panne : relance ratée, seule l'alarme %s a été pressée", "sector_low" },
    ev_blackout_back  = { "Panne : le courant est revenu seul" },
    ev_blackout_bonus = { "Panne : surrégime des machines pendant 1 min" },
}

M.SOUNDS = { "ev_blackout_off", "ev_blackout_on" }

local MIN_APART = 3000       -- cm: two beacons closer than this make the restart too easy
-- Each beacon sounds 2 s every 15 s; the second one 7 s after the first, so that both are heard
-- apart and can be found by ear.
local SIREN_ON, SIREN_OFF, SIREN_SHIFT = 2, 13, 7
local PRESS_DEDUP = 0.5      -- s: two presses of one box this close are one (a push and a blow)
local FAIL_SPACING = 5       -- s: at most one failure notice in that time
local MAX_FAILS = 4          -- failures noted in the summary
local BONUS_WINDOW, BONUS_SECS = 30, 60
local TEST_GAP = 20          -- s: the host alone runs from one box to the other
local SOUND_TAIL = 2         -- s: the power-up sound plays out before the event's end takes it back
-- The machines of the overdrive and the factor of their "Charge Speed" (read when a cycle
-- starts): a speed for the first five (the cycle's timer is 1 / speed), a duration for the
-- container cleaner (Charge Speed / Max Process: half as long). The rice and pizzushi machines
-- never read theirs; the defibrillator's charger is not a task.
local FAST = { { "BatteryCharger_C", 2 }, { "Centrifuge_C", 2 }, { "Mixer_C", 2 }, { "Analyzer_C", 2 },
               { "FilterCleaner_C", 2 }, { "ContainerCleaner_C", 0.5 } }

-- ---------------------------------------------------------------- host
-- The two boxes: pairs of boxes of two different sectors (boxes of no sector are not listed by
-- W.alarms), first those where neither is armed (2: pressing it sets off its real alarm) nor
-- ringing (3: it would drown the beacon). Among the best: a pair at least MIN_APART apart at
-- random, else the furthest one; in TEST the nearest one. Called again by M.start (ctx.run is
-- empty at each start).
local function pick_boxes(test)
    local list = W.alarms()
    local calm, other = {}, {}
    for i = 1, #list do
        for j = i + 1, #list do
            local a, b = list[i], list[j]
            if a.sector ~= b.sector then
                local busy = a.state == 2 or a.state == 3 or b.state == 2 or b.state == 3
                local pool = busy and other or calm
                pool[#pool + 1] = { a = a, b = b, d = U.dist(a.at, b.at) }
            end
        end
    end
    local pool = (#calm > 0) and calm or other
    if #pool == 0 then return nil end
    table.sort(pool, function(x, y) return x.d < y.d end)
    if test then return pool[1].a, pool[1].b end
    local far = {}
    for _, p in ipairs(pool) do
        if p.d >= MIN_APART then far[#far + 1] = p end
    end
    local p = (#far > 0) and far[math.random(#far)] or pool[#pool]
    if math.random(2) == 2 then return p.b, p.a end      -- either box may sound first
    return p.a, p.b
end

-- The machines' cycles twice as fast: each value noted, then written the way the game writes it
-- (FlushNetDormancy, the value, marked dirty for the push model: Task_Vents 0x02e0-0x03a7), and
-- always written back when the event stops, the end of the game included. Returns how many.
local function overdrive(ctx)
    local helpers = StaticFindObject("/Script/Engine.Default__NetPushModelHelpers")
    local function write(m, v)
        pcall(function() m:FlushNetDormancy() end)
        if U.set(m, "Charge Speed", v + 0.0) and U.valid(helpers) then
            pcall(function() helpers:MarkPropertyDirty(m, FName("Charge Speed")) end)
        end
    end
    local saved = {}
    for _, f in ipairs(FAST) do
        for _, m in ipairs(W.all_of(f[1])) do
            local v = U.get(m, "Charge Speed", nil)
            if type(v) == "number" and v > 0 then
                saved[#saved + 1] = { m = m, v = v }
                write(m, v * f[2])
            end
        end
    end
    ctx.defer(function()
        for _, s in ipairs(saved) do
            if U.valid(s.m) then write(s.m, s.v) end
        end
    end)
    return #saved
end

-- The power is back: slots, cameras and radios given back now (the event may live on for the
-- overdrive), the beacons silent, the power-up sound. fast: a quick restart with the option on.
local function power_back(ctx, r, now, fast)
    r.phase = "up"
    ctx.undo(r.locks)
    ctx.undo(r.cams)
    ctx.undo(r.radios)
    ctx.siren_off("s1")
    ctx.siren_off("s2")
    ctx.sound("pw", "ev_blackout_on", nil, { mode = "flat" })
    r.ends_at = now + SOUND_TAIL
    if fast and overdrive(ctx) > 0 then
        r.fast = true
        r.ends_at = now + BONUS_SECS
        ctx.say(nil, "BONUS")
        ctx.line(nil, "BONUS", BONUS_SECS)
        ctx.recap("ev_blackout_bonus")
    else
        ctx.line(nil, nil)
    end
end

-- Two presses within the gap, by two players: the real indexes, noted when they pressed (a
-- player who left since keeps its name on every machine).
local function success(ctx, r, now, i1, i2)
    ctx.say(nil, "FIXED")
    ctx.say(nil, "BY", i1, i2)
    ctx.recap("ev_blackout_fixed", i1, i2)
    power_back(ctx, r, now, r.bonus and now - r.t0 <= BONUS_WINDOW)
end

-- One side pressed alone: once the gap is over (and no later press took over), the failure is
-- told: which side, never who. It can be tried again at once.
local function check_fail(ctx, r, box, mark)
    if r.phase ~= "down" or box.last ~= mark then return end
    box.last = nil
    local now = ctx.now()
    if now - r.said >= FAIL_SPACING then
        r.said = now
        ctx.notice(nil, "FAIL", box.sector)
    end
    if r.fails < MAX_FAILS then
        r.fails = r.fails + 1
        ctx.recap("ev_blackout_fail", box.sector)
    end
end

-- A box's button pressed (on the host, after the game's own "Button Push"; the game refuses it
-- to a ghost, to a sleeping Rêveur and a flying Fée - ghosts on their own machine - and to a
-- hidden Clandestin). source: the Mec who pressed.
local function on_press(ctx, hc, source)
    local r = ctx.run
    if r.phase ~= "down" then return end
    local box = r.boxes[U.key(hc:get())]
    if not box then return end                             -- another box
    local ok, mec = pcall(function() return source:get() end)
    local P = (ok and U.valid(mec)) and ctx.by_key(U.key(mec)) or nil
    if not (P and P.camp and G.is_alive(P.mec)) then return end   -- not a player of this game
    local now = ctx.now()
    if now - box.pressed < PRESS_DEDUP then return end
    box.pressed = now
    local o = r.boxes[box.other].last
    if o and now - o.at <= r.gap then
        -- two different players (Échangeur, Écho: nobody presses both alone); in TEST one may
        if o.key ~= P.key or ctx.test then
            r.phase = "up"
            return success(ctx, r, now, o.idx, ctx.idx(P))
        end
        ctx.notice(P, "SAME")
    end
    local mark = { at = now, key = P.key, idx = ctx.idx(P) }
    box.last = mark
    ctx.at(r.gap + 0.05, function() check_fail(ctx, r, box, mark) end)
end

M.hooks = {
    { path = W.PATH_ALARM .. ":BndEvt__AlarmButton_Button_K2Node_ComponentBoundEvent_0_Button Push__DelegateSignature",
      fn = on_press },
}

function M.can_start(ctx, now, test)
    if not pick_boxes(test) then return false, "NOBOX" end
    return true
end

function M.start(ctx, now, test)
    local A, B = pick_boxes(test)
    if not A then return false end
    local r = ctx.run
    r.max = C.get("event_blackout_max")
    r.gap = test and TEST_GAP or C.get("event_blackout_gap")
    r.bonus = C.get("event_blackout_bonus") == true
    r.t0, r.fails, r.said = now, 0, -math.huge
    local ka, kb = U.key(A.actor), U.key(B.actor)
    r.boxes = { [ka] = { sector = A.sector, other = kb, pressed = -math.huge },
                [kb] = { sector = B.sector, other = ka, pressed = -math.huge } }
    -- the power is out: slots locked (the defibrillator's charger too; never the door readers,
    -- weapon cases and loader, alarm fuses, radios' readers, machine buttons), screens black,
    -- radios paused (one started again is paused again by the frame). The handles let the power
    -- come back before the event ends (the overdrive keeps it running).
    r.locks = ctx.lock_slots("power")
    r.cams = ctx.cameras_off()
    r.radios = ctx.radios_pause()
    ctx.siren("s1", A, SIREN_ON, SIREN_OFF, r.max)
    ctx.at(SIREN_SHIFT, function()
        if r.phase == "down" then ctx.siren("s2", B, SIREN_ON, SIREN_OFF, r.max - SIREN_SHIFT) end
    end)
    ctx.say(nil, "START")
    ctx.say(nil, "BOXES", A.sector, B.sector)
    ctx.say(nil, "HOW")
    ctx.line(nil, "RUN", r.max, A.sector, B.sector)
    ctx.sound("pw", "ev_blackout_off", nil, { mode = "flat" })
    ctx.recap("ev_blackout", A.sector, B.sector)
    r.phase = "down"
    -- the planned length covers the overdrive (the frame's hard stop is 15 s later)
    return r.max + (r.bonus and BONUS_SECS or 0)
end

function M.tick(ctx, now)
    local r = ctx.run
    if r.phase == "down" then
        -- the longest blackout (also the end when a chosen box is gone: nobody can press it)
        if now >= r.t0 + r.max then
            ctx.say(nil, "BACK")
            ctx.recap("ev_blackout_back")
            power_back(ctx, r, now, false)
        end
    elseif r.phase == "up" and now >= r.ends_at then
        if r.fast then ctx.say(nil, "BONUS_END") end
        ctx.finish("done")
    end
end

-- Stopped from the outside (TEST, a switch): the power is said to come back (the frame undoes it
-- all); at the end of the game nothing is said. The machines' speed is always written back.
function M.stop(ctx, reason)
    local r = ctx.run
    if reason == "end" or reason == "done" then return end
    if r.phase == "down" then
        ctx.say(nil, "BACK")
    elseif r.fast then
        ctx.say(nil, "BONUS_END")
    end
end

-- ---------------------------------------------------------------- every machine
M.client = {}                -- nothing local: the frame's messages do it all

return M
