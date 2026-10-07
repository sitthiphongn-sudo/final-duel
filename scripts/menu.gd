extends Node3D
## เมนูหลัก FINAL DUEL (สไตล์ Overwatch 2)
## ซ้าย: โลโก้ + ปุ่มใหญ่ PLAY / CHARACTERS / MAPS / SETTINGS + ปุ่มเล็ก CREDITS / EXIT
## ฉากหลัง: ตัวละคร 3D ระยะใกล้ (ไฟที่มือ) บนภาพแมพเบลอ | ขวาบน: การ์ดผู้เล่น + ปุ่มเสียง/ตั้งค่า
## ขวาล่าง: ป้ายหกเหลี่ยม "NEW FIGHTER" | หน้าแผงย่อย: CHARACTERS, MAPS, SETTINGS, CREDITS

const GameState := preload("res://scripts/game_state.gd")
const FighterRig := preload("res://scripts/fighter_rig.gd")
const HandFire := preload("res://scripts/hand_fire.gd")
const FONT_TITLE := preload("res://fonts/BarlowCondensed-BoldItalic.woff2")
const FONT_BODY := preload("res://fonts/MPLUSRounded1c-Medium.woff2")
const BG_TEX := preload("res://ui/menu/menu_bg.jpg")
const SFX_HOVER := preload("res://sounds/whoosh_light.wav")
const SFX_CLICK := preload("res://sounds/block.wav")

@export_file("*.tscn") var play_scene := "res://scenes/character_select.tscn"
@export var music: AudioStream = preload("res://s_b.wav")
@export var game_version := "v0.1.0"
@export var player_name := "PLAYER 1"

const ANIM_LEN := {"Punch1": 0.26, "Punch2": 0.26, "Punch3": 0.47, "JumpKick": 0.45, "Land": 0.18,
	"Hit": 0.35, "HitHeavy": 0.6, "JumpPrep": 0.08, "BlockHit": 0.25, "DashF": 0.3, "DashB": 0.28}

## เครดิต (แก้ได้ตามต้องการ)
const CREDITS := [
	["GAME DESIGN & DEVELOPMENT", ["Phurin Srithan", "นายสิทธิพงษ์ นครขวาง", "นายกิตตินันท์ ไขไพรวัน"]],
	["ENGINE", ["Godot Engine 4.7  (MIT License)"]],
	["3D CHARACTERS & ARENA", ["Emberclaw, Frostfang, Skyborne Ruins", "Generated with Meshy AI"]],
	["PROGRAMMING ASSISTANCE", ["Claude by Anthropic"]],
	["JAPANESE VOICE", ["VOICEVOX"]],
	["MUSIC", ["\"s_b\" — provided by the developer"]],
	["SOUND EFFECTS & VFX", ["Procedurally generated"]],
	["FONTS", ["Barlow Condensed  (SIL Open Font License)", "M PLUS Rounded 1c  (SIL Open Font License)", "Loma  (TLWG, GPL with font exception)"]],
]

const C_ORANGE := Color(1.0, 0.6, 0.12)
const C_YELLOW := Color(1.0, 0.8, 0.2)
const C_TEXT := Color(0.96, 0.97, 1.0)
const C_DIM := Color(0.72, 0.78, 0.86)
const C_PANEL := Color(0.03, 0.05, 0.09, 0.84)

var f_title: FontVariation         # ตัวเอียงหนา (หัวข้อ/ปุ่มใหญ่)
var f_upright: FontVariation       # ตัวเดียวกันแต่ตั้งตรง (ปุ่มเล็ก/ป้าย)

var cam: Camera3D
var stage: Node3D
var models := {}
var shown_id := ""
var t := 0.0
var ui: Control
var menu_box: Control
var menu_items := {}               # key -> Control
var panel_root: Control
var panel_body: Control
var panel_title: Label
var current_panel := ""
var badge: Control
var fade: ColorRect
var bgm: AudioStreamPlayer
var busy := false
var char_detail: VBoxContainer
var char_cards: Array = []
var char_sel := ""
var vol_labels := {}
var mute_btn


