"""Static verification of the LPRoles mod against the game's real Blueprints.

1. Lua syntax + scope check of every script (luacheck.py).
2. Every `Module.name` used across scripts exists in that module.
3. Every game function / property / asset the mod touches exists in the game, with the expected
   number of parameters and (for hooks) the expected network kind.
4. Every game name that appears in the Lua sources is covered by the manifest in (3).

Usage: python verify_mod.py
"""
import glob, os, re, sys
import luacheck

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
SCRIPTS = os.path.join(ROOT, "mod", "LPRoles", "Scripts")
BP = os.path.join(ROOT, "analysis", "bp")

DUMPS = {"Mec": "Character__Mec", "GM": "Gameplay__GM", "HUD": "UI__Game__W_inGame",
         "Notif": "UI__Game__W_MainNotif", "UpperNotif": "UI__Game__W_UpperNotif",
         "PlayerStateW": "UI__Game__W_PlayerState",
         "Selection": "UI__Menu2__W_Settings_Selection", "Value": "UI__Menu2__W_Settings_Value",
         "TextW": "UI__Menu2__W_Settings_Text", "Title": "UI__Menu2__W_Settings_Title",
         "TabButton": "UI__Menu2__W_Menu_MainTabButton", "NewMenu": "UI__Menu2__W_NewMenu",
         "MainTab": "UI__Menu2__W_Menu_MainTab", "PlayerList": "UI__Game__W_Player_List",
         "DeadBody": "Character__Ghost__DeadBody", "TabletUI": "Character__Tablet__Interface__W_Tablet_UI", "TabletButton": "Character__Tablet__Interface__W_Tablet_ButtonText", "Tablet": "Character__Tablet__Tablet",
         "WorldItem": "Items__WorldItem", "ItemSpawner": "Items__Item_Spawner",
         "PlayerData": "Character__Data_Player"}

EV_RIGHT = "BndEvt__W_Settings_Selection_ButtonR_K2Node_ComponentBoundEvent_5_OnButtonPressedEvent__DelegateSignature"
EV_LEFT = "BndEvt__W_Settings_Selection_ButtonL_K2Node_ComponentBoundEvent_4_OnButtonPressedEvent__DelegateSignature"
EV_COMMIT = "BndEvt__W_Settings_Value_SpinBox_115_K2Node_ComponentBoundEvent_1_OnSpinBoxValueCommittedEvent__DelegateSignature"

