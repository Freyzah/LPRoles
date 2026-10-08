-- LPRoles - a "role" page on the in-game tablet, reached with two arrows in its header.
--
-- The page lives inside the tablet's in-game screen: the arrows and a text panel are added
-- to it, and turning to the role page hides the task list and the map (the game itself never
-- shows or hides those, so they stay hidden until the arrow back is pressed).
-- The tablet is drawn in the world, so its layout is measured once it has been drawn.
-- Texts follow the same rule as the menu: only G.text_call, never a text variable.
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local S = require("lpr_strings")
local RT = require("lpr_roletext")

local T = {}

local BUTTON_CLASS = "/Game/Character/Tablet/Interface/W_Tablet_ButtonText.W_Tablet_ButtonText_C"
local EV_PRESSED = "BndEvt__W_Tablet_ButtonText_W_Tablet_Trigger_K2Node_ComponentBoundEvent_0_On Pressed__DelegateSignature"
local VISIBLE, HIDDEN = 0, 2           -- ESlateVisibility
local LINES = 7                        -- explanation lines under the status

local page = nil                       -- the built page: { ui, key, prev, next, panel, lines, hidden, on_role }
local role_source = nil
local status_source = nil
local attempts = {}

-- ---------------------------------------------------------------- crash guard (as for the menu tab)
-- Only the building of the page is guarded (see U.guard); the rest are plain protected calls.
local guard = U.guard("tablet_guard.txt")

local function guarded(what, fn, ...)
    local res = table.pack(pcall(fn, ...))
    if not res[1] then
        U.log("ERREUR dans %s : %s", what, tostring(res[2]))
        return false, res[2]
    end
    return true, table.unpack(res, 2, res.n)
end

local function check_previous_crash()
    if not guard.blocked then return end
    U.log("Page LPROLES de la tablette en pause %s : le jeu s'est arrêté pendant sa construction "
        .. "(%d fois de suite). F10 la remet.", guard.strikes >= 2 and "jusqu'à F10" or "pour ce lancement", guard.strikes)
    local function notice()
        if not guard.blocked then return end
        local mec = G.local_mec()
        if mec and U.valid(U.get(mec, "HUD", nil)) then
            G.say(S.TABLET_OFF, S.COLOR.warn)
        else
            U.after(5, "avis tablette", notice)       -- no screen to show it on yet
        end
    end
    U.after(30, "avis tablette", notice)
end

-- F10: a page given up after errors is tried again.
function T.retry()
    attempts = {}
end

