-- LPRoles - what the mod draws in the building for one player: the Traqueur's silhouette
-- seen through walls, the Shérif's green sphere over the safe person and the access card
-- shown to the Shérif. Each is drawn on that player's machine only.
local U = require("lpr_util")
local G = require("lpr_game")

local K = {}

-- ---------------------------------------------------------------- Traqueur: seen through walls
-- The game has nothing that shows through walls, but the engine ships a material drawn over
-- everything (the one its editor uses for control handles). Three stretched balls with that
-- material are attached to the tracked player, on the tracker's machine only: legs, chest and
-- head. They follow the player and are removed when the tracking ends.
-- Heights above the character's position, which is at its feet.
local XRAY_PARTS = {
    { z = 42.0,  scale = { X = 0.26, Y = 0.34, Z = 0.84 } },      -- legs
    { z = 112.0, scale = { X = 0.30, Y = 0.46, Z = 0.62 } },      -- chest (wider across the shoulders)
    { z = 158.0, scale = { X = 0.27, Y = 0.27, Z = 0.29 } },      -- head
}
local tracked = nil          -- { mec, parts = { components } }

local function track_off()
    local t = tracked
    tracked = nil
    if not t then return end
    for _, c in ipairs(t.parts) do
        if U.valid(c) and U.valid(t.mec) then
            U.try("fin de traque", function() c:K2_DestroyComponent(t.mec) end)
        end
    end
end

