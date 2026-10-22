-- LPRoles - what the random events do to the players' bodies (lpr_ev.lua): pushed, stopped,
-- made to drop what they hold or searched, tired and exhausted, frozen in place, kept from
-- acting (a truce), caught in a blast or hit, a veil of colour or a flash on the screen,
-- killed with a cause; and an explosion's effects.
-- [H] the host's part. A character's life and stamina live on its player's own machine (the
-- game trusts each machine with them): what only that machine can do is sent to it
-- ("EVBODY", then [T]); the game's own client calls ("Hit Health", "Get Explosion", "Loose
-- Item", "Interaction CD"...) also reach players without the mod.
-- [T] the player's machine, on the host's word. Nothing is done there while the local
-- character is dead or a ghost of its own for a while (a dreaming Rêveur, a flying Fée).
-- [A] every machine ("EVFX": an explosion's fireball, sounds and shake).
local U = require("lpr_util")
local G = require("lpr_game")
local A = require("lpr_audio")
local K = require("lpr_marks")
local W = require("lpr_ev_world")

local B = {}

-- The game's own effects of an explosion (Explosion_C 0x04fe, 0x05fc, 0x06a9).
B.FX = {
    NIAGARA  = "/Game/World/Explosion/Niagara_Explosion.Niagara_Explosion",
    GAS      = "/Game/World/Tasks/Task_Machine/MS_GazExplosion.MS_GazExplosion",
    C4       = "/Game/World/Explosion/MS_C4_Explosion.MS_C4_Explosion",
    ECHO     = "/Game/Items/MS_DetonationEcho.MS_DetonationEcho",
    ATT_SHOT = "/Game/Audio/Spatialization/Att_Shot.Att_Shot",
    ATT_ECHO = "/Game/Audio/Spatialization/Att_ShotEcho.Att_ShotEcho",
    -- the defibrillator's discharge, with the attenuation of a blow (a sound a module may use)
    REZ        = "/Game/Items/Melee/Rez/MS_Rez.MS_Rez",
    ATT_DAMAGE = "/Game/Audio/Spatialization/Att_Damage.Att_Damage",
}
local FX_REACH = 1500        -- cm: shaken and dazzled within this distance of an explosion

-- What lpr_ev.lua lends on the host: tell(P, cmd, ...), broadcast(cmd, ...), wake(P, why),
-- game (lpr_server.lua's state of the game).
local env = nil

function B.setup(e)
    env = e
end

local function tell(P, ...)
    if env and P and U.valid(P.mec) then env.tell(P, ...) end
end

-- A colour: a name of K.COLORS, or { r, g, b } (0 to 1).
local function color_of(c)
    if type(c) == "table" then return c end
    return K.COLORS[c] or K.COLORS.white
end

local function pct(v)
    return U.round((v or 0) * 100)
end

-- ---------------------------------------------------------------- [H] the game's own gestures
-- A push without harm: the game's "Hit Health" (client call) with no damage. A negative Stun
-- pushes towards Orientation + 180 at up to 800 cm/s (clamp(|Stun|^0.7)); a positive one stops
-- (Mec 0x39567-0x39944). yaw: the way the player goes, in degrees (away from Q:
-- math.deg(math.atan(P.Y - Q.Y, P.X - Q.X))); strength: 0 to 1 (0.3 is weak).
function B.push(P, yaw, strength)
    U.tcall(P.mec, "Hit Health", 0, -math.abs(strength or 0.3) + 0.0, (yaw or 0) - 180.0)
end

-- A sudden stop.
function B.halt(P)
    U.tcall(P.mec, "Hit Health", 0, 0.8, 0.0)
end

-- The item in hand thrown down, as the game throws it ("Loose Item", client call).
function B.drop(P)
    U.tcall(P.mec, "Loose Item", 120.0)
end

-- "Net Can Interact": the game's half of "may act" that the host can hold (the other half,
-- "Local Can Interact", is the player's machine's). Held by a truce and by a freeze of the
-- actions: true is given back only when nothing holds it any more.
local holds = {}             -- player key -> number of holds

function B.hold_interact(P)
    local n = holds[P.key] or 0
    holds[P.key] = n + 1
    if n == 0 then U.tcall(P.mec, "Set Net Can Interact", false) end
end

function B.release_interact(P)
    local n = holds[P.key] or 0
    if n <= 0 then return end
    if n == 1 then
        holds[P.key] = nil
        U.tcall(P.mec, "Set Net Can Interact", true)
    else
        holds[P.key] = n - 1
    end
end

-- A new game: nothing held any more.
function B.reset_holds()
    holds = {}
end

-- A truce: no blow, shot, throw, pick-up, put-down or switch of item for secs (the game's
-- "Interaction CD", whose delay gives "Local Can Interact" back by itself), and "Net Can
-- Interact" held until B.truce_end. Walking and talking stay free.
function B.truce(P, secs)
    U.tcall(P.mec, "Interaction CD", (secs or 1) + 0.0, false)
    B.hold_interact(P)
end

function B.truce_end(P)
    U.tcall(P.mec, "Interaction CD", 0.05, false)          -- the game's own delay ends at once
    B.release_interact(P)
end

-- Frozen in place on the player's own machine for secs (move: no walking; act: no action,
-- "Net Can Interact" held too). Without the mod, only the actions are held.
function B.freeze(P, secs, move, act)
    tell(P, "EVBODY", "freeze", 1, move and 1 or 0, act and 1 or 0, U.round((secs or 0) * 10))
    if act then B.hold_interact(P) end