# (owner, name, parameter count, required flags)
FUNCTIONS = [
    ("Mec", "Net Eye State", 1, "Server"), ("Mec", "Net Set Stance", 1, "Server"),
    ("Mec", "All Update Locomotion", 4, "Multicast"), ("Mec", "Net Update Locomotion", 4, "Server"),
    ("Mec", "Net Take Item", 3, "Server"), ("Mec", "Take Item", 3, "Client"),
    ("Mec", "Set Player Role", 1, "Server"), ("Mec", "Game Start Message", 1, "Client"),
    ("Mec", "Set Hacker Sphere", 1, "Client"), ("Mec", "Clear Hacker Sphere", 0, "Client"),
    ("Mec", "Request TP", 2, "Client"), ("Mec", "Net Request TP", 2, "Server"), ("Mec", "Apply Mic State", 0, ""), ("Mec", "Force Off Tablet", 0, ""),
    ("Mec", "Set Center of Mass Offset", 0, ""), ("Mec", "Death Deaf", 0, ""), ("Mec", "Death Update", 0, ""),
    ("Mec", "Set Sample", 1, ""), ("Mec", "Net Deal Damage", 8, "Server"), ("Mec", "Net Death", 3, "Server"),
    ("Mec", "Hit Health", 3, "Client"), ("Mec", "Let Item", 0, "Client"), ("Mec", "Net Let Item", 0, "Server"),
    ("Mec", "Net Set Item State", 1, "Server"), ("Mec", "Add Buff", 2, "Server"),
    ("Mec", "Request Net Interaction", 3, "Server"),
    ("GM", "Select Game Roles", 1, ""), ("GM", "End Game", 2, ""), ("GM", "Set HackerSphere", 1, ""),
    ("HUD", "Death Hidders", 1, ""), ("Notif", "Show Message", 2, ""), ("UpperNotif", "Show Message", 2, ""),
    ("PlayerStateW", "Set HP", 0, ""),
    ("Mec", "Check Eyes State", 0, ""), ("Mec", "Net Switch Item", 1, "Server"), ("Mec", "Set Bag Item", 1, "Client"),
    ("Selection", "Rename", 1, ""), ("Selection", EV_RIGHT, 0, ""), ("Selection", EV_LEFT, 0, ""),
    ("Value", "Rename", 1, ""), ("Value", "Set Range", 4, ""), ("Value", "Set Value", 2, ""),
    ("Value", EV_COMMIT, 2, ""), ("TextW", "Set Name", 1, ""), ("TextW", "Set Text", 1, ""),
    ("Mec", "Death", 2, "Client"), ("Mec", "Rez Effect", 2, "Client"), ("Mec", "All Rez Effect", 0, "Multicast"),
    ("PlayerList", "Update Player", 0, ""),
    ("Mec", "OnRep_Appearance", 0, ""), ("Mec", "Net Rez", 0, "Server"),
    ("TabletButton", "Rename", 1, ""),
    ("TabletButton", "BndEvt__W_Tablet_ButtonText_W_Tablet_Trigger_K2Node_ComponentBoundEvent_0_On Pressed__DelegateSignature", 0, ""),
    ("Mec", "InpActEvt_IA_EyeL_K2Node_EnhancedInputActionEvent_3", 4, ""), ("Mec", "InpActEvt_IA_EyeL_K2Node_EnhancedInputActionEvent_4", 4, ""),
    ("Mec", "InpActEvt_IA_EyeR_K2Node_EnhancedInputActionEvent_1", 4, ""), ("Mec", "InpActEvt_IA_EyeR_K2Node_EnhancedInputActionEvent_2", 4, ""),
    ("Selection", "Update Name", 0, ""), ("TabButton", "Set Selection", 1, ""), ("MainTab", "Select Tab", 1, ""),
    ("ItemSpawner", "Spawn Item", 1, ""), ("GM", "End on Death", 0, ""),
]
FIRST_PARAM = {("Mec", "Net Deal Damage"): "Victim", ("Mec", "Hit Health"): "Health", ("Mec", "Net Eye State"): "Eyes State",
               ("Value", EV_COMMIT): "InValue"}