func _ready() -> void:
	GameState.init_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	GameState.game_live = true
	f_title = FontVariation.new()
	f_title.base_font = FONT_TITLE
	f_upright = FontVariation.new()
	f_upright.base_font = FONT_TITLE
	f_upright.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	_build_world()
	_build_ui()
	_show_model(GameState.p1)
	if music:
		bgm = AudioStreamPlayer.new()
		bgm.bus = "Music"
		bgm.stream = music
		bgm.volume_db = -3.0
		add_child(bgm)
		bgm.finished.connect(bgm.play)
		bgm.play()


# ================= ฉาก 3D =================

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.58, 0.75)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-18, -38, 0)
	key.light_color = Color(1.0, 0.9, 0.8)
	key.light_energy = 1.5
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_color = Color(0.45, 0.65, 1.0)
	rim.light_energy = 1.6
	add_child(rim)
	var rim2 := OmniLight3D.new()
	rim2.position = Vector3(-1.2, 2.0, -0.8)
	rim2.light_color = Color(1.0, 0.45, 0.75)
	rim2.light_energy = 1.4
	rim2.omni_range = 4.0
	add_child(rim2)

	stage = Node3D.new()
	add_child(stage)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.78, 0.8, 0.95)
	bg_layer.add_child(bg)


func _show_model(id: String) -> void:
	if id == shown_id:
		return
	shown_id = id
	if not models.has(id):
		var d: Dictionary = GameState.data(id)
		var ps := load(d["walk_glb"]) as PackedScene
		if ps == null:
			return
		var m := ps.instantiate() as Node3D
		stage.add_child(m)
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var rig = FighterRig.new()
		var e := {"node": m, "rig": rig, "fire": []}
		if ap and rig.setup(m, ap):
			rig.build_all(ANIM_LEN)
			ap.play("FightIdle")
			if rig._skel:
				for side in [1, -1]:
					var att := BoneAttachment3D.new()
					att.bone_name = rig._skel.get_bone_name(rig._b(side, "Hand"))
					rig._skel.add_child(att)
					var fx := HandFire.new()
					fx.size = 1.15
					var fc: Array = d["fire"]
					fx.flipbook = load(d["flipbook"])
					fx.color_core = fc[0]
					fx.color_mid = fc[1]
					fx.color_tail = fc[2]
					fx.color_ember = fc[3]
					fx.color_light = fc[4]
					fx.position = Vector3(0, 0.12, 0)
					att.add_child(fx)
					e["fire"].append(fx)
		models[id] = e
	for k in models:
		models[k]["node"].visible = k == id
	var n: Node3D = models[id]["node"]
	n.position = Vector3(0.25, 0, 0)
	var tw := create_tween()
	tw.tween_property(n, "position", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for fx in models[id]["fire"]:
		fx.boost(1.5)


# ================= UI =================

func _lbl(txt: String, font: Font, size: int, col := C_TEXT, outline := 0) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.8))
		l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _style(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	# ไล่มืดด้านซ้ายให้ตัวหนังสืออ่านง่าย
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.03, 0.08, 0.72), Color(0.02, 0.03, 0.08, 0.35), Color(0.02, 0.03, 0.08, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.55
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

	var ver := _lbl("%s  ·  1V1 BUILD" % game_version, FONT_BODY, 9, Color(1, 1, 1, 0.45))
	ver.position = Vector2(10, 5)
	ui.add_child(ver)

	# ---- โลโก้ ----
	var logo := HBoxContainer.new()
	logo.position = Vector2(34, 26)
	logo.add_theme_constant_override("separation", 6)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(logo)
	var lt := _lbl("FINAL DUEL", f_title, 52, C_TEXT, 3)
	logo.add_child(lt)
	var tag := PanelContainer.new()
	var tsb := _style(C_ORANGE, Color(1, 1, 1, 0.0), 0, 3)
	tsb.content_margin_left = 7
	tsb.content_margin_right = 9
	tag.add_theme_stylebox_override("panel", tsb)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(_lbl("1V1", f_title, 30, Color.WHITE))
	logo.add_child(tag)

	# ---- เมนูซ้าย ----
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(46, 205)
	menu_box.add_theme_constant_override("separation", -6)
	menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(menu_box)
	for it in [["play", "PLAY", ""], ["characters", "CHARACTERS", "NEW!"], ["maps", "MAPS", ""], ["settings", "SETTINGS", ""]]:
		menu_box.add_child(_menu_item(it[0], it[1], true, it[2]))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	menu_box.add_child(gap)
	for it in [["credits", "CREDITS"], ["exit", "EXIT"]]:
		menu_box.add_child(_menu_item(it[0], it[1], false, ""))

	_build_top_right()
	_build_badge()
	_build_panel_frame()

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 0.6)