end

function B.unfreeze(P, act)
    tell(P, "EVBODY", "freeze", 0)
    if act then B.release_interact(P) end
end

-- Exhausted: the item in hand drops, the player staggers and cannot act for a moment (the
-- game's "Set Exhausted"). Without the mod: the item thrown down and a sudden stop.
function B.exhaust(P)
    if P.modded then
        tell(P, "EVBODY", "exhaust")
    else
        B.drop(P)
        B.halt(P)
    end
end

-- Tired by n (stamina, never up to the life: tiredness past the life would be dealt as
-- damage, Mec 0x39126), the game's own recovery held for `hold` seconds ("Stun Stamina");
-- exhausted at the cap. With the mod only.
function B.tire(P, n, hold)
    if P.modded then tell(P, "EVBODY", "tire", U.round(n or 0), U.round((hold or 0) * 10)) end
end

-- A search: what the player holds (weapon codes, W.weapon_code: 0 for any other item, nil for
-- nothing), then the item in hand thrown down and the bag's dropped at the feet.
function B.search(P)
    local hand = G.hand_item_data(P.mec)
    local bag = G.bag_item_data(P.mec)
    local out = { hand = hand and W.weapon_code(hand) or nil, bag = bag and W.weapon_code(bag) or nil }
    if bag then W.drop_bag(P.mec, true) end
    if hand then B.drop(P) end
    return out
end

-- ---------------------------------------------------------------- [H] blast and blows
-- victims: { { P, d (cm from the blast to the body + 140), at (the body) } } (lpr_ev.lua picks
-- them: present players within reach). opts: lethal (the game's own "Get Explosion": walls
-- protect, damage down to 0 at `range`, may kill), floor (life always left otherwise, 10),
-- push (strongest push otherwise, 0 to 1), fx ("gas" or "c4": the effects for all).
-- Not lethal: the player's machine works out the same blast, with its life kept above floor
-- (EVBODY "hurt"); without the mod, the push alone (the host does not know that player's life).
function B.blast(at, range, hp, opts, victims)
    opts = opts or {}
    local push = opts.push or 1
    for _, v in ipairs(victims or {}) do
        local P = v.P
        if opts.lethal then
            U.tcall(P.mec, "Get Explosion", { X = at.X + 0.0, Y = at.Y + 0.0, Z = at.Z + 0.0 }, range + 0.0, math.floor(hp), 0)
        elseif P.modded then
            tell(P, "EVBODY", "hurt", U.round(at.X), U.round(at.Y), U.round(at.Z), U.round(range), math.floor(hp),
                math.floor(opts.floor or 10), pct(push))
        else
            local share = math.max(0, 1 - (math.min(v.d, range) / range) ^ 2)
            B.push(P, math.deg(math.atan(v.at.Y - at.Y, v.at.X - at.X)), push * share)
        end
    end
    if opts.fx and env then env.broadcast("EVFX", opts.fx, U.round(at.X), U.round(at.Y), U.round(at.Z)) end
end

-- A blow with no direction: hp taken (lethal: may kill; otherwise floor kept), then a stop of
-- strength `stun` (0.8 by default). Without the mod and not lethal: the stop alone.
function B.hurt(P, hp, opts)
    opts = opts or {}
    local stun = opts.stun or 0.8
    if opts.lethal then
        U.tcall(P.mec, "Take Damage", 0, math.floor(hp), 0, stun + 0.0, 1000.0)
    elseif P.modded then
        tell(P, "EVBODY", "harm", math.floor(hp), math.floor(opts.floor or 10), pct(stun))
    else
        B.halt(P)
    end
end

-- A veil of colour on the player's screen (its "Vignette Color", written again ten times a
-- second: the game takes it back to white by itself afterwards). pulse: rather short flashes
-- of that colour now and then (the game pulls the veil back to white between two of the mod's
-- writes, which may make it flicker: to be seen in game). color nil: off.
function B.tint(P, color, pulse)
    if not P.modded then return end
    if color == nil then
        tell(P, "EVBODY", "tint", "-")
        return
    end
    local c = color_of(color)
    tell(P, "EVBODY", "tint", pct(c[1]), pct(c[2]), pct(c[3]), pulse and 1 or 0)
end

-- A flash of colour (the game's "Color Effect": the colour is added to the screen's for a
-- moment, aberration 10 by default; 4 is lighter).
function B.flash(P, color, aberration)
    if not P.modded then return end
    local c = color_of(color)
    tell(P, "EVBODY", "flash", pct(c[1]), pct(c[2]), pct(c[3]), U.round((aberration or 10) * 10))
end

-- The game's own explosion (Explosion_C), made on the host as a gas bottle makes it
-- (BottleSlot 0x0082-0x013a): created in two steps with its Type in between (0 gas, 1 C4),
-- then its multicast "All Explosion". Only the host's copy deals damage (HasAuthority, 0x034c):
-- "Get Explosion(…, 3000, 100, 300)" to every character within 35 m. It removes itself.
function B.game_explosion(at, kind)
    local cls = StaticFindObject(W.PATH_EXPLOSION)
    if not U.valid(cls) then
        pcall(LoadAsset, W.PATH_EXPLOSION)
        cls = StaticFindObject(W.PATH_EXPLOSION)
    end
    local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local gm = G.gm()
    if not (U.valid(cls) and U.valid(gs) and gm and at) then
        U.log("Évènements : explosion du jeu impossible (%s)", U.valid(cls) and "élément introuvable" or "classe introuvable")
        return false
    end
    local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 },
                Translation = { X = at.X + 0.0, Y = at.Y + 0.0, Z = at.Z + 0.0 },
                Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
    return U.try("explosion du jeu", function()
        local made = gs:BeginDeferredActorSpawnFromClass(gm, cls, t, 0, nil, 1)
        if not U.valid(made) then return false end
        U.set(made, "Type", math.floor(kind or 0))
        local actor = gs:FinishSpawningActor(made, t, 1)
        if not U.valid(actor) then actor = made end
        U.tcall(actor, "All Explosion")
        return true
    end) == true