PROPERTIES = [
    ("Mec", "Player Role"), ("Mec", "Net Alive State"), ("Mec", "PlayerName"), ("Mec", "Player Index"),
    ("Mec", "Net Hand ItemNew"), ("Mec", "HUD"), ("Mec", "Alive"), ("Mec", "Health"), ("Mec", "Stamina"),
    ("Mec", "Can Talk"), ("Mec", "Body Collider"), ("Mec", "Ghost Root"), ("Mec", "HackerSphere"),
    ("Mec", "HandMesh"), ("Mec", "BodyMesh"), ("Mec", "BodyTabletMesh"), ("Mec", "Hand Tablet"),
    ("Mec", "Body FX"), ("Mec", "Hand FX"), ("Mec", "Net Aim Target"), ("Mec", "Net Orientation"),
    ("Mec", "EyesState"),
    ("GM", "In Game"), ("GM", "Difficulty"), ("GM", "Innocents"), ("GM", "Hackers"),
    ("HUD", "W_MainNotif"), ("HUD", "W_UpperNotif"), ("HUD", "PlayerState"),
    ("Mec", "WinkL"), ("Mec", "WinkR"), ("Mec", "WinkLock"), ("Mec", "Net Bag ItemNew"), ("Mec", "Hand Item"), ("Mec", "Hand State"),
    ("Mec", "New Menu"), ("Mec", "Net Stance"),
    ("Selection", "SelectionText"), ("Value", "SpinBox_115"), ("Title", "Text"),
    ("TabButton", "ID"), ("TabButton", "Parent"), ("TabButton", "Button Name"), ("TabButton", "Icon"), ("TabButton", "Text"),
    ("NewMenu", "MainTab"), ("NewMenu", "MainSwitcher"), ("MainTab", "Buttons"), ("MainTab", "VerticalBox_50"),
    ("Selection", "Index"), ("Selection", "Hover L"), ("Selection", "Hover R"), ("Value", "Generated"), ("Value", "Default"), ("Value", "Min"), ("Value", "Max"),
    ("Value", "Slider Min"), ("Value", "Slider Max"), ("Value", "Delta"),
    ("Value", "Min Fractional Digits"), ("Value", "Max Fractional Digits"),
    ("Title", "Name"), ("TextW", "Name"), ("TextW", "Default Text"), ("TextW", "TextBlock"), ("TextW", "TextBlock_147"),
    ("Mec", "Net Item Switching"), ("NewMenu", "MainTitle"), ("NewMenu", "Menu Open"), ("Mec", "On Tablet"),
    ("Mec", "SkM Hands"), ("Mec", "Charm Mesh"), ("Mec", "FishMesh"),
    ("Mec", "Appearance"), ("Mec", "Saved Appearance"), ("Mec", "Lock Movements"), ("Mec", "SkM Body"),
    ("Mec", "SkM Head"), ("DeadBody", "Mec Ref"), ("Mec", "Local Can Interact"),
    ("TabletUI", "Mec Ref"), ("TabletUI", "GameMenu"), ("TabletUI", "Switcher"), ("TabletUI", "W_TaskList"),
    ("TabletUI", "B_return_to_lobby"), ("Mec", "Hand Tablet"), ("TabletButton", "ButtonText"), ("TabletButton", "Text Size"),
    ("TabletButton", "Letter Spacing"), ("TabletButton", "Letter Thickness"), ("TabletButton", "Color Preset"),
    ("TabletButton", "Color"), ("Tablet", "Hand Widget"), ("Mec", "Orientation"), ("Mec", "Head Collider"), ("Mec", "Head Hitbox"),
    ("PlayerList", "Target Mec"), ("PlayerList", "color_border"),
    ("WorldItem", "Data"), ("ItemSpawner", "Used"),
    ("Mec", "PlayerData"), ("Mec", "Stamina Regenering"), ("PlayerStateW", "Mec Ref"), ("PlayerStateW", "HPtext"),
    ("PlayerData", "Min Regen"), ("PlayerData", "Max Regen"), ("PlayerData", "Regen HP Speed"),
]
# Native functions whose first parameter is a text.
TEXT_NATIVES = {"SetText", "K2_SetText"}
# Engine properties (not Blueprint variables): checked by name only against this list.
ENGINE_PROPERTIES = {"Screen", "Controller", "Pawn", "PlayerState", "RelativeScale3D", "WidgetTree", "Slot", "bHidden", "Font", "ColorAndOpacity", "Preset", "Color", "bAlwaysRelevant", "MediaPlayer", "BrushColor", "AudioComponent"}