## ปุ่มเมนู: ใหญ่ = ตัวเอียงหนา, เล็ก = ตัวตั้งตรงเว้นระยะ; ชี้แล้วเลื่อนขวา + สีส้ม
func _menu_item(key: String, text: String, big: bool, badge_txt: String) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(300, 58 if big else 28)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inner)
	var bar := ColorRect.new()                       # แถบส้มด้านหน้าตอนชี้
	bar.color = C_ORANGE
	bar.custom_minimum_size = Vector2(4, 0)
	bar.position = Vector2(-14, 10 if big else 5)
	bar.size = Vector2(4, 38 if big else 16)
	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var l: Label
	if big:
		l = _lbl(text, f_title, 50, C_TEXT, 2)
	else:
		l = _lbl(text, f_upright, 20, C_DIM, 0)
		l.add_theme_constant_override("shadow_offset_x", 1)
	inner.add_child(l)
	if badge_txt != "":
		var b := _lbl(badge_txt, f_title, 15, C_YELLOW, 4)
		b.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0, 0.9))
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		inner.add_child(b)
	row.set_meta("label", l)
	row.set_meta("inner", inner)
	row.set_meta("bar", bar)
	row.set_meta("big", big)
	row.mouse_entered.connect(func(): _hover(key, true))
	row.mouse_exited.connect(func(): _hover(key, false))
	row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_menu(key))
	menu_items[key] = row
	return row


func _hover(key: String, on: bool) -> void:
	var row: Control = menu_items[key]
	var active := on or key == current_panel
	var l: Label = row.get_meta("label")
	var big: bool = row.get_meta("big")
	var col := C_ORANGE if active else (C_TEXT if big else C_DIM)
	l.add_theme_color_override("font_color", col)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(row.get_meta("inner"), "position:x", 12.0 if active else 0.0, 0.14).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(row.get_meta("bar"), "modulate:a", 1.0 if active else 0.0, 0.14)
	if on:
		_sfx(SFX_HOVER, -20.0, 1.6)


func _refresh_menu() -> void:
	for k in menu_items:
		_hover(k, false)


