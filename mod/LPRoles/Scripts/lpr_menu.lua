-- LPRoles - an "LPROLES" tab in the game's pause menu.
-- Everyone sees their role and how to use it; the host also gets every setting.
-- The page is assembled from the game's own menu widgets, so it looks like the other tabs.
--
-- These widgets copy their own variables (name, range, default...) onto the screen when they
-- are first drawn, which happens when they are added to the page. So their content is set
-- after they are added; numeric variables are also filled before, as a fallback.
--
-- Texts go through G.text_call only: this UE4SS build crashes the game when a text receives
-- anything but a genuine engine text object (see lpr_game.lua). As a last resort, if the game
-- ever stops while the tab is being built, the tab is skipped at the next launch (see U.guard).
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local S = require("lpr_strings")
local RT = require("lpr_roletext")

local M = {}

local UI = "/Game/UI/Menu2/"
local CLASS = {
    selection = UI .. "W_Settings_Selection.W_Settings_Selection_C",
    value     = UI .. "W_Settings_Value.W_Settings_Value_C",
    title     = UI .. "W_Settings_Title.W_Settings_Title_C",
    text      = UI .. "W_Settings_Text.W_Settings_Text_C",
    tab       = UI .. "W_Menu_MainTabButton.W_Menu_MainTabButton_C",
    main_tab  = UI .. "W_Menu_MainTab.W_Menu_MainTab_C",
}
local EV_SELECT_RIGHT = "BndEvt__W_Settings_Selection_ButtonR_K2Node_ComponentBoundEvent_5_OnButtonPressedEvent__DelegateSignature"
local EV_SELECT_LEFT = "BndEvt__W_Settings_Selection_ButtonL_K2Node_ComponentBoundEvent_4_OnButtonPressedEvent__DelegateSignature"
local EV_VALUE_COMMIT = "BndEvt__W_Settings_Value_SpinBox_115_K2Node_ComponentBoundEvent_1_OnSpinBoxValueCommittedEvent__DelegateSignature"
local HELP_ROWS = 14                      -- rows for the role's lines (those not needed take no room)
local HELP_WIDTH = 72                     -- characters on a row; a longer line goes on over the next
local MAX_ATTEMPTS = 5

local state = { key = nil, page = nil, index = -1, tab = nil }   -- the menu the tab was built in
local rows = {}                           -- widget address -> { widget, def, values, labels }
local role_row, help_rows = nil, {}
local help_shown = {}                     -- how each help row is shown when it has something to say
local role_source = nil                   -- function returning the local player's current role
local status_source = nil                 -- function returning the host's values about it
local attempts = {}                       -- menu address -> failed attempts before anything was added
local seen_revision = -1                  -- settings revision the rows currently show
local seen_open, opened_at = false, nil   -- the pause menu as last seen by the tick, and since when
-- The host's settings are many: one group at a time is shown, chosen with the first row.
local sections = {}                       -- names of the groups, in the order of that row
local members = {}                        -- group name -> { { w, vis }, ... }: its title and its rows
local selector = nil                      -- that row (nil for a player who is not the host: all is shown)
local shown = nil                         -- the group on screen; kept from one menu to the next
local FIRST_GROUPS = { "TEST", "GÉNÉRAL" }    -- right after the personal settings, before the roles

-- ---------------------------------------------------------------- crash guard
-- Only the building of the tab is guarded (see U.guard); updates are plain protected calls.
local guard = U.guard("menu_guard.txt")

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
    U.log("Onglet LPROLES en pause %s : le jeu s'est arrêté pendant sa construction (%d fois de suite). "
        .. "F10 le remet.", guard.strikes >= 2 and "jusqu'à F10" or "pour ce lancement", guard.strikes)
    local function notice()
        if not guard.blocked then return end
        local mec = G.local_mec()
        if mec and U.valid(U.get(mec, "HUD", nil)) then
            G.say(S.MENU_TAB_OFF, S.COLOR.warn)
        else
            U.after(5, "avis onglet", notice)         -- no screen to show it on yet
        end
    end
    U.after(25, "avis onglet", notice)
end

-- F10: a tab given up after errors is tried again.
function M.retry()
    attempts = {}
end

-- ---------------------------------------------------------------- texts
-- Sets what a text block shows (a Lua string is accepted where a function expects a text).
local function set_block_text(owner, block_name, s)
    return G.text_call(U.get(owner, block_name, nil), "SetText", s)
end