NATIVE_FUNCTIONS = [
    "/Script/Engine.Actor.K2_GetActorLocation", "/Script/Engine.Actor.SetActorHiddenInGame",
    "/Script/Engine.Actor.AddComponentByClass", "/Script/Engine.Actor.K2_GetComponentsByClass",
    "/Script/Engine.ActorComponent.K2_DestroyComponent", "/Script/Engine.SceneComponent.SetVisibility",
    "/Script/Engine.SceneComponent.IsVisible", "/Script/Engine.SceneComponent.SetRelativeScale3D",
    "/Script/Engine.SceneComponent.SetMobility", "/Script/Engine.PrimitiveComponent.SetCollisionEnabled",
    "/Script/Engine.PlayerController.ClientMessage", "/Script/Engine.Controller.IsLocalPlayerController", "/Script/SteamCorePro.SteamUtilities.MuteRemoteTalker",
    "/Script/Engine.LightComponent.SetIntensity", "/Script/Engine.LightComponent.SetLightColor",
    "/Script/Engine.LocalLightComponent.SetAttenuationRadius",
    "/Script/UMG.WidgetBlueprintLibrary.Create", "/Script/UMG.PanelWidget.AddChild",
    "/Script/UMG.PanelWidget.GetChildrenCount", "/Script/UMG.TextBlock.SetText", "/Script/UMG.SpinBox.SetDelta",
    "/Script/UMG.ScrollBox.GetScrollOffset",
    "/Script/UMG.SpinBox.SetMinFractionalDigits", "/Script/UMG.SpinBox.SetMaxFractionalDigits",
    "/Script/Engine.KismetTextLibrary.Conv_StringToText",
    "/Script/UMG.PanelWidget.GetChildAt", "/Script/Engine.SceneComponent.K2_AttachToComponent",
    "/Script/UMG.PanelWidget.RemoveChild", "/Script/UMG.VerticalBoxSlot.SetSize",
    "/Script/Engine.NetPushModelHelpers.MarkPropertyDirty", "/Script/Engine.GameplayStatics.SaveGameToSlot",
    "/Script/Engine.Actor.FlushNetDormancy", "/Script/UMG.Widget.GetCachedGeometry",
    "/Script/UMG.SlateBlueprintLibrary.LocalToAbsolute", "/Script/UMG.SlateBlueprintLibrary.AbsoluteToLocal",
    "/Script/UMG.SlateBlueprintLibrary.GetLocalSize", "/Script/UMG.CanvasPanelSlot.SetPosition",
    "/Script/UMG.CanvasPanelSlot.SetSize", "/Script/UMG.CanvasPanelSlot.SetZOrder", "/Script/UMG.Widget.SetVisibility",
    "/Script/UMG.Widget.GetVisibility", "/Script/UMG.TextBlock.SetFont", "/Script/UMG.TextBlock.SetColorAndOpacity",
    "/Script/UMG.TextBlock.SetAutoWrapText", "/Script/UMG.WidgetSwitcher.GetActiveWidget",
    "/Script/UMG.CanvasPanelSlot.GetPosition", "/Script/UMG.CanvasPanelSlot.GetSize", "/Script/UMG.CanvasPanelSlot.GetAnchors",
    "/Script/UMG.PanelWidget.ClearChildren", "/Script/UMG.ContentWidget.SetContent", "/Script/UMG.WrapBox.SetInnerSlotPadding",
    "/Script/UMG.Border.SetBrushColor", "/Script/UMG.Border.SetPadding",
    "/Script/MediaAssets.MediaSoundComponent.SetMediaPlayer", "/Script/MediaAssets.FileMediaSource.SetFilePath",
    "/Script/MediaAssets.MediaPlayer.OpenSource", "/Script/MediaAssets.MediaPlayer.Close", "/Script/Engine.Actor.K2_DestroyActor",
    "/Script/Engine.Actor.K2_TeleportTo", "/Script/Engine.PrimitiveComponent.GetCollisionEnabled",
    "/Script/Engine.ActorComponent.SetActive", "/Script/UMG.Widget.GetParent", "/Script/UMG.VerticalBoxSlot.SetPadding",
    "/Script/UMG.VerticalBoxSlot.SetHorizontalAlignment", "/Script/UMG.VerticalBoxSlot.SetVerticalAlignment",
    "/Script/UMG.WidgetComponent.GetMaterialInstance", "/Script/UMG.WidgetComponent.GetWidget", "/Script/UMG.Widget.RemoveFromParent",
    "/Script/Engine.PrimitiveComponent.SetCastShadow", "/Script/Engine.StaticMeshComponent.SetStaticMesh",
    "/Script/Engine.PrimitiveComponent.CreateDynamicMaterialInstance", "/Script/Engine.PrimitiveComponent.SetMaterial",
    "/Script/Engine.PrimitiveComponent.GetMaterial", "/Script/Engine.MaterialInstanceDynamic.SetScalarParameterValue", "/Script/Engine.MaterialInstanceDynamic.SetVectorParameterValue",
    "/Script/Engine.MaterialInstanceDynamic.K2_GetVectorParameterValue",
    "/Script/Engine.KismetSystemLibrary.LineTraceSingle", "/Script/Engine.AudioComponent.SetVolumeMultiplier",
    "/Script/Engine.TextRenderComponent.K2_SetText", "/Script/Engine.TextRenderComponent.SetTextRenderColor",
    "/Script/Engine.TextRenderComponent.SetWorldSize", "/Script/Engine.TextRenderComponent.SetHorizontalAlignment",
    "/Script/Engine.SceneComponent.K2_SetWorldRotation",
]
NATIVE_OBJECTS = ["/Script/UMG.ScrollBox", "/Script/UMG.VerticalBox", "/Script/UMG.TextBlock",
                  "/Script/UMG.WrapBox", "/Script/UMG.Border", "/Script/MediaAssets.MediaPlayer",
                  "/Script/MediaAssets.MediaSoundComponent", "/Script/MediaAssets.FileMediaSource",
                  "/Script/Engine.Default__NetPushModelHelpers", "/Script/Engine.Default__GameplayStatics",
                  "/Script/UMG.Default__SlateBlueprintLibrary", "/Script/UMG.Default__WidgetBlueprintLibrary",
                  "/Script/Engine.Default__KismetTextLibrary", "/Script/Engine.Default__KismetSystemLibrary",
                  "/Script/Engine.PrimitiveComponent", "/Script/Engine.PointLightComponent", "/Script/Engine.StaticMeshComponent",
                  "/Script/SteamCorePro.Default__SteamUtilities", "/Script/Engine.PlayerController",
                  "/Script/Engine.TextRenderComponent"]