## การ์ดผู้เล่นขวาบน + ปุ่มปิดเสียง + ปุ่มตั้งค่า
func _build_top_right() -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-300, 26)
	box.add_theme_constant_override("separation", 5)
	ui.add_child(box)
	var card := PanelContainer.new()
	var csb := _style(Color(0.92, 0.94, 0.97, 0.92), Color(0, 0, 0, 0), 0, 1)
	csb.content_margin_left = 3
	csb.content_margin_right = 12
	card.add_theme_stylebox_override("panel", csb)
	card.custom_minimum_size = Vector2(190, 36)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(card)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	var por := TextureRect.new()
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	por.custom_minimum_size = Vector2(32, 32)
	por.texture = load(GameState.data(GameState.p1)["portrait"])
	por.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(por)
	var nm := _lbl(player_name, f_upright, 15, Color(0.1, 0.12, 0.18))
	nm.remove_theme_color_override("font_shadow_color")
	nm.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(nm)
	mute_btn = IconButton.new()
	mute_btn.kind = "sound"
	mute_btn.bg = Color(0.92, 0.94, 0.97, 0.92)
	mute_btn.fg = Color(0.1, 0.12, 0.18)
	mute_btn.custom_minimum_size = Vector2(36, 36)
	mute_btn.off = GameState.audio["master"] <= 0.001
	mute_btn.pressed_btn.connect(_toggle_mute)
	box.add_child(mute_btn)
	var set_btn = IconButton.new()
	set_btn.kind = "gear"
	set_btn.bg = C_ORANGE
	set_btn.fg = Color.WHITE
	set_btn.custom_minimum_size = Vector2(36, 36)
	set_btn.pressed_btn.connect(func(): _on_menu("settings"))
	box.add_child(set_btn)


var _unmute_value := 0.8
func _toggle_mute() -> void:
	if GameState.audio["master"] > 0.001:
		_unmute_value = GameState.audio["master"]
		GameState.set_volume("master", 0.0)
	else:
		GameState.set_volume("master", maxf(_unmute_value, 0.3))
	GameState.save_settings()
	mute_btn.off = GameState.audio["master"] <= 0.001
	mute_btn.queue_redraw()
	if current_panel == "settings":
		_open_panel("settings")


## ป้ายหกเหลี่ยมขวาล่าง (แบบ DOUBLE MATCH XP) -> กดแล้วไปดูตัวละครใหม่
func _build_badge() -> void:
	badge = HexBadge.new()
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.position = Vector2(-190, -250)
	badge.size = Vector2(160, 230)
	badge.art = load(GameState.data("frostfang")["card"])
	badge.font = f_title
	badge.line1 = "NEW FIGHTER"
	badge.line2 = "FROSTFANG"
	badge.clicked.connect(func():
		_on_menu("characters")
		_select_char("frostfang"))
	ui.add_child(badge)


# ================= แผงย่อย =================

func _build_panel_frame() -> void:
	panel_root = Control.new()
	panel_root.anchor_left = 0.36
	panel_root.anchor_right = 1.0
	panel_root.anchor_top = 0.0
	panel_root.anchor_bottom = 1.0
	panel_root.offset_left = 0
	panel_root.offset_right = -36
	panel_root.offset_top = 86
	panel_root.offset_bottom = -34
	panel_root.visible = false
	ui.add_child(panel_root)
	var bg := Panel.new()
	var sb := _style(C_PANEL, Color(1, 1, 1, 0.08), 1, 2)
	sb.border_color = Color(1, 1, 1, 0.1)
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_root.add_child(bg)
	var top := ColorRect.new()                        # เส้นส้มบนหัวแผง
	top.color = C_ORANGE
	top.anchor_right = 1.0
	top.offset_bottom = 3
	panel_root.add_child(top)
	panel_title = _lbl("", f_title, 38, C_TEXT, 2)
	panel_title.position = Vector2(26, 12)
	panel_root.add_child(panel_title)
	var back := Button.new()
	back.text = "✕  BACK"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", f_upright)
	back.add_theme_font_size_override("font_size", 16)
	back.add_theme_color_override("font_color", C_DIM)
	back.add_theme_color_override("font_hover_color", C_ORANGE)
	back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back.position = Vector2(-100, 18)
	back.pressed.connect(_close_panel)
	panel_root.add_child(back)
	panel_body = Control.new()
	panel_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_body.offset_left = 26
	panel_body.offset_right = -26
	panel_body.offset_top = 70
	panel_body.offset_bottom = -22
	panel_root.add_child(panel_body)