-- ---------------------------------------------------------------- finding the local tablet screen
-- The tablet in hand keeps its screen ("Screen"); otherwise the screen whose owner is us.
local function local_tablet_ui()
    local mec = G.local_mec()
    if not mec then return nil, "personnage local introuvable" end
    local tablet = U.get(mec, "Hand Tablet", nil)
    local screen = U.valid(tablet) and U.get(tablet, "Screen", nil) or nil
    if U.valid(screen) then return screen end
    local list = FindAllOf("W_Tablet_UI_C")
    if not list then return nil, "aucun écran de tablette" end
    for _, ui in ipairs(list) do
        local owner = U.valid(ui) and U.get(ui, "Mec Ref", nil)
        if U.valid(owner) and owner:GetAddress() == mec:GetAddress() then return ui end
    end
    return nil, string.format("%d écran(s) de tablette, aucun à nous", #list)
end

local function same(a, b)
    return U.valid(a) and U.valid(b) and a:GetAddress() == b:GetAddress()
end

-- ---------------------------------------------------------------- measuring the drawn layout
local slate = nil
local function v2(v) return { X = v.X + 0.0, Y = v.Y + 0.0 } end

-- Rectangle of a widget, in the coordinates of the in-game screen (canvas).
local rect_in
rect_in = function(canvas_geo, w)
    slate = (U.valid(slate) and slate) or StaticFindObject("/Script/UMG.Default__SlateBlueprintLibrary")
    local g = w:GetCachedGeometry()
    local size = v2(slate:GetLocalSize(g))
    if size.X <= 0 or size.Y <= 0 then return nil end
    -- all four corners: some parts of the map are rotated or moved
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, c in ipairs({ { X = 0.0, Y = 0.0 }, { X = size.X, Y = 0.0 }, { X = 0.0, Y = size.Y }, size }) do
        local p = v2(slate:AbsoluteToLocal(canvas_geo, v2(slate:LocalToAbsolute(g, c))))
        x0, y0, x1, y1 = math.min(x0, p.X), math.min(y0, p.Y), math.max(x1, p.X), math.max(y1, p.Y)
    end
    return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end

local function fmt(r) return r and string.format("%.0f,%.0f %.0fx%.0f", r.x, r.y, r.w, r.h) or "-" end

-- ---------------------------------------------------------------- text style
-- Each text starts with the tablet buttons' font and colour; bold, size and colour are then
-- changed on the widget's own copy and applied. The typeface name must be a genuine engine
-- name object (FName), never a string: UE4SS does not check (see the note on texts).
local BOLD = nil
local function rgba(c, a) return { R = c[1], G = c[2], B = c[3], A = a or c[4] or 1.0 } end

-- The look is read from the page's own hidden template each time, never kept: a font or
-- colour read from a widget points into that widget, and copying it once the widget is gone
-- crashes the game (0.5.0 crashed at the end of a game that way, D53).
local function style(tb, look, bold, scale, color)
    local t = look.template
    if U.valid(t) then
        pcall(function() tb:SetFont(t.Font) end)
        pcall(function() tb:SetColorAndOpacity(t.ColorAndOpacity) end)
    elseif not look.warned then
        look.warned = true
        U.log("Tablette : modèle de texte perdu, police par défaut")
    end
    if bold or (scale and scale ~= 1) then
        pcall(function()
            local f = tb.Font
            if bold then
                BOLD = BOLD or FName("Bold")
                f.TypefaceFontName = BOLD
            end
            if scale and scale ~= 1 then f.Size = math.floor(look.size * scale + 0.5) end
            tb:SetFont(tb.Font)
        end)
    end
    if color then
        pcall(function()
            local c = tb.ColorAndOpacity
            c.SpecifiedColor = rgba(color)
            c.ColorUseRule = 0                 -- "specified colour"
            tb:SetColorAndOpacity(tb.ColorAndOpacity)
        end)
    end
end

-- Plant code of a word, if it is one (punctuation around it ignored).
local function plant_of(word)
    local bare = word:gsub("[%p]+$", "")
    for n, code in pairs(S.PLANT_CODE) do
        if code == bare then return n end
    end
    return nil
end

-- The plant named in the lines of the page, from line `first` on, if any (a role names one at
-- most; the band above the lines is plain text, and may name another: a poison's antidote).
local function page_plant(lines, first)
    for i = first or 1, #lines do
        local l = lines[i]
        for _, w in ipairs(RT.segments(l)) do
            local p = plant_of(w.text)
            if p then return p end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- plant colours on the screen
-- The screen draws its blue ink in the colour of the map room under each pixel: "Color 1" to
-- "Color 7" (and "Emissive 1" to "Emissive 7") of the screen's material, one per room (D52).
-- While the role page is shown the map is hidden, so all seven can take the colour of the
-- plant named on the page: written in blue, its name then comes out in that colour wherever
-- it is. They are read first and put back as soon as the page is left.
local ROOM_PARAMS = nil
local function room_params()
    if not ROOM_PARAMS then
        ROOM_PARAMS = {}
        for i = 1, 7 do
            ROOM_PARAMS[#ROOM_PARAMS + 1] = { name = FName("Color " .. i), key = "color" }
            ROOM_PARAMS[#ROOM_PARAMS + 1] = { name = FName("Emissive " .. i), key = "glow" }
        end
    end
    return ROOM_PARAMS
end

-- The material of the tablet screen in hand (the copy made for that tablet only), if that
-- screen is the one showing the page.
local function screen_material()
    local mec = G.local_mec()
    local tablet = mec and U.get(mec, "Hand Tablet", nil) or nil
    local comp = U.valid(tablet) and U.get(tablet, "Hand Widget", nil) or nil
    if not U.valid(comp) or not page then return nil end
    local ok, mid = pcall(function()
        if not same(comp:GetWidget(), page.ui) then return nil end
        return comp:GetMaterialInstance()
    end)
    if ok and U.valid(mid) then return mid end
    return nil
end

local function untint()
    local t = page and page.tint
    if not t then return end
    page.tint = nil
    if not U.valid(t.mid) then return end
    for _, s in ipairs(t.saved) do
        pcall(function() t.mid:SetVectorParameterValue(s.name, s.value) end)
    end
    U.dbg("Tablette : couleurs de la carte rétablies")
end

-- Ink of the plant's name: the blue ink once the room colours are the plant's, the glowing
-- white for the white plant, nil (like the other marked words) when the screen cannot be set.
local function tint_for(plant)
    local spec = plant and S.TABLET.plant[plant] or nil
    if not spec then untint(); return nil end
    if spec.white then untint(); return S.TABLET.glow_ink end
    local mid = screen_material()
    if not mid then untint(); return nil end
    local addr = mid:GetAddress()
    local t = page.tint
    if t and U.valid(t.mid) and t.mid:GetAddress() == addr then
        if t.plant == plant then return S.TABLET.room_ink end
        t.plant = plant                        -- same screen, other plant: the saved map colours stay
    else
        untint()
        if page.unreadable == addr then return nil end                 -- already tried on this screen
        local saved = {}
        for _, prm in ipairs(room_params()) do
            local ok, c = pcall(function()
                local v = mid:K2_GetVectorParameterValue(prm.name)
                return { R = v.R + 0.0, G = v.G + 0.0, B = v.B + 0.0, A = v.A + 0.0 }
            end)
            if not ok then
                page.unreadable = addr
                U.log("Tablette : couleurs de la carte illisibles (%s), noms de plantes sans couleur", tostring(c))
                return nil
            end
            saved[#saved + 1] = { name = prm.name, value = c }
        end
        page.tint = { mid = mid, plant = plant, saved = saved }       -- noted first: always put back
    end
    for _, prm in ipairs(room_params()) do
        local c = spec[prm.key]
        pcall(function() mid:SetVectorParameterValue(prm.name, rgba(c, 1.0)) end)
    end
    U.dbg("Tablette : couleurs de la carte réglées sur %s", S.PLANT_CODE[plant] or "?")
    return S.TABLET.room_ink
end

-- One line of explanation: a bullet, then its words, the marked ones in bold (the page's plant
-- in its colour).
local function fill_line(view, wb, line)
    pcall(function() wb:ClearChildren() end)
    if line == nil or line == "" then
        wb:SetVisibility(1)                    -- collapsed: takes no room
        return
    end
    wb:SetVisibility(VISIBLE)
    local words = RT.segments(line)
    table.insert(words, 1, { text = "-", em = true, bullet = true })
    for _, w in ipairs(words) do
        local tb = StaticConstructObject(view.tb_class, view.tree)
        wb:AddChild(tb)
        local color = nil
        if w.bullet then
            color = S.TABLET.bullet
        elseif w.em then
            local p = plant_of(w.text)
            color = (p and p == view.plant and view.plant_ink) or S.TABLET.accent
        end
        style(tb, view.look, w.em, view.body_scale, color)
        G.text_call(tb, "SetText", w.text)
    end
end

-- ---------------------------------------------------------------- the page
local function show_role()
    if not page or not U.valid(page.ui) or not page.view or not U.valid(page.view.tree) then return end
    local view = page.view
    local role = role_source and role_source() or nil
    local status, safe = nil, nil
    if status_source then status, safe = status_source() end
    local lines, kind = RT.lines(role, status, safe)
    local shown = view.shown
    local title = RT.title(role)
    if shown.title ~= title and U.valid(view.title) then
        G.text_call(view.title, "SetText", title)
        shown.title = title
    end
    -- the status line, light text in a dark band (no status without a role)
    local st = role and lines[1] or nil
    local first = role and 2 or 1
    if st ~= shown.status then
        if st then
            view.band:SetVisibility(VISIBLE)
            G.text_call(view.status, "SetText", RT.plain(st))
        else
            view.band:SetVisibility(1)
        end
        shown.status = st
    end
    -- the plant's colour, only while the page is on screen (the map uses those colours)
    local plant = page_plant(lines, first)
    local ink = nil
    if page.on_role then ink = tint_for(plant) end
    if plant ~= view.plant or ink ~= view.plant_ink then
        view.plant, view.plant_ink = plant, ink
        -- every line written again; "false" and not "nothing", so that a row the new page
        -- does not use is emptied too (it kept a line of the previous page otherwise)
        for i = 1, #view.rows do shown.rows[i] = false end
    end
    for i, wb in ipairs(view.rows) do
        local l = lines[first + i - 1]
        if shown.rows[i] ~= l then
            fill_line(view, wb, l)
            shown.rows[i] = l
        end
    end
end

local function set_page(n)
    if not page then return end
    if n == 2 and not page.on_role then
        page.hidden = page.hidden or {}
        for _, w in ipairs(page.to_hide) do
            if U.valid(w) then
                local was = w:GetVisibility()
                if was ~= HIDDEN and was ~= 1 then
                    page.hidden[#page.hidden + 1] = { w = w, was = was }   -- noted first: never lost
                    w:SetVisibility(HIDDEN)
                end
            end
        end
        page.on_role = true
        local ok, e = pcall(show_role)
        page.panel:SetVisibility(VISIBLE)       -- shown even if filling it failed: never a blank screen
        if not ok then U.log("ERREUR dans tablette : page : %s", tostring(e)) end
    elseif n == 1 and page.on_role then
        untint()                               -- the map's colours back first
        page.panel:SetVisibility(HIDDEN)
        for _, h in ipairs(page.hidden or {}) do
            -- only if still hidden as the mod left it: the game may have changed it since
            if U.valid(h.w) then
                pcall(function() if h.w:GetVisibility() == HIDDEN then h.w:SetVisibility(h.was) end end)
            end
        end
        page.hidden = {}
        page.on_role = false
    end
end

local widget_lib = nil
local function make_arrow(ui, canvas, label, r)
    widget_lib = (U.valid(widget_lib) and widget_lib) or StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local cls = StaticFindObject(BUTTON_CLASS)
    if not U.valid(cls) then error("bouton de tablette introuvable") end
    local b = widget_lib:Create(ui, cls, G.local_pc())
    if not U.valid(b) then error("bouton non créé") end
    -- same look as the tablet's "return to lobby" button (read before the button is drawn)
    local ref = U.get(ui, "B_return_to_lobby", nil)
    if U.valid(ref) then
        for _, prop in ipairs({ "Text Size", "Letter Spacing", "Letter Thickness", "Color Preset", "Color" }) do
            local v = U.get(ref, prop, nil)
            if type(v) == "number" then U.set(b, prop, v) end
        end
    end
    canvas:AddChild(b)
    if T.created then T.created[#T.created + 1] = b end
    local slot = b.Slot
    slot:SetPosition({ X = r.x, Y = r.y })
    slot:SetSize({ X = r.w, Y = r.h })
    slot:SetZOrder(60)
    G.text_call(b, "Rename", label)
    return b
end

local function make_panel(ui, canvas, r)
    local tree = U.get(ui, "WidgetTree", nil)
    local vb_class = StaticFindObject("/Script/UMG.VerticalBox")
    local tb_class = StaticFindObject("/Script/UMG.TextBlock")
    local wb_class = StaticFindObject("/Script/UMG.WrapBox")
    local border_class = StaticFindObject("/Script/UMG.Border")
    if not (U.valid(tree) and U.valid(vb_class) and U.valid(tb_class) and U.valid(wb_class) and U.valid(border_class)) then
        error("éléments de page introuvables")
    end
    local panel = StaticConstructObject(vb_class, tree)
    canvas:AddChild(panel)
    if T.created then T.created[#T.created + 1] = panel end
    local slot = panel.Slot
    slot:SetPosition({ X = r.x, Y = r.y })
    slot:SetSize({ X = r.w, Y = r.h })
    slot:SetZOrder(50)
    panel:SetVisibility(HIDDEN)
    -- the text style of the tablet's own buttons (never modified: each text gets a copy)
    local ref = U.get(U.get(ui, "B_return_to_lobby", nil), "ButtonText", nil)
    local look = { size = 24 }
    -- never shown, but inside the page (collapsed): a widget attached to nothing is deleted
    -- by the engine's next clean-up
    local template = StaticConstructObject(tb_class, tree)
    panel:AddChild(template)
    template:SetVisibility(1)
    if U.valid(ref) then
        pcall(function() template:SetFont(ref.Font) end)
        pcall(function()
            template:SetColorAndOpacity(ref.ColorAndOpacity)
            local c = template.ColorAndOpacity
            c.SpecifiedColor = rgba(S.TABLET.ink, 1.0)                -- the dark ink, whatever the hover state
            c.ColorUseRule = 0
            template:SetColorAndOpacity(template.ColorAndOpacity)
        end)
    end
    look.template = template
    pcall(function() look.size = template.Font.Size + 0 end)          -- a plain number
    local view = { tree = tree, tb_class = tb_class, border_class = border_class, look = look,
                   body_scale = 0.85, rows = {}, shown = { rows = {}, status = false } }
    local function pad(w, bottom)
        pcall(function() w.Slot:SetPadding({ Left = 0.0, Top = 0.0, Right = 0.0, Bottom = bottom }) end)
    end

    -- role name: bold, larger
    view.title = StaticConstructObject(tb_class, tree)
    panel:AddChild(view.title)
    style(view.title, look, true, 1.35, S.TABLET.title)
    pad(view.title, 14.0)

    -- status: light bold text in a dark band (opaque: a see-through band gets dithered)
    view.band = StaticConstructObject(border_class, tree)
    panel:AddChild(view.band)
    pcall(function() view.band:SetBrushColor(rgba(S.TABLET.band, 1.0)) end)
    pcall(function() view.band:SetPadding({ Left = 18.0, Top = 8.0, Right = 18.0, Bottom = 8.0 }) end)
    view.status = StaticConstructObject(tb_class, tree)
    view.band:SetContent(view.status)
    pcall(function() view.status:SetAutoWrapText(true) end)
    style(view.status, look, true, 1, S.TABLET.band_text)
    pad(view.band, 26.0)
    view.band:SetVisibility(1)                 -- shown once there is a status

    -- explanation lines: words laid out one after the other, wrapping at the edge
    local gap = math.floor((look.size or 24) * 0.85 * 0.3 + 0.5)
    for i = 1, LINES do
        local wb = StaticConstructObject(wb_class, tree)
        panel:AddChild(wb)
        pcall(function() wb:SetInnerSlotPadding({ X = gap, Y = 2.0 }) end)
        pad(wb, 10.0)
        wb:SetVisibility(1)
        view.rows[i] = wb
    end
    return panel, view
end

-- Second way to know where a widget is: its place in the canvas, as laid out by the game
-- (exact when it is anchored at a single point, which is the usual case for such screens).
local function slot_rect(w)
    local s = U.get(w, "Slot", nil)
    if not U.valid(s) then return nil end
    local ok, r = pcall(function()
        local p, z = s:GetPosition(), s:GetSize()
        local a = s:GetAnchors()
        if a.Minimum.X ~= a.Maximum.X or a.Minimum.Y ~= a.Maximum.Y then return nil end   -- stretched
        return { x = p.X, y = p.Y, w = z.X, h = z.Y }
    end)
    if ok and r and r.w > 0 and r.h > 0 then return r end
    return nil
end

-- Where a widget is on the in-game screen: measured on the drawn screen, else from its slot.
local function locate(ui, w)
    local canvas = U.get(ui, "GameMenu", nil)
    local ok, r = pcall(function() return rect_in(canvas:GetCachedGeometry(), w) end)
    if ok and r then return r, "mesure" end
    local s = slot_rect(w)
    if s then return s, "disposition" end
    return nil, ok and "pas encore dessinée" or tostring(r)
end

-- nil when the page can be built, else why not (written to the log when it changes).
local function not_ready(ui)
    local canvas = U.get(ui, "GameMenu", nil)
    local switcher = U.get(ui, "Switcher", nil)
    if not (U.valid(canvas) and U.valid(switcher)) then return "écran de partie introuvable" end
    local ok, active = pcall(function() return switcher:GetActiveWidget() end)
    if not ok then return "sélecteur illisible : " .. tostring(active) end
    if not same(active, canvas) then
        local name = "?"
        pcall(function() name = active:GetFName():ToString() end)
        return "la tablette affiche " .. name
    end
    local tasks = U.get(ui, "W_TaskList", nil)
    if not U.valid(tasks) then return "liste des tâches introuvable" end
    local r, how = locate(ui, tasks)
    if not r then return "liste des tâches non mesurable (" .. tostring(how) .. ")" end
    return nil
end

local function build(ui)
    local canvas = U.get(ui, "GameMenu", nil)
    local cgeo = canvas:GetCachedGeometry()
    local tl, how = locate(ui, U.get(ui, "W_TaskList", nil))
    if not tl then error("liste des tâches sans taille") end
    U.log("Tablette : liste des tâches placée par %s", how)
    -- the other widgets are located the same way
    rect_in = (how == "mesure") and rect_in or function(_, w) return slot_rect(w) end
    local back = U.get(ui, "B_return_to_lobby", nil)

    -- The screen's direct children: the header is the wide strip above the task list.
    local children, header = {}, nil
    local full = rect_in(cgeo, canvas)
    for i = 0, canvas:GetChildrenCount() - 1 do
        local c = canvas:GetChildAt(i)
        if U.valid(c) then
            local ok, r = pcall(rect_in, cgeo, c)
            r = ok and r or nil
            children[#children + 1] = { w = c, r = r }
            pcall(function()
                U.log("Tablette : %s (%s) %s", c:GetFName():ToString(), c:GetClass():GetFName():ToString(), fmt(r))
            end)
            if r and r.y + r.h <= tl.y + 4 and r.w >= 2 * tl.w and r.h < 0.3 * tl.h then
                if not header or r.y > header.y then header = r end
            end
        end
    end
    -- Without a header among them, its place is taken from the screenshot proportions.
    header = header or { x = tl.x, y = tl.y - 0.129 * tl.h, w = 3.34 * tl.w, h = 0.082 * tl.h }
    U.log("Tablette : liste %s, bandeau %s, écran %s", fmt(tl), fmt(header), fmt(full))

    -- What the role page hides: everything but the header, the lobby button and full-screen
    -- backgrounds.
    local to_hide = {}
    for _, ch in ipairs(children) do
        local r = ch.r
        local is_header = r and header and math.abs(r.x - header.x) < 2 and math.abs(r.y - header.y) < 2
        local is_back = same(ch.w, back)
        local is_background = r and full and r.w * r.h >= 0.85 * full.w * full.h
        -- the game's cursors and buttons stay as they are
        local name = ""
        pcall(function() name = ch.w:GetFName():ToString() end)
        local is_kept = name:find("Cursor", 1, true) ~= nil or name:sub(1, 2) == "B_"
        if not is_header and not is_back and not is_background and not is_kept then to_hide[#to_hide + 1] = ch.w end
    end

    local ah = header.h * 0.8
    local aw = math.max(ah * 1.8, 0.14 * tl.w)
    local ay = header.y + (header.h - ah) / 2
    local margin = 0.012 * header.w
    local pad = 0.06 * tl.w
    local p = { ui = ui, key = U.key(ui), to_hide = to_hide, hidden = {}, on_role = false }
    T.created = {}
    local ok, err = pcall(function()
        p.prev = make_arrow(ui, canvas, "<", { x = header.x + margin, y = ay, w = aw, h = ah })
        p.next = make_arrow(ui, canvas, ">", { x = header.x + header.w - aw - margin, y = ay, w = aw, h = ah })
        p.panel, p.view = make_panel(ui, canvas, {
            x = tl.x + pad, y = tl.y + pad, w = header.x + header.w - tl.x - 2 * pad, h = tl.h - 2 * pad })
    end)
    if not ok then
        -- take back whatever was added, and do not try again on this tablet
        for _, w in ipairs(T.created) do
            if U.valid(w) then pcall(function() canvas:RemoveChild(w) end) end
        end
        T.created = nil
        attempts[p.key] = 99
        error(err)
    end
    T.created = nil
    page = p
    show_role()
    U.log("Page LPROLES ajoutée à la tablette (%d éléments masqués sur la page rôle)", #to_hide)
    return true
end

-- ---------------------------------------------------------------- reacting
local function on_pressed(ctx)
    if not page then return end
    local b = ctx:get()
    if same(b, page.next) then
        set_page(2)
    elseif same(b, page.prev) then
        set_page(1)
    end
end

local last_report = nil
function T.report(reason)
    if reason == last_report then return end
    last_report = reason
    U.log("Tablette : %s", tostring(reason))
end

function T.install(get_role, on_role_change, get_status)
    role_source = get_role
    status_source = get_status
    check_previous_crash()
    if on_role_change then on_role_change(function() if page then guarded("tablette : rôle", show_role) end end) end
    U.hook(BUTTON_CLASS .. ":" .. EV_PRESSED, function(ctx) guarded("tablette : flèche", on_pressed, ctx) end)

    local last = 0
    U.every_tick("tablette", function(now)
        if now - last < 0.5 then return end
        last = now
        if not C.get("tablet_page") then
            -- turned off during play: back to the tasks, arrows and page out of sight
            if page and not page.off then
                guarded("tablette : arrêt", function()
                    set_page(1)
                    for _, w in ipairs({ page.prev, page.next }) do
                        if U.valid(w) then w:SetVisibility(HIDDEN) end
                    end
                end)
                page.off = true
            end
            return
        end
        if page and page.off then
            for _, w in ipairs({ page.prev, page.next }) do
                if U.valid(w) then pcall(function() w:SetVisibility(VISIBLE) end) end
            end
            page.off = false
        end
        local ui, why = local_tablet_ui()
        if not ui then return T.report(why) end
        if page and (not U.valid(page.ui) or page.key ~= U.key(ui) or not U.valid(page.prev)) then
            -- a new tablet (new game, new character): what the page changed is put back first
            pcall(untint)
            for _, h in ipairs(page.hidden or {}) do
                if U.valid(h.w) then
                    pcall(function() if h.w:GetVisibility() == HIDDEN then h.w:SetVisibility(h.was) end end)
                end
            end
            -- on the same screen, the old page and arrows go: a new set is built
            for _, w in ipairs({ page.panel, page.prev, page.next }) do
                if U.valid(w) then pcall(function() w:RemoveFromParent() end) end
            end
            page = nil
        end
        if page then
            -- back on the tasks whenever the in-game screen is left (lobby, video, tutorial)
            local switcher = U.get(ui, "Switcher", nil)
            if page.on_role and U.valid(switcher) and not same(switcher:GetActiveWidget(), U.get(ui, "GameMenu", nil)) then
                guarded("tablette : retour", set_page, 1)
            elseif page.on_role then
                -- the screen's material is made again after a video: colours set again at once
                local t = page.tint
                local mid = t and screen_material() or nil
                local stale = t and (not mid or not U.valid(t.mid) or mid:GetAddress() ~= t.mid:GetAddress())
                if stale or now - (page.checked or 0) >= 2 then
                    page.checked = now
                    local ok, e = pcall(show_role)
                    if not ok and e ~= page.last_error then
                        page.last_error = e
                        U.log("ERREUR dans tablette : page : %s", tostring(e))
                    end
                end
            end
            return
        end
        local key = U.key(ui)
        if (attempts[key] or 0) >= 5 then return end
        local reason = not_ready(ui)
        if reason then return T.report(reason) end
        T.report("prête")
        if guard.blocked then return end
        local ok, err = guard.run(build, ui)
        if not ok then U.log("ERREUR dans tablette : construction : %s", tostring(err)) end
        if not ok then
            attempts[key] = (attempts[key] or 0) + 1
            if attempts[key] >= 5 then U.log("Page LPROLES de la tablette abandonnée : %s", tostring(err)) end
        end
    end)
end

return T