ASSETS = ["/Game/Items/Melee/AccessCard/DA_AccessCard", "/Game/Items/Melee/SampleContainer/DA_Container",
          "/Game/Items/Melee/Fish/DA_Fish", "/Game/Items/Melee/ProcessedSample/Materials/M_HackerSphere",
          "/Game/Items/Melee/ProcessedSample/DA_Sample",
          "/ControlRig/Controls/ControlRigXRayMaterial", "/Engine/BasicShapes/Sphere"]
STRUCT_FIELDS = {"Str_AliveState": ["Alive_1_FD4B56084F2C8B7E0C61E289ED8A12E8", "Location_6_3846B1B5464EC1C009D1039EC345EE21", "Orientation_9_CABC5B924EC7C54F522C87A43A8B161B"],
                 "Str_Item": ["Data_18_5511228644AD6F4D6D0589BD4438C32F", "State_19_AFBBFC834F820A0E18A707A477B6D3FE"],
                 "Str_ItemState": ["Value_8_5511228644AD6F4D6D0589BD4438C32F", "Time_15_AFBBFC834F820A0E18A707A477B6D3FE"]}

errors, notes = [], []
def err(msg): errors.append(msg)

def load_dump(stem):
    funcs, props = {}, {}
    in_vars = False
    for line in open(os.path.join(BP, stem + ".txt"), encoding="utf-8"):
        if "-- variables" in line: in_vars = True; continue
        if in_vars:
            if not line.strip(): in_vars = False; continue
            body = line.strip().split("   [")[0]
            # "<type> <name>" where the type never contains two words except known patterns
            m = re.match(r"(?:(?:enum|Array<.*?>|Map<.*?>|Set<.*?>|MulticastInlineDelegate<.*?>|Class<.*?>|SoftClass<.*?>|\S+)(?: \(\w+\))?) (.+)$", body)
            if body.startswith("enum "): m = re.match(r"enum \S+ (.+)$", body)
            if m: props[m.group(1)] = body[:len(body) - len(m.group(1))].strip()
            continue
        m = re.match(r"  function (.+?)\((.*?)\)(?: -> [^\[]*)?(?:   \[(.*?)\])?(?:   overrides .*)?$", line.rstrip("\n"))
        if m:
            params = [p.strip() for p in m.group(2).split(", ")] if m.group(2).strip() else []
            funcs[m.group(1)] = {"params": params, "flags": m.group(3) or ""}
    return funcs, props