end

-- ---------------------------------------------------------------- [H] deaths
-- The cause of a death an event brings about, for the summary ("meurt (fuite de gaz)") and so
-- that no blow just before counts as a kill (lpr_server.lua reads EV.CAUSES). Written only when
-- the player has no cause already (a poison, a bond), and taken back after secs if the player
-- did not die meanwhile.
function B.cause(P, cause, secs)
    if not U.valid(P.mec) or P.death_cause ~= nil then return false end
    P.death_cause = cause
    U.after(secs or 3, "cause de mort", function()
        if P.death_cause == cause and U.valid(P.mec) and G.is_alive(P.mec) then P.death_cause = nil end
    end)
    return true
end

-- Kills a player, with a cause. opts: no_save (the Ange gardien does not raise this one),
-- body (false: no body left where the player was, the game puts it far away: Mec 0x64f5).
-- The player is woken first (a dreaming Rêveur, a flying Fée, a hidden Clandestin: the game
-- ignores a death asked while the player is a ghost on its machine), then the death is asked at
-- 0.6 s and again at 1.8 s (as for the Liés). Still alive at 3 s: the cause and no_save go.
function B.kill(P, cause, opts)
    opts = opts or {}
    if not (env and U.valid(P.mec) and G.is_alive(P.mec)) then return false end
    if opts.no_save then P.no_save = true end
    if P.death_cause == nil then P.death_cause = cause end
    if env.wake then U.try("réveil avant la mort", env.wake, P, "event") end
    local asked = U.now()
    local game = env.game
    local started = game.started_at
    local body = opts.body ~= false
    local function death()
        if P.died_at and P.died_at >= asked then return end
        if game.active and game.started_at == started and U.valid(P.mec) and G.is_alive(P.mec) then
            U.tcall(P.mec, "Death", (U.get(P.mec, "Net Orientation", 0.0) or 0.0) + 0.0, body)
        end
    end
    U.after(0.6, "mort (évènement)", death)
    U.after(1.8, "mort (évènement, second essai)", death)
    U.after(3, "mort (évènement)", function()
        P.no_save = nil                         -- the death, if any, is over: the next one is an ordinary one
        if P.death_cause == cause and U.valid(P.mec) and G.is_alive(P.mec) then P.death_cause = nil end
    end)
    return true