func _on_menu(key: String) -> void:
	if busy:
		return
	_sfx(SFX_CLICK, -10.0, 1.3)
	match key:
		"play":
			busy = true
			var tw := create_tween()
			tw.tween_property(fade, "color:a", 1.0, 0.4)
			if bgm:
				tw.parallel().tween_property(bgm, "volume_db", -40.0, 0.4)
			tw.tween_callback(func(): get_tree().change_scene_to_file(play_scene))
		"exit":
			busy = true
			var tw := create_tween()
			tw.tween_property(fade, "color:a", 1.0, 0.35)
			tw.tween_callback(func(): get_tree().quit())
		_:
			_open_panel(key)


func _open_panel(key: String) -> void:
	current_panel = key
	_refresh_menu()
	for c in panel_body.get_children():
		c.queue_free()
	panel_title.text = {"characters": "CHARACTERS", "maps": "MAPS", "settings": "SETTINGS", "credits": "CREDITS"}.get(key, "")
	match key:
		"characters": _panel_characters()
		"maps": _panel_maps()
		"settings": _panel_settings()
		"credits": _panel_credits()
	if not panel_root.visible:
		panel_root.visible = true
		panel_root.modulate.a = 0.0
		panel_root.position.x += 40
		var tw := create_tween().set_parallel(true)
		tw.tween_property(panel_root, "modulate:a", 1.0, 0.2)
		tw.tween_property(panel_root, "position:x", panel_root.position.x - 40, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	badge.visible = false


func _close_panel() -> void:
	if current_panel == "":
		return
	if current_panel == "settings":
		GameState.save_settings()
	current_panel = ""
	_refresh_menu()
	var tw := create_tween()
	tw.tween_property(panel_root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		panel_root.visible = false
		badge.visible = true)
	_show_model(GameState.p1)


# ---- CHARACTERS ----

func _panel_characters() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 22)
	panel_body.add_child(hb)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	hb.add_child(list)
	char_cards.clear()
	for id in GameState.ORDER:
		var c := ThumbCard.new()
		c.custom_minimum_size = Vector2(118, 132)
		c.tex = load(GameState.data(id)["card"])
		c.caption = GameState.data(id)["name"]
		c.font = f_title
		c.accent = GameState.data(id)["color"]
		c.set_meta("id", id)
		c.clicked.connect(func(): _select_char(id))
		list.add_child(c)
		char_cards.append(c)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(sc)
	char_detail = VBoxContainer.new()
	char_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_detail.add_theme_constant_override("separation", 6)
	sc.add_child(char_detail)
	_select_char(char_sel if char_sel != "" else GameState.p1)


