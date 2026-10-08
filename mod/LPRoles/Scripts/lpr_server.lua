-- LPRoles - host side: who has which role, the power key, and the powers.
-- Runs only on the machine that hosts the game (the hooks below fire only there).
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local N = require("lpr_net")

local Sv = {}

local players = {}                 -- key (object address) -> player record
local game = { active = false, started_at = 0, announced = false, converted = false, mole = false }
local frozen_count = 0             -- bodies currently held in place (dreaming or just woken)
local freeze_hook = nil            -- { path, pre, post } while the locomotion hook is registered
local guard_eye, guard_stance = false, false
local ZERO = U.vec()
local AIM_CONE = math.cos(math.rad(18))   -- how close to the centre of the view a new target must be
local AIM_KEEP = math.cos(math.rad(25))   -- a target already aimed at is kept while inside this cone
local AIM_GAP = 0.3                       -- a target lost for less than this is still the same aim
local ACT_WINDOW = 2.5                    -- seconds an aimed power looks for a target after the key
local INSTANT_WINDOW = 0.3                -- the same for the powers that act at once: the press itself, no more
-- Seconds during which the last attacker counts as the killer. Kept short: grenades, poison
-- and falls kill without going through the hook that records attackers.
local MARTYR_WINDOW = 3

-- Heights above a character's position, which is at its feet (the game's camera is about
-- 1.6 m up).
local EYE_HEIGHT = 160
local BODY_HEIGHTS = { 40, 100, 155 }          -- legs, chest, head
local SEATED_HEIGHTS = { 30, 70, 100 }         -- a Rêveur's body, sitting
-- A dead body lies along the way it faced (it fell forwards or backwards from where it died).
local LYING_HEIGHT = 25
local LYING_SPREAD = { -120, -60, 0, 60, 120 }
local BODY_REACH = 250                         -- Métamorphe: a body this close needs no aiming (cm)

-- ---------------------------------------------------------------- player records
local function fresh_game_fields(P)
    P.role, P.camp, P.charges = nil, nil, 0
    P.dreaming, P.tail, P.fairy = nil, nil, nil
    P.infect, P.infections_left = nil, 0
    P.infected_at, P.infected_by = nil, nil
    P.act = nil                    -- the power key was pressed and a target is awaited: { at }
    P.aim = nil                    -- target being aimed at: { key, since, lost }
    P.announced = nil              -- target already named since the key was pressed
    P.protege, P.saved = nil, false
    P.tracking, P.marker = nil, nil
    P.hypno_until = nil
    P.link, P.died_at = nil, nil
    P.link_done = false            -- Liés: the bond has already taken its toll (it acts once)
    P.vision_until, P.spirit_until = nil, nil
    P.last_hit = nil
    P.mimic, P.skin_original = nil, nil
    P.hiding = nil                 -- Clandestin: { loc, aim, yaw, real, since, ends }
    P.undoing = nil
    P.cleaned = false              -- this dead player's body was removed by the Nettoyeur
    P.recharges, P.recharged_at = 0, nil       -- uses got back with an item, and when the last one was asked
    P.jar_wait = nil               -- a jar was asked to be emptied: { role, code, ends }
    P.safe, P.marker_secs = nil, nil   -- Shérif: the safe person's key, and how long it was marked
    P.card = nil                   -- Shérif: the access card shown to this player: "shown", "taken", nil if none
    P.clean_aim = nil
    P.status_sent = nil
end

-- Keeps what must survive from one game to the next.
local function reset_for_game(P)
    local modded, eye = P.modded, P.eye
    fresh_game_fields(P)
    P.modded, P.eye = modded, eye
end

local function player(mec, create)
    local key = U.key(mec)
    if not key then return nil end
    local P = players[key]
    if P and U.valid(P.mec) then return P end
    if not create then return nil end
    P = { key = key, mec = mec, modded = false, eye = 0, closed_since = nil, hold_fired = false }
    fresh_game_fields(P)
    players[key] = P
    return P
end

local function each_player(fn)
    for _, P in pairs(players) do
        if U.valid(P.mec) then fn(P) end
    end
end

local function by_key(key)
    local P = key and players[key]
    if P and U.valid(P.mec) then return P end
    return nil
end

local function idx(P)
    return G.player_index(P.mec)
end

local function tell(P, cmd, ...)
    if P.modded and U.valid(P.mec) then N.send(P.mec, cmd, ...) end
end

local function broadcast(cmd, ...)
    local args = { ... }
    each_player(function(P) tell(P, cmd, table.unpack(args)) end)
end

-- ---------------------------------------------------------------- uses, and getting one back
-- Roles that get a use back by consuming the item in hand: a jar holding a plant, or a fish.
-- item: the setting naming the item ("none": no recharge); max: the setting giving the most
-- uses (one when absent); field: where the uses are counted.
local RECHARGE = {
    dreamer   = { item = "dreamer_item" },
    fairy     = { item = "fairy_item" },
    medium    = { item = "medium_item",   max = "medium_charges" },
    tracker   = { item = "tracker_item",  max = "tracker_charges" },
    hypnotist = { item = "hypno_item",    max = "hypno_charges" },
    mimic     = { item = "mimic_item",    max = "mimic_charges" },
    cleaner   = { item = "cleaner_item",  max = "cleaner_charges" },
    stowaway  = { item = "stowaway_item", max = "stowaway_charges" },
    swapper   = { item = "swapper_item",  max = "swapper_charges" },
    infector  = { item = "infector_item", max = "infect_charges", field = "infections_left" },
}
local RECHARGE_GAP = 1.5      -- seconds between two recharges of a player
local JAR_WAIT = 3            -- seconds a jar is given to come back emptied

-- Number (1-9) of the item this player's role recharges with, and the entry above; nil when
-- the role has none.
local function recharge_of(P)
    local spec = RECHARGE[P.role]
    local code = spec and C.item_code(C.get(spec.item)) or 0
    if code == 0 then return nil end
    return code, spec
end

-- The host may limit the recharges of each player in a game.
local function may_recharge(P)
    local limit = C.get("recharge_limit")
    return limit <= 0 or P.recharges < limit
end

-- What to tell a player whose power has no use left: the item to consume, when a recharge is
-- possible.
local function no_use_msg(P)
    local code = recharge_of(P)
    if code and may_recharge(P) then return "NO_CHARGE", code end
    return "NO_USE_LEFT"
end

-- Whether this player's role can take one more use; if not, the message that says why.
local function room_for_use(P, spec)
    local max = spec.max and C.get(spec.max) or 1
    if P[spec.field or "charges"] >= max then return false, max > 1 and "USES_FULL" or "CHARGE_FULL" end
    if not may_recharge(P) then return false, "NO_RECHARGE_LEFT" end
    return true, max
end

-- The use is given back, and the player told.
local function give_use_back(P, spec, max)
    local field = spec.field or "charges"
    P[field] = P[field] + 1
    P.recharges = P.recharges + 1
    tell(P, "MSG", max > 1 and "USE_BACK" or "RECHARGED")
    U.log("%s (%s) récupère une utilisation : objet consommé (%s)", G.player_name(P.mec), P.role, C.get(spec.item))
end

-- One use back for the item in hand. The use is only counted once the host has seen the item
-- used up, so that an item dropped or put away at the same moment gives nothing:
--   - a fish leaves the hand the way an item put in a slot does (the game's own two calls,
--     one for the player's machine, one for the host's record of the hand), checked at once;
--   - a jar is emptied by the player's own machine (see lpr_client.lua), which then tells the
--     host its new content: the use is given when that arrives (see jar_emptied).
-- missing: message sent when the right item is not in hand.
local function try_recharge(P, missing)
    local code, spec = recharge_of(P)
    if not code then return false end
    local ok, max = room_for_use(P, spec)
    if not ok then
        tell(P, "MSG", max)
        return false
    end
    local now = U.now()
    if P.jar_wait or (P.recharged_at and now - P.recharged_at < RECHARGE_GAP) then return false end
    if G.held_item(P.mec) ~= code then
        tell(P, "MSG", missing or "NO_CHARGE", code)
        return false
    end
    P.recharged_at = now
    if code <= G.PLANT_KINDS then
        P.jar_wait = { role = P.role, code = code, ends = now + JAR_WAIT }
        tell(P, "EMPTYJAR", code)              -- the plant: only the jar holding it is emptied
        return true
    end
    U.tcall(P.mec, "Let Item")
    U.tcall(P.mec, "Net Let Item")
    if G.held_item(P.mec) == code then
        U.log("ERREUR : le poisson de %s n'a pas pu être retiré de sa main, pas de recharge", G.player_name(P.mec))
        return false
    end
    tell(P, "EATEN")
    give_use_back(P, spec, max)
    return true
end