end

-- ---------------------------------------------------------------- [T] on the player's machine
local is_ghost = function() return false end      -- the local player is a ghost of its own for a while
local frozen = nil           -- { ends, move, act, applied }
local veil = nil             -- { r, g, b, pulse, next }
local trace_lib = nil
local NO_COLOR = { R = 0.0, G = 0.0, B = 0.0, A = 0.0 }

function B.client_setup(ghost_fn)
    is_ghost = ghost_fn or is_ghost
end

-- The local character, if alive and not a ghost of its own.
local function me_alive()
    local mec = G.local_mec()
    if mec and G.is_alive(mec) and not is_ghost() then return mec end
    return nil
end

local function unlock(mec, f)
    if not mec then return end
    if f.move then U.set(mec, "Lock Movements", false) end
    if f.act then U.set(mec, "Local Can Interact", true) end
end

-- (Giving the actions back may also end a lock the game itself had put, a terminal's or a
-- short wait of its own: the game puts those back when it needs them. A hidden Clandestin's own
-- lock is put back by lpr_client.lua's next tick.)
local function release_freeze()
    local f = frozen
    frozen = nil
    if f and f.applied then unlock(G.local_mec(), f) end
end

local function exhaust(mec)
    if U.get(mec, "Exhausted", false) == true then
        U.tcall(mec, "Loose Item", 120.0)      -- already exhausted: "Set Exhausted" would do nothing (0x000e)
        return
    end
    U.set(mec, "Stamina", (U.get(mec, "Health", 100) or 100) + 0.0)
    U.tcall(mec, "Set Exhausted", true)
end

local function tire(mec, n, hold)
    local hp = U.get(mec, "Health", 100) or 100
    local st = U.get(mec, "Stamina", 0) or 0
    local new = math.min(hp - 1, st + n)
    if new > st then U.set(mec, "Stamina", new + 0.0) end
    if hold > 0 then U.tcall(mec, "Stun Stamina", hold + 0.0) end
    if new >= hp - 1 and U.get(mec, "Exhausted", false) ~= true then U.tcall(mec, "Set Exhausted", true) end
end

-- The blast as the game's "Get Explosion" works it out (Mec 0x36f51-0x373ef), life kept above
-- floor: nothing if a wall stands between the blast and the body (+140 cm, channel 6) or beyond
-- the range; damage hp·(1-d/R)³; push -(1-(d/R)²), at most `push`; away from the blast.
local function hurt(mec, at, range, hp, floor, push)
    local p = G.location(mec)
    if not p or range <= 0 then return end
    local body = { X = p.X, Y = p.Y, Z = p.Z + 140 }
    local d = U.dist(at, body)
    if d >= range then return end
    trace_lib = (U.valid(trace_lib) and trace_lib) or StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local ok, hit = pcall(function()
        return trace_lib:LineTraceSingle(mec, at, body, 6, false, {}, 0, {}, true, NO_COLOR, NO_COLOR, 0.0)
    end)
    if ok and hit == true then return end
    local k = 1 - d / range
    local dmg = math.floor(hp * k ^ 3)
    local health = U.get(mec, "Health", 100) or 100
    dmg = math.max(0, math.min(dmg, health - floor))
    local stun = -math.min(push, 1 - (d / range) ^ 2)
    local yaw = math.deg(math.atan(at.Y - body.Y, at.X - body.X))
    U.tcall(mec, "Take Damage", 0, dmg, 0, stun + 0.0, yaw + 0.0)
end

local function harm(mec, hp, floor, stun)
    local health = U.get(mec, "Health", 100) or 100
    local dmg = math.max(0, math.min(hp, health - floor))
    U.tcall(mec, "Take Damage", 0, dmg, 0, stun + 0.0, 1000.0)
end

local function num(v, default)
    return tonumber(v) or default or 0
end

-- The host's "EVBODY what args...".
function B.on_body(what, a, b, c, d, e, f, g)
    if what == "freeze" then
        release_freeze()
        if a == "1" then frozen = { ends = U.now() + num(d) / 10, move = b == "1", act = c == "1" } end
        return
    end
    if what == "tint" then
        if a == "-" or a == nil then
            veil = nil
        else
            veil = { r = num(a) / 100, g = num(b) / 100, b = num(c) / 100, pulse = d == "1", next = 0 }
        end
        return
    end
    local mec = me_alive()
    if not mec then return end
    if what == "exhaust" then
        exhaust(mec)
    elseif what == "tire" then
        tire(mec, num(a), num(b) / 10)
    elseif what == "hurt" then
        hurt(mec, U.vec(num(a), num(b), num(c)), num(d), num(e), num(f, 10), num(g, 100) / 100)
    elseif what == "harm" then
        harm(mec, num(a), num(b, 10), num(c, 80) / 100)
    elseif what == "flash" then
        U.tcall(mec, "Color Effect", num(d, 100) / 10, { R = num(a) / 100, G = num(b) / 100, B = num(c) / 100, A = 0.0 })
    end
end

-- A veil asked by a module on this machine only (cx.tint): { r, g, b } or nil.
function B.local_tint(rgb, pulse)
    if not rgb then
        veil = nil
        return
    end
    veil = { r = rgb[1] or 1, g = rgb[2] or 1, b = rgb[3] or 1, pulse = pulse == true, next = 0 }
end

-- Ten times a second: the freeze and the veil held.
function B.client_tick(now)
    if frozen then
        if now >= frozen.ends then
            release_freeze()
        else
            local mec = me_alive()
            if mec then
                if frozen.move and U.get(mec, "Lock Movements", false) ~= true then U.set(mec, "Lock Movements", true) end
                if frozen.act and U.get(mec, "Local Can Interact", true) ~= false then U.set(mec, "Local Can Interact", false) end
                frozen.applied = true
            elseif frozen.applied then
                -- dead, or a ghost of its own for a while: free meanwhile (held again on its return)
                unlock(G.local_mec(), frozen)
                frozen.applied = false
            end
        end
    end
    if veil then
        local mec = me_alive()
        if mec then
            if not veil.pulse then
                U.set(mec, "Vignette Color", { R = veil.r, G = veil.g, B = veil.b, A = 1.0 })
            elseif now >= veil.next then
                veil.next = now + 0.7
                U.tcall(mec, "Color Effect", 2.0, { R = veil.r - 1, G = veil.g - 1, B = veil.b - 1, A = 0.0 })
            end
        end
    end
end

-- The end of an event, of a game: nothing held any more on this machine.
function B.client_reset()
    release_freeze()
    veil = nil
end

-- ---------------------------------------------------------------- [A] an explosion's effects
-- The game's fireball and sounds, without the game's actor (whose copy on the host would deal
-- its own damage): "gas" or "c4". Players near it are shaken and dazzled.
function B.on_fx(kind, x, y, z)
    local mec = G.local_mec()
    if not mec then return end
    local at = U.vec(num(x), num(y), num(z))
    local lib = StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
    local sys = G.asset(B.FX.NIAGARA)
    if U.valid(lib) and sys then
        U.try("explosion : boule de feu", function()
            lib:SpawnSystemAtLocation(mec, sys, at, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }, U.vec(1, 1, 1), true, true, 0, true)
        end)
    end
    A.game_sound_at(kind == "gas" and B.FX.GAS or B.FX.C4, at, B.FX.ATT_SHOT)
    A.game_sound_at(B.FX.ECHO, at, B.FX.ATT_ECHO)
    local p = G.location(mec)
    local d = p and U.dist(p, at) or math.huge
    if d < FX_REACH and G.is_alive(mec) and not is_ghost() then
        local k = 1 - d / FX_REACH
        U.set(mec, "Camera Shake Intensity", 3.0 * k)
        U.tcall(mec, "Color Effect", 6.0 * k, { R = 0.6 * k, G = 0.3 * k, B = 0.0, A = 0.0 })
    end
end

return B