func _select_char(id: String) -> void:
	char_sel = id
	_show_model(id)
	if char_detail == null or not is_instance_valid(char_detail):
		return
	for c in char_cards:
		c.selected = c.get_meta("id") == id
		c.queue_redraw()
	for c in char_detail.get_children():
		c.queue_free()
	var d: Dictionary = GameState.data(id)
	char_detail.add_child(_lbl(d["name"], f_title, 44, C_TEXT, 2))
	var sub := _lbl("%s   ·   %s   ·   %s" % [d["title"].to_upper(), ("FIRE" if d["element"] == "fire" else "ICE"), d["style"].to_upper()], f_upright, 15, d["color"])
	char_detail.add_child(sub)
	char_detail.add_child(_spacer(6))
	var desc := _lbl(d["desc"], FONT_BODY, 13, C_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(320, 0)
	char_detail.add_child(desc)
	char_detail.add_child(_spacer(8))
	char_detail.add_child(_stat_bar("HEALTH", float(d["hp"]), 2500.0, str(d["hp"]), d["color"]))
	char_detail.add_child(_stat_bar("ATTACK", float(d["atk"]), 30.0, str(d["atk"]), d["color"]))
	char_detail.add_child(_spacer(8))
	char_detail.add_child(_lbl("ABILITIES", f_upright, 16, C_ORANGE))
	for ab in d["abilities"]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var k := PanelContainer.new()
		var ksb := _style(Color(1, 1, 1, 0.9), Color(0, 0, 0, 0), 0, 3)
		ksb.content_margin_left = 6
		ksb.content_margin_right = 6
		k.add_theme_stylebox_override("panel", ksb)
		k.custom_minimum_size = Vector2(44, 0)
		var kl := _lbl(ab[0] + (" " + ab[1] if ab[1] != "" else ""), f_upright, 13, Color(0.08, 0.1, 0.15))
		kl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k.add_child(kl)
		r.add_child(k)
		r.add_child(_lbl(ab[2].to_upper(), f_title, 20, C_TEXT))
		char_detail.add_child(r)


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


func _stat_bar(label_txt: String, v: float, vmax: float, txt: String, col: Color) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	var n := _lbl(label_txt, f_upright, 15, C_DIM)
	n.custom_minimum_size = Vector2(70, 0)
	r.add_child(n)
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.1)))
	back.custom_minimum_size = Vector2(240, 10)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(back)
	var fill := ColorRect.new()
	fill.color = col
	fill.size = Vector2(240.0 * clampf(v / vmax, 0.0, 1.0), 10)
	back.add_child(fill)
	r.add_child(_lbl(txt, f_title, 18, C_TEXT))
	return r


# ---- MAPS ----

func _panel_maps() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 22)
	panel_body.add_child(hb)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	hb.add_child(list)
	var m: Dictionary = GameState.MAPS[0]
	var c := ThumbCard.new()
	c.custom_minimum_size = Vector2(150, 90)
	c.tex = load(m["image"])
	c.caption = m["name"]
	c.font = f_title
	c.accent = C_ORANGE
	c.selected = true
	list.add_child(c)
	var soon := ThumbCard.new()
	soon.custom_minimum_size = Vector2(150, 90)
	soon.caption = "COMING SOON"
	soon.font = f_title
	soon.accent = Color(0.5, 0.5, 0.55)
	soon.locked = true
	list.add_child(soon)

	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.25), 1))
	v.add_child(frame)
	var img := TextureRect.new()
	img.texture = load(m["image"])
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(440, 210)
	frame.add_child(img)
	v.add_child(_lbl(m["name"], f_title, 34, C_TEXT, 2))
	for row in [["LOCATION", m["location"]], ["MODE", m["mode"]], ["ARENA", m["size"]], ["TIME OF DAY", m["time"]], ["HAZARDS", m["hazards"]]]:
		var r := HBoxContainer.new()
		var a := _lbl(row[0], f_upright, 14, C_ORANGE)
		a.custom_minimum_size = Vector2(100, 0)
		r.add_child(a)
		r.add_child(_lbl(row[1], FONT_BODY, 13, C_TEXT))
		v.add_child(r)
	var desc := _lbl(m["desc"], FONT_BODY, 13, C_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	v.add_child(_spacer(4))
	v.add_child(desc)


# ---- SETTINGS ----

func _panel_settings() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	panel_body.add_child(v)
	v.add_child(_lbl("AUDIO", f_upright, 18, C_ORANGE))
	vol_labels.clear()
	for row in [["master", "MASTER VOLUME"], ["music", "MUSIC VOLUME"], ["sfx", "EFFECTS VOLUME"]]:
		v.add_child(_volume_row(row[0], row[1]))
	v.add_child(_spacer(10))
	var reset := Button.new()
	reset.text = "RESET TO DEFAULT"
	reset.focus_mode = Control.FOCUS_NONE
	reset.custom_minimum_size = Vector2(200, 36)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.add_theme_font_override("font", f_upright)
	reset.add_theme_font_size_override("font_size", 16)
	reset.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.25), 1, 2))
	reset.add_theme_stylebox_override("hover", _style(C_ORANGE, C_ORANGE, 1, 2))
	reset.add_theme_stylebox_override("pressed", _style(C_ORANGE.darkened(0.2), C_ORANGE, 1, 2))
	reset.pressed.connect(func():
		for k in GameState.AUDIO_DEFAULTS:
			GameState.set_volume(k, GameState.AUDIO_DEFAULTS[k])
		GameState.save_settings()
		mute_btn.off = false
		mute_btn.queue_redraw()
		_open_panel("settings"))
	v.add_child(reset)
	var note := _lbl("Settings are saved automatically.", FONT_BODY, 12, C_DIM)
	v.add_child(note)