-- The player's machine has told the host the new state of the item in hand: if a jar was
-- asked to be emptied and is now dirty, the use is given back. (Also checked at every tick
-- while a jar is awaited, should the game's call go unseen.)
local function jar_emptied(P)
    local w = P.jar_wait
    if not w or not G.holds_dirty_jar(P.mec) then return end
    P.jar_wait = nil
    local code, spec = recharge_of(P)
    if P.role ~= w.role or code ~= w.code then return end      -- the host changed the item meanwhile
    local ok, max = room_for_use(P, spec)
    if ok then give_use_back(P, spec, max) else tell(P, "MSG", max) end
end

-- The jar did not come back emptied in time (dropped or put away at the same moment):
-- nothing was given.
local function jar_timeout(P, now)
    local w = P.jar_wait
    if not w or now < w.ends then return end
    P.jar_wait = nil
    tell(P, "MSG", "NEED_ITEM", w.code)
    U.log("%s : bocal non vidé à temps, pas de recharge", G.player_name(P.mec))
end

-- ---------------------------------------------------------------- forcing replicated state
local function force_eye(mec, state)
    guard_eye = true
    U.tcall(mec, "Net Eye State", state)
    guard_eye = false
end

local function force_stance(mec, stance)
    guard_stance = true
    U.tcall(mec, "Net Set Stance", stance)
    guard_stance = false
end

-- ---------------------------------------------------------------- win condition safety net
-- The game ends itself when every employee it knows is dead. After a recruitment its lists
-- may be out of date, so the same check is redone here with the mod's own knowledge.
local function living_employees()
    local n = 0
    each_player(function(P)
        if P.camp == "employee" and G.is_alive(P.mec) then n = n + 1 end
    end)
    return n
end

local function check_dissident_win()
    local gm = G.gm()
    if not gm or not game.active or not game.converted then return end
    if U.get(gm, "Difficulty", 0) == 0 then return end        -- training: nobody wins by kills
    if living_employees() > 0 then return end
    U.after(0.6, "fin de partie", function()
        local gm2 = G.gm()
        if gm2 and game.active and game.converted and U.get(gm2, "In Game", false) and living_employees() == 0 then
            U.log("Plus aucun employé en vie : fin de partie (victoire des dissidents)")
            U.tcall(gm2, "End Game", false, false)
        end
    end)
end

-- ---------------------------------------------------------------- dissident spheres (Taupe, Traqueur, Shérif)
-- The game's "Set Hacker Sphere(list)" shows, on one player's screen, the sphere of every
-- character in the list, provided that player is in the list too. It replaces what was shown.
local function sphere_list(P, now)
    local list = {}
    if P.camp == "dissident" and P.role ~= "mole" then
        each_player(function(Q)
            if Q.camp == "dissident" and Q.role ~= "mole" then list[#list + 1] = Q.mec end
        end)
    else
        list[1] = P.mec
    end
    local marks = 0
    for _, mark in ipairs({ P.tracking or false, P.marker or false }) do
        if mark and now < mark.ends then
            local T = by_key(mark.key)
            if T then
                list[#list + 1] = T.mec
                marks = marks + 1
            end
        end
    end
    return list, marks
end

local function send_spheres(P)
    if not P.camp or not U.valid(P.mec) then return end
    local list, marks = sphere_list(P, U.now())
    if P.camp ~= "dissident" and marks == 0 then
        U.tcall(P.mec, "Clear Hacker Sphere")
    else
        U.tcall(P.mec, "Set Hacker Sphere", list)
    end
end

-- After the game has shown the spheres its own way, correct them where the mod needs to.
local function correct_spheres()
    if not game.active or not G.in_game() then return end
    local now = U.now()
    each_player(function(P)
        local marked = (P.tracking and now < P.tracking.ends) or (P.marker and now < P.marker.ends)
        if ((game.mole or game.converted) and P.camp == "dissident") or marked then send_spheres(P) end
    end)
end

-- ---------------------------------------------------------------- Rêveur: keeping the body in place
-- The game rebroadcasts every position a player sends. While a body is asleep the host
-- rebroadcasts the body's position right after, so everybody keeps seeing it where it fell
-- asleep. `P.tail` keeps this going for a moment after waking, until the player is back in it.
local function frozen_pose(P)
    if P.dreaming then return P.dreaming end
    if P.hiding then return P.hiding end
    if P.tail and U.now() < P.tail.ends then return P.tail end
    return nil
end

local function freeze_callback(ctx)
    if frozen_count <= 0 then return end
    local mec = ctx:get()
    local P = player(mec, false)
    local d = P and frozen_pose(P)
    if d then U.call(mec, "All Update Locomotion", d.loc, ZERO, d.aim, d.yaw) end
end

local function ensure_freeze_hook()
    if freeze_hook then return end
    local path = G.fn_path(G.PATH_MEC, "Net Update Locomotion")
    local ok, pre, post = pcall(RegisterHook, path, function(ctx) U.try("gel du corps", freeze_callback, ctx) end)
    if ok then
        freeze_hook = { path = path, pre = pre, post = post }
    else
        U.log("Impossible d'accrocher Net Update Locomotion : %s", tostring(pre))
    end
end

-- Recounts the frozen bodies and drops the locomotion hook when none is left.
local function recount_frozen()
    local n, now = 0, U.now()
    for _, P in pairs(players) do
        if P.tail and now >= P.tail.ends then P.tail = nil end
        if P.dreaming or P.tail or P.hiding then n = n + 1 end
    end
    frozen_count = n
    if n == 0 and freeze_hook then
        local h = freeze_hook
        if pcall(UnregisterHook, h.path, h.pre, h.post) then freeze_hook = nil end
    end
end

local function start_dream(P)
    local mec = P.mec
    local loc = G.location(mec)
    if not loc then return end
    local aim = U.get(mec, "Net Aim Target", nil)
    local d = {
        loc = loc,
        yaw = U.get(mec, "Net Orientation", 0.0) + 0.0,
        aim = (aim and U.vec_copy(aim)) or U.vec(),
        stance = U.get(mec, "Net Stance", G.STANCE_STAND),
        ends = U.now() + C.get("dream_duration"),
        opened = false,
    }
    P.charges = 0
    P.dreaming = d
    frozen_count = frozen_count + 1
    ensure_freeze_hook()
    force_stance(mec, G.STANCE_SIT)
    force_eye(mec, G.EYE_CLOSED)
    U.log("%s commence à rêver", G.player_name(mec))
    tell(P, "DREAM", 1, U.round(C.get("dream_duration")), U.round(loc.X), U.round(loc.Y), U.round(loc.Z), U.round(d.yaw))
    return true
end

-- skip_client: the player's machine already left the dream on its own.
local function end_dream(P, reason, skip_client)
    local d = P.dreaming
    if not d then return end
    P.dreaming = nil
    if not skip_client then
        -- keep the body in place until the player's own teleport arrives (see "Net Request TP")
        P.tail = { loc = d.loc, yaw = d.yaw, aim = d.aim, ends = U.now() + 1.5 }
    end
    P.closed_since, P.hold_fired = nil, true
    local mec = P.mec
    if U.valid(mec) then
        force_stance(mec, d.stance or G.STANCE_STAND)
        force_eye(mec, P.eye or G.EYE_OPEN)
        U.tcall(mec, "All Update Locomotion", d.loc, ZERO, d.aim, d.yaw)
        U.log("%s se réveille (%s)", G.player_name(mec), reason)
        if not skip_client then
            tell(P, "DREAM", 0, reason)
        end
    end
    recount_frozen()
end

-- ---------------------------------------------------------------- Fée
local function start_fairy(P)
    P.charges = 0
    local tenths = U.round(C.get("fairy_duration") * 10)
    P.fairy = { ends = U.now() + C.get("fairy_duration") }
    U.log("%s s'envole en fée", G.player_name(P.mec))
    -- what the others see in place of her body: the light, the purple ball (after the duration)
    broadcast("FX", idx(P), 1, C.get("fairy_light") and 1 or 0, tenths, C.get("fairy_ball") and 1 or 0)
    tell(P, "FAIRY", 1, tenths)
end

local function end_fairy(P)
    if not P.fairy then return end
    P.fairy = nil
    if U.valid(P.mec) then
        tell(P, "FAIRY", 0, 0)
        broadcast("FX", idx(P), 0, 0, 0)
    end
end

-- ---------------------------------------------------------------- Clandestin: hiding in a vent
-- Everybody sees the body where the host says it is: while hidden, it is sent far under the
-- vent, out of sight and out of reach, players without the mod included. The player stays
-- in place on their own machine (movement locked there), and reappears there at the end.
local function nearest_vent(P)
    local from = G.location(P.mec)
    if not from then return nil end
    local best, best_d = nil, C.get("stowaway_range")
    for _, v in ipairs(G.vent_spots()) do
        local dx, dy = v.X - from.X, v.Y - from.Y
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= best_d and math.abs(v.Z - from.Z) <= 400 then best, best_d = v, d end
    end
    return best
end

local function start_hide(P, now)
    if P.charges <= 0 then return tell(P, "MSG", no_use_msg(P)) end
    local vent = nearest_vent(P)
    if not vent then return tell(P, "MSG", "NO_VENT") end
    local real = G.location(P.mec)
    if not real then return end
    local secs = C.get("stowaway_duration")
    -- 40 m under the vent: out of sight and reach, but close enough for the engine to keep
    -- sending this player to the others (made sure of while hidden)
    local hidden = { X = vent.X, Y = vent.Y, Z = vent.Z - 4000 }
    P.charges = P.charges - 1
    P.was_relevant = U.get(P.mec, "bAlwaysRelevant", false)
    U.set(P.mec, "bAlwaysRelevant", true)
    P.hiding = { loc = hidden, aim = hidden, yaw = U.get(P.mec, "Net Orientation", 0.0) + 0.0,
                 real = real, since = now, ends = now + secs }
    frozen_count = frozen_count + 1
    ensure_freeze_hook()
    U.tcall(P.mec, "All Update Locomotion", hidden, ZERO, hidden, P.hiding.yaw)
    tell(P, "HIDE", 1, U.round(secs))
    U.log("Clandestin : %s se cache dans une bouche", G.player_name(P.mec))
    return true
end

local function end_hide(P, reason)
    local h = P.hiding
    if not h then return end
    P.hiding = nil
    recount_frozen()
    if U.valid(P.mec) then
        U.set(P.mec, "bAlwaysRelevant", P.was_relevant == true)
        -- shown again where they hid (the player has not moved on their side), looking ahead
        local r = math.rad(h.yaw or 0)
        local ahead = { X = h.real.X + 200 * math.cos(r), Y = h.real.Y + 200 * math.sin(r), Z = h.real.Z + EYE_HEIGHT }
        U.tcall(P.mec, "All Update Locomotion", h.real, ZERO, ahead, h.yaw)
        tell(P, "HIDE", 0, 0)
    end
    U.log("Clandestin : %s sort de sa cachette (%s)", G.player_name(P.mec), reason)
end

-- ---------------------------------------------------------------- Médium, Revenant
local function start_medium(P, now)
    if P.vision_until and now < P.vision_until then return end
    if P.charges <= 0 then return tell(P, "MSG", no_use_msg(P)) end
    P.charges = P.charges - 1
    local secs = C.get("medium_duration")
    P.vision_until = now + secs
    tell(P, "MEDIUM", 1, U.round(secs))
    U.log("%s a une vision (%d s)", G.player_name(P.mec), U.round(secs))
    return true
end

local function start_spirit(P, now)
    if P.spirit_until and now < P.spirit_until then return end
    if P.charges <= 0 then return tell(P, "MSG", "NO_USE_LEFT") end
    P.charges = P.charges - 1
    local secs = C.get("revenant_duration")
    P.spirit_until = now + secs
    broadcast("SPIRIT", idx(P), U.round(secs * 10))
    tell(P, "MSG", "SPIRIT_START")
    U.log("%s se manifeste", G.player_name(P.mec))
    return true
end

-- Both eyes kept closed for the configured time: the Rêveur's gesture, the only power still
-- started with the eyes (all the others are on the power key, see on_power). Closing both eyes
-- locks them shut: when the gesture starts something, the player's machine is told to open
-- them again.
local function on_eyes_held(P)
    if not game.active or P.role ~= "dreamer" or P.dreaming or not G.is_alive(P.mec) then return end
    local started = false
    if P.charges >= 1 then
        started = start_dream(P)
    elseif C.get("recharge_by_eyes") and recharge_of(P) ~= nil then
        -- recharging is done with the "consume" key; with the eyes too when the host allows it
        started = try_recharge(P)
    else
        tell(P, "MSG", no_use_msg(P))
    end
    if started then tell(P, "OPENEYES") end
end

-- The player pressed the "consume" key: the item in hand gives a use of the role's power back.
local function on_use(P)
    if not game.active or not G.is_alive(P.mec) or P.dreaming or P.fairy or P.hiding then return end
    try_recharge(P, "NEED_ITEM")
end

-- ---------------------------------------------------------------- Nettoyeur
-- The power key pressed near a body, then staying near it, removes it: every machine stops
-- showing it and it can no longer be hit by the defibrillator; a revival that still happens
-- is undone.
local function stop_act(P)
    P.act, P.aim, P.announced, P.infect, P.clean_aim = nil, nil, nil, nil, nil
end

-- The dead body (of a player of this game, and not removed) closest to this player, within
-- `reach` cm.
local function body_near(P, reach)
    local from = G.location(P.mec)
    if not from then return nil end
    local best, best_d = nil, reach
    each_player(function(T)
        if T == P or not T.camp or T.cleaned or G.is_alive(T.mec) then return end
        local at = G.death_spot(T.mec)
        if not at then return end
        local d = U.dist(from, at)
        if d <= best_d then best, best_d = T, d end
    end)
    return best
end

local function tick_cleaner(P, now)
    if not P.act then return end
    if not G.is_alive(P.mec) then return stop_act(P) end
    if P.charges <= 0 then
        tell(P, "MSG", no_use_msg(P))
        return stop_act(P)
    end
    local T = body_near(P, C.get("cleaner_range"))
    if not T then
        tell(P, "MSG", P.clean_aim and "TARGET_LOST" or "NO_BODY")
        return stop_act(P)
    end
    if not P.clean_aim or P.clean_aim.key ~= T.key then
        P.clean_aim = { key = T.key, since = now }
        tell(P, "MSG", "TARGET", idx(T))
        return
    end
    if now - P.clean_aim.since < C.get("cleaner_hold") then return end
    stop_act(P)
    P.charges = P.charges - 1
    T.cleaned = true
    broadcast("CLEAN", idx(T))
    tell(P, "MSG", "CLEAN_DONE", idx(T))
    U.log("Nettoyeur : %s fait disparaître le corps de %s", G.player_name(P.mec), G.player_name(T.mec))
end

-- A cleaned body brought back anyway (a player without the mod can still reach it): dead again.
local function undo_revival(P)
    U.after(0.3, "corps nettoyé", function()
        if not game.active or not U.valid(P.mec) or not G.is_alive(P.mec) then return end
        P.undoing = true                       -- not a new death for the other roles
        U.tcall(P.mec, "Death", U.get(P.mec, "Net Orientation", 0.0) + 0.0, true)
        U.after(1.0, "corps nettoyé", function() if game.active then broadcast("CLEAN", idx(P)) end end)
        U.log("Nettoyeur : %s, dont le corps avait disparu, ne peut pas revenir", G.player_name(P.mec))
    end)
end

-- ---------------------------------------------------------------- Recruteur (internal id "infector")
local function infection_target(P)
    local from = G.location(P.mec)
    if not from then return nil end
    local best, best_d = nil, C.get("infect_range")
    each_player(function(T)
        if T ~= P and T.camp == "employee" and not T.infected_at and not T.hiding and G.is_alive(T.mec) then
            local at = (T.dreaming and T.dreaming.loc) or G.location(T.mec)
            if at then
                local dist = U.dist(from, at)
                if dist <= best_d then best, best_d = T, dist end
            end
        end
    end)
    return best
end

-- The power key pressed near an employee, then staying near for the configured time.
local function tick_infector(P, now)
    if not P.act then return end
    if not G.is_alive(P.mec) then return stop_act(P) end
    if P.infections_left <= 0 then
        local id, item = no_use_msg(P)
        if id == "NO_CHARGE" then tell(P, "MSG", id, item) else tell(P, "MSG", "INFECT_NO_CHARGE") end
        return stop_act(P)
    end
    if now - game.started_at < C.get("infect_min_game_seconds") then
        tell(P, "MSG", "INFECT_TOO_EARLY")
        return stop_act(P)
    end
    local T = infection_target(P)
    if not T then
        tell(P, "MSG", P.infect and "TARGET_LOST" or "NO_ONE_NEAR")
        return stop_act(P)
    end
    if not P.infect or P.infect.key ~= T.key then
        if not P.infect then tell(P, "MSG", "INFECT_PROGRESS") end      -- said once per press
        P.infect = { key = T.key, since = now }
        return
    end
    if now - P.infect.since < C.get("infect_hold_seconds") then return end
    -- stayed near long enough
    stop_act(P)
    P.infections_left = P.infections_left - 1
    if T.role == "sheriff" and C.get("sheriff_immune") then
        tell(P, "MSG", "INFECT_FAILED")
        U.log("%s tente de recruter le shérif : échec", G.player_name(P.mec))
        return
    end
    T.infected_at = now + C.get("infect_delay_seconds")
    T.infected_by = P.key
    tell(P, "MSG", "INFECT_DONE", U.round(C.get("infect_delay_seconds")))
    U.log("%s a recruté %s (conversion dans %d s)", G.player_name(P.mec), G.player_name(T.mec), C.get("infect_delay_seconds"))
end

local function convert(T)
    local gm = G.gm()
    T.infected_at = nil
    if not gm or not game.active or not G.is_alive(T.mec) then return end
    if T.dreaming then end_dream(T, "infected") end
    T.camp = "dissident"
    game.converted = true
    U.tcall(T.mec, "Set Player Role", G.ROLE_DISSIDENT)
    G.array_remove(gm, "Innocents", T.mec)
    if not G.array_add(gm, "Hackers", T.mec) then
        U.log("La liste des dissidents du jeu n'a pas pu être mise à jour pour %s", G.player_name(T.mec))
    end
    if T.modded then
        tell(T, "MSG", "YOU_ARE_INFECTED")
    else
        -- Without the mod the only way to tell the player is the game's own role screen,
        -- which also freezes their controls for a few seconds.
        U.tcall(T.mec, "Game Start Message", true)
    end
    U.tcall(gm, "Set HackerSphere", false)               -- dissidents see each other (corrected for the Taupe)
    local by = T.infected_by and players[T.infected_by]
    if by then tell(by, "MSG", "INFECT_CONVERTED", idx(T)) end
    U.log("%s devient dissident", G.player_name(T.mec))
    check_dissident_win()
end

-- ---------------------------------------------------------------- powers aimed at a player
-- The player presses the power key while looking at someone. The game sends, with every position,
-- the point each player is looking at: the target is the player closest to that line of sight.
-- The aim point is where the player's line of sight hits something (the game traces it),
-- so a target further away than that point is behind a wall. But the game's trace stops 5 m
-- ahead: when it has met nothing, the aim point is simply 5 m away and says nothing of what
-- lies beyond. For a target further than that, the host has the engine trace a line of its
-- own, from the player's eyes to the target (clear_line, below).
local function line_of_sight(P)
    local from = G.location(P.mec)
    local aim = U.get(P.mec, "Net Aim Target", nil)
    if not from or not aim then return nil end
    aim = U.vec_copy(aim)
    -- a character's position is at its feet; the game's camera is about 1.6 m above
    local eye = { X = from.X, Y = from.Y, Z = from.Z + EYE_HEIGHT }
    local ax, ay, az = aim.X - eye.X, aim.Y - eye.Y, aim.Z - eye.Z
    local al = math.sqrt(ax * ax + ay * ay + az * az)
    if al < 1 then return nil end
    return { eye = eye, x = ax, y = ay, z = az, len = al }
end

-- The length of the game's own view trace (cm), and whether nothing stands on the line from
-- `from` to `to`, the two characters themselves left out. It is the call the game makes for
-- the aim point (same channel), written as in the line-trace example that ships with UE4SS.
-- Should it fail, walls further than 5 m are no longer checked, and the journal says so once.
local AIM_TRACE = 500
local trace_lib, trace_warned = nil, false
local NO_COLOR = { R = 0.0, G = 0.0, B = 0.0, A = 0.0 }

local function clear_line(P, T, from, to)
    trace_lib = (U.valid(trace_lib) and trace_lib) or StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local ok, hit = pcall(function()
        return trace_lib:LineTraceSingle(P.mec, from, to, 1, false, { T.mec }, 0, {}, true, NO_COLOR, NO_COLOR, 0.0)
    end)
    if ok then return hit ~= true end
    if not trace_warned then
        trace_warned = true
        U.log("Visée : le tracé de visibilité n'a pas pu être fait (%s) ; au-delà de 5 m, les murs ne sont pas vérifiés",
            tostring(hit))
    end
    return true
end

-- The points of a player that can be looked at: from the legs to the head for the living (a
-- Rêveur's body sits); along the body for the dead, when the power takes bodies (spec.bodies:
-- the Métamorphe's). nil when this player cannot be aimed at.
local function aim_points(P, T, spec)
    if T == P or T.fairy or T.hiding then return nil end
    local out = {}
    if G.is_alive(T.mec) then
        if spec.skip_dreaming and T.dreaming then return nil end
        local at = (T.dreaming and T.dreaming.loc) or G.location(T.mec)
        if not at then return nil end
        for _, h in ipairs(T.dreaming and SEATED_HEIGHTS or BODY_HEIGHTS) do
            out[#out + 1] = { X = at.X, Y = at.Y, Z = at.Z + h }
        end
    else
        -- a body: of a player of this game, and not removed by the Nettoyeur
        if not spec.bodies or not T.camp or T.cleaned then return nil end
        local at, yaw = G.death_spot(T.mec)
        if not at then return nil end
        local r = math.rad(yaw)
        for _, d in ipairs(LYING_SPREAD) do
            out[#out + 1] = { X = at.X + d * math.cos(r), Y = at.Y + d * math.sin(r), Z = at.Z + LYING_HEIGHT }
        end
    end
    return out
end

-- Cosine of the angle between the line of sight and the target, or nil if out of reach.
local function aim_fit(P, T, sight, range, spec)
    local points = aim_points(P, T, spec)
    if not points then return nil end
    local e = sight.eye
    -- the best of the points
    local best = nil
    for _, p in ipairs(points) do
        local tx, ty, tz = p.X - e.X, p.Y - e.Y, p.Z - e.Z
        local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
        if tl >= 1 and tl <= range then
            local cos = (sight.x * tx + sight.y * ty + sight.z * tz) / (sight.len * tl)
            -- only what can be chosen is looked at further (the wider of the two cones)
            if cos >= AIM_KEEP and (not best or cos > best) then
                local seen
                if sight.len + 80 >= tl then
                    seen = true                              -- the aim point is at the target, or beyond it
                elseif sight.len < AIM_TRACE - 20 then
                    seen = false                             -- the game's trace met something before the target
                else
                    seen = clear_line(P, T, e, p)            -- further than the game's trace reaches
                end
                if seen then best = cos end
            end
        end
    end
    return best
end

local function aimed_player(P, spec, current)
    local sight = line_of_sight(P)
    if not sight then return nil end
    local range = C.get(spec.range)
    if current then
        local cos = aim_fit(P, current, sight, range, spec)
        if cos and cos >= AIM_KEEP then return current end
    end
    local best, best_cos = nil, AIM_CONE
    each_player(function(T)
        local cos = aim_fit(P, T, sight, range, spec)
        if cos and cos >= best_cos then best, best_cos = T, cos end
    end)
    return best
end

local function angel_done(P, T)
    P.protege = T.key
    game.guard_now = true                      -- the protection of the game's end starts at once (see tick_guard)
    tell(P, "MSG", "ANGEL_SET", idx(T))
    U.log("Ange gardien : %s protège %s", G.player_name(P.mec), G.player_name(T.mec))
end

local function tracker_done(P, T, now)
    P.charges = P.charges - 1
    P.tracking = { key = T.key, ends = now + C.get("tracker_duration") }
    send_spheres(P)
    tell(P, "TRACK", idx(T), U.round(C.get("tracker_duration") * 10))
    tell(P, "MSG", "TRACK_START", idx(T))
    U.log("Traqueur : %s traque %s", G.player_name(P.mec), G.player_name(T.mec))
end

local function hypnotist_done(P, T, now)
    if not T.modded then
        tell(P, "MSG", "HYPNO_IMMUNE")                 -- nothing used up
        return
    end
    P.charges = P.charges - 1
    local secs = C.get("hypno_duration")
    T.hypno_until = now + secs + 0.5
    T.closed_since = nil
    tell(T, "HYPNO", U.round(secs * 10))
    tell(P, "MSG", "HYPNO_DONE", idx(T))
    U.log("Hypnotiseur : %s ferme les yeux de %s", G.player_name(P.mec), G.player_name(T.mec))
end

local function swapper_done(P, T)
    local a, b = G.location(P.mec), G.location(T.mec)
    if not a or not b or P.dreaming or P.fairy then
        tell(P, "MSG", "SWAP_FAILED")
        return
    end
    local ya = U.get(P.mec, "Net Orientation", 0.0) + 0.0
    local yb = U.get(T.mec, "Net Orientation", 0.0) + 0.0
    P.charges = P.charges - 1
    U.tcall(P.mec, "Request TP", b, yb)
    U.tcall(T.mec, "Request TP", a, ya)
    tell(P, "MSG", "SWAP_DONE", idx(T))
    tell(T, "MSG", "SWAP_YOU")
    -- the swap's own sound: heard by the two of them, and around each of them by those nearby
    broadcast("SWAPFX", idx(P), idx(T))
    U.log("Échangeur : %s et %s échangent leurs places", G.player_name(P.mec), G.player_name(T.mec))
end

-- Métamorphe: the target's appearance for a while; the target may be a dead body (a dead
-- player's character keeps its appearance). The player's own machine is told first, so that
-- it can protect its saved appearance (see lpr_client.lua), then the look changes.
local function mimic_done(P, T, now)
    local skin = G.copy_skin(T.mec)
    local original = P.skin_original or G.copy_skin(P.mec)
    if not skin or not original then return tell(P, "MSG", "MIMIC_FAILED") end
    P.skin_original = original
    P.charges = P.charges - 1
    P.mimic = { ends = now + C.get("mimic_duration") + 0.5 }
    tell(P, "MIMIC", 1)
    -- every machine notes the colour of this player's row in the list before the look changes
    if C.get("mimic_keep_list_color") then broadcast("LOOK", idx(P), 1) end
    tell(P, "MSG", "MIMIC_START", idx(T))
    U.log("Métamorphe : %s prend l'apparence de %s%s", G.player_name(P.mec), G.player_name(T.mec),
        G.is_alive(T.mec) and "" or " (cadavre)")
    U.after(0.5, "métamorphose", function()
        if P.mimic and game.active and U.valid(P.mec) then U.try("métamorphose", G.apply_skin, P.mec, skin) end
    end)
end

local function end_mimic(P)
    if not P.mimic then return end
    P.mimic = nil
    if U.valid(P.mec) and P.skin_original then U.try("fin de métamorphose", G.apply_skin, P.mec, P.skin_original) end
    if U.valid(P.mec) then broadcast("LOOK", idx(P), 0) end
    tell(P, "MIMIC", 0)
    tell(P, "MSG", "MIMIC_END")
end

local function has_charge(P)
    if P.charges > 0 then return true end
    return false, no_use_msg(P)
end

local AIM = {
    angel     = { range = "angel_range", done = angel_done,
                  ready = function(P) if P.protege then return false, "NO_USE_LEFT" end return true end },
    tracker   = { range = "tracker_range", done = tracker_done, instant = true,
                  ready = function(P, now)
                      if P.tracking and now < P.tracking.ends then return false, "TRACK_BUSY" end
                      return has_charge(P)
                  end },
    hypnotist = { range = "hypno_range", done = hypnotist_done, skip_dreaming = true, instant = true, ready = has_charge },
    swapper   = { range = "swapper_range", done = swapper_done, skip_dreaming = true, instant = true, ready = has_charge },
    mimic     = { range = "mimic_range", done = mimic_done, bodies = true, instant = true,
                  ready = function(P)
                      if P.mimic then return false, "MIMIC_BUSY" end
                      return has_charge(P)
                  end },
}

-- Carries on what a press of the power key began. Most aimed powers act at once on the player
-- in view when the key is pressed (spec.instant; nobody in view: nothing happens, nothing is
-- used up). The Ange gardien's choice, made once and for good, is confirmed: the target is
-- looked for (for a short while), named, then has to stay in view for the configured time.
local function tick_aim(P, now)
    local spec = AIM[P.role]
    if not spec or not P.act then return end
    if not G.is_alive(P.mec) or P.dreaming or P.fairy or P.hiding then return stop_act(P) end
    local ok, why, item = spec.ready(P, now)
    if not ok then
        if why then tell(P, "MSG", why, item) end
        return stop_act(P)
    end
    local T = aimed_player(P, spec, P.aim and by_key(P.aim.key))
    -- Métamorphe: with nobody in view, the body lying right there
    if not T and spec.bodies then T = body_near(P, BODY_REACH) end
    if not T then
        if P.aim then
            P.aim.lost = P.aim.lost or now
            if now - P.aim.lost <= AIM_GAP then return end
            P.aim = nil
        end
        if now - P.act.at > (spec.instant and INSTANT_WINDOW or ACT_WINDOW) then
            tell(P, "MSG", P.announced and "TARGET_LOST" or "NO_TARGET")
            stop_act(P)
        end
        return
    end
    if not P.aim or P.aim.key ~= T.key then
        P.aim = { key = T.key, since = now }
        P.act.at = now                                      -- found: the time to look starts again
        -- each target named once per press (not when the power acts at once: its own message names it)
        if not spec.instant and P.announced ~= T.key then
            P.announced = T.key
            tell(P, "MSG", "TARGET", idx(T))
        end
    end
    P.aim.lost = nil
    if not spec.instant and now - P.aim.since < C.get("aim_hold_seconds") then return end
    stop_act(P)
    spec.done(P, T, now)
end

-- ---------------------------------------------------------------- the power key
-- Every power starts with the player's power key, except the Rêveur's (both eyes closed, see
-- on_eyes_held). Powers that need a target (a player in view, a body or an employee nearby)
-- open an attempt, P.act, which the ticks carry on; the others act at once.
-- The player's machine plays a short sound for a power that starts and another for one that
-- does not: it tells which from the messages it gets. A press refused without any message
-- is answered with "SFX fail", so that no press of a role's key is left without an answer.
local function refuse(P)
    tell(P, "SFX", "fail")
end

local function on_power(P)
    if not game.active then return end
    local now = U.now()
    local role = P.role
    if role == "revenant" then
        -- alive, or already showing itself: nothing to start
        if G.is_alive(P.mec) or (P.spirit_until and now < P.spirit_until) then return refuse(P) end
        start_spirit(P, now)
        return
    end
    if not role or role == "dreamer" then return end
    if not G.is_alive(P.mec) then return refuse(P) end
    -- eyes shut by the Hypnotiseur: no power either
    if P.hypno_until and now < P.hypno_until then return refuse(P) end
    if role == "stowaway" then
        if not P.hiding then
            start_hide(P, now)
        elseif now - P.hiding.since >= 1 then      -- not the same press, counted twice
            end_hide(P, "touche")
        end
    elseif P.dreaming or P.fairy or P.hiding then
        return
    elseif role == "fairy" then
        if P.charges >= 1 then start_fairy(P) else tell(P, "MSG", no_use_msg(P)) end
    elseif role == "medium" then
        if P.vision_until and now < P.vision_until then return refuse(P) end      -- a vision is running
        start_medium(P, now)
    elseif AIM[role] or role == "cleaner" or role == "infector" then
        if P.act then P.act.at = now else P.act = { at = now } end
    end
end

-- ---------------------------------------------------------------- deaths (Ange gardien, Liés, Martyr, Revenant)
-- The game's own resurrection: the same two calls it makes for its revive item.
local function revive(V)
    if not game.active or not U.valid(V.mec) or G.is_alive(V.mec) then return end
    local loc, yaw = G.death_spot(V.mec)
    loc = loc or G.location(V.mec)
    if not loc then return end
    U.tcall(V.mec, "Rez Effect", loc, yaw)
    U.tcall(V.mec, "All Rez Effect")
end

-- When the last living employee of its list dies, the game schedules its end 0.5 s later and
-- does not check again: a resurrection would come too late. Same test as the game's "Check
-- Deaths", on the same list, in which tick_guard writes the dissidents for as long as an
-- employee is protected: this is then true only when no dissident is alive either.
local function game_ends_with(V)
    local gm = G.gm()
    if not gm or U.get(gm, "Difficulty", 0) == 0 then return false end      -- training: never ends on deaths
    local list = U.get(gm, "Innocents", nil)
    if list == nil then return false end
    local ok, ends = pcall(function()
        local listed, other_alive = false, false
        for i = 1, #list do
            local m = list[i]
            if U.valid(m) then
                if m:GetAddress() == V.mec:GetAddress() then
                    listed = true
                elseif G.is_alive(m) then
                    other_alive = true
                end
            end
        end
        return listed and not other_alive
    end)
    return ok and ends
end

local function angel_save(V)
    local saver = nil
    each_player(function(A)
        if not saver and A.role == "angel" and A.protege == V.key and not A.saved then saver = A end
    end)
    if not saver then return false end
    if game_ends_with(V) then
        tell(saver, "MSG", "ANGEL_TOO_LATE")
        U.log("Ange gardien : %s était le dernier joueur en vie de la liste du jeu, la partie se termine",
            G.player_name(V.mec))
        return false
    end
    saver.saved = true
    U.after(0.1, "ange gardien", function() U.try("résurrection", revive, V) end)
    tell(saver, "MSG", "ANGEL_SAVED")
    tell(V, "MSG", "ANGEL_SAVED_YOU")
    U.log("Ange gardien : %s est sauvé", G.player_name(V.mec))
    return true
end

-- The game ends when every employee of its list ("Innocents") is dead. It decides so at the
-- very moment of a death and never looks again: a protégé raised a moment later would come
-- back to a game already over. So, for as long as an employee has an Ange gardien's save
-- still to come, the dissidents are written in that list too: one of them alive is enough for
-- the game to go on when the protégé dies. Nothing else in the game reads that list (it is
-- filled when the roles are drawn and read by "Check Deaths" only). They are taken out once
-- the protégé is back on their feet, or was not raised in time, and the game is then asked to
-- do its own test again with its real list.
local standins = nil           -- player key -> true: dissidents written in the game's list of employees
local last_guard = 0

-- The employee whose death must not end the game: protected and not saved yet, or saved a
-- moment ago and not yet raised. nil when there is none.
local function guarded_employee(now)
    local found = nil
    each_player(function(A)
        if found or A.role ~= "angel" or not A.protege then return end
        local V = by_key(A.protege)
        if not V or V.camp ~= "employee" then return end
        local alive = G.is_alive(V.mec)
        if not A.saved then
            if alive then found = V end
        elseif not alive and V.died_at and now - V.died_at < 5 then
            found = V
        end
    end)
    return found
end

local function tick_guard(now)
    if not game.guard_now and now - last_guard < 0.5 then return end
    last_guard, game.guard_now = now, nil
    local gm = G.gm()
    if not gm then return end
    local V = guarded_employee(now)
    if V then
        if not standins then
            standins = {}
            U.log("Ange gardien : la mort de %s ne terminera pas la partie tant qu'un dissident est en vie",
                G.player_name(V.mec))
        end
        each_player(function(T)
            if T.camp == "dissident" and not standins[T.key] then
                standins[T.key] = true             -- tried once: never a repeated error
                if not G.array_add(gm, "Innocents", T.mec) then
                    U.log("Ange gardien : %s n'a pas pu être inscrit dans la liste du jeu", G.player_name(T.mec))
                end
            end
        end)
    elseif standins then
        standins = nil
        local out = {}
        each_player(function(T)
            if T.camp ~= "employee" then out[#out + 1] = T.mec end
        end)
        G.array_drop(gm, "Innocents", out)
        U.tcall(gm, "End on Death")                -- the game's own test, with its real list again
        U.log("Ange gardien : protection de la fin de partie levée, la liste du jeu est comme avant")
    end
end

local function martyr_reveal(P, now)
    if P.role ~= "martyr" then return end
    local hit = P.last_hit
    if not hit or now - hit.at > MARTYR_WINDOW then return end
    local K = by_key(hit.by)
    if not K or K == P then return end
    if C.get("martyr_reveal") == "name" then
        broadcast("MSG", "MARTYR_NAME", idx(K))
    else
        broadcast("MSG", K.camp == "dissident" and "MARTYR_CAMP_DISSIDENT" or "MARTYR_CAMP_EMPLOYEE")
    end
    U.log("Martyr : %s tué par %s", G.player_name(P.mec), G.player_name(K.mec))
end

-- Liés: the first of the two to die takes the other along, once. After that the bond is
-- over for both: a player brought back (defibrillator, Ange gardien) who dies again no longer
-- kills the other one - who may be alive again too, raised by an Ange gardien for instance.
local function link_death(P)
    local Q = by_key(P.link)
    if not Q or P.link_done then return end
    P.link_done, Q.link_done = true, true
    P.status_sent, Q.status_sent = nil, nil    -- their pages say so at once
    if not G.is_alive(Q.mec) then return end
    if Q.dreaming then end_dream(Q, "link") end
    if Q.fairy then end_fairy(Q) end
    tell(Q, "MSG", "LINK_DEAD")
    U.log("Liés : %s meurt, %s le suit", G.player_name(P.mec), G.player_name(Q.mec))
    -- A short wait lets a dreamer or a fairy get back into their body first.
    -- The game ignores the death while the player is still a ghost on their machine, so it is
    -- asked once more a little later - only if the first request did not make them die (a
    -- protégé raised by an Ange gardien must not be killed a second time).
    local asked = U.now()
    local function kill()
        if Q.died_at and Q.died_at >= asked then return end
        if game.active and U.valid(Q.mec) and G.is_alive(Q.mec) then
            U.tcall(Q.mec, "Death", U.get(Q.mec, "Net Orientation", 0.0) + 0.0, true)
        end
    end
    U.after(0.6, "mort du lié", kill)
    U.after(1.8, "mort du lié (second essai)", kill)
end

local function on_death(P)
    P.died_at = U.now()
    P.jar_wait = nil
    if P.dreaming then end_dream(P, "death", true) end
    if P.fairy then end_fairy(P) end
    -- Restored in the same instant as the death, so the body others see shows who it was.
    end_mimic(P)
    end_hide(P, "death")
    -- The game resets a dead player's eyes without going through the hook: start afresh, so
    -- that eyes closed just before dying do not count as a gesture afterwards.
    P.eye, P.closed_since, P.hold_fired = G.EYE_OPEN, nil, true
    stop_act(P)
    P.hypno_until = nil
    if P.vision_until then
        P.vision_until = nil
        tell(P, "MEDIUM", 0, 0)
    end
    if not game.active then
        P.infected_at = nil
        return
    end
    if P.undoing then                          -- a cleaned body's revival undone: nothing else
        P.undoing = nil
        return
    end
    if angel_save(P) then return end          -- comes back: a pending recruitment still applies
    P.infected_at = nil
    U.try("martyr", martyr_reveal, P, U.now())
    U.try("liés", link_death, P)
    if P.role == "revenant" then
        -- its apparitions are given again at every death: raised then dead again, it may show itself again
        P.charges = C.get("revenant_charges")
        tell(P, "MSG", "SPIRIT_READY")
    end
    check_dissident_win()
end

-- ---------------------------------------------------------------- Shérif
-- The Shérif is no longer given an access card: one card lying somewhere in the building is
-- shown to the Shérif alone, whose machine draws a highlight where the host says the card is.
-- By default the host puts one more card down for that, at one of the game's own item places;
-- when the host does not want that, or if it fails, one of the cards the game itself has
-- spread is taken. The highlight ends when somebody picks the card up: the item is then gone.
local card = nil               -- { item, key (the Shérif's), at = { X, Y, Z }, checked }

local function card_message(P)
    local at = card.at
    tell(P, "CARD", 1, U.round(at.X), U.round(at.Y), U.round(at.Z), C.get("sheriff_card_walls") and 1 or 0)
end

-- may_place: one more card may be put down (first try only: never two cards for one Shérif)
local function show_sheriff_card(P, tries, may_place)
    if card or not game.active or not U.valid(P.mec) or P.role ~= "sheriff" then return end
    local item, placed = nil, false
    if may_place and C.get("sheriff_card_extra") then
        item = U.try("carte du shérif", G.place_item, G.ASSET_ACCESS_CARD)
        placed = item ~= nil
        if not placed then U.log("Carte du shérif : aucune carte posée en plus, une carte du jeu est cherchée") end
    end
    if not item then
        local lying = G.world_items(G.ASSET_ACCESS_CARD)
        if #lying > 0 then item = lying[math.random(#lying)] end
    end
    local at = item and G.location(item) or nil
    if not at then
        -- the game spreads its items during the first seconds: looked for a few times more
        if tries > 0 then
            U.after(2, "carte du shérif", function() show_sheriff_card(P, tries - 1, false) end)
        else
            tell(P, "MSG", "CARD_NONE")
            U.log("Carte du shérif : aucune carte d'accès dans le bâtiment")
        end
        return
    end
    card = { item = item, key = P.key, at = at, checked = U.now() }
    P.card = "shown"
    card_message(P)
    tell(P, "MSG", "CARD_SHOWN")
    U.log("Carte d'accès du shérif : %s, en surbrillance pour %s", placed and "posée en plus" or "une carte du jeu",
        G.player_name(P.mec))
end

-- The card shown to the Shérif: over once picked up; its place is told again when it has
-- moved (an item just put down falls to the floor).
local function tick_card(now)
    local c = card
    if not c then return end
    local P = by_key(c.key)
    if not P or P.role ~= "sheriff" then
        card = nil
        return
    end
    if not U.valid(c.item) then
        card = nil
        P.card = "taken"
        tell(P, "CARD", 0)
        tell(P, "MSG", "CARD_TAKEN")
        U.log("Carte d'accès du shérif : ramassée, fin de la surbrillance")
        return
    end
    if now - c.checked < 0.5 then return end
    c.checked = now
    local at = G.location(c.item)
    if at and U.dist(at, c.at) > 20 then
        c.at = at
        card_message(P)
    end
end

local function sheriff_setup(P)
    if C.get("sheriff_card") then show_sheriff_card(P, 5, true) end
    if not C.get("sheriff_safe_info") then return end
    local pool = {}
    each_player(function(T)
        if T ~= P and T.camp == "employee" then pool[#pool + 1] = T end
    end)
    if #pool == 0 then return end
    local safe = pool[math.random(#pool)]
    local secs = C.get("sheriff_marker_seconds")
    P.safe, P.marker_secs = safe.key, secs
    tell(P, "SAFE", idx(safe), U.round(secs * 10))
    if secs > 0 then
        P.marker = { key = safe.key, ends = U.now() + secs }
        send_spheres(P)
    end
    U.log("Shérif : %s ; personne sûre : %s", G.player_name(P.mec), G.player_name(safe.mec))
end

-- ---------------------------------------------------------------- role assignment
local function take(pool, accept)
    U.shuffle(pool)
    for i, P in ipairs(pool) do
        if accept(P) then
            table.remove(pool, i)
            return P
        end
    end
    return nil
end

local function camp_ok(P, wanted)
    return wanted == "any" or P.camp == wanted
end

-- mod: "need" (only players with the mod), "prefer" (them first), "any"
local function pick(pool, camp, mod)
    local function fits(X) return camp_ok(X, camp) end
    if mod == "any" then return take(pool, fits) end
    local P = take(pool, function(X) return X.modded and fits(X) end)
    if P or mod == "need" then return P end
    return take(pool, fits)
end

local function camp_of(key) return function() return C.get(key) end end
local function dissident() return "dissident" end
local function employee() return "employee" end
local function charges_from(key) return function(P) P.charges = C.get(key) end end
-- Rêveur, Fée: the charge they start with; always one when the host gave the role no item to
-- get it back with (it could never act otherwise).
local function start_charge(key) return function(P) P.charges = recharge_of(P) and C.get(key) or 1 end end

-- One entry per role. prefix: start of its settings (prefix_enabled, prefix_min_players).
local SPECS = {
    { id = "infector",  prefix = "infector", camp = dissident, mod = "prefer",
      init = function(P) P.infections_left = C.get("infect_charges") end },
    { id = "sheriff",   prefix = "sheriff",  camp = employee, mod = "any" },
    { id = "dreamer",   prefix = "dreamer",  camp = camp_of("dreamer_camp"), mod = "need", init = start_charge("dream_start_charges") },
    { id = "fairy",     prefix = "fairy",    camp = camp_of("fairy_camp"), mod = "need", init = start_charge("fairy_start_charges") },
    { id = "medium",    prefix = "medium",   camp = camp_of("medium_camp"), mod = "need", init = charges_from("medium_charges") },
    { id = "angel",     prefix = "angel",    camp = camp_of("angel_camp"), mod = "need" },
    { id = "mole",      prefix = "mole",     camp = dissident, mod = "need",
      allowed = function(count) return count.dissident >= 2 end },
    { id = "tracker",   prefix = "tracker",  camp = dissident, mod = "need", init = charges_from("tracker_charges") },
    { id = "hypnotist", prefix = "hypno",    camp = dissident, mod = "need", init = charges_from("hypno_charges") },
    { id = "mimic",     prefix = "mimic",    camp = dissident, mod = "need",
      init = function(P)
          P.charges = C.get("mimic_charges")
          P.skin_original = G.copy_skin(P.mec)          -- taken before any change
      end },
    { id = "cleaner",   prefix = "cleaner",  camp = dissident, mod = "need", init = charges_from("cleaner_charges") },
    { id = "stowaway",  prefix = "stowaway", camp = camp_of("stowaway_camp"), mod = "need", init = charges_from("stowaway_charges") },
    { id = "swapper",   prefix = "swapper",  camp = camp_of("swapper_camp"), mod = "need", init = charges_from("swapper_charges") },
    { id = "martyr",    prefix = "martyr",   camp = camp_of("martyr_camp"), mod = "prefer" },
    { id = "revenant",  prefix = "revenant", camp = camp_of("revenant_camp"), mod = "need", init = charges_from("revenant_charges") },
}
local SPEC_BY_ID = {}
for _, s in ipairs(SPECS) do SPEC_BY_ID[s.id] = s end

local function give_role(P, spec)
    P.role = spec.id
    if spec.init then spec.init(P) end
    if spec.id == "mole" then
        game.mole = true
        -- The game's player list tags fellow dissidents by their role. The Taupe is shown as an
        -- employee; it stays in the game's dissident list, which decides who wins.
        U.tcall(P.mec, "Set Player Role", G.ROLE_EMPLOYEE)
    end
end

-- Liés: a bond between two players, with the mod if possible, whose camps follow the setting.
-- Not a role: each of the two may have a role of their own (or none).
local function link_pair(everyone, first)
    local mode = C.get("linked_mode")
    local pool = {}
    for _, X in ipairs(everyone) do
        if X ~= first then pool[#pool + 1] = X end
    end
    local function partner(A, others)
        local function match(X)
            if X == A then return false end
            if mode == "mixed" then return X.camp ~= A.camp end
            if mode == "same" then return X.camp == A.camp end
            return true
        end
        return take(others, function(X) return X.modded and match(X) end) or take(others, match)
    end
    -- the first of the two: the one given, else every player in turn (those with the mod first)
    local firsts = {}
    if first then
        firsts[1] = first
    else
        U.shuffle(pool)
        for _, X in ipairs(pool) do if X.modded then firsts[#firsts + 1] = X end end
        for _, X in ipairs(pool) do if not X.modded then firsts[#firsts + 1] = X end end
    end
    for _, A in ipairs(firsts) do
        local others = {}
        for _, X in ipairs(pool) do others[#others + 1] = X end
        local B = partner(A, others)
        if B then
            A.link, B.link = B.key, A.key
            return true
        end
    end
    return false
end

local function assign_roles()
    game.assigned = true
    if not C.get("enabled") then return end
    local pool = {}
    local count = { dissident = 0, employee = 0 }
    local mine = G.local_mec()
    if mine then
        local me = player(mine, true)
        if me then me.modded = true end          -- the host runs this script, so the host has the mod
    end
    game.mole = false
    for _, mec in ipairs(G.valid_players()) do
        local P = player(mec, true)
        reset_for_game(P)
        local role = G.role_of(mec)
        if role == G.ROLE_DISSIDENT then P.camp = "dissident" elseif role == G.ROLE_EMPLOYEE then P.camp = "employee" end
        if P.camp then
            pool[#pool + 1] = P
            count[P.camp] = count[P.camp] + 1
        end
    end
    local n = #pool
    local everyone = {}                        -- the roles take players out of "pool", not out of this
    for i, P in ipairs(pool) do everyone[i] = P end
    U.log("Attribution des rôles pour %d joueurs", n)
    -- what this game is played with, for whoever reads the journal after a surprise
    U.log("  réglages : liés %s (%d joueurs minimum), rôle forcé pour l'hôte : %s, %d rôles au plus, minimums ignorés : %s",
        C.get("linked_enabled") and "OUI" or "NON", C.get("linked_min_players"),
        tostring(C.get("force_host_role")), C.get("max_roles"), C.get("ignore_min_players") and "OUI" or "NON")
    for _, P in ipairs(pool) do
        U.log("  joueur %s : %s, %s le mod", G.player_name(P.mec), P.camp, P.modded and "avec" or "SANS")
    end
    local budget = C.get("max_roles")
    local ignore_min = C.get("ignore_min_players") == true
    game.short = 0                           -- told to the host with the roles

    -- Test aid: give the host a chosen role, ignoring player counts and camps ("linked":
    -- the host is one of the two Liés, and gets a role like everybody else).
    local forced = C.get("force_host_role")
    local forced_spec = SPEC_BY_ID[forced]
    local applied = nil
    if forced_spec then
        local P = mine and player(mine, false)
        if P and P.camp then
            applied = forced_spec
            for i, X in ipairs(pool) do
                if X == P then table.remove(pool, i) break end
            end
            give_role(P, forced_spec)
            budget = budget - 1
            U.log("Rôle forcé pour l'hôte : %s", forced)
        end
    end

    -- The other roles, in a different random order every game, up to the maximum.
    local order = {}
    for _, s in ipairs(SPECS) do order[#order + 1] = s end
    U.shuffle(order)
    -- Every role switched on that nobody gets is written down with the reason.
    for _, spec in ipairs(order) do
        if budget <= 0 then break end
        if spec ~= applied and C.get(spec.prefix .. "_enabled") then
            local min = C.get(spec.prefix .. "_min_players")
            if n < min and not ignore_min then
                game.short = game.short + 1
                U.log("  %s non attribué : %d joueurs minimum, %d présents", spec.id, min, n)
            elseif spec.allowed and not spec.allowed(count) then
                U.log("  %s non attribué : pas assez de dissidents", spec.id)
            else
                local camp = spec.camp()
                local P = pick(pool, camp, spec.mod)
                if P then
                    give_role(P, spec)
                    budget = budget - 1
                else
                    U.log("  %s non attribué : aucun joueur libre (camp : %s%s)", spec.id, camp,
                        spec.mod == "need" and ", avec le mod" or "")
                end
            end
        end
    end
    -- The host is only warned when places stayed free: with the maximum reached, the roles
    -- left out for lack of players would not have been given anyway.
    if budget <= 0 then game.short = 0 end
    -- Liés, on top of the roles (it takes no place among them).
    local host = (forced == "linked") and mine and player(mine, false) or nil
    if host and host.camp then
        U.log("  liés : lien imposé par « Rôle forcé pour l'hôte », quel que soit le réglage Liés (%s)",
            C.get("linked_enabled") and "OUI" or "NON")
        if not link_pair(everyone, host) then U.log("  liés : personne à lier à l'hôte") end
    elseif C.get("linked_enabled") then
        local min = C.get("linked_min_players")
        if n < min and not ignore_min then
            game.short = game.short + 1
            U.log("  liés non attribués : %d joueurs minimum, %d présents", min, n)
        elseif not link_pair(everyone) then
            U.log("  liés non attribués : pas deux joueurs qui conviennent")
        end
    end
    each_player(function(P)
        if P.role or P.link then
            local Q = by_key(P.link)
            U.log("  %s : %s (%s)%s", G.player_name(P.mec), P.role or "aucun rôle", tostring(P.camp),
                Q and (", lié à " .. G.player_name(Q.mec)) or "")
        end
    end)
    if game.mole then correct_spheres() end
end

local function announce_roles()
    if not game.active or game.announced then return end
    game.announced = true
    each_player(function(P)
        if not P.role then
            tell(P, "ROLE", "none")
            return
        end
        tell(P, "ROLE", P.role)
        if P.role == "sheriff" then U.try("shérif", sheriff_setup, P) end
    end)
    each_player(function(P)
        local Q = by_key(P.link)
        if Q then tell(P, "MSG", "LINKED_TO", idx(Q)) end
    end)
    -- The host is told what would otherwise go unnoticed: roles switched on that nobody got
    -- for lack of players, and players whose machine has not answered as having the mod.
    local mine = G.local_mec()
    local me = mine and player(mine, false)
    if me then
        if (game.short or 0) > 0 then tell(me, "MSG", "HOST_SHORT", game.short) end
        local no_mod = 0                       -- counted now: an answer may have come since
        for _, mec in ipairs(G.valid_players()) do
            local P = player(mec, false)
            if P and not P.modded then no_mod = no_mod + 1 end
        end
        if no_mod > 0 then tell(me, "MSG", "HOST_NO_MOD", no_mod) end
    end
end

-- ---------------------------------------------------------------- game start / end
-- True once every player's machine has said it has the mod (the host's own counts as said).
local function all_answered()
    local mine = G.local_mec()
    for _, mec in ipairs(G.valid_players()) do
        local P = player(mec, true)
        local own = mine and mec:GetAddress() == mine:GetAddress()
        if P and not P.modded and not own then return false end
    end
    return true
end

local function on_game_start()
    game.active, game.started_at, game.announced, game.converted = true, U.now(), false, false
    game.assigned, game.short = false, 0
    standins, game.guard_now = nil, nil        -- the game empties its list of employees at every start
    each_player(function(P) reset_for_game(P) end)
    recount_frozen()
    -- Ask every machine to say whether it has the mod. Roles are picked as soon as all have
    -- answered, and 1.5 s later at the latest (a slow answer no longer costs a player the
    -- roles that need the mod).
    for _, mec in ipairs(G.all_mecs()) do N.send(mec, "HELLO") end
    local started = game.started_at
    local function try_assign(last)
        if game.assigned or not game.active or game.started_at ~= started then return end
        if last or all_answered() then U.try("attribution", assign_roles) end
    end
    for _, delay in ipairs({ 0.5, 0.8, 1.1 }) do
        U.after(delay, "attribution des rôles", function() try_assign(false) end)
    end
    U.after(1.5, "attribution des rôles", function() try_assign(true) end)
    U.after(C.get("announce_delay"), "annonce des rôles", function() U.try("annonce", announce_roles) end)
end

local function reveal_roles()
    local parts = {}
    each_player(function(P)
        if P.role then parts[#parts + 1] = P.role .. ":" .. tostring(idx(P)) end
    end)
    -- a bond is told once, with both players
    each_player(function(P)
        local Q = by_key(P.link)
        if Q then
            if idx(P) < idx(Q) then
                parts[#parts + 1] = "pair:" .. tostring(idx(P)) .. ":" .. tostring(idx(Q))
            end
        elseif P.link then
            parts[#parts + 1] = "linked:" .. tostring(idx(P))      -- the other one has left the game
        end
    end)
    if #parts > 0 then broadcast("REVEAL", table.concat(parts, ",")) end
end

local function on_game_end()
    if not game.active then return end
    game.active = false
    U.log("Fin de partie : remise à zéro des rôles")
    each_player(function(P)
        if P.dreaming then end_dream(P, "end") end
        if P.fairy then end_fairy(P) end
        end_mimic(P)
        end_hide(P, "end")
    end)
    card = nil                                  -- the players' machines drop the highlight with "END"
    standins = nil
    broadcast("END")                            -- stops visions, hypnosis and everything still running
    -- no sphere left over anybody's head in the lobby (markers, recruits made dissidents)
    each_player(function(P) U.tcall(P.mec, "Clear Hacker Sphere") end)
    if C.get("reveal_roles_at_end") then U.try("révélation", reveal_roles) end
    each_player(function(P)
        local tail = P.tail
        reset_for_game(P)
        P.tail = tail
    end)
    game.mole = false
    recount_frozen()
end

-- ---------------------------------------------------------------- messages from the players, and the eyes
local function handle_opcode(P, op)
    if op == N.OP_HELLO then
        if not P.modded then
            P.modded = true
            U.log("%s a le mod%s", G.player_name(P.mec),
                (game.active and game.assigned) and " (reconnu après l'attribution des rôles de cette partie)" or "")
            N.send(P.mec, "ACK", U.VERSION)
            if game.active and game.announced then
                tell(P, "ROLE", P.role or "none")
                P.status_sent = nil
                local S = P.role == "sheriff" and by_key(P.safe) or nil
                if S then
                    local marked = P.marker and math.max(0, P.marker.ends - U.now()) or 0
                    tell(P, "SAFE", idx(S), U.round(marked * 10))
                end
                if card and card.key == P.key then card_message(P) end
            end
        end
    elseif op == N.OP_ACT then
        -- from a sleeping Rêveur's machine: "my dream ended on my side"; otherwise the power key
        if P.dreaming then
            end_dream(P, "damage", true)
        else
            U.try("touche de pouvoir", on_power, P)
        end
    elseif op == N.OP_USE then
        U.try("consommer", on_use, P)
    end
    force_eye(P.mec, (P.dreaming and G.EYE_CLOSED) or P.eye or G.EYE_OPEN)
end

local function on_eye(mec, value)
    if guard_eye then return end
    local P = player(mec, true)
    if not P then return end
    if value >= N.OP_MIN then return handle_opcode(P, value) end
    local now = U.now()
    P.eye = value
    local closed = (value == G.EYE_CLOSED or value == G.EYE_LOCK)
    if closed then
        if not P.closed_since then P.closed_since, P.hold_fired = now, false end
    else
        P.closed_since = nil
    end

    if P.dreaming then
        if not closed then
            P.dreaming.opened = true
        elseif P.dreaming.opened then
            return end_dream(P, "eyes")
        end
        force_eye(mec, G.EYE_CLOSED)            -- the sleeping body keeps its eyes shut
        return
    end

    -- Eyes shut by the Hypnotiseur: not the Rêveur's gesture.
    if P.hypno_until and now < P.hypno_until then P.closed_since = nil end
end

-- ---------------------------------------------------------------- role status sent to each player
-- Uses left, effect running, target, and the settings the role plays with. Sent as integers
-- ("k=v,..."): seconds and metres in tenths, players as index + 1.
local TENTHS = { hold = true, aim = true, dur = true, delay = true, marker = true,
                 ihold = true, chold = true, act = true, wait = true, conv = true, range = true,
                 reach = true }

local function metres(key)
    return C.get(key) / 100
end

local function left(now, ends)
    if ends and ends > now then return math.ceil(ends - now) end
    return nil
end

local function who(key)
    local T = by_key(key)
    return T and (idx(T) + 1) or nil
end

local function status_of(P, now)
    local r = P.role
    local v = { hold = C.get("dream_hold_seconds"), aim = C.get("aim_hold_seconds") }
    local function uses(max_key) v.n, v.m = P.charges, C.get(max_key) end
    if r == "sheriff" then
        v.card = P.card == "shown" and 1 or 0
        v.walls = (P.card == "shown" and C.get("sheriff_card_walls")) and 1 or 0
        v.taken = P.card == "taken" and 1 or 0
        v.info = P.safe and 1 or 0
        v.marker = P.safe and P.marker_secs or 0
        v.safe = who(P.safe)
        v.imm = C.get("sheriff_immune") and 1 or 0
    elseif r == "infector" then
        v.n, v.m = P.infections_left, C.get("infect_charges")
        v.range = metres("infect_range")
        v.ihold, v.delay = C.get("infect_hold_seconds"), C.get("infect_delay_seconds")
        v.early = C.get("infect_min_game_seconds")
        v.imm = C.get("sheriff_immune") and 1 or 0
        v.wait = left(now, game.started_at + C.get("infect_min_game_seconds"))
        each_player(function(T)
            if T.infected_by == P.key and T.infected_at then
                v.tgt, v.conv = idx(T) + 1, left(now, T.infected_at)
            end
        end)
    elseif r == "dreamer" then
        v.n, v.m = P.charges, 1
        v.dur = C.get("dream_duration")
        v.eyes = C.get("recharge_by_eyes") and 1 or 0
        v.act = P.dreaming and left(now, P.dreaming.ends)
    elseif r == "fairy" then
        v.n, v.m = P.charges, 1
        v.dur = C.get("fairy_duration")
        local ball, light = C.get("fairy_ball"), C.get("fairy_light")
        v.ball = ball and 1 or 0
        v.glow = (light and not ball) and 1 or 0
        v.unseen = (not light and not ball) and 1 or 0
        v.act = P.fairy and left(now, P.fairy.ends)
    elseif r == "medium" then
        uses("medium_charges")
        v.dur, v.act = C.get("medium_duration"), left(now, P.vision_until)
    elseif r == "angel" then
        v.range = metres("angel_range")
        v.tgt, v.saved = who(P.protege), P.saved and 1 or 0
    elseif r == "tracker" then
        uses("tracker_charges")
        v.dur, v.range = C.get("tracker_duration"), metres("tracker_range")
        if P.tracking then v.act, v.tgt = left(now, P.tracking.ends), who(P.tracking.key) end
    elseif r == "hypnotist" then
        uses("hypno_charges")
        v.dur, v.range = C.get("hypno_duration"), metres("hypno_range")
    elseif r == "mimic" then
        uses("mimic_charges")
        v.dur, v.range = C.get("mimic_duration"), metres("mimic_range")
        v.reach = BODY_REACH / 100
        v.act = P.mimic and left(now, P.mimic.ends - 0.5)     -- without the half second before the change
        v.keep = C.get("mimic_keep_list_color") and 1 or 0
    elseif r == "cleaner" then
        uses("cleaner_charges")
        v.range, v.chold = metres("cleaner_range"), C.get("cleaner_hold")
    elseif r == "stowaway" then
        uses("stowaway_charges")
        v.dur, v.range = C.get("stowaway_duration"), metres("stowaway_range")
        v.act = P.hiding and left(now, P.hiding.ends)
    elseif r == "swapper" then
        uses("swapper_charges")
        v.range = metres("swapper_range")
    elseif r == "martyr" then
        v.reveal = (C.get("martyr_reveal") == "name") and 1 or 0
    elseif r == "revenant" then
        uses("revenant_charges")
        v.dur = C.get("revenant_duration")
        v.dead = G.is_alive(P.mec) and 0 or 1
        if v.dead == 0 then v.n = v.m end          -- alive: what the next death will give
        v.act = left(now, P.spirit_until)
    end
    -- the item that gives a use back, and what is left of the host's limit
    local item = recharge_of(P)
    if item then
        v.item = item
        local limit = C.get("recharge_limit")
        if limit > 0 then v.rmax, v.rleft = limit, math.max(0, limit - P.recharges) end
    else
        v.eyes = nil
    end
    if P.link then
        if P.link_done then v.exlink = who(P.link) else v.link = who(P.link) end
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local x = v[k]
        if type(x) == "number" then
            if TENTHS[k] then x = x * 10 end
            parts[#parts + 1] = k .. "=" .. tostring(math.floor(x + 0.5))
        end
    end
    return table.concat(parts, ",")
end

-- Sent when it changed (checked every second, so running effects count down). A player's
-- first one goes at once: the role's page has nothing to show before it.
local last_status = 0
local function send_statuses(now)
    local due = now - last_status >= 1
    if due then last_status = now end
    each_player(function(P)
        if not (P.role or P.link) or not P.modded then return end
        if not due and P.status_sent then return end
        local s = status_of(P, now)
        if s ~= P.status_sent then
            P.status_sent = s
            tell(P, "STATUS", P.role or "none", s)
        end
    end)
end

-- ---------------------------------------------------------------- periodic work (10 times per second)
local last_prune = 0
local function prune()
    for key, P in pairs(players) do
        if not U.valid(P.mec) then players[key] = nil end
    end
    recount_frozen()
end

local function tick_timers(P, now)
    if P.dreaming and now >= P.dreaming.ends then end_dream(P, "timeout") end
    if P.fairy and now >= P.fairy.ends then end_fairy(P) end
    if P.tracking and now >= P.tracking.ends then
        P.tracking = nil
        send_spheres(P)
        tell(P, "TRACK", -1, 0)
        tell(P, "MSG", "TRACK_END")
    end
    if P.mimic and now >= P.mimic.ends then end_mimic(P) end
    if P.hiding and now >= P.hiding.ends then end_hide(P, "timeout") end
    if P.marker and now >= P.marker.ends then
        P.marker = nil
        send_spheres(P)
    end
    if P.vision_until and now >= P.vision_until then P.vision_until = nil end
    if P.spirit_until and now >= P.spirit_until then P.spirit_until = nil end
    if P.hypno_until and now >= P.hypno_until then P.hypno_until = nil end
    if P.jar_wait then
        U.try("bocal vidé", jar_emptied, P)
        jar_timeout(P, now)
    end
end

local function tick(now)
    if not G.is_host() then return end
    if now - last_prune > 5 then last_prune = now prune() end
    if game.active and not G.in_game() and now - game.started_at > 3 then on_game_end() end
    if frozen_count > 0 then
        local expired = false
        each_player(function(P)
            if P.tail and now >= P.tail.ends then expired = true end
        end)
        if expired then recount_frozen() end
    end
    if not game.active then return end
    local hold = C.get("dream_hold_seconds")
    each_player(function(P)
        if P.closed_since and not P.hold_fired and now - P.closed_since >= hold then
            P.hold_fired = true
            U.try("geste des yeux", on_eyes_held, P)
        end
        tick_timers(P, now)
        if P.role == "infector" then U.try("recruteur", tick_infector, P, now) end
        if P.role == "cleaner" then U.try("nettoyeur", tick_cleaner, P, now) end
        if AIM[P.role] then U.try("visée", tick_aim, P, now) end
        if P.infected_at and now >= P.infected_at then U.try("conversion", convert, P) end
    end)
    U.try("carte du shérif", tick_card, now)
    U.try("ange gardien", tick_guard, now)
    if game.announced then U.try("état des rôles", send_statuses, now) end
end

-- ---------------------------------------------------------------- hooks
local function hook(class_path, fname, fn)
    U.hook(G.fn_path(class_path, fname), fn)
end

function Sv.install()
    hook(G.PATH_MEC, "Net Eye State", function(ctx, state)
        on_eye(ctx:get(), state:get())
    end)
    hook(G.PATH_MEC, "Net Set Stance", function(ctx)
        if guard_stance or frozen_count <= 0 then return end
        local P = player(ctx:get(), false)
        if P and P.dreaming then force_stance(P.mec, G.STANCE_SIT) end
    end)
    -- A player's machine tells the host the new state of the item in hand (a jar emptied).
    hook(G.PATH_MEC, "Net Set Item State", function(ctx)
        local P = player(ctx:get(), false)
        if P and P.jar_wait and game.active then U.try("bocal vidé", jar_emptied, P) end
    end)
    -- The game takes the item out of the hand (put in a slot): a jar awaited is no longer
    -- there to be emptied.
    hook(G.PATH_MEC, "Net Let Item", function(ctx)
        local P = player(ctx:get(), false)
        if P then P.jar_wait = nil end
    end)
    hook(G.PATH_MEC, "Net Request TP", function(ctx)
        local P = player(ctx:get(), false)
        if P and P.tail then
            P.tail = nil
            recount_frozen()
        end
    end)
    -- Called on the attacker's character, with the victim as first parameter.
    hook(G.PATH_MEC, "Net Deal Damage", function(ctx, victim)
        local v = victim:get()
        if not U.valid(v) then return end
        local P = player(v, false)
        if not P then return end
        local A = player(ctx:get(), false)
        if A and A ~= P then P.last_hit = { by = A.key, at = U.now() } end
        if P.dreaming then end_dream(P, "attacked") end
    end)
    hook(G.PATH_MEC, "Net Death", function(ctx)
        local P = player(ctx:get(), false)
        if P then on_death(P) end
    end)
    hook(G.PATH_MEC, "Net Rez", function(ctx)
        local P = player(ctx:get(), false)
        if not P then return end
        if P.spirit_until then                     -- a Revenant raised while showing itself: that is over
            P.spirit_until = nil
            broadcast("SPIRIT", idx(P), 0)
        end
        if P.cleaned and game.active then undo_revival(P) end
    end)
    hook(G.PATH_GM, "Select Game Roles", function() on_game_start() end)
    hook(G.PATH_GM, "End Game", function() on_game_end() end)
    -- Only when the game shows the spheres: when it clears them (end of the game), putting
    -- them back left red spheres over the heads in the lobby.
    hook(G.PATH_GM, "Set HackerSphere", function(_, clear)
        local ok, cleared = pcall(function() return clear:get() end)
        if ok and cleared == true then return end
        U.try("sphères", correct_spheres)
    end)
    U.every_tick("hôte", tick)
    U.log("Partie hôte prête")
end

-- Used by the menu to show how many players have the mod.
function Sv.modded_count()
    local n, total = 0, 0
    each_player(function(P)
        if G.role_of(P.mec) ~= G.ROLE_NONE then
            total = total + 1
            if P.modded then n = n + 1 end
        end
    end)
    return n, total
end

return Sv