local function on_track(idx, tenths)
    track_off()
    idx = tonumber(idx) or -1
    local secs = (tonumber(tenths) or 0) / 10
    if idx < 0 or secs <= 0 then return end
    local mec = G.mec_by_index(idx)
    local cls = StaticFindObject("/Script/Engine.StaticMeshComponent")
    local ball, mat = G.asset(G.BALL_MESH), G.asset(G.XRAY_MATERIAL)
    if not mec or not U.valid(cls) or not ball or not mat then
        U.log("Traqueur : silhouette impossible (%s)", (not mat) and "matériau introuvable" or "élément introuvable")
        return
    end
    local rec = { mec = mec, parts = {} }
    tracked = rec
    -- the part of the character that turns with the player (its position never turns)
    local turning = U.get(mec, "Orientation", nil)
    for _, part in ipairs(XRAY_PARTS) do
        U.try("silhouette", function()
            -- put where the player stands, then tied to the turning part: place kept, direction
            -- taken from it (wherever that part itself sits inside the character)
            local at = U.valid(turning) and G.location(mec) or nil
            local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 },
                        Translation = at and { X = at.X, Y = at.Y, Z = at.Z + part.z } or { X = 0.0, Y = 0.0, Z = part.z },
                        Scale3D = part.scale }
            local c = mec:AddComponentByClass(cls, at ~= nil, t, false)
            if not U.valid(c) then return end
            rec.parts[#rec.parts + 1] = c         -- noted first: always removed with the others
            c:SetCollisionEnabled(0)              -- before it has a shape: never in anybody's way
            if at then
                pcall(function() c:SetMobility(2) end)
                local ok, attached = pcall(function()
                    return c:K2_AttachToComponent(turning, FName("None"), 1, 2, 1, false)
                end)
                if not ok or attached == false then
                    rec.parts[#rec.parts] = nil
                    c:K2_DestroyComponent(mec)    -- never a still shape left where the target stood
                    return
                end
            end
            pcall(function() c:SetCastShadow(false) end)
            c:SetStaticMesh(ball)
            local mid = c:CreateDynamicMaterialInstance(0, mat, FName("None"))
            if U.valid(mid) then
                mid:SetVectorParameterValue(FName("Color"), { R = 1.0, G = 0.25, B = 0.1, A = 1.0 })
                mid:SetScalarParameterValue(FName("Opacity"), 0.45)
            else
                c:SetMaterial(0, mat)
            end
        end)
    end
    U.after(secs + 0.5, "fin de traque", function()
        if tracked == rec then track_off() end
    end)
    U.log("Traqueur : silhouette posée sur %s (%d éléments)", G.player_name(mec), #rec.parts)
end

-- ---------------------------------------------------------------- Shérif: a green sphere
-- The safe person is marked with the game's own sphere, red like the one dissidents see over
-- each other. On the Shérif's machine it gets a green copy of its material for as long as the
-- marker lasts, then its own material back.
local safe_orb = nil         -- { orb, original }

local function orb_restore()
    local rec = safe_orb
    safe_orb = nil
    if rec and U.valid(rec.orb) and U.valid(rec.original) then
        U.try("sphère", function() rec.orb:SetMaterial(0, rec.original) end)
    end
end

local function orb_green(mec, secs)
    orb_restore()
    local orb = U.get(mec, "HackerSphere", nil)
    if not U.valid(orb) then return end
    U.try("sphère verte", function()
        local original = orb:GetMaterial(0)
        if not U.valid(original) then return end
        local mid = orb:CreateDynamicMaterialInstance(0, original, FName("None"))
        if not U.valid(mid) then return end
        local rec = { orb = orb, original = original }
        safe_orb = rec
        U.after(secs + 1, "sphère verte", function()
            if safe_orb == rec then orb_restore() end
        end)
        for _, name in ipairs({ "Color", "eColor" }) do
            local param = FName(name)
            local v = mid:K2_GetVectorParameterValue(param)
            local strength = math.max(v.R + 0.0, v.G + 0.0, v.B + 0.0)
            if strength > 0.001 then
                mid:SetVectorParameterValue(param, { R = 0.08 * strength, G = strength, B = 0.2 * strength, A = v.A + 0.0 })
            end
        end
    end)
end

-- ---------------------------------------------------------------- Shérif: an access card shown
-- The host says where one access card lies. On the Shérif's machine only, a ball around the
-- card and a column above it are drawn there, in yellow: with the engine's material drawn over
-- everything (the Traqueur's silhouette is made of it) when the host lets it be seen through
-- the walls, else with the glowing material of the game's spheres. The shapes belong to this
-- player's character but are tied to nothing, so they stay where they are put; the host says
-- when the card has been picked up.
local CARD_COLOR = { R = 1.0, G = 0.78, B = 0.08 }
local CARD_SHAPES = {
    { z = 0.0,   scale = { X = 0.40, Y = 0.40, Z = 0.40 } },      -- around the card
    { z = 160.0, scale = { X = 0.12, Y = 0.12, Z = 3.0 } },       -- a column above it, to be found from afar
}
local card_mark = nil        -- { mec, parts = { components } }

local function card_off()
    local m = card_mark
    card_mark = nil
    if not m then return end
    for _, c in ipairs(m.parts) do
        if U.valid(c) and U.valid(m.mec) then
            pcall(function() c:SetVisibility(false, false) end)   -- unseen even if it cannot be removed
            U.try("carte en surbrillance : retrait", function() c:K2_DestroyComponent(m.mec) end)
        end
    end
end

local function on_card(on, x, y, z, walls)
    card_off()
    if on ~= "1" then return end
    local mec = G.local_mec()
    local cls = StaticFindObject("/Script/Engine.StaticMeshComponent")
    local through = walls == "1"
    local ball, mat = G.asset(G.BALL_MESH), G.asset(through and G.XRAY_MATERIAL or G.ORB_MATERIAL)
    if not mec or not U.valid(cls) or not ball or not mat then
        U.log("Shérif : carte en surbrillance impossible (%s)", (not mat) and "matériau introuvable" or "élément introuvable")
        return
    end
    local at = { X = (tonumber(x) or 0) + 0.0, Y = (tonumber(y) or 0) + 0.0, Z = (tonumber(z) or 0) + 0.0 }
    local rec = { mec = mec, parts = {} }
    card_mark = rec
    for _, shape in ipairs(CARD_SHAPES) do
        local c = nil
        local dressed = U.try("carte en surbrillance", function()
            local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 },
                        Translation = { X = at.X, Y = at.Y, Z = at.Z + shape.z },
                        Scale3D = shape.scale }
            -- "true": tied to nothing, so placed in the building and left there
            c = mec:AddComponentByClass(cls, true, t, false)
            if not U.valid(c) then return false end
            c:SetCollisionEnabled(0)              -- before it has a shape: never in anybody's way
            pcall(function() c:SetCastShadow(false) end)
            if c:SetStaticMesh(ball) == false then error("forme refusée") end
            local mid = c:CreateDynamicMaterialInstance(0, mat, FName("None"))
            if not U.valid(mid) then error("matière non modifiable") end
            if through then
                mid:SetVectorParameterValue(FName("Color"),
                    { R = CARD_COLOR.R, G = CARD_COLOR.G, B = CARD_COLOR.B, A = 1.0 })
                mid:SetScalarParameterValue(FName("Opacity"), 0.55)
            else
                -- the material's own brightness is kept, only the hue changes
                for _, name in ipairs({ "Color", "eColor" }) do
                    local param = FName(name)
                    local v = mid:K2_GetVectorParameterValue(param)
                    local strength = math.max(v.R + 0.0, v.G + 0.0, v.B + 0.0)
                    if strength > 0.001 then
                        mid:SetVectorParameterValue(param, { R = CARD_COLOR.R * strength, G = CARD_COLOR.G * strength,
                                                             B = CARD_COLOR.B * strength, A = v.A + 0.0 })
                    end
                end
            end
            return true
        end)
        if dressed then
            rec.parts[#rec.parts + 1] = c
        elseif U.valid(c) then
            -- no shape rather than one in the material's own colour (red: the dissidents')
            pcall(function() c:SetVisibility(false, false) end)
            U.try("carte en surbrillance : retrait", function() c:K2_DestroyComponent(mec) end)
        end
    end
    U.log("Shérif : carte d'accès en surbrillance (%d éléments, %s)", #rec.parts,
        through and "vue à travers les murs" or "sans traverser les murs")
end

K.track = on_track                 -- host's "TRACK idx tenths"
K.track_off = track_off
K.orb_green = orb_green            -- (mec, seconds)
K.orb_restore = orb_restore
K.card = on_card                   -- host's "CARD on x y z walls"
K.card_off = card_off

return K
