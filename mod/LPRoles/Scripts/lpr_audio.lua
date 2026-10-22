-- LPRoles - the mod's sounds: files of the "sounds" folder played on this machine, as they
-- are or around another player (or at a spot of the building), fading with the distance.
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local SND = require("lpr_sound")

local A = {}

local play_sound, stop_sound, power_sfx, role_sound      -- defined below
local sound_around_on, sound_around_off

-- ---------------------------------------------------------------- custom sound
-- Sounds are files in the mod's "sounds" folder (WAV or MP3), played by the engine's own media
-- player (Windows Media Foundation, the one the tablet videos use), on this machine only.
-- A player serves one sound at a time, a new sound replacing the one it plays: the short
-- sounds share one ("sfx"), the Fée's flight has its own ("flight") so that both are heard;
-- so have the sound of a hypnosis ("hypno") and the sounds that come from somebody else's
-- deed ("event"), which a power used meanwhile must not cut.
local medias = {}            -- channel -> { owner, comp, player }

-- The player's own volume for the mod's sounds, given to a sound component (and to the
-- engine's sound source inside it) before each sound.
local function set_volume(comp)
    local v = (C.get("sound_volume") or 100) / 100
    pcall(function() comp:SetVolumeMultiplier(v) end)
    local inner = U.get(comp, "AudioComponent", nil)
    if U.valid(inner) then pcall(function() inner:SetVolumeMultiplier(v) end) end
end

local function sound_file(name)
    for _, ext in ipairs({ ".mp3", ".wav" }) do
        local path = U.MOD_DIR .. "/sounds/" .. name .. ext
        local f = io.open(path, "rb")
        if f then
            f:close()
            return (path:gsub("/", "\\"))
        end
    end
    return nil
end

-- name: the file in "sounds"; setting: the personal setting that switches this sound on;
-- seconds (optional): how long it must last (see lpr_sound.lua); channel (optional): the
-- player that plays it, "sfx" when not given; fade_in (optional): seconds of fade-in of a
-- sound made to last `seconds`, when not the usual one. Returns true when the sound plays.
play_sound = function(name, setting, seconds, channel, fade_in)
    if not C.get(setting) then return false end
    channel = channel or "sfx"
    local path = sound_file(name)
    local mec = G.local_mec()
    if not path or not mec then return false end
    -- a player and a sound component on the local character (new character: new ones)
    local media = medias[channel]
    if not media or media.owner ~= mec:GetAddress() or not U.valid(media.comp) or not U.valid(media.player) then
        if media and media.owner == mec:GetAddress() and U.valid(media.comp) then
            U.try("son", function() media.comp:K2_DestroyComponent(mec) end)
        end
        medias[channel] = nil
        local player_class = StaticFindObject("/Script/MediaAssets.MediaPlayer")
        local comp_class = StaticFindObject("/Script/MediaAssets.MediaSoundComponent")
        if not (U.valid(player_class) and U.valid(comp_class)) then return end
        local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 }, Translation = { X = 0.0, Y = 0.0, Z = 0.0 },
                    Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
        local comp = mec:AddComponentByClass(comp_class, false, t, false)
        if not U.valid(comp) then return end
        local player = StaticConstructObject(player_class, comp)
        U.set(comp, "MediaPlayer", player)       -- a real reference: keeps the player alive
        comp:SetMediaPlayer(player)
        pcall(function() comp:SetActive(true, false) end)
        media = { owner = mec:GetAddress(), comp = comp, player = player }
        medias[channel] = media
    end
    -- a new source each time: it only has to live until the player has opened it
    local source_class = StaticFindObject("/Script/MediaAssets.FileMediaSource")
    if not U.valid(source_class) then return end
    local source = StaticConstructObject(source_class, media.comp)
    source:SetFilePath(SND.playable(path, seconds, fade_in))    -- a copy with silence at the end: nothing cut
    set_volume(media.comp)
    if media.player:OpenSource(source) == false then   -- plays as soon as it is open
        U.log("Son %s : le fichier n'a pas pu être ouvert (%s)", name, path)
        return false
    end
    return true
end