func _volume_row(key: String, title: String) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 16)
	var n := _lbl(title, f_title, 24, C_TEXT)
	n.custom_minimum_size = Vector2(190, 0)
	r.add_child(n)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.value = round(GameState.audio[key] * 100.0)
	s.custom_minimum_size = Vector2(280, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	var track := _style(Color(1, 1, 1, 0.15), Color(0, 0, 0, 0), 0, 2)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	var filled := _style(C_ORANGE, Color(0, 0, 0, 0), 0, 2)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)
	var val := _lbl(str(int(s.value)), f_title, 24, C_ORANGE)
	val.custom_minimum_size = Vector2(44, 0)
	s.value_changed.connect(func(x: float):
		GameState.set_volume(key, x / 100.0)
		val.text = str(int(x))
		if key == "master":
			mute_btn.off = x <= 0.0
			mute_btn.queue_redraw())
	s.drag_ended.connect(func(_changed: bool):
		GameState.save_settings()
		if key == "sfx" or key == "master":
			_sfx(SFX_CLICK, -2.0, 1.0))
	r.add_child(s)
	r.add_child(val)
	return r


# ---- CREDITS ----

func _panel_credits() -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_body.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	sc.add_child(v)
	var head := _lbl("FINAL DUEL", f_title, 40, C_TEXT, 2)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	for sec in CREDITS:
		v.add_child(_spacer(8))
		var h := _lbl(sec[0], f_upright, 15, C_ORANGE)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(h)
		for line in sec[1]:
			var l := _lbl(line, FONT_BODY, 14, C_TEXT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
	v.add_child(_spacer(14))
	var thanks := _lbl("THANK YOU FOR PLAYING", f_title, 26, C_YELLOW)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(thanks)


# ================= อื่นๆ =================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_panel()


func _process(delta: float) -> void:
	t += delta
	# กล้องระยะใกล้ ส่ายช้าๆ (ตัวละครเยื้องไปทางขวาของจอ)
	var sway := sin(t * 0.25)
	var focus := Vector3(-0.55, 1.18, 0.0)
	var pos := Vector3(0.55 + sway * 0.12, 1.02 + sin(t * 0.33) * 0.04, 2.05)
	cam.global_transform = Transform3D(Basis(), pos).looking_at(focus, Vector3.UP)
	if shown_id != "" and models.has(shown_id):
		models[shown_id]["node"].rotation.y = 0.42 + sin(t * 0.4) * 0.05


func _sfx(stream: AudioStream, vol := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = vol
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ================= คอนโทรลวาดเอง =================

## ปุ่มไอคอนสี่เหลี่ยม (ลำโพง / เฟือง)
class IconButton extends Control:
	signal pressed_btn
	var kind := "gear"
	var bg := Color.WHITE
	var fg := Color.BLACK
	var off := false
	var _hover := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			_hover = true
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed_btn.emit()
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), bg.lightened(0.15) if _hover else bg)
		var c := size * 0.5
		if kind == "gear":
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2.from_angle(a)
				draw_line(c + d * 6.0, c + d * 11.0, fg, 4.0)
			draw_circle(c, 8.0, fg)
			draw_circle(c, 3.5, bg)
		else:
			var body := PackedVector2Array([c + Vector2(-9, -4), c + Vector2(-4, -4), c + Vector2(2, -9), c + Vector2(2, 9), c + Vector2(-4, 4), c + Vector2(-9, 4)])
			draw_colored_polygon(body, fg)
			if off:
				draw_line(c + Vector2(5, -5), c + Vector2(12, 5), fg, 2.5)
				draw_line(c + Vector2(12, -5), c + Vector2(5, 5), fg, 2.5)
			else:
				draw_arc(c + Vector2(2, 0), 6.0, -0.9, 0.9, 12, fg, 2.0)
				draw_arc(c + Vector2(2, 0), 10.0, -0.9, 0.9, 12, fg, 2.0)


