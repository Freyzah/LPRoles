-- LPRoles - player side: on-screen messages, local ghost mode (Rêveur / Fée), fairy light,
-- Médium's vision, Hypnotiseur's closed eyes, Revenant's ghost, Traqueur's silhouette,
-- Shérif's green sphere.
-- Runs on every machine that has the mod, including the host's.
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local N = require("lpr_net")
local S = require("lpr_strings")
local RT = require("lpr_roletext")
local A = require("lpr_audio")
local K = require("lpr_marks")
local MD = require("lpr_medic")
local SC = require("lpr_screens")
local RC = require("lpr_recap")
local BK = require("lpr_book")
local EV = require("lpr_ev")

local Cl = {}

local ghost = nil            -- { kind = "dream" | "fairy", health, stamina, can_talk, body = {X,Y,Z}, yaw }
local hello_sent_for = nil   -- address of the local character the host was told about
local my_role = nil
local my_status = nil        -- values sent by the host about the role (uses, timers, settings)
local safe_idx = nil         -- Shérif: the safe person's index
local hint_shown = false     -- the "consume" key was already named for this role
local role_listeners = {}
local fx = {}                -- player index -> what was hidden for the fairy effect
local vision = nil           -- Médium: { ends, next }
local hypno = nil            -- eyes held shut by the Hypnotiseur: { ends }
local spirits = {}           -- player index -> { mec, ends } (Revenant showing itself)
local spirit_next = 0        -- when the ghosts of Revenants are shown again
local showing_dead = false   -- true while the Médium trick itself calls the game's Death Update
local hiding = nil           -- Clandestin: { ends, first_person }
local cleaned = {}           -- Nettoyeur: player index -> { mec, hidden = { components } }
local end_hiding, restore_bodies   -- defined below (used at the end of a game)
local is_local = G.is_local       -- true for the local player's character
local skin_backup = nil      -- Métamorphe: this player's own appearance
local disguised = false
local disguise_gen = 0       -- so that an old "stop protecting" timer cannot end a newer disguise
local list_colors = {}       -- Métamorphe: player index -> { mec, color }, the colour its row of the player list keeps
local poisoned = false       -- the host said so: the "consume" key may then serve for the antidote
local gag = nil              -- Bâillonneur: this player's microphone is held off: { ends, next }
local vamp = nil             -- Vampire: life above the game's maximum: { max, reserve, acc, at }
local wolf = nil             -- Loup-garou: the game's own regeneration values, to give back: { asset, min, max, hp }

-- ---------------------------------------------------------------- notifications
local function say(id, color, ...)
    local fmt = S[id] or id
    local ok, text = pcall(string.format, fmt, ...)
    G.say(ok and text or fmt, S.COLOR[color or "info"])
end

-- ---------------------------------------------------------------- local ghost mode
local steam_utils = nil
local function mute_player(mec)
    steam_utils = (U.valid(steam_utils) and steam_utils) or StaticFindObject("/Script/SteamCorePro.Default__SteamUtilities")
    if not U.valid(steam_utils) then return end
    local ps = U.get(mec, "PlayerState", nil)
    if U.valid(ps) then
        U.try("MuteRemoteTalker", function() steam_utils:MuteRemoteTalker(mec, 0, ps, false) end)
    end
end

-- While we are a temporary ghost, the truly dead must stay invisible and silent.
local function hide_the_dead(mec)
    if G.is_alive(mec) then return end
    for _, rec in pairs(spirits) do            -- a Revenant showing itself is seen by all
        if U.valid(rec.mec) and rec.mec:GetAddress() == mec:GetAddress() then return end
    end
    local root = U.get(mec, "Ghost Root", nil)
    if U.valid(root) then U.try("cacher fantôme", function() root:SetVisibility(false, true) end) end
    mute_player(mec)
end

local function set_body_collision(mec, mode)
    local col = U.get(mec, "Body Collider", nil)
    if U.valid(col) then U.try("collision", function() col:SetCollisionEnabled(mode) end) end
end

local function hud_of(mec)
    local hud = U.get(mec, "HUD", nil)
    return U.valid(hud) and hud or nil
end

-- Opens both eyes the way the game itself does after a respawn. Closing both eyes locks
-- them shut, so without this the player would start the ghost phase blind.
local function open_eyes(mec)
    U.set(mec, "WinkL", false)
    U.set(mec, "WinkR", false)
    U.set(mec, "EyesState", G.EYE_OPEN)
    U.set(mec, "WinkLock", true)
    U.tcall(mec, "Check Eyes State")
end

-- First-person parts: the hands, and what goes with them (item in hand, tablet, weapon effect,
-- and the charm and fish, which belong to the body but would show in front of the camera). Hidden on this machine only while the player is a ghost; the other players
-- never see them anyway. Only what was visible is hidden, and only that is shown again.
local FP_COMPONENTS = { "SkM Hands", "Charm Mesh", "FishMesh" }
local FP_ACTORS = { "HandMesh", "Hand Tablet", "Hand FX" }