-- Stops the sound a player is playing.
stop_sound = function(channel)
    local media = medias[channel or "sfx"]
    if media and U.valid(media.player) then media.player:Close() end
end

-- The short sound that answers an attempt to use a power: "ok" when it starts, "fail" when
-- it does not, whatever the reason.
power_sfx = function(kind)
    if kind == "fail" then
        U.try("son d'échec", play_sound, "fail", "fail_sound")
    else
        U.try("son de démarrage", play_sound, "success", "start_sound")
    end
end

-- A role's own sound (a file of the "sounds" folder), heard as it is by the player it is
-- about. Those that come from somebody else's deed play on a player of their own. Returns
-- whether it plays: not when the player switched the roles' sounds off, or without the file.
local OWN_CHANNEL = { martyr = "event", recruit = "event", angel = "event", hypnosis = "event" }

role_sound = function(name)
    return U.try("son de rôle", play_sound, name, "role_sounds", nil, OWN_CHANNEL[name]) == true
end

-- A sound heard around another player (the flying Fée): a sound component of its own on that
-- player's character, which it follows. It is heard from where the character is and fades
-- with the distance: full within "inner" cm, silent beyond "inner + falloff". The engine
-- takes these settings when the component starts, and the component starts by itself when it
-- is added: it is stopped, set, then started again. The settings are written on the
-- component and on the engine's own sound source inside it, whichever one the engine reads.
-- A sound can also be placed at a spot of the building instead (`spot`): the component is
-- then left unattached, at that spot, and belongs to the local character.
local SOUND_AROUND = { inner = 300.0, falloff = 1800.0 }

-- Raises an error if the two switches cannot be set. Returns whether the distances were set
-- too: otherwise the engine's own apply (full within 4 m, silent beyond 40 m).
local function fades_with_distance(c)
    c.bAllowSpatialization = true
    c.bOverrideAttenuation = true
    return (pcall(function()
        local a = c.AttenuationOverrides
        a.FalloffDistance = SOUND_AROUND.falloff
        a.AttenuationShapeExtents = { X = SOUND_AROUND.inner, Y = 0.0, Z = 0.0 }
    end))
end

-- Returns what sound_around_off needs, or nil when nothing plays. mec: the character the
-- sound is hung on; with `spot` (a place of the building), the character it belongs to.
sound_around_on = function(mec, name, setting, seconds, spot)
    if not C.get(setting) then return nil end
    local path = sound_file(name)
    local player_class = StaticFindObject("/Script/MediaAssets.MediaPlayer")
    local comp_class = StaticFindObject("/Script/MediaAssets.MediaSoundComponent")
    local source_class = StaticFindObject("/Script/MediaAssets.FileMediaSource")
    if not path or not (U.valid(player_class) and U.valid(comp_class) and U.valid(source_class)) then return nil end
    local at = spot and { X = spot.X + 0.0, Y = spot.Y + 0.0, Z = spot.Z + 0.0 } or { X = 0.0, Y = 0.0, Z = 100.0 }
    local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 }, Translation = at,
                Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
    -- not attached (second argument) when it is placed at a spot: it then stays there
    local comp = mec:AddComponentByClass(comp_class, spot ~= nil, t, false)
    if not U.valid(comp) then return nil end
    local rec = { mec = mec, comp = comp }
    local set, tuned = { false, false }, { false, false }   -- for the component, for its sound source
    local playing = U.try("son autour d'un joueur", function()
        pcall(function() comp:SetActive(false, false) end)
        set[1], tuned[1] = pcall(fades_with_distance, comp)
        local inner = U.get(comp, "AudioComponent", nil)
        if U.valid(inner) then set[2], tuned[2] = pcall(fades_with_distance, inner) end
        local player = StaticConstructObject(player_class, comp)
        rec.player = player
        U.set(comp, "MediaPlayer", player)       -- a real reference: keeps the player alive
        comp:SetMediaPlayer(player)
        comp:SetActive(true, true)               -- started again: the settings above are taken now
        set_volume(comp)
        local source = StaticConstructObject(source_class, comp)
        source:SetFilePath(SND.playable(path, seconds))
        return player:OpenSource(source) ~= false
    end)
    -- never a sound heard everywhere: without the distance settings, no sound at all
    local where = spot and "un endroit" or G.player_name(mec)
    if not playing or not (set[1] or set[2]) then
        sound_around_off(rec)
        U.log("Son %s autour de %s : non joué (%s)", name, where,
            playing and "réglages de distance refusés" or "lecture impossible")
        return nil
    end
    local function word(i) return set[i] and (tuned[i] == true and "réglé" or "portée du moteur") or "refusé" end
    U.log("Son %s autour de %s : s'éteint avec la distance, jusqu'à %d m (composant : %s ; source : %s)", name,
        where, math.floor((SOUND_AROUND.inner + SOUND_AROUND.falloff) / 100), word(1), word(2))
    return rec