## ป้ายหกเหลี่ยมส้ม มีรูปตัวละครโผล่พ้นกรอบด้านบน
class HexBadge extends Control:
	signal clicked
	var art: Texture2D
	var font: Font
	var line1 := ""
	var line2 := ""
	var t := 0.0
	var _hover := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true)
		mouse_exited.connect(func(): _hover = false)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
			accept_event()

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _hex(c: Vector2, r: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 6:
			p.append(c + Vector2.from_angle(deg_to_rad(60.0 * i - 90.0)) * r)
		return p

	func _draw() -> void:
		var s := 1.0 + (0.04 if _hover else 0.0) + 0.015 * sin(t * 2.5)
		var c := Vector2(size.x * 0.5, size.y - 80.0)
		var r := 74.0 * s
		var outer := _hex(c, r + 5.0)
		draw_colored_polygon(outer, Color.WHITE)
		var inner := _hex(c, r)
		var cols := PackedColorArray()
		for v in inner:
			cols.append(Color(1.0, 0.72, 0.2).lerp(Color(0.95, 0.42, 0.05), (v.y - (c.y - r)) / (2.0 * r)))
		draw_polygon(inner, cols)
		if art:
			# รูปตัวละครโผล่จากกลางป้ายขึ้นไปด้านบน
			var w := 120.0 * s
			var h := w * art.get_size().y / art.get_size().x
			draw_texture_rect(art, Rect2(c.x - w * 0.5, c.y - r - h * 0.55, w, h), false)
		if font:
			for i in 2:
				var txt := line1 if i == 0 else line2
				var fs := 20 if i == 0 else 24
				var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var pos := Vector2(c.x - tw * 0.5, c.y + 10.0 + i * 24.0)
				draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.4, 0.15, 0.0, 0.8))
				draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## การ์ดรูปย่อในแผง (ตัวละคร / แมพ)
class ThumbCard extends Control:
	signal clicked
	var tex: Texture2D
	var caption := ""
	var font: Font
	var accent := Color.WHITE
	var selected := false
	var locked := false
	var _hover := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func():
			_hover = true
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if not locked and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.1, 0.16, 0.95))
		draw_rect(Rect2(0, size.y * 0.5, size.x, size.y * 0.5), Color(accent.r, accent.g, accent.b, 0.18 if selected else 0.08))
		if tex:
			var ts := tex.get_size()
			var sc := maxf(r.size.x / ts.x, r.size.y / ts.y)
			var src_size := r.size / sc
			draw_texture_rect_region(tex, r, Rect2((ts - src_size) * Vector2(0.5, 0.2), src_size), Color(1, 1, 1, 1.0 if (selected or _hover) else 0.6))
		if locked:
			draw_rect(r, Color(0, 0, 0, 0.45))
		# แถบชื่อด้านล่าง
		draw_rect(Rect2(0, size.y - 22, size.x, 22), Color(0, 0, 0, 0.6))
		if font:
			var fs := 16
			var tw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((size.x - tw) * 0.5, size.y - 6), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.6, 0.12) if selected else Color.WHITE)
		if selected:
			draw_rect(r, Color(1.0, 0.6, 0.12), false, 3.0)
		elif _hover and not locked:
			draw_rect(r, Color(1, 1, 1, 0.6), false, 1.5)