def main():
    # 1. syntax / scopes
    files = sorted(glob.glob(os.path.join(SCRIPTS, "*.lua")))
    for f in files:
        for p in luacheck.check_file(f): err(f"{os.path.basename(f)}: {p}")
    print(f"[1] syntaxe et portées : {len(files)} fichiers vérifiés")

    # 2. module cross references
    def strip_comments(text):
        return "\n".join(line.split("--", 1)[0] if '"' not in line.split("--", 1)[0][-1:] else line
                         for line in text.split("\n"))
    sources = {os.path.basename(f)[:-4]: strip_comments(open(f, encoding="utf-8").read()) for f in files}
    exports = {}
    for mod, src in sources.items():
        m = re.search(r"^return (\w+)\s*$", src, re.M)
        if not m: continue
        tbl = m.group(1)
        names = set(re.findall(rf"^\s*function {tbl}\.(\w+)", src, re.M))
        names |= set(re.findall(rf"(?:^|[\s,]){tbl}\.(\w+)(?=[\w\s,.]*=[^=])", src, re.M))
        exports[mod] = names
    used = 0
    for mod, src in sources.items():
        for alias, target in re.findall(r'local (\w+) = require\("(lpr_\w+)"\)', src):
            for name in set(re.findall(rf"(?<![\w.]){alias}\.(\w+)", src)):
                used += 1
                if name not in exports.get(target, set()):
                    err(f"{mod}.lua: {alias}.{name} n'existe pas dans {target}.lua")
    print(f"[2] références entre modules : {used} vérifiées")

    # 3. game symbols
    dumps = {k: load_dump(v) for k, v in DUMPS.items()}
    for owner, name, n, flag in FUNCTIONS:
        f = dumps[owner][0].get(name)
        if not f: err(f"fonction absente du jeu : {owner}.{name}"); continue
        if len(f["params"]) != n: err(f"{owner}.{name} : {len(f['params'])} paramètres dans le jeu, {n} attendus ({f['params']})")
        if flag and flag not in f["flags"].split(): err(f"{owner}.{name} : attendu '{flag}', drapeaux réels '{f['flags']}'")
        fp = FIRST_PARAM.get((owner, name))
        if fp and not f["params"][0].endswith(" " + fp): err(f"{owner}.{name} : premier paramètre '{f['params'][0]}', attendu '{fp}'")
    for owner, name in PROPERTIES:
        if name not in dumps[owner][1]: err(f"propriété absente du jeu : {owner}.{name}")
    print(f"[3a] fonctions Blueprint : {len(FUNCTIONS)} ; propriétés : {len(PROPERTIES)}")

    from zen import Game
    g = Game()
    script = set(g.script.values())
    for n in NATIVE_FUNCTIONS + NATIVE_OBJECTS:
        if n not in script: err(f"objet natif absent : {n}")
    for a in ASSETS:
        if a.lower() not in g.pub: err(f"asset absent : {a}")
    for struct, fields in STRUCT_FIELDS.items():
        paths = g.find(struct)
        names = g.load(paths[0]).names if paths else []
        for fld in fields:
            if fld not in names: err(f"champ absent de {struct} : {fld}")
    for cls, path in (("Mec_C", "/game/character/mec"), ("GM_C", "/game/gameplay/gm"),
                      ("W_Settings_Selection_C", "/game/ui/menu2/w_settings_selection"),
                      ("W_Settings_Value_C", "/game/ui/menu2/w_settings_value"),
                      ("W_Settings_Title_C", "/game/ui/menu2/w_settings_title"),
                      ("W_Settings_Text_C", "/game/ui/menu2/w_settings_text"),
                      ("W_Menu_MainTabButton_C", "/game/ui/menu2/w_menu_maintabbutton"),
                      ("W_Player_List_C", "/game/ui/game/w_player_list"),
                      ("W_PlayerState_C", "/game/ui/game/w_playerstate"),
                      ("Vent_C", "/game/world/tasks/task_vents/vent"),
                      ("DeadBody_C", "/game/character/ghost/deadbody")):
        if cls not in g.pub.get(path, {}).values(): err(f"classe absente : {path}.{cls}")
    print(f"[3b] fonctions natives : {len(NATIVE_FUNCTIONS)} ; objets : {len(NATIVE_OBJECTS)} ; assets : {len(ASSETS)}")

    # 4. coverage: every game name used in the Lua sources must be in the manifest
    known_fn = {n for _, n, _, _ in FUNCTIONS}
    known_prop = {n for _, n in PROPERTIES} | ENGINE_PROPERTIES
    native_short = {n.rsplit(".", 1)[1] for n in NATIVE_FUNCTIONS}
    seen = 0
    for mod, src in sources.items():
        for name in re.findall(r'(?:U\.t?call|G\.text_call)\(\s*[\w.]+\s*,\s*"([^"]+)"', src) + re.findall(r'\bhook\(\s*(?:G\.PATH_\w+\s*,\s*)?"([^"]+)"', src) + re.findall(r'G\.fn_path\(G\.PATH_\w+, "([^"]+)"\)', src):
            seen += 1
            if name.startswith("/Script/"):
                if name.replace(":", ".") not in NATIVE_FUNCTIONS: err(f"{mod}.lua : fonction native non couverte : {name}")
            elif name not in known_fn and name not in native_short: err(f"{mod}.lua : fonction du jeu non couverte par la vérification : {name}")
        # A text parameter must receive an engine text made by G.text_call (a Lua string crashes UE4SS).
        for name in re.findall(r'U\.t?call\(\s*[\w.]+\s*,\s*"([^"]+)"', src):
            takes_text = name in TEXT_NATIVES or any(
                any(p.split(" ")[0] == "text" for p in dumps[o][0].get(name, {"params": []})["params"]) for o in dumps)
            if takes_text: err(f"{mod}.lua : '{name}' prend un texte : passer par G.text_call")
        for name in re.findall(r':(\w+)\(', src):
            if name in TEXT_NATIVES: err(f"{mod}.lua : '{name}' prend un texte : passer par G.text_call")
        for name in re.findall(r'(?:U\.[gs]et|set_block_text)\(\s*[\w.]+\s*,\s*"([^"]+)"', src):
            seen += 1
            if name not in known_prop: err(f"{mod}.lua : propriété non couverte par la vérification : {name}")
        # UE4SS (this build) crashes when a Lua value is assigned to a text variable: it assumes an
        # engine text object without checking. Texts may only be passed as function parameters.
        writes = re.findall(r'U\.set\(\s*[\w.]+\s*,\s*"([^"]+)"', src) + re.findall(r'\[\s*"([^"]+)"\s*\]\s*=(?!=)', src)
        for name in writes:
            types = {dumps[o][1].get(name) for o in dumps} - {None}
            if any(t == "text" or "<text>" in t for t in types): err(f"{mod}.lua : écriture dans la variable texte '{name}' (fait planter UE4SS)")
        for name in re.findall(r'[\w\]\)]:(\w+)\(', src):
            if name in ("get", "IsValid", "GetAddress", "GetFullName", "ToString", "IsA", "Empty", "find", "sub", "match",
                        "gmatch", "gsub", "lower", "upper", "byte", "seek", "lines", "close", "write", "read", "format", "rep", "type", "GetFName", "GetClass"): continue
            seen += 1
            if name not in native_short: err(f"{mod}.lua : méthode native non couverte : {name}")
    menu_src = sources.get("lpr_menu", "")
    for ev in (EV_RIGHT, EV_LEFT, EV_COMMIT):
        if ev not in menu_src: err(f"lpr_menu.lua : nom d'evenement different du jeu : {ev}")
    for name in re.findall(r'UI \.\. "([^"]+)"', menu_src):
        pkg, cls = name.split(".")
        if cls not in g.pub.get(("/game/ui/menu2/" + pkg).lower(), {}).values(): err(f"lpr_menu.lua : classe absente : {name}")
    print(f"[4] couverture : {seen} usages de noms du jeu rattachés au manifeste")

    print()
    if errors:
        print(f"ÉCHEC : {len(errors)} problème(s)")
        for e in errors: print("  - " + e)
        return 1
    print("OK : aucune anomalie")
    return 0

if __name__ == "__main__":
    sys.exit(main())