end

sound_around_off = function(rec)
    if not rec then return end
    if U.valid(rec.player) then pcall(function() rec.player:Close() end) end
    if U.valid(rec.comp) and U.valid(rec.mec) then
        U.try("son autour d'un joueur : retrait", function() rec.comp:K2_DestroyComponent(rec.mec) end)
    end
end

-- An Échangeur has just swapped places with somebody (a, b: their indexes). The swap's sound
-- takes the place of the usual "power started" sound: the two of them hear it as it is, the
-- others hear it around each of the two, fading with the distance.
local SWAP_SOUND_SECONDS = 3     -- the sound lasts half a second: what was placed around them is then removed

local function on_swap_fx(a, b)
    local mine = G.local_mec()
    local first, second = G.mec_by_index(tonumber(a) or -1), G.mec_by_index(tonumber(b) or -1)
    local function is_mine(mec) return mine ~= nil and mec ~= nil and mec:GetAddress() == mine:GetAddress() end
    if is_mine(first) or is_mine(second) then
        U.try("son de l'échange", play_sound, "swap", "swap_sound")
        return
    end
    local function around(mec)
        if not mec then return end
        local rec = U.try("son de l'échange", sound_around_on, mec, "swap", "swap_sound")
        if rec then U.after(SWAP_SOUND_SECONDS, "son de l'échange", function() sound_around_off(rec) end) end
    end
    around(first)
    around(second)
end

-- A role's sound for the players around (the host's "SND" message, sent to all). The players
-- it is about (a, and b when there is one) hear it as it is, with their own message; the
-- others hear it around player a, fading with the distance. With a spot (x, y, z), it is
-- heard around that spot instead: the Clandestin's character is sent far away while it hides.
-- What was placed is removed once the sound is over.
local AROUND_SECONDS = 10    -- when the length of the sound cannot be told

local function on_sound(name, a, b, x, y, z)
    if type(name) ~= "string" or not name:match("^[%w_]+$") then return end
    local mine = G.local_mec()
    local who = G.mec_by_index(tonumber(a) or -1)
    if not mine or G.is_local(who) or G.is_local(G.mec_by_index(tonumber(b) or -1)) then return end
    local spot = (tonumber(x) and tonumber(y) and tonumber(z)) and U.vec(tonumber(x), tonumber(y), tonumber(z)) or nil
    local on = spot and mine or who
    if not on then return end
    local rec = U.try("son de rôle", sound_around_on, on, name, "role_sounds", nil, spot)
    if not rec then return end
    local path = sound_file(name)
    local secs = (path and SND.seconds(path) or AROUND_SECONDS) + 2      -- the silence added at the end, and a margin
    U.after(secs, "son de rôle", function() sound_around_off(rec) end)
end

A.play = play_sound                -- (name, setting, seconds, channel, fade_in): true when it plays
A.stop = stop_sound                -- (channel)
A.power_sfx = power_sfx            -- ("ok" | "fail")
A.role_sound = role_sound          -- (name): true when it plays
A.around_on = sound_around_on      -- (mec, name, setting, seconds, spot): what around_off needs
A.around_off = sound_around_off
A.on_swap_fx = on_swap_fx          -- host's "SWAPFX a b"
A.on_sound = on_sound              -- host's "SND name a b x y z"

return A