local function hide_first_person(mec)
    local hidden = { comps = {}, actors = {} }
    for _, name in ipairs(FP_COMPONENTS) do
        local c = U.get(mec, name, nil)
        if U.valid(c) then
            U.try("cacher " .. name, function()
                if c:IsVisible() then
                    c:SetVisibility(false, false)
                    hidden.comps[#hidden.comps + 1] = c
                end
            end)
        end
    end
    for _, name in ipairs(FP_ACTORS) do
        local a = U.get(mec, name, nil)
        if U.valid(a) and U.get(a, "bHidden", nil) == false then
            U.try("cacher " .. name, function()
                a:SetActorHiddenInGame(true)
                hidden.actors[#hidden.actors + 1] = a
            end)
        end
    end
    return hidden
end

local function show_first_person(hidden)
    if not hidden then return end
    for _, c in ipairs(hidden.comps) do
        if U.valid(c) then U.try("réafficher", function() c:SetVisibility(true, false) end) end
    end
    for _, a in ipairs(hidden.actors) do
        if U.valid(a) then U.try("réafficher", function() a:SetActorHiddenInGame(false) end) end
    end
end

local exit_ghost            -- defined below

local function enter_ghost(kind, body, yaw, duration)
    local mec = G.local_mec()
    if not mec or ghost then return false end
    ghost = {
        kind = kind,
        health = U.get(mec, "Health", 100),
        stamina = U.get(mec, "Stamina", 0.0),
        can_talk = U.get(mec, "Can Talk", true),
        body = body, yaw = yaw,
        lethal_at = nil,
    }
    U.set(mec, "Alive", false)                 -- switches movement, camera and interactions to ghost rules
    set_body_collision(mec, 0)
    U.set(mec, "Can Talk", false)
    U.tcall(mec, "Apply Mic State")
    U.tcall(mec, "Force Off Tablet")
    U.tcall(mec, "Set Center of Mass Offset")
    ghost.first_person = hide_first_person(mec)     -- a ghost has no hands
    open_eyes(mec)
    local hud = hud_of(mec)
    if hud then U.tcall(hud, "Death Hidders", true) end
    -- The game's death flash lasts a few seconds: fine for an 18 s dream, far too long
    -- for a 2.5 s flight, so the fairy gets none.
    if kind == "dream" and C.get("ghost_fx") then U.tcall(mec, "Death Deaf") end
    U.dbg("mode fantôme : %s", kind)
    -- Safety net: if the host's "end" message is lost, come back on our own.
    local this = ghost
    U.after((duration or 20) + 3, "fin de secours du mode fantôme", function()
        if ghost ~= this then return end
        exit_ghost(kind == "dream")
        if kind == "dream" then N.to_host(N.OP_WAKE) end
    end)
    return true
end

local function finish_exit(g, teleport)
    local mec = G.local_mec()
    if not mec then return end
    if teleport and g.body then
        U.tcall(mec, "Request TP", g.body, g.yaw or 0.0)
    end
    U.set(mec, "Alive", true)
    show_first_person(g.first_person)
    set_body_collision(mec, 3)
    U.tcall(mec, "Set Center of Mass Offset")
    U.tcall(mec, "Death Deaf")                 -- with Alive = true this resets sound and picture
    local hud = hud_of(mec)
    if hud then U.tcall(hud, "Death Hidders", false) end
    U.set(mec, "Can Talk", g.can_talk)
    U.tcall(mec, "Apply Mic State")
    if g.kind == "dream" then
        open_eyes(mec)                         -- the wake-up gesture leaves both eyes locked shut
    end
    if g.kind == "fairy" then
        -- hits taken while flying do not count
        U.set(mec, "Health", g.health)
        U.set(mec, "Stamina", g.stamina)
        local ps = hud and U.get(hud, "PlayerState", nil)
        if U.valid(ps) then U.tcall(ps, "Set HP") end
    end
    for _, m in ipairs(G.all_mecs()) do
        if m:GetAddress() ~= mec:GetAddress() then U.tcall(m, "Death Update") end
    end
    U.dbg("fin du mode fantôme")
end

exit_ghost = function(teleport)
    local g = ghost
    if not g then return end
    ghost = nil
    -- The game starts a death 0.1 s after a lethal hit and drops it if the player is not
    -- "alive" at that moment. A fairy that absorbed such a hit a split second ago stays a
    -- ghost a little longer, so that the pending death is dropped and not carried out.
    if g.kind == "fairy" and g.lethal_at and U.now() - g.lethal_at < 0.2 then
        U.after(0.25, "fin d'envol différée", function() finish_exit(g, teleport) end)
    else
        finish_exit(g, teleport)
    end
end

-- ---------------------------------------------------------------- a character's parts, by name
-- Asking the engine for the list of a character's parts (K2_GetComponentsByClass) gives nothing
-- through UE4SS: the parts are named here. What the others see of a player: the body and the
-- head (the game draws the whole appearance on these two), the charm, and a fish stuck on the
-- face. What can be hit: the same body and head, and the three shapes around them.
local BODY_PARTS = { "SkM Body", "SkM Head", "Charm Mesh", "FishMesh" }
local BODY_SOLIDS = { "SkM Body", "SkM Head", "Body Collider", "Head Collider", "Head Hitbox" }

-- ---------------------------------------------------------------- fairy effect seen by the others
-- While she flies, the others see a purple ball where the Fée's body was: a ball like the one
-- the game shows over dissidents (same shape, same material, another colour, 25 cm across
-- for the game's 10), at chest height (a character's position is at its feet). It is a part added to her
-- character on this machine, so it follows her flight; the game's own sphere is not touched,
-- the game shows and hides it as it pleases.
-- small: when the host only wants a light, a ball the size of the game's own, so that the
-- light has something to come from.
local FAIRY_BALL = { z = 110.0, scale = 0.25, small = 0.12, color = { R = 0.75, G = 0.10, B = 1.0 } }

local function fairy_ball(mec, small)
    local cls = StaticFindObject("/Script/Engine.StaticMeshComponent")
    local mesh, mat = G.asset(G.BALL_MESH), G.asset(G.ORB_MATERIAL)
    if not (U.valid(cls) and mesh and mat) then return nil end
    local s = small and FAIRY_BALL.small or FAIRY_BALL.scale
    local function placed(at)
        return { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 },
                 Translation = at and { X = at.X, Y = at.Y, Z = at.Z + FAIRY_BALL.z } or { X = 0.0, Y = 0.0, Z = FAIRY_BALL.z },
                 Scale3D = { X = s, Y = s, Z = s } }
    end
    local function drop(c)
        pcall(function() c:SetVisibility(false, false) end)      -- unseen even if it cannot be removed
        U.try("boule de la fée : retrait", function() c:K2_DestroyComponent(mec) end)
    end
    local c = nil
    -- First way: put where she is, then tied to the part of her character that sits at her
    -- position, place kept (the way the Traqueur's silhouette is).
    local carrier = U.get(mec, "Orientation", nil)
    local at = U.valid(carrier) and G.location(mec) or nil
    if at then
        c = mec:AddComponentByClass(cls, true, placed(at), false)
        if U.valid(c) then
            local tied = U.try("boule de la fée : attache", function()
                c:SetCollisionEnabled(0)          -- before it has a shape: never in anybody's way
                pcall(function() c:SetMobility(2) end)
                return c:K2_AttachToComponent(carrier, FName("None"), 1, 2, 1, false) ~= false
            end)
            if not tied then
                drop(c)                           -- never a still ball left where she took off
                c = nil
            end
        end
    end
    -- Second way: added straight onto her character (the way the light is).
    if not U.valid(c) then
        if at then U.log("Fée : boule non attachée de la première façon, posée comme la lumière") end
        c = mec:AddComponentByClass(cls, false, placed(nil), false)
        if not U.valid(c) then return nil end
    end
    local dressed = U.try("boule de la fée : aspect", function()
        c:SetCollisionEnabled(0)                  -- before it has a shape: never in anybody's way
        pcall(function() c:SetCastShadow(false) end)
        if c:SetStaticMesh(mesh) == false then error("forme refusée") end
        local mid = c:CreateDynamicMaterialInstance(0, mat, FName("None"))
        if not U.valid(mid) then error("matière non modifiable") end
        -- the material's own brightness is kept, only the hue changes (as for the Shérif's green)
        local hue = FAIRY_BALL.color
        for _, name in ipairs({ "Color", "eColor" }) do
            local param = FName(name)
            local v = mid:K2_GetVectorParameterValue(param)
            local strength = math.max(v.R + 0.0, v.G + 0.0, v.B + 0.0)
            if strength > 0.001 then
                mid:SetVectorParameterValue(param,
                    { R = hue.R * strength, G = hue.G * strength, B = hue.B * strength, A = v.A + 0.0 })
            end
        end
        return true
    end)
    if not dressed then
        drop(c)        -- no ball rather than the material's own red, the dissidents' colour
        return nil
    end
    return c
end

local fairy_fx_off           -- defined below

local function fairy_fx_on(mec, idx, with_light, with_ball)
    if fx[idx] then fairy_fx_off(idx) end      -- an effect left for this player: ended first
    local rec = { mec = mec, hidden = {}, actors = {} }
    fx[idx] = rec
    -- The body, part by part. Only what is visible is hidden, and only that is shown again;
    -- the game's marker sphere is not among the parts (dissidents seeing each other).
    for _, name in ipairs(BODY_PARTS) do
        local c = U.get(mec, name, nil)
        if U.valid(c) then
            U.try("masquer " .. name, function()
                if c:IsVisible() then
                    c:SetVisibility(false, false)
                    rec.hidden[#rec.hidden + 1] = c
                end
            end)
        end
    end
    -- What she carries: separate objects tied to her character.
    for _, prop in ipairs({ "HandMesh", "BodyMesh", "BodyTabletMesh", "Hand Tablet", "Body FX", "Hand FX" }) do
        local a = U.get(mec, prop, nil)
        if U.valid(a) and U.get(a, "bHidden", nil) == false then
            U.try("masquer " .. prop, function()
                a:SetActorHiddenInGame(true)
                rec.actors[#rec.actors + 1] = a
            end)
        end
    end
    if with_light then
        local cls = StaticFindObject("/Script/Engine.PointLightComponent")
        if U.valid(cls) then
            U.try("lumière de la fée", function()
                local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 },
                            Translation = { X = 0.0, Y = 0.0, Z = 60.0 },
                            Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
                local light = mec:AddComponentByClass(cls, false, t, false)
                if U.valid(light) then
                    rec.light = light
                    pcall(function() light:SetMobility(2) end)
                    pcall(function() light:SetAttenuationRadius(350.0) end)
                    pcall(function() light:SetIntensity(8000.0) end)
                    pcall(function() light:SetLightColor({ R = 1.0, G = 0.75, B = 0.95, A = 1.0 }, true) end)
                end
            end)
        end
    end
    -- after the body was hidden, so that the ball is not hidden with it; with the light alone,
    -- a small one for the light to come from
    if with_ball or with_light then
        rec.ball = U.try("boule de la fée", fairy_ball, mec, not with_ball)
    end
    U.log("Fée : %s masquée (%d éléments, %d objets), lumière %s, boule %s", G.player_name(mec),
        #rec.hidden, #rec.actors, with_light and (U.valid(rec.light) and "oui" or "NON CRÉÉE") or "non",
        (with_ball or with_light) and (U.valid(rec.ball) and (with_ball and "oui" or "petite") or "NON CRÉÉE") or "non")
end

fairy_fx_off = function(idx)
    local rec = fx[idx]
    if not rec then return end
    fx[idx] = nil
    A.around_off(rec.sound)
    for _, c in ipairs(rec.hidden) do
        if U.valid(c) then U.try("réafficher", function() c:SetVisibility(true, false) end) end
    end
    for _, a in ipairs(rec.actors) do
        if U.valid(a) then U.try("réafficher", function() a:SetActorHiddenInGame(false) end) end
    end
    for _, part in ipairs({ rec.light or false, rec.ball or false }) do
        if U.valid(part) and U.valid(rec.mec) then
            U.try("fin d'effet fée", function() part:K2_DestroyComponent(rec.mec) end)
        end
    end
end

-- ---------------------------------------------------------------- Médium: seeing and hearing the dead
-- The game itself decides, for every dead character, whether its ghost is shown and heard:
-- yes when the local player is dead, no otherwise. During a vision the local player is
-- reported dead for the length of that one decision, then alive again straight away.
local function show_the_dead(show)
    local me = G.local_mec()
    if not me then return end
    if show and U.get(me, "Alive", true) ~= true then return end     -- already a ghost
    if show then U.set(me, "Alive", false) end
    showing_dead = true
    pcall(function()
        for _, m in ipairs(G.all_mecs()) do
            if m:GetAddress() ~= me:GetAddress() and not G.is_alive(m) then U.tcall(m, "Death Update") end
        end
    end)
    showing_dead = false
    if show then U.set(me, "Alive", true) end
end

local function end_vision(quiet)
    if not vision then return end
    vision = nil
    local me = G.local_mec()
    if me and G.is_alive(me) then show_the_dead(false) end
    spirit_next = 0                           -- Revenants still showing come back at once
    if not quiet then say("MEDIUM_END", "info") end
end

local function on_medium(on, secs)
    if on == "1" then
        if ghost then return end
        local d = tonumber(secs) or 10
        vision = { ends = U.now() + d, next = 0 }
        say("MEDIUM_START", "role", d)
        A.power_sfx("ok")
    else
        end_vision(true)
    end
end

local function tick_vision(now)
    if not vision then return end
    local me = G.local_mec()
    if not me or not G.is_alive(me) then
        vision = nil                          -- dead: the game shows the ghosts by itself
        return
    end
    if now >= vision.ends then return end_vision(false) end
    if now >= vision.next then                -- again every second, for players who die meanwhile
        vision.next = now + 1
        show_the_dead(true)
    end
end

-- The host: something was started by closing both eyes (the Rêveur's gesture, which locks
-- them shut).
local function on_open_eyes()
    local mec = G.local_mec()
    if mec and not hypno then open_eyes(mec) end
end

-- ---------------------------------------------------------------- Hypnotiseur: eyes held shut
local function hold_eyes_shut(mec)
    if U.get(mec, "WinkL", false) and U.get(mec, "WinkR", false) and U.get(mec, "EyesState", 0) == G.EYE_LOCK then return end
    U.set(mec, "WinkL", true)
    U.set(mec, "WinkR", true)
    U.set(mec, "EyesState", G.EYE_LOCK)
    U.set(mec, "WinkLock", false)
    U.tcall(mec, "Check Eyes State")
end

-- Seconds over which the sound of a hypnosis comes in: under the sound of its start, whose
-- strong part lasts about as long, so that one leads into the other.
local HYPNO_FADE_IN = 0.8

local function on_hypno(tenths)
    local mec = G.local_mec()
    if not mec or ghost then return end
    local secs = (tonumber(tenths) or 30) / 10
    hypno = { ends = U.now() + secs }
    say("HYPNO_YOU", "bad")
    hold_eyes_shut(mec)
    -- the sound of the hypnosis that strikes, then the one heard for as long as the eyes are
    -- held shut, each on a player of its own
    A.role_sound("hypnosis")
    U.try("son de l'hypnose", A.play, "hypnotized", "role_sounds", secs, "hypno", HYPNO_FADE_IN)
end

local function tick_hypno(now)
    if not hypno then return end
    local mec = G.local_mec()
    if not mec then hypno = nil return end
    if now >= hypno.ends or not G.is_alive(mec) then
        -- over before its time (a death): the sound with it; otherwise it ends by itself
        if now < hypno.ends then U.try("son de l'hypnose", A.stop, "hypno") end
        hypno = nil
        open_eyes(mec)
        return
    end
    hold_eyes_shut(mec)
end

-- ---------------------------------------------------------------- Revenant: the ghost shown to all
-- For a moment a dead player's ghost is seen and heard by everybody. The game decides, for
-- each dead character, whether its ghost is shown and heard, from the local player's own
-- state (see the Médium): the local player is reported dead for the length of that one
-- decision. The game takes the decision again whenever someone dies or comes back: the mod
-- asks for it again right after, and every few seconds while the ghost must show.
local function show_ghost(mec, show)
    local me = G.local_mec()
    if not me or not U.valid(mec) or me:GetAddress() == mec:GetAddress() then return end
    if G.is_alive(mec) then return end
    local alive = U.get(me, "Alive", true) == true
    if not alive and not ghost then return end               -- truly dead: the game shows the ghosts
    -- a dreamer or a flying fairy already counts as dead for the game: the decision is just
    -- taken again (the Revenant showing itself is not hidden from them, see hide_the_dead)
    local flip = show and alive
    if flip then U.set(me, "Alive", false) end
    showing_dead = true
    pcall(function() U.tcall(mec, "Death Update") end)
    showing_dead = false
    if flip then U.set(me, "Alive", true) end
end

local function spirit_off(idx)
    local rec = spirits[idx]
    if not rec then return end
    spirits[idx] = nil
    if not U.valid(rec.mec) or vision then return end        -- a vision shows every ghost anyway
    if ghost then
        hide_the_dead(rec.mec)                               -- a dreamer never sees the dead
    else
        show_ghost(rec.mec, false)
    end
end

local function on_spirit(idx, tenths)
    idx = tonumber(idx) or -1
    local mec = G.mec_by_index(idx)
    local mine = G.local_mec()
    if not mec then return end
    if mine and mec:GetAddress() == mine:GetAddress() then return end      -- the Revenant itself: nothing to show
    local secs = (tonumber(tenths) or 30) / 10
    if secs <= 0 then return spirit_off(idx) end                           -- raised meanwhile: over
    local rec = { mec = mec, ends = U.now() + secs }
    spirits[idx] = rec
    spirit_next = math.min(spirit_next, rec.ends)            -- hidden again right on time
    show_ghost(mec, true)
end

local function tick_spirits(now)
    if now < spirit_next then return end
    spirit_next = now + 3                     -- sooner when the game has just hidden the ghosts
    for idx, rec in pairs(spirits) do
        if not U.valid(rec.mec) then
            spirits[idx] = nil
        elseif now >= rec.ends then
            spirit_off(idx)
        else
            show_ghost(rec.mec, true)
            spirit_next = math.min(spirit_next, rec.ends)    -- hidden again right on time
        end
    end
end

-- ---------------------------------------------------------------- Vampire: life above the game's maximum
-- The game keeps a character's life on its player's machine and never lets it go above 100.
-- What the Vampire gains is kept here, as a reserve on top of those 100: after every hit the
-- life is filled up again from it. So the reserve is spent first - but a single hit that
-- takes 100 at once still kills. The reserve comes back the way the game's own life does: one
-- point at each of its regeneration beats, once the life itself is full.
local function role_changed()
    for _, fn in ipairs(role_listeners) do U.try("état du rôle", fn, my_role) end
end

local HUD_STATE = "/Game/UI/Game/W_PlayerState.W_PlayerState_C"       -- the part of the HUD that shows life and stamina

-- The number on the HUD's life bar is written by the game each time the life changes
-- ("Set HP": the character's own life, 100 at most). Right after, the reserve is added to it:
-- the Vampire reads 115 for a full life and 15 in reserve. The bar itself stays the game's.
local function vamp_number(ps, mec)
    if not vamp or vamp.reserve <= 0 or ghost then return end
    local health = U.get(mec, "Health", 0)
    if type(health) ~= "number" or health <= 0 then return end
    G.text_call(U.get(ps, "HPtext", nil), "SetText", tostring(math.floor(health + vamp.reserve + 0.5)))
end

-- Has the game write that number again (the hook on "Set HP" then adds the reserve, if any).
local function show_health()
    local mec = G.local_mec()
    local hud = mec and hud_of(mec)
    local ps = hud and U.get(hud, "PlayerState", nil)
    if U.valid(ps) then U.tcall(ps, "Set HP") end
end

local function vamp_changed()
    if my_status and my_role == "vampire" then my_status.res = vamp and vamp.reserve or 0 end
    U.try("vie affichée", show_health)
    role_changed()
end

local function on_vamp(meals, per)
    local max = (tonumber(meals) or 0) * (tonumber(per) or 0)
    if not vamp then vamp = { max = 0, reserve = 0, acc = 0 } end
    local gained = math.max(0, max - vamp.max)
    vamp.max = max
    vamp.reserve = math.min(max, vamp.reserve + gained)
    U.log("Vampire : vie maximale 100 + %d, réserve %d", vamp.max, vamp.reserve)
    vamp_changed()
end

-- Right after a hit on the local character (amount: what it took).
local function vamp_absorb(mec, amount)
    if (amount or 0) <= 0 or vamp.reserve <= 0 then return end
    local health = U.get(mec, "Health", 0)
    if type(health) ~= "number" or health <= 0 or health >= 100 then return end     -- dying: nothing to give back
    local give = math.min(vamp.reserve, 100 - health)
    U.set(mec, "Health", health + give)
    vamp.reserve = vamp.reserve - give
    vamp_changed()
end

local function tick_vamp(now)
    if not vamp then return end
    local dt = now - (vamp.at or now)
    vamp.at = now
    local mec = G.local_mec()
    if not mec or ghost then return end
    if U.get(mec, "Alive", true) ~= true then          -- dead: the life above the maximum is lost
        if vamp.reserve > 0 then
            vamp.reserve, vamp.acc = 0, 0
            vamp_changed()
        end
        return
    end
    if vamp.reserve >= vamp.max then return end
    if U.get(mec, "Stamina Regenering", false) ~= true or U.get(mec, "Health", 0) < 100 then return end
    local data = U.get(mec, "PlayerData", nil)
    local beat = U.valid(data) and U.get(data, "Regen HP Speed", nil) or nil
    if type(beat) ~= "number" or beat <= 0 then beat = 3 end
    vamp.acc = (vamp.acc or 0) + dt / beat
    if vamp.acc >= 1 then
        vamp.acc = vamp.acc - 1
        vamp.reserve = math.min(vamp.max, vamp.reserve + 1)
        vamp_changed()
    end
end

-- ---------------------------------------------------------------- Loup-garou: faster regeneration
-- The game reads how fast stamina and life come back from its player data ("Min Regen" and
-- "Max Regen": stamina per second; "Regen HP Speed": seconds between two points of life).
-- On this machine only those three values are scaled, from the values found the first time,
-- and given back as soon as the role or the game is over: the data outlives a game.
local function wolf_reset()
    local w = wolf
    if not w then return end
    wolf = nil
    if U.valid(w.asset) then
        U.set(w.asset, "Min Regen", w.min)
        U.set(w.asset, "Max Regen", w.max)
        U.set(w.asset, "Regen HP Speed", w.hp)
        U.log("Loup-garou : régénération du jeu remise à ses valeurs")
    end
end

local function on_wolf(_, pct)
    local total = tonumber(pct) or 0
    if total <= 0 then return wolf_reset() end
    local mec = G.local_mec()
    if not mec then return end
    if not wolf then
        local asset = U.get(mec, "PlayerData", nil)
        local min = U.valid(asset) and U.get(asset, "Min Regen", nil) or nil
        local max = U.valid(asset) and U.get(asset, "Max Regen", nil) or nil
        local hp = U.valid(asset) and U.get(asset, "Regen HP Speed", nil) or nil
        if type(min) ~= "number" or type(max) ~= "number" or type(hp) ~= "number" or hp <= 0 then
            U.log("Loup-garou : valeurs de régénération du jeu illisibles, rien n'est changé")
            return
        end
        wolf = { asset = asset, min = min, max = max, hp = hp }
        U.log("Loup-garou : régénération du jeu : endurance %.2f à %.2f par seconde, 1 PV toutes les %.2f s", min, max, hp)
    end
    if not U.valid(wolf.asset) then return end
    local f = 1 + total / 100
    U.set(wolf.asset, "Min Regen", wolf.min * f)
    U.set(wolf.asset, "Max Regen", wolf.max * f)
    U.set(wolf.asset, "Regen HP Speed", wolf.hp / f)
    U.log("Loup-garou : régénération accélérée de %d %%", total)
end

-- ---------------------------------------------------------------- Bâillonneur: the microphone held off
-- The game only sends the voice of a character whose "Can Talk" is true (a sleeping Rêveur's
-- is switched off the same way, see enter_ghost): held false for as long as the host says.
local function mic(mec, on)
    U.set(mec, "Can Talk", on)
    U.tcall(mec, "Apply Mic State")
end

local function end_gag(quiet)
    if not gag then return end
    gag = nil
    local mec = G.local_mec()
    if ghost then
        ghost.can_talk = true                  -- given back when the flight or the dream ends
    elseif mec then
        mic(mec, true)
    end
    if not quiet then say("GAG_END", "info") end
end

local function on_gag(tenths)
    local secs = (tonumber(tenths) or 0) / 10
    if secs <= 0 then return end_gag(true) end
    gag = { ends = U.now() + secs, next = 0 }
    say("GAG_YOU", "bad", math.floor(secs + 0.5))
end

-- The game switches the microphone back on by itself now and then (a new character, a key):
-- looked at twice a second.
local function tick_gag(now)
    if not gag then return end
    if now >= gag.ends then return end_gag(false) end
    if now < gag.next then return end
    gag.next = now + 0.5
    local mec = G.local_mec()
    if mec and not ghost and U.get(mec, "Can Talk", true) ~= false then mic(mec, false) end
end

-- Empoisonneur: the host says when this player knows it is poisoned, and when that is over.
local function on_poison(on)
    poisoned = (on == "1")
end

-- End of the game: stop everything that may still be running.
local function on_end()
    G.clear_messages()                         -- banners still waiting belong to the finished game
    EV.client_reset("end")                     -- a random event's marks, sounds, freeze... (its EVOFF came first)
    list_colors = {}                           -- the host gives every look back: the rows follow by themselves
    end_vision(true)
    disguise_gen = disguise_gen + 1
    local gen = disguise_gen
    U.after(3, "fin du déguisement", function()       -- the host restores the look first
        if disguise_gen == gen then disguised, skin_backup = false, nil end
    end)
    if hypno then
        hypno = nil
        U.try("son de l'hypnose", A.stop, "hypno")
        local mec = G.local_mec()
        if mec then open_eyes(mec) end
    end
    for i in pairs(spirits) do spirit_off(i) end
    for i in pairs(fx) do fairy_fx_off(i) end
    K.track_off()
    K.orb_restore()
    K.card_off()
    end_hiding()
    restore_bodies()
    end_gag(true)
    poisoned = false
    if vamp then
        vamp = nil
        U.try("vie affichée", show_health)     -- the game's own number again
    end
    wolf_reset()
    MD.reset()
    -- no role any more until the next game
    my_role, my_status, safe_idx = nil, nil, nil
    for _, fn in ipairs(role_listeners) do U.try("rôle", fn, nil) end
end

-- The Taupe is shown as an employee by the game; the player list on its own screen still
-- tags the other dissidents until each row is refreshed.
local function refresh_player_lists()
    local rows = FindAllOf("W_Player_List_C")
    if not rows then return end
    for _, w in ipairs(rows) do
        if U.valid(w) then U.tcall(w, "Update Player") end
    end
end

-- ---------------------------------------------------------------- Métamorphe: the saved appearance
-- When a player's appearance changes, the game saves it on that player's machine as their own
-- customisation (slot "Save_Appearance2": the current preset and the colour). While disguised,
-- the player's real appearance is written back and saved again right after the game's save.
local function protect_skin_save(mec)
    if not skin_backup then return end
    local saved = U.get(mec, "Saved Appearance", nil)
    if not U.valid(saved) then return end
    local ok = pcall(function()
        local list = saved.Appearance
        local preset = (U.get(saved, "Preset", 0) or 0) + 1
        if preset < 1 or preset > #list then error("préréglage hors liste") end
        list[preset] = G.look_value({ color = 0, custom = skin_backup.custom })
    end)
    if not ok then return end
    U.set(saved, "Color", skin_backup.color or 0)
    local statics = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    if U.valid(statics) then
        U.try("sauvegarde de l'apparence", function() statics:SaveGameToSlot(saved, "Save_Appearance2", 0) end)
    end
end

-- ---------------------------------------------------------------- Métamorphe: the list of players
-- The game colours each row of the player list (top right) from the character's look, so a
-- Métamorphe's row would take the colour of the player it copies and give it away. Half a
-- second before the look changes, the host says so to every machine: the colour the row shows
-- at that moment is noted, and put back each time the game draws the row again, until the
-- disguise is over.
local LIST_ROW = "/Game/UI/Game/W_Player_List.W_Player_List_C"

local function row_border(w)
    local b = U.get(w, "color_border", nil)
    return U.valid(b) and b or nil
end

local function on_look(idx, on)
    idx = tonumber(idx) or -1
    if on == "1" then
        local mec = G.mec_by_index(idx)
        if not mec then return end
        local addr = mec:GetAddress()
        -- a disguise that has just ended still holds the true colour: kept (in a record of its own,
        -- so that the pending end of the previous one does not drop it)
        local color = list_colors[idx] and list_colors[idx].mec == addr and list_colors[idx].color or nil
        for _, w in ipairs(FindAllOf("W_Player_List_C") or {}) do
            if color then break end
            local target = U.valid(w) and U.get(w, "Target Mec", nil) or nil
            local b = U.valid(target) and target:GetAddress() == addr and row_border(w) or nil
            if b then
                pcall(function()
                    local c = b.BrushColor
                    color = { R = c.R + 0.0, G = c.G + 0.0, B = c.B + 0.0, A = c.A + 0.0 }
                end)
            end
        end
        if color then
            list_colors[idx] = { mec = addr, color = color }
        else
            U.log("Métamorphe : couleur de la ligne de %s introuvable dans la liste des joueurs", G.player_name(mec))
        end
    else
        local rec = list_colors[idx]
        if not rec then return end
        -- a moment more: the true look has to come back first, the row then redraws by itself
        U.after(1.5, "liste des joueurs", function()
            if list_colors[idx] == rec then list_colors[idx] = nil end
        end)
    end
end

-- Right after the game has drawn a row of the list: a disguised player's row gets its own
-- colour back.
local function on_list_row(ctx)
    if next(list_colors) == nil then return end
    local w = ctx:get()
    local target = U.valid(w) and U.get(w, "Target Mec", nil) or nil
    if not U.valid(target) then return end
    local addr = target:GetAddress()
    for _, rec in pairs(list_colors) do
        if rec.mec == addr then
            local b = row_border(w)
            if b then b:SetBrushColor(rec.color) end
            return
        end
    end
end

local function on_mimic(on)
    disguise_gen = disguise_gen + 1
    if on == "1" then
        local mec = G.local_mec()
        if not skin_backup and mec then skin_backup = G.copy_skin(mec) end
        disguised = true
    else
        -- the real appearance comes back now; keep protecting a little longer
        local gen = disguise_gen
        U.after(3, "fin du déguisement", function()
            if disguise_gen == gen then disguised = false end
        end)
    end
end

-- ---------------------------------------------------------------- messages from the host
local function set_role(role)
    if role ~= my_role then my_status, safe_idx, hint_shown = nil, nil, false end
    if role ~= "vampire" and vamp then
        vamp = nil
        U.try("vie affichée", show_health)
    end
    if role ~= "werewolf" then wolf_reset() end
    my_role = role
    for _, fn in ipairs(role_listeners) do U.try("rôle", fn, role) end
end

local function on_role(role)
    if role == "none" or role == nil then
        set_role(nil)
        U.log("Mon rôle : aucun")
        return
    end
    set_role(role)
    if role == "mimic" then
        local mec = G.local_mec()
        skin_backup = mec and G.copy_skin(mec) or nil          -- the real look, before any change
    end
    if role == "mole" then
        U.after(0.5, "liste des joueurs", function() U.try("liste", refresh_player_lists) end)
        U.after(5, "liste des joueurs", function() U.try("liste", refresh_player_lists) end)
    end
    for _, line in ipairs(S.ROLE_BANNER[role] or { S.ROLE_NAME[role] or role }) do
        G.say(line, S.COLOR.role)
    end
    U.log("Mon rôle : %s", tostring(role))
end

-- Message id -> { colour, kind of argument ("item": a recharge item's number, "num", "name": a
-- player index, or "pkey": nothing sent, this player's own power key), sfx = the short sound
-- that goes with it: "ok" for a power that has just started, "fail" for one that has not,
-- own = the role's own sound (a file of the "sounds" folder), which takes the place of sfx;
-- a player who switched the roles' sounds off still gets sfx }.
-- (Médium, Clandestin, Rêveur and Fée start with a command of their own, not a message:
-- their sound is played there.)
local OK, FAIL = "ok", "fail"
local MSG = {
    NO_CHARGE = { "warn", "item", sfx = FAIL }, NO_USE_LEFT = { "warn", sfx = FAIL },
    NEED_ITEM = { "warn", "item" }, RECHARGED = { "good" }, USE_BACK = { "good" },
    CHARGE_FULL = { "warn" }, USES_FULL = { "warn" }, NO_RECHARGE_LEFT = { "warn" },
    TARGET = { "info", "name" }, NO_TARGET = { "warn", sfx = FAIL }, TARGET_LOST = { "warn", sfx = FAIL },
    NO_ONE_NEAR = { "warn", sfx = FAIL }, NO_BODY = { "warn", sfx = FAIL },
    INFECT_DONE = { "good", "num", sfx = OK }, INFECT_CONVERTED = { "good", "name" },
    YOU_ARE_INFECTED = { "bad", own = "recruit" },
    INFECT_PROGRESS = { "info" }, INFECT_FAILED = { "bad", sfx = FAIL }, INFECT_NO_CHARGE = { "warn", sfx = FAIL },
    INFECT_TOO_EARLY = { "warn", sfx = FAIL }, ANGEL_TOO_LATE = { "bad" },
    ANGEL_SET = { "good", "name", sfx = OK }, ANGEL_SAVED = { "good", own = "angel" },
    ANGEL_SAVED_YOU = { "good", own = "angel" },
    TRACK_START = { "good", "name", sfx = OK }, TRACK_END = { "info" }, TRACK_BUSY = { "warn", sfx = FAIL },
    HYPNO_DONE = { "good", "name", sfx = OK }, HYPNO_IMMUNE = { "warn", sfx = FAIL },   -- the hypnosis has sounds of its own, for its target
    LINKED_TO = { "role", "name" }, LINK_DEAD = { "bad" },
    SWAP_DONE = { "good", "name" }, SWAP_FAILED = { "warn", sfx = FAIL }, SWAP_YOU = { "bad" },   -- the swap has a sound of its own
    MIMIC_START = { "good", "name", sfx = OK, own = "shapeshift" }, MIMIC_END = { "info", own = "shapeshift" },
    MIMIC_FAILED = { "warn", sfx = FAIL }, MIMIC_BUSY = { "warn", sfx = FAIL },
    NO_VENT = { "warn", sfx = FAIL }, CLEAN_DONE = { "good", "name", sfx = OK, own = "clean" },
    MARTYR_NAME = { "bad", "name", own = "martyr" }, MARTYR_CAMP_DISSIDENT = { "bad", own = "martyr" },
    MARTYR_CAMP_EMPLOYEE = { "bad", own = "martyr" },
    SPIRIT_READY = { "role", "pkey" }, SPIRIT_START = { "good", sfx = OK, own = "revenant" },
    HOST_SHORT = { "warn", "num" }, HOST_NO_MOD = { "warn", "num" },
    CARD_SHOWN = { "role" }, CARD_TAKEN = { "info" }, CARD_NONE = { "warn" },
    POISON_DONE = { "good", "name", sfx = OK }, POISON_ALREADY = { "warn", sfx = FAIL },
    POISON_YOU = { "bad", "num" }, POISON_CURE = { "info", "plant" }, POISON_CURED = { "good" },
    POISON_LOST = { "warn" }, POISON_DEAD = { "bad" },
    GAG_DONE = { "good", "name", sfx = OK },
    STEAL_DONE = { "good", "name", sfx = OK }, STEAL_NOTHING = { "warn", sfx = FAIL },
    STEAL_HANDS_FULL = { "warn", sfx = FAIL }, STEAL_FAILED = { "warn", sfx = FAIL }, STEAL_YOU = { "bad" },
    ECHO_DONE = { "good", sfx = OK }, ECHO_NOTHING = { "warn", sfx = FAIL },
    AMNESIA_DONE = { "good", "name", sfx = OK }, AMNESIA_NO_ROLE = { "warn", sfx = FAIL }, AMNESIA_DISSIDENT = { "bad" },
    JESTER_WIN = { "role", "name" }, JESTER_LOST = { "bad" }, TEST_JESTER_NO = { "warn", sfx = FAIL },
    TEST_EVENT_NO = { "warn", sfx = FAIL }, TEST_EVENT_NONE = { "warn", sfx = FAIL }, TEST_EVENT_STOP = { "warn" },
    TEST_EVENT_IDLE = { "warn", sfx = FAIL }, TEST_EVENT_MISSING = { "warn", sfx = FAIL },
    VAMP_DONE = { "good", "num", sfx = OK }, VAMP_NOT_YOURS = { "warn", sfx = FAIL }, FEED_USED = { "warn", sfx = FAIL },
    WOLF_DONE = { "good", "num", sfx = OK },
    MEDIC_DONE = { "good", "name", sfx = OK }, MEDIC_FULL = { "warn", sfx = FAIL }, MEDIC_YOU = { "good" },
}

local function on_msg(id, a)
    if id == "NO_CHARGE" and not hint_shown then
        -- once per role: the hint names this player's own key (a personal setting)
        hint_shown = true
        U.after(0.1, "rappel de la touche", function() say("USE_HINT", "info", C.format("use_key")) end)
    end
    local spec = MSG[id] or { "warn" }
    if not (spec.own and A.role_sound(spec.own)) and spec.sfx then A.power_sfx(spec.sfx) end
    local arg = nil
    if spec[2] == "item" then
        arg = S.ITEM_SHORT[tonumber(a) or 0] or "?"
    elseif spec[2] == "num" then
        arg = tonumber(a) or 0
    elseif spec[2] == "name" then
        local mec = G.mec_by_index(tonumber(a) or -1)
        arg = mec and G.player_name(mec) or "?"
    elseif spec[2] == "pkey" then
        arg = C.format("power_key")
    elseif spec[2] == "plant" then
        arg = S.PLANT_CODE[tonumber(a) or 0] or "?"
    end
    if arg ~= nil then say(id, spec[1], arg) else say(id, spec[1]) end
end

local function on_status(role, text)
    if role == "none" then role = nil end     -- no role, but something to show (Liés)
    if role ~= my_role then return end
    my_status = RT.parse(text)
    -- kept on this machine, not by the host: what is left of the Vampire's extra life
    if my_role == "vampire" then my_status.res = vamp and vamp.reserve or 0 end
    for _, fn in ipairs(role_listeners) do U.try("état du rôle", fn, my_role) end
end

local function on_safe(idx, tenths)
    safe_idx = tonumber(idx)
    for _, fn in ipairs(role_listeners) do U.try("état du rôle", fn, my_role) end
    local mec = G.mec_by_index(tonumber(idx) or -1)
    say("SAFE_PERSON", "good", mec and G.player_name(mec) or "?")
    local secs = (tonumber(tenths) or 0) / 10
    if mec and secs > 0 then K.orb_green(mec, secs) end
end

local function on_dream(on, a, x, y, z, yaw)
    if on == "1" then
        local body = U.vec(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
        local duration = tonumber(a) or 20
        if enter_ghost("dream", body, (tonumber(yaw) or 0) + 0.0, duration) then
            say("DREAM_START", "role", duration)
            A.power_sfx("ok")
        end
    elseif ghost and ghost.kind == "dream" then
        exit_ghost(true)
        say(a == "attacked" and "DREAM_ATTACKED" or "DREAM_END", a == "attacked" and "bad" or "info")
    end
end

local function on_fairy(on, tenths)
    if on == "1" then
        local secs = (tonumber(tenths) or 30) / 10
        if enter_ghost("fairy", nil, nil, secs) then
            -- the sound of a power that starts, and under it the flight's own sound, which comes
            -- in with a fade and lasts as long as the flight (each on a player of its own)
            A.power_sfx("ok")
            U.try("son de l'envol", A.play, "fairy", "fairy_sound", secs, "flight")
        end
    elseif ghost and ghost.kind == "fairy" then
        exit_ghost(false)
        U.try("son de l'envol", A.stop, "flight")     -- a flight ended early: the sound with it
    end
end

-- light, ball: "1" when the others see it in place of the body
local function on_fx(idx, on, light, tenths, ball)
    idx = tonumber(idx) or -1
    local mine = G.local_mec()
    local mec = G.mec_by_index(idx)
    if on == "1" then
        if not mec or (mine and mec:GetAddress() == mine:GetAddress()) then return end
        fairy_fx_on(mec, idx, light == "1", ball == "1")
        local rec = fx[idx]
        local secs = (tonumber(tenths) or 30) / 10
        -- the flight's sound, heard around her by those who are near
        if rec then rec.sound = U.try("son de l'envol", A.around_on, mec, "fairy", "fairy_sound", secs) end
        -- Safety net: restore the body even if the "off" message never comes.
        U.after(secs + 2, "fin d'effet fée", function()
            if fx[idx] == rec then fairy_fx_off(idx) end
        end)
    else
        fairy_fx_off(idx)
    end
end

-- ---------------------------------------------------------------- Clandestin: hidden in a vent
-- Others see the body far under the vent (the host sends it there); here the player stays in
-- place, cannot walk ("Lock Movements", which the game itself changes at times, so it is kept
-- on), cannot use or hit anything ("Local Can Interact") and has no hands.
end_hiding = function()
    local h = hiding
    if not h then return end
    hiding = nil
    local mec = G.local_mec()
    if mec then
        U.set(mec, "Lock Movements", false)
        -- always back on: a cooldown of the game running when the hide began has ended since,
        -- and nothing would clear a "false" put back here
        U.set(mec, "Local Can Interact", true)
        show_first_person(h.first_person)
    end
end

local function on_hide(on, secs)
    if on == "1" then
        local mec = G.local_mec()
        if not mec or ghost or hiding then return end
        local d = tonumber(secs) or 20
        U.tcall(mec, "Force Off Tablet")       -- a tablet in hand would stay on, unseen
        hiding = { ends = U.now() + d }
        hiding.first_person = hide_first_person(mec)
        U.set(mec, "Lock Movements", true)
        U.set(mec, "Local Can Interact", false)
        say("HIDE_START", "role", d)
        if not A.role_sound("vent_in") then A.power_sfx("ok") end
    elseif hiding then
        end_hiding()
        say("HIDE_END", "info")
        A.role_sound("vent_out")
    end
end

local function tick_hiding(now)
    if not hiding then return end
    local mec = G.local_mec()
    if not mec or not G.is_alive(mec) or now > hiding.ends + 3 then    -- safety net
        return end_hiding()
    end
    if U.get(mec, "Lock Movements", true) ~= true then U.set(mec, "Lock Movements", true) end
    if U.get(mec, "Local Can Interact", false) ~= false then U.set(mec, "Local Can Interact", false) end
end

-- ---------------------------------------------------------------- Nettoyeur: a body removed
-- On other machines a dead player's body is that player's own character (its body meshes);
-- on the dead player's machine it is a separate "DeadBody" actor. Both are taken away: the
-- body parts are hidden, and nothing of that character can be hit any more (what each part
-- could hit before is noted, and given back if the player comes back to life or at the end).
local function remove_body(idx)
    local mec = G.mec_by_index(idx)
    if not mec then return end
    local rec = cleaned[idx]
    if not rec or rec.mec ~= mec:GetAddress() then
        rec = { mec = mec:GetAddress(), obj = mec, hidden = {}, collisions = {} }
        cleaned[idx] = rec
    end
    if not is_local(mec) then
        for _, name in ipairs(BODY_PARTS) do
            local c = U.get(mec, name, nil)
            if U.valid(c) then
                U.try("corps nettoyé", function()
                    if c:IsVisible() then
                        c:SetVisibility(false, false)
                        rec.hidden[#rec.hidden + 1] = c
                    end
                end)
            end
        end
        for _, name in ipairs(BODY_SOLIDS) do
            local c = U.get(mec, name, nil)
            if U.valid(c) then
                U.try("corps nettoyé", function()
                    local was = c:GetCollisionEnabled()
                    if was ~= 0 then
                        rec.collisions[#rec.collisions + 1] = { c = c, was = was }
                        c:SetCollisionEnabled(0)              -- nothing left for the defibrillator
                    end
                end)
            end
        end
    end
    local bodies = FindAllOf("DeadBody_C")
    for _, body in ipairs(bodies or {}) do
        local owner = U.valid(body) and U.get(body, "Mec Ref", nil) or nil
        if U.valid(owner) and owner:GetAddress() == mec:GetAddress() then
            U.try("cadavre", function() body:K2_DestroyActor() end)
        end
    end
end

local function on_clean(idx)
    idx = tonumber(idx)
    if idx then U.try("corps nettoyé", remove_body, idx) end
end

local function give_back(rec)
    for _, c in ipairs(rec.hidden) do
        if U.valid(c) then U.try("réafficher", function() c:SetVisibility(true, false) end) end
    end
    for _, h in ipairs(rec.collisions) do
        if U.valid(h.c) then U.try("collisions", function() h.c:SetCollisionEnabled(h.was) end) end
    end
end

-- The body may be shown again by the game (a revival undone by the host): hidden again.
-- A player who stays alive (a revival that was not undone, a training game) gets it all back.
local last_clean_check = 0
local function tick_cleaned(now)
    if now - last_clean_check < 1 then return end
    last_clean_check = now
    for idx, rec in pairs(cleaned) do
        local mec = rec.obj
        if not U.valid(mec) or mec:GetAddress() ~= rec.mec then
            cleaned[idx] = nil
        elseif not is_local(mec) then
            if G.is_alive(mec) then
                rec.alive_since = rec.alive_since or now
                if now - rec.alive_since > 2 then
                    give_back(rec)
                    cleaned[idx] = nil
                end
            else
                rec.alive_since = nil
                for _, name in ipairs(BODY_PARTS) do
                    local c = U.get(mec, name, nil)
                    if U.valid(c) and c:IsVisible() then U.try("corps nettoyé", remove_body, idx) break end
                end
            end
        end
    end
end

restore_bodies = function()
    for _, rec in pairs(cleaned) do give_back(rec) end
    cleaned = {}
end

-- A player who died while hidden in a vent would leave the body where the host had sent it,
-- far under the map: it is put back where the player really died.
local function body_to_death_spot(mec)
    if G.is_alive(mec) then return end
    local spot, yaw = G.death_spot(mec)
    local at = G.location(mec)
    if not spot or not at or U.dist(spot, at) < 500 then return end
    U.try("corps sous la carte", function()
        mec:K2_TeleportTo(spot, { Pitch = 0.0, Yaw = yaw or 0.0, Roll = 0.0 })
    end)
end

-- The plant was consumed: the jar is left dirty, as the game's centrifuge leaves it after
-- taking the sample out (content -1; the jar cleaner turns it back into 0, a clean jar).
-- Only if the jar is still in hand: a jar holding the plant the host saw (plant: its number),
-- not another one drawn from the bag meanwhile. The game then tells the host the jar's new
-- content, which is what gives the use back.
local function on_empty_jar(plant)
    local mec = G.local_mec()
    if not mec then return end
    local item = U.get(mec, "Hand Item", nil)
    if not U.valid(item) then return end
    local ok, name = pcall(function() return item:GetFullName() end)
    if not ok or not name:find("DA_Container", 1, true) then return end
    local wanted = tonumber(plant)
    if wanted then
        local state = U.get(mec, "Hand State", nil)
        local read, held = pcall(function() return state[G.F_STATE_VALUE] end)
        if not read or held ~= wanted then return end
    end
    U.tcall(mec, "Set Sample", G.DIRTY_JAR)
    U.try("son de consommation", A.play, "consume", "consume_sound")
end

-- The fish was consumed: the host has taken it out of the hand (the game's own calls), only
-- the sound is left to play.
local function on_eaten()
    U.try("son de consommation", A.play, "consume", "consume_sound")
end

local acked_for = nil        -- character for which the host has answered
local function send_hello()
    local mec = G.local_mec()
    if not mec or not G.controller_of(mec) then return end
    if hello_sent_for ~= mec:GetAddress() then U.log("Annonce du mod à l'hôte") end   -- once per character
    hello_sent_for = mec:GetAddress()
    N.to_host(N.OP_HELLO)
end

-- ---------------------------------------------------------------- "consume" key
-- Does something only for a role that has an item to get a use back with (the host says so in
-- the role's status, "item") or for a player who knows it is poisoned (the antidote); the host
-- decides what actually happens.
local last_use = 0

local function use_item()
    local now = U.now()
    if now - last_use < 0.5 or ghost or hiding then return end
    -- a random event may want the key too, whatever the role (a cassette to air, a dead player's beep)
    local ev = EV.key_wanted("use")
    if not (ev or poisoned or (my_role and my_status and (my_status.item or 0) ~= 0)) then return end
    local mec = G.local_mec()
    if not mec or U.get(mec, "On Tablet", false) then return end
    -- as for the game's own use of an item: not while the hands are busy (hand and bag being
    -- swapped, an item just taken or put down); not asked for an event's key (a dead player's,
    -- a truce's: that test is false for them)
    if not ev and U.get(mec, "Local Can Interact", true) == false then return end
    local menu = U.get(mec, "New Menu", nil)
    if U.valid(menu) and U.get(menu, "Menu Open", false) then return end
    last_use = now
    N.to_host(N.OP_USE)
end

-- ---------------------------------------------------------------- power key
-- Starts the role's power (the host decides what happens), for the roles that have one to
-- start. The Rêveur's stays on the eyes: for that role the key only says so.
local POWER_ROLES = { infector = true, fairy = true, medium = true, angel = true, tracker = true, hypnotist = true,
                      mimic = true, cleaner = true, stowaway = true, swapper = true, revenant = true,
                      poisoner = true, gagger = true, thief = true, echo = true, amnesiac = true,
                      vampire = true, werewolf = true, medic = true }
local last_power = 0

local function use_power()
    local now = U.now()
    -- a random event may want the key too, whatever the role (a vote, a seat, a dead player's beep)
    local ev = EV.key_wanted("act")
    if now - last_power < 0.3 or not (my_role or ev) then return end
    local mec = G.local_mec()
    if not mec then return end
    local menu = U.get(mec, "New Menu", nil)
    if U.valid(menu) and U.get(menu, "Menu Open", false) then return end
    last_power = now
    if my_role == "dreamer" and not ev then
        if not ghost then
            say("POWER_EYES", "info")
            A.power_sfx("fail")
        end
        return
    end
    -- flying or dreaming: nothing to start (and the same message, from a sleeping Rêveur's
    -- machine, tells the host that the dream is over)
    if ghost or not (POWER_ROLES[my_role] or ev) then return end
    N.to_host(N.OP_ACT)
end

-- UE4SS cannot change a key once it is registered, so every allowed key is registered and
-- only the two chosen in the LPROLES tab do something (they are never the same key).
local function install_keys()
    for _, name in ipairs(C.FREE_KEYS) do
        local code = Key[C.KEY_NAME[name] or name]
        if code then
            local ok, err = U.on_key(code, name, function()
                if C.get("power_key") == name then
                    use_power()
                elseif C.get("use_key") == name then
                    use_item()
                end
            end)
            if not ok then U.log("Touche %s non enregistrée : %s", name, tostring(err)) end
        else
            U.log("Touche %s inconnue de UE4SS", name)
        end
    end
end

-- ---------------------------------------------------------------- hooks on the local character
local function on_hit_health(mec, amount)
    if not is_local(mec) then return end
    if vamp and not ghost then vamp_absorb(mec, amount) end
    if not ghost then return end
    if ghost.kind == "fairy" then
        -- Untouchable while flying. A lethal hit is also ignored by the game itself:
        -- its death sequence starts 0.1 s later and stops when "Alive" is false.
        if U.get(mec, "Health", 1) <= 0 then ghost.lethal_at = U.now() end
        U.set(mec, "Health", ghost.health)
        return
    end
    if (amount or 0) <= 0 then return end
    -- The sleeping body was hurt: wake up where the body is. If the hit was lethal,
    -- the game's own death sequence (already pending) now runs normally at the body.
    local lethal = U.get(mec, "Health", 1) <= 0
    exit_ghost(true)
    N.to_host(N.OP_WAKE)
    if not lethal then say("DREAM_ATTACKED", "bad") end
end

local function hook(fname, fn)
    U.hook(G.fn_path(G.PATH_MEC, fname), fn)
end

function Cl.install()
    N.on("ROLE", on_role)
    N.on("MSG", on_msg)
    N.on("SAFE", on_safe)
    N.on("DREAM", on_dream)
    N.on("FAIRY", on_fairy)
    N.on("FX", on_fx)
    N.on("EMPTYJAR", on_empty_jar)
    N.on("EATEN", on_eaten)
    N.on("OPENEYES", on_open_eyes)
    N.on("MEDIUM", on_medium)
    N.on("HYPNO", on_hypno)
    N.on("SPIRIT", on_spirit)
    N.on("END", on_end)
    N.on("MIMIC", on_mimic)
    N.on("LOOK", on_look)
    U.hook(LIST_ROW .. ":Update Player", function(ctx) U.try("liste des joueurs", on_list_row, ctx) end)
    N.on("STATUS", on_status)
    N.on("HIDE", on_hide)
    N.on("CLEAN", on_clean)
    N.on("TRACK", K.track)
    N.on("CARD", K.card)
    N.on("SFX", function(kind) A.power_sfx(kind) end)
    N.on("SWAPFX", A.on_swap_fx)
    N.on("SND", A.on_sound)
    N.on("GAG", on_gag)
    N.on("POISON", on_poison)
    N.on("VAMP", on_vamp)
    U.hook(HUD_STATE .. ":Set HP", function(ctx)
        if not vamp then return end
        local ps = ctx:get()
        local mec = U.valid(ps) and U.get(ps, "Mec Ref", nil) or nil
        if U.valid(mec) and is_local(mec) then U.try("vie du vampire", vamp_number, ps, mec) end
    end)
    N.on("WOLF", on_wolf)
    N.on("VITALS", MD.on_vitals)
    MD.setup({
        ghost = function() return ghost end,
        reserve = function() return vamp and vamp.reserve or 0 end,
        role = function() return my_role, my_status end,
    })
    N.on("HP", MD.on_hp)
    N.on("HEAL", MD.on_heal)
    EV.client_setup({ ghost = function() return ghost end })      -- a Rêveur's or a Fée's own ghost
    N.on("HELLO", function()
        G.clear_messages()                     -- a new game: nothing left to show of the one before
        EV.client_reset("new")
        BK.close()
        SC.new_game()
        RC.clear()
        U.log("L'hôte demande qui a le mod (début de partie)")
        send_hello()
    end)
    SC.install()                               -- the role on the start screen, the Bouffon's end screen
    N.on("BOOK", BK.on_book)                   -- the encyclopedia of the lobby: the pages
    N.on("BOOKPAGE", BK.on_page)               -- and the one the host shows
    BK.install()
    RC.install_client()                        -- the summary of the last game
    N.on("ACK", function(version)
        BK.reset()                             -- a host met for the first time: its pages come again
        require("lpr_stats").reset()           -- and its statistics, if it has any to show
        local mec = G.local_mec()
        acked_for = mec and mec:GetAddress() or nil
        say("MOD_ACK", "info", version or "?")
        U.log("L'hôte a reconnu ce joueur (mod de l'hôte : %s, le mien : %s)", tostring(version), U.VERSION)
        if version and version ~= U.VERSION then say("VERSION_DIFF", "warn", version, U.VERSION) end
    end)
    N.install_receiver()

    hook("Hit Health", function(ctx, amount)
        on_hit_health(ctx:get(), amount:get())
    end)
    hook("Death Update", function(ctx)
        local mec = ctx:get()
        if not U.valid(mec) then return end
        local mine = is_local(mec)
        if not mine then body_to_death_spot(mec) end
        if ghost and not mine then hide_the_dead(mec) end
        if showing_dead then return end
        spirit_next = 0                       -- the game has just hidden the ghosts again
        -- someone died or came back: the game just hid the ghosts again
        if vision then vision.next = 0 end
        -- the game also reopens the local player's eyes here
        if hypno and mine then hold_eyes_shut(mec) end
    end)
    hook("OnRep_Appearance", function(ctx)
        local mec = ctx:get()
        if disguised and U.valid(mec) and is_local(mec) then protect_skin_save(mec) end
    end)
    -- Hypnosis: shut the eyes again as soon as an eye key is pressed or released, before the
    -- picture can show them open.
    for _, ev in ipairs({ "InpActEvt_IA_EyeL_K2Node_EnhancedInputActionEvent_3", "InpActEvt_IA_EyeL_K2Node_EnhancedInputActionEvent_4",
                          "InpActEvt_IA_EyeR_K2Node_EnhancedInputActionEvent_1", "InpActEvt_IA_EyeR_K2Node_EnhancedInputActionEvent_2" }) do
        hook(ev, function(ctx)
            if not hypno then return end
            local mec = ctx:get()
            if U.valid(mec) and is_local(mec) then hold_eyes_shut(mec) end
        end)
    end

    install_keys()
    U.every_tick("messages", G.pump_messages)
    U.every_tick("vision", tick_vision)
    U.every_tick("revenants", tick_spirits)
    U.every_tick("cachette", tick_hiding)
    U.every_tick("corps nettoyés", tick_cleaned)
    U.every_tick("hypnose", tick_hypno)
    U.every_tick("bâillon", tick_gag)
    U.every_tick("vampire", tick_vamp)
    U.every_tick("vie dite à l'hôte", MD.tick_vitals)
    U.every_tick("vie au-dessus des têtes", MD.tick_tags)
    -- Tell the host we have the mod: once per character, every 2 s until the host has answered
    -- (ten times at most: the host only answers the first time it hears of a player), then
    -- again now and then in case the host has changed.
    local last, last_hello, tries = 0, 0, 0
    local last_pc = nil
    U.every_tick("joueur", function(now)
        if now - last < 2 then return end
        last = now
        -- another connection (another host, a host without the mod, playing alone): nothing kept
        -- of the last host's summary, statistics and encyclopedia; a host with the mod sends them again
        local pc = G.local_pc()
        local pc_addr = U.valid(pc) and pc:GetAddress() or nil
        if pc_addr and pc_addr ~= last_pc then
            if last_pc then
                RC.clear()
                require("lpr_stats").reset()
                BK.reset()
                U.log("Nouvelle connexion : récapitulatif, statistiques et encyclopédie de l'hôte précédent effacés")
            end
            last_pc = pc_addr
        end
        local mec = G.local_mec()
        if not mec then
            if ghost then ghost = nil end
            EV.client_reset("left")                -- the game was left: a random event's part goes too
            vamp = nil
            wolf_reset()                           -- the game was left: its values go back as they were
            MD.reset()
            hello_sent_for, acked_for, tries = nil, nil, 0   -- the next character says it again at once
            return
        end
        if ghost then return end
        local addr = mec:GetAddress()
        local waiting = acked_for ~= addr and tries < 10
        if hello_sent_for ~= addr or waiting or now - last_hello > 20 then
            if hello_sent_for ~= addr then tries = 0 end
            tries = tries + 1
            last_hello = now
            send_hello()
        end
    end)
    U.log("Partie joueur prête")
end

-- Values about the role sent by the host, and the Shérif's safe person (index), or nil.
function Cl.status()
    return my_status, safe_idx
end

function Cl.role()
    return my_role
end

-- fn(role) is called whenever the local player's role changes (nil = no special role).
function Cl.on_role_change(fn)
    role_listeners[#role_listeners + 1] = fn
end

return Cl