-- ---------------------------------------------------------------- small helpers
local widget_lib = nil
local function create(class_path, ctx, pc)
    widget_lib = (U.valid(widget_lib) and widget_lib) or StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local cls = StaticFindObject(class_path)
    if not U.valid(cls) then error("classe de menu introuvable : " .. class_path) end
    local w = widget_lib:Create(ctx, cls, pc)
    if not U.valid(w) then error("widget non créé : " .. class_path) end
    return w
end

-- The page this mod added to a menu, if any (the game's own pages are not scroll boxes).
local function find_page(switcher)
    for i = switcher:GetChildrenCount() - 1, 0, -1 do
        local child = switcher:GetChildAt(i)
        if U.valid(child) and child:GetFullName():find("ScrollBox ", 1, true) == 1 then return child end
    end
    return nil
end

-- Values and labels offered by a bool / choice setting.
local function options_of(def)
    if def.kind == "bool" then return { false, true }, { "NON", "OUI" } end
    local labels = {}
    for i, c in ipairs(def.choices) do labels[i] = C.CHOICE_LABEL[c] or c end
    return def.choices, labels
end

local function current_index(row)
    local v = shown
    if not row.selector then v = C.get(row.def.key) end
    for i, x in ipairs(row.values) do
        if x == v then return i end
    end
    return 1
end

-- ---------------------------------------------------------------- rows
local function add_title(page, ctx, pc, name)
    local w = create(CLASS.title, ctx, pc)
    page:AddChild(w)
    set_block_text(w, "Text", name)
    return w
end

local function set_row_value(w, value)
    set_block_text(w, "TextBlock", value)
end

local function add_text(page, ctx, pc, name, value)
    local w = create(CLASS.text, ctx, pc)
    page:AddChild(w)
    set_block_text(w, "TextBlock_147", name)
    set_block_text(w, "TextBlock", value)
    return w
end

-- The widget's own list of values stays empty (the mod keeps the list). The game lights the
-- left arrow only when the widget's index is above 0, so the index is pinned to 1: both arrows
-- stay lit, and the choice wraps around.
local function show_selection(row)
    local w = row.widget
    U.set(w, "Index", 1)
    U.tcall(w, "Update Name")
    set_block_text(w, "SelectionText", row.labels[current_index(row)] or "?")
end

local function add_selection(page, ctx, pc, def)
    local w = create(CLASS.selection, ctx, pc)
    local values, labels = options_of(def)
    local row = { widget = w, def = def, values = values, labels = labels }
    G.text_call(w, "Rename", def.label)
    page:AddChild(w)
    rows[U.key(w)] = row
    show_selection(row)
    return w
end

local function show_value(row)
    U.tcall(row.widget, "Set Value", C.get(row.def.key), false)
end

local function add_value(page, ctx, pc, def)
    local w = create(CLASS.value, ctx, pc)
    local digits = (def.kind == "int") and 0 or 1
    local step = def.step or 1
    U.set(w, "Generated", false)
    U.set(w, "Default", C.get(def.key))
    U.set(w, "Min", def.min)
    U.set(w, "Max", def.max)
    U.set(w, "Slider Min", def.min)
    U.set(w, "Slider Max", def.max)
    U.set(w, "Delta", step)
    U.set(w, "Min Fractional Digits", digits)
    U.set(w, "Max Fractional Digits", digits)
    G.text_call(w, "Rename", def.label)
    page:AddChild(w)
    local row = { widget = w, def = def }
    rows[U.key(w)] = row
    local spin = U.get(w, "SpinBox_115", nil)
    if U.valid(spin) then
        U.try("réglage du champ", function()
            spin:SetDelta(step)
            spin:SetMinFractionalDigits(digits)
            spin:SetMaxFractionalDigits(digits)
        end)
    end
    U.tcall(w, "Set Range", def.min, def.max, def.min, def.max)
    show_value(row)
    return w
end

-- ---------------------------------------------------------------- one group at a time
-- A name without its accents, in capitals: what the roles are sorted by ("ÉCHO" before "FÉE").
local UNACCENTED = { ["É"] = "E", ["È"] = "E", ["Ê"] = "E", ["À"] = "A", ["Â"] = "A", ["Î"] = "I", ["Ô"] = "O",
                     ["Û"] = "U", ["Ç"] = "C", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["à"] = "a", ["â"] = "a",
                     ["î"] = "i", ["ô"] = "o", ["û"] = "u", ["ç"] = "c" }
local function sort_key(name)
    return (name:gsub("\195[\128-\191]", UNACCENTED)):upper()
end

-- The row that chooses the group: a selection like the others, tied to no setting.
local function add_selector(page, ctx, pc)
    local w = create(CLASS.selection, ctx, pc)
    local row = { widget = w, selector = true, values = sections, labels = sections }
    G.text_call(w, "Rename", S.MENU_SECTION)
    page:AddChild(w)
    rows[U.key(w)] = row
    return row
end

-- Only the chosen group takes room on the page (the others are collapsed, as the unused rows
-- of the role's help are); its rows are written again from the settings.
local function apply_sections()
    if not selector then return end
    for name, list in pairs(members) do
        for _, m in ipairs(list) do
            if U.valid(m.w) then pcall(function() m.w:SetVisibility(name == shown and m.vis or 1) end) end      -- 1: collapsed
        end
    end
    for _, row in pairs(rows) do
        if row.section == shown and U.valid(row.widget) then
            if row.values then show_selection(row) else show_value(row) end
        end
    end
end

-- Shows the current settings again (they can also change through the backup keys).
local function refresh_rows()
    seen_revision = C.revision
    for _, row in pairs(rows) do
        if U.valid(row.widget) then
            if row.values then show_selection(row) else show_value(row) end
        end
    end
end

-- When the menu or the tab opens, every row is written again from its setting, so that what is
-- shown cannot be out of date. Nothing is read back from the widgets: reading an engine text
-- is something this mod has never done in game.
local function check_rows()
    for _, row in pairs(rows) do
        if U.valid(row.widget) then
            if row.values then
                set_block_text(row.widget, "SelectionText", row.labels[current_index(row)] or "?")
            else
                show_value(row)
            end
        end
    end
end

-- ---------------------------------------------------------------- role panel
local function refresh_role()
    local role = role_source and role_source() or nil
    if U.valid(role_row) then
        set_row_value(role_row, role and (S.ROLE_NAME[role] or role) or S.MENU_NO_ROLE)
    end
    local status, safe = nil, nil
    if status_source then status, safe = status_source() end
    local pieces = {}
    for _, l in ipairs(RT.lines(role, status, safe)) do
        for _, piece in ipairs(RT.wrap(RT.plain(l), HELP_WIDTH, "   ")) do pieces[#pieces + 1] = piece end
    end
    for i, w in ipairs(help_rows) do
        if U.valid(w) then
            set_row_value(w, pieces[i] or "")
            pcall(function() w:SetVisibility(pieces[i] and (help_shown[i] or 0) or 1) end)     -- 1: collapsed
        end
    end
end

-- ---------------------------------------------------------------- building the tab
-- Layout of a widget's place in the tab column, so it can be put back identically.
local function read_slot(w)
    local rec = { w = w }
    pcall(function()
        local s = w.Slot
        local p, z = s.Padding, s.Size
        rec.padding = { Left = p.Left, Top = p.Top, Right = p.Right, Bottom = p.Bottom }
        rec.size = { Value = z.Value, SizeRule = z.SizeRule }
        rec.h, rec.v = s.HorizontalAlignment, s.VerticalAlignment
    end)
    return rec
end

local function write_slot(rec)
    local s = U.get(rec.w, "Slot", nil)
    if not U.valid(s) then return end
    if rec.padding then pcall(function() s:SetPadding(rec.padding) end) end
    if rec.size then pcall(function() s:SetSize(rec.size) end) end
    if rec.h then pcall(function() s:SetHorizontalAlignment(rec.h) end) end
    if rec.v then pcall(function() s:SetVerticalAlignment(rec.v) end) end
end

-- Moves the new tab (added last) right after the game's "Règles" tab. The column only redraws
-- what is added at its end, so the widgets that follow "Règles" are taken out and put back
-- after the new tab, each with its own layout. The page the tab opens is not affected.
local function place_after_rules(box, button)
    local count = box:GetChildrenCount()
    local rules_at = nil
    for i = 0, count - 1 do
        local c = box:GetChildAt(i)
        if U.valid(c) and c:GetFName():ToString() == "TabButton_Rules" then
            rules_at = i
            break
        end
    end
    if not rules_at then
        U.log("Menu : onglet Règles introuvable, LPROLES reste en bas de la liste")
        return
    end
    local moved = {}
    for i = rules_at + 1, count - 1 do
        local c = box:GetChildAt(i)
        if U.valid(c) and c:GetAddress() ~= button:GetAddress() then moved[#moved + 1] = read_slot(c) end
    end
    -- These are the game's own tabs: each one taken out is put back, whatever happens to the others.
    local out = {}
    for _, rec in ipairs(moved) do
        if pcall(function() box:RemoveChild(rec.w) end) then out[#out + 1] = rec end
    end
    for _, rec in ipairs(out) do
        if pcall(function() box:AddChild(rec.w) end) then
            write_slot(rec)
        else
            U.log("Menu : un onglet du jeu n'a pas pu être remis en place")
        end
    end
    U.log("Onglet LPROLES placé après Règles (%d éléments déplacés)", #out)
end

-- The tab button, with the look of the existing ones.
local function add_tab_button(tab, mec, pc, page_index)
    local box = U.get(tab, "VerticalBox_50", nil)
    if not U.valid(box) then error("colonne des onglets introuvable") end
    local first = nil
    pcall(function()
        local buttons = tab.Buttons
        if #buttons > 0 and U.valid(buttons[1]) then first = buttons[1] end
        if #buttons ~= page_index then
            U.log("Menu : %d onglets pour la page %d, le titre de l'onglet peut être faux", #buttons, page_index)
        end
    end)

    local button = create(CLASS.tab, mec, pc)
    U.set(button, "ID", page_index)
    U.set(button, "Parent", tab)
    local icon = first and U.get(first, "Icon", nil)
    if U.valid(icon) then U.set(button, "Icon", icon) end
    box:AddChild(button)
    set_block_text(button, "Text", S.MENU_TAB)
    U.tcall(button, "Set Selection", false)

    -- Same placement as the other buttons of the column.
    if first then
        local rec = read_slot(first)
        rec.w = button
        write_slot(rec)
    end
    U.try("menu : position de l'onglet", place_after_rules, box, button)

    -- Being in this list lets the game highlight the tab.
    if not G.array_add(tab, "Buttons", button) then
        U.log("Menu : onglet non enregistré dans la liste du jeu (il s'ouvre mais ne s'allume pas)")
    end
    state.index, state.tab = page_index, tab
end

-- The game titles the page with the button's own name, which cannot be written from here
-- (see the note on texts): the title is set right after the game has done it.
local function on_select_tab(ctx, id)
    local tab = ctx:get()
    if not U.valid(tab) or not U.valid(state.tab) or U.key(tab) ~= U.key(state.tab) then return end
    if id:get() ~= state.index then return end
    local mec = G.local_mec()
    local menu = mec and U.get(mec, "New Menu", nil)
    if U.valid(menu) then set_block_text(menu, "MainTitle", S.MENU_TAB) end
    check_rows()                               -- what the rows show is the settings, whatever happened since
end

local function build(menu, mec)
    local pc = G.local_pc()
    local tab = U.get(menu, "MainTab", nil)
    local switcher = U.get(menu, "MainSwitcher", nil)
    local tree = U.get(menu, "WidgetTree", nil)
    if not (U.valid(tab) and U.valid(switcher) and U.valid(tree)) then error("menu pas encore prêt") end
    local scroll_class = StaticFindObject("/Script/UMG.ScrollBox")
    if not U.valid(scroll_class) then error("ScrollBox introuvable") end

    local page = StaticConstructObject(scroll_class, tree)
    if not U.valid(page) then error("page non créée") end
    switcher:AddChild(page)
    local page_index = switcher:GetChildrenCount() - 1
    state = { key = U.key(menu), page = page, index = -1, tab = nil }
    rows, role_row, help_rows, help_shown = {}, nil, {}, {}

    -- Role and help, for everyone. One bad row must not prevent the rest.
    role_row = U.try("menu : rôle", add_text, page, mec, pc, S.MENU_ROLE, S.MENU_NO_ROLE)
    for _ = 1, HELP_ROWS do
        local w = U.try("menu : aide", add_text, page, mec, pc, "", "")
        help_rows[#help_rows + 1] = w
        if U.valid(w) then pcall(function() help_shown[#help_rows] = w:GetVisibility() end) end
    end
    U.try("menu : rôle", refresh_role)

    -- Settings: each player's own (keys), then the game's, for the host only. The host's are
    -- many: a first row chooses the group shown. After the personal settings come the test
    -- aids and the general settings, then every role's on/off switch in one group, then the
    -- roles one by one (each with its switch again: two rows of one setting stay alike).
    local host = G.is_host()
    sections, members, selector = {}, {}, nil
    if host then selector = U.try("menu : choix du groupe", add_selector, page, mec, pc) end
    local function member(section, w)
        if not U.valid(w) then return end
        local vis = 0
        pcall(function() vis = w:GetVisibility() end)
        members[section] = members[section] or {}
        table.insert(members[section], { w = w, vis = vis })
        local row = rows[U.key(w)]
        if row then row.section = section end
    end
    local function add_group(section, defs)
        sections[#sections + 1] = section
        member(section, U.try("menu : " .. section, add_title, page, mec, pc, section))
        for _, def in ipairs(defs) do
            local add = (def.kind == "bool" or def.kind == "choice") and add_selection or add_value
            member(section, U.try("menu : " .. def.key, add, page, mec, pc, def))
        end
    end
    local function defs_where(wanted)
        local out = {}
        for _, def in ipairs(C.DEFS) do
            if wanted(def) then out[#out + 1] = def end
        end
        return out
    end
    local function of_group(group) return defs_where(function(def) return def.group == group end) end
    local placed = {}
    for _, group in ipairs(C.GROUPS) do
        if C.PERSONAL_GROUPS[group] then
            add_group(group, of_group(group))
            placed[group] = true
        end
    end
    if host then
        for _, group in ipairs(FIRST_GROUPS) do
            add_group(group, of_group(group))
            placed[group] = true
        end
        -- the roles in alphabetical order, here and in the row that chooses the group: with
        -- that many, one knows which way to turn
        local switches = defs_where(function(def) return def.key:match("^.+_enabled$") ~= nil end)
        table.sort(switches, function(a, b) return sort_key(a.label) < sort_key(b.label) end)
        add_group(S.MENU_ROLES, switches)
        local roles = {}
        for _, group in ipairs(C.GROUPS) do
            if not placed[group] then roles[#roles + 1] = group end
        end
        table.sort(roles, function(a, b) return sort_key(a) < sort_key(b) end)
        for _, group in ipairs(roles) do add_group(group, of_group(group)) end
        -- the group last looked at; the first time, the test aids if a role is forced, else the first
        local known = false
        for _, name in ipairs(sections) do known = known or name == shown end
        if not known then shown = (C.get("force_host_role") ~= "none") and "TEST" or sections[1] end
        if selector then
            U.try("menu : choix du groupe", show_selection, selector)
            U.try("menu : groupe affiché", apply_sections)
        end
    else
        U.try("menu : note", add_text, page, mec, pc, "", S.MENU_HOST_ONLY)
    end
    seen_revision = C.revision

    add_tab_button(tab, mec, pc, page_index)
    U.log("Onglet LPROLES ajouté au menu (page %d)", page_index)
end

-- ---------------------------------------------------------------- reacting to the widgets
-- The events are hooked for the whole widget class: keep only the rows of the current page.
local function row_of(w)
    if not U.valid(w) or not U.valid(state.page) then return nil end
    local row = rows[U.key(w)]
    if not row then return nil end
    local ok, parent = pcall(function() return w:GetParent() end)
    if not ok or not U.valid(parent) or U.key(parent) ~= U.key(state.page) then return nil end
    return row
end

-- True while the pause menu is on screen.
local function menu_open()
    local mec = G.local_mec()
    local menu = mec and U.get(mec, "New Menu", nil)
    return U.valid(menu) and U.get(menu, "Menu Open", false) == true
end

-- A setting only changes by a click in the open menu. The journal says how each change came:
-- a setting found changed without anybody meaning to can then be traced.
local function on_selection(ctx, dir)
    local w = ctx:get()
    local row = row_of(w)
    if not row or not row.values then return end
    if row.selector then
        -- another group of settings: nothing is changed, only what the page shows
        if menu_open() then shown = row.values[((current_index(row) - 1 + dir) % #row.values) + 1] end
        guarded("menu : groupe affiché", function()
            show_selection(row)
            apply_sections()
        end)
        return
    end
    if not menu_open() then
        -- the game has already blanked the row: what it shows is put back, nothing changes
        guarded("menu : choix", show_selection, row)
        U.log("Réglage %s : appui ignoré, le menu Échap est fermé", row.def.key)
        return
    end
    local i = ((current_index(row) - 1 + dir) % #row.values) + 1
    C.set(row.def.key, row.values[i], true)
    guarded("menu : choix", function()
        show_selection(row)
        -- a role's switch has a second row, in the group of all the switches
        for _, other in pairs(rows) do
            if other ~= row and other.values and other.def == row.def and U.valid(other.widget) then show_selection(other) end
        end
        if row.def.key == "use_key" or row.def.key == "power_key" then
            refresh_rows()                      -- the other key takes the letter just left, if it was the same
            refresh_role()
        end
    end)
    seen_revision = C.revision
    -- how the change came: enough to tell a click made on purpose from a stray one
    local over = U.get(w, dir > 0 and "Hover R" or "Hover L", nil)
    local since = (not seen_open or not opened_at) and "moins de 1 s" or string.format("%d s", math.floor(U.now() - opened_at))
    local scroll = "?"
    pcall(function() scroll = string.format("%d", math.floor(state.page:GetScrollOffset() + 0.5)) end)
    U.log("Réglage %s = %s (onglet LPROLES, flèche %s, souris dessus : %s, menu ouvert depuis %s, défilement %s)",
        row.def.key, C.format(row.def.key), dir > 0 and "droite" or "gauche",
        over == true and "oui" or over == false and "non" or "?", since, scroll)
end

local function on_value(ctx, value)
    local row = row_of(ctx:get())
    if not row or row.values then return end
    -- no "menu open" test here: a number typed is confirmed when its field loses the keyboard,
    -- which is also what closing the menu does
    local v = value:get()
    if type(v) ~= "number" then return end
    local before = C.get(row.def.key)
    C.set(row.def.key, v, false)                -- rounded and limited as the setting requires
    if C.get(row.def.key) == before then
        show_value(row)
        seen_revision = C.revision
        return
    end
    C.save()
    show_value(row)             -- the setting may have been rounded or limited
    seen_revision = C.revision
    U.log("Réglage %s = %s (onglet LPROLES, saisie)", row.def.key, C.format(row.def.key))
end

function M.install(get_role, on_role_change, get_status)
    role_source = get_role
    status_source = get_status
    check_previous_crash()
    if on_role_change then on_role_change(function() guarded("menu : rôle", refresh_role) end) end

    U.hook(CLASS.selection .. ":" .. EV_SELECT_RIGHT, function(ctx) on_selection(ctx, 1) end)
    U.hook(CLASS.selection .. ":" .. EV_SELECT_LEFT, function(ctx) on_selection(ctx, -1) end)
    U.hook(CLASS.value .. ":" .. EV_VALUE_COMMIT, function(ctx, value) on_value(ctx, value) end)
    U.hook(CLASS.main_tab .. ":Select Tab", function(ctx, id) guarded("menu : titre", on_select_tab, ctx, id) end)

    local last, was_open = 0, false
    U.every_tick("menu", function(now)
        if now - last < 1 then return end
        last = now
        if not C.get("menu_tab") or guard.blocked then return end    -- off in config.txt, or after a stop
        local mec = G.local_mec()
        local menu = mec and U.get(mec, "New Menu", nil)
        local switcher = U.valid(menu) and U.get(menu, "MainSwitcher", nil) or nil
        if not U.valid(switcher) then return end

        -- The tab exists as long as the menu holds the page; a new menu (new game, new
        -- character) has none, whatever its address.
        local found, page = pcall(find_page, switcher)
        if found and page then
            local open = U.get(menu, "Menu Open", false) == true
            local opened = open and not was_open
            was_open, seen_open = open, open
            if opened then opened_at = now end
            if state.key == U.key(menu) and U.valid(state.page) then
                if seen_revision ~= C.revision then
                    guarded("menu : mise à jour", function()
                        refresh_rows()
                        refresh_role()                -- the help names the chosen key
                    end)
                elseif opened then
                    guarded("menu : vérification", check_rows)
                end
            end
            return
        end

        local key = U.key(menu)
        if (attempts[key] or 0) >= MAX_ATTEMPTS then return end
        local ok, err = guard.run(build, menu, mec)
        if not ok then U.log("ERREUR dans menu : construction : %s", tostring(err)) end
        if ok then
            attempts[key] = nil
        else
            attempts[key] = (attempts[key] or 0) + 1
            local _, added = pcall(find_page, switcher)
            if added or attempts[key] >= MAX_ATTEMPTS then
                U.log("Onglet LPROLES incomplet : %s (touches F5 à F9 toujours disponibles)", tostring(err))
            end
        end
    end)
end

return M
